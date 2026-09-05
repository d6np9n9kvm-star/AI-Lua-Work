# Independent Follow-up Review — `fal-core.lua` v1.2.0 + WAR Core Conversion

## Scope

This is the follow-up review of Claude's response to the prior independent audit.

Files inspected:

- `fal-core.lua` v1.2.0
- `fal-core-v1.1.0-to-v1.2.0.diff`
- `REVIEW-RESPONSE.md`
- `harness.lua`
- `falcheck.lua`
- `test_core.lua`
- `test_moving.lua`
- `test_jobs.lua`
- `validate.lua`
- `fal-owned.lua`
- `run-tests.sh`
- converted `WAR_2.lua`

I checked whether the previous P0/P1 findings were actually implemented, then looked for new integration or test defects introduced by the hardening pass and the WAR conversion.

## Important verification limitation

I could inspect all delivered source and tests, but this review environment does not have `lua5.1` or `luac5.1` installed, so I could **not independently execute `run-tests.sh`**.

Accordingly:

- I verified the fixes structurally and logically from the delivered code.
- I verified that the assertion runner now exits non-zero on failure.
- I verified that the test cases described below exist.
- I am **not independently certifying Claude's claimed numerical pass count**.

Claude should run the full gate after the remaining corrections below.

---

# Executive verdict

## The previous P0 blockers are fixed.

The following prior findings are genuinely addressed in the code:

- complete-load sentinel exists and is assigned as the last statement;
- `require_version()` checks the full major/minor/patch version;
- `MANIFEST_REQUIRED` is checked against the actual namespace table;
- harness lifecycle errors are no longer silently discarded;
- `user_setup()` now executes in the harness;
- table-form `include(file, table)` semantics are reproduced;
- tests now use a real fail-fast assertion runner;
- validation receives the actual job identity;
- ring release settle is restored to 1.0 seconds;
- Core no longer depends on WAR/BLU having an RDM-only `check_gear()` global;
- action-row reporting is capability-aware;
- reserved key collisions are rejected;
- movement override is stored rather than replacing the module method;
- stale movement refresh tokens are checked before clearing queue state;
- callback failures are surfaced;
- TH now has a policy seam.

The architecture **does not need another redesign**.

However, I found a small set of remaining issues that should be fixed before starting the next shared-engine extraction. Two are real code-quality/lifecycle issues and one is a real test bug.

There are **no P0 blockers** remaining.

---

# Required cleanup before the next extraction

## P1-1 — `FalCore.init()` is not actually idempotent

### File

`fal-core.lua`, lifecycle `init()` around lines 767-801.

### Current behavior

`init()` currently does this:

```lua
runtime.event_ids = {}
keys.bound = {}
```

and then may register a new movement prerender event.

The comment says:

> `init()` is deliberately idempotent

but resetting the Lua bookkeeping tables is not the same thing as undoing the external Windower side effects those tables describe.

If the same Core namespace is initialized twice without a prior `unload()`:

1. old Windower event IDs are discarded from `runtime.event_ids` without being unregistered;
2. old key names are discarded from `keys.bound` without being unbound;
3. a new movement `prerender` event can then be registered;
4. `unload()` only knows about the newer event/key records.

That produces leaked callbacks/binds in exactly the defensive-reuse scenario `init()` claims to handle.

### Why this matters

Normal GearSwap job loads appear to create a fresh environment, so this is not presently a reason to reject the WAR conversion.

But Core explicitly advertises idempotent defensive initialization. At 22 jobs, lifecycle claims should be true, especially before more modules begin registering events.

### Required fix

Before clearing ownership tables in `init()`:

```lua
keys.unbind_all()
events.unregister_all()
```

Then reset/rebuild state.

If there are other Core-owned external side effects added later, `init()` should clean them before replacing their tracking state.

### Required regression test

Test this exact sequence:

```text
Core.init()
Core.keys.apply(...)
register/track events
Core.init() again
```

Assert that:

- every old key was unbound;
- every old event was unregistered;
- old IDs are not lost;
- only the new movement event remains after re-init;
- final `unload()` cleans the second initialization.

After this fix, calling `init()` idempotent is justified.

---

## P1-2 — WAR currently unregisters Core's internal events and manually rebuilds one

### File

`WAR_2.lua`, `register_war_events()` around lines 757-779.

### Current code pattern

WAR does:

```lua
FalCore.events.unregister_all()
...
FalCore.events.track(windower.raw_register_event('prerender', FalCore.move.sample))
```

But `FalCore.init{movement_ring=...}` already registers Core's movement prerender event.

Therefore WAR currently:

1. initializes Core;
2. Core registers its own movement event;
3. WAR calls `FalCore.events.unregister_all()` and destroys Core's event;
4. WAR manually re-registers Core's internal movement callback.

This happens to preserve movement **today**, because movement is currently the only Core-owned event registered by `init()`.

It is a poor ownership boundary.

If `fal-core.lua`, `fal-combat.lua`, or another shared module later registers an event that WAR does not know about, `register_war_events()` can silently delete it.

That recreates the exact shared-engine/job-coupling problem this refactor is meant to eliminate.

### Required fix

WAR should not globally reset the Core event registry during ordinary startup.

For this conversion:

- remove `FalCore.events.unregister_all()` from `register_war_events()`;
- remove WAR's manual registration of `FalCore.move.sample`;
- let `FalCore.init()` own the movement prerender event;
- register only WAR-specific events (`action`, `zone change`) through `FalCore.events.track/register`.

`FalCore.unload()` should remain the one global cleanup point.

If repeated job-specific event registration becomes necessary later, add scoped/grouped event ownership rather than having a job erase the whole Core registry.

### Required regression test

After a normal WAR load, verify:

- Core movement prerender is registered exactly once;
- WAR action event is registered once;
- WAR zone event is registered once;
- WAR setup never unregisters Core's already-registered internal event;
- unload removes all three.

---

## P1-3 — Remove the dead legacy `_movementrefresh` engine from WAR

### File

`WAR_2.lua`, `job_self_command()` around lines 2898-2929.

### Finding

Core now owns the managed movement command:

```text
_falmovementrefresh
```

through:

```lua
FalCore.self_command(...)
```

But WAR still contains the entire old:

```lua
elseif cmd == '_movementrefresh' then
    ...
end
```

implementation.

Nothing in the delivered Core/WAR code queues `_movementrefresh` anymore; Core queues `_falmovementrefresh`.

So this block is dead duplicated engine code.

Worse, the dead block contains the exact stale-token ordering defect that was just fixed in Core:

```lua
FalCore.move.refresh_queued = false
...
if FalCore.runtime.unloading or cmdParams[2] ~= FalCore.runtime.token then return end
```

Core correctly validates the token **before** clearing the queue flag.

### Why this matters

Even though the branch is currently unreachable through normal Core movement, retaining it:

- leaves duplicate movement-engine logic in WAR;
- preserves a known-bad version of that logic;
- creates an obvious future regression path if an old command is accidentally reintroduced;
- undermines the extraction goal.

### Required fix

Delete the WAR `_movementrefresh` branch completely.

`FalCore.self_command()` must be the sole owner of managed Core movement refresh.

Do not keep the old branch "for compatibility" unless there is a demonstrated external caller that still emits it. None appears in the delivered files.

---

## P1-4 — One WAR regression assertion is logically ineffective

### File

`test_jobs.lua`, WAR A6 section, current line ~35.

### Current assertion

```lua
check.ne(
    kj.Acc.ammo,
    mh.Acc.ammo == kj.Acc.ammo and nil or '#',
    'KJ.Acc is not MultiHit.Acc'
)
```

This does not compare `kj.Acc.ammo` against `mh.Acc.ammo`.

Because of Lua's `and/or` behavior:

```lua
condition and nil or '#'
```

evaluates to `'#'` whether the condition is true or false.

So the test effectively becomes:

```lua
check.ne(kj.Acc.ammo, '#', ...)
```

which will almost always pass and does not prove the stated invariant.

### Required fix

Use the direct comparison:

```lua
check.ne(kj.Acc.ammo, mh.Acc.ammo, 'KJ.Acc ammo differs from MultiHit.Acc')
```

If the intended invariant is broader than ammo, add explicit checks for the fields that distinguish King's Justice from the generic MultiHit set.

This is a real test defect and should be fixed before quoting the suite as regression proof.

---

# Finish the one acknowledged test gap now

## P1-5 — Add direct Fishing + movement integration tests

Claude's response correctly acknowledges that the requested combined scenarios were still only covered indirectly.

Do not defer these again.

The movement/ring/Fishing ownership boundary is one of the most failure-prone parts of this architecture.

Add direct assertions for:

### Case A — Fishing + moving + ring2 protected

- Fishing active.
- Player moving.
- ring2 contains a protected ring.
- ring1 is available.
- movement overlay selects ring1.
- Fishing keeps non-ring slots locked.
- protected ring2 remains locked.
- movement ring can still flow into ring1.

### Case B — Fishing + moving + both rings protected

- Fishing active.
- Player moving.
- both rings protected.
- movement overlay returns nil.
- neither protected ring is displaced.

### Case C — movement transition while Fishing

Exercise the actual managed refresh path, not only `move.overlay()`:

- begin Fishing while stationary;
- movement starts;
- Core queues/handles `_falmovementrefresh`;
- non-ring Fishing locks remain intact;
- selected live ring receives movement policy;
- stop movement;
- managed refresh returns to normal Fishing ring policy.

These tests are particularly valuable now that WAR's old `_movementrefresh` branch will be removed.

---

# P2 cleanup — make the release/test packet reproducible

This is not an architecture blocker, but the delivered packet is not fully self-contained.

Examples:

- `run-tests.sh` expects `WAR.lua`, while the delivered converted file is named `WAR_2.lua`;
- `test_jobs.lua` compares against `WAR.pre-core.lua`, which was not included in this response packet;
- `run-tests.sh` also assumes the original `RDM.lua`, `BLU.lua`, and `ItemStats.lua` are present.

Those files may exist in Claude's working project, so this does not mean the tests are invalid there.

However, when calling a bundle a reproducible review/release gate, either:

1. include every required fixture/file, or
2. document the required external baseline files explicitly.

For the user's actual installation artifact, ensure the converted WAR is delivered under the intended final filename (`WAR.lua`).

---

# Optional P2 improvement — validate before unbinding keys

`keys.apply()` currently calls:

```lua
keys.unbind_all()
```

before checking whether `job_slots` collide with reserved keys.

During first startup this is harmless.

During a runtime reconfiguration, a bad new configuration would:

1. remove the currently working Core binds;
2. discover the collision;
3. raise an error;
4. leave the prior valid key layout gone.

Cleaner behavior is:

1. validate the proposed configuration first;
2. if valid, unbind the previous layout;
3. apply the new layout.

This is not required to proceed, but it is cheap to correct while lifecycle/key ownership is being touched.

---

# What is now approved

After the P1 items above are fixed and `run-tests.sh` passes, I consider this first shared-Core phase approved.

Specifically, I approve the following architectural decisions:

- namespace-table Core architecture;
- shared `util/perf/events/locks/th/move/keys` ownership;
- full-load manifest approach;
- full semantic version requirement;
- lightweight default TH policy with override seam;
- namespaced authoritative movement state;
- managed movement refresh through Core self-command;
- unified keybind data model;
- WAR as the first converted proving job;
- later separation into `fal-combat.lua`, `fal-actions.lua`, and `fal-hud.lua`.

I do **not** recommend another broad rewrite of `fal-core.lua`.

---

# Direction after this cleanup

Once these remaining P1 fixes are made and the complete gate is green:

## Proceed to the next extraction phase.

Recommended next phase:

```text
fal-combat.lua
```

Start with shared/parameterized mechanisms such as:

- Haste ownership/math;
- Dual Wield calculation/selection;
- shared weapon-profile reconciliation infrastructure;
- shared Fast Cast infrastructure only where the mechanism is genuinely common.

Keep job-specific policy/configuration in the job file.

Do not move RDM into the Core architecture yet if the agreed conversion order remains WAR first and RDM last. Use WAR plus the next substantially different job to continue proving the seams.

The next extraction should follow the same rule established here:

```text
shared mechanism -> explicit job configuration/policy -> narrow job override
```

not:

```text
copy RDM behavior into Core and add job-name conditionals
```

---

# Claude action request

Please perform one short cleanup pass containing only the following:

1. make `FalCore.init()` truly idempotent by cleaning old tracked external events/binds before resetting their bookkeeping;
2. remove WAR's `FalCore.events.unregister_all()` startup ownership violation and let Core own its movement prerender event;
3. remove WAR's dead legacy `_movementrefresh` command branch;
4. repair the ineffective King's Justice regression assertion in `test_jobs.lua`;
5. add the direct Fishing + movement integration scenarios above;
6. run the complete test gate.

Also make the release/test dependency filenames explicit so the gate is reproducible.

Do **not** redesign Core again.

If that gate passes, consider the `fal-core` foundation approved and proceed directly to the next planned shared-engine extraction (`fal-combat.lua` or the equivalent agreed module) without waiting for another architecture review.
