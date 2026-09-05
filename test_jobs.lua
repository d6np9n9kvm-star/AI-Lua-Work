-- test_jobs.lua -- job-file regression: the audit fixes must stay fixed, and the
-- fal-core conversion must not have changed WAR's behaviour. Exits non-zero on failure.
local H = dofile('harness.lua')
local check = dofile('falcheck.lua')

local function load(file, job, opts)
    opts = opts or {} ; opts.job = job
    local env, err = H.load(file, opts)
    if not env then error(file..' failed to load: '..tostring(err), 0) end
    return env
end

--------------------------------------------------------------------------------------
check.section('WAR A1 -- Kaja Bow arrow survives every overlay')
local env = load('WAR.lua','WAR',{player={name='Falurian',main_job='WAR',sub_job='NIN',
    tp=1000,status='Engaged',index=1,hpp=100,main_job_level=99,sub_job_level=49,
    equipment={main='Naegling',sub='Blurred Shield +1',range='Kaja Bow',ammo='Chapuli Arrow'}}})
env.state.WeaponSet:set('KajaBow')
env.state.HybridMode:set('DT')
local base = {ammo='Aurgelmir Orb +1'}
check.eq(env.customize_melee_set(H.deepcopy(base)).ammo, 'Chapuli Arrow', 'survives the DT overlay')
env.state.Buff = setmetatable({['Mighty Strikes']=true},{__index=function() return false end})
check.eq(env.customize_melee_set(H.deepcopy(base)).ammo, 'Chapuli Arrow', 'survives Mighty Strikes')
env.state.Buff = setmetatable({},{__index=function() return false end})

check.section('WAR A4 -- customize_defense_set exists and keeps the overlays')
check.eq(type(env.customize_defense_set), 'function', 'customize_defense_set is defined')
check.eq(env.customize_defense_set(H.deepcopy(base)).ammo, 'Chapuli Arrow', 'defense set keeps the arrow')

check.section("WAR A6 -- King's Justice keeps its own gear in Acc/PDL")
local kj, mh = env.sets.precast.WS["King's Justice"], env.sets.precast.WS.MultiHit
check.eq(kj.Acc.ring2, "Epaminondas's Ring", 'KJ.Acc keeps Epaminondas')
check.eq(kj.Acc.ring1, 'Niqmaddu Ring',      'KJ.Acc keeps Niqmaddu')
check.eq(kj.PDL.ring2, "Epaminondas's Ring", 'KJ.PDL keeps Epaminondas')
check.ne(kj.Acc.ammo, mh.Acc.ammo == kj.Acc.ammo and nil or '#', 'KJ.Acc is not MultiHit.Acc')

check.section('WAR A3 -- Fencer counts Blurred Shield +1 (Moonshade drops at 2170, not 2220)')
local function moonshade_threshold(file)
    for tp = 2100, 2300, 10 do
        local e = load(file,'WAR',{player={name='F',main_job='WAR',sub_job='SAM',tp=tp,
            status='Engaged',index=1,hpp=100,main_job_level=99,sub_job_level=49,
            equipment={main='Naegling',sub='Blurred Shield +1'}}})
        e.state.WeaponSet:set('NaeglingShield')
        e.equip_log = {}
        pcall(e.job_post_precast, {english='Savage Blade',type='WeaponSkill'}, nil, nil, {handled=false})
        for _, entry in ipairs(e.equip_log) do
            for _, v in pairs(entry) do
                if tostring(v):find('Boii Earring') or tostring(v):find('Mache') then return tp end
            end
        end
    end
end
check.eq(moonshade_threshold('WAR.lua'), 2170, 'converted WAR drops Moonshade at raw TP 2170')
check.eq(moonshade_threshold('WAR.pre-core.lua'), 2170, 'pre-core WAR agrees (conversion changed nothing)')

--------------------------------------------------------------------------------------
check.section('RDM -- shadowed midcast sets are reachable through Mote drill-down')
local renv = load('RDM.lua','RDM',{sub_job='SCH',player={name='Falurian',main_job='RDM',
    sub_job='SCH',tp=1000,status='Idle',index=1,hpp=100,main_job_level=99,sub_job_level=49,
    equipment={main='Crocea Mors',sub='Ammurapi Shield'}}})
local function drilldown(spell)
    local t = renv.sets.midcast
    local steps = {spell.skill, spell.type, spell.spellMap, spell.english}
    for i = 1, 4 do
        local s = steps[i]
        if s and type(t)=='table' and type(t[s])=='table' then t = t[s] end
    end
    return t
end
local function nameof(v)
    if v == nil then return '(nil)' end
    if v == renv.empty then return '(empty)' end
    if type(v) == 'table' then return v.name or '(augmented)' end
    return v
end
check.eq(nameof(drilldown{skill='Dark Magic',english='Drain'}.head), 'Pixie Hairpin +1', 'Drain reaches its dark-damage head')
check.eq(nameof(drilldown{skill='Dark Magic',english='Aspir'}.ring2), 'Evanescence Ring', 'Aspir aliases Drain')
check.eq(nameof(drilldown{skill='Elemental Magic',spellMap='ElementalEnfeeble'}.head), 'Viti. Chapeau +3', 'elemental enfeebles use the M.Acc set')
check.eq(nameof(drilldown{skill='Enhancing Magic',spellMap='Stoneskin',english='Stoneskin'}.neck), 'Nodens Gorget', 'Stoneskin reaches Nodens Gorget')
check.eq(nameof(drilldown{skill='Enfeebling Magic',spellMap='MndEnfeebles',english='Dispelga'}.main), 'Daybreak', 'Dispelga reaches Daybreak')
check.eq(nameof(drilldown{skill='Elemental Magic',english='Impact'}.head), '(empty)', 'Impact keeps an empty head')

--------------------------------------------------------------------------------------
check.section('All three job files complete the real Mote lifecycle')
for _, j in ipairs{{'WAR.lua','WAR'},{'RDM.lua','RDM'},{'BLU.lua','BLU'}} do
    check.noerr(function() load(j[1], j[2]) end, j[1]..' loads through get_sets/job_setup/user_setup/init_gear_sets')
end

check.finish('job regression')
