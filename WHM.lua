-------------------------------------------------------------------------------------------------------------------
-- WHM.lua -- built from the Falurian NIN/RDM templates (Mote v2)
-- Subjob assumption: flexible (/SCH for Light Arts+stratagems+Regen, /RDM for Refresh+haste,
--  /BLM for Warp/Sleep utility). Scholar stratagem shortcut is included below for /SCH.
--
--  Keybind philosophy: mode changes only. No spell/ability binds -- use in-game
--  macros for casting. All binds live on F9-F12 (Mote defaults) or Win+letter.
--
--  Modes:      [ CTRL+F9 ]         Cycle Hybrid Modes (-PDT overlay while curing)
--              [ F10 ]             Emergency -PDT Mode
--              [ ALT+F10 ]         Toggle Kiting Mode
--              [ F11 ]             Emergency -MDT Mode
--              [ CTRL+F11 ]        Cycle Casting Modes (Normal/Resistant -- MAcc for enfeebles)
--              [ F12 ]             Update Current Gear / Report Current Status
--              [ CTRL+F12 ]        Cycle Idle Modes (Normal/Town/DT)
--              [ ALT+F12 ]         Cancel Emergency -PDT/-MDT Mode
--
--  Win+letter: [ WIN+B ]           Toggle Magic Burst Mode (Banish/Holy magic burst gear)
--              [ WIN+W ]           Toggle Weapon Lock
--              [ WIN+E ]           Cycle Weapon Set (back)
--              [ WIN+R ]           Cycle Weapon Set (forward)
--              [ WIN+A ]           Audit Gear (check sets vs. inventory)
--
--  Typed/macro commands:
--      gs c barelement     -- casts your currently selected Bar-element spell on self
--      gs c barstatus      -- casts your currently selected Bar-status spell on self
--      gs c scholar light|dark|speed|cost|aoe|addendum   (only relevant if subbing /SCH)
--
--  WEAPON POLICY: main-hand WHM club (Queller Rod) is job-locked WHM and carries
--  Enmity-10 / Cure potency II+2% / Refresh+1 -- excellent all-purpose main.
--  Chatoyant Staff (all-jobs) is the weather-cure alternative: +10% Cure potency,
--  and its Iridescence effect adds another +10% during matching weather/day.
--  Ammurapi Shield rides in the sub slot for general FC/MP/Refresh; the game also
--  lets a Rod/Club ride in "sub" as an off-hand catalyst for extra stats -- Queller
--  Rod and Enki Strap are used that way in a couple of the sets below.
--
--  GEAR NOTE: every job-restricted piece below was checked against FFXIAH's job
--  list for this character's current inventory export. Kaykaus (WHM Empyrean),
--  Theophany (WHM AF3/Reforged), Vanya (WHM Relic, partial -- only Hood/Clogs
--  owned), Telchine (older Empyrean, multi-job incl. WHM), Nyame (all jobs), and
--  Cleric's Torque/Queller Rod (WHM-only) are all confirmed WHM-equippable.
--  Pieces that turned out to be OTHER jobs' AF3/Empyrean (Vitiation/Atrophy=RDM,
--  Jhakri/Inyanga/Tali'ah=BLM, Malignance=melee/hybrid jobs, Amalric=BLM/RDM/SMN/
--  BLU/SCH/GEO, Mpaca's=RUN, Mummu/Cirque/Maxixi=DNC, Baayami=BLU, Mallquis=GEO,
--  Meghanada=RNG, Ayanmo=WAR) were deliberately left out.
-------------------------------------------------------------------------------------------------------------------

function get_sets()
    mote_include_version = 2
    include('Mote-Include.lua')
end

function job_setup()
    -- Rings that must STAY ON once you manually equip them -- GearSwap will not
    -- swap them off. Split by what RELEASES them back to normal gear:
    --   warp_gear  -> released on ZONE CHANGE  (you've arrived; normal rings return)
    --   boost_gear -> released when the EXP/CP boost BUFF lands (the effect is used)
    warp_gear  = S{"Warp Ring", "Dim. Ring (Dem)", "Dim. Ring (Holla)", "Dim. Ring (Mea)"}
    boost_gear = S{"Trizek Ring", "Echad Ring", "Facility Ring", "Capacity Ring",
                   "Jubilee Ring", "Empress Band"}
    no_swap_gear = S{"Warp Ring", "Dim. Ring (Dem)", "Dim. Ring (Holla)", "Dim. Ring (Mea)",
                     "Trizek Ring", "Echad Ring", "Facility Ring", "Capacity Ring",
                     "Jubilee Ring", "Empress Band"}

    -- Buffs that mean a boost ring's effect is now active (so the ring can come off).
    boost_buffs = S{'dedication', 'commitment'}

    -- Slots momentarily being released (so check_gear lets the normal ring return)
    releasing = {ring1=false, ring2=false}

    -- WHM's whole enfeebling toolkit is MND-based (Dia line, Paralyze, Slow).
    -- Kept as a simple set for job_get_spell_map routing below.
    whm_enfeebles = S{'Dia', 'Dia II', 'Dia III', 'Diaga', 'Paralyze', 'Paralyze II', 'Slow', 'Slow II'}
    divine_magic  = S{'Banish', 'Banish II', 'Banish III', 'Banishga', 'Banishga II', 'Holy', 'Holy II', 'Flash', 'Repose'}
    status_removal_spells = S{'Poisona', 'Paralyna', 'Blindna', 'Stona', 'Silena', 'Viruna', 'Cursna'}
    bar_element_spells = S{'Barfire', 'Barblizzard', 'Baraero', 'Barstone', 'Barthunder', 'Barwater',
                            'Barfira', 'Barblizzara', 'Baraera', 'Barstonra', 'Barthundra', 'Barwatra'}
    bar_status_spells  = S{'Baramnesia', 'Barvirus', 'Barparalyze', 'Barsilence', 'Barpetrify', 'Barpoison',
                            'Barblind', 'Barsleep', 'Baramnesra', 'Barvira', 'Barparalyzra', 'Barsilencera',
                            'Barpetra', 'Barpoisonra', 'Barblindra', 'Barsleepra'}

    state.Buff.Doom = buffactive.doom or false

    lockstyleset = 1   -- adjust to your WHM lockstyle set number
end

function user_setup()
    state.HybridMode:options('Normal', 'PDT')
    state.CastingMode:options('Normal', 'Resistant')
    state.IdleMode:options('Normal', 'Town', 'DT')

    state.BarElement = M{['description']='BarElement', 'Barfire', 'Barblizzard', 'Baraero', 'Barstone', 'Barthunder', 'Barwater'}
    state.BarStatus  = M{['description']='BarStatus', 'Baramnesia', 'Barvirus', 'Barparalyze', 'Barsilence', 'Barpetrify', 'Barpoison', 'Barblind', 'Barsleep'}

    state.WeaponSet = M{['description']='Weapon Set', 'QuellerRod', 'ChatoyantStaff'}
    state.WeaponLock = M(true, 'Weapon Lock')
    state.MagicBurst = M(false, 'Magic Burst')
    state.Auto_Kite = M(false, 'Auto_Kite')

    -- Apply weapon lock immediately on load (job_state_change only fires on changes)
    if state.WeaponLock.value == true then
        disable('main','sub','range')
    end

    -- Mode-change binds only. F9-F12 come from Mote-Include.
    send_command('bind @b gs c toggle MagicBurst')
    send_command('bind @w gs c toggle WeaponLock')
    send_command('bind @e gs c cycleback WeaponSet')
    send_command('bind @r gs c cycle WeaponSet')
    send_command('bind @a gs c auditgear')

    select_default_macro_book()
    set_lockstyle()

    update_combat_form()
end

function user_unload()
    send_command('unbind @b')
    send_command('unbind @w')
    send_command('unbind @e')
    send_command('unbind @r')
    send_command('unbind @a')
end

function init_gear_sets()

    ------------------------------------------------------------------------------------------------
    ----------------------------------------- Precast Sets ------------------------------------------
    ------------------------------------------------------------------------------------------------

    -- Fast Cast: general FC gear for every spell. Cure-specific "cure spellcasting
    -- time" pieces (Kaykaus/Vanya/Theophany) live in midcast.Cure -- see note there.
    sets.precast.FC = {
        ammo="Impatiens",          --Quick Magic 2
        neck="Null Loop",          --FC neck
        ear1="Loquac. Earring",    --FC 2
        ear2="Etiolation Earring", --FC 1
        ring1="Kishar Ring",       --FC 4
        ring2="Lebeche Ring",      --Quick Magic +2% (stacks w/ Witful)
        back={ name="Sucellos's Cape", augments={'MND+20','Mag. Acc+20 /Mag. Dmg.+20','MND+10','"Fast Cast"+10','Damage taken-5%',}},
        waist="Witful Belt",       --FC 3 + Quick Magic proc
        }

    sets.precast.FC.Cure = set_combine(sets.precast.FC, {})
    sets.precast.FC.Curaga = sets.precast.FC.Cure
    sets.precast.FC['Healing Magic'] = sets.precast.FC.Cure
    sets.precast.FC['Enhancing Magic'] = set_combine(sets.precast.FC, {})
    sets.precast.FC['Enfeebling Magic'] = set_combine(sets.precast.FC, {})
    sets.precast.FC['Divine Magic'] = set_combine(sets.precast.FC, {})
    sets.precast.FC.Teleport = sets.precast.FC
    sets.precast.FC.Raise = set_combine(sets.precast.FC, {})
    sets.precast.FC.Reraise = sets.precast.FC.Raise


    ------------------------------------------------------------------------------------------------
    ------------------------------------- Weapon Skill Sets -----------------------------------------
    ------------------------------------------------------------------------------------------------
    -- WHM rarely weaponskills (Judgment/Vidohunir on occasion). Minimal MND/MAcc set.

    sets.precast.WS = {
        main="Queller Rod",
        sub="Ammurapi Shield",
        ammo="Ghastly Tathlum +1",
        head="Kaykaus Mitra +1",
        body="Kaykaus Bliaut +1",
        hands="Theophany Mitts +3",
        legs="Kaykaus Tights +1",
        feet="Kaykaus Boots +1",
        neck="Cleric's Torque",
        ear1="Enchntr. Earring +1",
        ear2="Snotra Earring",
        ring1="Stikini Ring +1",
        ring2="Menelaus's Ring",
        back={ name="Sucellos's Cape", augments={'MND+20','Mag. Acc+20 /Mag. Dmg.+20','MND+10','"Fast Cast"+10','Damage taken-5%',}},
        waist="Acuity Belt +1",
        }


    ------------------------------------------------------------------------------------------------
    ---------------------------------------- Midcast Sets ------------------------------------------
    ------------------------------------------------------------------------------------------------

    sets.midcast.FastRecast = sets.precast.FC

    sets.midcast.SpellInterrupt = {
        ammo="Staunch Tathlum +1", --SIRD
        ring2="Evanescence Ring",  --SIRD
        }

    -- Core Cure set. Kaykaus is WHM's own current-tier Empyrean (LV99 WHM/RDM/BRD/
    -- SCH) so it's the single best block of Cure potency/MND/MP/Enmity- available.
    sets.midcast.Cure = {
        main="Queller Rod",       --Enmity-10, Cure potency II+2%, Refresh+1
        sub="Ammurapi Shield",
        ammo="Staunch Tathlum +1",
        head="Kaykaus Mitra +1",  --MP+80, MND+12, Mag. Acc.+20
        body="Kaykaus Bliaut +1", --MP+80, MND+12, Mag. Acc.+20
        hands="Kaykaus Cuffs +1", --MP+80, MND+12, Mag. Acc.+20
        legs="Kaykaus Tights +1", --MP+80, MND+12, Mag. Acc.+20
        feet="Kaykaus Boots +1",  --MP+80, "Cure" spellcasting time -7%, Enmity-6
        neck="Cleric's Torque",   --MP+30, "Cure" potency +5%, "Erase"+1
        ear1="Mendi. Earring",    --Cure potency
        ear2="Nourish. Earring",
        ring1="Stikini Ring +1",
        ring2="Menelaus's Ring",
        back={ name="Sucellos's Cape", augments={'MND+20','Mag. Acc+20 /Mag. Dmg.+20','MND+10','"Fast Cast"+10','Damage taken-5%',}},
        waist="Salire Belt",
        }

    -- Weather/day-matched Light element: Chatoyant Staff's Cure potency+10% and
    -- Iridescence effect stack strongly during light weather/day (see job_get_spell_map).
    sets.midcast.CureWeather = set_combine(sets.midcast.Cure, {
        main="Chatoyant Staff",
        sub="Enki Strap",
        })

    sets.midcast.CureSelf = set_combine(sets.midcast.Cure, {
        waist="Gishdubar Sash", --Cure received +10
        })

    sets.midcast.Curaga = set_combine(sets.midcast.Cure, {
        ring1="Stikini Ring +1",
        ring2="Stikini Ring +1",
        })

    sets.midcast.Regen = {
        head="Telchine Cap",      --Enh. Mag. eff. dur. +10
        body="Telchine Chas.",    --Enh. Mag. eff. dur. +9 (aug), Regen dur+12 base
        hands="Telchine Gloves",  --Enh. Mag. eff. dur. +9
        legs="Telchine Braconi",  --Enh. Mag. eff. dur. +8
        neck="Cleric's Torque",
        ring1="Stikini Ring +1",
        ring2="Stikini Ring +1",
        waist="Olympus Sash",     --Enhancing magic skill
        }

    sets.midcast['Enhancing Magic'] = {
        sub="Ammurapi Shield",
        head="Telchine Cap",
        body="Telchine Chas.",
        hands="Telchine Gloves",
        legs="Telchine Braconi",
        neck="Cleric's Torque",
        ring1="Stikini Ring +1",
        ring2="Stikini Ring +1",
        waist="Olympus Sash",
        }

    sets.midcast.EnhancingDuration = sets.midcast['Enhancing Magic']
    sets.midcast.Protect  = sets.midcast['Enhancing Magic']
    sets.midcast.Protectra = sets.midcast.Protect
    sets.midcast.Shell    = sets.midcast.Protect
    sets.midcast.Shellra  = sets.midcast.Shell
    sets.midcast['Bar-element'] = sets.midcast['Enhancing Magic']
    sets.midcast['Bar-status']  = sets.midcast['Enhancing Magic']

    sets.midcast.Aquaveil = set_combine(sets.midcast['Enhancing Magic'], {
        ammo="Staunch Tathlum +1",
        ring2="Evanescence Ring",
        })

    sets.midcast.StatusRemoval = {
        head="Vanya Hood",         --Healing magic skill +19/20, "Cure" cast -7%
        body="Theo. Bliaut +3",
        legs="Th. Pant. +3",
        feet="Vanya Clogs",        --Healing magic skill +20, "Cure" cast -7%
        neck="Cleric's Torque",
        ring1="Stikini Ring +1",
        ring2="Menelaus's Ring",
        waist="Bishop's Sash",
        }

    sets.midcast.Cursna = set_combine(sets.midcast.StatusRemoval, {
        hands="Theophany Mitts +3", --Magic accuracy for landing Cursna's removal
        })

    -- Enfeebling: WHM's whole list is MND-based (Dia/Paralyze/Slow). Kaykaus's
    -- Mag. Acc.+20 (x4 pieces) plus Theophany Mitts covers most of the accuracy need.
    sets.midcast.Enfeebles = {
        ammo="Ghastly Tathlum +1",
        head="Kaykaus Mitra +1",
        body="Kaykaus Bliaut +1",
        hands="Theophany Mitts +3", --~111 Mag. Acc.
        legs="Kaykaus Tights +1",
        feet="Kaykaus Boots +1",
        neck="Cleric's Torque",
        ear1="Enchntr. Earring +1", --Enfeebling magic skill
        ear2="Snotra Earring",      --Enfeebling magic skill
        ring1="Kishar Ring",        --Enfeebling duration +10%
        ring2="Stikini Ring +1",
        back={ name="Sucellos's Cape", augments={'MND+20','Mag. Acc+20 /Mag. Dmg.+20','MND+10','"Fast Cast"+10','Damage taken-5%',}},
        waist="Acuity Belt +1",     --Magic accuracy
        }

    sets.midcast.Enfeebles.Resistant = set_combine(sets.midcast.Enfeebles, {
        ear1="Sortiarius Earring",
        })

    -- Divine Magic: Banish/Holy/Flash. Damage is a bonus, not WHM's job -- kept simple.
    sets.midcast['Divine Magic'] = set_combine(sets.midcast.Enfeebles, {
        main="Queller Rod",
        })

    -- Overlay applied on top of Divine Magic when Banish/Holy land on a skillchain.
    sets.magic_burst = {
        ear2="Friomisi Earring",
        ring2="Metamor. Ring +1",
        }

    sets.midcast.Raise  = set_combine(sets.precast.FC, {})
    sets.midcast.Raise3  = sets.midcast.Raise
    sets.midcast.Reraise = sets.midcast.Raise
    sets.midcast.Teleport = sets.precast.FC


    ------------------------------------------------------------------------------------------------
    ----------------------------------------- Idle Sets --------------------------------------------
    ------------------------------------------------------------------------------------------------

    sets.idle = {
        ammo="Staunch Tathlum +1",
        head="Kaykaus Mitra +1",
        body="Telchine Chas.",     --Refresh/MP, Enhancing skill
        hands="Kaykaus Cuffs +1",
        legs="Telchine Braconi",
        feet="Kaykaus Boots +1",
        neck="Sanctity Necklace",
        ear1="Etiolation Earring",
        ear2="Loquac. Earring",
        ring1="Stikini Ring +1",   --Refresh
        ring2="Stikini Ring +1",   --Refresh
        back={ name="Sucellos's Cape", augments={'MND+20','Mag. Acc+20 /Mag. Dmg.+20','MND+10','"Fast Cast"+10','Damage taken-5%',}},
        waist="Witful Belt",
        }

    sets.idle.Town = set_combine(sets.idle, {
        legs="Kaykaus Tights +1",
        neck="Cleric's Torque",
        })

    sets.idle.DT = set_combine(sets.idle, {
        head="Nyame Helm",       --All Jobs DT
        body="Nyame Mail",
        hands="Nyame Gauntlets",
        legs="Nyame Flanchard",
        feet="Nyame Sollerets",
        ear2="Alabaster Earring", --DT/HP
        ring2="Gelatinous Ring +1", --PDT
        back={ name="Sucellos's Cape", augments={'MND+20','Mag. Acc+20 /Mag. Dmg.+20','MND+10','"Fast Cast"+10','Damage taken-5%',}},
        })

    sets.resting = set_combine(sets.idle, {
        main="Chatoyant Staff",
        sub="Enki Strap",
        })


    ------------------------------------------------------------------------------------------------
    ---------------------------------------- Defense Sets ------------------------------------------
    ------------------------------------------------------------------------------------------------

    sets.defense.PDT = sets.idle.DT
    sets.defense.MDT = sets.idle.DT

    sets.engaged = sets.idle.DT -- WHM shouldn't be meleeing; this only matters if you get pulled into it


    ------------------------------------------------------------------------------------------------
    ---------------------------------------- Special Sets ------------------------------------------
    ------------------------------------------------------------------------------------------------

    sets.Kiting = {ring1="Shneddick Ring"}

    sets.buff.Doom = {
        neck="Nicander's Necklace", --Doom recovery
        ring1="Blenmot's Ring +1",  --Doom resist
        waist="Gishdubar Sash",
        }

    sets.QuellerRod = {main="Queller Rod", sub="Ammurapi Shield"}
    sets.ChatoyantStaff = {main="Chatoyant Staff", sub="Enki Strap"}

    sets.DefaultShield = {sub="Ammurapi Shield"}

end

-------------------------------------------------------------------------------------------------------------------
-- Job-specific hooks for standard casting events.
-------------------------------------------------------------------------------------------------------------------

function job_precast(spell, action, spellMap, eventArgs)
    if spell.english == 'Stoneskin' then
        send_command('cancel stoneskin')
    elseif spell.english == 'Sneak' then
        send_command('cancel sneak')
    end
end

function job_post_midcast(spell, action, spellMap, eventArgs)
    if spellMap == 'Cure' and spell.target.type == 'SELF' then
        equip(sets.midcast.CureSelf)
    end

    if (spellMap == 'Cure' or spellMap == 'Curaga') and
       (world.weather_element == 'Light' or world.day_element == 'Light') then
        equip(sets.midcast.CureWeather)
    end

    if spell.skill == 'Divine Magic' then
        local bursting = state.MagicBurst.value
        if bursting and (spell.english == 'Banish' or spell.english:startswith('Banish') or spell.english:startswith('Holy')) then
            equip(sets.magic_burst)
        end
    end
end

function job_aftercast(spell, action, spellMap, eventArgs)
    if player.status ~= 'Engaged' and state.WeaponLock.value == false then
        check_weaponset()
    end
end

-------------------------------------------------------------------------------------------------------------------
-- Job-specific hooks for non-casting events.
-------------------------------------------------------------------------------------------------------------------

-- Auto Echo Drops with a hard cap of 3 attempts per silence instance.
silence_echo = {attempts=0, active=false}

function try_echo_drops()
    if not buffactive.silence then
        if silence_echo.active and silence_echo.attempts > 0 then
            add_to_chat(158, '** [Silence removed] **')
        end
        silence_echo.active = false
        silence_echo.attempts = 0
        return
    end
    if silence_echo.attempts >= 3 then
        add_to_chat(123, '** [Echo Drops cap (3) hit - silence resisted items. Wait it out. ] **')
        silence_echo.active = false
        return
    end
    silence_echo.attempts = silence_echo.attempts + 1
    send_command('input /item "Echo Drops" <me>')
    add_to_chat(123, '** [Silenced! Echo Drops attempt '..silence_echo.attempts..'/3] **')
    coroutine.schedule(try_echo_drops, 4)
end

function job_buff_change(buff, gain)
    if buff:lower() == "silence" then
        if gain and not silence_echo.active then
            silence_echo.active = true
            silence_echo.attempts = 0
            try_echo_drops()
        elseif not gain then
            silence_echo.active = false
            silence_echo.attempts = 0
        end
    end

    if buff:lower() == "doom" then
        if gain then
            equip(sets.buff.Doom)
            send_command('@input /p Doomed.')
            send_command('input /echo ** DOOMED - spam Holy Waters **')
            disable('ring1','ring2','waist')
        else
            enable('ring1','ring2','waist')
            handle_equipping_gear(player.status)
        end
    end

    -- EXP/CP boost is now active: release any boost ring so normal gear returns.
    if gain and boost_buffs:contains(buff:lower()) then
        local slots = {}
        if boost_gear:contains(player.equipment.left_ring)  then slots[#slots+1] = 'ring1' end
        if boost_gear:contains(player.equipment.right_ring) then slots[#slots+1] = 'ring2' end
        release_ring_slots(slots, buff..' active')
    end
end

function job_state_change(stateField, newValue, oldValue)
    if state.WeaponLock.value == true then
        disable('main','sub','range')
    else
        enable('main','sub','range')
    end
    check_weaponset()
end

-------------------------------------------------------------------------------------------------------------------
-- User code that supplements standard library decisions.
-------------------------------------------------------------------------------------------------------------------

function job_handle_equipping_gear(playerStatus, eventArgs)
    check_gear()
end

function job_update(cmdParams, eventArgs)
    handle_equipping_gear(player.status)
end

function update_combat_form()
    state.CombatForm:reset()
end

-- Custom spell mapping: routes WHM's Cure/enfeeble/status-removal/bar spells to
-- the sets defined above; Mote-Include's base library handles most everything else.
function job_get_spell_map(spell, default_spell_map)
    if spell.action_type ~= 'Magic' then return end

    if default_spell_map == 'Cure' or default_spell_map == 'Curaga' then
        if (world.weather_element == 'Light' or world.day_element == 'Light') then
            return 'CureWeather'
        end
    end

    if status_removal_spells:contains(spell.english) then
        if spell.english == 'Cursna' then
            return 'Cursna'
        end
        return 'StatusRemoval'
    end

    if bar_element_spells:contains(spell.english) then
        return 'Bar-element'
    end

    if bar_status_spells:contains(spell.english) then
        return 'Bar-status'
    end

    if whm_enfeebles:contains(spell.english) then
        if state.CastingMode.value == 'Resistant' then
            return 'EnfeeblesResistant'
        end
        return 'Enfeebles'
    end

    if divine_magic:contains(spell.english) then
        return 'Divine Magic'
    end

    if spell.english == 'Raise' or spell.english == 'Raise II' then
        return 'Raise'
    elseif spell.english == 'Raise III' then
        return 'Raise3'
    end
end

-- Modify the default idle set after it was constructed.
function customize_idle_set(idleSet)
    if state.Auto_Kite.value == true then
        idleSet = set_combine(idleSet, sets.Kiting)
    end
    check_gear()
    return idleSet
end

function display_current_job_state(eventArgs)
    local h_msg = state.HybridMode.value
    local c_msg = state.CastingMode.value
    local i_msg = state.IdleMode.value
    local msg = ''
    if state.MagicBurst.value then
        msg = ' Burst: On |'
    end
    if state.Kiting.value then
        msg = msg .. ' Kiting: On |'
    end

    add_to_chat(002, '| ' ..string.char(31,004).. 'Hybrid: ' ..string.char(31,001)..h_msg.. string.char(31,002)..  ' |'
        ..string.char(31,060).. ' Magic: ' ..string.char(31,001)..c_msg.. string.char(31,002)..  ' |'
        ..string.char(31,008).. ' Idle: ' ..string.char(31,001)..i_msg.. string.char(31,002)..  ' |'
        ..string.char(31,002)..msg)

    eventArgs.handled = true
end

-------------------------------------------------------------------------------------------------------------------
-- Utility functions specific to this job.
-------------------------------------------------------------------------------------------------------------------

-- Lock a ring slot (disable) whenever it holds a no_swap ring, unless we're in the
-- middle of releasing it. Enable it otherwise so normal gear flows back in.
function check_gear()
    if no_swap_gear:contains(player.equipment.left_ring) and not releasing.ring1 then
        disable("ring1")
    else
        enable("ring1")
    end
    if no_swap_gear:contains(player.equipment.right_ring) and not releasing.ring2 then
        disable("ring2")
    else
        enable("ring2")
    end
end

function release_ring_slots(slots, reason)
    local any = false
    for _, s in ipairs(slots) do releasing[s] = true; enable(s); any = true end
    if not any then return end
    if reason then add_to_chat(158, '** [no-swap ring released: '..reason..'] **') end
    handle_equipping_gear(player.status)
    coroutine.schedule(function()
        for _, s in ipairs(slots) do releasing[s] = false end
        check_gear()
    end, 1)
end

function check_weaponset()
    equip(sets[state.WeaponSet.current])
end

function job_self_command(cmdParams, eventArgs)
    if cmdParams[1]:lower() == 'barelement' then
        send_command('@input /ma "'..state.BarElement.value..'" <me>')
        eventArgs.handled = true
    elseif cmdParams[1]:lower() == 'barstatus' then
        send_command('@input /ma "'..state.BarStatus.value..'" <me>')
        eventArgs.handled = true
    elseif cmdParams[1]:lower() == 'scholar' then
        handle_strategems(cmdParams)
        eventArgs.handled = true
    elseif cmdParams[1] == 'auditgear' then
        audit_gear()
        eventArgs.handled = true
    elseif cmdParams[1] == '_auditdrain' then
        if audit_queue and #audit_queue > 0 then
            local line = table.remove(audit_queue, 1)
            add_to_chat(line.c, line.m)
            if #audit_queue > 0 then
                windower.send_command('wait 0.05; gs c _auditdrain')
            end
        end
        eventArgs.handled = true
    end
end

-- General handling of stratagems in an Arts-agnostic way (only relevant if /SCH).
-- Format: gs c scholar <strategem>
function handle_strategems(cmdParams)
    if not cmdParams[2] then
        add_to_chat(123,'Error: No strategem command given.')
        return
    end
    local strategem = cmdParams[2]:lower()

    if strategem == 'light' then
        if buffactive['light arts'] then
            send_command('input /ja "Addendum: White" <me>')
        elseif buffactive['addendum: white'] then
            add_to_chat(122,'Error: Addendum: White is already active.')
        else
            send_command('input /ja "Light Arts" <me>')
        end
    elseif strategem == 'dark' then
        if buffactive['dark arts'] then
            send_command('input /ja "Addendum: Black" <me>')
        elseif buffactive['addendum: black'] then
            add_to_chat(122,'Error: Addendum: Black is already active.')
        else
            send_command('input /ja "Dark Arts" <me>')
        end
    elseif buffactive['light arts'] or buffactive['addendum: white'] then
        if strategem == 'cost' then
            send_command('input /ja Penury <me>')
        elseif strategem == 'speed' then
            send_command('input /ja Celerity <me>')
        elseif strategem == 'aoe' then
            send_command('input /ja Accession <me>')
        elseif strategem == 'addendum' then
            send_command('input /ja "Addendum: White" <me>')
        else
            add_to_chat(123,'Error: Unknown strategem ['..strategem..']')
        end
    elseif buffactive['dark arts'] or buffactive['addendum: black'] then
        if strategem == 'cost' then
            send_command('input /ja Parsimony <me>')
        elseif strategem == 'speed' then
            send_command('input /ja Alacrity <me>')
        elseif strategem == 'aoe' then
            send_command('input /ja Manifestation <me>')
        elseif strategem == 'addendum' then
            send_command('input /ja "Addendum: Black" <me>')
        else
            add_to_chat(123,'Error: Unknown strategem ['..strategem..']')
        end
    else
        add_to_chat(123,'No arts has been activated yet.')
    end
end

-- On zone change you've arrived: drop WARP/dimension rings so normal rings return.
windower.register_event('zone change',
    function()
        local slots = {}
        if warp_gear:contains(player.equipment.left_ring)  then slots[#slots+1] = 'ring1' end
        if warp_gear:contains(player.equipment.right_ring) then slots[#slots+1] = 'ring2' end
        if #slots > 0 then
            for _, s in ipairs(slots) do enable(s) end
            equip(sets.idle)
        end
    end
)

-- Select default macro book on initial load or subjob change.
function select_default_macro_book()
    set_macro_page(1, 12)
end

function set_lockstyle()
    send_command('wait 2; input /lockstyleset ' .. lockstyleset)
end

-------------------------------------------------------------------------------------------------------------------
-- Gear Audit (Win+A)
-- Walks every set and gear table, checks each named piece against all inventory bags.
-- For every missing item, reports which set(s) and slot(s) reference it so you know
-- exactly where to make substitutions in the lua. (Ported verbatim from NIN/RDM template.)
-------------------------------------------------------------------------------------------------------------------

audit_queue = nil

local function collect_gear_names(tbl, found, set_path, visited)
    if type(tbl) ~= 'table' then return found end
    found   = found   or {}
    visited = visited or {}

    if visited[tbl] then return found end
    visited[tbl] = true

    for k, v in pairs(tbl) do
        if k == 'augments' then
            -- never recurse into augments -- stat strings, not item names

        elseif k == 'name' and type(v) == 'string' then
            if not found[v] then found[v] = {locs={}, seen={}} end
            if not found[v].seen[set_path] then
                found[v].seen[set_path] = true
                table.insert(found[v].locs, set_path)
            end

        elseif type(k) == 'string' and type(v) == 'string' then
            if k ~= 'name' and k ~= 'type' and k ~= 'field'
                    and k ~= 'slot' and k ~= 'bag' then
                if not found[v] then found[v] = {locs={}, seen={}} end
                local loc = set_path .. ' [' .. k .. ']'
                if not found[v].seen[loc] then
                    found[v].seen[loc] = true
                    table.insert(found[v].locs, loc)
                end
            end

        elseif type(v) == 'table' then
            local child = (type(k) == 'string') and (set_path .. '.' .. k) or set_path
            collect_gear_names(v, found, child, visited)
        end
    end
    return found
end

local function item_in_inventory(name)
    local bags = {
        player.inventory,
        player.wardrobe,  player.wardrobe2, player.wardrobe3,
        player.wardrobe4, player.wardrobe5, player.wardrobe6, player.wardrobe7, player.wardrobe8,
        player.safe,      player.safe2,
        player.storage,   player.satchel,
        player.sack,      player.case,
    }
    for _, bag in ipairs(bags) do
        if bag and bag[name] then return true end
    end
    return false
end

local audit_skip = S{
    'empty', '', 'Path: A', 'Path: B', 'Path: C', 'Path: D',
    'wardrobe', 'wardrobe2', 'wardrobe3', 'wardrobe4', 'wardrobe5', 'wardrobe6', 'wardrobe7', 'wardrobe8',
}

local function looks_like_stat(s)
    return s:match('^[%+%-]?%d') ~= nil
        or s:match('^MP%+')         ~= nil
        or s:match('^MND%+')        ~= nil
        or s:match('^INT%+')        ~= nil
        or s:match('^STR%+')        ~= nil
        or s:match('^DEX%+')        ~= nil
        or s:match('^AGI%+')        ~= nil
        or s:match('^VIT%+')        ~= nil
        or s:match('^CHR%+')        ~= nil
        or s:match('^Mag%.')        ~= nil
        or s:match('^"')            ~= nil
        or s:match('Dmg%.')         ~= nil
        or s:match('skill %+')      ~= nil
        or s:match('taken')         ~= nil
        or s:match('Bonus %+')      ~= nil
        or s:match('^Accuracy%+')   ~= nil
        or s:match('^Weapon skill') ~= nil
        or s:match('^Enh%.')        ~= nil
        or s:match('^Damage')       ~= nil
        or s:match('^Enmity')       ~= nil
        or s:match('^System:')      ~= nil
        or s:match('^Enhances')     ~= nil
        or s:match('^Pet:')         ~= nil
end

function audit_gear()
    add_to_chat(158, '=== Gear Audit Starting ===')

    local all_names = {}
    local visited   = {}
    collect_gear_names(sets, all_names, 'sets', visited)
    collect_gear_names(gear, all_names, 'gear', visited)

    local missing = {}
    local checked = 0

    for name, entry in pairs(all_names) do
        if not audit_skip:contains(name)
                and name ~= ''
                and not looks_like_stat(name) then
            checked = checked + 1
            if not item_in_inventory(name) then
                table.insert(missing, {name=name, locs=entry.locs})
            end
        end
    end

    table.sort(missing, function(a, b) return a.name < b.name end)

    audit_queue = {}
    local function q(color, msg) table.insert(audit_queue, {c=color, m=msg}) end

    if #missing == 0 then
        q(158, 'Audit complete (' .. checked .. ' pieces checked) — all items found.')
    else
        q(167, 'Audit: ' .. checked .. ' checked, ' .. #missing .. ' missing:')
        for _, item in ipairs(missing) do
            q(167, '  MISSING: ' .. item.name)
            local show = math.min(#item.locs, 4)
            for i = 1, show do
                q(167, '    -> ' .. item.locs[i])
            end
            if #item.locs > 4 then
                q(167, '    -> ...and ' .. (#item.locs - 4) .. ' more set(s)')
            end
        end
    end

    q(158, '=== Gear Audit Done ===')

    windower.send_command('gs c _auditdrain')
end
