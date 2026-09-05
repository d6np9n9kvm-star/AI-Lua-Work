-- Original framework: Motenten / community patterns: Kinematics, Arislan, Mote
-- Falurian THF GearSwap v1.00
-- Built from the Falurian RDM v2.16 core, adapted for native THF systems.
-- Community references reviewed 2026-08-02:
--   github.com/Kinematics/GearSwap-Jobs/blob/master/THF.lua
--   github.com/ArislanShiva/luas/blob/master/Arislan-THF.lua
--   github.com/AlanWarren/gearswap/blob/master/THF.lua
--   github.com/Kinematics/Mote-libs/blob/master/Mote-TreasureHunter.lua
local THF_RELEASE_VERSION = '1.00'
local THF_RELEASE_DATE = '2026-08-02'

-------------------------------------------------------------------------------------------------------------------
-- INSTALL
--   1. Save as data/<character>/THF.lua.
--   2. Put the supplied ItemStats.lua in the same directory.
--   3. Requires the standard Mote-Include.lua libraries. GearInfo is optional.
--
-- COMMUNITY-INFORMED THF POLICY
--   TreasureMode=Tag      : wear TH on first contact with each target.
--   TreasureMode=SATA     : Tag behavior plus TH during Sneak/Trick Attack hits.
--   TreasureMode=Fulltime : keep TH equipped while engaged.
--   TreasureMode=None     : never force TH gear.
--
--   First-contact tagging covers melee, ranged attacks, weaponskills, hostile
--   magic, and hostile job abilities (including Provoke, Steps, Flourishes,
--   Feint, Bully, Mug, Steal, Despoil, and Larceny). Tagged targets expire
--   after 180 seconds or on zone change. No incoming-chunk hook is used.
--
-- KEYBINDS (mode changes only; use in-game macros for abilities)
--   F9 offense | Ctrl+F9 hybrid | Win+F9 WS mode | F10/F11 defense | F12 update
--   Win+T TreasureMode | Win+W WeaponLock | Win+E/R weapon back/forward
--   Win+C AutoSC | Win+A gear audit | Win+P pause | Win+F fishing
--   Win+H HUD | Ctrl+Win+H HUD lock | Win+Z Silmaril all toggle
--
-- IMPORTANT OWNERSHIP RULES
--   * Native tracking owns Haste, DW, and DW_needed. GearInfo is comparison-only.
--   * THF main-job Dual Wield (25 at level 98+) is not added to /NIN or /DNC;
--     only the strongest available trait tier applies.
--   * Movement is detected natively from player coordinates. Kiting gear is
--     applied in BOTH idle and engaged resolution, so Shneddick Ring really equips.
--   * Adaptive DW chooses the smallest owned subset that meets the gear-only need.
--   * Protected warp/boost rings and Doom locks take precedence over normal swaps.
-------------------------------------------------------------------------------------------------------------------

local THF_RUNTIME = {unloading=false, event_ids={}}

-- @ai:fn track_thf_event | layer=lifecycle | hot=no | purity=write | contract=Record custom Windower event IDs for deterministic unload cleanup.
local function track_thf_event(id)
    if id ~= nil then THF_RUNTIME.event_ids[#THF_RUNTIME.event_ids + 1] = id end
    return id
end

-- @ai:fn unregister_thf_events | layer=lifecycle | hot=no | purity=write | contract=Unregister only event IDs owned by this job file.
local function unregister_thf_events()
    if not (windower and type(windower.unregister_event) == 'function') then
        THF_RUNTIME.event_ids = {}
        return
    end
    for _, id in ipairs(THF_RUNTIME.event_ids) do pcall(windower.unregister_event, id) end
    THF_RUNTIME.event_ids = {}
end

local ok_socket, socket_lib = pcall(require, 'socket')

-- @ai:fn monotonic_now | layer=utility | hot=yes | purity=read | contract=Return a subsecond monotonic-enough clock for movement/action windows.
local function monotonic_now()
    if ok_socket and socket_lib and socket_lib.gettime then return socket_lib.gettime() end
    return os.clock()
end

-- Top-level policy tables exist before ItemStats loads. resolve_dw_pool()
-- fills their numeric facts during Mote's job_setup phase.
dw_pool = {
    {slot='ear1', piece='Eabani Earring', off='Brutal Earring',       prio=2},
    {slot='ear2', piece='Suppanomimi',    off='Telos Earring',        prio=3},
    {slot='waist',piece='Patentia Sash',  off='Windbuffet Belt +1',   prio=1},
    {slot='feet', piece='Taeon Boots',    off='Malignance Boots',     prio=4},
}
local dw_subset_plan = {}
dw_have, dw_shortfall = 0, false

-- Native haste/DW state.
Haste, DW, DW_needed = 0, false, 0
GI_Haste, GI_DW, GI_DW_needed = 0, false, 0
gearinfo_last = nil
local GEARINFO_STALE_SECONDS = 6
haste_manual_magic = 0
haste_assume = {
    magic = {['Haste']=307, ['March']=170, ['Embrava']=266, ['Mighty Guard']=150},
    ja = {},
}

-- Runtime feature state.
moving = false
low_hp_active = false
local motion_runtime = {
    x=nil, y=nil, z=nil, last_sample=0, last_motion=0,
    target_id=nil, sample_interval=0.08, stop_delay=0.35,
}
local th_runtime = {
    tagged={}, armed={}, last_cleanup=0, ttl=180, debug=false,
}

-- Forward-visible async report queues; job_self_command consumes them.
audit_queue = nil
audit_queue_index = 1

-------------------------------------------------------------------------------------------------------------------
-- Mote initialization
-------------------------------------------------------------------------------------------------------------------

-- @ai:fn get_sets | layer=framework | hot=no | purity=write | contract=Load ItemStats before Mote-Include; the order is mandatory.
function get_sets()
    mote_include_version = 2
    include('ItemStats.lua')
    include('Mote-Include.lua')
end

-- @ai:fn job_setup | layer=framework | hot=no | purity=write | contract=Create job-global policy and buff state before gear initialization.
function job_setup()
    resolve_dw_pool()

    state.Buff['Sneak Attack'] = buffactive['Sneak Attack'] or false
    state.Buff['Trick Attack'] = buffactive['Trick Attack'] or false

    warp_gear = S{'Warp Ring', 'Dim. Ring (Dem)', 'Dim. Ring (Holla)', 'Dim. Ring (Mea)'}
    boost_gear = S{'Trizek Ring', 'Echad Ring', 'Facility Ring', 'Capacity Ring',
        'Jubilee Ring', 'Empress Band'}
    no_swap_gear = S{'Warp Ring', 'Dim. Ring (Dem)', 'Dim. Ring (Holla)', 'Dim. Ring (Mea)',
        'Trizek Ring', 'Echad Ring', 'Facility Ring', 'Capacity Ring',
        'Jubilee Ring', 'Empress Band'}
    boost_buffs = S{'dedication', 'commitment'}
    all_equip_slots = {'main','sub','range','ammo','head','neck','ear1','ear2',
        'body','hands','ring1','ring2','back','waist','legs','feet'}
    releasing = {ring1=false, ring2=false}
    ring_lock_state = {ring1=nil, ring2=nil}

    lockstyleset = 24 -- user-editable; retained from the shared RDM core.
end

-- @ai:fn user_setup | layer=framework | hot=no | purity=write | contract=Define user modes, keybinds, defaults, and initial runtime state.
function user_setup()
    THF_RUNTIME.unloading = false

    state.OffenseMode:options('Normal', 'MidAcc', 'HighAcc')
    state.HybridMode:options('Normal', 'DT')
    state.WeaponskillMode:options('Normal', 'Acc')
    state.CastingMode:options('Normal', 'Resistant')
    state.IdleMode:options('Normal', 'DT')

    state.WeaponSet = M{['description']='Weapon Set', 'Tauret', 'Naegling', 'Odium', 'Rhadamanthus', 'LowDamage', 'Idle'}
    state.WeaponLock = M(true, 'Weapon Lock')
    state.TreasureMode = M{['description']='Treasure Mode', 'Tag', 'SATA', 'Fulltime', 'None'}
    state.AutoSC = M(false, 'Auto Skillchain')
    state.PauseSwaps = M(false, 'Pause Gear Swapping')
    state.FishingMode = M(false, 'Fishing Mode')
    state.Auto_Kite = M(false, 'Auto Kiting')

    send_command('bind @t gs c cycle TreasureMode')
    send_command('bind @w gs c toggle WeaponLock')
    send_command('bind @c gs c toggle AutoSC')
    send_command('bind @e gs c cycleback WeaponSet')
    send_command('bind @r gs c cycle WeaponSet')
    send_command('bind @a gs c auditgear')
    send_command('bind @p gs c toggle PauseSwaps')
    send_command('bind @f gs c toggle FishingMode')
    send_command('bind @h gs c hud')
    send_command('bind ^@h gs c hudlock')
    send_command('bind @z sm all toggle')

    init_hud()
    select_default_macro_book()
    set_lockstyle()

    moving, low_hp_active = false, false
    motion_runtime.x, motion_runtime.y, motion_runtime.z = nil, nil, nil
    motion_runtime.last_motion = 0
    th_reset(false)

    if state.WeaponLock.value then disable('main','sub') end
    update_native_haste_dw(true)
    update_dw_overlay()
    update_combat_form()
    update_hud(true)

    coroutine.schedule(function()
        if not THF_RUNTIME.unloading then print_keybinds() end
    end, 4)
end

-- @ai:fn user_unload | layer=lifecycle | hot=no | purity=write | contract=Invalidate async work, unregister events, restore slots, unbind keys, and hide HUD.
function user_unload()
    THF_RUNTIME.unloading = true
    if sc_cancel then sc_cancel('unload') end
    unregister_thf_events()
    if all_equip_slots then enable(unpack(all_equip_slots)) end

    for _, key in ipairs({'@t','@w','@c','@e','@r','@a','@p','@f','@h','^@h','@z'}) do
        send_command('unbind '..key)
    end
    if hud then hud:hide() end
end

-------------------------------------------------------------------------------------------------------------------
-- Gear sets
-------------------------------------------------------------------------------------------------------------------

-- @ai:fn init_gear_sets | layer=framework | hot=no | purity=write | contract=Define owned THF gear, action coverage, and canonical set aliases.
function init_gear_sets()
    ---------------------------------------------------------------------------------------------------------------
    -- Precast: magic, ranged, and job abilities
    ---------------------------------------------------------------------------------------------------------------
    sets.precast.FC = {
        ammo='Staunch Tathlum +1',
        head='Malignance Chapeau',
        neck="Naji's Loop",              -- FC+1
        ear1='Loquac. Earring',           -- FC+2
        ear2='Enchntr. Earring +1',       -- FC+2
        body='Taeon Tabard',              -- FC+4
        hands='Malignance Gloves',
        ring1='Chirich Ring +1',
        ring2='Murky Ring',
        back='Null Shawl',
        waist='Null Belt',
        legs='Limbo Trousers',            -- FC+3
        feet='Malignance Boots',
    }
    sets.precast.FC.Utsusemi = sets.precast.FC
    sets.precast.FC.Ninjutsu = sets.precast.FC

    sets.precast.RA = {
        range='Albin Bane',
        ammo=empty,
        head='Malignance Chapeau',
        neck='Null Loop',
        ear1='Telos Earring',
        ear2='Enervating Earring',
        body='Malignance Tabard',
        hands='Malignance Gloves',
        ring1='Chirich Ring +1',
        ring2='Chirich Ring +1',
        back='Null Shawl',
        waist='Null Belt',
        legs='Malignance Tights',
        feet='Meg. Jambeaux',             -- Snapshot+5
    }

    -- Ability-specific future upgrades are documented but never equipped until
    -- ItemStats/inventory proves ownership. This keeps the file install-safe now.
    sets.precast.JA['Sneak Attack'] = {}
    sets.precast.JA['Trick Attack'] = {}
    sets.precast.JA['Steal'] = {}
        -- Future: head="Plun. Bonnet +3"
    sets.precast.JA['Aura Steal'] = sets.precast.JA['Steal']
    sets.precast.JA['Despoil'] = {}
        -- Future: legs="Skulk. Culottes +3", feet="Skulk. Poulaines +3"
    sets.precast.JA['Mug'] = {}
    sets.precast.JA['Hide'] = {}
        -- Future: body="Pill. Vest +3"
    sets.precast.JA['Flee'] = {}
        -- Future: feet="Pill. Poulaines +3"
    sets.precast.JA['Feint'] = {}
        -- Future: legs="Plun. Culottes +3"
    sets.precast.JA['Bully'] = {}
    sets.precast.JA['Conspirator'] = {}
        -- Future: body="Skulk. Vest +3"
    sets.precast.JA['Accomplice'] = {}
        -- Future: head="Skulk. Bonnet +3"
    sets.precast.JA['Collaborator'] = sets.precast.JA['Accomplice']
    sets.precast.JA['Perfect Dodge'] = {}
        -- Future: hands="Plun. Armlets +3"
    sets.precast.JA['Larceny'] = {}
    sets.precast.JA["Assassin's Charge"] = {}

    sets.precast.Step = {
        ammo='Yamarang',
        head='Malignance Chapeau', body='Malignance Tabard',
        hands='Malignance Gloves', legs='Malignance Tights', feet='Malignance Boots',
        neck='Null Loop', ear1='Mache Earring +1', ear2='Telos Earring',
        ring1='Chirich Ring +1', ring2='Chirich Ring +1',
        back='Null Shawl', waist='Null Belt',
    }
    sets.precast.Flourish1 = sets.precast.Step
    sets.precast.Flourish2 = sets.precast.Step
    sets.precast.Flourish3 = sets.precast.Step

    -- Do not swap Rhadamanthus into Waltz precast: changing main hand would
    -- erase TP. Yamarang provides the owned, TP-safe Waltz potency bonus.
    sets.precast.Waltz = {
        ammo='Yamarang',
        head='Mummu Bonnet +2', body='Nyame Mail', hands='Nyame Gauntlets',
        legs='Nyame Flanchard', feet='Mummu Gamash. +2',
        neck='Null Loop', ear1='Eabani Earring', ear2='Alabaster Earring',
        ring1='Chirich Ring +1', ring2='Murky Ring',
        back='Null Shawl', waist='Sailfi Belt +1',
    }
    sets.precast.WaltzSelf = sets.precast.Waltz
    sets.precast.Waltz['Healing Waltz'] = {}
    sets.precast.HealingWaltz = {}

    ---------------------------------------------------------------------------------------------------------------
    -- Weaponskills
    ---------------------------------------------------------------------------------------------------------------
    sets.precast.WS = {
        ammo="Oshasha's Treatise",
        head='Nyame Helm', body='Nyame Mail', hands='Meg. Gloves +2',
        legs='Nyame Flanchard', feet='Nyame Sollerets',
        neck='Rep. Plat. Medal', ear1='Telos Earring', ear2='Moonshade Earring',
        ring1="Epaminondas's Ring", ring2='Sroda Ring',
        back='Null Shawl', waist='Sailfi Belt +1',
    }
    sets.precast.WS.Acc = set_combine(sets.precast.WS, {
        ammo='Yamarang', neck='Null Loop', ear1='Mache Earring +1',
        ring1='Chirich Ring +1', ring2='Chirich Ring +1', waist='Null Belt',
    })

    -- DEX-weighted single-hit dagger weaponskills. Sroda Ring is excluded
    -- because DEX-20 directly harms these modifiers.
    local dex_wsd = set_combine(sets.precast.WS, {
        ring2='Ramuh Ring +1',
    })
    local dex_wsd_acc = set_combine(dex_wsd, {
        ammo='Yamarang', neck='Null Loop', ear1='Mache Earring +1',
        ring1='Chirich Ring +1', ring2='Ramuh Ring +1', waist='Null Belt',
    })
    sets.precast.WS["Rudra's Storm"] = set_combine(dex_wsd, {})
    sets.precast.WS["Rudra's Storm"].Acc = set_combine(dex_wsd_acc, {})
    sets.precast.WS['Mandalic Stab'] = set_combine(dex_wsd, {})
    sets.precast.WS['Mandalic Stab'].Acc = set_combine(dex_wsd_acc, {})
    sets.precast.WS['Shark Bite'] = set_combine(dex_wsd, {})
    sets.precast.WS['Shark Bite'].Acc = set_combine(dex_wsd_acc, {})

    sets.precast.WS['Mercy Stroke'] = set_combine(sets.precast.WS, {
        ring2='Sroda Ring',
    })
    sets.precast.WS['Mercy Stroke'].Acc = sets.precast.WS.Acc

    -- Tauret's Evisceration bonus and its reverse-TP crit trait make this the
    -- default dagger profile's signature WS. Mummu supplies crit rate and DEX.
    sets.precast.WS['Evisceration'] = {
        ammo='Yetshila +1',
        head='Mummu Bonnet +2', body='Mummu Jacket +2', hands='Mummu Wrists +2',
        legs='Mummu Kecks +2', feet='Mummu Gamash. +2',
        neck='Anu Torque', ear1='Odr Earring', ear2='Mache Earring +1',
        ring1='Mummu Ring', ring2='Ramuh Ring +1',
        back='Null Shawl', waist='Sailfi Belt +1',
    }
    sets.precast.WS['Evisceration'].Acc = set_combine(sets.precast.WS['Evisceration'], {
        ammo='Yamarang', neck='Null Loop', waist='Null Belt',
        ring1='Chirich Ring +1',
    })

    sets.precast.WS['Dancing Edge'] = set_combine(sets.precast.WS['Evisceration'], {
        ammo='Yamarang', head='Malignance Chapeau', body='Malignance Tabard',
        hands='Malignance Gloves', legs='Malignance Tights', feet='Malignance Boots',
        ear1='Brutal Earring', ear2='Telos Earring',
        ring1='Chirich Ring +1', ring2='Chirich Ring +1',
    })
    sets.precast.WS['Dancing Edge'].Acc = set_combine(sets.precast.WS['Dancing Edge'], {
        neck='Null Loop', waist='Null Belt', ear1='Mache Earring +1',
    })

    sets.precast.WS['Exenterator'] = {
        ammo='Yamarang',
        head='Mummu Bonnet +2', body='Mummu Jacket +2', hands='Malignance Gloves',
        legs='Mummu Kecks +2', feet='Mummu Gamash. +2',
        neck='Anu Torque', ear1='Brutal Earring', ear2='Suppanomimi',
        ring1='Dingir Ring', ring2='Mummu Ring',
        back='Null Shawl', waist='Sailfi Belt +1',
    }
    sets.precast.WS['Exenterator'].Acc = set_combine(sets.precast.WS['Exenterator'], {
        neck='Null Loop', ear1='Mache Earring +1', ear2='Telos Earring',
        ring2='Chirich Ring +1', waist='Null Belt',
    })

    sets.precast.WS['Savage Blade'] = set_combine(sets.precast.WS, {})
    sets.precast.WS['Savage Blade'].Acc = sets.precast.WS.Acc

    -- Magical dagger/sword WS: Nyame contributes MAB/M.Acc/SCB on every job.
    local magical_ws_set = {
        ammo='Yamarang',
        head='Nyame Helm', body='Nyame Mail', hands='Nyame Gauntlets',
        legs='Nyame Flanchard', feet='Nyame Sollerets',
        neck='Sibyl Scarf', ear1='Friomisi Earring', ear2='Moonshade Earring',
        ring1='Metamor. Ring +1', ring2='Dingir Ring',
        back='Toro Cape', waist="Orpheus's Sash",
    }
    local magical_ws_acc = set_combine(magical_ws_set, {
        ammo='Yamarang', neck='Null Loop', ear1='Mache Earring +1',
        ring1='Chirich Ring +1', waist='Null Belt',
    })
    for _, name in ipairs({'Aeolian Edge','Cyclone','Gust Slash','Sanguine Blade','Burning Blade','Red Lotus Blade'}) do
        sets.precast.WS[name] = magical_ws_set
        sets.precast.WS[name].Acc = magical_ws_acc
    end
    sets.precast.WS['Sanguine Blade'] = set_combine(magical_ws_set, {head='Pixie Hairpin +1'})
    sets.precast.WS['Sanguine Blade'].Acc = set_combine(magical_ws_acc, {head='Pixie Hairpin +1'})

    local drain_ws = {
        ammo='Yamarang',
        head='Malignance Chapeau', body='Malignance Tabard',
        hands='Malignance Gloves', legs='Malignance Tights', feet='Malignance Boots',
        neck='Null Loop', ear1='Enchntr. Earring +1', ear2='Telos Earring',
        ring1='Metamor. Ring +1', ring2='Dingir Ring',
        back='Null Shawl', waist='Null Belt',
    }
    sets.precast.WS['Energy Drain'] = drain_ws
    sets.precast.WS['Energy Steal'] = drain_ws

    -- Every physical WS gets explicit SA/TA/SATA variants. Yetshila must be
    -- worn for the guaranteed critical hit; named AF/Empyrean action pieces can
    -- be added to these overlays when acquired.
    local magical_ws_names = S{'Aeolian Edge','Cyclone','Gust Slash','Sanguine Blade','Burning Blade','Red Lotus Blade','Energy Drain','Energy Steal'}
    local ws_names = {
        "Rudra's Storm", 'Mandalic Stab', 'Shark Bite', 'Mercy Stroke',
        'Evisceration', 'Dancing Edge', 'Exenterator', 'Savage Blade',
    }
    for _, name in ipairs(ws_names) do
        local base = sets.precast.WS[name]
        if base and not magical_ws_names:contains(name) then
            base.SA = set_combine(base, {ammo='Yetshila +1'})
            base.TA = set_combine(base, {ammo='Yetshila +1'})
            base.SATA = set_combine(base, {ammo='Yetshila +1'})
            if base.Acc then
                base.Acc.SA = set_combine(base.Acc, {ammo='Yetshila +1'})
                base.Acc.TA = set_combine(base.Acc, {ammo='Yetshila +1'})
                base.Acc.SATA = set_combine(base.Acc, {ammo='Yetshila +1'})
            end
        end
    end
    sets.precast.WS.SA = set_combine(sets.precast.WS, {ammo='Yetshila +1'})
    sets.precast.WS.TA = sets.precast.WS.SA
    sets.precast.WS.SATA = sets.precast.WS.SA
    sets.precast.WS.Acc.SA = set_combine(sets.precast.WS.Acc, {ammo='Yetshila +1'})
    sets.precast.WS.Acc.TA = sets.precast.WS.Acc.SA
    sets.precast.WS.Acc.SATA = sets.precast.WS.Acc.SA

    ---------------------------------------------------------------------------------------------------------------
    -- Midcast
    ---------------------------------------------------------------------------------------------------------------
    sets.midcast.FastRecast = sets.precast.FC
    sets.midcast.Utsusemi = {
        ammo='Staunch Tathlum +1',
        head='Malignance Chapeau', neck='Null Loop',
        ear1='Magnetic Earring', ear2='Alabaster Earring',
        body='Malignance Tabard', hands='Malignance Gloves',
        ring1='Murky Ring', ring2='Evanescence Ring',
        back='Null Shawl', waist='Null Belt',
        legs='Malignance Tights', feet='Malignance Boots',
    }
    sets.midcast.Ninjutsu = set_combine(sets.midcast.Utsusemi, {
        ammo='Yamarang', ear1='Enchntr. Earring +1', ear2='Telos Earring',
        ring1='Chirich Ring +1', waist='Null Belt',
    })
    sets.midcast.RA = {
        range='Albin Bane', ammo=empty,
        head='Malignance Chapeau', body='Malignance Tabard',
        hands='Malignance Gloves', legs='Malignance Tights', feet='Malignance Boots',
        neck='Null Loop', ear1='Telos Earring', ear2='Enervating Earring',
        ring1='Chirich Ring +1', ring2='Chirich Ring +1',
        back='Null Shawl', waist='Null Belt',
    }

    ---------------------------------------------------------------------------------------------------------------
    -- Sneak Attack / Trick Attack held-hit sets
    ---------------------------------------------------------------------------------------------------------------
    sets.buff['Sneak Attack'] = {
        ammo='Yetshila +1',
        head='Mummu Bonnet +2', body='Meg. Cuirie +2', hands='Mummu Wrists +2',
        legs='Mummu Kecks +2', feet='Malignance Boots',
        neck='Null Loop', ear1='Odr Earring', ear2='Mache Earring +1',
        ring1='Ramuh Ring +1', ring2='Mummu Ring',
        back='Null Shawl', waist='Sailfi Belt +1',
    }
    sets.buff['Trick Attack'] = {
        ammo='Yetshila +1',
        head='Mummu Bonnet +2', body='Mummu Jacket +2', hands='Malignance Gloves',
        legs='Mummu Kecks +2', feet='Mummu Gamash. +2',
        neck='Null Loop', ear1='Brutal Earring', ear2='Suppanomimi',
        ring1='Dingir Ring', ring2='Mummu Ring',
        back='Null Shawl', waist='Sailfi Belt +1',
    }
    sets.buff.SATA = set_combine(sets.buff['Trick Attack'], {
        body='Meg. Cuirie +2', hands='Mummu Wrists +2',
        ear1='Odr Earring', ear2='Mache Earring +1',
        ring1='Ramuh Ring +1',
    })

    ---------------------------------------------------------------------------------------------------------------
    -- Idle / defense / engaged
    ---------------------------------------------------------------------------------------------------------------
    sets.idle = {
        ammo='Yamarang',
        head='Turms Cap', body='Malignance Tabard', hands='Malignance Gloves',
        legs='Malignance Tights', feet='Turms Leggings',
        neck='Null Loop', ear1='Eabani Earring', ear2='Alabaster Earring',
        ring1='Chirich Ring +1', ring2='Murky Ring',
        back='Null Shawl', waist="Carrier's Sash",
    }
    sets.idle.DT = {
        ammo='Staunch Tathlum +1',
        head='Nyame Helm', body='Nyame Mail', hands='Nyame Gauntlets',
        legs='Nyame Flanchard', feet='Nyame Sollerets',
        neck='Null Loop', ear1='Eabani Earring', ear2='Alabaster Earring',
        ring1='Chirich Ring +1', ring2='Murky Ring',
        back='Null Shawl', waist="Carrier's Sash",
    }
    sets.idle.Town = sets.idle
    sets.resting = sets.idle.DT
    sets.defense.PDT = sets.idle.DT
    sets.defense.MDT = sets.idle.DT

    sets.engaged = {
        ammo='Yamarang',
        head='Malignance Chapeau', body='Malignance Tabard',
        hands='Malignance Gloves', legs='Malignance Tights', feet='Malignance Boots',
        neck='Anu Torque', ear1='Brutal Earring', ear2='Telos Earring',
        ring1='Chirich Ring +1', ring2='Chirich Ring +1',
        back='Null Shawl', waist='Windbuffet Belt +1',
    }
    sets.engaged.MidAcc = set_combine(sets.engaged, {
        neck='Null Loop', ear2='Mache Earring +1', waist='Null Belt',
    })
    sets.engaged.HighAcc = set_combine(sets.engaged.MidAcc, {
        ear1='Odr Earring', ring2='Mummu Ring',
    })

    sets.engaged.Hybrid = {
        neck='Null Loop', ear2='Alabaster Earring', ring2='Murky Ring',
    }
    sets.engaged.DT = set_combine(sets.engaged, sets.engaged.Hybrid)
    sets.engaged.MidAcc.DT = set_combine(sets.engaged.MidAcc, sets.engaged.Hybrid)
    sets.engaged.HighAcc.DT = set_combine(sets.engaged.HighAcc, sets.engaged.Hybrid)

    -- Mote needs a DW family to select while native THF DW is active. Adaptive
    -- overlay code replaces each of the four candidate slots every resolution.
    sets.engaged.DW = set_combine(sets.engaged, {})
    sets.engaged.DW.MidAcc = sets.engaged.MidAcc
    sets.engaged.DW.HighAcc = sets.engaged.HighAcc
    sets.engaged.DW.DT = sets.engaged.DT
    sets.engaged.DW.MidAcc.DT = sets.engaged.MidAcc.DT
    sets.engaged.DW.HighAcc.DT = sets.engaged.HighAcc.DT

    ---------------------------------------------------------------------------------------------------------------
    -- Special policy overlays and weapons
    ---------------------------------------------------------------------------------------------------------------
    -- THF99 native TH3 + this owned gear TH3 = initial TH6. A future
    -- Skulk. Poulaines +1 (TH3) paired with Hoxne Ring (TH2) would reach the
    -- normal initial TH8 cap without occupying ammo.
    sets.TreasureHunter = {ammo='Per. Lucky Egg', ring1='Hoxne Ring'} -- owned gear TH+3
    sets.TreasureHunter.RA = {ring1='Hoxne Ring'} -- Albin Bane occupies range; no egg swap.
    sets.Kiting = {ring2='Shneddick Ring'}
    sets.LowHP = {neck='Null Loop', ear2='Alabaster Earring', ring2='Murky Ring'}
    sets.buff.Doom = {
        neck="Nicander's Necklace", ring1="Blenmot's Ring +1",
        ring2="Blenmot's Ring +1", waist='Gishdubar Sash',
    }
    sets.Fishing = {
        range="Lu Shang's F. Rod",
        body="Fisherman's Tunica", hands="Fisherman's Gloves",
        legs="Fisherman's Hose", feet="Fisherman's Boots",
    }

    sets.Tauret = {main='Tauret', sub='Blurred Knife +1'}
    sets.Naegling = {main='Naegling', sub='Blurred Knife +1'}
    sets.Odium = {main='Odium', sub='Blurred Knife +1'}
    sets.Rhadamanthus = {main='Rhadamanthus', sub='Blurred Knife +1'} -- Waltz potency+7 while already equipped.
    sets.LowDamage = {main='Twinned Blade', sub='Ceremonial Dagger'}
    sets.Idle = {main='Tauret', sub='Blurred Knife +1'}
    sets.DefaultShield = {sub='Deliverance'}

    -- Mote calls user_setup before this function, so weapon tables only become
    -- valid here. Apply the default pair now, then recompute native DW from the
    -- real offhand and refresh the initial HUD.
    check_weaponset()
    update_native_haste_dw(true)
    update_dw_overlay()
    update_combat_form()
    update_hud(true)
end

-------------------------------------------------------------------------------------------------------------------
-- Native haste / Dual Wield engine
-------------------------------------------------------------------------------------------------------------------

local equipment_snapshot_slots = {
    'main','sub','range','ammo','head','neck','ear1','ear2',
    'body','hands','ring1','ring2','back','waist','legs','feet',
}
local equipment_snapshot = {initialized=false, names={}, gear_haste=0}
local haste_estimate = {gear=0, magic=0, ja=0, total=0, pct=0}
local native_state_active, native_state_haste, native_state_trait, native_state_need
local dw_overlay_active_cache, dw_overlay_need_cache

-- @ai:fn get_equipment_snapshot | layer=haste-dw | hot=yes | purity=write | contract=Cache equipped item names and gear haste without allocation on unchanged hits.
local function get_equipment_snapshot()
    local equipment = player and player.equipment
    if not equipment then return equipment_snapshot end
    local names = equipment_snapshot.names
    local changed = not equipment_snapshot.initialized
    if not changed then
        for i, slot in ipairs(equipment_snapshot_slots) do
            if names[i] ~= (equipment[slot] or '') then changed = true; break end
        end
    end
    if not changed then return equipment_snapshot end

    local gear_haste = 0
    for i, slot in ipairs(equipment_snapshot_slots) do
        local name = equipment[slot] or ''
        names[i] = name
        local stats = item_stats and item_stats[name]
        if stats then gear_haste = gear_haste + (stats.haste or 0) end
    end
    equipment_snapshot.initialized = true
    equipment_snapshot.gear_haste = math.min(256, gear_haste)
    return equipment_snapshot
end

-- @ai:fn estimate_haste | layer=haste-dw | hot=yes | purity=write | contract=Return a reused native haste estimate in 1024ths.
function estimate_haste()
    local magic, ja = haste_manual_magic, 0
    if buffactive then
        for buff, value in pairs(haste_assume.magic) do
            local count = buffactive[buff]
            if count then magic = magic + value * (tonumber(count) or 1) end
        end
        for buff, value in pairs(haste_assume.ja) do
            if buffactive[buff] then ja = ja + value end
        end
    end
    magic, ja = math.min(448, magic), math.min(256, ja)
    local gear = get_equipment_snapshot().gear_haste
    local total = math.min(819, gear + magic + ja)
    haste_estimate.gear, haste_estimate.magic, haste_estimate.ja = gear, magic, ja
    haste_estimate.total, haste_estimate.pct = total, total / 1024 * 100
    return haste_estimate
end

-- @ai:fn dw_needed_at_haste | layer=haste-dw | hot=yes | purity=pure | contract=Calculate total DW needed to reach the 80 percent delay-reduction ceiling.
function dw_needed_at_haste(haste1024)
    if haste1024 >= 819 then return 0 end
    return math.max(0, math.ceil((1 - 0.2 / ((1024 - haste1024) / 1024)) * 100))
end

local main_dw_tiers = {
    THF = {{98,25},{87,15},{83,10}},
}
local sub_dw_tiers = {
    NIN = {{85,35},{65,30},{45,25},{25,15},{10,10}},
    DNC = {{80,30},{60,25},{40,15},{20,10}},
}

-- @ai:fn trait_value_for | layer=haste-dw | hot=yes | purity=pure | contract=Resolve one job/level Dual Wield trait table.
local function trait_value_for(tiers, job, level)
    local list = job and tiers[job]
    if not list then return 0 end
    for _, tier in ipairs(list) do
        if (level or 0) >= tier[1] then return tier[2] end
    end
    return 0
end

-- @ai:fn dw_native_trait | layer=haste-dw | hot=yes | purity=read | contract=Return the strongest main/sub DW trait without stacking job traits.
function dw_native_trait()
    if not player then return 0 end
    local main = trait_value_for(main_dw_tiers, player.main_job, player.main_job_level)
    local sub = trait_value_for(sub_dw_tiers, player.sub_job, player.sub_job_level)
    return math.max(main, sub)
end

local native_non_weapon_subs = S{
    'Deliverance', "Archduke's Shield", 'Ammurapi Shield', 'Enki Strap',
}

-- @ai:fn native_dual_wield_active | layer=haste-dw | hot=yes | purity=read | contract=Require a native trait and weapon-like offhand before enabling DW policy.
local function native_dual_wield_active(trait)
    trait = trait or dw_native_trait()
    if trait <= 0 then return false end
    local equipment = player and player.equipment
    local sub = equipment and (equipment.sub or equipment.left_sub)
    if not sub or sub == '' or sub == 'empty' then return false end
    return not native_non_weapon_subs:contains(sub)
end

-- @ai:fn rebuild_dw_subset_plan | layer=haste-dw | hot=no | purity=write | contract=Precompute the minimal owned four-piece DW subset for every gear target.
local function rebuild_dw_subset_plan()
    dw_subset_plan = {}
    local count, max_mask = #dw_pool, (2 ^ #dw_pool) - 1
    local full_sum = 0
    for _, entry in ipairs(dw_pool) do full_sum = full_sum + (entry.dw or 0) end

    for target = 0, 100 do
        local best_mask, best_sum, best_pieces, best_prio
        for mask = 0, max_mask do
            local sum, pieces, prio = 0, 0, 0
            for i, entry in ipairs(dw_pool) do
                if math.floor(mask / 2 ^ (i - 1)) % 2 == 1 then
                    sum = sum + (entry.dw or 0)
                    pieces = pieces + 1
                    prio = prio + (entry.prio or 0)
                end
            end
            if sum >= target and (not best_sum or sum < best_sum
                    or (sum == best_sum and pieces < best_pieces)
                    or (sum == best_sum and pieces == best_pieces and prio < best_prio)) then
                best_mask, best_sum, best_pieces, best_prio = mask, sum, pieces, prio
            end
        end
        if best_mask then
            dw_subset_plan[target] = {mask=best_mask, sum=best_sum, shortfall=false}
        else
            dw_subset_plan[target] = {mask=max_mask, sum=full_sum, shortfall=true}
        end
    end
end

-- @ai:fn resolve_dw_pool | layer=haste-dw | hot=no | purity=write | contract=Read DW values from ItemStats and apply the documented Patentia hidden value.
function resolve_dw_pool()
    for _, entry in ipairs(dw_pool) do
        entry.dw = item_stat(entry.piece, 'dw') or 0
        -- Patentia's description says only "Enhances Dual Wield effect". Its
        -- community-tested value is +5; keep that hidden fact local until the
        -- shared ItemStats generator records hidden DW for it.
        if entry.piece == 'Patentia Sash' and entry.dw == 0 then entry.dw = 5 end
    end
    rebuild_dw_subset_plan()
    dw_overlay_active_cache, dw_overlay_need_cache = nil, nil
end

-- @ai:fn update_native_haste_dw | layer=haste-dw | hot=yes | purity=write | contract=Own authoritative Haste, DW, and gear-only DW_needed state.
function update_native_haste_dw(force)
    local estimate = estimate_haste()
    local trait = dw_native_trait()
    local active = native_dual_wield_active(trait)
    -- All engaged families carry exactly 25% equipment haste. Use that stable
    -- bucket through idle-to-engaged transitions instead of the stale idle set.
    local delay_haste = active and math.min(819, 256 + estimate.magic + estimate.ja) or estimate.total
    local total_need = active and dw_needed_at_haste(delay_haste) or 0
    local gear_need = active and math.max(0, total_need - trait) or 0
    if not force and active == native_state_active and delay_haste == native_state_haste
            and trait == native_state_trait and gear_need == native_state_need then
        return false
    end
    native_state_active, native_state_haste = active, delay_haste
    native_state_trait, native_state_need = trait, gear_need
    Haste, DW, DW_needed = delay_haste, active, gear_need
    dw_overlay_active_cache, dw_overlay_need_cache = nil, nil
    return true
end

-- @ai:fn update_dw_overlay | layer=haste-dw | hot=yes | purity=write | contract=Select the precomputed minimal gear-DW subset for the current need.
function update_dw_overlay()
    local active, need = DW == true, DW_needed or 0
    if active == dw_overlay_active_cache and need == dw_overlay_need_cache then return end
    if not active then
        for _, entry in ipairs(dw_pool) do entry.active = false end
        dw_have, dw_shortfall = 0, false
        dw_overlay_active_cache, dw_overlay_need_cache = active, need
        return
    end
    local plan = dw_subset_plan[math.min(100, need)]
    if not plan then rebuild_dw_subset_plan(); plan = dw_subset_plan[math.min(100, need)] end
    for i, entry in ipairs(dw_pool) do
        entry.active = math.floor(plan.mask / 2 ^ (i - 1)) % 2 == 1
    end
    dw_have, dw_shortfall = plan.sum, plan.shortfall
    dw_overlay_active_cache, dw_overlay_need_cache = active, need
end

-- @ai:fn determine_haste_group | layer=framework | hot=yes | purity=write | contract=Refresh native haste/DW state and leave Mote custom melee groups empty.
function determine_haste_group()
    classes.CustomMeleeGroups:clear()
    update_native_haste_dw()
    update_combat_form()
    update_dw_overlay()
end

-- @ai:fn report_dw_tier | layer=haste-dw | hot=no | purity=write | contract=Explain the current native and adaptive DW selection.
function report_dw_tier()
    update_native_haste_dw(true)
    update_dw_overlay()
    if not DW then add_to_chat(158, '[DW] inactive: no weapon-like offhand or no native trait.'); return end
    local worn = {}
    for _, entry in ipairs(dw_pool) do
        if entry.active then worn[#worn + 1] = entry.piece..' +'..entry.dw end
    end
    local trait = dw_native_trait()
    add_to_chat(158, string.format('[DW] native %d + gear %d/%d = total %d/%d%s',
        trait, dw_have, DW_needed, trait + dw_have, trait + DW_needed,
        dw_shortfall and '  ** wardrobe shortfall **' or ''))
    add_to_chat(158, '[DW] active pieces: '..(#worn > 0 and table.concat(worn, ', ') or 'none'))
end

-- @ai:fn report_haste_check | layer=haste-dw | hot=no | purity=write | contract=Report native haste math and optional GearInfo comparison.
function report_haste_check()
    local estimate = estimate_haste()
    local native_total = native_dual_wield_active() and math.min(819, 256 + estimate.magic + estimate.ja) or estimate.total
    add_to_chat(158, string.format('[Haste] gear %d/256 + magic %d/448 + JA %d/256 = %d/819 (%.1f%%)',
        estimate.gear, estimate.magic, estimate.ja, native_total, native_total / 10.24))
    if gearinfo_last and monotonic_now() - gearinfo_last <= GEARINFO_STALE_SECONDS then
        add_to_chat(158, string.format('[Haste] GearInfo comparison %.1f%%; native delta %.1f points',
            (GI_Haste or 0) / 10.24, math.abs((GI_Haste or 0) - native_total) / 10.24))
    else
        add_to_chat(158, '[Haste] GearInfo offline/stale; native engine remains authoritative.')
    end
    add_to_chat(158, '[Haste] Haste Samba is not auto-counted: the self buff does not prove Haste Daze is on this target.')
end

-- @ai:fn gearinfo | layer=haste-dw | hot=yes | purity=write | contract=Parse optional comparison packets without changing native authoritative state.
function gearinfo(cmdParams, eventArgs)
    if not cmdParams or cmdParams[1] ~= 'gearinfo' then return end
    local gi_need = tonumber(cmdParams[2])
    local gi_inactive = cmdParams[2] == 'false'
    local gi_haste = tonumber(cmdParams[3])
    if (not gi_need and not gi_inactive) or not gi_haste then return end
    gearinfo_last = monotonic_now()
    GI_DW, GI_DW_needed = gi_need ~= nil, gi_need or 0
    GI_Haste = gi_haste
    update_hud()
    if eventArgs then eventArgs.handled = true end
end

-------------------------------------------------------------------------------------------------------------------
-- Treasure Hunter target state
-------------------------------------------------------------------------------------------------------------------

-- @ai:fn current_target | layer=treasure | hot=yes | purity=read | contract=Return the current target entity without assuming one exists.
local function current_target()
    local getter = windower and windower.ffxi and windower.ffxi.get_mob_by_target
    return type(getter) == 'function' and getter('t') or nil
end

-- @ai:fn th_cleanup | layer=treasure | hot=yes | purity=write | contract=Expire old tagged and armed target records at a throttled cadence.
local function th_cleanup(force)
    local now = monotonic_now()
    if not force and now - th_runtime.last_cleanup < 5 then return end
    th_runtime.last_cleanup = now
    for id, stamp in pairs(th_runtime.tagged) do
        if now - stamp > th_runtime.ttl then th_runtime.tagged[id] = nil end
    end
    for id, expiry in pairs(th_runtime.armed) do
        if now > expiry then th_runtime.armed[id] = nil end
    end
end

-- @ai:fn th_reset | layer=treasure | hot=no | purity=write | contract=Clear all per-target TH knowledge and optionally report it.
function th_reset(verbose)
    th_runtime.tagged, th_runtime.armed = {}, {}
    th_runtime.last_cleanup = monotonic_now()
    if verbose ~= false then add_to_chat(158, '[TH] target memory cleared.') end
    update_hud()
end

-- @ai:fn th_target_needs_tag | layer=treasure | hot=yes | purity=read | contract=Return whether a target lacks a non-expired confirmed tag.
local function th_target_needs_tag(target_id)
    if not target_id then return false end
    local stamp = th_runtime.tagged[target_id]
    return not stamp or monotonic_now() - stamp > th_runtime.ttl
end

-- @ai:fn th_mode | layer=treasure | hot=yes | purity=read | contract=Return a nil-safe TreasureMode string.
local function th_mode()
    return state and state.TreasureMode and state.TreasureMode.value or 'None'
end

-- @ai:fn sata_active | layer=gear | hot=yes | purity=read | contract=Return SA, TA, and combined held-buff state.
local function sata_active()
    local sa = buffactive and buffactive['Sneak Attack'] or false
    local ta = buffactive and buffactive['Trick Attack'] or false
    if sa and ta then return 'SATA' end
    if sa then return 'SA' end
    if ta then return 'TA' end
    return nil
end

-- @ai:fn th_arm_target | layer=treasure | hot=yes | purity=write | contract=Remember that TH gear is armed for a target until its action packet arrives.
local function th_arm_target(target_id)
    if not target_id then return end
    th_runtime.armed[target_id] = monotonic_now() + 8
    if th_runtime.debug then add_to_chat(160, '[TH dbg] armed target '..tostring(target_id)) end
end

-- @ai:fn th_hostile_target_id | layer=treasure | hot=yes | purity=read | contract=Extract only non-self hostile target IDs from a GearSwap spell record.
local function th_hostile_target_id(spell)
    local target = spell and spell.target
    local id = target and target.id
    if not id or (player and id == player.id) then return nil end
    local kind = target.type
    if kind == 'SELF' or kind == 'PLAYER' or kind == 'NPC' or kind == 'PARTY' or kind == 'ALLY' then return nil end
    -- MONSTER is authoritative. Some WS/RA records omit target.type, so their
    -- action class is also accepted after excluding friendly/self classes.
    if kind == 'MONSTER' or spell.type == 'WeaponSkill' or spell.action_type == 'Ranged Attack' then return id end
    if spell.action_type == 'Magic' or spell.type == 'JobAbility' or spell.action_type == 'Ability' then return id end
    return nil
end

-- @ai:fn th_should_equip_for_target | layer=treasure | hot=yes | purity=read | contract=Apply mode policy to one target and current SA/TA state.
local function th_should_equip_for_target(target_id)
    local mode = th_mode()
    if mode == 'None' or not target_id then return false end
    if mode == 'Fulltime' then return true end
    if th_target_needs_tag(target_id) then return true end
    return mode == 'SATA' and sata_active() ~= nil
end

-- @ai:fn th_mark_tagged | layer=treasure | hot=yes | purity=write | contract=Confirm one armed target, clear its arm, and refresh gear after first contact.
local function th_mark_tagged(target_id)
    if not target_id then return end
    th_runtime.tagged[target_id] = monotonic_now()
    th_runtime.armed[target_id] = nil
    if th_runtime.debug then add_to_chat(160, '[TH dbg] confirmed target '..tostring(target_id)) end
    update_hud()
    coroutine.schedule(function()
        if not THF_RUNTIME.unloading and player and not midaction() then
            handle_equipping_gear(player.status)
        end
    end, 0.1)
end

-- @ai:fn report_th_info | layer=treasure | hot=no | purity=read | contract=Describe TH mode, owned total, and current target state.
function report_th_info()
    th_cleanup(true)
    local target = current_target()
    local tag = target and (th_target_needs_tag(target.id) and 'NEEDS TAG' or 'TAGGED') or 'NO TARGET'
    local count = 0
    for _ in pairs(th_runtime.tagged) do count = count + 1 end
    add_to_chat(158, string.format('[TH] mode=%s | owned swap=TH+3 (egg+ring) | current=%s | remembered=%d | TTL=%ds',
        th_mode(), tag, count, th_runtime.ttl))
    add_to_chat(158, '[TH] Tag=first contact | SATA=first contact plus SA/TA | Fulltime=always | None=disabled')
end

-------------------------------------------------------------------------------------------------------------------
-- Gear overlays, movement, and ring protection
-------------------------------------------------------------------------------------------------------------------

local idle_overlay_scratch, melee_overlay_scratch = {}, {}
local overlay_slots = S{
    'main','sub','range','ammo','head','neck','ear1','ear2',
    'body','hands','ring1','ring2','back','waist','legs','feet',
}

-- @ai:fn clear_overlay | layer=gear | hot=yes | purity=write | contract=Clear one reusable overlay table in place.
local function clear_overlay(tbl)
    for key in pairs(tbl) do tbl[key] = nil end
end

-- @ai:fn merge_overlay | layer=gear | hot=yes | purity=write | contract=Copy an overlay into scratch with later values winning.
local function merge_overlay(dst, src)
    if not src then return end
    for slot, item in pairs(src) do
        if overlay_slots:contains(slot) then dst[slot] = item end
    end
end

-- @ai:fn swaps_frozen | layer=gear | hot=yes | purity=read | contract=Return whether Pause or Fishing owns a full-slot freeze.
local function swaps_frozen()
    return state and ((state.PauseSwaps and state.PauseSwaps.value) or (state.FishingMode and state.FishingMode.value))
end

-- @ai:fn customize_idle_set | layer=gear | hot=yes | purity=write | contract=Apply low-HP and real movement overlays with one final set combine.
function customize_idle_set(idleSet)
    check_gear()
    clear_overlay(idle_overlay_scratch)
    if low_hp_active then merge_overlay(idle_overlay_scratch, sets.LowHP) end
    if moving or (state.Auto_Kite and state.Auto_Kite.value) then merge_overlay(idle_overlay_scratch, sets.Kiting) end
    if next(idle_overlay_scratch) then return set_combine(idleSet, idle_overlay_scratch) end
    return idleSet
end

-- @ai:fn customize_melee_set | layer=gear | hot=yes | purity=write | contract=Apply adaptive DW, defense, SA/TA, TH, and movement in fixed precedence.
function customize_melee_set(meleeSet)
    check_gear()
    update_native_haste_dw()
    update_dw_overlay()
    clear_overlay(melee_overlay_scratch)

    -- Every candidate slot gets an explicit active/off choice, which removes a
    -- stale DW item immediately when haste rises.
    if DW then
        for _, entry in ipairs(dw_pool) do
            melee_overlay_scratch[entry.slot] = entry.active and entry.piece or entry.off
        end
    end
    if low_hp_active then merge_overlay(melee_overlay_scratch, sets.LowHP) end

    local sata = sata_active()
    if sata == 'SATA' then merge_overlay(melee_overlay_scratch, sets.buff.SATA)
    elseif sata == 'SA' then merge_overlay(melee_overlay_scratch, sets.buff['Sneak Attack'])
    elseif sata == 'TA' then merge_overlay(melee_overlay_scratch, sets.buff['Trick Attack']) end

    local target = current_target()
    local target_id = target and target.id
    if th_should_equip_for_target(target_id) then
        merge_overlay(melee_overlay_scratch, sets.TreasureHunter)
        if th_target_needs_tag(target_id) then th_arm_target(target_id) end
    end

    -- Last movement overlay guarantees that the actual engaged ring changes;
    -- protected-ring slot locks can still correctly veto it.
    if moving or (state.Auto_Kite and state.Auto_Kite.value) then merge_overlay(melee_overlay_scratch, sets.Kiting) end
    if next(melee_overlay_scratch) then return set_combine(meleeSet, melee_overlay_scratch) end
    return meleeSet
end

-- @ai:fn movement_sample | layer=gear | hot=yes | purity=write | contract=Derive movement transitions from player coordinate deltas with stop hysteresis.
local function movement_sample()
    if THF_RUNTIME.unloading or not player then return end
    local now = monotonic_now()
    if now - motion_runtime.last_sample < motion_runtime.sample_interval then return end
    motion_runtime.last_sample = now

    local getter = windower and windower.ffxi and windower.ffxi.get_mob_by_target
    local me = type(getter) == 'function' and getter('me') or nil
    if not me or me.x == nil or me.y == nil then return end

    if motion_runtime.x ~= nil then
        local dx, dy = me.x - motion_runtime.x, me.y - motion_runtime.y
        local dz = (me.z or 0) - (motion_runtime.z or 0)
        if dx * dx + dy * dy + dz * dz > 0.000001 then motion_runtime.last_motion = now end
    end
    motion_runtime.x, motion_runtime.y, motion_runtime.z = me.x, me.y, me.z
    local new_moving = now - motion_runtime.last_motion < motion_runtime.stop_delay
    local target = current_target()
    local target_id = target and target.id or nil
    local target_changed = target_id ~= motion_runtime.target_id
    motion_runtime.target_id = target_id

    local hpp = tonumber(player.hpp) or 100
    local new_low_hp = low_hp_active and hpp < 50 or hpp <= 35
    if new_moving == moving and new_low_hp == low_hp_active and not target_changed then
        th_cleanup(false)
        return
    end

    moving, low_hp_active = new_moving, new_low_hp
    if state and state.Auto_Kite and state.Auto_Kite.value ~= moving then
        state.Auto_Kite.value = moving
    end
    update_hud()
    if not swaps_frozen() and not midaction() then handle_equipping_gear(player.status) end
end

-- @ai:fn check_moving | layer=gear | hot=yes | purity=write | contract=Run one native movement sample; retained as the Mote hook entry.
function check_moving()
    movement_sample()
end

-- @ai:fn invalidate_ring_lock_cache | layer=gear | hot=no | purity=write | contract=Force protected ring slots to be reconsidered.
function invalidate_ring_lock_cache()
    if ring_lock_state then ring_lock_state.ring1, ring_lock_state.ring2 = nil, nil end
end

-- @ai:fn apply_ring_lock | layer=gear | hot=yes | purity=write | contract=Deduplicate enable or disable calls for one protected ring slot.
local function apply_ring_lock(slot, should_lock)
    if ring_lock_state[slot] == should_lock then return end
    ring_lock_state[slot] = should_lock
    if should_lock then disable(slot) else enable(slot) end
end

-- @ai:fn check_gear | layer=gear | hot=yes | purity=write | contract=Protect manually equipped travel and boost rings unless Doom or a full freeze owns slots.
function check_gear()
    if not player or not player.equipment or not ring_lock_state or swaps_frozen() then return end
    if buffactive and buffactive.Doom then return end
    local left, right = player.equipment.left_ring, player.equipment.right_ring
    apply_ring_lock('ring1', not releasing.ring1 and no_swap_gear:contains(left))
    apply_ring_lock('ring2', not releasing.ring2 and no_swap_gear:contains(right))
end

-- @ai:fn release_ring_slots | layer=gear | hot=no | purity=write | contract=Release protected slots, restore normal gear, then re-arm protection checks.
function release_ring_slots(slots, reason)
    if not slots or #slots == 0 then return end
    for _, slot in ipairs(slots) do releasing[slot] = true; enable(slot); ring_lock_state[slot] = false end
    if not swaps_frozen() then handle_equipping_gear(player.status) end
    if reason then add_to_chat(158, '[Ring] released '..table.concat(slots, ', ')..' -- '..reason) end
    coroutine.schedule(function()
        if THF_RUNTIME.unloading then return end
        for _, slot in ipairs(slots) do releasing[slot] = false end
        invalidate_ring_lock_cache()
        check_gear()
    end, 0.5)
end

-------------------------------------------------------------------------------------------------------------------
-- Mote action and state hooks
-------------------------------------------------------------------------------------------------------------------

local magical_ws_names = S{
    'Aeolian Edge','Cyclone','Gust Slash','Sanguine Blade','Burning Blade','Red Lotus Blade',
}

-- @ai:fn spell_target_within | layer=utility | hot=yes | purity=read | contract=Safely test target distance including model size.
local function spell_target_within(spell, yalms)
    local target = spell and spell.target
    local distance = target and tonumber(target.distance)
    if not distance then return false end
    return distance < yalms + (tonumber(target.model_size) or 0)
end

-- @ai:fn get_custom_wsmode | layer=framework | hot=yes | purity=read | contract=Map high-accuracy offense to the WS Acc family.
function get_custom_wsmode(spell, action, spellMap)
    if state.OffenseMode and state.OffenseMode.value == 'HighAcc' then return 'Acc' end
end

-- @ai:fn job_get_spell_map | layer=framework | hot=yes | purity=read | contract=Route Utsusemi and generic Ninjutsu to owned midcast families.
function job_get_spell_map(spell, default_spell_map)
    if spell and spell.skill == 'Ninjutsu' then
        if spell.english and spell.english:startswith('Utsusemi') then return 'Utsusemi' end
        return 'Ninjutsu'
    end
    return default_spell_map
end

-- @ai:fn job_precast | layer=framework | hot=yes | purity=write | contract=Protect rings and enforce Utsusemi image cancellation rules before Mote equips.
function job_precast(spell, action, spellMap, eventArgs)
    check_gear()
    if spellMap == 'Utsusemi' then
        if buffactive['Copy Image (3)'] or buffactive['Copy Image (4+)'] then
            cancel_spell()
            add_to_chat(123, '** '..spell.english..' canceled: 3+ images remain **')
            eventArgs.handled = true
            return
        elseif buffactive['Copy Image'] or buffactive['Copy Image (2)'] then
            send_command('cancel 66; cancel 444; cancel "Copy Image"; cancel "Copy Image (2)"')
        end
    end
end

-- @ai:fn selected_ws_set | layer=gear | hot=yes | purity=read | contract=Resolve named/default WS, accuracy, and held SA/TA variants.
local function selected_ws_set(spell)
    local selected = sets.precast.WS[spell.english] or sets.precast.WS
    local want_acc = state.WeaponskillMode and state.WeaponskillMode.value == 'Acc'
    if want_acc and selected.Acc then selected = selected.Acc end
    local sata = sata_active()
    if sata and selected[sata] then selected = selected[sata] end
    return selected
end

-- @ai:fn job_post_precast | layer=framework | hot=yes | purity=write | contract=Apply final WS/JA/TH overlays; the last equip deliberately wins.
function job_post_precast(spell, action, spellMap, eventArgs)
    if spell.type == 'WeaponSkill' then
        equip(selected_ws_set(spell))
        if magical_ws_names:contains(spell.english) and spell_target_within(spell, 8) then
            equip({waist="Orpheus's Sash"})
        end
    elseif spell.type == 'Step' then
        equip(sets.precast.Step)
    elseif spell.type == 'Flourish1' then
        equip(sets.precast.Flourish1)
    elseif spell.type == 'Flourish2' then
        equip(sets.precast.Flourish2)
    elseif spell.type == 'Flourish3' then
        equip(sets.precast.Flourish3)
    elseif spell.type == 'Waltz' then
        if spell.english == 'Healing Waltz' then equip(sets.precast.HealingWaltz)
        else equip(spell.target and spell.target.type == 'SELF' and sets.precast.WaltzSelf or sets.precast.Waltz) end
    end

    local target_id = th_hostile_target_id(spell)
    if th_should_equip_for_target(target_id) then
        if th_target_needs_tag(target_id) then th_arm_target(target_id) end
        if spell.action_type == 'Ranged Attack' then equip(sets.TreasureHunter.RA)
        else equip(sets.TreasureHunter) end
    end
end

-- @ai:fn job_post_midcast | layer=framework | hot=yes | purity=write | contract=Hold TH through hostile magic/ranged impact while preserving the ranged weapon slot.
function job_post_midcast(spell, action, spellMap, eventArgs)
    local target_id = th_hostile_target_id(spell)
    if not th_should_equip_for_target(target_id) then return end
    if th_target_needs_tag(target_id) then th_arm_target(target_id) end
    if spell.action_type == 'Ranged Attack' then equip(sets.TreasureHunter.RA)
    else equip(sets.TreasureHunter) end
end

-- @ai:fn job_aftercast | layer=framework | hot=yes | purity=write | contract=Clear interrupted TH arms and restore weapon policy after actions.
function job_aftercast(spell, action, spellMap, eventArgs)
    if spell.interrupted then
        local id = spell.target and spell.target.id
        if id then th_runtime.armed[id] = nil end
    end
    if player and player.status ~= 'Engaged' then check_weaponset() end
    update_hud()
end

silence_echo = {attempts=0, active=false}

-- @ai:fn try_echo_drops | layer=qol | hot=no | purity=write | contract=Attempt at most three Echo Drops uses for one Silence instance.
function try_echo_drops()
    if THF_RUNTIME.unloading then return end
    if not (buffactive and buffactive.silence) then
        silence_echo.active, silence_echo.attempts = false, 0
        return
    end
    if silence_echo.attempts >= 3 then
        add_to_chat(123, '** Echo Drops cap reached; use Healing Waltz or wait for support. **')
        silence_echo.active = false
        return
    end
    silence_echo.attempts = silence_echo.attempts + 1
    send_command('input /item "Echo Drops" <me>')
    add_to_chat(123, '** Silenced: Echo Drops '..silence_echo.attempts..'/3 **')
    coroutine.schedule(try_echo_drops, 4)
end

-- @ai:fn job_buff_change | layer=framework | hot=yes | purity=write | contract=Refresh SA/TA, haste, Doom, silence, boost-ring, and HUD state on buff transitions.
function job_buff_change(buff, gain)
    local lower = tostring(buff):lower()
    if lower == 'silence' then
        if gain and not silence_echo.active then
            silence_echo.active, silence_echo.attempts = true, 0
            try_echo_drops()
        elseif not gain then
            silence_echo.active, silence_echo.attempts = false, 0
        end
    end

    if lower == 'doom' then
        if gain then
            if not swaps_frozen() then
                enable('neck','ring1','ring2','waist')
                equip(sets.buff.Doom)
                disable('neck','ring1','ring2','waist')
            end
            send_command('@input /p Doomed.')
            add_to_chat(167, '** DOOMED -- use Holy Water **')
        else
            if not swaps_frozen() then enable('neck','ring1','ring2','waist') end
            invalidate_ring_lock_cache()
            if player and not midaction() and not swaps_frozen() then handle_equipping_gear(player.status) end
        end
    end

    if gain and boost_buffs and boost_buffs:contains(lower) and player and player.equipment then
        local slots = {}
        if boost_gear:contains(player.equipment.left_ring) then slots[#slots + 1] = 'ring1' end
        if boost_gear:contains(player.equipment.right_ring) then slots[#slots + 1] = 'ring2' end
        release_ring_slots(slots, buff..' active')
    end

    local native_changed = update_native_haste_dw()
    if native_changed then update_dw_overlay() end
    if player and not swaps_frozen() and not midaction()
            and (native_changed or lower == 'sneak attack' or lower == 'trick attack') then
        handle_equipping_gear(player.status)
    end
    update_hud()
end

-- @ai:fn resume_swaps | layer=gear | hot=no | purity=write | contract=Restore all slots after the final full-freeze owner releases them.
function resume_swaps(message)
    enable(unpack(all_equip_slots))
    invalidate_ring_lock_cache()
    check_weaponset()
    if state.WeaponLock.value then disable('main','sub') end
    check_gear()
    handle_equipping_gear(player.status)
    if message then add_to_chat(158, message) end
end

-- @ai:fn job_state_change | layer=framework | hot=yes | purity=write | contract=Apply mode transitions without violating freeze, weapon, or async ownership.
function job_state_change(stateField, newValue, oldValue)
    local field = tostring(stateField or '')
    if (field == 'AutoSC' or field == 'Auto Skillchain') and newValue == false and sc_cancel then
        sc_cancel('toggle off')
    end

    if field == 'Weapon Set' or field == 'WeaponSet' then check_weaponset() end
    if field == 'Weapon Lock' or field == 'WeaponLock' then
        if not swaps_frozen() then
            if state.WeaponLock.value then check_weaponset(); disable('main','sub')
            else enable('main','sub'); check_weaponset() end
        end
    end

    if field == 'PauseSwaps' or field == 'Pause Gear Swapping' then
        if state.PauseSwaps.value then
            disable(unpack(all_equip_slots))
            add_to_chat(167, '** GearSwap PAUSED -- every slot frozen **')
        elseif state.FishingMode.value then
            add_to_chat(158, '** Pause off; Fishing Mode still owns the freeze **')
        else
            resume_swaps('** GearSwap RESUMED **')
        end
    end

    if field == 'FishingMode' or field == 'Fishing Mode' then
        if state.FishingMode.value then
            enable(unpack(all_equip_slots))
            equip(sets.Fishing)
            disable(unpack(all_equip_slots))
            add_to_chat(167, '** FISHING MODE -- gear equipped and slots frozen **')
        elseif state.PauseSwaps.value then
            add_to_chat(158, '** Fishing off; Pause still owns the freeze **')
        else
            resume_swaps('** Fishing off -- normal swaps resumed **')
        end
    end

    if field == 'Treasure Mode' or field == 'TreasureMode' then
        add_to_chat(158, '[TH] mode -> '..tostring(state.TreasureMode.value))
        if player and not swaps_frozen() and not midaction() then handle_equipping_gear(player.status) end
    end
    update_hud()
end

-- @ai:fn job_handle_equipping_gear | layer=framework | hot=yes | purity=write | contract=Refresh ring and native combat state before Mote resolves a set.
function job_handle_equipping_gear(playerStatus, eventArgs)
    check_gear()
    determine_haste_group()
end

-- @ai:fn job_update | layer=framework | hot=no | purity=write | contract=Force one normal Mote equipment resolution.
function job_update(cmdParams, eventArgs)
    if player then handle_equipping_gear(player.status) end
end

-- @ai:fn update_combat_form | layer=gear | hot=yes | purity=write | contract=Mirror authoritative native DW state into Mote CombatForm.
function update_combat_form()
    if not state or not state.CombatForm then return end
    if DW then state.CombatForm:set('DW') else state.CombatForm:reset() end
end

-- @ai:fn job_status_change | layer=framework | hot=yes | purity=write | contract=Cancel stale AutoSC work when leaving combat and refresh HUD.
function job_status_change(newStatus, oldStatus, eventArgs)
    if newStatus ~= 'Engaged' and sc_cancel then sc_cancel('status '..tostring(newStatus)) end
    update_hud()
end

-- @ai:fn job_sub_job_change | layer=framework | hot=no | purity=write | contract=Invalidate native trait state and re-resolve gear after a support-job change.
function job_sub_job_change(newSubjob, oldSubjob)
    native_state_active, native_state_haste, native_state_trait, native_state_need = nil, nil, nil, nil
    update_native_haste_dw(true)
    update_dw_overlay()
    if player and not swaps_frozen() then handle_equipping_gear(player.status) end
end

local shielded_weapon_sets = {}

-- @ai:fn check_weaponset | layer=gear | hot=yes | purity=write | contract=Equip the selected pair or cached shield fallback while respecting locks/freezes.
function check_weaponset()
    if not (state and state.WeaponSet and sets and player) or swaps_frozen() then return end
    local name = state.WeaponSet.value or state.WeaponSet.current
    local selected = sets[name]
    if not selected then add_to_chat(123, '[WeaponSet] missing set '..tostring(name)); return end

    local relock = state.WeaponLock and state.WeaponLock.value
    enable('main','sub')
    if dw_native_trait() > 0 then
        equip(selected)
    else
        if not shielded_weapon_sets[name] then
            shielded_weapon_sets[name] = set_combine(selected, sets.DefaultShield)
        end
        equip(shielded_weapon_sets[name])
    end
    if relock then disable('main','sub') end
end

-- @ai:fn select_default_macro_book | layer=framework | hot=no | purity=write | contract=Select the THF macro page and shared book.
function select_default_macro_book()
    set_macro_page(1, 11)
end

-- @ai:fn set_lockstyle | layer=framework | hot=no | purity=write | contract=Schedule the user-editable lockstyle command.
function set_lockstyle()
    send_command('wait 2; input /lockstyleset '..lockstyleset)
end

-------------------------------------------------------------------------------------------------------------------
-- Reactive AutoSC and the shared raw-action consumer
-------------------------------------------------------------------------------------------------------------------

local res = nil
do
    local ok, loaded = pcall(require, 'resources')
    if ok and type(loaded) == 'table' then
        res = loaded
    elseif type(_G) == 'table' and type(rawget(_G, 'res')) == 'table' then
        res = rawget(_G, 'res')
    end
end

local sc_property_keys = {'skillchain_a','skillchain_b','skillchain_c'}
local sc_ws_properties = {}

-- @ai:fn get_ws_properties | layer=autosc | hot=yes | purity=write | contract=Memoize immutable WS skillchain properties by resource ID.
local function get_ws_properties(ws_id, ws)
    local cached = sc_ws_properties[ws_id]
    if cached then return cached end
    cached = {}
    ws = ws or (res and res.weapon_skills and res.weapon_skills[ws_id])
    if ws then
        for _, key in ipairs(sc_property_keys) do
            local property = ws[key]
            if property and property ~= '' then cached[#cached + 1] = property end
        end
    end
    sc_ws_properties[ws_id] = cached
    return cached
end

local sc_combo = {
    Light         = {Light='Light'},
    Darkness      = {Darkness='Darkness'},
    Gravitation   = {Distortion='Darkness', Fragmentation='Fragmentation'},
    Fragmentation = {Fusion='Light', Distortion='Distortion'},
    Distortion    = {Gravitation='Darkness', Fusion='Fusion'},
    Fusion        = {Fragmentation='Light', Gravitation='Gravitation'},
    Compression   = {Transfixion='Transfixion', Detonation='Detonation'},
    Liquefaction  = {Impaction='Fusion', Scission='Scission'},
    Induration    = {Reverberation='Fragmentation', Compression='Compression', Impaction='Impaction'},
    Reverberation = {Induration='Induration', Impaction='Impaction'},
    Transfixion   = {Scission='Distortion', Reverberation='Reverberation', Compression='Compression'},
    Scission      = {Liquefaction='Liquefaction', Reverberation='Reverberation', Detonation='Detonation'},
    Detonation    = {Compression='Gravitation', Scission='Scission'},
    Impaction     = {Liquefaction='Liquefaction', Detonation='Detonation'},
}
local sc_level = {
    Light=3, Darkness=3, Radiance=3, Umbra=3,
    Gravitation=2, Fragmentation=2, Distortion=2, Fusion=2,
    Compression=1, Liquefaction=1, Induration=1, Reverberation=1,
    Transfixion=1, Scission=1, Detonation=1, Impaction=1,
}

autosc = {
    min_tp=1000,
    react_delay=3.0,
    window=6.0,
    retry_step=0.4,
    ws_cooldown=3.0,
    party_only=true,
    chain_pref='Light',
    ws_priority={"Rudra's Storm", 'Evisceration', 'Mandalic Stab', 'Savage Blade'},
    debug=false,
}
sc_react = {props=nil,target_id=nil,expires=0,opener='',last_ws=0,generation=0}

local party_member_keys = {'p0','p1','p2','p3','p4','p5'}

-- @ai:fn actor_is_party | layer=autosc | hot=yes | purity=read | contract=Accept only the six-person party, not alliance members.
local function actor_is_party(actor_id)
    if not actor_id or not (windower and windower.ffxi and windower.ffxi.get_party) then return false end
    local party = windower.ffxi.get_party()
    if not party then return false end
    for _, key in ipairs(party_member_keys) do
        local member = party[key]
        if member and ((member.mob and member.mob.id == actor_id) or member.id == actor_id) then return true end
    end
    return false
end

-- @ai:fn sc_cancel | layer=autosc | hot=no | purity=write | contract=Invalidate scheduled callbacks and clear active resonance.
function sc_cancel(reason)
    sc_react.generation = (sc_react.generation or 0) + 1
    sc_react.props, sc_react.target_id, sc_react.expires, sc_react.opener = nil, nil, 0, ''
    if autosc.debug and reason then add_to_chat(160, '[AutoSC dbg] cleared: '..tostring(reason)) end
end

-- @ai:fn sc_consume | layer=autosc | hot=yes | purity=write | contract=Consume one resonance and invalidate retries without chat noise.
local function sc_consume()
    sc_react.generation = sc_react.generation + 1
    sc_react.props, sc_react.target_id, sc_react.expires, sc_react.opener = nil, nil, 0, ''
end

-- @ai:fn sc_note_resonance | layer=autosc | hot=yes | purity=write | contract=Arm a generation-token reaction window and schedule one attempt.
function sc_note_resonance(properties, target_id, opener)
    if not (state and state.AutoSC and state.AutoSC.value) or not properties then return end
    sc_react.generation = sc_react.generation + 1
    local generation = sc_react.generation
    sc_react.props = type(properties) == 'table' and properties or {properties}
    sc_react.target_id = target_id
    sc_react.expires = monotonic_now() + autosc.window
    sc_react.opener = opener or ''
    coroutine.schedule(function() try_skillchain_react(target_id, generation) end, autosc.react_delay)
end

-- @ai:fn sc_track_ws_open | layer=autosc | hot=yes | purity=write | contract=Read a non-self party WS and arm its resonance properties.
function sc_track_ws_open(act)
    if not act or not (state and state.AutoSC and state.AutoSC.value) then return end
    if player and act.actor_id == player.id then return end
    if autosc.party_only and not actor_is_party(act.actor_id) then return end
    if not (res and res.weapon_skills) then
        add_to_chat(123, '[AutoSC] resources library unavailable.')
        return
    end
    local ws = res.weapon_skills[act.param]
    if not ws then return end
    local properties = get_ws_properties(act.param, ws)
    if #properties == 0 then return end
    local target_id
    for _, target in pairs(act.targets or {}) do target_id = target.id; break end
    if not target_id then return end
    if autosc.debug then
        add_to_chat(160, '[AutoSC dbg] '..tostring(ws.en)..' -> '..table.concat(properties, '/'))
    end
    sc_note_resonance(properties, target_id, ws.en)
end

-- @ai:fn pick_chain_ws | layer=autosc | hot=no | purity=read | contract=Rank currently usable WS closures by chain level and user priority.
local function pick_chain_ws(active_properties)
    if not (res and res.weapon_skills) then return nil end
    local abilities = windower.ffxi.get_abilities()
    local usable = abilities and abilities.weapon_skills
    if not usable then return nil end
    local priority = {}
    for index, name in ipairs(autosc.ws_priority) do priority[name] = #autosc.ws_priority - index + 1 end
    local best, best_rank
    for _, ws_id in ipairs(usable) do
        local ws = res.weapon_skills[ws_id]
        if ws then
            for _, mine in ipairs(get_ws_properties(ws_id, ws)) do
                for _, active in ipairs(active_properties) do
                    local result = sc_combo[active] and sc_combo[active][mine]
                    if result then
                        local rank = (sc_level[result] or 1) * 10000
                            + ((result == autosc.chain_pref) and 1000 or 0)
                            + (priority[ws.en] or 0)
                        if not best_rank or rank > best_rank then
                            best_rank = rank
                            best = {name=ws.en,result=result,level=sc_level[result] or 1}
                        end
                    end
                end
            end
        end
    end
    return best
end

-- @ai:fn try_skillchain_react | layer=autosc | hot=yes | purity=write | contract=Generation-safely validate target, combat, TP, and WS immediately before firing.
function try_skillchain_react(target_id, generation)
    if THF_RUNTIME.unloading or not (state and state.AutoSC and state.AutoSC.value) then return end
    if generation ~= sc_react.generation or not sc_react.props then return end
    local now = monotonic_now()
    if now > sc_react.expires then sc_cancel('window expired'); return end

    local target = current_target()
    if not target or (sc_react.target_id and target.id ~= sc_react.target_id) then
        sc_cancel('target changed')
        return
    end
    if not player or player.status ~= 'Engaged' then sc_cancel('not engaged'); return end
    if midaction() or now - sc_react.last_ws < autosc.ws_cooldown then return end

    if (player.tp or 0) < autosc.min_tp then
        if sc_react.expires - now > autosc.retry_step then
            coroutine.schedule(function() try_skillchain_react(target_id, generation) end, autosc.retry_step)
        end
        return
    end
    local choice = pick_chain_ws(sc_react.props)
    if not choice then
        if autosc.debug then add_to_chat(160, '[AutoSC dbg] no usable closer for '..table.concat(sc_react.props, '/')) end
        return
    end
    sc_react.last_ws = now
    sc_consume()
    add_to_chat(158, string.format('[AutoSC] %s (Lv%d) with %s.', choice.result, choice.level, choice.name))
    send_command('input /ws "'..choice.name..'" <t>')
end

-- @ai:fn sc_selftest | layer=autosc | hot=no | purity=read | contract=Print resources, target, usable WS, and resonance diagnostics.
function sc_selftest()
    add_to_chat(158, '=== THF AutoSC self-test ===')
    add_to_chat(158, string.format('mode=%s resources=%s TP=%s status=%s target=%s',
        tostring(state and state.AutoSC and state.AutoSC.value), tostring(res ~= nil),
        tostring(player and player.tp), tostring(player and player.status),
        tostring(current_target() and current_target().name or 'none')))
    if res and res.weapon_skills then
        local abilities = windower.ffxi.get_abilities()
        for _, id in ipairs(abilities and abilities.weapon_skills or {}) do
            local ws = res.weapon_skills[id]
            if ws then add_to_chat(158, '  '..ws.en..' ['..table.concat(get_ws_properties(id, ws), '/')..']') end
        end
    end
end

-- @ai:fn handle_action_packet | layer=treasure | hot=yes | purity=write | contract=Share one early-exit raw action listener between TH confirmation and AutoSC opener tracking.
local function handle_action_packet(act)
    if not act or not act.targets or not player then return end
    th_cleanup(false)

    -- Keep the three-minute TTL tied to actual battle activity, matching the
    -- community utility without its additional incoming-chunk listener.
    local now = monotonic_now()
    if th_runtime.tagged[act.actor_id] then th_runtime.tagged[act.actor_id] = now end
    for _, target in pairs(act.targets) do
        if target.id and th_runtime.tagged[target.id] then th_runtime.tagged[target.id] = now end
    end

    if act.actor_id == player.id then
        for _, target in pairs(act.targets) do
            if target.id and th_runtime.armed[target.id] then th_mark_tagged(target.id) end
        end
    elseif act.category == 3 and state and state.AutoSC and state.AutoSC.value then
        sc_track_ws_open(act)
    end
end

track_thf_event(windower.raw_register_event('action', handle_action_packet))
track_thf_event(windower.register_event('prerender', movement_sample))

track_thf_event(windower.register_event('zone change', function()
    th_reset(false)
    if sc_cancel then sc_cancel('zone change') end
    motion_runtime.x, motion_runtime.y, motion_runtime.z = nil, nil, nil
    motion_runtime.target_id, motion_runtime.last_motion = nil, 0
    moving = false
    if not player or not player.equipment then return end
    local released = false
    if warp_gear and warp_gear:contains(player.equipment.left_ring) then enable('ring1'); released = true end
    if warp_gear and warp_gear:contains(player.equipment.right_ring) then enable('ring2'); released = true end
    if released then
        invalidate_ring_lock_cache()
        coroutine.schedule(function()
            if not THF_RUNTIME.unloading and player and not swaps_frozen() then handle_equipping_gear(player.status) end
        end, 2)
    end
end))

-------------------------------------------------------------------------------------------------------------------
-- Compact HUD
-------------------------------------------------------------------------------------------------------------------

hud_settings = {
    pos={x=675,y=950},
    text={size=10,font='Consolas',alpha=255,
        stroke={width=2,alpha=255,red=0,green=0,blue=0}},
    bg={alpha=190,red=8,green=10,blue=14},
    flags={draggable=false},
}
hud, hud_last_text, hud_visible = nil, nil, true
local hud_colors = {
    label='\\cs(205,210,220)', value='\\cs(248,248,250)', cyan='\\cs(105,210,235)',
    green='\\cs(115,225,145)', yellow='\\cs(245,210,100)', orange='\\cs(245,165,90)',
    red='\\cs(255,105,115)', dim='\\cs(135,140,150)',
}

-- @ai:fn hud_color | layer=hud | hot=yes | purity=read | contract=Wrap one HUD value in a color escape sequence.
local function hud_color(name, value)
    return (hud_colors[name] or '')..tostring(value or '')..'\\cr'
end

-- @ai:fn hud_pill | layer=hud | hot=yes | purity=read | contract=Format one compact labeled status token.
local function hud_pill(label, value, color)
    return hud_color('dim','[')..hud_color('label',label..':')
        ..hud_color(color or 'value',value)..hud_color('dim',']')
end

-- @ai:fn hud_onoff | layer=hud | hot=yes | purity=read | contract=Render a nil-safe boolean mode.
local function hud_onoff(mode)
    local enabled = mode and mode.value
    return enabled and 'ON' or 'off', enabled and 'green' or 'dim'
end

-- @ai:fn init_hud | layer=hud | hot=no | purity=write | contract=Create the texts object once at the shared RDM position.
function init_hud()
    local ok, texts = pcall(require, 'texts')
    if not ok or not texts then add_to_chat(167, '[HUD] texts library unavailable.'); return end
    hud = texts.new('', hud_settings)
    update_hud(true)
    if hud_visible then hud:show() end
end

-- @ai:fn update_hud | layer=hud | hot=yes | purity=write | contract=Render cached runtime state only and suppress identical redraws.
function update_hud(force)
    if not hud or (not hud_visible and not force) then return end
    local target = current_target()
    local target_state = 'NO TARGET'
    local target_color = 'dim'
    if target then
        if th_mode() == 'None' then target_state, target_color = 'TH OFF', 'dim'
        elseif th_target_needs_tag(target.id) then target_state, target_color = 'NEED TAG', 'yellow'
        else target_state, target_color = 'TAGGED', 'green' end
    end

    local trait = dw_native_trait()
    local dw_text, dw_color = '--', 'dim'
    if DW then
        dw_text = string.format('%d+%d/%d',trait,dw_have or 0,trait+(DW_needed or 0))
        dw_color = dw_shortfall and 'red' or 'green'
    end
    local actual_ring = player and player.equipment and player.equipment.right_ring or '-'
    local moving_now = moving or (state and state.Auto_Kite and state.Auto_Kite.value)
    local ring_good = not moving_now or actual_ring == 'Shneddick Ring'
    local sata = sata_active() or '--'
    local sc_text, sc_color = hud_onoff(state and state.AutoSC)

    local lines = {
        hud_color('value','THF STATUS')..hud_color('dim','  v'..THF_RELEASE_VERSION),
        hud_color('dim','----------------------------------------'),
        hud_pill('WPN',state and state.WeaponSet and state.WeaponSet.value or '-', 'cyan')..' '
            ..hud_pill('ATK',state and state.OffenseMode and state.OffenseMode.value or '-')..' '
            ..hud_pill('HYB',state and state.HybridMode and state.HybridMode.value or '-')..' '
            ..hud_pill('WS',state and state.WeaponskillMode and state.WeaponskillMode.value or '-'),
        hud_pill('DW',dw_text,dw_color)..' '..hud_pill('Haste',string.format('%.1f%%',(Haste or 0)/10.24),'cyan')..' '
            ..hud_pill('Move',moving_now and 'ON' or 'off',moving_now and 'yellow' or 'dim')..' '
            ..hud_pill('Ring',actual_ring,ring_good and 'green' or 'red'),
        hud_pill('TH',th_mode(),'cyan')..' '..hud_pill('Target',target_state,target_color)..' '
            ..hud_pill('SA/TA',sata,sata ~= '--' and 'yellow' or 'dim'),
        hud_pill('AutoSC',sc_text,sc_color)..' '
            ..hud_pill('Pause',state and state.PauseSwaps and state.PauseSwaps.value and 'ON' or 'off',
                state and state.PauseSwaps and state.PauseSwaps.value and 'red' or 'dim')..' '
            ..hud_pill('Fishing',state and state.FishingMode and state.FishingMode.value and 'ON' or 'off',
                state and state.FishingMode and state.FishingMode.value and 'cyan' or 'dim'),
    }
    local text = table.concat(lines,'\n')
    if text ~= hud_last_text then hud_last_text = text; hud:text(text) end
end

-- @ai:fn toggle_hud | layer=hud | hot=no | purity=write | contract=Toggle HUD visibility without hidden redraw work.
function toggle_hud()
    if not hud then return end
    hud_visible = not hud_visible
    if hud_visible then update_hud(true); hud:show() else hud:hide() end
end

-- @ai:fn toggle_hud_lock | layer=hud | hot=no | purity=write | contract=Toggle HUD drag ownership and report the result.
function toggle_hud_lock()
    if not hud then return end
    local draggable = hud:draggable()
    hud:draggable(not draggable)
    add_to_chat(158, draggable and '[HUD] locked.' or '[HUD] unlocked; drag to reposition.')
end

-------------------------------------------------------------------------------------------------------------------
-- Command routing
-------------------------------------------------------------------------------------------------------------------

-- @ai:fn drain_chat_queue | layer=utility | hot=no | purity=write | contract=Emit one queued report line per private command tick.
local function drain_chat_queue(queue, index, next_command)
    if not queue or not queue[index] then return nil, 1 end
    add_to_chat(queue[index].c, queue[index].m)
    index = index + 1
    if queue[index] then
        windower.send_command('wait 0.05; gs c '..next_command)
        return queue, index
    end
    return nil, 1
end

-- @ai:fn print_keybinds | layer=command | hot=no | purity=write | contract=Print the complete mode key map.
function print_keybinds()
    add_to_chat(158, '=== THF keybinds (Win+key; ^ = Ctrl+Win) ===')
    add_to_chat(158, ' T TreasureMode | W WeaponLock | C AutoSC | E/R Weapon -/+')
    add_to_chat(158, ' A AuditGear | P Pause | F Fishing | H HUD | ^H HUD-lock | Z Silmaril')
    add_to_chat(158, ' F9 offense | Ctrl+F9 hybrid | Win+F9 WS | F10/F11 defense | F12 update')
    add_to_chat(158, ' typed: thinfo | threset | dwinfo | hastecheck | hastetier 1|2 | hasteadj <pct>')
end

-- @ai:fn display_current_job_state | layer=framework | hot=no | purity=write | contract=Provide F12-compatible current mode reporting.
function display_current_job_state(eventArgs)
    add_to_chat(158, string.format('[THF] WPN=%s ATK=%s HYB=%s WS=%s TH=%s AutoSC=%s',
        state.WeaponSet.value, state.OffenseMode.value, state.HybridMode.value,
        state.WeaponskillMode.value, state.TreasureMode.value, tostring(state.AutoSC.value)))
    report_dw_tier()
    if eventArgs then eventArgs.handled = true end
end

-- @ai:fn job_self_command | layer=command | hot=no | purity=write | contract=Route THF diagnostics and let Mote own standard mode commands.
function job_self_command(cmdParams, eventArgs)
    local command = tostring(cmdParams[1] or ''):lower()
    local handled = true
    if command == 'version' then
        add_to_chat(158, string.format('[THF] Falurian GearSwap v%s (%s)',THF_RELEASE_VERSION,THF_RELEASE_DATE))
    elseif command == 'hud' then toggle_hud()
    elseif command == 'hudlock' then toggle_hud_lock()
    elseif command == 'keys' then print_keybinds()
    elseif command == 'thinfo' then report_th_info()
    elseif command == 'threset' then th_reset(true)
    elseif command == 'thdebug' then
        th_runtime.debug = not th_runtime.debug
        add_to_chat(158, '[TH] debug '..(th_runtime.debug and 'ON' or 'OFF'))
    elseif command == 'dwinfo' then report_dw_tier()
    elseif command == 'hastecheck' then report_haste_check()
    elseif command == 'hastetier' then
        local tier = tostring(cmdParams[2] or ''):lower()
        if tier == '1' or tier == 'haste' then haste_assume.magic.Haste = 150
        elseif tier == '2' or tier == 'haste2' or tier == 'hasteii' then haste_assume.magic.Haste = 307
        else
            add_to_chat(158, string.format('[Haste] icon assumption %.1f%%; usage: gs c hastetier 1|2',haste_assume.magic.Haste/10.24))
            if eventArgs then eventArgs.handled = true end
            return
        end
        update_native_haste_dw(true); update_dw_overlay()
        if player and not swaps_frozen() and not midaction() then handle_equipping_gear(player.status) end
        add_to_chat(158, '[Haste] shared icon assumption -> Haste '..(haste_assume.magic.Haste == 150 and 'I' or 'II'))
    elseif command == 'hasteadj' then
        local pct = tonumber(cmdParams[2])
        if pct then
            haste_manual_magic = math.floor(pct * 10.24 + 0.5)
            update_native_haste_dw(true); update_dw_overlay()
            if player and not swaps_frozen() and not midaction() then handle_equipping_gear(player.status) end
            add_to_chat(158, string.format('[Haste] manual magic adjustment %+.1f%%',pct))
        else add_to_chat(158, string.format('[Haste] manual adjustment %+.1f%%; usage: gs c hasteadj <pct>',haste_manual_magic/10.24)) end
    elseif command == 'scdelay' then
        local delay = tonumber(cmdParams[2])
        if delay then autosc.react_delay = math.max(0.5,math.min(5,delay)) end
        add_to_chat(158,string.format('[AutoSC] reaction delay %.1fs',autosc.react_delay))
    elseif command == 'sctest' then sc_selftest()
    elseif command == 'scdebug' then
        autosc.debug = not autosc.debug
        add_to_chat(158,'[AutoSC] debug '..(autosc.debug and 'ON' or 'OFF'))
    elseif command == 'auditgear' then audit_gear()
    elseif command == '_auditdrain' then
        audit_queue, audit_queue_index = drain_chat_queue(audit_queue,audit_queue_index,'_auditdrain')
    elseif command == 'gearinfo' then
        gearinfo(cmdParams,eventArgs)
        return
    else handled = false end
    if handled and eventArgs then eventArgs.handled = true end
end

-------------------------------------------------------------------------------------------------------------------
-- Gear audit (command-driven; paced output)
-------------------------------------------------------------------------------------------------------------------

local audit_slots = S{
    'main','sub','range','ammo','head','neck','ear1','ear2','left_ear','right_ear',
    'body','hands','ring1','ring2','left_ring','right_ring','back','waist','legs','feet',
}
local audit_skip = S{'empty',''}

-- @ai:fn audit_item_name | layer=audit | hot=no | purity=pure | contract=Normalize a string or augmented GearSwap item reference.
local function audit_item_name(reference)
    if type(reference) == 'string' then return reference end
    if type(reference) == 'table' and type(reference.name) == 'string' then return reference.name end
end

-- @ai:fn audit_record_set | layer=audit | hot=no | purity=write | contract=Record item paths and maximum simultaneous copy requirements for one set.
local function audit_record_set(tbl, path, found)
    local direct = {}
    for slot, reference in pairs(tbl) do
        if type(slot) == 'string' and audit_slots:contains(slot) then
            local name = audit_item_name(reference)
            if name then direct[name] = (direct[name] or 0) + 1 end
        end
    end
    for slot, count in pairs(direct) do
        local entry = found[slot]
        if not entry then entry = {paths={},seen={},copies=1}; found[slot] = entry end
        entry.copies = math.max(entry.copies,count)
    end
    for slot, reference in pairs(tbl) do
        if type(slot) == 'string' and audit_slots:contains(slot) then
            local name = audit_item_name(reference)
            if name then
                local entry = found[name]
                if not entry then entry = {paths={},seen={},copies=1}; found[name] = entry end
                local location = path..' ['..slot..']'
                if not entry.seen[location] then
                    entry.seen[location] = true
                    entry.paths[#entry.paths + 1] = location
                end
            end
        end
    end
end

-- @ai:fn audit_collect_sets | layer=audit | hot=no | purity=write | contract=Cycle-safely walk nested gear sets without treating augment strings as items.
local function audit_collect_sets(tbl, path, found, visited)
    if type(tbl) ~= 'table' or visited[tbl] then return end
    visited[tbl] = true
    audit_record_set(tbl,path,found)
    for key, value in pairs(tbl) do
        if type(value) == 'table' and key ~= 'augments' and not audit_slots:contains(key) then
            audit_collect_sets(value,path..'.'..tostring(key),found,visited)
        end
    end
end

-- @ai:fn audit_add_bag | layer=audit | hot=no | purity=write | contract=Accumulate accessible or stored item counts from a GearSwap player bag table.
local function audit_add_bag(catalog, label, bag, accessible)
    if type(bag) ~= 'table' then return end
    for name, data in pairs(bag) do
        if type(name) == 'string' then
            local entry = catalog[name]
            if not entry then entry = {accessible=0,stored=0,bags={}}; catalog[name] = entry end
            local count = type(data) == 'table' and tonumber(data.count) or 1
            count = math.max(1,count or 1)
            if accessible then entry.accessible = entry.accessible + count
            else entry.stored = entry.stored + count end
            entry.bags[label] = true
        end
    end
end

-- @ai:fn audit_jobs_allow_thf | layer=audit | hot=no | purity=pure | contract=Tri-state ItemStats THF eligibility check.
local function audit_jobs_allow_thf(stats)
    if not stats or not stats.jobs then return nil end
    if stats.jobs == 'ALL' then return true end
    return ('/'..stats.jobs..'/'):find('/THF/',1,true) ~= nil
end

-- @ai:fn audit_paths | layer=audit | hot=no | purity=read | contract=Create a compact path suffix for one audit finding.
local function audit_paths(entry)
    if not entry or #entry.paths == 0 then return '' end
    local shown = {}
    for i = 1, math.min(2,#entry.paths) do shown[#shown + 1] = entry.paths[i] end
    local suffix = #entry.paths > 2 and ('; +'..(#entry.paths-2)..' more') or ''
    return ' -> '..table.concat(shown,'; ')..suffix
end

-- @ai:fn audit_gear | layer=audit | hot=no | purity=write | contract=Validate availability, duplicates, ItemStats coverage, and THF eligibility asynchronously.
function audit_gear()
    if not (sets and player) then add_to_chat(123,'[Audit] sets/player not ready.'); return end
    local references = {}
    audit_collect_sets(sets,'sets',references,{})

    local catalog = {}
    for _, bag in ipairs({
        {'Inventory',player.inventory},{'Wardrobe',player.wardrobe},{'Wardrobe 2',player.wardrobe2},
        {'Wardrobe 3',player.wardrobe3},{'Wardrobe 4',player.wardrobe4},{'Wardrobe 5',player.wardrobe5},
        {'Wardrobe 6',player.wardrobe6},{'Wardrobe 7',player.wardrobe7},{'Wardrobe 8',player.wardrobe8},
    }) do audit_add_bag(catalog,bag[1],bag[2],true) end
    for _, bag in ipairs({
        {'Mog Safe',player.safe},{'Mog Safe 2',player.safe2},{'Storage',player.storage},
        {'Satchel',player.satchel},{'Sack',player.sack},{'Case',player.case},{'Locker',player.locker},
    }) do audit_add_bag(catalog,bag[1],bag[2],false) end

    local missing, inaccessible, copies, non_thf, uncatalogued = {},{},{},{},{}
    local checked = 0
    for name, reference in pairs(references) do
        if not audit_skip:contains(name) then
            checked = checked + 1
            local owned = catalog[name]
            if not owned then
                missing[#missing + 1] = {name=name,ref=reference}
            elseif owned.accessible == 0 and owned.stored > 0 then
                inaccessible[#inaccessible + 1] = {name=name,count=owned.stored,ref=reference}
            elseif owned.accessible < reference.copies then
                copies[#copies + 1] = {name=name,need=reference.copies,have=owned.accessible,ref=reference}
            end
            local eligible = audit_jobs_allow_thf(item_stats and item_stats[name])
            if eligible == false then
                non_thf[#non_thf + 1] = {name=name,jobs=item_stats[name].jobs,ref=reference}
            elseif eligible == nil then
                uncatalogued[#uncatalogued + 1] = {name=name,ref=reference}
            end
        end
    end
    -- @ai:fn sort | layer=audit | hot=no | purity=write | contract=Sort one local finding list by item name.
    local function sort(list) table.sort(list,function(a,b) return a.name < b.name end) end
    sort(missing); sort(inaccessible); sort(copies); sort(non_thf); sort(uncatalogued)

    audit_queue, audit_queue_index = {},1
    -- @ai:fn line | layer=audit | hot=no | purity=write | contract=Append one paced audit output row.
    local function line(color,message) audit_queue[#audit_queue + 1] = {c=color,m=message} end
    line(158,string.format('=== THF Gear Audit: %d unique items ===',checked))
    if #missing+#inaccessible+#copies+#non_thf == 0 then
        line(158,'PASS: active references are accessible, sufficiently duplicated, and THF-equippable.')
    end
    if #missing > 0 then
        line(167,'MISSING / NAME MISMATCH ('..#missing..'):')
        for _, item in ipairs(missing) do line(167,'  '..item.name..audit_paths(item.ref)) end
    end
    if #inaccessible > 0 then
        line(167,'STORED OUTSIDE ACCESSIBLE BAGS ('..#inaccessible..'):')
        for _, item in ipairs(inaccessible) do line(167,string.format('  %s x%d%s',item.name,item.count,audit_paths(item.ref))) end
    end
    if #copies > 0 then
        line(167,'INSUFFICIENT ACCESSIBLE COPIES ('..#copies..'):')
        for _, item in ipairs(copies) do line(167,string.format('  %s needs %d, has %d%s',item.name,item.need,item.have,audit_paths(item.ref))) end
    end
    if #non_thf > 0 then
        line(167,'NOT THF-EQUIPPABLE ('..#non_thf..'):')
        for _, item in ipairs(non_thf) do line(167,'  '..item.name..' ['..item.jobs..']'..audit_paths(item.ref)) end
    end
    if #uncatalogued > 0 then
        line(159,'ITEMSTATS COVERAGE UNKNOWN ('..#uncatalogued..'):')
        for _, item in ipairs(uncatalogued) do line(159,'  '..item.name) end
    end
    line(158,string.format('Summary: missing=%d stored=%d copies=%d nonTHF=%d uncatalogued=%d',
        #missing,#inaccessible,#copies,#non_thf,#uncatalogued))
    line(158,'=== THF Gear Audit Done ===')
    windower.send_command('gs c _auditdrain')
end
