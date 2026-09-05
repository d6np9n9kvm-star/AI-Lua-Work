-------------------------------------------------------------------------------------------------------------------
-- fal-core.lua -- shared job-agnostic infrastructure for the Falurian GearSwap set.
--
-- INSTALL: Windower4/addons/GearSwap/data/common/fal-core.lua
--   GearSwap's pathsearch resolves an include() in this order:
--       libs-dev/ , libs/ , data/<player.name>/ , data/common/ , data/
--   so data/common/ is searched BEFORE data/ and keeps data/ as just the job luas.
--   NOTE: include() lowercases the filename before searching, hence the lowercase name.
--
-- USAGE, from a job lua:
--       FalCore = {}
--       include('fal-core.lua', FalCore)
--       FalCore.require_version('1.2.0', 'WAR')     -- see the pcall warning below
--       FalCore.init{ job = 'WAR', movement_ring = 'Shneddick Ring' }
--
-- WHY A NAMESPACE TABLE, NOT GLOBALS:
--   GearSwap's include_user(str, tbl) does setmetatable(tbl, {__index = user_env._G})
--   and setfenv(chunk, tbl).  So everything this file defines lands in `tbl`, while
--   reads of sets / state / player / windower / disable / enable fall through to the
--   live job environment.  A job file therefore cannot silently shadow a core function,
--   which is precisely how the three original job luas drifted apart.
--
-- !! GEARSWAP SWALLOWS ERRORS IN AN INCLUDE !!
--   include_user runs the loaded chunk under pcall() and DISCARDS the error.  A runtime
--   fault in this file therefore produces no message -- just a half-populated table and
--   a confusing nil-call much later.  Always call require_version() immediately after
--   including, so a partial load fails loudly at the point of the include.
--
-- DESIGN RULE: nothing in this file may know a job's name, gear, spells or weapons.
--   Anything job-specific arrives through init() options or a registered callback.
--
-- PROVENANCE: implementations are lifted from Falurian RDM v2.62, which is the most
--   developed of the three source files.  Where WAR/BLU had diverged, RDM's version
--   wins deliberately -- see the Treasure Hunter note in the `th` section for the
--   clearest case.
--
-- CHANGELOG
--   1.2.0  Hardening pass after an independent review of v1.0.1.
--          * COMPLETE-LOAD SENTINEL: manifest.complete is assigned on the last line, and
--            require_version now also verifies every symbol in MANIFEST_REQUIRED. The old
--            guard only proved `version` existed, so a chunk that faulted after that
--            point still passed -- precisely the failure GearSwap's swallowed pcall makes
--            invisible.
--          * require_version now compares major.minor.PATCH. It previously ignored the
--            patch field while the documented call site asked for one (`'1.0.1'`), so a
--            job requesting the movement-bug fix would happily accept 1.0.0.
--          * locks.refresh() replaces three `if type(check_gear)=='function'` calls.
--            check_gear is defined ONLY by RDM, so on WAR and BLU those were dead: Core
--            owned the ring mechanics but delegated the refresh to a global that did not
--            exist. Jobs now use init{on_ring_refresh=fn}.
--          * RING_RELEASE_SETTLE restored to RDM's 1.0s (RDM.lua:6605); 1.0.0-1.1.0
--            shipped 0.6 with no justification.
--          * move.handle_refresh validates the token BEFORE clearing refresh_queued.
--          * Keybinds: job slots that collide with a reserved universal key are now a
--            hard error, and keys.report prints only the F10-F12 keys this job bound.
--          * TH gained a policy seam (init{th_policy}) so a future THF is not forced to
--            fork Core; movement stores kiting_override instead of overwriting the method.
--          * Callback errors from on_movement_change / th_policy / on_ring_refresh are
--            reported instead of swallowed. init() is now genuinely idempotent.
--   1.1.0  Added util.ring_name (handles both left_ring/right_ring and ring1/ring2 key
--          spellings -- WAR handled both, RDM assumed one) and locks.clear_fishing_rod.
--          locks.release_rings now carries WAR's reload token guard, which RDM lacked.
--   1.0.1  Fixed a live bug in 1.0.0: the movement sampler wrote a bare `moving`, which
--          under setfenv creates a key on THIS table rather than setting the job
--          environment's global -- so the flag flipped internally, kiting never engaged,
--          and no error was ever raised.  The flag is now explicitly `move.moving`, with
--          an optional `on_movement_change` callback for jobs that keep their own copy.
--          Also made move.kiting_allowed() permissive when DefenseMode is absent.
--   1.0.0  Initial extraction from RDM v2.62: util, perf, events, locks, th, move, keys.
-------------------------------------------------------------------------------------------------------------------

-- GearSwap calls this chunk as pcall(chunk, <the namespace table>), so `...` IS that
-- table. getfenv(1) is the fallback for the plain include() form.
local CORE_SELF = ... or getfenv(1)

version = '1.2.0'

-- Every symbol a job file is entitled to rely on.  MANIFEST_REQUIRED is checked by
-- require_version, so a chunk that dies halfway through cannot pass the guard.
MANIFEST_REQUIRED = {
    'version','manifest','require_version','init','unload','self_command',
    'ALL_EQUIP_SLOTS','FISHING_LOCK_SLOTS','UNIVERSAL_BINDS','ACTION_ROW',
    'util','perf','events','locks','th','move','keys',
}

local function parse_version(v)
    local a,b,c = tostring(v):match('^(%d+)%.(%d+)%.(%d+)$')
    if not a then return nil end
    return tonumber(a), tonumber(b), tonumber(c)
end

-- Guard against BOTH failure modes of GearSwap's table-form include():
--   1. the chunk faulted partway (pcall swallows the error) -> manifest.complete is nil,
--      or a module listed in MANIFEST_REQUIRED is missing;
--   2. an older Core is installed than this job needs -> version comparison.
-- `wanted` is a full x.y.z and means ">= wanted" within the same major.
function require_version(wanted, who)
    who = tostring(who or '?')

    -- (1) completeness. manifest.complete is assigned on the LAST line of this file.
    if not (manifest and manifest.complete) then
        error('fal-core: PARTIAL LOAD -- the chunk faulted before completing and GearSwap '
            ..'discarded the error. '..who..' cannot run. Check fal-core.lua for a runtime fault.', 2)
    end
    local missing = {}
    for _, sym in ipairs(MANIFEST_REQUIRED) do
        if rawget(manifest.owner or {}, sym) == nil then missing[#missing + 1] = sym end
    end
    if #missing > 0 then
        error('fal-core: INCOMPLETE LOAD -- missing '..table.concat(missing, ', ')..'. '..who..' cannot run.', 2)
    end

    -- (2) version, comparing all three components.
    local wmaj, wmin, wpat = parse_version(wanted)
    local hmaj, hmin, hpat = parse_version(version)
    if not wmaj then
        error('fal-core: '..who..' requested a malformed version ('..tostring(wanted)..'); want x.y.z', 2)
    end
    if not hmaj then
        error('fal-core: own version string is malformed ('..tostring(version)..')', 2)
    end
    local too_old = (hmaj ~= wmaj)
        or (hmin < wmin)
        or (hmin == wmin and hpat < wpat)
    if too_old then
        error(string.format('fal-core %s is loaded but %s requires >= %s (same major)',
            version, who, tostring(wanted)), 2)
    end
    return true
end

-------------------------------------------------------------------------------------------------------------------
-- Runtime + slot vocabulary
-------------------------------------------------------------------------------------------------------------------

runtime = {
    job = nil,
    unloading = false,
    token = nil,
    event_ids = {},
}

ALL_EQUIP_SLOTS = {'main','sub','range','ammo','head','neck','ear1','ear2',
                   'body','hands','ring1','ring2','back','waist','legs','feet'}

-- Fishing owns every slot EXCEPT the two rings, so a protected ring (Warp, Capacity,
-- Empress) and the movement ring keep their slot ownership while fishing.
FISHING_LOCK_SLOTS = {'main','sub','range','ammo','head','neck','ear1','ear2',
                      'body','hands','back','waist','legs','feet'}

util = {}

function util.item_name(item)
    if type(item) == 'table' then return item.name end
    return item
end

function util.chat(color, text)
    add_to_chat(color or 158, text)
end

function util.bool_word(v)
    return v and 'ON' or 'OFF'
end

-- Ring slot name, tolerating both key spellings GearSwap uses across versions
-- (left_ring/right_ring and ring1/ring2).  Lifted from WAR, which handled both;
-- RDM's ring code assumed left_ring/right_ring only.
function util.ring_name(slot)
    local eq = player and player.equipment
    if not eq then return nil end
    if slot == 'ring1' then return eq.left_ring or eq.ring1 end
    return eq.right_ring or eq.ring2
end

function util.current_target_mob()
    if not (windower and windower.ffxi and type(windower.ffxi.get_mob_by_target) == 'function') then return nil end
    local ok, mob = pcall(windower.ffxi.get_mob_by_target, 't')
    return ok and mob or nil
end

-------------------------------------------------------------------------------------------------------------------
-- Profiler
--
-- STRUCTURAL FIX (RDM audit 2.8): the old design kept a hand-maintained
-- `perf_counter_order` list separate from the perf_count() call sites, so a counter
-- could be incremented forever and never be printable -- which is exactly what happened
-- to 'engaged_defense_preserved'.  Here, count() registers a name the first time it is
-- seen, so an unprintable counter is impossible by construction.
-------------------------------------------------------------------------------------------------------------------

perf = {enabled = false, started = 0, counters = {}, timers = {}, order = {}, seen = {}}

function perf.register(name)
    if not perf.seen[name] then
        perf.seen[name] = true
        perf.order[#perf.order + 1] = name
    end
end

function perf.count(name, amount)
    if not perf.enabled then return end
    perf.register(name)
    perf.counters[name] = (perf.counters[name] or 0) + (amount or 1)
end

function perf.begin()
    if perf.enabled then return os.clock() end
end

function perf.finish(name, started)
    if not perf.enabled or not started then return end
    local elapsed = os.clock() - started
    local t = perf.timers[name]
    if not t then t = {calls = 0, total = 0, max = 0} ; perf.timers[name] = t end
    t.calls = t.calls + 1
    t.total = t.total + elapsed
    if elapsed > t.max then t.max = elapsed end
end

function perf.reset()
    perf.started = os.clock()
    perf.counters = {}
    perf.timers = {}
end

function perf.report()
    local elapsed = perf.started > 0 and math.max(0, os.clock() - perf.started) or 0
    util.chat(158, string.format('=== %s perf: %s, %.1fs sample ===',
        tostring(runtime.job or '?'), perf.enabled and 'ON' or 'OFF', elapsed))
    local parts = {}
    for _, name in ipairs(perf.order) do
        local v = perf.counters[name]
        if v then parts[#parts + 1] = name..'='..v end
    end
    util.chat(158, (#parts > 0) and table.concat(parts, ' | ') or 'Counters: no samples yet')
    local tnames = {}
    for n in pairs(perf.timers) do tnames[#tnames + 1] = n end
    table.sort(tnames)
    for _, name in ipairs(tnames) do
        local t = perf.timers[name]
        if t.calls > 0 then
            util.chat(158, string.format('%-17s %5d calls  total %.3fms  avg %.3fms  max %.3fms',
                name, t.calls, t.total * 1000, t.total * 1000 / t.calls, t.max * 1000))
        end
    end
    util.chat(158, 'Usage: gs c perf on|off|reset')
end

function perf.command(arg)
    arg = tostring(arg or ''):lower()
    if arg == 'on' then perf.enabled = true ; perf.reset()
    elseif arg == 'off' then perf.enabled = false
    elseif arg == 'reset' then perf.reset() end
    perf.report()
end

-------------------------------------------------------------------------------------------------------------------
-- Event registry
--
-- Every custom Windower event a job registers goes through track(), so unregister_all()
-- in user_unload can never miss one.  A leaked raw 'prerender' handler survives the
-- job change and keeps firing against a dead environment.
-------------------------------------------------------------------------------------------------------------------

events = {}

function events.track(id)
    if id ~= nil then runtime.event_ids[#runtime.event_ids + 1] = id end
    return id
end

function events.register(name, fn)
    if not (windower and type(windower.register_event) == 'function') then return nil end
    return events.track(windower.register_event(name, fn))
end

function events.register_raw(name, fn)
    if not (windower and type(windower.raw_register_event) == 'function') then return nil end
    return events.track(windower.raw_register_event(name, fn))
end

function events.unregister_all()
    if windower and type(windower.unregister_event) == 'function' then
        for _, id in ipairs(runtime.event_ids) do pcall(windower.unregister_event, id) end
    end
    runtime.event_ids = {}
end

-------------------------------------------------------------------------------------------------------------------
-- Gear locks: protected rings, Fishing, PauseSwaps
--
-- Ownership hierarchy, highest first:
--   PauseSwaps  -> owns every slot
--   Doom        -> owns both rings (Blenmot's/Nicander's must not be swapped off)
--   Fishing     -> owns every slot EXCEPT the rings
--   protected   -> owns a ring slot holding a no-swap ring (Warp, Capacity, Empress...)
--   normal gear -> everything else
-------------------------------------------------------------------------------------------------------------------

-- Extraction fidelity: RDM's release_ring_slots scheduled its settle at 1.0s
-- (RDM.lua:6605, `end, 1)`).  v1.0.0-1.1.0 shipped 0.6 with no justification; restored.
RING_RELEASE_SETTLE = 1.0

locks = {
    ring_state = {ring1 = nil, ring2 = nil},
    on_ring_refresh = nil,
    releasing  = {ring1 = false, ring2 = false},
    no_swap    = nil,   -- set by init()
}

DEFAULT_NO_SWAP_RINGS = {
    'Warp Ring', 'Dim. Ring (Dem)', 'Dim. Ring (Holla)', 'Dim. Ring (Mea)',
    'Trizek Ring', 'Echad Ring', 'Facility Ring', 'Capacity Ring',
    'Jubilee Ring', 'Empress Band',
}

function locks.pause_active()
    return (state and state.PauseSwaps and state.PauseSwaps.value == true) or false
end

function locks.fishing_active()
    return (state and state.FishingMode and state.FishingMode.value == true) or false
end

function locks.frozen()
    return locks.pause_active() or locks.fishing_active()
end

function locks.is_no_swap(name)
    if not (locks.no_swap and name) then return false end
    return locks.no_swap[name] == true
end

function locks.invalidate_ring_cache()
    locks.ring_state.ring1 = nil
    locks.ring_state.ring2 = nil
end

-- Deduplicated enable/disable for one ring slot.
function locks.apply_ring(slot, should_lock)
    if locks.ring_state[slot] == should_lock then
        perf.count('ring_lock_hits')
        return
    end
    if should_lock then disable(slot) else enable(slot) end
    locks.ring_state[slot] = should_lock
    perf.count('ring_lock_changes')
end

-- Pause and Doom own both rings outright. Call locks.refresh(), not this, from a job.
function locks.check_rings()
    if locks.pause_active() then return end
    if buffactive and buffactive.doom then return end
    if not (player and player.equipment) then return end
    locks.apply_ring('ring1', locks.is_no_swap(util.ring_name('ring1')) and not locks.releasing.ring1)
    locks.apply_ring('ring2', locks.is_no_swap(util.ring_name('ring2')) and not locks.releasing.ring2)
end

-- Core's own ring-policy entry point.  v1.2.0 replaced three `if type(check_gear)==
-- 'function' then check_gear() end` calls with this: `check_gear` is defined ONLY by
-- RDM, so on WAR and BLU those calls were silently doing nothing -- Core owned the ring
-- mechanics but delegated the refresh back to a job global that did not exist.
-- A job needing extra work on a ring refresh sets init{on_ring_refresh=fn} instead of
-- being required to define a specially-named global.
function locks.refresh()
    locks.check_rings()
    if type(locks.on_ring_refresh) == 'function' then
        local ok, err = pcall(locks.on_ring_refresh)
        if not ok then
            util.chat(123, '[fal-core] on_ring_refresh callback error: '..tostring(err))
        end
    end
end

function locks.ring_protected(slot)
    return locks.is_no_swap(util.ring_name(slot))
end

-- Fishing hands the range slot to the rod; this returns it.
function locks.clear_fishing_rod()
    enable('range')
    equip({range = empty})
end

-- Temporarily release protected ring slots so normal gear can flow back in.
function locks.release_rings(slots, reason, settle)
    local any = false
    for _, s in ipairs(slots) do
        locks.releasing[s] = true
        enable(s)
        locks.ring_state[s] = false
        any = true
    end
    if not any then return end
    if reason then util.chat(158, '** [no-swap ring released: '..reason..'] **') end
    if type(handle_equipping_gear) == 'function' then handle_equipping_gear(player.status) end
    -- The token guard is WAR's, not RDM's: without it a settle scheduled before a
    -- //gs reload fires against the NEXT load and clears a release flag that the new
    -- environment never set.  runtime.unloading alone does not cover that case.
    local token = runtime.token
    coroutine.schedule(function()
        if runtime.unloading or token ~= runtime.token then return end
        for _, s in ipairs(slots) do locks.releasing[s] = false end
        locks.invalidate_ring_cache()
        locks.refresh()
    end, settle or RING_RELEASE_SETTLE)
end

function locks.apply_fishing_policy()
    if locks.pause_active() then
        disable(unpack(ALL_EQUIP_SLOTS))
        return
    end
    if not locks.fishing_active() then return end
    disable(unpack(FISHING_LOCK_SLOTS))
    if buffactive and buffactive.doom then
        disable('ring1', 'ring2')
        return
    end
    enable('ring1', 'ring2')
    -- A prior full Pause/Fishing lock may have left the rings disabled while the cached
    -- policy still says enabled.  Reopen, then force an immediate re-lock of any real
    -- protected ring.
    locks.invalidate_ring_cache()
    locks.refresh()
end

function locks.reapply()
    if locks.pause_active() or locks.fishing_active() then
        locks.apply_fishing_policy()
    else
        enable(unpack(ALL_EQUIP_SLOTS))
        locks.invalidate_ring_cache()
        locks.refresh()
    end
end

-------------------------------------------------------------------------------------------------------------------
-- Treasure Hunter
--
-- RDM retired the Mote-TreasureHunter plugin in 2026-07 and WAR/BLU never followed.
-- Its two reasons, preserved here because they are the reason this module is four lines
-- instead of a mob tracker:
--   1. It never worked on a non-THF job: only 'None'/'Tag' options are offered, so the
--      'Fulltime' branch was unreachable, and 'Tag' equips TH only while ENGAGED --
--      tagging with a spell from range wore no TH gear at all.
--   2. It registers FIVE windower events including raw 'action' (fires for every action
--      by anyone in range, walking a mob table each time) and raw 'incoming chunk'
--      (every packet) -- the per-event dispatch class that caused the SMN stutter.
--
-- Replacement: a plain ON/OFF state toggle that layers sets.TreasureHunter into engaged
-- sets and hostile-spell midcasts.  No mob tracking, ZERO event handlers.
-------------------------------------------------------------------------------------------------------------------

th = {policy = nil}

function th.active()
    return (state and state.TreasureHunter and state.TreasureHunter.value == true) or false
end

-- Default strategy: TH gear is layered whenever the toggle is on and the action is
-- hostile.  `spell` may be nil, meaning melee.
function th.default_should_apply(spell)
    if not th.active() then return false end
    if spell == nil then return true end
    return spell.target ~= nil and spell.target.type == 'MONSTER'
end

-- v1.2.0 policy seam.  The ON/OFF model above is right for every job that merely wants
-- TH+n layered (RDM, WAR, BLU).  THF is different -- it has real TH tiers, Feint/SA/TA
-- interactions and a reason to care which mob has already been tagged -- so a job can
-- install its own strategy with init{th_policy=fn} rather than forking Core.
function th.should_apply(spell)
    if type(th.policy) == 'function' then
        local ok, result = pcall(th.policy, spell)
        if ok then return result == true end
        util.chat(123, '[fal-core] th_policy callback error: '..tostring(result))
    end
    return th.default_should_apply(spell)
end

-------------------------------------------------------------------------------------------------------------------
-- Native movement sampling
--
-- Samples the player's own position on the raw prerender clock instead of registering a
-- position/status event per movement change.  NEVER calls equip() from the raw callback:
-- a transition is queued back through a managed `gs c` self-command so GearSwap's equip
-- queue is flushed on a normal event boundary.
-------------------------------------------------------------------------------------------------------------------

-- !! `move.moving` is the authority, NOT a bare `moving` global. !!
--   The lib's chunk environment IS the namespace table, so an undeclared assignment in
--   here (`moving = true`) creates CORE.moving and does NOT write the job environment's
--   `moving` that the original files maintained.  v1.0.0 had exactly that bug: the flag
--   flipped inside the table while the job's global stayed false, so kiting never engaged
--   and no error was ever raised.  Keeping the flag explicitly namespaced makes the
--   mistake unrepresentable.  Job files ask `FalCore.move.requested()`; if a job still
--   wants a bare `moving` global for its own code, it assigns it from `move.moving`.
move = {
    moving           = false,
    sample_interval  = 0.15,
    stop_debounce    = 0.45,
    distance_squared = 0.01,   -- 0.1 yalms between samples
    next_sample      = 0,
    last_motion_at   = 0,
    x = nil, y = nil, z = nil,
    refresh_pending  = false,
    refresh_queued   = false,
    ring_name        = nil,    -- set by init()
    on_change        = nil,    -- optional job callback: function(is_moving)
}

-- v1.2.0: init() stores an override in move.kiting_override instead of overwriting this
-- method, so the module's own function stays stable and a re-init cannot leave a
-- previous job's closure installed.
-- Default mirrors RDM: kite only while no defensive set owns the gear. WAR overrides it
-- to always-true because it applies the movement overlay inside customize_defense_set.
function move.kiting_allowed()
    if type(move.kiting_override) == 'function' then return move.kiting_override() == true end
    if not (state and state.DefenseMode) then return true end
    return state.DefenseMode.value == 'None'
end

function move.check()
    if not (state and state.Auto_Kite) then return end
    local wanted = (move.moving == true) and move.kiting_allowed()
    if state.Auto_Kite.value ~= wanted then state.Auto_Kite:set(wanted) end
end

function move.queue_refresh()
    if runtime.unloading or move.refresh_queued then return end
    move.refresh_queued = true
    send_command('gs c _falmovementrefresh '..tostring(runtime.token))
end

-- Consume the queued refresh. The job routes `gs c _falmovementrefresh <token>` here.
-- v1.2.0: validate the token BEFORE mutating queue bookkeeping.  Clearing
-- refresh_queued first meant a self-command left over from a previous load could drop
-- the flag for the current one, so a genuinely queued refresh would never be re-queued.
function move.handle_refresh(token)
    if tostring(token) ~= tostring(runtime.token) then return false end
    move.refresh_queued = false
    if not move.refresh_pending then return false end
    move.refresh_pending = false
    return true
end

function move.sample()
    if runtime.unloading then return end

    local now = os.clock()
    if now < move.next_sample then return end
    move.next_sample = now + move.sample_interval

    if not (player and player.index and windower and windower.ffxi
        and type(windower.ffxi.get_mob_by_index) == 'function') then return end

    local mob = windower.ffxi.get_mob_by_index(player.index)
    if not (mob and mob.x and mob.y and mob.z) then
        move.x, move.y, move.z = nil, nil, nil
        return
    end

    local ox, oy, oz = move.x, move.y, move.z
    move.x, move.y, move.z = mob.x, mob.y, mob.z

    -- The first valid sample establishes a baseline and never guesses movement.
    if ox == nil or oy == nil or oz == nil then
        move.last_motion_at = now
        return
    end

    local dx, dy, dz = mob.x - ox, mob.y - oy, mob.z - oz
    local displaced = (dx*dx + dy*dy + dz*dz) > move.distance_squared
    local new_moving = move.moving

    if displaced then
        move.last_motion_at = now
        new_moving = true
    elseif move.moving and (now - move.last_motion_at) >= move.stop_debounce then
        new_moving = false
    end

    if new_moving ~= move.moving then
        move.moving = new_moving
        move.refresh_pending = true
        -- Mirror into whatever the job wants to keep in sync (a bare `moving` global,
        -- a HUD field). Core cannot write the job's globals directly -- see the note
        -- on the `move` table above.
        if type(move.on_change) == 'function' then
            local ok, err = pcall(move.on_change, new_moving)
            if not ok then
                util.chat(123, '[fal-core] on_movement_change callback error: '..tostring(err))
            end
        end
    end

    -- A transition during a spell / full Pause / Doom waits here until that owner
    -- clears.  Fishing is deliberately allowed through: its non-ring slots stay
    -- disabled while the managed refresh updates only the live rings.
    if move.refresh_pending and state and state.Auto_Kite
        and not locks.pause_active()
        and not (buffactive and buffactive.doom)
        and (type(midaction) ~= 'function' or not midaction()) then
        move.check()
        move.queue_refresh()
    end
end

function move.requested()
    return move.moving == true and move.kiting_allowed()
end

-- Which ring slot the movement ring may occupy, respecting protected rings.
function move.ring_slot()
    if locks.ring_protected('ring2') then
        if not locks.ring_protected('ring1') then return 'ring1' end
        return nil
    end
    return 'ring2'
end

-- Overlay table for the movement ring, or nil when it cannot be worn.
function move.overlay()
    if not move.requested() then return nil end
    if locks.pause_active() then return nil end
    if buffactive and buffactive.doom then return nil end
    local slot = move.ring_slot()
    if not (slot and move.ring_name) then return nil end
    return {[slot] = move.ring_name}
end

-------------------------------------------------------------------------------------------------------------------
-- Keybinds
--
-- The layout is DATA, not code.  Eight slots were already byte-identical across the
-- three original job luas; the rest were one intent wearing three names
-- (rdmweapon/warweapon/bluweapon, toggle TreasureHunter vs cycle TreasureMode).
--
-- STRUCTURAL FIX: bind() records exactly what it bound, and unbind_all() unbinds exactly
-- that.  The old files kept a hand-written unbind list in user_unload that drifted from
-- the bind list, leaving stale keys pointing at a dead job.
--
-- SLOT MAP
--   Universal action row (Core binds these only if the job declares it implements them):
--     F10   gs c magicburst   one-shot: burst the live skillchain with the best spell
--     F11   gs c skillchain   one-shot: close the live skillchain with the best WS
--     F12   gs c bestws       one-shot: best weapon skill for the equipped weapon
--   Universal modes/toggles (always bound):
--     Ctrl+F1  OffenseMode      Ctrl+F2  HybridMode      Ctrl+F3  defense next
--     Ctrl+F7  IdleMode         Ctrl+F9/F10 weapon prev/next
--     Ctrl+F11 WeaponLock       Ctrl+F12 sm all toggle
--     Alt+F1 TreasureHunter     Alt+F2 FishingMode       Alt+F3 PauseSwaps
--     Alt+F9 hudlock            Alt+F10 hud
--   Job slots (declared per job):  Ctrl+F4, Ctrl+F5, Ctrl+F6
-------------------------------------------------------------------------------------------------------------------

keys = {bound = {}, declared_row = {}, reserved = {}}

UNIVERSAL_BINDS = {
    {'^f1',  'gs c cycle OffenseMode'},
    {'^f2',  'gs c cycle HybridMode'},
    {'^f3',  'gs c defense next'},
    {'^f7',  'gs c cycle IdleMode'},
    {'^f9',  'gs c weapon previous'},
    {'^f10', 'gs c weapon next'},
    {'^f11', 'gs c toggle WeaponLock'},
    {'^f12', 'sm all toggle'},
    {'!f1',  'gs c toggle TreasureHunter'},
    {'!f2',  'gs c toggle FishingMode'},
    {'!f3',  'gs c toggle PauseSwaps'},
    {'!f9',  'gs c hudlock'},
    {'!f10', 'gs c hud'},
}

-- The universal action row. A job opts in per key via init{ action_row = {...} }.
ACTION_ROW = {
    magicburst = {'f10', 'gs c magicburst'},
    skillchain = {'f11', 'gs c skillchain'},
    bestws     = {'f12', 'gs c bestws'},
}

function keys.bind(key, command)
    send_command('bind '..key..' '..command)
    keys.bound[#keys.bound + 1] = key
end

-- Which universal keys a job slot may never claim.
local function reserved_keys()
    local r = {}
    for _, b in ipairs(UNIVERSAL_BINDS) do r[b[1]] = b[2] end
    for _, row in pairs(ACTION_ROW) do r[row[1]] = row[2] end
    return r
end

function keys.unbind_all()
    for _, key in ipairs(keys.bound) do send_command('unbind '..key) end
    keys.bound = {}
end

-- opts.action_row : list of 'magicburst' / 'skillchain' / 'bestws' this job implements
-- opts.job_slots  : { ['^f4'] = 'gs c cycle CastingMode', ... }
function keys.apply(opts)
    opts = opts or {}
    keys.unbind_all()
    keys.reserved = reserved_keys()
    keys.declared_row = {}

    -- v1.2.0: a job slot silently overwriting a universal key is a configuration error,
    -- not something to discover in game. Reject it loudly before binding anything.
    local collisions = {}
    for key in pairs(opts.job_slots or {}) do
        if keys.reserved[key] then
            collisions[#collisions + 1] = key..' (reserved for: '..keys.reserved[key]..')'
        end
    end
    if #collisions > 0 then
        error('fal-core keys: job slot collides with a reserved universal key -> '
            ..table.concat(collisions, '; '), 2)
    end

    for _, b in ipairs(UNIVERSAL_BINDS) do keys.bind(b[1], b[2]) end
    for _, name in ipairs(opts.action_row or {}) do
        local row = ACTION_ROW[name]
        if row then
            keys.bind(row[1], row[2])
            keys.declared_row[name] = row
        else
            util.chat(123, '[fal-core keys] unknown action_row entry: '..tostring(name))
        end
    end
    for key, cmd in pairs(opts.job_slots or {}) do keys.bind(key, cmd) end
end

local ROW_LABEL = {magicburst='magic burst', skillchain='close skillchain', bestws='best weapon skill'}

-- v1.2.0: report only what this job actually bound.  The old version printed the whole
-- F10-F12 row unconditionally, so WAR advertised a magic-burst key it never binds.
function keys.report(compact)
    util.chat(158, string.format('=== %s keybinds (fal-core %s) ===', tostring(runtime.job or '?'), version))
    util.chat(158, ' Ctrl: F1 offense | F2 hybrid | F3 defense | F7 idle | F9/F10 weapon | F11 lock | F12 sm')
    util.chat(158, ' Alt:  F1 TH | F2 fishing | F3 pause | F9 hudlock | F10 hud')
    local row = {}
    for name, def in pairs(keys.declared_row) do
        row[#row + 1] = def[1]:upper()..' '..(ROW_LABEL[name] or name)
    end
    table.sort(row)
    util.chat(158, (#row > 0) and (' Row:  '..table.concat(row, ' | '))
        or ' Row:  (this job binds none of F10-F12)')
    if not compact then
        util.chat(158, ' Typed: gs c keys | gs c perf on|off|reset | gs c coreversion')
    end
end

-------------------------------------------------------------------------------------------------------------------
-- Lifecycle
-------------------------------------------------------------------------------------------------------------------

-- opts.job            : 'WAR' etc, for chat prefixes only
-- opts.movement_ring  : item name of the kiting ring, or nil to disable movement gear
-- opts.no_swap_rings  : list of protected ring names (defaults to DEFAULT_NO_SWAP_RINGS)
-- opts.kiting_allowed : function() -> boolean, overrides the default DefenseMode rule
-- opts.on_movement_change : function(is_moving), called when the movement flag flips
-- opts.on_ring_refresh : function(), extra work after Core re-checks the ring policy
-- opts.th_policy      : function(spell) -> boolean, replaces the default TH strategy
function init(opts)
    opts = opts or {}
    runtime.job = opts.job
    runtime.unloading = false
    runtime.token = tostring(os.time())..'-'..tostring(math.floor(os.clock() * 1000000))
    runtime.event_ids = {}

    -- init() is deliberately idempotent: every mutable field below is reset, so a second
    -- init (or a reload that somehow reuses this table) cannot inherit stale state.
    keys.bound = {}
    keys.declared_row = {}
    keys.reserved = {}
    perf.counters, perf.timers, perf.order, perf.seen = {}, {}, {}, {}
    perf.started = 0
    th.policy = (type(opts.th_policy) == 'function') and opts.th_policy or nil
    locks.on_ring_refresh = (type(opts.on_ring_refresh) == 'function') and opts.on_ring_refresh or nil

    local ns = {}
    for _, name in ipairs(opts.no_swap_rings or DEFAULT_NO_SWAP_RINGS) do ns[name] = true end
    locks.no_swap = ns
    locks.invalidate_ring_cache()
    locks.releasing.ring1, locks.releasing.ring2 = false, false

    move.ring_name = opts.movement_ring
    move.moving = false
    move.on_change = opts.on_movement_change
    move.next_sample, move.last_motion_at = 0, 0
    move.x, move.y, move.z = nil, nil, nil
    move.refresh_pending, move.refresh_queued = false, false
    move.kiting_override = (type(opts.kiting_allowed) == 'function') and opts.kiting_allowed or nil

    if opts.movement_ring then
        events.register_raw('prerender', move.sample)
    end
    return runtime.token
end

function unload()
    runtime.unloading = true
    keys.unbind_all()
    events.unregister_all()
    if type(enable) == 'function' then pcall(enable, unpack(ALL_EQUIP_SLOTS)) end
end

-- Shared self-command handling. Returns true if Core consumed the command.
-- A job's job_self_command should call this FIRST and return early when it returns true.
function self_command(cmdParams, eventArgs)
    local cmd = tostring(cmdParams[1] or ''):lower()
    if cmd == '_falmovementrefresh' then
        if move.handle_refresh(cmdParams[2]) and type(handle_equipping_gear) == 'function' then
            handle_equipping_gear(player.status)
        end
        eventArgs.handled = true
        return true
    elseif cmd == 'perf' then
        perf.command(cmdParams[2])
        eventArgs.handled = true
        return true
    elseif cmd == 'keys' then
        keys.report(false)
        eventArgs.handled = true
        return true
    elseif cmd == 'coreversion' then
        util.chat(158, 'fal-core '..version..' loaded for '..tostring(runtime.job or '?'))
        eventArgs.handled = true
        return true
    end
    return false
end

-------------------------------------------------------------------------------------------------------------------
-- COMPLETE-LOAD SENTINEL -- MUST REMAIN THE LAST STATEMENT IN THIS FILE.
--
-- GearSwap's include_user() runs this chunk under pcall() and DISCARDS the error, so a
-- runtime fault anywhere above produces no message at all -- just a half-populated table
-- and a confusing nil-call much later.  require_version() refuses to pass unless
-- manifest.complete is set here AND every symbol in MANIFEST_REQUIRED is present, so a
-- partial load fails loudly at the include site instead of silently at 3am in Odyssey.
--
-- `owner` is this namespace table itself, captured so require_version can introspect the
-- symbols actually defined rather than trusting that it got far enough to define them.
-------------------------------------------------------------------------------------------------------------------

manifest = {complete = true, version = version, owner = CORE_SELF}
