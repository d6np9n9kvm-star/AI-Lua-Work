-- Original: Motenten / Modified: Arislan (SMN) / Rebuilt from ItemStats.lua 2026-07-09
-------------------------------------------------------------------------------------------------------------------
--  Keybinds
-------------------------------------------------------------------------------------------------------------------
--  Keybind philosophy: mode changes only. No spell/ability binds -- use in-game
--  macros for casting. All binds live on F9-F12 (Mote defaults) or Win+letter.
--
--  Modes:      [ F9 ]              Cycle Offense Mode      (Normal/Acc -> physical BP gear)
--              [ F10 ]             Emergency -PDT Mode
--              [ F11 ]             Emergency -MDT Mode
--              [ CTRL+F11 ]        Cycle Casting Modes     (Normal/Resistant -> magical BP gear)
--              [ F12 ]             Update Current Gear / Report Current Status
--              [ CTRL+F12 ]        Cycle Idle Modes        (Normal/PDT)
--              [ ALT+F12 ]         Cancel Emergency -PDT/-MDT Mode
--
--  Win+letter: [ WIN+W ]           Toggle Weapon Lock
--              [ WIN+E ]           Cycle Weapon Set (back)
--              [ WIN+R ]           Cycle Weapon Set (forward)
--              [ WIN+A ]           Audit Gear (check sets vs. inventory)
--              [ WIN+P ]           Pause/Resume ALL auto gear swapping
--                                  (freezes every slot -- fishing, crafting, etc.)
--              [ WIN+H ]           Toggle on-screen HUD ('gs c hud')
--              [ CTRL+WIN+H ]      Lock/unlock HUD position ('gs c hudlock')
--
--  Typed/macro commands:  gs c keys        (reprint this list in-game)
--                         gs c auditgear   (same as Win+A)
--                         gs c perf        (tick-cost counters; verify smoothness)
--                         gs c bpwatch     (toggle per-pact recast report; default ON)
--
-------------------------------------------------------------------------------------------------------------------
--  ARCHITECTURE MAP -- read this before editing (human or AI)
-------------------------------------------------------------------------------------------------------------------
--
--  This file is a Mote-framework GearSwap job lua rebuilt on the RDM.lua
--  template. Mote-Include.lua owns the event loop and calls the job_* hooks
--  here. Purpose-built pieces, each in a banner-marked section:
--
--    1. BLOOD PACT ROUTER (job_get_spell_map): classifies every Blood Pact
--       and folds the F9/Ctrl-F11 modes into the map name, so mode variants
--       are plain named sets (no post-equip overlay hacks):
--         OffenseMode 'Acc'        -> PhysicalBloodPactRageAcc
--         CastingMode 'Resistant'  -> MagicalBloodPactRageResistant
--       WARDS route by EFFECT OBJECTIVE, not by avatar (ward_objectives in
--       job_setup): 'Skill' (potency/duration scales with summoning skill)
--       -> Baayami set; 'Acc' (lands on the enemy) -> Bunzi Pet-M.Acc set;
--       'Fixed' (nothing gear-side scales, e.g. Hastega II) -> DT chassis,
--       because the only thing gear can still buy is survivability during
--       the swap window. Unlisted wards fall back to a target heuristic
--       (enemy -> Acc, else Skill), so new pacts degrade safely.
--    2. ASTRAL CONDUIT LOCK (job_buff_change): conduit makes pacts instant
--       (no midcast window), so the magical BP set is equipped and every
--       slot frozen for the duration.
--    3. NO-SWAP RING ENGINE (check_gear / release_ring_slots / zone-change
--       handler): warp rings stay locked until you zone; EXP/CP rings stay
--       locked until their buff lands. Ported verbatim from RDM.lua.
--    4. GEAR AUDIT (Win+A): walks every set, checks each piece against all
--       inventory bags, reports what's missing and where it's referenced.
--    5. HUD (banner: 'On-screen SMN HUD'): a windower text box repainted by
--       the 1s smn_tick, plus the string cache so hud:text() only fires on
--       real change. Shows pet name/status/HP (mob data ONLY -- no packet
--       capture, see the performance invariants), Blood Pact Rage/Ward +
--       Siphon/Apogee recasts, modes, and player MP.
--       PERFORMANCE: no 'prerender', no 'incoming chunk'; one 1s
--       coroutine.schedule chain (smn_tick) drives everything periodic;
--       'gs c perf' shows measured tick cost so stutter claims can be
--       tested, not guessed.
--
--  SIDECAR: ItemStats.lua (same folder) is the single source of truth for
--  owned-gear stats and job locks. It loads FIRST in get_sets() because
--  Mote-Include runs job_setup/init_gear_sets during its own include.
--
--  UNITS / INVARIANTS -- violating these produces silent wrongness:
--    * BP RECAST TIMING v2 (2026-07, refined against Pergatory's SMN --
--      the battle-tested reference): the recast locks between the COMMAND
--      and the pet's READYING, never at pact resolution. Proof chain:
--      (a) capped-delay-in-precast-only regressed ~20s -> ~35s because
--      Mote's default_aftercast guard races pet_midaction() and can idle
--      you in the command->pet gap; (b) Pergatory's file holds a recast
--      TIMER set through that gap (his aftercast refuses to idle for BP
--      types), swaps to damage at pet_midcast, carries ZERO recast gear
--      in his damage sets, and observes capped timers -- so resolution-
--      time gear is irrelevant to recast. Implementation here mirrors his:
--        1. sets.midcast.BloodPactRage/Ward = TIMER set (bp_delay 15 cap
--           via Glyphic -8 + Baayami Slops -7, Sancus recast II -7, rest
--           summoning skill to hold the Favor tier) -- worn during the
--           player-midcast phase of the pact;
--        2. job_aftercast sets eventArgs.handled for uninterrupted BPs --
--           a HARD hold through the gap, no pet_midaction() race;
--        3. sets.midcast.Pet.* damage sets carry NO recast gear -- full
--           damage slots restored (Sancus stays for its BP dmg +15).
--      Shock Squall resolves before pet_midcast can fire (per Pergatory):
--      sets.midcast['Shock Squall'] is a timer+Pet-M.Acc hybrid that the
--      pact lands in. 'gs c bpwatch' verifies actual timers in-game --
--      if it ever reads ~35s again, the hold in job_aftercast broke.
--    * Damage-relevant pet stats (acc/m.acc/MAB/BP dmg) snapshot at pact
--      RESOLUTION -- gear worn in the sets.midcast.Pet.* sets.
--    * Avatar perpetuation gear totals -25 MP/tick in sets.idle.Avatar
--      (Gridarvor 5, Glyphic 4, Apogee Pumps 8, Assid. Pants 3, Evans 2,
--      Evoker's 1, Lucidity 2) -- enough to zero out any avatar's tick cost.
--    * Pet haste (pet-engaged overlay) caps at 25%: Gridarvor 3 + Klouskap
--      Sash +1 9 + Tali'ah Crackows +2 7 + Rimeice 3 = 22. Player haste
--      1024ths convention from RDM.lua applies only to player sets here.
--    * Cure potency gear caps at +50%: Daybreak 30 + Bunzi's Robe 15 +
--      Vanya Hood 10 = 55, already capped. The remaining Cure slots buy
--      healing skill / cast time / DT, NOT potency -- don't "optimize" them.
--    * REMOVED FEATURE -- reactive perpetuation engine (2026-07): computed
--      net MP/tick and swapped perp gear for stat gear by MP tier. Removed
--      because (a) the estimate disagreed with observed in-game drain (the
--      model had unverifiable knobs: trait/gift refresh, back-solved base
--      costs, unmodeled day/weather) and (b) it added hot-path work during
--      a stutter investigation. Do NOT re-add gear reactivity built on an
--      unvalidated model. ItemStats keeps the verified perp fields; a
--      display-only estimator may return AFTER the model is validated
--      manually in-game. idle.Avatar simply wears the full perp loadout.
--    * Ward names in ward_objectives are verbatim from Windower
--      res/job_abilities.lua (the offline test asserts this). Notable
--      classifications: Perfect Defense DURATION scales with summoning
--      skill at use -- it must always hit the skill set; Earthen Ward's
--      stoneskin and Crystal Blessing's TP-bonus tier are skill-gated;
--      Hastega/Hastega II are FLAT -- skill gear does nothing for them.
--    * Ability recast IDs (from Windower res/job_abilities.lua, NOT guessed):
--      BP Rage=173, BP Ward=174, Elemental Siphon=175 (not 172!), Apogee=108,
--      Mana Cede=71, Astral Flow=0 (SP1), Astral Conduit=254 (SP2).
--      windower.ffxi.get_ability_recasts() returns SECONDS; spell recasts
--      (get_spell_recasts) are in 60ths -- don't mix the two scales.
--
--  WARDROBE FACTS (things an optimizer would wrongly "fix"):
--    * The previous revision of this file slotted gear SMN CANNOT EQUIP --
--      confirmed against ItemStats job masks and removed:
--        Foire Dastanas/Babouches +1 (PUP), Kaykaus set +1 (WHM/RDM/BRD/SCH),
--        Jhakri Robe +2 (BLM/RDM/BLU/SCH/GEO), Nourish. Earring (WHM/PLD),
--        "Assiduity Pants" (not owned; the owned piece is "Assid. Pants +1").
--      Do not re-add them.
--    * Grioavolr's DESCRIPTION carries Avatar: M.Acc+35 / MAB+115, and its
--      augments add BP Dmg+5 / Pet M.Acc+16 / Pet MAB+24 -- it beats the
--      owned Keraunos (Avatar M.Acc+20 / MAB+100) for magical pacts.
--    * Asteria Mitts hide Avatar: MAB+25 -- best owned magical-BP hands.
--      (Bunzi's Gloves' Pet M.Acc+50 is the Resistant swap.)
--    * Inyan. Crackows +1 hide Avatar: BP damage +7 -- best owned BP feet
--      for BOTH physical and magical damage sets.
--    * Two Varar Ring +1 copies exist (BP dmg +4 / Pet Acc+10 each).
--    * Convoker's/Apogee +1/Merlinic/Nirvana are NOT owned -- the comments
--      near each set list the owned substitute; don't slot wishlist gear.
--
--  FIXED vs the previous revision:
--    * job_pet_aftercast wrote to a `wards` table that was never defined
--      (guaranteed nil-index error on every buff ward) and signalled a
--      'reset_ward_flag' command that had no handler. Removed.
--    * Precast BP set wore full Baayami (13/15 delay, hatless) -- now caps
--      at 15 with Glyphic Horn +1 + Baayami Slops.
--    * The FC set was mostly Inyanga pieces with zero Fast Cast on them;
--      rebuilt to the real owned FC pool (42% -- SMN has no native FC).
--    * display_current_job_state reported RDM-shaped state; now SMN-shaped.
--
--  PERFORMANCE ROADMAP (stutter investigation -- work top to bottom):
--    1. [DONE] Remove per-frame ('prerender') and per-packet ('incoming
--       chunk') dispatch, pet TP capture, and the reactive perp engine;
--       single 1s tick; 'gs c perf' instrumentation.
--    2. BISECT with the tools in this file: play identical content with
--       'gs c hud' toggled off. If stutter vanishes -> the texts object
--       repaint is the cost; move the HUD to a standalone addon (own Lua
--       state, fed by send_command) and keep this file HUD-free. If
--       stutter persists with HUD off and 'gs c perf' near zero -> this
--       file's periodic work is exonerated; go to 3.
--    3. Swap volume: each cast can rewrite up to 16 slots four times
--       (precast/midcast/pet midcast/idle). GearSwap only sends CHANGED
--       slots, so maximize piece overlap between adjacent sets (e.g. FC
--       filler slots already mirror idle DT pieces). A 'swap distance'
--       report in the audit engine could quantify the worst transitions.
--    4. Environment: test with other addons unloaded (GearSwap shares its
--       processing budget), and with a different job lua active on the
--       same content -- to separate SMN.lua costs from GearSwap-wide ones.
--
--  FEATURE ROADMAP:
--    0. VERIFY the BP recast fix in-game with 'gs c bpwatch' (default ON):
--       rages and wards should both report ~20s starts again. Once
--       confirmed, toggle bpwatch off or set the default to false.
--    1. Pet-DT idle variant when pet-DT gear is acquired (none owned now).
--    2. Display-only perp estimator, ONLY after manual in-game validation
--       of the model (see REMOVED FEATURE invariant).
--
-------------------------------------------------------------------------------------------------------------------
-- Setup functions for this job.  Generally should not be modified.
-------------------------------------------------------------------------------------------------------------------

function get_sets()
    mote_include_version = 2

    -- Wardrobe fact sheet (stats + job locks per owned item). Sidecar file in
    -- the same folder; shared by all job luas so a new acquisition is a
    -- one-line edit there. Defines: item_stats table, item_stat(name,field).
    -- MUST load BEFORE Mote-Include: Mote's init chain calls job_setup(),
    -- user_setup(), and init_gear_sets() during its own include.
    include('ItemStats.lua')

    include('Mote-Include.lua')
end

-- Setup vars that are user-independent.  state.Buff vars initialized here will automatically be tracked.
function job_setup()
    state.Buff["Avatar's Favor"] = buffactive["Avatar's Favor"] or false
    state.Buff["Astral Conduit"] = buffactive["Astral Conduit"] or false

    spirits = S{"LightSpirit", "DarkSpirit", "FireSpirit", "EarthSpirit", "WaterSpirit", "AirSpirit", "IceSpirit", "ThunderSpirit"}
    avatars = S{"Carbuncle", "Fenrir", "Diabolos", "Ifrit", "Titan", "Leviathan", "Garuda", "Shiva", "Ramuh", "Odin", "Alexander", "Cait Sith", "Siren"}

    -- Magical Blood Pacts -> Pet: Magic Attack Bonus / Magic Accuracy set
    magical_bps = S{'Meteorite','Holy Mist','Lunar Bay','Night Terror','Blood Drake','Flaming Crush',
        'Meteor Strike','Geocrush','Grand Fall','Wind Blade','Heavenly Strike','Thunderstorm',
        'Level ? Holy','Conflag Strike'}

    -- Physical Blood Pacts -> Pet: Attack / Accuracy set
    physical_bps = S{'Poison Nails','Moonlit Charge','Crescent Fang','Eclipse Bite','Blindside',
        'Punch','Burning Strike','Double Punch','Megalith Throw','Mountain Buster','Spinning Dive',
        'Predator Claws','Claw','Rush','Chaotic Strike','Volt Strike'}

    ---------------------------------------------------------------------------
    -- WARD OBJECTIVES: gear is chosen per ward EFFECT, not per avatar.
    -- With this wardrobe there are exactly three objectives a ward can have:
    --   'Skill' -> potency/duration scales with summoning magic skill worn
    --              during the pet's action  -> Baayami skill set
    --   'Acc'   -> lands on the enemy, needs Pet: Magic Accuracy
    --              -> Bunzi Pet-M.Acc set
    --   'Fixed' -> no potency AND no duration scaling (raises etc.); the
    --              best use of the swap window is not being squishy -> DT.
    --              NOTE (2026-07): most former 'Fixed' wards moved to
    --              'Skill' -- their DURATION scales with skill even when
    --              potency is flat (source: Pergatory's Buff_BPs_Duration).
    -- Names verified verbatim against Windower res/job_abilities.lua.
    -- Unlisted wards fall back to the target heuristic in job_get_spell_map
    -- (enemy target -> Acc, otherwise Skill) -- safe for future pacts.
    -- Misrouting cost is small (a ~1s midcast in slightly-wrong gear), so
    -- uncertain cases below default to Skill, which is never harmful.
    ---------------------------------------------------------------------------
    ward_objectives = {
        -- Carbuncle
        ['Healing Ruby']    = 'Skill',  -- cure amount scales w/ skill
        ['Healing Ruby II'] = 'Skill',
        ['Shining Ruby']    = 'Skill',  -- (regen widely believed fixed; Skill costs nothing)
        ['Glittering Ruby'] = 'Skill',  -- duration scales w/ skill (Pergatory's list)
        -- Fenrir
        ['Ecliptic Growl']  = 'Skill',
        ['Ecliptic Howl']   = 'Skill',
        ['Heavenward Howl'] = 'Skill',
        ['Lunar Cry']       = 'Acc',    -- acc/eva down
        ['Lunar Roar']      = 'Acc',    -- dispel
        -- Ifrit
        ['Crimson Howl']    = 'Skill',
        ['Inferno Howl']    = 'Skill',  -- enfire damage scales
        -- Titan
        ['Earthen Ward']    = 'Skill',  -- stoneskin amount scales -- the classic skill ward
        ['Earthen Armor']   = 'Skill',  -- potency flat, DURATION scales (Pergatory)
        -- Leviathan
        ['Spring Water']    = 'Skill',
        ['Soothing Current']= 'Skill',
        ['Slowga']          = 'Acc',
        ['Tidal Roar']      = 'Acc',    -- attack down
        -- Garuda
        ['Whispering Wind'] = 'Skill',  -- cure scales
        ['Aerial Armor']    = 'Skill',  -- shadows flat, DURATION scales (Pergatory)
        ['Hastega']         = 'Skill',  -- haste % flat, DURATION scales (Pergatory)
        ['Hastega II']      = 'Skill',  -- haste % flat, DURATION scales (Pergatory)
        ['Fleet Wind']      = 'Skill',  -- movement flat, DURATION scales (Pergatory)
        -- Shiva
        ['Frost Armor']     = 'Skill',  -- spike damage scales
        ['Crystal Blessing']= 'Skill',  -- TP-bonus TIER is skill-gated: wear the full set
        ['Sleepga']         = 'Acc',
        -- Ramuh
        ['Lightning Armor'] = 'Skill',
        ['Rolling Thunder'] = 'Skill',  -- enthunder scales
        ['Shock Squall']    = 'Acc',    -- stun
        -- Diabolos
        ['Noctoshield']     = 'Skill',  -- phalanx amount scales
        ['Dream Shroud']    = 'Skill',  -- potency time-of-day, DURATION scales (Pergatory)
        ['Somnolence']      = 'Acc',
        ['Nightmare']       = 'Acc',
        ['Ultimate Terror'] = 'Acc',
        ['Pavor Nocturnus'] = 'Acc',
        -- Alexander / Odin / Cait Sith / Siren
        ['Perfect Defense'] = 'Skill',  -- DURATION scales with skill at use -- the most
                                        -- important skill ward in the game; never misroute
        ['Raise II']        = 'Fixed',
        ['Reraise II']      = 'Fixed',
        ["Altana's Favor"]  = 'Fixed',
        ['Mewing Lullaby']  = 'Acc',    -- sleep + TP reset
        ['Eerie Eye']       = 'Acc',    -- silence/amnesia
        ["Wind's Blessing"] = 'Skill',  -- Pergatory: potency scales w/ Pet:MND (no owned
                                        -- Pet:MND set; skill holds duration meanwhile)
        ['Chinook']         = 'Fixed',
        ['Bitter Elegy']    = 'Acc',
        ['Lunatic Voice']   = 'Acc',
        ['Clarsach Call']   = 'Fixed',
    }

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
    -- Dedication = EXP/Limit boost (Empress/anniversary rings); Commitment = Capacity Pts.
    boost_buffs = S{'dedication', 'commitment'}

    -- Slots momentarily being released (so check_gear lets the normal ring return)
    releasing = {ring1=false, ring2=false}

    -- Every equippable slot GearSwap manages. Used by Win+P (PauseSwaps) and the
    -- Astral Conduit lock to freeze/unfreeze the entire gear set at once.
    all_equip_slots = {'main','sub','range','ammo','head','neck','ear1','ear2',
                       'body','hands','ring1','ring2','back','waist','legs','feet'}

    lockstyleset = 183
end

-------------------------------------------------------------------------------------------------------------------
-- User setup functions for this job.
-------------------------------------------------------------------------------------------------------------------

function user_setup()
    state.OffenseMode:options('Normal', 'Acc')          -- Acc -> physical BP acc variant
    state.CastingMode:options('Normal', 'Resistant')    -- Resistant -> magical BP acc variant
    state.IdleMode:options('Normal', 'PDT')

    state.WeaponSet = M{['description']='Weapon Set', 'Gridarvor', 'Idle', 'Malignance'}
    state.WeaponLock = M(false, 'Weapon Lock')
    state.PauseSwaps = M(false, 'Pause Gear Swapping (Fish/Craft)')

    send_command('bind @w gs c toggle WeaponLock')
    send_command('bind @e gs c cycleback WeaponSet')
    send_command('bind @r gs c cycle WeaponSet')
    send_command('bind @a gs c auditgear')            -- Win+A: check all set pieces against inventory
    send_command('bind @p gs c toggle PauseSwaps')    -- Win+P: pause/resume ALL auto gear swapping
    send_command('bind @h gs c hud')                  -- Win+H: toggle on-screen HUD
    send_command('bind ^@h gs c hudlock')             -- Ctrl+Win+H: lock/unlock HUD position

    init_hud()  -- on-screen status box (safe here: needs no gear tables)

    select_default_macro_book()
    set_lockstyle()

    -- Apply weapon lock immediately on load (job_state_change only fires on changes)
    if state.WeaponLock.value == true then
        disable('main','sub','range')
    end
end

-- Called when this job file is unloaded (eg: job change)
function user_unload()
    send_command('unbind @w')
    send_command('unbind @e')
    send_command('unbind @r')
    send_command('unbind @a')
    send_command('unbind @p')
    send_command('unbind @h')
    send_command('unbind ^@h')
    if hud then hud:hide() end
end

-------------------------------------------------------------------------------------------------------------------
-- Sets
-------------------------------------------------------------------------------------------------------------------

function init_gear_sets()

    ------------------------------------------------------------------------------------------------
    ---------------------------------------- Precast Sets ------------------------------------------
    ------------------------------------------------------------------------------------------------

    -- Fast Cast for standard magic (owned pool = 42% gear FC + Quick Magic procs).
    -- SMN has no native FC trait/gift, so the 80% cap is out of reach -- wear the
    -- whole pool. Numbers from ItemStats: Jubbah 14, Amalric 11, Volte 6, Kishar 4,
    -- Witful 3, Loquac 2, Enchntr 2 (=42); Impatiens/Lebeche/Witful add Quick Magic.
    -- legs/feet have no owned SMN FC piece: filled with DT/M.Eva so precast isn't naked.
    sets.precast.FC = {
        ammo="Impatiens",               --QM+2, spell interrupt -10
        head="Amalric Coif +1",         --FC 11 (beats Bunzi's Hat 10, Baayami Robe's slot rival below)
        body="Inyanga Jubbah +2",       --FC 14 (beats Baayami Robe 11)
        hands="Volte Gloves",           --FC 6
        legs="Bunzi's Pants",           --filler: DT-9
        feet="Inyan. Crackows +1",      --filler: MDT-2 / M.Eva 141
        neck="Null Loop",               --filler: DT-5
        ear1="Loquac. Earring",         --FC 2
        ear2="Enchntr. Earring +1",     --FC 2
        ring1="Kishar Ring",            --FC 4
        ring2="Lebeche Ring",           --QM+2
        waist="Witful Belt",            --FC 3 + QM proc
        }

    sets.precast.JA['Astral Flow'] = {
        head={ name="Glyphic Horn +1", augments={'Enhances "Astral Flow" effect',}},
        }

    -- Elemental Siphon: Esper Stone +1 (+20 Siphon) + summoning magic skill.
    sets.precast.JA['Elemental Siphon'] = {
        ammo="Esper Stone +1",          --Siphon+20, Blood Boon+3
        head="Baayami Hat",             --skill 26
        body="Baayami Robe",            --skill 32
        hands="Baayami Cuffs",          --skill 28
        legs="Baayami Slops",           --skill 30
        feet="Baayami Sabots",          --skill 24
        ring1="Evoker's Ring",          --skill 10
        ring2="Stikini Ring +1",        --all magic skills +8
        waist="Lucidity Sash",          --skill 7
        }

    -- Blood Pact precast: the recast TIMER window opens here and the timer
    -- set (sets.midcast.BloodPactRage below) carries it through the player
    -- midcast + held gap (see BP RECAST TIMING v2). Same delay core here
    -- so the swap into the timer set is minimal.
    sets.precast.BloodPactWard = {
        ammo="Sancus Sachet +1",        --BP recast II -7
        head={ name="Glyphic Horn +1", augments={'Enhances "Astral Flow" effect',}}, --BP delay -8
        body="Bunzi's Robe",            --filler: DT-10
        hands="Bunzi's Gloves",         --filler: DT-8
        legs="Baayami Slops",           --BP delay -7 (15 = gear cap)
        feet="Bunzi's Sabots",          --filler: DT-6
        neck="Null Loop",               --filler: DT-5
        ear1="Enmerkar Earring",        --filler: DT-3
        ear2="Etiolation Earring",      --filler: MDT-3
        }

    sets.precast.BloodPactRage = sets.precast.BloodPactWard

    -- Generic weaponskill set (SMN melee is a novelty; Nyame is the owned catch-all).
    sets.precast.WS = {
        ammo="Oshasha's Treatise",      --WSD 3
        head="Nyame Helm",
        body="Nyame Mail",
        hands="Nyame Gauntlets",
        legs="Nyame Flanchard",
        feet="Nyame Sollerets",
        neck="Ygnas's Resolve +1",      --WSD (see ItemStats desc)
        ear1={ name="Moonshade Earring", augments={'Accuracy+4','TP Bonus +250',}},
        ear2="Telos Earring",
        ring1="Epaminondas's Ring",     --WSD 5
        ring2="Varar Ring +1",
        back="Null Shawl",
        waist="Grunfeld Rope",
        }

    -- Myrkr (staff WS, restores MP = max-MP set). Real MP sink for SMN.
    sets.precast.WS['Myrkr'] = {
        ammo="Psilomene",               --MP+45
        head="Pixie Hairpin +1",        --MP+120
        body="Baayami Robe",            --MP+103
        hands="Bunzi's Gloves",         --MP+53
        legs="Baayami Slops",           --MP+53
        feet="Bunzi's Sabots",          --MP+35
        ear1="Etiolation Earring",      --MP+50
        ear2="Loquac. Earring",         --MP+30
        ring1="Metamor. Ring +1",       --converts 60 HP to MP
        ring2="Tamas Ring",
        back="Aurist's Cape",           --MP+40
        waist="Shinjutsu-no-Obi +1",    --MP+85
        }

    ------------------------------------------------------------------------------------------------
    ---------------------------------------- Midcast Sets ------------------------------------------
    ------------------------------------------------------------------------------------------------

    sets.midcast.FastRecast = sets.precast.FC

    -- Cure: Daybreak 30 + Bunzi's Robe 15 + Vanya Hood 10 = 55, over the +50%
    -- potency cap already. Every other slot buys healing skill / cast time /
    -- enmity / DT -- do NOT chase more potency here.
    -- (Kaykaus is WHM/RDM/BRD/SCH and Nourish. Earring is WHM/PLD: not equippable.)
    sets.midcast.Cure = {
        main="Daybreak",                --Cure+30
        sub="Sors Shield",              --Cure+3, cast -5%
        ammo="Staunch Tathlum +1",
        head={ name="Vanya Hood", augments={'Healing magic skill +19','"Cure" spellcasting time -7%','Magic dmg. taken -2',}},
        body="Bunzi's Robe",            --Cure+15, DT-10
        hands={ name="Telchine Gloves", augments={'Enh. Mag. eff. dur. +9',}}, --Cure+10 (past cap; healing-set filler)
        legs="Bunzi's Pants",           --filler: DT-9
        feet={ name="Vanya Clogs", augments={'Healing magic skill +20','"Cure" spellcasting time -7%','Magic dmg. taken -3',}},
        neck="Null Loop",
        ear1="Mendi. Earring",          --Cure+5, cast -5%
        ear2="Etiolation Earring",
        ring1="Menelaus's Ring",        --healing skill 15 (its FC-10 is harmless in midcast)
        ring2="Lebeche Ring",
        waist="Bishop's Sash",          --healing skill 5
        }

    -- Sub-job self buffs (/RDM, /SCH, /WHM): Telchine duration augments + Ammurapi.
    -- NOTE: sub swap is dead while WeaponLock is on -- expected, not a bug.
    sets.midcast['Enhancing Magic'] = {
        sub="Ammurapi Shield",          --enhancing duration +10%
        head={ name="Telchine Cap", augments={'Enh. Mag. eff. dur. +10',}},
        body={ name="Telchine Chas.", augments={'Enh. Mag. eff. dur. +9',}},
        hands={ name="Telchine Gloves", augments={'Enh. Mag. eff. dur. +9',}},
        legs={ name="Telchine Braconi", augments={'Enh. Mag. eff. dur. +8',}},
        waist="Olympus Sash",           --enhancing skill 5
        }

    -- Self-Refresh (/RDM only): +duration on refresh RECEIVED.
    sets.midcast.Refresh = set_combine(sets.midcast['Enhancing Magic'], {
        feet="Inspirited Boots",        --refresh received +15
        waist="Gishdubar Sash",         --refresh received +20
        })

    -- Player nukes (utility; SMN nuking is a sideshow -- see midcast.Pet for the real damage).
    sets.midcast['Elemental Magic'] = {
        main="Bunzi's Rod",             --MAB 35, M.Dmg 248
        sub="Ammurapi Shield",          --M.Acc/MAB 38
        ammo="Ghastly Tathlum +1",
        head="Amalric Coif +1",         --M.Acc 36
        body="Count's Garb",            --MAB 30, magic crit
        hands="Volte Gloves",           --MAB 30, M.Acc 36
        legs="Bunzi's Pants",           --M.Acc 40, MAB 30
        feet="Inspirited Boots",        --MAB 20
        neck="Sanctity Necklace",
        ear1="Friomisi Earring",        --MAB 10
        ear2="Sortiarius Earring",      --MAB 6
        ring1="Metamor. Ring +1",
        ring2="Stikini Ring +1",
        back="Aurist's Cape",
        waist="Orpheus's Sash",         --ele dmg by distance
        }

    -- Drain/Aspir (/SCH, /BLM, /DRK subs): dark skill + dark affinity.
    sets.midcast.Drain = set_combine(sets.midcast['Elemental Magic'], {
        head="Pixie Hairpin +1",        --dark MAB+28
        neck="Erra Pendant",            --dark skill 10, Drain/Aspir +5
        ring1="Evanescence Ring",       --dark skill 10, Drain/Aspir +10
        ring2="Excelsis Ring",          --Drain/Aspir potency
        })
    sets.midcast.Aspir = sets.midcast.Drain

    -- BP TIMER set (player midcast of the pact; held through the gap by
    -- job_aftercast -- BP RECAST TIMING v2). Recast core: Glyphic -8 +
    -- Slops -7 (= 15 gear cap) + Sancus recast II -7. Everything else is
    -- summoning skill so the Avatar's Favor tier doesn't sag mid-window
    -- (Pergatory's rationale; Cuffs' extra -6 delay is harmlessly over cap
    -- and its skill 28 is the point).
    sets.midcast.BloodPactRage = {
        ammo="Sancus Sachet +1",        --BP recast II -7
        head={ name="Glyphic Horn +1", augments={'Enhances "Astral Flow" effect',}}, --bp_delay -8
        body="Baayami Robe",            --skill 32
        hands="Baayami Cuffs",          --skill 28 (bp_delay -6, over cap)
        legs="Baayami Slops",           --bp_delay -7 (15 = gear cap)
        feet="Baayami Sabots",          --skill 24
        neck="Summoner's Collar",
        ear1="Evans Earring",
        ear2={ name="Beck. Earring +1", augments={'System: 1 ID: 1676 Val: 0','Pet: Accuracy+14 Pet: Rng. Acc.+14','Pet: Mag. Acc.+14','Damage taken-5%',}},
        ring1="Evoker's Ring",          --skill 10
        ring2="Stikini Ring +1",        --all magic skills +8
        back="Campestres's Cape",
        waist="Lucidity Sash",          --skill 7
        }
    sets.midcast.BloodPactWard = sets.midcast.BloodPactRage

    -- Shock Squall resolves BEFORE pet_midcast can fire (per Pergatory) --
    -- the pact lands in whatever the timer window wears. This hybrid keeps
    -- the recast core and swaps the skill filler for Pet: Magic Accuracy.
    -- Mote's midcast select matches spell.english first, so this wins.
    sets.midcast['Shock Squall'] = set_combine(sets.midcast.BloodPactRage, {
        body="Bunzi's Robe",            --Pet M.Acc+50
        hands="Bunzi's Gloves",         --Pet M.Acc+50
        feet="Bunzi's Sabots",          --Pet M.Acc+50
        neck="Adad Amulet",             --Pet M.Acc+20
        ear1="Enmerkar Earring",        --Pet M.Acc+15
        waist="Incarnation Sash",       --Pet M.Acc+15
        })

    ------------------------------------------------------------------------------------------------
    ----------------------------------- Blood Pact Midcast (pet action: DAMAGE window) -------------
    ------------------------------------------------------------------------------------------------
    -- These equip during the PET'S action -- this is where pet stats snapshot.
    -- Map names (incl. the Acc/Resistant variants) are produced by the
    -- BLOOD PACT ROUTER in job_get_spell_map below.

    -- Buff wards (skill-scaling; see ward_objectives): summoning magic
    -- skill for potency AND duration (Pergatory's Buff_BPs_Duration).
    sets.midcast.Pet.BloodPactWard = {
        ammo="Sancus Sachet +1",
        head="Baayami Hat",             --skill 26
        body="Baayami Robe",            --skill 32
        hands="Baayami Cuffs",          --skill 28
        legs="Baayami Slops",           --skill 30
        feet="Baayami Sabots",          --skill 24
        neck="Summoner's Collar",
        ear1="Evans Earring",
        ear2={ name="Beck. Earring +1", augments={'System: 1 ID: 1676 Val: 0','Pet: Accuracy+14 Pet: Rng. Acc.+14','Pet: Mag. Acc.+14','Damage taken-5%',}},
        ring1="Evoker's Ring",          --skill 10
        ring2="Stikini Ring +1",        --all magic skills +8
        back="Campestres's Cape",
        waist="Lucidity Sash",          --skill 7
        }

    -- Debuff wards on the enemy (Shock Squall, Diabolic Curse, Somnolence...):
    -- these need Pet: Magic Accuracy, not skill.
    sets.midcast.Pet.DebuffBloodPactWard = {
        ammo="Sancus Sachet +1",        --BP dmg +15 (recast handled by timer set)
        head="Bunzi's Hat",             --Pet M.Acc+50
        body="Bunzi's Robe",            --Pet M.Acc+50
        hands="Bunzi's Gloves",         --Pet M.Acc+50
        legs="Bunzi's Pants",           --Pet M.Acc+50
        feet="Bunzi's Sabots",          --Pet M.Acc+50
        neck="Adad Amulet",             --Pet M.Acc+20
        ear1="Enmerkar Earring",        --Pet M.Acc+15
        ear2={ name="Beck. Earring +1", augments={'System: 1 ID: 1676 Val: 0','Pet: Accuracy+14 Pet: Rng. Acc.+14','Pet: Mag. Acc.+14','Damage taken-5%',}},
        ring1="Evoker's Ring",
        ring2="Stikini Ring +1",
        back="Campestres's Cape",
        waist="Incarnation Sash",       --Pet M.Acc+15
        }

    -- No-scaling wards (raises etc. -- see the shrunken 'Fixed' class in
    -- ward_objectives): nothing gear-side scales and recast is the timer
    -- set's job now, so this is the full DT chassis again (both buckets
    -- capped: Bunzi 39 + Null 5 + Staunch 3 + Alabaster 5 + Murky 10 (+Gel
    -- 7 phys / +Etiolation 3 magic)).
    sets.midcast.Pet.FixedBloodPactWard = {
        ammo="Staunch Tathlum +1",      --DT-3
        head="Bunzi's Hat",             --DT-7
        body="Bunzi's Robe",            --DT-10
        hands="Bunzi's Gloves",         --DT-8
        legs="Bunzi's Pants",           --DT-9
        feet="Bunzi's Sabots",          --DT-6
        neck="Null Loop",               --DT-5
        ear1="Etiolation Earring",      --MDT-3
        ear2="Alabaster Earring",       --DT-5
        ring1="Gelatinous Ring +1",     --PDT-7
        ring2="Murky Ring",             --DT-10
        back="Null Shawl",
        waist="Null Belt",
        }

    -- Physical rages -- PURE damage window (recast already locked by the
    -- timer set; BP RECAST TIMING v2): Bunzi 4/5 Pet Acc+50, Gridarvor's
    -- Pet Atk+70, damage riders on ammo/feet/back/rings/ears.
    sets.midcast.Pet.PhysicalBloodPactRage = {
        main={ name="Gridarvor", augments={'Pet: Accuracy+70','Pet: Attack+70','Pet: "Dbl. Atk."+15',}},
        sub="Enki Strap",
        ammo="Sancus Sachet +1",        --BP recast II -7, BP dmg +15
        head="Bunzi's Hat",             --Pet Acc+50
        body="Bunzi's Robe",            --Pet Acc+50
        hands="Bunzi's Gloves",         --Pet Acc+50
        legs="Bunzi's Pants",           --Pet Acc+50
        feet="Inyan. Crackows +1",      --Avatar BP dmg +7
        neck="Shulmanu Collar",         --Pet Acc/Atk+20, Pet DA+5
        ear1="Kyrene's Earring",        --Pet Acc+15, BP dmg +1
        ear2={ name="Beck. Earring +1", augments={'System: 1 ID: 1676 Val: 0','Pet: Accuracy+14 Pet: Rng. Acc.+14','Pet: Mag. Acc.+14','Damage taken-5%',}}, --BP dmg +4
        ring1="Varar Ring +1",          --BP dmg +4, Pet Acc+10
        ring2="Varar Ring +1",
        back="Campestres's Cape",       --BP dmg +5, Avatar Lv+1
        waist="Klouskap Sash +1",       --Pet Acc+20 (beats Incarnation's 15 here)
        }

    -- OffenseMode 'Acc': trade the BP-damage feet/ear for more Pet Accuracy.
    sets.midcast.Pet.PhysicalBloodPactRageAcc = set_combine(sets.midcast.Pet.PhysicalBloodPactRage, {
        feet="Bunzi's Sabots",          --Pet Acc+50 (drops Crackows' BP dmg +7)
        ear1="Enmerkar Earring",        --Pet Acc+15 flat (drops Kyrene's BP dmg +1 -- wash, but no player DT+10%)
        })

    -- Magical rages: Grioavolr (Avatar M.Acc+51 / MAB+139 with augments, BP
    -- dmg +5) + the two hidden-stat pieces (Glyphic MAB+23, Asteria MAB+25).
    sets.midcast.Pet.MagicalBloodPactRage = {
        main={ name="Grioavolr", augments={'Blood Pact Dmg.+5','Pet: VIT+9','Pet: Mag. Acc.+16','Pet: "Mag.Atk.Bns."+24','DMG:+6',}},
        sub="Enki Strap",
        ammo="Sancus Sachet +1",        --BP dmg +15
        head={ name="Glyphic Horn +1", augments={'Enhances "Astral Flow" effect',}}, --Avatar MAB+23
        body="Bunzi's Robe",            --Pet M.Acc+50 (no owned Avatar-MAB body)
        hands="Asteria Mitts",          --Avatar MAB+25 (hidden in desc -- trust ItemStats)
        legs="Bunzi's Pants",           --Pet M.Acc+50
        feet="Inyan. Crackows +1",      --Avatar BP dmg +7
        neck="Adad Amulet",             --Pet M.Acc+20, Pet MAB+10
        ear1="Kyrene's Earring",        --Pet M.Acc+15, BP dmg +1
        ear2={ name="Beck. Earring +1", augments={'System: 1 ID: 1676 Val: 0','Pet: Accuracy+14 Pet: Rng. Acc.+14','Pet: Mag. Acc.+14','Damage taken-5%',}}, --BP dmg +4
        ring1="Varar Ring +1",          --BP dmg +4
        ring2="Varar Ring +1",
        back="Campestres's Cape",       --BP dmg +5
        waist="Incarnation Sash",       --Pet M.Acc+15 (Klouskap's acc is physical-only)
        }

    -- CastingMode 'Resistant': trade the two Avatar-MAB pieces for Pet
    -- M.Acc+50s (recast no longer constrains this set -- TIMING v2).
    sets.midcast.Pet.MagicalBloodPactRageResistant = set_combine(sets.midcast.Pet.MagicalBloodPactRage, {
        head="Bunzi's Hat",             --Pet M.Acc+50
        hands="Bunzi's Gloves",         --Pet M.Acc+50
        ear1="Enmerkar Earring",        --Pet M.Acc+15
        })

    -- Flaming Crush (hybrid: physical base + magical rider): physical chassis,
    -- magical main/neck/hands.
    sets.midcast.Pet.HybridBloodPactRage = set_combine(sets.midcast.Pet.PhysicalBloodPactRage, {
        main={ name="Grioavolr", augments={'Blood Pact Dmg.+5','Pet: VIT+9','Pet: Mag. Acc.+16','Pet: "Mag.Atk.Bns."+24','DMG:+6',}},
        hands="Asteria Mitts",          --Avatar MAB+25
        neck="Adad Amulet",             --Pet MAB+10
        })

    ------------------------------------------------------------------------------------------------
    ----------------------------------------- Idle Sets --------------------------------------------
    ------------------------------------------------------------------------------------------------

    -- Petless idle: refresh (7/tick: Daybreak 1, Befouled 1, Volte 1, Assid 1,
    -- Sabots 2, Stikini 1) + DT. main/sub come from the WeaponSet cycle.
    -- Sibyl Scarf adds Refresh+1 for Windurst citizens -- neck swap if applicable.
    sets.idle = {
        ammo="Staunch Tathlum +1",
        head="Befouled Crown",          --refresh 1
        body="Bunzi's Robe",            --DT-10
        hands="Volte Gloves",           --refresh 1
        legs="Assid. Pants +1",         --refresh 1, perp -3
        feet="Baayami Sabots",          --refresh 2
        neck="Null Loop",               --DT-5
        ear1="Eabani Earring",
        ear2="Etiolation Earring",
        ring1="Stikini Ring +1",        --refresh 1
        ring2="Gelatinous Ring +1",     --PDT-7
        back="Null Shawl",
        waist="Null Belt",
        }

    -- Emergency turtle idle (Ctrl+F12): caps DT (Bunzi 39 + Null Loop 5 +
    -- Staunch 3 + Murky 10 alone clears 50).
    sets.idle.PDT = set_combine(sets.idle, {
        head="Bunzi's Hat",             --DT-7
        hands="Bunzi's Gloves",         --DT-8
        legs="Bunzi's Pants",           --DT-9
        feet="Bunzi's Sabots",          --DT-6
        ear2="Alabaster Earring",       --DT-5
        ring2="Murky Ring",             --DT-10
        })

    -- Avatar out: perpetuation -25/tick (incl. weapon) + refresh.
    -- Baayami Robe stays for summoning skill -> Avatar's Favor tier.
    sets.idle.Avatar = set_combine(sets.idle, {
        main={ name="Gridarvor", augments={'Pet: Accuracy+70','Pet: Attack+70','Pet: "Dbl. Atk."+15',}}, --perp -5
        sub="Enki Strap",
        ammo="Sancus Sachet +1",
        head={ name="Glyphic Horn +1", augments={'Enhances "Astral Flow" effect',}}, --perp -4
        body="Baayami Robe",            --summoning skill 32 (Favor potency)
        hands="Asteria Mitts",          --refresh 1; Carbuncle: halves perpetuation
        legs="Assid. Pants +1",         --perp -3, refresh 1
        feet="Apogee Pumps",            --perp -8 (beats Sabots' refresh 2 while a pet ticks)
        ear1="Evans Earring",           --perp -2
        ear2={ name="Beck. Earring +1", augments={'System: 1 ID: 1676 Val: 0','Pet: Accuracy+14 Pet: Rng. Acc.+14','Pet: Mag. Acc.+14','Damage taken-5%',}}, --refresh 2
        ring1="Evoker's Ring",          --perp -1
        back="Campestres's Cape",
        waist="Lucidity Sash",          --perp -2
        })

    -- Overlay applied ON TOP of idle.Avatar while the pet is ENGAGED:
    -- pet haste 22/25 cap (Gridarvor 3 + Klouskap 9 + Tali'ah 7 + Rimeice 3)
    -- + pet acc/DA. Swap ear1 to Enmerkar Earring if the avatar whiffs.
    sets.PetEngaged = {
        head="Bunzi's Hat",             --Pet Acc+50
        hands="Bunzi's Gloves",         --Pet Acc+50
        feet="Tali'ah Crackows +2",     --Pet Haste+7, Pet Acc+42
        neck="Shulmanu Collar",         --Pet Acc/Atk+20, Pet DA+5
        ear1="Rimeice Earring",         --Pet Haste+3
        ring1="Varar Ring +1",
        ring2="Varar Ring +1",
        waist="Klouskap Sash +1",       --Pet Haste+9, Pet Acc+20
        }

    -- Town idle: Mote equips sets.idle.Town automatically in city zones.
    sets.idle.Town = set_combine(sets.idle, {
        ring1="Shneddick Ring",         --movement +18%
        })

    -- Kiting (Shneddick 18% beats Herald's Gaiters 12%; movement doesn't stack,
    -- highest wins. Use feet="Herald's Gaiters" instead when rings are locked.)
    sets.Kiting = {ring1="Shneddick Ring"}

    ------------------------------------------------------------------------------------------------
    ---------------------------------------- Engaged Sets ------------------------------------------
    ------------------------------------------------------------------------------------------------

    -- Player melee is a novelty on SMN; Bunzi carries acc + DT.
    sets.engaged = {
        ammo="Staunch Tathlum +1",
        head="Bunzi's Hat",
        body="Bunzi's Robe",
        hands="Bunzi's Gloves",
        legs="Bunzi's Pants",
        feet="Bunzi's Sabots",
        neck="Shulmanu Collar",         --player Acc/Atk+20, DA+3
        ear1="Telos Earring",
        ear2="Cessance Earring",
        ring1="Chirich Ring +1",
        ring2="Varar Ring +1",
        back="Null Shawl",              --Acc+50, DA+7, STP+7
        waist="Windbuffet Belt +1",
        }

    ------------------------------------------------------------------------------------------------
    ---------------------------------------- Weapon Sets -------------------------------------------
    ------------------------------------------------------------------------------------------------

    sets.Gridarvor = {main={ name="Gridarvor", augments={'Pet: Accuracy+70','Pet: Attack+70','Pet: "Dbl. Atk."+15',}}, sub="Enki Strap"}
    sets.Idle = {main="Daybreak", sub="Ammurapi Shield"}
    sets.Malignance = {main="Malignance Pole", sub="Enki Strap"}   --DT-20% panic stick

end

-------------------------------------------------------------------------------------------------------------------
-- Job-specific hooks for standard casting events.
-------------------------------------------------------------------------------------------------------------------

function job_precast(spell, action, spellMap, eventArgs)
    -- Under Astral Conduit pacts are instant: the conduit lock (job_buff_change)
    -- has already frozen the BP set in place -- skip all swapping.
    if state.Buff['Astral Conduit'] and pet_midaction() then
        eventArgs.handled = true
    end
end

function job_midcast(spell, action, spellMap, eventArgs)
    if state.Buff['Astral Conduit'] and pet_midaction() then
        eventArgs.handled = true
    end
end

-- BP RECAST WATCHER ('gs c bpwatch' toggles; default ON while we verify the
-- recast fix in-game). After each pact, reads the ACTUAL timer the game set
-- and reports it -- observed numbers beat assumed mechanics (that lesson is
-- the BP RECAST TIMING invariant). One scheduled read per pact; no polling.
bpwatch = true

function job_aftercast(spell, action, spellMap, eventArgs)
    -- HARD HOLD (BP RECAST TIMING v2): after an uninterrupted pact command,
    -- do NOT let Mote re-equip idle -- the timer set must survive the
    -- command->pet-readying gap. Mote's own guard races pet_midaction();
    -- this doesn't (mirrors Pergatory's aftercast). pet_midcast equips the
    -- damage set when the pet readies; pet_aftercast restores idle.
    if not spell.interrupted
        and (spell.type == 'BloodPactRage' or spell.type == 'BloodPactWard') then
        eventArgs.handled = true
    end

    if bpwatch and not spell.interrupted
        and (spell.type == 'BloodPactRage' or spell.type == 'BloodPactWard') then
        local id = (spell.type == 'BloodPactRage') and 173 or 174
        local label = (spell.type == 'BloodPactRage') and 'Rage' or 'Ward'
        local name = spell.english
        coroutine.schedule(function()
            local recasts = windower.ffxi.get_ability_recasts and windower.ffxi.get_ability_recasts()
            local r = recasts and recasts[id]
            if r and r > 0 then
                -- read 2s after use; the timer has already counted down 2
                add_to_chat(122, string.format('[BP] %s (%s) recast started at ~%ds', label, name, r + 2))
            end
        end, 2)
    end
end

-- Elemental Siphon rides the weather: Chatoyant Staff boosts it when the
-- current weather matches the summoned spirit's element (Pergatory's
-- SiphonWeather). Guarded on WeaponLock -- a locked main can't swap.
function job_post_precast(spell, action, spellMap, eventArgs)
    if spell.english == 'Elemental Siphon'
        and pet.isvalid and world and pet.element == world.weather_element
        and not state.WeaponLock.value then
        equip({main="Chatoyant Staff"})
    end
end

-------------------------------------------------------------------------------------------------------------------
-- BLOOD PACT ROUTER
-- Classifies each pact and folds the current mode into the map name, so the
-- Acc/Resistant variants are ordinary named sets under sets.midcast.Pet.
--   physical_bps + OffenseMode 'Acc'      -> PhysicalBloodPactRageAcc
--   magical_bps  + CastingMode 'Resistant'-> MagicalBloodPactRageResistant
--   Flaming Crush                         -> HybridBloodPactRage
-- Wards route by EFFECT OBJECTIVE (ward_objectives in job_setup):
--   'Skill' -> BloodPactWard (Baayami skill set)
--   'Acc'   -> DebuffBloodPactWard (Bunzi Pet-M.Acc set)
--   'Fixed' -> FixedBloodPactWard (DT chassis -- nothing gear-side scales)
--   unlisted ward -> target heuristic (enemy -> Acc, otherwise Skill)
-------------------------------------------------------------------------------------------------------------------

function job_get_spell_map(spell)
    if spell.type == 'BloodPactRage' then
        if spell.english == 'Flaming Crush' then
            return 'HybridBloodPactRage'
        elseif magical_bps:contains(spell.english) then
            if state.CastingMode.value == 'Resistant' then
                return 'MagicalBloodPactRageResistant'
            end
            return 'MagicalBloodPactRage'
        else
            if state.OffenseMode.value == 'Acc' then
                return 'PhysicalBloodPactRageAcc'
            end
            return 'PhysicalBloodPactRage'
        end
    elseif spell.type == 'BloodPactWard' then
        local obj = ward_objectives[spell.english]
        if obj == 'Acc' then
            return 'DebuffBloodPactWard'
        elseif obj == 'Fixed' then
            return 'FixedBloodPactWard'
        elseif obj == 'Skill' then
            return 'BloodPactWard'
        elseif spell.target.type == 'MONSTER' then
            return 'DebuffBloodPactWard'   -- unlisted enemy-target ward
        else
            return 'BloodPactWard'         -- unlisted buff ward: skill never hurts
        end
    end
end

-------------------------------------------------------------------------------------------------------------------
-- Job-specific hooks for non-casting events.
-------------------------------------------------------------------------------------------------------------------

function job_buff_change(buff, gain)
    -- ASTRAL CONDUIT LOCK: pacts are instant for the duration, so wear the
    -- magical BP set and freeze every slot. (Conduit spam is overwhelmingly
    -- magical pacts; physical spam loses little from the magical chassis.)
    if buff == "Astral Conduit" then
        if gain then
            equip(sets.midcast.Pet.MagicalBloodPactRage)
            disable(unpack(all_equip_slots))
        else
            enable(unpack(all_equip_slots))
            if state.WeaponLock.value == true then
                disable('main','sub','range')
            end
            check_gear()   -- re-lock any no-swap rings still equipped
            handle_equipping_gear(player.status)
        end
    end

    -- EXP/CP ring release: the boost buff landed, so the ring's job is done.
    if gain and boost_buffs:contains(buff:lower()) then
        local slots = {}
        if boost_gear:contains(player.equipment.left_ring)  then slots[#slots+1] = 'ring1' end
        if boost_gear:contains(player.equipment.right_ring) then slots[#slots+1] = 'ring2' end
        release_ring_slots(slots, buff..' active')
    end

    -- No update_hud() here: buff changes arrive in bursts and the 1s tick
    -- repaints soon enough (GC PRESSURE invariant).
end

-- Re-evaluate gear when the pet engages/disengages (drives the PetEngaged overlay).
function job_pet_status_change(newStatus, oldStatus)
    handle_equipping_gear(player.status)
end

-- Pet appeared or despawned: swap between idle and idle.Avatar promptly.
function job_pet_change(petparam, gain)
    handle_equipping_gear(player.status)
end

-------------------------------------------------------------------------------------------------------------------
-- User code that supplements standard library decisions.
-------------------------------------------------------------------------------------------------------------------

-- Layer avatar idle + pet-engaged overlay on the constructed idle set.
-- Layer avatar idle + pet-engaged overlay on the constructed idle set.
function customize_idle_set(idleSet)
    if pet.isvalid then
        idleSet = set_combine(idleSet, sets.idle.Avatar)
        if pet.status == 'Engaged' then
            idleSet = set_combine(idleSet, sets.PetEngaged)
        end
    end
    check_gear()
    return idleSet
end

function job_handle_equipping_gear(playerStatus, eventArgs)
    check_gear()
end

function job_update(cmdParams, eventArgs)
    handle_equipping_gear(player.status)
end

function job_state_change(stateField, newValue, oldValue)
    if state.WeaponLock.value == true then
        disable('main','sub','range')
    elseif not state.PauseSwaps.value then
        -- Don't re-enable weapon slots while PauseSwaps has everything frozen.
        enable('main','sub','range')
    end

    -- Win+P: freeze/unfreeze every gear slot at once (fishing, crafting, etc.)
    -- (Mote passes the state's description string, so match it as well as the raw name.)
    if stateField == 'PauseSwaps' or stateField == 'Pause Gear Swapping (Fish/Craft)' then
        if state.PauseSwaps.value == true then
            disable(unpack(all_equip_slots))
            add_to_chat(167, '** [GearSwap PAUSED -- all auto gear swapping OFF] **')
        else
            enable(unpack(all_equip_slots))
            if state.WeaponLock.value == true then
                disable('main','sub','range')
            end
            check_gear()
            handle_equipping_gear(player.status)
            add_to_chat(158, '** [GearSwap RESUMED -- auto gear swapping ON] **')
        end
    end

    check_weaponset()
end

function job_sub_job_change(newSubjob, oldSubjob)
    handle_equipping_gear(player.status)
end

-- Function to display the current relevant user state when doing an update (F12).
function display_current_job_state(eventArgs)
    local msg = 'BP: ' .. state.OffenseMode.value
    if state.CastingMode.value ~= 'Normal' then
        msg = msg .. '/' .. state.CastingMode.value
    end
    msg = msg .. ', Idle: ' .. state.IdleMode.value
    msg = msg .. ', Weapon: ' .. state.WeaponSet.current
    if state.WeaponLock.value then
        msg = msg .. ' (locked)'
    end
    if state.DefenseMode.value ~= 'None' then
        msg = msg .. ', Defense: ' .. state.DefenseMode.value
            .. ' (' .. state[state.DefenseMode.value .. 'DefenseMode'].value .. ')'
    end
    if state.Kiting.value then
        msg = msg .. ', Kiting'
    end
    if pet.isvalid then
        msg = msg .. ', Pet: ' .. pet.name .. ' (' .. (pet.status or 'Idle') .. ')'
    end
    if state.PauseSwaps.value then
        msg = msg .. '  ** SWAPS PAUSED **'
    end

    add_to_chat(122, msg)
    eventArgs.handled = true
end

function job_self_command(cmdParams, eventArgs)
    if cmdParams[1] == 'auditgear' then
        audit_gear()
        eventArgs.handled = true
    elseif cmdParams[1]:lower() == 'keys' then
        print_keybinds()
        eventArgs.handled = true
    elseif cmdParams[1]:lower() == 'hud' then
        toggle_hud()
        eventArgs.handled = true
    elseif cmdParams[1]:lower() == 'hudlock' then
        toggle_hud_lock()
        eventArgs.handled = true
    elseif cmdParams[1]:lower() == 'bpwatch' then
        bpwatch = not bpwatch
        add_to_chat(158, '** [BP recast watcher ' .. (bpwatch and 'ON' or 'OFF') .. '] **')
        eventArgs.handled = true
    elseif cmdParams[1]:lower() == 'perf' then
        report_perf()
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

-------------------------------------------------------------------------------------------------------------------
-- Utility functions
-------------------------------------------------------------------------------------------------------------------

function check_weaponset()
    equip(sets[state.WeaponSet.current])
end

-- Keybind refresher. All binds are Win+<key>. Printed once on load (below)
-- and available on demand via 'gs c keys'.
function print_keybinds()
    add_to_chat(158, '=== SMN keybinds (Win+key) ===')
    add_to_chat(158, ' W WeaponLock | E/R WeaponSet -/+ | A AuditGear | P PauseSwaps')
    add_to_chat(158, ' H HUD | ^H HUD-lock | gs c perf (perf counters) | gs c bpwatch (recast check)')
    add_to_chat(158, ' F9 BP Offense (Acc) | ^F11 BP Casting (Resistant) | ^F12 Idle | F12 Status')
end

-- Print the keybind refresher shortly after load (after user_setup has bound
-- the keys and the GearSwap load spam has settled).
coroutine.schedule(function()
    print_keybinds()
end, 4)

-------------------------------------------------------------------------------------------------------------------
-- NO-SWAP RING ENGINE (ported from RDM.lua)
-------------------------------------------------------------------------------------------------------------------

-- Lock a ring slot (disable) whenever it holds a no_swap ring, unless we're in the
-- middle of releasing it. Enable it otherwise so normal gear flows back in.
-- Bails out entirely during PauseSwaps or Doom so it can't undo those locks.
function check_gear()
    if state.PauseSwaps.value or buffactive.doom then return end
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

-- Release the given ring slots: enable them, recompute gear so the normal ring
-- returns, then clear the release flag once the swap has settled.
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

-- On zone change you've arrived: drop WARP/dimension rings so normal rings return.
-- Boost rings (EXP/CP) are intentionally kept across zones until their buff lands.
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

function select_default_macro_book()
    set_macro_page(1, 19)
end

function set_lockstyle()
    send_command('wait 2; input /lockstyleset ' .. lockstyleset)
end


-------------------------------------------------------------------------------------------------------------------
-- On-screen SMN HUD
--
-- Toggle visibility: Win+H or 'gs c hud'. The box loads LOCKED in place;
-- Ctrl+Win+H (or 'gs c hudlock') unlocks it so you can drag to reposition,
-- then locks it again. Position is NOT persisted across reloads -- once you
-- like where it sits, copy the coords into hud_settings.pos below.
--
-- DATA SOURCES (each chosen because it's authoritative, not guessed):
--   * Recasts: windower.ffxi.get_ability_recasts() -- returns SECONDS.
--     IDs from Windower res/job_abilities.lua: Rage 173, Ward 174,
--     Siphon 175, Apogee 108.
--   * Pet TP / MP%%: GearSwap's pet object has neither. Incoming packet
--     0x068 (Pet Status) carries Current HP%% / Current MP%% / Pet TP and is
--     sent on EVERY pet vitals change; parsed with Windower's packets
--     library so the fields are read by NAME (no byte-offset rot). 0x067
--     (Pet Info, message type 4) carries the same vitals on zone/summon
--     and is handled too. Fields read '--' until the first packet lands;
--     pet HP falls back to GearSwap mob data (pet.hpp) meanwhile.
--   * Repaint: prerender event throttled to ~0.3s (recasts tick), and the
--     composed string is cached so texts:text() is only touched on change.
-------------------------------------------------------------------------------------------------------------------

hud_settings = {
    pos = {x = 675, y = 985},   -- bottom-center @1920x1080; Ctrl+Win+H to re-drag
    text = {size = 10, font = 'Consolas'},
    bg = {alpha = 120},
    flags = {draggable = false},   -- loads LOCKED; Ctrl+Win+H unlocks to reposition
}
hud = nil
hud_visible = true
hud_last_text = nil

-- Ability recast IDs -- ground truth from Windower res/job_abilities.lua.
hud_recast_ids = {
    {label = 'Rage',   id = 173},
    {label = 'Ward',   id = 174},
    {label = 'Siphon', id = 175},
    {label = 'Apogee', id = 108},
}

function init_hud()
    local ok, texts_lib = pcall(require, 'texts')
    if not ok or not texts_lib then
        add_to_chat(167, '[HUD] texts library unavailable; HUD disabled')
        return
    end
    hud = texts_lib.new('', hud_settings)
    update_hud()
    if hud_visible then hud:show() end
end

-- Inline color tags for the texts library: '\\cs(r,g,b)' opens, '\\cr' resets.
hud_colors = {
    label  = '\\cs(135,135,150)',  -- field names
    value  = '\\cs(240,240,240)',  -- neutral values
    good   = '\\cs(120,255,120)',  -- ready timers, healthy pet, toggles on
    warn   = '\\cs(255,210,80)',   -- mid HP / conduit flag
    bad    = '\\cs(255,110,110)',  -- low HP/MP, ** PAUSED **
    dim    = '\\cs(110,110,110)',  -- absent pet, unknown values
    accent = '\\cs(120,200,255)',  -- pet TP, [Favor]
}
local function col(name, s) return (hud_colors[name] or '') .. s .. '\\cr' end

-- Green at 0, m:ss over a minute, plain seconds otherwise.
local function fmt_recast(s)
    if not s or s <= 0 then return col('good', 'rdy') end
    s = math.floor(s + 0.5)   -- get_ability_recasts returns whole seconds, but be safe
    if s >= 60 then return col('value', string.format('%d:%02d', math.floor(s / 60), s % 60)) end
    return col('value', s .. 's')
end

local function pct_col(p, warn_at, bad_at)
    if not p then return 'dim' end
    if p <= bad_at then return 'bad' end
    if p <= warn_at then return 'warn' end
    return 'good'
end

function update_hud()
    if not hud then return end

    -- L1: pet vitals + status flags
    local l1
    if pet and pet.isvalid then
        local hpp = pet.hpp                            -- mob data (no packet capture)
        l1 = col('label', 'Pet ') .. col('value', pet.name or '?')
          .. col('label', ' [') .. col(pet.status == 'Engaged' and 'warn' or 'value', pet.status or 'Idle') .. col('label', ']')
          .. col('label', '  HP ') .. col(pct_col(hpp, 50, 25), hpp and (hpp .. '%') or '--')
    else
        l1 = col('label', 'Pet ') .. col('dim', '--')
    end
    if buffactive and buffactive["Avatar's Favor"] then
        l1 = l1 .. ' ' .. col('accent', '[Favor]')
    end
    if buffactive and buffactive['Astral Conduit'] then
        l1 = l1 .. ' ' .. col('warn', '<CONDUIT>')
    end

    -- L2: ability recast timers (get_ability_recasts returns SECONDS)
    local recasts = (windower.ffxi and windower.ffxi.get_ability_recasts and windower.ffxi.get_ability_recasts()) or {}
    local parts = {}
    for _, e in ipairs(hud_recast_ids) do
        parts[#parts + 1] = col('label', e.label .. ' ') .. fmt_recast(recasts[e.id])
    end
    local l2 = table.concat(parts, col('label', ' | '))

    -- L3: modes (mirrors the F12 status line)
    local l3 = ''
    if state then
        local wname = state.WeaponSet and (state.WeaponSet.current or state.WeaponSet.value) or '-'
        local dval = state.DefenseMode and state.DefenseMode.value or 'None'
        l3 = col('label', 'BP:') .. col('value', (state.OffenseMode and state.OffenseMode.value or '-')
                .. '/' .. (state.CastingMode and state.CastingMode.value or '-'))
          .. col('label', '  Idle:') .. col('value', state.IdleMode and state.IdleMode.value or '-')
          .. col('label', '  Def:') .. col(dval ~= 'None' and 'warn' or 'dim', dval)
          .. col('label', '  Wpn:') .. col('value', wname)
          .. ((state.WeaponLock and state.WeaponLock.value) and col('dim', '(L)') or '')
    end

    -- L4: player MP + pause flag
    local l4 = ''
    if player and player.max_mp then
        local mpp = player.mpp or 0
        l4 = col('label', 'MP ') .. col(pct_col(mpp, 50, 25), (player.mp or 0) .. ' (' .. mpp .. '%)')
    end
    if state and state.PauseSwaps and state.PauseSwaps.value then
        l4 = l4 .. col('bad', '  ** PAUSED **')
    end

    local text = l1 .. '\n' .. l2 .. '\n' .. l3 .. '\n' .. l4
    if text ~= hud_last_text then       -- only touch the texts object on change
        hud_last_text = text
        hud:text(text)
    end
end

function toggle_hud()
    if not hud then return end
    hud_visible = not hud_visible
    if hud_visible then hud:show() else hud:hide() end
end

-- Lock/unlock the HUD's position. Loads LOCKED (see hud_settings); this
-- unlocks it to move, then re-locks. Not persisted across reloads.
-- Lock state is tracked HERE, not read back from the texts lib -- its
-- draggable() is a setter and can't be trusted as a getter.
hud_unlocked = false
function toggle_hud_lock()
    if not hud then return end
    hud_unlocked = not hud_unlocked
    hud:draggable(hud_unlocked)
    if hud_unlocked then
        add_to_chat(158, '** [HUD UNLOCKED -- drag to reposition] **')
    else
        add_to_chat(158, '** [HUD LOCKED -- position fixed] **')
    end
end

-- PERFORMANCE INVARIANTS (multiple stutter regressions taught us these):
--   * NO 'incoming chunk' handler ANYWHERE in this file: GearSwap copies
--     EVERY packet's payload into a Lua string just to dispatch it, even
--     when the handler rejects on line one. Pet TP was the only feature
--     that needed packets and it was removed for exactly this reason.
--   * NO 'prerender' handler either: per-frame dispatch through GearSwap's
--     event layer is a stutter source. All periodic work runs on the
--     single smn_tick scheduler (1s) below.
--   * GC PRESSURE is the quieter stutter: the HUD string rebuilds at most
--     1/s and hud:text() fires only on change. Don't add allocations to
--     hot paths (per-aftercast hooks, the tick, event handlers).


-------------------------------------------------------------------------------------------------------------------
-- smn_tick: THE single periodic driver (1s coroutine.schedule chain).
-- Replaces any per-frame or per-packet polling -- see PERFORMANCE
-- INVARIANTS above. One job: repaint the HUD (string cache makes
-- no-change ticks nearly free). 'gs c perf' reads the counters.
-------------------------------------------------------------------------------------------------------------------
smn_tick_interval = 1.0   -- recasts tick once/sec; nothing gains from faster
smn_tick_count = 0
perf = {ticks = 0, total = 0, max = 0}   -- 'gs c perf' to read

function smn_tick()
    local t0 = os.clock()
    smn_tick_count = smn_tick_count + 1

    if hud and hud_visible then update_hud() end

    -- perf accounting (os.clock granularity is coarse ~10ms: 'max' catches
    -- spikes, 'total' catches trends; both should stay near zero)
    local dt = os.clock() - t0
    perf.ticks = perf.ticks + 1
    perf.total = perf.total + dt
    if dt > perf.max then perf.max = dt end
    coroutine.schedule(smn_tick, smn_tick_interval)
end

function report_perf()
    add_to_chat(122, string.format(
        '[Perf] ticks %d | tick total %.3fs, max %.3fs',
        perf.ticks, perf.total, perf.max))
end

coroutine.schedule(smn_tick, 3)   -- start after load settles; chain self-sustains

-------------------------------------------------------------------------------------------------------------------
-- Gear Audit (Win+A)
-- Walks every set and gear table, checks each named piece against all inventory bags.
-- For every missing item, reports which set(s) and slot(s) reference it so you know
-- exactly where to make substitutions in the lua.
--
-- Performance notes:
--   - visited-table guard prevents re-walking shared set_combine sub-tables
--   - O(1) dedup via lookup table avoids the slow linear scan per item
--   - output is drained asynchronously (one line per 0.05s) so the client never freezes
-------------------------------------------------------------------------------------------------------------------

-- Queue used by the async drain — file-local so it persists between commands
-- (declared as a plain global, not `local`, since job_self_command's
-- '_auditdrain' handler above references it earlier in the file than any
-- `local` declaration here would come into scope)
audit_queue = nil

-- Recursively walk a gear table, tracking path (e.g. "sets.midcast.Cure").
-- Builds: found[itemName] = { locs={"sets.midcast.Cure [body]",...}, seen={loc=true,...} }
-- visited guards against re-walking the same table reference twice (set_combine shares tables).
-- Two shapes recognised as item references:
--   Bare slot:      head="Malignance Chapeau"
--   Augmented ref:  head={ name="Bunzi's Hat", augments={...} }
-- augments arrays are never recursed — their contents are stat strings, not item names.
local function collect_gear_names(tbl, found, set_path, visited)
    if type(tbl) ~= 'table' then return found end
    found   = found   or {}
    visited = visited or {}

    -- Skip any table we have already fully walked
    if visited[tbl] then return found end
    visited[tbl] = true

    for k, v in pairs(tbl) do
        if k == 'augments' then
            -- never recurse into augments — stat strings, not item names

        elseif k == 'name' and type(v) == 'string' then
            -- augmented ref: { name="X", augments={...} }
            -- set_path is already the slot path e.g. "sets.precast.FC.head"
            if not found[v] then found[v] = {locs={}, seen={}} end
            if not found[v].seen[set_path] then
                found[v].seen[set_path] = true
                table.insert(found[v].locs, set_path)
            end

        elseif type(k) == 'string' and type(v) == 'string' then
            -- bare slot: head="Item Name"
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

-- Check all GearSwap-accessible containers for an item by base name.
local function item_in_inventory(name)
    local bags = {
        player.inventory,
        player.wardrobe,  player.wardrobe2, player.wardrobe3,
        player.wardrobe4, player.wardrobe5, player.wardrobe6, player.wardrobe7, player.wardrobe8,
        player.safe,      player.safe2,
        player.storage,   player.satchel,
        player.sack,      player.case,
        player.locker,    -- Mog Locker: without this, locker-stored gear audits as "missing"
    }
    for _, bag in ipairs(bags) do
        if bag and bag[name] then return true end
    end
    return false
end

-- Non-item strings that legitimately appear as slot values
local audit_skip = S{
    'empty', '', 'Path: A', 'Path: B', 'Path: C', 'Path: D',
    'wardrobe', 'wardrobe2', 'wardrobe3', 'wardrobe4', 'wardrobe5', 'wardrobe6', 'wardrobe7', 'wardrobe8',
}

-- Filter out augment stat strings that may survive as bare values
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
    -- ── Collection phase (synchronous, optimised) ────────────────────────────
    add_to_chat(158, '=== Gear Audit Starting ===')

    local all_names = {}
    local visited   = {}   -- shared across both calls so tables are only walked once
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

    -- ── Build output queue (no chat calls yet) ───────────────────────────────
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

    -- ── Drain asynchronously — 50 ms between lines so the client never freezes
    windower.send_command('gs c _auditdrain')
end
