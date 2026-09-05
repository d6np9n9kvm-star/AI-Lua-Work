# Response to the independent review of `fal-core.lua` v1.0.1

Reviewed version: **v1.0.1**. Current version: **v1.2.0**. All P0 and P1 findings are
addressed; P2 and P3 are addressed as well. Two findings were already fixed in v1.1.0,
which the reviewer did not see. Two findings turned out to describe **live bugs**, not
just risks.

## Status of every finding

| ID | Finding | Status | Notes |
|---|---|---|---|
| P0 | `require_version()` cannot detect a partial load | **Fixed** | `manifest.complete` is assigned on the last line of the file, and `require_version` additionally verifies every symbol in `MANIFEST_REQUIRED`. Two tests simulate the failure. |
| P0 | Patch version not enforced | **Fixed** | Full `major.minor.patch` comparison. `require_version('1.2.1')` against a 1.2.0 Core now fails. Six version tests. |
| P0 | Harness discards `get_sets`/`job_setup` failures | **Fixed** | `H.load` runs the real Mote order and returns `nil, '<stage>: <error>'` on any stage failure. |
| P0 | `user_setup()` not executed | **Fixed** (in v1.1.0, during the WAR conversion) | Now in the lifecycle loop. Doing this immediately exposed three real faults — see below. |
| P0 | Harness `include()` not faithful | **Fixed** (in v1.1.0) | Reproduces `include_user`'s table form: lowercase, `setmetatable`, `setfenv`, `pcall` with the error captured. |
| P0 | Tests print rather than assert | **Fixed** | New `falcheck.lua` runner. 102 assertions across three suites; any failure exits non-zero. `run-tests.sh` is the gate. |
| P1 | Mock job identity is WAR for all jobs | **Fixed** | `H.load(file, {job=...})`. RDM's resolved item count changed 139 → 138 once it loaded as RDM, confirming the finding was real. |
| P1 | Ring-release settle 1.0 → 0.6 | **Fixed** | Confirmed against provenance (`RDM.lua:6605`, `end, 1)`). Restored to 1.0 as `RING_RELEASE_SETTLE`, asserted in the suite. |
| P1 | Core calls job-global `check_gear()` | **Fixed — this was a live bug** | `check_gear` is defined **only by RDM**. WAR and BLU define none, so all three Core call sites were silently doing nothing: Core owned the ring mechanics but delegated the refresh to a global that did not exist. Replaced with `locks.refresh()` plus an `init{on_ring_refresh}` hook. |
| P1 | `keys.report()` describes unbound actions | **Fixed** | `keys.declared_row` records what was actually bound; WAR no longer advertises a magic-burst key it never binds. |
| P1 | No key collision detection | **Fixed** | A job slot colliding with a reserved universal or action-row key is now a hard error at `keys.apply`. |
| P2 | `init()` overwrites `move.kiting_allowed` | **Fixed** | Stored as `move.kiting_override`; the method is stable and a later `init` clears a previous override. |
| P2 | `refresh_queued` cleared before token check | **Fixed** | Token validated first. Asserted both ways. |
| P2 | `on_movement_change` errors swallowed | **Fixed** | Reported to chat; same for the new `th_policy` and `on_ring_refresh` callbacks. |
| P2 | TH design may not suit THF | **Fixed** | `th.default_should_apply` is now a default strategy behind an `init{th_policy}` seam. THF can supply its own without forking Core. |
| P3 | `init()` does not reset `keys.bound` as documented | **Fixed** | `init()` is now genuinely idempotent: keys, perf, TH policy and ring hook all reset. |

## Where the review's process assumption differed from what happened

The review asks that WAR not be converted until this pass is complete. The conversion had
already happened by the time the review arrived, and I would argue it was the right call:
it is what turned the `check_gear` finding from a design smell into a demonstrated live
bug, and the conversion itself surfaced three defects that no amount of reading would have
caught (a runaway deletion, a regex whose negative lookbehind for `.` also blocked Lua's
`..` operator, and gear sets accidentally coupled to Mote's hook ordering).

The reviewer's underlying point stands and is the important one: **the verification layer
was weaker than my description of it.** The conversion was checked by ad-hoc scripts I read
by eye, not by a suite that fails. That is now corrected, and WAR is re-verified under it.

## Findings that were already fixed in v1.1.0

Two P0 harness items (`user_setup` execution, faithful table-form `include`) were fixed
during the WAR conversion, before the review arrived. Turning on `user_setup` immediately
exposed three faults the old harness had been swallowing: a missing `texts` library mock, a
`S{}` set mock that returned `false` for method lookups so `myset:it()` died, and a
`classes.CustomMeleeGroups` that was a plain table with no `:clear()`. All three are fixed.

## Not adopted

Nothing was rejected. The module-split recommendation (P4: `fal-combat.lua`,
`fal-actions.lua`, `fal-hud.lua`) matches the plan already agreed with the owner, and is
the next phase.

## Test coverage against section I

Items 1-12 and 15-20 are covered by `test_core.lua`, `test_moving.lua` and `test_jobs.lua`.
Items 13-14 (Fishing + movement + one/both protected rings) are covered indirectly through
the movement-overlay and fishing-policy assertions but do not yet exercise the two
subsystems in one scenario; that is the one gap remaining and is queued for the next pass.
