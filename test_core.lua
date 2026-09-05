-- test_core.lua -- fal-core.lua contract tests.  Every invariant is an assertion;
-- the process exits non-zero if any fails.  Run: lua5.1 test_core.lua
local H = dofile('harness.lua')
local check = dofile('falcheck.lua')

-- Load Core exactly the way GearSwap's include_user(str, tbl) does:
--   setmetatable(tbl, {__index = user_env._G}); setfenv(chunk, tbl); pcall(chunk, tbl)
local function load_core(env, source)
    local CORE = {}
    setmetatable(CORE, {__index = env})
    local f = assert(loadfile(source or 'fal-core.lua'))
    setfenv(f, CORE)
    local ok, err = pcall(f, CORE)
    return CORE, ok, err
end

local function fresh_env(opts)
    opts = opts or {}
    opts.player = opts.player or {name='Falurian', main_job='WAR', sub_job='NIN', tp=1000,
        status='Engaged', index=1, hpp=100, main_job_level=99, sub_job_level=49,
        equipment = opts.equipment or {left_ring='Warp Ring', right_ring='Chirich Ring +1'}}
    return H.build_env(opts)
end

--------------------------------------------------------------------------------------
check.section('1. Load contract under GearSwap include(file, table) semantics')
local env = fresh_env()
local CORE, ok, err = load_core(env)
check.ok(ok, 'chunk runs without error'..(ok and '' or (': '..tostring(err))))
check.eq(CORE.version, '1.2.0', 'version is 1.2.0')
check.ok(CORE.manifest and CORE.manifest.complete, 'manifest.complete set (sentinel reached)')
check.eq(CORE.manifest.owner, CORE, 'manifest.owner is the namespace table itself')

--------------------------------------------------------------------------------------
check.section('2. Namespace boundary: nothing leaks into the job environment')
for _, sym in ipairs(CORE.MANIFEST_REQUIRED) do
    check.nilv(rawget(env, sym), 'job env has no leaked `'..sym..'`')
end

--------------------------------------------------------------------------------------
check.section('3. Partial load is detected (the swallowed-pcall failure mode)')
-- Simulate a chunk that dies after defining `version` and `require_version` but before
-- the sentinel: this is exactly what GearSwap hides, and what v1.0.x could not detect.
-- NOTE: each case loads its OWN Core copy. require_version is a closure over the chunk
-- environment, so setfenv-ing a shared function object would repoint the real Core's
-- guard at the crippled table and corrupt every later test.
local partial = load_core(fresh_env())
partial.manifest = nil                      -- as if the chunk died before the sentinel
check.err(function() partial.require_version('1.2.0', 'WAR') end,
    'PARTIAL LOAD', 'require_version rejects a chunk that never reached the sentinel')

local missing = load_core(fresh_env())
missing.keys = nil                          -- as if the chunk died mid-file
check.err(function() missing.require_version('1.2.0', 'WAR') end,
    'INCOMPLETE LOAD', 'require_version rejects a load missing a required module')

--------------------------------------------------------------------------------------
check.section('4. Version comparison honours the patch field')
check.noerr(function() CORE.require_version('1.2.0', 'WAR') end, '1.2.0 accepts 1.2.0')
check.noerr(function() CORE.require_version('1.1.9', 'WAR') end, '1.2.0 accepts a lower request')
check.err(function() CORE.require_version('1.2.1', 'WAR') end, 'requires',
    '1.2.0 REJECTS 1.2.1 (patch is enforced, not ignored)')
check.err(function() CORE.require_version('1.3.0', 'WAR') end, 'requires', '1.2.0 rejects 1.3.0')
check.err(function() CORE.require_version('2.0.0', 'WAR') end, 'requires', '1.2.0 rejects 2.0.0')
check.err(function() CORE.require_version('1.2', 'WAR') end, 'malformed', 'rejects a malformed request')

--------------------------------------------------------------------------------------
check.section('5. Keybinds: tracked, balanced, capability-aware, collision-checked')
local cmds = {}
env.send_command = function(c) cmds[#cmds+1] = c end
CORE.init{job='WAR', movement_ring='Shneddick Ring'}
CORE.keys.apply{action_row = {'skillchain','bestws'},
                job_slots  = {['^f4']='gs c cycle WeaponskillMode', ['^f5']='gs c toggle BerserkAuto'}}
local binds = 0
for _, c in ipairs(cmds) do if c:match('^bind ') then binds = binds + 1 end end
check.eq(binds, #CORE.keys.bound, 'every issued bind is tracked')
check.eq(binds, #CORE.UNIVERSAL_BINDS + 2 + 2, 'universal + 2 action-row + 2 job slots')
cmds = {}
CORE.keys.unbind_all()
local unbinds = 0
for _, c in ipairs(cmds) do if c:match('^unbind ') then unbinds = unbinds + 1 end end
check.eq(unbinds, binds, 'unbind_all covers exactly what bind issued')
check.eq(#CORE.keys.bound, 0, 'bound list emptied')

-- Capability-aware reporting: WAR binds no magicburst, so it must not advertise one.
CORE.keys.apply{action_row = {'skillchain','bestws'}, job_slots = {}}
env.chat_log = {}
CORE.keys.report(true)
local row_line = ''
for _, l in ipairs(env.chat_log) do if l:find('Row:') then row_line = l end end
check.ok(row_line:find('F11'), 'report mentions F11 (bound)')
check.ok(row_line:find('F12'), 'report mentions F12 (bound)')
check.ok(not row_line:find('F10'), 'report does NOT mention F10 (this job never binds it)')

-- A job slot may not silently steal a reserved universal key.
check.err(function()
    CORE.keys.apply{action_row = {}, job_slots = {['^f1'] = 'gs c something'}}
end, 'reserved', 'job slot colliding with Ctrl+F1 is rejected')
check.err(function()
    CORE.keys.apply{action_row = {}, job_slots = {['f11'] = 'gs c something'}}
end, 'reserved', 'job slot colliding with the F11 action row is rejected')

--------------------------------------------------------------------------------------
check.section('6. Gear locks: protected rings, Fishing, Pause, Doom')
local disabled = {}
env.disable = function(...) for _, s in ipairs({...}) do disabled[s] = true end end
env.enable  = function(...) for _, s in ipairs({...}) do disabled[s] = false end end
CORE.init{job='WAR', movement_ring='Shneddick Ring'}

env.player.equipment = {left_ring='Warp Ring', right_ring='Chirich Ring +1'}
CORE.locks.check_rings()
check.eq(disabled.ring1, true,  'Warp Ring locks ring1')
check.ne(disabled.ring2, true,  'Chirich Ring +1 does not lock ring2')

-- Core must not depend on a job-global check_gear. That global is defined ONLY by RDM,
-- so on WAR and BLU the v1.1.0 call sites were silently dead.
check.nilv(rawget(env, 'check_gear'), 'harness provides no check_gear (it is not a Mote global)')
check.noerr(function() CORE.locks.refresh() end, 'locks.refresh works with no job check_gear')
local hook_ran = false
CORE.init{job='WAR', movement_ring='Shneddick Ring', on_ring_refresh=function() hook_ran = true end}
CORE.locks.refresh()
check.ok(hook_ran, 'on_ring_refresh job hook is invoked')

-- Fishing owns everything except the rings.
disabled = {}
env.state.FishingMode:set(true)
CORE.locks.apply_fishing_policy()
check.eq(disabled.head, true,  'Fishing disables head')
check.eq(disabled.body, true,  'Fishing disables body')
check.ne(disabled.ring2, true, 'Fishing leaves ring2 live')

-- Doom while Fishing takes both rings.
disabled = {}
env.buffactive = setmetatable({doom=true}, {__index=function() return false end})
CORE.locks.apply_fishing_policy()
check.eq(disabled.ring1, true, 'Doom while Fishing disables ring1')
check.eq(disabled.ring2, true, 'Doom while Fishing disables ring2')
env.buffactive = setmetatable({}, {__index=function() return false end})

-- Pause outranks Fishing and owns every slot.
disabled = {}
env.state.PauseSwaps:set(true)
CORE.locks.apply_fishing_policy()
for _, s in ipairs(CORE.ALL_EQUIP_SLOTS) do
    if disabled[s] ~= true then check.eq(disabled[s], true, 'Pause disables '..s) end
end
check.eq(disabled.ring1, true, 'Pause disables ring1 (outranks Fishing)')

-- Leaving Pause back into Fishing restores the Fishing policy.
disabled = {}
env.state.PauseSwaps:set(false)
CORE.locks.apply_fishing_policy()
check.ne(disabled.ring2, true, 'leaving Pause into Fishing re-opens ring2')
env.state.FishingMode:set(false)

check.eq(CORE.RING_RELEASE_SETTLE, 1.0, 'ring release settle matches RDM provenance (1.0s)')

--------------------------------------------------------------------------------------
check.section('7. Movement: flag ownership, ring fallback, token discipline')
CORE.init{job='WAR', movement_ring='Shneddick Ring', kiting_allowed=function() return true end}
check.eq(rawget(CORE, 'moving'), nil, 'no stray CORE.moving (the v1.0.0 bug)')
CORE.move.moving = true

env.player.equipment = {left_ring='Chirich Ring +1', right_ring='Chirich Ring +1'}
local ov = CORE.move.overlay()
check.eq(ov and ov.ring2, 'Shneddick Ring', 'movement ring prefers ring2')

env.player.equipment = {left_ring='Chirich Ring +1', right_ring='Capacity Ring'}
ov = CORE.move.overlay()
check.eq(ov and ov.ring1, 'Shneddick Ring', 'falls back to ring1 when ring2 is protected')

env.player.equipment = {left_ring='Warp Ring', right_ring='Capacity Ring'}
check.nilv(CORE.move.overlay(), 'no overlay when both rings are protected')

env.player.equipment = {left_ring='Chirich Ring +1', right_ring='Chirich Ring +1'}
env.buffactive = setmetatable({doom=true}, {__index=function() return false end})
check.nilv(CORE.move.overlay(), 'no overlay while doomed')
env.buffactive = setmetatable({}, {__index=function() return false end})

env.state.PauseSwaps:set(true)
check.nilv(CORE.move.overlay(), 'no overlay while swaps are paused')
env.state.PauseSwaps:set(false)

-- A stale token must not consume the queued flag.
CORE.move.refresh_queued, CORE.move.refresh_pending = true, true
check.eq(CORE.move.handle_refresh('not-the-token'), false, 'stale token refresh returns false')
check.eq(CORE.move.refresh_queued, true, 'stale token did NOT clear refresh_queued')
check.eq(CORE.move.handle_refresh(CORE.runtime.token), true, 'current token consumes the refresh')
check.eq(CORE.move.refresh_queued, false, 'current token cleared refresh_queued')

-- kiting override is stored, not installed over the method.
CORE.init{job='RDM', movement_ring='Shneddick Ring'}
check.nilv(CORE.move.kiting_override, 'a later init without an override clears the previous one')

--------------------------------------------------------------------------------------
check.section('8. Treasure Hunter: default strategy plus a policy seam')
CORE.init{job='WAR', movement_ring='Shneddick Ring'}
env.state.TreasureHunter = env.M(false)
check.eq(CORE.th.should_apply(nil), false, 'TH off: melee does not apply')
env.state.TreasureHunter:set(true)
check.eq(CORE.th.should_apply(nil), true, 'TH on: melee applies')
check.eq(CORE.th.should_apply({target={type='MONSTER'}}), true, 'TH on: hostile spell applies')
check.eq(CORE.th.should_apply({target={type='SELF'}}), false, 'TH on: self-targeted does not apply')
check.eq(CORE.th.should_apply({}), false, 'TH on: spell with no target does not apply')

CORE.init{job='THF', movement_ring='Shneddick Ring', th_policy=function() return false end}
env.state.TreasureHunter:set(true)
check.eq(CORE.th.should_apply(nil), false, 'a job th_policy overrides the default strategy')

--------------------------------------------------------------------------------------
check.section('9. Profiler: no counter can be unprintable')
CORE.perf.enabled = true
CORE.perf.reset()
CORE.perf.count('a_counter_declared_nowhere')
env.chat_log = {}
CORE.perf.report()
local printed = false
for _, l in ipairs(env.chat_log) do
    if l:find('a_counter_declared_nowhere=1') then printed = true end
end
check.ok(printed, 'an unregistered counter still prints (RDM audit 2.8 impossible)')

--------------------------------------------------------------------------------------
check.section('10. Unload: every tracked event and bind is released')
local unregistered, cmds2 = {}, {}
env.windower.unregister_event = function(id) unregistered[#unregistered+1] = id end
env.send_command = function(c) cmds2[#cmds2+1] = c end
local n = 0
env.windower.register_event = function() n = n + 1 ; return n end
env.windower.raw_register_event = function() n = n + 1 ; return n end
CORE.init{job='WAR', movement_ring='Shneddick Ring'}
CORE.events.register('zone change', function() end)
CORE.keys.apply{action_row={'skillchain'}, job_slots={}}
local tracked, bound = #CORE.runtime.event_ids, #CORE.keys.bound
cmds2 = {}
local enabled_all = false
env.enable = function(...) if select('#', ...) >= 16 then enabled_all = true end end
CORE.unload()
check.eq(#unregistered, tracked, 'unload unregisters every tracked event')
local u = 0
for _, c in ipairs(cmds2) do if c:match('^unbind ') then u = u + 1 end end
check.eq(u, bound, 'unload unbinds every bound key')
check.ok(enabled_all, 'unload re-enables all equipment slots')
check.eq(CORE.runtime.unloading, true, 'runtime marked as unloading')

check.finish('fal-core v1.2.0 contract')
