-- Original: Motenten / Modified: Arislan
-- Falurian RDM GearSwap v2.61 (concise reload log; v2.18 core frozen)
local RDM_RELEASE_VERSION = '2.61'
local RDM_RELEASE_DATE = '2026-08-15'

-- @ai:gearpolicy v2.29 | Augmented RDM JSE items are first-class policy: Dls. Torque +2 Path A duration and Crocea Mors Path C main-hand synergies must never be treated as base-item-only stats.
-- @ai:intelligence v2.32 | Community Harvest C1 adds deterministic Moonshade overflow replacement, instant-cast midcast preloading, bidirectional Phalanx routing, SIRD casting policy, and explicit smart-nuke degradation. No broad encounter-context inference is introduced. Augment ranks remain intentionally undefined until finalized.
-- @ai:niche v2.34 | Adds projected-set DW math, Maxentius, MEVA defense, automatic/manual low/high-tier nuking, manual PDL WS mode, and overlay-aware sleep timing.
-- @ai:cleanup v2.35 | Removes all in-job optimizer code for extraction to a separate addon; fixes instant-midcast chat dedup, exact Mote WS-set resolution, dynamic FC reporting, and ear-aware Moonshade replacement.
-- @ai:gearaudit v2.37 | Reconciles every literal gear reference to the 2026-07-30 inventory export and recent RDM sources; separates balanced/max Enspell TP, preserves capped normal TP haste, and corrects WS/cure/midcast objective leaks.
-- @ai:controls v2.39 | Separates plain F9-F12 into weapon-pair cycle, playstyle cycle, manual Savage Blade, and deterministic default reset. Weapon pairs retain shield fallback and TP-bonus-aware WS ear routing.
-- @ai:hud v2.40 | Replaces the abbreviation-heavy GearInfo-era panel with a wide native command-center HUD: explicit mode purposes, burst policy/window, Saboteur target semantics, hidden selectors, safety state, and actionable key hints.
-- @ai:hudpersistence v2.41 | Saves layout, scale, opacity, visibility, section choices, and debounced drag position per character in GearSwap/data/Falurian_RDM_HUD.xml; the HUD still reloads locked for mouse safety.
-- @ai:controls v2.42 | Restores the displaced legacy combat-mode row on Shift+F9-F12: melee accuracy, emergency PDT, emergency MDT, and gear refresh. Plain F9-F12 retain their v2.39 single-purpose controls.
-- @ai:controls v2.43 | Decouples plain F11 Savage Blade from GearSwap's main-hand snapshot so valid sword-and-shield/single-wield transitions cannot suppress the command; F11 still never changes weapons.
-- @ai:controls v2.44 | Begins the full-keyboard rebind rollout by moving melee accuracy from Shift+F9 to Ctrl+F1. The bind cycles the shared OffenseMode, so Normal/MidAcc/HighAcc resolve through the same indexed engine in single-wield and DW forms.
-- @ai:controls v2.45 | Moves the engaged-melee DT toggle from Ctrl+F9 to Ctrl+F2. HybridMode remains Normal/DT internally for set compatibility, while the HUD and reload guide expose the clearer Melee DT Off/On wording.
-- @ai:controls v2.46 | Retires the independent WS selector so OffenseMode alone chooses normal/accuracy WS gear; consolidates emergency defense as Normal/DT/MEVA on Ctrl+F3; renames Resistant casting to SpellACC and moves casting to Ctrl+F4. Legacy Mote defense values remain internal-only for stable set resolution.
-- @ai:defense v2.47 | Preserves Mote's post-resolution DT/MEVA overlay in customize_melee_set. Active emergency Defense now owns engaged armor instead of being replaced by the indexed TP base; Normal retains all existing melee overlays.
-- @ai:simplification v2.48 | Retires NukeMode, SleepMode, forced/optional burst states, low-tier elemental branches, and smart-nuke commands. Elemental Magic uses one canonical set plus CastingMode SpellACC; Sleep always uses its accuracy-first set; validated target/element/window AutoMB is permanently active and presentation-free.
-- @ai:simplification v2.49 | Makes Enhancing permanently spell-aware with no mode/HUD state; reduces Enfeebling to Auto/Accuracy on Ctrl+F5; renames forced Enspell melee to Max and moves its Auto/Max/Off cycle to Ctrl+F6, retiring Win+M.
-- @ai:utility v2.50 | Moves manual TH/Fishing/Pause to Alt+F1/F2/F3. Fishing now freezes every slot except rings, explicitly clears the rod on exit, permits native Shneddick movement swaps, and preserves Warp/Dimensional ring protection; Pause remains a true all-slot freeze.
-- @ai:controls v2.51 | Clears every plain/Shift/Ctrl/Alt/Win F9-F12 binding, then reserves plain F12 for a weapon-aware WS command. The command reads the equipped main/sub pair and maps canonical Crocea, Naegling, Maxentius, Tauret, and Daybreak loadouts to their primary WS without changing weapons.
-- @ai:controls v2.52 | Rebuilds Ctrl+F9/F10 as previous/next canonical weapon-pair controls and Ctrl+F11 as WeaponLock, retiring the overlapping Win+E/Win+R/Win+W routes. Plain F12 remains the live-pair weapon-aware WS button.
-- @ai:skillchain v2.53 | Replaces timer-driven AutoSC with a fully manual F11 closer. Action packets only remember the latest WS/formed-chain resonance on the target; F11 validates timing/target/TP, ranks live-weapon WS options by resulting chain level, and fires exactly once without changing weapons. Ctrl+F11 WeaponLock and F12 standalone WS remain independent.
-- @ai:controls v2.54 | Retires Win+D and Mote's hidden Ctrl-minus/Ctrl-equals targeting binds, moves Silmaril to Ctrl+F12, and adds a Naegling/TP Bonus/Kaja Bow profile with Empyreal Arrow F11/F12 awareness, a ranged-accuracy-conscious WS set, and explicit range-slot cleanup when leaving the bow.
-- @ai:controls v2.55 | Retires manual Kiting in favor of authoritative native movement detection and removes the redundant typed Savage Blade command. Idle gear, the inert generic ranged selector, ammo safety, playstyle presets, and typed rdmreset remain unchanged pending individual review.
-- @ai:controls v2.56 | Moves Idle Gear Normal/DT to Ctrl+F7, retires the inert generic ranged selector from RDM's exposed controls, and gives optional ammo safety an explicit typed rangedlock command with toggle/on/off/status forms.
-- @ai:hud v2.56 | Moves Weapon Lock beside the authoritative top-line Gear swaps state, removes duplicate lower swap state and inactive F11 placeholders, and exposes the active plain/Ctrl F9-F12 legend in both HUD layouts.
-- @ai:controls v2.57 | Reclaims Alt+F9 from the retired generic ranged selector as the HUD drag-lock toggle, retiring Ctrl+Win+H while preserving Win+H visibility and the typed hudlock command.
-- @ai:gearpolicy v2.57 | Standardizes the Kaja Bow Empyreal Arrow profile on the user-preferred Chapuli Arrow.
-- @ai:skillchain v2.58 | Keeps the validated manual-F11 timing, treats all live same-class learned WS as eligible, uses weapon synergy only as a same-chain-level tie-break, records one final resonance per WS packet, and makes the HUD distinguish WAIT/NEED TP/READY/NO CLOSER/PENDING while naming the exact WS and chain result. F11 context is consumed only after its WS completion packet confirms execution.
-- @ai:magicburst v2.59 | Adds a fully manual plain-F10 magic-burst button driven by the formed-chain window already used by AutoMB gear. Each press selects the highest-tier learned, current-job-usable, ready, affordable standard RDM elemental nuke compatible with that chain; same-tier ties favor the stronger base nuke. It fires once, never queues/retries, never consumes the window, and exposes the exact spell/blocker in both HUD layouts.
-- @ai:controls v2.60 | Moves HUD show/hide from Win+H to Alt+F10 while retaining Alt+F9 drag lock and typed `gs c hud`; explicitly clears stale Win+H on load/unload and updates every player-facing key legend.
-- @ai:gearpolicy v2.60 | Makes Chapuli Arrow part of the canonical KajaBow weapon set and the final idle/melee profile overlay (including emergency Defense), so later armor resolution cannot silently replace the selected bow ammunition. Empyreal Arrow retains its dedicated Chapuli precast.
-- @ai:chat v2.61 | Makes the automatic reload refresher concise: HUD-covered F10-F12 and Ctrl/Alt F9-F10 guidance, fixed Enhancing/WS-mode notes, and retired Mote target-bind history are omitted only at startup. Typed `gs c keys` retains the complete reference.
-- @ai:safety v2.24 | Runtime Gear Audit is intentionally removed after repeated live-client stack-overflow/crash reports. Do not reintroduce inventory/set traversal in-game without explicit user approval.
-- @ai:corefreeze v2.18 | The combat/performance core is frozen here. New features
-- should live in cold-path modules unless a measured bug/correctness issue requires
-- touching hot=yes engine code. JA_RELOAD and OFFHAND_CLASSIFY remain accepted risks.

-- Runtime lifecycle registry. Custom Windower events are explicitly tracked so
-- repeated GearSwap reloads/job changes cannot leave duplicate callbacks behind.
-- Async helpers also consult `unloading` before performing delayed side effects.
local RDM_RUNTIME = {
    unloading = false,
    event_ids = {},
    -- Private self-commands carry this per-load token so a movement refresh
    -- queued by an older/reloaded copy can never mutate the new runtime.
    token = tostring(os.time())..'-'..tostring(math.floor(os.clock() * 1000000)),
}

-- Defined with the HUD subsystem later in the file. user_unload needs this
-- forward reference so the final dragged coordinates are committed before the
-- text primitive is destroyed during a GearSwap reload or job change.
local save_hud_preferences

-- The manual skillchain chooser is implemented after the action-packet tables,
-- while the HUD is defined earlier. Forward declarations let presentation read
-- the same authoritative decision that F11 will execute. These are assigned
-- once during file load and never replaced at runtime.
local pick_chain_ws
local sc_refresh_choice
local sc_opportunity_snapshot
local sc_confirm_pending
local mb_opportunity_snapshot
local mb_confirm_precast
local mb_confirm_aftercast
local execute_manual_magic_burst
local manual_mb

-- Weapon selection and playstyle selection remain independent controllers.
-- Ctrl+F7 cycles idle gear. Ctrl+F9/F10 cycle the canonical weapon-pair list,
-- Ctrl+F11 controls whether spells may temporarily replace those weapons,
-- plain F10 manually bursts the latest formed skillchain, plain F11 manually
-- closes the highest-level available skillchain, and plain F12 fires a
-- standalone WS for the live equipped combination. Ctrl+F12 toggles Silmaril,
-- and Alt+F9 toggles whether the HUD can be dragged. F10/F11/F12 never change
-- the selected weapon pair.
local RDM_DEFAULT_WEAPON_SET = 'CroceaMors'
local RDM_DEFAULT_PLAYSTYLE = 'Balanced'

-- Mote-Globals claims much of F9-F12 before user_setup runs. Clear every
-- unmodified and single-modifier variant so no generic or retired controller
-- survives a reload. user_setup then binds plain F10/F11/F12, Ctrl+F9-F12,
-- and Alt+F9 for HUD position locking.
local RDM_FKEY_MODIFIERS = {'', '^', '!', '~', '@'} -- plain, Ctrl, Alt, Shift, Win
local function clear_f9_f12_bindings()
    for key_number = 9, 12 do
        for _, modifier in ipairs(RDM_FKEY_MODIFIERS) do
            send_command('unbind '..modifier..'f'..tostring(key_number))
        end
    end
end

-- Mote-Globals also claims Ctrl-minus and Ctrl-equals for automatic target
-- rewrites. They were never used in this profile, so explicitly clear them on
-- both load and unload instead of allowing invisible framework controls.
local function clear_legacy_target_bindings()
    send_command('unbind ^-')
    send_command('unbind ^=')
end

local RDM_WEAPON_PAIR_ORDER = {
    'CroceaMors', 'CroceaTPBonus',
    'Naegling', 'NaeglingTPBonus',
    'Maxentius', 'MaxentiusTPBonus',
    'Tauret', 'KajaBow', 'Idle',
}

-- Gear tables for these keys are built in init_gear_sets. The metadata is
-- presentation/review policy plus the primary WS hint printed on each cycle.
-- `crocea_main` drives the audited balanced Enspell overlay for both Crocea
-- pairings; `tp_bonus` documents the confirmed Machaera +2 augment.
local RDM_WEAPON_PAIR_META = {
    CroceaMors={label='Crocea / Daybreak', primary_ws='Chant du Cygne',
        purpose='balanced Enspell melee and elemental WS', crocea_main=true},
    CroceaTPBonus={label='Crocea / TP Bonus', primary_ws='Seraph Blade',
        purpose='Crocea elemental WS with TP Bonus +1000', crocea_main=true, tp_bonus=1000},
    Naegling={label='Naegling / Blurred', primary_ws='Savage Blade',
        purpose='fast sustained Savage Blade TP'},
    NaeglingTPBonus={label='Naegling / TP Bonus', primary_ws='Savage Blade',
        purpose='high-value Savage Blade with TP Bonus +1000', tp_bonus=1000},
    Maxentius={label='Maxentius / Blurred', primary_ws='Black Halo',
        purpose='fast sustained Black Halo TP'},
    MaxentiusTPBonus={label='Maxentius / TP Bonus', primary_ws='Black Halo',
        purpose='high-value Black Halo with TP Bonus +1000', tp_bonus=1000},
    Tauret={label='Tauret / Blurred', primary_ws='Evisceration',
        purpose='piercing damage and critical Evisceration'},
    KajaBow={label='Naegling / TP / Kaja Bow', primary_ws='Empyreal Arrow',
        purpose='melee TP into Chapuli Arrow ranged Fusion WS', tp_bonus=1000, ranged_ws=true},
    Idle={label='Daybreak / Ammurapi', primary_ws='Black Halo',
        purpose='caster and shield utility'},
}

-- Plain F12 gives a recognized ranged weapon first priority, then resolves an
-- exact canonical main/sub pair. That distinction matters for Crocea:
-- Daybreak/shield routes to CDC, while Machaera TP Bonus routes to Seraph Blade.
-- A main-hand fallback supports manual offhand changes without ever guessing
-- for an unknown/casting weapon.
local RDM_CONTEXT_WS_BY_WEAPON_SET = {
    CroceaMors='Chant du Cygne',
    CroceaTPBonus='Seraph Blade',
    Naegling='Savage Blade',
    NaeglingTPBonus='Savage Blade',
    Maxentius='Black Halo',
    MaxentiusTPBonus='Black Halo',
    Tauret='Evisceration',
    KajaBow='Empyreal Arrow',
    Idle='Black Halo',
}

local RDM_CONTEXT_WS_BY_RANGE = {
    ['Kaja Bow']='Empyreal Arrow',
}

local RDM_CONTEXT_WS_BY_MAIN = {
    ['Crocea Mors']='Chant du Cygne',
    ['Naegling']='Savage Blade',
    ['Maxentius']='Black Halo',
    ['Tauret']='Evisceration',
    ['Daybreak']='Black Halo',
}

local RDM_WEAPON_PAIR_ALIASES = {
    crocea='CroceaMors', croceadaybreak='CroceaMors', croceamors='CroceaMors',
    croceatp='CroceaTPBonus', croceatpbonus='CroceaTPBonus',
    naegling='Naegling', naeglingblurred='Naegling', savage='Naegling',
    naeglingtp='NaeglingTPBonus', naeglingtpbonus='NaeglingTPBonus', savagetp='NaeglingTPBonus',
    maxentius='Maxentius', maxentiusblurred='Maxentius', blackhalo='Maxentius',
    maxentiustp='MaxentiusTPBonus', maxentiustpbonus='MaxentiusTPBonus', blackhalotp='MaxentiusTPBonus',
    tauret='Tauret', evisceration='Tauret', dagger='Tauret',
    kajabow='KajaBow', kaja='KajaBow', empyrealarrow='KajaBow', bow='KajaBow',
    idle='Idle', caster='Idle', daybreak='Idle', shield='Idle',
}

local RDM_PLAYSTYLE_ORDER = {
    'Balanced', 'MaxTP', 'Enspell', 'DT', 'MEVA', 'HardTarget', 'Caster',
}

-- Playstyles are deterministic gear-policy bundles. Manual Treasure Hunter
-- stays independent and is never silently changed by this cycle. Manual
-- divergence changes the displayed style to
-- Custom without trying to force the preset back on.
local RDM_PLAYSTYLE_PROFILES = {
    Balanced={label='Balanced', modes={
        {'OffenseMode','Normal'}, {'HybridMode','DT'},
        {'CastingMode','Normal'},
        {'IdleMode','DT'},
        {'EnfeeblingMode','Auto'},
        {'EnspellMode','Auto'},
        {'DefenseMode','None'},
        {'WeaponLock',true},
    }, summary='DT-capped melee safety with normal WS/casting and balanced Crocea Enspell routing'},
    MaxTP={label='Max TP / Offense', modes={
        {'OffenseMode','Normal'}, {'HybridMode','Normal'},
        {'CastingMode','Normal'},
        {'IdleMode','DT'},
        {'EnfeeblingMode','Auto'},
        {'EnspellMode','Off'},
        {'DefenseMode','None'},
        {'WeaponLock',true},
    }, summary='maximum TP speed and physical offense; Enspell TP substitutions disabled'},
    Enspell={label='Max Enspell', modes={
        {'OffenseMode','Normal'}, {'HybridMode','Normal'},
        {'CastingMode','Normal'},
        {'IdleMode','DT'},
        {'EnfeeblingMode','Auto'},
        {'EnspellMode','Max'},
        {'DefenseMode','None'},
        {'WeaponLock',true},
    }, summary='explicit Ayanmo hands, Vitiation legs, and Orpheus max-Enspell overlay'},
    DT={label='Damage Taken', modes={
        {'OffenseMode','Normal'}, {'HybridMode','DT'},
        {'CastingMode','Normal'},
        {'IdleMode','DT'},
        {'EnfeeblingMode','Auto'},
        {'EnspellMode','Off'},
        {'DefenseMode','None'},
        {'WeaponLock',true},
    }, summary='engaged and idle DT sets with Enspell substitutions disabled'},
    MEVA={label='Magic Evasion', modes={
        {'OffenseMode','Normal'}, {'HybridMode','DT'},
        {'CastingMode','SIRD'},
        {'IdleMode','DT'},
        {'EnfeeblingMode','Accuracy'},
        {'EnspellMode','Off'}, {'MagicalDefenseMode','MEVA'},
        {'DefenseMode','Magical'}, {'WeaponLock',true},
    }, summary='full Bunzi magic-evasion wall with SIRD casting protection'},
    HardTarget={label='Hard Target', modes={
        {'OffenseMode','HighAcc'}, {'HybridMode','DT'},
        {'CastingMode','SpellACC'},
        {'IdleMode','DT'},
        {'EnfeeblingMode','Accuracy'},
        {'EnspellMode','Auto'},
        {'DefenseMode','None'},
        {'WeaponLock',true},
    }, summary='high-accuracy melee/WS, SpellACC elemental casting, and accuracy enfeebles'},
    Caster={label='Caster / Burst', modes={
        {'OffenseMode','Normal'}, {'HybridMode','DT'},
        {'CastingMode','Normal'},
        {'IdleMode','DT'},
        {'EnfeeblingMode','Auto'},
        {'EnspellMode','Auto'},
        {'DefenseMode','None'},
        {'WeaponLock',false},
    }, summary='spell weapon swaps unlocked; validated magic-burst gear is always automatic'},
}

local RDM_PLAYSTYLE_ALIASES = {
    balanced='Balanced', default='Balanced', normal='Balanced',
    maxtp='MaxTP', offense='MaxTP', tp='MaxTP',
    enspell='Enspell', maxenspell='Enspell',
    dt='DT', damagetaken='DT', defensive='DT',
    meva='MEVA', magicdefense='MEVA', magical='MEVA',
    hardtarget='HardTarget', accuracy='HardTarget', acc='HardTarget', nm='HardTarget',
    caster='Caster', burst='Caster', casterburst='Caster',
}

-- Player-facing defense policy. Mote's resolver still receives its required
-- None/Physical/Magical values, but no HUD, bind, or reload message exposes
-- that implementation detail.
local RDM_DEFENSE_ORDER = {'Normal', 'DT', 'MEVA'}
local RDM_DEFENSE_ALIASES = {
    normal='Normal', none='Normal', off='Normal',
    dt='DT', pdt='DT', mdt='DT', damagetaken='DT',
    meva='MEVA', magicevasion='MEVA',
}

local applying_weapon_pair = false
local applying_playstyle = false
local weapon_cycle_generation = 0
local playstyle_generation = 0

-- Lightweight native movement sampler. The prerender callback is throttled to
-- ~6.7 checks/second, uses squared distance (no sqrt), and only asks GearSwap
-- to rebuild gear when movement state actually changes. A short stop debounce
-- prevents packet cadence from making the movement ring flicker.
local movement_monitor = {
    sample_interval = 0.15,
    stop_debounce = 0.45,
    distance_squared = 0.01, -- 0.1 yalms between samples
    next_sample = 0,
    last_motion_at = 0,
    x = nil, y = nil, z = nil,
    refresh_pending = false,
    refresh_queued = false,
}

-- @ai:fn track_rdm_event | layer=lifecycle | hot=no | purity=write | contract=Record custom Windower event IDs for deterministic unload cleanup.
local function track_rdm_event(id)
    if id ~= nil then
        RDM_RUNTIME.event_ids[#RDM_RUNTIME.event_ids + 1] = id
    end
    return id
end

-- @ai:fn unregister_rdm_events | layer=lifecycle | hot=no | purity=write | contract=Unregister only IDs owned by this job file; safe on repeated calls.
local function unregister_rdm_events()
    if not (windower and type(windower.unregister_event) == 'function') then
        RDM_RUNTIME.event_ids = {}
        return
    end
    for _, id in ipairs(RDM_RUNTIME.event_ids) do
        pcall(windower.unregister_event, id)
    end
    RDM_RUNTIME.event_ids = {}
end
--
--  Haste/DW tiers are tracked natively. Equipped haste + visible haste buffs
--  feed the delay-cap formula, then /NIN or /DNC native DW is subtracted to
--  derive the exact gear-DW target. GearInfo is optional and comparison-only.
--  Geo/Indi-Haste has no personal buff icon; use 'gs c hasteadj <pct>' when needed.

-------------------------------------------------------------------------------------------------------------------
--  Keybinds
-------------------------------------------------------------------------------------------------------------------

--  Keybind philosophy: Ctrl+F9-F12 are the compact weapon/utility row. Plain
--  F10 is the fully manual magic-burst button, F11 is the fully manual
--  skillchain closer, and F12 is the standalone weapon-aware WS button. None
--  changes the selected weapon pair. Alt+F9 locks/unlocks HUD rearrangement.
--  Alt+F10 shows/hides the HUD. Plain F9, Shift/Win+F9-F12, and Alt+F11-F12
--  stay clear. Ctrl+F7 owns Idle Gear independently of the legacy preset bundles.
--
--  Main keys:  [ F10 ]             Burst the latest formed skillchain with the
--                                  highest-tier learned/usable/ready/affordable
--                                  compatible RDM elemental spell (one press,
--                                  one cast; never queues or retries)
--              [ F11 ]             Close the highest-level live skillchain
--                                  with any learned WS currently usable by the
--                                  equipped weapon class; affinity is tie-break only
--                                  (never queues, retries, or changes weapons)
--              [ F12 ]             Use primary WS for equipped weapon combination
--                                  Crocea/Daybreak or shield -> Chant du Cygne
--                                  Crocea/TP Bonus -> Seraph Blade
--                                  Naegling -> Savage Blade
--                                  Maxentius or Daybreak -> Black Halo
--                                  Tauret -> Evisceration
--                                  Kaja Bow -> Empyreal Arrow
--  Weapons:    [ CTRL+F9 ]         Previous Weapon Pair
--              [ CTRL+F10 ]        Next Weapon Pair
--              [ CTRL+F11 ]        Toggle Weapon Lock
--  Utility:    [ CTRL+F12 ]        Silmaril start/stop ('sm all toggle')
--  HUD:        [ ALT+F9 ]          Lock/unlock HUD rearrangement ('gs c hudlock')
--              [ ALT+F10 ]         Show/hide on-screen HUD ('gs c hud')
--  Open keys:  [ F9 ]              Unbound
--              [ SHIFT/WIN + F9-F12; ALT+F11-F12 ]  Unbound
--
--  Accuracy:   [ CTRL+F1 ]         Cycle Melee Accuracy (Normal/MidAcc/HighAcc)
--  Melee DT:   [ CTRL+F2 ]         Toggle Melee DT (Off/On)
--  Defense:    [ CTRL+F3 ]         Cycle Defense (Normal/DT/MEVA)
--  Casting:    [ CTRL+F4 ]         Cycle Casting (Normal/SIRD/SpellACC)
--  Enfeebling: [ CTRL+F5 ]         Cycle Enfeebling (Auto/Accuracy)
--  Enspell:    [ CTRL+F6 ]         Cycle Enspell Melee (Auto/Max/Off)
--  Idle gear:  [ CTRL+F7 ]         Cycle Idle Gear (Normal/DT)
--  Utilities:  [ ALT+F1 ]          Toggle Treasure Hunter OFF/ON (TH+3: egg + ring)
--              [ ALT+F2 ]          Fishing: equip fishing set; freeze all but rings
--              [ ALT+F3 ]          Pause/Resume ALL automatic gear swapping
--
--  Typed only:                      Caster's Roll FC assumption:
--                                  'gs c cycle CasterRollFC' (unbound;
--                                  never used as a key)
--                                  Adaptive Fast Cast: 'gs c fcinfo'
--                                  HUD lock also remains typed as 'gs c hudlock'
--  Retired:    [ WIN+H ]           HUD visibility (explicitly cleared; use Alt+F10)
--  Retired:    [ CTRL+- / CTRL+= ] Mote automatic target rewrites (explicitly cleared)
--
--  Typed/macro commands:
--      gs c rangedlock [on|off|status]  Toggle/query ordinary ranged-attack ammo safety (default on)
--      gs c rdmreset                   Restore Crocea/Daybreak + Balanced; preserve TH
--
--  Scholar stratagems (subjob SCH) via typed/macro commands:
--      gs c scholar light|dark|speed|cost|aoe|addendum
--
--  Magic Burst: formed skillchain windows are detected automatically (any
--  source: you, Silmaril, Trusts, party). Matching elemental spells always get
--  burst gear. Press F10 to select and cast the highest ready compatible RDM
--  nuke manually; the exact spell or blocker appears in the HUD. There is no
--  automatic spell casting, queue, retry, or mode toggle.
--
--  Manual Skillchain Closer: WS packets are observed passively, but no action is
--  scheduled. Press F11 during the valid window; pressing early/late only reports
--  why no WS fired. The live equipped weapon determines the available closers.


-------------------------------------------------------------------------------------------------------------------
--  AI MAINTENANCE MAP -- source-of-truth architecture contract (v2.32)
-------------------------------------------------------------------------------------------------------------------
--
--  PURPOSE
--    This is a Mote-framework GearSwap job file. Mote-Include.lua owns normal
--    GearSwap dispatch and calls the global framework hooks in this file.
--    Internal engines may be localized/refactored, but framework hook names and
--    signatures must remain global unless Mote itself is changed.
--
--  FUNCTION ANNOTATION SCHEMA
--    Every named function carries a compact, machine-searchable line:
--      @ai:fn <name> | layer=<...> | hot=<yes/no> | purity=<...> | contract=<...>
--    layer: framework, gear, fc, hud, haste-dw, command, qol, automb, skillchain,
--           lifecycle, utility
--    hot=yes: called per cast/equip/action/tick; minimize allocations/API calls first.
--    purity=pure: deterministic calculation; preferred target for unit tests.
--    purity=read: reads runtime/global state but should not mutate game state.
--    purity=write: mutates Lua state and/or performs GearSwap/Windower side effects.
--
--  OWNER / DATA-FLOW MAP
--    LOAD:
--      get_sets -> ItemStats.lua -> Mote-Include.lua
--      Mote init -> job_setup -> user_setup -> init_gear_sets
--
--    PERMANENT CHARACTER BASELINE:
--      RDM_PROGRESSION -> build_rdm_progression_baseline -> RDM_BASELINE -> RDM_PROFILE
--      RDM_MECHANICS + RDM_SPELL_POLICY + RDM_WEAPONSKILL_POLICY feed the intelligence
--      layer. job_setup compiles RDM_SPELL_POLICY -> RDM_SPELL_RUNTIME once; hot spell
--      hooks use exact-name O(1) resolvers with no policy scans/dynamic route strings.
--      Consumers: diagnostics, spell routing, and future gear/role engines.
--      Current profile assumptions: Job Master, all Gifts, ML23, capped general
--      HP/MP/attribute/combat-skill/magic-skill merits. RDM Group 1/2 choices
--      remain runtime-driven and must not be invented.
--
--    FAST CAST:
--      rdm_native_fc + CasterRollFC + instant-cast buffs
--        -> update_fc_tier -> build_fc_sets/cache -> sets.precast.FC variants
--
--    NATIVE HASTE / DUAL WIELD (AUTHORITATIVE):
--      player.equipment -> ItemStats haste -> get_equipment_snapshot
--      buffactive + haste_assume + haste_manual_magic -> estimate_haste
--      projected resolved melee set + dw_native_trait + offhand state
--        -> update_native_haste_dw -> Haste/DW/DW_needed
--        -> update_dw_overlay -> minimal valid owned DW subset
--      GearInfo packets NEVER drive Haste/DW/DW_needed or movement; they
--      populate GI_* only for optional comparison.
--
--    NATIVE MOVEMENT (AUTHORITATIVE):
--      throttled prerender -> player entity position delta -> moving
--        -> check_moving -> state.Auto_Kite -> sets.Kiting
--      GearInfo is not read for movement and may be fully unloaded.
--
--    MELEE:
--      determine_haste_group -> update_native_haste_dw/update_dw_overlay
--      customize_melee_set -> engaged_set_index + DW overlay + policy overlays
--
--    HUD:
--      update_hud reads already-computed state. Keep it presentation-only.
--      It retains hidden-HUD and identical-text fast paths. Do not move expensive
--      inventory/resource scans into update_hud.
--
--    AUTO MAGIC BURST:
--      raw action event -> handle_action_packet -> sc_window
--      sc_burst_window_active validates time, target, and element at cast time.
--      F10 -> mb_opportunity_snapshot -> execute_manual_magic_burst -> one cast.
--      F10 reads the same formed-chain window; it never infers from a raw WS.
--
--    MANUAL SKILLCHAIN CLOSER:
--      action WS/formed chain -> sc_track_ws_open/sc_note_resonance
--      F11 -> execute_manual_skillchain -> pick_chain_ws -> one manual WS.
--      Packet tracking never schedules, retries, queues, or spends TP.
--
--    COMMUNITY HARVEST C1 (DETERMINISTIC ONLY):
--      WS precast -> apply_max_tp_moonshade (only when resolved set wears Moonshade)
--      Chainspell/Spontaneity -> preload normal midcast + post-midcast overlays in precast
--      Phalanx ally target -> Phalanx II; Phalanx II self target -> Phalanx
--      CastingMode SIRD -> final 57%-owned-SIRD overlay; Utsusemi always protected
--
--    LIFECYCLE:
--      RDM_RUNTIME owns unload state + custom Windower event IDs.
--      user_unload must restore disabled slots, invalidate async work, unregister
--      custom events, unbind keys, and hide HUD so the next job starts clean.
--
--  UNITS / NUMERIC INVARIANTS
--    * Haste: 1024ths. 1% = 10.24. Caps: gear 256, magic 448, JA 256,
--      total delay-reduction bucket 819 (~80%).
--    * Fast Cast / Dual Wield: flat percentage points.
--    * DW_needed is GEAR-ONLY after native /NIN or /DNC trait subtraction.
--      Never add dw_native_trait() back into update_dw_overlay's target.
--    * Delay cap math:
--        (1 - DW/100) * (1 - haste/1024) = 0.20
--    * DW delay math uses the projected final engaged set, including Enspell,
--      Carmine, adaptive-DW, and Sailfi choices. Never substitute a blanket
--      256 gear-haste assumption: some valid resolved variants sit below cap.
--    * Native RDM FC comes from RDM_BASELINE and is already subtracted from the
--      80% FC target. Never double-count trait/Gifts.
--
--  GEAR / INVENTORY INVARIANTS
--    * Five Sucellos's Capes exist. `capes` in init_gear_sets is the canonical
--      augment registry; do not inline cape augment tables elsewhere.
--    * DW cape contributes +10 only when dw_cape_active=true; otherwise DA cape.
--    * ItemStats.lua is the numeric/item-eligibility sidecar. Policy belongs here;
--      owned item stat facts belong there.
--    * Patentia Sash, Niqmaddu Ring, and Yamarang are not valid RDM suggestions.
--
--  OPTIMIZATION PRIORITY FOR FUTURE AI
--    1. Preserve observable gear/command behavior before micro-optimizing.
--    2. For hot=yes functions, prefer invalidation keys/caches over repeated scans.
--    3. Extract arithmetic into purity=pure helpers before changing formulas.
--    4. Never add raw per-frame/per-packet work when a state-change event exists.
--    5. Update @ai contracts + tests whenever ownership/data flow changes.
--
--  CURRENT HOT-PATH INVARIANTS (v2.17)
--    * update_hud compares scalar visible state BEFORE constructing colored strings.
--      Do not replace this with a concatenated signature key or eager formatting.
--    * Visible magic/JA haste is invalidation-cached. Only haste-family buff changes
--      or hastetier changes should dirty the buff bucket cache.
--    * check_weaponset skips equip() while weapon/full-swap locks are active and
--      when actual main/sub/range already match the selected profile.
--    * job_get_spell_map performs one exact compiled-policy lookup per spell and
--      must not scan policy/classification tables or synthesize route strings.
--    * update_native_haste_dw must preserve the adaptive DW overlay cache when
--      only haste/trait observability changes and active+gear_need are unchanged.
--      Buff-change gear re-resolution is required only when overlay_changed=true.
--
--  KNOWN MODEL LIMITS / REVIEW TARGETS
--    @ai:risk HASTE_ICON | Haste/Haste II share a buff icon; `hastetier` is an explicit assumption.
--    @ai:risk HASTE_EXTERNAL | March potency is estimated; Geo/Indi-Haste needs `hasteadj`.
--    @ai:risk HASTE_SAMBA | Haste Samba is intentionally excluded from authoritative
--      haste math because the self-buff does not prove the current target has Haste Daze.
--    @ai:risk OFFHAND_CLASSIFY | Native DW uses a small known shield/grip denylist; update
--      native_non_weapon_subs if future weapon profiles add other non-weapon sub items.
--    @ai:risk AUTOBURST_SINGLE | The detector stores one global sc_window; simultaneous
--      multi-target chains collapse to the last detected target/window.
--    @ai:risk JA_RELOAD | JA readiness is locally timestamped and may be optimistic
--      immediately after a GearSwap reload.
--
--  PRIMARY DIAGNOSTICS
--    gs c version | baseline | intelligence | policy <name> | spellintel <spell> | spellwhy <spell>
--    gs c fcinfo | dwinfo | hastecheck | magicmodes
--    gs c perf | sctest | keys | hudinfo
--
-------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------


-------------------------------------------------------------------------------------------------------------------
-- Gear Intelligence Foundation + Phase B2 spell intelligence + Community Harvest C1 (v2.32)
--
-- This layer is deliberately declarative and cold-path. It centralizes facts and
-- policy labels that used to be scattered across job_setup, spell routing comments,
-- WS aliases, and Gain-spell hints. It MUST NOT perform runtime
-- inventory scans or per-frame work. Heavy gear analysis remains offline.
--
-- Migration rule: a future behavior change should first be expressible here as data,
-- then consumed by a small tested resolver. Do not turn these tables into a second
-- hot engine or silently change gear behavior merely by editing metadata.
-------------------------------------------------------------------------------------------------------------------

RDM_MECHANICS = {
    schema_version = '1.0',
    units = {
        haste = '1024ths',
        fast_cast = 'percentage_points',
        dual_wield = 'percentage_points',
        damage_taken = 'percentage_points',
    },
    caps = {
        fast_cast_total = 80,
        gear_haste_1024 = 256,
        magic_haste_1024 = 448,
        ja_haste_1024 = 256,
        total_haste_1024 = 819,
        damage_taken = 50,
        magic_damage_taken = 50,
    },
    delay = {
        floor_multiplier = 0.20,
    },
    breakpoints = {
        -- Existing v2.20 gear policy: once this project model reaches the
        -- Phalanx potency skill breakpoint, remaining slots prioritize duration.
        phalanx_enhancing_skill = 500,
    },
}

-- Phase B2 family intent supplies explicit decision dimensions shared by spells.
-- These are policy goals, not raw FFXI target masks or invented potency formulas.
-- Per-spell entries may override any dimension when the family is too broad.
RDM_SPELL_FAMILY_POLICY = {
    -- Enhancing families. `landing_intent='none'` means accuracy is not a gear objective.
    haste          ={target_scope='self_or_ally', landing_intent='none', potency_intent='tier_defined',          duration_intent='primary',   skill_dependence='none',             composure_other_gear=true},
    flurry         ={target_scope='self_or_ally', landing_intent='none', potency_intent='tier_defined',          duration_intent='primary',   skill_dependence='none',             composure_other_gear=true},
    refresh        ={target_scope='self_or_ally', landing_intent='none', potency_intent='refresh_potency_gear',  duration_intent='primary',   skill_dependence='none',             composure_other_gear=true},
    regen          ={target_scope='self_or_ally', landing_intent='none', potency_intent='spell_specific',        duration_intent='primary',   skill_dependence='low',              composure_other_gear=true},
    protect        ={target_scope='self_or_ally', landing_intent='none', potency_intent='tier_defined',          duration_intent='primary',   skill_dependence='none',             composure_other_gear=true},
    shell          ={target_scope='self_or_ally', landing_intent='none', potency_intent='tier_defined',          duration_intent='primary',   skill_dependence='none',             composure_other_gear=true},
    aquaveil       ={target_scope='self',         landing_intent='none', potency_intent='spell_specific',        duration_intent='primary',   skill_dependence='spell_formula',    composure_other_gear=false},
    stoneskin      ={target_scope='self',         landing_intent='none', potency_intent='spell_specific',        duration_intent='primary',   skill_dependence='spell_formula',    composure_other_gear=false},
    blink          ={target_scope='self',         landing_intent='none', potency_intent='fixed_effect',          duration_intent='primary',   skill_dependence='none',             composure_other_gear=false},
    phalanx        ={target_scope='self',         landing_intent='none', potency_intent='skill_to_breakpoint',   duration_intent='primary',   skill_dependence='enhancing_skill', composure_other_gear=true},
    temper         ={target_scope='self',         landing_intent='none', potency_intent='skill_governed',        duration_intent='secondary', skill_dependence='enhancing_skill', composure_other_gear=false},
    enspell        ={target_scope='self',         landing_intent='none', potency_intent='skill_governed',        duration_intent='secondary', skill_dependence='enhancing_skill', composure_other_gear=false},

    -- Enfeebling families. These describe what the policy tries to preserve when
    -- choosing among Accuracy/Potency/Duration objectives; they do not change routes.
    control        ={target_scope='hostile_single', landing_intent='high',   potency_intent='binary_effect',       duration_intent='secondary', skill_dependence='enfeebling_skill', stymie_accuracy_relief=true, saboteur_gear=true},
    dispel         ={target_scope='hostile_single', landing_intent='high',   potency_intent='binary_effect',       duration_intent='none',      skill_dependence='enfeebling_skill', stymie_accuracy_relief=true, saboteur_gear=true},
    evasion_down   ={target_scope='hostile_single', landing_intent='high',   potency_intent='skill_or_tier',       duration_intent='primary',   skill_dependence='enfeebling_skill', stymie_accuracy_relief=true, saboteur_gear=true},
    mevasion_down  ={target_scope='hostile_single', landing_intent='high',   potency_intent='skill_or_tier',       duration_intent='primary',   skill_dependence='enfeebling_skill', stymie_accuracy_relief=true, saboteur_gear=true},
    gravity        ={target_scope='hostile_single', landing_intent='high',   potency_intent='effect_strength',      duration_intent='secondary', skill_dependence='enfeebling_skill', stymie_accuracy_relief=true, saboteur_gear=true},
    silence        ={target_scope='hostile_single', landing_intent='high',   potency_intent='binary_effect',        duration_intent='primary',   skill_dependence='enfeebling_skill', stymie_accuracy_relief=true, saboteur_gear=true},
    poison         ={target_scope='hostile_single', landing_intent='normal', potency_intent='skill_governed',       duration_intent='primary',   skill_dependence='enfeebling_skill', stymie_accuracy_relief=true, saboteur_gear=true},
    dia            ={target_scope='hostile_single', landing_intent='normal', potency_intent='effect_strength',      duration_intent='primary',   skill_dependence='low',              stymie_accuracy_relief=true, saboteur_gear=true},
    blind          ={target_scope='hostile_single', landing_intent='normal', potency_intent='effect_strength',      duration_intent='primary',   skill_dependence='enfeebling_skill', stymie_accuracy_relief=true, saboteur_gear=true},
    sleep          ={target_scope='hostile_single', landing_intent='maximum',potency_intent='binary_effect',        duration_intent='secondary', skill_dependence='enfeebling_skill', stymie_accuracy_relief=true, saboteur_gear=true},
    slow           ={target_scope='hostile_single', landing_intent='normal', potency_intent='effect_strength',      duration_intent='primary',   skill_dependence='enfeebling_skill', stymie_accuracy_relief=true, saboteur_gear=true},
    paralyze       ={target_scope='hostile_single', landing_intent='normal', potency_intent='effect_strength',      duration_intent='primary',   skill_dependence='enfeebling_skill', stymie_accuracy_relief=true, saboteur_gear=true},
    addle          ={target_scope='hostile_single', landing_intent='normal', potency_intent='effect_strength',      duration_intent='primary',   skill_dependence='enfeebling_skill', stymie_accuracy_relief=true, saboteur_gear=true},
}

-- Spell metadata describes routing-specific overrides and aliases. Phase B2
-- merges these entries with RDM_SPELL_FAMILY_POLICY during setup so every
-- compiled spell has explicit intent dimensions without per-cast inheritance work.
RDM_SPELL_POLICY = {
    -- Enhancing: direct map aliases and Auto-mode governing mechanic.
    ['Haste']       ={school='Enhancing Magic', family='haste', enhancing_auto='duration'},
    ['Haste II']    ={school='Enhancing Magic', family='haste', enhancing_auto='duration'},
    ['Flurry']      ={school='Enhancing Magic', family='flurry', enhancing_auto='duration'},
    ['Flurry II']   ={school='Enhancing Magic', family='flurry', enhancing_auto='duration'},
    ['Refresh']     ={school='Enhancing Magic', family='refresh', direct_map='Refresh', enhancing_auto='duration'},
    ['Refresh II']  ={school='Enhancing Magic', family='refresh', direct_map='Refresh', enhancing_auto='duration'},
    ['Refresh III'] ={school='Enhancing Magic', family='refresh', direct_map='Refresh', enhancing_auto='duration'},
    ['Regen']       ={school='Enhancing Magic', family='regen', direct_map='Regen', enhancing_auto='duration'},
    ['Regen II']    ={school='Enhancing Magic', family='regen', direct_map='Regen', enhancing_auto='duration'},
    ['Regen III']   ={school='Enhancing Magic', family='regen', direct_map='Regen'},
    ['Regen IV']    ={school='Enhancing Magic', family='regen', direct_map='Regen'},
    ['Regen V']     ={school='Enhancing Magic', family='regen', direct_map='Regen'},
    ['Protect']     ={school='Enhancing Magic', family='protect', enhancing_auto='duration'},
    ['Protect II']  ={school='Enhancing Magic', family='protect', enhancing_auto='duration'},
    ['Protect III'] ={school='Enhancing Magic', family='protect', enhancing_auto='duration'},
    ['Protect IV']  ={school='Enhancing Magic', family='protect', enhancing_auto='duration'},
    ['Protect V']   ={school='Enhancing Magic', family='protect', enhancing_auto='duration'},
    ['Shell']       ={school='Enhancing Magic', family='shell', enhancing_auto='duration'},
    ['Shell II']    ={school='Enhancing Magic', family='shell', enhancing_auto='duration'},
    ['Shell III']   ={school='Enhancing Magic', family='shell', enhancing_auto='duration'},
    ['Shell IV']    ={school='Enhancing Magic', family='shell', enhancing_auto='duration'},
    ['Shell V']     ={school='Enhancing Magic', family='shell', enhancing_auto='duration'},
    ['Aquaveil']    ={school='Enhancing Magic', family='aquaveil', enhancing_auto='duration', overlay='Aquaveil'},
    ['Stoneskin']   ={school='Enhancing Magic', family='stoneskin', enhancing_auto='duration'},
    ['Blink']       ={school='Enhancing Magic', family='blink', enhancing_auto='duration'},
    ['Phalanx II']  ={school='Enhancing Magic', family='phalanx', target_scope='ally', enhancing_auto='duration'},
    ['Temper']      ={school='Enhancing Magic', family='temper', enhancing_auto='skill', legacy_skill=true},
    ['Temper II']   ={school='Enhancing Magic', family='temper', enhancing_auto='skill', legacy_skill=true},
    ['Phalanx']     ={school='Enhancing Magic', family='phalanx', enhancing_auto='skill', overlay='Phalanx', breakpoint='phalanx_enhancing_skill'},
    ['Enfire']      ={school='Enhancing Magic', family='enspell', enhancing_auto='skill', legacy_skill=true},
    ['Enfire II']   ={school='Enhancing Magic', family='enspell', enhancing_auto='skill', legacy_skill=true},
    ['Enblizzard']  ={school='Enhancing Magic', family='enspell', enhancing_auto='skill', legacy_skill=true},
    ['Enblizzard II']={school='Enhancing Magic', family='enspell', enhancing_auto='skill', legacy_skill=true},
    ['Enaero']      ={school='Enhancing Magic', family='enspell', enhancing_auto='skill', legacy_skill=true},
    ['Enaero II']   ={school='Enhancing Magic', family='enspell', enhancing_auto='skill', legacy_skill=true},
    ['Enstone']     ={school='Enhancing Magic', family='enspell', enhancing_auto='skill', legacy_skill=true},
    ['Enstone II']  ={school='Enhancing Magic', family='enspell', enhancing_auto='skill', legacy_skill=true},
    ['Enthunder']   ={school='Enhancing Magic', family='enspell', enhancing_auto='skill', legacy_skill=true},
    ['Enthunder II']={school='Enhancing Magic', family='enspell', enhancing_auto='skill', legacy_skill=true},
    ['Enwater']     ={school='Enhancing Magic', family='enspell', enhancing_auto='skill', legacy_skill=true},
    ['Enwater II']  ={school='Enhancing Magic', family='enspell', enhancing_auto='skill', legacy_skill=true},

    -- Enfeebling: route is the existing Auto-mode family; duration/composure
    -- flags independently describe long-duration policy overlays.
    ['Bind']        ={school='Enfeebling Magic', family='control', enfeeble_route='accuracy'},
    ['Break']       ={school='Enfeebling Magic', family='control', enfeeble_route='accuracy'},
    ['Dispel']      ={school='Enfeebling Magic', family='dispel', enfeeble_route='accuracy'},
    ['Distract']    ={school='Enfeebling Magic', family='evasion_down', enfeeble_route='accuracy'},
    ['Distract II'] ={school='Enfeebling Magic', family='evasion_down', enfeeble_route='accuracy'},
    ['Frazzle']     ={school='Enfeebling Magic', family='mevasion_down', enfeeble_route='accuracy'},
    ['Frazzle II']  ={school='Enfeebling Magic', family='mevasion_down', enfeeble_route='accuracy'},
    ['Gravity']     ={school='Enfeebling Magic', family='gravity', enfeeble_route='accuracy'},
    ['Gravity II']  ={school='Enfeebling Magic', family='gravity', enfeeble_route='accuracy'},
    ['Silence']     ={school='Enfeebling Magic', family='silence', enfeeble_route='accuracy'},

    ['Distract III']={school='Enfeebling Magic', family='evasion_down', enfeeble_route='skill', duration_mode=true, composure_duration=true, saboteur_hint=true},
    ['Frazzle III'] ={school='Enfeebling Magic', family='mevasion_down', enfeeble_route='skill', duration_mode=true, composure_duration=true, saboteur_hint=true},
    ['Poison II']   ={school='Enfeebling Magic', family='poison', enfeeble_route='skill', duration_mode=true, composure_duration=true},

    ['Dia']         ={school='Enfeebling Magic', family='dia', enfeeble_route='effect', duration_mode=true, composure_duration=true},
    ['Dia II']      ={school='Enfeebling Magic', family='dia', enfeeble_route='effect', duration_mode=true, composure_duration=true},
    ['Dia III']     ={school='Enfeebling Magic', family='dia', enfeeble_route='effect', duration_mode=true, composure_duration=true},
    ['Diaga']       ={school='Enfeebling Magic', family='dia', target_scope='hostile_area', enfeeble_route='effect', duration_mode=true, composure_duration=true},
    ['Blind']       ={school='Enfeebling Magic', family='blind', enfeeble_route='effect', duration_mode=true, composure_duration=true},
    ['Blind II']    ={school='Enfeebling Magic', family='blind', enfeeble_route='effect', duration_mode=true, composure_duration=true},

    ['Sleep']       ={school='Enfeebling Magic', family='sleep', enfeeble_route='sleep'},
    ['Sleep II']    ={school='Enfeebling Magic', family='sleep', enfeeble_route='sleep'},
    ['Sleepga']     ={school='Enfeebling Magic', family='sleep', target_scope='hostile_area', enfeeble_route='sleep'},

    ['Slow']        ={school='Enfeebling Magic', family='slow', enfeeble_route='effect', duration_mode=true, composure_duration=true},
    ['Slow II']     ={school='Enfeebling Magic', family='slow', enfeeble_route='effect', duration_mode=true, composure_duration=true},
    ['Paralyze']    ={school='Enfeebling Magic', family='paralyze', enfeeble_route='effect', duration_mode=true, composure_duration=true},
    ['Paralyze II'] ={school='Enfeebling Magic', family='paralyze', enfeeble_route='effect', duration_mode=true, composure_duration=true},
    ['Addle']       ={school='Enfeebling Magic', family='addle', enfeeble_route='effect', duration_mode=true, composure_duration=true},
    ['Addle II']    ={school='Enfeebling Magic', family='addle', enfeeble_route='effect', duration_mode=true, composure_duration=true},
}

RDM_WEAPONSKILL_POLICY = {
    ['Savage Blade']     ={family='physical_wsd', set='Savage Blade', accuracy_variant=true, gain_hint='Gain-STR'},
    ['Death Blossom']    ={family='physical_wsd', set='Death Blossom', accuracy_variant=true},
    ['Chant du Cygne']   ={family='critical_physical', set='Chant du Cygne', accuracy_variant=true, gain_hint='Gain-DEX'},
    ['Vorpal Blade']     ={family='critical_physical', set='Vorpal Blade', accuracy_variant=true},
    ['Requiescat']       ={family='physical_multi', set='Requiescat', accuracy_variant=true},
    ['Sanguine Blade']   ={family='magical', set='Sanguine Blade', proximity_waist=true, crocea_path_c_synergy=true},
    ['Seraph Blade']     ={family='magical', set='Seraph Blade', proximity_waist=true, crocea_path_c_synergy=true},
    ['Aeolian Edge']     ={family='magical', set='Aeolian Edge', proximity_waist=true, crocea_path_c_synergy=true},
    ['Black Halo']       ={family='physical_wsd', set='Black Halo', accuracy_variant=true, gain_hint='Gain-MND'},
    ['Evisceration']     ={family='critical_physical', set='Evisceration', accuracy_variant=true, gain_hint='Gain-DEX'},
    ['Empyreal Arrow']   ={family='ranged_physical_wsd', set='Empyreal Arrow', accuracy_variant=true, gain_hint='Gain-AGI'},
}

RDM_WEAPON_POLICY = {
    ['Naegling']    ={primary_ws='Savage Blade', gain_spell='Gain-STR'},
    ['Crocea Mors'] ={primary_ws='Chant du Cygne', gain_spell='Gain-DEX', augment_path='C', enspell_mainhand_synergy=true, elemental_ws_mainhand_synergy=true},
    ['Tauret']      ={primary_ws='Evisceration', gain_spell='Gain-DEX'},
    ['Maxentius']   ={primary_ws='Black Halo', gain_spell='Gain-MND'},
    ['Kaja Bow']    ={primary_ws='Empyreal Arrow', gain_spell='Gain-AGI', ranged_weapon=true},
}

-- Account-specific augment policy. The 2026-07-30 export proves the selected
-- augment PATHS but does not expose reinforcement rank, so rank-scaled bonuses
-- are never assumed to be at their R25 maxima. `max_rank` values document the
-- ceiling for offline reasoning only; live source-set choices may rely on the
-- existence/direction of a path effect, not an unverified numeric rank.
RDM_AUGMENT_POLICY = {
    ['Dls. Torque +2'] = {
        path='A', rank='unknown', scoring='qualitative_until_rank_known',
        effects={
            int_mnd={max_rank=15},
            enhancing_duration={max_rank=25, unit='percent'},
            enfeebling_duration={max_rank=25, unit='percent'},
        },
    },
    ['Crocea Mors'] = {
        path='C', rank='unknown', scoring='qualitative_until_rank_known', main_hand_only=true,
        effects={
            sword_enhancing_spell_damage={max_rank=500, unit='percent'},
            elemental_weaponskill_damage={max_rank=100, unit='percent'},
            damage={max_rank=7},
        },
    },
}

-- Source-set objectives are declarative review policy, not a runtime solver.
-- v2.32 keeps Phase A gear policy and Phase B2 compiled intent, then adds only deterministic community-harvest behavior. Unknown augment ranks remain deliberately undefined until finalized.
RDM_GEAR_POLICY = {
    engaged = {
        Normal  ={objective='tp_efficiency', invariants={'gear_haste_cap'}},
        MidAcc  ={objective='meaningful_accuracy_step', preserve={'tp_efficiency_where_possible'}},
        HighAcc ={objective='explicit_accuracy_max_with_dt_cap_compatibility'},
        Hybrid  ={objective='dt_cap_with_minimum_offense_loss', cap='damage_taken'},
    },
    weaponskills = {
        ['Savage Blade']   ={objective='first_hit_wsd_str_mnd'},
        ['Chant du Cygne'] ={objective='dex_critical_physical'},
        ['Vorpal Blade']   ={objective='critical_physical_legacy_safe', separate_from='Chant du Cygne'},
        ['Requiescat']     ={objective='mnd_multi_hit_accuracy'},
        ['Evisceration']    ={objective='dex_critical_multi_hit', separate_from='generic_ws'},
        ['Empyreal Arrow']  ={objective='single_hit_agi_str_wsd_with_ranged_accuracy'},
        magical            ={objective='mab_magic_damage_stat_mod'},
    },
    magic = {
        elemental_high={objective='nonburst_int_mab_damage_then_accuracy'},
        elemental_low ={objective='flat_magic_damage_for_tier_one_two'},
        spell_accuracy={objective='meaningful_magic_accuracy_step_without_replacing_every_damage_slot'},
        burst     ={objective='mb1_cap_without_relying_on_unlocked_main'},
    },
    enfeebling = {
        normal     ={objective='land_then_effect'},
        accuracy   ={objective='landing_margin'},
        potency    ={objective='effect_or_skill_governed_potency'},
        duration   ={objective='viti_head_plus_four_piece_lethargy_under_composure'},
    },
    enhancing = {
        skill      ={objective='skill_governed_potency'},
        duration   ={objective='enhancing_duration_including_account_specific_path_augments'},
        refresh    ={objective='refresh_potency_then_duration'},
        enspell_cast={objective='skill_and_duration_at_cast_time'},
        enspell_melee={objective='sword_enhancement_damage_and_attack_frequency', crocea_path_c_mainhand=true, dls_torque_duration_not_melee_damage=true},
    },
    healing = {
        cure       ={objective='cure_potency_cap_plus_kaykaus_cure_potency_ii'},
        cursna     ={objective='cursna_bonus_plus_healing_skill'},
    },
    idle = {
        Normal ={objective='refresh_and_utility'},
        DT     ={objective='dt_cap_then_refresh', cap='damage_taken'},
    },
    defense = {
        MEVA={objective='bunzipieces_magic_evasion_with_dt_cap', automatic=false},
    },
    data_rules = {
        player_stat_scope_only = true,
        pet_prefixed_stats = 'excluded_from_player_scoring',
        unknown_augments = 'never_invent',
    },
}

-- Role names remain schema-only in v2.32. No automatic role switching or hidden
-- behavior is enabled yet; Phase C will consume these deliberately.
RDM_ROLE_SCHEMA = {
    active = false,
    planned = {'Solo', 'Melee', 'Support', 'Caster', 'Defensive'},
    dimensions = {'offense', 'survivability', 'buff_maintenance', 'enfeebling', 'bursting'},
}

-- Phase B2: family+spell intent metadata is compiled once during job_setup into
-- a compact exact-name runtime index. Hot casting hooks consume only this flat
-- index or prebuilt compatibility sets; inheritance and explanation stay cold.
RDM_SPELL_INTELLIGENCE = {
    schema_version = '2.1',
    phase = 'B2',
    active = true,
    compile = 'job_setup_once',
    hot_lookup = 'exact_name_O1',
    dimensions = {
        'school', 'family', 'target_scope', 'landing_intent', 'potency_intent',
        'duration_intent', 'skill_dependence', 'job_ability_interaction',
        'spell_specific_overlay',
    },
    invariants = {
        no_policy_scan_per_cast = true,
        no_dynamic_route_strings = true,
        manual_modes_override_auto = true,
        unknown_spells_preserve_legacy_fallback = true,
        family_inheritance_compile_time_only = true,
        diagnostics_are_cold_path_only = true,
    },
}

-- Stable table identity lets RDM_PROFILE reference this before job_setup fills it.
RDM_SPELL_RUNTIME = {}

-- @ai:fn build_spell_policy_groups | layer=utility | hot=no | purity=pure | contract=Derive legacy spell-classification lists from RDM_SPELL_POLICY without touching runtime state.
local function build_spell_policy_groups()
    local g = {
        enfeebling_acc={}, enfeebling_skill={}, enfeebling_effect={}, enfeebling_sleep={},
        lethargy_duration={}, legacy_skill={}, enhancing_duration={}, enhancing_skill={},
        enfeebling_duration={}, direct_map={}, saboteur_worthy={},
    }
    for name, p in pairs(RDM_SPELL_POLICY) do
        if p.direct_map then g.direct_map[name] = p.direct_map end
        if p.enhancing_auto == 'duration' then g.enhancing_duration[#g.enhancing_duration+1] = name end
        if p.enhancing_auto == 'skill' then g.enhancing_skill[#g.enhancing_skill+1] = name end
        if p.legacy_skill then g.legacy_skill[#g.legacy_skill+1] = name end
        if p.enfeeble_route == 'accuracy' then g.enfeebling_acc[#g.enfeebling_acc+1] = name end
        if p.enfeeble_route == 'skill' then g.enfeebling_skill[#g.enfeebling_skill+1] = name end
        if p.enfeeble_route == 'effect' then g.enfeebling_effect[#g.enfeebling_effect+1] = name end
        if p.enfeeble_route == 'sleep' then g.enfeebling_sleep[#g.enfeebling_sleep+1] = name end
        if p.duration_mode then g.enfeebling_duration[#g.enfeebling_duration+1] = name end
        if p.composure_duration then g.lethargy_duration[#g.lethargy_duration+1] = name end
        if p.saboteur_hint then g.saboteur_worthy[#g.saboteur_worthy+1] = name end
    end
    return g
end

-- @ai:fn compile_spell_intelligence | layer=utility | hot=no | purity=write | contract=Compile family+spell policy once into flat exact-name runtime entries; inheritance must never occur per cast.
local function compile_spell_intelligence()
    for name in pairs(RDM_SPELL_RUNTIME) do RDM_SPELL_RUNTIME[name] = nil end
    for name, p in pairs(RDM_SPELL_POLICY) do
        local f = RDM_SPELL_FAMILY_POLICY[p.family] or {}
        RDM_SPELL_RUNTIME[name] = {
            school = p.school,
            family = p.family,
            target_scope = p.target_scope or f.target_scope or 'unknown',
            landing_intent = p.landing_intent or f.landing_intent or 'unspecified',
            potency_intent = p.potency_intent or f.potency_intent or 'unspecified',
            duration_intent = p.duration_intent or f.duration_intent or 'unspecified',
            skill_dependence = p.skill_dependence or f.skill_dependence or 'unspecified',
            direct_map = p.direct_map,
            enhancing_auto = p.enhancing_auto,
            enfeeble_route = p.enfeeble_route,
            duration_mode = p.duration_mode == true,
            composure_duration = p.composure_duration == true,
            saboteur_hint = p.saboteur_hint == true,
            overlay = p.overlay,
            breakpoint = p.breakpoint,
            ja_composure_other_gear = p.composure_other_gear == true or f.composure_other_gear == true,
            ja_stymie_accuracy_relief = p.stymie_accuracy_relief == true or f.stymie_accuracy_relief == true,
            ja_saboteur_gear = p.saboteur_gear == true or f.saboteur_gear == true,
        }
    end
    return build_spell_policy_groups()
end

-- @ai:fn resolve_enhancing_route | layer=utility | hot=yes | purity=read | contract=Resolve the permanent spell-aware Enhancing objective from compiled exact-name policy; return nil for legacy NoSkillSpells fallback.
local function resolve_enhancing_route(policy)
    return policy and policy.enhancing_auto or nil
end

-- @ai:fn resolve_enfeebling_spell_map | layer=utility | hot=yes | purity=pure | contract=Resolve one Enfeebling spell-map string from compiled policy plus Auto/Accuracy and Stymie inputs; Sleep is always accuracy-first.
local function resolve_enfeebling_spell_map(policy, spell_type, mode, stymie_active)
    local route = policy and policy.enfeeble_route or nil
    local is_white = spell_type == 'WhiteMagic'

    -- Sleep has one authoritative gear route. This early return deliberately
    -- disconnects SleepMaxDuration from EnfeeblingMode and JA combinations.
    if route == 'sleep' then
        return 'Sleep'
    elseif mode == 'Accuracy' then
        return is_white and 'MndEnfeeblesAcc' or 'IntEnfeeblesAcc'
    end

    if route == 'skill' then
        return 'SkillEnfeebles'
    elseif is_white then
        if route == 'accuracy' and not stymie_active then
            return 'MndEnfeeblesAcc'
        elseif route == 'effect' then
            return 'MndEnfeeblesEffect'
        end
        return 'MndEnfeebles'
    elseif spell_type == 'BlackMagic' then
        if route == 'accuracy' and not stymie_active then
            return 'IntEnfeeblesAcc'
        elseif route == 'effect' then
            return 'IntEnfeeblesEffect'
        end
        return 'IntEnfeebles'
    end
end

-- @ai:fn policy_count | layer=utility | hot=no | purity=pure | contract=Count direct entries in one policy table for diagnostics only.
local function policy_count(t)
    local n = 0
    for _ in pairs(t or {}) do n = n + 1 end
    return n
end

-- @ai:fn policy_find_casefold | layer=utility | hot=no | purity=pure | contract=Case-insensitive exact-name lookup for tiny declarative policy tables; diagnostics only.
local function policy_find_casefold(t, query)
    local q = string.lower(tostring(query or ''))
    if q == '' then return nil, nil end
    for name, policy in pairs(t or {}) do
        if string.lower(name) == q then return name, policy end
    end
    return nil, nil
end

-------------------------------------------------------------------------------------------------------------------
-- Setup functions for this job.  Generally should not be modified.
-------------------------------------------------------------------------------------------------------------------

--              Addendum Commands:
--              Shorthand versions for each strategem type that uses the version appropriate for
--              the current Arts.
--                                          Light Arts                  Dark Arts
--                                          ----------                  ---------
--              gs c scholar light          Light Arts/Addendum
--              gs c scholar dark                                       Dark Arts/Addendum
--              gs c scholar cost           Penury                      Parsimony
--              gs c scholar speed          Celerity                    Alacrity
--              gs c scholar aoe            Accession                   Manifestation
--              gs c scholar addendum       Addendum: White             Addendum: Black


-------------------------------------------------------------------------------------------------------------------
-- Setup functions for this job.  Generally should not be modified.
-------------------------------------------------------------------------------------------------------------------

-- Initialization function for this job file.
-- @ai:fn get_sets | layer=framework | hot=no | purity=write | contract=Load ItemStats.lua before Mote-Include.lua; order is mandatory.
function get_sets()
    mote_include_version = 2

    -- Wardrobe fact sheet (fc/dw/haste per owned item). Sidecar file in the
    -- same folder as this lua; shared by all job luas so a new acquisition is
    -- a one-line edit there. Defines: item_stats table, item_stat(name,field).
    -- MUST load BEFORE Mote-Include: Mote's init chain calls job_setup(),
    -- user_setup(), and init_gear_sets() during its own include, and those
    -- consume item_stat().
    include('ItemStats.lua')

    -- Load and initialize the include file.
    include('Mote-Include.lua')
end


-------------------------------------------------------------------------------
-- Optional runtime instrumentation (Act 1)
--
-- Disabled by default: when off, each probe is a single boolean check and no
-- clocks, strings, or report tables are created. Commands:
--   gs c perf on      reset and enable counters/timers
--   gs c perf         print the current snapshot
--   gs c perf reset   clear the current snapshot
--   gs c perf off     print, then disable
-------------------------------------------------------------------------------
local perf = {
    enabled = false,
    started = 0,
    counters = {},
    timers = {},
}

-- Act 4: direct engaged-set index. Built once after init_gear_sets creates all
-- Normal/MidAcc/HighAcc, single-wield/DW, and Normal/DT variants.
local engaged_set_index = nil


-- @ai:fn perf_reset | layer=utility | hot=no | purity=write | contract=Reset profiler counters/timers without enabling instrumentation.
local function perf_reset()
    perf.started = os.clock()
    perf.counters = {}
    perf.timers = {}
end

-- @ai:fn perf_count | layer=utility | hot=yes | purity=write | contract=Cheap counter increment; must remain near-zero overhead when perf is disabled.
local function perf_count(name, amount)
    if not perf.enabled then return end
    perf.counters[name] = (perf.counters[name] or 0) + (amount or 1)
end

-- @ai:fn perf_begin | layer=utility | hot=yes | purity=read | contract=Return a clock sample only when profiler is enabled.
local function perf_begin()
    if perf.enabled then return os.clock() end
end

-- @ai:fn perf_finish | layer=utility | hot=yes | purity=write | contract=Accumulate elapsed time only for enabled profiler samples.
local function perf_finish(name, started)
    if not started then return end
    local elapsed = os.clock() - started
    local timer = perf.timers[name]
    if timer then
        timer.calls = timer.calls + 1
        timer.total = timer.total + elapsed
        if elapsed > timer.max then timer.max = elapsed end
    else
        perf.timers[name] = {calls=1, total=elapsed, max=elapsed}
    end
end

local perf_counter_order = {
    'action_packets', 'action_skillchain', 'action_burst_scans',
    'hud_calls', 'hud_hidden_skips', 'hud_state_cache_hits', 'hud_renders',
    'idle_resolutions', 'melee_resolutions',
    'fc_rebuilds', 'fc_cache_hits', 'dw_rebuilds', 'dw_cache_hits', 'skillchain_scans',
    'native_dw_active_changes', 'native_dw_haste_changes', 'native_dw_trait_changes',
    'native_dw_need_changes', 'native_dw_plan_changes', 'native_dw_force_refreshes',
    'dw_overlay_invalidations',
    'equipment_snapshot_rebuilds', 'equipment_snapshot_hits',
    'haste_buff_rebuilds', 'haste_buff_cache_hits',
    'engaged_index_hits', 'engaged_index_fallbacks',
    'ring_lock_hits', 'ring_lock_changes',
    'weapon_reassert_hits', 'weapon_reassert_changes',
}
local perf_timer_order = {
    'action', 'hud', 'idle_resolution', 'melee_resolution',
    'fc_rebuild', 'dw_rebuild', 'skillchain_scan',
}

-- @ai:fn perf_report | layer=utility | hot=no | purity=write | contract=Render profiler snapshot to chat; diagnostic-only.
local function perf_report()
    local elapsed = perf.started > 0 and math.max(0, os.clock() - perf.started) or 0
    add_to_chat(158, string.format('=== RDM perf: %s, %.1fs sample ===',
        perf.enabled and 'ON' or 'OFF', elapsed))
    local counter_parts = {}
    for _, name in ipairs(perf_counter_order) do
        local value = perf.counters[name]
        if value then counter_parts[#counter_parts + 1] = name..'='..value end
    end
    add_to_chat(158, (#counter_parts > 0) and table.concat(counter_parts, ' | ')
        or 'Counters: no samples yet')
    for _, name in ipairs(perf_timer_order) do
        local timer = perf.timers[name]
        if timer and timer.calls > 0 then
            add_to_chat(158, string.format('%-17s %5d calls  total %.3fms  avg %.3fms  max %.3fms',
                name, timer.calls, timer.total * 1000,
                timer.total * 1000 / timer.calls, timer.max * 1000))
        end
    end
    add_to_chat(158, 'Usage: gs c perf on|off|reset')
end


-- Setup vars that are user-independent.  state.Buff vars initialized here will automatically be tracked.
-- @ai:fn job_setup | layer=framework | hot=no | purity=write | contract=Create job-global state/policy tables before gear sets are initialized.
function job_setup()

    -- Fill dw_pool/dw_cape_constant from ItemStats.lua (loaded in get_sets
    -- just before Mote-Include invoked this).
    resolve_dw_pool()

    -- state.CP = M(false, "Capacity Points Mode")
    state.Buff.Composure = buffactive.Composure or false
    state.Buff.Saboteur = buffactive.Saboteur or false
    state.Buff.Stymie = buffactive.Stymie or false

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

    -- Every equippable slot GearSwap manages. PauseSwaps owns this full list.
    all_equip_slots = {'main','sub','range','ammo','head','neck','ear1','ear2',
                        'body','hands','ring1','ring2','back','waist','legs','feet'}

    -- Fishing owns every slot except the two rings. Keeping ring1/ring2 live
    -- lets native movement use Shneddick and lets the normal protected-ring
    -- policy hold a manually equipped Warp/Dimensional ring. Pause still wins
    -- over this partial lock and freezes all sixteen slots when both are on.
    fishing_lock_slots = {'main','sub','range','ammo','head','neck','ear1','ear2',
                          'body','hands','back','waist','legs','feet'}

    -- Buffs that mean a boost ring's effect is now active (so the ring can come off).
    -- Dedication = EXP/Limit boost (Empress/anniversary rings); Commitment = Capacity Pts.
    boost_buffs = S{'dedication', 'commitment'}

    -- Slots momentarily being released (so check_gear lets the normal ring return)
    releasing = {ring1=false, ring2=false}

    -- Cache the lock state GearSwap has already applied to protected ring slots.
    -- check_gear() runs on precast, idle, and melee resolution, but the desired
    -- lock normally remains unchanged for long stretches.
    ring_lock_state = {ring1=nil, ring2=nil}

    -- Phase B2: compile family+spell intent once into flat exact-name entries, while retaining legacy
    -- S{} mirrors for compatibility with sidecars/older helper paths. Hot spell
    -- routing now consumes RDM_SPELL_RUNTIME directly instead of classification scans.
    local spell_groups = compile_spell_intelligence()
    enfeebling_magic_acc = S(spell_groups.enfeebling_acc)
    enfeebling_magic_skill = S(spell_groups.enfeebling_skill)
    enfeebling_magic_effect = S(spell_groups.enfeebling_effect)
    enfeebling_magic_sleep = S(spell_groups.enfeebling_sleep)
    lethargy_duration_enfeebles = S(spell_groups.lethargy_duration)
    skill_spells = S(spell_groups.legacy_skill)
    enhancing_direct_spell_map = spell_groups.direct_map
    enhancing_duration_spells = S(spell_groups.enhancing_duration)
    enhancing_skill_spells = S(spell_groups.enhancing_skill)
    enfeebling_duration_spells = S(spell_groups.enfeebling_duration)
    saboteur_worthy = S(spell_groups.saboteur_worthy)

    -- REMOVED (2026-07): Mote-TreasureHunter. Two reasons:
    --   1. It never worked here: non-THF jobs only get 'None'/'Tag' options,
    --      so the old customize_melee_set 'Fulltime' branch was unreachable,
    --      and 'Tag' only equips TH while ENGAGED -- tagging with Dia from
    --      range never wore TH gear at all.
    --   2. Performance: the plugin registers FIVE windower events including
    --      raw 'action' (fires for every action by anyone in range, walking
    --      a mob table each time) and raw 'incoming chunk' (every packet).
    --      That's the per-event dispatch class the SMN stutter hunt purged.
    -- Replacement: state.TreasureHunter OFF/ON toggle (Alt+F1). ON layers
    -- sets.TreasureHunter (TH+3) into engaged sets and hostile-spell
    -- midcasts -- simple, no mob tracking, ZERO event handlers.

    lockstyleset = 24
end


-------------------------------------------------------------------------------------------------------------------
-- User setup functions for this job.  Recommend that these be overridden in a sidecar file.
-------------------------------------------------------------------------------------------------------------------

-- Setup vars that are user-dependent.  Can override this function in a sidecar file.
-- @ai:fn user_setup | layer=framework | hot=no | purity=write | contract=Define user modes/keybinds/default runtime state; reset unload guard here.
function user_setup()
    RDM_RUNTIME.unloading = false
    applying_weapon_pair = false
    applying_playstyle = false
    weapon_cycle_generation = 0
    playstyle_generation = 0
    state.OffenseMode:options('Normal', 'MidAcc', 'HighAcc')
    state.HybridMode:options('Normal', 'DT')
    state.CastingMode:options('Normal', 'SIRD', 'SpellACC')
    state.IdleMode:options('Normal', 'DT')
    -- Mote always creates a manual Kiting mode and applies sets.Kiting when it
    -- is true. That controller is retired: native position tracking owns
    -- state.Auto_Kite and applies the same movement set in the custom resolvers.
    -- Keep Mote's compatibility state false and neutralize its manual overlay.
    if state.Kiting and type(state.Kiting.set) == 'function' then
        state.Kiting:set(false)
    end
    apply_kiting = function(baseSet) return baseSet end
    if state.PhysicalDefenseMode then
        state.PhysicalDefenseMode:options('PDT')
        state.PhysicalDefenseMode:set('PDT')
    end
    if state.MagicalDefenseMode then
        -- Internal-only Mote routing: Magical now always means the MEVA set.
        state.MagicalDefenseMode:options('MEVA')
        state.MagicalDefenseMode:set('MEVA')
    end

    state.EnSpell = M{['description']='EnSpell', 'Enfire', 'Enblizzard', 'Enaero', 'Enstone', 'Enthunder', 'Enwater'}
    state.BarElement = M{['description']='BarElement', 'Barfire', 'Barblizzard', 'Baraero', 'Barstone', 'Barthunder', 'Barwater'}
    state.BarStatus = M{['description']='BarStatus', 'Baramnesia', 'Barvirus', 'Barparalyze', 'Barsilence', 'Barpetrify', 'Barpoison', 'Barblind', 'Barsleep'}
    state.GainSpell = M{['description']='GainSpell', 'Auto', 'Gain-STR', 'Gain-INT', 'Gain-AGI', 'Gain-VIT', 'Gain-DEX', 'Gain-MND', 'Gain-CHR'}

    state.WeaponSet = M{['description']='Weapon Set',
        'CroceaMors', 'CroceaTPBonus',
        'Naegling', 'NaeglingTPBonus',
        'Maxentius', 'MaxentiusTPBonus',
        'Tauret', 'KajaBow', 'Idle'}
    state.WeaponLock = M(true, 'Weapon Lock')
    state.TreasureHunter = M(false, 'Treasure Hunter')
    state.RangedLock = M(true, 'Ranged Lock')
    state.EnfeeblingMode = M{['description']='Enfeebling Mode', 'Auto', 'Accuracy'}
    state.EnspellMode = M{['description']='Enspell Melee Mode', 'Auto', 'Max', 'Off'}
    -- Custom is the honest load state because the Lua does not force equipment
    -- during Mote initialization. Named bundles remain available through
    -- 'gs c rdmplay'; the typed 'gs c rdmreset' command restores the default.
    state.Playstyle = M{['description']='Playstyle Lock',
        'Custom', 'Balanced', 'MaxTP', 'Enspell', 'DT', 'MEVA', 'HardTarget', 'Caster'}
    state.PauseSwaps = M(false, 'Pause Gear Swapping (Fish/Craft)')
    state.FishingMode = M(false, 'Fishing Mode')      -- Alt+F2: fishing gear + ring-aware freeze
    -- state.CP = M(false, "Capacity Points Mode")

    -- Assumed FC% of an active Caster's Roll (value isn't readable from the
    -- buff icon). Use 'gs c cycle CasterRollFC' to match the roll called in chat.
    -- Default 10 is deliberately low = safe (see update_fc_tier).
    state.CasterRollFC = M{['description']='Caster Roll FC Assumption', '10', '15', '20', '25', '30', '5'}

    -- Mote binds its generic mode row before user_setup. Clear the entire
    -- plain/Shift/Ctrl/Alt/Win F9-F12 block, then rebuild only the intentional
    -- weapon row, manual F10 magic burst, manual F11 skillchain closer,
    -- weapon-aware F12 WS, Ctrl+F12 Silmaril toggle, Alt+F9 HUD position lock,
    -- and Alt+F10 HUD visibility.
    -- Displaced controllers remain available through typed commands and are
    -- recorded in the companion backlog.
    -- Scholar stratagem commands remain available as typed/macro commands:
    --   gs c scholar light|dark|speed|cost|aoe|addendum

    clear_f9_f12_bindings()
    clear_legacy_target_bindings()
    send_command('bind f10 gs c magicburst')
    send_command('bind f11 gs c skillchain')
    send_command('bind f12 gs c bestws')
    send_command('bind ^f9 gs c rdmweapon previous')
    send_command('bind ^f10 gs c rdmweapon next')
    send_command('bind ^f11 gs c toggle WeaponLock')
    send_command('bind ^f12 sm all toggle')
    send_command('bind !f9 gs c hudlock')
    send_command('bind !f10 gs c hud')
    -- Full-keyboard combat row. Ctrl+F1/F2 use the shared engaged-set engine;
    -- Ctrl+F3 translates the player-facing Normal/DT/MEVA cycle into Mote's
    -- legacy defense fields; Ctrl+F4 owns casting, Ctrl+F5 owns Enfeebling,
    -- Ctrl+F6 owns the Enspell melee policy, and Ctrl+F7 owns Idle Gear.
    -- The clean sweep above also retires hidden Mote defaults such as the
    -- generic Alt+F9 ranged selector, Alt+F10 Kiting, and Ctrl+F12 IdleMode.
    -- Ctrl+F9-F12 plus the Alt+F9/F10 HUD controls are rebound only after that
    -- sweep, so none of the stock meanings survive.
    send_command('unbind @v')
    send_command('bind ^f1 gs c cycle OffenseMode')
    send_command('bind ^f2 gs c cycle HybridMode')
    send_command('bind ^f3 gs c rdmdefense next')
    send_command('bind ^f4 gs c cycle CastingMode')
    send_command('bind ^f5 gs c cycle EnfeeblingMode')
    send_command('bind ^f6 gs c cycle EnspellMode')
    send_command('bind ^f7 gs c cycle IdleMode')
    -- Sparse utility row. Keep the states fully manual and clear the retired
    -- Win+letter bindings so a reload over v2.49 cannot leave stale controls.
    send_command('unbind @t')
    send_command('unbind @f')
    send_command('unbind @p')
    send_command('bind !f1 gs c toggle TreasureHunter')
    send_command('bind !f2 gs c toggle FishingMode')
    send_command('bind !f3 gs c toggle PauseSwaps')
    send_command('unbind @b')                        -- retired v2.48: forced MB gear
    send_command('unbind @s')                        -- retired v2.48: Sleep gear selector
    send_command('unbind @m')                        -- retired v2.49: moved to Ctrl+F6
    send_command('unbind @d')                        -- retired v2.54: fixed conservative Saboteur timer math
    send_command('unbind @w')                       -- retired v2.52: moved to Ctrl+F11
    send_command('unbind @c')                       -- retired v2.53: manual closer is plain F11
    send_command('unbind @e')                       -- retired v2.52: moved to Ctrl+F9
    send_command('unbind @r')                       -- retired v2.52: moved to Ctrl+F10
    send_command('unbind @a')                        -- v2.24: runtime Gear Audit removed; clear any stale prior binding
    -- CasterRollFC has no key (never used as one): 'gs c cycle CasterRollFC'
    send_command('unbind @h')                         -- retired v2.60: HUD visibility moved to Alt+F10
    send_command('unbind ^@h')                        -- retired v2.57: HUD lock moved to Alt+F9
    send_command('unbind @g')                        -- retired v2.48: AutoMB is permanently active
    send_command('unbind @n')                        -- retired v2.48: Nuke gear selector
    -- Silmaril moved to Ctrl+F12. Explicitly clear Win+Z so a reload over an
    -- older RDM revision cannot leave the Windows shortcut active.
    send_command('unbind @z')

    init_hud()  -- on-screen status box (safe here: needs no gear tables)


    select_default_macro_book()
    set_lockstyle()

    -- Apply weapon lock immediately on load (job_state_change only fires on changes)
    if state.WeaponLock.value == true then
        disable('main','sub','range')
    end

    state.Auto_Kite = M(false, 'Auto_Kite')
    Haste = 0
    DW_needed = 0
    DW = false
    GI_Haste = 0
    GI_DW_needed = 0
    GI_DW = false
    moving = false
    movement_monitor.next_sample = 0
    movement_monitor.last_motion_at = 0
    movement_monitor.x, movement_monitor.y, movement_monitor.z = nil, nil, nil
    movement_monitor.refresh_pending = false
    movement_monitor.refresh_queued = false
    update_combat_form()
    determine_haste_group()

    -- NOTE: the initial update_fc_tier() lives at the END of init_gear_sets,
    -- not here -- Mote's init order is job_setup -> user_setup ->
    -- init_gear_sets, so fc_core/fc_ladder don't exist yet at this point.
end

-- Called when this job file is unloaded (eg: job change)
-- @ai:fn user_unload | layer=lifecycle | hot=no | purity=write | contract=Save HUD preferences, invalidate async work, unregister events, enable all slots, unbind keys, and destroy the HUD primitive.
function user_unload()
    -- Save before setting the unload guard so a position changed immediately
    -- before reload is not lost even if the drag debounce has not fired yet.
    if save_hud_preferences then save_hud_preferences(true) end
    RDM_RUNTIME.unloading = true
    if sc_cancel then sc_cancel('unload') end
    -- sc_clear_burst_window is a later local declaration and therefore is not
    -- lexically visible here. Clear the global window record directly on unload.
    if sc_window then
        sc_window.name, sc_window.target_id = nil, nil
        sc_window.observed_at, sc_window.expires = 0, 0
        sc_window.generation = (sc_window.generation or 0) + 1
    end
    if manual_mb then
        manual_mb.pending = nil
        manual_mb.pending_generation = (manual_mb.pending_generation or 0) + 1
    end
    unregister_rdm_events()

    -- Slot disable state is GearSwap-global enough to poison the next job if we
    -- unload while Pause/Fishing/WeaponLock/Doom/ring protection is active.
    -- Always hand the next job a clean, enabled equipment state.
    if all_equip_slots then enable(unpack(all_equip_slots)) end

    clear_f9_f12_bindings()
    clear_legacy_target_bindings()
    send_command('unbind ^f1')
    send_command('unbind ^f2')
    send_command('unbind ^f3')
    send_command('unbind ^f4')
    send_command('unbind ^f5')
    send_command('unbind ^f6')
    send_command('unbind ^f7')
    send_command('unbind !f1')
    send_command('unbind !f2')
    send_command('unbind !f3')
    send_command('unbind @t')
    send_command('unbind @b')
    send_command('unbind @s')
    send_command('unbind @m')
    send_command('unbind @d')
    send_command('unbind @w')
    send_command('unbind @c')
    send_command('unbind @e')
    send_command('unbind @r')
    send_command('unbind @a')
    send_command('unbind @p')
    send_command('unbind @f')
    send_command('unbind @h')
    send_command('unbind ^@h')
    send_command('unbind @g')
    send_command('unbind @n')
    send_command('unbind @v')
    send_command('unbind @z')
    if hud then
        if type(hud.hide) == 'function' then pcall(hud.hide, hud) end
        if type(hud.destroy) == 'function' then pcall(hud.destroy, hud) end
        hud = nil
    end
end

-- Define sets and vars used by this job file.
-- @ai:fn init_gear_sets | layer=framework | hot=no | purity=write | contract=Canonical gear-definition phase; preserve cape augment registry and set aliases.
function init_gear_sets()

    ------------------------------------------------------------------------
    -- Five Sucellos's Capes, one per niche. GearSwap picks a specific copy
    -- ONLY by exact augment match, so these strings are copied verbatim from
    -- the inventory export (Falurian 2026-07-30) and defined once; every set
    -- references capes.<niche>. ItemStats.lua mirrors them as pseudo-keys.
    -- Niches: fc=precast+MND midcast | dw=engaged w/ gear-DW need |
    -- da=single-wield TP, DW-capped TP, CDC | ws=physical WS | nuke=ele/dark.
    -- NOTE the DA cape carries no DT-5 (4-slot augment roll).
    ------------------------------------------------------------------------
    capes = {
        fc   = { name="Sucellos's Cape", augments={'MND+20','Mag. Acc+20 /Mag. Dmg.+20','MND+10','"Fast Cast"+10','Damage taken-5%',}},
        dw   = { name="Sucellos's Cape", augments={'DEX+20','Accuracy+20 Attack+20','"Dual Wield"+10','Damage taken-5%',}},
        da   = { name="Sucellos's Cape", augments={'DEX+20','Accuracy+20 Attack+20','Accuracy+6','"Dbl.Atk."+10',}},
        ws   = { name="Sucellos's Cape", augments={'STR+20','Accuracy+20 Attack+20','STR+10','Weapon skill damage +10%','Damage taken-5%',}},
        nuke = { name="Sucellos's Cape", augments={'INT+20','Mag. Acc+20 /Mag. Dmg.+20','"Mag.Atk.Bns."+10',}},
    }


    -- Canonical account-specific augmented JSE items. Always reference these
    -- augmented tables in source sets so GearSwap preserves the exported path
    -- identity instead of silently degrading the item to a base-name string.
    local augmented_gear = {
        dls_torque = {name="Dls. Torque +2", augments={'Path: A',}},
        crocea_mors = {name="Crocea Mors", augments={'Path: C',}},
        machaera_tp_bonus = {name="Machaera +2", augments={'TP Bonus +1000',}},
        vanya_hood_b = {name="Vanya Hood", augments={'Healing magic skill +19','"Cure" spellcasting time -7%','Magic dmg. taken -2',}},
    }


    ------------------------------------------------------------------------------------------------
    ---------------------------------------- Precast Sets ------------------------------------------
    ------------------------------------------------------------------------------------------------

    -- Precast sets to enhance JAs
    sets.precast.JA['Chainspell'] = {body="Viti. Tabard +3"}

    -- Convert grants MP equal to CURRENT HP, so precast in max owned HP:
    -- full Nyame + HP ears. (Add Moogle belt/Gelatinous +1 here if acquired.)
    sets.precast.JA['Convert'] = {
        head="Nyame Helm",
        body="Nyame Mail",
        hands="Nyame Gauntlets",
        legs="Nyame Flanchard",
        feet="Nyame Sollerets",
        ear1="Etiolation Earring", --HP+50
        ear2="Alabaster Earring",  --HP
        }

    ----------------------------------------------------------------------------
    -- ADAPTIVE FAST CAST (FC analog of the DW haste tiers, computed locally)
    --
    -- The 80% cast-time cap is a TOTAL: job trait + JP gifts + party buffs
    -- (Caster's Roll) + gear all share the same budget. Gear only has to close
    -- the remaining gap, so as native FC rises the ladder pieces below are shed
    -- for DT / M.Eva fillers.
    --
    --   gear target = 80 - trait(30 @89+) - gifts(+2 per FC gift) - Caster's Roll
    --
    -- Full pool below = 62 gear FC; a mastered RDM only needs 42, so up to
    -- three-to-four slots come back as utility. Everything is rebuilt by
    -- build_fc_sets() whenever the target changes (login, Caster's Roll
    -- gain/loss, typed CasterRollFC assumption change). 'gs c fcinfo' prints the current
    -- math and forces a recompute.
    --
    -- OLD assumptions removed: FC feet/neck purchases are unnecessary (the pool
    -- is already over target at any JP count), and Leth. Chappel +1 for
    -- enfeebles is handled automatically -- it slots in whenever the set still
    -- caps without the FC+14 head, instead of waiting for "61%+ gear FC".
    ----------------------------------------------------------------------------

    -- FC pieces that are never shed (no better precast use for the slot):
    -- ammo/ring2 are Quick Magic, waist is FC+QM proc, and the head is handled
    -- separately (the Enfeebling variant swaps it for Leth. Chappel +1).
    fc_core = {
        ammo="Impatiens",        --Quick Magic 2
        head="Atro. Chapeau +2", --FC 14 (Enfeebling variant may swap this out)
        neck="Null Loop",
        ring2="Lebeche Ring",    --Quick Magic 2
        waist="Witful Belt",     --FC 3 + Quick Magic proc
        }
    -- FC numbers come from ItemStats.lua (single source of truth) -- edit
    -- values THERE, structure/policy here.
    fc_head_value = item_stat("Atro. Chapeau +2", 'fc')       -- what the Enfeebling head swap gives up
    fc_core_value = fc_head_value + item_stat("Witful Belt", 'fc')

    -- Shed ladder: dropped top-to-bottom (smallest FC first) while the set
    -- stays at/above the gear target. Fillers are owned DT/M.Eva pieces.
    -- body/back only ever come off under a strong Caster's Roll.
    -- (fc fields filled from item_stats below; keep entries sorted ascending.)
    fc_ladder = {
        {slot='ear2',  piece="Etiolation Earring", filler="Alabaster Earring"}, --DT/HP
        {slot='ear1',  piece="Loquac. Earring",    filler="Eabani Earring"},    --M.Eva
        {slot='ring1', piece="Kishar Ring",        filler="Murky Ring"},        --DT-10
        {slot='legs',  piece="Aya. Cosciales +2",  filler="Nyame Flanchard"},   --DT/M.Eva
        {slot='hands', piece="Gende. Gages +1",    filler="Nyame Gauntlets"},   --DT/M.Eva
        {slot='back',  stats_key="Sucellos's Cape (FC path)",                   --FC 10 / DT-5
                       piece=capes.fc,
                       filler="Null Shawl"},                                    --M.Eva
        {slot='body',  piece="Viti. Tabard +3",    filler="Nyame Mail"},        --DT/M.Eva (Inyanga Jubbah +2 is WHM/BRD/SMN-only)
        }
    fc_ladder_value = 0
    for _, e in ipairs(fc_ladder) do
        e.fc = item_stat(e.stats_key or e.piece, 'fc')
        fc_ladder_value = fc_ladder_value + e.fc
    end
    -- (= 45 with the current wardrobe; full pool = core 17 + ladder 45 = 62)

    -- Shed ORDER is separate from the ladder so DT/MEVA Defense can re-prioritize:
    --   normal: smallest FC first (max FC retained, meva-leaning fillers)
    --   dt:     Nyame slots first (max DT gained per shed; the FC cape stays
    --           last since it already carries DT-5 and Null Shawl doesn't)
    fc_shed_order        = {'ear2','ear1','ring1','legs','hands','back','body'}
    fc_shed_order_dt     = {'hands','legs','body','ring1','ear2','ear1','back'}
    fc_head_filler       = "Nyame Helm" -- worn if even the head's 14 FC is
                                        -- unneeded (only reachable while
                                        -- Chainspell/Spontaneity zero the target)

    build_fc_sets()  -- constructs sets.precast.FC and every variant for the
                     -- current fc_gear_target (defaults to 50 = zero-JP-safe
                     -- until update_fc_tier() runs at the end of init_gear_sets)


    ------------------------------------------------------------------------------------------------
    ------------------------------------- Weapon Skill Sets ----------------------------------------
    ------------------------------------------------------------------------------------------------

    sets.precast.WS = {
        ammo="Oshasha's Treatise",
        head="Nyame Helm",
        body="Nyame Mail",
        hands="Nyame Gauntlets", --WSD
        legs="Nyame Flanchard",
        feet="Nyame Sollerets",
        neck="Anu Torque",
        ear1="Telos Earring",
        ear2="Moonshade Earring",
        ring1="Epaminondas's Ring", --WSD
        ring2="Sroda Ring",
        back=capes.ws,
        waist="Sailfi Belt +1",
        }

    sets.precast.WS.Acc = set_combine(sets.precast.WS, {
        neck="Null Loop",
        ear2="Mache Earring +1",
        })

    -- Chant du Cygne: dedicated DEX/critical physical policy.  The old set
    -- prioritized TP-cycle/Store TP pieces that do not directly raise the current WS damage and left several owned
    -- critical/DEX options unused. Accuracy mode deliberately restores the
    -- Malignance body/legs/feet and double Chirich rings.
    sets.precast.WS['Chant du Cygne'] = set_combine(sets.precast.WS, {
        ammo="Yetshila +1", --Crit rate +2 / crit damage +6
        head="Malignance Chapeau", --DEX+40 / Acc+50 / PDL+3
        body="Ayanmo Corazza +2", --DEX+48 / DA+7; only 1 DEX below Malignance body
        hands="Malignance Gloves", --DEX+56 / Acc+50 / PDL+4
        legs="Viti. Tights +3", --DEX+22 / Attack+64; Malignance Tights carries no DEX
        feet="Aya. Gambieras +2", --DEX+37 / Crit rate +6
        neck="Rep. Plat. Medal", --Attack+30; trades Anu's post-WS TP return for current-WS damage
        ear1="Mache Earring +1", --DEX+8 / Acc+10 / DA+2
        ring1="Ramuh Ring +1", --DEX+9 / Accuracy+5
        ring2="Epaminondas's Ring", --WSD+5 still benefits the first WS hit
        back=capes.da, --DEX+20 / Acc+26 / DA+10
        waist="Grunfeld Rope", --DEX+5 / Acc+10 / Attack+20 / DA+2
        })

    sets.precast.WS['Chant du Cygne'].Acc = set_combine(sets.precast.WS['Chant du Cygne'], {
        body="Malignance Tabard",
        legs="Malignance Tights",
        feet="Malignance Boots",
        neck="Null Loop",
        ear2="Mache Earring +1",
        ring1="Chirich Ring +1",
        ring2="Chirich Ring +1",
        waist="Null Belt",
        })

    -- Evisceration: dedicated DEX/critical multi-hit policy.  v2.26 still
    -- fell through to the generic Nyame/STR-WSD set even though Tauret's primary
    -- WS belongs to the same DEX/critical family as CDC.  Start from the proven
    -- CDC damage/accuracy split, but keep an independent table so later dagger-
    -- specific tuning cannot silently alter CDC (or vice versa).
    sets.precast.WS['Evisceration'] = set_combine(sets.precast.WS['Chant du Cygne'], {})
    sets.precast.WS['Evisceration'].Acc = set_combine(sets.precast.WS['Chant du Cygne'].Acc, {})

    -- Vorpal Blade: 60% STR, four-hit critical WS. Preserve the Malignance
    -- accuracy core, but use the owned Ayanmo/Vitiation damage pieces instead
    -- of Store TP armor that contributes little to the current WS.
    sets.precast.WS['Vorpal Blade'] = set_combine(sets.precast.WS, {
        ammo="Yetshila +1",
        head="Malignance Chapeau",
        body="Ayanmo Corazza +2", --STR+28 / DA+7
        hands="Malignance Gloves",
        legs="Viti. Tights +3", --STR+35 / Attack+64
        feet="Aya. Gambieras +2", --STR+16 / Crit rate+6
        ear1="Mache Earring +1",
        ring1="Epaminondas's Ring", --WSD still benefits the first hit
        ring2="Sroda Ring", --STR+15 / attack / PDL
        back=capes.da,
        })
    sets.precast.WS['Vorpal Blade'].Acc = set_combine(sets.precast.WS['Vorpal Blade'], {
        neck="Null Loop",
        ear2="Mache Earring +1",
        ring1="Chirich Ring +1",
        ring2="Chirich Ring +1",
        waist="Null Belt",
        })

    -- Savage Blade: 50% STR / 50% MND, first-hit WSD is extremely valuable.
    -- Owned relic/AF upgrades beat the unranked Nyame head/hands recorded in
    -- this inventory, while Rep. Plat. Medal beats Anu Torque for WS damage.
    sets.precast.WS['Savage Blade'] = set_combine(sets.precast.WS, {
        head="Viti. Chapeau +3", --MND+42 / WSD+6 / Attack+62
        body="Viti. Tabard +3", --STR+31/MND+45/Attack+65 beats unaugmented Nyame Mail for this WS objective
        hands="Atro. Gloves +4", --MND+48 / WSD+9 / Acc+63
        neck="Rep. Plat. Medal", --STR+10 / Attack+30
        waist="Sailfi Belt +1",
        })

    sets.precast.WS['Savage Blade'].Acc = set_combine(sets.precast.WS['Savage Blade'], {
        neck="Null Loop", --Accuracy+50 / DT-5 when landing the WS is the priority
        ear2="Mache Earring +1",
        })

    -- Death Blossom: 50% MND / 30% STR. Its fTP is flat at every TP tier and
    -- TP only raises accuracy, so Moonshade's TP Bonus is not a damage stat.
    -- Keep the strong owned Savage armor, but use a real multi-hit earring.
    sets.precast.WS['Death Blossom'] = set_combine(sets.precast.WS['Savage Blade'], {
        ear2="Mache Earring +1",
        })
    sets.precast.WS['Death Blossom'].Acc = set_combine(sets.precast.WS['Death Blossom'], {
        neck="Null Loop",
        })

    sets.precast.WS['Requiescat'] = set_combine(sets.precast.WS, {
        head="Viti. Chapeau +3", --MND+42 / Attack+62 / WSD+6
        body="Viti. Tabard +3", --MND+45 / Attack+65 / Acc+40
        hands="Atro. Gloves +4", --MND+48 / Acc+63 / WSD+9
        legs="Viti. Tights +3", --MND+34 / Attack+64 / Acc+39
        neck="Rep. Plat. Medal", --more attack than inherited Anu; trades post-WS TP return for current-WS damage
        ring2="Stikini Ring +1", --MND+8
        })

    sets.precast.WS['Requiescat'].Acc = set_combine(sets.precast.WS['Requiescat'], {
        neck="Null Loop",
        ear1="Mache Earring +1",
        ear2="Mache Earring +1",
        })

    sets.precast.WS['Sanguine Blade'] = {
        ammo="Ghastly Tathlum +1",
        head="Pixie Hairpin +1", --Dark dmg+
        body="Lethargy Sayon +2", --MAB 49 / M.Dmg 24 (Jhakri Robe +2 is MAB 43, no M.Dmg)
        hands="Jhakri Cuffs +2",
        legs="Nyame Flanchard",
        feet="Vitiation Boots +3", --MAB+55 / M.Acc+43; stronger non-burst magical-WS foot
        neck="Sibyl Scarf",
        ear1="Friomisi Earring",
        ear2="Sortiarius Earring",
        ring1="Epaminondas's Ring", --WSD+5 applies to this one-hit magical WS
        ring2="Metamor. Ring +1", --MND modifier / M.Acc
        back=capes.ws, --STR+30 / WSD+10; INT is not a Sanguine modifier
        waist="Orpheus's Sash",
        }

    sets.precast.WS['Seraph Blade'] = set_combine(sets.precast.WS['Sanguine Blade'], {
        head="Jhakri Coronal +2",
        ear2="Moonshade Earring",
        })

    sets.precast.WS['Aeolian Edge'] = set_combine(sets.precast.WS['Seraph Blade'], {
        head="Jhakri Coronal +2",
        back=capes.nuke, --Aeolian is 40% DEX / 40% INT
        waist="Orpheus's Sash",
        })

    -- Black Halo: 70% MND / 30% STR and damage scales strongly with TP.
    -- Savage's owned WSC/WSD armor is appropriate; retain Moonshade and Sroda.
    -- The old override attempted to equip the single Telos Earring in both ears.
    sets.precast.WS['Black Halo'] = set_combine(sets.precast.WS['Savage Blade'], {})

    sets.precast.WS['Black Halo'].Acc = set_combine(sets.precast.WS['Black Halo'], {
        neck="Null Loop",
        ear2="Mache Earring +1",
        })

    -- Empyreal Arrow: single-hit physical ranged WS (50% AGI / 20% STR).
    -- RDM's borrowed Archery skill makes landing the shot the first priority, so
    -- Malignance supplies the high-ranged-accuracy core while Nyame legs/feet
    -- retain AGI, STR, ranged attack, and Path B WSD potential. The normal set
    -- keeps the owned STR/WSD cape and damage accessories; Ctrl+F1 MidAcc or
    -- HighAcc selects the Null/Malignance accuracy variant below. Chapuli Arrow
    -- is used for this profile as the user's preferred bow ammunition.
    sets.precast.WS['Empyreal Arrow'] = {
        range="Kaja Bow",
        ammo="Chapuli Arrow",
        head="Malignance Chapeau",
        body="Malignance Tabard",
        hands="Malignance Gloves",
        legs="Nyame Flanchard",
        feet="Nyame Sollerets",
        neck="Rep. Plat. Medal",
        ear1="Telos Earring",
        ear2="Moonshade Earring",
        ring1="Epaminondas's Ring",
        ring2="Sroda Ring",
        back=capes.ws,
        waist="Eschan Stone",
        }

    sets.precast.WS['Empyreal Arrow'].Acc = set_combine(sets.precast.WS['Empyreal Arrow'], {
        legs="Malignance Tights",
        feet="Malignance Boots",
        neck="Null Loop",
        back="Null Shawl",
        waist="Null Belt",
        })

    -- Community Harvest C1: when Moonshade's TP Bonus would push effective TP
    -- past an already-reached 3000-TP ceiling, replace it with a real damage earring.
    -- The runtime helper only applies these overlays when the resolved WS set
    -- actually contains Moonshade and moves the configured replacement to the
    -- ear slot Moonshade occupies. Acc variants that already replace it are
    -- untouched. Two Mache Earring +1 copies are owned.
    sets.MaxTP = {ear2="Mache Earring +1"}
    sets.MaxTP['Empyreal Arrow'] = {ear2="Enervating Earring"}
    sets.MagicalMaxTP = {ear2="Sortiarius Earring"}


    ------------------------------------------------------------------------------------------------
    ---------------------------------------- Midcast Sets ------------------------------------------
    ------------------------------------------------------------------------------------------------

    sets.midcast.FastRecast = sets.precast.FC -- (re-pointed by build_fc_sets on every rebuild)

    -- Manual SIRD CastingMode overlay. Explicit owned SIRD = 57%:
    -- Staunch 11 + Bunzi legs 20 + Magnetic 8 + Murky 3 + Evanescence 5 +
    -- Rumination 10. Open slots retain FC/haste/DT utility instead of inventing
    -- unowned interruption gear. Applied last in job_post_midcast when SIRD mode
    -- is selected, so the user explicitly chooses interruption resistance over
    -- spell-specific potency/accuracy in the conflicting slots.
    sets.midcast.SIRD = {
        ammo="Staunch Tathlum +1", --SIRD 11 / DT-3
        legs="Bunzi's Pants", --SIRD 20 / DT-9 / M.Eva 150
        ear1="Magnetic Earring", --SIRD 8
        ring1="Murky Ring", --SIRD 3 / DT-10
        ring2="Evanescence Ring", --SIRD 5
        waist="Rumination Sash", --SIRD 10
        }
    sets.midcast.SpellInterrupt = sets.midcast.SIRD

    -- Utsusemi always gets its own protected cast path: adaptive precast FC is
    -- already capped (native 38% + enough gear to hit the 80% total cap), then
    -- midcast combines the full owned 57% SIRD package with 47% gear FC in free
    -- slots plus DT/M.Eva. This keeps shadows fast while materially reducing
    -- interruption risk without requiring the global SIRD mode.
    sets.midcast.Utsusemi = set_combine(sets.midcast.SIRD, {
        head="Atro. Chapeau +2", --FC 14 / Haste 6
        body="Viti. Tabard +3", --FC 15 / Haste 3
        hands="Gende. Gages +1", --FC 7
        feet="Malignance Boots", --Haste 3 / DT-4 / M.Eva 150
        neck="Null Loop", --DT-5 / HP
        ear2="Etiolation Earring", --FC 1 / DT-3
        back=capes.fc, --FC 10 / DT-5
        })

    -- Weapon-independent Cure Potency +51 and Cure Potency II +12:
    -- four Kaykaus pieces give CP II+8 and the body adds another +4. Replacing
    -- the weakest Kaykaus slot with Bunzi hands costs only 2 CP II while adding
    -- DT-8 and 75 M.Eva. Daybreak remains a bonus when WeaponLock permits it;
    -- the armor/jewelry set already clears the regular +50 cap without it.
    sets.midcast.Cure = {
        main="Daybreak", --Cure potency +30; not required to cap
        sub="Ammurapi Shield",
        ammo="Staunch Tathlum +1", --DT-3 / SIRD-11
        head="Kaykaus Mitra +1", --CP+11 / MDT-3
        body="Kaykaus Bliaut +1", --CP II+4
        hands="Bunzi's Gloves", --DT-8 / M.Eva 112
        legs="Kaykaus Tights +1", --CP+11
        feet="Kaykaus Boots +1", --CP+11
        neck="Nodens Gorget", --CP+5
        ear1="Mendi. Earring", --CP+5
        ring1="Lebeche Ring", --CP+3 / Enmity-5
        ring2="Menelaus's Ring", --CP+5
        back=capes.fc,
        waist="Salire Belt",
        }

    sets.midcast.CureWeather = set_combine(sets.midcast.Cure, {
        main="Chatoyant Staff",
        sub="Enki Strap",
        })

    sets.midcast.CureSelf = set_combine(sets.midcast.Cure, {
        waist="Gishdubar Sash", --Cure received +10
        })

    -- Curaga uses the same capped set; replacing both potency rings with
    -- Stikini dropped the weapon-independent total below the +50 cap.
    sets.midcast.Curaga = sets.midcast.Cure

    -- Trimmed to RDM-equippable gear: Theo. Bliaut/Pantaloons and Cleric's Torque
    -- are WHM-only. Unlisted slots keep FC pieces from precast, which is fine --
    -- status removals have no potency scaling to chase.
    sets.midcast.StatusRemoval = {
        head=augmented_gear.vanya_hood_b,
        feet="Vanya Clogs",
        ring1="Stikini Ring +1",
        ring2="Murky Ring", --Menelaus is Cursna-only and carries Fast Cast-10
        waist="Bishop's Sash",
        }

    -- Cursna is not a generic status-removal cast: success rate benefits from
    -- Healing Magic skill, while owned Cursna+ comes from Menelaus (+20) and
    -- Vanya Clogs (+5). Build a dedicated skill set instead of inheriting only
    -- the minimal Erase/na-spell utility pieces.
    sets.midcast.Cursna = set_combine(sets.midcast.StatusRemoval, {
        head=augmented_gear.vanya_hood_b, --Path B: Healing skill +19 (Kaykaus is +16)
        body="Viti. Tabard +3", --Healing skill +23
        legs="Carmine Cuisses +1", --Healing skill +18 (highest owned RDM legs)
        feet="Vanya Clogs", --Healing skill +20 / Cursna +5
        ring1="Menelaus's Ring", --Healing skill +15 / Cursna +20
        ring2="Stikini Ring +1", --All magic skills +8
        waist="Bishop's Sash", --Healing skill +5
        })

    sets.midcast['Enhancing Magic'] = {
        sub="Ammurapi Shield",
        head="Befouled Crown", --Enh. skill 16
        body="Viti. Tabard +3", --Enh. skill 23
        hands="Viti. Gloves +3", --Enh. skill 24 (Atrophy Gloves +3 is DURATION, not skill)
        legs="Atrophy Tights +2", --Enh. skill 19
        feet="Leth. Houseaux +1", --Enh. skill 25 (slot was previously unfilled)
        neck=augmented_gear.dls_torque, --Path A adds rank-scaled Enhancing duration; no skill, but never a dead Enhancing slot
        ring1="Stikini Ring +1",
        ring2="Stikini Ring +1",
        back=capes.fc, --base: Enh. dur +20% on every copy
        waist="Olympus Sash", --Enh. skill
        }

    sets.midcast.EnhancingDuration = {
        sub="Ammurapi Shield",
        head="Telchine Cap", --Dur. +10 aug
        body="Viti. Tabard +3", --Enh. dur +15% + Enh. skill 23 (beats Telchine Chas.'s +9% dur / no skill)
        hands="Atro. Gloves +4", -- exact GearSwap/export name; Enh. duration +20 (still beats Viti. Gloves +3's flat +sec/merit aug)
        legs="Telchine Braconi", --Dur. +8 aug
        feet="Leth. Houseaux +1", --Enh. duration +30
        neck=augmented_gear.dls_torque, --Path A adds rank-scaled Enhancing duration; export does not expose rank, so do not assume R25
        back=capes.fc, --base: Enh. dur +20% on every copy
        waist="Embla Sash", --Enhancing duration +10%; ML23 baseline + Viti body already clears 500 skill
        }

    -- The base Enhancing set now carries max owned skill in every slot, so no
    -- overlay is needed for Temper/enspell casts. Kept as a hook for future
    -- skill-only pieces. (Viti. Tights +3's Enspell-damage aug is a melee-time
    -- stat and lives in sets.engaged.Enspell instead.)
    sets.midcast.EnhancingSkill = {}

    -- Regen rides the Duration set as-is: Telchine head/legs + Viti. Tabard +3
    -- body are already there, and Atro. Gloves +4 (duration +20) beats Telchine Gloves' +9 aug.
    sets.midcast.Regen = sets.midcast.EnhancingDuration

    sets.midcast.Refresh = set_combine(sets.midcast.EnhancingDuration, {
        head="Amalric Coif +1", --Refresh potency +2/tick
        body="Atrophy Tabard +3", --Refresh potency +2/tick (the Refresh+3 is idle-only)
        legs="Leth. Fuseau +1", --Refresh potency +2/tick; stronger sustain than Telchine legs' +8% generic duration here
        })

    sets.midcast.RefreshSelf = {
        waist="Gishdubar Sash", --Refresh effect received duration +20%
        }

    sets.midcast.Stoneskin = set_combine(sets.midcast.EnhancingDuration, {
        neck="Nodens Gorget", --Stoneskin +30
        })

    -- ML23 mastered baseline is 479 Enhancing skill. Viti. Tabard +3 alone
    -- raises the duration set above the 500-skill Phalanx cap, so excess skill
    -- gear is wasted here; use the much longer-duration set at full potency.
    sets.midcast['Phalanx'] = sets.midcast.EnhancingDuration

    sets.midcast.Aquaveil = set_combine(sets.midcast.EnhancingDuration, {
        ammo="Staunch Tathlum +1",
        head="Amalric Coif +1", --Aquaveil+
        ring2="Evanescence Ring",
        })

    sets.midcast.Storm = sets.midcast.EnhancingDuration
    sets.midcast.GainSpell = {hands="Viti. Gloves +3"} --Gain magic effect +30
    sets.midcast.SpikesSpell = {legs="Viti. Tights +3"}

    sets.midcast.Protect = sets.midcast.EnhancingDuration
    sets.midcast.Protectra = sets.midcast.Protect
    sets.midcast.Shell = sets.midcast.Protect
    sets.midcast.Shellra = sets.midcast.Shell


     -- Custom spell classes

    sets.midcast.MndEnfeebles = {
        main="Daybreak",
        sub="Ammurapi Shield",
        ammo="Hydrocera", --M.Acc
        head="Viti. Chapeau +3",
        body="Atrophy Tabard +3", --Enfeebling+
        hands="Kaykaus Cuffs +1", --M.Acc+20 aug
        legs="Malignance Tights", --M.Acc 50 (Inyanga is WHM/BRD/SMN-only)
        feet="Vitiation Boots +3",
        neck=augmented_gear.dls_torque,
        ear1="Enchntr. Earring +1", --player Magic Accuracy+6; Alabaster's M.Acc line is Pet:-scoped and must not be credited to RDM
        ear2="Snotra Earring",
        ring1="Kishar Ring", --Enf. duration +10%
        ring2="Stikini Ring +1",
        back=capes.fc,
        waist="Null Belt", --M.Acc 30 (Acuity Belt +1 is only INT/MP)
        }

    sets.midcast.MndEnfeeblesAcc = set_combine(sets.midcast.MndEnfeebles, {
        main=augmented_gear.crocea_mors,
        sub="Ammurapi Shield",
        ring1="Stikini Ring +1",
        })

    -- Potency lean: Leth. Sayon +2 = Enfeebling magic effect +16, and its M.Acc 54
    -- is within 1 of Atrophy Tabard +3's 55 -- the old potency-vs-macc trade is gone.
    -- Feet (Viti. Boots +3, effect +10) and
    -- neck (Dls. Torque +2, effect +10) already carry effect in the base set.
    sets.midcast.MndEnfeeblesEffect = set_combine(sets.midcast.MndEnfeebles, {
        body="Lethargy Sayon +2", --Enf. effect +16
        })

    sets.midcast.IntEnfeebles = set_combine(sets.midcast.MndEnfeebles, {
        main="Maxentius",
        sub="Ammurapi Shield",
        back=capes.nuke, --INT+20 with the same M.Acc+20; do not inherit the MND+30 FC cape
        })

    sets.midcast.IntEnfeeblesAcc = set_combine(sets.midcast.IntEnfeebles, {
        main=augmented_gear.crocea_mors,
        sub="Ammurapi Shield",
        ring1="Stikini Ring +1",
        })

    sets.midcast.IntEnfeeblesEffect = set_combine(sets.midcast.IntEnfeebles, {
        body="Lethargy Sayon +2", --Enf. effect +16 (see MndEnfeeblesEffect note)
        })

    sets.midcast.SkillEnfeebles = set_combine(sets.midcast.MndEnfeebles, {
        head="Viti. Chapeau +3",
        body="Atrophy Tabard +3", --Enf. skill 21
        feet="Vitiation Boots +3",
        neck=augmented_gear.dls_torque, --M.Acc/effect + Path A duration; does NOT provide Enfeebling skill
        ring1="Stikini Ring +1",
        ring2="Stikini Ring +1",
        ear1="Enchntr. Earring +1", --M.Acc+6; no owned Enfeebling-skill earring
        ear2="Snotra Earring",
        waist="Rumination Sash", --Enf. skill 7 / SIRD 10
        -- Hands option: Leth. Gantherots +1 (skill 19) beats Kaykaus Cuffs +1
        -- (skill 16) by 3 skill but gives up ~29 M.Acc -- swap if potency-starved.
        })

    -- Manual Potency mode for skill-governed Distract III/Frazzle III/Poison II:
    -- preserve the skill-oriented routing but take Lethargy body's +16 effect.
    sets.midcast.SkillEnfeeblesPotency = set_combine(sets.midcast.SkillEnfeebles, {
        body="Lethargy Sayon +2",
        })

    -- Sleep is intentionally one accuracy-first route. IntEnfeeblesAcc keeps
    -- the strongest owned landing package; no mode or JA silently substitutes
    -- the dormant duration set.
    sets.midcast.Sleep = set_combine(sets.midcast.IntEnfeeblesAcc, {})

    -- Retained as a disconnected future option. Nothing in v2.48 routes here.
    -- 4/5 Lethargy plus Viti. Chapeau +3 and Kishar preserves the prior
    -- maximum-duration package if a deliberate selector is restored later.
    sets.midcast.SleepMaxDuration = set_combine(sets.midcast.Sleep, {
        body="Lethargy Sayon +2",
        hands="Leth. Gantherots +1",
        legs="Leth. Fuseau +1",
        feet="Leth. Houseaux +1",
        ring1="Kishar Ring",
        })

    -- Reserved duration routes retained for possible future use. They are
    -- disconnected from the streamlined Auto/Accuracy controller.
    sets.midcast.MndEnfeeblesDuration = set_combine(sets.midcast.MndEnfeebles, {
        head="Viti. Chapeau +3",
        body="Lethargy Sayon +2",
        hands="Leth. Gantherots +1",
        legs="Leth. Fuseau +1",
        feet="Leth. Houseaux +1",
        ear2="Snotra Earring",
        ring1="Kishar Ring",
        })
    sets.midcast.IntEnfeeblesDuration = set_combine(sets.midcast.IntEnfeebles, {
        head="Viti. Chapeau +3",
        body="Lethargy Sayon +2",
        hands="Leth. Gantherots +1",
        legs="Leth. Fuseau +1",
        feet="Leth. Houseaux +1",
        ear2="Snotra Earring",
        ring1="Kishar Ring",
        })

    sets.midcast.ElementalEnfeeble = sets.midcast.IntEnfeebles
    sets.midcast.Dispelga = set_combine(sets.midcast.IntEnfeeblesAcc, {
        main="Daybreak", --required to cast Dispelga
        sub="Ammurapi Shield",
        waist="Null Belt", --M.Acc+30; Shinjutsu is a precast/resting piece
        })

    sets.midcast['Dark Magic'] = {
        sub="Ammurapi Shield",
        ammo="Hydrocera",
        head="Atro. Chapeau +2",
        body="Lethargy Sayon +2", --M.Acc 54 + M.Dmg 24 (Jhakri Robe +2 is M.Acc 46)
        hands="Kaykaus Cuffs +1",
        legs="Malignance Tights", --M.Acc 50 (Inyanga is WHM/BRD/SMN-only)
        feet="Vitiation Boots +3", --M.Acc+43 / MAB+55 beats Jhakri here
        neck="Erra Pendant",
        ear1="Enchntr. Earring +1",
        ear2="Snotra Earring",
        ring1="Stikini Ring +1",
        ring2="Evanescence Ring",
        back=capes.nuke, --M.Acc 20 (Aurist's is only M.Acc 7)
        waist="Null Belt", --M.Acc 30 (Acuity Belt +1 is only INT/MP)
        }

    sets.midcast.Drain = set_combine(sets.midcast['Dark Magic'], {
        head="Pixie Hairpin +1", --Dark dmg+
        ring2="Evanescence Ring",
        })

    sets.midcast.Aspir = sets.midcast.Drain
    sets.midcast.Stun = set_combine(sets.midcast['Dark Magic'], {waist="Null Belt"})
    -- Vitiation Tights augment Enspell/accuracy, not Bio III.
    sets.midcast['Bio III'] = sets.midcast['Dark Magic']

    sets.midcast['Elemental Magic'] = {
        main="Bunzi's Rod",
        sub="Ammurapi Shield",
        ammo="Ghastly Tathlum +1", --Mag. dmg.
        head="Jhakri Coronal +2", --MAB
        body="Lethargy Sayon +2", --MAB 49 / M.Dmg 24 / M.Acc 54 (Jhakri Robe +2 is MAB 43, M.Acc 46, no M.Dmg)
        hands="Jhakri Cuffs +2", --MAB
        legs="Jhakri Slops +2", --MAB
        feet="Vitiation Boots +3", --MAB+55 / M.Acc+43; +16 MAB over Jhakri for non-burst nukes
        neck="Sibyl Scarf", --Mag. dmg.
        ear1="Friomisi Earring", --MAB
        ear2="Sortiarius Earring",
        ring1="Jhakri Ring", --MAB
        ring2="Metamor. Ring +1",
        back=capes.nuke,
        waist="Skrymir Cord", --M.Acc 5 / MAB 5 / M.Dmg 30 (Acuity Belt +1 is only INT/MP)
        }


    local elemental_spellacc_overlay = {
        ammo="Hydrocera", --M.Acc+6
        hands="Kaykaus Cuffs +1", --M.Acc 33 + owned M.Acc+20 augment
        legs="Malignance Tights", --M.Acc 50
        neck="Null Loop", --M.Acc 50 / DT-5: strict elemental-landing upgrade over Erra Pendant's M.Acc 17
        ring1="Stikini Ring +1", --M.Acc 11 + Elemental skill via All magic skills +8
        ring2="Stikini Ring +1", --second owned copy; accuracy mode values skill/M.Acc over Metamor INT
        waist="Null Belt", --M.Acc 30; meaningful SpellACC tier instead of Skrymir's M.Acc 5
        }
    sets.midcast['Elemental Magic'].SpellACC =
        set_combine(sets.midcast['Elemental Magic'], elemental_spellacc_overlay)

    -- DISABLED: Twilight Cloak (NOT OWNED) is required to cast Impact; set is dormant.
    -- NOTE: Twilight Cloak is NOT in the 2026-07-30 inventory export. If it
    -- lives on a slip / mog safe / locker, GearSwap cannot equip it and Impact
    -- silently loses its REQUIRED body piece -- keep it in a wardrobe.
    sets.midcast.Impact = set_combine(sets.midcast['Elemental Magic'], {
        head=empty,
        --body="Twilight Cloak", -- not owned; uncomment when acquired
        })

    -- Initializes trusts at iLvl 119
    sets.midcast.Trust = sets.precast.FC -- (re-pointed by build_fc_sets on every rebuild)

    -- Job-specific buff sets
    -- Composure duration policy differs by magic school:
    --   Enhancing on others: 4/5 Lethargy plus Atrophy Gloves +4. The gloves'
    --   separate +20% Enhancing duration category beats the fifth Empyrean piece.
    --   Enfeebling: preserve Viti. Chapeau +3's +20% enfeebling duration and use
    --   4/5 Lethargy (body/hands/legs/feet). Under the project's documented set
    --   bonus model, 1.40 x 1.35 beats replacing Viti head for 1.20 x 1.50.
    -- Keep a compatibility alias for older helpers, but new routing is explicit.
    sets.buff.ComposureOtherEnhancing = {
        head="Leth. Chappel +1",
        body="Lethargy Sayon +2",
        hands="Atro. Gloves +4", --Enhancing duration +20%
        legs="Leth. Fuseau +1",
        feet="Leth. Houseaux +1",
        }
    sets.buff.ComposureOtherEnfeebling = {
        body="Lethargy Sayon +2",
        hands="Leth. Gantherots +1",
        legs="Leth. Fuseau +1",
        feet="Leth. Houseaux +1",
        }
    sets.buff.ComposureOther = sets.buff.ComposureOtherEnhancing

    sets.buff.Saboteur = {hands="Leth. Gantherots +1"} --Enhances Saboteur


    ------------------------------------------------------------------------------------------------
    ----------------------------------------- Idle Sets --------------------------------------------
    ------------------------------------------------------------------------------------------------

    sets.idle = {
        ammo="Staunch Tathlum +1",
        head="Viti. Chapeau +3",
        body="Jhakri Robe +2", --Refresh
        hands="Volte Gloves",
        legs="Carmine Cuisses +1", --Movement+
        feet="Nyame Sollerets",
        neck="Sanctity Necklace",
        ear1="Eabani Earring", --M.Eva
        ear2="Etiolation Earring",
        ring1="Stikini Ring +1", --Refresh
        ring2="Stikini Ring +1", --Refresh
        back="Null Shawl",
        waist="Carrier's Sash", --Elem. resist
        }

    -- DT cap without throwing away idle refresh.  Inherited Staunch Tathlum +1
    -- (DT-3), Viti head (Refresh+3), Volte hands (Refresh+1), and Stikini ring1
    -- combine with the pieces below for 51% untyped DT and 8 Refresh/tick before
    -- movement overlays. This is strictly more useful than the old 5/5 Nyame idle.
    sets.idle.DT = set_combine(sets.idle, {
        body="Lethargy Sayon +2", --DT-13 / Refresh+3
        legs="Nyame Flanchard", --DT-8
        feet="Nyame Sollerets", --DT-7
        ear2="Alabaster Earring", --DT-5 / HP+100
        ring2="Murky Ring", --DT-10
        back=capes.dw, --DT-5
        })

    sets.idle.Town = set_combine(sets.idle, {
        head="Viti. Chapeau +3",
        body="Viti. Tabard +3",
        legs="Carmine Cuisses +1", --Movement+
        neck=augmented_gear.dls_torque,
        back=capes.nuke,
        waist="Acuity Belt +1",
        })

    sets.resting = set_combine(sets.idle, {
        main="Chatoyant Staff",
        waist="Shinjutsu-no-Obi +1",
        })

    ------------------------------------------------------------------------------------------------
    ---------------------------------------- Defense Sets ------------------------------------------
    ------------------------------------------------------------------------------------------------

    -- One shared untyped-DT wall. Mote's Physical/PDT path is the internal
    -- route used by the player-facing DT mode; the duplicate MDT route is gone.
    sets.defense.DT = sets.idle.DT
    sets.defense.PDT = sets.defense.DT
    -- Dedicated magic-evasion wall: Bunzi 5/5 supplies 674 M.Eva and DT-40;
    -- Staunch + Null Loop + Etiolation bring total DT to 51 while Null
    -- Shawl/Null Belt/Carrier's Sash preserve M.Eva and elemental resistance.
    sets.defense.MEVA = {
        ammo="Staunch Tathlum +1",
        head="Bunzi's Hat",
        body="Bunzi's Robe",
        hands="Bunzi's Gloves",
        legs="Bunzi's Pants",
        feet="Bunzi's Sabots",
        neck="Null Loop",
        ear1="Eabani Earring",
        ear2="Etiolation Earring",
        ring1="Stikini Ring +1",
        ring2="Stikini Ring +1",
        back="Null Shawl",
        waist="Carrier's Sash",
        }

    -- Overlay applied on top of sets.midcast['Elemental Magic'] when bursting.
    -- Only slots listed here swap; everything else keeps the canonical elemental set.
    -- Bunzi 5/5 = MB dmg +40, exactly the Magic Burst I equipment cap. Bunzi's Rod
    -- adds +10 more when held (over cap, harmless; main won't swap under WeaponLock).
    -- Mujin Band's +5 is MB II, a separate uncapped term.
    sets.magic_burst = {
        main="Bunzi's Rod",
        sub="Ammurapi Shield",
        head="Bunzi's Hat", --MB +7, MAB 30, M.Dmg 30 (Amalric Coif has no MAB/MB)
        body="Bunzi's Robe", --MB +10 (Mallquis is BLM/SCH/GEO-only)
        hands="Bunzi's Gloves", --MB +8
        legs="Bunzi's Pants", --MB +9 (Leth. Fuseau +1 has no MB)
        feet="Bunzi's Sabots", --MB +6 (Mallquis is BLM/SCH/GEO-only)
        ring2="Mujin Band", --MB II +5
        }

    -- Movement speed gear does not stack. Kiting uses ring1 normally; the
    -- explicit combined overlay moves Shneddick to ring2 so TH retains Hoxne.
    sets.Kiting = {ring1="Shneddick Ring"}
    sets.TreasureHunterKiting = {
        ammo="Per. Lucky Egg",
        ring1="Hoxne Ring",
        ring2="Shneddick Ring",
        }
    sets.latent_refresh = {} -- Fucho-no-obi not owned yet


    ------------------------------------------------------------------------------------------------
    ---------------------------------------- Engaged Sets ------------------------------------------
    ------------------------------------------------------------------------------------------------

    -- Variations for TP weapon and (optional) offense/defense modes.  Code will fall back on previous
    -- sets if more refined versions aren't defined.
    -- If you create a set with both offense and defense modes, the offense mode should be first.
    -- EG: sets.engaged.Dagger.Accuracy.Evasion

    sets.engaged = {
        ammo="Focal Orb",
        head="Malignance Chapeau",
        body="Malignance Tabard",
        hands="Malignance Gloves",
        legs="Malignance Tights",
        feet="Malignance Boots",
        neck="Anu Torque",
        ear1="Brutal Earring", --DA
        ear2="Telos Earring",
        ring1="Chirich Ring +1", --STP/Acc (Niqmaddu is not RDM; 2x Chirich owned)
        ring2="Chirich Ring +1", --STP/Acc
        back=capes.da, -- single-wield: DW+10 is dead, Dbl.Atk+10 is live.
                          -- The adaptive overlay owns this slot in DW forms.
        -- Full Malignance supplies 266/1024 haste and already clears the
        -- 256/1024 gear cap, so Windbuffet's TA+2/QA+2 is fully live here.
        waist="Windbuffet Belt +1",
        }

    sets.engaged.MidAcc = set_combine(sets.engaged, {
        neck="Null Loop", --Acc+50: a real step above Anu instead of Sanctity's +10
        ear2="Mache Earring +1", --DEX+8 / Acc+10
        })

    sets.engaged.HighAcc = set_combine(sets.engaged.MidAcc, {
        ammo="Oshasha's Treatise", --Acc+5: +15 explicit accuracy versus Focal Orb's Acc-10 baseline
        neck="Null Loop", --Accuracy+50 / DT-5
        ear1="Telos Earring", --Acc+10/Atk+10/STP+5; stronger landing policy than Cessance's Acc+6
        back="Null Shawl", --Acc+50/STP+7/DA+7: dedicated single-wield high-accuracy back
        waist="Null Belt", --Acc+30
        })

    -- Owned DW gear: Suppanomimi 5, Eabani 4, DW cape 10, Carmine legs 6 (augment) = 25 total.
    -- (Patentia Sash is not RDM-equippable; Sailfi's Haste+9% fills the waist instead.)
    -- No Magic Haste (max gear DW)
    sets.engaged.DW = set_combine(sets.engaged, {
        legs="Carmine Cuisses +1", --DW
        ear1="Eabani Earring", --DW
        ear2="Suppanomimi", --DW
        waist="Sailfi Belt +1", --Haste 9 / TA 2
        })

    sets.engaged.DW.MidAcc = set_combine(sets.engaged.DW, {
        neck="Null Loop", --Acc+50; adaptive DW overlay still owns required DW slots
        ear2="Mache Earring +1",
        })

    sets.engaged.DW.HighAcc = set_combine(sets.engaged.DW.MidAcc, {
        ammo="Oshasha's Treatise", --Acc+5: +15 explicit accuracy versus Focal Orb's Acc-10 baseline
        neck="Null Loop", --Accuracy+50 / DT-5
        ear1="Telos Earring", --preserved whenever adaptive DW does not require Eabani in ear1
        waist="Null Belt", --Acc+30; adaptive shortfall logic may still force Sailfi when genuinely required
        })

    ------------------------------------------------------------------------------------------------
    ---------------------------------------- Hybrid Sets -------------------------------------------
    ------------------------------------------------------------------------------------------------

    sets.engaged.Hybrid = {
       neck="Null Loop", --DT-5 / Acc+50; base Malignance + ear/ring reaches the 50% DT cap
       ear2="Alabaster Earring", --DT-5/HP
       ring2="Murky Ring", --DT-10
       }

    sets.engaged.DT = set_combine(sets.engaged, sets.engaged.Hybrid)
    sets.engaged.MidAcc.DT = set_combine(sets.engaged.MidAcc, sets.engaged.Hybrid)
    sets.engaged.HighAcc.DT = set_combine(sets.engaged.HighAcc, sets.engaged.Hybrid)

    sets.engaged.DW.DT = set_combine(sets.engaged.DW, sets.engaged.Hybrid)
    sets.engaged.DW.MidAcc.DT = set_combine(sets.engaged.DW.MidAcc, sets.engaged.Hybrid)
    sets.engaged.DW.HighAcc.DT = set_combine(sets.engaged.DW.HighAcc, sets.engaged.Hybrid)

    -- Balanced Auto overlay: Crocea + active Enspell only. Ayanmo hands give the
    -- large +17 Enspell bonus without surrendering the normal Windbuffet waist or
    -- Malignance legs' Haste+9/STP+10/DT-7.
    sets.engaged.Enspell = {
        hands="Aya. Manopolas +2", --Sword enhancement spell damage +17
        -- No neck override: Dls. Torque +2 Path A extends Enhancing CAST duration;
        -- it does not add melee-time sword enhancement damage. Preserve the
        -- underlying TP/accuracy neck selected by the engaged mode.
        }

    -- Explicit EnspellMode=Max overlay. This is the owned max-Enspell option for
    -- Invincible/zero-physical-damage strategies where Enspell output outweighs
    -- TP speed, Store TP, and defensive value.
    sets.engaged.EnspellMax = set_combine(sets.engaged.Enspell, {
        legs="Viti. Tights +3", --Enspell +5 at five Group-2 merits
        waist="Orpheus's Sash",
        })



    ------------------------------------------------------------------------------------------------
    ---------------------------------------- Special Sets ------------------------------------------
    ------------------------------------------------------------------------------------------------

    sets.buff.Doom = {
        neck="Nicander's Necklace", --Doom recovery
        ring1="Blenmot's Ring +1", --Doom resist
        ring2="Blenmot's Ring +1", --Doom resist (2 owned)
        waist="Gishdubar Sash",
        }

    -- Hachirin-no-Obi not owned: obi branches removed from waist logic until acquired.
    -- sets.CP = {back="Mecisto. Mantle"}

    sets.TreasureHunter = {ammo="Per. Lucky Egg", ring1="Hoxne Ring"}

    -- Fishing Mode gear (Alt+F2 equips this, then freezes every slot except
    -- ring1/ring2). The live rings preserve Warp/Dimensional protection and
    -- allow native Shneddick movement swaps while the fishing armor stays put.
    -- Rod goes in RANGE; the fisher addon supplies bait via direct equips
    -- that bypass GearSwap's freeze. Halcyon Rod = owned break-proof
    -- alternative. The export's exact abbreviated body/hands resource names
    -- are required by GearSwap; legs and feet use their full names.
    sets.Fishing = {
        range="Lu Shang's F. Rod",
        body="Fsh. Tunica",                --Fishing skill +1
        hands="Fsh. Gloves",               --Fishing skill +1
        legs="Fisherman's Hose",           --Fishing skill +1
        feet="Fisherman's Boots",          --Fishing skill +1
        }

    -- Canonical weapon-combination controller. All combat combinations use the
    -- same audited armor core,
    -- then branch through adaptive DW, weapon-aware Enspell routing, the WS's
    -- own dedicated precast set, and TP-bonus-aware Moonshade overflow logic.
    -- If /NIN or /DNC is unavailable, the control engine replaces each weapon
    -- offhand with its owned casting/physical shield and resolves single-wield TP.
    -- Every non-bow profile explicitly empties range so Kaja Bow can never be
    -- stranded and locked after cycling away from its profile.
    sets.CroceaMors = {main=augmented_gear.crocea_mors, sub="Daybreak", range=empty}
    sets.CroceaTPBonus = {main=augmented_gear.crocea_mors, sub=augmented_gear.machaera_tp_bonus, range=empty}
    sets.Naegling = {main="Naegling", sub="Blurred Knife +1", range=empty}
    sets.NaeglingTPBonus = {main="Naegling", sub=augmented_gear.machaera_tp_bonus, range=empty}
    sets.Maxentius = {main="Maxentius", sub="Blurred Knife +1", range=empty}
    sets.MaxentiusTPBonus = {main="Maxentius", sub=augmented_gear.machaera_tp_bonus, range=empty}
    sets.Tauret = {main="Tauret", sub="Blurred Knife +1", range=empty}
    -- Kaja Bow owns its ammunition as part of the weapon profile, not only in
    -- Empyreal Arrow precast. The reusable ammo overlay is applied last in idle
    -- and melee resolution so ordinary armor/TH/Defense ammo cannot silently
    -- replace Chapuli Arrow while this profile is selected.
    sets.KajaBowAmmo = {ammo="Chapuli Arrow"}
    sets.KajaBow = {
        main="Naegling",
        sub=augmented_gear.machaera_tp_bonus,
        range="Kaja Bow",
        ammo="Chapuli Arrow",
    }
    sets.Idle = {main="Daybreak", sub="Ammurapi Shield", range=empty}

    sets.DefaultShield = {sub="Ammurapi Shield"}
    -- Owned single-wield fallbacks are objective-specific. Ammurapi supports
    -- Crocea/casting with M.Acc/MAB and Enhancing duration; Deliverance gives
    -- physical weapon profiles Accuracy, PDT-3, Counter, and stronger blocking.
    sets.WeaponShields = {
        CroceaMors=sets.DefaultShield,
        CroceaTPBonus=sets.DefaultShield,
        Naegling={sub="Deliverance"},
        NaeglingTPBonus={sub="Deliverance"},
        Maxentius={sub="Deliverance"},
        MaxentiusTPBonus={sub="Deliverance"},
        Tauret={sub="Deliverance"},
        KajaBow={sub="Deliverance"},
        Idle=sets.DefaultShield,
    }

    -- Act 4: resolve every currently valid engaged base once. Mote's normal
    -- resolver remains the fallback, but the hot path can now select the exact
    -- prebuilt table with three direct lookups and no name/path traversal.
    engaged_set_index = {
        Normal = {
            Normal  = {Normal=sets.engaged,         DT=sets.engaged.DT},
            MidAcc  = {Normal=sets.engaged.MidAcc,  DT=sets.engaged.MidAcc.DT},
            HighAcc = {Normal=sets.engaged.HighAcc, DT=sets.engaged.HighAcc.DT},
        },
        DW = {
            Normal  = {Normal=sets.engaged.DW,         DT=sets.engaged.DW.DT},
            MidAcc  = {Normal=sets.engaged.DW.MidAcc,  DT=sets.engaged.DW.MidAcc.DT},
            HighAcc = {Normal=sets.engaged.DW.HighAcc, DT=sets.engaged.DW.HighAcc.DT},
        },
    }

    -- user_setup runs before this index exists and therefore uses the safe
    -- initialization fallback. Re-resolve once now so the first engaged swap
    -- already owns a projected-set DW plan.
    update_native_haste_dw(true)
    update_combat_form()
    update_dw_overlay()

    -- Adaptive Fast Cast: everything now exists (fc_core/fc_ladder above,
    -- all midcast sets, states from user_setup), so compute the real gear
    -- target and rebuild the FC sets. init_gear_sets is the LAST step of
    -- Mote's init order -- do not move this call into user_setup.
    -- (silent: rebuild on load without printing the FC tier line --
    -- 'gs c fcinfo' still reports on demand.)
    update_fc_tier(false, true)

end

-------------------------------------------------------------------------------------------------------------------
-- Job-specific hooks for standard casting events.
-------------------------------------------------------------------------------------------------------------------

-- Spell metadata owns Saboteur eligibility through compiled policy. WS metadata owns
-- the magical-WS proximity family; build only that tiny S{} once after initialization.
local magical_ws_names = {}
for ws_name, ws_policy in pairs(RDM_WEAPONSKILL_POLICY) do
    if ws_policy.family == 'magical' and ws_policy.proximity_waist then
        magical_ws_names[#magical_ws_names + 1] = ws_name
    end
end
magical_ws = S(magical_ws_names)

-- @ai:fn spell_target_within | layer=utility | hot=yes | purity=read | contract=Nil-safe distance predicate; never assume target/model_size exists.
local function spell_target_within(spell, yalms)
    local target = spell and spell.target
    local distance = target and tonumber(target.distance)
    if not distance then return false end
    local model_size = tonumber(target.model_size) or 0
    return distance < (yalms + model_size)
end

-- @ai:fn resolved_ws_precast_set | layer=gear | hot=yes | purity=read | contract=Mirror Mote's specific-set-then-mode WS resolution without inventory/resource scans.
local function resolved_ws_precast_set(spell)
    if not (spell and sets and sets.precast and sets.precast.WS) then return nil end
    local mode = type(get_custom_wsmode) == 'function'
        and get_custom_wsmode(spell) or nil

    -- Mote first selects the spell-specific table, then applies a mode child
    -- only when that selected table owns one. It does not fall back from a
    -- specific magical WS with no .Acc child to the generic physical WS.Acc set.
    local resolved = sets.precast.WS[spell.english] or sets.precast.WS
    if mode and resolved[mode] then
        resolved = resolved[mode]
    end
    return resolved
end

-- @ai:fn apply_max_tp_moonshade | layer=gear | hot=yes | purity=write | contract=Replace Moonshade only when the resolved WS set wears it and actual TP plus confirmed non-Moonshade bonuses already reaches 3000.
local function apply_max_tp_moonshade(spell)
    local ws_set = resolved_ws_precast_set(spell)
    if not ws_set then return end
    local ear1 = type(ws_set.ear1) == 'table' and ws_set.ear1.name or ws_set.ear1
    local ear2 = type(ws_set.ear2) == 'table' and ws_set.ear2.name or ws_set.ear2
    local moonshade_slot = ear1 == 'Moonshade Earring' and 'ear1'
        or (ear2 == 'Moonshade Earring' and 'ear2')
    if not moonshade_slot then return end

    -- Moonshade is removed only when its own +250 is redundant. Machaera +2's
    -- exported TP Bonus +1000 augment is counted only while that item is actually
    -- equipped in sub; a non-DW shield fallback therefore contributes zero.
    -- Without Crystal Blessing, at 1750 raw TP with Machaera, Moonshade is still
    -- needed to reach the ceiling; at 2000, Machaera alone reaches 3000 and the
    -- real damage ear wins.
    -- Hidden/unknown encounter bonuses are never inferred.
    local equipped_sub = player and player.equipment
        and (player.equipment.sub or player.equipment.left_sub)
    local weapon_tp_bonus = equipped_sub == 'Machaera +2' and 1000 or 0
    local tp_without_moonshade = (player and tonumber(player.tp) or 0)
        + (buffactive and buffactive['Crystal Blessing'] and 250 or 0)
        + weapon_tp_bonus
    if tp_without_moonshade < 3000 then return end

    local replacements
    if magical_ws and magical_ws:contains(spell.english) then
        replacements = (sets.MagicalMaxTP and sets.MagicalMaxTP[spell.english])
            or sets.MagicalMaxTP
    else
        replacements = (sets.MaxTP and sets.MaxTP[spell.english]) or sets.MaxTP
    end
    if type(replacements) ~= 'table' then return end

    -- Existing replacement sets use ear2 as the canonical item holder. Relocate
    -- that item to whichever ear Moonshade actually occupies in the resolved WS.
    local replacement = replacements[moonshade_slot] or replacements.ear2 or replacements.ear1
    if not replacement then return end
    local overlay = {}
    overlay[moonshade_slot] = replacement
    equip(overlay)
end

-- Bidirectional Phalanx convenience. Player intent remains explicit: casting
-- Phalanx on another player means Phalanx II; self-target Phalanx stays Phalanx.
-- The reverse Phalanx II -> self safeguard remains in job_post_precast.
-- @ai:fn job_pretarget | layer=framework | hot=yes | purity=write | contract=Redirect Phalanx-on-ally to Phalanx II before invalid-target filtering; never infer non-player targets.
function job_pretarget(spell, action, spellMap, eventArgs)
    if spell and spell.english == 'Phalanx' and spell.target
        and spell.target.type == 'PLAYER' and spell.target.name ~= player.name then
        local target = spell.target.raw or '<t>'
        cancel_spell()
        send_command('@input /ma "Phalanx II" '..target)
        if eventArgs then eventArgs.cancel = true end
    end
end

-- @ai:fn job_precast | layer=framework | hot=yes | purity=write | contract=Pre-action guards/cancellations only; protect locked rings before Mote equips FC.
function job_precast(spell, action, spellMap, eventArgs)
    -- Protect warp/dimension/boost rings BEFORE any precast set is equipped.
    -- check_gear disables the ring slot whenever a no_swap ring is worn, so the
    -- FC set's hardcoded ring2 (Lebeche) can't yank a Dim. Ring out mid-teleport.
    -- (The ring is released later by the zone-change handler once you arrive.)
    check_gear()

    -- A matching GearSwap precast is stronger evidence than the command send:
    -- it confirms that the exact F10-selected spell reached the casting engine.
    -- The pending guard remains until aftercast (or a bounded state-only
    -- timeout), preventing a double tap without ever scheduling another spell.
    if type(mb_confirm_precast) == 'function' then
        mb_confirm_precast(spell)
    end

    -- Convert guard (Selindrile pattern): the JA fails outright at 0 MP, so
    -- abort instead of burning the attempt. The max-HP precast set in
    -- sets.precast.JA['Convert'] handles the equipment side.
    if spell.english == 'Convert' and player.mp == 0 then
        cancel_spell()
        add_to_chat(167, '** [Convert Canceled - 0 MP, it would fail] **')
        eventArgs.handled = true
        return
    end

    -- Nudge: big enfeeble going out without Saboteur while it sits ready.
    -- Phase B2 consumes the flat compiled policy instead of inheritance or parallel S{} lookups.
    local precast_policy = RDM_SPELL_RUNTIME[spell.english]
    if precast_policy and precast_policy.saboteur_hint and not buffactive.Saboteur and ja_ready('Saboteur') then
        send_command('input /echo ** Saboteur is ready - pair it with '..spell.english..' **')
    end

    -- Optional ordinary-shot ammo protection (typed: gs c rangedlock).
    if spell.action_type == 'Ranged Attack' and state.RangedLock.value then
        cancel_spell()
        add_to_chat(167, '** [Ranged Attack Canceled - Ammo Protection On] **')
        eventArgs.handled = true
        return
    end

    -- Auto-Cancel Active Buffs
    if spell.english == 'Stoneskin' then
        send_command('cancel stoneskin')
    elseif spell.english == 'Sneak' and spell.target.type == 'SELF' then
        -- Self-target gate: casting Sneak ON SOMEONE ELSE must not strip ours.
        send_command('cancel sneak')
    end

    if spellMap == 'Utsusemi' then
        if buffactive['Copy Image (3)'] or buffactive['Copy Image (4+)'] then
            cancel_spell()
            add_to_chat(123, '**!! '..spell.english..' Canceled: [3+ IMAGES] !!**')
            eventArgs.handled = true
            return
        elseif buffactive['Copy Image'] or buffactive['Copy Image (2)'] then
            send_command('cancel 66; cancel 444; cancel Copy Image; cancel Copy Image (2)')
        end
    end
end

-- @ai:fn job_post_precast | layer=framework | hot=yes | purity=write | contract=Final precast overlays/redirections; last equip wins.
function job_post_precast(spell, action, spellMap, eventArgs)
    if spell.name == 'Impact' then
        equip(sets.precast.FC.Impact)
    end
    if spell.english == "Phalanx II" and spell.target.type == 'SELF' then
        cancel_spell()
        send_command('@input /ma "Phalanx" <me>')
        if eventArgs then eventArgs.cancel = true end
        return
    end

    if spell.type == 'WeaponSkill' then
        apply_max_tp_moonshade(spell)
    end

    -- Chainspell/Spontaneity can resolve before an ordinary midcast swap safely
    -- lands. Preload the normal Mote midcast set plus our final spell-family
    -- overlays during precast. The regular midcast hook still runs afterward as
    -- a second safety pass. Mark the preload invocation itself so it stays
    -- silent; Mote creates a fresh eventArgs table for the real midcast, which
    -- then prints the AutoMB notification exactly once.
    if spell.action_type == 'Magic' and buffactive
        and (buffactive['Chainspell'] or buffactive['Spontaneity']) then
        if type(get_midcast_set) == 'function' then
            local mid = get_midcast_set(spell, spellMap)
            if mid then equip(mid) end
        end
        job_post_midcast(spell, action, spellMap, {
            _rdm_instant_midcast_preloaded = true
        })
    end

    -- Smart Magical WS Logic
    if spell.type == 'WeaponSkill' and magical_ws:contains(spell.english) then
        -- Equip Orpheus if under 1.7 yalms. (Obi branch removed: Hachirin-no-Obi
        -- not owned. Re-add a weather/day branch here when acquired.)
        if spell_target_within(spell, 1.7) then
            equip({waist="Orpheus's Sash"})
        end
    end
end

-- Run after the default midcast() is done.
-- eventArgs is the same one used in job_midcast, in case information needs to be persisted.
-- @ai:fn job_post_midcast | layer=framework | hot=yes | purity=write | contract=Final spell-family overlays; preserve ordering because later equip calls override earlier ones.
function job_post_midcast(spell, action, spellMap, eventArgs)
    local english = spell.english
    local spell_policy = RDM_SPELL_RUNTIME[english]

    if spell.skill == 'Enhancing Magic' then
        local enhancing_route = resolve_enhancing_route(spell_policy)

        -- Phase B2 resolves known spells from the flat compiled exact-name policy.
        -- Unknown/legacy NoSkillSpells retain the old Mote duration fallback.
        if enhancing_route == 'skill' then
            equip(sets.midcast['Enhancing Magic'])
            equip(sets.midcast.EnhancingSkill)
        elseif enhancing_route == 'duration'
            or classes.NoSkillSpells:contains(english) then
            equip(sets.midcast.EnhancingDuration)
        end

        -- Spell-specific potency pieces are always retained after the broad mode
        -- route. They are the defining bonuses for these spell families.
        if english:startswith('Gain') then
            equip(sets.midcast.GainSpell)
        elseif english:contains('Spikes') then
            equip(sets.midcast.SpikesSpell)
        elseif english == 'Aquaveil' then
            equip(sets.midcast.Aquaveil)
        elseif english == 'Phalanx' then
            equip(sets.midcast['Phalanx'])
        end

        if spellMap == 'Refresh' then
            equip(sets.midcast.Refresh)
            if spell.target.type == 'SELF' then
                equip(sets.midcast.RefreshSelf)
            end
        end

        local cast_on_other = spell.target.type == 'PLAYER' or spell.target.type == 'NPC'
        if cast_on_other and buffactive.Composure then
            equip(sets.buff.ComposureOtherEnhancing)
            -- Refresh potency remains stronger than two additional Lethargy slots.
            if spellMap == 'Refresh' then
                equip({head="Amalric Coif +1", body="Atrophy Tabard +3"})
            end
        end
    end

    -- Treasure Hunter ON: wear TH+3 for any hostile spell (Dia tag from
    -- range, nukes, enfeebles). Last equip wins the ammo/ring1 slots --
    -- deliberately, per the OFF/ON model: when farming, TH beats the
    -- marginal m.acc; when it doesn't, toggle OFF.
    if state.TreasureHunter.value and spell.target and spell.target.type == 'MONSTER' then
        equip(sets.TreasureHunter)
    end

    -- Saboteur is up: hold the empowered hands on for this enfeeble.
    -- (Applied last so it wins over the Composure overlay's hands.)
    if spell.skill == 'Enfeebling Magic' and buffactive.Saboteur then
        equip(sets.buff.Saboteur)
    end

    -- Under Light weather/day the self-cure maps to 'CureWeather', so check both.
    if (spellMap == 'Cure' or spellMap == 'CureWeather') and spell.target.type == 'SELF' then
        equip(sets.midcast.CureSelf)
    end
    if spell.skill == 'Elemental Magic' then
        -- Magic-burst gear is automatic and has no player-facing state. The
        -- detector must validate window time, target, and element at cast time.
        local bursting = sc_burst_window_active(spell)
        if bursting then
            if not (eventArgs and eventArgs._rdm_instant_midcast_preloaded) then
                add_to_chat(158, '[AutoMB] '..spell.english..' bursting on '..tostring(sc_window.name)..' window.')
            end
        end
        if bursting and spell.english ~= 'Death' then
            equip(sets.magic_burst)
            if spell.english == "Impact" then
                equip(sets.midcast.Impact)
            end
        end
        -- Waist: Orpheus's Sash scales +1..15 elemental damage by proximity; use it
        -- inside ~8 yalms. (Obi ladder removed: Hachirin-no-Obi not owned. When
        -- acquired, re-add weather/day branches above this distance check.)
        if spell_target_within(spell, 8) then
            equip({waist="Orpheus's Sash"})
        end
    end

    -- Manual SIRD mode is an explicit final-priority safety overlay. Utsusemi
    -- always receives its dedicated set regardless of CastingMode.
    if spellMap == 'Utsusemi' then
        equip(sets.midcast.Utsusemi)
    elseif state.CastingMode and state.CastingMode.value == 'SIRD'
        and spell.action_type == 'Magic' then
        equip(sets.midcast.SIRD)
    end
end

-- @ai:fn job_aftercast | layer=framework | hot=yes | purity=write | contract=Record JA use, create sleep timers, and restore weapon policy after completed actions.
function job_aftercast(spell, action, spellMap, eventArgs)
    local mb_state_changed = type(mb_confirm_aftercast) == 'function'
        and mb_confirm_aftercast(spell) or false
    if spell.type == 'JobAbility' and ja_tracker[spell.english] and not spell.interrupted then
        ja_tracker[spell.english].used_at = os.time()
    end
    if spell.english:contains('Sleep') and not spell.interrupted then
        set_sleep_timer(spell, spellMap)
    end
    if player.status ~= 'Engaged' and state.WeaponLock.value == false then
        check_weaponset()
    end
    -- MP/recast data changes after any spell. While a formed-chain window is
    -- still live, refresh the F10 choice so a second manual press can select
    -- the next highest ready compatible tier.
    if mb_state_changed or (sc_window and sc_window.name
        and (tonumber(sc_window.expires) or 0) > os.clock()) then
        update_hud()
    end
end

-------------------------------------------------------------------------------------------------------------------
-- Job-specific hooks for non-casting events.
-------------------------------------------------------------------------------------------------------------------

-- Auto Echo Drops with a hard cap of 3 attempts per silence instance.
-- Some silences are item-resistant; this avoids burning the whole stack.
silence_echo = {attempts=0, active=false}

-- @ai:fn try_echo_drops | layer=qol | hot=no | purity=write | contract=Bounded delayed silence recovery; must stop on unload or when silence clears.
function try_echo_drops()
    if RDM_RUNTIME.unloading then return end
    if not buffactive.silence then
        if silence_echo.active and silence_echo.attempts > 0 then
            add_to_chat(158, '** [Silence removed] **')
        end
        silence_echo.active = false
        silence_echo.attempts = 0
        return
    end
    if silence_echo.attempts >= 3 then
        add_to_chat(123, '** [Echo Drops cap (3) hit - silence resisted items. Wait it out or Healing Waltz/ally Silena] **')
        silence_echo.active = false
        return
    end
    silence_echo.attempts = silence_echo.attempts + 1
    send_command('input /item "Echo Drops" <me>')
    add_to_chat(123, '** [Silenced! Echo Drops attempt '..silence_echo.attempts..'/3] **')
    coroutine.schedule(try_echo_drops, 4) -- re-check after item delay
end

-- @ai:fn job_buff_change | layer=framework | hot=yes | purity=write | contract=Central buff invalidation hook for FC/haste/HUD/enspell/ring state.
function job_buff_change(buff,gain)
    -- Normalize once; this event previously lowercased the same buff name up to
    -- four times while handling common status changes.
    local buff_l = buff:lower()

    -- Slept with Stoneskin up: damage ABSORBED by Stoneskin does not break
    -- Sleep, so a stoneskinned RDM sleeps through the hits that should wake
    -- it. Cancel Stoneskin so the next hit wakes us. Gated on Sublimation:
    -- Activated per the source (Pergatory's RDM) -- effectively an "in
    -- serious content" heuristic; delete that condition to make it always-on.
    if buff_l == "sleep" and gain
        and buffactive['Sublimation: Activated'] and buffactive['Stoneskin'] then
        send_command('cancel stoneskin')
        add_to_chat(123, '** [Slept: Stoneskin dropped so damage wakes you] **')
    end

    if buff_l == "silence" then
        if gain and not silence_echo.active then
            silence_echo.active = true
            silence_echo.attempts = 0
            try_echo_drops()
        elseif not gain then
            silence_echo.active = false
            silence_echo.attempts = 0
        end
    end

    if buff_l == "paralysis" and gain then
        add_to_chat(123, '** [Paralyzed - cast Paralyna] **')
    end

    -- Adaptive Fast Cast: a COR's Caster's Roll counts toward the 80% cast cap,
    -- and Chainspell/Spontaneity zero the gear target entirely (instant casts).
    if buff == "Caster's Roll" or buff == 'Chainspell' or buff == 'Spontaneity' then
        update_fc_tier()
    end
    -- Only haste-family buffs can change the visible magic/JA haste buckets.
    -- Unrelated buff events no longer rescan haste state or run delay-cap math.
    if haste_relevant_buffs:contains(buff_l) then
        invalidate_haste_buff_cache()
        local native_changed, overlay_changed = update_native_haste_dw()
        if native_changed and overlay_changed then
            update_dw_overlay()
            if player.status == 'Engaged' and not midaction() then handle_equipping_gear(player.status) end
        end
    end
    update_hud()

    -- Re-evaluate melee gear when an enspell starts or wears (drives EnspellMode Auto)
    if enspell_buff_names:contains(buff) and player.status == 'Engaged' then
        handle_equipping_gear(player.status)
    end

    if buff_l == "doom" then
        if gain then
            equip(sets.buff.Doom)
            send_command('@input /p Doomed.')
            send_command('input /echo ** DOOMED - spam Holy Waters **')
            disable('neck','ring1','ring2','waist')
        else
            if state.PauseSwaps.value then
                -- Full Pause owns every slot. Doom ending must not partially
                -- re-enable neck/rings/waist behind it.
                disable(unpack(all_equip_slots))
            elseif state.FishingMode.value then
                -- Fishing owns only non-ring slots. Restore the normal live-ring
                -- policy after Doom without disturbing the rod or fishing armor.
                disable(unpack(fishing_lock_slots))
                invalidate_ring_lock_cache()
                check_gear()
            else
                enable('neck','ring1','ring2','waist')
                invalidate_ring_lock_cache()
                handle_equipping_gear(player.status)
            end
        end
    end

    -- EXP/CP boost is now active (Dedication/Commitment): release any boost ring so
    -- normal gear returns -- the buff persists without the ring.
    if gain and boost_buffs:contains(buff_l) then
        local slots = {}
        if boost_gear:contains(player.equipment.left_ring)  then slots[#slots+1] = 'ring1' end
        if boost_gear:contains(player.equipment.right_ring) then slots[#slots+1] = 'ring2' end
        release_ring_slots(slots, buff..' active')
    end
end

-- Handle notifications of general user state change.
-- Pause is a full sixteen-slot freeze. Fishing is a partial freeze that owns
-- every slot except ring1/ring2, but both still block atomic control changes.
-- @ai:fn pause_swaps_active | layer=gear | hot=yes | purity=read | contract=Return whether Pause currently owns every equipment slot.
local function pause_swaps_active()
    return state and state.PauseSwaps and state.PauseSwaps.value == true or false
end

-- @ai:fn fishing_mode_active | layer=gear | hot=yes | purity=read | contract=Return whether Fishing currently owns its non-ring slot list.
local function fishing_mode_active()
    return state and state.FishingMode and state.FishingMode.value == true or false
end

-- @ai:fn swaps_frozen | layer=gear | hot=yes | purity=read | contract=Return whether either manual equipment lock is active.
local function swaps_frozen()
    return pause_swaps_active() or fishing_mode_active()
end

-- @ai:fn apply_fishing_slot_policy | layer=gear | hot=no | purity=write | contract=Hold fishing equipment while leaving both rings governed by protected-ring and movement policy.
local function apply_fishing_slot_policy()
    if pause_swaps_active() then
        disable(unpack(all_equip_slots))
        return
    end
    if not fishing_mode_active() then return end

    disable(unpack(fishing_lock_slots))
    if buffactive and buffactive.doom then
        disable('ring1','ring2')
        return
    end
    enable('ring1','ring2')
    -- A prior full Pause/Fishing lock may have left the rings disabled while
    -- the cached policy still says they are enabled. Reopen them, then force
    -- check_gear() to re-lock any actual protected ring immediately.
    invalidate_ring_lock_cache()
    check_gear()
end

-- @ai:fn clear_fishing_rod | layer=gear | hot=no | purity=write | contract=Explicitly empty range before WeaponLock can reclaim the slot on Fishing exit.
local function clear_fishing_rod()
    enable('range')
    equip({range=empty})
end

-- @ai:fn control_state_value | layer=command | hot=no | purity=read | contract=Read one Mote state value for control matching without mutating or formatting it.
local function control_state_value(name)
    local st = state and state[name]
    if not st then return nil end
    if st.value ~= nil then return st.value end
    return st.current
end

-- @ai:fn normalize_control_token | layer=command | hot=no | purity=pure | contract=Normalize typed control aliases without changing canonical mixed-case state keys.
local function normalize_control_token(value)
    return tostring(value or ''):lower():gsub('[%s_%-/]+', '')
end

-- @ai:fn ordered_control_index | layer=command | hot=no | purity=pure | contract=Return the one-based index of a canonical control value, or zero when Custom/unknown.
local function ordered_control_index(order, current)
    for i, value in ipairs(order) do
        if value == current then return i end
    end
    return 0
end

-- @ai:fn playstyle_profile_matches | layer=command | hot=no | purity=read | contract=Return true only while every state owned by the selected playstyle still matches its preset.
local function playstyle_profile_matches(key)
    local profile = RDM_PLAYSTYLE_PROFILES[key]
    if not (profile and state) then return false end
    for _, change in ipairs(profile.modes) do
        if control_state_value(change[1]) ~= change[2] then return false end
    end
    return true
end

-- @ai:fn set_control_state | layer=command | hot=no | purity=write | contract=Set one validated Mote state only when its requested control value differs.
local function set_control_state(name, value)
    local st = state and state[name]
    if not (st and type(st.set) == 'function') then
        error('missing state '..tostring(name))
    end
    if control_state_value(name) ~= value then st:set(value) end
end

-- @ai:fn dual_wield_available | layer=command | hot=no | purity=read | contract=Report whether the current support job can equip a weapon-pair offhand.
local function dual_wield_available()
    if not player then return false end
    local level = tonumber(player.sub_job_level) or 0
    return (player.sub_job == 'NIN' and level >= 10)
        or (player.sub_job == 'DNC' and level >= 20)
end

-- @ai:fn control_item_name | layer=command | hot=no | purity=pure | contract=Return a readable item name from a string or augmented GearSwap item table.
local function control_item_name(item)
    return type(item) == 'table' and item.name or item
end

-- @ai:fn weapon_pair_label | layer=command | hot=no | purity=read | contract=Return the HUD/chat label for a canonical WeaponSet key.
local function weapon_pair_label(weapon_name)
    local meta = RDM_WEAPON_PAIR_META[weapon_name]
    return meta and meta.label or tostring(weapon_name or 'Unknown')
end

-- @ai:fn resolve_weapon_pair_set | layer=command | hot=no | purity=write | contract=Resolve a named weapon pair and apply its objective-specific owned shield when native dual wield is unavailable.
local function resolve_weapon_pair_set(weapon_name)
    local source = sets and sets[weapon_name]
    if not source then return nil, false end
    if dual_wield_available() then return source, false end
    local shield = sets.WeaponShields and sets.WeaponShields[weapon_name]
        or sets.DefaultShield
    local desired = set_combine(source, shield)
    local fallback = control_item_name(source.sub) ~= control_item_name(desired.sub)
    return desired, fallback
end

-- @ai:fn control_action_ready | layer=command | hot=no | purity=read | contract=Reject atomic control work while slot freezes or another action makes a transition unsafe.
local function control_action_ready(key)
    if swaps_frozen() then
        add_to_chat(123, '['..key..'] Blocked while Pause or Fishing Mode owns the equipment slots. Resume swaps first.')
        return false
    end
    if type(midaction) == 'function' and midaction() then
        add_to_chat(123, '['..key..'] Wait for the current spell/ability/WS to finish, then try again.')
        return false
    end
    if not (state and player) then
        add_to_chat(123, '['..key..'] GearSwap state is not ready yet; try again after the Lua finishes loading.')
        return false
    end
    return true
end

-- @ai:fn defense_control_mode | layer=command | hot=yes | purity=read | contract=Translate legacy Mote defense fields into the sole player-facing Normal/DT/MEVA policy.
local function defense_control_mode()
    local internal = control_state_value('DefenseMode') or 'None'
    if internal == 'Physical' then return 'DT' end
    if internal == 'Magical' then
        return control_state_value('MagicalDefenseMode') == 'MEVA' and 'MEVA' or 'DT'
    end
    return 'Normal'
end

-- @ai:fn apply_defense_control | layer=command | hot=no | purity=write | contract=Atomically map Normal/DT/MEVA into stable Mote defense states, refresh gear when safe, and report only the simplified policy.
local function apply_defense_control(requested, source_key, quiet)
    source_key = source_key or 'Ctrl+F3'
    local key = RDM_DEFENSE_ALIASES[normalize_control_token(requested)]
    if not key then
        add_to_chat(158, '[Defense] Ctrl+F3 order: Normal -> DT -> MEVA')
        add_to_chat(158, '[Defense] typed usage: gs c rdmdefense <normal|dt|meva>')
        return false
    end
    if not (state and state.DefenseMode) then
        add_to_chat(123, '['..source_key..' Defense] GearSwap defense state is unavailable.')
        return false
    end

    local ok, err = pcall(function()
        if key == 'Normal' then
            set_control_state('DefenseMode', 'None')
        elseif key == 'DT' then
            if state.PhysicalDefenseMode then
                set_control_state('PhysicalDefenseMode', 'PDT')
            end
            set_control_state('DefenseMode', 'Physical')
        else
            if state.MagicalDefenseMode then
                set_control_state('MagicalDefenseMode', 'MEVA')
            end
            set_control_state('DefenseMode', 'Magical')
        end
    end)
    if not ok then
        add_to_chat(123, '['..source_key..' Defense] Apply failed: '..tostring(err))
        return false
    end

    -- Direct Mode:set calls do not invoke Mote's job_state_change callback.
    -- Preserve the established rule that manual policy changes expose Custom.
    local playstyle_key = control_state_value('Playstyle')
    if playstyle_key and playstyle_key ~= 'Custom'
        and not playstyle_profile_matches(playstyle_key) then
        applying_playstyle = true
        state.Playstyle:set('Custom')
        applying_playstyle = false
    end

    update_fc_tier(false, true)
    if not swaps_frozen()
        and not (type(midaction) == 'function' and midaction())
        and type(handle_equipping_gear) == 'function' and player then
        handle_equipping_gear(player.status)
    end
    update_hud(true)

    if not quiet then
        local purpose = key == 'Normal' and 'standard idle/engaged policy'
            or (key == 'DT' and 'full damage-taken set' or 'full magic-evasion set')
        add_to_chat(158, string.format('[%s Defense] %s (%d/%d) - %s',
            source_key, key, ordered_control_index(RDM_DEFENSE_ORDER, key),
            #RDM_DEFENSE_ORDER, purpose))
    end
    return true
end

-- @ai:fn cycle_defense_control | layer=command | hot=no | purity=write | contract=Advance the one Ctrl+F3 defense order Normal -> DT -> MEVA.
local function cycle_defense_control(source_key)
    local index = ordered_control_index(RDM_DEFENSE_ORDER, defense_control_mode())
    index = (index % #RDM_DEFENSE_ORDER) + 1
    return apply_defense_control(RDM_DEFENSE_ORDER[index], source_key or 'Ctrl+F3')
end

-- @ai:fn schedule_control_refresh | layer=command | hot=no | purity=write | contract=Re-sample equipment-driven DW/haste once after a weapon/playstyle equip packet, invalidating stale scheduled work by controller generation.
local function schedule_control_refresh(kind)
    local generation
    if kind == 'weapon' then
        weapon_cycle_generation = weapon_cycle_generation + 1
        generation = weapon_cycle_generation
    else
        playstyle_generation = playstyle_generation + 1
        generation = playstyle_generation
    end
    coroutine.schedule(function()
        if RDM_RUNTIME.unloading then return end
        if kind == 'weapon' and generation ~= weapon_cycle_generation then return end
        if kind ~= 'weapon' and generation ~= playstyle_generation then return end
        if swaps_frozen() or (type(midaction) == 'function' and midaction()) then return end
        if type(update_native_haste_dw) == 'function' then update_native_haste_dw(true) end
        if type(update_combat_form) == 'function' then update_combat_form() end
        if type(update_dw_overlay) == 'function' then update_dw_overlay() end
        if type(handle_equipping_gear) == 'function' and player then
            handle_equipping_gear(player.status)
        end
        update_hud(true)
    end, 0.35)
end

-- @ai:fn apply_weapon_pair | layer=command | hot=no | purity=write | contract=Apply one canonical weapon combination immediately, preserve the current playstyle's WeaponLock policy, and use shield fallback without changing modes.
local function apply_weapon_pair(requested, source_key, quiet, skip_guard)
    source_key = source_key or 'Weapon'
    if not skip_guard and not control_action_ready(source_key) then return false end
    if not (state and sets and player and state.WeaponSet and state.WeaponLock) then
        add_to_chat(123, '['..source_key..' Weapon] Weapon states/sets are unavailable.')
        return false
    end

    local key = RDM_WEAPON_PAIR_META[requested] and requested
        or RDM_WEAPON_PAIR_ALIASES[normalize_control_token(requested)]
    local desired, shield_fallback
    if key then desired, shield_fallback = resolve_weapon_pair_set(key) end
    if not (key and desired) then
        add_to_chat(158, '[Weapon] order: Crocea/Daybreak -> Crocea/TP -> Naegling/Blurred -> Naegling/TP -> Maxentius/Blurred -> Maxentius/TP -> Tauret/Blurred -> Naegling/TP/Kaja Bow -> Daybreak/Shield')
        add_to_chat(158, '[Weapon] typed usage: gs c rdmweapon <next|previous|pair name>')
        return false
    end

    applying_weapon_pair = true
    local ok, err = pcall(function() set_control_state('WeaponSet', key) end)
    applying_weapon_pair = false
    if not ok then
        add_to_chat(123, '['..source_key..' Weapon] Apply failed: '..tostring(err))
        return false
    end

    -- The weapon controller owns only the combination. Caster playstyle leaves
    -- the slots open; every other playstyle re-locks the selected combination
    -- after the equip lands.
    enable('main','sub','range')
    equip(desired)
    local weapon_locked = control_state_value('WeaponLock') == true
    if weapon_locked then disable('main','sub','range') end
    if type(handle_equipping_gear) == 'function' then handle_equipping_gear(player.status) end
    update_hud(true)

    if not quiet then
        local meta = RDM_WEAPON_PAIR_META[key]
        local fallback_note = shield_fallback
            and (' [shield fallback: '..tostring(control_item_name(desired.sub))..'; no native DW]') or ''
        local desired_range = control_item_name(desired.range)
        local range_note = desired_range and desired_range ~= '' and desired_range ~= 'empty'
            and (' | Range '..tostring(desired_range)) or ''
        local desired_ammo = control_item_name(desired.ammo)
        local ammo_note = desired_ammo and desired_ammo ~= '' and desired_ammo ~= 'empty'
            and (' | Ammo '..tostring(desired_ammo)) or ''
        add_to_chat(158, string.format('[%s Weapon] %s | %s / %s%s%s%s',
            source_key, meta.label,
            control_item_name(desired.main) or '(unchanged)',
            control_item_name(desired.sub) or '(empty)', range_note, ammo_note, fallback_note))
        add_to_chat(158, '[Weapon] '..meta.purpose..' | primary WS '..meta.primary_ws
            ..' | WeaponLock '..(weapon_locked and 'ON' or 'off'))
    end
    schedule_control_refresh('weapon')
    return true
end

-- @ai:fn cycle_weapon_pair | layer=command | hot=no | purity=write | contract=Advance/reverse only the canonical weapon order and delegate the atomic equip to apply_weapon_pair.
local function cycle_weapon_pair(direction, source_key)
    local current = control_state_value('WeaponSet')
    local index = ordered_control_index(RDM_WEAPON_PAIR_ORDER, current)
    local step = (direction == 'previous' or direction == 'prev' or direction == 'back') and -1 or 1
    if index == 0 then
        index = step > 0 and 0 or 1
    end
    index = ((index - 1 + step) % #RDM_WEAPON_PAIR_ORDER) + 1
    return apply_weapon_pair(RDM_WEAPON_PAIR_ORDER[index], source_key or 'Weapon')
end

-- @ai:fn apply_playstyle | layer=command | hot=no | purity=write | contract=Apply one playstyle gear-policy bundle without changing WeaponSet; reassert the selected pair before restoring its lock policy.
local function apply_playstyle(requested, source_key, quiet, skip_guard)
    source_key = source_key or 'Playstyle'
    if not skip_guard and not control_action_ready(source_key) then return false end
    local key = RDM_PLAYSTYLE_PROFILES[requested] and requested
        or RDM_PLAYSTYLE_ALIASES[normalize_control_token(requested)]
    local profile = key and RDM_PLAYSTYLE_PROFILES[key] or nil
    if not profile then
        add_to_chat(158, '[Playstyle] order: Balanced -> Max TP -> Max Enspell -> Damage Taken -> Magic Evasion -> Hard Target -> Caster/Burst')
        add_to_chat(158, '[Playstyle] typed usage: gs c rdmplay <next|previous|balanced|maxtp|enspell|dt|meva|accuracy|caster>')
        return false
    end
    if not (state and sets and player and state.Playstyle and state.WeaponSet) then
        add_to_chat(123, '['..source_key..' Playstyle] GearSwap state is unavailable.')
        return false
    end

    -- Validate the entire bundle and currently selected pair before mutating
    -- anything, so a typo/missing state cannot leave a half-applied playstyle.
    for _, change in ipairs(profile.modes) do
        local st = state[change[1]]
        if not (st and type(st.set) == 'function') then
            add_to_chat(123, '['..source_key..' Playstyle] Missing state: '..tostring(change[1]))
            return false
        end
    end
    local selected_weapon = control_state_value('WeaponSet') or RDM_DEFAULT_WEAPON_SET
    local desired, shield_fallback = resolve_weapon_pair_set(selected_weapon)
    if not desired then
        add_to_chat(123, '['..source_key..' Playstyle] Missing selected weapon set: '..tostring(selected_weapon))
        return false
    end

    applying_playstyle = true
    local ok, err = pcall(function()
        set_control_state('Playstyle', key)
        for _, change in ipairs(profile.modes) do
            set_control_state(change[1], change[2])
        end
    end)
    applying_playstyle = false
    if not ok then
        add_to_chat(123, '['..source_key..' Playstyle] Apply failed: '..tostring(err))
        update_hud(true)
        return false
    end

    -- Returning from Caster must not lock a transient spell weapon. Re-equip
    -- the independently selected weapon pair first, then restore the new policy.
    -- Direct Mode:set calls do not invoke job_state_change, so refresh the
    -- defense-aware Fast Cast shed order explicitly before rebuilding gear.
    update_fc_tier(false, true)
    enable('main','sub','range')
    equip(desired)
    local weapon_locked = control_state_value('WeaponLock') == true
    if weapon_locked then disable('main','sub','range') end
    if type(handle_equipping_gear) == 'function' then handle_equipping_gear(player.status) end
    update_hud(true)

    if not quiet then
        local fallback_note = shield_fallback
            and (' | '..tostring(control_item_name(desired.sub))..' shield fallback active') or ''
        add_to_chat(158, string.format('[%s Playstyle] %s (%d/%d)%s',
            source_key, profile.label,
            ordered_control_index(RDM_PLAYSTYLE_ORDER, key),
            #RDM_PLAYSTYLE_ORDER, fallback_note))
        add_to_chat(158, '[Playstyle] '..profile.summary
            ..' | Weapon '..weapon_pair_label(selected_weapon))
    end
    schedule_control_refresh('playstyle')
    return true
end

-- @ai:fn cycle_playstyle | layer=command | hot=no | purity=write | contract=Advance/reverse only the canonical playstyle order; Custom always enters at Balanced.
local function cycle_playstyle(direction, source_key)
    local current = control_state_value('Playstyle')
    local index = ordered_control_index(RDM_PLAYSTYLE_ORDER, current)
    local step = (direction == 'previous' or direction == 'prev' or direction == 'back') and -1 or 1
    if index == 0 then
        index = step > 0 and 0 or 1
    end
    index = ((index - 1 + step) % #RDM_PLAYSTYLE_ORDER) + 1
    return apply_playstyle(RDM_PLAYSTYLE_ORDER[index], source_key or 'Playstyle')
end

-- @ai:fn issue_target_weaponskill | layer=command | hot=no | purity=write | contract=Validate the shared manual-WS safety gates and issue one named WS without changing weapons; optionally preserve F11 context until its completion packet confirms execution.
local function issue_target_weaponskill(ws_name, source_label, loadout_note, preserve_sc_context)
    source_label = source_label or 'Manual WS'
    if not control_action_ready(source_label) then return false end
    if (tonumber(player.tp) or 0) < 1000 then
        add_to_chat(123, '['..source_label..'] Need 1000 TP for '..tostring(ws_name)
            ..' (current '..tostring(player.tp or 0)..')'
            ..(loadout_note and (' | '..loadout_note) or '')..'.')
        return false
    end
    local target = windower and windower.ffxi and windower.ffxi.get_mob_by_target
        and windower.ffxi.get_mob_by_target('t') or nil
    if not target or (target.hpp ~= nil and tonumber(target.hpp) and tonumber(target.hpp) <= 0) then
        add_to_chat(123, '['..source_label..'] No valid living <t> target.')
        return false
    end
    -- Standalone F12 intentionally replaces any old closer context. F11 passes
    -- preserve_sc_context=true so a rejected/late command cannot erase the
    -- opportunity before the game confirms that its selected WS completed.
    if not preserve_sc_context and sc_cancel then
        sc_cancel('manual '..tostring(ws_name))
    end
    send_command('@input /ws "'..tostring(ws_name)..'" <t>')
    return true
end

-- @ai:fn resolve_context_weaponskill | layer=command | hot=no | purity=read | contract=Choose the canonical primary WS from the live range/main/sub combination, giving an equipped Kaja Bow priority without changing gear.
local function resolve_context_weaponskill()
    local equipment = player and player.equipment or {}
    local main_name = control_item_name(equipment.main)
    local sub_name = control_item_name(equipment.sub)
    local range_name = control_item_name(equipment.range)

    -- A live ranged weapon is authoritative for a ranged-WS profile. This check
    -- must precede main/sub matching because KajaBow intentionally shares the
    -- Naegling/TP Bonus melee pair with an existing Savage Blade profile.
    local ranged_ws = RDM_CONTEXT_WS_BY_RANGE[range_name]
    if ranged_ws then
        return ranged_ws, 'KajaBow', main_name, sub_name, range_name
    end

    -- Exact pair resolution preserves the one meaningful offhand distinction:
    -- Crocea + Machaera TP Bonus uses Seraph Blade instead of CDC.
    for _, weapon_key in ipairs(RDM_WEAPON_PAIR_ORDER) do
        local ws_name = RDM_CONTEXT_WS_BY_WEAPON_SET[weapon_key]
        local desired = ws_name and resolve_weapon_pair_set(weapon_key) or nil
        if desired
            and control_item_name(desired.main) == main_name
            and control_item_name(desired.sub) == sub_name then
            return ws_name, weapon_key, main_name, sub_name, range_name
        end
    end

    -- A recognized main hand remains authoritative if the player manually
    -- changes the offhand. Unknown/casting weapons deliberately have no guess.
    return RDM_CONTEXT_WS_BY_MAIN[main_name], nil, main_name, sub_name, range_name
end

-- @ai:fn execute_context_weaponskill | layer=command | hot=no | purity=write | contract=Make plain F12 fire the primary WS for the equipped canonical weapon combination without swapping or resetting gear.
local function execute_context_weaponskill()
    local ws_name, _, main_name, sub_name, range_name = resolve_context_weaponskill()
    local loadout_note = tostring(main_name or '(empty)')..' / '..tostring(sub_name or '(empty)')
    if range_name and range_name ~= '' and range_name ~= 'empty' then
        loadout_note = loadout_note..' | range '..tostring(range_name)
    end
    if not ws_name then
        add_to_chat(123, '[F12 WS] No WS mapping for equipped weapons: '..loadout_note
            ..'. F12 did not change weapons or spend TP.')
        return false
    end
    return issue_target_weaponskill(ws_name, 'F12 WS', loadout_note)
end

-- @ai:fn reset_rdm_controls | layer=command | hot=no | purity=write | contract=Typed reset restores Crocea/Daybreak + Balanced defaults while preserving manual Treasure Hunter.
local function reset_rdm_controls()
    if not control_action_ready('Reset') then return false end
    if not apply_playstyle(RDM_DEFAULT_PLAYSTYLE, 'Reset', true, true) then return false end
    if not apply_weapon_pair(RDM_DEFAULT_WEAPON_SET, 'Reset', true, true) then return false end
    add_to_chat(158, '[Reset] Crocea / Daybreak + Balanced restored; TH preserved.')
    update_hud(true)
    return true
end

-- @ai:fn set_ranged_lock | layer=command | hot=no | purity=write | contract=Typed-only toggle/set/query for ordinary ranged-attack ammo safety; never blocks ranged weapon skills.
local function set_ranged_lock(request)
    if not (state and state.RangedLock and type(state.RangedLock.set) == 'function') then
        add_to_chat(123, '[Ammo safety] Ranged Lock state is unavailable.')
        return false
    end

    local token = normalize_control_token(request)
    local current = state.RangedLock.value == true
    local desired
    if token == '' or token == 'toggle' then
        desired = not current
    elseif token == 'on' or token == 'enable' or token == 'enabled' or token == 'safe' then
        desired = true
    elseif token == 'off' or token == 'disable' or token == 'disabled' or token == 'live' then
        desired = false
    elseif token == 'status' or token == 'show' or token == 'check' then
        desired = current
    else
        add_to_chat(123, '[Ammo safety] Usage: gs c rangedlock [toggle|on|off|status]')
        return false
    end

    if desired ~= current then
        state.RangedLock:set(desired)
    end
    add_to_chat(desired and 158 or 167, desired
        and '[Ammo safety] ON - ordinary /ra is blocked; ranged weapon skills remain allowed.'
        or '[Ammo safety] OFF - ordinary /ra is allowed and may consume equipped ammo.')
    update_hud()
    return true
end

-- @ai:fn resume_swaps | layer=gear | hot=no | purity=write | contract=Restore normal slots after the final lock clears, or reassert Fishing's ring-aware partial lock.
function resume_swaps(msg)
    if pause_swaps_active() then
        disable(unpack(all_equip_slots))
        return
    end
    if fishing_mode_active() then
        apply_fishing_slot_policy()
        return
    end
    enable(unpack(all_equip_slots))
    invalidate_ring_lock_cache()
    -- Reassert the selected weapon pair before restoring WeaponLock. Otherwise a
    -- pause/fishing release could lock whatever transient weapon happened to be
    -- worn when the freeze began.
    local selected = control_state_value('WeaponSet') or RDM_DEFAULT_WEAPON_SET
    local desired = resolve_weapon_pair_set(selected)
    if desired then equip(desired) end
    if state.WeaponLock.value == true then
        disable('main','sub','range')
    end
    check_gear()
    handle_equipping_gear(player.status)
    if msg then add_to_chat(158, msg) end
end

-- @ai:fn job_state_change | layer=framework | hot=yes | purity=write | contract=State invalidation hub; preserve Pause/Fishing freeze ordering and coordinated weapon/playstyle controllers.
function job_state_change(stateField, newValue, oldValue)
    -- Typed CasterRollFC cycling changed the assumed roll value: retarget FC.
    -- (Mote passes the state's description string; check the raw name too.)
    if stateField == 'Caster Roll FC Assumption' or stateField == 'CasterRollFC' then
        update_fc_tier(true)
    end

    -- Defense DT/MEVA toggled: same FC target, but sheds re-walk in
    -- DT-priority order (Nyame slots first). The build key catches this.
    if stateField == 'Defense Mode' then
        update_fc_tier()
    end

    -- Generic Mote commands/sidecars that set these states directly still use
    -- the same safe weapon/playstyle controllers. The controller flags prevent the
    -- state mutations inside those batches from recursively re-entering here.
    if not applying_weapon_pair
        and (stateField == 'WeaponSet' or stateField == 'Weapon Set') then
        apply_weapon_pair(newValue, 'WeaponSet')
        return
    end
    if not applying_playstyle
        and (stateField == 'Playstyle' or stateField == 'Playstyle Lock')
        and newValue ~= 'Custom' then
        apply_playstyle(newValue, 'Playstyle')
        return
    end

    -- Playstyles are descriptive gear-policy locks, not sticky automation. A
    -- manual change to a controlled gear state immediately exposes Custom;
    -- unrelated choices such as manual TH remain independent.
    local playstyle_key = control_state_value('Playstyle')
    if not applying_playstyle and playstyle_key and playstyle_key ~= 'Custom'
        and not playstyle_profile_matches(playstyle_key) then
        applying_playstyle = true
        state.Playstyle:set('Custom')
        applying_playstyle = false
    end

    update_hud()

    -- The independent controllers own their final equip/lock pass. Suppress
    -- normal per-state weapon handling while either coordinated batch runs.
    if applying_playstyle or applying_weapon_pair then return end

    -- Alt+F3: freeze/unfreeze every gear slot at once.
    -- (Mote passes the state's description string, so match it as well as the raw name.)
    if stateField == 'PauseSwaps' or stateField == 'Pause Gear Swapping (Fish/Craft)' then
        if state.PauseSwaps.value == true then
            disable(unpack(all_equip_slots))
            add_to_chat(167, '** [GearSwap PAUSED -- all auto gear swapping OFF] **')
        elseif state.FishingMode.value then
            apply_fishing_slot_policy()
            if moving and type(midaction) == 'function' and not midaction()
                and type(handle_equipping_gear) == 'function' and player then
                handle_equipping_gear(player.status)
                apply_fishing_slot_policy()
            end
            add_to_chat(158, '** [Pause off -- Fishing remains; movement/protected rings active] **')
        else
            resume_swaps('** [GearSwap RESUMED -- auto gear swapping ON] **')
        end
        return
    end

    -- FISHING MODE (Alt+F2): equip the fishing set, then freeze every slot
    -- except ring1/ring2. The live rings retain no-swap Warp/Dimensional
    -- protection and native Shneddick movement behavior. Pause is still the
    -- stronger owner when both states are on.
    if stateField == 'FishingMode' or stateField == 'Fishing Mode' then
        if state.FishingMode.value == true then
            enable(unpack(all_equip_slots))
            equip(sets.Fishing)
            if pause_swaps_active() then
                disable(unpack(all_equip_slots))
                add_to_chat(167, '** [FISHING MODE -- rod equipped; Pause keeps all slots frozen] **')
            else
                apply_fishing_slot_policy()
                -- If Fishing was enabled while already moving, resolve the
                -- live rings immediately instead of waiting for a new position
                -- transition. Stationary rings are deliberately left as worn.
                if moving and type(midaction) == 'function' and not midaction()
                    and type(handle_equipping_gear) == 'function' and player then
                    handle_equipping_gear(player.status)
                    apply_fishing_slot_policy()
                end
                add_to_chat(167, '** [FISHING MODE -- rod/armor held; movement and protected rings active] **')
            end
        elseif state.PauseSwaps.value then
            clear_fishing_rod()
            disable(unpack(all_equip_slots))
            add_to_chat(158, '** [Fishing off -- rod cleared; still frozen by Pause (Alt+F3)] **')
        else
            clear_fishing_rod()
            resume_swaps('** [Fishing off -- gear swapping resumed] **')
        end
        return
    end

    -- Unrelated state changes must preserve the active lock's exact ownership:
    -- Pause owns every slot; Fishing owns every non-ring slot.
    if pause_swaps_active() then
        disable(unpack(all_equip_slots))
        return
    end
    if fishing_mode_active() then
        apply_fishing_slot_policy()
        return
    end

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

-- Called by the 'update' self-command, for common needs.
-- Set eventArgs.handled to true if we don't want automatic equipping of gear.
-- @ai:fn job_handle_equipping_gear | layer=framework | hot=yes | purity=write | contract=Pre-resolution hook; refresh ring/combat/haste/movement state before Mote selects gear.
function job_handle_equipping_gear(playerStatus, eventArgs)
    check_gear()
    update_combat_form()
    determine_haste_group()
    check_moving()
end

-- @ai:fn job_update | layer=framework | hot=no | purity=write | contract=Force current-status gear resolution through Mote.
function job_update(cmdParams, eventArgs)
    handle_equipping_gear(player.status)
end

-- CombatForm 'DW' selects the sets.engaged.DW.* family. Native tracking owns
-- DW now; GearInfo is retained only as an optional cross-check feed.
-- @ai:fn update_combat_form | layer=gear | hot=yes | purity=write | contract=Mirror authoritative DW boolean into Mote CombatForm only.
function update_combat_form()
    if DW == true then
        state.CombatForm:set('DW')
    else
        state.CombatForm:reset()
    end
end

-- Custom spell mapping.
-- @ai:fn job_get_spell_map | layer=framework | hot=yes | purity=read | contract=Route spells through one exact compiled-policy lookup plus static resolvers; never scan policy tables or allocate dynamic route names.
function job_get_spell_map(spell, default_spell_map)
    if spell.action_type ~= 'Magic' then return end

    local skill = spell.skill
    local english = spell.english
    local policy = RDM_SPELL_RUNTIME[english]
    if default_spell_map == 'Cure' or default_spell_map == 'Curaga' then
        if world.weather_element == 'Light' or world.day_element == 'Light' then
            return 'CureWeather'
        end
    end

    if skill == 'Enhancing Magic' then
        if policy and policy.direct_map then return policy.direct_map end
    elseif skill == 'Enfeebling Magic' then
        local mode = state.EnfeeblingMode and state.EnfeeblingMode.value or 'Auto'
        return resolve_enfeebling_spell_map(
            policy,
            spell.type,
            mode,
            not not buffactive.Stymie)
    end
end

-- @ai:fn get_custom_wsmode | layer=framework | hot=yes | purity=read | contract=Use OffenseMode as the sole normal/accuracy WS policy; independent WS modes are retired.
function get_custom_wsmode(spell, spellMap, default_wsmode)
    if state.OffenseMode.value == 'MidAcc' or state.OffenseMode.value == 'HighAcc' then
        return 'Acc'
    end
end

-- Reusable overlay scratch tables keep hot gear-resolution paths from allocating
-- one temporary table for every conditional overlay. set_combine() copies the
-- scratch contents into its result before these tables are reused.
local idle_overlay_scratch = {}
local melee_overlay_scratch = {}

-- @ai:fn clear_overlay_scratch | layer=gear | hot=yes | purity=write | contract=Clear reusable overlay table in place; never return/store the scratch itself as a gear set.
local function clear_overlay_scratch(t)
    for k in pairs(t) do t[k] = nil end
end

-- @ai:fn merge_overlay_scratch | layer=gear | hot=yes | purity=write | contract=Copy one gear overlay into reusable scratch preserving later-overlay-wins ordering.
local function merge_overlay_scratch(dst, src)
    if not src then return end
    for k, v in pairs(src) do dst[k] = v end
end

-- Modify the default idle set after it was constructed.
-- @ai:fn customize_idle_set | layer=gear | hot=yes | purity=write | contract=Apply idle policy overlays with at most one set_combine allocation; preserve protected-ring checks.
function customize_idle_set(idleSet)
    perf_count('idle_resolutions')
    local perf_t = perf_begin()
    clear_overlay_scratch(idle_overlay_scratch)
    local has_overlay = false

    if player.mpp < 51 then
        merge_overlay_scratch(idle_overlay_scratch, sets.latent_refresh)
        has_overlay = true
    end

    if monitor_state.hp_lean then
        merge_overlay_scratch(idle_overlay_scratch, sets.idle.DT)
        has_overlay = true
    end
    -- if state.CP.current == 'on' then
    --     equip(sets.CP)
    --     disable('back')
    -- else
    --     enable('back')
    -- end

    if state.Auto_Kite.value == true then
        -- Normal/Town idle already wear Carmine movement legs. Only spend a
        -- Refresh ring slot when the resolved idle legs (DT/HP lean) lack speed.
        -- During Fishing the resolved idle legs are disabled behind Fisherman's
        -- Hose, so force the live Shneddick ring instead of trusting that
        -- projected Carmine slot.
        local effective_legs = idle_overlay_scratch.legs or idleSet.legs
        if fishing_mode_active()
            or item_stat(dw_item_name(effective_legs), 'movement') <= 0 then
            merge_overlay_scratch(idle_overlay_scratch, sets.Kiting)
            has_overlay = true
        end
    end

    -- A selected ranged-weapon profile must retain real ammunition after the
    -- idle armor set resolves. Apply this last so DT/refresh/movement ammo does
    -- not replace the Chapuli Arrow declared by sets.KajaBow.
    if control_state_value('WeaponSet') == 'KajaBow' then
        merge_overlay_scratch(idle_overlay_scratch, sets.KajaBowAmmo)
        has_overlay = true
    end

    if has_overlay then
        idleSet = set_combine(idleSet, idle_overlay_scratch)
    end

    check_gear()
    perf_finish('idle_resolution', perf_t)
    return idleSet
end

-- Modify the default melee set after it was constructed.
-- @ai:fn customize_melee_set | layer=gear | hot=yes | purity=write | contract=Preserve active Mote Defense; otherwise apply indexed engaged base + DW/DT/resolved-Enspell/TH overlays.
function customize_melee_set(meleeSet)
    perf_count('melee_resolutions')
    local perf_t = perf_begin()

    -- Mote applies Defense after resolving the TP hierarchy and before calling
    -- this hook. Preserve that supplied set verbatim while DT/MEVA is active.
    -- Replacing it with engaged_set_index here was the v2.46 regression that
    -- made Ctrl+F3 change state/HUD without changing engaged equipment.
    -- Native movement is intentionally suppressed by emergency Defense. All
    -- normal melee overlays resume when Defense returns to Normal.
    if defense_control_mode() ~= 'Normal' then
        if control_state_value('WeaponSet') == 'KajaBow' then
            meleeSet = set_combine(meleeSet, sets.KajaBowAmmo)
        end
        perf_count('engaged_defense_preserved')
        check_gear()
        check_weaponset()
        perf_finish('melee_resolution', perf_t)
        return meleeSet
    end

    -- Act 4: select the already-built base set directly. This mirrors Mote's
    -- CombatForm -> OffenseMode -> HybridMode hierarchy, but avoids repeated
    -- string/path resolution on every engaged refresh. Any unexpected custom
    -- mode safely falls back to the set Mote supplied.
    local form = (state.CombatForm and state.CombatForm.value == 'DW') and 'DW' or 'Normal'
    local offense = state.OffenseMode and state.OffenseMode.value or 'Normal'
    local hybrid = state.HybridMode and state.HybridMode.value or 'Normal'
    local form_index = engaged_set_index and engaged_set_index[form]
    local offense_index = form_index and form_index[offense]
    local indexed_set = offense_index and offense_index[hybrid]
    if indexed_set then
        meleeSet = indexed_set
        perf_count('engaged_index_hits')
    else
        perf_count('engaged_index_fallbacks')
    end

    -- Build every conditional override into one reusable table, preserving the
    -- exact policy precedence: Enspell -> TH -> HP lean -> adaptive DW -> movement.
    -- This turns up to four set_combine() allocations into at most one.
    clear_overlay_scratch(melee_overlay_scratch)
    local has_overlay = false

    local enspell_set = resolved_enspell_melee_set()
    if enspell_set then
        merge_overlay_scratch(melee_overlay_scratch, enspell_set)
        has_overlay = true
    end

    local th_enabled = state.TreasureHunter.value == true
    if th_enabled then
        merge_overlay_scratch(melee_overlay_scratch, sets.TreasureHunter)
        has_overlay = true
    end

    if monitor_state.hp_lean then
        merge_overlay_scratch(melee_overlay_scratch, sets.engaged.Hybrid)
        has_overlay = true
    end

    -- Resolve Adaptive Dual Wield before the final movement-speed check. When a DW piece is not required,
    -- only strip it if it would otherwise still be the effective item after the
    -- earlier overlays; this preserves Acc/DT/Enspell choices in freed slots.
    if form == 'DW' then
        for _, e in ipairs(dw_pool) do
            if e.active then
                melee_overlay_scratch[e.slot] = e.piece
                has_overlay = true
            else
                local effective = melee_overlay_scratch[e.slot]
                if effective == nil then effective = meleeSet[e.slot] end
                if dw_item_name(effective) == e.piece then
                    melee_overlay_scratch[e.slot] = e.off
                    has_overlay = true
                end
            end
        end

        melee_overlay_scratch.back = dw_cape_active and capes.dw or capes.da
        has_overlay = true

        if dw_sailfi_active then
            melee_overlay_scratch.waist = "Sailfi Belt +1"
            has_overlay = true
        else
            local effective_waist = melee_overlay_scratch.waist
            if effective_waist == nil then effective_waist = meleeSet.waist end
            if dw_item_name(effective_waist) == "Sailfi Belt +1" then
                melee_overlay_scratch.waist = "Windbuffet Belt +1"
                has_overlay = true
            end
        end
    end

    -- Native movement detection owns Auto_Kite. If adaptive DW already selected
    -- Carmine movement legs, no ring is spent. Otherwise TH uses the explicit
    -- two-ring overlay so Shneddick can never overwrite Hoxne.
    if state.Auto_Kite.value == true then
        local effective_legs = melee_overlay_scratch.legs or meleeSet.legs
        if fishing_mode_active()
            or item_stat(dw_item_name(effective_legs), 'movement') <= 0 then
            merge_overlay_scratch(melee_overlay_scratch,
                th_enabled and sets.TreasureHunterKiting or sets.Kiting)
            has_overlay = true
        end
    end

    -- Ammunition is part of the Kaja Bow profile. Keep this final so adaptive
    -- DW, movement, HP lean, and Treasure Hunter cannot displace Chapuli Arrow.
    if control_state_value('WeaponSet') == 'KajaBow' then
        merge_overlay_scratch(melee_overlay_scratch, sets.KajaBowAmmo)
        has_overlay = true
    end

    if has_overlay then
        meleeSet = set_combine(meleeSet, melee_overlay_scratch)
    end

    check_gear()

    -- Weapon reassert is safe here: WeaponLock (Ctrl+F11) is the supported way to
    -- protect manually equipped weapons; when locked, this call is a no-op.
    check_weaponset()

    perf_finish('melee_resolution', perf_t)
    return meleeSet
end

-- Function to display the current relevant user state when doing an update.
-- Return true if display was handled, and you don't want the default info shown.
-- @ai:fn display_current_job_state | layer=framework | hot=no | purity=write | contract=Chat-only mode report and eventArgs.handled ownership.
function display_current_job_state(eventArgs)
    local cf_msg = ''
    if state.CombatForm.has_value then
        cf_msg = ' (' ..state.CombatForm.value.. ')'
    end

    local m_msg = state.OffenseMode.value
    if state.HybridMode.value ~= 'Normal' then
        m_msg = m_msg .. '/' ..state.HybridMode.value
    end

    local c_msg = state.CastingMode.value
    local d_msg = defense_control_mode()

    local i_msg = state.IdleMode.value

    local weapon_msg = weapon_pair_label(control_state_value('WeaponSet'))
    local playstyle_key = control_state_value('Playstyle') or 'Custom'
    local playstyle_profile = RDM_PLAYSTYLE_PROFILES[playstyle_key]
    local playstyle_msg = playstyle_profile and playstyle_profile.label or playstyle_key

    add_to_chat(002, '| ' ..string.char(31,200).. 'Weapon: ' ..string.char(31,001)..weapon_msg.. string.char(31,002).. ' |'
        ..string.char(31,200).. ' Style: ' ..string.char(31,001)..playstyle_msg.. string.char(31,002).. ' |'
        ..string.char(31,210).. ' Melee' ..cf_msg.. ': ' ..string.char(31,001)..m_msg.. string.char(31,002)..  ' |'
        ..string.char(31,060).. ' Magic: ' ..string.char(31,001)..c_msg.. string.char(31,002)..  ' |'
        ..string.char(31,004).. ' Defense: ' ..string.char(31,001)..d_msg.. string.char(31,002)..  ' |'
        ..string.char(31,008).. ' Idle: ' ..string.char(31,001)..i_msg.. string.char(31,002)..  ' |')

    eventArgs.handled = true
end

-------------------------------------------------------------------------------------------------------------------
-- Utility functions specific to this job.
-------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Permanent RDM progression baseline (v2.14)
--
-- User profile assumptions:
--   * RDM Job Master: 2100 JP, every JP category at rank 20, all Gifts unlocked
--   * Master Level 23
--   * General merits capped for HP, MP, all seven attributes, all combat skills,
--     and all magic skills. Job-specific RDM Group 1/2 merit ALLOCATION is NOT
--     guessed here because those categories require choices; runtime merit data
--     remains authoritative for those effects (e.g. sleep-duration math).
--
-- This table intentionally describes guaranteed PROGRESSION bonuses and RDM
-- skill baselines, not race-dependent naked attributes/HP/MP. Future potency,
-- accuracy and future role math should query this module instead of duplicating
-- JP/Gift/Master-Level constants in multiple systems.
-------------------------------------------------------------------------------
RDM_PROGRESSION = {
    job_master = true,
    jp_spent = 2100,
    master_level = 23,
    merits = {
        hp = 15, mp = 15,
        attributes = 15,      -- each of STR/DEX/VIT/AGI/INT/MND/CHR
        combat_skill = 8,     -- +2 skill each rank = +16
        magic_skill = 8,      -- +2 skill each rank = +16
    },
    gifts = {
        fast_cast = 8,
        enhancing_skill = 36,
        enfeebling_skill = 36,
        magic_accuracy = 70,
        magic_attack = 28,
        magic_defense = 28,
        magic_evasion = 52,
        physical_accuracy = 22,
        enspell_damage = 23,
    },
    -- All RDM JP categories are rank 20 at Job Master. Static/conditional
    -- bonuses are kept separate from Gifts so downstream math can explain
    -- exactly where a number came from.
    jp = {
        magic_accuracy = 20,
        magic_attack = 20,
        composure_accuracy = 20,
        saboteur_magic_accuracy = 40,
        enfeebling_duration_seconds = 20,
        enhancing_duration_seconds = 20,
        stymie_duration_seconds = 20,
        chainspell_elemental_damage = 40,
        convert_hp_reduction_pct = 20,
        quick_magic_mp_reduction_pct = 40,
    },
}

-- Level-99 native RDM skill caps before merits, Gifts, Master Levels, or gear.
RDM_SKILL_CAP_99 = {
    dagger=398, sword=398, club=334, archery=334, throwing=265,
    evasion=334, parrying=300, shield=265,
    divine=300, healing=368, enhancing=404, enfeebling=424,
    elemental=378, dark=300,
}

-- @ai:fn build_rdm_progression_baseline | layer=utility | hot=no | purity=read | contract=Derive progression-only stats from RDM_PROGRESSION; do not invent race or Group1/2 merits.
local function build_rdm_progression_baseline()
    local cfg = RDM_PROGRESSION
    local ml = math.max(0, math.min(50, tonumber(cfg.master_level) or 0))
    local merit_attr = (cfg.merits.attributes or 0)
    local merit_combat = (cfg.merits.combat_skill or 0) * 2
    local merit_magic = (cfg.merits.magic_skill or 0) * 2

    local b = {
        master_level = ml,
        job_master = cfg.job_master == true,
        jp_spent = cfg.jp_spent or 0,
        subjob_cap = 49 + math.floor(ml / 5),
        progression = {
            all_attributes = merit_attr + ml,
            hp = (cfg.merits.hp or 0) * 10 + ml * 7,
            mp = (cfg.merits.mp or 0) * 10 + ml * 2,
            magic_accuracy = (cfg.gifts.magic_accuracy or 0) + (cfg.jp.magic_accuracy or 0),
            magic_attack = (cfg.gifts.magic_attack or 0) + (cfg.jp.magic_attack or 0),
            magic_defense = cfg.gifts.magic_defense or 0,
            magic_evasion = cfg.gifts.magic_evasion or 0,
            physical_accuracy = cfg.gifts.physical_accuracy or 0,
            enspell_damage = cfg.gifts.enspell_damage or 0,
        },
        conditional = {
            composure_accuracy = cfg.jp.composure_accuracy or 0,
            saboteur_magic_accuracy = cfg.jp.saboteur_magic_accuracy or 0,
            enfeebling_duration_seconds = cfg.jp.enfeebling_duration_seconds or 0,
            enhancing_duration_seconds = cfg.jp.enhancing_duration_seconds or 0,
            stymie_duration_seconds = cfg.jp.stymie_duration_seconds or 0,
        },
        skills = {},
    }

    for skill, cap in pairs(RDM_SKILL_CAP_99) do
        local magic = (skill == 'divine' or skill == 'healing' or skill == 'enhancing'
            or skill == 'enfeebling' or skill == 'elemental' or skill == 'dark')
        local total = cap + ml + (magic and merit_magic or merit_combat)
        if skill == 'enhancing' then total = total + (cfg.gifts.enhancing_skill or 0) end
        if skill == 'enfeebling' then total = total + (cfg.gifts.enfeebling_skill or 0) end
        b.skills[skill] = total
    end

    -- Native RDM Fast Cast V is 30% at 89+, plus four mastered Gifts = +8%.
    b.native_fast_cast = 30 + (cfg.gifts.fast_cast or 0)
    return b
end

RDM_BASELINE = build_rdm_progression_baseline()

-- Canonical character/intelligence model. `progression` is mutable only through
-- explicit session commands; `baseline` is refreshed from it. Policy/mechanics
-- tables are declarative references, not copies, so offline tooling and future
-- resolvers have one authoritative ownership chain.
RDM_PROFILE = {
    schema_version = '1.1',
    job = 'RDM',
    release = RDM_RELEASE_VERSION,
    progression = RDM_PROGRESSION,
    baseline = RDM_BASELINE,
    mechanics = RDM_MECHANICS,
    spells = RDM_SPELL_POLICY,
    spell_families = RDM_SPELL_FAMILY_POLICY,
    spell_intelligence = RDM_SPELL_INTELLIGENCE,
    spell_runtime = RDM_SPELL_RUNTIME,
    weaponskills = RDM_WEAPONSKILL_POLICY,
    weapons = RDM_WEAPON_POLICY,
    augments = RDM_AUGMENT_POLICY,
    gear = RDM_GEAR_POLICY,
    roles = RDM_ROLE_SCHEMA,
    safety = {
        runtime_audit = false,
        heavy_analysis = 'offline_only',
        frozen_core = 'v2.18',
    },
}

-- @ai:fn refresh_rdm_baseline | layer=utility | hot=no | purity=write | contract=Rebuild RDM_BASELINE after configuration changes.
function refresh_rdm_baseline()
    RDM_BASELINE = build_rdm_progression_baseline()
    if RDM_PROFILE then RDM_PROFILE.baseline = RDM_BASELINE end
    return RDM_BASELINE
end

-- @ai:fn rdm_baseline_skill | layer=utility | hot=no | purity=read | contract=Case-insensitive baseline skill lookup returning zero when unknown.
function rdm_baseline_skill(skill)
    if not skill then return 0 end
    return (RDM_BASELINE.skills[string.lower(tostring(skill))] or 0)
end

-- @ai:fn report_rdm_baseline | layer=utility | hot=no | purity=write | contract=Diagnostic-only baseline report; refresh first.
function report_rdm_baseline()
    local b = refresh_rdm_baseline()
    local p = b.progression
    add_to_chat(158, string.format(
        '[Baseline] RDM Job Master=%s | JP=%d | ML=%d | support-job cap=%d',
        b.job_master and 'YES' or 'NO', b.jp_spent, b.master_level, b.subjob_cap))
    add_to_chat(158, string.format(
        '[Baseline] permanent progression: all attributes +%d | HP +%d | MP +%d | native FC %d%%',
        p.all_attributes, p.hp, p.mp, b.native_fast_cast))
    add_to_chat(158, string.format(
        '[Baseline] skills before gear: Enhancing %d | Enfeebling %d | Elemental %d | Healing %d | Sword %d | Dagger %d',
        b.skills.enhancing, b.skills.enfeebling, b.skills.elemental, b.skills.healing,
        b.skills.sword, b.skills.dagger))
    add_to_chat(158, string.format(
        '[Baseline] progression stats: M.Acc +%d | MAB +%d | M.Def +%d | M.Eva +%d | Phys.Acc +%d | Enspell +%d',
        p.magic_accuracy, p.magic_attack, p.magic_defense, p.magic_evasion,
        p.physical_accuracy, p.enspell_damage))
    add_to_chat(158, string.format(
        '[Baseline] conditional JP: Composure Acc +%d | Saboteur M.Acc +%d | Enh/Enf duration +%ds/+%ds | Stymie +%ds',
        b.conditional.composure_accuracy, b.conditional.saboteur_magic_accuracy,
        b.conditional.enhancing_duration_seconds, b.conditional.enfeebling_duration_seconds,
        b.conditional.stymie_duration_seconds))
    add_to_chat(158, '[Baseline] RDM Group 1/2 merit choices remain runtime-driven; this module does not guess those allocations.')
end

-- @ai:fn report_intelligence_summary | layer=utility | hot=no | purity=write | contract=Print compact intelligence-model ownership/status only; never scan inventory or gear sets.
function report_intelligence_summary()
    local b = refresh_rdm_baseline()
    add_to_chat(158, string.format(
        '[Intelligence] schema %s | core %s frozen | profile RDM ML%d JobMaster=%s',
        RDM_PROFILE.schema_version, RDM_PROFILE.safety.frozen_core, b.master_level,
        b.job_master and 'YES' or 'NO'))
    add_to_chat(158, string.format(
        '[Intelligence] %d spell policies | spell resolver=%s/%s | %d WS policies | %d weapon policies | %d augment policies | %d gear-policy groups | role engine=%s',
        policy_count(RDM_SPELL_POLICY), RDM_SPELL_INTELLIGENCE.phase, RDM_SPELL_INTELLIGENCE.hot_lookup,
        policy_count(RDM_WEAPONSKILL_POLICY), policy_count(RDM_WEAPON_POLICY), policy_count(RDM_AUGMENT_POLICY), policy_count(RDM_GEAR_POLICY), RDM_ROLE_SCHEMA.active and 'ACTIVE' or 'PLANNED'))
    add_to_chat(158, '[Intelligence] Runtime audit OFF permanently; heavy inventory/set analysis is offline-only.')
end

-- @ai:fn report_policy | layer=utility | hot=no | purity=write | contract=Print one exact spell/WS/weapon policy entry for development diagnostics; no fuzzy scans or game-state mutation.
function report_policy(query)
    local name, p = policy_find_casefold(RDM_SPELL_POLICY, query)
    local kind = 'Spell'
    if not p then name, p = policy_find_casefold(RDM_WEAPONSKILL_POLICY, query); kind = 'WS' end
    if not p then name, p = policy_find_casefold(RDM_WEAPON_POLICY, query); kind = 'Weapon' end
    if not p then name, p = policy_find_casefold(RDM_AUGMENT_POLICY, query); kind = 'Augment' end
    if not p then
        add_to_chat(167, '[Policy] No exact policy entry for "'..tostring(query or '')..'".')
        add_to_chat(158, 'Usage: gs c policy <exact spell, weaponskill, weapon, or augmented item name>')
        return
    end
    local parts = {}
    for k, v in pairs(p) do
        if type(v) ~= 'table' then parts[#parts+1] = tostring(k)..'='..tostring(v) end
    end
    table.sort(parts)
    add_to_chat(158, string.format('[Policy:%s] %s | %s', kind, name, table.concat(parts, ' | ')))
end

-- @ai:fn report_spell_intelligence | layer=utility | hot=no | purity=write | contract=Explain one exact spell's compiled B2 intent dimensions without scanning inventory, resources, targets, or gear sets.
function report_spell_intelligence(query)
    local name, source = policy_find_casefold(RDM_SPELL_POLICY, query)
    if not source then
        add_to_chat(167, '[SpellIntel] No exact spell policy entry for "'..tostring(query or '')..'".')
        add_to_chat(158, 'Usage: gs c spellintel <exact spell name>')
        return
    end
    local p = RDM_SPELL_RUNTIME[name] or source
    add_to_chat(158, string.format('[SpellIntel] %s | school=%s | family=%s | target=%s',
        name, tostring(p.school or '-'), tostring(p.family or '-'), tostring(p.target_scope or '-')))
    add_to_chat(158, string.format('[SpellIntel] intent: landing=%s | potency=%s | duration=%s | skill=%s',
        tostring(p.landing_intent or '-'), tostring(p.potency_intent or '-'),
        tostring(p.duration_intent or '-'), tostring(p.skill_dependence or '-')))
    if p.school == 'Enhancing Magic' then
        add_to_chat(158, string.format('[SpellIntel] route: Auto=%s | direct_map=%s | overlay=%s | breakpoint=%s | Composure-other-gear=%s',
            tostring(p.enhancing_auto or 'legacy/Mote'), tostring(p.direct_map or '-'),
            tostring(p.overlay or '-'), tostring(p.breakpoint or '-'), p.ja_composure_other_gear and 'YES' or 'NO'))
    elseif p.school == 'Enfeebling Magic' then
        add_to_chat(158, string.format('[SpellIntel] route: Auto=%s | duration-mode=%s | Composure-duration=%s | Stymie-accuracy-relief=%s | Saboteur-gear=%s | Saboteur-hint=%s',
            tostring(p.enfeeble_route or 'base-stat-family'), p.duration_mode and 'YES' or 'NO',
            p.composure_duration and 'YES' or 'NO', p.ja_stymie_accuracy_relief and 'YES' or 'NO',
            p.ja_saboteur_gear and 'YES' or 'NO', p.saboteur_hint and 'YES' or 'NO'))
    end
end

-- @ai:fn report_spell_decision | layer=utility | hot=no | purity=write | contract=Explain the current resolver outcome for one exact policy spell using current manual modes/JA state; diagnostics only and never called by casting hooks.
function report_spell_decision(query)
    local name = policy_find_casefold(RDM_SPELL_POLICY, query)
    if not name then
        add_to_chat(167, '[SpellWhy] No exact spell policy entry for "'..tostring(query or '')..'".')
        add_to_chat(158, 'Usage: gs c spellwhy <exact spell name>')
        return
    end
    local p = RDM_SPELL_RUNTIME[name]
    if not p then
        add_to_chat(167, '[SpellWhy] Runtime policy is not compiled yet; reload GearSwap first.')
        return
    end
    if p.school == 'Enhancing Magic' then
        local route = resolve_enhancing_route(p) or 'legacy/Mote fallback'
        add_to_chat(158, string.format('[SpellWhy] %s | Enhancing=Auto -> objective=%s', name, route))
        add_to_chat(158, string.format('[SpellWhy] because potency=%s | duration=%s | skill=%s | target=%s',
            tostring(p.potency_intent), tostring(p.duration_intent), tostring(p.skill_dependence), tostring(p.target_scope)))
        if p.breakpoint then add_to_chat(158, '[SpellWhy] breakpoint policy='..tostring(p.breakpoint)) end
    elseif p.school == 'Enfeebling Magic' then
        local mode = state.EnfeeblingMode and state.EnfeeblingMode.value or 'Auto'
        local stymie = not not buffactive.Stymie
        -- White/Black route cannot be inferred from policy family alone for every
        -- future entry, so report both exact resolver branches when necessary.
        local white_map = resolve_enfeebling_spell_map(p, 'WhiteMagic', mode, stymie)
        local black_map = resolve_enfeebling_spell_map(p, 'BlackMagic', mode, stymie)
        local resolved = white_map == black_map and white_map or ('White='..white_map..' / Black='..black_map)
        add_to_chat(158, string.format('[SpellWhy] %s | EnfeeblingMode=%s | Stymie=%s -> %s',
            name, mode, stymie and 'ON' or 'OFF', resolved))
        if p.enfeeble_route == 'sleep' then
            add_to_chat(158, '[SpellWhy] Sleep is fixed to the accuracy-first set; duration routing is disconnected.')
        end
        add_to_chat(158, string.format('[SpellWhy] because landing=%s | potency=%s | duration=%s | skill=%s | Auto-family=%s',
            tostring(p.landing_intent), tostring(p.potency_intent), tostring(p.duration_intent),
            tostring(p.skill_dependence), tostring(p.enfeeble_route or 'base-stat-family')))
    else
        add_to_chat(158, '[SpellWhy] '..name..' has metadata but no Phase B2 resolver family.')
    end
end

-------------------------------------------------------------------------------
-- Adaptive Fast Cast engine (see the header comment on fc_core in
-- init_gear_sets for the full explanation).
-------------------------------------------------------------------------------

fc_gear_target = nil     -- gear FC the current sets aim for
fc_current_gear = 0      -- gear FC the base set actually carries
fc_jp_spent = RDM_PROGRESSION.jp_spent
fc_shed_list = {}
fc_set_cache = {}        -- Act 5: complete FC bundles keyed by target/order/instant state

-- Native (non-gear, non-buff) FC now consumes the single progression baseline.
-- Under level sync, fall back to the visible trait tier and do not assume Lv99
-- Job Point Gifts are active; at normal endgame level the mastered baseline is
-- authoritative and yields 38% (Fast Cast V 30 + Gifts 8).
-- @ai:fn rdm_native_fc | layer=fc | hot=yes | purity=read | contract=Return native FC; mastered baseline only at unsynced Lv99, trait tiers under sync.
function rdm_native_fc()
    if player and player.main_job and player.main_job ~= 'RDM' then return 0 end
    local lvl = (player and player.main_job_level) or 99
    if lvl >= 99 and RDM_BASELINE and RDM_BASELINE.job_master then
        fc_jp_spent = RDM_BASELINE.jp_spent
        return RDM_BASELINE.native_fast_cast
    end

    fc_jp_spent = 0
    if     lvl >= 89 then return 30
    elseif lvl >= 76 then return 25
    elseif lvl >= 55 then return 20
    elseif lvl >= 35 then return 15
    elseif lvl >= 15 then return 10
    end
    return 0
end

-- Build ONE precast FC set that meets `target` gear FC with as few FC pieces
-- as possible; freed ladder slots get their DT/M.Eva fillers.
-- opts.enfeeb: try Leth. Chappel +1 (Enfeebling cast time -15%, a separate
--   multiplier that stacks past the FC cap) over the FC+14 head -- taken only
--   when the set can still reach target without those 14 FC.
-- opts.order: which shed priority to walk (fc_shed_order / fc_shed_order_dt).
-- Finally, if even the FC head is unneeded (target 0 under Chainspell/
-- Spontaneity), it too becomes a filler.
-- @ai:fn build_fc_set | layer=fc | hot=no | purity=read | contract=Construct one FC table meeting target without dropping below cap target.
function build_fc_set(target, opts)
    opts = opts or {}
    local order = opts.order or fc_shed_order
    local set = {}
    for slot, item in pairs(fc_core) do set[slot] = item end
    local fc = fc_core_value + fc_ladder_value
    local shed = {}
    local head_locked = false

    if opts.enfeeb and (fc - fc_head_value) >= target then
        set.head = "Leth. Chappel +1"
        fc = fc - fc_head_value
        head_locked = true
    end

    -- index ladder entries by slot, walk them in the requested order
    local by_slot = {}
    for _, e in ipairs(fc_ladder) do by_slot[e.slot] = e end
    for _, slot in ipairs(order) do
        local e = by_slot[slot]
        if e then
            if (fc - e.fc) >= target then
                set[e.slot] = e.filler
                fc = fc - e.fc
                -- augmented pieces are tables; report by name
                shed[#shed+1] = type(e.piece) == 'table' and e.piece.name or e.piece
            else
                set[e.slot] = e.piece
            end
        end
    end

    -- Head shed: only mathematically reachable when instant-cast buffs zero
    -- the target (17 core - 14 head = 3 <= target otherwise).
    if not head_locked and (fc - fc_head_value) >= target then
        set.head = fc_head_filler
        fc = fc - fc_head_value
        shed[#shed+1] = "Atro. Chapeau +2"
    end

    return set, fc, shed
end

-- (Re)construct sets.precast.FC and every dependent variant for the current
-- fc_gear_target. Safe to call before user_setup (defaults to 50, the
-- zero-job-points target -- never under cap). While player-facing DT or MEVA
-- defense is active, sheds walk the DT-priority order instead, trading
-- retained-FC headroom for Nyame slots (still never below target).
-- @ai:fn build_fc_sets | layer=fc | hot=no | purity=write | contract=Build/cache complete FC bundle; keep self-referential spell-map aliases intentional.
function build_fc_sets()
    local target = fc_gear_target or 50
    local dt_mode = state and state.DefenseMode and
        (state.DefenseMode.value == 'Physical' or state.DefenseMode.value == 'Magical')
    local cache_key = target .. (dt_mode and '/DT' or '/NORMAL')
        .. (fc_instant and '/INSTANT' or '/CAST')
    local bundle = fc_set_cache[cache_key]

    if bundle then
        perf_count('fc_cache_hits')
    else
        perf_count('fc_rebuilds')
        local perf_t = perf_begin()
        local order = dt_mode and fc_shed_order_dt or fc_shed_order
        local base, base_fc, base_shed = build_fc_set(target, {order=order})

        base['Enhancing Magic'] = base
        -- (Chappel skipped while instant-cast is up: -15% cast time on a 0s cast)
        base['Enfeebling Magic'] = build_fc_set(target, {order=order, enfeeb=(not fc_instant)})

        base.Cure = base
        base.Curaga = base.Cure
        base['Healing Magic'] = base.Cure
        base['Elemental Magic'] = base

        -- DISABLED: Impact requires Twilight/Crepuscular Cloak (NOT OWNED) to even
        -- cast, so this set is dormant. Re-enable by acquiring the cloak.
        base.Impact = set_combine(base, {
            head=empty,
            --body="Twilight Cloak", -- not owned; uncomment when acquired
            })

        base.Dispelga = set_combine(base, {main="Daybreak", sub="Ammurapi Shield", waist="Shinjutsu-no-Obi +1"})
        base.Storm = set_combine(base, {ring2="Stikini Ring +1"})
        base.Utsusemi = base.Cure

        bundle = {
            set = base,
            gear_fc = base_fc,
            shed = base_shed,
            dt_mode = dt_mode,
        }
        fc_set_cache[cache_key] = bundle
        perf_finish('fc_rebuild', perf_t)
    end

    sets.precast.FC = bundle.set
    fc_current_gear = bundle.gear_fc
    fc_shed_list = bundle.shed
    fc_dt_order_active = bundle.dt_mode

    -- These two are bound by reference and must follow the active cached bundle.
    if sets.midcast then
        sets.midcast.FastRecast = sets.precast.FC
        sets.midcast.Trust = sets.precast.FC
    end

    update_hud()
end

-- Recompute the gear target from trait + gifts + party buffs and rebuild the
-- FC sets when anything changed. Caster's Roll's value can't be read off the
-- buff icon, so state.CasterRollFC holds the typed-command assumption
-- ('gs c cycle CasterRollFC'). Assuming LOW is the safe direction:
-- worst case you stay slightly over cap. Assuming high on a low roll = under
-- cap. Chainspell/Spontaneity make casts instant, so the target drops to 0 and
-- every FC piece (head included) becomes a DT/M.Eva filler -- Leth. Chappel is
-- skipped too, since its -15% cast multiplier is meaningless on instant casts.
-- @ai:fn update_fc_tier | layer=fc | hot=yes | purity=write | contract=Invalidate/rebuild FC only when target or defense flavor changes.
function update_fc_tier(verbose, silent)
    -- Guard: never run before init_gear_sets has defined the FC pool, or
    -- before Mote has created the sets tables (order-independence safety).
    if not (fc_core and fc_ladder and sets and sets.precast) then return end

    local native = rdm_native_fc()
    local buff_fc = 0
    fc_instant = buffactive and (buffactive['Chainspell'] or buffactive['Spontaneity']) and true or false
    if buffactive and buffactive["Caster's Roll"] and state and state.CasterRollFC then
        buff_fc = tonumber(state.CasterRollFC.value) or 0
    end
    local target = fc_instant and 0 or math.max(0, 80 - native - buff_fc)

    -- Rebuild key includes the shed-order flavor so cycling Defense
    -- rebuilds even when the numeric target is unchanged.
    local dt_mode = state and state.DefenseMode and
        (state.DefenseMode.value == 'Physical' or state.DefenseMode.value == 'Magical')
    local build_key = target .. (dt_mode and '/DT' or '')

    if build_key ~= fc_build_key then
        fc_build_key = build_key
        fc_gear_target = target
        build_fc_sets()
        if not silent then report_fc_tier() end
    elseif verbose then
        report_fc_tier()
    end
end

-------------------------------------------------------------------------------
-- On-screen command-center HUD. All gameplay values, haste/DW, and movement
-- state are native; GearInfo is neither required nor displayed. The HUD is a
-- presentation layer only and must not scan inventory/resources or equip gear.
--
-- Toggle visibility: Alt+F10 or 'gs c hud'. The box loads LOCKED in place;
-- Alt+F9 (or 'gs c hudlock') unlocks it so you can drag to reposition,
-- then locks it again. Layout, scale, opacity, visibility, section choices,
-- and drag position are saved per character. Dragging is debounced so the
-- settings file is written once after movement settles, not every mouse tick.
-------------------------------------------------------------------------------

local HUD_PREFERENCES_FILE = 'data/Falurian_RDM_HUD.xml'
local HUD_PREFERENCES_CACHE_KEY = '__falurian_rdm_hud_preferences_v1'
local HUD_SECTION_ORDER = {'loadout','combat','magic','automation','diagnostics','shortcuts'}
local HUD_DEFAULT_PREFERENCES = {
    schema = 1,
    x = 675,
    y = 950,
    layout = 'expanded',
    scale = 1.00,
    opacity = 205,
    visible = true,
    sections = {
        loadout = true,
        combat = true,
        magic = true,
        automation = true,
        diagnostics = true,
        shortcuts = true,
    },
}

local hud_config_lib = nil
local hud_preferences = nil
local hud_persistence_error_reported = false
local hud_drag_generation = 0
local hud_drag_save_pending = false

hud_settings = {
    pos = {x = 675, y = 950},
    text = {
        size = 11,
        font = 'Consolas',
        alpha = 255,
        stroke = {width = 2, alpha = 255, red = 0, green = 0, blue = 0},
    },
    bg = {alpha = 205, red = 8, green = 10, blue = 14},
    flags = {draggable = false},
}
hud = nil
hud_visible = true
gearinfo_last = nil
GEARINFO_STALE_SECONDS = 6
hud_last_text = nil
local hud_state_cache = {initialized=false}

-- Wide, high-contrast dashboard. Expanded is the new full command center;
-- compact remains available for fights where only essential state is wanted.
hud_config = {
    layout = 'expanded',      -- compact | expanded
    scale = 1.00,             -- 0.70 .. 1.60
    opacity = 205,            -- 0 .. 255
    sections = {
        loadout = true,
        combat = true,
        magic = true,
        automation = true,
        diagnostics = true,
        shortcuts = true,
    },
}

-- @ai:fn hud_persistence_error | layer=hud | hot=no | purity=write | contract=Report at most one persistence failure per load; the HUD must continue with in-memory defaults.
local function hud_persistence_error(message)
    if hud_persistence_error_reported then return end
    hud_persistence_error_reported = true
    add_to_chat(167, '[HUD] Per-character saving unavailable; using session-only settings. '..tostring(message or ''))
end

-- @ai:fn hud_number | layer=hud | hot=no | purity=pure | contract=Return one finite numeric preference clamped to the supplied range.
local function hud_number(value, fallback, low, high)
    local number = tonumber(value)
    if not number or number ~= number or number == math.huge or number == -math.huge then
        number = fallback
    end
    if low and number < low then number = low end
    if high and number > high then number = high end
    return number
end

-- @ai:fn load_hud_preferences | layer=hud | hot=no | purity=write | contract=Load and sanitize one shared XML settings table whose config library character overlay supplies this player's values.
local function load_hud_preferences()
    local ok, config_lib = pcall(require, 'config')
    if not ok or not config_lib then
        hud_persistence_error(config_lib)
        return false
    end

    local loaded = nil
    if type(windower) == 'table' then
        loaded = rawget(windower, HUD_PREFERENCES_CACHE_KEY)
        if type(loaded) == 'table' then
            local reload_ok = pcall(config_lib.reload, loaded)
            if not reload_ok then loaded = nil end
        end
    end

    if not loaded then
        local load_ok, result = pcall(config_lib.load, HUD_PREFERENCES_FILE, HUD_DEFAULT_PREFERENCES)
        if not load_ok or type(result) ~= 'table' then
            hud_persistence_error(result)
            return false
        end
        loaded = result
        if type(windower) == 'table' then
            rawset(windower, HUD_PREFERENCES_CACHE_KEY, loaded)
        end
    end

    hud_config_lib = config_lib
    hud_preferences = loaded

    local layout = tostring(loaded.layout or ''):lower()
    hud_config.layout = (layout == 'compact' or layout == 'expanded') and layout
        or HUD_DEFAULT_PREFERENCES.layout
    hud_config.scale = hud_number(loaded.scale, HUD_DEFAULT_PREFERENCES.scale, 0.70, 1.60)
    hud_config.opacity = math.floor(hud_number(loaded.opacity, HUD_DEFAULT_PREFERENCES.opacity, 0, 255) + 0.5)
    if type(loaded.visible) == 'boolean' then
        hud_visible = loaded.visible
    else
        hud_visible = HUD_DEFAULT_PREFERENCES.visible
    end

    local saved_sections = type(loaded.sections) == 'table' and loaded.sections or {}
    for _, name in ipairs(HUD_SECTION_ORDER) do
        if type(saved_sections[name]) == 'boolean' then
            hud_config.sections[name] = saved_sections[name]
        else
            hud_config.sections[name] = HUD_DEFAULT_PREFERENCES.sections[name]
        end
    end

    hud_settings.pos.x = math.floor(hud_number(loaded.x, HUD_DEFAULT_PREFERENCES.x, -20000, 20000) + 0.5)
    hud_settings.pos.y = math.floor(hud_number(loaded.y, HUD_DEFAULT_PREFERENCES.y, -20000, 20000) + 0.5)
    -- Lock state is intentionally not persisted: every reload starts locked so
    -- the HUD cannot unexpectedly capture mouse input during combat.
    hud_settings.flags.draggable = false
    return true
end

-- @ai:fn current_hud_position | layer=hud | hot=no | purity=read | contract=Read the texts object's canonical coordinates, falling back to the last known settings position.
local function current_hud_position()
    local x, y = hud_settings.pos.x, hud_settings.pos.y
    if hud and type(hud.pos) == 'function' then
        local ok, live_x, live_y = pcall(hud.pos, hud)
        if ok and tonumber(live_x) and tonumber(live_y) then
            x, y = tonumber(live_x), tonumber(live_y)
        end
    end
    x = math.floor(hud_number(x, HUD_DEFAULT_PREFERENCES.x, -20000, 20000) + 0.5)
    y = math.floor(hud_number(y, HUD_DEFAULT_PREFERENCES.y, -20000, 20000) + 0.5)
    hud_settings.pos.x, hud_settings.pos.y = x, y
    return x, y
end

-- @ai:fn save_hud_preferences | layer=hud | hot=no | purity=write | contract=Snapshot all user-facing HUD presentation state and save it to the current character overlay.
save_hud_preferences = function(silent)
    if not hud_config_lib or not hud_preferences then return false end

    local x, y = current_hud_position()
    hud_preferences.schema = HUD_DEFAULT_PREFERENCES.schema
    hud_preferences.x = x
    hud_preferences.y = y
    hud_preferences.layout = hud_config.layout
    hud_preferences.scale = hud_config.scale
    hud_preferences.opacity = hud_config.opacity
    hud_preferences.visible = hud_visible == true
    if type(hud_preferences.sections) ~= 'table' then hud_preferences.sections = {} end
    for _, name in ipairs(HUD_SECTION_ORDER) do
        hud_preferences.sections[name] = hud_config.sections[name] ~= false
    end

    local ok, err = pcall(hud_config_lib.save, hud_preferences)
    if not ok then
        hud_persistence_error(err)
        return false
    end
    return true
end

-- @ai:fn queue_hud_drag_save | layer=hud | hot=no | purity=write | contract=Debounce drag writes and save the newest coordinates once mouse movement has settled.
local function queue_hud_drag_save()
    hud_drag_generation = hud_drag_generation + 1
    if hud_drag_save_pending then return end
    if not (coroutine and type(coroutine.schedule) == 'function') then return end

    hud_drag_save_pending = true
    local settle
    settle = function()
        local observed_generation = hud_drag_generation
        coroutine.schedule(function()
            if RDM_RUNTIME.unloading then
                hud_drag_save_pending = false
                return
            end
            if hud_drag_generation ~= observed_generation then
                settle()
                return
            end
            hud_drag_save_pending = false
            if save_hud_preferences then save_hud_preferences(true) end
        end, 0.60)
    end
    settle()
end

-- Compatibility aliases for the v2.39 section command vocabulary.
local hud_section_aliases = {
    modes = 'loadout',
    casting = 'magic',
    keys = 'shortcuts',
    help = 'shortcuts',
}

hud_colors = {
    label='\\cs(205,210,220)', value='\\cs(248,248,250)',
    section='\\cs(120,205,255)', cyan='\\cs(105,210,235)', green='\\cs(115,225,145)',
    yellow='\\cs(245,210,100)', orange='\\cs(245,165,90)',
    red='\\cs(255,105,115)', dim='\\cs(135,140,150)',
    bg={8,10,14},
}

-- @ai:fn hud_call | layer=hud | hot=no | purity=write | contract=Protected dynamic method call for texts object compatibility.
local function hud_call(method, ...)
    if not hud or type(hud[method]) ~= 'function' then return false end
    return pcall(hud[method], hud, ...)
end

-- @ai:fn apply_hud_style | layer=hud | hot=no | purity=write | contract=Apply visual config only; do not compute gameplay state.
local function apply_hud_style()
    local bg = hud_colors.bg or {8,10,14}
    hud_call('size', math.max(8, math.floor(11 * hud_config.scale + 0.5)))
    hud_call('bg_alpha', hud_config.opacity)
    hud_call('bg_color', bg[1], bg[2], bg[3])
    hud_last_text = nil
end

-- @ai:fn init_hud | layer=hud | hot=no | purity=write | contract=Create HUD once and initialize presentation state.
function init_hud()
    load_hud_preferences()
    local ok, texts_lib = pcall(require, 'texts')
    if not ok or not texts_lib then
        add_to_chat(167, '[HUD] texts library unavailable; HUD disabled')
        return
    end
    hud = texts_lib.new('', hud_settings)
    if type(hud.register_event) == 'function' then
        pcall(hud.register_event, hud, 'drag', function(x, y)
            if tonumber(x) and tonumber(y) then
                hud_settings.pos.x = tonumber(x)
                hud_settings.pos.y = tonumber(y)
            end
            queue_hud_drag_save()
        end)
    end
    apply_hud_style()
    update_hud(true)
    if hud_visible then hud:show() end
end

-- @ai:fn col | layer=hud | hot=yes | purity=read | contract=Return color escape wrapper; presentation-only.
local function col(name, value)
    return (hud_colors[name] or '') .. tostring(value or '') .. '\\cr'
end
-- @ai:fn pill | layer=hud | hot=yes | purity=read | contract=Format one compact-layout HUD status token.
local function pill(label, value, color)
    return col('dim', '[') .. col('label', label .. ':') .. col(color or 'value', value) .. col('dim', ']')
end
-- @ai:fn mode_value | layer=hud | hot=yes | purity=read | contract=Nil-safe Mote mode value accessor.
local function mode_value(st, fallback)
    return st and st.value or fallback or '-'
end
-- @ai:fn hud_row | layer=hud | hot=yes | purity=read | contract=Align expanded-layout section names in the monospace HUD.
local function hud_row(label, content)
    return col('section', string.format('%-12s', label or '')) .. (content or '')
end
-- @ai:fn hud_field | layer=hud | hot=yes | purity=read | contract=Format a descriptive label/value pair for expanded rows.
local function hud_field(label, value, color)
    return col('label', label .. ': ') .. col(color or 'value', value)
end
-- @ai:fn hud_section_enabled | layer=hud | hot=yes | purity=read | contract=Read HUD section visibility flag.
local function hud_section_enabled(name)
    return hud_config.sections[name] ~= false
end

local HUD_CASTING_DETAIL = {
    Normal='standard', SIRD='57% SIRD overlay', SpellACC='elemental M.Acc',
}
local HUD_ENFEEBLING_DETAIL = {
    Auto='spell-aware', Accuracy='landing-first',
}

-- @ai:fn update_hud | layer=hud | hot=yes | purity=write | contract=Presentation-only; scalar-state cache must return before string formatting when visible state is unchanged.
function update_hud(force)
    perf_count('hud_calls')
    if not hud then return end
    if not hud_visible and not force then
        perf_count('hud_hidden_skips')
        return
    end
    local perf_t = perf_begin()

    -- Snapshot scalars before formatting. update_hud() is called by many state
    -- invalidations, so unchanged calls still return before allocating HUD rows.
    local now = os.clock()
    local est = estimate_haste()
    local dw_trait = dw_native_trait()
    local native_haste_total = DW == true and (Haste or est.total) or est.total
    local native_haste_pct = native_haste_total / 1024 * 100
    local manual_haste_pct = (tonumber(haste_manual_magic) or 0) / 10.24

    local caster_roll_active = buffactive and buffactive["Caster's Roll"] and true or false
    local caster_roll_value = state and state.CasterRollFC and state.CasterRollFC.value or nil
    local player_status = player and player.status or 'Loading'

    local offense = state and mode_value(state.OffenseMode) or '-'
    local hybrid = state and mode_value(state.HybridMode) or '-'
    local casting_mode = state and mode_value(state.CastingMode) or '-'
    local idle_mode = state and mode_value(state.IdleMode) or '-'
    local defense_mode = state and defense_control_mode() or 'Normal'
    local enfeebling_mode = state and mode_value(state.EnfeeblingMode) or '-'
    local enspell_mode = state and mode_value(state.EnspellMode) or '-'

    local treasure_hunter = state and state.TreasureHunter and state.TreasureHunter.value or false
    local ranged_lock = state and state.RangedLock and state.RangedLock.value or false
    local weapon_locked = state and state.WeaponLock and state.WeaponLock.value or false
    local auto_kite = state and state.Auto_Kite and state.Auto_Kite.value or false
    local fishing = state and state.FishingMode and state.FishingMode.value or false
    local paused = state and state.PauseSwaps and state.PauseSwaps.value or false
    local native_moving = moving == true
    local hp_lean = monitor_state and monitor_state.hp_lean or false
    local doom_active = buffactive and buffactive.doom and true or false

    local weapon_key = state and control_state_value('WeaponSet') or RDM_DEFAULT_WEAPON_SET
    local weapon_label = weapon_pair_label(weapon_key)
    local weapon_meta = RDM_WEAPON_PAIR_META[weapon_key] or {}
    local playstyle_key = state and control_state_value('Playstyle') or 'Custom'
    local playstyle_profile = RDM_PLAYSTYLE_PROFILES[playstyle_key]
    local playstyle_label = playstyle_profile and playstyle_profile.label or playstyle_key
    local dw_available = dual_wield_available()

    -- Match the actual Enspell overlay resolver: equipped main is authoritative
    -- while weapons are locked; the selected pair is authoritative while
    -- unlocked so an equip packet cannot make the HUD lag one refresh behind.
    local actual_main_name = player and player.equipment and player.equipment.main
    local crocea_melee_ready
    if not weapon_locked then
        crocea_melee_ready = weapon_meta.crocea_main == true
    else
        crocea_melee_ready = actual_main_name == 'Crocea Mors'
        if actual_main_name == nil or actual_main_name == '' then
            crocea_melee_ready = weapon_meta.crocea_main == true
        end
    end

    local enspell_buffed = type(enspell_active) == 'function' and enspell_active() or false
    local enspell_effective
    if enspell_mode == 'Max' then
        enspell_effective = 'forced max'
    elseif enspell_mode == 'Off' then
        enspell_effective = 'disabled'
    elseif not enspell_buffed then
        enspell_effective = 'waiting for Enspell buff'
    elseif not crocea_melee_ready then
        enspell_effective = 'Crocea required'
    elseif player_status == 'Engaged' then
        enspell_effective = 'balanced overlay active'
    else
        enspell_effective = 'balanced overlay ready'
    end

    local enspell_selector = state and mode_value(state.EnSpell) or '-'
    local gain_selector = state and mode_value(state.GainSpell) or '-'
    local bar_element = state and mode_value(state.BarElement) or '-'
    local bar_status = state and mode_value(state.BarStatus) or '-'
    local gain_effective = gain_selector
    if gain_selector == 'Auto' then
        local policy = actual_main_name and RDM_WEAPON_POLICY[actual_main_name]
        gain_effective = policy and policy.gain_spell or 'Gain-MND'
    end

    -- The HUD and F11 share one authoritative opportunity resolver. It scans
    -- Windower's complete currently available WS list, so a learned sword WS
    -- remains eligible with any equipped sword; weapon-specific preferences
    -- affect same-level ranking only. The snapshot also prevents a timing-only
    -- READY label when TP, target, or an actual closer is missing.
    local sc_snapshot = type(sc_opportunity_snapshot) == 'function'
        and sc_opportunity_snapshot(now) or {active=false, status='NONE'}
    local react_active = sc_snapshot.active == true
    local react_ready = sc_snapshot.status == 'READY'
    local react_generation = sc_snapshot.generation or 0
    local react_opener = sc_snapshot.opener or ''
    local react_first = sc_snapshot.first_property
    local react_status = sc_snapshot.status or 'NONE'
    local react_choice_name = sc_snapshot.choice_name or ''
    local react_choice_result = sc_snapshot.choice_result or ''
    local react_wait_tenths = math.floor((tonumber(sc_snapshot.wait_remaining) or 0) * 10 + 0.5)
    local react_tp = tonumber(sc_snapshot.tp) or 0

    -- F10 reads only the formed-chain AutoMB window. The snapshot performs no
    -- action and shares its exact READY/blocker decision with the command.
    local mb_snapshot = type(mb_opportunity_snapshot) == 'function'
        and mb_opportunity_snapshot(now) or {active=false, status='NONE'}
    local mb_active = mb_snapshot.active == true
    local mb_status = mb_snapshot.status or 'NONE'
    local mb_remaining_tenths = math.floor(
        (tonumber(mb_snapshot.remaining) or 0) * 10 + 0.5)
    local mb_recast_tenths = mb_snapshot.choice_recast_known and math.floor(
        (tonumber(mb_snapshot.choice_recast) or 0) * 10 + 0.5) or 0

    local c = hud_state_cache
    local unchanged = c.initialized
        and c.fc_instant == fc_instant
        and c.fc_dt == fc_dt_order_active
        and c.fc_current == (fc_current_gear or 0)
        and c.fc_target == (fc_gear_target or 0)
        and c.roll_active == caster_roll_active
        and c.roll_value == caster_roll_value
        and c.dw == (DW == true)
        and c.dw_trait == dw_trait
        and c.dw_need == (DW_needed or 0)
        and c.dw_have == (dw_have or 0)
        and c.dw_shortfall == (dw_shortfall == true)
        and c.dw_sailfi == (dw_sailfi_active == true)
        and c.haste_total == native_haste_total
        and c.haste_manual == (haste_manual_magic or 0)
        and c.status == player_status
        and c.offense == offense
        and c.hybrid == hybrid
        and c.casting == casting_mode
        and c.idle == idle_mode
        and c.defense == defense_mode
        and c.enfeebling == enfeebling_mode
        and c.enspell == enspell_mode
        and c.enspell_buffed == enspell_buffed
        and c.enspell_effective == enspell_effective
        and c.th == treasure_hunter
        and c.ranged_lock == ranged_lock
        and c.weapon_locked == weapon_locked
        and c.auto_kite == auto_kite
        and c.fishing == fishing
        and c.paused == paused
        and c.moving == native_moving
        and c.hp_lean == hp_lean
        and c.doom == doom_active
        and c.weapon_key == weapon_key
        and c.playstyle_key == playstyle_key
        and c.dw_available == dw_available
        and c.enspell_selector == enspell_selector
        and c.gain_selector == gain_selector
        and c.gain_effective == gain_effective
        and c.bar_element == bar_element
        and c.bar_status == bar_status
        and c.react_active == react_active
        and c.react_ready == react_ready
        and c.react_generation == react_generation
        and c.react_opener == react_opener
        and c.react_first == react_first
        and c.react_status == react_status
        and c.react_choice_name == react_choice_name
        and c.react_choice_result == react_choice_result
        and c.react_wait_tenths == react_wait_tenths
        and c.react_tp == react_tp
        and c.mb_active == mb_active
        and c.mb_generation == (mb_snapshot.generation or 0)
        and c.mb_status == mb_status
        and c.mb_chain_name == (mb_snapshot.chain_name or '')
        and c.mb_choice_name == (mb_snapshot.choice_name or '')
        and c.mb_choice_element == (mb_snapshot.choice_element or '')
        and c.mb_choice_cost == (tonumber(mb_snapshot.choice_cost) or 0)
        and c.mb_current_mp == (tonumber(mb_snapshot.mp) or 0)
        and c.mb_remaining_tenths == mb_remaining_tenths
        and c.mb_recast_tenths == mb_recast_tenths
        and c.mb_recast_known == (mb_snapshot.choice_recast_known == true)
        and c.mb_pending_started == (mb_snapshot.pending_started == true)

    if unchanged and not force then
        perf_count('hud_state_cache_hits')
        perf_finish('hud', perf_t)
        return
    end

    c.initialized = true
    c.fc_instant, c.fc_dt = fc_instant, fc_dt_order_active
    c.fc_current, c.fc_target = fc_current_gear or 0, fc_gear_target or 0
    c.roll_active, c.roll_value = caster_roll_active, caster_roll_value
    c.dw, c.dw_trait = DW == true, dw_trait
    c.dw_need, c.dw_have = DW_needed or 0, dw_have or 0
    c.dw_shortfall, c.dw_sailfi = dw_shortfall == true, dw_sailfi_active == true
    c.haste_total, c.haste_manual = native_haste_total, haste_manual_magic or 0
    c.status = player_status
    c.offense, c.hybrid = offense, hybrid
    c.casting, c.idle, c.defense = casting_mode, idle_mode, defense_mode
    c.enfeebling = enfeebling_mode
    c.enspell, c.enspell_buffed, c.enspell_effective = enspell_mode, enspell_buffed, enspell_effective
    c.th, c.ranged_lock = treasure_hunter, ranged_lock
    c.weapon_locked = weapon_locked
    c.auto_kite = auto_kite
    c.fishing, c.paused, c.moving = fishing, paused, native_moving
    c.hp_lean, c.doom = hp_lean, doom_active
    c.weapon_key, c.playstyle_key, c.dw_available = weapon_key, playstyle_key, dw_available
    c.enspell_selector, c.gain_selector = enspell_selector, gain_selector
    c.gain_effective, c.bar_element, c.bar_status = gain_effective, bar_element, bar_status
    c.react_active, c.react_ready, c.react_generation = react_active, react_ready, react_generation
    c.react_opener, c.react_first = react_opener, react_first
    c.react_status = react_status
    c.react_choice_name, c.react_choice_result = react_choice_name, react_choice_result
    c.react_wait_tenths, c.react_tp = react_wait_tenths, react_tp
    c.mb_active = mb_active
    c.mb_generation = mb_snapshot.generation or 0
    c.mb_status = mb_status
    c.mb_chain_name = mb_snapshot.chain_name or ''
    c.mb_choice_name = mb_snapshot.choice_name or ''
    c.mb_choice_element = mb_snapshot.choice_element or ''
    c.mb_choice_cost = tonumber(mb_snapshot.choice_cost) or 0
    c.mb_current_mp = tonumber(mb_snapshot.mp) or 0
    c.mb_remaining_tenths = mb_remaining_tenths
    c.mb_recast_tenths = mb_recast_tenths
    c.mb_recast_known = mb_snapshot.choice_recast_known == true
    c.mb_pending_started = mb_snapshot.pending_started == true

    local separator = col('dim', '  |  ')
    local status_color = player_status == 'Engaged' and 'green'
        or (player_status == 'Idle' and 'cyan' or 'yellow')
    local swap_text, swap_color = 'ACTIVE', 'green'
    if fishing and paused then
        swap_text, swap_color = 'FISHING + PAUSED', 'red'
    elseif fishing then
        swap_text, swap_color = 'FISHING - RINGS ACTIVE', 'orange'
    elseif paused then
        swap_text, swap_color = 'PAUSED', 'red'
    end

    local title = col('value', 'RDM COMMAND CENTER')
        .. col('dim', '  v' .. RDM_RELEASE_VERSION)
        .. separator .. hud_field('Status', string.upper(tostring(player_status)), status_color)
        .. separator .. hud_field('Gear swaps', swap_text, swap_color)
        .. '  ' .. pill('Lock', weapon_locked and 'ON' or 'off',
            weapon_locked and 'green' or 'yellow')
    local rule = col('dim', '------------------------------------------------------------------------------------------------------------')

    local playstyle_color = playstyle_key == 'Custom' and 'yellow' or 'green'
    local fallback_text = (not dw_available and weapon_key ~= 'Idle')
        and ' / shield fallback' or ''
    local loadout_row = hud_row('LOADOUT',
        hud_field('Weapon pair', weapon_label .. fallback_text, 'cyan'))
    local style_summary = playstyle_profile and playstyle_profile.summary
        or 'manual mode mix; use gs c rdmplay <style> for a complete preset'
    local style_row = hud_row('PLAYSTYLE',
        hud_field('Preset', playstyle_label, playstyle_color)
        .. col('dim', '  -  ' .. style_summary))
    local ws_hint_row = hud_row('WEAPON ROLE',
        hud_field('Primary WS', weapon_meta.primary_ws or '-', 'cyan')
        .. separator .. col('dim', weapon_meta.purpose or 'custom weapon policy'))

    local acc_color = offense == 'Normal' and 'value' or 'orange'
    local hybrid_color = hybrid == 'DT' and 'green' or 'value'
    local melee_dt_display = hybrid == 'DT' and 'On' or 'Off'
    local enspell_color = enspell_mode == 'Max' and 'yellow'
        or (enspell_effective:find('active', 1, true) and 'green'
        or (enspell_mode == 'Off' and 'dim' or 'cyan'))
    local melee_row = hud_row('MELEE',
        hud_field('Accuracy', offense, acc_color)
        .. separator .. hud_field('Melee DT', melee_dt_display, hybrid_color)
        .. separator .. hud_field('Enspell melee', enspell_mode .. ' (' .. enspell_effective .. ')', enspell_color))

    local defense_display = defense_mode
    local move_text, move_color = 'still / speed gear off', 'dim'
    if auto_kite then
        move_text, move_color = 'MOVING - native auto-speed active', 'green'
    elseif native_moving then
        move_text, move_color = 'MOVING - defense currently owns gear', 'orange'
    end
    local defense_row = hud_row('DEFENSE',
        hud_field('Mode', defense_display, defense_mode ~= 'Normal' and 'orange' or 'value')
        .. separator .. hud_field('Idle', idle_mode, idle_mode == 'DT' and 'green' or 'value')
        .. separator .. hud_field('Movement', move_text, move_color))

    local cast_detail = HUD_CASTING_DETAIL[casting_mode] or 'custom'
    local casting_row = hud_row('CASTING',
        hud_field('Mode', casting_mode .. ' (' .. cast_detail .. ')',
            casting_mode == 'Normal' and 'value' or 'orange'))

    local enfeebling_detail = HUD_ENFEEBLING_DETAIL[enfeebling_mode] or 'custom'
    local enfeebling_row = hud_row('ENFEEBLING',
        hud_field('Policy', enfeebling_mode .. ' (' .. enfeebling_detail .. ')',
            enfeebling_mode == 'Auto' and 'cyan' or 'orange'))

    local gain_display = gain_selector == 'Auto'
        and ('Auto -> ' .. tostring(gain_effective)) or gain_selector
    local quick_cast_row = hud_row('QUICK CAST',
        hud_field('Enspell', enspell_selector, 'cyan')
        .. separator .. hud_field('Gain', gain_display, 'cyan')
        .. separator .. hud_field('Bars', bar_element .. ' / ' .. bar_status, 'cyan'))

    local compact_mb_text, compact_mb_color
    local compact_sc_text, compact_sc_color
    local utility_parts = {}
    if mb_active then
        local chain_name = mb_snapshot.chain_name or '?'
        local choice_name = mb_snapshot.choice_name or ''
        local choice_element = mb_snapshot.choice_element or ''
        local choice_text = choice_name ~= ''
            and (choice_name .. (choice_element ~= '' and (' ('..choice_element..')') or '')
                .. ' -> ' .. chain_name) or chain_name
        local burst_text, burst_color
        if mb_status == 'READY' then
            burst_text = string.format('READY %.1fs - F10: %s',
                mb_remaining_tenths / 10, choice_text)
            burst_color = 'green'
            compact_mb_text, compact_mb_color = 'READY '..choice_text, 'green'
        elseif mb_status == 'PENDING' then
            local phase = mb_snapshot.pending_started and 'CASTING' or 'SENT'
            burst_text = phase..' - '..choice_text
            burst_color = 'cyan'
            compact_mb_text, compact_mb_color = phase..' '..choice_name, 'cyan'
        elseif mb_status == 'NEED_MP' then
            burst_text = 'NEED MP '..tostring(mb_snapshot.mp or 0)..'/'
                ..tostring(mb_snapshot.choice_cost or '?')..' - F10: '..choice_text
            burst_color = 'yellow'
            compact_mb_text, compact_mb_color = 'MP '..tostring(mb_snapshot.mp or 0)
                ..'/'..tostring(mb_snapshot.choice_cost or '?')..' '..choice_name, 'yellow'
        elseif mb_status == 'RECAST' then
            local recast_text = mb_snapshot.choice_recast_known
                and string.format('%.1fs', mb_recast_tenths / 10) or '?'
            burst_text = 'RECAST '..recast_text..' - '..choice_text
            burst_color = 'orange'
            compact_mb_text, compact_mb_color = 'RECAST '..recast_text..' '..choice_name, 'orange'
        elseif mb_status == 'NO_SPELL' then
            burst_text = 'NO SPELL - '..chain_name..' has no learned/current-job standard nuke match'
            burst_color = 'red'
            compact_mb_text, compact_mb_color = 'NO SPELL '..chain_name, 'red'
        elseif mb_status == 'TARGET_CHANGED' then
            burst_text = 'TARGET CHANGED - retarget the enemy that formed '..chain_name
            burst_color = 'red'
            compact_mb_text, compact_mb_color = 'TARGET CHANGED', 'red'
        elseif mb_status == 'NO_TARGET' then
            burst_text = 'NO TARGET - retarget the enemy that formed '..chain_name
            burst_color = 'red'
            compact_mb_text, compact_mb_color = 'NO TARGET', 'red'
        elseif mb_status == 'SWAPS_FROZEN' then
            burst_text = 'GEAR FROZEN - resume swaps before F10: '..choice_text
            burst_color = 'red'
            compact_mb_text, compact_mb_color = 'GEAR FROZEN', 'red'
        elseif mb_status == 'BUSY' then
            burst_text = 'BUSY - finish the current action, then F10: '..choice_text
            burst_color = 'orange'
            compact_mb_text, compact_mb_color = 'BUSY '..choice_name, 'orange'
        elseif mb_status == 'SILENCED' then
            burst_text = 'SILENCED - magic blocked; F10 choice: '..choice_text
            burst_color = 'red'
            compact_mb_text, compact_mb_color = 'SILENCED', 'red'
        else
            burst_text = tostring(mb_status)..' - '..choice_text
            burst_color = 'orange'
            compact_mb_text, compact_mb_color = tostring(mb_status), 'orange'
        end
        utility_parts[#utility_parts + 1] = hud_field(
            'Manual magic burst', burst_text, burst_color)
    end
    if react_active then
        local properties = sc_snapshot.properties_text or '?'
        local choice_text = react_choice_name ~= ''
            and (react_choice_name .. ' -> ' .. react_choice_result) or ''
        local skillchain_text, skillchain_color
        if react_status == 'READY' then
            skillchain_text = 'READY - F11: ' .. choice_text
            skillchain_color = 'green'
            compact_sc_text, compact_sc_color = 'READY ' .. choice_text, 'green'
        elseif react_status == 'WAIT' then
            local wait_text = string.format('%.1fs', react_wait_tenths / 10)
            skillchain_text = 'WAIT ' .. wait_text .. ' - F11: ' .. choice_text
            skillchain_color = 'orange'
            compact_sc_text, compact_sc_color = 'WAIT ' .. wait_text .. ' ' .. choice_text, 'orange'
        elseif react_status == 'NEED_TP' then
            skillchain_text = 'NEED TP ' .. tostring(react_tp) .. '/1000 - F11: ' .. choice_text
            skillchain_color = 'yellow'
            compact_sc_text, compact_sc_color = 'TP ' .. tostring(react_tp) .. '/1000 ' .. choice_text, 'yellow'
        elseif react_status == 'PENDING' then
            skillchain_text = 'SENT - awaiting confirmation: ' .. tostring(sc_snapshot.pending_name or react_choice_name)
            skillchain_color = 'cyan'
            compact_sc_text, compact_sc_color = 'SENT ' .. tostring(sc_snapshot.pending_name or react_choice_name), 'cyan'
        elseif react_status == 'NO_CLOSER' then
            skillchain_text = 'NO CLOSER - ' .. tostring(react_opener)
                .. ' (' .. properties .. ') has no match in the live WS list'
            skillchain_color = 'red'
            compact_sc_text, compact_sc_color = 'NO CLOSER ' .. tostring(react_opener), 'red'
        elseif react_status == 'TARGET_CHANGED' then
            skillchain_text = 'TARGET CHANGED - opportunity belongs to another target'
            skillchain_color = 'red'
            compact_sc_text, compact_sc_color = 'TARGET CHANGED', 'red'
        elseif react_status == 'NO_TARGET' then
            skillchain_text = 'NO TARGET - retarget the resonating enemy'
            skillchain_color = 'red'
            compact_sc_text, compact_sc_color = 'NO TARGET', 'red'
        elseif react_status == 'NOT_ENGAGED' then
            skillchain_text = 'NOT ENGAGED - F11: ' .. choice_text
            skillchain_color = 'orange'
            compact_sc_text, compact_sc_color = 'NOT ENGAGED ' .. choice_text, 'orange'
        elseif react_status == 'SWAPS_FROZEN' then
            skillchain_text = 'GEAR FROZEN - resume swaps before F11: ' .. choice_text
            skillchain_color = 'red'
            compact_sc_text, compact_sc_color = 'GEAR FROZEN', 'red'
        elseif react_status == 'BUSY' then
            skillchain_text = 'BUSY - finish the current action, then F11: ' .. choice_text
            skillchain_color = 'orange'
            compact_sc_text, compact_sc_color = 'BUSY ' .. choice_text, 'orange'
        else
            skillchain_text = tostring(react_status) .. ' - ' .. tostring(react_opener)
            skillchain_color = 'orange'
            compact_sc_text, compact_sc_color = tostring(react_status), 'orange'
        end
        utility_parts[#utility_parts + 1] = hud_field('Manual SC closer', skillchain_text, skillchain_color)
    end
    utility_parts[#utility_parts + 1] = hud_field('Treasure Hunter',
        treasure_hunter and 'ON - TH+3 override' or 'off',
        treasure_hunter and 'yellow' or 'dim')
    utility_parts[#utility_parts + 1] = hud_field('Ammo safety',
        ranged_lock and 'ON - normal shots blocked; WS allowed' or 'OFF - normal shots allowed',
        ranged_lock and 'green' or 'orange')
    local automation_row = hud_row('UTILITY', table.concat(utility_parts, separator))

    local safety_parts = {
        hud_field('Low-HP DT lean', hp_lean and 'ACTIVE' or 'off', hp_lean and 'orange' or 'dim'),
    }
    if doom_active then
        safety_parts[#safety_parts + 1] = hud_field('Doom', 'ACTIVE - ring protection owns slots', 'red')
    end
    local safety_row = hud_row('SAFETY', table.concat(safety_parts, separator))

    local haste_text = string.format('%.1f%% native estimate', native_haste_pct)
    if math.abs(manual_haste_pct) >= 0.05 then
        haste_text = haste_text .. string.format(' (%+.1f manual)', manual_haste_pct)
    end
    local dw_text, dw_color
    if DW == true then
        dw_text = string.format('trait %d + gear %d/%d', dw_trait, dw_have or 0, DW_needed or 0)
        if dw_shortfall then
            dw_text, dw_color = dw_text .. ' SHORT', 'red'
        elseif dw_sailfi_active then
            dw_text, dw_color = dw_text .. ' OK (Sailfi)', 'orange'
        else
            dw_text, dw_color = dw_text .. ' OK', 'green'
        end
    else
        dw_text, dw_color = 'single wield / shield - no gear DW needed', 'dim'
    end
    local combat_math_row = hud_row('NATIVE MATH',
        hud_field('Haste', haste_text, 'cyan')
        .. separator .. hud_field('Dual Wield', dw_text, dw_color)
        .. separator .. hud_field('Movement source', 'native coordinates', 'green'))

    local fc_text, fc_color
    if fc_instant then
        fc_text, fc_color = 'INSTANT - FC traded for DT/M.Eva', 'yellow'
    else
        fc_text = string.format('gear %d/%d toward 80%% cap', fc_current_gear or 0, fc_gear_target or 0)
        fc_color = (fc_current_gear or 0) >= (fc_gear_target or 0) and 'green' or 'red'
    end
    if fc_dt_order_active then fc_text = fc_text .. ' / DT shed order' end
    if caster_roll_active and caster_roll_value then
        fc_text = fc_text .. " / Caster's Roll ~" .. tostring(caster_roll_value) .. '%'
    end
    local cast_math_row = hud_row('CAST MATH', hud_field('Fast Cast', fc_text, fc_color))

    local key_row_1 = hud_row('F9-F12',
        col('value', 'F10 Manual Magic Burst  |  F11 Manual SC Closer  |  F12 Weapon-Aware WS'))
    local key_row_2 = hud_row('CTRL F9-F12',
        col('value', 'F9 Previous Weapon  |  F10 Next Weapon  |  F11 Weapon Lock  |  F12 Silmaril'))
    local key_row_3 = hud_row('COMBAT KEYS',
        col('value', 'Ctrl+F1 Melee Accuracy  |  Ctrl+F2 Melee DT  |  Ctrl+F3 Defense  |  Ctrl+F4 Casting'))
    local key_row_4 = hud_row('SUPPORT KEYS',
        col('value', 'Ctrl+F5 Enfeebling  |  Ctrl+F6 Enspell Melee  |  Ctrl+F7 Idle Gear'))
    local key_row_5 = hud_row('MODE KEYS',
        col('value', 'Alt+F1 TH  |  Alt+F2 Fishing  |  Alt+F3 Pause'))
    local key_row_6 = hud_row('HUD KEYS',
        col('value', 'Alt+F9 Move Lock/Unlock  |  Alt+F10 Show/Hide'))

    local rows = {title, rule}
    if hud_config.layout == 'compact' then
        if hud_section_enabled('loadout') then
            rows[#rows + 1] = pill('Weapon', weapon_label, 'cyan')
                .. ' ' .. pill('Style', playstyle_label, playstyle_color)
        end
        if hud_section_enabled('combat') then
            rows[#rows + 1] = pill('Melee Acc', offense, acc_color)
                .. ' ' .. pill('Melee DT', melee_dt_display, hybrid_color)
                .. ' ' .. pill('Defense', defense_display, defense_mode ~= 'Normal' and 'orange' or 'value')
                .. ' ' .. pill('Move', move_text, move_color)
        end
        if hud_section_enabled('magic') then
            rows[#rows + 1] = pill('Cast', casting_mode, casting_mode == 'Normal' and 'value' or 'orange')
                .. ' ' .. pill('Enfeeble', enfeebling_mode,
                    enfeebling_mode == 'Auto' and 'cyan' or 'orange')
                .. ' ' .. pill('Enspell', enspell_mode, enspell_color)
        end
        if hud_section_enabled('automation') then
            local compact_utility_parts = {}
            if mb_active then
                compact_utility_parts[#compact_utility_parts + 1] = pill(
                    'F10 MB', compact_mb_text or mb_status, compact_mb_color or 'orange')
            end
            if react_active then
                compact_utility_parts[#compact_utility_parts + 1] = pill(
                    'F11 SC', compact_sc_text or react_status, compact_sc_color or 'orange')
            end
            compact_utility_parts[#compact_utility_parts + 1] = pill(
                'TH', treasure_hunter and 'ON' or 'off', treasure_hunter and 'yellow' or 'dim')
            compact_utility_parts[#compact_utility_parts + 1] = pill(
                'Ammo', ranged_lock and 'SAFE' or 'LIVE', ranged_lock and 'green' or 'orange')
            if doom_active then
                compact_utility_parts[#compact_utility_parts + 1] = pill('DOOM', 'ACTIVE', 'red')
            end
            rows[#rows + 1] = table.concat(compact_utility_parts, ' ')
        end
        if hud_section_enabled('diagnostics') then
            rows[#rows + 1] = pill('Haste', string.format('%.1f%%', native_haste_pct), 'cyan')
                .. ' ' .. pill('DW', dw_text, dw_color)
                .. ' ' .. pill('FC', fc_instant and 'INSTANT' or
                    string.format('%d/%d', fc_current_gear or 0, fc_gear_target or 0), fc_color)
        end
        if hud_section_enabled('shortcuts') then
            rows[#rows + 1] = key_row_1
            rows[#rows + 1] = key_row_2
            rows[#rows + 1] = key_row_6
        end
    else
        if hud_section_enabled('loadout') then
            rows[#rows + 1] = loadout_row
            rows[#rows + 1] = style_row
            rows[#rows + 1] = ws_hint_row
        end
        if hud_section_enabled('combat') then
            rows[#rows + 1] = melee_row
            rows[#rows + 1] = defense_row
        end
        if hud_section_enabled('magic') then
            rows[#rows + 1] = casting_row
            rows[#rows + 1] = enfeebling_row
            rows[#rows + 1] = quick_cast_row
        end
        if hud_section_enabled('automation') then
            rows[#rows + 1] = automation_row
            rows[#rows + 1] = safety_row
        end
        if hud_section_enabled('diagnostics') then
            rows[#rows + 1] = combat_math_row
            rows[#rows + 1] = cast_math_row
        end
        if hud_section_enabled('shortcuts') then
            rows[#rows + 1] = key_row_1
            rows[#rows + 1] = key_row_2
            rows[#rows + 1] = key_row_3
            rows[#rows + 1] = key_row_4
            rows[#rows + 1] = key_row_5
            rows[#rows + 1] = key_row_6
        end
    end

    local text = table.concat(rows, '\n')
    if text ~= hud_last_text then
        hud_last_text = text
        hud:text(text)
        perf_count('hud_renders')
    end
    perf_finish('hud', perf_t)
end
-- @ai:fn toggle_hud | layer=hud | hot=no | purity=write | contract=Toggle visibility without leaving hidden HUD work active.
function toggle_hud()
    if not hud then return end
    hud_visible = not hud_visible
    if hud_visible then update_hud(true); hud:show() else hud:hide() end
    if save_hud_preferences then save_hud_preferences(true) end
end

-- @ai:fn toggle_hud_lock | layer=hud | hot=no | purity=write | contract=Toggle drag lock only.
function toggle_hud_lock()
    if not hud then return end
    local unlocked = hud:draggable()
    hud:draggable(not unlocked)
    -- Locking normally follows a drag, but save on either transition so the
    -- position and all presentation choices are durable immediately.
    if save_hud_preferences then save_hud_preferences(true) end
    add_to_chat(158, unlocked and '** [HUD LOCKED -- position fixed] **' or '** [HUD UNLOCKED -- drag to reposition] **')
end

-- @ai:fn hud_config_report | layer=hud | hot=no | purity=write | contract=Report HUD configuration to chat.
local function hud_config_report()
    local shown = {}
    for _, name in ipairs(HUD_SECTION_ORDER) do
        if hud_section_enabled(name) then shown[#shown + 1] = name end
    end
    local x, y = current_hud_position()
    add_to_chat(158, string.format('[HUD] saved per character | layout=%s scale=%.2f opacity=%d visible=%s position=%d,%d sections=%s',
        hud_config.layout, hud_config.scale, hud_config.opacity,
        hud_visible and 'yes' or 'no', x, y, table.concat(shown, ',')))
end

-- @ai:fn set_hud_layout | layer=hud | hot=no | purity=write | contract=Validate/apply layout then force one redraw.
local function set_hud_layout(value)
    value = (value or ''):lower()
    if value ~= 'compact' and value ~= 'expanded' then
        add_to_chat(158, '[HUD] layout: compact | expanded')
        return
    end
    hud_config.layout = value
    hud_last_text = nil; update_hud(true)
    if save_hud_preferences then save_hud_preferences(true) end
    hud_config_report()
end

-- @ai:fn set_hud_scale | layer=hud | hot=no | purity=write | contract=Clamp/apply scale then force one redraw.
local function set_hud_scale(value)
    local scale = tonumber(value)
    if not scale then add_to_chat(158, '[HUD] scale: 0.70 .. 1.60'); return end
    hud_config.scale = math.max(0.70, math.min(1.60, scale))
    apply_hud_style(); update_hud(true)
    if save_hud_preferences then save_hud_preferences(true) end
    hud_config_report()
end

-- @ai:fn set_hud_opacity | layer=hud | hot=no | purity=write | contract=Clamp/apply opacity then force one redraw.
local function set_hud_opacity(value)
    local opacity = tonumber(value)
    if not opacity then add_to_chat(158, '[HUD] opacity: 0 .. 255'); return end
    hud_config.opacity = math.max(0, math.min(255, math.floor(opacity + 0.5)))
    apply_hud_style(); update_hud(true)
    if save_hud_preferences then save_hud_preferences(true) end
    hud_config_report()
end

-- @ai:fn set_hud_section | layer=hud | hot=no | purity=write | contract=Validate section visibility mutation then force one redraw.
local function set_hud_section(name, value)
    name, value = (name or ''):lower(), (value or ''):lower()
    name = hud_section_aliases[name] or name
    if hud_config.sections[name] == nil then
        add_to_chat(158, '[HUD] section: loadout | combat | magic | automation | diagnostics | shortcuts')
        add_to_chat(158, '[HUD] old aliases still work: modes=loadout | casting=magic | keys=shortcuts')
        return
    end
    if value == 'toggle' or value == '' then
        hud_config.sections[name] = not hud_config.sections[name]
    elseif value == 'on' then
        hud_config.sections[name] = true
    elseif value == 'off' then
        hud_config.sections[name] = false
    else
        add_to_chat(158, '[HUD] section value: on | off | toggle')
        return
    end
    hud_last_text = nil; update_hud(true)
    if save_hud_preferences then save_hud_preferences(true) end
    hud_config_report()
end

-- @ai:fn report_fc_tier | layer=fc | hot=no | purity=write | contract=Explain FC math; diagnostic-only.
function report_fc_tier()
    local native = rdm_native_fc()
    if fc_instant then
        local full_gear_fc = (tonumber(fc_core_value) or 0) + (tonumber(fc_ladder_value) or 0)
        add_to_chat(158, string.format('[FC] Chainspell/Spontaneity: casts are instant -- all %d gear FC percentage points traded for DT/M.Eva', full_gear_fc))
        return
    end
    local roll_up = buffactive and buffactive["Caster's Roll"] and state and state.CasterRollFC
    local roll = roll_up and (tonumber(state.CasterRollFC.value) or 0) or 0
    local roll_note = roll_up
        and string.format(" + Caster's Roll ~%d%%", roll) or ""
    local order_note = fc_dt_order_active and " [DT-priority sheds]" or ""
    add_to_chat(158, string.format("[FC] native %d%% (trait+mastered gifts, %d JP baseline)%s -> gear target %d%%; set carries %d%%%s",
        native, fc_jp_spent, roll_note, fc_gear_target or 0, fc_current_gear, order_note))
    if fc_shed_list and #fc_shed_list > 0 then
        add_to_chat(158, '[FC] shed for DT/M.Eva: '..table.concat(fc_shed_list, ', '))
    else
        add_to_chat(158, '[FC] full FC pool worn (nothing shed)')
    end
    local total = native + roll + fc_current_gear
    if total < 80 then
        add_to_chat(167, string.format('[FC] WARNING: %d%% below the 80%% cast cap', 80 - total))
    end
end

-------------------------------------------------------------------------------
-- Native haste estimator (authoritative; GearInfo is comparison-only).
--
-- UNITS: everything internal is in 1024ths, matching the game engine and
-- native delay math. 1% = 10.24/1024. Caps: gear 256 (25%), magic 448 (43.75%),
-- JA 256 (25%), and a global 819 (~80%) delay-reduction ceiling.
-- NOTE: the Haste value GearInfo streams to us (cmdParams[3]) is ALSO in
-- 1024ths, not percent -- the HUD converts for display.
--
-- Gear: summed from player.equipment against item_stats (ItemStats.lua)
-- 'haste' fields; unlisted items count 0.
-- Magic/JA: read from buffactive with conservative ASSUMED potencies below.
-- The Haste icon does not encode tier (Haste vs Haste II look identical).
-- Haste Samba is intentionally NOT inferred from its self-buff alone: the 5% JA
-- haste benefit is target/hit-dependent (Haste Daze), so auto-counting it could
-- under-request DW before the current target is actually affected.
-- KNOWN BLIND SPOT: Geo-Haste/Indi-Haste set no personal buff icon, so the
-- estimator can't see them; use 'gs c hasteadj <pct>' to feed a manual
-- correction (e.g. gs c hasteadj 33 under an Idris Geo-Haste, 0 to clear).
-------------------------------------------------------------------------------

haste_assume = {
    magic = {
        ['Haste']        = 307,  -- assumes Haste II (30%); use 150 for Haste I
        ['March']        = 170,  -- per March instance (~Honor March)
        ['Embrava']      = 266,
        ['Mighty Guard'] = 150,
    },
    ja = {
        ['Hasso']        = 103,
    },
}

haste_manual_magic = 0   -- 1024ths; set via 'gs c hasteadj <pct>' (Geo etc.)
local haste_estimate = {gear=0, magic=0, ja=0, total=0, pct=0}
local haste_buff_cache = {dirty=true, magic=0, ja=0}
haste_relevant_buffs = S{'haste','march','embrava','mighty guard','hasso'}

-- @ai:fn invalidate_haste_buff_cache | layer=haste-dw | hot=yes | purity=write | contract=Mark visible magic/JA haste contribution dirty only when a relevant buff or Haste-tier assumption changes.
function invalidate_haste_buff_cache()
    haste_buff_cache.dirty = true
end

-- @ai:fn refresh_haste_buff_cache | layer=haste-dw | hot=yes | purity=write | contract=Recompute visible magic/JA haste from buffactive only after invalidation; cache hits perform no buff map scan.
local function refresh_haste_buff_cache()
    local c = haste_buff_cache
    if not c.dirty then
        perf_count('haste_buff_cache_hits')
        return c
    end
    local b = buffactive
    local magic, ja = 0, 0
    if b then
        local n = b['Haste']
        if n then magic = magic + (haste_assume.magic['Haste'] or 0) * (tonumber(n) or 1) end
        n = b['March']
        if n then magic = magic + (haste_assume.magic['March'] or 0) * (tonumber(n) or 1) end
        if b['Embrava'] then magic = magic + (haste_assume.magic['Embrava'] or 0) end
        if b['Mighty Guard'] then magic = magic + (haste_assume.magic['Mighty Guard'] or 0) end
        if b['Hasso'] then ja = ja + (haste_assume.ja['Hasso'] or 0) end
    end
    c.magic = math.min(magic, 448)
    c.ja = math.min(ja, 256)
    c.dirty = false
    perf_count('haste_buff_rebuilds')
    return c
end

-- Equipment-derived values are immutable until an equipped item name changes.
-- Keep one compact snapshot so HUD/diagnostic callers do not repeatedly perform
-- ItemStats lookups for the same sixteen slots. Cache hits compare names in place
-- with no temporary table/signature allocation and still catch manual equips.
local equipment_snapshot_slots = {
    'main','sub','range','ammo','head','neck','left_ear','right_ear',
    'body','hands','left_ring','right_ring','back','waist','legs','feet',
}
local equipment_snapshot = {initialized=false, names={}, gear_haste=0, gear_dw=0}

-- @ai:fn get_equipment_snapshot | layer=haste-dw | hot=yes | purity=write | contract=Allocation-free cache-hit path for equipment names/derived haste; ItemStats scans only after a slot actually changes.
local function get_equipment_snapshot()
    local equipment = player and player.equipment
    if not equipment then
        return equipment_snapshot
    end

    local names = equipment_snapshot.names
    local changed = not equipment_snapshot.initialized
    if not changed then
        for i, slot in ipairs(equipment_snapshot_slots) do
            if names[i] ~= (equipment[slot] or '') then
                changed = true
                break
            end
        end
    end
    if not changed then
        perf_count('equipment_snapshot_hits')
        return equipment_snapshot
    end

    local gear_haste, gear_dw = 0, 0
    for i, slot in ipairs(equipment_snapshot_slots) do
        local name = equipment[slot] or ''
        names[i] = name
        local st = item_stats and item_stats[name]
        if st then
            gear_haste = gear_haste + (st.haste or 0)
            gear_dw = gear_dw + (st.dw or 0)
        end
    end

    equipment_snapshot.initialized = true
    equipment_snapshot.gear_haste = math.min(gear_haste, 256)
    equipment_snapshot.gear_dw = gear_dw
    perf_count('equipment_snapshot_rebuilds')
    return equipment_snapshot
end

-- @ai:fn estimate_haste | layer=haste-dw | hot=yes | purity=write | contract=Reuse one haste snapshot plus invalidation-cached buff buckets; callers treat result as ephemeral read-only state.
function estimate_haste()
    local gear = get_equipment_snapshot().gear_haste
    local buffs = refresh_haste_buff_cache()
    local magic = math.min(448, buffs.magic + haste_manual_magic)
    local ja = buffs.ja

    local total = gear + magic + ja
    if total > 819 then total = 819 end
    local e = haste_estimate
    e.gear, e.magic, e.ja, e.total = gear, magic, ja, total
    e.pct = total / 1024 * 100
    return e
end

-- Total DW (trait+gear) needed to cap delay at a given total haste (1024ths):
-- (1 - DW) * (1 - haste) = 0.2  =>  DW = 1 - 0.2/(1 - haste).
-- @ai:fn dw_needed_at_haste | layer=haste-dw | hot=yes | purity=pure | contract=Pure delay-cap formula from haste1024 to total DW percent.
function dw_needed_at_haste(h1024)
    if h1024 >= 819 then return 0 end
    return math.ceil((1 - 0.2 / ((1024 - h1024) / 1024)) * 100)
end

-- Native authoritative haste/DW state. GearInfo values are stored separately
-- and never overwrite these globals. The offhand test deliberately rejects the
-- shield/grip families used by this profile; any actual weapon in sub enables DW.
local native_non_weapon_subs = S{'Ammurapi Shield', 'Enki Strap'}
local native_state_active = nil
local native_state_haste = nil
local native_state_gear_haste = nil
local native_state_trait = nil
local native_state_gear_need = nil
local native_dw_plan_mask = nil
local native_dw_plan_cape = false
local native_dw_plan_sailfi = false
local native_dw_plan_shortfall = false
local native_dw_plan_have = 0
local dw_overlay_active_cache = nil
local dw_overlay_need_cache = nil
local projected_melee_haste_scratch = {}
local projected_dw_result = {}
local projected_haste_slots = {
    'main','sub','range','ammo','head','neck','ear1','ear2',
    'body','hands','ring1','ring2','back','waist','legs','feet',
}

-- @ai:fn native_dual_wield_active | layer=haste-dw | hot=yes | purity=read | contract=Return true only when native DW trait and weapon-like offhand are both present.
local function native_dual_wield_active(trait)
    if (trait or dw_native_trait()) <= 0 then return false end
    local sub = player and player.equipment and (player.equipment.sub or player.equipment.left_sub)
    if not sub or sub == '' or sub == 'empty' then return false end
    return not native_non_weapon_subs:contains(sub)
end

-- @ai:fn projected_engaged_gear_haste | layer=haste-dw | hot=yes | purity=write | contract=Resolve final DW melee gear haste for one candidate mask/Sailfi choice without allocating or reading transient idle gear.
local function projected_engaged_gear_haste(mask, sailfi)
    local index = engaged_set_index and engaged_set_index.DW
    local offense = state and state.OffenseMode and state.OffenseMode.value or 'Normal'
    local hybrid = state and state.HybridMode and state.HybridMode.value or 'Normal'
    local base = index and index[offense] and index[offense][hybrid]
    if not (base and dw_pool and capes) then return nil end

    local scratch = projected_melee_haste_scratch
    for _, slot in ipairs(projected_haste_slots) do scratch[slot] = base[slot] end

    local enspell_set = type(resolved_enspell_melee_set) == 'function'
        and resolved_enspell_melee_set() or nil
    if enspell_set then
        for _, slot in ipairs(projected_haste_slots) do
            local item = enspell_set[slot]
            if item ~= nil then scratch[slot] = item end
        end
    end
    if monitor_state and monitor_state.hp_lean and sets.engaged.Hybrid then
        for _, slot in ipairs(projected_haste_slots) do
            local item = sets.engaged.Hybrid[slot]
            if item ~= nil then scratch[slot] = item end
        end
    end

    for i, entry in ipairs(dw_pool) do
        local active = math.floor(mask / 2 ^ (i - 1)) % 2 == 1
        if active then
            scratch[entry.slot] = entry.piece
        elseif dw_item_name(scratch[entry.slot]) == entry.piece then
            scratch[entry.slot] = entry.off
        end
    end
    scratch.back = mask ~= nil and capes.dw or capes.da
    if sailfi then
        scratch.waist = "Sailfi Belt +1"
    elseif dw_item_name(scratch.waist) == "Sailfi Belt +1" then
        scratch.waist = "Windbuffet Belt +1"
    end

    local haste = 0
    for _, slot in ipairs(projected_haste_slots) do
        haste = haste + item_stat(dw_item_name(scratch[slot]), 'haste')
    end
    return math.min(haste, RDM_MECHANICS.caps.gear_haste_1024)
end

-- @ai:fn resolve_projected_dw_plan | layer=haste-dw | hot=yes | purity=write | contract=Enumerate eight owned DW subsets against their own projected gear haste; prefer no Sailfi, then minimum DW sacrifice, and report true residual shortfall.
local function resolve_projected_dw_plan(trait, magic_haste, ja_haste)
    if not (dw_pool and #dw_pool > 0) then return nil end
    local max_mask = (2 ^ #dw_pool) - 1
    local best_mask, best_sum, best_prio, best_need, best_haste, best_have
    local best_sailfi = false

    -- First preserve the normal waist. Only if no owned subset is self-consistent
    -- do a second pass with Sailfi's +9% gear haste.
    for pass = 1, 2 do
        local sailfi = pass == 2
        best_mask, best_sum, best_prio = nil, nil, nil
        for mask = 0, max_mask do
            local gear_haste = projected_engaged_gear_haste(mask, sailfi)
            if gear_haste then
                local delay_haste = math.min(RDM_MECHANICS.caps.total_haste_1024,
                    gear_haste + magic_haste + ja_haste)
                local need = math.max(0, dw_needed_at_haste(delay_haste) - trait)
                local sum, prio = 0, 0
                for i, entry in ipairs(dw_pool) do
                    if math.floor(mask / 2 ^ (i - 1)) % 2 == 1 then
                        sum = sum + (entry.dw or 0)
                        prio = prio + (entry.prio or 0)
                    end
                end
                local cape = need > 0
                local have = (cape and dw_cape_constant or 0) + sum
                if have >= need and (best_sum == nil or sum < best_sum
                    or (sum == best_sum and prio < best_prio)) then
                    best_mask, best_sum, best_prio = mask, sum, prio
                    best_need, best_haste, best_have = need, delay_haste, have
                    best_sailfi = sailfi
                end
            end
        end
        if best_mask ~= nil then break end
    end

    local shortfall = false
    if best_mask == nil then
        best_mask = max_mask
        best_sailfi = true
        local gear_haste = projected_engaged_gear_haste(best_mask, true)
        if not gear_haste then return nil end
        best_haste = math.min(RDM_MECHANICS.caps.total_haste_1024,
            gear_haste + magic_haste + ja_haste)
        best_need = math.max(0, dw_needed_at_haste(best_haste) - trait)
        best_have = dw_cape_constant
        for _, entry in ipairs(dw_pool) do best_have = best_have + (entry.dw or 0) end
        shortfall = best_have < best_need
    end

    projected_dw_result.mask = best_mask
    projected_dw_result.cape = best_need > 0
    projected_dw_result.sailfi = best_sailfi
    projected_dw_result.shortfall = shortfall
    projected_dw_result.need = best_need
    projected_dw_result.haste = best_haste
    projected_dw_result.gear_haste =
        projected_engaged_gear_haste(best_mask, best_sailfi)
    projected_dw_result.have = best_have
    return projected_dw_result
end

-- @ai:fn update_native_haste_dw | layer=haste-dw | hot=yes | purity=write | contract=Authoritative projected Haste/DW/DW_needed owner; invalidate the overlay when active state, requirement, or selected plan changes.
function update_native_haste_dw(force)
    local e = estimate_haste()
    local trait = dw_native_trait()
    local active = native_dual_wield_active(trait)
    local plan = active and resolve_projected_dw_plan(trait, e.magic, e.ja) or nil
    -- During the early Mote initialization window engaged sets do not exist yet;
    -- retain the prior safe capped fallback until the first real gear resolution.
    local gear_haste = plan and plan.gear_haste
        or (active and RDM_MECHANICS.caps.gear_haste_1024 or e.gear)
    local delay_haste = plan and plan.haste
        or (active and math.min(RDM_MECHANICS.caps.total_haste_1024,
            gear_haste + e.magic + e.ja) or e.total)
    local gear_need = plan and plan.need
        or (active and math.max(0, dw_needed_at_haste(delay_haste) - trait) or 0)
    local plan_mask = plan and plan.mask or nil
    local plan_cape = plan and plan.cape or false
    local plan_sailfi = plan and plan.sailfi or false
    local plan_shortfall = plan and plan.shortfall or false
    local plan_have = plan and plan.have or 0

    local active_changed = active ~= native_state_active
    local haste_changed = delay_haste ~= native_state_haste
    local trait_changed = trait ~= native_state_trait
    local need_changed = gear_need ~= native_state_gear_need
    local plan_changed = plan_mask ~= native_dw_plan_mask
        or plan_cape ~= native_dw_plan_cape
        or plan_sailfi ~= native_dw_plan_sailfi
        or plan_shortfall ~= native_dw_plan_shortfall
    local state_changed = active_changed or haste_changed or trait_changed
        or need_changed or plan_changed

    if not force and not state_changed then
        return false, false
    end

    -- Cause counters explain live native-state churn without affecting behavior
    -- while profiling is off. A haste-only change does NOT imply a gear change.
    if active_changed then perf_count('native_dw_active_changes') end
    if haste_changed then perf_count('native_dw_haste_changes') end
    if trait_changed then perf_count('native_dw_trait_changes') end
    if need_changed then perf_count('native_dw_need_changes') end
    if plan_changed then perf_count('native_dw_plan_changes') end
    if force and not state_changed then perf_count('native_dw_force_refreshes') end

    native_state_active = active
    native_state_haste = delay_haste
    native_state_gear_haste = gear_haste
    native_state_trait = trait
    native_state_gear_need = gear_need
    native_dw_plan_mask = plan_mask
    native_dw_plan_cape = plan_cape
    native_dw_plan_sailfi = plan_sailfi
    native_dw_plan_shortfall = plan_shortfall
    native_dw_plan_have = plan_have
    Haste = delay_haste
    DW = active
    DW_needed = gear_need

    local overlay_changed = active_changed or need_changed or plan_changed
    if overlay_changed then
        dw_overlay_active_cache = nil
        dw_overlay_need_cache = nil
        perf_count('dw_overlay_invalidations')
    end
    return true, overlay_changed
end

-- @ai:fn report_haste_check | layer=haste-dw | hot=no | purity=write | contract=Diagnostic comparison; never treat stale/offline GearInfo as authoritative zero.
function report_haste_check()
    local e = estimate_haste()
    local active = native_dual_wield_active()
    local native_total = active and (native_state_haste or e.total) or e.total
    local native_gear = active and (native_state_gear_haste or e.gear) or e.gear
    local gi_alive = gearinfo_last and (os.clock() - gearinfo_last) <= GEARINFO_STALE_SECONDS or false
    local gi = GI_Haste or 0   -- optional GearInfo comparison feed, 1024ths
    add_to_chat(158, string.format(
        '[Haste] NATIVE: gear %d/256 + magic %d/448 + JA %d/256 = %d/819 (%.1f%%)%s',
        native_gear, e.magic, e.ja, native_total, native_total / 1024 * 100,
        haste_manual_magic ~= 0
            and string.format('  [manual magic adj %+d]', haste_manual_magic) or ''))
    if gi_alive then
        add_to_chat(158, string.format(
            '[Haste] GearInfo comparison: %d/1024 (%.1f%%) -- delta %.1f pts',
            gi, gi / 1024 * 100, math.abs(gi - native_total) / 1024 * 100))
    else
        add_to_chat(158, '[Haste] GearInfo comparison: offline/stale (native tracking remains authoritative)')
    end
    local trait = dw_native_trait()
    local pool_max = dw_cape_constant
    for _, p in ipairs(dw_pool) do pool_max = pool_max + p.dw end
    local est_need = dw_needed_at_haste(native_total)
    if gi_alive then
        local gi_need = dw_needed_at_haste(gi)
        add_to_chat(158, string.format(
            '[Haste] total DW to cap: %d (native) vs %d (GI)  [trait %d + wardrobe max %d = %d reachable]',
            est_need, gi_need, trait, pool_max, trait + pool_max))
        if math.abs(gi - native_total) > 31 then
            add_to_chat(167, '[Haste] WARNING: native estimate and GearInfo diverge by >3 pts -- check haste assumptions or an unseen Geo bubble')
        end
    else
        add_to_chat(158, string.format(
            '[Haste] total DW to cap: %d native  [trait %d + wardrobe max %d = %d reachable]',
            est_need, trait, pool_max, trait + pool_max))
    end
end


--
-- Native tracking derives DW_needed = gear DW required to cap delay under the
-- projected resolved-set + magic/JA haste. GearInfo is comparison-only. Only
-- three swappable DW pieces exist in inventory (plus the DW+10 cape), so the
-- engine checks ALL 8 subsets against the gear haste each subset would actually
-- produce. Carmine/Enspell under-cap variants can therefore never hide behind a
-- blanket 25% gear-haste assumption.
--
-- POLICY: a needed DW piece wins its slot over Acc/DT variant pieces
-- (Mache/Cessance/Alabaster) -- delay cap first, accuracy compensates via
-- neck/ammo. Unneeded DW remnants left in a variant set are stripped back to
-- the base piece; non-DW slot choices are never touched. Sailfi is considered
-- only when no normal-waist subset is self-consistent; a residual shortage after
-- Sailfi and the full pool turns the HUD DW readout red.
--
-- 'gs c dwinfo' prints the current math.
-------------------------------------------------------------------------------

-- DW values are filled from ItemStats.lua by resolve_dw_pool() (called from
-- job_setup) -- this table is defined at file top-level, which executes
-- BEFORE get_sets() includes the sidecar, so stats can't be read here.
dw_pool = {
    {slot='ear2', piece="Suppanomimi",        off="Telos Earring",      prio=1},
    {slot='ear1', piece="Eabani Earring",     off="Brutal Earring",     prio=2},
    {slot='legs', piece="Carmine Cuisses +1", off="Malignance Tights",  prio=4},
}
dw_cape_constant = 10   -- overwritten by resolve_dw_pool(); safe fallback
dw_have = 0
dw_shortfall = false
dw_sailfi_active = false
local dw_subset_plan = {}

-- @ai:fn rebuild_dw_subset_plan | layer=haste-dw | hot=no | purity=write | contract=Precompute minimal three-piece DW subset for every possible gear-DW target; update path becomes O(1).
local function rebuild_dw_subset_plan()
    dw_subset_plan = {}
    local n = #dw_pool
    local max_mask = (2 ^ n) - 1
    local full_sum = 0
    for i = 1, n do full_sum = full_sum + (dw_pool[i].dw or 0) end

    for target = 0, 100 do
        local best_mask, best_sum, best_prio = nil, nil, nil
        for mask = 0, max_mask do
            local sum, prio = 0, 0
            for i = 1, n do
                if math.floor(mask / 2 ^ (i - 1)) % 2 == 1 then
                    sum = sum + (dw_pool[i].dw or 0)
                    prio = prio + (dw_pool[i].prio or 0)
                end
            end
            if sum >= target and (best_sum == nil or sum < best_sum
                or (sum == best_sum and prio < best_prio)) then
                best_mask, best_sum, best_prio = mask, sum, prio
            end
        end
        if best_mask == nil then
            dw_subset_plan[target] = {mask=max_mask, sum=full_sum, shortfall=true}
        else
            dw_subset_plan[target] = {mask=best_mask, sum=best_sum, shortfall=false}
        end
    end
end

-- @ai:fn resolve_dw_pool | layer=haste-dw | hot=no | purity=write | contract=Populate DW policy values from ItemStats and rebuild the constant-time subset plan.
function resolve_dw_pool()
    for _, e in ipairs(dw_pool) do
        e.dw = item_stat(e.piece, 'dw')
    end
    dw_cape_constant = item_stat("Sucellos's Cape (DW path)", 'dw')
    rebuild_dw_subset_plan()
    dw_overlay_active_cache = nil
    dw_overlay_need_cache = nil
end

-- Native (trait) Dual Wield from the subjob, tiered by actual sub level --
-- the DW analog of rdm_native_fc(). RDM itself has no DW trait, so only the
-- subjob contributes. Master Levels raise the sub cap to 59, so /NIN tops
-- out at DW III (25%) and /DNC at DW II (15%) in practice; higher tiers are
-- listed anyway so the table is complete.
--
-- Native tracking subtracts this trait from the total DW required by the
-- delay-cap formula; update_dw_overlay() therefore receives a gear-only target.
dw_trait_tiers = {
    NIN = { {85, 35}, {65, 30}, {45, 25}, {25, 15}, {10, 10} },
    DNC = { {80, 30}, {60, 25}, {40, 15}, {20, 10} },
}

-- @ai:fn dw_native_trait | layer=haste-dw | hot=yes | purity=read | contract=Derive /NIN or /DNC trait from actual reported subjob level.
function dw_native_trait()
    local sj = player and player.sub_job
    local tiers = sj and dw_trait_tiers[sj]
    if not tiers then return 0 end
    local lvl = (player and player.sub_job_level) or 0
    for _, t in ipairs(tiers) do
        if lvl >= t[1] then return t[2] end
    end
    return 0
end

-- @ai:fn dw_item_name | layer=haste-dw | hot=yes | purity=pure | contract=Normalize string or augmented item reference to display name.
function dw_item_name(it) return type(it) == 'table' and it.name or it end

-- Apply the projected-set plan selected by update_native_haste_dw. The older
-- target-only table remains a safe initialization fallback before engaged sets
-- exist, but normal runtime plans account for each subset's own resulting haste.
-- @ai:fn update_dw_overlay | layer=haste-dw | hot=yes | purity=write | contract=Apply the authoritative projected DW mask/cape/Sailfi plan; use target-only fallback solely during early initialization.
function update_dw_overlay()
    local active = DW == true
    local need = DW_needed or 0
    if active == dw_overlay_active_cache and need == dw_overlay_need_cache then
        perf_count('dw_cache_hits')
        return
    end

    perf_count('dw_rebuilds')
    local perf_t = perf_begin()
    if not active then
        for _, e in ipairs(dw_pool) do e.active = false end
        dw_cape_active = false
        dw_have, dw_shortfall, dw_sailfi_active = 0, false, false
        dw_overlay_active_cache, dw_overlay_need_cache = active, need
        perf_finish('dw_rebuild', perf_t)
        return
    end

    local mask = native_dw_plan_mask
    if mask ~= nil then
        dw_cape_active = native_dw_plan_cape
        dw_sailfi_active = native_dw_plan_sailfi
        dw_shortfall = native_dw_plan_shortfall
        dw_have = native_dw_plan_have
    else
        dw_cape_active = need > 0
        local target = math.max(0, need - (dw_cape_active and dw_cape_constant or 0))
        local fallback = dw_subset_plan[math.min(100, target)]
        if not fallback then
            rebuild_dw_subset_plan()
            fallback = dw_subset_plan[math.min(100, target)]
        end
        mask = fallback.mask
        dw_shortfall = fallback.shortfall
        dw_sailfi_active = fallback.shortfall
        dw_have = (dw_cape_active and dw_cape_constant or 0) + fallback.sum
    end

    for i = 1, #dw_pool do
        dw_pool[i].active = math.floor(mask / 2 ^ (i - 1)) % 2 == 1
    end
    dw_overlay_active_cache, dw_overlay_need_cache = active, need
    perf_finish('dw_rebuild', perf_t)
end

-- @ai:fn report_dw_tier | layer=haste-dw | hot=no | purity=write | contract=Diagnostic-only explanation of selected DW subset.
function report_dw_tier()
    if DW ~= true then
        add_to_chat(158, '[DW] not dual wielding (native offhand/trait check inactive)')
        return
    end
    local worn, stripped = {}, {}
    for _, e in ipairs(dw_pool) do
        if e.active then worn[#worn+1] = e.piece .. ' +' .. e.dw
        else stripped[#stripped+1] = e.piece end
    end
    local trait = dw_native_trait()
    local trait_note = (trait > 0)
        and string.format('native %d%% (/%s%d trait) + ', trait,
            player.sub_job or '?', player.sub_job_level or 0)
        or ''
    local cape_txt = dw_cape_active
        and ('cape ' .. dw_cape_constant .. ' + ')
        or 'DA cape (DW cape unneeded) + '
    add_to_chat(158, string.format('[DW] %sgear need %d -> %s%s = %d worn (total %d/%d)%s',
        trait_note,
        DW_needed or 0,
        cape_txt,
        (#worn > 0) and table.concat(worn, ', ') or 'nothing',
        dw_have,
        trait + dw_have,
        trait + (DW_needed or 0),
        (dw_sailfi_active and '  [Sailfi haste compensation]' or '')
            .. (dw_shortfall and '  ** DW SHORTFALL **' or '')))
    if #stripped > 0 then
        add_to_chat(158, '[DW] freed for base/Acc/DT pieces: ' .. table.concat(stripped, ', '))
    end
end

-- @ai:fn determine_haste_group | layer=framework | hot=yes | purity=write | contract=Mote melee resolver entry: refresh native haste/DW, combat form, and overlay.
function determine_haste_group()
    -- Native haste/DW math is authoritative. Refresh it before resolving the
    -- adaptive overlay so buff, equipment, subjob, and manual-haste changes are
    -- reflected without requiring GearInfo.
    classes.CustomMeleeGroups:clear()
    update_native_haste_dw()
    update_combat_form()
    update_dw_overlay()
end

-- @ai:fn gearinfo | layer=haste-dw | hot=yes | purity=write | contract=Parse optional GearInfo comparison heartbeat; never update authoritative Haste/DW/movement.
function gearinfo(cmdParams, eventArgs)
    if not cmdParams or cmdParams[1] ~= 'gearinfo' then return end

    -- Parse and validate before refreshing the heartbeat. A mistyped/manual
    -- 'gs c gearinfo' command must not make the HUD report a live GearInfo link.
    -- GearInfo sends either a numeric gear-DW need or the literal string
    -- 'false', plus numeric haste and a legacy movement token. The movement
    -- token is deliberately validated but ignored; native position owns it.
    local new_dw_needed = tonumber(cmdParams[2])
    local dw_inactive = cmdParams[2] == 'false'
    local new_haste = tonumber(cmdParams[3])
    if (not new_dw_needed and not dw_inactive) or not new_haste
            or (cmdParams[4] ~= 'true' and cmdParams[4] ~= 'false') then
        return
    end

    local now = os.clock()
    local first_packet = gearinfo_last == nil
    local link_recovered = first_packet or (now - gearinfo_last) > GEARINFO_STALE_SECONDS
    gearinfo_last = now

    local dw_changed, haste_changed = false, false
    if new_dw_needed then
        if GI_DW ~= true or GI_DW_needed ~= new_dw_needed then
            GI_DW = true
            GI_DW_needed = new_dw_needed
            dw_changed = true
        end
    elseif dw_inactive and (GI_DW ~= false or GI_DW_needed ~= 0) then
        GI_DW = false
        GI_DW_needed = 0
        dw_changed = true
    end

    if new_haste and GI_Haste ~= new_haste then
        GI_Haste = new_haste
        haste_changed = true
    end
    -- GearInfo is comparison-only. Native haste/DW and native position
    -- detection remain authoritative even while the addon is loaded.
    if link_recovered or dw_changed or haste_changed then
        update_hud()
    end
end

local gain_spell_by_weapon = {}
for weapon_name, weapon_policy in pairs(RDM_WEAPON_POLICY) do
    gain_spell_by_weapon[weapon_name] = weapon_policy.gain_spell
end

-- @ai:fn job_self_command | layer=command | hot=no | purity=write | contract=Single command router; custom commands must set eventArgs.handled.
function job_self_command(cmdParams, eventArgs)
    local command = (cmdParams[1] or ''):lower()
    if command == '_movementrefresh' then
        -- Native coordinates are sampled from a raw prerender callback for low
        -- overhead, but equip() requests made inside that raw callback are not
        -- reliably flushed by GearSwap. Cross back through this managed `gs c`
        -- path before rebuilding the active idle/melee set.
        movement_monitor.refresh_queued = false
        eventArgs.handled = true
        if RDM_RUNTIME.unloading or cmdParams[2] ~= RDM_RUNTIME.token then return end
        if not movement_monitor.refresh_pending then
            update_hud()
            return
        end

        check_moving()
        if pause_swaps_active()
            or (buffactive and buffactive.doom)
            or (type(midaction) == 'function' and midaction()) then
            -- Keep refresh_pending armed. Fishing deliberately permits this
            -- ring-only refresh; a cast, Doom lock, or full Pause waits.
            return
        end

        -- Repair a stale ring-slot disable before resolution, while preserving
        -- manually equipped Warp/Dimensional/EXP/CP utility rings.
        local equipment = player and player.equipment
        if equipment and no_swap_gear and releasing then
            if not no_swap_gear:contains(equipment.left_ring) and not releasing.ring1 then
                enable('ring1')
                if ring_lock_state then ring_lock_state.ring1 = false end
            end
            if not no_swap_gear:contains(equipment.right_ring) and not releasing.ring2 then
                enable('ring2')
                if ring_lock_state then ring_lock_state.ring2 = false end
            end
        end

        movement_monitor.refresh_pending = false
        if type(handle_equipping_gear) == 'function' and player then
            handle_equipping_gear(player.status)
        end
        update_hud()
    elseif command == 'version' then
        add_to_chat(158, string.format('[RDM] Falurian GearSwap v%s (%s)', RDM_RELEASE_VERSION, RDM_RELEASE_DATE))
        eventArgs.handled = true
    elseif command == 'baseline' or command == 'statbaseline' then
        report_rdm_baseline()
        eventArgs.handled = true
    elseif command == 'intelligence' or command == 'brain' then
        report_intelligence_summary()
        eventArgs.handled = true
    elseif command == 'policy' then
        report_policy(table.concat(cmdParams, ' ', 2))
        eventArgs.handled = true
    elseif command == 'spellintel' or command == 'spellintent' then
        report_spell_intelligence(table.concat(cmdParams, ' ', 2))
        eventArgs.handled = true
    elseif command == 'spellwhy' or command == 'whyspell' then
        report_spell_decision(table.concat(cmdParams, ' ', 2))
        eventArgs.handled = true
    elseif command == 'masterlevel' or command == 'ml' then
        local ml = tonumber(cmdParams[2])
        if ml then
            RDM_PROGRESSION.master_level = math.max(0, math.min(50, math.floor(ml)))
            refresh_rdm_baseline()
            fc_set_cache = {}
            fc_gear_target = nil
            native_state_active = nil
            native_state_haste = nil
            native_state_gear_haste = nil
            native_state_trait = nil
            native_state_gear_need = nil
            native_dw_plan_mask = nil
            update_fc_tier(true)
            update_native_haste_dw(true)
            update_dw_overlay()
            if not midaction() then job_update() end
            update_hud()
            add_to_chat(158, string.format('[Baseline] Master Level set to %d for this session (configured default is 23).', RDM_BASELINE.master_level))
        else
            add_to_chat(158, string.format('[Baseline] Master Level %d | usage: gs c ml <0-50>', RDM_BASELINE.master_level))
        end
        eventArgs.handled = true
    elseif command == 'magicmodes' or command == 'spellmodes' then
        add_to_chat(158, '[Magic] Casting='..state.CastingMode.value
            ..' | Enhancing=Auto (fixed)'
            ..' | Enfeebling='..state.EnfeeblingMode.value
            ..' | EnspellMelee='..state.EnspellMode.value)
        add_to_chat(158, '[Magic] Elemental uses one canonical set; matching magic-burst gear is automatic.')
        add_to_chat(158, '[Sleep] Accuracy-first set is fixed; SleepMaxDuration is disconnected.')
        add_to_chat(158, '[Sleep timer] Saboteur uses fixed conservative NM math (1.25x); no target mode.')
        add_to_chat(158, 'Usage: gs c cycle CastingMode | cycle EnfeeblingMode | cycle EnspellMode')
        eventArgs.handled = true
    elseif command == 'scholar' then
        handle_strategems(cmdParams)
        eventArgs.handled = true
    elseif command == 'enspell' then
        send_command('@input /ma '..state.EnSpell.value..' <me>')
        eventArgs.handled = true
    elseif command == 'barelement' then
        send_command('@input /ma '..state.BarElement.value..' <me>')
        eventArgs.handled = true
    elseif command == 'barstatus' then
        send_command('@input /ma '..state.BarStatus.value..' <me>')
        eventArgs.handled = true
    elseif command == 'gainspell' then
        local spell_to_cast = state.GainSpell.value

        -- 'Auto' picks the Gain spell to match the equipped weapon's WS modifier;
        -- any explicit choice in the cycle is always respected.
        if spell_to_cast == 'Auto' then
            spell_to_cast = gain_spell_by_weapon[player.equipment.main] or 'Gain-MND' --MND aids enfeebles
        end

        send_command('@input /ma "'..spell_to_cast..'" <me>')
        eventArgs.handled = true
    elseif command == 'rdmdefense' or command == 'defensecycle' then
        local request = normalize_control_token(cmdParams[2])
        if request == '' or request == 'next' or request == 'forward' then
            cycle_defense_control('Ctrl+F3')
        else
            apply_defense_control(cmdParams[2], 'Defense')
        end
        eventArgs.handled = true
    elseif command == 'rdmweapon' or command == 'weaponpair' then
        local request = normalize_control_token(cmdParams[2])
        if request == 'next' or request == 'forward' or request == '' then
            cycle_weapon_pair('next', 'Weapon')
        elseif request == 'previous' or request == 'prev' or request == 'back' then
            cycle_weapon_pair('previous', 'Weapon')
        else
            apply_weapon_pair(cmdParams[2], 'Weapon')
        end
        eventArgs.handled = true
    elseif command == 'rdmplay' or command == 'rdmplaystyle' or command == 'playstyle' then
        local request = normalize_control_token(cmdParams[2])
        if request == 'next' or request == 'forward' or request == '' then
            cycle_playstyle('next', 'Playstyle')
        elseif request == 'previous' or request == 'prev' or request == 'back' then
            cycle_playstyle('previous', 'Playstyle')
        else
            apply_playstyle(cmdParams[2], 'Playstyle')
        end
        eventArgs.handled = true
    elseif command == 'magicburst' or command == 'mburst' or command == 'burstspell' then
        execute_manual_magic_burst()
        eventArgs.handled = true
    elseif command == 'skillchain' or command == 'scclose' or command == 'chainws' then
        execute_manual_skillchain()
        eventArgs.handled = true
    elseif command == 'bestws' or command == 'weaponws' or command == 'contextws' then
        execute_context_weaponskill()
        eventArgs.handled = true
    elseif command == 'rangedlock' or command == 'ammosafety' or command == 'ammolock' then
        set_ranged_lock(cmdParams[2])
        eventArgs.handled = true
    elseif command == 'rdmreset' or command == 'resetprofile' then
        reset_rdm_controls()
        eventArgs.handled = true
    elseif command == 'rdmprofile' or command == 'situation' then
        add_to_chat(158, '[Controls] rdmprofile was retired in v2.39: use rdmweapon, rdmplay, bestws, or rdmreset.')
        eventArgs.handled = true
    elseif command == 'hud' then
        toggle_hud()
        eventArgs.handled = true
    elseif command == 'hudlock' then
        toggle_hud_lock()
        eventArgs.handled = true
    elseif command == 'hudinfo' then
        hud_config_report()
        eventArgs.handled = true
    elseif command == 'hudlayout' then
        set_hud_layout(cmdParams[2])
        eventArgs.handled = true
    elseif command == 'hudscale' then
        set_hud_scale(cmdParams[2])
        eventArgs.handled = true
    elseif command == 'hudopacity' then
        set_hud_opacity(cmdParams[2])
        eventArgs.handled = true
    elseif command == 'hudsection' then
        set_hud_section(cmdParams[2], cmdParams[3])
        eventArgs.handled = true
    elseif command == 'keys' then
        print_keybinds()
        eventArgs.handled = true
    elseif command == 'dwinfo' then
        update_dw_overlay()
        report_dw_tier()
        eventArgs.handled = true
    elseif command == 'hastecheck' then
        report_haste_check()
        eventArgs.handled = true
    elseif command == 'moveinfo' or command == 'movementinfo' then
        local equipment = player and player.equipment or {}
        local legs = dw_item_name(equipment.legs)
        local ring1 = equipment.left_ring or equipment.ring1
        local ring2 = equipment.right_ring or equipment.ring2
        local source = 'none'
        if legs and type(item_stat) == 'function' and item_stat(legs, 'movement') > 0 then
            source = 'legs/'..legs
        elseif ring1 == 'Shneddick Ring' then
            source = 'ring1/Shneddick'
        elseif ring2 == 'Shneddick Ring' then
            source = 'ring2/Shneddick'
        elseif moving then
            source = 'pending-or-blocked'
        end
        add_to_chat(158, string.format(
            '[Move] native=%s | Auto_Kite=%s | pending=%s | queued=%s',
            moving and 'MOVING' or 'still',
            state.Auto_Kite.value and 'ON' or 'off',
            tostring(movement_monitor.refresh_pending),
            tostring(movement_monitor.refresh_queued)))
        add_to_chat(158, string.format(
            '[Move] source=%s | ring1=%s | ring2=%s | sample=%.2fs | stop debounce=%.2fs',
            source, tostring(ring1), tostring(ring2),
            movement_monitor.sample_interval, movement_monitor.stop_debounce))
        eventArgs.handled = true
    elseif command == 'hastetier' then
        -- Haste and Haste II share one buff icon, so buffactive alone cannot
        -- distinguish their potency. RDM defaults to Haste II; override here
        -- when another source gives Haste I. Values are game-engine 1024ths.
        local tier = tostring(cmdParams[2] or ''):lower()
        if tier == '1' or tier == 'haste' then
            haste_assume.magic['Haste'] = 150
            invalidate_haste_buff_cache()
            update_native_haste_dw(true)
            if not midaction() then job_update() end
            update_hud()
            add_to_chat(158, '[Haste] shared Haste icon assumption: Haste I (14.6%)')
        elseif tier == '2' or tier == 'haste2' or tier == 'hasteii' then
            haste_assume.magic['Haste'] = 307
            invalidate_haste_buff_cache()
            update_native_haste_dw(true)
            if not midaction() then job_update() end
            update_hud()
            add_to_chat(158, '[Haste] shared Haste icon assumption: Haste II (30.0%)')
        else
            add_to_chat(158, string.format('[Haste] icon assumption %.1f%% -- usage: gs c hastetier 1|2', (haste_assume.magic['Haste'] or 0) / 10.24))
        end
        eventArgs.handled = true
    elseif command == 'hasteadj' then
        -- Manual magic-haste correction in PERCENT for buffs the estimator
        -- can't see (Geo-Haste bubbles chiefly). 'gs c hasteadj 33' under an
        -- Idris geo; 'gs c hasteadj 0' to clear. Stored in 1024ths.
        local pct = tonumber(cmdParams[2])
        if pct then
            haste_manual_magic = math.floor(pct * 10.24 + 0.5)
            update_native_haste_dw(true)
            update_dw_overlay()
            if not midaction() then job_update() end
            update_hud()
            add_to_chat(158, string.format('[Haste] manual magic adjustment set to %+.1f%% (%+d/1024)', pct, haste_manual_magic))
        else
            add_to_chat(158, string.format('[Haste] manual magic adjustment is %+d/1024 -- usage: gs c hasteadj <pct>', haste_manual_magic))
        end
        update_hud()
        eventArgs.handled = true
    elseif command == 'fcinfo' then
        -- Recompute from the progression baseline and print the FC math.
        update_fc_tier(true)
        eventArgs.handled = true
    elseif command == 'perf' or command == 'profile' then
        local sub = (cmdParams[2] or ''):lower()
        if sub == 'on' then
            perf_reset()
            perf.enabled = true
            add_to_chat(158, '[Perf] instrumentation ON; sample reset.')
        elseif sub == 'off' then
            perf_report()
            perf.enabled = false
            add_to_chat(158, '[Perf] instrumentation OFF.')
        elseif sub == 'reset' then
            perf_reset()
            add_to_chat(158, '[Perf] sample reset; instrumentation '..(perf.enabled and 'remains ON.' or 'is OFF.'))
        else
            perf_report()
        end
        eventArgs.handled = true
    elseif command == 'auditgear' then
        add_to_chat(167, '[Safety] auditgear is disabled in v2.32. Runtime inventory/set auditing was removed after live-client crashes.')
        eventArgs.handled = true
    elseif command == 'sctest' then
        sc_selftest()
        eventArgs.handled = true
    elseif command == 'scdebug' then
        manual_sc.debug = not manual_sc.debug
        add_to_chat(158, '[F11 SC] packet debug logging '..(manual_sc.debug and 'ON' or 'OFF'))
        eventArgs.handled = true
    end

    gearinfo(cmdParams, eventArgs)
end

-- General handling of strategems in an Arts-agnostic way.
-- Format: gs c scholar <strategem>

-- @ai:fn handle_strategems | layer=command | hot=no | purity=write | contract=Translate arts-agnostic scholar command to one JA command.
function handle_strategems(cmdParams)
    -- cmdParams[1] == 'scholar'
    -- cmdParams[2] == strategem to use

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
    elseif buffactive['dark arts']  or buffactive['addendum: black'] then
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

-- Set true to echo the sleep-duration math to chat for tuning.
sleep_timer_debug = false

local sleep_kishar_maps = {
    SleepMaxDuration=true,
    MndEnfeebles=true, IntEnfeebles=true,
    MndEnfeeblesEffect=true, IntEnfeeblesEffect=true,
    MndEnfeeblesDuration=true, IntEnfeeblesDuration=true,
}

-- @ai:fn sleep_duration_gear_profile | layer=qol | hot=no | purity=read | contract=Derive duration multiplier from the fixed accuracy Sleep set after TH and SIRD slot overrides; retain dormant duration-map support for diagnostics.
local function sleep_duration_gear_profile(spell, spell_map)
    local map = spell_map
        or (type(job_get_spell_map) == 'function' and job_get_spell_map(spell, nil))
        or 'Sleep'
    local sird = state.CastingMode and state.CastingMode.value == 'SIRD'
    local th = state.TreasureHunter and state.TreasureHunter.value
        and spell.target and spell.target.type == 'MONSTER'

    -- Viti. Chapeau +3 remains in every current sleep route: +20%.
    local gear_mult = 1.20
    if sleep_kishar_maps[map] and not th and not sird then gear_mult = gear_mult + 0.10 end
    -- Snotra remains in Accuracy/Potency/Duration routes, but SIRD replaces ear2.
    if not sird then gear_mult = gear_mult + 0.10 end

    local lethargy_pieces = 0
    if map == 'SleepMaxDuration'
        or map == 'MndEnfeeblesDuration' or map == 'IntEnfeeblesDuration' then
        lethargy_pieces = 4
    elseif map == 'MndEnfeeblesEffect' or map == 'IntEnfeeblesEffect'
        or map == 'SkillEnfeeblesPotency' then
        lethargy_pieces = 1
    end
    -- The final SIRD overlay replaces Lethargy legs with Bunzi's Pants.
    if sird and lethargy_pieces >= 4 then lethargy_pieces = lethargy_pieces - 1 end
    return gear_mult, lethargy_pieces, map, th, sird
end

-- @ai:fn set_sleep_timer | layer=qol | hot=no | purity=write | contract=Calculate/report an overlay-aware sleep timer with nil-safe runtime merit/target reads.
function set_sleep_timer(spell, spellMap)
    local self = windower and windower.ffxi and windower.ffxi.get_player
        and windower.ffxi.get_player() or nil
    local merits = (self and self.merits) or {}
    local duration_merits = tonumber(merits.enfeebling_magic_duration) or 0

    local base
    if spell.en == "Sleep II" then
        base = 90
    elseif spell.en == "Sleep" or spell.en == "Sleepga" then
        base = 60
    end
    -- Unhandled sleep-type spell: skip the timer rather than erroring on a nil base.
    if not base then return end

    if state.Buff.Saboteur then
        -- The former Win+D normal/NM selector was retired in v2.54. Use the
        -- conservative NM multiplier permanently so the display never promises
        -- more Saboteur Sleep time than a notorious monster actually receives.
        base = base * 1.25
    end

    -- Merit Points Duration Bonus
    base = base + duration_merits*6

    -- Relic Head Duration Bonus: Viti. Chapeau +3 is worn in BOTH Sleep and
    -- SleepMaxDuration sets now, so this always applies.
    base = base + duration_merits*3

    -- Job Master baseline: all RDM JP categories are rank 20. Keep this on the
    -- shared progression baseline rather than reading a second copy of JP state.
    base = base + RDM_BASELINE.conditional.enfeebling_duration_seconds

    -- Resolve what actually survived final-priority overlays. The fixed Sleep
    -- route does not wear Kishar; TH replaces ring1 and SIRD replaces duration
    -- accessories. The timer must never promise duration from displaced gear.
    local gear_mult, lethargy_pieces, routed_map, th_overlay, sird_overlay =
        sleep_duration_gear_profile(spell, spellMap)

    -- Estoquer/Lethargy Composure set bonus:
    -- 2pc = 1.1 / 3pc = 1.2 / 4pc = 1.35 / 5pc = 1.5.
    local empy_mult = 1
    local using_max_duration = routed_map == 'SleepMaxDuration'
        or routed_map == 'MndEnfeeblesDuration'
        or routed_map == 'IntEnfeeblesDuration'
    if using_max_duration then
        if buffactive.Stymie then
            base = base + RDM_BASELINE.conditional.stymie_duration_seconds
        end
        if buffactive.Composure then
            if lethargy_pieces >= 5 then empy_mult = 1.50
            elseif lethargy_pieces == 4 then empy_mult = 1.35
            elseif lethargy_pieces == 3 then empy_mult = 1.20
            elseif lethargy_pieces == 2 then empy_mult = 1.10
            end
        end
    end

    local totalDuration = math.floor(base * gear_mult * empy_mult)

    -- Create the custom timer. Target data can briefly be incomplete on
    -- packet edge cases; a fallback label is safer than aborting aftercast.
    local target_name = spell.target and spell.target.name or 'target'
    if spell.english == "Sleep II" then
        send_command('@timers c "Sleep II ['..target_name..']" ' ..totalDuration.. ' down spells/00259.png')
    elseif spell.english == "Sleep" or spell.english == "Sleepga" then
        send_command('@timers c "Sleep ['..target_name..']" ' ..totalDuration.. ' down spells/00253.png')
    end
    if sleep_timer_debug then
        add_to_chat(1, 'Sleep timer -- map: '..routed_map
            ..' TH: '..tostring(th_overlay)..' SIRD: '..tostring(sird_overlay)
            ..' Leth: '..lethargy_pieces..' base: '..base
            ..' gear: x'..gear_mult..' set bonus: x'..empy_mult
            ..' total: '..totalDuration)
    end
end

-- Mote-Include dispatches subjob changes here. Re-resolve the selected weapon pair
-- after the player snapshot settles so /NIN or /DNC loss immediately receives
-- Ammurapi Shield even while WeaponLock is on (and regaining DW restores the
-- selected offhand instead of leaving the shield behind).
-- @ai:fn job_sub_job_change | layer=framework | hot=no | purity=write | contract=Re-resolve selected weapon pair and force gear refresh after support-job change.
function job_sub_job_change(newSubjob, oldSubjob)
    weapon_cycle_generation = weapon_cycle_generation + 1
    local generation = weapon_cycle_generation
    local function restore_pair(attempt)
        if RDM_RUNTIME.unloading or generation ~= weapon_cycle_generation then return end
        if swaps_frozen() then return end
        if type(midaction) == 'function' and midaction() then
            if attempt < 4 then
                coroutine.schedule(function() restore_pair(attempt + 1) end, 0.5)
            end
            return
        end
        local selected = control_state_value('WeaponSet') or RDM_DEFAULT_WEAPON_SET
        apply_weapon_pair(selected, 'Subjob', true, true)
        if player then handle_equipping_gear(player.status) end
    end
    coroutine.schedule(function() restore_pair(1) end, 0.5)
end

-- @ai:fn check_moving | layer=gear | hot=yes | purity=write | contract=Mirror authoritative native movement into Auto_Kite whenever emergency Defense does not own gear.
function check_moving()
    if not (state and state.Auto_Kite and state.DefenseMode) then return end
    local auto_wanted = moving == true
        and state.DefenseMode.value == 'None'
    if state.Auto_Kite.value ~= auto_wanted then
        state.Auto_Kite:set(auto_wanted)
    end
end

-- Raw Windower callbacks are intentionally used only for sampling. GearSwap's
-- managed self-command path owns the actual equip refresh so queued equipment
-- is transmitted after job_self_command returns.
-- @ai:fn queue_movement_gear_refresh | layer=gear | hot=yes | purity=write | contract=Coalesce native movement transitions into one token-guarded managed GearSwap refresh.
local function queue_movement_gear_refresh()
    if RDM_RUNTIME.unloading or movement_monitor.refresh_queued then return end
    movement_monitor.refresh_queued = true
    send_command('gs c _movementrefresh '..RDM_RUNTIME.token)
end

-- @ai:fn native_movement_sample | layer=gear | hot=yes | purity=write | contract=Sample player coordinates at a fixed low rate; debounce stopping and request gear only on native movement transitions.
local function native_movement_sample()
    if RDM_RUNTIME.unloading then return end

    local now = os.clock()
    if now < movement_monitor.next_sample then return end
    movement_monitor.next_sample = now + movement_monitor.sample_interval

    if not (player and player.index and windower and windower.ffxi
        and type(windower.ffxi.get_mob_by_index) == 'function') then
        return
    end

    local mob = windower.ffxi.get_mob_by_index(player.index)
    if not (mob and mob.x and mob.y and mob.z) then
        movement_monitor.x, movement_monitor.y, movement_monitor.z = nil, nil, nil
        return
    end

    local old_x, old_y, old_z = movement_monitor.x, movement_monitor.y, movement_monitor.z
    movement_monitor.x, movement_monitor.y, movement_monitor.z = mob.x, mob.y, mob.z

    -- First valid sample establishes a baseline and never guesses movement.
    if old_x == nil or old_y == nil or old_z == nil then
        movement_monitor.last_motion_at = now
        return
    end

    local dx, dy, dz = mob.x - old_x, mob.y - old_y, mob.z - old_z
    local displaced = (dx * dx + dy * dy + dz * dz) > movement_monitor.distance_squared
    local new_moving = moving

    if displaced then
        movement_monitor.last_motion_at = now
        new_moving = true
    elseif moving and (now - movement_monitor.last_motion_at) >= movement_monitor.stop_debounce then
        new_moving = false
    end

    if new_moving ~= moving then
        moving = new_moving
        movement_monitor.refresh_pending = true
    end

    -- A transition detected during a spell/full-Pause/Doom waits here until
    -- that owner clears. Fishing is intentionally allowed: its non-ring slots
    -- stay disabled while the managed refresh updates only the live rings.
    -- Never equip directly from this raw callback.
    if movement_monitor.refresh_pending and state and state.Auto_Kite
        and not pause_swaps_active()
        and not (buffactive and buffactive.doom)
        and (type(midaction) ~= 'function' or not midaction()) then
        check_moving()
        queue_movement_gear_refresh()
    end
end

-- Prerender is used only as a reliable clock source; native_movement_sample()
-- exits before any entity lookup on nearly every frame.
track_rdm_event(windower.raw_register_event('prerender', native_movement_sample))

-- Lock a ring slot (disable) whenever it holds a no_swap ring, unless we're in the
-- middle of releasing it. Enable it otherwise so normal gear flows back in.
-- Fishing leaves rings under this policy; only full Pause or Doom suspends it.
-- @ai:fn invalidate_ring_lock_cache | layer=gear | hot=no | purity=write | contract=Force next protected-ring check to reapply enable/disable state.
function invalidate_ring_lock_cache()
    if ring_lock_state then
        ring_lock_state.ring1 = nil
        ring_lock_state.ring2 = nil
    end
end

-- @ai:fn apply_ring_lock | layer=gear | hot=yes | purity=write | contract=Deduplicate enable/disable calls for one protected ring slot.
local function apply_ring_lock(slot, should_lock)
    if not ring_lock_state then ring_lock_state = {ring1=nil, ring2=nil} end
    if ring_lock_state[slot] == should_lock then
        perf_count('ring_lock_hits')
        return
    end
    if should_lock then disable(slot) else enable(slot) end
    ring_lock_state[slot] = should_lock
    perf_count('ring_lock_changes')
end

-- @ai:fn check_gear | layer=gear | hot=yes | purity=write | contract=Enforce protected rings normally and during Fishing; only Pause or Doom owns both ring slots outright.
function check_gear()
    if state.PauseSwaps.value or buffactive.doom then return end
    local equipment = player and player.equipment
    if not equipment then return end
    apply_ring_lock('ring1', no_swap_gear:contains(equipment.left_ring) and not releasing.ring1)
    apply_ring_lock('ring2', no_swap_gear:contains(equipment.right_ring) and not releasing.ring2)
end

-- Release the given ring slots: enable them, recompute gear so the normal ring
-- returns, then clear the release flag once the swap has settled.
-- @ai:fn release_ring_slots | layer=gear | hot=no | purity=write | contract=Temporarily release protected rings, re-equip, then re-arm lock checks asynchronously.
function release_ring_slots(slots, reason)
    local any = false
    for _, s in ipairs(slots) do
        releasing[s] = true
        enable(s)
        if ring_lock_state then ring_lock_state[s] = false end
        any = true
    end
    if not any then return end
    if reason then add_to_chat(158, '** [no-swap ring released: '..reason..'] **') end
    handle_equipping_gear(player.status)
    coroutine.schedule(function()
        if RDM_RUNTIME.unloading then return end
        for _, s in ipairs(slots) do releasing[s] = false end
        check_gear()
    end, 1)
end

-------------------------------------------------------------------------------------------------------------------
-- Auto Magic Burst detection
-- Watches action packets for skillchains closing (by you, Silmaril, Trusts, or party)
-- and opens an internal burst window. Matching-target, matching-element spells
-- automatically get sets.magic_burst. This service is always on and has no
-- gear toggle. The same formed-chain record feeds the manual F10 spell chooser
-- and its temporary actionable HUD row; it never casts by itself.
-------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------
-- QoL monitors: Convert alert, low-HP defensive lean, Saboteur nudge
-- All notifications are local-only /echo lines.
-------------------------------------------------------------------------------------------------------------------

-- Self-tracked JA timestamps (no recast-ID dependency). 0 = assume ready at load.
ja_tracker = {
    ['Convert']   = {used_at = 0, recast = 600},
    ['Saboteur']  = {used_at = 0, recast = 60},
}

-- @ai:fn ja_ready | layer=qol | hot=no | purity=read | contract=Local timestamp readiness estimate; optimistic immediately after reload by design.
function ja_ready(name)
    local ja = ja_tracker[name]
    return ja and (os.time() - ja.used_at) >= ja.recast
end

monitor_state = {convert_alerted = false, hp_lean = false, last_tick = 0}

-- Fires roughly every 2.4 real seconds (each game minute); throttled to ~5s.
track_rdm_event(windower.raw_register_event('time change', function()
    local now = os.clock()
    if now - monitor_state.last_tick < 5 then return end
    monitor_state.last_tick = now

    if not player or not player.max_mp or player.max_mp == 0 then return end

    -- Convert alert: low MP and Convert (self-tracked) ready
    if player.mpp <= 20 and ja_ready('Convert') then
        if not monitor_state.convert_alerted then
            send_command('input /echo ** CONVERT READY - MP at '..tostring(player.mpp)..'% **')
            monitor_state.convert_alerted = true
        end
    elseif player.mpp > 35 then
        monitor_state.convert_alerted = false -- re-arm after recovery
    end

    -- Low-HP defensive lean with hysteresis (on at <=50%, off at >=60%)
    if not monitor_state.hp_lean and player.hpp <= 50 then
        monitor_state.hp_lean = true
        send_command('input /echo ** HP LOW - leaning into DT gear **')
        handle_equipping_gear(player.status)
        update_hud()
    elseif monitor_state.hp_lean and player.hpp >= 60 then
        monitor_state.hp_lean = false
        send_command('input /echo ** HP recovered - resuming normal gear **')
        handle_equipping_gear(player.status)
        update_hud()
    end
end))

-- Enspell buff detection (drives EnspellMode 'Auto')
enspell_buff_names = S{'Enfire','Enblizzard','Enaero','Enstone','Enthunder','Enwater',
                       'Enfire II','Enblizzard II','Enaero II','Enstone II','Enthunder II','Enwater II'}

-- @ai:fn enspell_active | layer=gear | hot=yes | purity=read | contract=Return whether any tracked enspell buff is active.
function enspell_active()
    for name in enspell_buff_names:it() do
        if buffactive[name] then return true end
    end
    return false
end

-- @ai:fn resolved_enspell_melee_set | layer=gear | hot=yes | purity=read | contract=Resolve Off/Auto/Max to no overlay, balanced Crocea-only gear, or explicit max-Enspell gear without allocating.
function resolved_enspell_melee_set()
    if not (state and state.EnspellMode and sets and sets.engaged) then return nil end
    local mode = state.EnspellMode.value
    if mode == 'Max' then
        return sets.engaged.EnspellMax or sets.engaged.Enspell
    end
    if mode ~= 'Auto' or not enspell_active() then return nil end

    -- Actual equipment is authoritative while WeaponLock can intentionally
    -- leave the selected WeaponSet out of sync. While unlocked, the selected
    -- set wins immediately so a weapon-cycle refresh cannot retain one stale
    -- Crocea overlay before the equipment packet lands.
    local equipment = player and player.equipment
    local main = equipment and (equipment.main or equipment.right_main)
    local selected = state.WeaponSet
        and (state.WeaponSet.current or state.WeaponSet.value)
    local weapon_locked = state.WeaponLock and state.WeaponLock.value
    local crocea_equipped
    local selected_meta = selected and RDM_WEAPON_PAIR_META[selected] or nil
    if not weapon_locked and selected then
        crocea_equipped = selected_meta and selected_meta.crocea_main or false
    else
        crocea_equipped = main == 'Crocea Mors'
        if main == nil or main == '' then
            crocea_equipped = selected_meta and selected_meta.crocea_main or false
        end
    end
    if crocea_equipped then return sets.engaged.Enspell end
    return nil
end

sc_window = {
    name=nil, target_id=nil, observed_at=0, expires=0, generation=0,
}

-- @ai:fn sc_clear_burst_window | layer=automb | hot=no | purity=write | contract=Atomically clear the shared AutoMB/F10 window and invalidate pending presentation work.
local function sc_clear_burst_window()
    local was_active = sc_window.name ~= nil
    sc_window.name = nil
    sc_window.target_id = nil
    sc_window.observed_at = 0
    sc_window.expires = 0
    sc_window.generation = (sc_window.generation or 0) + 1
    if manual_mb then
        manual_mb.pending = nil
        manual_mb.pending_generation = (manual_mb.pending_generation or 0) + 1
    end
    if was_active and not RDM_RUNTIME.unloading
        and type(update_hud) == 'function' then
        update_hud()
    end
end

-- A burst window is only useful while its target still exists in the local
-- entity table. Guard the lookup for compatibility with test/mocked runtimes.
-- @ai:fn sc_burst_target_exists | layer=automb | hot=yes | purity=read | contract=Validate target entity exists and is not hpp=0; tolerate mocked runtimes.
local function sc_burst_target_exists(target_id)
    if not target_id then return false end
    local get_mob_by_id = windower and windower.ffxi and windower.ffxi.get_mob_by_id
    if type(get_mob_by_id) ~= 'function' then return true end
    local mob = get_mob_by_id(target_id)
    if not mob then return false end
    -- Entity rows can survive briefly after death; hpp=0 is not burstable.
    if mob.hpp ~= nil and tonumber(mob.hpp) and tonumber(mob.hpp) <= 0 then return false end
    return true
end

-- Windower resources is forward-declared here because get_ws_properties()
-- is defined before the loader block below. Without this declaration, `res`
-- inside that function would resolve to a global instead of the intended local.
local res = nil

-- Skillchain -> elements that can magic burst on it
local sc_property_keys = {'skillchain_a', 'skillchain_b', 'skillchain_c'}

-- Resource records are immutable for the life of the Lua. Cache each WS's
-- non-empty skillchain properties the first time it is inspected so F11,
-- diagnostics, and opener tracking do not rebuild the same small arrays.
local sc_ws_properties = {}
-- @ai:fn get_ws_properties | layer=skillchain | hot=yes | purity=write | contract=Memoize immutable WS skillchain properties by resource ID.
local function get_ws_properties(ws_id, ws)
    local cached = sc_ws_properties[ws_id]
    if cached then return cached end
    cached = {}
    ws = ws or (res and res.weapon_skills[ws_id])
    if ws then
        for _, key in ipairs(sc_property_keys) do
            local prop = ws[key]
            if prop and prop ~= '' then cached[#cached + 1] = prop end
        end
    end
    sc_ws_properties[ws_id] = cached
    return cached
end

local sc_burst_elements = {
    Liquefaction    = S{'Fire'},
    Scission        = S{'Earth'},
    Reverberation   = S{'Water'},
    Detonation      = S{'Wind'},
    Induration      = S{'Ice'},
    Impaction       = S{'Lightning'},
    Transfixion     = S{'Light'},
    Compression     = S{'Dark'},
    Fusion          = S{'Fire', 'Light'},
    Fragmentation   = S{'Wind', 'Lightning'},
    Gravitation     = S{'Earth', 'Dark'},
    Distortion      = S{'Ice', 'Water'},
    Light           = S{'Fire', 'Wind', 'Lightning', 'Light'},
    Darkness        = S{'Ice', 'Earth', 'Water', 'Dark'},
    Radiance        = S{'Fire', 'Wind', 'Lightning', 'Light'},
    Umbra           = S{'Ice', 'Earth', 'Water', 'Dark'},
}

-------------------------------------------------------------------------------------------------------------------
-- Manual Magic Burst -- plain F10
--
--   Only a FORMED skillchain opens this button. Raw WS properties remain valid
--   F11-closing information, but they can never make F10 claim a burst exists.
--   Each press evaluates standard single-target RDM elemental nukes from tier V
--   down to tier I. Eligibility requires all of the following at press time:
--     * the spell's element bursts on the formed chain,
--     * the character has learned it and the current main/sub job can use it,
--     * its recast is ready, and its base MP cost is affordable.
--   Resulting tier dominates selection. At the same tier, the ordinary base
--   nuke strength order is Thunder > Blizzard > Fire > Aero > Water > Stone.
--   No target resistance/day/weather weakness is guessed. Nothing is queued,
--   delayed, retried, or cast automatically, and the burst window is not
--   consumed so a later deliberate F10 press can choose another ready spell.
-------------------------------------------------------------------------------------------------------------------

manual_mb = {
    pending=nil,
    pending_generation=0,
    submit_timeout=1.5,
    hard_timeout=6.0,
}

local MANUAL_MB_ELEMENTS = {
    {element='Lightning', root='Thunder',  power=6},
    {element='Ice',       root='Blizzard', power=5},
    {element='Fire',      root='Fire',     power=4},
    {element='Wind',      root='Aero',     power=3},
    {element='Water',     root='Water',    power=2},
    {element='Earth',     root='Stone',    power=1},
}

local MANUAL_MB_TIERS = {
    {suffix=' V',   tier=5},
    {suffix=' IV',  tier=4},
    {suffix=' III', tier=3},
    {suffix=' II',  tier=2},
    {suffix='',     tier=1},
}

-- Resource rows are immutable for one GearSwap load. Cache the thirty possible
-- standard nuke names so HUD refreshes never rescan the resources collection.
local manual_mb_spell_cache = {}

-- @ai:fn manual_mb_spell_resource | layer=automb | hot=no | purity=write | contract=Resolve and memoize one English spell resource name without inventing spell data.
local function manual_mb_spell_resource(name)
    local cached = manual_mb_spell_cache[name]
    if cached ~= nil then return cached or nil end
    if not (res and res.spells) then return nil end
    local entry
    if type(res.spells.with) == 'function' then
        local ok, found = pcall(function()
            return res.spells:with('en', name)
        end)
        if ok and found and found.id then entry = found end
    end
    if not entry then
        for _, row in pairs(res.spells) do
            if type(row) == 'table' and row.en == name then
                entry = row
                break
            end
        end
    end
    manual_mb_spell_cache[name] = entry or false
    return entry
end

-- get_spells() establishes learned ownership, while resources.levels prevents a
-- spell learned on another job (for example BLM) from being selected on RDM.
-- If an older resource/runtime omits job IDs or level metadata, learned status
-- remains the conservative compatibility fallback used by the former smart-nuke
-- command rather than making the entire button unusable.
-- @ai:fn manual_mb_job_usable | layer=automb | hot=no | purity=read | contract=Accept a learned spell only when current main/sub job level metadata permits it; tolerate legacy metadata gaps.
local function manual_mb_job_usable(entry)
    if not entry or type(entry.levels) ~= 'table' or not player then return true end
    local main_id = tonumber(player.main_job_id)
    local sub_id = tonumber(player.sub_job_id)
    local checked = false
    if main_id then
        checked = true
        local required = tonumber(entry.levels[main_id])
        if required and required > 0
            and required <= (tonumber(player.main_job_level) or 0) then
            return true
        end
    end
    if sub_id then
        checked = true
        local required = tonumber(entry.levels[sub_id])
        if required and required > 0
            and required <= (tonumber(player.sub_job_level) or 0) then
            return true
        end
    end
    return not checked
end

-- Return the highest ranked spell that is castable NOW. When none is castable,
-- return the most actionable blocker so the HUD/F10 message can distinguish no
-- learned spell, insufficient MP, and recast. Optional learned/recasts arguments
-- keep this decision deterministic under the offline test harness.
-- @ai:fn manual_mb_resolve_spell | layer=automb | hot=no | purity=read | contract=Choose the highest-tier compatible learned/job-usable/ready/affordable standard elemental spell; never cast or mutate game state.
local function manual_mb_resolve_spell(chain_name, current_mp, learned, recasts)
    local elements = sc_burst_elements[chain_name]
    if not elements then return nil, 'NO_SPELL' end

    local get_spells = windower and windower.ffxi and windower.ffxi.get_spells
    local get_recasts = windower and windower.ffxi and windower.ffxi.get_spell_recasts
    learned = learned or (type(get_spells) == 'function' and get_spells()) or {}
    recasts = recasts or (type(get_recasts) == 'function' and get_recasts()) or {}
    current_mp = tonumber(current_mp) or 0

    local best_learned
    local best_ready
    local soonest_recast
    for _, tier_row in ipairs(MANUAL_MB_TIERS) do
        for _, element_row in ipairs(MANUAL_MB_ELEMENTS) do
            if elements:contains(element_row.element) then
                local name = element_row.root..tier_row.suffix
                local entry = manual_mb_spell_resource(name)
                if entry and learned[entry.id] and manual_mb_job_usable(entry) then
                    local recast_key = entry.recast_id or entry.id
                    local recast_value = tonumber(recasts[recast_key])
                    local candidate = {
                        id=entry.id,
                        name=name,
                        element=element_row.element,
                        tier=tier_row.tier,
                        rank=tier_row.tier * 100 + element_row.power,
                        cost=tonumber(entry.mp_cost) or 0,
                        recast=recast_value or math.huge,
                        recast_known=recast_value ~= nil,
                    }
                    if not best_learned then best_learned = candidate end
                    if candidate.recast <= 0 then
                        if not best_ready then best_ready = candidate end
                        if candidate.cost <= current_mp then
                            return candidate, 'READY'
                        end
                    else
                        if not soonest_recast
                            or candidate.recast < soonest_recast.recast
                            or (candidate.recast == soonest_recast.recast
                                and candidate.rank > soonest_recast.rank) then
                            soonest_recast = candidate
                        end
                    end
                end
            end
        end
    end

    if not best_learned then return nil, 'NO_SPELL' end
    if best_ready then return best_ready, 'NEED_MP' end
    return soonest_recast or best_learned, 'RECAST'
end

-- One read-only state snapshot feeds expanded HUD, compact HUD, and the F10
-- command. READY therefore has one definition everywhere: formed window alive,
-- matching living target, concrete spell, enough MP, recast ready, no Silence,
-- live swaps, and no other GearSwap action in progress.
-- @ai:fn mb_opportunity_snapshot | layer=automb | hot=yes | purity=read | contract=Describe the current F10 opportunity and exact spell/blocker without issuing or scheduling an action.
mb_opportunity_snapshot = function(now)
    now = tonumber(now) or os.clock()
    local snapshot = {
        active=false,
        status='NONE',
        generation=sc_window and sc_window.generation or 0,
        mp=tonumber(player and player.mp) or 0,
    }
    if not (sc_window and sc_window.name)
        or (tonumber(sc_window.expires) or 0) <= now then
        return snapshot
    end

    snapshot.active = true
    snapshot.chain_name = sc_window.name
    snapshot.target_id = sc_window.target_id
    snapshot.remaining = math.max(0, (tonumber(sc_window.expires) or now) - now)

    local pending = manual_mb and manual_mb.pending
    if pending then
        snapshot.status = 'PENDING'
        snapshot.choice_name = pending.name
        snapshot.choice_element = pending.element
        snapshot.choice_tier = pending.tier
        snapshot.choice_cost = pending.cost
        snapshot.pending_started = pending.started == true
        return snapshot
    end

    local get_target = windower and windower.ffxi and windower.ffxi.get_mob_by_target
    local target = type(get_target) == 'function' and get_target('t') or nil
    if not target or (target.hpp ~= nil and tonumber(target.hpp)
        and tonumber(target.hpp) <= 0) then
        snapshot.status = 'NO_TARGET'
        return snapshot
    end
    if sc_window.target_id and target.id ~= sc_window.target_id then
        snapshot.status = 'TARGET_CHANGED'
        return snapshot
    end
    if not sc_burst_target_exists(sc_window.target_id) then
        snapshot.status = 'NO_TARGET'
        return snapshot
    end

    local choice, selection_status = manual_mb_resolve_spell(
        sc_window.name, snapshot.mp)
    if choice then
        snapshot.choice_id = choice.id
        snapshot.choice_name = choice.name
        snapshot.choice_element = choice.element
        snapshot.choice_tier = choice.tier
        snapshot.choice_cost = choice.cost
        snapshot.choice_recast = choice.recast
        snapshot.choice_recast_known = choice.recast_known
    end
    if selection_status ~= 'READY' then
        snapshot.status = selection_status
        return snapshot
    end
    if type(swaps_frozen) == 'function' and swaps_frozen() then
        snapshot.status = 'SWAPS_FROZEN'
        return snapshot
    end
    if type(midaction) == 'function' and midaction() then
        snapshot.status = 'BUSY'
        return snapshot
    end
    if buffactive and (buffactive.silence or buffactive.Silence
        or buffactive.mute or buffactive.Mute) then
        snapshot.status = 'SILENCED'
        return snapshot
    end
    snapshot.status = 'READY'
    return snapshot
end

-- Pending matching is name-first and target-safe. A missing target ID in an
-- older GearSwap hook is tolerated; an explicit different ID is never accepted.
-- @ai:fn manual_mb_pending_matches | layer=automb | hot=yes | purity=read | contract=Match an exact F10-selected spell and reject an explicit target mismatch.
local function manual_mb_pending_matches(spell)
    local pending = manual_mb and manual_mb.pending
    if not pending or not spell or spell.english ~= pending.name then return false end
    local spell_target_id = spell.target and spell.target.id
    if pending.target_id and spell_target_id
        and pending.target_id ~= spell_target_id then
        return false
    end
    return true
end

-- @ai:fn mb_confirm_precast | layer=automb | hot=yes | purity=write | contract=Mark the exact F10-selected spell as accepted by GearSwap; never clear or issue a second action.
mb_confirm_precast = function(spell)
    if not manual_mb_pending_matches(spell) then return false end
    manual_mb.pending.started = true
    return true
end

-- @ai:fn mb_confirm_aftercast | layer=automb | hot=yes | purity=write | contract=Release the exact F10 pending guard after completion/interruption while preserving the formed-chain window for another manual press.
mb_confirm_aftercast = function(spell)
    if not manual_mb_pending_matches(spell) then return false end
    manual_mb.pending = nil
    manual_mb.pending_generation = (manual_mb.pending_generation or 0) + 1
    return true
end

-- @ai:fn execute_manual_magic_burst | layer=command | hot=no | purity=write | contract=On F10 only, cast one highest-ranked currently actionable nuke for the tracked formed chain; never queue, retry, swap weapons, or consume the window.
execute_manual_magic_burst = function()
    local source = 'F10 MB'
    if manual_mb and manual_mb.pending then
        add_to_chat(123, '[F10 MB] '..tostring(manual_mb.pending.name)
            ..' was already submitted; wait for that cast to start or finish.')
        return false
    end
    if not control_action_ready(source) then return false end

    local now = os.clock()
    if not (sc_window and sc_window.name) then
        add_to_chat(123, '[F10 MB] No formed skillchain is currently tracked. Raw WS properties are not a burst window.')
        return false
    end
    if (tonumber(sc_window.expires) or 0) <= now then
        sc_clear_burst_window()
        add_to_chat(123, '[F10 MB] The magic-burst window expired; wait for the next formed skillchain.')
        return false
    end

    local snapshot = mb_opportunity_snapshot(now)
    local status = snapshot.status
    if status == 'NO_TARGET' then
        add_to_chat(123, '[F10 MB] No valid living <t>; retarget the enemy that formed '
            ..tostring(snapshot.chain_name or sc_window.name)..'.')
        return false
    elseif status == 'TARGET_CHANGED' then
        add_to_chat(123, '[F10 MB] Current <t> is not the target that formed '
            ..tostring(snapshot.chain_name or sc_window.name)..'; no spell was cast.')
        return false
    elseif status == 'NO_SPELL' then
        add_to_chat(123, '[F10 MB] '..tostring(snapshot.chain_name or sc_window.name)
            ..' has no learned, current-job-usable standard RDM elemental nuke match.')
        return false
    elseif status == 'NEED_MP' then
        add_to_chat(123, '[F10 MB] Need '..tostring(snapshot.choice_cost or '?')
            ..' MP for '..tostring(snapshot.choice_name or 'the next spell')
            ..' (current '..tostring(snapshot.mp or 0)..').')
        return false
    elseif status == 'RECAST' then
        local recast_text = snapshot.choice_recast_known
            and string.format('%.1fs', math.max(0, snapshot.choice_recast or 0))
            or 'unknown'
        add_to_chat(123, '[F10 MB] No compatible spell is ready; '
            ..tostring(snapshot.choice_name or 'next spell')..' recast '..recast_text..'.')
        return false
    elseif status == 'SILENCED' then
        add_to_chat(123, '[F10 MB] Silence/Mute blocks magic; no spell was submitted.')
        return false
    elseif status == 'SWAPS_FROZEN' then
        add_to_chat(123, '[F10 MB] Resume Pause/Fishing gear ownership before bursting.')
        return false
    elseif status == 'BUSY' then
        add_to_chat(123, '[F10 MB] Finish the current action, then press F10 again.')
        return false
    elseif status ~= 'READY' then
        add_to_chat(123, '[F10 MB] Burst is not actionable ('..tostring(status)..').')
        return false
    end

    local target_id = snapshot.target_id
    local remaining = tonumber(snapshot.remaining) or 0
    add_to_chat(158, string.format(
        '[F10 MB] %s -> %s (%s, tier %d, %d MP; %.1fs window).',
        tostring(snapshot.chain_name), tostring(snapshot.choice_name),
        tostring(snapshot.choice_element), tonumber(snapshot.choice_tier) or 0,
        tonumber(snapshot.choice_cost) or 0, remaining))

    manual_mb.pending_generation = (manual_mb.pending_generation or 0) + 1
    local pending_token = manual_mb.pending_generation
    manual_mb.pending = {
        token=pending_token,
        id=snapshot.choice_id,
        name=snapshot.choice_name,
        element=snapshot.choice_element,
        tier=snapshot.choice_tier,
        cost=snapshot.choice_cost,
        target_id=target_id,
        window_generation=sc_window.generation,
        issued_at=now,
        started=false,
    }
    send_command('@input /ma "'..tostring(snapshot.choice_name)..'" <t>')
    update_hud()

    -- The first timeout only releases a command that never reached precast.
    -- A confirmed cast gets a longer state-only failsafe in case an unusual
    -- interrupted action omits aftercast. Neither callback sends or retries.
    if coroutine and type(coroutine.schedule) == 'function' then
        coroutine.schedule(function()
            if RDM_RUNTIME.unloading then return end
            local pending = manual_mb and manual_mb.pending
            if not (pending and pending.token == pending_token) then return end
            if not pending.started then
                manual_mb.pending = nil
                manual_mb.pending_generation = manual_mb.pending_generation + 1
                update_hud()
                return
            end
            coroutine.schedule(function()
                if RDM_RUNTIME.unloading then return end
                local still_pending = manual_mb and manual_mb.pending
                if still_pending and still_pending.token == pending_token then
                    manual_mb.pending = nil
                    manual_mb.pending_generation = manual_mb.pending_generation + 1
                    update_hud()
                end
            end, manual_mb.hard_timeout)
        end, manual_mb.submit_timeout)
    end
    return true
end

-- Action packet add_effect message IDs that announce a skillchain
local sc_messages = {
    [288]='Light', [289]='Darkness', [290]='Gravitation', [291]='Fragmentation',
    [292]='Distortion', [293]='Fusion', [294]='Compression', [295]='Liquefaction',
    [296]='Induration', [297]='Reverberation', [298]='Transfixion', [299]='Scission',
    [300]='Detonation', [301]='Impaction',
    [385]='Light', [386]='Darkness', [387]='Gravitation', [388]='Fragmentation',
    [389]='Distortion', [390]='Fusion', [391]='Compression', [392]='Liquefaction',
    [393]='Induration', [394]='Reverberation', [395]='Transfixion', [396]='Scission',
    [397]='Detonation', [398]='Impaction',
    [767]='Radiance', [768]='Umbra', [769]='Radiance', [770]='Umbra',
}

-- @ai:fn handle_action_packet | layer=automb | hot=yes | purity=write | contract=Passively remember WS/formed-chain context for manual F11 and the shared AutoMB/F10 window; never issue an action.
local function handle_action_packet(act)
    if not act or not act.targets or not state then return end

    -- A completion packet from the exact F11-selected WS is the authority for
    -- consuming its old opportunity. Merely sending the /ws command is not.
    -- The confirmation helper returns the generation that was submitted so a
    -- no-property WS can clear only its own stale context after this scan.
    local confirmed_generation
    if act.category == 3 and type(sc_confirm_pending) == 'function' then
        confirmed_generation = sc_confirm_pending(act)
    end

    -- The remaining scan maintains the always-on magic-burst window.
    perf_count('action_burst_scans')

    local packet_now
    local packet_seen
    local formed_chain_targets
    for _, targ in pairs(act.targets) do
        if targ.actions then
            for _, a in pairs(targ.actions) do
                local chain_name = a.has_add_effect and sc_messages[a.add_effect_message]
                if chain_name and targ.id then
                    -- Some packets repeat the same skillchain add-effect record.
                    -- Deduplicate by target + chain within this packet so one real
                    -- chain opens one burst window and one manual-F11 resonance.
                    packet_seen = packet_seen or {}
                    local target_seen = packet_seen[targ.id]
                    if not target_seen then
                        target_seen = {}
                        packet_seen[targ.id] = target_seen
                    end
                    if not target_seen[chain_name] then
                        target_seen[chain_name] = true
                        formed_chain_targets = formed_chain_targets or {}
                        formed_chain_targets[targ.id] = chain_name
                        -- A single action packet can contain multiple targets/actions.
                        -- Sample the packet time only once and give every detected
                        -- skillchain effect the same ten-second window.
                        packet_now = packet_now or os.clock()
                        sc_window.generation = (sc_window.generation or 0) + 1
                        sc_window.name = chain_name
                        sc_window.target_id = targ.id
                        sc_window.observed_at = packet_now
                        sc_window.expires = packet_now + 10
                        -- A newer formed chain supersedes any still-pending F10
                        -- request from the previous window. Midaction remains the
                        -- authority if that old spell is already casting.
                        if manual_mb then
                            manual_mb.pending = nil
                            manual_mb.pending_generation =
                                (manual_mb.pending_generation or 0) + 1
                        end
                        -- Re-arm F11 to the FORMED chain's property so a Lv1/Lv2
                        -- can be manually escalated (e.g. Distortion -> Darkness).
                        sc_note_resonance(chain_name, targ.id, chain_name)
                        update_hud()
                        -- A generation-safe wakeup clears the internal target
                        -- reference promptly when its ten-second window ends.
                        local window_generation = sc_window.generation
                        coroutine.schedule(function()
                            if RDM_RUNTIME.unloading then return end
                            if sc_window.generation == window_generation
                                and sc_window.expires <= os.clock() then
                                sc_clear_burst_window()
                            end
                        end, 10.1)
                    end
                end
            end
        end
    end

    -- Manual skillchain tracking consumes completed WS packets only. When that
    -- same packet formed a chain, the formed Light/Darkness/Lv2/Lv1 resonance is
    -- the final truth and the raw WS properties must not briefly arm a competing
    -- HUD state first. This removes the old disappear/reappear flicker while
    -- preserving formed-chain escalation.
    if act.category == 3 then
        perf_count('action_skillchain')
        perf_count('skillchain_scans')
        local perf_t = perf_begin()
        local raw_target_id
        for _, targ in pairs(act.targets or {}) do
            raw_target_id = targ.id
            break
        end
        if not (raw_target_id and formed_chain_targets
            and formed_chain_targets[raw_target_id]) then
            sc_track_ws_open(act)
        end
        perf_finish('skillchain_scan', perf_t)

        -- A successfully completed WS with no SC properties cannot create a
        -- replacement context. Clear only if no newer packet already replaced
        -- the generation that F11 submitted.
        if confirmed_generation and sc_react
            and sc_react.generation == confirmed_generation then
            sc_cancel('confirmed F11 WS produced no new resonance')
        end
    end

    -- TP gained from the player's melee round can turn NEED TP into READY while
    -- the same opportunity remains active. Refresh presentation from the event
    -- instead of adding a polling/retry loop; this callback never issues actions.
    if act.category == 1 and player and act.actor_id == player.id
        and sc_react and sc_react.props then
        update_hud()
    end
end

track_rdm_event(windower.raw_register_event('action', function(act)
    if not perf.enabled then
        handle_action_packet(act)
        return
    end
    perf_count('action_packets')
    local perf_t = perf_begin()
    handle_action_packet(act)
    perf_finish('action', perf_t)
end))

-- @ai:fn sc_burst_window_active | layer=automb | hot=yes | purity=write | contract=Validate window expiry/target/element at cast time; clears stale windows.
function sc_burst_window_active(spell)
    local now = os.clock()
    if sc_window.expires <= now then
        -- Drop stale references once the window closes rather than carrying the
        -- last chain name/target forever between casts.
        sc_clear_burst_window()
        return false
    end
    if not sc_burst_target_exists(sc_window.target_id) then
        -- The target despawned, died, or left the local entity table. Do not keep
        -- a burst window alive for an entity that can no longer be acted upon.
        sc_clear_burst_window()
        return false
    end
    if not spell.target or spell.target.id ~= sc_window.target_id then return false end
    local elems = sc_burst_elements[sc_window.name]
    return elems and elems:contains(spell.element) or false
end


-------------------------------------------------------------------------------------------------------------------
-- Manual Skillchain Closer -- plain F11
--
--   Completed WS packets and formed skillchains are observed passively. The
--   newest resonance is stored only for its target and only for the normal SC
--   timing window. Nothing is fired, queued, delayed, or retried automatically.
--
--   Press F11 after the opening delay. The closer scans weaponskills currently
--   usable with the LIVE equipped weapon, ranks them by the resulting chain
--   level (Light/Darkness > Lv2 > Lv1), then uses the strongest
--   configured tie-break for the live main/range weapons. It never changes gear.
--
--   A formed Lv1/Lv2/Light/Darkness chain replaces the raw WS resonance, allowing
--   a later F11 press to escalate or double the chain. An early press reports the
--   remaining delay and requires another press; it never schedules a future WS.
-------------------------------------------------------------------------------------------------------------------

-- Resources are required to map a weaponskill id -> its skillchain properties.
-- Try a few ways to obtain them so this works across GearSwap setups.
-- `res` is forward-declared above get_ws_properties() to preserve lexical scope.
do
    local ok, r = pcall(require, 'resources')
    if ok and type(r) == 'table' then
        res = r
    elseif type(_G) == 'table' and type(rawget(_G, 'res')) == 'table' then
        res = rawget(_G, 'res')
    end
end

-- Property combination matrix: sc_combo[resonating_property][your_ws_property] = result.
-- Canonical FFXI skillchain table.
local sc_combo = {
    Light         = {Light='Light'},          -- terminal (double Light)
    Darkness      = {Darkness='Darkness'},     -- terminal (double Darkness)
    Gravitation   = {Distortion='Darkness',     Fragmentation='Fragmentation'},
    Fragmentation = {Fusion='Light',            Distortion='Distortion'},
    Distortion    = {Gravitation='Darkness',    Fusion='Fusion'},
    Fusion        = {Fragmentation='Light',     Gravitation='Gravitation'},
    Compression   = {Transfixion='Transfixion', Detonation='Detonation'},
    Liquefaction  = {Impaction='Fusion',        Scission='Scission'},
    Induration    = {Reverberation='Fragmentation', Compression='Compression', Impaction='Impaction'},
    Reverberation = {Induration='Induration',   Impaction='Impaction'},
    Transfixion   = {Scission='Distortion',     Reverberation='Reverberation', Compression='Compression'},
    Scission      = {Liquefaction='Liquefaction',Reverberation='Reverberation', Detonation='Detonation'},
    Detonation    = {Compression='Gravitation', Scission='Scission'},
    Impaction     = {Liquefaction='Liquefaction',Detonation='Detonation'},
}

local sc_level = {
    Radiance=4, Umbra=4,
    Light=3, Darkness=3,
    Gravitation=2, Fragmentation=2, Distortion=2, Fusion=2,
    Compression=1, Liquefaction=1, Induration=1, Reverberation=1,
    Transfixion=1, Scission=1, Detonation=1, Impaction=1,
}

-- Timing and same-level tie-break policy. The live abilities list remains the
-- authority for whether a WS is usable with the weapon actually equipped.
manual_sc = {
    min_tp      = 1000,
    opens_after = 2.8,     -- do not fire inside the post-WS dead zone
    window      = 7.5,     -- conservative outer edge of the normal SC window
    debug       = false,
    pending     = nil,     -- one manually submitted closer awaiting completion packet
    pending_generation = 0,
    ws_priority_by_main = {
        ['Crocea Mors']={'Chant du Cygne','Savage Blade','Death Blossom','Requiescat','Vorpal Blade','Seraph Blade','Sanguine Blade'},
        ['Naegling']   ={'Savage Blade','Chant du Cygne','Death Blossom','Requiescat','Vorpal Blade','Seraph Blade','Sanguine Blade'},
        ['Maxentius']  ={'Black Halo','Realmrazer','Hexa Strike','Judgment','Flash Nova'},
        ['Daybreak']   ={'Black Halo','Realmrazer','Hexa Strike','Judgment','Flash Nova'},
        ['Tauret']     ={'Evisceration','Exenterator','Aeolian Edge'},
    },
    ws_priority_by_range = {
        ['Kaja Bow']   ={'Empyreal Arrow'},
    },
}

-- The latest usable context only. `generation` lets presentation-only wakeups
-- ignore an opener that was replaced before their timer elapsed.
sc_react = {
    props=nil, target_id=nil, observed_at=0, opens_at=0, expires=0,
    opener='', actor_id=nil, generation=0,
    choice=nil, choice_signature=nil,
}

-- Centralized manual-resonance lifecycle ---------------------------------------
-- Clearing increments generation so presentation-only timing callbacks cannot
-- redraw an opener that has already been consumed or replaced.
-- @ai:fn sc_cancel | layer=skillchain | hot=no | purity=write | contract=Clear the remembered manual-F11 resonance and invalidate presentation wakeups.
function sc_cancel(reason)
    local had_resonance = sc_react.props ~= nil
    if manual_sc then
        manual_sc.pending = nil
        manual_sc.pending_generation = (manual_sc.pending_generation or 0) + 1
    end
    sc_react.generation = (sc_react.generation or 0) + 1
    sc_react.props = nil
    sc_react.target_id = nil
    sc_react.observed_at = 0
    sc_react.opens_at = 0
    sc_react.expires = 0
    sc_react.opener = ''
    sc_react.actor_id = nil
    sc_react.choice = nil
    sc_react.choice_signature = nil
    if manual_sc.debug and reason then
        add_to_chat(160, '[F11 SC dbg] resonance cleared: '..tostring(reason))
    end
    if had_resonance and not RDM_RUNTIME.unloading and type(update_hud) == 'function' then
        update_hud()
    end
end

-- @ai:fn sc_note_resonance | layer=skillchain | hot=yes | purity=write | contract=Remember only the newest resonance on the current target and schedule HUD refreshes, never a combat action.
function sc_note_resonance(prop, target_id, opener, actor_id)
    if not prop then return end
    local get_target = windower and windower.ffxi and windower.ffxi.get_mob_by_target
    local current = type(get_target) == 'function' and get_target('t') or nil
    if current and target_id and current.id ~= target_id then return end
    target_id = target_id or (current and current.id)
    if not target_id then return end

    local now = os.clock()
    sc_react.generation = (sc_react.generation or 0) + 1
    local generation = sc_react.generation
    sc_react.props = (type(prop) == 'table') and prop or {prop}
    sc_react.target_id = target_id
    sc_react.observed_at = now
    sc_react.opens_at = now + manual_sc.opens_after
    sc_react.expires = now + manual_sc.window
    sc_react.opener = opener or ''
    sc_react.actor_id = actor_id
    sc_react.choice = nil
    sc_react.choice_signature = nil
    update_hud()

    -- These wakeups affect presentation only. They cannot issue commands, and
    -- generation checks make them harmless when a newer WS replaces the window.
    coroutine.schedule(function()
        if RDM_RUNTIME.unloading then return end
        if sc_react.generation == generation and sc_react.props then update_hud() end
    end, manual_sc.opens_after + 0.05)
    coroutine.schedule(function()
        if RDM_RUNTIME.unloading then return end
        if sc_react.generation == generation then
            if sc_react.expires <= os.clock() then sc_cancel('window expired') end
        end
    end, manual_sc.window + 0.05)
end

-- Every completed WS on the current target is a valid manual closer context,
-- whether it came from the player, a Trust, party/alliance member, or another PC.
-- @ai:fn sc_track_ws_open | layer=skillchain | hot=yes | purity=write | contract=Parse one completed WS and remember its properties for F11 without filtering self or scheduling an action.
function sc_track_ws_open(act)
    if not act or not res then return end
    local ws = res.weapon_skills[act.param]
    if not ws then return end

    local props = get_ws_properties(act.param, ws)
    if #props == 0 then
        if manual_sc.debug then
            add_to_chat(160, '[F11 SC dbg] '..tostring(ws.en)..' has no skillchain properties.')
        end
        return
    end

    local target_id
    for _, targ in pairs(act.targets or {}) do
        target_id = targ.id
        break
    end
    if manual_sc.debug then
        add_to_chat(160, '[F11 SC dbg] WS='..tostring(ws.en)
            ..' actor='..tostring(act.actor_id)..' target='..tostring(target_id)
            ..' props='..table.concat(props, '/'))
    end
    sc_note_resonance(props, target_id, ws.en, act.actor_id)
end

local manual_sc_ws_rank_by_main = {}
for main_name, priority in pairs(manual_sc.ws_priority_by_main) do
    local ranks = {}
    for index, ws_name in ipairs(priority) do
        ranks[ws_name] = #priority - index + 1
    end
    manual_sc_ws_rank_by_main[main_name] = ranks
end

local manual_sc_ws_rank_by_range = {}
for range_name, priority in pairs(manual_sc.ws_priority_by_range) do
    local ranks = {}
    for index, ws_name in ipairs(priority) do
        ranks[ws_name] = #priority - index + 1
    end
    manual_sc_ws_rank_by_range[range_name] = ranks
end

-- Of EVERY weaponskill the client says is currently available, choose the
-- closure producing the highest chain level. This list is the eligibility
-- authority: Naegling can use every learned/unlocked sword WS, not just Savage
-- Blade. Weapon-specific priorities are damage-oriented tie-breakers only after
-- resulting chain level; they never filter or grant eligibility.
-- @ai:fn pick_chain_ws | layer=skillchain | hot=no | purity=read | contract=Rank all live same-class learned WS closures by resulting chain level; weapon affinity is tie-break only and the function never equips or issues anything.
pick_chain_ws = function(active_props, available_ws_ids)
    if not res or type(active_props) ~= 'table' then return nil end
    if not available_ws_ids then
        local get_abilities = windower and windower.ffxi and windower.ffxi.get_abilities
        local abils = type(get_abilities) == 'function' and get_abilities() or nil
        available_ws_ids = abils and abils.weapon_skills or nil
    end
    if not available_ws_ids then return nil end

    local equipment = player and player.equipment or {}
    local main_name = control_item_name(equipment.main)
    local range_name = control_item_name(equipment.range)
    local main_ranks = manual_sc_ws_rank_by_main[main_name] or {}
    local range_ranks = manual_sc_ws_rank_by_range[range_name] or {}
    local best
    for _, ws_id in ipairs(available_ws_ids) do
        local ws = res.weapon_skills[ws_id]
        if ws and ws.en then
            for _, my_prop in ipairs(get_ws_properties(ws_id, ws)) do
                for _, active_prop in ipairs(active_props) do
                    local combos = sc_combo[active_prop]
                    local result = combos and combos[my_prop]
                    if result then
                        local level = sc_level[result] or 1
                        local main_rank = main_ranks[ws.en] or 0
                        local range_rank = range_ranks[ws.en] or 0
                        local geared_rank = RDM_WEAPONSKILL_POLICY[ws.en] and 1 or 0
                        local rank = level * 1000000 + range_rank * 10000
                            + main_rank * 1000 + geared_rank * 100
                        if not best or rank > best.rank
                            or (rank == best.rank and ws.en < best.name) then
                            best = {
                                name=ws.en, result=result, level=level, rank=rank,
                                id=ws_id,
                                ws_property=my_prop, opener_property=active_prop,
                            }
                        end
                    end
                end
            end
        end
    end
    return best
end

-- Recompute the choice only when the resonance generation, live weapon
-- combination, or Windower's available-WS list changes. Including the list in
-- the signature prevents a transient action-lock/weapon update from caching a
-- false NO CLOSER after the client publishes the usable WS menu again.
-- @ai:fn sc_refresh_choice | layer=skillchain | hot=yes | purity=write | contract=Cache the authoritative all-live-WS closer by resonance, equipped main/sub/range, and available-WS signatures.
sc_refresh_choice = function()
    if not (sc_react and sc_react.props and type(pick_chain_ws) == 'function') then
        return nil
    end
    local equipment = player and player.equipment or {}
    local get_abilities = windower and windower.ffxi and windower.ffxi.get_abilities
    local abils = type(get_abilities) == 'function' and get_abilities() or nil
    local available_ws_ids = abils and abils.weapon_skills or nil
    local ability_signature = available_ws_ids and table.concat(available_ws_ids, ',') or 'unavailable'
    local signature = table.concat({
        tostring(sc_react.generation or 0),
        tostring(control_item_name(equipment.main) or ''),
        tostring(control_item_name(equipment.sub) or ''),
        tostring(control_item_name(equipment.range) or ''),
        tostring(player and player.main_job or ''),
        tostring(player and player.sub_job or ''),
        ability_signature,
    }, '|')
    if sc_react.choice_signature == signature then
        return sc_react.choice
    end
    sc_react.choice_signature = signature
    sc_react.choice = pick_chain_ws(sc_react.props, available_ws_ids)
    return sc_react.choice
end

-- One read-only decision snapshot feeds both HUD layouts. Timing is intentionally
-- unchanged from the live-tested v2.57 values; READY now additionally means the
-- target matches, a real closer exists, the player is engaged, TP is sufficient,
-- swaps are live, and GearSwap is not busy with another action.
-- @ai:fn sc_opportunity_snapshot | layer=skillchain | hot=yes | purity=read | contract=Describe the current F11 opportunity as WAIT/NEED_TP/READY/NO_CLOSER/PENDING or a concrete blocking reason, naming the exact chosen WS/result.
sc_opportunity_snapshot = function(now)
    now = tonumber(now) or os.clock()
    local snapshot = {
        active=false, status='NONE', generation=sc_react and sc_react.generation or 0,
        tp=0,
    }
    if not (sc_react and sc_react.props)
        or (tonumber(sc_react.expires) or 0) <= now then
        return snapshot
    end

    snapshot.active = true
    snapshot.tp = tonumber(player and player.tp) or 0
    snapshot.opener = sc_react.opener or ''
    snapshot.first_property = sc_react.props[1]
    snapshot.properties_text = table.concat(sc_react.props, '/')
    snapshot.wait_remaining = math.max(0, (tonumber(sc_react.opens_at) or now) - now)

    local choice = sc_refresh_choice()
    if choice then
        snapshot.choice_name = choice.name
        snapshot.choice_result = choice.result
        snapshot.choice_level = choice.level
        snapshot.choice_id = choice.id
    end

    local pending = manual_sc and manual_sc.pending
    if pending then
        snapshot.status = 'PENDING'
        snapshot.pending_name = pending.name
        snapshot.choice_name = pending.name or snapshot.choice_name
        snapshot.choice_result = pending.result or snapshot.choice_result
        return snapshot
    end

    local get_target = windower and windower.ffxi and windower.ffxi.get_mob_by_target
    local target = type(get_target) == 'function' and get_target('t') or nil
    if not target or (target.hpp ~= nil and tonumber(target.hpp)
        and tonumber(target.hpp) <= 0) then
        snapshot.status = 'NO_TARGET'
        return snapshot
    end
    if sc_react.target_id and target.id ~= sc_react.target_id then
        snapshot.status = 'TARGET_CHANGED'
        return snapshot
    end
    if not choice then
        snapshot.status = 'NO_CLOSER'
        return snapshot
    end
    if not player or player.status ~= 'Engaged' then
        snapshot.status = 'NOT_ENGAGED'
        return snapshot
    end
    if now < (tonumber(sc_react.opens_at) or math.huge) then
        snapshot.status = 'WAIT'
        return snapshot
    end
    if snapshot.tp < (manual_sc.min_tp or 1000) then
        snapshot.status = 'NEED_TP'
        return snapshot
    end
    if type(swaps_frozen) == 'function' and swaps_frozen() then
        snapshot.status = 'SWAPS_FROZEN'
        return snapshot
    end
    if type(midaction) == 'function' and midaction() then
        snapshot.status = 'BUSY'
        return snapshot
    end
    snapshot.status = 'READY'
    return snapshot
end

-- Match only the player's exact submitted F11 WS completion. The old context is
-- not consumed here; handle_action_packet first records the packet's final
-- formed-chain/raw-WS resonance, then clears the old generation only if the WS
-- produced no replacement context.
-- @ai:fn sc_confirm_pending | layer=skillchain | hot=yes | purity=write | contract=Confirm one pending F11 request from the matching player WS completion packet and return its submitted resonance generation.
sc_confirm_pending = function(act)
    local pending = manual_sc and manual_sc.pending
    if not pending or not act or not player or act.actor_id ~= player.id then
        return nil
    end
    local ws = res and res.weapon_skills and res.weapon_skills[act.param]
    if not ws or (pending.id and act.param ~= pending.id)
        or ws.en ~= pending.name then
        return nil
    end
    local target_id
    for _, targ in pairs(act.targets or {}) do
        target_id = targ.id
        break
    end
    if pending.target_id and target_id ~= pending.target_id then
        return nil
    end

    manual_sc.pending = nil
    manual_sc.pending_generation = (manual_sc.pending_generation or 0) + 1
    if manual_sc.debug then
        add_to_chat(160, '[F11 SC dbg] confirmed '..tostring(ws.en)
            ..' completion on target '..tostring(target_id)..'.')
    end
    return pending.generation
end

-- @ai:fn execute_manual_skillchain | layer=command | hot=no | purity=write | contract=On F11 only, validate the remembered target/timing and fire one highest-level live-weapon-combination closer without changing weapons.
function execute_manual_skillchain()
    local source = 'F11 SC'
    if manual_sc and manual_sc.pending then
        add_to_chat(123, '[F11 SC] '..tostring(manual_sc.pending.name)
            ..' was already submitted; waiting for its completion packet.')
        return false
    end
    if not control_action_ready(source) then return false end
    if not res then
        add_to_chat(123, '[F11 SC] Windower resources are unavailable; no WS was issued.')
        return false
    end

    local get_target = windower and windower.ffxi and windower.ffxi.get_mob_by_target
    local target = type(get_target) == 'function' and get_target('t') or nil
    if not target or (target.hpp ~= nil and tonumber(target.hpp) and tonumber(target.hpp) <= 0) then
        add_to_chat(123, '[F11 SC] No valid living <t> target; no WS was issued.')
        return false
    end
    if player.status ~= 'Engaged' then
        add_to_chat(123, '[F11 SC] Engage the target before using the closer.')
        return false
    end

    local now = os.clock()
    if not sc_react.props then
        add_to_chat(123, '[F11 SC] No recent WS or formed skillchain is tracked on this target.')
        return false
    end
    if now > sc_react.expires then
        sc_cancel('F11 found expired window')
        add_to_chat(123, '[F11 SC] The skillchain window expired; wait for the next WS.')
        return false
    end
    if sc_react.target_id ~= target.id then
        local tracked_id = sc_react.target_id
        sc_cancel('F11 target mismatch')
        add_to_chat(123, '[F11 SC] Last WS belonged to another target ('
            ..tostring(tracked_id)..'); no WS was issued.')
        return false
    end

    local choice = sc_refresh_choice()
    local equipment = player.equipment or {}
    local main_name = control_item_name(equipment.main) or '(empty)'
    local sub_name = control_item_name(equipment.sub) or '(empty)'
    local range_name = control_item_name(equipment.range) or '(empty)'
    if not choice then
        add_to_chat(123, '[F11 SC] No WS currently usable with '..tostring(main_name)
            ..' closes '..table.concat(sc_react.props, '/')
            ..'. Weapons were not changed and no TP was spent.')
        return false
    end
    if now < sc_react.opens_at then
        add_to_chat(123, string.format(
            '[F11 SC] Too early for %s; press F11 again in about %.1fs. Nothing was queued.',
            tostring(sc_react.opener ~= '' and sc_react.opener or 'the opener'),
            math.max(0, sc_react.opens_at - now)))
        return false
    end
    if (tonumber(player.tp) or 0) < manual_sc.min_tp then
        add_to_chat(123, '[F11 SC] Need 1000 TP during the live window (current '
            ..tostring(player.tp or 0)..'); no retry was queued.')
        return false
    end

    local opener = sc_react.opener ~= '' and sc_react.opener
        or table.concat(sc_react.props, '/')
    add_to_chat(158, '[F11 SC] '..tostring(opener)..' -> '..choice.result
        ..' (Lv'..choice.level..') with '..choice.name
        ..' | '..tostring(main_name)..' / '..tostring(sub_name)
        ..' | range '..tostring(range_name)..'.')

    -- Preserve the opportunity until an action packet confirms this exact WS.
    -- A rejected command therefore returns to READY instead of silently erasing
    -- the HUD. The timeout is presentation/state cleanup only; it never retries.
    manual_sc.pending_generation = (manual_sc.pending_generation or 0) + 1
    local pending_token = manual_sc.pending_generation
    manual_sc.pending = {
        token=pending_token,
        id=choice.id,
        name=choice.name,
        result=choice.result,
        target_id=target.id,
        generation=sc_react.generation,
        issued_at=now,
    }
    local issued = issue_target_weaponskill(choice.name, source,
        tostring(main_name)..' / '..tostring(sub_name)..' | range '..tostring(range_name),
        true)
    if not issued then
        if manual_sc.pending and manual_sc.pending.token == pending_token then
            manual_sc.pending = nil
            manual_sc.pending_generation = manual_sc.pending_generation + 1
        end
        update_hud()
        return false
    end

    update_hud()
    if coroutine and type(coroutine.schedule) == 'function' then
        coroutine.schedule(function()
            if RDM_RUNTIME.unloading then return end
            local pending = manual_sc and manual_sc.pending
            if pending and pending.token == pending_token then
                manual_sc.pending = nil
                manual_sc.pending_generation = manual_sc.pending_generation + 1
                if manual_sc.debug then
                    add_to_chat(160, '[F11 SC dbg] no completion packet for '
                        ..tostring(choice.name)..'; opportunity preserved.')
                end
                update_hud()
            end
        end, 3.0)
    end
    return true
end

-- On-demand diagnostics: gs c sctest
-- @ai:fn sc_selftest | layer=skillchain | hot=no | purity=write | contract=Diagnostic-only dump of resources, live WS properties, F11 decision, and formed-chain F10 spell decision.
function sc_selftest()
    add_to_chat(158, '=== F11 manual skillchain closer ===')
    add_to_chat(158, string.format(
        'Manual only | resources=%s | opens=%.1fs | expires=%.1fs | TP minimum=%d',
        tostring(res ~= nil), manual_sc.opens_after, manual_sc.window, manual_sc.min_tp))
    add_to_chat(158, 'Your TP: '..tostring(player.tp)..' | status: '..tostring(player.status))
    local t = windower.ffxi.get_mob_by_target('t')
    add_to_chat(158, 'Current target: '..tostring(t and (t.name..' ['..t.id..']') or 'none'))
    if not res then
        add_to_chat(123, 'Resources unavailable -> F11 cannot read WS properties.')
        add_to_chat(158, '=== end ===')
        return
    end
    local abils = windower.ffxi.get_abilities()
    local list = abils and abils.weapon_skills or nil
    if not list or #list == 0 then
        add_to_chat(123, 'No weaponskills are currently usable with the equipped weapon.')
    else
        add_to_chat(158, 'All currently available same-class WS options ('..#list..'):')
        for _, id in ipairs(list) do
            local ws = res.weapon_skills[id]
            if ws then
                local props = get_ws_properties(id, ws)
                add_to_chat(158, '  '..ws.en..'  ['..table.concat(props,'/')..']')
            end
        end
    end
    if sc_react.props then
        local now = os.clock()
        local choice = sc_refresh_choice()
        local snapshot = sc_opportunity_snapshot(now)
        local timing = now < sc_react.opens_at
            and string.format('opens in %.1fs', sc_react.opens_at - now)
            or string.format('%.1fs remains', math.max(0, sc_react.expires - now))
        add_to_chat(158, 'Tracked: '..tostring(sc_react.opener)..' ['
            ..table.concat(sc_react.props,'/')..'] | '..timing)
        add_to_chat(158, 'F11 HUD state: '..tostring(snapshot.status)
            ..' | TP '..tostring(snapshot.tp or 0)
            ..(snapshot.pending_name and (' | pending '..snapshot.pending_name) or ''))
        add_to_chat(158, choice
            and ('F11 choice: '..choice.name..' -> '..choice.result..' (Lv'..choice.level..')')
            or 'F11 choice: none in the currently available WS list')
    else
        add_to_chat(158, 'No active resonance right now.')
    end
    local mb_snapshot = type(mb_opportunity_snapshot) == 'function'
        and mb_opportunity_snapshot(os.clock()) or {active=false, status='NONE'}
    if mb_snapshot.active then
        add_to_chat(158, 'F10 formed chain: '..tostring(mb_snapshot.chain_name)
            ..' | state '..tostring(mb_snapshot.status)
            ..' | window '..string.format('%.1fs', tonumber(mb_snapshot.remaining) or 0))
        add_to_chat(158, mb_snapshot.choice_name
            and ('F10 choice: '..tostring(mb_snapshot.choice_name)
                ..' ('..tostring(mb_snapshot.choice_element)..')'
                ..' | MP '..tostring(mb_snapshot.mp or 0)
                ..'/'..tostring(mb_snapshot.choice_cost or 0))
            or 'F10 choice: no standard elemental nuke match')
    else
        add_to_chat(158, 'F10 formed burst window: none.')
    end
    add_to_chat(158, 'Tip: gs c scdebug toggles packet diagnostics; it never enables automatic WS use.')
    add_to_chat(158, '=== end ===')
end

-- Complete on-demand keybind refresher. Plain F10 is manual MB, F11 is the manual SC closer,
-- and F12 is the weapon-aware standalone WS. Ctrl+F9/F10/F11 own weapon
-- pair/lock, Ctrl+F12 owns Silmaril, Alt+F9 owns HUD position lock, and Alt+F10
-- owns HUD visibility. Plain F9, Shift/Win+F9-F12, and Alt+F11-F12 remain
-- clear. Ctrl+F1-F7 retain the compact combat row and Alt+F1-F3 retain sparse
-- TH/Fishing/Pause utilities.
-- The optional startup_summary flag suppresses HUD-covered/retired-history
-- lines during automatic reload output without weakening typed help.
-- @ai:fn print_keybinds | layer=command | hot=no | purity=write | contract=Chat-only keybind reference; true emits the concise automatic reload variant.
function print_keybinds(startup_summary)
    if not startup_summary then
        add_to_chat(158, '=== RDM primary controls ===')
        add_to_chat(158, ' F10 Manual Magic Burst <t> | F11 Manual Skillchain Closer <t> | F12 Weapon-Aware WS <t>')
        add_to_chat(158, ' F10: formed chain only; highest-tier learned/usable/ready/affordable compatible elemental spell')
        add_to_chat(158, ' F10 same-tier order: Thunder > Blizzard > Fire > Aero > Water > Stone; one press = one cast')
        add_to_chat(158, ' F10 HUD: exact spell -> chain plus READY / NEED MP / RECAST / NO SPELL / SENT')
        add_to_chat(158, ' F11: all learned live-class WS eligible; chain level wins; weapon affinity only breaks ties')
        add_to_chat(158, ' F11 HUD: exact WS -> result plus WAIT / NEED TP / READY / NO CLOSER / SENT')
        add_to_chat(158, ' F12: Crocea/Daybreak CDC | Crocea/TP Seraph Blade | Tauret Evisceration')
        add_to_chat(158, ' F12: Naegling Savage Blade | Maxentius/Daybreak Black Halo')
        add_to_chat(158, ' F12: Kaja Bow Empyreal Arrow (Naegling/TP Bonus + Chapuli Arrow profile)')
        add_to_chat(158, ' Ctrl+F9 Weapon Pair back | Ctrl+F10 Weapon Pair forward | Ctrl+F11 Weapon Lock | Ctrl+F12 Silmaril')
        add_to_chat(158, ' Alt+F9 HUD Position Lock/Unlock | Alt+F10 HUD Show/Hide')
        add_to_chat(158, ' F9, Shift/Win+F9-F12, and Alt+F11-F12 unbound')
    end
    add_to_chat(158, '=== RDM combat mode controls ===')
    add_to_chat(158, ' Ctrl+F1 Melee Accuracy: Normal > MidAcc > HighAcc (single-wield and DW)')
    add_to_chat(158, ' Ctrl+F2 Melee DT: Off/On (single-wield and DW)')
    add_to_chat(158, ' Ctrl+F3 Defense: Normal > DT > MEVA')
    add_to_chat(158, ' Ctrl+F4 Casting: Normal > SIRD > SpellACC')
    add_to_chat(158, ' Ctrl+F5 Enfeebling: Auto > Accuracy')
    add_to_chat(158, ' Ctrl+F6 Enspell Melee: Auto > Max > Off')
    add_to_chat(158, ' Ctrl+F7 Idle Gear: Normal > DT')
    if not startup_summary then
        add_to_chat(158, ' Enhancing: automatic spell-aware routing (no mode)')
        add_to_chat(158, ' WS accuracy follows Ctrl+F1; independent WS mode retired')
    end
    add_to_chat(158, '=== RDM utility controls ===')
    add_to_chat(158, ' Alt+F1 Treasure Hunter: manual Off/On')
    add_to_chat(158, ' Alt+F2 Fishing: rod/armor hold; movement and protected rings remain active')
    add_to_chat(158, ' Alt+F3 Pause: full all-slot gear freeze')
    if not startup_summary then
        add_to_chat(158, ' Alt+F9 HUD Position: lock/unlock dragging (position saves on either transition)')
        add_to_chat(158, ' Ctrl+- / Ctrl+= Mote target rewrites: disabled')
        add_to_chat(158, '=== RDM HUD controls ===')
        add_to_chat(158, ' Alt+F10 HUD show/hide | typed: gs c hud | position lock: gs c hudlock')
        add_to_chat(158, ' Win+H retired and explicitly cleared')
    end
    add_to_chat(158, ' typed: gs c rdmweapon <pair> | gs c rdmplay <style> | gs c rdmreset')
    add_to_chat(158, ' typed: gs c rangedlock [on|off|status] (no argument toggles ordinary-shot ammo safety)')
    add_to_chat(158, ' typed: gs c magicburst | gs c skillchain | gs c bestws')
    add_to_chat(158, ' typed: gs c cycle EnfeeblingMode | cycle EnspellMode | gs c magicmodes')
    add_to_chat(158, ' typed: gs c rdmdefense <normal|dt|meva> | gs c cycle CastingMode')
    add_to_chat(158, ' typed: gs c cycle CasterRollFC | gs c perf on|off|reset')
    if startup_summary then
        add_to_chat(158, ' Full keybind reference: gs c keys')
    end
end

-- Print only the concise refresher shortly after load (after user_setup has
-- bound the keys and the GearSwap load spam has settled). Typed 'gs c keys'
-- calls the same function without the startup flag and prints the full map.
coroutine.schedule(function()
    if not RDM_RUNTIME.unloading then print_keybinds(true) end
end, 4)



-- Disengaging ends the remembered manual skillchain context. Presentation-only
-- HUD wakeups are invalidated through sc_cancel(); no combat callback exists.
-- @ai:fn job_status_change | layer=framework | hot=yes | purity=write | contract=Clear manual skillchain context when leaving Engaged.
function job_status_change(newStatus, oldStatus, eventArgs)
    if newStatus ~= 'Engaged' and sc_cancel then
        sc_cancel('status '..tostring(newStatus))
    end
    update_hud()
end

-- Single-wield variants never change after init_gear_sets. Build each one
-- once on first use instead of allocating a fresh set after every idle cast.
local shielded_weapon_sets = {}
-- @ai:fn check_weaponset | layer=gear | hot=yes | purity=write | contract=Reassert selected weapon pair only when unlocked and actual weapon slots differ; cache shield fallback.
function check_weaponset()
    if not (state and state.WeaponSet and sets and player) then return end

    -- WeaponLock and full-swap freezes intentionally make weapon equip attempts
    -- no-ops. Skip the GearSwap equip call entirely until those locks are released.
    if (state.WeaponLock and state.WeaponLock.value)
        or (state.PauseSwaps and state.PauseSwaps.value)
        or (state.FishingMode and state.FishingMode.value) then
        perf_count('weapon_reassert_hits')
        return
    end

    local weapon_name = control_state_value('WeaponSet')
    local weapon_set = sets[weapon_name]
    if not weapon_set then
        add_to_chat(123, '[WeaponSet] Missing set: '..tostring(weapon_name))
        return
    end
    local desired = weapon_set
    if not dual_wield_available() then
        desired = shielded_weapon_sets[weapon_name]
        if not desired then
            local shield = sets.WeaponShields and sets.WeaponShields[weapon_name]
                or sets.DefaultShield
            desired = set_combine(weapon_set, shield)
            shielded_weapon_sets[weapon_name] = desired
        end
    end

    -- check_weaponset() runs during every engaged resolution. If the selected
    -- main/sub/range/ammo are already worn, do not enqueue a redundant equip
    -- request. Ammo is normally unspecified; KajaBow intentionally owns it.
    local eq = player.equipment or {}
    local main_ok = not desired.main or dw_item_name(eq.main) == dw_item_name(desired.main)
    local sub_ok = not desired.sub or dw_item_name(eq.sub or eq.left_sub) == dw_item_name(desired.sub)
    local range_ok = not desired.range or dw_item_name(eq.range) == dw_item_name(desired.range)
    local ammo_ok = not desired.ammo or dw_item_name(eq.ammo) == dw_item_name(desired.ammo)
    if main_ok and sub_ok and range_ok and ammo_ok then
        perf_count('weapon_reassert_hits')
        return
    end

    perf_count('weapon_reassert_changes')
    equip(desired)
end
-- On zone change you've arrived: drop WARP/dimension rings so normal rings return.
-- Boost rings (EXP/CP) are intentionally kept across zones until their buff lands.
track_rdm_event(windower.register_event('zone change',
    function()
        if sc_cancel then sc_cancel('zone change') end
        moving = false
        movement_monitor.x, movement_monitor.y, movement_monitor.z = nil, nil, nil
        movement_monitor.last_motion_at = 0
        movement_monitor.refresh_pending = true
        movement_monitor.refresh_queued = false
        -- During zone transitions the player/equipment snapshot can briefly be
        -- unavailable. Ignore that edge rather than indexing nil. Also avoid
        -- allocating a temporary slot list for this two-slot check.
        if not player or not player.equipment then return end
        local changed = false
        if warp_gear:contains(player.equipment.left_ring) then
            enable('ring1')
            if ring_lock_state then ring_lock_state.ring1 = false end
            changed = true
        end
        if warp_gear:contains(player.equipment.right_ring) then
            enable('ring2')
            if ring_lock_state then ring_lock_state.ring2 = false end
            changed = true
        end
        if changed then
            -- Force the idle rings back in now (no check_gear in between to re-lock).
            equip(sets.idle)
        end
    end
))

-- Select default macro book on initial load or subjob change.
-- @ai:fn select_default_macro_book | layer=framework | hot=no | purity=write | contract=Set default macro page/book.
function select_default_macro_book()
    -- Default macro set/book
    set_macro_page(1, 11)
end

-- @ai:fn set_lockstyle | layer=framework | hot=no | purity=write | contract=Schedule lockstyle command.
function set_lockstyle()
    send_command('wait 2; input /lockstyleset ' .. lockstyleset)
end

-------------------------------------------------------------------------------------------------------------------
