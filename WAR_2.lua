-- Falurian WAR GearSwap v3.4.0
--
-- v3.4.0 (2026-09-03) -- converted onto fal-core.lua (data/common/fal-core.lua).
--   ~190 lines of infrastructure removed from this file and 181 call sites repointed at
--   the shared library: profiler, event registry, protected-ring / Fishing / PauseSwaps
--   locks, native movement sampling, Treasure Hunter, and the keybind layout.
--   Behaviour changes, all deliberate:
--     * Treasure Hunter is now a plain ON/OFF toggle (state.TreasureHunter), replacing
--       the Off/Tag/Fulltime mob tracker. RDM retired that design in 2026-07: 'Fulltime'
--       was unreachable on a non-THF job, 'Tag' equipped TH only while ENGAGED so
--       tagging from range wore nothing, and it cost a raw 'action' handler that walked
--       a mob table for every action by anyone in range. Alt+F1 toggles, not cycles.
--     * BerserkAuto moves from plain F10 to Ctrl+F5. F10-F12 are now the universal
--       one-shot action row across every job; a mode toggle does not belong there.
--     * Kiting is explicitly allowed in every defense mode via init{kiting_allowed},
--       which is correct for WAR now that v3.3.9 added customize_defense_set.
--   Verified by test_war_a1/a3b + validate.lua against the pre-conversion file.
--
-- v3.3.9 (2026-09-03) -- audit fixes.  Every change is tagged `v3.3.9 (An)` in place.
--
-- v3.3.9 (2026-09-03) -- audit fixes.  Every change is tagged `v3.3.9 (An)` in place.
--   A1 Kaja Bow overlay is now merged LAST, so DT / Mighty Strikes / Treasure Hunter can
--      no longer strip Chapuli Arrow.  This also ends the A2 weapon-reapply oscillation:
--      weapon_profile_matches('KajaBow') stayed false forever once the arrow was gone.
--   A3 Blurred Shield +1 ("Fencer"+1, sub slot) is now counted -- Fencer rank was low by
--      exactly 1, costing 50 effective TP and keeping Moonshade past the 3000 cap.
--   A4 customize_defense_set added.  Mote skips the melee path entirely whenever
--      DefenseMode ~= 'None', so DT and MEVA silently dropped the kiting ring, all 14
--      gear Dual Wield, Treasure Hunter and the Kaja Bow arrow.
--   A5 weapon_profile_tp_bonus documented as an override hook (it reads a field no
--      profile defines; 0 is the correct answer today, but it read like a live term).
--   A6 King's Justice .Acc / .PDL now layer onto the King's Justice set instead of
--      rebuilding from MultiHit, which discarded six KJ-specific pieces.
--   A7 playstyle_profile_matches no longer mis-reads a boolean `false` mode.
--   A8 the F11 skillchain closer bypasses auto-Berserk, which used to cancel and
--      re-issue it outside the window that manual_sc.pending was still waiting on.
--   Verified NOT a bug, contrary to the audit: Sakpata's Sword and Sakpata's Fists ARE
--      present in ItemStats.lua.  All 105 item references in this file resolve.
-- Warrior-native combat policy on the current Falurian RDM lifecycle/control/HUD foundation.
-- Full install-ready file; native movement, manual skillchain assistance, protected rings,
-- partial Fishing locks, effective-TP/Fencer intelligence, support-job-gated Dual Wield,
-- verified weapon-slot ownership, expanded damage-type coverage, weapon-aware TP routing, dedicated primary WS sets, and inventory-grounded WAR gear policy are self-contained here.

local WAR_RELEASE_VERSION = '3.4.0'
local WAR_RELEASE_DATE = '2026-09-03'
-- @ai:weaponfix v3.3.3 | All delayed weapon-profile equips now bridge through a managed gs c self-command; coroutine timers never call equip() directly. This fixes 2H/grip <-> 1H/shield/offhand transitions that left the HUD in WEAPON MISMATCH.
-- @ai:inventoryaudit v3.3.4 | The raw 2026-08-15 inventory export is the ownership authority. Removes stale Ragnarok/Bravura/Utu Grip references, uses owned Nepenthe Grip for all 2H profiles, and never equips absent Tomahawk ammo.
-- @ai:weaponswap v3.3.5 | Explicit Ctrl+F9/F10 weapon-profile changes are allowed while Engaged and while GearSwap reports midaction(); only Pause/Fishing may block them. General engaged gear refresh is skipped during midaction so the manual weapon transition does not trigger an unrelated full-set resolution.
-- @ai:multiattack v3.3.6 | HUD/reporting now derives live gear Double/Triple Attack from ItemStats and adds WAR trait, Double Attack merits, and all 2100-JP Double Attack Gifts. Raw DA/TA are shown against their 100% rate ceilings; higher-tier multi-attack priority remains a separate proc-order mechanic.
-- @ai:sakpata v3.3.7 | Player-confirmed post-export Sakpata R0 acquisition. Five WAR armor pieces are integrated into DT/MEVA, hard-target TP, Fast Cast, and multi-hit/PDL routes; Sakpata Sword/Fists are catalogued in ItemStats but intentionally excluded from WAR weapon profiles because WAR cannot equip them.
-- @ai:communityaudit v3.3.8 | 2026-08 current-maintained WAR references translated to owned gear: Sakpata hands enter normal TP, four primary WS gain dedicated Normal/Acc/PDL sets, and Normal TP can route by weapon profile (STP vs PDL) without overriding explicit Acc/STP/PDL selections. Finished Cichol/JSE/ranked-Sakpata assumptions remain future-only comments.
local war_res = require('resources')
local war_magical_ws={}
-- The kiting ring is job data: it names a piece of gear this character owns, so it
-- stays here and is handed to FalCore.init{movement_ring=...}. Gear sets reference this
-- constant directly rather than FalCore.move.ring_name, which is only populated once
-- init() has run -- init_gear_sets must not depend on Mote's hook ordering.
local MOVEMENT_RING_NAME='Shneddick Ring'


-- RDM-v2.61 control philosophy translated to WAR: clear Mote's overlapping
-- F9-F12 defaults, use a compact Ctrl combat row, reserve Ctrl+F9-F12 for
-- weapons/lock/Silmaril, and keep HUD/utility controls on Alt.
local WAR_FKEY_MODIFIERS={'','^','!','~','@'}
local function clear_f9_f12_bindings()
    for key_number=9,12 do
        for _,modifier in ipairs(WAR_FKEY_MODIFIERS) do
            send_command('unbind '..modifier..'f'..tostring(key_number))
        end
    end
end
local function clear_legacy_target_bindings()
    send_command('unbind ^-')
    send_command('unbind ^=')
end

local WAR_WEAPON_ORDER_BASE={
    'BunziChopper','KajaChopper','KajaClaymore','KajaLance',
    'NaeglingShield','LoxoticShield','KajaKnuckles','KajaBow',
}
local WAR_WEAPON_ORDER_DW={
    'BunziChopper','KajaChopper','KajaClaymore','KajaLance',
    'NaeglingShield','NaeglingDW','LoxoticShield','LoxoticDW','KajaKnuckles','KajaBow',
}
local WAR_WEAPON_ORDER_ALL=WAR_WEAPON_ORDER_DW
local WAR_WEAPON_META={
    -- tp_style is an automatic preference ONLY while OffenseMode=Normal.
    -- Explicit Acc/STP/PDL selections always win.  This keeps one key cycle
    -- useful while letting the weapon's actual purpose influence TP gearing.
    BunziChopper={label="Bunzi's Chopper / Nepenthe",ws='Upheaval',damage='SLASH',purpose='defensive/Retaliation great-axe profile',tp_style='PDL'},
    KajaChopper={label='Kaja Chopper / Nepenthe',ws='Steel Cyclone',damage='SLASH',purpose='Steel Cyclone +30% specialty',tp_style='STP'},
    KajaClaymore={label='Kaja Claymore / Nepenthe',ws='Ground Strike',damage='SLASH',purpose='Ground Strike +15% specialty',tp_style='STP'},
    KajaLance={label='Kaja Lance / Nepenthe',ws='Impulse Drive',damage='PIERCE',purpose='piercing melee profile; Impulse Drive +40%',tp_style='STP'},
    NaeglingShield={label='Naegling / Blurred Shield +1',ws='Savage Blade',damage='SLASH',purpose='Fencer Savage Blade profile',fencer=true,tp_style='Fencer'},
    NaeglingDW={label='Naegling / Blurred Knife +1',ws='Savage Blade',damage='SLASH',purpose='Dual Wield Savage Blade profile',requires_dw=true,fallback='NaeglingShield',tp_style='STP'},
    LoxoticShield={label='Loxotic Mace / Blurred Shield +1',ws='Judgment',damage='BLUNT',purpose='Fencer blunt profile',fencer=true,tp_style='Fencer'},
    LoxoticDW={label='Loxotic Mace / Blurred Knife +1',ws='Judgment',damage='BLUNT',purpose='Dual Wield blunt profile',requires_dw=true,fallback='LoxoticShield',tp_style='STP'},
    KajaKnuckles={label='Kaja Knuckles',ws='Asuran Fists',damage='BLUNT',purpose='hand-to-hand blunt profile; Asuran Fists +50%',tp_style='STP'},
    KajaBow={label='Naegling / Shield + Kaja Bow',ws='Empyreal Arrow',damage='PIERCE',purpose='melee TP into ranged piercing WS; Empyreal Arrow +50%',fencer=true,ranged=true,tp_style='Fencer'},
}
local WAR_WEAPON_ALIASES={
    bunzi='BunziChopper',bunzichopper='BunziChopper',
    kaja='KajaChopper',kajachopper='KajaChopper',kajaclaymore='KajaClaymore',
    kajalance='KajaLance',lance='KajaLance',impulsedrive='KajaLance',
    naegling='NaeglingShield',savage='NaeglingShield',naeglingshield='NaeglingShield',
    naeglingdw='NaeglingDW',savagedw='NaeglingDW',
    loxotic='LoxoticShield',loxoticmace='LoxoticShield',judgment='LoxoticShield',
    loxoticdw='LoxoticDW',judgmentdw='LoxoticDW',
    kajaknuckles='KajaKnuckles',knuckles='KajaKnuckles',asuranfists='KajaKnuckles',
    kajabow='KajaBow',bow='KajaBow',empyrealarrow='KajaBow',
}
local WAR_CONTEXT_WS_BY_MAIN={
    ["Bunzi's Chopper"]='Upheaval',
    ['Kaja Chopper']='Steel Cyclone',['Kaja Claymore']='Ground Strike',['Kaja Lance']='Impulse Drive',
    ['Naegling']='Savage Blade',['Loxotic Mace']='Judgment',['Kaja Knuckles']='Asuran Fists',
}
local WAR_CONTEXT_WS_BY_RANGE={['Kaja Bow']='Empyreal Arrow'}

-- WAR has no native Dual Wield.  The selectable DW profiles therefore exist
-- only when the current support job/level actually grants the trait.  At this
-- file's ML0 policy, the usual level-49 support jobs reach NIN DW III (25) or
-- DNC DW II (15).  Level-sync reads remain authoritative through
-- player.sub_job_level.
local function war_native_dual_wield()
    local sub=player and player.sub_job or nil
    local level=player and tonumber(player.sub_job_level) or 0
    if sub=='NIN' then
        if level>=45 then return 25,'NIN III' end
        if level>=25 then return 15,'NIN II' end
        if level>=10 then return 10,'NIN I' end
    elseif sub=='DNC' then
        if level>=40 then return 15,'DNC II' end
        if level>=20 then return 10,'DNC I' end
    end
    return 0,'None'
end

local function war_dual_wield_available()
    local value=war_native_dual_wield()
    return value>0
end

local function current_weapon_order()
    return war_dual_wield_available() and WAR_WEAPON_ORDER_DW or WAR_WEAPON_ORDER_BASE
end

local function weapon_profile_available(key)
    local meta=WAR_WEAPON_META[key]
    return meta~=nil and (not meta.requires_dw or war_dual_wield_available())
end

-- Owned WAR-equippable DW pieces.  Patentia Sash's hidden enhancement is DW+5.
-- All three are used in the present DW profiles because even /NIN at capped
-- gear+magic haste still benefits from more than 10 gear-DW, while /DNC needs
-- every available point.
local WAR_DW_GEAR_VALUES={
    ['Suppanomimi']=5,
    ['Eabani Earring']=4,
    ['Patentia Sash']=5,
}
local WAR_DW_GEAR_TOTAL=14

-- Progression policy for this WAR profile.  The file intentionally models the
-- completed end-state even while the character finishes the last Job Points:
-- Job Master / 2100 JP / all WAR Gifts, with Master Level fixed at 0.
-- Do not make combat math depend on live Job Point reads or Master Level unless this
-- explicit policy is intentionally changed.
local WAR_PROGRESSION={
    job_master=true,
    job_points=2100,
    all_gifts=true,
    master_level=0,
}

-- WAR99 reaches native Fencer V. Gear can add three ranks (VI-VIII).
-- With the progression policy above, all four WAR Fencer Gifts are permanently
-- available: +50/+50/+60/+70 TP Bonus = +230 total.
local WAR_FENCER_TP_BY_RANK={[5]=500,[6]=550,[7]=600,[8]=630}
-- v3.3.9 (A3): Blurred Shield +1 carries "Fencer"+1 and lives in the sub slot, which
-- fencer_rank_for_ws_set never scanned.  Because fencer_melee_active() *requires* that
-- shield, its point was guaranteed present and guaranteed uncounted -- every Fencer
-- rank was low by exactly 1, so effective_ws_tp under-reported by 50 TP and
-- apply_max_tp_moonshade kept Moonshade past the 3000 cap, wasting the overflow.
local WAR_FENCER_GEAR_RANK={['War. Beads +2']=1,['Boii Cuisses +1']=2,['Blurred Shield +1']=1}
local WAR_FENCER_GIFT_TP=230
local function war_fencer_gift_tp()
    return WAR_PROGRESSION.all_gifts and WAR_FENCER_GIFT_TP or 0, WAR_PROGRESSION.job_points
end


-- Multi-attack progression policy. WAR's level-99 Double Attack trait is 10%.
-- Double Attack Rate merits add 1% per rank (up to 5). The completed 2100-JP
-- Gift ladder contributes another +10% DA rate total: +2 at 125 JP, +2 at 450,
-- +3 at 1050, and +3 at 1900. The Job Point CATEGORY named Double Attack
-- Effect is intentionally not counted here; it increases physical attack on a
-- doubled hit rather than the chance to proc Double Attack.
local WAR_MULTIATTACK_RATE_CAP=100
local WAR_DOUBLE_ATTACK_TRAIT=10
local WAR_DOUBLE_ATTACK_MERIT_FALLBACK=5
local WAR_DOUBLE_ATTACK_GIFT_THRESHOLDS={
    {jp=125,rate=2},{jp=450,rate=2},{jp=1050,rate=3},{jp=1900,rate=3},
}
local war_da_merit_cache=nil
local war_da_merit_source='assumed'

local function war_double_attack_gift_rate()
    if not WAR_PROGRESSION.all_gifts then return 0 end
    local jp=tonumber(WAR_PROGRESSION.job_points) or 0
    local total=0
    for _,gift in ipairs(WAR_DOUBLE_ATTACK_GIFT_THRESHOLDS) do
        if jp>=gift.jp then total=total+gift.rate end
    end
    return total
end

local function war_double_attack_merit_rate(force)
    if war_da_merit_cache~=nil and not force then return war_da_merit_cache,war_da_merit_source end
    local value=nil
    local ffxi=windower and windower.ffxi
    if ffxi and type(ffxi.get_player)=='function' then
        local ok,info=pcall(ffxi.get_player)
        local merits=ok and info and info.merits or nil
        if type(merits)=='table' then
            value=tonumber(merits.double_attack_rate)
                or tonumber(merits['double attack rate'])
                or tonumber(merits.double_attack)
        end
    end
    if value~=nil then
        war_da_merit_cache=math.max(0,math.min(5,value))
        war_da_merit_source='live'
    else
        war_da_merit_cache=WAR_DOUBLE_ATTACK_MERIT_FALLBACK
        war_da_merit_source='assumed'
    end
    return war_da_merit_cache,war_da_merit_source
end
local WAR_DEFENSE_ORDER={'Normal','DT','MEVA'}
local WAR_PLAYSTYLE_ORDER={'Balanced','MaxTP','DT','MEVA','HardTarget'}
local WAR_PLAYSTYLE_PROFILES={
    Balanced={label='Balanced',modes={{'OffenseMode','Normal'},{'HybridMode','DT'},{'WeaponskillMode','Normal'},{'IdleMode','DT'}},defense='Normal',summary='DT-capped engaged overlay with normal accuracy/WS policy'},
    MaxTP={label='Max TP',modes={{'OffenseMode','STP'},{'HybridMode','Normal'},{'WeaponskillMode','Normal'},{'IdleMode','DT'}},defense='Normal',summary='offensive TP set with defensive overlay disabled'},
    DT={label='Damage Taken',modes={{'OffenseMode','Normal'},{'HybridMode','DT'},{'WeaponskillMode','Normal'},{'IdleMode','DT'}},defense='DT',summary='full emergency DT ownership'},
    MEVA={label='Magic Evasion',modes={{'OffenseMode','Normal'},{'HybridMode','DT'},{'WeaponskillMode','Normal'},{'IdleMode','DT'}},defense='MEVA',summary='full magic-evasion defense ownership'},
    HardTarget={label='Hard Target',modes={{'OffenseMode','Acc'},{'HybridMode','DT'},{'WeaponskillMode','Acc'},{'IdleMode','DT'}},defense='Normal',summary='accuracy-first melee and weaponskills'},
}
local WAR_PLAYSTYLE_ALIASES={balanced='Balanced',default='Balanced',maxtp='MaxTP',tp='MaxTP',dt='DT',meva='MEVA',hardtarget='HardTarget',acc='HardTarget',accuracy='HardTarget'}
local applying_weapon_profile=false
local applying_playstyle=false
local save_war_hud_preferences
local handle_manual_sc_action

-- Native movement is authoritative.  Prerender is only a clock; coordinates are
-- sampled at a fixed low rate and stopping is debounced to avoid ring flicker.
-- [fal-core] FalCore.move.moving -> FalCore.move.moving
-- [fal-core] movement_monitor -> FalCore.move

-------------------------------------------------------------------------------------------------------------------
-- Lifecycle and shared runtime ownership
-------------------------------------------------------------------------------------------------------------------

-- [fal-core] FalCore.runtime -> FalCore.runtime (created by FalCore.init)

-- [fal-core] FalCore.events.track() removed -> FalCore.events.track

-- [fal-core] FalCore.events.unregister_all() removed -> FalCore.events.unregister_all

-- [fal-core] FalCore.ALL_EQUIP_SLOTS -> FalCore.ALL_EQUIP_SLOTS
-- [fal-core] FalCore.FISHING_LOCK_SLOTS -> FalCore.FISHING_LOCK_SLOTS

-- [fal-core] FalCore.locks.pause_active() removed -> FalCore.locks.pause_active
-- [fal-core] FalCore.locks.fishing_active() removed -> FalCore.locks.fishing_active
-- [fal-core] FalCore.locks.frozen() removed -> FalCore.locks.frozen

-- [fal-core] FalCore.util.item_name() removed -> FalCore.util.item_name

local function spell_target_within(spell,yalms)
    local target=spell and spell.target
    local distance=target and tonumber(target.distance)
    if not distance then return false end
    return distance < (yalms+(tonumber(target.model_size) or 0))
end

-------------------------------------------------------------------------------------------------------------------
-- Protected rings and coordinated slot locks
-------------------------------------------------------------------------------------------------------------------

local WARP_GEAR={
    ['Warp Ring']=true,
    ['Dim. Ring (Dem)']=true,
    ['Dim. Ring (Holla)']=true,
    ['Dim. Ring (Mea)']=true,
}

local BOOST_GEAR={
    ['Trizek Ring']=true,
    ['Echad Ring']=true,
    ['Facility Ring']=true,
    ['Capacity Ring']=true,
    ['Jubilee Ring']=true,
    ['Empress Band']=true,
    ['Emperor Band']=true,
}

local NO_SWAP_GEAR={}
for name in pairs(WARP_GEAR) do NO_SWAP_GEAR[name]=true end
for name in pairs(BOOST_GEAR) do NO_SWAP_GEAR[name]=true end

local BOOST_BUFFS={dedication=true,commitment=true}
-- [fal-core] FalCore.locks.releasing -> FalCore.locks.releasing
-- [fal-core] FalCore.locks.ring_state -> FalCore.locks.ring_state

-- [fal-core] FalCore.util.ring_name() removed -> FalCore.util.ring_name

-- [fal-core] FalCore.locks.invalidate_ring_cache() removed -> FalCore.locks.invalidate_ring_cache

-- [fal-core] FalCore.locks.apply_ring() removed -> FalCore.locks.apply_ring

-- [fal-core] FalCore.locks.check_rings() removed -> FalCore.locks.check_rings

-- [fal-core] FalCore.locks.ring_protected() removed -> FalCore.locks.ring_protected


-- [fal-core] FalCore.locks.apply_fishing_policy() removed -> FalCore.locks.apply_fishing_policy

-- [fal-core] FalCore.locks.clear_fishing_rod() removed -> FalCore.locks.clear_fishing_rod

local weapon_apply_state={generation=0,pending_key=nil,retries=0}
local WEAPON_STAGE_DELAY=0.40
local WEAPON_VERIFY_DELAY=0.50
local WEAPON_MAX_RETRIES=3

local function normalized_slot_name(value)
    local name=FalCore.util.item_name(value)
    if not name or name=='' then return 'empty' end
    return name
end

local function live_weapon_slot(slot)
    local eq=player and player.equipment or {}
    return normalized_slot_name(eq[slot])
end

local function weapon_profile_equip_table(key)
    local desired=sets and sets.weapons and sets.weapons[key] or nil
    if not desired then return nil end
    local result={main=desired.main,sub=desired.sub}
    if key=='KajaBow' then
        result.range=desired.range
        result.ammo=desired.ammo
    else
        result.range=empty
    end
    return result
end

local function weapon_profile_matches(key)
    local desired=sets and sets.weapons and sets.weapons[key] or nil
    if not desired then return false end
    if live_weapon_slot('main')~=normalized_slot_name(desired.main) then return false end
    if live_weapon_slot('sub')~=normalized_slot_name(desired.sub) then return false end
    if key=='KajaBow' then
        if live_weapon_slot('range')~=normalized_slot_name(desired.range) then return false end
        if live_weapon_slot('ammo')~=normalized_slot_name(desired.ammo) then return false end
    elseif live_weapon_slot('range')=='Kaja Bow' then
        return false
    end
    return true
end

local function live_weapon_description()
    local main=live_weapon_slot('main')
    local sub=live_weapon_slot('sub')
    local range=live_weapon_slot('range')
    local text=main..' / '..sub
    if range~='empty' then text=text..' | '..range end
    return text
end

-- GearSwap equip() calls issued directly from coroutine.schedule callbacks do
-- not reliably flush to the client. Timers therefore schedule only a private
-- self-command; the actual equip occurs inside job_self_command's managed
-- GearSwap event, exactly like the native movement refresh bridge.
local function queue_weapon_apply_command(key,generation,stage,delay)
    local token=FalCore.runtime.token
    coroutine.schedule(function()
        if FalCore.runtime.unloading or token~=FalCore.runtime.token then return end
        if generation~=weapon_apply_state.generation then return end
        send_command('gs c _weaponapply '..token..' '..tostring(generation)..' '..tostring(key)..' '..tostring(stage))
    end,delay or 0)
end

local function finish_weapon_profile(key)
    weapon_apply_state.pending_key=nil
    weapon_apply_state.retries=0
    if state and state.WeaponLock and state.WeaponLock.value then
        disable('main','sub')
    else
        enable('main','sub')
    end
    if type(update_hud)=='function' then update_hud(true) end
end

local function run_weapon_apply_stage(key,generation,stage)
    if FalCore.runtime.unloading or generation~=weapon_apply_state.generation then return end
    if not (state and state.WeaponSet and state.WeaponSet.value==key) then return end
    if FalCore.locks.frozen() then return end
    local desired=sets and sets.weapons and sets.weapons[key] or nil
    if not desired then return end

    if weapon_profile_matches(key) then
        finish_weapon_profile(key)
        return
    end

    enable('main','sub','range','ammo')

    if stage=='prepare' then
        -- Establish the main-hand weapon class first. This is essential when
        -- FalCore.move.moving between 2H+grip, 1H+shield/offhand, and H2H because FFXI may
        -- reject a new sub item until the new main has been accepted.
        local first={main=desired.main}
        if key~='KajaBow' then first.range=empty end
        equip(first)
        queue_weapon_apply_command(key,generation,'full',WEAPON_STAGE_DELAY)
        return
    end

    if stage=='full' then
        local full=weapon_profile_equip_table(key)
        if full then equip(full) end
        queue_weapon_apply_command(key,generation,'verify',WEAPON_VERIFY_DELAY)
        return
    end

    -- Verify from the live equipment snapshot after the previous managed equip
    -- has had time to reach the client. A mismatch gets bounded managed retries.
    if stage=='verify' then
        if weapon_profile_matches(key) then
            finish_weapon_profile(key)
            return
        end
        if weapon_apply_state.retries>=WEAPON_MAX_RETRIES then
            weapon_apply_state.pending_key=nil
            enable('main','sub')
            add_to_chat(123,'[WAR Weapon] Could not complete selected profile after '..tostring(WEAPON_MAX_RETRIES)..' retries; live: '..live_weapon_description())
            if type(update_hud)=='function' then update_hud(true) end
            return
        end
        weapon_apply_state.retries=weapon_apply_state.retries+1
        if live_weapon_slot('main')~=normalized_slot_name(desired.main) then
            local first={main=desired.main}
            if key~='KajaBow' then first.range=empty end
            equip(first)
            queue_weapon_apply_command(key,generation,'full',WEAPON_STAGE_DELAY)
        else
            local full=weapon_profile_equip_table(key)
            if full then equip(full) end
            queue_weapon_apply_command(key,generation,'verify',WEAPON_VERIFY_DELAY)
        end
    end
end

local function begin_weapon_profile_apply(key,force)
    if not weapon_profile_available(key) then return false end
    if weapon_apply_state.pending_key==key and not force then return true end
    local desired=sets and sets.weapons and sets.weapons[key] or nil
    if not desired then return false end

    weapon_apply_state.generation=weapon_apply_state.generation+1
    local generation=weapon_apply_state.generation
    weapon_apply_state.pending_key=key
    weapon_apply_state.retries=0
    enable('main','sub','range','ammo')

    -- Always enter through a managed self-command. This is safe both during
    -- startup/init_gear_sets and during live Ctrl+F9/F10 weapon cycling.
    send_command('gs c _weaponapply '..FalCore.runtime.token..' '..tostring(generation)..' '..tostring(key)..' prepare')
    return true
end

local function check_weaponset(force)
    if not sets or not sets.weapons or not state or not state.WeaponSet then return end
    if FalCore.locks.frozen() then return end
    local key=state.WeaponSet.value
    if not weapon_profile_available(key) then return end
    if weapon_profile_matches(key) then
        weapon_apply_state.pending_key=nil
        weapon_apply_state.retries=0
        if state.WeaponLock.value then disable('main','sub') else enable('main','sub') end
        return
    end
    -- WeaponLock protects only a verified live profile. A mismatch always
    -- reopens main/sub and enters the managed staged repair path first.
    begin_weapon_profile_apply(key,force==true)
end

local function reapply_runtime_locks()
    if FalCore.locks.pause_active() then
        disable(unpack(FalCore.ALL_EQUIP_SLOTS))
        return
    end
    if FalCore.locks.fishing_active() then
        FalCore.locks.apply_fishing_policy()
        return
    end
    enable(unpack(FalCore.ALL_EQUIP_SLOTS))
    FalCore.locks.invalidate_ring_cache()
    check_weaponset(true)
    if buffactive and buffactive.doom and sets and sets.buff and sets.buff.Doom then
        enable('neck','ring1','ring2','waist')
        equip(sets.buff.Doom)
        disable('neck','ring1','ring2','waist')
        return
    end
    FalCore.locks.check_rings()
end

-- [fal-core] settle_released_ring_slots() removed -> folded into FalCore.locks.release_rings

-- [fal-core] FalCore.locks.release_rings() removed -> FalCore.locks.release_rings

-------------------------------------------------------------------------------------------------------------------
-- Treasure Hunter: Off / Tag / Fulltime
-------------------------------------------------------------------------------------------------------------------

-- [fal-core] th_tracker -> FalCore.th (mob tracker retired)

-- [fal-core] FalCore.util.current_target_mob() removed -> FalCore.util.current_target_mob

-- [fal-core] th_sync_target() removed -> FalCore.th (mob tracker retired, see fal-core th notes)

-- [fal-core] th_should_apply() removed -> FalCore.th.should_apply

-- [fal-core] th_mark_tagged() removed -> FalCore.th (mob tracker retired)

-- v3.4.0: the mob tracker is gone (see the Treasure Hunter note in fal-core.lua).
-- TH is now a plain ON/OFF toggle, so this is just "is this a hostile action".
local function th_action_overlay(spell)
    return FalCore.th.should_apply(spell)
end

-- [fal-core] reset_th_tracker() removed -> FalCore.th (mob tracker retired)

-------------------------------------------------------------------------------------------------------------------
-- Weapon-skill range safety
-------------------------------------------------------------------------------------------------------------------

local WS_RANGE_MULT={
    [0]=0,[2]=1.70,[3]=1.490909,[4]=1.44,[5]=1.377778,[6]=1.30,
    [7]=1.20,[8]=1.30,[9]=1.377778,[10]=1.45,[11]=1.490909,[12]=1.70,
}

local function ws_max_distance(spell)
    if not spell or not spell.target then return nil end
    local range=tonumber(spell.range)
    local mult=range and WS_RANGE_MULT[range]
    if not mult then return nil end
    return (tonumber(spell.target.model_size) or 0)+(range*mult)
end

local function ws_out_of_range(spell)
    if not spell or spell.type~='WeaponSkill' or not spell.target or spell.target.type~='MONSTER' then
        return false,nil
    end
    local actual=tonumber(spell.target.distance)
    local maxd=ws_max_distance(spell)
    if not actual or not maxd then return false,maxd end
    return actual>(maxd+0.20),maxd
end

-------------------------------------------------------------------------------------------------------------------
-- Bounded Silence recovery and Doom ownership
-------------------------------------------------------------------------------------------------------------------

local silence_echo={attempts=0,active=false,generation=0}

local function try_echo_drops(generation)
    if FalCore.runtime.unloading or generation~=silence_echo.generation then return end
    if not buffactive or not buffactive.silence then
        if silence_echo.active and silence_echo.attempts>0 then add_to_chat(158,'[WAR] Silence removed.') end
        silence_echo.active=false
        silence_echo.attempts=0
        if type(update_hud)=='function' then update_hud(false) end
        return
    end
    if silence_echo.attempts>=3 then
        add_to_chat(123,'[WAR] Echo Drops cap (3) reached; Silence remains.')
        silence_echo.active=false
        return
    end
    silence_echo.attempts=silence_echo.attempts+1
    send_command('input /item "Echo Drops" <me>')
    add_to_chat(123,'[WAR] Silenced: Echo Drops '..silence_echo.attempts..'/3')
    coroutine.schedule(function() try_echo_drops(generation) end,4)
end

local function set_doom_policy(gain)
    if not sets or not sets.buff or not sets.buff.Doom then return end
    if gain then
        enable('neck','ring1','ring2','waist')
        equip(sets.buff.Doom)
        disable('neck','ring1','ring2','waist')
        add_to_chat(123,'[WAR] DOOMED: recovery gear equipped/locked. Spam Holy Water.')
        send_command('@input /p Doomed.')
    else
        enable('neck','ring1','ring2','waist')
        FalCore.locks.invalidate_ring_cache()
        reapply_runtime_locks()
        if state and state.PauseSwaps and not state.PauseSwaps.value and
           state.FishingMode and not state.FishingMode.value and
           type(handle_equipping_gear)=='function' and player then
            handle_equipping_gear(player.status)
        end
    end
end

-------------------------------------------------------------------------------------------------------------------
-- Safe Berserk-before-WS controller
-------------------------------------------------------------------------------------------------------------------

-- `suppress_next` (v3.3.9, A8) lets a caller issue exactly one weapon skill that
-- queue_berserk_before_ws must not intercept.  It lives here rather than on manual_sc
-- because manual_sc is declared far below queue_berserk_before_ws, and referencing it
-- from there would resolve to a nil global.
local berserk_sequence={pending=nil,generation=0,suppress_next=false}

local function ability_ready(name)
    local ja=war_res.job_abilities and war_res.job_abilities:with('en',name)
    local fn=windower and windower.ffxi and windower.ffxi.get_ability_recasts
    if not ja or type(fn)~='function' then return false end
    local recasts=fn() or {}
    return (tonumber(recasts[ja.recast_id]) or 0)==0
end

local function clear_berserk_sequence()
    berserk_sequence.pending=nil
    berserk_sequence.generation=berserk_sequence.generation+1
end

local function queue_berserk_before_ws(spell,eventArgs)
    if berserk_sequence.pending then
        cancel_spell()
        eventArgs.cancel=true
        eventArgs.handled=true
        add_to_chat(158,'[WAR Berserk] Waiting for Berserk; duplicate weapon skill request ignored.')
        return true
    end
    -- v3.3.9 (A8): a manual F11 skillchain closer must not be cancelled and re-issued.
    -- Doing so cost ~1s of Berserk animation plus a 0.35s retry inside a 7.5s chain
    -- window, and manual_sc.pending self-clears after 3.0s, so the re-issued WS was no
    -- longer matched by sc_confirm_pending and the chain silently failed to register.
    if berserk_sequence.suppress_next then
        berserk_sequence.suppress_next=false
        return false
    end
    if not state.BerserkAuto.value or buffactive.berserk or not ability_ready('Berserk') then return false end
    if state.PauseSwaps.value or state.FishingMode.value then return false end
    local target_id=spell.target and spell.target.id or nil
    if not target_id then return false end

    cancel_spell()
    eventArgs.cancel=true
    eventArgs.handled=true
    berserk_sequence.generation=berserk_sequence.generation+1
    local generation=berserk_sequence.generation
    berserk_sequence.pending={ws=spell.english,target_id=target_id,generation=generation}
    add_to_chat(158,'[WAR Berserk] Holding '..spell.english..'; using Berserk first.')
    send_command('input /ja "Berserk" <me>')

    local token=FalCore.runtime.token
    coroutine.schedule(function()
        if FalCore.runtime.unloading or token~=FalCore.runtime.token then return end
        local pending=berserk_sequence.pending
        if pending and pending.generation==generation then
            add_to_chat(123,'[WAR Berserk] Retry timed out; weapon skill was not reissued.')
            clear_berserk_sequence()
        end
    end,4)
    return true
end

local function retry_berserk_ws(spell)
    local pending=berserk_sequence.pending
    if not pending or not spell or spell.english~='Berserk' then return end
    local generation=pending.generation
    local token=FalCore.runtime.token
    if spell.interrupted then
        add_to_chat(123,'[WAR Berserk] Berserk failed; weapon skill was not reissued.')
        clear_berserk_sequence()
        return
    end

    coroutine.schedule(function()
        if FalCore.runtime.unloading or token~=FalCore.runtime.token then return end
        local p=berserk_sequence.pending
        if not p or p.generation~=generation then return end
        if state.PauseSwaps.value or state.FishingMode.value or (player.tp or 0)<1000 then
            add_to_chat(123,'[WAR Berserk] Retry canceled: mode changed or TP is below 1000.')
            clear_berserk_sequence()
            return
        end
        local mob=FalCore.util.current_target_mob()
        if not mob or mob.id~=p.target_id or (mob.hpp and mob.hpp<=0) then
            add_to_chat(123,'[WAR Berserk] Retry canceled: original target is no longer selected/alive.')
            clear_berserk_sequence()
            return
        end
        local ws=p.ws
        clear_berserk_sequence()
        windower.chat.input('/ws "'..ws..'" <t>')
    end,0.35)
end

-------------------------------------------------------------------------------------------------------------------
-- Lightweight native movement / kiting
-------------------------------------------------------------------------------------------------------------------

-- [fal-core] FalCore.move.requested() removed -> FalCore.move.requested

-- [fal-core] FalCore.move.ring_slot() removed -> FalCore.move.ring_slot

local function movement_route_label()
    if not FalCore.move.requested() then return 'idle' end
    if FalCore.locks.pause_active() then return 'blocked:pause' end
    if buffactive and buffactive.doom then return 'blocked:doom' end
    local slot=FalCore.move.ring_slot()
    if not slot then return 'blocked:rings' end
    local equipped=FalCore.util.ring_name(slot)==MOVEMENT_RING_NAME
    return 'native/'..slot..'/'..(equipped and 'equipped' or 'pending')
end

-- [fal-core] FalCore.move.check() removed -> FalCore.move.check

-- raw_register_event is deliberately retained for the high-frequency clock:
-- unlike a normal GearSwap event it has almost no per-frame wrapper overhead.
-- A raw callback cannot flush GearSwap's equip queue, however, so movement
-- transitions cross back into a normal `gs c` event before rebuilding gear.
-- [fal-core] FalCore.move.queue_refresh() removed -> FalCore.move.queue_refresh

-- [fal-core] FalCore.move.sample() removed -> FalCore.move.sample

-------------------------------------------------------------------------------------------------------------------
-- Action and zone events
-------------------------------------------------------------------------------------------------------------------

local function handle_war_action(act)
    if FalCore.runtime.unloading or not act then return end
    if handle_manual_sc_action then handle_manual_sc_action(act) end

    if not player or act.actor_id~=player.id then return end
    -- v3.4.0: the TH "tag" tracker is retired. It only ever worked while ENGAGED, so
    -- tagging from range wore no TH gear at all, and it cost a raw 'action' handler that
    -- walked a mob table for every action by anyone in range. See fal-core.lua.
end

local function register_war_events()
    FalCore.events.unregister_all()
    if windower and type(windower.raw_register_event)=='function' then
        FalCore.events.track(windower.raw_register_event('action',handle_war_action))
        FalCore.events.track(windower.raw_register_event('prerender',FalCore.move.sample))
    end
    if windower and type(windower.register_event)=='function' then
        FalCore.events.track(windower.register_event('zone change',function()
            if FalCore.runtime.unloading then return end
            clear_berserk_sequence()
            if type(sc_cancel)=='function' then sc_cancel('zone change') end
            FalCore.move.moving=false
            FalCore.move.x,FalCore.move.y,FalCore.move.z=nil,nil,nil
            FalCore.move.last_motion_at=0
            FalCore.move.refresh_pending=true
            local slots={}
            if WARP_GEAR[FalCore.util.ring_name('ring1')] then slots[#slots+1]='ring1' end
            if WARP_GEAR[FalCore.util.ring_name('ring2')] then slots[#slots+1]='ring2' end
            if #slots>0 then FalCore.locks.release_rings(slots,'zone change') end
            if type(update_hud)=='function' then update_hud(false) end
        end))
    end
end

-------------------------------------------------------------------------------------------------------------------
-- Mote setup
-------------------------------------------------------------------------------------------------------------------

function get_sets()
    mote_include_version=2
    include('ItemStats.lua')

    -- Shared infrastructure. GearSwap's include(file, table) sets the chunk environment
    -- to FalCore with __index falling through to this job's environment, so Core reads
    -- live sets/state/player but cannot be shadowed by anything defined here.
    -- The require_version call is NOT optional: include_user runs the chunk under pcall
    -- and DISCARDS the error, so a partial load is otherwise silent.
    FalCore = {}
    include('fal-core.lua', FalCore)
    FalCore.require_version('1.2.0', 'WAR')

    include('Mote-Include.lua')
end

function job_setup()
    state.Buff.Berserk=buffactive.berserk or false
    state.Buff.Warcry=buffactive.warcry or false
    state.Buff.Aggressor=buffactive.aggressor or false
    state.Buff.Defender=buffactive.defender or false
    state.Buff.Retaliation=buffactive.retaliation or false
    state.Buff.Restraint=buffactive.restraint or false
    state.Buff['Blood Rage']=buffactive['blood rage'] or false
    state.Buff["Warrior's Charge"]=buffactive["warrior's charge"] or false
    state.Buff['Mighty Strikes']=buffactive['mighty strikes'] or false
    state.Buff['Brazen Rush']=buffactive['brazen rush'] or false
    state.Buff.Doom=buffactive.doom or false
end

function user_setup()
    FalCore.init{
        job = 'WAR',
        movement_ring = MOVEMENT_RING_NAME,
        -- RDM suppresses kiting whenever a defensive set owns the gear. WAR does not:
        -- v3.3.9 added customize_defense_set, so the movement overlay is applied on top
        -- of the selected PDT/MEVA set rather than being dropped. This is a real job
        -- policy difference, not drift.
        kiting_allowed = function() return true end,
        -- WAR keeps its own `moving` for HUD/report code; Core owns the authoritative flag.
        on_movement_change = function(m) moving = m end,
    }
    applying_weapon_profile=false
    applying_playstyle=false

    state.OffenseMode:options('Normal','Acc','STP','PDL')
    state.HybridMode:options('Normal','DT')
    state.WeaponskillMode:options('Normal','Acc','PDL')
    state.IdleMode:options('Normal','DT','Reraise')
    state.PhysicalDefenseMode:options('PDT')
    if state.PhysicalDefenseMode then state.PhysicalDefenseMode:set('PDT') end
    if state.MagicalDefenseMode then
        state.MagicalDefenseMode:options('MEVA')
        state.MagicalDefenseMode:set('MEVA')
    end
    if state.Kiting and type(state.Kiting.set)=='function' then state.Kiting:set(false) end
    apply_kiting=function(baseSet) return baseSet end

    state.WeaponSet=M{['description']='Weapon Set',unpack(WAR_WEAPON_ORDER_ALL)}
    state.WeaponLock=M(true,'Weapon Lock')
    state.Playstyle=M{['description']='Playstyle','Custom','Balanced','MaxTP','DT','MEVA','HardTarget'}
    state.BerserkAuto=M(false,'Berserk Auto')
    state.PauseSwaps=M(false,'Pause Gear Swapping')
    state.FishingMode=M(false,'Fishing Mode')
    -- v3.4.0: was M{'Off','Tag','Fulltime'}. Only 'Off'/'Tag' were ever reachable on a
    -- non-THF job and 'Tag' equipped TH only while engaged. RDM replaced this with a
    -- plain toggle in 2026-07; WAR now matches. Alt+F1 toggles instead of cycling.
    state.TreasureHunter=M(false,'Treasure Hunter')
    state.Auto_Kite=M(false,'Auto_Kite')

    clear_f9_f12_bindings()
    clear_legacy_target_bindings()
    -- v3.4.0: the layout is now data in fal-core.lua, shared by every job.
    -- Ctrl+F5 takes BerserkAuto, which was on plain F10: F10-F12 are the universal
    -- one-shot action row (magic burst / close skillchain / best WS) and a mode toggle
    -- does not belong there. WAR implements skillchain and bestws, not magicburst.
    FalCore.keys.apply{
        action_row = {'skillchain','bestws'},
        job_slots  = {
            ['^f4'] = 'gs c cycle WeaponskillMode',
            ['^f5'] = 'gs c toggle BerserkAuto',
        },
    }

    -- Explicitly clear retired Win-letter controls from v3.1 and older RDM-style defaults.
    for _,key in ipairs({'w','r','e','b','p','h','f','t','z','v'}) do send_command('unbind @'..key) end
    send_command('unbind ^@h')

    FalCore.move.moving=false
    FalCore.move.next_sample=0
    FalCore.move.last_motion_at=0
    FalCore.move.x,FalCore.move.y,FalCore.move.z=nil,nil,nil
    FalCore.move.refresh_pending=false
    FalCore.move.refresh_queued=false
    FalCore.move.last_route_label=nil

    init_hud()
    register_war_events()
    if buffactive and buffactive.silence then
        silence_echo.generation=silence_echo.generation+1
        silence_echo.active=true
        silence_echo.attempts=0
        try_echo_drops(silence_echo.generation)
    end
    set_macro_page(2,11)
    send_command('wait 4;gs c _startupkeys '..FalCore.runtime.token)
    send_command('wait 2;input /lockstyleset 40')
end

function user_unload()
    if save_war_hud_preferences then save_war_hud_preferences(true) end
    FalCore.runtime.unloading=true
    FalCore.runtime.token='unloaded-'..tostring(os.clock())
    if type(sc_cancel)=='function' then sc_cancel('unload') end
    clear_berserk_sequence()
    silence_echo.generation=silence_echo.generation+1
    silence_echo.active=false
    -- Core unbinds exactly the keys it bound and unregisters exactly the events it
    -- tracked, so neither list can drift from what was actually applied.
    FalCore.unload()
    clear_f9_f12_bindings()
    clear_legacy_target_bindings()
    for _,key in ipairs({'w','r','e','b','p','h','f','t','z','v'}) do send_command('unbind @'..key) end
    send_command('unbind ^@h')
    if war_hud then war_hud:hide() end
end

-------------------------------------------------------------------------------------------------------------------
-- Gear sets
-------------------------------------------------------------------------------------------------------------------

function init_gear_sets()
    war_gear=war_gear or {}
    -- Current-inventory fallbacks.  Brigantia's Mantle is DRG-only; Null
    -- Shawl is WAR-equippable and remains the strongest completed TP/WS cape
    -- until dedicated Cichol's Mantles are actually finished.  Community-audit
    -- roadmap (future only; NEVER synthesize these augments):
    --   TP:  DEX/Acc+Atk/STP+10/PDT-10 (or DA+10 after final x-hit review)
    --   WS:  STR/Acc+Atk/WSD+10/PDT-10
    --   Upheaval specialty later: VIT/Acc+Atk/WSD+10/PDT-10 if resources allow.
    war_gear.ws_cape='Null Shawl'
    war_gear.tp_cape='Null Shawl'
    war_gear.berserk_cape={name="Cichol's Mantle",augments={'DEX+20','Accuracy+10 Attack+10'}}
    war_gear.magic_cape='Toro Cape'
    war_gear.nyame_legs={name='Nyame Flanchard',augments={'Path: B'}}
    war_gear.sailfi={name='Sailfi Belt +1',augments={'Path: A'}}
    war_gear.moonshade={name='Moonshade Earring',augments={'Accuracy+4','TP Bonus +250'}}
    war_gear.alabaster={name='Alabaster Earring',augments={'Path: A'}}

    -- Post-export acquisition confirmed 2026-08-16: all Sakpata pieces are owned
    -- at R0 (no Odyssey RP augments).  GearSwap's inventory name for the body
    -- is "Sakpata's Plate".  Sakpata's Sword (RDM/PLD/BLU) and Fists
    -- (MNK/PUP) live in ItemStats for account-wide truth but are not WAR-valid.

    -- Every profile owns both weapon slots.  WeaponLock protects the selected
    -- profile; it does not block cycling to another profile through Ctrl+F9/F10.
    -- Raw-export-owned weapon profiles only. Nepenthe Grip is the strongest
    -- owned general 2H grip here (Attack+10, Store TP+5); the stale Utu/RMEA
    -- assumptions from older WAR files are intentionally gone.
    sets.weapons={
        BunziChopper={main="Bunzi's Chopper",sub='Nepenthe Grip'},
        KajaChopper={main='Kaja Chopper',sub='Nepenthe Grip'},
        KajaClaymore={main='Kaja Claymore',sub='Nepenthe Grip'},
        KajaLance={main='Kaja Lance',sub='Nepenthe Grip'},
        NaeglingShield={main='Naegling',sub='Blurred Shield +1'},
        NaeglingDW={main='Naegling',sub='Blurred Knife +1'},
        LoxoticShield={main='Loxotic Mace',sub='Blurred Shield +1'},
        LoxoticDW={main='Loxotic Mace',sub='Blurred Knife +1'},
        KajaKnuckles={main='Kaja Knuckles',sub='empty'},
        -- Keep Fencer active while meleeing with Naegling/Shield; Kaja Bow and
        -- Chapuli Arrow are owned continuously by the profile and reasserted
        -- after ordinary TP/DT resolution so the ranged WS can fire immediately.
        KajaBow={main='Naegling',sub='Blurred Shield +1',range='Kaja Bow',ammo='Chapuli Arrow'},
    }
    sets.weapons.KajaBowOverlay={range='Kaja Bow',ammo='Chapuli Arrow'}

    sets.idle={
        ammo='Staunch Tathlum +1',
        head='Nyame Helm',
        neck='Null Loop',
        ear1='Etiolation Earring',
        ear2=war_gear.alabaster,
        body='Nyame Mail',
        hands='Nyame Gauntlets',
        ring1='Chirich Ring +1',
        ring2='Chirich Ring +1',
        back=war_gear.tp_cape,
        waist="Carrier's Sash",
        legs=war_gear.nyame_legs,
        feet='Nyame Sollerets',
    }
    local idle_base=set_combine(sets.idle,{})
    -- Sakpata R0 five-piece = DT-40 with the same 674 armor-slot M.Eva as
    -- the current Nyame five-piece.  Staunch + Null Loop + Alabaster take
    -- total untyped DT beyond 50 without spending a ring slot on Murky.
    sets.idle.DT=set_combine(idle_base,{
        head="Sakpata's Helm",
        body="Sakpata's Plate",
        hands="Sakpata's Gauntlets",
        legs="Sakpata's Cuisses",
        feet="Sakpata's Leggings",
        ear1='Eabani Earring',
        ring1='Chirich Ring +1',
        ring2='Chirich Ring +1',
    })
    -- No Reraise Earring exists in the current inventory catalog.  Preserve
    -- the mode as a safe DT fallback instead of attempting an impossible swap.
    sets.idle.Reraise=set_combine(sets.idle.DT,{})
    sets.resting=set_combine(sets.idle.DT,{})

    -- Updated 2026-08-15 offensive TP core.  The new +2/+1 Flamma pieces,
    -- Pummeler feet and Ioskeha +1 reach the gear-haste cap while substantially
    -- improving STP/multiattack over the old Sailfi/Flam-Gambieras combination.
    sets.engaged={
        ammo='Focal Orb',
        head='Flam. Zucchetto +2',
        neck='Null Loop',
        ear1='Telos Earring',
        ear2='Boii Earring',
        body='Flamma Korazin +2',
        hands="Sakpata's Gauntlets", -- R0: same DA as Sulevia +2, +PDL/+DT/+MEva for only -3 Acc/-7 Atk
        ring1='Niqmaddu Ring',
        ring2='Chirich Ring +1',
        back=war_gear.tp_cape,
        waist='Ioskeha Belt +1',
        legs='Flamma Dirs +1',
        feet='Pumm. Calligae +2',
    }
    local engaged_base=set_combine(sets.engaged,{})
    sets.engaged.Acc=set_combine(engaged_base,{
        ammo='Eschan Stone',
        neck='Null Loop',
        ear1='Mache Earring +1',
        ear2='Telos Earring',
        -- R0 Sakpata keeps Acc+40 per slot while adding meaningful DA/PDL/DT.
        -- Nyame feet remain here because their 3% haste makes this exact armor
        -- mix + Ioskeha +1 reach the 25% gear-haste bucket without Alabaster.
        body="Sakpata's Plate",
        hands="Sakpata's Gauntlets",
        ring2='Chirich Ring +1',
        legs="Sakpata's Cuisses",
        feet='Nyame Sollerets',
    })
    sets.engaged.STP=set_combine(engaged_base,{
        ear1='Telos Earring',
        ear2='Cessance Earring',
        body='Flamma Korazin +2',
        ring1='Chirich Ring +1',
        ring2='Chirich Ring +1',
        legs='Flamma Dirs +1',
    })

    -- High-attack / white-damage PDL route.  This is intentionally NOT
    -- full Sakpata at R0: keeping Flam. head + Pummeler feet preserves the
    -- 25% gear-haste bucket and useful TA/STP/DA while Sakpata body/hands/legs
    -- contribute PDL+21. Sroda trades one STP ring for another +3 PDL.
    sets.engaged.PDL=set_combine(engaged_base,{
        body="Sakpata's Plate",
        hands="Sakpata's Gauntlets",
        ring2='Sroda Ring',
        legs="Sakpata's Cuisses",
    })

    -- Dual Wield profiles are support-job gated.  These three owned pieces
    -- provide 14 gear-DW total and are applied after the ordinary TP/DT family
    -- so the delay-reduction requirement wins its slots while dual wielding.
    sets.engaged.DWOverlay={
        ear1='Suppanomimi',
        ear2='Eabani Earring',
        waist='Patentia Sash',
    }

    -- R0 Sakpata hybrid: five armor pieces provide DT-40 / DA+30 / PDL+30.
    -- Armor haste is only ~16%, so Ioskeha +1 (inherited, +8%) plus Alabaster
    -- (+5%) keep the live melee set at the 25% equipment-haste cap.  Staunch,
    -- Null Loop and Alabaster take untyped DT to 53%, leaving Niqmaddu/Chirich
    -- free instead of paying the old Murky-ring offensive cost.
    sets.engaged.DTOverlay={
        ammo='Staunch Tathlum +1',
        head="Sakpata's Helm",
        ear2=war_gear.alabaster,
        body="Sakpata's Plate",
        hands="Sakpata's Gauntlets",
        legs="Sakpata's Cuisses",
        feet="Sakpata's Leggings",
    }

    -- Fencer profile is automatic for Naegling/Shield and Loxotic/Shield.
    -- Boii Cuisses +1 contributes Fencer+2; War. Beads +2 adds Fencer+1.
    sets.engaged.Fencer=set_combine(engaged_base,{
        neck='War. Beads +2',
        legs='Boii Cuisses +1',
    })
    sets.engaged.Fencer.Acc=set_combine(sets.engaged.Fencer,{
        ammo='Eschan Stone',
        ear1='Mache Earring +1',
        body="Sakpata's Plate",
        hands="Sakpata's Gauntlets",
        legs="Sakpata's Cuisses",
        feet='Nyame Sollerets',
    })
    sets.engaged.Fencer.STP=set_combine(sets.engaged.Fencer,{
        ear1='Telos Earring',
        ear2='Cessance Earring',
        body='Flamma Korazin +2',
        ring1='Chirich Ring +1',
        ring2='Chirich Ring +1',
    })
    -- Fencer PDL route preserves War. Beads +2 + Boii Cuisses +1 (+3
    -- Fencer ranks) while adding Sakpata body/hands/feet and Sroda.  Boii's
    -- 8% leg haste lets this remain safely over the equipment-haste cap.
    sets.engaged.Fencer.PDL=set_combine(sets.engaged.Fencer,{
        body="Sakpata's Plate",
        hands="Sakpata's Gauntlets",
        ring2='Sroda Ring',
        feet="Sakpata's Leggings",
    })
    -- Fencer hybrid deliberately keeps War. Beads +2 and Boii Cuisses +1 so
    -- the +3 Fencer ranks / effective-TP advantage survives.  Four Sakpata
    -- armor slots add DT-31; Staunch + Etiolation + Alabaster + Murky bring
    -- the set above 50% DT.  Boii legs' 8% haste means the inherited Ioskeha
    -- still caps equipment haste even though Sakpata feet are only 2% haste.
    sets.engaged.FencerDTOverlay={
        ammo='Staunch Tathlum +1',
        head="Sakpata's Helm",
        ear1='Etiolation Earring',
        ear2=war_gear.alabaster,
        body="Sakpata's Plate",
        hands="Sakpata's Gauntlets",
        ring1='Murky Ring',
        feet="Sakpata's Leggings",
    }

    -- All native WAR job abilities are covered.  Where enhancing JSE is not
    -- owned, the active set deliberately falls back to safe combat gear.
    -- Current owned JSE upgrades are already routed for Berserk (Cichol),
    -- Warcry (Agoge Mask +3), and Blood Rage (Rvg. Lorica +1). Remaining
    -- future upgrade targets:
    --   Berserk       Pummeler's Lorica +3 / Agoge Calligae +3 / dedicated WAR cape
    --   Aggressor     Pummeler's Mask +3 / Agoge Lorica +3
    --   Defender      Agoge Mufflers +3
    --   Retaliation   Boii Calligae +3
    --   Restraint     Boii Mufflers +3
    --   Blood Rage    Boii Lorica +3
    --   Tomahawk      Agoge Calligae +3. No Thr. Tomahawk stack is present
    --                 in the 2026-08-15 export, so the active set cannot
    --                 pretend to equip the consumable.
    sets.precast.JA={}
    sets.precast.JA.Provoke={
        ammo='Staunch Tathlum +1',
        head='Rabid Visor',
        neck='Unmoving Collar +1',
        ear1='Etiolation Earring',
        ear2=war_gear.alabaster,
        body='Nyame Mail',
        hands='Nyame Gauntlets',
        ring1='Vengeful Ring',
        ring2='Murky Ring',
        back='Emico Mantle',
        waist='Sinew Belt',
        legs='Perle Brayettes',
        feet='Eschite Greaves',
    }
    sets.precast.JA.Berserk=set_combine(engaged_base,{back=war_gear.berserk_cape})
    sets.precast.JA.Aggressor=set_combine(engaged_base,{})
    sets.precast.JA.Warcry=set_combine(engaged_base,{head='Agoge Mask +3'})
    sets.precast.JA.Defender=set_combine(sets.idle.DT,{})
    sets.precast.JA.Retaliation=set_combine(engaged_base,{})
    sets.precast.JA.Restraint=set_combine(engaged_base,{})
    sets.precast.JA['Blood Rage']=set_combine(engaged_base,{body='Rvg. Lorica +1'})
    sets.precast.JA["Warrior's Charge"]=set_combine(sets.engaged.STP,{})
    sets.precast.JA['Mighty Strikes']=set_combine(engaged_base,{})
    sets.precast.JA['Brazen Rush']=set_combine(engaged_base,{})
    -- Tomahawk itself still requires the consumable in inventory to execute.
    -- Keep the gear set ownership-valid until a Thr. Tomahawk stack is acquired.
    sets.precast.JA.Tomahawk=set_combine(sets.engaged.Acc,{})

    -- Common support-job actions.  These are useful without introducing any
    -- automation that competes with Silmaril or player intent.
    sets.precast.JA.Meditate=set_combine(sets.engaged.STP,{})
    sets.precast.JA.Sekkanoki=set_combine(sets.engaged.STP,{})
    sets.precast.JA.Sengikori=set_combine(engaged_base,{})
    sets.precast.JA.Hasso=set_combine(engaged_base,{})
    sets.precast.JA.Seigan=set_combine(sets.idle.DT,{})
    sets.precast.JA['Third Eye']=set_combine(sets.idle.DT,{})
    sets.precast.JA.Jump=set_combine(sets.engaged.STP,{})
    sets.precast.JA['High Jump']=set_combine(sets.engaged.STP,{})
    sets.precast.JA.Step=set_combine(sets.engaged.Acc,{})
    sets.precast.JA.Flourish=set_combine(sets.engaged.Acc,{})
    sets.precast.Step=set_combine(sets.engaged.Acc,{})
    sets.precast.Flourish1=set_combine(sets.engaged.Acc,{})
    sets.precast.Flourish2=set_combine(sets.engaged.Acc,{})
    sets.precast.Flourish3=set_combine(sets.engaged.Acc,{})
    -- Waltz potency is driven by the caster's VIT+CHR.  This owned set is a
    -- real healing snapshot rather than the former generic DT fallback.
    sets.precast.Waltz={
        head='Nyame Helm',
        neck='Unmoving Collar +1',
        ear1='Enchntr. Earring +1',
        ear2='Rimeice Earring',
        body='Nyame Mail',
        hands='Sulev. Gauntlets +2',
        ring1='Niqmaddu Ring',
        ring2='Metamor. Ring +1',
        back='Laic Mantle',
        waist="Chuq'aba Belt",
        legs=war_gear.nyame_legs,
        feet='Nyame Sollerets',
    }
    sets.precast.Waltz['Healing Waltz']=set_combine(sets.idle.DT,{})

    -- WAR has little native Fast Cast in the owned catalog, but these pieces
    -- still cover Utsusemi and support-job magic without changing weapons.
    sets.precast.FC={
        ammo='Impatiens',
        head="Sakpata's Helm", -- R0: Fast Cast +8% with DT-7
        neck="Naji's Loop",
        ear1='Loquac. Earring',
        ear2='Enchntr. Earring +1',
        legs='Limbo Trousers',
    }
    sets.precast.FC.Utsusemi=set_combine(sets.precast.FC,{})
    sets.midcast.FastRecast={
        ammo='Staunch Tathlum +1',
        head="Sakpata's Helm", -- same 4% haste as Flamma head, much stronger defensive midcast
        neck='Null Loop',
        ear1='Magnetic Earring',
        ear2=war_gear.alabaster,
        body='Flamma Korazin +2',
        hands='Flam. Manopolas +1',
        ring1='Evanescence Ring',
        ring2='Murky Ring',
        back='Null Shawl',
        waist=war_gear.sailfi,
        legs='Limbo Trousers',
        feet='Flam. Gambieras +1',
    }
    sets.midcast.Utsusemi=set_combine(sets.midcast.FastRecast,{})

    -- Single-hit / WSD physical family.  Moonshade is always in ear2 so the
    -- right-ear-only Boii Earring is the exact 3000-TP replacement.
    sets.precast.WS={
        ammo="Oshasha's Treatise",
        head='Agoge Mask +3',
        neck='Rep. Plat. Medal',
        ear1='Mache Earring +1',
        ear2=war_gear.moonshade,
        body='Nyame Mail',
        hands='Nyame Gauntlets',
        ring1='Niqmaddu Ring',
        ring2="Epaminondas's Ring",
        back=war_gear.ws_cape,
        waist='Sinew Belt',
        legs=war_gear.nyame_legs,
        feet="Sulevia's Leggings",
    }
    local ws_physical_base=set_combine(sets.precast.WS,{})
    sets.precast.WS.Acc=set_combine(ws_physical_base,{
        ammo='Eschan Stone',
        head='Nyame Helm',
        neck='Null Loop',
        ear1='Telos Earring',
        ring2='Chirich Ring +1',
        waist='Null Belt',
        feet='Nyame Sollerets',
    })
    sets.precast.WS.PDL=set_combine(ws_physical_base,{ring1='Sroda Ring'})
    sets.precast.WS.WSD=set_combine(ws_physical_base,{})
    sets.precast.WS.WSD.Acc=set_combine(ws_physical_base,{
        ammo='Eschan Stone',
        head='Nyame Helm',
        neck='Null Loop',
        ear1='Telos Earring',
        ring2='Chirich Ring +1',
        waist='Null Belt',
        feet='Nyame Sollerets',
    })
    sets.precast.WS.WSD.PDL=set_combine(ws_physical_base,{ring1='Sroda Ring'})

    sets.precast.WS.MultiHit=set_combine(ws_physical_base,{
        ammo='Focal Orb',
        head='Flam. Zucchetto +2',
        ear1='Cessance Earring',
        -- At R0 these are already the strongest clear Sakpata WS insertions:
        -- body adds DA+8/PDL+8 and hands DA+6/PDL+6 with far better DT/M.Eva.
        body="Sakpata's Plate",
        hands="Sakpata's Gauntlets",
        ring2='Chirich Ring +1',
        waist='Windbuffet Belt +1',
        legs='Sulev. Cuisses +2',
        feet='Pumm. Calligae +2',
    })
    sets.precast.WS.MultiHit.Acc=set_combine(sets.precast.WS.MultiHit,{
        ammo='Eschan Stone',
        head='Nyame Helm',
        neck='Null Loop',
        ear1='Telos Earring',
        -- Preserve the older higher-direct-accuracy pieces in explicit Acc mode.
        body="Sulevia's Plate. +2",
        hands='Sulev. Gauntlets +2',
        waist='Null Belt',
        legs=war_gear.nyame_legs,
        feet='Nyame Sollerets',
    })
    -- PDL mode means attack support is intentionally assumed high enough to
    -- exploit Physical Damage Limit.  R0 Sakpata 5/5 supplies PDL+30 while
    -- retaining DA+30 and strong defensive stats during the WS snapshot.
    sets.precast.WS.MultiHit.PDL=set_combine(sets.precast.WS.MultiHit,{
        head="Sakpata's Helm",
        body="Sakpata's Plate",
        hands="Sakpata's Gauntlets",
        legs="Sakpata's Cuisses",
        feet="Sakpata's Leggings",
        ring1='Sroda Ring',
    })

    sets.precast.WS.Critical=set_combine(sets.precast.WS.MultiHit,{
        ammo='Yetshila +1',
        ear1='Mache Earring +1',
        hands='Flam. Manopolas +1',
        ring1='Niqmaddu Ring',
        ring2='Chirich Ring +1',
    })
    sets.precast.WS.Critical.Acc=set_combine(sets.precast.WS.Critical,{
        ammo='Eschan Stone',
        head='Nyame Helm',
        neck='Null Loop',
        ear1='Telos Earring',
        body="Sulevia's Plate. +2",
        hands='Sulev. Gauntlets +2',
        waist='Null Belt',
        legs=war_gear.nyame_legs,
        feet='Nyame Sollerets',
    })
    sets.precast.WS.Critical.PDL=set_combine(sets.precast.WS.Critical,{ring1='Sroda Ring'})

    -- Break-family WS are selected for their additional effects.  Maximize
    -- owned magic accuracy rather than inheriting physical damage accessories.
    sets.precast.WS.Break=set_combine(ws_physical_base,{
        ammo='Eschan Stone',
        head='Nyame Helm',
        neck='Null Loop',
        ear1='Enchntr. Earring +1',
        body='Nyame Mail',
        hands='Nyame Gauntlets',
        ring1='Stikini Ring +1',
        ring2='Stikini Ring +1',
        back='Null Shawl',
        waist='Null Belt',
        legs=war_gear.nyame_legs,
        feet='Nyame Sollerets',
    })
    sets.precast.WS.Break.Acc=set_combine(sets.precast.WS.Break,{})
    sets.precast.WS.Break.PDL=set_combine(sets.precast.WS.Break,{ring1='Sroda Ring'})

    sets.precast.WS.Magical={
        ammo="Oshasha's Treatise",
        head='Nyame Helm',
        neck='Sibyl Scarf',
        ear1='Friomisi Earring',
        ear2=war_gear.moonshade,
        body='Nyame Mail',
        hands='Nyame Gauntlets',
        ring1="Epaminondas's Ring",
        ring2='Metamor. Ring +1',
        back=war_gear.magic_cape,
        waist='Skrymir Cord',
        legs=war_gear.nyame_legs,
        feet='Nyame Sollerets',
    }
    sets.precast.WS.Magical.Acc=set_combine(sets.precast.WS.Magical,{
        ammo='Eschan Stone',
        neck='Null Loop',
        ear1='Enchntr. Earring +1',
        ring1='Stikini Ring +1',
        ring2='Stikini Ring +1',
        back='Null Shawl',
        waist='Null Belt',
    })

    -- Spirits Within scales directly with current HP and TP.
    sets.precast.WS['Spirits Within']={
        ammo="Oshasha's Treatise",
        head='Nyame Helm',
        neck='Null Loop',
        ear1=war_gear.alabaster,
        ear2=war_gear.moonshade,
        body='Nyame Mail',
        hands='Nyame Gauntlets',
        ring1='Gelatinous Ring +1',
        ring2='Vengeful Ring',
        back='Emico Mantle',
        waist="Carrier's Sash",
        legs=war_gear.nyame_legs,
        feet='Nyame Sollerets',
    }
    sets.precast.WS['Spirits Within'].Acc=set_combine(sets.precast.WS['Spirits Within'],{})

    local function alias_ws(source,names)
        for _,name in ipairs(names) do sets.precast.WS[name]=source end
    end

    alias_ws(sets.precast.WS.WSD,{
        'Steel Cyclone','Metatron Torment','Fell Cleave',
        'Ground Strike','Mistral Axe','Calamity','Judgment',
        'Retribution','Spinning Slash','Cross Reaper','Spiral Hell',
        'Fast Blade','Hard Slash','Heavy Swing','Full Swing','True Strike',
    })
    alias_ws(sets.precast.WS.MultiHit,{
        'Resolution','Scourge','Decimation','Ruinator',
        'Requiescat','Stardiver','Shattersoul','Realmrazer','Penta Thrust',
        'Guillotine','Vorpal Scythe','Dancing Edge','Shark Bite','Exenterator',
        'Vorpal Blade','Swift Blade','Hexa Strike','Raging Axe','Spinning Axe',
    })
    alias_ws(sets.precast.WS.Critical,{
        "Ukko's Fury",'Raging Rush','Rampage','Evisceration','Drakesbane',
    })
    alias_ws(sets.precast.WS.Break,{
        'Shield Break','Armor Break','Weapon Break','Full Break','Shockwave',
        'Leg Sweep','Shell Crusher','Skullbreaker','Flat Blade','Brainshaker',
        'Shadowstitch','Nightmare Scythe',
    })

    ------------------------------------------------------------------------
    -- Dedicated primary WAR weaponskills -- 2026 community-audit translation
    --
    -- Current maintained WAR files no longer treat these as interchangeable
    -- generic WSD/MultiHit aliases.  The active choices below use ONLY owned
    -- gear and R0 Sakpata.  Future targets are comments, never phantom equips.
    ------------------------------------------------------------------------

    -- UPHEAVAL: multi-hit VIT-weighted great-axe WS.  Community endgame sets
    -- commonly pair Boii JSE with Sakpata.  Until Boii Mask/Cuisses +3 exist,
    -- Agoge Mask +3 retains its WSD and Sakpata body/hands add DA/PDL/defense.
    -- Future: Boii Mask +3, Boii Cuisses +3, Knobkierrie, Schere/Thrud,
    -- Ephramad ring, and a finished VIT/WSD Cichol's Mantle.
    sets.precast.WS['Upheaval']=set_combine(ws_physical_base,{
        head='Agoge Mask +3',
        neck='Null Loop',
        ear1='Cessance Earring',
        body="Sakpata's Plate",
        hands="Sakpata's Gauntlets",
        ring1='Niqmaddu Ring',
        ring2="Epaminondas's Ring",
        waist='Ioskeha Belt +1',
        legs=war_gear.nyame_legs,
        feet="Sulevia's Leggings",
    })
    sets.precast.WS['Upheaval'].Acc=set_combine(sets.precast.WS['Upheaval'],{
        ammo='Eschan Stone',
        neck='Null Loop',
        ear1='Telos Earring',
        ring2='Chirich Ring +1',
        waist='Null Belt',
        feet='Nyame Sollerets',
    })
    sets.precast.WS['Upheaval'].PDL=set_combine(sets.precast.WS['Upheaval'],{
        body="Sakpata's Plate",
        hands="Sakpata's Gauntlets",
        ring2='Sroda Ring',
        legs="Sakpata's Cuisses",
        feet="Sakpata's Leggings",
    })

    -- SAVAGE BLADE: keep the owned WSD core in Normal mode.  At R0 Sakpata
    -- becomes most compelling in explicit PDL mode, matching current high-buff
    -- community practice without pretending the pieces carry Odyssey RP stats.
    -- FencerOverlay still adds War. Beads +2 only when the live shield profile
    -- is actually equipped. Future: Agoge Mask +4, Thrud/Ephramad/Kentarch,
    -- finished STR/WSD Cichol, and stronger Boii JSE as acquired.
    sets.precast.WS['Savage Blade']=set_combine(ws_physical_base,{
        head='Agoge Mask +3',
        neck='Rep. Plat. Medal',
        ear1='Cessance Earring',
        body='Nyame Mail',
        hands='Nyame Gauntlets',
        ring1='Niqmaddu Ring',
        ring2="Epaminondas's Ring",
        waist='Sinew Belt',
        legs=war_gear.nyame_legs,
        feet="Sulevia's Leggings",
    })
    sets.precast.WS['Savage Blade'].Acc=set_combine(sets.precast.WS['Savage Blade'],{
        ammo='Eschan Stone',
        neck='Null Loop',
        ear1='Telos Earring',
        body='Nyame Mail',
        hands='Nyame Gauntlets',
        ring2='Chirich Ring +1',
        waist='Null Belt',
        feet='Nyame Sollerets',
    })
    sets.precast.WS['Savage Blade'].PDL=set_combine(sets.precast.WS['Savage Blade'],{
        body="Sakpata's Plate",
        hands="Sakpata's Gauntlets",
        ring1='Sroda Ring',
        ring2="Epaminondas's Ring",
        legs="Sakpata's Cuisses",
        feet='Nyame Sollerets',
    })

    -- KING'S JUSTICE: true multi-hit routing rather than the old generic alias.
    -- The R0 Sakpata body/hands provide DA+14 and PDL+14; Flamma head, Sulevia
    -- legs and Pummeler feet retain owned multi-attack.  Future: Boii Mask +3,
    -- Boii Mufflers/Cuisses +3, Schere/Boii earring upgrades, Crepuscular
    -- Pebble, Ephramad ring, and finished STR/WSD Cichol.
    sets.precast.WS["King's Justice"]=set_combine(sets.precast.WS.MultiHit,{
        ammo='Focal Orb',
        head='Flam. Zucchetto +2',
        neck='Rep. Plat. Medal',
        ear1='Cessance Earring',
        body="Sakpata's Plate",
        hands="Sakpata's Gauntlets",
        ring1='Niqmaddu Ring',
        ring2="Epaminondas's Ring",
        waist='Windbuffet Belt +1',
        legs='Sulev. Cuisses +2',
        feet='Pumm. Calligae +2',
    })
    -- v3.3.9 (A6): these used to rebuild from sets.precast.WS.MultiHit.*, which threw
    -- away every King's Justice-specific piece -- Rep. Plat. Medal, Niqmaddu Ring,
    -- Epaminondas's Ring, Windbuffet Belt +1, Sulev. Cuisses +2 and Pumm. Calligae +2 --
    -- making .Acc byte-identical to MultiHit.Acc.  The banner above claimed "true
    -- multi-hit routing", which was only true in Normal mode.  They now layer the SAME
    -- Acc / PDL deltas that MultiHit uses on top of the King's Justice base, so slots the
    -- delta does not touch (ring1/ring2 in Acc, ammo/waist/ring2 in PDL) survive.
    sets.precast.WS["King's Justice"].Acc=set_combine(sets.precast.WS["King's Justice"],{
        ammo='Eschan Stone',
        head='Nyame Helm',
        neck='Null Loop',
        ear1='Telos Earring',
        body="Sulevia's Plate. +2",
        hands='Sulev. Gauntlets +2',
        waist='Null Belt',
        legs=war_gear.nyame_legs,
        feet='Nyame Sollerets',
    })
    sets.precast.WS["King's Justice"].PDL=set_combine(sets.precast.WS["King's Justice"],{
        head="Sakpata's Helm",
        body="Sakpata's Plate",
        hands="Sakpata's Gauntlets",
        legs="Sakpata's Cuisses",
        feet="Sakpata's Leggings",
        ring1='Sroda Ring',
    })

    -- IMPULSE DRIVE: no longer a generic WSD alias.  Kaja Lance makes this a
    -- real piercing profile, so the set keeps STR/WSD pieces in Normal and
    -- reserves deeper Sakpata/PDL substitutions for explicit high-attack mode.
    -- Yetshila +1 is retained because current maintained WAR examples snapshot
    -- critical support here. Future: Boii Mask/Mufflers/Cuisses/Calligae +3,
    -- Thrud/Boii earring upgrades, Ephramad ring, and finished STR/WSD Cichol.
    sets.precast.WS['Impulse Drive']=set_combine(ws_physical_base,{
        ammo='Yetshila +1',
        head='Agoge Mask +3',
        neck='Rep. Plat. Medal',
        ear1='Cessance Earring',
        body="Sakpata's Plate",
        hands="Sakpata's Gauntlets",
        ring1='Niqmaddu Ring',
        ring2="Epaminondas's Ring",
        waist='Sinew Belt',
        legs=war_gear.nyame_legs,
        feet="Sulevia's Leggings",
    })
    sets.precast.WS['Impulse Drive'].Acc=set_combine(sets.precast.WS['Impulse Drive'],{
        ammo='Eschan Stone',
        neck='Null Loop',
        ear1='Telos Earring',
        ring2='Chirich Ring +1',
        waist='Null Belt',
        feet='Nyame Sollerets',
    })
    sets.precast.WS['Impulse Drive'].PDL=set_combine(sets.precast.WS['Impulse Drive'],{
        ammo='Yetshila +1',
        body="Sakpata's Plate",
        hands="Sakpata's Gauntlets",
        ring2='Sroda Ring',
        legs="Sakpata's Cuisses",
        feet="Sakpata's Leggings",
    })

    -- Remaining expanded owned weapon coverage.
    sets.precast.WS['Asuran Fists']=sets.precast.WS.MultiHit
    sets.precast.WS['Empyreal Arrow']=set_combine(sets.precast.WS.WSD,{ammo='Chapuli Arrow'})
    sets.precast.WS['Empyreal Arrow'].Acc=set_combine(sets.precast.WS.WSD.Acc,{ammo='Chapuli Arrow'})
    sets.precast.WS['Empyreal Arrow'].PDL=set_combine(sets.precast.WS.WSD.PDL,{ammo='Chapuli Arrow'})
    alias_ws(sets.precast.WS.Magical,{
        'Burning Blade','Red Lotus Blade','Shining Blade','Seraph Blade',
        'Sanguine Blade','Gust Slash','Cyclone','Aeolian Edge',
        'Shining Strike','Seraph Strike','Flash Nova','Rock Crusher',
        'Earth Crusher','Starburst','Sunburst','Cataclysm','Freezebite',
        'Herculean Slash','Cloudsplitter','Dark Harvest','Shadow of Death',
        'Infernal Scythe','Thunder Thrust','Raiden Thrust',
    })

    war_magical_ws={
        ['Burning Blade']=true,['Red Lotus Blade']=true,['Shining Blade']=true,
        ['Seraph Blade']=true,['Sanguine Blade']=true,['Gust Slash']=true,
        Cyclone=true,['Aeolian Edge']=true,['Shining Strike']=true,
        ['Seraph Strike']=true,['Flash Nova']=true,['Rock Crusher']=true,
        ['Earth Crusher']=true,Starburst=true,Sunburst=true,Cataclysm=true,
        Freezebite=true,['Herculean Slash']=true,Cloudsplitter=true,
        ['Dark Harvest']=true,['Shadow of Death']=true,['Infernal Scythe']=true,
        ['Thunder Thrust']=true,['Raiden Thrust']=true,
    }
    -- While actually using a sword/club + shield Fencer profile, War. Beads +2
    -- contributes another Fencer tier during physical damage WS.  Keep the
    -- strong Nyame legs: Boii Cuisses +1 are excellent TP/Fencer legs, but the
    -- current catalog does not establish that their +2 Fencer beats the owned
    -- Path-B Nyame WS legs in every TP/buff state.  Accuracy/debuff and magical
    -- WS keep their dedicated necks instead of receiving this overlay.
    sets.precast.WS.FencerOverlay={neck='War. Beads +2'}
    sets.MaxTP={ear1='Mache Earring +1',ear2='Boii Earring'}
    sets.MaxTP['Spirits Within']={ear1=war_gear.alabaster,ear2='Etiolation Earring'}
    sets.MagicalMaxTP={ear1='Friomisi Earring',ear2='Sortiarius Earring'}

    sets.defense.PDT=set_combine(sets.idle.DT,{})
    sets.defense.MDT=set_combine(sets.idle.DT,{
        neck='Null Loop',
        ear1='Eabani Earring',
        ear2=war_gear.alabaster,
        ring1='Chirich Ring +1',
        ring2='Vengeful Ring',
        back='Null Shawl',
        waist='Null Belt',
    })
    sets.defense.MEVA=set_combine(sets.idle.DT,{
        neck='Null Loop',
        ear1='Eabani Earring',
        ear2=war_gear.alabaster,
        ring1='Chirich Ring +1',
        ring2='Vengeful Ring',
        back='Null Shawl',
        waist='Null Belt',
    })
    -- Keep Mote's built-in apply_kiting() neutral; the custom idle/melee
    -- resolvers below choose the free ring slot after protected-ring policy.
    sets.Kiting={}
    sets.KitingRing1={ring1=MOVEMENT_RING_NAME}
    sets.KitingRing2={ring2=MOVEMENT_RING_NAME}
    sets.TreasureHunter={ammo='Per. Lucky Egg',ring1='Hoxne Ring'}
    sets.TreasureHunterKiting={
        ammo='Per. Lucky Egg',
        ring1='Hoxne Ring',
        ring2=MOVEMENT_RING_NAME,
    }
    sets.Fishing={
        range="Lu Shang's F. Rod",
        body='Fsh. Tunica',
        hands='Fsh. Gloves',
        legs="Fisherman's Hose",
        feet="Fisherman's Boots",
    }
    -- v3.3 buff-state intelligence. Mighty Strikes guarantees physical
    -- critical hits, so Yetshila +1's crit-damage bonus is more valuable than
    -- ordinary crit-rate chasing during the window. Retaliation and Restraint
    -- have no owned armor enhancer yet; their future hooks stay explicit rather
    -- than auto-equipping weaker placeholder armor. Bunzi's Chopper itself
    -- already contributes Retaliation+10 when that weapon profile is selected.
    sets.buff.MightyStrikesTP={ammo='Yetshila +1'}
    sets.buff.MightyStrikesWS={ammo='Yetshila +1'}
    sets.buff.Retaliation={}
    sets.buff.Restraint={}

    sets.buff.Doom={
        neck="Nicander's Necklace",
        ring1="Blenmot's Ring +1",
        ring2="Blenmot's Ring +1",
        waist='Gishdubar Sash',
    }

    check_weaponset(true)
    FalCore.locks.check_rings()
    if state.Buff.Doom then set_doom_policy(true) end
    update_hud(false)
end


-------------------------------------------------------------------------------------------------------------------
-- RDM-derived control layer: atomic weapon profiles, simplified defense, F11/F12
-------------------------------------------------------------------------------------------------------------------

local function normalize_control_token(value)
    return tostring(value or ''):lower():gsub('[%s_%-/]+','')
end
local function ordered_control_index(order,current)
    for i,value in ipairs(order) do if value==current then return i end end
    return 0
end
local function control_action_ready(label)
    if FalCore.locks.frozen() then
        add_to_chat(123,'['..label..'] Blocked while Pause or Fishing owns equipment slots.')
        return false
    end
    if type(midaction)=='function' and midaction() then
        add_to_chat(123,'['..label..'] Finish the current action, then try again.')
        return false
    end
    return state~=nil and player~=nil
end

-- Weapon cycling is an explicit player override, not an automatic gear action.
-- It must remain usable while Engaged and must not be rejected merely because
-- GearSwap reports midaction() during a JA/WS/spell window. Pause and Fishing
-- still retain absolute equipment ownership and therefore remain hard blocks.
local function weapon_control_ready()
    if FalCore.locks.frozen() then
        add_to_chat(123,'[WAR Weapon] Blocked while Pause or Fishing owns equipment slots.')
        return false
    end
    return state~=nil and player~=nil
end
local function set_mode(name,value)
    local st=state and state[name]
    if not (st and type(st.set)=='function') then return false end
    st:set(value)
    return true
end
local function defense_control_mode()
    local mode=state and state.DefenseMode and state.DefenseMode.value or 'None'
    if mode=='Physical' then return 'DT' end
    if mode=='Magical' then return 'MEVA' end
    return 'Normal'
end
local function apply_defense_control(requested,quiet)
    local token=normalize_control_token(requested)
    local key=(token=='normal' or token=='none' or token=='off') and 'Normal'
        or ((token=='dt' or token=='pdt' or token=='mdt') and 'DT')
        or ((token=='meva' or token=='magicevasion') and 'MEVA') or nil
    if not key then
        add_to_chat(158,'[WAR Defense] Normal -> DT -> MEVA | gs c wardefense <normal|dt|meva>')
        return false
    end
    if key=='Normal' then
        set_mode('DefenseMode','None')
    elseif key=='DT' then
        if state.PhysicalDefenseMode then set_mode('PhysicalDefenseMode','PDT') end
        set_mode('DefenseMode','Physical')
    else
        if state.MagicalDefenseMode then set_mode('MagicalDefenseMode','MEVA') end
        set_mode('DefenseMode','Magical')
    end
    if not applying_playstyle and not FalCore.locks.frozen() and not midaction() and type(handle_equipping_gear)=='function' then
        handle_equipping_gear(player.status)
    end
    if type(update_hud)=='function' then update_hud(true) end
    if not quiet then add_to_chat(158,'[WAR Defense] '..key) end
    return true
end
local function cycle_defense_control()
    local i=ordered_control_index(WAR_DEFENSE_ORDER,defense_control_mode())
    i=(i%#WAR_DEFENSE_ORDER)+1
    return apply_defense_control(WAR_DEFENSE_ORDER[i])
end
local function weapon_label(key)
    local meta=WAR_WEAPON_META[key]
    return meta and meta.label or tostring(key or '?')
end
local function weapon_order_text()
    local labels={}
    for _,key in ipairs(current_weapon_order()) do labels[#labels+1]=weapon_label(key) end
    return table.concat(labels,' -> ')
end

local function apply_weapon_profile(requested,quiet)
    if not weapon_control_ready() then return false end
    local key=WAR_WEAPON_META[requested] and requested or WAR_WEAPON_ALIASES[normalize_control_token(requested)]
    local desired=key and sets and sets.weapons and sets.weapons[key] or nil
    if not desired then
        add_to_chat(158,'[WAR Weapon] '..weapon_order_text())
        return false
    end
    if not weapon_profile_available(key) then
        local _,tier=war_native_dual_wield()
        add_to_chat(123,'[WAR Weapon] '..weapon_label(key)..' requires an active Dual Wield support-job trait. Current: '..tier..'.')
        return false
    end
    applying_weapon_profile=true
    state.WeaponSet:set(key)
    applying_weapon_profile=false
    check_weaponset(true)
    -- Do not launch an unrelated full engaged/idle gear resolution in the
    -- middle of an action. The managed _weaponapply bridge owns the explicit
    -- main/sub/range transition; normal gear resolution resumes aftercast.
    if not (type(midaction)=='function' and midaction())
        and type(handle_equipping_gear)=='function' then
        handle_equipping_gear(player.status)
    end
    if type(update_hud)=='function' then update_hud(true) end
    if not quiet then
        local meta=WAR_WEAPON_META[key]
        local _,tier=war_native_dual_wield()
        local suffix=meta.requires_dw and (' | '..tier..' + gear DW '..WAR_DW_GEAR_TOTAL) or ''
        add_to_chat(158,'[WAR Weapon] '..meta.label..' | primary '..meta.ws..' | '..meta.purpose..suffix)
    end
    return true
end
local function cycle_weapon_profile(direction)
    local order=current_weapon_order()
    local current=state and state.WeaponSet and state.WeaponSet.value
    local i=ordered_control_index(order,current)
    local step=(direction=='previous' or direction=='prev' or direction=='back') and -1 or 1
    if i==0 then i=step>0 and 0 or 1 end
    i=((i-1+step)%#order)+1
    return apply_weapon_profile(order[i])
end
local function playstyle_profile_matches(key)
    local profile=WAR_PLAYSTYLE_PROFILES[key]
    if not profile then return false end
    for _,change in ipairs(profile.modes) do
        local st=state and state[change[1]]
        -- v3.3.9 (A7): `a~=nil and a or b` silently falls through to `b` when a==false.
        -- Latent while every compared mode is a string list-mode, but it would misread
        -- the first boolean mode added to a WAR_PLAYSTYLE_PROFILES entry.
        local value=nil
        if st then
            if st.value~=nil then value=st.value else value=st.current end
        end
        if value~=change[2] then return false end
    end
    return defense_control_mode()==profile.defense
end

local function apply_playstyle(requested,quiet)
    if not control_action_ready('WAR Playstyle') then return false end
    local key=WAR_PLAYSTYLE_PROFILES[requested] and requested or WAR_PLAYSTYLE_ALIASES[normalize_control_token(requested)]
    local profile=key and WAR_PLAYSTYLE_PROFILES[key]
    if not profile then
        add_to_chat(158,'[WAR Playstyle] Balanced -> MaxTP -> DT -> MEVA -> HardTarget')
        return false
    end
    applying_playstyle=true
    state.Playstyle:set(key)
    for _,change in ipairs(profile.modes) do set_mode(change[1],change[2]) end
    apply_defense_control(profile.defense,true)
    applying_playstyle=false
    check_weaponset(true)
    if not FalCore.locks.frozen() and not midaction() and type(handle_equipping_gear)=='function' then handle_equipping_gear(player.status) end
    if type(update_hud)=='function' then update_hud(true) end
    if not quiet then add_to_chat(158,'[WAR Playstyle] '..profile.label..' - '..profile.summary) end
    return true
end
local function cycle_playstyle(direction)
    local current=state and state.Playstyle and state.Playstyle.value
    local i=ordered_control_index(WAR_PLAYSTYLE_ORDER,current)
    local step=(direction=='previous' or direction=='prev' or direction=='back') and -1 or 1
    if i==0 then i=step>0 and 0 or 1 end
    i=((i-1+step)%#WAR_PLAYSTYLE_ORDER)+1
    return apply_playstyle(WAR_PLAYSTYLE_ORDER[i])
end

local function issue_target_weaponskill(ws_name,source,preserve_sc_context)
    source=source or 'WAR WS'
    if not control_action_ready(source) then return false end
    if (tonumber(player.tp) or 0)<1000 then
        add_to_chat(123,'['..source..'] Need 1000 TP for '..tostring(ws_name)..' (current '..tostring(player.tp or 0)..').')
        return false
    end
    local target=FalCore.util.current_target_mob()
    if not target or (target.hpp and tonumber(target.hpp)<=0) then
        add_to_chat(123,'['..source..'] No valid living <t> target.')
        return false
    end
    if not preserve_sc_context and type(sc_cancel)=='function' then sc_cancel('manual '..tostring(ws_name)) end
    send_command('@input /ws "'..tostring(ws_name)..'" <t>')
    return true
end

local function resolve_context_weaponskill()
    local eq=player and player.equipment or {}
    local range=FalCore.util.item_name(eq.range)
    if WAR_CONTEXT_WS_BY_RANGE[range] then
        return WAR_CONTEXT_WS_BY_RANGE[range],range,FalCore.util.item_name(eq.ammo)
    end
    local main=FalCore.util.item_name(eq.main)
    return WAR_CONTEXT_WS_BY_MAIN[main],main,FalCore.util.item_name(eq.sub)
end
function execute_context_weaponskill()
    local ws,main,sub=resolve_context_weaponskill()
    if not ws then
        add_to_chat(123,'[F12 WS] No primary WS mapping for '..tostring(main or '(empty)')..' / '..tostring(sub or '(empty)')..'.')
        return false
    end
    return issue_target_weaponskill(ws,'F12 WS',false)
end

-- Manual F11 skillchain closer.  It passively remembers completed WS / formed
-- chain properties on the current target and never auto-fires or changes weapons.
local sc_property_keys={'skillchain_a','skillchain_b','skillchain_c'}
local sc_ws_properties={}
local function get_ws_properties(ws_id,ws)
    local cached=sc_ws_properties[ws_id]
    if cached then return cached end
    cached={}
    ws=ws or (war_res and war_res.weapon_skills and war_res.weapon_skills[ws_id])
    if ws then
        for _,key in ipairs(sc_property_keys) do
            local prop=ws[key]
            if prop and prop~='' then cached[#cached+1]=prop end
        end
    end
    sc_ws_properties[ws_id]=cached
    return cached
end
local sc_messages={
    [288]='Light',[289]='Darkness',[290]='Gravitation',[291]='Fragmentation',[292]='Distortion',[293]='Fusion',[294]='Compression',[295]='Liquefaction',[296]='Induration',[297]='Reverberation',[298]='Transfixion',[299]='Scission',[300]='Detonation',[301]='Impaction',
    [385]='Light',[386]='Darkness',[387]='Gravitation',[388]='Fragmentation',[389]='Distortion',[390]='Fusion',[391]='Compression',[392]='Liquefaction',[393]='Induration',[394]='Reverberation',[395]='Transfixion',[396]='Scission',[397]='Detonation',[398]='Impaction',
    [767]='Radiance',[768]='Umbra',[769]='Radiance',[770]='Umbra',
}
local sc_combo={
    Light={Light='Light'},Darkness={Darkness='Darkness'},
    Gravitation={Distortion='Darkness',Fragmentation='Fragmentation'},
    Fragmentation={Fusion='Light',Distortion='Distortion'},
    Distortion={Gravitation='Darkness',Fusion='Fusion'},
    Fusion={Fragmentation='Light',Gravitation='Gravitation'},
    Compression={Transfixion='Transfixion',Detonation='Detonation'},
    Liquefaction={Impaction='Fusion',Scission='Scission'},
    Induration={Reverberation='Fragmentation',Compression='Compression',Impaction='Impaction'},
    Reverberation={Induration='Induration',Impaction='Impaction'},
    Transfixion={Scission='Distortion',Reverberation='Reverberation',Compression='Compression'},
    Scission={Liquefaction='Liquefaction',Reverberation='Reverberation',Detonation='Detonation'},
    Detonation={Compression='Gravitation',Scission='Scission'},
    Impaction={Liquefaction='Liquefaction',Detonation='Detonation'},
}
local sc_level={Radiance=4,Umbra=4,Light=3,Darkness=3,Gravitation=2,Fragmentation=2,Distortion=2,Fusion=2,Compression=1,Liquefaction=1,Induration=1,Reverberation=1,Transfixion=1,Scission=1,Detonation=1,Impaction=1}
local manual_sc={min_tp=1000,opens_after=2.8,window=7.5,pending=nil,pending_generation=0,ws_priority_by_main={
    ["Bunzi's Chopper"]={'Upheaval',"King's Justice","Ukko's Fury",'Raging Rush','Steel Cyclone'},
    ['Kaja Chopper']={'Steel Cyclone','Upheaval',"King's Justice",'Raging Rush'},
    ['Kaja Claymore']={'Ground Strike','Resolution','Spinning Slash'},
    ['Kaja Lance']={'Impulse Drive','Stardiver','Penta Thrust'},
    ['Kaja Knuckles']={'Asuran Fists','Raging Fists','Howling Fist'},
    ['Naegling']={'Savage Blade','Vorpal Blade','Requiescat'},
    ['Loxotic Mace']={'Judgment','Black Halo','Realmrazer','Hexa Strike'},
},ws_priority_by_range={
    ['Kaja Bow']={'Empyreal Arrow','Sidewinder','Arching Arrow'},
}}
local sc_react={props=nil,target_id=nil,observed_at=0,opens_at=0,expires=0,opener='',actor_id=nil,generation=0,choice=nil,choice_signature=nil}
local sc_ws_rank_by_main={}
local sc_ws_rank_by_range={}
for main_name,priority in pairs(manual_sc.ws_priority_by_main) do
    local ranks={}
    for i,name in ipairs(priority) do ranks[name]=#priority-i+1 end
    sc_ws_rank_by_main[main_name]=ranks
end
for range_name,priority in pairs(manual_sc.ws_priority_by_range) do
    local ranks={}
    for i,name in ipairs(priority) do ranks[name]=#priority-i+1 end
    sc_ws_rank_by_range[range_name]=ranks
end
function sc_cancel(reason)
    local had=sc_react.props~=nil
    manual_sc.pending=nil
    manual_sc.pending_generation=manual_sc.pending_generation+1
    sc_react.generation=sc_react.generation+1
    sc_react.props=nil; sc_react.target_id=nil; sc_react.observed_at=0; sc_react.opens_at=0; sc_react.expires=0
    sc_react.opener=''; sc_react.actor_id=nil; sc_react.choice=nil; sc_react.choice_signature=nil
    if had and not FalCore.runtime.unloading and type(update_hud)=='function' then update_hud(false) end
end
local function sc_note_resonance(prop,target_id,opener,actor_id)
    if not prop then return end
    local current=FalCore.util.current_target_mob()
    if current and target_id and current.id~=target_id then return end
    target_id=target_id or (current and current.id)
    if not target_id then return end
    local now=os.clock()
    sc_react.generation=sc_react.generation+1
    local generation=sc_react.generation
    sc_react.props=type(prop)=='table' and prop or {prop}
    sc_react.target_id=target_id
    sc_react.observed_at=now
    sc_react.opens_at=now+manual_sc.opens_after
    sc_react.expires=now+manual_sc.window
    sc_react.opener=opener or ''
    sc_react.actor_id=actor_id
    sc_react.choice=nil; sc_react.choice_signature=nil
    if type(update_hud)=='function' then update_hud(false) end
    coroutine.schedule(function()
        if FalCore.runtime.unloading then return end
        if sc_react.generation==generation and sc_react.props and type(update_hud)=='function' then update_hud(false) end
    end,manual_sc.opens_after+0.05)
    coroutine.schedule(function()
        if FalCore.runtime.unloading then return end
        if sc_react.generation==generation and sc_react.expires<=os.clock() then sc_cancel('window expired') end
    end,manual_sc.window+0.05)
end
local function sc_track_ws_open(act)
    if not act or not war_res or not war_res.weapon_skills then return end
    local ws=war_res.weapon_skills[act.param]
    if not ws then return end
    local props=get_ws_properties(act.param,ws)
    if #props==0 then return end
    local target_id
    for _,targ in pairs(act.targets or {}) do target_id=targ.id break end
    sc_note_resonance(props,target_id,ws.en,act.actor_id)
end
local function pick_chain_ws(active_props,available_ws_ids)
    if type(active_props)~='table' then return nil end
    if not available_ws_ids then
        local abils=windower and windower.ffxi and windower.ffxi.get_abilities and windower.ffxi.get_abilities() or nil
        available_ws_ids=abils and abils.weapon_skills or nil
    end
    if not available_ws_ids then return nil end
    local eq=player and player.equipment or {}
    local main=FalCore.util.item_name(eq.main)
    local range=FalCore.util.item_name(eq.range)
    local main_ranks=(range and sc_ws_rank_by_range[range]) or sc_ws_rank_by_main[main] or {}
    local best
    for _,ws_id in ipairs(available_ws_ids) do
        local ws=war_res.weapon_skills[ws_id]
        if ws and ws.en then
            for _,my_prop in ipairs(get_ws_properties(ws_id,ws)) do
                for _,active_prop in ipairs(active_props) do
                    local result=sc_combo[active_prop] and sc_combo[active_prop][my_prop]
                    if result then
                        local level=sc_level[result] or 1
                        local rank=level*1000000+(main_ranks[ws.en] or 0)*1000+(sets.precast.WS[ws.en] and 100 or 0)
                        if not best or rank>best.rank or (rank==best.rank and ws.en<best.name) then
                            best={name=ws.en,result=result,level=level,rank=rank,id=ws_id}
                        end
                    end
                end
            end
        end
    end
    return best
end
local function sc_refresh_choice()
    if not sc_react.props then return nil end
    local eq=player and player.equipment or {}
    local abils=windower and windower.ffxi and windower.ffxi.get_abilities and windower.ffxi.get_abilities() or nil
    local ids=abils and abils.weapon_skills or nil
    local sig=table.concat({tostring(sc_react.generation),tostring(FalCore.util.item_name(eq.main) or ''),tostring(FalCore.util.item_name(eq.sub) or ''),tostring(FalCore.util.item_name(eq.range) or ''),ids and table.concat(ids,',') or 'unavailable'},'|')
    if sc_react.choice_signature==sig then return sc_react.choice end
    sc_react.choice_signature=sig
    sc_react.choice=pick_chain_ws(sc_react.props,ids)
    return sc_react.choice
end
function sc_opportunity_snapshot(now)
    now=tonumber(now) or os.clock()
    local out={active=false,status='NONE',tp=tonumber(player and player.tp) or 0}
    if not sc_react.props or sc_react.expires<=now then return out end
    out.active=true; out.opener=sc_react.opener; out.properties_text=table.concat(sc_react.props,'/')
    out.wait_remaining=math.max(0,sc_react.opens_at-now)
    local choice=sc_refresh_choice()
    if choice then out.choice_name=choice.name; out.choice_result=choice.result; out.choice_level=choice.level end
    if manual_sc.pending then out.status='PENDING'; out.pending_name=manual_sc.pending.name; return out end
    local target=FalCore.util.current_target_mob()
    if not target or (target.hpp and tonumber(target.hpp)<=0) then out.status='NO_TARGET'; return out end
    if sc_react.target_id and target.id~=sc_react.target_id then out.status='TARGET_CHANGED'; return out end
    if not choice then out.status='NO_CLOSER'; return out end
    if not player or player.status~='Engaged' then out.status='NOT_ENGAGED'; return out end
    if now<sc_react.opens_at then out.status='WAIT'; return out end
    if out.tp<manual_sc.min_tp then out.status='NEED_TP'; return out end
    if FalCore.locks.frozen() then out.status='SWAPS_FROZEN'; return out end
    if midaction() then out.status='BUSY'; return out end
    out.status='READY'; return out
end
local function sc_confirm_pending(act)
    local pending=manual_sc.pending
    if not pending or not player or act.actor_id~=player.id then return nil end
    local ws=war_res.weapon_skills[act.param]
    if not ws or ws.en~=pending.name or (pending.id and pending.id~=act.param) then return nil end
    local target_id
    for _,targ in pairs(act.targets or {}) do target_id=targ.id break end
    if pending.target_id and target_id~=pending.target_id then return nil end
    manual_sc.pending=nil; manual_sc.pending_generation=manual_sc.pending_generation+1
    return pending.generation
end
handle_manual_sc_action=function(act)
    if not act or not act.targets then return end
    local confirmed
    if act.category==3 then confirmed=sc_confirm_pending(act) end
    local formed={}
    local packet_seen={}
    for _,targ in pairs(act.targets) do
        for _,a in pairs(targ.actions or {}) do
            local chain=a.has_add_effect and sc_messages[a.add_effect_message]
            if chain and targ.id then
                local seen=packet_seen[targ.id]
                if not seen then seen={}; packet_seen[targ.id]=seen end
                if not seen[chain] then
                    seen[chain]=true
                    formed[targ.id]=chain
                    sc_note_resonance(chain,targ.id,chain,act.actor_id)
                end
            end
        end
    end
    if act.category==3 then
        local target_id
        for _,targ in pairs(act.targets) do target_id=targ.id break end
        if not (target_id and formed[target_id]) then sc_track_ws_open(act) end
        if confirmed and sc_react.generation==confirmed then sc_cancel('confirmed closer produced no new resonance') end
    elseif act.category==1 and player and act.actor_id==player.id and sc_react.props and type(update_hud)=='function' then
        update_hud(false)
    end
end
function execute_manual_skillchain()
    if manual_sc.pending then
        add_to_chat(123,'[F11 SC] '..tostring(manual_sc.pending.name)..' already submitted; awaiting completion.')
        return false
    end
    if not control_action_ready('F11 SC') then return false end
    local target=FalCore.util.current_target_mob()
    if not target or (target.hpp and tonumber(target.hpp)<=0) then add_to_chat(123,'[F11 SC] No valid living <t>.'); return false end
    if player.status~='Engaged' then add_to_chat(123,'[F11 SC] Engage the target first.'); return false end
    local now=os.clock()
    if not sc_react.props then add_to_chat(123,'[F11 SC] No recent WS/skillchain is tracked on this target.'); return false end
    if now>sc_react.expires then sc_cancel('expired'); add_to_chat(123,'[F11 SC] Window expired.'); return false end
    if sc_react.target_id~=target.id then sc_cancel('target mismatch'); add_to_chat(123,'[F11 SC] Last opener belonged to another target.'); return false end
    local choice=sc_refresh_choice()
    if not choice then add_to_chat(123,'[F11 SC] No currently usable WS closes '..table.concat(sc_react.props,'/')..'.'); return false end
    if now<sc_react.opens_at then add_to_chat(123,string.format('[F11 SC] Too early; press again in about %.1fs.',sc_react.opens_at-now)); return false end
    if (tonumber(player.tp) or 0)<manual_sc.min_tp then add_to_chat(123,'[F11 SC] Need 1000 TP (current '..tostring(player.tp or 0)..').'); return false end
    add_to_chat(158,'[F11 SC] '..tostring(sc_react.opener)..' -> '..choice.result..' (Lv'..choice.level..') with '..choice.name..'.')
    manual_sc.pending_generation=manual_sc.pending_generation+1
    local token=manual_sc.pending_generation
    manual_sc.pending={token=token,id=choice.id,name=choice.name,result=choice.result,target_id=target.id,generation=sc_react.generation}
    berserk_sequence.suppress_next=true   -- v3.3.9 (A8): this one WS bypasses auto-Berserk
    local issued=issue_target_weaponskill(choice.name,'F11 SC',true)
    if not issued then berserk_sequence.suppress_next=false; manual_sc.pending=nil; return false end
    -- issue_target_weaponskill uses send_command('@input ...'), which is asynchronous and
    -- can be refused by the client (range, target death).  If pretarget never fires and
    -- consumes the flag, expire it so it cannot suppress an unrelated later weapon skill.
    coroutine.schedule(function()
        if FalCore.runtime.unloading then return end
        berserk_sequence.suppress_next=false
    end,2.0)
    if type(update_hud)=='function' then update_hud(false) end
    coroutine.schedule(function()
        if FalCore.runtime.unloading then return end
        if manual_sc.pending and manual_sc.pending.token==token then manual_sc.pending=nil; manual_sc.pending_generation=manual_sc.pending_generation+1; if type(update_hud)=='function' then update_hud(false) end end
    end,3.0)
    return true
end

-------------------------------------------------------------------------------------------------------------------
-- Mote hooks and gear resolution
-------------------------------------------------------------------------------------------------------------------

-- Accuracy offense can request an accuracy WS child, while an explicit manual
-- WS mode always wins.  Mote calls this function during its own set resolution.
function get_custom_wsmode(spell)
    local mode=state and state.WeaponskillMode
        and (state.WeaponskillMode.current or state.WeaponskillMode.value) or 'Normal'
    if mode=='Normal' and state and state.OffenseMode and state.OffenseMode.value=='Acc' then
        return 'Acc'
    end
    return mode
end

local fencer_melee_active
local war_fencer_ws_excluded

local function resolved_ws_precast_set(spell)
    if not (spell and sets and sets.precast and sets.precast.WS) then return nil end
    local mode=get_custom_wsmode(spell)
    local resolved=sets.precast.WS[spell.english] or sets.precast.WS
    if mode and resolved[mode] then resolved=resolved[mode] end
    return resolved
end

-- Effective-TP model for Moonshade overflow. Fencer ranks are calculated from
-- the actual resolved WS set plus the final WAR Fencer overlay; Job Point Gifts
-- remain a separate +230 under the fixed Job Master/2100-JP policy. Crystal
-- Blessing and weapon-profile TP Bonus are also included. Moonshade itself is
-- deliberately excluded from the threshold check.
local function ws_fencer_eligible(spell)
    if not spell or not fencer_melee_active or not fencer_melee_active() then return false end
    if war_magical_ws and war_magical_ws[spell.english] then return false end
    if war_fencer_ws_excluded and war_fencer_ws_excluded[spell.english] then return false end
    return true
end

local function fencer_rank_for_ws_set(ws_set,spell)
    if not ws_fencer_eligible(spell) then return 0 end
    local rank=5
    local slots={'head','neck','ear1','ear2','body','hands','ring1','ring2','back','waist','legs','feet'}
    for _,slot in ipairs(slots) do
        local piece=ws_set and FalCore.util.item_name(ws_set[slot]) or nil
        if slot=='neck' and sets.precast.WS.FencerOverlay and sets.precast.WS.FencerOverlay.neck then
            piece=FalCore.util.item_name(sets.precast.WS.FencerOverlay.neck)
        end
        rank=rank+(WAR_FENCER_GEAR_RANK[piece] or 0)
    end
    -- The sub slot is owned by the weapon profile, not the WS set, so read it live.
    rank=rank+(WAR_FENCER_GEAR_RANK[live_weapon_slot('sub')] or 0)
    return math.min(8,rank)
end

-- v3.3.9 (A5): `tp_bonus` is a deliberate per-profile OVERRIDE hook, and it is
-- currently unset on every entry in WAR_WEAPON_META because none of the weapons in
-- these profiles (Bunzi's Chopper, Kaja Chopper/Claymore/Lance/Knuckles/Bow, Naegling,
-- Loxotic Mace) carries "TP Bonus".  So a return of 0 is CORRECT, not a missing value --
-- but it used to read like a live term, and a typo here would have been silent.
-- If a TP-Bonus weapon ever enters a profile, add `tp_bonus=<n>` to that entry.
-- Gear-borne TP Bonus (Moonshade Earring, Mpaca's Cap) is handled separately: Moonshade
-- in effective_ws_tp below, and armour is not counted here by design.
local function weapon_profile_tp_bonus()
    local key=state and state.WeaponSet and state.WeaponSet.value
    local meta=key and WAR_WEAPON_META[key]
    local bonus=meta and rawget(meta,'tp_bonus')
    return tonumber(bonus) or 0
end

local function effective_ws_tp(spell,include_moonshade)
    local ws_set=resolved_ws_precast_set(spell) or {}
    local raw=player and tonumber(player.tp) or 0
    local crystal=(buffactive and buffactive['Crystal Blessing']) and 250 or 0
    local rank=fencer_rank_for_ws_set(ws_set,spell)
    local fencer_trait=rank>0 and (WAR_FENCER_TP_BY_RANK[rank] or 0) or 0
    local fencer_gifts=rank>0 and war_fencer_gift_tp() or 0
    local fencer=fencer_trait+fencer_gifts
    local weapon_bonus=weapon_profile_tp_bonus()
    local moonshade=0
    if include_moonshade then
        local e1,e2=FalCore.util.item_name(ws_set.ear1),FalCore.util.item_name(ws_set.ear2)
        if e1=='Moonshade Earring' or e2=='Moonshade Earring' then moonshade=250 end
    end
    local total=math.min(3000,raw+crystal+fencer+weapon_bonus+moonshade)
    return total,{raw=raw,crystal=crystal,fencer_rank=rank,fencer_trait=fencer_trait,fencer_gifts=fencer_gifts,fencer=fencer,weapon=weapon_bonus,moonshade=moonshade}
end

local function apply_max_tp_moonshade(spell)
    local ws_set=resolved_ws_precast_set(spell)
    if not ws_set then return end
    local ear1=FalCore.util.item_name(ws_set.ear1)
    local ear2=FalCore.util.item_name(ws_set.ear2)
    local moonshade_slot=ear1=='Moonshade Earring' and 'ear1'
        or (ear2=='Moonshade Earring' and 'ear2')
    if not moonshade_slot then return end

    local effective_without=effective_ws_tp(spell,false)
    if effective_without<3000 then return end

    local replacements
    if war_magical_ws and war_magical_ws[spell.english] then
        replacements=(sets.MagicalMaxTP and sets.MagicalMaxTP[spell.english]) or sets.MagicalMaxTP
    else
        replacements=(sets.MaxTP and sets.MaxTP[spell.english]) or sets.MaxTP
    end
    if type(replacements)~='table' then return end
    local replacement=replacements[moonshade_slot] or replacements.ear2 or replacements.ear1
    if not replacement then return end
    local overlay={}; overlay[moonshade_slot]=replacement; equip(overlay)
end

function job_pretarget(spell,action,spellMap,eventArgs)
    if spell and spell.type=='WeaponSkill' then
        local out,maxd=ws_out_of_range(spell)
        if out then
            local actual=tonumber(spell.target and spell.target.distance) or -1
            cancel_spell()
            eventArgs.cancel=true
            eventArgs.handled=true
            add_to_chat(123,string.format('[WAR Range] %s canceled: %.1f yalms > safe %.1f.',
                spell.english,actual,maxd or 0))
            return
        end
        if queue_berserk_before_ws(spell,eventArgs) then return end
    end
end

function job_precast(spell,action,spellMap,eventArgs)
    FalCore.locks.check_rings()
end

function job_post_precast(spell,action,spellMap,eventArgs)
    if spell and spell.type=='WeaponSkill' then
        if fencer_melee_active and fencer_melee_active()
            and not (war_magical_ws and war_magical_ws[spell.english])
            and not (war_fencer_ws_excluded and war_fencer_ws_excluded[spell.english])
            and sets.precast.WS.FencerOverlay then
            equip(sets.precast.WS.FencerOverlay)
        end
        if state and state.Buff and state.Buff['Mighty Strikes']
            and not (war_magical_ws and war_magical_ws[spell.english])
            and not (war_fencer_ws_excluded and war_fencer_ws_excluded[spell.english])
            and sets.buff.MightyStrikesWS then
            equip(sets.buff.MightyStrikesWS)
        end
        apply_max_tp_moonshade(spell)
        if war_magical_ws and war_magical_ws[spell.english]
            and spell_target_within(spell,15) then
            equip({waist="Orpheus's Sash"})
        end
    end
    if th_action_overlay(spell) and sets.TreasureHunter then equip(sets.TreasureHunter) end
end

function job_aftercast(spell,action,spellMap,eventArgs)
    retry_berserk_ws(spell)
    check_weaponset(false)
    if FalCore.move.refresh_pending and not FalCore.locks.pause_active() then
        FalCore.move.refresh_pending=false
        FalCore.move.check()
    end
    if not FalCore.locks.pause_active() and not midaction()
        and type(handle_equipping_gear)=='function' and player then
        handle_equipping_gear(player.status)
        if FalCore.locks.fishing_active() then FalCore.locks.apply_fishing_policy() end
    end
    update_hud(false)
end

local function dual_wield_melee_active()
    local key=state and state.WeaponSet and state.WeaponSet.value
    local meta=key and WAR_WEAPON_META[key]
    return meta and meta.requires_dw==true and war_dual_wield_available()
end

fencer_melee_active=function()
    local eq=player and player.equipment or {}
    local main=FalCore.util.item_name(eq.main)
    local sub=FalCore.util.item_name(eq.sub)
    return (main=='Naegling' or main=='Loxotic Mace') and sub=='Blurred Shield +1'
end
war_fencer_ws_excluded={
    ['Shield Break']=true,['Armor Break']=true,['Weapon Break']=true,['Full Break']=true,
    Shockwave=true,['Leg Sweep']=true,['Shell Crusher']=true,Skullbreaker=true,
    ['Flat Blade']=true,Brainshaker=true,Shadowstitch=true,['Nightmare Scythe']=true,
    ['Spirits Within']=true,
}

local melee_overlay={}
local function clear_melee_overlay()
    for k in pairs(melee_overlay) do melee_overlay[k]=nil end
end
local function merge_melee_overlay(source)
    for k,v in pairs(source or {}) do melee_overlay[k]=v end
end

local function selected_kiting_overlay(th_enabled)
    local slot=FalCore.move.ring_slot()
    if not slot then return nil end
    if th_enabled and slot=='ring2' and not FalCore.locks.ring_protected('ring1') then
        return sets.TreasureHunterKiting
    end
    return slot=='ring1' and sets.KitingRing1 or sets.KitingRing2
end

-- v3.3.9 (A1/A4): single overlay stack shared by customize_melee_set and
-- customize_defense_set.  merge_melee_overlay is last-writer-wins, so ORDER IS
-- SIGNIFICANT: the Kaja Bow overlay is merged LAST because it owns range+ammo for
-- the whole profile and was previously being overwritten by the DT overlay
-- (Staunch Tathlum +1), Mighty Strikes (Yetshila +1) and Treasure Hunter
-- (Per. Lucky Egg).  Losing Chapuli Arrow made weapon_profile_matches('KajaBow')
-- permanently false, which drove an endless prepare/full/verify weapon reapply.
local function apply_war_overlays(baseSet,opts)
    opts=opts or {}
    clear_melee_overlay()
    if opts.dt_overlay and state.HybridMode.value=='DT' then
        merge_melee_overlay(opts.fencer and sets.engaged.FencerDTOverlay or sets.engaged.DTOverlay)
    end
    if dual_wield_melee_active() and sets.engaged.DWOverlay then
        merge_melee_overlay(sets.engaged.DWOverlay)
    end
    if opts.mighty_strikes and state and state.Buff and state.Buff['Mighty Strikes'] and sets.buff.MightyStrikesTP then
        merge_melee_overlay(sets.buff.MightyStrikesTP)
    end
    local th_enabled=FalCore.th.should_apply(nil)
    if th_enabled then merge_melee_overlay(sets.TreasureHunter) end
    if FalCore.move.requested() then merge_melee_overlay(selected_kiting_overlay(th_enabled)) end
    -- LAST: the profile's own weapon/ammo allocation outranks every overlay above.
    if state and state.WeaponSet and state.WeaponSet.value=='KajaBow' and sets.weapons.KajaBowOverlay then
        merge_melee_overlay(sets.weapons.KajaBowOverlay)
    end
    FalCore.locks.check_rings()
    if next(melee_overlay) then return set_combine(baseSet,melee_overlay) end
    return baseSet
end

function customize_melee_set(meleeSet)
    local key=state and state.WeaponSet and state.WeaponSet.value or nil
    local meta=key and WAR_WEAPON_META[key] or nil
    local mode=state.OffenseMode and state.OffenseMode.value or 'Normal'
    local fencer=fencer_melee_active()
    if fencer and sets.engaged.Fencer then
        meleeSet=(mode~='Normal' and sets.engaged.Fencer[mode]) or sets.engaged.Fencer
    elseif mode=='Normal' and meta and meta.tp_style then
        -- Normal is the weapon-aware AUTO route.  Explicit Acc/STP/PDL modes
        -- are never replaced here. Bunzi favors PDL/white-damage; Kaja 2H,
        -- H2H and DW profiles favor WS-frequency STP.
        if meta.tp_style=='STP' and sets.engaged.STP then
            meleeSet=sets.engaged.STP
        elseif meta.tp_style=='PDL' and sets.engaged.PDL then
            meleeSet=sets.engaged.PDL
        end
    end

    return apply_war_overlays(meleeSet,{fencer=fencer,dt_overlay=true,mighty_strikes=true})
end

function customize_defense_set(defenseSet)
    -- v3.3.9 (A4): Mote routes through sets.defense.* and SKIPS customize_melee_set
    -- entirely whenever DefenseMode ~= 'None' -- which the DT and MEVA playstyles set.
    -- Without this hook the kiting ring, the Dual Wield overlay (14 gear DW), Treasure
    -- Hunter and the Kaja Bow arrow were all silently dropped in every defensive mode.
    -- The DT overlay is intentionally NOT applied here: the defense set is already the
    -- defensive allocation. MightyStrikesTP is a TP-phase offensive overlay and is also
    -- skipped, but Dual Wield is kept because losing it mid-fight is a real delay loss.
    return apply_war_overlays(defenseSet,{fencer=fencer_melee_active(),dt_overlay=false,mighty_strikes=false})
end

function customize_idle_set(idleSet)
    if FalCore.move.requested() then
        local movement_set=selected_kiting_overlay(false)
        if movement_set then idleSet=set_combine(idleSet,movement_set) end
    end
    FalCore.locks.check_rings()
    return idleSet
end

function job_buff_change(buff,gain)
    local b=buff:lower()
    if state.Buff[buff]~=nil then state.Buff[buff]=gain end
    if b=='berserk' then state.Buff.Berserk=gain
    elseif b=='warcry' then state.Buff.Warcry=gain
    elseif b=='aggressor' then state.Buff.Aggressor=gain
    elseif b=='defender' then state.Buff.Defender=gain
    elseif b=='retaliation' then state.Buff.Retaliation=gain
    elseif b=='restraint' then state.Buff.Restraint=gain
    elseif b=='blood rage' then state.Buff['Blood Rage']=gain
    elseif b=="warrior's charge" then state.Buff["Warrior's Charge"]=gain
    elseif b=='mighty strikes' then state.Buff['Mighty Strikes']=gain
    elseif b=='brazen rush' then state.Buff['Brazen Rush']=gain
    elseif b=='doom' then
        state.Buff.Doom=gain
        set_doom_policy(gain)
    elseif b=='silence' then
        silence_echo.generation=silence_echo.generation+1
        if gain then
            silence_echo.active=true
            silence_echo.attempts=0
            try_echo_drops(silence_echo.generation)
        else
            silence_echo.active=false
            silence_echo.attempts=0
        end
    end

    if gain and BOOST_BUFFS[b] then
        local slots={}
        if BOOST_GEAR[FalCore.util.ring_name('ring1')] then slots[#slots+1]='ring1' end
        if BOOST_GEAR[FalCore.util.ring_name('ring2')] then slots[#slots+1]='ring2' end
        FalCore.locks.release_rings(slots,buff..' active')
    end
    if not FalCore.locks.frozen() and not midaction()
        and type(handle_equipping_gear)=='function' and player then
        handle_equipping_gear(player.status)
    end
    update_hud(false)
end

local function resume_swaps(message)
    if FalCore.locks.pause_active() then disable(unpack(FalCore.ALL_EQUIP_SLOTS)); return end
    if FalCore.locks.fishing_active() then FalCore.locks.apply_fishing_policy(); return end
    enable(unpack(FalCore.ALL_EQUIP_SLOTS))
    FalCore.locks.invalidate_ring_cache()
    FalCore.move.refresh_pending=false
    FalCore.move.check()
    reapply_runtime_locks()
    if not buffactive.doom and type(handle_equipping_gear)=='function' and player then handle_equipping_gear(player.status) end
    local deferred={}
    if FalCore.locks.releasing.ring1 then deferred[#deferred+1]='ring1' end
    if FalCore.locks.releasing.ring2 then deferred[#deferred+1]='ring2' end
    if #deferred>0 then
        -- Settling is folded into FalCore.locks.release_rings, but a deferred clear is
        -- still needed when the release happened while Doom owned the rings.
        local token=FalCore.runtime.token
        coroutine.schedule(function()
            if FalCore.runtime.unloading or token~=FalCore.runtime.token then return end
            for _,slot in ipairs(deferred) do FalCore.locks.releasing[slot]=false end
            FalCore.locks.invalidate_ring_cache()
            FalCore.locks.check_rings()
        end,1)
    end
    if message then add_to_chat(158,message) end
end

function job_state_change(descriptor,new_value,old_value)
    if not applying_weapon_profile and (descriptor=='Weapon Set' or descriptor=='WeaponSet') then
        if not weapon_profile_available(new_value) then
            local fallback=weapon_profile_available(old_value) and old_value or current_weapon_order()[1]
            applying_weapon_profile=true
            state.WeaponSet:set(fallback)
            applying_weapon_profile=false
            add_to_chat(123,'[WAR Weapon] Dual Wield profile skipped: current support job does not grant Dual Wield.')
            check_weaponset(true)
            update_hud(true)
            return
        end
        apply_weapon_profile(new_value,true)
        return
    end
    if not applying_playstyle and (descriptor=='Playstyle') and new_value~='Custom' then
        apply_playstyle(new_value,true)
        return
    end
    local style=state and state.Playstyle and state.Playstyle.value
    if not applying_playstyle and style and style~='Custom' and not playstyle_profile_matches(style) then
        applying_playstyle=true
        state.Playstyle:set('Custom')
        applying_playstyle=false
    end

    if descriptor=='PauseSwaps' or descriptor=='Pause Gear Swapping' then
        if state.PauseSwaps.value then
            disable(unpack(FalCore.ALL_EQUIP_SLOTS))
            add_to_chat(167,'[WAR] GearSwap PAUSED: all automatic equipment swaps frozen.')
        elseif state.FishingMode.value then
            FalCore.locks.apply_fishing_policy()
            add_to_chat(158,'[WAR] Pause off; Fishing still holds non-ring gear.')
        else
            resume_swaps('[WAR] GearSwap RESUMED: automatic equipment swaps restored.')
        end
        update_hud(false); return
    elseif descriptor=='FishingMode' or descriptor=='Fishing Mode' then
        if state.FishingMode.value then
            enable(unpack(FalCore.ALL_EQUIP_SLOTS))
            equip(sets.Fishing)
            if FalCore.locks.pause_active() then
                disable(unpack(FalCore.ALL_EQUIP_SLOTS))
                add_to_chat(167,'[WAR] FISHING MODE: rod equipped; Pause still owns all slots.')
            else
                FalCore.locks.apply_fishing_policy()
                if FalCore.move.moving and not midaction() and type(handle_equipping_gear)=='function' then
                    handle_equipping_gear(player.status)
                    FalCore.locks.apply_fishing_policy()
                end
                add_to_chat(167,'[WAR] FISHING MODE: rod/apparel held; movement and protected rings remain live.')
            end
        elseif state.PauseSwaps.value then
            FalCore.locks.clear_fishing_rod()
            disable(unpack(FalCore.ALL_EQUIP_SLOTS))
            add_to_chat(158,'[WAR] Fishing off; rod cleared; Pause still active.')
        else
            FalCore.locks.clear_fishing_rod()
            resume_swaps('[WAR] Fishing Mode OFF: normal gear policy restored.')
        end
        update_hud(false); return
    elseif descriptor=='Treasure Hunter' or descriptor=='TreasureHunter' then
        add_to_chat(158,'[WAR TH] '..FalCore.util.bool_word(state.TreasureHunter.value))
    elseif descriptor=='Weapon Lock' or descriptor=='WeaponLock' then
        check_weaponset(true)
    elseif descriptor=='Berserk Auto' or descriptor=='BerserkAuto' then
        if not state.BerserkAuto.value then clear_berserk_sequence() end
        add_to_chat(158,'[WAR Berserk] Auto-before-WS: '..(state.BerserkAuto.value and 'ON' or 'OFF'))
    elseif descriptor=='Auto_Kite' or descriptor=='DefenseMode' or descriptor=='Defense Mode'
        or descriptor=='Physical Defense Mode' or descriptor=='Magical Defense Mode' then
        FalCore.move.check()
    end

    if FalCore.locks.pause_active() then disable(unpack(FalCore.ALL_EQUIP_SLOTS)); update_hud(false); return end
    if FalCore.locks.fishing_active() then FalCore.locks.apply_fishing_policy(); update_hud(false); return end
    if not midaction() and type(handle_equipping_gear)=='function' and player then handle_equipping_gear(player.status) end
    update_hud(false)
end

function job_status_change(newStatus,oldStatus,eventArgs)
    if oldStatus=='Engaged' and newStatus~='Engaged' and type(sc_cancel)=='function' then sc_cancel('disengaged') end
    FalCore.move.check()
    FalCore.locks.check_rings()
    check_weaponset(false)
    update_hud(false)
end

function job_sub_job_change(newSubjob,oldSubjob)
    local key=state and state.WeaponSet and state.WeaponSet.value
    local meta=key and WAR_WEAPON_META[key]
    if meta and meta.requires_dw and not war_dual_wield_available() then
        local fallback=meta.fallback or 'BunziChopper'
        applying_weapon_profile=true
        state.WeaponSet:set(fallback)
        applying_weapon_profile=false
        add_to_chat(158,'[WAR Weapon] Dual Wield is no longer available; falling back to '..weapon_label(fallback)..'.')
        check_weaponset(true)
    else
        check_weaponset(true)
    end
    if not FalCore.locks.frozen() and type(handle_equipping_gear)=='function' and player then
        handle_equipping_gear(player.status)
    end
    update_hud(true)
end

function job_handle_equipping_gear(playerStatus,eventArgs)
    FalCore.move.check()
    FalCore.locks.check_rings()
end

function job_update(cmdParams,eventArgs)
    FalCore.move.check()
    FalCore.locks.check_rings()
    check_weaponset(false)
    update_hud(false)
end

-------------------------------------------------------------------------------------------------------------------
-- Live Double / Triple Attack snapshot
-------------------------------------------------------------------------------------------------------------------

-- This follows the RDM equipment-snapshot discipline: compare the live slot
-- names in place and only rescan ItemStats when a real equipment name changes.
-- The HUD consumes the already-derived snapshot; it never walks bags/inventory.
local WAR_MULTIATTACK_SLOTS={
    'main','sub','range','ammo','head','neck','ear1','ear2',
    'body','hands','ring1','ring2','back','waist','legs','feet',
}
local war_multiattack_snapshot={
    initialized=false,names={},gear_da=0,gear_ta=0,
    merit_da=0,merit_source='assumed',gift_da=0,native_da=0,
    raw_da=0,raw_ta=0,total_da=0,total_ta=0,
}

local function live_equipment_name_for_multiattack(slot)
    local eq=player and player.equipment or nil
    if not eq then return '' end
    if slot=='ear1' then return eq.ear1 or eq.left_ear or '' end
    if slot=='ear2' then return eq.ear2 or eq.right_ear or '' end
    if slot=='ring1' then return eq.ring1 or eq.left_ring or '' end
    if slot=='ring2' then return eq.ring2 or eq.right_ring or '' end
    return eq[slot] or ''
end

local function get_war_multiattack_snapshot(force)
    local snap=war_multiattack_snapshot
    local changed=force==true or not snap.initialized
    if not changed then
        for i,slot in ipairs(WAR_MULTIATTACK_SLOTS) do
            if snap.names[i]~=live_equipment_name_for_multiattack(slot) then
                changed=true
                break
            end
        end
    end

    if changed then
        local gear_da,gear_ta=0,0
        for i,slot in ipairs(WAR_MULTIATTACK_SLOTS) do
            local name=live_equipment_name_for_multiattack(slot)
            snap.names[i]=name
            local stats=item_stats and item_stats[name] or nil
            if stats then
                gear_da=gear_da+(tonumber(stats.da) or 0)
                gear_ta=gear_ta+(tonumber(stats.ta) or 0)
            end
        end
        snap.gear_da=gear_da
        snap.gear_ta=gear_ta
        snap.initialized=true
    end

    local merit_da,merit_source=war_double_attack_merit_rate(false)
    local gift_da=war_double_attack_gift_rate()
    snap.merit_da=merit_da
    snap.merit_source=merit_source
    snap.gift_da=gift_da
    snap.native_da=WAR_DOUBLE_ATTACK_TRAIT+merit_da+gift_da
    snap.raw_da=snap.gear_da+snap.native_da
    snap.raw_ta=snap.gear_ta
    snap.total_da=math.min(WAR_MULTIATTACK_RATE_CAP,snap.raw_da)
    snap.total_ta=math.min(WAR_MULTIATTACK_RATE_CAP,snap.raw_ta)
    return snap
end

local function report_multiattack(force_merits)
    if force_merits then war_double_attack_merit_rate(true) end
    local ma=get_war_multiattack_snapshot(true)
    add_to_chat(158,string.format(
        '[WAR Multi] DA %d/%d = gear %d + trait %d + merits %d (%s) + Gifts %d | TA %d/%d = gear %d',
        ma.raw_da,WAR_MULTIATTACK_RATE_CAP,ma.gear_da,WAR_DOUBLE_ATTACK_TRAIT,
        ma.merit_da,ma.merit_source,ma.gift_da,ma.raw_ta,WAR_MULTIATTACK_RATE_CAP,ma.gear_ta))
    if state and state.Buff and state.Buff['Brazen Rush'] then
        add_to_chat(158,'[WAR Multi] Brazen Rush active: numeric DA above is the permanent/live-gear baseline; the ability applies a temporary decaying DA-rate override that is not modeled as a fixed percentage.')
    end
    add_to_chat(158,'[WAR Multi] Raw rate ceilings are 100%. Higher-tier multi-attacks are checked before Double Attack, so raw DA is not the same as realized DA rounds when TA/QA can proc.')
end

-------------------------------------------------------------------------------------------------------------------
-- Persistent WAR command-center HUD (RDM v2.61 presentation model)
-------------------------------------------------------------------------------------------------------------------

war_hud=nil
local war_hud_visible=true
local war_hud_cache={key=nil}
local WAR_HUD_FILE='data/Falurian_WAR_HUD.xml'
local WAR_HUD_CACHE_KEY='__falurian_war_hud_preferences_v1'
local WAR_HUD_SECTIONS={'loadout','combat','utility','buffs','shortcuts'}
local WAR_HUD_DEFAULT={schema=1,x=675,y=950,layout='expanded',scale=1.0,opacity=205,visible=true,sections={loadout=true,combat=true,utility=true,buffs=true,shortcuts=true}}
local war_hud_config_lib=nil
local war_hud_preferences=nil
local war_hud_drag_generation=0
local war_hud_drag_pending=false
local war_hud_settings={pos={x=675,y=950},text={size=11,font='Consolas',alpha=255,stroke={width=2,alpha=255,red=0,green=0,blue=0}},bg={alpha=205,red=8,green=10,blue=14},flags={draggable=false}}
local war_hud_config={layout='expanded',scale=1.0,opacity=205,sections={loadout=true,combat=true,utility=true,buffs=true,shortcuts=true}}
local war_hud_colors={label='\\cs(205,210,220)',value='\\cs(248,248,250)',section='\\cs(120,205,255)',cyan='\\cs(105,210,235)',green='\\cs(115,225,145)',yellow='\\cs(245,210,100)',orange='\\cs(245,165,90)',red='\\cs(255,105,115)',dim='\\cs(135,140,150)'}

local function hud_num(v,fallback,lo,hi)
    local n=tonumber(v); if not n or n~=n then n=fallback end
    if lo and n<lo then n=lo end; if hi and n>hi then n=hi end; return n
end
local function load_war_hud_preferences()
    local ok,cfg=pcall(require,'config'); if not ok or not cfg then return false end
    local loaded=type(windower)=='table' and rawget(windower,WAR_HUD_CACHE_KEY) or nil
    if type(loaded)=='table' then pcall(cfg.reload,loaded) else
        local ok2,result=pcall(cfg.load,WAR_HUD_FILE,WAR_HUD_DEFAULT); if not ok2 or type(result)~='table' then return false end
        loaded=result; if type(windower)=='table' then rawset(windower,WAR_HUD_CACHE_KEY,loaded) end
    end
    war_hud_config_lib=cfg; war_hud_preferences=loaded
    local layout=tostring(loaded.layout or ''):lower(); war_hud_config.layout=(layout=='compact' or layout=='expanded') and layout or 'expanded'
    war_hud_config.scale=hud_num(loaded.scale,1.0,0.70,1.60); war_hud_config.opacity=math.floor(hud_num(loaded.opacity,205,0,255)+0.5)
    if type(loaded.visible)=='boolean' then war_hud_visible=loaded.visible else war_hud_visible=true end
    local sec=type(loaded.sections)=='table' and loaded.sections or {}
    for _,name in ipairs(WAR_HUD_SECTIONS) do war_hud_config.sections[name]=type(sec[name])=='boolean' and sec[name] or true end
    war_hud_settings.pos.x=math.floor(hud_num(loaded.x,675,-20000,20000)+0.5); war_hud_settings.pos.y=math.floor(hud_num(loaded.y,950,-20000,20000)+0.5)
    war_hud_settings.flags.draggable=false
    return true
end
local function current_war_hud_position()
    local x,y=war_hud_settings.pos.x,war_hud_settings.pos.y
    if war_hud and type(war_hud.pos)=='function' then local ok,a,b=pcall(war_hud.pos,war_hud); if ok and tonumber(a) and tonumber(b) then x,y=tonumber(a),tonumber(b) end end
    war_hud_settings.pos.x,war_hud_settings.pos.y=math.floor(x+0.5),math.floor(y+0.5); return war_hud_settings.pos.x,war_hud_settings.pos.y
end
save_war_hud_preferences=function(silent)
    if not war_hud_config_lib or not war_hud_preferences then return false end
    local x,y=current_war_hud_position(); local p=war_hud_preferences
    p.schema=1;p.x=x;p.y=y;p.layout=war_hud_config.layout;p.scale=war_hud_config.scale;p.opacity=war_hud_config.opacity;p.visible=war_hud_visible
    if type(p.sections)~='table' then p.sections={} end
    for _,name in ipairs(WAR_HUD_SECTIONS) do p.sections[name]=war_hud_config.sections[name]~=false end
    return pcall(war_hud_config_lib.save,p)
end
local function queue_war_hud_save()
    war_hud_drag_generation=war_hud_drag_generation+1; if war_hud_drag_pending then return end
    war_hud_drag_pending=true
    local function settle()
        local gen=war_hud_drag_generation
        coroutine.schedule(function()
            if FalCore.runtime.unloading then war_hud_drag_pending=false; return end
            if gen~=war_hud_drag_generation then settle(); return end
            war_hud_drag_pending=false; save_war_hud_preferences(true)
        end,0.60)
    end
    settle()
end
local function war_hud_call(method,...)
    if not war_hud or type(war_hud[method])~='function' then return false end
    return pcall(war_hud[method],war_hud,...)
end
local function apply_war_hud_style()
    war_hud_call('size',math.max(8,math.floor(11*war_hud_config.scale+0.5)))
    war_hud_call('bg_alpha',war_hud_config.opacity); war_hud_call('bg_color',8,10,14); war_hud_cache.key=nil
end
local function hcol(name,value) return (war_hud_colors[name] or '')..tostring(value or '')..'\\cr' end
local function hfield(label,value,color) return hcol('label',label..': ')..hcol(color or 'value',value) end
local function hrow(label,content) return hcol('section',string.format('%-11s',label))..content end
local function section_on(name) return war_hud_config.sections[name]~=false end

function init_hud()
    load_war_hud_preferences()
    local ok,texts=pcall(require,'texts'); if not ok or not texts then add_to_chat(123,'[WAR HUD] texts library unavailable.'); return end
    war_hud=texts.new('',war_hud_settings)
    if type(war_hud.register_event)=='function' then pcall(war_hud.register_event,war_hud,'drag',function(x,y) if tonumber(x) and tonumber(y) then war_hud_settings.pos.x=tonumber(x); war_hud_settings.pos.y=tonumber(y) end; queue_war_hud_save() end) end
    apply_war_hud_style(); update_hud(true); if war_hud_visible then war_hud:show() end
end
local function toggle_hud()
    if not war_hud then return end
    war_hud_visible=not war_hud_visible; save_war_hud_preferences(true)
    if war_hud_visible then update_hud(true); war_hud:show() else war_hud:hide() end
end
local function toggle_hud_lock()
    if not war_hud then return end
    local was=war_hud:draggable(); war_hud:draggable(not was); save_war_hud_preferences(true)
    add_to_chat(158,was and '[WAR HUD] Locked; position saved.' or '[WAR HUD] Unlocked; drag to reposition.')
end
local function set_hud_layout(value)
    value=tostring(value or ''):lower(); if value~='compact' and value~='expanded' then add_to_chat(158,'[WAR HUD] layout compact|expanded'); return end
    war_hud_config.layout=value; save_war_hud_preferences(true); update_hud(true)
end
local function set_hud_scale(value)
    war_hud_config.scale=hud_num(value,war_hud_config.scale,0.70,1.60); apply_war_hud_style(); save_war_hud_preferences(true); update_hud(true)
end
local function set_hud_opacity(value)
    war_hud_config.opacity=math.floor(hud_num(value,war_hud_config.opacity,0,255)+0.5); apply_war_hud_style(); save_war_hud_preferences(true); update_hud(true)
end
local function set_hud_section(name,value)
    name=tostring(name or ''):lower(); if war_hud_config.sections[name]==nil then add_to_chat(158,'[WAR HUD] sections: '..table.concat(WAR_HUD_SECTIONS,', ')); return end
    value=tostring(value or 'toggle'):lower(); if value=='toggle' then war_hud_config.sections[name]=not war_hud_config.sections[name] else war_hud_config.sections[name]=(value=='on' or value=='true' or value=='1') end
    save_war_hud_preferences(true); update_hud(true)
end

function update_hud(force)
    if not war_hud or (not war_hud_visible and not force) then return end
    local sc=type(sc_opportunity_snapshot)=='function' and sc_opportunity_snapshot(os.clock()) or {active=false,status='NONE'}
    local weapon=state and state.WeaponSet and state.WeaponSet.value or '?'
    local weapon_meta=WAR_WEAPON_META[weapon] or {}
    local damage_type=weapon_meta.damage or '?'
    local weapon_ok=weapon_profile_matches(weapon)
    local live_weapon=live_weapon_description()
    local native_dw,dw_tier=war_native_dual_wield()
    local dw_text=native_dw>0 and (dw_tier..' '..native_dw..' + gear '..WAR_DW_GEAR_TOTAL) or 'unavailable'
    local ma=get_war_multiattack_snapshot(false)
    local brazen_active=state and state.Buff and state.Buff['Brazen Rush'] or false
    local da_text=string.format('%d/%d',ma.raw_da,WAR_MULTIATTACK_RATE_CAP)..(brazen_active and ' +BR' or '')
    local ta_text=string.format('%d/%d',ma.raw_ta,WAR_MULTIATTACK_RATE_CAP)
    local style=state and state.Playstyle and state.Playstyle.value or 'Custom'
    local offense=state and state.OffenseMode and state.OffenseMode.value or '?'
    local preferred_tp=weapon_meta.tp_style or 'Normal'
    local tp_route=offense=='Normal' and preferred_tp or offense
    if weapon_meta.fencer then tp_route='Fencer/'..tostring(offense)
    elseif weapon_meta.requires_dw then tp_route='DW/'..tostring(tp_route) end
    local hybrid=state and state.HybridMode and state.HybridMode.value or '?'
    local wsmode=state and state.WeaponskillMode and state.WeaponskillMode.value or '?'
    local defense=defense_control_mode()
    local idle=state and state.IdleMode and state.IdleMode.value or '?'
    local th=state and state.TreasureHunter and state.TreasureHunter.value or 'Off'
    local lock=state and state.WeaponLock and state.WeaponLock.value or false
    local berserk_auto=state and state.BerserkAuto and state.BerserkAuto.value or false
    local warnings={}; if FalCore.locks.pause_active() then warnings[#warnings+1]='PAUSED' end; if FalCore.locks.fishing_active() then warnings[#warnings+1]='FISHING' end; if buffactive and buffactive.doom then warnings[#warnings+1]='DOOM' end; if buffactive and buffactive.silence then warnings[#warnings+1]='SILENCED' end; if not weapon_ok then warnings[#warnings+1]='WEAPON MISMATCH' end
    local status=#warnings>0 and table.concat(warnings,' | ') or 'OK'
    local active={}; local function ab(name,label) if state and state.Buff and state.Buff[name] then active[#active+1]=label or name end end
    ab('Berserk');ab('Aggressor');ab('Warcry');ab('Defender')
    if state and state.Buff and state.Buff.Retaliation then
        active[#active+1]=(weapon=='BunziChopper') and 'Retaliation(+10)' or 'Retaliation'
    end
    if state and state.Buff and state.Buff.Restraint then active[#active+1]='Restraint' end
    ab('Blood Rage');ab("Warrior's Charge");ab('Mighty Strikes');ab('Brazen Rush')
    local buffs=#active>0 and table.concat(active,', ') or 'none'
    local sc_text=sc.active and ((sc.status or '?')..(sc.choice_name and (' '..sc.choice_name..' -> '..tostring(sc.choice_result or '?')) or '')) or 'none'
    local key=table.concat({weapon,live_weapon,tostring(weapon_ok),dw_text,damage_type,style,offense,tp_route,hybrid,wsmode,defense,idle,th,tostring(lock),tostring(berserk_auto),status,buffs,movement_route_label(),sc_text,war_hud_config.layout,da_text,ta_text,tostring(ma.gear_da),tostring(ma.gear_ta),tostring(ma.native_da)},'|')
    if not force and war_hud_cache.key==key then return end
    war_hud_cache.key=key
    local rows={hcol('cyan','WAR v'..WAR_RELEASE_VERSION)..'  '..hfield('STATUS',status,status=='OK' and 'green' or 'red')}
    if section_on('loadout') then rows[#rows+1]=hrow('LOADOUT',hfield('Selected',weapon_label(weapon),'cyan')..'  '..hfield('Live',live_weapon,weapon_ok and 'green' or 'red')..'  '..hfield('Damage',damage_type,damage_type=='PIERCE' and 'yellow' or (damage_type=='BLUNT' and 'orange' or 'value'))..'  '..hfield('Lock',lock and 'ON' or 'off',lock and 'green' or 'orange')..'  '..hfield('Style',style,style=='Custom' and 'dim' or 'green')) end
    if section_on('combat') then rows[#rows+1]=hrow('COMBAT',hfield('Melee',offense)..'  '..hfield('TP Route',tp_route,offense=='Normal' and 'cyan' or 'value')..'  '..hfield('Hybrid',hybrid,hybrid=='DT' and 'green' or 'orange')..'  '..hfield('WS',wsmode)..'  '..hfield('Defense',defense,defense~='Normal' and 'orange' or 'value')..'  '..hfield('Idle',idle)..'  '..hfield('DW',dw_text,native_dw>0 and 'green' or 'dim')) end
    if section_on('combat') then rows[#rows+1]=hrow('MULTI',hfield('DA',da_text,ma.raw_da>=WAR_MULTIATTACK_RATE_CAP and 'green' or 'cyan')..'  '..hfield('TA',ta_text,ma.raw_ta>=WAR_MULTIATTACK_RATE_CAP and 'green' or 'yellow')..'  '..hfield('DA gear',tostring(ma.gear_da)..'%','value')..'  '..hfield('DA native',tostring(ma.native_da)..'%','value')..'  '..hfield('TA gear',tostring(ma.gear_ta)..'%','value')) end
    if section_on('utility') then
        rows[#rows+1]=hrow('UTILITY',hfield('TH',th,th~='Off' and 'yellow' or 'dim')..'  '..hfield('Berserk Auto',berserk_auto and 'ON' or 'off',berserk_auto and 'green' or 'dim')..'  '..hfield('Move',movement_route_label(),FalCore.move.moving and 'green' or 'dim'))
        if sc.active then rows[#rows+1]=hrow('F11 SC',hfield('State',sc.status,sc.status=='READY' and 'green' or (sc.status=='WAIT' and 'orange' or 'yellow'))..(sc.choice_name and ('  '..hfield('Closer',sc.choice_name..' -> '..tostring(sc.choice_result or '?'),'cyan')) or '')) end
    end
    if section_on('buffs') then rows[#rows+1]=hrow('BUFFS',hcol('value',buffs)) end
    if section_on('shortcuts') then
        rows[#rows+1]=hrow('F10-F12',hcol('value','F10 Berserk Auto | F11 SC Closer | F12 Primary WS'))
        rows[#rows+1]=hrow('CTRL F9-12',hcol('value','Prev Weapon | Next Weapon | Weapon Lock | Silmaril'))
        rows[#rows+1]=hrow('COMBAT KEY',hcol('value','Ctrl+F1 Normal/Acc/STP/PDL | F2 Melee DT | F3 Defense | F4 WS Mode | F7 Idle'))
        rows[#rows+1]=hrow('UTILITY KEY',hcol('value','Alt+F1 TH | F2 Fishing | F3 Pause | F9 HUD Lock | F10 HUD'))
    end
    if war_hud_config.layout=='compact' then
        local compact={rows[1],hfield('Weapon',weapon_label(weapon),'cyan')..'  '..hfield('Dmg',damage_type,'yellow')..'  '..hfield('Melee',offense)..'  '..hfield('TP',tp_route,'cyan')..'  '..hfield('DT',hybrid)..'  '..hfield('Def',defense),hfield('DA',da_text,'cyan')..'  '..hfield('TA',ta_text,'yellow')..'  '..hfield('TH',th)..'  '..hfield('Move',FalCore.move.moving and 'ON' or 'off')..'  '..hfield('F11',sc.active and sc.status or '-')}
        war_hud:text(table.concat(compact,'\n'))
    else
        war_hud:text(table.concat(rows,'\n'))
    end
    if war_hud_visible then war_hud:show() end
end

-------------------------------------------------------------------------------------------------------------------
-- Reports and commands
-------------------------------------------------------------------------------------------------------------------

local function report_keybinds(startup_summary)
    if not startup_summary then
        add_to_chat(158,'=== WAR v'..WAR_RELEASE_VERSION..' primary controls ===')
        add_to_chat(158,' F10 Berserk Auto | F11 Manual Skillchain Closer | F12 Weapon-Aware Primary WS')
        add_to_chat(158,' Ctrl+F9 Previous Weapon | Ctrl+F10 Next Weapon | Ctrl+F11 Weapon Lock | Ctrl+F12 Silmaril')
        add_to_chat(158,' Alt+F9 HUD Position Lock | Alt+F10 HUD Show/Hide')
    end
    add_to_chat(158,'=== WAR combat modes ===')
    add_to_chat(158,' Ctrl+F1 Melee: Normal(Auto by weapon) > Acc > STP > PDL | Ctrl+F2 Melee DT: Off/On')
    add_to_chat(158,' Ctrl+F3 Defense: Normal > DT > MEVA | Ctrl+F4 WS: Normal > Acc > PDL | Ctrl+F7 Idle')
    add_to_chat(158,'=== WAR utility ===')
    add_to_chat(158,' Alt+F1 TH: Off > Tag > Fulltime | Alt+F2 Fishing | Alt+F3 Pause')
    if not startup_summary then
        add_to_chat(158,' typed: gs c warweapon <next|previous|name> | gs c warplay <style> | gs c wardefense <mode>')
        add_to_chat(158,' typed: gs c skillchain | gs c bestws | gs c hudlayout compact|expanded | hudscale <0.7-1.6> | hudopacity <0-255>')
        add_to_chat(158,' Info: thinfo | weaponinfo/dwinfo | multiattackinfo/mainfo | fencerinfo/tpinfo | berserkinfo | moveinfo | abilityinfo | sctest | version')
    else
        add_to_chat(158,' Full keybind reference: gs c keys')
    end
end

local function report_th()
    local mob=FalCore.util.current_target_mob()
    add_to_chat(158,string.format('[WAR TH] %s | target=%s (no tracker: TH is a plain toggle, see fal-core.lua)',
        FalCore.util.bool_word(state.TreasureHunter.value),tostring(mob and mob.id or nil)))
end

local function report_abilities()
    local names={
        'Berserk','Aggressor','Warcry','Defender','Retaliation','Restraint',
        'Blood Rage',"Warrior's Charge",'Mighty Strikes','Brazen Rush',
    }
    local active={}
    for _,name in ipairs(names) do
        if state.Buff[name] then active[#active+1]=name end
    end
    add_to_chat(158,'[WAR Buffs] '..(#active>0 and table.concat(active,', ') or 'none active'))
end

function job_self_command(cmdParams,eventArgs)
    -- Core handles _falmovementrefresh / perf / keys / coreversion.
    if FalCore.self_command(cmdParams,eventArgs) then return end
    local cmd=(cmdParams[1] or ''):lower()
    if cmd=='_weaponapply' then
        eventArgs.handled=true
        local token=cmdParams[2]
        local generation=tonumber(cmdParams[3])
        local key=cmdParams[4]
        local stage=(cmdParams[5] or ''):lower()
        if FalCore.runtime.unloading or token~=FalCore.runtime.token then return end
        if generation~=weapon_apply_state.generation then return end
        run_weapon_apply_stage(key,generation,stage)
    elseif cmd=='_movementrefresh' then
        -- This command is entered through GearSwap's managed self-command
        -- path, so the equip() calls made by handle_equipping_gear are sent
        -- after this function returns.  The raw prerender callback cannot do
        -- that itself.
        FalCore.move.refresh_queued=false
        eventArgs.handled=true
        if FalCore.runtime.unloading or cmdParams[2]~=FalCore.runtime.token then return end
        if not FalCore.move.refresh_pending then
            update_hud(false)
            return
        end
        FalCore.move.check()
        if FalCore.locks.pause_active() or (type(midaction)=='function' and midaction()) then
            return
        end

        local slot=FalCore.move.requested() and FalCore.move.ring_slot() or nil
        if slot and not FalCore.locks.ring_protected(slot) then
            -- Reassert the selected slot here rather than trusting the local
            -- lock cache; this also repairs a stale disabled slot left by a
            -- prior Doom, Pause, Fishing, or utility-ring transition.
            enable(slot)
            FalCore.locks.ring_state[slot]=false
        end

        FalCore.move.refresh_pending=false
        if type(handle_equipping_gear)=='function' and player then
            handle_equipping_gear(player.status)
            if FalCore.locks.fishing_active() then FalCore.locks.apply_fishing_policy() end
        end
        update_hud(false)
    elseif cmd=='_startupkeys' then
        if cmdParams[2]==FalCore.runtime.token and not FalCore.runtime.unloading then report_keybinds(true) end
        eventArgs.handled=true
    elseif cmd=='warweapon' or cmd=='weapon' then
        local arg=(cmdParams[2] or 'next'):lower()
        if arg=='next' or arg=='forward' then cycle_weapon_profile('next')
        elseif arg=='previous' or arg=='prev' or arg=='back' then cycle_weapon_profile('previous')
        else apply_weapon_profile(cmdParams[2]) end
        eventArgs.handled=true
    elseif cmd=='warplay' or cmd=='playstyle' then
        local arg=(cmdParams[2] or 'next'):lower()
        if arg=='next' or arg=='forward' then cycle_playstyle('next')
        elseif arg=='previous' or arg=='prev' or arg=='back' then cycle_playstyle('previous')
        else apply_playstyle(cmdParams[2]) end
        eventArgs.handled=true
    elseif cmd=='wardefense' or cmd=='defense' then
        local arg=(cmdParams[2] or 'next'):lower()
        if arg=='next' or arg=='cycle' then cycle_defense_control() else apply_defense_control(arg) end
        eventArgs.handled=true
    elseif cmd=='skillchain' or cmd=='scclose' then
        execute_manual_skillchain()
        eventArgs.handled=true
    elseif cmd=='bestws' or cmd=='primaryws' then
        execute_context_weaponskill()
        eventArgs.handled=true
    elseif cmd=='sctest' then
        local snap=sc_opportunity_snapshot(os.clock())
        add_to_chat(158,'[WAR SC] active='..tostring(snap.active)..' status='..tostring(snap.status)..' opener='..tostring(snap.opener)..' props='..tostring(snap.properties_text)..' closer='..tostring(snap.choice_name)..' -> '..tostring(snap.choice_result))
        eventArgs.handled=true
    elseif cmd=='hudlayout' then
        set_hud_layout(cmdParams[2]); eventArgs.handled=true
    elseif cmd=='hudscale' then
        set_hud_scale(cmdParams[2]); eventArgs.handled=true
    elseif cmd=='hudopacity' then
        set_hud_opacity(cmdParams[2]); eventArgs.handled=true
    elseif cmd=='hudsection' then
        set_hud_section(cmdParams[2],cmdParams[3]); eventArgs.handled=true
    elseif cmd=='version' then
        add_to_chat(158,'Falurian WAR GearSwap v'..WAR_RELEASE_VERSION..' ('..WAR_RELEASE_DATE..')')
        eventArgs.handled=true
    elseif cmd=='keybinds' or cmd=='keys' then
        report_keybinds()
        eventArgs.handled=true
    elseif cmd=='hud' then
        toggle_hud()
        eventArgs.handled=true
    elseif cmd=='hudlock' then
        toggle_hud_lock()
        eventArgs.handled=true
    elseif cmd=='thinfo' then
        report_th()
        eventArgs.handled=true
    elseif cmd=='threset' then
        if type(handle_equipping_gear)=='function' and player then handle_equipping_gear(player.status) end
        eventArgs.handled=true
    elseif cmd=='ringinfo' then
        add_to_chat(158,'[WAR Rings] ring1='..tostring(FalCore.util.ring_name('ring1'))..
            ' protected='..tostring(NO_SWAP_GEAR[FalCore.util.ring_name('ring1')]==true))
        add_to_chat(158,'[WAR Rings] ring2='..tostring(FalCore.util.ring_name('ring2'))..
            ' protected='..tostring(NO_SWAP_GEAR[FalCore.util.ring_name('ring2')]==true))
        eventArgs.handled=true
    elseif cmd=='weaponinfo' or cmd=='dwinfo' then
        local native_dw,dw_tier=war_native_dual_wield()
        local wmeta=WAR_WEAPON_META[state.WeaponSet.value] or {}
        add_to_chat(158,'[WAR Weapon] selected='..weapon_label(state.WeaponSet.value)..
            ' | live='..live_weapon_description()..
            ' | match='..tostring(weapon_profile_matches(state.WeaponSet.value))..
            ' | lock='..tostring(state.WeaponLock.value)..
            ' | damage='..tostring(wmeta.damage)..
            ' | autoTP='..tostring(wmeta.tp_style or 'Normal')..
            ' | DW='..dw_tier..' '..native_dw..' + gear '..(dual_wield_melee_active() and WAR_DW_GEAR_TOTAL or 0))
        eventArgs.handled=true
    elseif cmd=='multiattackinfo' or cmd=='mainfo' or cmd=='dainfo' then
        report_multiattack((cmdParams[2] or ''):lower()=='refresh')
        eventArgs.handled=true
    elseif cmd=='fencerinfo' or cmd=='tpinfo' then
        local ws=resolve_context_weaponskill()
        local mock={english=ws,type='WeaponSkill'}
        local total,detail=effective_ws_tp(mock,true)
        local _,assumed_jp=war_fencer_gift_tp()
        add_to_chat(158,string.format('[WAR TP] WS=%s | raw=%d | Fencer rank=%s trait=%d + gifts=%d (assumed JP=%d, ML=%d) = %d | weapon=%d | Crystal=%d | Moonshade=%d | effective=%d',
            tostring(ws or 'n/a'),detail.raw,tostring(detail.fencer_rank>0 and detail.fencer_rank or 'off'),detail.fencer_trait,detail.fencer_gifts,assumed_jp or 0,WAR_PROGRESSION.master_level,detail.fencer,detail.weapon,detail.crystal,detail.moonshade,total))
        eventArgs.handled=true
    elseif cmd=='berserkinfo' then
        add_to_chat(158,'[WAR Berserk] auto='..tostring(state.BerserkAuto.value)..
            ' | active='..tostring(state.Buff.Berserk)..
            ' | pending='..tostring(berserk_sequence.pending and berserk_sequence.pending.ws or nil))
        eventArgs.handled=true
    elseif cmd=='moveinfo' then
        add_to_chat(158,string.format(
            '[WAR Move] FalCore.move.moving=%s | Auto_Kite=%s | manual=%s | route=%s | pending=%s | queued=%s | defense=%s | sample=%.2fs | stop debounce=%.2fs',
            tostring(FalCore.move.moving),tostring(state.Auto_Kite.value),tostring(state.Kiting.value),
            movement_route_label(),tostring(FalCore.move.refresh_pending),
            tostring(FalCore.move.refresh_queued),tostring(state.DefenseMode.value),
            FalCore.move.sample_interval,FalCore.move.stop_debounce))
        add_to_chat(158,'[WAR Move] ring1='..tostring(FalCore.util.ring_name('ring1'))..
            ' lock='..tostring(FalCore.locks.ring_state.ring1)..
            ' | ring2='..tostring(FalCore.util.ring_name('ring2'))..
            ' lock='..tostring(FalCore.locks.ring_state.ring2))
        eventArgs.handled=true
    elseif cmd=='abilityinfo' or cmd=='buffinfo' then
        report_abilities()
        eventArgs.handled=true
    end
end

function display_current_job_state(eventArgs)
    local msg=string.format(
        'WAR | Weapon %s [%s] | Damage %s | Style %s | Melee %s/%s | WS %s | Defense %s | Idle %s | TH %s | Move %s | BerserkAuto %s | /%s',
        weapon_label(state.WeaponSet.value),
        state.WeaponLock.value and 'LOCK' or 'FREE',
        tostring((WAR_WEAPON_META[state.WeaponSet.value] or {}).damage or '?'),
        tostring(state.Playstyle and state.Playstyle.value or 'Custom'),
        tostring(state.OffenseMode.value),tostring(state.HybridMode.value),
        tostring(state.WeaponskillMode.value),defense_control_mode(),
        tostring(state.IdleMode.value),tostring(state.TreasureHunter.value),
        FalCore.move.moving and 'ON' or 'off',state.BerserkAuto.value and 'ON' or 'OFF',
        tostring(player.sub_job))
    add_to_chat(158,msg)
    eventArgs.handled=true
end
