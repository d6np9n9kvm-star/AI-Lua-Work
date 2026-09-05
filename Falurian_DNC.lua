-- Original: Motenten / Modified: Arislan
-- GearSwap Lua for DNC
-- Player: Falurian
-- Generated: 2026-05-30 09:43

-------------------------------------------------------------------------------------------------------------------
-- Setup functions for this job. Generally should not be modified.
-------------------------------------------------------------------------------------------------------------------

-- Initialization function for this job file.
function get_sets()
    mote_include_version = 2

    -- Load and initialize the include file.
    include('Mote-Include.lua')
end

-- Setup vars that are user-independent. state.Buff vars initialized here will automatically be tracked.
function job_setup()
    state.Buff['Climactic Flourish'] = buffactive['Climactic Flourish'] or false
    state.Buff['Fan Dance'] = buffactive['Fan Dance'] or false
    state.Buff['Saber Dance'] = buffactive['Saber Dance'] or false

    no_swap_gear = S{"Warp Ring", "Dim. Ring (Dem)", "Dim. Ring (Holla)", "Dim. Ring (Mea)",
        "Trizek Ring", "Echad Ring", "Facility Ring", "Capacity Ring"}

-------------------------------------------------------------------------------------------------------------------
-- User setup functions for this job. Recommend that these be overridden in a sidecar file.
-------------------------------------------------------------------------------------------------------------------

-- Setup vars that are user-dependent. Can override this function in a sidecar file.
function user_setup()
    state.OffenseMode:options('Normal', 'STP', 'Acc')
    state.HybridMode:options('Normal', 'DT')
    state.IdleMode:options('Normal', 'DT', 'Regen')

    state.WeaponLock = M(false, 'Weapon Lock')

    -- Additional local binds
    -- include('Global-Binds.lua') -- OK to remove this line

    -- Default macro book/set
    set_macro_page(1, 1)
end

function user_unload()
    -- Unbind keys here if needed
end

-- Define sets and vars used by this job file.
function init_gear_sets()

    ------------------------------------------------------------------------------------------------
    ---------------------------------------- Gear Variables ----------------------------------------
    ------------------------------------------------------------------------------------------------

    -- Augmented gear variables - define your augmented gear here
    gear.DNC_FC_Cape = { name="Senuna's Mantle", augments={'Fast Cast +10%'} }
    gear.DNC_WS_Cape = { name="Senuna's Mantle", augments={'Weapon skill damage +10%'} }
    gear.DNC_Nuke_Cape = { name="Senuna's Mantle", augments={'INT+20','Mag. Acc+20 /Mag. Dmg.+20','"Mag.Atk.Bns."+10'} }
    gear.DNC_TP_Cape = { name="Senuna's Mantle", augments={'DEX+20','Accuracy+20 Attack+20','"Dbl.Atk."+10'} }


    ------------------------------------------------------------------------------------------------
    ---------------------------------------- Precast Sets ------------------------------------------
    ------------------------------------------------------------------------------------------------

    -- Fast Cast
    sets.precast.FC = {
        ammo="Staunch Tathlum +1",
        head="Nyame Helm",
        neck="Null Loop",
        left_ear="Etiolation Earring",
        right_ear="Eabani Earring",
        body={ name="Taeon Tabard", augments={'Pet: Accuracy+23 Pet: Rng. Acc.+23', 'Pet: "Dbl. Atk."+5', 'Pet: Damage taken -3%'} },
        hands="Nyame Gauntlets",
        left_ring="Gelatinous Ring +1",
        right_ring="Naji's Loop",
        back="Null Shawl",
        waist="Eschan Stone",
        legs="Limbo Trousers",
        feet="Nyame Sollerets",
    }


    ------------------------------------------------------------------------------------------------
    ---------------------------------------- JA Sets ------------------------------------------
    ------------------------------------------------------------------------------------------------

    -- Trance
    sets.precast.JA['Trance'] = {
        --main="",
        --sub="",
        --range="",
        --ammo="",
        --head="",
        --neck="",
        --ear1="",
        --ear2="",
        --body="",
        --hands="",
        --ring1="",
        --ring2="",
        --back="",
        --waist="",
        --legs="",
        --feet="",
    }

    -- No Foot Rise
    sets.precast.JA['No Foot Rise'] = {
        --main="",
        --sub="",
        --range="",
        --ammo="",
        --head="",
        --neck="",
        --ear1="",
        --ear2="",
        --body="",
        --hands="",
        --ring1="",
        --ring2="",
        --back="",
        --waist="",
        --legs="",
        --feet="",
    }

    -- Fan Dance
    sets.precast.JA['Fan Dance'] = {
        --main="",
        --sub="",
        --range="",
        --ammo="",
        --head="",
        --neck="",
        --ear1="",
        --ear2="",
        --body="",
        --hands="",
        --ring1="",
        --ring2="",
        --back="",
        --waist="",
        --legs="",
        --feet="",
    }

    -- Saber Dance
    sets.precast.JA['Saber Dance'] = {
        --main="",
        --sub="",
        --range="",
        --ammo="",
        --head="",
        --neck="",
        --ear1="",
        --ear2="",
        --body="",
        --hands="",
        --ring1="",
        --ring2="",
        --back="",
        --waist="",
        --legs="",
        --feet="",
    }

    -- Climactic Flourish
    sets.precast.JA['Climactic Flourish'] = {
        --main="",
        --sub="",
        --range="",
        --ammo="",
        --head="",
        --neck="",
        --ear1="",
        --ear2="",
        --body="",
        --hands="",
        --ring1="",
        --ring2="",
        --back="",
        --waist="",
        --legs="",
        --feet="",
    }

    -- Striking Flourish
    sets.precast.JA['Striking Flourish'] = {
        --main="",
        --sub="",
        --range="",
        --ammo="",
        --head="",
        --neck="",
        --ear1="",
        --ear2="",
        --body="",
        --hands="",
        --ring1="",
        --ring2="",
        --back="",
        --waist="",
        --legs="",
        --feet="",
    }

    -- Building Flourish
    sets.precast.JA['Building Flourish'] = {
        --main="",
        --sub="",
        --range="",
        --ammo="",
        --head="",
        --neck="",
        --ear1="",
        --ear2="",
        --body="",
        --hands="",
        --ring1="",
        --ring2="",
        --back="",
        --waist="",
        --legs="",
        --feet="",
    }

    -- Presto
    sets.precast.JA['Presto'] = {
        --main="",
        --sub="",
        --range="",
        --ammo="",
        --head="",
        --neck="",
        --ear1="",
        --ear2="",
        --body="",
        --hands="",
        --ring1="",
        --ring2="",
        --back="",
        --waist="",
        --legs="",
        --feet="",
    }


    ------------------------------------------------------------------------------------------------
    ---------------------------------------- Buff Sets ------------------------------------------
    ------------------------------------------------------------------------------------------------

    -- Doom (Holy Water)
    sets.buff.Doom = {
        --main="",
        --sub="",
        --range="",
        --ammo="",
        --head="",
        --neck="",
        --ear1="",
        --ear2="",
        --body="",
        --hands="",
        --ring1="",
        --ring2="",
        --back="",
        --waist="",
        --legs="",
        --feet="",
    }

    -- Climactic Flourish active
    sets.buff.ClimaticFlourish = {
        --main="",
        --sub="",
        --range="",
        --ammo="",
        --head="",
        --neck="",
        --ear1="",
        --ear2="",
        --body="",
        --hands="",
        --ring1="",
        --ring2="",
        --back="",
        --waist="",
        --legs="",
        --feet="",
    }


    ------------------------------------------------------------------------------------------------
    ---------------------------------------- Idle Sets ------------------------------------------
    ------------------------------------------------------------------------------------------------

    -- Default idle
    sets.idle = {
        -- main="Tauret",
        -- sub={ name="Polyhymnia", augments={'Accuracy+50', '"Store TP"+8', 'Weapon skill damage +5%'} },
        ammo="Staunch Tathlum +1",
        head="Nyame Helm",
        neck="Null Loop",
        left_ear="Etiolation Earring",
        right_ear="Eabani Earring",
        body="Nyame Mail",
        hands="Nyame Gauntlets",
        left_ring="Gelatinous Ring +1",
        right_ring="Meghanada Ring",
        back="Null Shawl",
        waist="Eschan Stone",
        legs={ name="Nyame Flanchard", augments={'Path: B'} },
        feet="Nyame Sollerets",
    }

    -- Idle DT
    sets.idle.DT = {
        -- main="Tauret",
        -- sub={ name="Polyhymnia", augments={'Accuracy+50', '"Store TP"+8', 'Weapon skill damage +5%'} },
        ammo="Staunch Tathlum +1",
        head="Nyame Helm",
        neck="Null Loop",
        left_ear="Etiolation Earring",
        right_ear="Eabani Earring",
        body="Nyame Mail",
        hands="Nyame Gauntlets",
        left_ring="Gelatinous Ring +1",
        right_ring="Meghanada Ring",
        back="Null Shawl",
        waist="Eschan Stone",
        legs={ name="Nyame Flanchard", augments={'Path: B'} },
        feet="Nyame Sollerets",
    }

    -- Idle Regen
    sets.idle.Regen = {
        -- main="Tauret",
        -- sub={ name="Polyhymnia", augments={'Accuracy+50', '"Store TP"+8', 'Weapon skill damage +5%'} },
        ammo="Staunch Tathlum +1",
        head="Nyame Helm",
        neck="Null Loop",
        left_ear="Etiolation Earring",
        right_ear="Eabani Earring",
        body="Nyame Mail",
        hands="Nyame Gauntlets",
        left_ring="Gelatinous Ring +1",
        right_ring="Meghanada Ring",
        back="Null Shawl",
        waist="Eschan Stone",
        legs={ name="Nyame Flanchard", augments={'Path: B'} },
        feet="Nyame Sollerets",
    }


    ------------------------------------------------------------------------------------------------
    ---------------------------------------- Engaged Sets ------------------------------------------
    ------------------------------------------------------------------------------------------------

    -- Base engaged (damage)
    sets.engaged = {
        -- main="Tauret",
        -- sub={ name="Polyhymnia", augments={'Accuracy+50', '"Store TP"+8', 'Weapon skill damage +5%'} },
        ammo="Yamarang",
        head="Malignance Chapeau",
        neck="Anu Torque",
        left_ear="Telos Earring",
        right_ear="Cessance Earring",
        body="Malignance Tabard",
        hands="Malignance Gloves",
        left_ring="Chirich Ring +1",
        right_ring="Chirich Ring +1",
        back="Null Shawl",
        waist="Sinew Belt",
        legs="Malignance Tights",
        feet="Malignance Boots",
    }

    -- Store TP focus
    sets.engaged.STP = {
        -- main="Tauret",
        -- sub={ name="Polyhymnia", augments={'Accuracy+50', '"Store TP"+8', 'Weapon skill damage +5%'} },
        ammo="Yamarang",
        head="Malignance Chapeau",
        neck="Anu Torque",
        left_ear="Telos Earring",
        right_ear="Cessance Earring",
        body="Malignance Tabard",
        hands="Malignance Gloves",
        left_ring="Chirich Ring +1",
        right_ring="Chirich Ring +1",
        back="Null Shawl",
        waist="Sinew Belt",
        legs="Malignance Tights",
        feet="Malignance Boots",
    }

    -- Accuracy focus
    sets.engaged.Acc = {
        -- main="Tauret",
        -- sub={ name="Polyhymnia", augments={'Accuracy+50', '"Store TP"+8', 'Weapon skill damage +5%'} },
        ammo="Focal Orb",
        head="Malignance Chapeau",
        neck="Anu Torque",
        left_ear="Telos Earring",
        right_ear="Cessance Earring",
        body="Malignance Tabard",
        hands="Malignance Gloves",
        left_ring="Chirich Ring +1",
        right_ring="Chirich Ring +1",
        back="Null Shawl",
        waist="Patentia Sash",
        legs="Malignance Tights",
        feet="Malignance Boots",
    }

    -- Normal + DT
    sets.engaged.DT = {
        -- main="Tauret",
        -- sub={ name="Polyhymnia", augments={'Accuracy+50', '"Store TP"+8', 'Weapon skill damage +5%'} },
        ammo="Yamarang",
        head="Malignance Chapeau",
        neck="Anu Torque",
        left_ear="Telos Earring",
        right_ear="Cessance Earring",
        body="Malignance Tabard",
        hands="Malignance Gloves",
        left_ring="Chirich Ring +1",
        right_ring="Chirich Ring +1",
        back="Null Shawl",
        waist={ name="Sailfi Belt +1", augments={'Path: A'} },
        legs="Malignance Tights",
        feet="Malignance Boots",
    }

    -- STP + DT
    sets.engaged.STP.DT = {
        -- main="Tauret",
        -- sub={ name="Polyhymnia", augments={'Accuracy+50', '"Store TP"+8', 'Weapon skill damage +5%'} },
        ammo="Yamarang",
        head="Malignance Chapeau",
        neck="Anu Torque",
        left_ear="Telos Earring",
        right_ear="Cessance Earring",
        body="Malignance Tabard",
        hands="Malignance Gloves",
        left_ring="Chirich Ring +1",
        right_ring="Chirich Ring +1",
        back="Null Shawl",
        waist="Sinew Belt",
        legs="Malignance Tights",
        feet="Malignance Boots",
    }

    -- Acc + DT
    sets.engaged.Acc.DT = {
        -- main="Tauret",
        -- sub={ name="Polyhymnia", augments={'Accuracy+50', '"Store TP"+8', 'Weapon skill damage +5%'} },
        ammo="Yamarang",
        head="Malignance Chapeau",
        neck="Anu Torque",
        left_ear="Telos Earring",
        right_ear="Cessance Earring",
        body="Malignance Tabard",
        hands="Malignance Gloves",
        left_ring="Chirich Ring +1",
        right_ring="Chirich Ring +1",
        back="Null Shawl",
        waist={ name="Sailfi Belt +1", augments={'Path: A'} },
        legs="Malignance Tights",
        feet="Malignance Boots",
    }


    ------------------------------------------------------------------------------------------------
    ---------------------------------------- Defense Sets ------------------------------------------
    ------------------------------------------------------------------------------------------------

    -- Physical DT
    sets.defense.PDT = {
        -- main="Tauret",
        -- sub={ name="Polyhymnia", augments={'Accuracy+50', '"Store TP"+8', 'Weapon skill damage +5%'} },
        ammo="Staunch Tathlum +1",
        head="Nyame Helm",
        neck="Null Loop",
        left_ear="Etiolation Earring",
        right_ear="Eabani Earring",
        body="Meg. Cuirie +2",
        hands="Nyame Gauntlets",
        left_ring="Gelatinous Ring +1",
        right_ring="Meghanada Ring",
        back="Null Shawl",
        waist="Eschan Stone",
        legs={ name="Nyame Flanchard", augments={'Path: B'} },
        feet="Nyame Sollerets",
    }

    -- Magical DT
    sets.defense.MDT = {
        -- main="Tauret",
        -- sub={ name="Polyhymnia", augments={'Accuracy+50', '"Store TP"+8', 'Weapon skill damage +5%'} },
        ammo="Staunch Tathlum +1",
        head="Nyame Helm",
        neck="Null Loop",
        left_ear="Etiolation Earring",
        right_ear="Eabani Earring",
        body="Nyame Mail",
        hands="Nyame Gauntlets",
        left_ring="Gelatinous Ring +1",
        right_ring="Meghanada Ring",
        back="Null Shawl",
        waist="Eschan Stone",
        legs={ name="Nyame Flanchard", augments={'Path: B'} },
        feet="Nyame Sollerets",
    }


    ------------------------------------------------------------------------------------------------
    ---------------------------------------- Step Sets ------------------------------------------
    ------------------------------------------------------------------------------------------------

    -- Steps
    sets.precast.Step = {
        ammo="Staunch Tathlum +1",
        head="Nyame Helm",
        neck="Null Loop",
        left_ear="Etiolation Earring",
        right_ear="Eabani Earring",
        body={ name="Taeon Tabard", augments={'Pet: Accuracy+23 Pet: Rng. Acc.+23', 'Pet: "Dbl. Atk."+5', 'Pet: Damage taken -3%'} },
        hands="Nyame Gauntlets",
        left_ring="Gelatinous Ring +1",
        right_ring="Naji's Loop",
        back="Null Shawl",
        waist="Eschan Stone",
        legs="Limbo Trousers",
        feet="Nyame Sollerets",
    }


    ------------------------------------------------------------------------------------------------
    ---------------------------------------- Waltz Sets ------------------------------------------
    ------------------------------------------------------------------------------------------------

    -- Waltzes
    sets.precast.Waltz = {
        ammo="Staunch Tathlum +1",
        head="Nyame Helm",
        neck="Null Loop",
        left_ear="Etiolation Earring",
        right_ear="Eabani Earring",
        body={ name="Taeon Tabard", augments={'Pet: Accuracy+23 Pet: Rng. Acc.+23', 'Pet: "Dbl. Atk."+5', 'Pet: Damage taken -3%'} },
        hands="Nyame Gauntlets",
        left_ring="Gelatinous Ring +1",
        right_ring="Naji's Loop",
        back="Null Shawl",
        waist="Eschan Stone",
        legs="Limbo Trousers",
        feet="Nyame Sollerets",
    }

    -- Waltz potency
    sets.midcast.Waltz = {
        -- main="Tauret",
        -- sub="Horos Knife",
        -- range="Albin Bane",
        ammo="Yamarang",
        head="Nyame Helm",
        neck="Null Loop",
        left_ear="Sortiarius Earring",
        right_ear="Friomisi Earring",
        body="Nyame Mail",
        hands="Nyame Gauntlets",
        left_ring="Stikini Ring +1",
        right_ring="Stikini Ring +1",
        back="Null Shawl",
        waist="Null Belt",
        legs={ name="Nyame Flanchard", augments={'Path: B'} },
        feet="Nyame Sollerets",
    }

    -- Self Waltz
    sets.midcast.WaltzSelf = {
        -- main="Tauret",
        -- sub="Horos Knife",
        -- range="Albin Bane",
        ammo="Yamarang",
        head="Nyame Helm",
        neck="Null Loop",
        left_ear="Sortiarius Earring",
        right_ear="Friomisi Earring",
        body="Nyame Mail",
        hands="Nyame Gauntlets",
        left_ring="Stikini Ring +1",
        right_ring="Stikini Ring +1",
        back="Null Shawl",
        waist="Null Belt",
        legs={ name="Nyame Flanchard", augments={'Path: B'} },
        feet="Nyame Sollerets",
    }


    ------------------------------------------------------------------------------------------------
    ---------------------------------------- Samba Sets ------------------------------------------
    ------------------------------------------------------------------------------------------------

    -- Sambas
    sets.precast.Samba = {
        ammo="Staunch Tathlum +1",
        head="Nyame Helm",
        neck="Null Loop",
        left_ear="Etiolation Earring",
        right_ear="Eabani Earring",
        body={ name="Taeon Tabard", augments={'Pet: Accuracy+23 Pet: Rng. Acc.+23', 'Pet: "Dbl. Atk."+5', 'Pet: Damage taken -3%'} },
        hands="Nyame Gauntlets",
        left_ring="Gelatinous Ring +1",
        right_ring="Naji's Loop",
        back="Null Shawl",
        waist="Eschan Stone",
        legs="Limbo Trousers",
        feet="Nyame Sollerets",
    }


    ------------------------------------------------------------------------------------------------
    ---------------------------------------- Jig Sets ------------------------------------------
    ------------------------------------------------------------------------------------------------

    -- Jigs
    sets.precast.Jig = {
        ammo="Staunch Tathlum +1",
        head="Nyame Helm",
        neck="Null Loop",
        left_ear="Etiolation Earring",
        right_ear="Eabani Earring",
        body={ name="Taeon Tabard", augments={'Pet: Accuracy+23 Pet: Rng. Acc.+23', 'Pet: "Dbl. Atk."+5', 'Pet: Damage taken -3%'} },
        hands="Nyame Gauntlets",
        left_ring="Gelatinous Ring +1",
        right_ring="Naji's Loop",
        back="Null Shawl",
        waist="Eschan Stone",
        legs="Limbo Trousers",
        feet="Nyame Sollerets",
    }

    ------------------------------------------------------------------------------------------------
    ------------------------------------- Weapon Skill Sets ----------------------------------------
    ------------------------------------------------------------------------------------------------

    -- Default WS set
    sets.precast.WS = {
        ammo="Oshasha's Treatise",
        head="Malignance Chapeau",
        neck="Rep. Plat. Medal",
        left_ear="Telos Earring",
        right_ear="Odr Earring",
        body="Malignance Tabard",
        hands="Meg. Gloves +2",
        left_ring="Sroda Ring",
        right_ring="Epaminondas's Ring",
        back={ name="Senuna's Mantle", augments={'DEX+20', 'Accuracy+20 Attack+20', '"Dbl.Atk."+10'} },
        waist="Sinew Belt",
        legs={ name="Nyame Flanchard", augments={'Path: B'} },
        feet="Malignance Boots",
    }

    -- Asuran Fists: Physical (VIT:15%, STR:15%)
    sets.precast.WS['Asuran Fists'] = set_combine(sets.precast.WS, {
        --main="",
        --sub="",
        --range="",
        --ammo="",
        --head="",
        --neck="",
        --ear1="",
        --ear2="",
        --body="",
        --hands="",
        --ring1="",
        --ring2="",
        --back="",
        --waist="",
        --legs="",
        --feet="",
    })

    -- Evisceration: Physical (DEX:50%)
    sets.precast.WS['Evisceration'] = set_combine(sets.precast.WS, {
        -- main="Tauret",
        -- sub={ name="Polyhymnia", augments={'Accuracy+50', '"Store TP"+8', 'Weapon skill damage +5%'} },
        ammo="Focal Orb",
        head="Mummu Bonnet +2",
        neck="Rep. Plat. Medal",
        left_ear="Mache Earring +1",
        right_ear="Mache Earring +1",
        body="Maculele Casaque",
        hands="Mummu Wrists +2",
        left_ring="Sroda Ring",
        right_ring="Mummu Ring",
        back={ name="Senuna's Mantle", augments={'DEX+20', 'Accuracy+20 Attack+20', '"Dbl.Atk."+10'} },
        waist="Sinew Belt",
        legs="Meg. Chausses +1",
        feet="Mummu Gamash. +2",
    })

    -- Pyrrhic Kleos: Physical (STR:40%, DEX:40%)
    sets.precast.WS['Pyrrhic Kleos'] = set_combine(sets.precast.WS, {
        -- main="Tauret",
        -- sub={ name="Polyhymnia", augments={'Accuracy+50', '"Store TP"+8', 'Weapon skill damage +5%'} },
        ammo="Focal Orb",
        head="Nyame Helm",
        neck="Rep. Plat. Medal",
        left_ear="Mache Earring +1",
        right_ear="Cessance Earring",
        body="Malignance Tabard",
        hands="Mummu Wrists +2",
        left_ring="Sroda Ring",
        right_ring="Epaminondas's Ring",
        back={ name="Senuna's Mantle", augments={'DEX+20', 'Accuracy+20 Attack+20', '"Dbl.Atk."+10'} },
        waist="Sinew Belt",
        legs="Meg. Chausses +1",
        feet="Nyame Sollerets",
    })

    -- Rudra's Storm: Physical (DEX:80%)
    sets.precast.WS["Rudra's Storm"] = set_combine(sets.precast.WS, {
        -- main="Tauret",
        -- sub={ name="Polyhymnia", augments={'Accuracy+50', '"Store TP"+8', 'Weapon skill damage +5%'} },
        ammo="Oshasha's Treatise",
        head="Mummu Bonnet +2",
        neck="Rep. Plat. Medal",
        left_ear={ name="Moonshade Earring", augments={'Accuracy+4', 'TP Bonus +250'} },
        right_ear="Cessance Earring",
        body="Malignance Tabard",
        hands="Meg. Gloves +2",
        left_ring="Sroda Ring",
        right_ring="Epaminondas's Ring",
        back={ name="Senuna's Mantle", augments={'DEX+20', 'Accuracy+20 Attack+20', '"Dbl.Atk."+10'} },
        waist="Sinew Belt",
        legs={ name="Nyame Flanchard", augments={'Path: B'} },
        feet="Mummu Gamash. +2",
    })

end

-------------------------------------------------------------------------------------------------------------------
-- Job-specific hooks for standard casting events.
-------------------------------------------------------------------------------------------------------------------

-- Set eventArgs.handled to true if we don't want any automatic gear equipping to be done.
-- Set eventArgs.useMidcastGear to true if we want midcast gear equipped on precast.
function job_precast(spell, action, spellMap, eventArgs)
end

function job_midcast(spell, action, spellMap, eventArgs)
end

function job_aftercast(spell, action, spellMap, eventArgs)
    -- Add any aftercast logic here
end

-------------------------------------------------------------------------------------------------------------------
-- Job-specific hooks for non-casting events.
-------------------------------------------------------------------------------------------------------------------

function job_buff_change(buff, gain)
    if state.Buff[buff] ~= nil then
        state.Buff[buff] = gain
        if not midaction() then
            handle_equipping_gear(player.status)
        end
    end

    if buff == 'Doom' then
        if gain then
            send_command('@input /p Doomed.')
        end
    end
end

function job_state_change(stateField, newValue, oldValue)
    -- Handle state changes like WeaponLock
    if stateField == 'Weapon Lock' then
        if newValue == true then
            disable('main', 'sub', 'range')
        else
            enable('main', 'sub', 'range')
        end
    end
end

-------------------------------------------------------------------------------------------------------------------
-- User code that supplements standard library decisions.
-------------------------------------------------------------------------------------------------------------------

function job_handle_equipping_gear(playerStatus, eventArgs)
    check_rings()
    check_moving()
end

function check_rings()
    if no_swap_gear:contains(player.equipment.ring1) then
        disable('ring1')
    else
        enable('ring1')
    end
    if no_swap_gear:contains(player.equipment.ring2) then
        disable('ring2')
    else
        enable('ring2')
    end
end

function check_moving()
    -- Movement gear logic can go here
end

-------------------------------------------------------------------------------------------------------------------
-- Utility functions specific to this job.
-------------------------------------------------------------------------------------------------------------------
