-- test_moving.lua -- isolates the v1.0.0 namespace bug: an undeclared assignment inside
-- an included chunk creates a key on the namespace table, NOT on the job environment.
local H = dofile('harness.lua')
local check = dofile('falcheck.lua')

local env = H.build_env{job='WAR', player={name='F',main_job='WAR',sub_job='NIN',tp=1000,
    status='Engaged', index=1, hpp=100, main_job_level=99, sub_job_level=49,
    equipment={left_ring='Chirich Ring +1', right_ring='Chirich Ring +1'}}}
env.moving = false
local pos = {x=0, y=0, z=0}
env.windower.ffxi.get_mob_by_index = function() return {x=pos.x, y=pos.y, z=pos.z} end
env.midaction = function() return false end

local CORE = {}
setmetatable(CORE, {__index = env})
local f = assert(loadfile('fal-core.lua'))
setfenv(f, CORE)
assert(pcall(f, CORE))

local mirrored
CORE.init{job='WAR', movement_ring='Shneddick Ring',
          kiting_allowed = function() return true end,
          on_movement_change = function(m) mirrored = m ; env.moving = m end}

check.section('Movement flag ownership (regression for the v1.0.0 bug)')
CORE.move.sample()                       -- baseline
pos.x = 5 ; CORE.move.next_sample = 0    -- displace well past the threshold
CORE.move.sample()

check.eq(CORE.move.moving, true, 'Core owns the flag: move.moving flipped')
check.nilv(rawget(CORE, 'moving'), 'NO stray CORE.moving key (the v1.0.0 defect)')
check.eq(mirrored, true, 'on_movement_change fired')
check.eq(rawget(env, 'moving'), true, 'the job environment was updated through the callback')
check.eq(CORE.move.requested(), true, 'move.requested() reads the right flag')
local ov = CORE.move.overlay()
check.eq(ov and ov.ring2, 'Shneddick Ring', 'overlay produced')

check.section('Stop debounce')
pos.x = 5                                 -- no further displacement
CORE.move.next_sample = 0
CORE.move.last_motion_at = CORE.move.last_motion_at - 10   -- age past stop_debounce
CORE.move.sample()
check.eq(CORE.move.moving, false, 'movement clears after the stop debounce')
check.eq(rawget(env,'moving'), false, 'the mirror follows it down')

check.section('A raw-callback error in the job callback is reported, not swallowed')
CORE.init{job='WAR', movement_ring='Shneddick Ring',
          kiting_allowed=function() return true end,
          on_movement_change=function() error('deliberate callback failure') end}
env.chat_log = {}
CORE.move.sample()
pos.x = 40 ; CORE.move.next_sample = 0
CORE.move.sample()
local reported = false
for _, l in ipairs(env.chat_log) do
    if l:find('on_movement_change callback error') then reported = true end
end
check.ok(reported, 'the callback error is surfaced to chat')
check.eq(CORE.move.moving, true, 'a broken job callback does not break movement tracking')

check.finish('movement')
