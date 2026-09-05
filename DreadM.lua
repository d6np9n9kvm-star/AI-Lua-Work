-- Original: Motenten / Modified: Arislan
--
--  Haste/DW tiers: load the Gearinfo addon (//lua load gearinfo, or add it to
--  Windower auto-load). It reports magic haste + DW-needed to this file
--  automatically ('gs c gearinfo ...') and the DW haste-tier sets engage with
--  no further input. Without Gearinfo: dual wield is inferred from the subjob
--  (NIN/DNC) and the base max-DW set is used -- functional, just not optimal.

-------------------------------------------------------------------------------------------------------------------
--  Keybinds
-------------------------------------------------------------------------------------------------------------------

--  Keybind philosophy: mode changes only. No spell/ability binds -- use in-game
--  macros for casting. All binds live on F9-F12 (Mote defaults) or Win+letter.
--
--  Modes:      [ F9 ]              Cycle Offense Mode
--              [ CTRL+F9 ]         Cycle Hybrid Modes
--              [ WIN+F9 ]          Cycle Weapon Skill Modes
--              [ F10 ]             Emergency -PDT Mode
--              [ ALT+F10 ]         Toggle Kiting Mode
--              [ F11 ]             Emergency -MDT Mode
--              [ CTRL+F11 ]        Cycle Casting Modes
--              [ F12 ]             Update Current Gear / Report Current Status
--              [ CTRL+F12 ]        Cycle Idle Modes
--              [ ALT+F12 ]         Cancel Emergency -PDT/-MDT Mode
--
--  Win+letter: [ WIN+B ]           Toggle Magic Burst Mode (manual force-on)
--              [ WIN+S ]           Cycle Sleep Mode
--              [ WIN+M ]           Cycle Enspell Melee Mode (Auto/On/Off)
--              [ WIN+D ]           Toggle NM Mode
--              [ WIN+W ]           Toggle Weapon Lock
--              [ WIN+C ]           Toggle AutoSC (reactive skillchain closer)
--              [ WIN+E ]           Cycle Weapon Set (back)
--              [ WIN+R ]           Cycle Weapon Set (forward)
--              [ WIN+T ]           Cycle Treasure Hunter Mode
--              [ WIN+A ]           Audit Gear (check sets vs. inventory)
--              [ WIN+F ]           Cycle assumed Caster's Roll FC value
--                                  (adaptive Fast Cast -- see fc_core in
--                                  init_gear_sets; 'gs c fcinfo' prints math)
--              [ WIN+H ]           Toggle on-screen HUD ('gs c hud')
--              [ WIN+P ]           Pause/Resume ALL auto gear swapping
--                                  (freezes every slot -- use for fishing, crafting,
--                                  synthing, etc. Toggle again to resume normal swaps.)
--
--  Unbound (typed/macro commands):
--      gs c toggle RangedLock      Ammo-slot protection during ranged attacks (default on)
--
--  Scholar stratagems (subjob SCH) via typed/macro commands:
--      gs c scholar light|dark|speed|cost|aoe|addendum
--
--  Auto Magic Burst: skillchain windows are detected automatically (any source:
--  you, Silmaril, Trusts, party). Matching nukes get burst gear with no input.
--  Disable/enable detection: gs c toggle AutoBurst


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
function get_sets()
    mote_include_version = 2

    -- Load and initialize the include file.
    include('Mote-Include.lua')
end


-- Setup vars that are user-independent.  state.Buff vars initialized here will automatically be tracked.
function job_setup()

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

    -- Every equippable slot GearSwap manages. Used by Win+P (PauseSwaps) to
    -- freeze/unfreeze the entire gear set at once (fishing, crafting, etc.).
    all_equip_slots = {'main','sub','range','ammo','head','neck','ear1','ear2',
                        'body','hands','ring1','ring2','back','waist','legs','feet'}

    -- Buffs that mean a boost ring's effect is now active (so the ring can come off).
    -- Dedication = EXP/Limit boost (Empress/anniversary rings); Commitment = Capacity Pts.
    boost_buffs = S{'dedication', 'commitment'}

    -- Slots momentarily being released (so check_gear lets the normal ring return)
    releasing = {ring1=false, ring2=false}

    enfeebling_magic_acc = S{'Bind', 'Break', 'Dispel', 'Distract', 'Distract II', 'Frazzle',
        'Frazzle II',  'Gravity', 'Gravity II', 'Silence'}
    enfeebling_magic_skill = S{'Distract III', 'Frazzle III', 'Poison II'}
    enfeebling_magic_effect = S{'Dia', 'Dia II', 'Dia III', 'Diaga', 'Blind', 'Blind II'}
    enfeebling_magic_sleep = S{'Sleep', 'Sleep II', 'Sleepga'}

    -- Enfeebles where DURATION is the goal -> eligible for the Lethargy/Composure
    -- duration overlay when cast on an enemy with Composure active. Acc-fishing
    -- debuffs and Sleep are deliberately excluded (landing/own-path matters more).
    lethargy_duration_enfeebles = S{
        'Dia', 'Dia II', 'Dia III', 'Diaga', 'Blind', 'Blind II',
        'Distract III', 'Frazzle III', 'Poison II',
        'Slow', 'Slow II', 'Paralyze', 'Paralyze II', 'Addle', 'Addle II'}

    skill_spells = S{
        'Temper', 'Temper II', 'Enfire', 'Enfire II', 'Enblizzard', 'Enblizzard II', 'Enaero', 'Enaero II',
        'Enstone', 'Enstone II', 'Enthunder', 'Enthunder II', 'Enwater', 'Enwater II'}

    include('Mote-TreasureHunter')

    -- For th_action_check():
    -- JA IDs for actions that always have TH: Provoke, Animated Flourish
    info.default_ja_ids = S{35, 204}
    -- Unblinkable JA IDs for actions that always have TH: Quick/Box/Stutter Step, Desperate/Violent Flourish
    info.default_u_ja_ids = S{201, 202, 203, 205, 207}

    lockstyleset = 24
end


-------------------------------------------------------------------------------------------------------------------
-- User setup functions for this job.  Recommend that these be overridden in a sidecar file.
-------------------------------------------------------------------------------------------------------------------

-- Setup vars that are user-dependent.  Can override this function in a sidecar file.
function user_setup()
    state.OffenseMode:options('Normal', 'MidAcc', 'HighAcc')
    state.HybridMode:options('Normal', 'DT')
    state.WeaponskillMode:options('Normal', 'Acc')
    state.CastingMode:options('Normal', 'Seidr', 'Resistant')
    state.IdleMode:options('Normal', 'DT')

    state.EnSpell = M{['description']='EnSpell', 'Enfire', 'Enblizzard', 'Enaero', 'Enstone', 'Enthunder', 'Enwater'}
    state.BarElement = M{['description']='BarElement', 'Barfire', 'Barblizzard', 'Baraero', 'Barstone', 'Barthunder', 'Barwater'}
    state.BarStatus = M{['description']='BarStatus', 'Baramnesia', 'Barvirus', 'Barparalyze', 'Barsilence', 'Barpetrify', 'Barpoison', 'Barblind', 'Barsleep'}
    state.GainSpell = M{['description']='GainSpell', 'Auto', 'Gain-STR', 'Gain-INT', 'Gain-AGI', 'Gain-VIT', 'Gain-DEX', 'Gain-MND', 'Gain-CHR'}

    state.WeaponSet = M{['description']='Weapon Set', 'CroceaMors', 'Naegling', 'Tauret', 'Idle'}
    state.WeaponLock = M(true, 'Weapon Lock')
    state.MagicBurst = M(false, 'Magic Burst')
    state.RangedLock = M(true, 'Ranged Lock')
    state.AutoBurst = M(true, 'Auto Burst Detect')
    state.AutoSC = M(true, 'Auto Skillchain')   -- react to party WS to CLOSE skillchains (ported from NIN)
    state.SleepMode = M{['description']='Sleep Mode', 'Normal', 'MaxDuration'}
    state.EnspellMode = M{['description']='Enspell Melee Mode', 'Auto', 'On', 'Off'}
    state.NM = M(false, 'NM?')
    state.PauseSwaps = M(false, 'Pause Gear Swapping (Fish/Craft)')
    -- state.CP = M(false, "Capacity Points Mode")

    -- Assumed FC% of an active Caster's Roll (value isn't readable from the
    -- buff icon). Cycle with Win+F to match the roll number called in chat.
    -- Default 10 is deliberately low = safe (see update_fc_tier).
    state.CasterRollFC = M{['description']='Caster Roll FC Assumption', '10', '15', '20', '25', '30', '5'}

    -- Mode-change binds only (Win+letter). F9-F12 mode binds come from Mote-Include.
    -- Spell/ability shortcuts intentionally omitted -- use in-game macros for those.
    -- Scholar stratagem commands remain available as typed/macro commands:
    --   gs c scholar light|dark|speed|cost|aoe|addendum

    send_command('bind @t gs c cycle treasuremode')
    send_command('bind @b gs c toggle MagicBurst')
    send_command('bind @s gs c cycle SleepMode')
    send_command('bind @m gs c cycle EnspellMode')
    send_command('bind @d gs c toggle NM')
    send_command('bind @w gs c toggle WeaponLock')
    send_command('bind @c gs c toggle AutoSC')       -- Win+C: reactive skillchain closer
    send_command('bind @e gs c cycleback WeaponSet')
    send_command('bind @r gs c cycle WeaponSet')
    send_command('bind @a gs c auditgear')           -- Win+A: check all set pieces against inventory
    send_command('bind @p gs c toggle PauseSwaps')    -- Win+P: pause/resume ALL auto gear swapping
    send_command('bind @f gs c cycle CasterRollFC')   -- Win+F: assumed Caster's Roll FC value
    send_command('bind @h gs c hud')                  -- Win+H: toggle on-screen HUD

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
    moving = false
    update_combat_form()
    determine_haste_group()

    -- NOTE: the initial update_fc_tier() lives at the END of init_gear_sets,
    -- not here -- Mote's init order is job_setup -> user_setup ->
    -- init_gear_sets, so fc_core/fc_ladder don't exist yet at this point.
end

-- Called when this job file is unloaded (eg: job change)
function user_unload()
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
    if hud then hud:hide() end
end

-- Define sets and vars used by this job file.
function init_gear_sets()

    ------------------------------------------------------------------------------------------------
    ---------------------------------------- Precast Sets ------------------------------------------
    ------------------------------------------------------------------------------------------------

    -- Precast sets to enhance JAs
    sets.precast.JA['Chainspell'] = {body="Viti. Tabard +1"}

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
    -- Full pool below = 60 gear FC; a mastered RDM only needs 42, so up to
    -- three-to-four slots come back as utility. Everything is rebuilt by
    -- build_fc_sets() whenever the target changes (login, Caster's Roll
    -- gain/loss, Win+F assumption change). 'gs c fcinfo' prints the current
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
    fc_core_value = 14 + 3              -- head + waist = 17
    fc_head_value = 14                  -- what the Enfeebling head swap gives up

    -- Shed ladder: dropped top-to-bottom (smallest FC first) while the set
    -- stays at/above the gear target. Fillers are owned DT/M.Eva pieces.
    -- body/back only ever come off under a strong Caster's Roll.
    fc_ladder = {
        {slot='ear2',  fc=1,  piece="Etiolation Earring", filler="Alabaster Earring"}, --DT/HP
        {slot='ear1',  fc=2,  piece="Loquac. Earring",    filler="Eabani Earring"},    --M.Eva
        {slot='ring1', fc=4,  piece="Kishar Ring",        filler="Murky Ring"},        --DT-10
        {slot='legs',  fc=6,  piece="Aya. Cosciales +2",  filler="Nyame Flanchard"},   --DT/M.Eva
        {slot='hands', fc=7,  piece="Gende. Gages +1",    filler="Nyame Gauntlets"},   --DT/M.Eva
        {slot='back',  fc=10, piece={ name="Sucellos's Cape", augments={'MND+20','Mag. Acc+20 /Mag. Dmg.+20','MND+10','"Fast Cast"+10','Damage taken-5%',}}, --FC 10 / DT-5
                              filler="Null Shawl"},                                    --M.Eva
        {slot='body',  fc=13, piece="Viti. Tabard +1",    filler="Nyame Mail"},        --DT/M.Eva (Inyanga Jubbah +2 is WHM/BRD/SMN-only)
        }
    fc_ladder_value = 1 + 2 + 4 + 6 + 7 + 10 + 13 -- = 43 (full pool = 60)

    -- Shed ORDER is separate from the ladder so DefenseMode can re-prioritize:
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
        back={ name="Sucellos's Cape", augments={'STR+20','Accuracy+20 Attack+20','STR+10','Weapon skill damage +10%','Damage taken-5%',}},
        waist="Sailfi Belt +1",
        }

    sets.precast.WS.Acc = set_combine(sets.precast.WS, {
        ear2="Mache Earring +1",
        })

    sets.precast.WS['Chant du Cygne'] = set_combine(sets.precast.WS, {
        ammo="Yetshila +1", --Crit
        head="Malignance Chapeau", --DEX 40 / Acc 50 (Mummu is not RDM; no owned RDM crit head)
        body="Malignance Tabard",
        hands="Malignance Gloves",
        legs="Malignance Tights",
        feet="Malignance Boots",
        ear1="Mache Earring +1", --DEX/Acc (Odr is not RDM; no owned RDM crit ear)
        ring1="Chirich Ring +1", --Acc (Mummu Ring is not RDM)
        ring2="Sroda Ring",
        back={ name="Sucellos's Cape", augments={'DEX+20','Accuracy+20 Attack+20','"Dual Wield"+10','Damage taken-5%',}},
        })

    sets.precast.WS['Chant du Cygne'].Acc = set_combine(sets.precast.WS['Chant du Cygne'], {
        ear2="Mache Earring +1",
        })

    sets.precast.WS['Vorpal Blade'] = sets.precast.WS['Chant du Cygne']
    sets.precast.WS['Vorpal Blade'].Acc = sets.precast.WS['Chant du Cygne'].Acc

    sets.precast.WS['Savage Blade'] = set_combine(sets.precast.WS, {
        neck="Anu Torque", 
        waist="Sailfi Belt +1",
        })

    sets.precast.WS['Savage Blade'].Acc = set_combine(sets.precast.WS['Savage Blade'], {
        ear2="Mache Earring +1",
        })

    sets.precast.WS['Death Blossom'] = sets.precast.WS['Savage Blade']
    sets.precast.WS['Death Blossom'].Acc = sets.precast.WS['Savage Blade'].Acc

    sets.precast.WS['Requiescat'] = set_combine(sets.precast.WS, {
        ring2="Stikini Ring +1", --MND
        })

    sets.precast.WS['Requiescat'].Acc = set_combine(sets.precast.WS['Requiescat'], {
        ear1="Mache Earring +1",
        })

    sets.precast.WS['Sanguine Blade'] = {
        ammo="Ghastly Tathlum +1",
        head="Pixie Hairpin +1", --Dark dmg+
        body="Lethargy Sayon +2", --MAB 49 / M.Dmg 24 (Jhakri Robe +2 is MAB 43, no M.Dmg)
        hands="Jhakri Cuffs +2",
        legs="Nyame Flanchard",
        feet="Jhakri Pigaches +2",
        neck="Sibyl Scarf",
        ear1="Friomisi Earring",
        ear2="Sortiarius Earring",
        ring1="Metamor. Ring +1",
        ring2="Jhakri Ring",
        back={ name="Sucellos's Cape", augments={'INT+20','Mag. Acc+20 /Mag. Dmg.+20','"Mag.Atk.Bns."+10',}},
        waist="Orpheus's Sash",
        }

    sets.precast.WS['Seraph Blade'] = set_combine(sets.precast.WS['Sanguine Blade'], {
        head="Jhakri Coronal +2",
        ear2="Moonshade Earring",
        })

    sets.precast.WS['Aeolian Edge'] = set_combine(sets.precast.WS['Seraph Blade'], {
        head="Jhakri Coronal +2",
        waist="Orpheus's Sash",
        })

    sets.precast.WS['Black Halo'] = set_combine(sets.precast.WS['Savage Blade'], {
        ear2="Telos Earring",
        ring2="Metamor. Ring +1", --MND
        })

    sets.precast.WS['Black Halo'].Acc = set_combine(sets.precast.WS['Black Halo'], {
        ear2="Mache Earring +1",
        })


    ------------------------------------------------------------------------------------------------
    ---------------------------------------- Midcast Sets ------------------------------------------
    ------------------------------------------------------------------------------------------------

    sets.midcast.FastRecast = sets.precast.FC -- (re-pointed by build_fc_sets on every rebuild)

    sets.midcast.SpellInterrupt = {
        ammo="Staunch Tathlum +1", --SIRD 11
        legs="Bunzi's Pants", --SIRD 20 + DT-9/MEva 150 (Carmine has the same SIRD but no DT)
        ear1="Magnetic Earring", --SIRD 8
        ring1="Murky Ring", --SIRD 3 + DT-10
        ring2="Evanescence Ring", --SIRD 5
        }

    sets.midcast.Utsusemi = sets.midcast.SpellInterrupt

    sets.midcast.Cure = {
        main="Daybreak", --Cure pot. 30
        sub="Ammurapi Shield",
        ammo="Esper Stone +1", --Enmity-5
        head="Kaykaus Mitra +1", --11(+2)/(-6)
        body="Bunzi's Robe", --Cure pot. 15 + DT-10: caps Cure I (~50%) even without Daybreak
                             --in hand under WeaponLock. (Trades Kaykaus Bliaut's Cure II+4/Refresh+3.)
        hands="Kaykaus Cuffs +1", --11(+2)/(-6)
        legs="Kaykaus Tights +1", --11(+2)/(-6)
        feet="Kaykaus Boots +1", --11(+2)/(-12)
        -- neck/ear2: no RDM-equippable cure-potency pieces owned (Cleric's Torque
        -- and Nourish. Earring are WHM gear); slots inherit from precast.
        ear1="Mendi. Earring", --Cure pot. 5
        ring1="Stikini Ring +1",
        ring2="Menelaus's Ring",
        back={ name="Sucellos's Cape", augments={'MND+20','Mag. Acc+20 /Mag. Dmg.+20','MND+10','"Fast Cast"+10','Damage taken-5%',}},
        waist="Salire Belt",
        }

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

    -- Trimmed to RDM-equippable gear: Theo. Bliaut/Pantaloons and Cleric's Torque
    -- are WHM-only. Unlisted slots keep FC pieces from precast, which is fine --
    -- status removals have no potency scaling to chase.
    sets.midcast.StatusRemoval = {
        head="Vanya Hood",
        feet="Vanya Clogs",
        ring1="Stikini Ring +1",
        ring2="Menelaus's Ring",
        waist="Bishop's Sash",
        }

    -- Cursna+ comes from Menelaus's Ring (+20) and Vanya Clogs (+5) in StatusRemoval.
    -- (Theophany Mitts are WHM-only; no RDM-equippable Cursna hands owned.)
    sets.midcast.Cursna = set_combine(sets.midcast.StatusRemoval, {})

    sets.midcast['Enhancing Magic'] = {
        sub="Ammurapi Shield",
        head="Befouled Crown", --Enh. skill 16
        body="Viti. Tabard +1", --Enh. skill 19
        hands="Viti. Gloves +1", --Enh. skill 20 (Atrophy Gloves +3 is DURATION, not skill)
        legs="Atrophy Tights +2", --Enh. skill 19
        feet="Leth. Houseaux +1", --Enh. skill 25 (slot was previously unfilled)
        neck="Dls. Torque +2",
        ring1="Stikini Ring +1",
        ring2="Stikini Ring +1",
        back={ name="Sucellos's Cape", augments={'MND+20','Mag. Acc+20 /Mag. Dmg.+20','MND+10','"Fast Cast"+10','Damage taken-5%',}}, --base: Enh. dur +20% on every copy
        waist="Olympus Sash", --Enh. skill
        }

    sets.midcast.EnhancingDuration = {
        sub="Ammurapi Shield",
        head="Telchine Cap", --Dur. +10 aug
        body="Telchine Chas.", --Dur. +9 aug (Viti. Tabard +1 has no duration)
        hands="Atrophy Gloves +3", --Enh. duration +20 (beats Viti. Gloves +1's aug)
        legs="Telchine Braconi", --Dur. +8 aug
        feet="Leth. Houseaux +1", --Enh. duration +30
        neck="Dls. Torque +2",
        back={ name="Sucellos's Cape", augments={'MND+20','Mag. Acc+20 /Mag. Dmg.+20','MND+10','"Fast Cast"+10','Damage taken-5%',}}, --base: Enh. dur +20% on every copy
        waist="Olympus Sash",
        }

    -- The base Enhancing set now carries max owned skill in every slot, so no
    -- overlay is needed for Temper/enspell casts. Kept as a hook for future
    -- skill-only pieces. (Viti. Tights +3's Enspell-damage aug is a melee-time
    -- stat and lives in sets.engaged.Enspell instead.)
    sets.midcast.EnhancingSkill = {}

    -- Regen rides the Duration set as-is: Telchine head/body/legs are already
    -- there, and Atrophy Gloves +3 (dur +20) beats Telchine Gloves' +9 aug.
    sets.midcast.Regen = set_combine(sets.midcast.EnhancingDuration, {})

    sets.midcast.Refresh = set_combine(sets.midcast.EnhancingDuration, {
        head="Amalric Coif +1", --Refresh potency +2/tick
        body="Atrophy Tabard +3", --Refresh potency +2/tick (the Refresh+3 is idle-only)
        })

    sets.midcast.RefreshSelf = {
        waist="Gishdubar Sash", --Refresh received +1
        }

    sets.midcast.Stoneskin = set_combine(sets.midcast.EnhancingDuration, {})

    -- Phalanx potency scales with enhancing skill at cast: use the skill set.
    sets.midcast['Phalanx'] = set_combine(sets.midcast['Enhancing Magic'], {})

    sets.midcast.Aquaveil = set_combine(sets.midcast.EnhancingDuration, {
        ammo="Staunch Tathlum +1",
        head="Amalric Coif +1", --Aquaveil+
        ring2="Evanescence Ring",
        })

    sets.midcast.Storm = sets.midcast.EnhancingDuration
    sets.midcast.GainSpell = {hands="Viti. Gloves +1"}
    sets.midcast.SpikesSpell = {legs="Viti. Tights +3"}

    sets.midcast.Protect = set_combine(sets.midcast.EnhancingDuration, {})
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
        neck="Dls. Torque +2",
        ear1="Enchntr. Earring +1",
        ear2="Snotra Earring",
        ring1="Kishar Ring", --Enf. duration +10%
        ring2="Stikini Ring +1",
        back={ name="Sucellos's Cape", augments={'MND+20','Mag. Acc+20 /Mag. Dmg.+20','MND+10','"Fast Cast"+10','Damage taken-5%',}},
        waist="Null Belt", --M.Acc 30 (Acuity Belt +1 is only INT/MP)
        }

    sets.midcast.MndEnfeeblesAcc = set_combine(sets.midcast.MndEnfeebles, {
        main="Crocea Mors",
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
        })

    sets.midcast.IntEnfeeblesAcc = set_combine(sets.midcast.IntEnfeebles, {
        main="Crocea Mors",
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
        neck="Dls. Torque +2", --Enf. skill
        ring1="Stikini Ring +1",
        ring2="Stikini Ring +1",
        ear1="Enchntr. Earring +1", --Enf. skill
        ear2="Snotra Earring",
        waist="Rumination Sash", --Enf. skill 7 / SIRD 10
        -- Hands option: Leth. Gantherots +1 (skill 19) beats Kaykaus Cuffs +1
        -- (skill 16) by 3 skill but gives up ~29 M.Acc -- swap if potency-starved.
        })

    sets.midcast.Sleep = set_combine(sets.midcast.IntEnfeeblesAcc, {
        head="Viti. Chapeau +3",
        neck="Dls. Torque +2",
        ear2="Snotra Earring",
        ring1="Kishar Ring",
        })

    -- 4/5 Lethargy (body +2, rest +1 -- set bonus mixes tiers): with Composure up,
    -- the set bonus adds +35% enfeebling duration while KEEPING Viti. Chapeau +3's
    -- +20% duration augment.
    -- (4/5 + Chapeau = 1.40 x 1.35 beats 5/5's 1.20 x 1.50.) Head/ring inherit from Sleep.
    sets.midcast.SleepMaxDuration = set_combine(sets.midcast.Sleep, {
        body="Lethargy Sayon +2",
        hands="Leth. Gantherots +1",
        legs="Leth. Fuseau +1",
        feet="Leth. Houseaux +1",
        })

    sets.midcast.ElementalEnfeeble = sets.midcast.IntEnfeebles
    sets.midcast.Dispelga = set_combine(sets.midcast.IntEnfeeblesAcc, {main="Daybreak", sub="Ammurapi Shield", waist="Shinjutsu-no-Obi +1"})

    sets.midcast['Dark Magic'] = {
        sub="Ammurapi Shield",
        ammo="Hydrocera",
        head="Atro. Chapeau +2",
        body="Lethargy Sayon +2", --M.Acc 54 + M.Dmg 24 (Jhakri Robe +2 is M.Acc 46)
        hands="Kaykaus Cuffs +1",
        legs="Malignance Tights", --M.Acc 50 (Inyanga is WHM/BRD/SMN-only)
        feet="Jhakri Pigaches +2",
        neck="Erra Pendant",
        ear1="Enchntr. Earring +1",
        ear2="Snotra Earring",
        ring1="Stikini Ring +1",
        ring2="Evanescence Ring",
        back={ name="Sucellos's Cape", augments={'INT+20','Mag. Acc+20 /Mag. Dmg.+20','"Mag.Atk.Bns."+10',}}, --M.Acc 20 (Aurist's is only M.Acc 7)
        waist="Null Belt", --M.Acc 30 (Acuity Belt +1 is only INT/MP)
        }

    sets.midcast.Drain = set_combine(sets.midcast['Dark Magic'], {
        head="Pixie Hairpin +1", --Dark dmg+
        ring2="Evanescence Ring",
        })

    sets.midcast.Aspir = sets.midcast.Drain
    sets.midcast.Stun = set_combine(sets.midcast['Dark Magic'], {waist="Null Belt"})
    sets.midcast['Bio III'] = set_combine(sets.midcast['Dark Magic'], {legs="Viti. Tights +3"})

    sets.midcast['Elemental Magic'] = {
        main="Bunzi's Rod",
        sub="Ammurapi Shield",
        ammo="Ghastly Tathlum +1", --Mag. dmg.
        head="Jhakri Coronal +2", --MAB
        body="Lethargy Sayon +2", --MAB 49 / M.Dmg 24 / M.Acc 54 (Jhakri Robe +2 is MAB 43, M.Acc 46, no M.Dmg)
        hands="Jhakri Cuffs +2", --MAB
        legs="Jhakri Slops +2", --MAB
        feet="Jhakri Pigaches +2", --MAB
        neck="Sibyl Scarf", --Mag. dmg.
        ear1="Friomisi Earring", --MAB
        ear2="Sortiarius Earring",
        ring1="Jhakri Ring", --MAB
        ring2="Metamor. Ring +1",
        back={ name="Sucellos's Cape", augments={'INT+20','Mag. Acc+20 /Mag. Dmg.+20','"Mag.Atk.Bns."+10',}},
        waist="Skrymir Cord", --M.Acc 5 / MAB 5 / M.Dmg 30 (Acuity Belt +1 is only INT/MP)
        }

    -- Seidr gear not owned; falls through to base nuke set for now.
    sets.midcast['Elemental Magic'].Seidr = set_combine(sets.midcast['Elemental Magic'], {})

    sets.midcast['Elemental Magic'].Resistant = set_combine(sets.midcast['Elemental Magic'], {
        ammo="Hydrocera", --M.Acc
        hands="Kaykaus Cuffs +1", --M.Acc+20 aug
        legs="Malignance Tights", --M.Acc 50 (Inyanga is WHM/BRD/SMN-only)
        neck="Erra Pendant",
        ring1="Stikini Ring +1",
        })

    -- DISABLED: Twilight Cloak (NOT OWNED) is required to cast Impact; set is dormant.
    sets.midcast.Impact = set_combine(sets.midcast['Elemental Magic'], {
        head=empty,
        --body="Twilight Cloak", -- not owned; uncomment when acquired
        })

    -- Initializes trusts at iLvl 119
    sets.midcast.Trust = sets.precast.FC -- (re-pointed by build_fc_sets on every rebuild)

    -- Job-specific buff sets
    -- Lethargy +1 / Composure set bonus: +10-50% duration (by pieces worn) on
    -- ENHANCING magic cast on others AND long-duration ENFEEBLES cast on enemies.
    -- Self-targeted spells are unaffected, so this overlays only on non-self casts.
    sets.buff.ComposureOther = {
        head="Leth. Chappel +1",
        body="Lethargy Sayon +2",
        hands="Leth. Gantherots +1",
        legs="Leth. Fuseau +1",
        feet="Leth. Houseaux +1",
        }

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

    sets.idle.DT = set_combine(sets.idle, {
        head="Nyame Helm", --DT
        body="Nyame Mail", --DT
        hands="Nyame Gauntlets", --DT
        legs="Nyame Flanchard", --DT
        feet="Nyame Sollerets", --DT
        ear1="Eabani Earring",
        ear2="Alabaster Earring", --DT/HP
        ring2="Murky Ring", --DT-10 (untyped: covers MDT too, unlike Gelatinous PDT-7)
        back={ name="Sucellos's Cape", augments={'DEX+20','Accuracy+20 Attack+20','"Dual Wield"+10','Damage taken-5%',}}, --DT-5
        })

    sets.idle.Town = set_combine(sets.idle, {
        head="Viti. Chapeau +3",
        body="Viti. Tabard +1",
        legs="Carmine Cuisses +1", --Movement+
        neck="Dls. Torque +2",
        back={ name="Sucellos's Cape", augments={'INT+20','Mag. Acc+20 /Mag. Dmg.+20','"Mag.Atk.Bns."+10',}},
        waist="Acuity Belt +1",
        })

    sets.resting = set_combine(sets.idle, {
        main="Chatoyant Staff",
        waist="Shinjutsu-no-Obi +1",
        })

    ------------------------------------------------------------------------------------------------
    ---------------------------------------- Defense Sets ------------------------------------------
    ------------------------------------------------------------------------------------------------

    sets.defense.PDT = sets.idle.DT
    sets.defense.MDT = sets.idle.DT

    -- Overlay applied on top of sets.midcast['Elemental Magic'] when bursting.
    -- Only slots listed here swap; everything else keeps the nuke set.
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

    -- Movement speed gear does not stack; one piece suffices. Ring keeps legs free while engaged.
    sets.Kiting = {ring1="Shneddick Ring"}
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
        back={ name="Sucellos's Cape", augments={'DEX+20','Accuracy+20 Attack+20','"Dual Wield"+10','Damage taken-5%',}},
        waist="Windbuffet Belt +1",
        }

    sets.engaged.MidAcc = set_combine(sets.engaged, {
        neck="Sanctity Necklace", --Acc
        ear2="Mache Earring +1", --Acc
        })

    sets.engaged.HighAcc = set_combine(sets.engaged.MidAcc, {
        ammo="Staunch Tathlum +1", --Yamarang is not RDM; keeps Acc-10 Focal Orb out
        ear1="Cessance Earring",
        waist="Null Belt",
        })

    -- Owned DW gear: Suppanomimi 5, Eabani 4, DW cape 10, Carmine legs 5 = 24 total.
    -- (Patentia Sash is not RDM-equippable; Sailfi's Haste+9% fills the waist instead.)
    -- No Magic Haste (max gear DW)
    sets.engaged.DW = set_combine(sets.engaged, {
        legs="Carmine Cuisses +1", --DW
        ear1="Eabani Earring", --DW
        ear2="Suppanomimi", --DW
        waist="Sailfi Belt +1", --Haste 9 / TA 2
        })

    sets.engaged.DW.MidAcc = set_combine(sets.engaged.DW, {
        neck="Sanctity Necklace",
        ear2="Mache Earring +1",
        })

    sets.engaged.DW.HighAcc = set_combine(sets.engaged.DW.MidAcc, {
        ammo="Staunch Tathlum +1", --Yamarang is not RDM; keeps Acc-10 Focal Orb out
        ear1="Cessance Earring",
        })

    -- DEPRECATED: the LowHaste..MaxHaste tier family below is no longer
    -- selected (determine_haste_group keeps CustomMeleeGroups empty); the
    -- adaptive DW overlay in customize_melee_set now decides the three DW
    -- slots exactly from Gearinfo's DW_needed. Sets kept for reference only.
    -- Gear DW pool totals 24 (cape 10 + Suppa 5 + Eabani 4 + Carmine 5),
    -- short of the 43 needed at zero magic haste -- an inventory limit.
    -- 15% Magic Haste
    sets.engaged.DW.LowHaste = set_combine(sets.engaged.DW, {})

    sets.engaged.DW.MidAcc.LowHaste = set_combine(sets.engaged.DW.MidAcc, {})

    sets.engaged.DW.HighAcc.LowHaste = set_combine(sets.engaged.DW.HighAcc, {})

    -- 30% Magic Haste (less DW needed: drop Carmine legs)
    sets.engaged.DW.MidHaste = set_combine(sets.engaged.DW, {
        legs="Malignance Tights",
        })

    sets.engaged.DW.MidAcc.MidHaste = set_combine(sets.engaged.DW.MidHaste, {
        neck="Sanctity Necklace",
        ear2="Mache Earring +1",
        })

    sets.engaged.DW.HighAcc.MidHaste = set_combine(sets.engaged.DW.MidAcc.MidHaste, {
        ammo="Staunch Tathlum +1", --Yamarang is not RDM; keeps Acc-10 Focal Orb out
        ear1="Cessance Earring",
        })

    -- 35% Magic Haste (drop Eabani)
    sets.engaged.DW.HighHaste = set_combine(sets.engaged.DW.MidHaste, {
        ear1="Brutal Earring",
        })

    sets.engaged.DW.MidAcc.HighHaste = set_combine(sets.engaged.DW.HighHaste, {
        neck="Sanctity Necklace",
        ear2="Mache Earring +1",
        })

    sets.engaged.DW.HighAcc.HighHaste = set_combine(sets.engaged.DW.MidAcc.HighHaste, {
        ammo="Staunch Tathlum +1", --Yamarang is not RDM; keeps Acc-10 Focal Orb out
        ear1="Cessance Earring",
        })

    -- 45% Magic Haste (cape 10 + Suppa 5 covers it)
    sets.engaged.DW.MaxHaste = set_combine(sets.engaged.DW.HighHaste, {
        waist="Windbuffet Belt +1",
        })

    sets.engaged.DW.MidAcc.MaxHaste = set_combine(sets.engaged.DW.MaxHaste, {
        neck="Sanctity Necklace",
        ear2="Mache Earring +1",
        })

    sets.engaged.DW.HighAcc.MaxHaste = set_combine(sets.engaged.DW.MidAcc.MaxHaste, {
        ammo="Staunch Tathlum +1", --Yamarang is not RDM; keeps Acc-10 Focal Orb out
        ear1="Cessance Earring",
        waist="Null Belt",
        })


    ------------------------------------------------------------------------------------------------
    ---------------------------------------- Hybrid Sets -------------------------------------------
    ------------------------------------------------------------------------------------------------

    sets.engaged.Hybrid = {
       ear2="Alabaster Earring", --DT/HP
       ring2="Murky Ring", --DT-10 (untyped; replaces Gelatinous PDT-7)
       }

    sets.engaged.DT = set_combine(sets.engaged, sets.engaged.Hybrid)
    sets.engaged.MidAcc.DT = set_combine(sets.engaged.MidAcc, sets.engaged.Hybrid)
    sets.engaged.HighAcc.DT = set_combine(sets.engaged.HighAcc, sets.engaged.Hybrid)

    sets.engaged.DW.DT = set_combine(sets.engaged.DW, sets.engaged.Hybrid)
    sets.engaged.DW.MidAcc.DT = set_combine(sets.engaged.DW.MidAcc, sets.engaged.Hybrid)
    sets.engaged.DW.HighAcc.DT = set_combine(sets.engaged.DW.HighAcc, sets.engaged.Hybrid)

    sets.engaged.DW.DT.LowHaste = set_combine(sets.engaged.DW.LowHaste, sets.engaged.Hybrid)
    sets.engaged.DW.MidAcc.DT.LowHaste = set_combine(sets.engaged.DW.MidAcc.LowHaste, sets.engaged.Hybrid)
    sets.engaged.DW.HighAcc.DT.LowHaste = set_combine(sets.engaged.DW.HighAcc.LowHaste, sets.engaged.Hybrid)

    sets.engaged.DW.DT.MidHaste = set_combine(sets.engaged.DW.MidHaste, sets.engaged.Hybrid)
    sets.engaged.DW.MidAcc.DT.MidHaste = set_combine(sets.engaged.DW.MidAcc.MidHaste, sets.engaged.Hybrid)
    sets.engaged.DW.HighAcc.DT.MidHaste = set_combine(sets.engaged.DW.HighAcc.MidHaste, sets.engaged.Hybrid)

    sets.engaged.DW.DT.HighHaste = set_combine(sets.engaged.DW.HighHaste, sets.engaged.Hybrid)
    sets.engaged.DW.MidAcc.DT.HighHaste = set_combine(sets.engaged.DW.MidAcc.HighHaste, sets.engaged.Hybrid)
    sets.engaged.DW.HighAcc.DT.HighHaste = set_combine(sets.engaged.DW.HighAcc.HighHaste, sets.engaged.Hybrid)

    sets.engaged.DW.DT.MaxHaste = set_combine(sets.engaged.DW.MaxHaste, sets.engaged.Hybrid)
    sets.engaged.DW.MidAcc.DT.MaxHaste = set_combine(sets.engaged.DW.MidAcc.MaxHaste, sets.engaged.Hybrid)
    sets.engaged.DW.HighAcc.DT.MaxHaste = set_combine(sets.engaged.DW.HighAcc.MaxHaste, sets.engaged.Hybrid)

    sets.engaged.Enspell = {
        hands="Aya. Manopolas +2", --Sword enh. spell dmg +17
        legs="Viti. Tights +3", --Enspell dmg aug (melee-time stat; was wasted in a midcast set)
        neck="Dls. Torque +2",
        waist="Orpheus's Sash",
        }



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

    sets.CroceaMors = {main="Crocea Mors", sub="Daybreak"}
    sets.Naegling = {main="Naegling", sub="Blurred Knife +1"}
    sets.Tauret = {main="Tauret", sub="Blurred Knife +1"}
    sets.Idle = {main="Daybreak", sub="Ammurapi Shield"}

    sets.DefaultShield = {sub="Ammurapi Shield"}

    -- Adaptive Fast Cast: everything now exists (fc_core/fc_ladder above,
    -- all midcast sets, states from user_setup), so compute the real gear
    -- target and rebuild the FC sets. init_gear_sets is the LAST step of
    -- Mote's init order -- do not move this call into user_setup.
    update_fc_tier()

end

-------------------------------------------------------------------------------------------------------------------
-- Job-specific hooks for standard casting events.
-------------------------------------------------------------------------------------------------------------------

saboteur_worthy = S{'Distract III', 'Frazzle III'}

function job_precast(spell, action, spellMap, eventArgs)
    -- Convert guard (Selindrile pattern): the JA fails outright at 0 MP, so
    -- abort instead of burning the attempt. The max-HP precast set in
    -- sets.precast.JA['Convert'] handles the equipment side.
    if spell.english == 'Convert' and player.mp == 0 then
        cancel_spell()
        add_to_chat(167, '** [Convert Canceled - 0 MP, it would fail] **')
        eventArgs.handled = true
        return
    end

    -- Nudge: big enfeeble going out without Saboteur while it sits ready
    if saboteur_worthy:contains(spell.english) and not buffactive.Saboteur and ja_ready('Saboteur') then
        send_command('input /echo ** Saboteur is ready - pair it with '..spell.english..' **')
    end

    -- Ammo Protection (toggle with: gs c toggle RangedLock)
    if spell.action_type == 'Ranged Attack' and state.RangedLock.value then
        cancel_spell()
        add_to_chat(167, '** [Ranged Attack Canceled - Ammo Protection On] **')
        eventArgs.handled = true
        return
    end

    -- Auto-Cancel Active Buffs
    if spell.english == 'Stoneskin' then
        send_command('cancel stoneskin')
    elseif spell.english == 'Sneak' then
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

function job_post_precast(spell, action, spellMap, eventArgs)
    if spell.name == 'Impact' then
        equip(sets.precast.FC.Impact)
    end
    if spell.english == "Phalanx II" and spell.target.type == 'SELF' then
        cancel_spell()
        send_command('@input /ma "Phalanx" <me>')
    end

    -- Smart Magical WS Logic
    if spell.type == 'WeaponSkill' then
        local magical_ws = S{'Sanguine Blade', 'Seraph Blade', 'Aeolian Edge'}
        
        if magical_ws:contains(spell.english) then
            -- Equip Orpheus if under 1.7 yalms. (Obi branch removed: Hachirin-no-Obi
            -- not owned. Re-add a weather/day branch here when acquired.)
            if spell.target.distance < (1.7 + spell.target.model_size) then
                equip({waist="Orpheus's Sash"})
            end
        end
    end
end

-- Run after the default midcast() is done.
-- eventArgs is the same one used in job_midcast, in case information needs to be persisted.
function job_post_midcast(spell, action, spellMap, eventArgs)
    if spell.skill == 'Enhancing Magic' then
        if classes.NoSkillSpells:contains(spell.english) then
            equip(sets.midcast.EnhancingDuration)
        elseif skill_spells:contains(spell.english) then
            equip(sets.midcast.EnhancingSkill)
        elseif spell.english:startswith('Gain') then
            equip(sets.midcast.GainSpell)
        elseif spell.english:contains('Spikes') then
            equip(sets.midcast.SpikesSpell)
        end
        if spellMap == 'Refresh' then
            equip(sets.midcast.Refresh)
            if spell.target.type == 'SELF' then
                equip(sets.midcast.RefreshSelf)
            end
        end
        if (spell.target.type == 'PLAYER' or spell.target.type == 'NPC') and buffactive.Composure then
            equip(sets.buff.ComposureOther)
            -- Refresh: potency beats set-bonus tiers. Keeping Amalric (+2/tick) and
            -- Atrophy Tabard +3 (+2/tick) at 3/5 Lethargy (+20% dur) delivers more
            -- total MP than 5/5 (+50% dur) with no potency pieces. Fuseau's +2 stays.
            if spellMap == 'Refresh' then
                equip({head="Amalric Coif +1", body="Atrophy Tabard +3"})
            end
        end
    end

    -- Lethargy/Composure duration overlay for long-duration enemy debuffs.
    -- Only when Composure is up and the debuff is one we want to KEEP, not land.
    if spell.skill == 'Enfeebling Magic' and buffactive.Composure
       and lethargy_duration_enfeebles:contains(spell.english) then
        equip(sets.buff.ComposureOther)
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
        local bursting = state.MagicBurst.value
        if not bursting and state.AutoBurst.value and sc_burst_window_active(spell) then
            bursting = true
            add_to_chat(158, '[AutoMB] '..spell.english..' bursting on '..tostring(sc_window.name)..' window.')
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
        if spell.target.distance < (8 + spell.target.model_size) then
            equip({waist="Orpheus's Sash"})
        end
    end
end

function job_aftercast(spell, action, spellMap, eventArgs)
    if spell.type == 'JobAbility' and ja_tracker[spell.english] and not spell.interrupted then
        ja_tracker[spell.english].used_at = os.time()
    end
    if spell.english:contains('Sleep') and not spell.interrupted then
        set_sleep_timer(spell)
    end
    if player.status ~= 'Engaged' and state.WeaponLock.value == false then
        check_weaponset()
    end
end

-------------------------------------------------------------------------------------------------------------------
-- Job-specific hooks for non-casting events.
-------------------------------------------------------------------------------------------------------------------

-- Auto Echo Drops with a hard cap of 3 attempts per silence instance.
-- Some silences are item-resistant; this avoids burning the whole stack.
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
        add_to_chat(123, '** [Echo Drops cap (3) hit - silence resisted items. Wait it out or Healing Waltz/ally Silena] **')
        silence_echo.active = false
        return
    end
    silence_echo.attempts = silence_echo.attempts + 1
    send_command('input /item "Echo Drops" <me>')
    add_to_chat(123, '** [Silenced! Echo Drops attempt '..silence_echo.attempts..'/3] **')
    coroutine.schedule(try_echo_drops, 4) -- re-check after item delay
end

function job_buff_change(buff,gain)
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

    if buff:lower() == "paralysis" and gain then
        add_to_chat(123, '** [Paralyzed - cast Paralyna] **')
    end

    -- Adaptive Fast Cast: a COR's Caster's Roll counts toward the 80% cast cap,
    -- and Chainspell/Spontaneity zero the gear target entirely (instant casts).
    if buff == "Caster's Roll" or buff == 'Chainspell' or buff == 'Spontaneity' then
        update_fc_tier()
    end
    update_hud()

    -- Re-evaluate melee gear when an enspell starts or wears (drives EnspellMode Auto)
    if enspell_buff_names:contains(buff) and player.status == 'Engaged' then
        handle_equipping_gear(player.status)
    end

    if buff:lower() == "doom" then
        if gain then
            equip(sets.buff.Doom)
            send_command('@input /p Doomed.')
            send_command('input /echo ** DOOMED - spam Holy Waters **')
            disable('neck','ring1','ring2','waist')
        else
            enable('neck','ring1','ring2','waist')
            handle_equipping_gear(player.status)
        end
    end

    -- EXP/CP boost is now active (Dedication/Commitment): release any boost ring so
    -- normal gear returns -- the buff persists without the ring.
    if gain and boost_buffs:contains(buff:lower()) then
        local slots = {}
        if boost_gear:contains(player.equipment.left_ring)  then slots[#slots+1] = 'ring1' end
        if boost_gear:contains(player.equipment.right_ring) then slots[#slots+1] = 'ring2' end
        release_ring_slots(slots, buff..' active')
    end
end

-- Handle notifications of general user state change.
function job_state_change(stateField, newValue, oldValue)
    -- Win+F changed the assumed Caster's Roll value: retarget the FC sets.
    -- (Mote passes the state's description string; check the raw name too.)
    if stateField == 'Caster Roll FC Assumption' or stateField == 'CasterRollFC' then
        update_fc_tier(true)
    end

    -- Emergency PDT/MDT toggled: same target, but sheds re-walk in DT-priority
    -- order (Nyame slots first). update_fc_tier's build key catches this.
    if stateField == 'Defense Mode' then
        update_fc_tier()
    end

    update_hud()

    if state.WeaponLock.value == true then
        disable('main','sub','range')
    elseif not state.PauseSwaps.value then
        -- Don't re-enable weapon slots while PauseSwaps has everything frozen.
        enable('main','sub','range')
    end

    -- Win+P: freeze/unfreeze every gear slot at once (fishing, crafting, gathering, etc.)
    if stateField == 'PauseSwaps' then
        if state.PauseSwaps.value == true then
            disable(unpack(all_equip_slots))
            add_to_chat(167, '** [GearSwap PAUSED -- all auto gear swapping OFF] **')
        else
            enable(unpack(all_equip_slots))
            if state.WeaponLock.value == true then
                disable('main','sub','range')
            end
            check_gear()                        -- re-lock any no_swap rings still equipped
            handle_equipping_gear(player.status) -- resync gear now that swapping resumed
            add_to_chat(158, '** [GearSwap RESUMED -- auto gear swapping ON] **')
        end
    end

    check_weaponset()
end

-------------------------------------------------------------------------------------------------------------------
-- User code that supplements standard library decisions.
-------------------------------------------------------------------------------------------------------------------

-- Called by the 'update' self-command, for common needs.
-- Set eventArgs.handled to true if we don't want automatic equipping of gear.
function job_handle_equipping_gear(playerStatus, eventArgs)
    check_gear()
    update_combat_form()
    determine_haste_group()
    check_moving()
end

function job_update(cmdParams, eventArgs)
    handle_equipping_gear(player.status)
end

-- CombatForm 'DW' selects the sets.engaged.DW.* family.
-- Primary source: Gearinfo addon reports (sets the DW global via gearinfo()).
-- Fallback when Gearinfo isn't loaded: infer Dual Wield from the subjob.
-- Without Gearinfo the haste tiers stay off, so the base DW set (max DW gear)
-- is used -- the safe default.
function update_combat_form()
    if DW == true then
        state.CombatForm:set('DW')
    elseif (player.sub_job == 'NIN' and player.sub_job_level > 9)
        or (player.sub_job == 'DNC' and player.sub_job_level > 19) then
        state.CombatForm:set('DW')
    else
        state.CombatForm:reset()
    end
end

-- Custom spell mapping.
function job_get_spell_map(spell, default_spell_map)
    if spell.action_type == 'Magic' then
        if default_spell_map == 'Cure' or default_spell_map == 'Curaga' then
            if (world.weather_element == 'Light' or world.day_element == 'Light') then
                return 'CureWeather'
            end
        end
        if spell.skill == 'Enhancing Magic' and spell.english:startswith('Refresh') then
            return 'Refresh'
        end
        if spell.skill == 'Enhancing Magic' and spell.english:startswith('Regen') then
            return 'Regen'
        end
        if spell.skill == 'Enfeebling Magic' then
            if enfeebling_magic_skill:contains(spell.english) then
                return "SkillEnfeebles"
            elseif spell.type == "WhiteMagic" then
                if enfeebling_magic_acc:contains(spell.english) and not buffactive.Stymie then
                    return "MndEnfeeblesAcc"
                elseif enfeebling_magic_effect:contains(spell.english) then
                    return "MndEnfeeblesEffect"
                else
                    return "MndEnfeebles"
              end
            elseif spell.type == "BlackMagic" then
                if enfeebling_magic_acc:contains(spell.english) and not buffactive.Stymie then
                    return "IntEnfeeblesAcc"
                elseif enfeebling_magic_effect:contains(spell.english) then
                    return "IntEnfeeblesEffect"
                elseif enfeebling_magic_sleep:contains(spell.english) and ((buffactive.Stymie and buffactive.Composure) or state.SleepMode.value == 'MaxDuration') then
                    return "SleepMaxDuration"
                elseif enfeebling_magic_sleep:contains(spell.english) then
                    return "Sleep"
                else
                    return "IntEnfeebles"
                end
            else
                return "MndEnfeebles"
            end
        end
    end
end

function get_custom_wsmode(spell, action, spellMap)
    local wsmode
    if state.OffenseMode.value == 'MidAcc' or state.OffenseMode.value == 'HighAcc' then
        wsmode = 'Acc'
    end

    return wsmode
end

-- Modify the default idle set after it was constructed.
function customize_idle_set(idleSet)
    if player.mpp < 51 then
        idleSet = set_combine(idleSet, sets.latent_refresh)
    end

    if monitor_state.hp_lean then
        idleSet = set_combine(idleSet, sets.idle.DT)
    end
    -- if state.CP.current == 'on' then
    --     equip(sets.CP)
    --     disable('back')
    -- else
    --     enable('back')
    -- end

    if state.Auto_Kite.value == true then
       idleSet = set_combine(idleSet, sets.Kiting)
    end

    check_gear()
    return idleSet
end

-- Modify the default melee set after it was constructed.
function customize_melee_set(meleeSet)
    local enspell_gear_wanted = state.EnspellMode.value == 'On'
        or (state.EnspellMode.value == 'Auto' and enspell_active())

    if enspell_gear_wanted then
        meleeSet = set_combine(meleeSet, sets.engaged.Enspell)
    end
    
    if state.TreasureMode.value == 'Fulltime' then
        meleeSet = set_combine(meleeSet, sets.TreasureHunter)
    end

    if monitor_state.hp_lean then
        meleeSet = set_combine(meleeSet, sets.engaged.Hybrid)
    end

    -- Adaptive Dual Wield: applied LAST so a needed DW piece wins its slot
    -- over Acc/Hybrid variant choices, while unneeded DW remnants are
    -- stripped back to base without disturbing non-DW variant picks
    -- (Alabaster/Mache/Cessance survive whenever their slot isn't needed).
    if state.CombatForm and state.CombatForm.value == 'DW' then
        for _, e in ipairs(dw_pool) do
            if e.active then
                meleeSet = set_combine(meleeSet, {[e.slot] = e.piece})
            elseif dw_item_name(meleeSet[e.slot]) == e.piece then
                meleeSet = set_combine(meleeSet, {[e.slot] = e.off})
            end
        end
        -- Waist: Sailfi's Haste+9% only while the pool can't reach the need;
        -- otherwise strip a leftover Sailfi back to Windbuffet. Null Belt and
        -- other variant waists are only displaced by an actual shortfall.
        if dw_shortfall then
            meleeSet = set_combine(meleeSet, {waist="Sailfi Belt +1"})
        elseif dw_item_name(meleeSet.waist) == "Sailfi Belt +1" then
            meleeSet = set_combine(meleeSet, {waist="Windbuffet Belt +1"})
        end
    end

    check_gear()

    -- Weapon reassert is safe here: WeaponLock (Win+W) is the supported way to
    -- protect manually equipped weapons; when locked, this call is a no-op.
    check_weaponset()

    return meleeSet
end

-- Function to display the current relevant user state when doing an update.
-- Return true if display was handled, and you don't want the default info shown.
function display_current_job_state(eventArgs)
    local cf_msg = ''
    if state.CombatForm.has_value then
        cf_msg = ' (' ..state.CombatForm.value.. ')'
    end

    local m_msg = state.OffenseMode.value
    if state.HybridMode.value ~= 'Normal' then
        m_msg = m_msg .. '/' ..state.HybridMode.value
    end

    local ws_msg = state.WeaponskillMode.value

    local c_msg = state.CastingMode.value

    local d_msg = 'None'
    if state.DefenseMode.value ~= 'None' then
        d_msg = state.DefenseMode.value .. state[state.DefenseMode.value .. 'DefenseMode'].value
    end

    local i_msg = state.IdleMode.value

    local msg = ''
    if state.MagicBurst.value then
        msg = ' Burst: On |'
    end
    if state.AutoBurst.value then
        msg = msg .. ' AutoMB |'
    end
    if state.AutoSC.value then
        msg = msg .. ' AutoSC |'
    end
    if state.Kiting.value then
        msg = msg .. ' Kiting: On |'
    end

    add_to_chat(002, '| ' ..string.char(31,210).. 'Melee' ..cf_msg.. ': ' ..string.char(31,001)..m_msg.. string.char(31,002)..  ' |'
        ..string.char(31,207).. ' WS: ' ..string.char(31,001)..ws_msg.. string.char(31,002)..  ' |'
        ..string.char(31,060).. ' Magic: ' ..string.char(31,001)..c_msg.. string.char(31,002)..  ' |'
        ..string.char(31,004).. ' Defense: ' ..string.char(31,001)..d_msg.. string.char(31,002)..  ' |'
        ..string.char(31,008).. ' Idle: ' ..string.char(31,001)..i_msg.. string.char(31,002)..  ' |'
        ..string.char(31,002)..msg)

    eventArgs.handled = true
end

-------------------------------------------------------------------------------------------------------------------
-- Utility functions specific to this job.
-------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Adaptive Fast Cast engine (see the header comment on fc_core in
-- init_gear_sets for the full explanation).
-------------------------------------------------------------------------------

-- JP-spent thresholds of RDM's four Fast Cast gifts (+2% cast each):
-- 150 / 500 / 1125 / 2000. A mastered RDM (2100) has all four = 38% native FC.
RDM_FC_GIFT_JP = {150, 500, 1125, 2000}

fc_gear_target = nil     -- gear FC the current sets aim for
fc_current_gear = 0      -- gear FC the base set actually carries
fc_jp_spent = 0
fc_shed_list = {}

-- Native (non-gear, non-buff) FC: trait tier by level + JP gifts.
function rdm_native_fc()
    if player and player.main_job and player.main_job ~= 'RDM' then return 0 end
    local lvl = (player and player.main_job_level) or 99
    local trait = 0
    if     lvl >= 89 then trait = 30
    elseif lvl >= 76 then trait = 25
    elseif lvl >= 55 then trait = 20
    elseif lvl >= 35 then trait = 15
    elseif lvl >= 15 then trait = 10
    end

    local ok, jp = pcall(function() return windower.ffxi.get_player().job_points.rdm.jp_spent end)
    fc_jp_spent = (ok and type(jp) == 'number') and jp or 0
    local gifts = 0
    for _, threshold in ipairs(RDM_FC_GIFT_JP) do
        if fc_jp_spent >= threshold then gifts = gifts + 2 end
    end
    return trait + gifts
end

-- Build ONE precast FC set that meets `target` gear FC with as few FC pieces
-- as possible; freed ladder slots get their DT/M.Eva fillers.
-- opts.enfeeb: try Leth. Chappel +1 (Enfeebling cast time -15%, a separate
--   multiplier that stacks past the FC cap) over the FC+14 head -- taken only
--   when the set can still reach target without those 14 FC.
-- opts.order: which shed priority to walk (fc_shed_order / fc_shed_order_dt).
-- Finally, if even the FC head is unneeded (target 0 under Chainspell/
-- Spontaneity), it too becomes a filler.
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
-- zero-job-points target -- never under cap). While a physical/magical
-- DefenseMode is active, sheds walk the DT-priority order instead, trading
-- retained-FC headroom for Nyame slots (still never below target).
function build_fc_sets()
    local target = fc_gear_target or 50
    local dt_mode = state and state.DefenseMode and
        (state.DefenseMode.value == 'Physical' or state.DefenseMode.value == 'Magical')
    local order = dt_mode and fc_shed_order_dt or fc_shed_order
    local base, base_fc, base_shed = build_fc_set(target, {order=order})

    sets.precast.FC = base
    fc_current_gear = base_fc
    fc_shed_list = base_shed
    fc_dt_order_active = dt_mode

    sets.precast.FC['Enhancing Magic'] = sets.precast.FC
    -- (Chappel skipped while instant-cast is up: -15% cast time on a 0s cast)
    sets.precast.FC['Enfeebling Magic'] = build_fc_set(target, {order=order, enfeeb=(not fc_instant)})

    sets.precast.FC.Cure = set_combine(base, {})
    sets.precast.FC.Curaga = sets.precast.FC.Cure
    sets.precast.FC['Healing Magic'] = sets.precast.FC.Cure
    sets.precast.FC['Elemental Magic'] = set_combine(base, {})

    -- DISABLED: Impact requires Twilight/Crepuscular Cloak (NOT OWNED) to even
    -- cast, so this set is dormant. Re-enable by acquiring the cloak.
    sets.precast.FC.Impact = set_combine(base, {
        head=empty,
        --body="Twilight Cloak", -- not owned; uncomment when acquired
        })

    sets.precast.FC.Dispelga = set_combine(base, {main="Daybreak", sub="Ammurapi Shield", waist="Shinjutsu-no-Obi +1"})
    sets.precast.FC.Storm = set_combine(base, {ring2="Stikini Ring +1"})
    sets.precast.FC.Utsusemi = sets.precast.FC.Cure

    -- These two were bound to the old table by reference; re-point them.
    if sets.midcast then
        sets.midcast.FastRecast = sets.precast.FC
        sets.midcast.Trust = sets.precast.FC
    end

    update_hud()
end

-- Recompute the gear target from trait + gifts + party buffs and rebuild the
-- FC sets when anything changed. Caster's Roll's value can't be read off the
-- buff icon, so state.CasterRollFC holds the assumption (Win+F to cycle --
-- match the roll number you saw in chat). Assuming LOW is the safe direction:
-- worst case you stay slightly over cap. Assuming high on a low roll = under
-- cap. Chainspell/Spontaneity make casts instant, so the target drops to 0 and
-- every FC piece (head included) becomes a DT/M.Eva filler -- Leth. Chappel is
-- skipped too, since its -15% cast multiplier is meaningless on instant casts.
function update_fc_tier(verbose)
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

    -- Rebuild key includes the shed-order flavor so toggling DefenseMode
    -- rebuilds even when the numeric target is unchanged.
    local dt_mode = state and state.DefenseMode and
        (state.DefenseMode.value == 'Physical' or state.DefenseMode.value == 'Magical')
    local build_key = target .. (dt_mode and '/DT' or '')

    if build_key ~= fc_build_key then
        fc_build_key = build_key
        fc_gear_target = target
        build_fc_sets()
        report_fc_tier()
    elseif verbose then
        report_fc_tier()
    end
end

-------------------------------------------------------------------------------
-- On-screen HUD (replaces the GearInfo addon's display -- run '//gi hide'
-- once; the addon keeps calculating and feeding 'gs c gearinfo' regardless,
-- which this HUD surfaces along with a link-alive indicator).
--
-- Toggle: Win+H or 'gs c hud'. The box is draggable, but the position is NOT
-- persisted -- set your preferred default in hud_settings below.
-------------------------------------------------------------------------------

hud_settings = {
    pos = {x = 170, y = 640},   -- default anchor; drag in-game, then copy here
    text = {size = 10, font = 'Consolas'},
    bg = {alpha = 120},
    flags = {draggable = true},
}
hud = nil
hud_visible = true
gearinfo_last = nil   -- os.clock() of the last 'gs c gearinfo' packet

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

-- Inline color tags for the texts library: '\cs(r,g,b)' opens, '\cr' resets.
-- Tune the palette here.
hud_colors = {
    label  = '\\cs(135,135,150)',  -- field names
    value  = '\\cs(240,240,240)',  -- neutral values
    good   = '\\cs(120,255,120)',  -- capped FC, GI:true, toggles on
    bad    = '\\cs(255,110,110)',  -- GI:false, ** PAUSED **
    dim    = '\\cs(110,110,110)',  -- toggles off
    accent = '\\cs(120,200,255)',  -- Caster's Roll assumption
    cs     = '\\cs(255,210,80)',   -- <CHAINSPELL>
    dt     = '\\cs(255,160,70)',   -- [DT] shed order / active DefenseMode
}
local function col(name, s) return (hud_colors[name] or '') .. s .. '\\cr' end
local function onoff(st)
    local on = st and st.value
    return col(on and 'good' or 'dim', on and 'on' or 'off')
end

function update_hud()
    if not hud then return end

    -- L1: Fast Cast engine status
    local flags = ''
    if fc_instant then flags = flags .. ' ' .. col('cs', '<CHAINSPELL>') end
    if fc_dt_order_active then flags = flags .. ' ' .. col('dt', '[DT]') end
    if buffactive and buffactive["Caster's Roll"] and state and state.CasterRollFC then
        flags = flags .. ' ' .. col('accent', '[Roll~' .. tostring(state.CasterRollFC.value) .. ']')
    end
    local fc_nums = string.format('%d/%d', fc_current_gear or 0, fc_gear_target or 0)
    -- construction guarantees carried >= target, so green unless instant-cast
    -- makes the numbers moot (dim)
    local l1 = col('label', 'FC ') .. col(fc_instant and 'dim' or 'good', fc_nums) .. flags

    -- L2: Dual Wield have/need + haste feed from GearInfo, link as true/false
    local linked = gearinfo_last and col('good', 'true') or col('bad', 'false')
    local dw_txt, dw_col = '--/--', 'dim'
    if DW == true and DW_needed then
        dw_txt = string.format('%d/%d', dw_have or 0, DW_needed or 0)
        dw_col = dw_shortfall and 'bad' or 'good'
    end
    local l2 = col('label', 'DW ') .. col(dw_col, dw_txt)
        .. col('label', '  Haste ') .. col('value', tostring(Haste or 0) .. '%')
        .. col('label', '  GI:') .. linked

    -- L3: modes (DefenseMode highlighted while an emergency mode is up)
    local l3 = ''
    if state then
        local dval = state.DefenseMode and state.DefenseMode.value or '-'
        local dcol = (dval == 'Physical' or dval == 'Magical') and 'dt' or 'value'
        l3 = col('label', 'Offense:') .. col('value', state.OffenseMode and state.OffenseMode.value or '-')
          .. col('label', '  Hybrid:') .. col('value', state.HybridMode and state.HybridMode.value or '-')
          .. col('label', '  Casting:') .. col('value', state.CastingMode and state.CastingMode.value or '-')
          .. col('label', '  Defense:') .. col(dcol, dval)
    end

    -- L4: automation toggles
    local l4 = ''
    if state then
        l4 = col('label', 'AutoSC:') .. onoff(state.AutoSC)
          .. col('label', '  MagicBurst:') .. onoff(state.MagicBurst)
          .. col('label', '  AutoBurst:') .. onoff(state.AutoBurst)
          .. col('label', '  Sleep:') .. col('value', state.SleepMode and state.SleepMode.value or '-')
          .. col('label', '  NM:') .. onoff(state.NM)
          .. ((state.PauseSwaps and state.PauseSwaps.value) and col('bad', '  ** PAUSED **') or '')
    end

    hud:text(l1 .. '\n' .. l2 .. '\n' .. l3 .. '\n' .. l4)
end

function toggle_hud()
    if not hud then return end
    hud_visible = not hud_visible
    if hud_visible then hud:show() else hud:hide() end
end

function report_fc_tier()
    local native = rdm_native_fc()
    if fc_instant then
        add_to_chat(158, string.format('[FC] Chainspell/Spontaneity: casts are instant -- all %d FC slots traded for DT/M.Eva', 60))
        return
    end
    local roll_up = buffactive and buffactive["Caster's Roll"] and state and state.CasterRollFC
    local roll = roll_up and (tonumber(state.CasterRollFC.value) or 0) or 0
    local roll_note = roll_up
        and string.format(" + Caster's Roll ~%d%%", roll) or ""
    local order_note = fc_dt_order_active and " [DT-priority sheds]" or ""
    add_to_chat(158, string.format("[FC] native %d%% (trait+gifts, %d JP spent)%s -> gear target %d%%; set carries %d%%%s",
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
-- Adaptive Dual Wield (the DW analog of the FC engine).
--
-- Gearinfo streams DW_needed = total gear DW required to cap delay under the
-- current magic/JA haste. Only three swappable DW pieces exist in inventory
-- (plus a constant DW+10 on the TP cape worn in every melee set), so instead
-- of a greedy ladder the engine checks ALL 8 subsets and picks the provably
-- minimal one that still meets the need -- e.g. need 14 wears Eabani alone
-- (cape 10 + 4 = exact) where a greedy walk would overshoot with Suppanomimi.
--
-- POLICY: a needed DW piece wins its slot over Acc/DT variant pieces
-- (Mache/Cessance/Alabaster) -- delay cap first, accuracy compensates via
-- neck/ammo. Unneeded DW remnants left in a variant set are stripped back to
-- the base piece; non-DW slot choices are never touched. If even the full 24
-- can't reach the need, everything is worn, the waist swaps to Sailfi
-- (Haste+9% squeezes the gap) and the HUD DW readout turns red.
--
-- 'gs c dwinfo' prints the current math.
-------------------------------------------------------------------------------

dw_pool = {
    {slot='ear2', dw=5, piece="Suppanomimi",        off="Telos Earring",      prio=1},
    {slot='ear1', dw=4, piece="Eabani Earring",     off="Brutal Earring",     prio=2},
    {slot='legs', dw=5, piece="Carmine Cuisses +1", off="Malignance Tights",  prio=4},
}
dw_cape_constant = 10   -- DW+10 TP cape: present in every engaged set
dw_have = 0
dw_shortfall = false

function dw_item_name(it) return type(it) == 'table' and it.name or it end

-- Pick the minimal subset of dw_pool covering (DW_needed - cape). Exhaustive:
-- 3 pieces = 8 masks. Ties break toward lower prio sum (prefer sacrificing
-- ear2's Telos before ear1's Brutal before the Malignance legs).
function update_dw_overlay()
    if DW ~= true or not DW_needed then
        for _, e in ipairs(dw_pool) do e.active = false end
        dw_have, dw_shortfall = 0, false
        return
    end

    local target = math.max(0, DW_needed - dw_cape_constant)
    local n = #dw_pool
    local best = nil
    for mask = 0, (2 ^ n) - 1 do
        local sum, prio = 0, 0
        for i = 1, n do
            if math.floor(mask / 2 ^ (i - 1)) % 2 == 1 then
                sum = sum + dw_pool[i].dw
                prio = prio + dw_pool[i].prio
            end
        end
        if sum >= target and (not best or sum < best.sum
            or (sum == best.sum and prio < best.prio)) then
            best = {mask = mask, sum = sum, prio = prio}
        end
    end

    if best then
        dw_shortfall = false
    else
        -- unreachable: wear the whole pool and flag it
        best = {mask = (2 ^ n) - 1, sum = 0}
        for i = 1, n do best.sum = best.sum + dw_pool[i].dw end
        dw_shortfall = true
    end

    for i = 1, n do
        dw_pool[i].active = math.floor(best.mask / 2 ^ (i - 1)) % 2 == 1
    end
    dw_have = dw_cape_constant + best.sum
end

function report_dw_tier()
    if DW ~= true then
        add_to_chat(158, '[DW] not dual wielding (Gearinfo reports DW inactive)')
        return
    end
    local worn, stripped = {}, {}
    for _, e in ipairs(dw_pool) do
        if e.active then worn[#worn+1] = e.piece .. ' +' .. e.dw
        else stripped[#stripped+1] = e.piece end
    end
    add_to_chat(158, string.format('[DW] need %d -> cape 10 + %s = %d worn%s',
        DW_needed or 0,
        (#worn > 0) and table.concat(worn, ', ') or 'nothing',
        dw_have,
        dw_shortfall and '  ** SHORT: pool maxed, Sailfi haste compensating **' or ''))
    if #stripped > 0 then
        add_to_chat(158, '[DW] freed for base/Acc/DT pieces: ' .. table.concat(stripped, ', '))
    end
end

function determine_haste_group()
    -- LEGACY tier groups replaced by the adaptive overlay: groups stay empty
    -- so Mote resolves the tier-less sets.engaged.DW family, and
    -- customize_melee_set corrects the three DW slots piece-by-piece.
    classes.CustomMeleeGroups:clear()
    update_dw_overlay()
end

function gearinfo(cmdParams, eventArgs)
    if cmdParams[1] == 'gearinfo' then
        gearinfo_last = os.clock()
        if type(tonumber(cmdParams[2])) == 'number' then
            if tonumber(cmdParams[2]) ~= DW_needed then
            DW_needed = tonumber(cmdParams[2])
            DW = true
            end
        elseif type(cmdParams[2]) == 'string' then
            if cmdParams[2] == 'false' then
                DW_needed = 0
                DW = false
            end
        end
        if type(tonumber(cmdParams[3])) == 'number' then
            if tonumber(cmdParams[3]) ~= Haste then
                Haste = tonumber(cmdParams[3])
            end
        end
        if type(cmdParams[4]) == 'string' then
            if cmdParams[4] == 'true' then
                moving = true
            elseif cmdParams[4] == 'false' then
                moving = false
            end
        end
        update_dw_overlay()   -- recompute even mid-cast so the HUD is live;
                              -- gear itself applies on the next equip pass
        if not midaction() then
            job_update()
        end
        update_hud()
    end
end

function job_self_command(cmdParams, eventArgs)
    if cmdParams[1]:lower() == 'scholar' then
        handle_strategems(cmdParams)
        eventArgs.handled = true
    elseif cmdParams[1]:lower() == 'enspell' then
        send_command('@input /ma '..state.EnSpell.value..' <me>')
    elseif cmdParams[1]:lower() == 'barelement' then
        send_command('@input /ma '..state.BarElement.value..' <me>')
    elseif cmdParams[1]:lower() == 'barstatus' then
        send_command('@input /ma '..state.BarStatus.value..' <me>')
    elseif cmdParams[1]:lower() == 'gainspell' then
        local spell_to_cast = state.GainSpell.value

        -- 'Auto' picks the Gain spell to match the equipped weapon's WS modifier;
        -- any explicit choice in the cycle is always respected.
        if spell_to_cast == 'Auto' then
            local weapon_gain = {
                ['Naegling']    = 'Gain-STR', -- Savage Blade (STR/MND)
                ['Crocea Mors'] = 'Gain-DEX', -- Chant du Cygne / Vorpal (DEX)
                ['Tauret']      = 'Gain-DEX', -- Evisceration (DEX)
                ['Maxentius']   = 'Gain-MND', -- Black Halo (MND)
            }
            spell_to_cast = weapon_gain[player.equipment.main] or 'Gain-MND' --MND aids enfeebles
        end

        send_command('@input /ma "'..spell_to_cast..'" <me>')
    elseif cmdParams[1]:lower() == 'hud' then
        toggle_hud()
        eventArgs.handled = true
    elseif cmdParams[1]:lower() == 'dwinfo' then
        update_dw_overlay()
        report_dw_tier()
        eventArgs.handled = true
    elseif cmdParams[1]:lower() == 'fcinfo' then
        -- Recompute (picks up JP spent since load) and print the FC math.
        update_fc_tier(true)
        eventArgs.handled = true
    elseif cmdParams[1] == 'auditgear' then
        audit_gear()
        eventArgs.handled = true
    elseif cmdParams[1]:lower() == 'scdelay' then
        local v = tonumber(cmdParams[2])
        if v then
            autosc.react_delay = math.max(0.5, math.min(5.0, v))
            add_to_chat(158, string.format('[AutoSC] react delay set to %.1fs (session only; edit autosc.react_delay to keep it)', autosc.react_delay))
        else
            add_to_chat(158, string.format('[AutoSC] react delay is %.1fs -- usage: gs c scdelay <0.5-5.0>', autosc.react_delay))
        end
        eventArgs.handled = true
    elseif cmdParams[1] == 'sctest' then
        sc_selftest()
        eventArgs.handled = true
    elseif cmdParams[1] == 'scdebug' then
        autosc.debug = not autosc.debug
        add_to_chat(158, '[AutoSC] debug logging '..(autosc.debug and 'ON' or 'OFF'))
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

    gearinfo(cmdParams, eventArgs)
end

-- General handling of strategems in an Arts-agnostic way.
-- Format: gs c scholar <strategem>

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

function set_sleep_timer(spell)
    local self = windower.ffxi.get_player()

    local base
    if spell.en == "Sleep II" then
        base = 90
    elseif spell.en == "Sleep" or spell.en == "Sleepga" then
        base = 60
    end
    -- Unhandled sleep-type spell: skip the timer rather than erroring on a nil base.
    if not base then return end

    if state.Buff.Saboteur then
        if state.NM.value then
            base = base * 1.25
        else
            base = base * 2
        end
    end

    -- Merit Points Duration Bonus
    base = base + self.merits.enfeebling_magic_duration*6

    -- Relic Head Duration Bonus: Viti. Chapeau +3 is worn in BOTH Sleep and
    -- SleepMaxDuration sets now, so this always applies.
    base = base + self.merits.enfeebling_magic_duration*3

    -- Job Points Duration Bonus
    base = base + self.job_points.rdm.enfeebling_magic_duration

    -- Gear enfeebling duration in the Sleep sets (additive, then multiplied):
    -- Viti. Chapeau +3 aug +20% + Kishar Ring +10% + Snotra Earring +10% = 1.40
    local gear_mult = 1.40

    -- Estoquer/Lethargy Composure set bonus
    -- 2pc = 1.1 / 3pc = 1.2 / 4pc = 1.35 / 5pc = 1.5
    local empy_mult = 1 --from sets.midcast.Sleep

    if ((buffactive.Stymie and buffactive.Composure) or state.SleepMode.value == 'MaxDuration') then
        if buffactive.Stymie then
            base = base + self.job_points.rdm.stymie_effect
        end
        -- 4/5 Lethargy worn (sets.midcast.SleepMaxDuration), but the set bonus
        -- only functions while Composure is actually up.
        if buffactive.Composure then
            empy_mult = 1.35
        end
    end

    local totalDuration = math.floor(base * gear_mult * empy_mult)

    -- Create the custom timer
    if spell.english == "Sleep II" then
        send_command('@timers c "Sleep II ['..spell.target.name..']" ' ..totalDuration.. ' down spells/00259.png')
    elseif spell.english == "Sleep" or spell.english == "Sleepga" then
        send_command('@timers c "Sleep ['..spell.target.name..']" ' ..totalDuration.. ' down spells/00253.png')
    end
    if sleep_timer_debug then
        add_to_chat(1, 'Sleep timer -- base: ' ..base.. ' gear: x' ..gear_mult.. ' set bonus: x' ..empy_mult.. ' total: ' ..totalDuration)
    end
end

-- Check for various actions that we've specified in user code as being used with TH gear.
-- This will only ever be called if TreasureMode is not 'None'.
-- Category and Param are as specified in the action event packet.
function th_action_check(category, param)
    if category == 2 or -- any ranged attack
        --category == 4 or -- any magic action
        (category == 3 and param == 30) or -- Aeolian Edge
        (category == 6 and info.default_ja_ids:contains(param)) or -- Provoke, Animated Flourish
        (category == 14 and info.default_u_ja_ids:contains(param)) -- Quick/Box/Stutter Step, Desperate/Violent Flourish
        then return true
    end
end

-- Mote-Include dispatches subjob changes here. update_combat_form (called every
-- equip cycle) reads the subjob directly; this just forces an immediate refresh.
function job_sub_job_change(newSubjob, oldSubjob)
    handle_equipping_gear(player.status)
end

function check_moving()
    if state.DefenseMode.value == 'None'  and state.Kiting.value == false then
        if state.Auto_Kite.value == false and moving then
            state.Auto_Kite:set(true)
        elseif state.Auto_Kite.value == true and moving == false then
            state.Auto_Kite:set(false)
        end
    end
end

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

-------------------------------------------------------------------------------------------------------------------
-- Auto Magic Burst detection
-- Watches action packets for skillchains closing (by you, Silmaril, Trusts, or party)
-- and opens a burst window. Matching-element nukes cast during the window
-- automatically get sets.magic_burst, no manual toggle needed.
-- Manual override: WIN+B (state.MagicBurst) forces burst gear on regardless.
-- Disable detection: gs c toggle AutoBurst
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

function ja_ready(name)
    local ja = ja_tracker[name]
    return ja and (os.time() - ja.used_at) >= ja.recast
end

monitor_state = {convert_alerted = false, hp_lean = false, last_tick = 0}

-- Fires roughly every 2.4 real seconds (each game minute); throttled to ~5s.
windower.raw_register_event('time change', function()
    if os.clock() - monitor_state.last_tick < 5 then return end
    monitor_state.last_tick = os.clock()
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
    elseif monitor_state.hp_lean and player.hpp >= 60 then
        monitor_state.hp_lean = false
        send_command('input /echo ** HP recovered - resuming normal gear **')
        handle_equipping_gear(player.status)
    end
end)

-- Enspell buff detection (drives EnspellMode 'Auto')
enspell_buff_names = S{'Enfire','Enblizzard','Enaero','Enstone','Enthunder','Enwater',
                       'Enfire II','Enblizzard II','Enaero II','Enstone II','Enthunder II','Enwater II'}

function enspell_active()
    for name in enspell_buff_names:it() do
        if buffactive[name] then return true end
    end
    return false
end

sc_window = {name=nil, target_id=nil, expires=0}

-- Skillchain -> elements that can magic burst on it
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

windower.raw_register_event('action', function(act)
    if not act or not act.targets then return end

    -- Reactive skillchain: a party member's WS opens a resonance window (ported from NIN).
    sc_track_ws_open(act)

    for _, targ in pairs(act.targets) do
        if targ.actions then
            for _, a in pairs(targ.actions) do
                if a.has_add_effect and sc_messages[a.add_effect_message] then
                    sc_window.name = sc_messages[a.add_effect_message]
                    sc_window.target_id = targ.id
                    sc_window.expires = os.clock() + 10
                    -- Re-arm the reactive window to the FORMED chain's property so a
                    -- Lv1/Lv2 can be escalated (e.g. Distortion -> Darkness).
                    sc_note_resonance(sc_window.name, targ.id, sc_window.name)
                    if state.AutoBurst.value then
                        local list = {}
                        for el, _ in pairs(sc_burst_elements[sc_window.name]) do list[#list+1] = el end
                        add_to_chat(158, '[AutoMB] '..sc_window.name..' window open ('
                            ..table.concat(list, '/')..', ~10s)')
                    end
                end
            end
        end
    end
end)

function sc_burst_window_active(spell)
    if sc_window.expires <= os.clock() then return false end
    if not spell.target or spell.target.id ~= sc_window.target_id then return false end
    local elems = sc_burst_elements[sc_window.name]
    return elems and elems:contains(spell.element) or false
end


-------------------------------------------------------------------------------------------------------------------
-- Reactive Skillchains -- close a chain off party-member weaponskills (Win+C / gs c toggle AutoSC)
--
--   When a member of YOUR party (Trust, alt, anyone -- but not you) lands a WS on
--   your target, the mob resonates with that WS's skillchain property for ~5-6s.
--   If AutoSC is on and your TP >= autosc.min_tp, the lua scans the weaponskills
--   you can CURRENTLY use (auto-detected from your equipped weapon) and fires the
--   one whose property closes a skillchain on that resonance -- preferring bigger
--   chains (Light/Darkness > Lv2 > Lv1). It also re-arms off a freshly-formed
--   skillchain, so a Lv2 can be escalated. The existing AutoMB window then opens
--   for your elemental ninjutsu.
--
--   It only CLOSES; it never opens. Keep your normal opener (macro/partner) to
--   start chains -- the lua reacts and finishes them. Tune the autosc.* knobs;
--   'gs c scdelay <seconds>' adjusts the reaction delay live (0.5-5.0).
-------------------------------------------------------------------------------------------------------------------

-- Resources are required to map a weaponskill id -> its skillchain properties.
-- Try a few ways to obtain them so this works across GearSwap setups.
local res = nil
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
    Light=3, Darkness=3, Radiance=3, Umbra=3,
    Gravitation=2, Fragmentation=2, Distortion=2, Fusion=2,
    Compression=1, Liquefaction=1, Induration=1, Reverberation=1,
    Transfixion=1, Scission=1, Detonation=1, Impaction=1,
}

-- Tunables -----------------------------------------------------------------------
autosc = {
    min_tp      = 1000,    -- don't react below this TP
    react_delay = 3.0,     -- wait this long after the opener's WS before closing.
                           -- The resonance window only OPENS ~3s after the
                           -- opener lands; the old 1.6 could fire inside the
                           -- dead zone and produce a plain, chainless WS.
                           -- Tune live with 'gs c scdelay <seconds>'.
    window      = 6.0,     -- resonance lasts ~6-8s; give up after this
    retry_step  = 0.4,     -- if short on TP, re-check this often within the window
    ws_cooldown = 3.0,     -- min seconds between auto-fired WS (anti double-fire)
    party_only  = true,    -- only react to WS by YOUR party (Trusts/alts), not the alliance
    level_order = {3, 2, 1}, -- prefer bigger skillchains first
    chain_pref  = 'Light', -- tie-break when both Light and Darkness are possible
    ws_priority = {},      -- optional WS names, best first, e.g. {'Blade: Shun','Blade: Hi'}
    debug       = false,   -- chat-log what AutoSC sees/decides (gs c scdebug to toggle)
}

sc_react = {props=nil, target_id=nil, expires=0, opener='', last_ws=0}

-- Is this mob id a member of your party OR alliance (Trusts/alts included)?
local function actor_is_party(id)
    if not id then return false end
    local p = windower.ffxi.get_party()
    if not p then return false end
    local keys = {'p0','p1','p2','p3','p4','p5',
                  'a10','a11','a12','a13','a14','a15',
                  'a20','a21','a22','a23','a24','a25'}
    for _, key in ipairs(keys) do
        local m = p[key]
        if m then
            if m.mob and m.mob.id == id then return true end
            if m.id and m.id == id then return true end  -- out-of-zone fallback
        end
    end
    return false
end

-- Arm (or refresh) the reaction window and schedule an attempt.
function sc_note_resonance(prop, target_id, opener)
    if not state.AutoSC or not state.AutoSC.value then return end
    if not prop then return end
    sc_react.props     = (type(prop) == 'table') and prop or {prop}
    sc_react.target_id = target_id
    sc_react.expires   = os.clock() + autosc.window
    sc_react.opener    = opener or sc_react.opener
    coroutine.schedule(function() try_skillchain_react(target_id) end, autosc.react_delay)
end

-- A party member's WS opened a resonance? (action category 3 = weaponskill finish)
function sc_track_ws_open(act)
    if not act or act.category ~= 3 then return end
    if not (state.AutoSC and state.AutoSC.value) then return end
    if act.actor_id == player.id then return end                  -- never react to our own WS

    local party = actor_is_party(act.actor_id)
    local ws = res and res.weapon_skills[act.param]

    if autosc.debug then
        add_to_chat(160, '[AutoSC dbg] WS finish seen: actor='..tostring(act.actor_id)
            ..' party='..tostring(party)..' res='..tostring(res ~= nil)
            ..' ws='..tostring(ws and ws.en or act.param))
    end

    if autosc.party_only and not party then return end
    if not res then
        add_to_chat(123, '[AutoSC] resources library not loaded -- cannot read WS properties. See header notes.')
        return
    end
    if not ws then return end

    local props = {}
    for _, key in ipairs({'skillchain_a','skillchain_b','skillchain_c'}) do
        if ws[key] and ws[key] ~= '' then props[#props+1] = ws[key] end
    end
    if #props == 0 then
        if autosc.debug then add_to_chat(160, '[AutoSC dbg] '..tostring(ws.en)..' has no skillchain properties.') end
        return
    end

    -- grab the first target's id robustly (targets is iterated via pairs elsewhere)
    local target_id
    for _, targ in pairs(act.targets or {}) do target_id = targ.id; break end

    add_to_chat(158, '[AutoSC] '..tostring(ws.en)..' -> '..table.concat(props,'/')..' resonance; looking to close.')
    sc_note_resonance(props, target_id, ws.en)
end

-- Of the WS you can currently use, choose the best one that closes on active_props.
local function pick_chain_ws(active_props)
    if not res then return nil end
    local abils = windower.ffxi.get_abilities()
    if not abils or not abils.weapon_skills then return nil end

    local prio = {}
    for i, n in ipairs(autosc.ws_priority) do prio[n] = i end

    local best, best_rank
    for _, ws_id in ipairs(abils.weapon_skills) do
        local ws = res.weapon_skills[ws_id]
        if ws then
            for _, my in ipairs({ws.skillchain_a, ws.skillchain_b, ws.skillchain_c}) do
                if my and my ~= '' then
                    for _, act_prop in ipairs(active_props) do
                        local result = sc_combo[act_prop] and sc_combo[act_prop][my]
                        if result then
                            local lvl = sc_level[result] or 1
                            local lvl_rank = 0
                            for i, L in ipairs(autosc.level_order) do
                                if L == lvl then lvl_rank = #autosc.level_order - i end
                            end
                            local chain_rank = (result == autosc.chain_pref) and 1 or 0
                            local name_rank  = prio[ws.en] and (1000 - prio[ws.en]) or 0
                            local rank = lvl_rank*100000 + chain_rank*10000 + name_rank
                            if not best_rank or rank > best_rank then
                                best_rank = rank
                                best = {name=ws.en, result=result, level=lvl}
                            end
                        end
                    end
                end
            end
        end
    end
    return best
end

function try_skillchain_react(target_id)
    if not (state.AutoSC and state.AutoSC.value) then return end
    if not sc_react.props or os.clock() > sc_react.expires then return end

    -- still engaged on the resonating mob? (if we never captured an id, trust <t>)
    local t = windower.ffxi.get_mob_by_target('t')
    if not t then
        if autosc.debug then add_to_chat(160, '[AutoSC dbg] no current target; skip.') end
        return
    end
    if sc_react.target_id and t.id ~= sc_react.target_id then
        if autosc.debug then add_to_chat(160, '[AutoSC dbg] target mismatch; skip.') end
        return
    end
    if player.status ~= 'Engaged' then return end
    if midaction() then return end
    if (os.clock() - sc_react.last_ws) < autosc.ws_cooldown then return end

    -- TP gate: if short, keep checking until the window is nearly up
    if (player.tp or 0) < autosc.min_tp then
        if (sc_react.expires - os.clock()) > autosc.retry_step then
            coroutine.schedule(function() try_skillchain_react(target_id) end, autosc.retry_step)
        elseif autosc.debug then
            add_to_chat(160, '[AutoSC dbg] window closed at '..tostring(player.tp)..' TP (<'..autosc.min_tp..').')
        end
        return
    end

    local choice = pick_chain_ws(sc_react.props)
    if not choice then
        if autosc.debug then
            add_to_chat(160, '[AutoSC dbg] no usable WS closes '..table.concat(sc_react.props,'/')
                ..' with this weapon.')
        end
        return
    end

    sc_react.last_ws = os.clock()
    sc_react.props   = nil   -- consume this resonance so we don't double-fire
    add_to_chat(158, '[AutoSC] Closing '..choice.result..' (Lv'..choice.level..') with '..choice.name..'.')
    send_command('input /ws "'..choice.name..'" <t>')
end

-- On-demand diagnostics: gs c sctest
function sc_selftest()
    add_to_chat(158, '=== AutoSC self-test ===')
    add_to_chat(158, 'AutoSC: '..tostring(state.AutoSC and state.AutoSC.value)
        ..' | resources: '..tostring(res ~= nil)
        ..' | party_only: '..tostring(autosc.party_only)
        ..' | min_tp: '..autosc.min_tp)
    add_to_chat(158, 'Your TP: '..tostring(player.tp)..' | status: '..tostring(player.status))
    local t = windower.ffxi.get_mob_by_target('t')
    add_to_chat(158, 'Current target: '..tostring(t and (t.name..' ['..t.id..']') or 'none'))
    if not res then
        add_to_chat(123, 'resources NOT loaded -> AutoSC cannot read WS properties. This is the blocker.')
        add_to_chat(158, '=== end ===')
        return
    end
    local abils = windower.ffxi.get_abilities()
    local list = abils and abils.weapon_skills or nil
    if not list or #list == 0 then
        add_to_chat(123, 'No usable weaponskills right now (weapon unequipped, or not in a WS-capable state).')
    else
        add_to_chat(158, 'Usable weaponskills ('..#list..'):')
        for _, id in ipairs(list) do
            local ws = res.weapon_skills[id]
            if ws then
                local props = {}
                for _, k in ipairs({'skillchain_a','skillchain_b','skillchain_c'}) do
                    if ws[k] and ws[k] ~= '' then props[#props+1] = ws[k] end
                end
                add_to_chat(158, '  '..ws.en..'  ['..(table.concat(props,'/'))..']')
            end
        end
    end
    if sc_react.props then
        add_to_chat(158, 'Active resonance: '..table.concat(sc_react.props,'/')
            ..' ('..string.format('%.1f', math.max(0, sc_react.expires-os.clock()))..'s left)')
    else
        add_to_chat(158, 'No active resonance right now.')
    end
    add_to_chat(158, 'Tip: gs c scdebug toggles live packet logging.')
    add_to_chat(158, '=== end ===')
end

-- Announce module status shortly after load (after user_setup has run).
coroutine.schedule(function()
    add_to_chat(158, '[AutoSC] loaded. resources='..tostring(res ~= nil)
        ..'. Toggle Win+C; diagnose with: gs c sctest')
end, 4)


function check_weaponset()
    if (player.sub_job ~= 'NIN' and player.sub_job ~= 'DNC') then
        equip(set_combine(sets[state.WeaponSet.current], sets.DefaultShield))
    elseif player.sub_job == 'NIN' and player.sub_job_level < 10 or player.sub_job == 'DNC' and player.sub_job_level < 20 then
        equip(set_combine(sets[state.WeaponSet.current], sets.DefaultShield))
    else
        equip(sets[state.WeaponSet.current])
    end
end

-- On zone change you've arrived: drop WARP/dimension rings so normal rings return.
-- Boost rings (EXP/CP) are intentionally kept across zones until their buff lands.
windower.register_event('zone change',
    function()
        local slots = {}
        if warp_gear:contains(player.equipment.left_ring)  then slots[#slots+1] = 'ring1' end
        if warp_gear:contains(player.equipment.right_ring) then slots[#slots+1] = 'ring2' end
        if #slots > 0 then
            -- enable + force the idle rings back in now (no check_gear in between to re-lock)
            for _, s in ipairs(slots) do enable(s) end
            equip(sets.idle)
        end
    end
)

-- Select default macro book on initial load or subjob change.
function select_default_macro_book()
    -- Default macro set/book
    set_macro_page(1, 11)
end

function set_lockstyle()
    send_command('wait 2; input /lockstyleset ' .. lockstyleset)
end

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
