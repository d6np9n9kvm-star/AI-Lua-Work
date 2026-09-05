-- Falurian BLU GearSwap v2.1.0
-- 2026-09-01 community harvest, owned-gear audit, and BLU intelligence pass.
-- Install as: Windower4/addons/GearSwap/data/BLU.lua
-- Keep ItemStats.lua in the same GearSwap data folder.
--
-- v2.0.0:
--   * Migrated to the current F-key control philosophy and persistent command-center HUD.
--   * Native movement sampling now owns Shneddick routing; GearInfo is comparison-only.
--   * Fishing freezes non-ring slots only, preserving protected rings and movement routing.
--   * Added Sakpata's Sword throughout BLU weapon/casting policy and replaced obsolete Claid offhands.
--   * Re-audited owned BLU gear against the 2026-08-16 ItemStats inventory.
--   * Corrected invalid Null Loop ring references in HP/breath/White Wind sets.
--   * Corrected Sub-zero Smash to physical/VIT routing.
--   * DT now resolves before adaptive DW so required delay-cap pieces cannot be overwritten.
--   * Hot idle/melee overlays are aggregated into one final set_combine allocation.
--   * Spell-family routing, live set-spell FC/DW traits, AutoMB, Auto-Unbridled, TH, Doom,
--     Echo Drops, protected rings, learning hands, and WS range guards are preserved.
--
-- v2.1.0:
--   * Assumes level 99 BLU with 2,100 Job Points and both Job Trait Bonus gifts.
--   * Corrected Dual Wield VI to 37% and repaired two resource-name spell routes.
--   * Reworked melee accuracy, HighBuff/PDL, White Wind, CDC, WSD, and magical WS sets.
--   * Added exact route/resource validation and honest SIRD 57/102 diagnostics.
--   * Added safe, named 75-point spell profiles with preview/learning validation and
--     an optional paced in-game installer; no profile relies on Assimilation merits.

local BLU_RELEASE_VERSION = '2.1.0'
local BLU_RELEASE_DATE = '2026-09-01'
local blu_res = require('resources')

local BLU_RUNTIME = {
    unloading = false,
    event_ids = {},
    token = tostring(os.time())..'-'..tostring(math.floor(os.clock() * 1000000)),
}

local function track_blu_event(id)
    if id ~= nil then BLU_RUNTIME.event_ids[#BLU_RUNTIME.event_ids + 1] = id end
    return id
end

local function unregister_blu_events()
    if windower and type(windower.unregister_event) == 'function' then
        for _, id in ipairs(BLU_RUNTIME.event_ids) do
            pcall(windower.unregister_event, id)
        end
    end
    BLU_RUNTIME.event_ids = {}
end

local function chat(color, text)
    add_to_chat(color or 158, text)
end

local function bool_word(v)
    return v and 'ON' or 'OFF'
end

local ALL_EQUIP_SLOTS = {
    'main','sub','range','ammo','head','neck','ear1','ear2',
    'body','hands','ring1','ring2','back','waist','legs','feet',
}
local FISHING_LOCK_SLOTS = {
    'main','sub','range','ammo','head','neck','ear1','ear2',
    'body','hands','back','waist','legs','feet',
}
local MOVEMENT_RING_NAME = 'Shneddick Ring'
local save_blu_hud_preferences
local movement_route_label

local function pause_swaps_active()
    return state and state.PauseSwaps and state.PauseSwaps.value == true or false
end

local function fishing_mode_active()
    return state and state.FishingMode and state.FishingMode.value == true or false
end

local function swaps_frozen()
    return pause_swaps_active() or fishing_mode_active()
end

local function item_name(item)
    return type(item) == 'table' and item.name or item
end

-------------------------------------------------------------------------------------------------------------------
-- Small profiler. No clocks or allocations are performed while disabled.
-------------------------------------------------------------------------------------------------------------------

local perf = {enabled=false, started=0, counters={}, timers={}}

local function perf_count(name, amount)
    if not perf.enabled then return end
    perf.counters[name] = (perf.counters[name] or 0) + (amount or 1)
end

local function perf_begin()
    if perf.enabled then return os.clock() end
end

local function perf_finish(name, started)
    if not perf.enabled or not started then return end
    local elapsed = os.clock() - started
    local timer = perf.timers[name]
    if not timer then
        timer = {calls=0, total=0, max=0}
        perf.timers[name] = timer
    end
    timer.calls = timer.calls + 1
    timer.total = timer.total + elapsed
    if elapsed > timer.max then timer.max = elapsed end
end

local function perf_reset()
    perf.started = os.clock()
    perf.counters = {}
    perf.timers = {}
end

local function perf_report()
    chat(158, string.format('[BLU Perf] %s | %.1fs sample',
        perf.enabled and 'ON' or 'OFF',
        perf.started > 0 and math.max(0, os.clock() - perf.started) or 0))
    local names = {}
    for name in pairs(perf.counters) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do
        chat(158, string.format('  %s=%s', name, tostring(perf.counters[name])))
    end
    names = {}
    for name in pairs(perf.timers) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do
        local timer = perf.timers[name]
        chat(158, string.format('  %s: %d calls | %.3fms total | %.3f avg | %.3f max',
            name, timer.calls, timer.total * 1000,
            timer.calls > 0 and timer.total * 1000 / timer.calls or 0,
            timer.max * 1000))
    end
end

-------------------------------------------------------------------------------------------------------------------
-- Exact Blue Magic classification
--
-- FFXI resources expose all Blue Magic as one skill. The game data does not identify physical,
-- magical, breath, healing, buff, or debuff subfamilies, so those distinctions must live here.
-- Later gear resolution is one exact table lookup, never a scan through multiple S{} collections.
-------------------------------------------------------------------------------------------------------------------

local BLUE_MAGIC_MAP = {}
local BLUE_MAGIC_POLICY = {}
local BLUE_FAMILY_COUNTS = {}
local BLUE_POLICY_DUPLICATES = {}

local function add_blue_family(family, objective, names)
    for _, name in ipairs(names) do
        if BLUE_MAGIC_MAP[name] then
            BLUE_POLICY_DUPLICATES[#BLUE_POLICY_DUPLICATES + 1] =
                name..' ('..BLUE_MAGIC_MAP[name]..' -> '..family..')'
        end
        BLUE_MAGIC_MAP[name] = family
        BLUE_MAGIC_POLICY[name] = {
            family = family,
            source_set = 'sets.midcast.'..family,
            objective = objective,
        }
        BLUE_FAMILY_COUNTS[family] = (BLUE_FAMILY_COUNTS[family] or 0) + 1
    end
end

add_blue_family('Physical',
    'physical Blue Magic: Blue Magic skill, STR, attack, and balanced secondary stats', {
    'Bilgestorm',
})

add_blue_family('PhysicalAcc',
    'accuracy-first physical Blue Magic for innate accuracy penalties or reliable contact', {
    'Heavy Strike',
})

add_blue_family('PhysicalStr',
    'physical Blue Magic with a significant STR modifier', {
    'Battle Dance','Bloodrake','Death Scissors','Dimensional Death','Empty Thrash',
    'Quadrastrike','Saurian Slide','Sinker Drill','Spinal Cleave','Sweeping Gouge',
    'Uppercut','Vertical Cleave',
})

add_blue_family('PhysicalDex',
    'physical Blue Magic with a significant DEX modifier', {
    'Amorphic Spikes','Asuran Claws','Barbed Crescent','Claw Cyclone','Disseverment',
    'Foot Kick','Frenetic Rip','Goblin Rush','Hysteric Barrage','Paralyzing Triad',
    'Seedspray','Sickle Slash','Smite of Rage','Terror Touch','Thrashing Assault','Vanity Dive',
})

add_blue_family('PhysicalVit',
    'physical Blue Magic with a significant VIT modifier', {
    'Body Slam','Cannonball','Delta Thrust','Glutinous Dart','Grand Slam','Power Attack',
    'Quad. Continuum','Sprout Smack','Sub-zero Smash',
})

add_blue_family('PhysicalAgi',
    'physical Blue Magic with a significant AGI modifier', {
    'Benthic Typhoon','Feather Storm','Helldive','Hydro Shot','Jet Stream',
    'Pinecone Bomb','Spiral Spin','Wild Oats',
})

add_blue_family('PhysicalInt',
    'physical Blue Magic with a significant INT modifier', {
    'Mandibular Bite','Queasyshroom',
})

add_blue_family('PhysicalMnd',
    'physical Blue Magic with a significant MND modifier', {
    'Ram Charge','Screwdriver','Tourbillion',
})

add_blue_family('PhysicalChr',
    'physical Blue Magic with a significant CHR modifier', {
    'Bludgeon',
})

add_blue_family('PhysicalHP',
    'current-HP physical Blue Magic', {
    'Final Sting',
})

add_blue_family('Magical',
    'magical Blue Magic damage: INT, Magic Damage, MAB, and balanced Magic Accuracy', {
    'Anvil Lightning','Blastbomb','Blazing Bound','Bomb Toss',
    'Crashing Thunder','Cursed Sphere','Droning Whirlwind','Embalming Earth','Entomb',
    'Firespit','Foul Waters','Ice Break','Leafstorm','Maelstrom','Molting Plumage',
    'Nectarous Deluge','Polar Roar','Regurgitation','Rending Deluge','Scouring Spate','Searing Tempest',
    'Spectral Floe','Subduction','Tem. Upheaval','Tearing Gust','Uproot','Water Bomb',
    'Cesspool',
})

add_blue_family('MagicalDark',
    'dark magical Blue Magic damage with dark affinity priority', {
    'Dark Orb','Death Ray','Eyes On Me','Evryone. Grudge','Palling Salvo','Tenebral Crush',
})

add_blue_family('MagicalLight',
    'light magical Blue Magic damage', {
    'Blinding Fulgor','Diffusion Ray','Rail Cannon','Retinal Glare',
})

add_blue_family('MagicalMnd',
    'magical Blue Magic with a significant MND modifier', {
    'Acrid Stream','Magic Hammer',
})

add_blue_family('MagicalChr',
    'magical Blue Magic with a significant CHR modifier', {
    'Mysterious Light',
})

add_blue_family('MagicalVit',
    'magical Blue Magic with a significant VIT modifier', {
    'Thermal Pulse',
})

add_blue_family('MagicalAgi',
    'magical Blue Magic with a significant AGI modifier', {
    'Silent Storm',
})

add_blue_family('MagicalDex',
    'magical Blue Magic with a significant DEX modifier', {
    'Charged Whisker','Gates of Hades',
})

add_blue_family('MagicAccuracy',
    'hostile effect Blue Magic: maximize Magic Accuracy and Blue Magic skill', {
    '1000 Needles','Absolute Terror','Actinic Burst','Atra. Libations','Auroral Drape','Awful Eye',
    'Blank Gaze','Blistering Roar','Blood Drain','Blood Saber','Chaotic Eye',
    'Cimicine Discharge','Cold Wave','Corrosive Ooze','Cruel Joke','Demoralizing Roar',
    'Digest','Dream Flower','Enervation','Feather Tickle','Filamented Hold',
    'Frightful Roar','Geist Wall','Infrasonics','Jettatura','Light of Penance',
    'Lowing','Mind Blast','Mortal Ray','MP Drainkiss','Osmosis','Reaving Wind',
    'Sandspin','Sandspray','Sheep Song','Soporific','Sound Blast','Stinking Gas',
    'Venom Shell','Voracious Trunk','Yawn',
})

add_blue_family('Breath',
    'breath Blue Magic: current HP and survival stats; MAB does not drive breath damage', {
    'Bad Breath','Flying Hip Press','Frost Breath','Heat Breath','Hecatomb Wave',
    'Magnetite Cloud','Poison Breath','Radiant Breath','Self-Destruct','Thunder Breath',
    'Vapor Spray','Wind Breath',
})

add_blue_family('StunPhysical',
    'physical stun Blue Magic: accuracy, Blue Magic skill, and defensive casting', {
    'Frypan','Head Butt','Sudden Lunge','Tail Slap','Whirl of Rage',
})

add_blue_family('StunMagical',
    'magical stun Blue Magic: Magic Accuracy and Blue Magic skill', {
    'Blitzstrahl','Temporal Shift','Thunderbolt',
})

add_blue_family('Healing',
    'healing Blue Magic: cure potency, MND, and Blue Magic skill', {
    'Healing Breeze','Magic Fruit','Plenilune Embrace','Pollen','Restoral','Wild Carrot',
})

add_blue_family('WhiteWind',
    'White Wind: maximize current HP and retain Blue Magic skill', {
    'White Wind',
})

add_blue_family('SkillBasedBuff',
    'Blue Magic buffs whose potency scales with Blue Magic skill', {
    'Barrier Tusk','Diamondhide','Magic Barrier','Metallic Body','Mighty Guard',
    'Occultation','Plasma Charge','Pyric Bulwark','Reactor Cool',
})

add_blue_family('Buff',
    'fixed-potency/self-support Blue Magic: recast speed and defensive casting', {
    'Amplification','Animating Wail','Carcharian Verve','Cocoon','Erratic Flutter',
    'Exuviation','Fantod','Feather Barrier','Harden Shell','Memento Mori',
    'Nat. Meditation','O. Counterstance','Refueling','Regeneration','Saline Coat',
    'Triumphant Roar','Warm-Up','Winds of Promy.','Zephyr Mantle',
})

add_blue_family('Refresh',
    'Battery Charge: recast speed and defensive casting', {
    'Battery Charge',
})

local UNBRIDLED_SPELLS = {
    ['Absolute Terror']=true, ['Bilgestorm']=true, ['Blistering Roar']=true,
    ['Bloodrake']=true, ['Carcharian Verve']=true, ['Cesspool']=true,
    ['Crashing Thunder']=true, ['Cruel Joke']=true, ['Droning Whirlwind']=true,
    ['Gates of Hades']=true, ['Harden Shell']=true, ['Mighty Guard']=true,
    ['Polar Roar']=true, ['Pyric Bulwark']=true, ['Tearing Gust']=true,
    ['Thunderbolt']=true, ['Tourbillion']=true, ['Uproot']=true,
}

local MAGICAL_BLUE_FAMILIES = {
    Magical=true, MagicalDark=true, MagicalLight=true, MagicalMnd=true,
    MagicalChr=true, MagicalVit=true, MagicalAgi=true, MagicalDex=true,
}

local PHYSICAL_BLUE_FAMILIES = {
    Physical=true, PhysicalAcc=true, PhysicalStr=true, PhysicalDex=true,
    PhysicalVit=true, PhysicalAgi=true, PhysicalInt=true, PhysicalMnd=true,
    PhysicalChr=true, PhysicalHP=true, StunPhysical=true,
}

-------------------------------------------------------------------------------------------------------------------
-- Built-in Blue Magic profiles
--
-- Every shipped profile is capped at 75 points: level 99 (55) + 2,100 JP (20).
-- Assimilation merits may raise the live cap to 80, but these profiles never require them.
-- Selecting a profile is inert; only an explicit "gs c bluprofile apply <name>" changes spells.
-------------------------------------------------------------------------------------------------------------------

local BLU_PROFILE_POINT_CAP = 75
local BLU_SIRD_TOTALS = {base=57, th_tag=41, cap=102}
local BLU_PROFILE_ORDER = {
    'SavageHighHaste','CDCHighHaste','SavageHasteII','CleaveDamage',
    'MagicBurst','TankControl','LearningSafe','SupportSafe',
}

local BLU_SPELL_PROFILES = {
    SavageHighHaste = {
        label='Savage / high haste',
        focus='Savage Blade melee with external high haste; base DW I becomes DW III with max-JP gifts.',
        spells={
            'Delta Thrust','Barbed Crescent','Erratic Flutter','Nat. Meditation','Fantod',
            'Sudden Lunge','Thrashing Assault','Heavy Strike','Empty Thrash','Occultation',
            'Cocoon','Magic Fruit','Tenebral Crush','Winds of Promy.','Battery Charge',
            'White Wind','Paralyzing Triad','Searing Tempest',
        },
    },
    CDCHighHaste = {
        label='CDC / high haste',
        focus='Critical-hit melee profile with max-JP gift traits and core solo utility.',
        spells={
            'Delta Thrust','Barbed Crescent','Erratic Flutter','Nat. Meditation','Fantod',
            'Sudden Lunge','Thrashing Assault','Heavy Strike','Empty Thrash','Occultation',
            'Cocoon','Magic Fruit','Tenebral Crush','Winds of Promy.','Battery Charge',
            'White Wind','Sinker Drill','Paralyzing Triad','Glutinous Dart',
        },
    },
    SavageHasteII = {
        label='Savage / Haste II',
        focus='Base DW III becomes DW V with max-JP gifts for lower external-haste situations.',
        spells={
            'Molting Plumage','Delta Thrust','Barbed Crescent','Blazing Bound','Quad. Continuum',
            'Erratic Flutter','Nat. Meditation','Fantod','Sudden Lunge','Thrashing Assault',
            'Heavy Strike','Empty Thrash','Occultation','Cocoon','Magic Fruit','Tenebral Crush',
            'Winds of Promy.','Battery Charge','Paralyzing Triad',
        },
    },
    CleaveDamage = {
        label='Cleave / damage',
        focus='AoE magical damage, crowd control, self-buffs, MP sustain, and recovery.',
        spells={
            'Erratic Flutter','Battery Charge','Occultation','Cocoon','Magic Hammer',
            'Dream Flower','Winds of Promy.','Magic Fruit','Spectral Floe','Entomb',
            'Tenebral Crush','Anvil Lightning','Searing Tempest','Subduction',
        },
    },
    MagicBurst = {
        label='Magic burst',
        focus='Broad elemental MB coverage with core defense, control, and recovery.',
        spells={
            'Sound Blast','Cursed Sphere','Magic Hammer','Dream Flower','Subduction',
            'Spectral Floe','Tenebral Crush','Rail Cannon','Erratic Flutter','Battery Charge',
            'Occultation','Cocoon','Magic Fruit','Winds of Promy.','Entomb','White Wind',
            'Barrier Tusk',
        },
    },
    TankControl = {
        label='Tank / control',
        focus='Defensive buffs, AoE hate tools, control, recovery, and recast support.',
        spells={
            'Entomb','Silent Storm','Scouring Spate','Tenebral Crush','Restoral',
            'Erratic Flutter','Occultation','Cocoon','Barrier Tusk','Magic Barrier',
            'White Wind','Saline Coat','Battery Charge','Dream Flower','Actinic Burst','Fantod',
        },
    },
    LearningSafe = {
        label='Learning / safe',
        focus='Low-risk utility shell for learning sessions; use Learning Mode for Magus Bazubands.',
        spells={
            'Delta Thrust','Barbed Crescent','Erratic Flutter','Occultation','Cocoon',
            'Barrier Tusk','Magic Barrier','White Wind','Magic Fruit','Restoral',
            'Battery Charge','Winds of Promy.','Dream Flower','Sheep Song','Sudden Lunge',
            'Fantod','Glutinous Dart','Healing Breeze','Saline Coat','Blank Gaze',
        },
    },
    SupportSafe = {
        label='Support / safe',
        focus='General-purpose support, recovery, control, and party defensive tools.',
        spells={
            'Erratic Flutter','Battery Charge','Occultation','Cocoon','Barrier Tusk',
            'Magic Barrier','White Wind','Magic Fruit','Restoral','Winds of Promy.',
            'Dream Flower','Sheep Song','Blank Gaze','Saline Coat','Diamondhide',
            'Nat. Meditation','Magic Hammer','Actinic Burst','Temporal Shift','Fantod',
        },
    },
}

-------------------------------------------------------------------------------------------------------------------
-- Live Blue Magic spell-set traits
--
-- get_mjob_data().spells is the authoritative set-spell list. BLU trait points activate in
-- eight-point tiers. The 100 and 1200 JP Job Trait Bonus gifts add one tier each, but only
-- after the base trait is active. Main-job and subjob traits do not add; the stronger wins.
-------------------------------------------------------------------------------------------------------------------

local TRAIT_SPELL_POINTS = {
    DualWield = {
        ['Animating Wail']=4, ['Blazing Bound']=4, ['Quad. Continuum']=4,
        ['Delta Thrust']=4, ['Mortal Ray']=4, ['Barbed Crescent']=4,
        ['Molting Plumage']=8,
    },
    FastCast = {
        ['Bad Breath']=4, ['Sub-zero Smash']=4, ['Auroral Drape']=4,
        ['Wind Breath']=4, ['Erratic Flutter']=8,
    },
}

local DW_TIER_VALUE = {[1]=10,[2]=15,[3]=25,[4]=30,[5]=35,[6]=37}
local BLU_FC_TIER_VALUE = {[1]=5,[2]=10,[3]=15,[4]=20,[5]=25,[6]=30}

local trait_cache = {
    signature=nil,
    jp_spent=0,
    gift_tiers=0,
    set_names={},
    contributors={DualWield={}, FastCast={}},
    points={DualWield=0, FastCast=0},
    blu_tier={DualWield=0, FastCast=0},
    blu_value={DualWield=0, FastCast=0},
    sub_value={DualWield=0, FastCast=0},
    value={DualWield=0, FastCast=0},
}

local function runtime_jp_spent()
    local jp = player and player.job_points and player.job_points.blu
    if type(jp) == 'table' then return tonumber(jp.jp_spent) or 0 end
    local fn = windower and windower.ffxi and windower.ffxi.get_player
    local p = type(fn) == 'function' and fn() or nil
    jp = p and p.job_points and p.job_points.blu
    return type(jp) == 'table' and (tonumber(jp.jp_spent) or 0) or 0
end

local function blue_set_spell_names()
    local names, ids = {}, {}
    local fn = windower and windower.ffxi and windower.ffxi.get_mjob_data
    local data = type(fn) == 'function' and fn() or nil
    for _, id in pairs(data and data.spells or {}) do
        id = tonumber(id)
        local spell = id and id ~= 512 and blu_res.spells and blu_res.spells[id] or nil
        local name = spell and (spell.en or spell.english)
        if name and name ~= '' then
            names[name] = true
            ids[#ids + 1] = id
        end
    end
    table.sort(ids)
    return names, ids
end

local profile_resource_cache = {}
local profile_analysis_cache = {}
local profile_install = {
    running=false,
    generation=0,
    key=nil,
    index=0,
    analysis=nil,
    cooldown_until=0,
}
local refresh_trait_cache
local invalidate_haste_cache
local update_native_haste_dw

local function blue_spell_resource(name)
    if profile_resource_cache[name] ~= nil then
        return profile_resource_cache[name] or nil
    end
    local spell
    if blu_res.spells and type(blu_res.spells.with) == 'function' then
        local ok, result = pcall(blu_res.spells.with, blu_res.spells, 'en', name)
        if ok then spell = result end
    end
    if not spell and blu_res.spells then
        for _, candidate in pairs(blu_res.spells) do
            if type(candidate) == 'table'
                and (candidate.en == name or candidate.english == name) then
                spell = candidate
                break
            end
        end
    end
    profile_resource_cache[name] = spell or false
    return spell
end

local function normalize_profile_name(value)
    return tostring(value or ''):lower():gsub('[^%w]','')
end

local function resolve_profile_key(value)
    local wanted = normalize_profile_name(value)
    if wanted == '' or wanted == 'manual' then return nil end
    for _, key in ipairs(BLU_PROFILE_ORDER) do
        local profile = BLU_SPELL_PROFILES[key]
        if wanted == normalize_profile_name(key)
            or wanted == normalize_profile_name(profile.label) then
            return key
        end
    end
end

local function analyze_spell_profile(key)
    if profile_analysis_cache[key] then return profile_analysis_cache[key] end
    local profile = BLU_SPELL_PROFILES[key]
    if not profile then return nil end
    local analysis = {key=key, total=0, slots=0, resources={}, invalid={}}
    for slot, name in ipairs(profile.spells) do
        local spell = blue_spell_resource(name)
        local points = spell and tonumber(spell.blu_points) or nil
        if not spell or spell.type ~= 'BlueMagic' or not points then
            analysis.invalid[#analysis.invalid + 1] = name
        else
            analysis.total = analysis.total + points
            analysis.resources[#analysis.resources + 1] = {
                id=spell.id,
                name=name,
                points=points,
                slot=slot,
            }
        end
    end
    analysis.slots = #profile.spells
    profile_analysis_cache[key] = analysis
    return analysis
end

local function learned_blue_spells()
    local fn = windower and windower.ffxi and windower.ffxi.get_spells
    if type(fn) ~= 'function' then return nil end
    local ok, learned = pcall(fn)
    return ok and type(learned) == 'table' and learned or nil
end

local function profile_unlearned_spells(analysis)
    local learned = learned_blue_spells()
    if not learned then return nil end
    local missing = {}
    for _, entry in ipairs(analysis.resources) do
        if learned[entry.id] ~= true and learned[entry.id] ~= 1 then
            missing[#missing + 1] = entry.name
        end
    end
    return missing
end

local function active_profile_matches(key)
    local profile = BLU_SPELL_PROFILES[key]
    if not profile then return false end
    local set_names = blue_set_spell_names()
    local count = 0
    for _ in pairs(set_names) do count = count + 1 end
    if count ~= #profile.spells then return false end
    for _, name in ipairs(profile.spells) do
        if not set_names[name] then return false end
    end
    return true
end

local function spell_profile_hud_status()
    if profile_install.running then
        return 'INSTALL '..tostring(profile_install.index)..'/'
            ..tostring(profile_install.analysis and profile_install.analysis.slots or '?')
    end
    local selected = state and state.SpellProfile and state.SpellProfile.value or 'Manual'
    local key = resolve_profile_key(selected)
    if not key then return 'Manual' end
    local status = key..(active_profile_matches(key) and ' (live)' or ' (selected)')
    local cooldown = math.max(0, math.ceil((profile_install.cooldown_until or 0) - os.clock()))
    return status..(cooldown > 0 and (' CD '..tostring(cooldown)..'s') or '')
end

local function report_spell_profile(key, include_spells)
    key = key or resolve_profile_key(state and state.SpellProfile and state.SpellProfile.value)
    if not key then
        chat(158, '[BLU Profile] Manual spell set selected.')
        chat(158, '  Use: gs c bluprofile list | preview <name> | apply <name>')
        return
    end
    local profile = BLU_SPELL_PROFILES[key]
    local analysis = analyze_spell_profile(key)
    local invalid = analysis and analysis.invalid or {}
    local unlearned = analysis and profile_unlearned_spells(analysis) or nil
    chat(#invalid == 0 and 158 or 123, string.format(
        '[BLU Profile] %s (%s): %d/%d points | %d/20 slots | live=%s',
        key, profile.label, analysis and analysis.total or 0, BLU_PROFILE_POINT_CAP,
        analysis and analysis.slots or 0, tostring(active_profile_matches(key))))
    chat(158, '  '..profile.focus)
    if #invalid > 0 then chat(123, '  invalid resources: '..table.concat(invalid, ', ')) end
    if unlearned == nil then
        chat(123, '  learned-spell validation unavailable; apply is disabled for safety.')
    elseif #unlearned > 0 then
        chat(123, '  not learned: '..table.concat(unlearned, ', '))
    end
    if include_spells then chat(158, '  spells: '..table.concat(profile.spells, ', ')) end
end

local function list_spell_profiles()
    chat(158, '[BLU Profile] Built-in profiles (all max-JP-safe at 75 points or less):')
    for _, key in ipairs(BLU_PROFILE_ORDER) do
        local profile = BLU_SPELL_PROFILES[key]
        local analysis = analyze_spell_profile(key)
        chat(158, string.format('  %-17s %2d pts / %2d slots - %s',
            key, analysis and analysis.total or 0, analysis and analysis.slots or 0, profile.label))
    end
end

local function cancel_profile_install(message)
    profile_install.generation = profile_install.generation + 1
    profile_install.running = false
    profile_install.key = nil
    profile_install.index = 0
    profile_install.analysis = nil
    if message then chat(123, '[BLU Profile] '..message) end
    if type(update_hud) == 'function' then update_hud(true) end
end

local function finish_profile_install(generation)
    if not profile_install.running or generation ~= profile_install.generation then return end
    local key = profile_install.key
    profile_install.running = false
    profile_install.cooldown_until = os.clock() + 60
    profile_install.index = 0
    profile_install.analysis = nil
    refresh_trait_cache(true)
    invalidate_haste_cache()
    update_native_haste_dw(true)
    chat(158, '[BLU Profile] '..key..' installed. Blue Magic cast cooldown: 60 seconds.')
    if type(update_hud) == 'function' then update_hud(true) end
end

local function install_profile_step(generation)
    if BLU_RUNTIME.unloading or not profile_install.running
        or generation ~= profile_install.generation then return end
    local analysis = profile_install.analysis
    local entry = analysis and analysis.resources[profile_install.index] or nil
    if not entry then
        finish_profile_install(generation)
        return
    end
    local fn = windower and windower.ffxi and windower.ffxi.set_blue_magic_spell
    local ok, result = pcall(fn, entry.id, entry.slot)
    if not ok or result == false then
        cancel_profile_install('Stopped at slot '..tostring(entry.slot)..' ('..entry.name..').')
        return
    end
    profile_install.index = profile_install.index + 1
    if type(update_hud) == 'function' then update_hud(true) end
    coroutine.schedule(function() install_profile_step(generation) end, 0.45)
end

local function apply_spell_profile(key)
    key = resolve_profile_key(key)
    if not key then chat(123, '[BLU Profile] Unknown profile. Use: gs c bluprofile list'); return false end
    if profile_install.running then
        chat(123, '[BLU Profile] An install is already running; use "gs c bluprofile cancel" first.')
        return false
    end
    if not player or player.main_job ~= 'BLU' or (tonumber(player.main_job_level) or 0) < 99 then
        chat(123, '[BLU Profile] Apply requires level 99 BLU as the current main job.')
        return false
    end
    if player.status == 'Engaged' or (type(midaction) == 'function' and midaction()) then
        chat(123, '[BLU Profile] Disengage and finish the current action before changing spells.')
        return false
    end
    local analysis = analyze_spell_profile(key)
    if not analysis or #analysis.invalid > 0 or analysis.total > BLU_PROFILE_POINT_CAP
        or analysis.slots > 20 or #analysis.resources ~= analysis.slots then
        chat(123, '[BLU Profile] Validation failed; no spells were changed.')
        report_spell_profile(key, false)
        return false
    end
    local unlearned = profile_unlearned_spells(analysis)
    if unlearned == nil or #unlearned > 0 then
        chat(123, '[BLU Profile] Learned-spell validation failed; no spells were changed.')
        report_spell_profile(key, false)
        return false
    end
    local reset_fn = windower and windower.ffxi and windower.ffxi.reset_blue_magic_spells
    local set_fn = windower and windower.ffxi and windower.ffxi.set_blue_magic_spell
    if type(reset_fn) ~= 'function' or type(set_fn) ~= 'function' then
        chat(123, '[BLU Profile] This Windower build does not expose the Blue Magic setting API.')
        return false
    end
    local ok, result = pcall(reset_fn)
    if not ok or result == false then
        chat(123, '[BLU Profile] Windower could not clear the current spell set; nothing else was attempted.')
        return false
    end
    state.SpellProfile:set(key)
    profile_install.generation = profile_install.generation + 1
    profile_install.running = true
    profile_install.key = key
    profile_install.index = 1
    profile_install.analysis = analysis
    profile_install.cooldown_until = os.clock() + 60
    local generation = profile_install.generation
    chat(158, string.format('[BLU Profile] Installing %s: %d points / %d slots.',
        key, analysis.total, analysis.slots))
    coroutine.schedule(function() install_profile_step(generation) end, 0.75)
    if type(update_hud) == 'function' then update_hud(true) end
    return true
end

local function select_spell_profile(direction)
    local current = resolve_profile_key(state and state.SpellProfile and state.SpellProfile.value)
    local index = 0
    for i, key in ipairs(BLU_PROFILE_ORDER) do if key == current then index = i; break end end
    if direction == 'previous' then
        index = index <= 1 and #BLU_PROFILE_ORDER or index - 1
    else
        index = index >= #BLU_PROFILE_ORDER and 1 or index + 1
    end
    local key = BLU_PROFILE_ORDER[index]
    state.SpellProfile:set(key)
    report_spell_profile(key, false)
    chat(158, '  Selection only; apply explicitly with: gs c bluprofile apply')
    if type(update_hud) == 'function' then update_hud(true) end
end

local function subjob_dw_value()
    local sub = player and player.sub_job or 'NON'
    local level = tonumber(player and player.sub_job_level) or 0
    if sub == 'NIN' then
        if level >= 85 then return 35 end
        if level >= 65 then return 30 end
        if level >= 45 then return 25 end
        if level >= 25 then return 15 end
        if level >= 10 then return 10 end
    elseif sub == 'DNC' then
        if level >= 80 then return 30 end
        if level >= 60 then return 25 end
        if level >= 40 then return 15 end
        if level >= 20 then return 10 end
    end
    return 0
end

local function subjob_fc_value()
    local sub = player and player.sub_job or 'NON'
    local level = tonumber(player and player.sub_job_level) or 0
    if sub == 'RDM' then
        if level >= 55 then return 20 end
        if level >= 35 then return 15 end
        if level >= 15 then return 10 end
    end
    return 0
end

refresh_trait_cache = function(force)
    local names, ids = blue_set_spell_names()
    local jp = runtime_jp_spent()
    local sub = player and player.sub_job or 'NON'
    local sublevel = tonumber(player and player.sub_job_level) or 0
    local signature = table.concat(ids, ',')..'|'..jp..'|'..sub..'|'..sublevel
    if not force and signature == trait_cache.signature then
        perf_count('trait_cache_hits')
        return false
    end

    local gift_tiers = jp >= 1200 and 2 or (jp >= 100 and 1 or 0)
    local points = {DualWield=0, FastCast=0}
    local contributors = {DualWield={}, FastCast={}}
    for trait, spell_points in pairs(TRAIT_SPELL_POINTS) do
        for name, value in pairs(spell_points) do
            if names[name] then
                points[trait] = points[trait] + value
                contributors[trait][#contributors[trait] + 1] = name..'+'..value
            end
        end
        table.sort(contributors[trait])
    end

    local dw_base = math.floor(points.DualWield / 8)
    local fc_base = math.floor(points.FastCast / 8)
    local dw_tier = dw_base > 0 and math.min(6, dw_base + gift_tiers) or 0
    local fc_tier = fc_base > 0 and math.min(6, fc_base + gift_tiers) or 0
    local blu_dw = DW_TIER_VALUE[dw_tier] or 0
    local blu_fc = BLU_FC_TIER_VALUE[fc_tier] or 0
    local sub_dw = subjob_dw_value()
    local sub_fc = subjob_fc_value()

    trait_cache.signature = signature
    trait_cache.jp_spent = jp
    trait_cache.gift_tiers = gift_tiers
    trait_cache.set_names = names
    trait_cache.contributors = contributors
    trait_cache.points = points
    trait_cache.blu_tier = {DualWield=dw_tier, FastCast=fc_tier}
    trait_cache.blu_value = {DualWield=blu_dw, FastCast=blu_fc}
    trait_cache.sub_value = {DualWield=sub_dw, FastCast=sub_fc}
    trait_cache.value = {
        DualWield=math.max(blu_dw, sub_dw),
        FastCast=math.max(blu_fc, sub_fc),
    }
    perf_count('trait_cache_rebuilds')
    return true
end

local function spell_is_set(name)
    refresh_trait_cache(false)
    return trait_cache.set_names[name] == true
end

-------------------------------------------------------------------------------------------------------------------
-- Native haste and adaptive Dual Wield
-------------------------------------------------------------------------------------------------------------------

local haste_cache = {dirty=true, magic=0}
local haste_manual_magic = 0
local native_haste = 0
local native_dw_trait = 0
local native_dw_need = 0
local native_dw_active = false
local dw_overlay = {}
local dw_overlay_need_cache = -1

local DW_CANDIDATES = {
    {slot='ear1', name='Eabani Earring',      dw=4, cost=3},
    {slot='ear2', name='Suppanomimi',          dw=5, cost=4},
    {slot='legs', name='Carmine Cuisses +1',  dw=6, cost=7},
    {slot='feet', name='Taeon Boots',          dw=4, cost=8},
}

local dw_plan = {}

local function build_dw_plan()
    for need = 0, 50 do
        local best
        for mask = 0, (2 ^ #DW_CANDIDATES) - 1 do
            local have, cost, selected = 0, 0, {}
            for i, candidate in ipairs(DW_CANDIDATES) do
                local bit = 2 ^ (i - 1)
                if math.floor(mask / bit) % 2 == 1 then
                    have = have + candidate.dw
                    cost = cost + candidate.cost
                    selected[candidate.slot] = candidate.name
                end
            end
            local shortfall = math.max(0, need - have)
            local excess = math.max(0, have - need)
            local score = shortfall * 10000 + excess * 50 + cost
            if not best or score < best.score then
                best = {score=score, have=have, set=selected, shortfall=shortfall}
            end
        end
        dw_plan[need] = best or {score=0, have=0, set={}, shortfall=need}
    end
end
build_dw_plan()

invalidate_haste_cache = function()
    haste_cache.dirty = true
end

local function refresh_magic_haste()
    if not haste_cache.dirty then
        perf_count('haste_cache_hits')
        return haste_cache.magic
    end
    local magic = 0
    if buffactive then
        if buffactive.Haste then
            local tier = state and state.HasteTier and tonumber(state.HasteTier.value) or 2
            magic = magic + (tier == 1 and 150 or 307)
        end
        local march_count = tonumber(buffactive.March) or (buffactive.March and 1 or 0)
        magic = magic + march_count * 170
        if buffactive.Embrava then magic = magic + 266 end
        if buffactive['Mighty Guard'] then magic = magic + 150 end
    end
    haste_cache.magic = math.min(448, math.max(0, magic + haste_manual_magic))
    haste_cache.dirty = false
    perf_count('haste_cache_rebuilds')
    return haste_cache.magic
end

local WEAPON_PROFILE_ORDER = {
    'NaeglingSakpata','MaxentiusSakpata','BunziSors','SakpataSors',
    'NaeglingEmpty','MaxentiusEmpty','LearnLv1',
}
local WEAPON_PROFILE_META = {
    NaeglingSakpata={dual=true,fallback='NaeglingEmpty',label="Naegling / Sakpata",ws='Savage Blade',role='primary sword TP / Savage Blade'},
    MaxentiusSakpata={dual=true,fallback='MaxentiusEmpty',label='Maxentius / Sakpata',ws='Black Halo',role='club TP / Black Halo'},
    BunziSors={dual=false,label="Bunzi's Rod / Sors",ws='Black Halo',role='magic burst / healing'},
    SakpataSors={dual=false,label="Sakpata / Sors",ws='Savage Blade',role='defensive fast casting / shield utility'},
    NaeglingEmpty={dual=false,label='Naegling / Empty',ws='Savage Blade',role='single-wield sword / no DW trait'},
    MaxentiusEmpty={dual=false,label='Maxentius / Empty',ws='Black Halo',role='single-wield club / no DW trait'},
    LearnLv1={dual=true,fallback='LearnSingle',label="Twinned / Kam'lanaut",ws=nil,role='minimum-damage spell learning'},
    LearnSingle={dual=false,label='Twinned / Empty',ws=nil,role='minimum-damage spell learning fallback'},
}
local WEAPON_PROFILE_ALIASES = {
    naegling='NaeglingSakpata', savage='NaeglingSakpata', sword='NaeglingSakpata',
    maxentius='MaxentiusSakpata', blackhalo='MaxentiusSakpata', club='MaxentiusSakpata',
    bunzi='BunziSors', caster='BunziSors', magic='BunziSors', heal='BunziSors',
    sakpata='SakpataSors', defense='SakpataSors',
    naeglingempty='NaeglingEmpty', maxentiusempty='MaxentiusEmpty',
    learn='LearnLv1', learning='LearnLv1', lv1='LearnLv1',
}
local BLU_DEFENSE_ORDER = {'Normal','DT','MEVA'}

local function selected_profile_is_dual()
    local name = state and state.WeaponSet and state.WeaponSet.value
    local meta = name and WEAPON_PROFILE_META[name]
    return meta and meta.dual or false
end

local function dw_needed_at_haste(haste)
    if haste >= 819 then return 0 end
    return math.ceil((1 - 0.2 / ((1024 - haste) / 1024)) * 100)
end

update_native_haste_dw = function(force)
    local started = perf_begin()
    local trait_changed = refresh_trait_cache(false)
    local dual = selected_profile_is_dual()
    local active = dual and trait_cache.value.DualWield > 0
        and player and player.status == 'Engaged' or false
    local gear_haste = player and player.status == 'Engaged' and 256 or 0
    local total_haste = math.min(819, gear_haste + refresh_magic_haste())
    local trait = trait_cache.value.DualWield
    local total_dw = active and dw_needed_at_haste(total_haste) or 0
    local need = active and math.max(0, total_dw - trait) or 0
    local changed = force or trait_changed or active ~= native_dw_active
        or total_haste ~= native_haste or trait ~= native_dw_trait or need ~= native_dw_need

    native_dw_active = active
    native_haste = total_haste
    native_dw_trait = trait
    native_dw_need = need
    if changed then dw_overlay_need_cache = -1 end
    perf_finish('native_haste_dw', started)
    return changed
end

local function update_dw_overlay()
    local need = native_dw_active and math.max(0, native_dw_need) or 0
    if need == dw_overlay_need_cache then
        perf_count('dw_overlay_hits')
        return dw_overlay
    end
    local plan = dw_plan[math.min(50, need)] or {set={}, have=0, shortfall=need}
    dw_overlay = {}
    for slot, item in pairs(plan.set) do dw_overlay[slot] = item end
    dw_overlay_need_cache = need
    perf_count('dw_overlay_rebuilds')
    return dw_overlay
end

local function dw_plan_current()
    return dw_plan[math.min(50, math.max(0, native_dw_need))]
        or {set={}, have=0, shortfall=native_dw_need}
end

-------------------------------------------------------------------------------------------------------------------
-- Protected warp/dimension/boost rings and full-slot freeze ownership
-------------------------------------------------------------------------------------------------------------------

local WARP_GEAR = {
    ['Warp Ring']=true, ['Dim. Ring (Dem)']=true, ['Dim. Ring (Holla)']=true,
    ['Dim. Ring (Mea)']=true,
}
local BOOST_GEAR = {
    ['Trizek Ring']=true, ['Echad Ring']=true, ['Facility Ring']=true,
    ['Capacity Ring']=true, ['Jubilee Ring']=true, ['Empress Band']=true,
}
local NO_SWAP_GEAR = {}
for name in pairs(WARP_GEAR) do NO_SWAP_GEAR[name] = true end
for name in pairs(BOOST_GEAR) do NO_SWAP_GEAR[name] = true end
local BOOST_BUFFS = {dedication=true, commitment=true}
local releasing = {ring1=false, ring2=false}
local ring_lock_state = {ring1=nil, ring2=nil}

local function current_ring_name(slot)
    local equipment = player and player.equipment
    if not equipment then return nil end
    return slot == 'ring1' and (equipment.left_ring or equipment.ring1)
        or (equipment.right_ring or equipment.ring2)
end

local function invalidate_ring_lock_cache()
    ring_lock_state.ring1 = nil
    ring_lock_state.ring2 = nil
end

local function apply_ring_lock(slot, should_lock)
    if ring_lock_state[slot] == should_lock then return end
    if should_lock then disable(slot) else enable(slot) end
    ring_lock_state[slot] = should_lock
end

local function protected_ring_check()
    if not state then return end
    if state.PauseSwaps and state.PauseSwaps.value then return end
    if buffactive and buffactive.doom then return end
    apply_ring_lock('ring1',
        NO_SWAP_GEAR[current_ring_name('ring1')] == true and not releasing.ring1)
    apply_ring_lock('ring2',
        NO_SWAP_GEAR[current_ring_name('ring2')] == true and not releasing.ring2)
end

local function settle_released_ring_slots(slots)
    local token = BLU_RUNTIME.token
    coroutine.schedule(function()
        if BLU_RUNTIME.unloading or token ~= BLU_RUNTIME.token then return end
        for _, slot in ipairs(slots or {}) do releasing[slot] = false end
        protected_ring_check()
    end, 1)
end

local function release_protected_ring_slots(slots, reason)
    if not slots or #slots == 0 then return end
    for _, slot in ipairs(slots) do
        releasing[slot] = true
        ring_lock_state[slot] = false
        enable(slot)
    end
    if reason then chat(158, '[BLU Rings] Releasing protected ring: '..reason) end
    if not (state and state.PauseSwaps and state.PauseSwaps.value)
        and type(handle_equipping_gear) == 'function' and player then
        handle_equipping_gear(player.status)
    end
    settle_released_ring_slots(slots)
end

local function apply_fishing_slot_policy()
    if pause_swaps_active() then disable(unpack(ALL_EQUIP_SLOTS)); return end
    if not fishing_mode_active() then return end
    disable(unpack(FISHING_LOCK_SLOTS))
    if buffactive and buffactive.doom then disable('ring1','ring2'); return end
    enable('ring1','ring2'); invalidate_ring_lock_cache(); protected_ring_check()
end

local function clear_fishing_rod()
    enable('range'); equip({range=empty})
end

local function reapply_runtime_locks()
    if pause_swaps_active() then disable(unpack(ALL_EQUIP_SLOTS)); return end
    enable(unpack(ALL_EQUIP_SLOTS)); invalidate_ring_lock_cache()
    if state and state.WeaponLock and state.WeaponLock.value then disable('main','sub') end
    if fishing_mode_active() then apply_fishing_slot_policy() end
    if buffactive and buffactive.doom and sets and sets.buff and sets.buff.Doom then
        enable('neck','ring1','ring2','waist'); equip(sets.buff.Doom); disable('neck','ring1','ring2','waist'); return
    end
    protected_ring_check()
end

-------------------------------------------------------------------------------------------------------------------
-- Treasure Hunter: Off / first-action Tag / Fulltime, tracked per target.
-------------------------------------------------------------------------------------------------------------------

local th_tracker = {target_id=nil, tagged=false, pending_target_id=nil}

local function current_target_mob()
    local fn = windower and windower.ffxi and windower.ffxi.get_mob_by_target
    return type(fn) == 'function' and fn('t') or nil
end

local function th_sync_target()
    if not state or not state.TreasureMode then return nil end
    local mob = current_target_mob()
    local id = mob and mob.id or nil
    if id ~= th_tracker.target_id then
        th_tracker.target_id = id
        th_tracker.tagged = false
        th_tracker.pending_target_id = nil
    end
    return id
end

local function th_should_apply(target_id)
    if not state or not state.TreasureMode then return false end
    local mode = state.TreasureMode.value
    if mode == 'Off' then return false end
    if mode == 'Fulltime' then return true end
    if mode ~= 'Tag' then return false end
    th_sync_target()
    if target_id and target_id ~= th_tracker.target_id then
        th_tracker.target_id = target_id
        th_tracker.tagged = false
        th_tracker.pending_target_id = nil
    end
    return target_id ~= nil and not th_tracker.tagged
end

local function th_mark_tagged(target_id, source)
    if not target_id or not state or not state.TreasureMode
        or state.TreasureMode.value ~= 'Tag' then return end
    if target_id ~= th_tracker.target_id or th_tracker.tagged then return end
    th_tracker.tagged = true
    th_tracker.pending_target_id = nil
    chat(158, '[BLU TH] Target tagged'..(source and (' via '..source) or '')
        ..'; combat gear restored.')
    if not BLU_RUNTIME.unloading and not midaction()
        and type(handle_equipping_gear) == 'function' and player then
        handle_equipping_gear(player.status)
    end
end

local function th_action_overlay(spell)
    if not spell or not spell.target or spell.target.type ~= 'MONSTER' then return false end
    if not th_should_apply(spell.target.id) then return false end
    th_tracker.pending_target_id = spell.target.id
    return true
end

local function reset_th_tracker(verbose)
    th_tracker.target_id = nil
    th_tracker.tagged = false
    th_tracker.pending_target_id = nil
    th_sync_target()
    if verbose then chat(158, '[BLU TH] Tag state reset for current target.') end
end

-------------------------------------------------------------------------------------------------------------------
-- WS distance safety
-------------------------------------------------------------------------------------------------------------------

local WS_RANGE_MULT = {
    [0]=0, [2]=1.70, [3]=1.490909, [4]=1.44, [5]=1.377778, [6]=1.30,
    [7]=1.20, [8]=1.30, [9]=1.377778, [10]=1.45, [11]=1.490909, [12]=1.70,
}

local function ws_max_distance(spell)
    local range = spell and tonumber(spell.range)
    local mult = range and WS_RANGE_MULT[range]
    if not mult or not spell.target then return nil end
    return (tonumber(spell.target.model_size) or 0) + range * mult
end

local function ws_out_of_range(spell)
    if not spell or spell.type ~= 'WeaponSkill' or not spell.target
        or spell.target.type ~= 'MONSTER' then return false, nil end
    local actual = tonumber(spell.target.distance)
    local maximum = ws_max_distance(spell)
    if not actual or not maximum then return false, maximum end
    return actual > maximum + 0.20, maximum
end

-------------------------------------------------------------------------------------------------------------------
-- Target-specific Auto Magic Burst window
--
-- Magical Blue Magic can burst only while Burst Affinity or Azure Lore enables it. Manual MagicBurst
-- is an explicit gear override; AutoBurst additionally validates affinity, target, element, and expiry.
-------------------------------------------------------------------------------------------------------------------

local SC_BURST_ELEMENTS = {
    Liquefaction={Fire=true}, Scission={Earth=true}, Reverberation={Water=true},
    Detonation={Wind=true}, Induration={Ice=true}, Impaction={Lightning=true},
    Transfixion={Light=true}, Compression={Dark=true},
    Fusion={Fire=true,Light=true}, Fragmentation={Wind=true,Lightning=true},
    Gravitation={Earth=true,Dark=true}, Distortion={Ice=true,Water=true},
    Light={Fire=true,Wind=true,Lightning=true,Light=true},
    Darkness={Ice=true,Earth=true,Water=true,Dark=true},
    Radiance={Fire=true,Wind=true,Lightning=true,Light=true},
    Umbra={Ice=true,Earth=true,Water=true,Dark=true},
}

local SC_MESSAGES = {
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

local SC_BURST_LABEL = {}
for name, elements in pairs(SC_BURST_ELEMENTS) do
    local list = {}
    for element in pairs(elements) do list[#list + 1] = element end
    table.sort(list)
    SC_BURST_LABEL[name] = table.concat(list, '/')
end

local sc_window = {name=nil, target_id=nil, expires=0}

local function clear_burst_window()
    sc_window.name = nil
    sc_window.target_id = nil
    sc_window.expires = 0
end

local function burst_target_exists(target_id)
    if not target_id then return false end
    local fn = windower and windower.ffxi and windower.ffxi.get_mob_by_id
    if type(fn) ~= 'function' then return true end
    local mob = fn(target_id)
    if not mob then return false end
    return not (mob.hpp ~= nil and tonumber(mob.hpp) and tonumber(mob.hpp) <= 0)
end

local function auto_burst_affinity_active()
    return buffactive and (buffactive['Burst Affinity'] or buffactive['Azure Lore']) or false
end

local function burst_window_active(spell)
    if sc_window.expires <= os.clock() then
        clear_burst_window()
        return false
    end
    if not burst_target_exists(sc_window.target_id) then
        clear_burst_window()
        return false
    end
    if not spell or not spell.target or spell.target.id ~= sc_window.target_id then return false end
    local elements = SC_BURST_ELEMENTS[sc_window.name]
    return elements and elements[spell.element] == true or false
end

local function handle_skillchain_action(act)
    if not state or not state.AutoBurst or not state.AutoBurst.value
        or not act or not act.targets then return end
    local packet_seen, packet_now
    for _, target in pairs(act.targets) do
        if target and target.actions then
            for _, action in pairs(target.actions) do
                local chain = action.has_add_effect and SC_MESSAGES[action.add_effect_message]
                if chain and target.id then
                    packet_seen = packet_seen or {}
                    local key = tostring(target.id)..':'..chain
                    if not packet_seen[key] then
                        packet_seen[key] = true
                        packet_now = packet_now or os.clock()
                        sc_window.name = chain
                        sc_window.target_id = target.id
                        sc_window.expires = packet_now + 10
                        chat(158, '[BLU AutoMB] '..chain..' window ('
                            ..(SC_BURST_LABEL[chain] or '?')..', ~10s).')
                    end
                end
            end
        end
    end
end

-------------------------------------------------------------------------------------------------------------------
-- Safe Unbridled Learning convenience
--
-- If an Unbridled spell is requested without Unbridled Learning/Wisdom/Azure Lore, the original
-- cast is canceled, UL is used once if ready, then the exact spell/target is reissued. All delayed
-- work carries both runtime and generation tokens, and one failed JA never creates a retry loop.
-------------------------------------------------------------------------------------------------------------------

local unbridled_ctl = {pending=nil, generation=0}

local function ability_recast_remaining(name)
    local ability = blu_res.job_abilities and blu_res.job_abilities:with('en', name)
    local fn = windower and windower.ffxi and windower.ffxi.get_ability_recasts
    if not ability or type(fn) ~= 'function' then return math.huge end
    local recasts = fn() or {}
    return tonumber(recasts[ability.recast_id]) or math.huge
end

local function unbridled_access_active()
    return buffactive and (buffactive['Unbridled Learning']
        or buffactive['Unbridled Wisdom'] or buffactive['Azure Lore']) or false
end

local function safe_spell_target(spell)
    if spell and spell.target and spell.target.raw and spell.target.raw ~= '' then
        return spell.target.raw
    end
    return spell and spell.target and spell.target.type == 'SELF' and '<me>' or '<t>'
end

local function prepare_unbridled_spell(spell, eventArgs)
    if not spell or not UNBRIDLED_SPELLS[spell.english]
        or not state or not state.AutoUnbridled or not state.AutoUnbridled.value
        or unbridled_access_active() then return false end
    if unbridled_ctl.pending then
        chat(123, '[BLU Unbridled] A protected cast is already pending.')
        cancel_spell()
        if eventArgs then eventArgs.cancel=true; eventArgs.handled=true end
        return true
    end
    local recast = ability_recast_remaining('Unbridled Learning')
    if recast ~= 0 then
        chat(123, string.format('[BLU Unbridled] UL is not ready (%ss); normal game error allowed.',
            recast == math.huge and '?' or tostring(math.ceil(recast))))
        return false
    end

    unbridled_ctl.generation = unbridled_ctl.generation + 1
    local generation = unbridled_ctl.generation
    unbridled_ctl.pending = {
        spell=spell.english,
        target=safe_spell_target(spell),
        generation=generation,
    }
    cancel_spell()
    if eventArgs then eventArgs.cancel=true; eventArgs.handled=true end
    chat(158, '[BLU Unbridled] Priming '..spell.english..' with Unbridled Learning.')
    send_command(string.format(
        'input /ja "Unbridled Learning" <me>; wait 1.50; gs c _unbridledcast %s %d',
        BLU_RUNTIME.token, generation))
    return true
end

local function execute_pending_unbridled(token, generation)
    local pending = unbridled_ctl.pending
    if BLU_RUNTIME.unloading or token ~= BLU_RUNTIME.token or not pending
        or tonumber(generation) ~= pending.generation then return end
    unbridled_ctl.pending = nil
    if not unbridled_access_active() then
        chat(123, '[BLU Unbridled] UL did not activate; protected cast was not reissued.')
        return
    end
    windower.chat.input('/ma "'..pending.spell..'" '..pending.target)
end

-------------------------------------------------------------------------------------------------------------------
-- Bounded Silence recovery
-------------------------------------------------------------------------------------------------------------------

local silence_echo = {attempts=0, active=false, generation=0}

local function try_echo_drops(generation)
    if BLU_RUNTIME.unloading or generation ~= silence_echo.generation then return end
    if not (buffactive and buffactive.silence) then
        silence_echo.active = false
        silence_echo.attempts = 0
        return
    end
    if silence_echo.attempts >= 3 then
        silence_echo.active = false
        chat(123, '[BLU Safety] Echo Drops cap (3) reached; silence resisted item removal.')
        return
    end
    silence_echo.attempts = silence_echo.attempts + 1
    send_command('input /item "Echo Drops" <me>')
    chat(123, string.format('[BLU Safety] Silenced: Echo Drops %d/3.',
        silence_echo.attempts))
    local token = BLU_RUNTIME.token
    coroutine.schedule(function()
        if BLU_RUNTIME.unloading or token ~= BLU_RUNTIME.token then return end
        try_echo_drops(generation)
    end, 4)
end

-------------------------------------------------------------------------------------------------------------------
-- Optional GearInfo comparison heartbeat. Native BLU math/movement remain authoritative.
-------------------------------------------------------------------------------------------------------------------

local moving = false
local gearinfo_last = nil
local gi_haste = 0
local gi_dw_need = 0
local GEARINFO_STALE_SECONDS = 12
local movement_monitor = {
    sample_interval=0.15,
    stop_debounce=0.45,
    distance_squared=0.01,
    next_sample=0,
    last_motion_at=0,
    x=nil,y=nil,z=nil,
    refresh_pending=false,
    refresh_queued=false,
    last_route_label=nil,
}

local function handle_gearinfo_command(cmdParams)
    if not cmdParams or (cmdParams[1] or ''):lower() ~= 'gearinfo' then return false end
    local new_dw = tonumber(cmdParams[2])
    local dw_inactive = cmdParams[2] == 'false'
    local new_haste = tonumber(cmdParams[3])
    if (not new_dw and not dw_inactive) or not new_haste then return true end
    gearinfo_last = os.clock()
    gi_dw_need = new_dw or 0
    gi_haste = new_haste
    -- cmdParams[4] may contain GearInfo movement, but v2.0 intentionally ignores it.
    return true
end

-------------------------------------------------------------------------------------------------------------------
-- Weapon policy and compact current-core controls
-------------------------------------------------------------------------------------------------------------------

local function normalized_equipped_sub()
    local sub = player and player.equipment and (player.equipment.sub or player.equipment.left_sub)
    if not sub or sub == '' or sub == 'empty' then return 'empty' end
    return sub
end

local function weapon_profile_label(key)
    local meta=WEAPON_PROFILE_META[key]
    return meta and meta.label or tostring(key or '?')
end

local function weapon_profile_effective_key()
    local key=state and state.WeaponSet and state.WeaponSet.value
    local meta=key and WEAPON_PROFILE_META[key]
    if meta and meta.dual then
        refresh_trait_cache(false)
        if trait_cache.value.DualWield == 0 then return meta.fallback or key end
    end
    return key
end

local warned_no_dw_weapon=false

local function check_weaponset(force)
    if not sets or not sets.weapons or not state or not state.WeaponSet then return end
    if swaps_frozen() then return end
    local selected = state.WeaponSet.value
    local effective = weapon_profile_effective_key()
    local desired = effective and sets.weapons[effective]
    if not desired then return end
    if effective ~= selected then
        if not warned_no_dw_weapon then
            warned_no_dw_weapon=true
            chat(123,'[BLU Weapons] '..weapon_profile_label(selected)..' requires a live Dual Wield trait; using '..weapon_profile_label(effective)..'.')
        end
    else
        warned_no_dw_weapon=false
    end
    local equipment=player and player.equipment or {}
    local desired_sub=desired.sub==empty and 'empty' or item_name(desired.sub)
    local mismatch=item_name(equipment.main)~=item_name(desired.main)
        or normalized_equipped_sub()~=(desired_sub or 'empty')
    if not force and not mismatch then return end
    enable('main','sub')
    if mismatch then equip(desired) end
    if state.WeaponLock.value then disable('main','sub') end
end

local function normalize_control_token(value)
    return tostring(value or ''):lower():gsub('[%s%p_]+','')
end

local function ordered_index(order,value)
    for i,v in ipairs(order) do if v==value then return i end end
    return 0
end

local function apply_weapon_profile(requested,quiet)
    local key=WEAPON_PROFILE_META[requested] and requested
        or WEAPON_PROFILE_ALIASES[normalize_control_token(requested)]
    if not key or not sets or not sets.weapons or not sets.weapons[key] then
        local labels={}
        for _,k in ipairs(WEAPON_PROFILE_ORDER) do labels[#labels+1]=weapon_profile_label(k) end
        chat(158,'[BLU Weapon] '..table.concat(labels,' -> '))
        return false
    end
    state.WeaponSet:set(key)
    check_weaponset(true)
    invalidate_haste_cache()
    update_native_haste_dw(true)
    if not midaction() and type(handle_equipping_gear)=='function' and player then handle_equipping_gear(player.status) end
    if type(update_hud)=='function' then update_hud(true) end
    if not quiet then
        local meta=WEAPON_PROFILE_META[key]
        chat(158,'[BLU Weapon] '..meta.label..' | '..meta.role..(meta.ws and (' | primary '..meta.ws) or ''))
    end
    return true
end

local function cycle_weapon_profile(direction)
    local current=state and state.WeaponSet and state.WeaponSet.value
    local i=ordered_index(WEAPON_PROFILE_ORDER,current)
    local step=(direction=='previous' or direction=='prev' or direction=='back') and -1 or 1
    if i==0 then i=step>0 and 0 or 1 end
    i=((i-1+step)%#WEAPON_PROFILE_ORDER)+1
    return apply_weapon_profile(WEAPON_PROFILE_ORDER[i])
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
        chat(158,'[BLU Defense] Normal -> DT -> MEVA | gs c bludefense <normal|dt|meva>')
        return false
    end
    if key=='Normal' then
        state.DefenseMode:set('None')
    elseif key=='DT' then
        if state.PhysicalDefenseMode then state.PhysicalDefenseMode:set('PDT') end
        state.DefenseMode:set('Physical')
    else
        if state.MagicalDefenseMode then state.MagicalDefenseMode:set('MEVA') end
        state.DefenseMode:set('Magical')
    end
    if not swaps_frozen() and not midaction() and type(handle_equipping_gear)=='function' and player then
        handle_equipping_gear(player.status)
    end
    if type(update_hud)=='function' then update_hud(true) end
    if not quiet then chat(158,'[BLU Defense] '..key) end
    return true
end

local function cycle_defense_control()
    local i=ordered_index(BLU_DEFENSE_ORDER,defense_control_mode())
    i=(i%#BLU_DEFENSE_ORDER)+1
    return apply_defense_control(BLU_DEFENSE_ORDER[i])
end

local function resolve_context_weaponskill()
    local main=item_name(player and player.equipment and player.equipment.main)
    if main=='Naegling' or main=="Sakpata's Sword" then return 'Savage Blade' end
    if main=='Maxentius' or main=="Bunzi's Rod" then return 'Black Halo' end
    return nil
end

local function execute_context_weaponskill()
    local ws=resolve_context_weaponskill()
    if not ws then chat(123,'[BLU F12] No primary WS for the live main hand.'); return false end
    if (tonumber(player and player.tp) or 0)<1000 then
        chat(123,'[BLU F12] Need 1000 TP for '..ws..'.')
        return false
    end
    local get_target=windower and windower.ffxi and windower.ffxi.get_mob_by_target
    local target=type(get_target)=='function' and get_target('t') or nil
    if not target or (target.hpp and tonumber(target.hpp)<=0) then
        chat(123,'[BLU F12] No valid living <t> target.')
        return false
    end
    send_command('@input /ws "'..ws..'" <t>')
    return true
end

-------------------------------------------------------------------------------------------------------------------
-- Persistent BLU command-center HUD (RDM v2.61 / WAR v3.3.8 presentation model)
-------------------------------------------------------------------------------------------------------------------

local blu_hud=nil
local blu_hud_visible=true
local blu_hud_cache={key=nil}
local BLU_HUD_FILE='data/Falurian_BLU_HUD.xml'
local BLU_HUD_CACHE_KEY='__falurian_blu_hud_preferences_v1'
local BLU_HUD_SECTIONS={'loadout','combat','magic','utility','shortcuts'}
local BLU_HUD_DEFAULT={schema=1,x=675,y=950,layout='expanded',scale=1.0,opacity=205,visible=true,
    sections={loadout=true,combat=true,magic=true,utility=true,shortcuts=true}}
local blu_hud_config_lib=nil
local blu_hud_preferences=nil
local blu_hud_drag_generation=0
local blu_hud_drag_pending=false
local blu_hud_settings={pos={x=675,y=950},text={size=11,font='Consolas',alpha=255,
    stroke={width=2,alpha=255,red=0,green=0,blue=0}},bg={alpha=205,red=8,green=10,blue=14},flags={draggable=false}}
local blu_hud_config={layout='expanded',scale=1.0,opacity=205,
    sections={loadout=true,combat=true,magic=true,utility=true,shortcuts=true}}
local blu_hud_colors={label='\\cs(205,210,220)',value='\\cs(248,248,250)',section='\\cs(120,205,255)',
    cyan='\\cs(105,210,235)',green='\\cs(115,225,145)',yellow='\\cs(245,210,100)',
    orange='\\cs(245,165,90)',red='\\cs(255,105,115)',dim='\\cs(135,140,150)'}

local function hud_num(v,fallback,lo,hi)
    local n=tonumber(v); if not n or n~=n then n=fallback end
    if lo and n<lo then n=lo end; if hi and n>hi then n=hi end; return n
end

local function load_blu_hud_preferences()
    local ok,cfg=pcall(require,'config'); if not ok or not cfg then return false end
    local loaded=type(windower)=='table' and rawget(windower,BLU_HUD_CACHE_KEY) or nil
    if type(loaded)=='table' then pcall(cfg.reload,loaded) else
        local ok2,result=pcall(cfg.load,BLU_HUD_FILE,BLU_HUD_DEFAULT)
        if not ok2 or type(result)~='table' then return false end
        loaded=result; if type(windower)=='table' then rawset(windower,BLU_HUD_CACHE_KEY,loaded) end
    end
    blu_hud_config_lib=cfg; blu_hud_preferences=loaded
    local layout=tostring(loaded.layout or ''):lower()
    blu_hud_config.layout=(layout=='compact' or layout=='expanded') and layout or 'expanded'
    blu_hud_config.scale=hud_num(loaded.scale,1.0,0.70,1.60)
    blu_hud_config.opacity=math.floor(hud_num(loaded.opacity,205,0,255)+0.5)
    blu_hud_visible=type(loaded.visible)=='boolean' and loaded.visible or true
    local sec=type(loaded.sections)=='table' and loaded.sections or {}
    for _,name in ipairs(BLU_HUD_SECTIONS) do
        blu_hud_config.sections[name]=type(sec[name])=='boolean' and sec[name] or true
    end
    blu_hud_settings.pos.x=math.floor(hud_num(loaded.x,675,-20000,20000)+0.5)
    blu_hud_settings.pos.y=math.floor(hud_num(loaded.y,950,-20000,20000)+0.5)
    blu_hud_settings.flags.draggable=false
    return true
end

local function current_blu_hud_position()
    local x,y=blu_hud_settings.pos.x,blu_hud_settings.pos.y
    if blu_hud and type(blu_hud.pos)=='function' then
        local ok,a,b=pcall(blu_hud.pos,blu_hud)
        if ok and tonumber(a) and tonumber(b) then x,y=tonumber(a),tonumber(b) end
    end
    blu_hud_settings.pos.x,blu_hud_settings.pos.y=math.floor(x+0.5),math.floor(y+0.5)
    return blu_hud_settings.pos.x,blu_hud_settings.pos.y
end

save_blu_hud_preferences=function(silent)
    if not blu_hud_config_lib or not blu_hud_preferences then return false end
    local x,y=current_blu_hud_position(); local p=blu_hud_preferences
    p.schema=1;p.x=x;p.y=y;p.layout=blu_hud_config.layout;p.scale=blu_hud_config.scale
    p.opacity=blu_hud_config.opacity;p.visible=blu_hud_visible
    if type(p.sections)~='table' then p.sections={} end
    for _,name in ipairs(BLU_HUD_SECTIONS) do p.sections[name]=blu_hud_config.sections[name]~=false end
    return pcall(blu_hud_config_lib.save,p)
end

local function queue_blu_hud_save()
    blu_hud_drag_generation=blu_hud_drag_generation+1
    if blu_hud_drag_pending then return end
    blu_hud_drag_pending=true
    local function settle()
        local generation=blu_hud_drag_generation
        coroutine.schedule(function()
            if BLU_RUNTIME.unloading then blu_hud_drag_pending=false; return end
            if generation~=blu_hud_drag_generation then settle(); return end
            blu_hud_drag_pending=false; save_blu_hud_preferences(true)
        end,0.60)
    end
    settle()
end

local function blu_hud_call(method,...)
    if not blu_hud or type(blu_hud[method])~='function' then return false end
    return pcall(blu_hud[method],blu_hud,...)
end

local function apply_blu_hud_style()
    blu_hud_call('size',math.max(8,math.floor(11*blu_hud_config.scale+0.5)))
    blu_hud_call('bg_alpha',blu_hud_config.opacity)
    blu_hud_call('bg_color',8,10,14)
    blu_hud_cache.key=nil
end

local function hcol(name,value) return (blu_hud_colors[name] or '')..tostring(value or '')..'\\cr' end
local function hfield(label,value,color) return hcol('label',label..': ')..hcol(color or 'value',value) end
local function hrow(label,content) return hcol('section',string.format('%-11s',label))..content end
local function section_on(name) return blu_hud_config.sections[name]~=false end

local function burst_hud_status()
    if state and state.MagicBurst and state.MagicBurst.value then return 'MANUAL' end
    if not state or not state.AutoBurst or not state.AutoBurst.value then return 'OFF' end
    if sc_window.name and sc_window.expires > os.clock() then return sc_window.name end
    return 'READY'
end

local function affinity_hud_status()
    local active={}
    for _,name in ipairs({'Chain Affinity','Burst Affinity','Efflux','Convergence','Diffusion',
        'Unbridled Learning','Unbridled Wisdom','Azure Lore'}) do
        if buffactive and buffactive[name] then active[#active+1]=name end
    end
    return #active>0 and table.concat(active,', ') or 'none'
end

local function set_stat_total(set,field)
    local total=0
    if type(set)~='table' or type(item_stat)~='function' then return total end
    for _,slot in ipairs(ALL_EQUIP_SLOTS) do
        local name=item_name(set[slot])
        if name and name~='empty' then total=total+(tonumber(item_stat(name,field)) or 0) end
    end
    return total
end

local function live_precast_fc_gear()
    local total=set_stat_total(sets and sets.precast and sets.precast.FC,'fc')
    if type(item_stat)~='function' then return total end
    local eq=player and player.equipment or {}
    total=total+(tonumber(item_stat(item_name(eq.main),'fc')) or 0)
    total=total+(tonumber(item_stat(item_name(eq.sub),'fc')) or 0)
    return total
end

function init_hud()
    load_blu_hud_preferences()
    local ok,texts=pcall(require,'texts')
    if not ok or not texts then chat(123,'[BLU HUD] texts library unavailable.'); return end
    blu_hud=texts.new('',blu_hud_settings)
    if type(blu_hud.register_event)=='function' then
        pcall(blu_hud.register_event,blu_hud,'drag',function(x,y)
            if tonumber(x) and tonumber(y) then blu_hud_settings.pos.x=tonumber(x); blu_hud_settings.pos.y=tonumber(y) end
            queue_blu_hud_save()
        end)
    end
    apply_blu_hud_style(); update_hud(true); if blu_hud_visible then blu_hud:show() end
end

local function toggle_hud()
    if not blu_hud then return end
    blu_hud_visible=not blu_hud_visible; save_blu_hud_preferences(true)
    if blu_hud_visible then update_hud(true); blu_hud:show() else blu_hud:hide() end
end

local function toggle_hud_lock()
    if not blu_hud then return end
    local was=blu_hud:draggable(); blu_hud:draggable(not was)
    if was then save_blu_hud_preferences(true) end
    chat(158,was and '[BLU HUD] Position locked.' or '[BLU HUD] Position unlocked; drag to move.')
end

local function set_hud_layout(value)
    local layout=tostring(value or ''):lower()
    if layout~='compact' and layout~='expanded' then chat(158,'[BLU HUD] hudlayout compact|expanded'); return end
    blu_hud_config.layout=layout; save_blu_hud_preferences(true); update_hud(true)
end

local function set_hud_scale(value)
    blu_hud_config.scale=hud_num(value,blu_hud_config.scale,0.70,1.60)
    apply_blu_hud_style(); save_blu_hud_preferences(true); update_hud(true)
end

local function set_hud_opacity(value)
    blu_hud_config.opacity=math.floor(hud_num(value,blu_hud_config.opacity,0,255)+0.5)
    apply_blu_hud_style(); save_blu_hud_preferences(true); update_hud(true)
end

local function set_hud_section(name,value)
    name=tostring(name or ''):lower(); if blu_hud_config.sections[name]==nil then
        chat(158,'[BLU HUD] sections: '..table.concat(BLU_HUD_SECTIONS,', ')); return
    end
    local token=tostring(value or 'toggle'):lower()
    if token=='toggle' then blu_hud_config.sections[name]=not blu_hud_config.sections[name]
    elseif token=='on' or token=='true' or token=='1' then blu_hud_config.sections[name]=true
    elseif token=='off' or token=='false' or token=='0' then blu_hud_config.sections[name]=false
    else chat(158,'[BLU HUD] hudsection <name> on|off|toggle'); return end
    save_blu_hud_preferences(true); update_hud(true)
end

function update_hud(force)
    if not blu_hud or (not blu_hud_visible and not force) or not state then return end
    update_native_haste_dw(false)
    local plan=dw_plan_current()
    local selected=state.WeaponSet.value
    local effective=weapon_profile_effective_key()
    local eq=player and player.equipment or {}
    local live=tostring(item_name(eq.main) or 'empty')..' / '..tostring(normalized_equipped_sub())
    local expected=sets and sets.weapons and effective and sets.weapons[effective]
    local expected_sub=expected and (expected.sub==empty and 'empty' or item_name(expected.sub)) or nil
    local weapon_ok=expected and item_name(eq.main)==item_name(expected.main) and normalized_equipped_sub()==expected_sub or false
    local set_count=0; for _ in pairs(trait_cache.set_names) do set_count=set_count+1 end
    local fc_gear=live_precast_fc_gear()
    local profile_status=spell_profile_hud_status()
    local gi_alive=gearinfo_last and os.clock()-gearinfo_last<=GEARINFO_STALE_SECONDS or false
    local warnings={}
    if pause_swaps_active() then warnings[#warnings+1]='PAUSED' end
    if fishing_mode_active() then warnings[#warnings+1]='FISHING' end
    if buffactive and buffactive.doom then warnings[#warnings+1]='DOOM' end
    if buffactive and buffactive.silence then warnings[#warnings+1]='SILENCED' end
    if selected_profile_is_dual() and trait_cache.value.DualWield==0 then warnings[#warnings+1]='DW FALLBACK' end
    if native_dw_active and plan.shortfall>0 then warnings[#warnings+1]='DW SHORT '..plan.shortfall end
    if not weapon_ok and not swaps_frozen() then warnings[#warnings+1]='WEAPON MISMATCH' end
    if state.LearningMode.value then warnings[#warnings+1]='LEARNING' end
    local status=#warnings>0 and table.concat(warnings,' | ') or 'OK'
    local move=movement_route_label and movement_route_label() or (moving and 'native' or 'idle')
    local key=table.concat({selected,effective,live,tostring(weapon_ok),state.OffenseMode.value,state.HybridMode.value,
        state.WeaponskillMode.value,state.CastingMode.value,defense_control_mode(),state.IdleMode.value,state.TreasureMode.value,
        tostring(state.WeaponLock.value),tostring(state.LearningMode.value),tostring(state.AutoUnbridled.value),
        tostring(native_haste),tostring(native_dw_trait),tostring(native_dw_need),tostring(plan.have),
        tostring(trait_cache.value.FastCast),tostring(fc_gear),tostring(set_count),burst_hud_status(),affinity_hud_status(),move,status,
        profile_status,state.EntombMode.value,blu_hud_config.layout,tostring(gi_alive)},'|')
    if not force and key==blu_hud_cache.key then return end
    blu_hud_cache.key=key
    local rows={hcol('cyan','BLU v'..BLU_RELEASE_VERSION)..'  '..hfield('STATUS',status,status=='OK' and 'green' or 'red')}
    if section_on('loadout') then
        rows[#rows+1]=hrow('LOADOUT',hfield('Selected',weapon_profile_label(selected),'cyan')..'  '..hfield('Live',live,weapon_ok and 'green' or 'red')..'  '..hfield('Lock',state.WeaponLock.value and 'ON' or 'off',state.WeaponLock.value and 'green' or 'orange'))
    end
    if section_on('combat') then
        rows[#rows+1]=hrow('COMBAT',hfield('Melee',state.OffenseMode.value)..'  '..hfield('Hybrid',state.HybridMode.value,state.HybridMode.value=='DT' and 'green' or 'orange')..'  '..hfield('WS',state.WeaponskillMode.value)..'  '..hfield('Defense',defense_control_mode())..'  '..hfield('Idle',state.IdleMode.value))
        local dw=tostring(native_dw_trait)..' + '..tostring(plan.have)..'/'..tostring(native_dw_need)
        rows[#rows+1]=hrow('DELAY',hfield('Haste',string.format('%.1f%%',native_haste/1024*100),'cyan')..'  '..hfield('DW trait+gear',dw,native_dw_active and 'green' or 'dim')..'  '..hfield('Move',move,moving and 'green' or 'dim'))
    end
    if section_on('magic') then
        rows[#rows+1]=hrow('MAGIC',hfield('Casting',state.CastingMode.value)..'  '..hfield('FC',tostring(trait_cache.value.FastCast)..' trait + '..tostring(fc_gear)..' gear','cyan')..'  '..hfield('Burst',burst_hud_status(),'yellow')..'  '..hfield('SIRD',tostring(BLU_SIRD_TOTALS.base)..'/'..tostring(BLU_SIRD_TOTALS.cap),'orange'))
        rows[#rows+1]=hrow('BLUE SET',hfield('Profile',profile_status,'cyan')..'  '..hfield('Spells',set_count)..'  '..hfield('Entomb',state.EntombMode.value,state.EntombMode.value=='Control' and 'yellow' or 'dim'))
        rows[#rows+1]=hrow('AFFINITY',hcol('value',affinity_hud_status()))
    end
    if section_on('utility') then
        rows[#rows+1]=hrow('UTILITY',hfield('TH',state.TreasureMode.value,state.TreasureMode.value~='Off' and 'yellow' or 'dim')..'  '..hfield('Learning',state.LearningMode.value and 'ON' or 'off',state.LearningMode.value and 'green' or 'dim')..'  '..hfield('Auto UL',state.AutoUnbridled.value and 'ON' or 'off',state.AutoUnbridled.value and 'green' or 'dim')..'  '..hfield('GearInfo',gi_alive and 'compare' or 'off','dim'))
    end
    if section_on('shortcuts') then
        rows[#rows+1]=hrow('F10-F12',hcol('value','F10 Learning | F11 Burst Gear | F12 Primary WS'))
        rows[#rows+1]=hrow('CTRL F9-12',hcol('value','Prev Weapon | Next Weapon | Weapon Lock | Silmaril'))
        rows[#rows+1]=hrow('COMBAT KEY',hcol('value','Ctrl+F1 Melee | F2 Melee DT | F3 Defense | F4 Casting | F7 Idle'))
        rows[#rows+1]=hrow('UTILITY KEY',hcol('value','Alt+F1 TH | F2 Fishing | F3 Pause | F9 HUD Lock | F10 HUD'))
    end
    if blu_hud_config.layout=='compact' then
        local compact={rows[1],hfield('Weapon',weapon_profile_label(selected),'cyan')..'  '..hfield('Melee',state.OffenseMode.value)..'  '..hfield('DT',state.HybridMode.value)..'  '..hfield('Cast',state.CastingMode.value),
            hfield('DW',tostring(native_dw_trait)..'+'..tostring(plan.have)..'/'..tostring(native_dw_need),'cyan')..'  '..hfield('TH',state.TreasureMode.value)..'  '..hfield('Learn',state.LearningMode.value and 'ON' or 'off')..'  '..hfield('Move',moving and 'ON' or 'off'),
            hfield('Profile',profile_status,'cyan')..'  '..hfield('Entomb',state.EntombMode.value)}
        blu_hud:text(table.concat(compact,'\n'))
    else
        blu_hud:text(table.concat(rows,'\n'))
    end
    if blu_hud_visible then blu_hud:show() end
    perf_count('hud_renders')
end

-------------------------------------------------------------------------------------------------------------------
-- Native movement, action, and zone event dispatch
-------------------------------------------------------------------------------------------------------------------

local function protected_ring_active(slot)
    return releasing[slot]~=true and NO_SWAP_GEAR[current_ring_name(slot)]==true
end

local function movement_ring_slot()
    if protected_ring_active('ring2') then
        if not protected_ring_active('ring1') then return 'ring1' end
        return nil
    end
    return 'ring2'
end

movement_route_label=function()
    if not moving then return 'idle' end
    if pause_swaps_active() then return 'blocked:pause' end
    if buffactive and buffactive.doom then return 'blocked:doom' end
    local slot=movement_ring_slot(); if not slot then return 'blocked:rings' end
    local equipped=current_ring_name(slot)==MOVEMENT_RING_NAME
    return 'native/'..slot..'/'..(equipped and 'equipped' or 'pending')
end

local function check_moving()
    if state and state.Auto_Kite and state.Auto_Kite.value~=moving then state.Auto_Kite:set(moving) end
end

local function queue_movement_gear_refresh()
    if BLU_RUNTIME.unloading or movement_monitor.refresh_queued then return end
    movement_monitor.refresh_queued=true
    send_command('gs c _movementrefresh '..BLU_RUNTIME.token)
end

local function native_movement_sample()
    if BLU_RUNTIME.unloading then return end
    local now=os.clock(); if now<movement_monitor.next_sample then return end
    movement_monitor.next_sample=now+movement_monitor.sample_interval
    local ffxi=windower and windower.ffxi
    if not (player and player.index and ffxi and type(ffxi.get_mob_by_index)=='function') then return end
    local mob=ffxi.get_mob_by_index(player.index)
    if not (mob and mob.x and mob.y and mob.z) then movement_monitor.x,movement_monitor.y,movement_monitor.z=nil,nil,nil; return end
    local ox,oy,oz=movement_monitor.x,movement_monitor.y,movement_monitor.z
    movement_monitor.x,movement_monitor.y,movement_monitor.z=mob.x,mob.y,mob.z
    if ox==nil or oy==nil or oz==nil then
        movement_monitor.last_motion_at=now
    else
        local dx,dy,dz=mob.x-ox,mob.y-oy,mob.z-oz
        local displaced=(dx*dx+dy*dy+dz*dz)>movement_monitor.distance_squared
        local new_moving=moving
        if displaced then movement_monitor.last_motion_at=now; new_moving=true
        elseif moving and (now-movement_monitor.last_motion_at)>=movement_monitor.stop_debounce then new_moving=false end
        if new_moving~=moving then moving=new_moving; movement_monitor.refresh_pending=true end
    end
    if movement_monitor.refresh_pending and not pause_swaps_active()
        and (type(midaction)~='function' or not midaction()) then
        check_moving(); queue_movement_gear_refresh()
    end
    local route=movement_route_label()
    if route~=movement_monitor.last_route_label then movement_monitor.last_route_label=route; if type(update_hud)=='function' then update_hud(false) end end
end

local function handle_blu_action(act)
    if BLU_RUNTIME.unloading or not act then return end
    perf_count('action_packets')
    if player and act.actor_id==player.id and state and state.TreasureMode
        and state.TreasureMode.value=='Tag' and not th_tracker.tagged and act.category==1 and act.targets then
        for _,target in pairs(act.targets) do
            if target and target.id==th_tracker.target_id then th_mark_tagged(target.id,'melee'); break end
        end
    end
    handle_skillchain_action(act)
end

local function register_blu_events()
    unregister_blu_events()
    if windower and type(windower.raw_register_event)=='function' then
        track_blu_event(windower.raw_register_event('action',handle_blu_action))
        track_blu_event(windower.raw_register_event('prerender',native_movement_sample))
    end
    if windower and type(windower.register_event)=='function' then
        track_blu_event(windower.register_event('zone change',function()
            if BLU_RUNTIME.unloading then return end
            clear_burst_window(); reset_th_tracker(false)
            unbridled_ctl.pending=nil; unbridled_ctl.generation=unbridled_ctl.generation+1
            moving=false; movement_monitor.x,movement_monitor.y,movement_monitor.z=nil,nil,nil
            movement_monitor.last_motion_at=0; movement_monitor.refresh_pending=true
            local slots={}
            if WARP_GEAR[current_ring_name('ring1')] then slots[#slots+1]='ring1' end
            if WARP_GEAR[current_ring_name('ring2')] then slots[#slots+1]='ring2' end
            if #slots>0 then release_protected_ring_slots(slots,'zone change') end
            if type(update_hud)=='function' then update_hud(false) end
        end))
    end
end

-------------------------------------------------------------------------------------------------------------------
-- Framework initialization
-------------------------------------------------------------------------------------------------------------------

local BLU_FKEY_MODIFIERS={'','^','!','~','@'}
local function clear_f9_f12_bindings()
    for key_number=9,12 do
        for _,modifier in ipairs(BLU_FKEY_MODIFIERS) do send_command('unbind '..modifier..'f'..tostring(key_number)) end
    end
end
local function clear_legacy_target_bindings()
    send_command('unbind ^-'); send_command('unbind ^=')
end

function get_sets()
    mote_include_version=2
    include('ItemStats.lua')
    include('Mote-Include.lua')
end

function job_setup()
    lockstyleset=41
    state.Buff['Burst Affinity']=buffactive['Burst Affinity'] or false
    state.Buff['Chain Affinity']=buffactive['Chain Affinity'] or false
    state.Buff.Convergence=buffactive.Convergence or false
    state.Buff.Diffusion=buffactive.Diffusion or false
    state.Buff.Efflux=buffactive.Efflux or false
    state.Buff['Unbridled Learning']=buffactive['Unbridled Learning'] or false
    state.Buff['Unbridled Wisdom']=buffactive['Unbridled Wisdom'] or false
    state.Buff['Azure Lore']=buffactive['Azure Lore'] or false
    state.Buff.Doom=buffactive.doom or false
end

local function report_keybinds(startup_summary)
    if not startup_summary then
        chat(158,'=== BLU v'..BLU_RELEASE_VERSION..' primary controls ===')
        chat(158,' F10 Learning Hands | F11 Manual Burst Gear | F12 Weapon-Aware Primary WS')
        chat(158,' Ctrl+F9 Previous Weapon | Ctrl+F10 Next Weapon | Ctrl+F11 Weapon Lock | Ctrl+F12 Silmaril')
        chat(158,' Alt+F9 HUD Position Lock | Alt+F10 HUD Show/Hide')
    end
    chat(158,'=== BLU combat modes ===')
    chat(158,' Ctrl+F1 Melee: Normal > MidAcc > HighAcc > HighBuff | Ctrl+F2 Melee DT: Off/On')
    chat(158,' Ctrl+F3 Defense: Normal > DT > MEVA | Ctrl+F4 Casting: Normal > SpellACC > SIRD | Ctrl+F7 Idle')
    chat(158,'=== BLU utility ===')
    chat(158,' Alt+F1 TH: Off > Tag > Fulltime | Alt+F2 Fishing | Alt+F3 Pause')
    if not startup_summary then
        chat(158,' typed: gs c bluweapon <next|previous|name> | gs c bludefense <normal|dt|meva>')
        chat(158,' typed: gs c entombmode <damage|control>')
        chat(158,' typed: hudlayout compact|expanded | hudscale <0.7-1.6> | hudopacity <0-255> | hudsection <name> on|off')
        chat(158,' Profiles: gs c bluprofile list | preview <name> | apply <name> | cancel')
        chat(158,' Info: traits | dwinfo | fcinfo | sirdinfo | hasteinfo | burstinfo | unbridledinfo | thinfo | moveinfo | spellinfo <name> | policy | version')
    else
        chat(158,' Full keybind reference: gs c keys')
    end
end

function user_setup()
    BLU_RUNTIME.unloading=false
    clear_f9_f12_bindings(); clear_legacy_target_bindings()
    state.OffenseMode:options('Normal','MidAcc','HighAcc','HighBuff')
    state.HybridMode:options('Normal','DT')
    state.WeaponskillMode:options('Normal','Acc')
    state.CastingMode:options('Normal','SpellACC','SIRD')
    state.IdleMode:options('Normal','DT')
    state.PhysicalDefenseMode:options('PDT')
    if state.MagicalDefenseMode then state.MagicalDefenseMode:options('MEVA') end

    state.WeaponSet=M{['description']='Weapon Set','NaeglingSakpata','MaxentiusSakpata','BunziSors','SakpataSors','NaeglingEmpty','MaxentiusEmpty','LearnLv1'}
    state.WeaponLock=M(true,'Weapon Lock')
    state.MagicBurst=M(false,'Magic Burst')
    state.AutoBurst=M(true,'Auto Burst Detect')
    state.AutoUnbridled=M(true,'Auto Unbridled Learning')
    state.LearningMode=M(false,'Blue Magic Learning')
    state.PauseSwaps=M(false,'Pause Gear Swapping')
    state.FishingMode=M(false,'Fishing Mode')
    state.TreasureMode=M{['description']='Treasure Hunter','Off','Tag','Fulltime'}
    state.Auto_Kite=M(false,'Auto Kiting')
    state.HasteTier=M{['description']='Haste Tier',2,1}
    state.EntombMode=M{['description']='Entomb Objective','Damage','Control'}
    state.SpellProfile=M{['description']='Spell Profile','Manual','SavageHighHaste','CDCHighHaste',
        'SavageHasteII','CleaveDamage','MagicBurst','TankControl','LearningSafe','SupportSafe'}

    send_command('bind ^f1 gs c cycle OffenseMode')
    send_command('bind ^f2 gs c cycle HybridMode')
    send_command('bind ^f3 gs c bludefense cycle')
    send_command('bind ^f4 gs c cycle CastingMode')
    send_command('bind ^f7 gs c cycle IdleMode')
    send_command('bind f10 gs c toggle LearningMode')
    send_command('bind f11 gs c toggle MagicBurst')
    send_command('bind f12 gs c primaryws')
    send_command('bind ^f9 gs c bluweapon previous')
    send_command('bind ^f10 gs c bluweapon next')
    send_command('bind ^f11 gs c toggle WeaponLock')
    send_command('bind ^f12 sm all toggle')
    send_command('bind !f1 gs c cycle TreasureMode')
    send_command('bind !f2 gs c toggle FishingMode')
    send_command('bind !f3 gs c toggle PauseSwaps')
    send_command('bind !f9 gs c hudlock')
    send_command('bind !f10 gs c hud')

    -- Explicitly retire old Alt-letter / Windows-era controls so a reload cannot leave stale binds.
    for _,key in ipairs({'!w','!r','!e','!m','!g','!u','!l','!p','!f','!t','!h','^!h','^!z','@h','@z'}) do send_command('unbind '..key) end

    movement_monitor.next_sample=0; movement_monitor.last_motion_at=0
    movement_monitor.x,movement_monitor.y,movement_monitor.z=nil,nil,nil
    movement_monitor.refresh_pending=false; movement_monitor.refresh_queued=false; movement_monitor.last_route_label=nil
    init_hud(); register_blu_events(); refresh_trait_cache(true); invalidate_haste_cache()
    send_command('wait 4; gs c _startupkeys '..BLU_RUNTIME.token)
    select_default_macro_book(); set_lockstyle()
end

function user_unload()
    BLU_RUNTIME.unloading=true
    profile_install.generation=profile_install.generation+1; profile_install.running=false
    if save_blu_hud_preferences then pcall(save_blu_hud_preferences,true) end
    BLU_RUNTIME.token='unloaded-'..tostring(os.clock())
    unregister_blu_events(); clear_burst_window()
    unbridled_ctl.pending=nil; unbridled_ctl.generation=unbridled_ctl.generation+1
    silence_echo.generation=silence_echo.generation+1; silence_echo.active=false
    movement_monitor.refresh_pending=false; movement_monitor.refresh_queued=false
    enable(unpack(ALL_EQUIP_SLOTS))
    clear_f9_f12_bindings(); clear_legacy_target_bindings()
    for _,key in ipairs({'^f1','^f2','^f3','^f4','^f7','!f1','!f2','!f3','!f9','!f10','!w','!r','!e','!m','!g','!u','!l','!p','!f','!t','!h','^!h','^!z','@h','@z'}) do send_command('unbind '..key) end
    if blu_hud then blu_hud:hide() end
end

-------------------------------------------------------------------------------------------------------------------
-- Owned gear sets
-------------------------------------------------------------------------------------------------------------------

function init_gear_sets()
    blu_gear = blu_gear or {}
    blu_gear.moonshade = {
        name='Moonshade Earring',
        augments={'Accuracy+4','TP Bonus +250'},
    }
    blu_gear.ghastly = {name='Ghastly Tathlum +1', augments={'Path: A'}}
    blu_gear.murky = {name='Murky Ring', augments={'Path: A'}}
    blu_gear.carmine_legs = {
        name='Carmine Cuisses +1',
        augments={'Accuracy+20','Attack+12','"Dual Wield"+6'},
    }
    blu_gear.sailfi = {name='Sailfi Belt +1', augments={'Path: A'}}

    sets.weapons = {
        NaeglingSakpata={main='Naegling',sub="Sakpata's Sword"},
        MaxentiusSakpata={main='Maxentius',sub="Sakpata's Sword"},
        BunziSors={main="Bunzi's Rod",sub='Sors Shield'},
        SakpataSors={main="Sakpata's Sword",sub='Sors Shield'},
        NaeglingEmpty={main='Naegling',sub=empty},
        MaxentiusEmpty={main='Maxentius',sub=empty},
        LearnLv1={main='Twinned Blade',sub="Kam'lanaut's Sword"},
        LearnSingle={main='Twinned Blade',sub=empty},
    }

    -- Owned non-weapon FC is 34% (Aya. Cosciales +2 replaces Carmine here). Sakpata's
    -- Sword contributes another 10% whenever the live weapon profile is actually wearing it.
    -- Live set-spell/subjob FC is reported separately and never double-counted.
    sets.precast.FC = {
        ammo='Impatiens',
        head='Amalric Coif +1',
        body='Vanir Cotehardie',
        hands='Malignance Gloves',
        legs='Aya. Cosciales +2',
        feet='Malignance Boots',
        neck='Null Loop',
        ear1='Loquac. Earring',
        ear2='Enchntr. Earring +1',
        ring1='Kishar Ring',
        ring2="Naji's Loop",
        back='Hecate\'s Cape',
        waist='Witful Belt',
    }
    sets.precast.FC['Blue Magic'] = sets.precast.FC

    sets.precast.RA = {
        ammo='Albin Bane',
        head='Malignance Chapeau',
        body='Malignance Tabard',
        hands='Malignance Gloves',
        legs='Malignance Tights',
        feet='Malignance Boots',
        neck='Null Loop',
        back='Null Shawl',
        waist='Null Belt',
    }
    sets.midcast.RA = sets.precast.RA

    -- No owned BLU JSE enhances these abilities. Empty hooks are kept deliberately
    -- so future acquisitions can be added without changing the routing layer.
    sets.precast.JA['Azure Lore'] = {}
    sets.precast.JA['Chain Affinity'] = {}
    sets.precast.JA['Burst Affinity'] = {}
    sets.precast.JA['Efflux'] = {}
    sets.precast.JA['Diffusion'] = {}
    sets.precast.JA['Convergence'] = {}
    sets.precast.JA['Unbridled Learning'] = {}
    sets.precast.JA['Unbridled Wisdom'] = {}

    ---------------------------------------------------------------------------------------------------------------
    -- Weapon skills
    ---------------------------------------------------------------------------------------------------------------

    sets.precast.WS = {
        ammo="Oshasha's Treatise",
        head='Nyame Helm',
        body='Nyame Mail',
        hands='Nyame Gauntlets',
        legs='Nyame Flanchard',
        feet='Nyame Sollerets',
        neck='Rep. Plat. Medal',
        ear1='Mache Earring +1',
        ear2='Telos Earring',
        ring1="Epaminondas's Ring",
        ring2='Sroda Ring',
        back='Null Shawl',
        waist=blu_gear.sailfi,
    }
    sets.precast.WS.Acc = set_combine(sets.precast.WS, {
        ammo="Oshasha's Treatise",
        head='Malignance Chapeau',
        body='Malignance Tabard',
        hands='Malignance Gloves',
        legs='Malignance Tights',
        feet='Malignance Boots',
        neck='Null Loop',
        ear1='Mache Earring +1',
        ear2='Telos Earring',
        ring1='Varar Ring +1',
        ring2='Chirich Ring +1',
        back='Null Shawl',
        waist='Null Belt',
    })

    sets.precast.WS['Savage Blade'] = set_combine(sets.precast.WS, {
        hands='Jhakri Cuffs +2',
        ear1=blu_gear.moonshade,
        ear2='Brutal Earring',
    })
    sets.precast.WS['Savage Blade'].Acc = set_combine(sets.precast.WS.Acc, {
        ear1=blu_gear.moonshade,
        ear2='Mache Earring +1',
    })
    sets.precast.WS['Expiacion'] = set_combine(sets.precast.WS, {
        hands='Jhakri Cuffs +2',
        ear1=blu_gear.moonshade,
        ear2='Brutal Earring',
    })
    sets.precast.WS['Expiacion'].Acc = set_combine(sets.precast.WS.Acc, {
        ear1=blu_gear.moonshade,
        ear2='Mache Earring +1',
    })
    sets.precast.WS['Black Halo'] = set_combine(sets.precast.WS, {
        ammo='Hydrocera',
        hands='Jhakri Cuffs +2',
        ear1=blu_gear.moonshade,
        ear2='Brutal Earring',
        ring2='Metamor. Ring +1',
    })
    sets.precast.WS['Black Halo'].Acc = set_combine(sets.precast.WS.Acc, {
        ammo='Hydrocera',
        ear1=blu_gear.moonshade,
        ear2='Mache Earring +1',
        ring2='Metamor. Ring +1',
    })
    sets.precast.WS['Circle Blade'] = sets.precast.WS

    sets.precast.WS['Requiescat'] = {
        ammo='Hydrocera',
        head='Malignance Chapeau',
        body='Malignance Tabard',
        hands='Malignance Gloves',
        legs='Malignance Tights',
        feet='Malignance Boots',
        neck='Null Loop',
        ear1='Brutal Earring',
        ear2='Telos Earring',
        ring1='Metamor. Ring +1',
        ring2='Chirich Ring +1',
        back='Null Shawl',
        waist='Grunfeld Rope',
    }
    sets.precast.WS['Requiescat'].Acc = set_combine(sets.precast.WS['Requiescat'], {
        ear2='Mache Earring +1',
        ring2='Chirich Ring +1',
        waist='Null Belt',
    })
    sets.precast.WS['Realmrazer'] = set_combine(sets.precast.WS['Requiescat'], {
        ring1='Metamor. Ring +1',
        ring2='Chirich Ring +1',
    })
    sets.precast.WS['Realmrazer'].Acc = sets.precast.WS['Requiescat'].Acc

    sets.precast.WS.CriticalAcc = {
        ammo='Staunch Tathlum +1',
        head='Malignance Chapeau',
        body='Malignance Tabard',
        hands='Malignance Gloves',
        legs='Malignance Tights',
        feet='Malignance Boots',
        neck='Null Loop',
        ear1='Odr Earring',
        ear2='Mache Earring +1',
        ring1='Ramuh Ring +1',
        ring2='Chirich Ring +1',
        back='Null Shawl',
        waist='Windbuffet Belt +1',
    }
    sets.precast.WS.Critical = set_combine(sets.precast.WS.CriticalAcc, {
        body="Enforcer's Harness",
        feet='Aya. Gambieras +2',
    })
    sets.precast.WS.Critical.Acc = sets.precast.WS.CriticalAcc
    sets.precast.WS['Chant du Cygne'] = sets.precast.WS.Critical
    sets.precast.WS['Vorpal Blade'] = sets.precast.WS.Critical

    sets.precast.WS.Magic = {
        ammo=blu_gear.ghastly,
        head='Jhakri Coronal +2',
        body='Jhakri Robe +2',
        hands='Jhakri Cuffs +2',
        legs='Jhakri Slops +2',
        feet='Jhakri Pigaches +2',
        neck='Sibyl Scarf',
        ear1='Friomisi Earring',
        ear2='Sortiarius Earring',
        ring1='Jhakri Ring',
        ring2='Metamor. Ring +1',
        back='Toro Cape',
        waist='Skrymir Cord',
    }
    sets.precast.WS.Magic.Acc = set_combine(sets.precast.WS.Magic, {
        neck='Null Loop',
        ear2='Enchntr. Earring +1',
        ring1='Stikini Ring +1',
        back='Null Shawl',
        waist='Null Belt',
    })
    sets.precast.WS['Aeolian Edge'] = sets.precast.WS.Magic
    sets.precast.WS['Flash Nova'] = sets.precast.WS.Magic
    sets.precast.WS['Seraph Strike'] = sets.precast.WS.Magic
    sets.precast.WS['Sanguine Blade'] = set_combine(sets.precast.WS.Magic, {
        head='Pixie Hairpin +1',
    })
    sets.precast.WS['Sanguine Blade'].Acc = set_combine(sets.precast.WS.Magic.Acc, {
        head='Pixie Hairpin +1',
    })

    ---------------------------------------------------------------------------------------------------------------
    -- Blue Magic midcast families
    ---------------------------------------------------------------------------------------------------------------

    sets.midcast.FastRecast = {
        ammo='Impatiens',
        head='Amalric Coif +1',
        body='Vanir Cotehardie',
        hands='Malignance Gloves',
        legs='Aya. Cosciales +2',
        feet='Malignance Boots',
        neck='Null Loop',
        ear1='Loquac. Earring',
        ear2='Enchntr. Earring +1',
        ring1='Kishar Ring',
        ring2="Naji's Loop",
        back='Hecate\'s Cape',
        waist='Witful Belt',
    }

    sets.midcast.SIRD = {
        ammo='Staunch Tathlum +1',
        head='Malignance Chapeau',
        body='Malignance Tabard',
        hands='Malignance Gloves',
        legs=blu_gear.carmine_legs,
        feet='Malignance Boots',
        neck='Null Loop',
        ear1='Magnetic Earring',
        ear2='Etiolation Earring',
        ring1='Evanescence Ring',
        ring2=blu_gear.murky,
        back='Null Shawl',
        waist='Rumination Sash',
    }

    sets.midcast.Physical = {
        ammo='Staunch Tathlum +1',
        head='Nyame Helm',
        body='Nyame Mail',
        hands='Nyame Gauntlets',
        legs='Nyame Flanchard',
        feet='Nyame Sollerets',
        neck='Null Loop',
        ear1='Mache Earring +1',
        ear2='Telos Earring',
        ring1='Stikini Ring +1',
        ring2='Sroda Ring',
        back='Null Shawl',
        waist='Grunfeld Rope',
    }
    sets.midcast.PhysicalAcc = {
        ammo='Staunch Tathlum +1',
        head='Malignance Chapeau',
        body='Malignance Tabard',
        hands='Malignance Gloves',
        legs='Malignance Tights',
        feet='Malignance Boots',
        neck='Null Loop',
        ear1='Mache Earring +1',
        ear2='Telos Earring',
        ring1='Stikini Ring +1',
        ring2='Varar Ring +1',
        back='Null Shawl',
        waist='Null Belt',
    }
    sets.midcast.PhysicalStr = set_combine(sets.midcast.Physical, {
        ring2='Sroda Ring',
    })
    sets.midcast.PhysicalDex = set_combine(sets.midcast.PhysicalAcc, {
        ear1='Odr Earring',
        ring2='Ramuh Ring +1',
    })
    sets.midcast.PhysicalVit = set_combine(sets.midcast.Physical, {
        neck='Unmoving Collar +1',
        ring2='Gelatinous Ring +1',
    })
    sets.midcast.PhysicalAgi = set_combine(sets.midcast.PhysicalAcc, {
        ring2='Chirich Ring +1',
    })
    sets.midcast.PhysicalInt = set_combine(sets.midcast.Physical, {
        ammo=blu_gear.ghastly,
        ring2='Metamor. Ring +1',
        waist='Acuity Belt +1',
    })
    sets.midcast.PhysicalMnd = set_combine(sets.midcast.Physical, {
        ammo='Hydrocera',
        ring2='Metamor. Ring +1',
    })
    sets.midcast.PhysicalChr = sets.midcast.PhysicalMnd
    sets.midcast.PhysicalHP = {
        ammo='Staunch Tathlum +1',
        head='Nyame Helm',
        body='Nyame Mail',
        hands='Nyame Gauntlets',
        legs='Nyame Flanchard',
        feet='Nyame Sollerets',
        neck='Unmoving Collar +1',
        ear1='Alabaster Earring',
        ear2='Etiolation Earring',
        ring1='Gelatinous Ring +1',
        ring2='Vengeful Ring',
        back='Null Shawl',
        waist="Carrier's Sash",
    }
    sets.midcast.StunPhysical = sets.midcast.PhysicalAcc

    sets.midcast.Magical = {
        ammo=blu_gear.ghastly,
        head='Jhakri Coronal +2',
        body='Jhakri Robe +2',
        hands='Jhakri Cuffs +2',
        legs='Jhakri Slops +2',
        feet='Jhakri Pigaches +2',
        neck='Sibyl Scarf',
        ear1='Friomisi Earring',
        ear2='Sortiarius Earring',
        ring1='Jhakri Ring',
        ring2='Metamor. Ring +1',
        back='Toro Cape',
        waist='Skrymir Cord',
    }
    sets.midcast.Magical.SpellACC = {
        ammo=blu_gear.ghastly,
        head='Malignance Chapeau',
        body='Malignance Tabard',
        hands='Malignance Gloves',
        legs='Malignance Tights',
        feet='Malignance Boots',
        neck='Null Loop',
        ear1='Enchntr. Earring +1',
        ear2='Friomisi Earring',
        ring1='Stikini Ring +1',
        ring2='Metamor. Ring +1',
        back='Null Shawl',
        waist='Null Belt',
    }
    sets.midcast.Magical.Burst = {
        ammo=blu_gear.ghastly,
        head='Nyame Helm',
        body='Nyame Mail',
        hands='Nyame Gauntlets',
        legs='Nyame Flanchard',
        feet='Nyame Sollerets',
        neck='Sanctity Necklace',
        ear1='Friomisi Earring',
        ear2='Enchntr. Earring +1',
        ring1='Jhakri Ring',
        ring2='Mujin Band',
        back='Toro Cape',
        waist='Skrymir Cord',
    }
    sets.midcast.Magical.BurstSpellACC = set_combine(sets.midcast.Magical.Burst, {
        neck='Null Loop',
        ear2='Enchntr. Earring +1',
        ring1='Stikini Ring +1',
        back='Null Shawl',
        waist='Null Belt',
    })
    sets.magic_burst = sets.midcast.Magical.Burst
    sets.midcast.Magical.Resistant = sets.midcast.Magical.SpellACC
    sets.midcast.Magical.BurstResistant = sets.midcast.Magical.BurstSpellACC

    sets.midcast.MagicalDark = set_combine(sets.midcast.Magical, {
        head='Pixie Hairpin +1',
    })
    sets.midcast.MagicalLight = sets.midcast.Magical
    sets.midcast.MagicalMnd = set_combine(sets.midcast.Magical, {
        ammo='Hydrocera',
        ring2='Metamor. Ring +1',
    })
    sets.midcast.MagicalChr = sets.midcast.MagicalMnd
    sets.midcast.MagicalVit = sets.midcast.Magical
    sets.midcast.MagicalAgi = sets.midcast.Magical
    sets.midcast.MagicalDex = sets.midcast.Magical

    sets.midcast.MagicAccuracy = {
        ammo=blu_gear.ghastly,
        head='Malignance Chapeau',
        body='Malignance Tabard',
        hands='Malignance Gloves',
        legs='Malignance Tights',
        feet='Malignance Boots',
        neck='Null Loop',
        ear1='Enchntr. Earring +1',
        ear2='Etiolation Earring',
        ring1='Stikini Ring +1',
        ring2='Stikini Ring +1',
        back='Null Shawl',
        waist='Null Belt',
    }
    sets.midcast.StunMagical = sets.midcast.MagicAccuracy

    sets.midcast.Breath = {
        ammo='Staunch Tathlum +1',
        head='Nyame Helm',
        body='Nyame Mail',
        hands='Nyame Gauntlets',
        legs='Nyame Flanchard',
        feet='Nyame Sollerets',
        neck='Unmoving Collar +1',
        ear1='Alabaster Earring',
        ear2='Etiolation Earring',
        ring1='Gelatinous Ring +1',
        ring2='Vengeful Ring',
        back='Null Shawl',
        waist="Carrier's Sash",
    }

    sets.midcast.Healing = {
        main="Bunzi's Rod",
        sub='Sors Shield',
        ammo='Hydrocera',
        head='Amalric Coif +1',
        body='Jhakri Robe +2',
        hands='Telchine Gloves',
        legs='Jhakri Slops +2',
        feet='Jhakri Pigaches +2',
        neck='Null Loop',
        ear1='Mendi. Earring',
        ear2='Loquac. Earring',
        ring1='Stikini Ring +1',
        ring2='Lebeche Ring',
        back='Hecate\'s Cape',
        waist='Witful Belt',
    }
    sets.midcast.Healing.Self = set_combine(sets.midcast.Healing, {
        waist='Gishdubar Sash',
    })
    sets.midcast.WhiteWind = {
        main="Bunzi's Rod",
        sub='Sors Shield',
        ammo='Staunch Tathlum +1',
        head='Nyame Helm',
        body='Nyame Mail',
        hands='Telchine Gloves',
        legs='Nyame Flanchard',
        feet='Nyame Sollerets',
        neck='Null Loop',
        ear1='Alabaster Earring',
        ear2='Mendi. Earring',
        ring1='Gelatinous Ring +1',
        ring2='Lebeche Ring',
        back='Emico Mantle',
        waist='Gishdubar Sash',
    }

    sets.midcast.SkillBasedBuff = {
        ammo=blu_gear.ghastly,
        head='Malignance Chapeau',
        body='Malignance Tabard',
        hands='Malignance Gloves',
        legs='Malignance Tights',
        feet='Malignance Boots',
        neck='Null Loop',
        ear1='Loquac. Earring',
        ear2='Enchntr. Earring +1',
        ring1='Stikini Ring +1',
        ring2='Stikini Ring +1',
        back='Hecate\'s Cape',
        waist='Witful Belt',
    }
    sets.midcast.Buff = sets.midcast.FastRecast
    sets.midcast.Refresh = sets.midcast.FastRecast

    -- Build mode variants once. SIRD remains an explicit final-priority safety set.
    for family in pairs(BLUE_FAMILY_COUNTS) do
        local family_set = sets.midcast[family]
        if family_set then
            if not family_set.SpellACC then
                if MAGICAL_BLUE_FAMILIES[family] then
                    family_set.SpellACC = sets.midcast.Magical.SpellACC
                elseif family == 'MagicAccuracy' or family == 'StunMagical' then
                    family_set.SpellACC = set_combine(sets.midcast.MagicAccuracy, {})
                elseif PHYSICAL_BLUE_FAMILIES[family] then
                    family_set.SpellACC = set_combine(sets.midcast.PhysicalAcc, {})
                else
                    family_set.SpellACC = set_combine(family_set, {})
                end
            end
            family_set.SIRD = sets.midcast.SIRD
        end
    end

    -- Mote can resolve spell maps either as sets.midcast[spellMap] or as
    -- sets.midcast['Blue Magic'][spellMap], depending on include/version.
    -- Publish both shapes so the policy table remains portable.
    local blue_magic_sets = set_combine(sets.midcast.FastRecast, {})
    for family in pairs(BLUE_FAMILY_COUNTS) do
        blue_magic_sets[family] = sets.midcast[family]
    end
    blue_magic_sets.SIRD = sets.midcast.SIRD
    sets.midcast['Blue Magic'] = blue_magic_sets

    -- Affinity/JSE hook points. No unowned BLU JSE is invented.
    sets.buff['Chain Affinity'] = {}
    sets.buff['Burst Affinity'] = {}
    sets.buff.Efflux = {}
    sets.buff.Convergence = {}
    sets.buff.Diffusion = {}
    sets.buff['Unbridled Learning'] = {}
    sets.buff['Unbridled Wisdom'] = {}
    sets.buff['Azure Lore'] = {}

    ---------------------------------------------------------------------------------------------------------------
    -- Idle, engaged, defensive, utility
    ---------------------------------------------------------------------------------------------------------------

    sets.engaged = {
        ammo='Staunch Tathlum +1',
        head='Malignance Chapeau',
        body='Ayanmo Corazza +2',
        hands='Malignance Gloves',
        legs='Malignance Tights',
        feet='Malignance Boots',
        neck='Null Loop',
        ear1='Brutal Earring',
        ear2='Telos Earring',
        ring1='Chirich Ring +1',
        ring2='Varar Ring +1',
        back='Null Shawl',
        waist='Windbuffet Belt +1',
    }
    sets.engaged.MidAcc = set_combine(sets.engaged, {
        body='Malignance Tabard',
        ear1='Mache Earring +1',
    })
    sets.engaged.HighAcc = set_combine(sets.engaged.MidAcc, {
        ammo="Oshasha's Treatise",
        ring1='Varar Ring +1',
        ring2='Chirich Ring +1',
        waist='Null Belt',
    })
    sets.engaged.HighBuff = set_combine(sets.engaged, {
        body='Malignance Tabard',
        ring1='Chirich Ring +1',
        ring2='Sroda Ring',
    })
    -- Compatibility alias for old macros and saved Mote states.
    sets.engaged.PDL = sets.engaged.HighBuff
    sets.engaged.DTOverlay = {
        body='Malignance Tabard',
        ear1='Alabaster Earring',
        ring1=blu_gear.murky,
    }

    sets.idle = {
        ammo='Staunch Tathlum +1',
        head='Malignance Chapeau',
        body='Jhakri Robe +2',
        hands='Malignance Gloves',
        legs='Malignance Tights',
        feet='Malignance Boots',
        neck='Null Loop',
        ear1='Alabaster Earring',
        ear2='Etiolation Earring',
        ring1=blu_gear.murky,
        ring2='Stikini Ring +1',
        back='Null Shawl',
        waist='Null Belt',
    }
    sets.idle.DT = set_combine(sets.idle, {
        body='Malignance Tabard',
    })
    sets.Kiting = {ring2='Shneddick Ring'}
    sets.Learning = {hands='Magus Bazubands'}
    sets.TreasureHunter = {ammo='Per. Lucky Egg', ring1='Hoxne Ring'}
    sets.Fishing = {
        range="Lu Shang's F. Rod",
        body='Fsh. Tunica',
        hands='Fsh. Gloves',
        legs="Fisherman's Hose",
        feet="Fisherman's Boots",
    }

    sets.defense.PDT = sets.idle.DT
    sets.defense.MDT = sets.idle.DT
    sets.defense.MEVA = {
        ammo='Staunch Tathlum +1',
        head='Malignance Chapeau',
        body='Malignance Tabard',
        hands='Malignance Gloves',
        legs='Malignance Tights',
        feet='Malignance Boots',
        neck='Null Loop',
        ear1='Eabani Earring',
        ear2='Etiolation Earring',
        ring1=blu_gear.murky,
        ring2='Vengeful Ring',
        back='Null Shawl',
        waist='Null Belt',
    }
    sets.defense.Evasion = sets.defense.MEVA
    sets.buff.Doom = {
        neck="Nicander's Necklace",
        ring1="Blenmot's Ring +1",
        ring2="Blenmot's Ring +1",
        waist='Gishdubar Sash',
    }

    invalidate_haste_cache()
    refresh_trait_cache(true)
    update_native_haste_dw(true)
    update_dw_overlay()
    check_weaponset(true)
    protected_ring_check()
    if state.Buff.Doom then
        enable('neck','ring1','ring2','waist')
        equip(sets.buff.Doom)
        disable('neck','ring1','ring2','waist')
    end
    update_hud(true)
end

-------------------------------------------------------------------------------------------------------------------
-- Action hooks
-------------------------------------------------------------------------------------------------------------------

function job_get_spell_map(spell, defaultSpellMap)
    if spell and spell.skill == 'Blue Magic' then
        return BLUE_MAGIC_MAP[spell.english] or defaultSpellMap
    end
    return defaultSpellMap
end

local function spell_target_within(spell, yalms)
    local target = spell and spell.target
    local distance = target and tonumber(target.distance)
    if not distance then return false end
    return distance < yalms + (tonumber(target.model_size) or 0)
end

local function resolved_ws_set(spell)
    if not spell or not sets or not sets.precast or not sets.precast.WS then return nil end
    local specific = sets.precast.WS[spell.english]
    if state and state.WeaponskillMode and state.WeaponskillMode.value == 'Acc' then
        return specific and specific.Acc or sets.precast.WS.Acc or specific or sets.precast.WS
    end
    return specific or sets.precast.WS
end

local function set_uses_moonshade(set)
    if not set then return false end
    local ear1 = type(set.ear1) == 'table' and set.ear1.name or set.ear1
    local ear2 = type(set.ear2) == 'table' and set.ear2.name or set.ear2
    return ear1 == 'Moonshade Earring' or ear2 == 'Moonshade Earring'
end

local function apply_max_tp_moonshade(spell)
    local ws_set = resolved_ws_set(spell)
    if not set_uses_moonshade(ws_set) then return end
    local effective_tp = (tonumber(player and player.tp) or 0)
        + (buffactive and buffactive['Crystal Blessing'] and 250 or 0) + 250
    if effective_tp < 3000 then return end
    local ear1 = type(ws_set.ear1) == 'table' and ws_set.ear1.name or ws_set.ear1
    if ear1 == 'Moonshade Earring' then equip({ear1='Mache Earring +1'})
    else equip({ear2='Mache Earring +1'}) end
end

function job_pretarget(spell, action, spellMap, eventArgs)
    if prepare_unbridled_spell(spell, eventArgs) then return end
    if spell and spell.type == 'WeaponSkill' then
        local outside, maximum = ws_out_of_range(spell)
        if outside then
            local actual = tonumber(spell.target and spell.target.distance) or -1
            cancel_spell()
            if eventArgs then eventArgs.cancel=true; eventArgs.handled=true end
            chat(123, string.format('[BLU Range] %s canceled: %.1f > safe %.1f yalms.',
                spell.english, actual, maximum or 0))
            return
        end
    end
end

function job_precast(spell, action, spellMap, eventArgs)
    protected_ring_check()
    refresh_trait_cache(false)
    if spell and (spell.english == 'Metallic Body' or spell.english == 'Diamondhide')
        and buffactive and buffactive.Stoneskin then
        send_command('cancel stoneskin')
    end
end

function job_post_precast(spell, action, spellMap, eventArgs)
    if spell and spell.type == 'WeaponSkill' then
        apply_max_tp_moonshade(spell)
    end
    if th_action_overlay(spell) and sets.TreasureHunter then equip(sets.TreasureHunter) end
    if state and state.LearningMode and state.LearningMode.value and sets.Learning then
        equip(sets.Learning)
    end
end

function job_post_midcast(spell, action, spellMap, eventArgs)
    if not spell then return end
    local family = spellMap or BLUE_MAGIC_MAP[spell.english]

    if spell.skill == 'Blue Magic' then
        -- Apply only the affinity hooks relevant to this spell family.
        if PHYSICAL_BLUE_FAMILIES[family] then
            if buffactive['Chain Affinity'] and sets.buff['Chain Affinity'] then
                equip(sets.buff['Chain Affinity'])
            end
            if buffactive.Efflux and sets.buff.Efflux then equip(sets.buff.Efflux) end
            if buffactive['Azure Lore'] and sets.buff['Azure Lore'] then
                equip(sets.buff['Azure Lore'])
            end
        elseif MAGICAL_BLUE_FAMILIES[family] then
            if buffactive['Burst Affinity'] and sets.buff['Burst Affinity'] then
                equip(sets.buff['Burst Affinity'])
            end
            if buffactive.Convergence and sets.buff.Convergence then equip(sets.buff.Convergence) end
            if buffactive['Azure Lore'] and sets.buff['Azure Lore'] then
                equip(sets.buff['Azure Lore'])
            end
        end

        if buffactive.Diffusion and sets.buff.Diffusion
            and (family == 'Buff' or family == 'SkillBasedBuff'
                or family == 'Refresh' or family == 'Healing') then
            equip(sets.buff.Diffusion)
        end
        if UNBRIDLED_SPELLS[spell.english] then
            if buffactive['Unbridled Wisdom'] and sets.buff['Unbridled Wisdom'] then
                equip(sets.buff['Unbridled Wisdom'])
            elseif buffactive['Unbridled Learning'] and sets.buff['Unbridled Learning'] then
                equip(sets.buff['Unbridled Learning'])
            elseif buffactive['Azure Lore'] and sets.buff['Azure Lore'] then
                equip(sets.buff['Azure Lore'])
            end
        end

        if family == 'Healing' and spell.target and spell.target.type == 'SELF' then
            equip(sets.midcast.Healing.Self)
        end
        if (family == 'Healing' or family == 'WhiteWind')
            and state.WeaponLock and not state.WeaponLock.value then
            equip({main="Bunzi's Rod",sub='Sors Shield'})
        end

        if MAGICAL_BLUE_FAMILIES[family] and state.CastingMode.value ~= 'SIRD' then
            local manual = state.MagicBurst.value
            local automatic = not manual and state.AutoBurst.value
                and auto_burst_affinity_active() and burst_window_active(spell)
            if manual or automatic then
                if state.CastingMode.value == 'SpellACC' then
                    equip(sets.midcast.Magical.BurstSpellACC)
                else
                    equip(sets.midcast.Magical.Burst)
                end
                -- Dark affinity is worth preserving after the general MB head swap.
                if family == 'MagicalDark' then equip({head='Pixie Hairpin +1'}) end
                if automatic then
                    chat(158, '[BLU AutoMB] '..spell.english..' on '..tostring(sc_window.name)..'.')
                end
            end
            if state.CastingMode.value == 'Normal' and spell_target_within(spell, 8) then
                equip({waist="Orpheus's Sash"})
            end
        end

        -- Entomb damage and crowd-control accuracy are different jobs. Control mode
        -- intentionally gives up damage/MB/Orpheus pieces for the full MAcc set.
        if spell.english == 'Entomb' and state.EntombMode
            and state.EntombMode.value == 'Control'
            and state.CastingMode.value ~= 'SIRD' then
            equip(sets.midcast.Magical.SpellACC)
        end

        -- Explicit SIRD is final among combat objectives. TH and Learning are user-requested
        -- policy overlays and intentionally retain final ownership of their two slots.
        if state.CastingMode.value == 'SIRD' then equip(sets.midcast.SIRD) end
    end

    if th_action_overlay(spell) and sets.TreasureHunter then equip(sets.TreasureHunter) end
    if state.LearningMode.value and sets.Learning then equip(sets.Learning) end
end

function job_aftercast(spell, action, spellMap, eventArgs)
    if spell and not spell.interrupted and th_tracker.pending_target_id
        and spell.target and spell.target.id == th_tracker.pending_target_id then
        th_mark_tagged(spell.target.id, spell.english)
    end
    refresh_trait_cache(false)
    update_native_haste_dw(false)
    check_weaponset(false)
    protected_ring_check()
    if movement_monitor.refresh_pending and not pause_swaps_active() then movement_monitor.refresh_pending=false; check_moving() end
    if not pause_swaps_active() and not midaction() and type(handle_equipping_gear)=='function' and player then
        handle_equipping_gear(player.status); if fishing_mode_active() then apply_fishing_slot_policy() end
    end
    update_hud(false)
end

-------------------------------------------------------------------------------------------------------------------
-- Final idle/melee composition. Conditional overlays aggregate into one final combine.
-------------------------------------------------------------------------------------------------------------------

local melee_overlay_scratch={}
local idle_overlay_scratch={}
local function clear_overlay_scratch(t) for k in pairs(t) do t[k]=nil end end
local function merge_overlay_scratch(dst,src) if not src then return end; for k,v in pairs(src) do dst[k]=v end end

local function movement_overlay_into(dst)
    if not moving or pause_swaps_active() or (buffactive and buffactive.doom) then return false end
    local slot=movement_ring_slot(); if not slot then return false end
    dst[slot]=MOVEMENT_RING_NAME
    return true
end

function customize_melee_set(meleeSet)
    local started=perf_begin(); update_native_haste_dw(false)
    clear_overlay_scratch(melee_overlay_scratch); local has=false
    -- Defensive base first; adaptive DW follows so required delay-cap pieces win their slots.
    if state.HybridMode.value=='DT' then merge_overlay_scratch(melee_overlay_scratch,sets.engaged.DTOverlay); has=true end
    local dw=update_dw_overlay()
    if next(dw) then
        merge_overlay_scratch(melee_overlay_scratch,dw); has=true
        if item_name(dw.legs)=='Carmine Cuisses +1' then melee_overlay_scratch.waist=blu_gear.sailfi end
    end
    if movement_overlay_into(melee_overlay_scratch) then has=true end
    if th_should_apply(th_sync_target()) then merge_overlay_scratch(melee_overlay_scratch,sets.TreasureHunter); has=true end
    if state.LearningMode.value then
        merge_overlay_scratch(melee_overlay_scratch,sets.Learning)
        -- Magus Bazubands sacrifice the TP hands' haste; Sailfi restores the gear-haste cap while learning.
        melee_overlay_scratch.waist=blu_gear.sailfi
        has=true
    end
    local output=has and set_combine(meleeSet,melee_overlay_scratch) or meleeSet
    protected_ring_check(); perf_finish('melee_resolution',started); return output
end

function customize_idle_set(idleSet)
    clear_overlay_scratch(idle_overlay_scratch); local has=false
    if movement_overlay_into(idle_overlay_scratch) then has=true end
    if state.LearningMode.value then merge_overlay_scratch(idle_overlay_scratch,sets.Learning); has=true end
    local output=has and set_combine(idleSet,idle_overlay_scratch) or idleSet
    protected_ring_check(); return output
end

-------------------------------------------------------------------------------------------------------------------
-- Buff, state, status, and update lifecycle
-------------------------------------------------------------------------------------------------------------------

local TRACKED_BLU_BUFFS = {
    ['burst affinity']='Burst Affinity',
    ['chain affinity']='Chain Affinity',
    ['convergence']='Convergence',
    ['diffusion']='Diffusion',
    ['efflux']='Efflux',
    ['unbridled learning']='Unbridled Learning',
    ['unbridled wisdom']='Unbridled Wisdom',
    ['azure lore']='Azure Lore',
}

local function apply_doom_policy(gain)
    state.Buff.Doom = gain
    if gain then
        enable('neck','ring1','ring2','waist')
        equip(sets.buff.Doom)
        disable('neck','ring1','ring2','waist')
        send_command('input /echo ** DOOMED - spam Holy Waters **')
        send_command('input /p Doomed.')
    else
        enable('neck','ring1','ring2','waist')
        invalidate_ring_lock_cache()
        reapply_runtime_locks()
        if type(handle_equipping_gear) == 'function' and player then
            handle_equipping_gear(player.status)
        end
    end
end

function job_buff_change(buff, gain)
    local lower = buff:lower()
    local tracked = TRACKED_BLU_BUFFS[lower]
    if tracked then state.Buff[tracked] = gain end

    if lower == 'haste' or lower == 'march' or lower == 'embrava'
        or lower == 'mighty guard' then
        invalidate_haste_cache()
        update_native_haste_dw(true)
        if player and player.status == 'Engaged' and not midaction()
            and type(handle_equipping_gear) == 'function' then
            handle_equipping_gear(player.status)
        end
    elseif lower == 'doom' then
        apply_doom_policy(gain)
    elseif lower == 'silence' then
        silence_echo.generation = silence_echo.generation + 1
        if gain then
            silence_echo.active = true
            silence_echo.attempts = 0
            try_echo_drops(silence_echo.generation)
        else
            silence_echo.active = false
            silence_echo.attempts = 0
        end
    elseif lower == 'paralysis' and gain then
        chat(123, '[BLU Safety] Paralyzed.')
    end

    if gain and BOOST_BUFFS[lower] then
        local slots = {}
        if BOOST_GEAR[current_ring_name('ring1')] then slots[#slots + 1] = 'ring1' end
        if BOOST_GEAR[current_ring_name('ring2')] then slots[#slots + 1] = 'ring2' end
        release_protected_ring_slots(slots, buff..' active')
    end
    update_hud(true)
end

local function resume_swaps(message)
    enable(unpack(ALL_EQUIP_SLOTS)); invalidate_ring_lock_cache()
    if fishing_mode_active() then
        equip(sets.Fishing); apply_fishing_slot_policy()
        if message then chat(158,'[BLU] Fishing Mode remains active; non-ring slots stay frozen.') end
        return
    end
    reapply_runtime_locks()
    if not (buffactive and buffactive.doom) and type(handle_equipping_gear)=='function' and player then handle_equipping_gear(player.status) end
    local deferred={}; if releasing.ring1 then deferred[#deferred+1]='ring1' end; if releasing.ring2 then deferred[#deferred+1]='ring2' end
    if #deferred>0 then settle_released_ring_slots(deferred) end
    if message then chat(158,message) end
end

function job_state_change(descriptor,newValue,oldValue)
    if descriptor=='PauseSwaps' or descriptor=='Pause Gear Swapping' then
        if pause_swaps_active() then disable(unpack(ALL_EQUIP_SLOTS)); chat(167,'[BLU] GearSwap PAUSED: all equipment slots frozen.')
        elseif fishing_mode_active() then resume_swaps('[BLU] Pause off.')
        else resume_swaps('[BLU] GearSwap RESUMED.') end
    elseif descriptor=='FishingMode' or descriptor=='Fishing Mode' then
        if fishing_mode_active() then
            enable(unpack(ALL_EQUIP_SLOTS)); equip(sets.Fishing); apply_fishing_slot_policy()
            chat(167,'[BLU] FISHING MODE: fishing gear locked; rings remain available for protection/movement.')
        else
            clear_fishing_rod()
            if pause_swaps_active() then disable(unpack(ALL_EQUIP_SLOTS)); chat(158,'[BLU] Fishing off; Pause still owns the full freeze.')
            else resume_swaps('[BLU] Fishing Mode OFF.') end
        end
    elseif descriptor=='Treasure Hunter' or descriptor=='TreasureMode' then
        reset_th_tracker(false); chat(158,'[BLU TH] Mode: '..tostring(state.TreasureMode.value))
        if not midaction() and type(handle_equipping_gear)=='function' and player then handle_equipping_gear(player.status) end
    elseif descriptor=='Weapon Set' or descriptor=='WeaponSet' or descriptor=='Weapon Lock' or descriptor=='WeaponLock' then
        check_weaponset(true); invalidate_haste_cache(); update_native_haste_dw(true)
    elseif descriptor=='Haste Tier' or descriptor=='HasteTier' then
        invalidate_haste_cache(); update_native_haste_dw(true)
    elseif descriptor=='Auto Burst Detect' or descriptor=='AutoBurst' then
        if not state.AutoBurst.value then clear_burst_window() end
    elseif descriptor=='Auto Unbridled Learning' or descriptor=='AutoUnbridled' then
        if not state.AutoUnbridled.value then unbridled_ctl.pending=nil; unbridled_ctl.generation=unbridled_ctl.generation+1 end
    elseif descriptor=='Blue Magic Learning' or descriptor=='LearningMode' then
        if not midaction() and type(handle_equipping_gear)=='function' and player then handle_equipping_gear(player.status) end
        chat(158,'[BLU Learning] Magus Bazubands '..bool_word(state.LearningMode.value)..'.')
    elseif descriptor=='Spell Profile' or descriptor=='SpellProfile' then
        chat(158,'[BLU Profile] Selected '..tostring(state.SpellProfile.value)..'; selection does not change spells.')
    elseif descriptor=='Entomb Objective' or descriptor=='EntombMode' then
        chat(158,'[BLU Entomb] Objective: '..tostring(state.EntombMode.value)..'.')
    end
    update_hud(true)
end

function job_status_change(newStatus,oldStatus,eventArgs)
    refresh_trait_cache(false); invalidate_haste_cache(); update_native_haste_dw(true)
    th_sync_target(); protected_ring_check(); check_weaponset(false); update_hud(true)
end

function job_handle_equipping_gear(playerStatus,eventArgs)
    protected_ring_check(); check_moving()
end

function job_update(cmdParams,eventArgs)
    refresh_trait_cache(false); update_native_haste_dw(false); th_sync_target(); protected_ring_check(); check_weaponset(false); update_hud(false)
end

function job_sub_job_change(newSubjob,oldSubjob)
    refresh_trait_cache(true); invalidate_haste_cache(); update_native_haste_dw(true); check_weaponset(true)
    if type(handle_equipping_gear)=='function' and player then handle_equipping_gear(player.status) end
    update_hud(true)
end

-------------------------------------------------------------------------------------------------------------------
-- Set-aware Blue Magic utility commands
-------------------------------------------------------------------------------------------------------------------
-- Set-aware Blue Magic utility commands
--
-- These are intentionally macro commands, not extra global binds:
--   /console gs c utility sleep
--   /console gs c utility stun
--   /console gs c utility heal
--   /console gs c utility haste
--   /console gs c utility refresh
-------------------------------------------------------------------------------------------------------------------

local UTILITY_PRIORITY = {
    sleep = {
        {name='Dream Flower', target='<t>'},
        {name='Sheep Song', target='<t>'},
        {name='Soporific', target='<t>'},
        {name='Yawn', target='<t>'},
    },
    stun = {
        {name='Sudden Lunge', target='<t>'},
        {name='Head Butt', target='<t>'},
        {name='Temporal Shift', target='<t>'},
        {name='Blitzstrahl', target='<t>'},
    },
    heal = {
        {name='Magic Fruit', target='<stpc>'},
        {name='Restoral', target='<me>'},
        {name='White Wind', target='<me>'},
        {name='Wild Carrot', target='<stpc>'},
        {name='Pollen', target='<me>'},
    },
    haste = {
        {name='Erratic Flutter', target='<me>'},
        {name='Animating Wail', target='<me>'},
        {name='Refueling', target='<me>'},
    },
    refresh = {
        {name='Battery Charge', target='<me>'},
    },
}

local function spell_recast_remaining(name)
    local spell = blu_res.spells and blu_res.spells:with('en', name)
    local fn = windower and windower.ffxi and windower.ffxi.get_spell_recasts
    if not spell or type(fn) ~= 'function' then return math.huge end
    local recasts = fn() or {}
    return tonumber(recasts[spell.id]) or math.huge
end

local function cast_utility(kind)
    kind = (kind or ''):lower()
    local choices = UTILITY_PRIORITY[kind]
    if not choices then
        chat(123, '[BLU Utility] sleep | stun | heal | haste | refresh')
        return
    end
    refresh_trait_cache(false)
    local first_set
    for _, choice in ipairs(choices) do
        if spell_is_set(choice.name) then
            first_set = first_set or choice.name
            if spell_recast_remaining(choice.name) == 0 then
                chat(158, '[BLU Utility] '..kind..' -> '..choice.name)
                windower.chat.input('/ma "'..choice.name..'" '..choice.target)
                return
            end
        end
    end
    if first_set then
        chat(123, '[BLU Utility] No '..kind..' option is ready; first set spell is '..first_set..'.')
    else
        chat(123, '[BLU Utility] No recognized '..kind..' spell is currently set.')
    end
end

-------------------------------------------------------------------------------------------------------------------
-- Diagnostics
-------------------------------------------------------------------------------------------------------------------

local function report_traits()
    refresh_trait_cache(true)
    chat(158, string.format(
        '[BLU Traits] JP=%d | gift tiers=+%d | sub=%s%d',
        trait_cache.jp_spent, trait_cache.gift_tiers,
        tostring(player and player.sub_job or 'NON'),
        tonumber(player and player.sub_job_level) or 0))
    chat(158, string.format(
        '[BLU Traits] Dual Wield: %d pts -> BLU tier %d (%d%%); sub %d%%; ACTIVE %d%%',
        trait_cache.points.DualWield, trait_cache.blu_tier.DualWield,
        trait_cache.blu_value.DualWield, trait_cache.sub_value.DualWield,
        trait_cache.value.DualWield))
    chat(158, '  DW spells: '..(#trait_cache.contributors.DualWield > 0
        and table.concat(trait_cache.contributors.DualWield, ', ') or 'none'))
    chat(158, string.format(
        '[BLU Traits] Fast Cast: %d pts -> BLU tier %d (%d%%); sub %d%%; ACTIVE %d%%',
        trait_cache.points.FastCast, trait_cache.blu_tier.FastCast,
        trait_cache.blu_value.FastCast, trait_cache.sub_value.FastCast,
        trait_cache.value.FastCast))
    chat(158, '  FC spells: '..(#trait_cache.contributors.FastCast > 0
        and table.concat(trait_cache.contributors.FastCast, ', ') or 'none'))
end

local function report_dw()
    update_native_haste_dw(true)
    local plan = dw_plan_current()
    local pieces = {}
    for _, candidate in ipairs(DW_CANDIDATES) do
        if plan.set[candidate.slot] then
            pieces[#pieces + 1] = candidate.name..'+'..candidate.dw
        end
    end
    chat(158, string.format(
        '[BLU DW] profile=%s dual=%s | trait=%d | haste=%d/819 (%.1f%%)',
        tostring(state.WeaponSet.value), tostring(selected_profile_is_dual()),
        native_dw_trait, native_haste, native_haste / 1024 * 100))
    chat(158, string.format(
        '[BLU DW] total DW target=%d | gear need=%d | planned=%d | shortfall=%d',
        native_dw_active and dw_needed_at_haste(native_haste) or 0,
        native_dw_need, plan.have, plan.shortfall))
    chat(158, '  overlay: '..(#pieces > 0 and table.concat(pieces, ', ') or 'none'))
    chat(158, '  exact pool: Eabani 4, Suppanomimi 5, Carmine legs 6, Taeon feet 4 (max 19).')
end

local function report_fc()
    refresh_trait_cache(true)
    local gear=live_precast_fc_gear()
    local total=trait_cache.value.FastCast+gear
    chat(158,string.format(
        '[BLU FC] live trait=%d%% (BLU=%d, sub=%d; stronger wins) + configured gear=%d%% -> %d%% precast',
        trait_cache.value.FastCast,trait_cache.blu_value.FastCast,trait_cache.sub_value.FastCast,gear,total))
    chat(158,"[BLU FC] Non-weapon core=34: Amalric11 + Vanir5 + Aya legs6 + Loquac2 + Enchntr2 + Kishar4 + Naji1 + Witful3. Live Sakpata Sword adds 10 when equipped.")
    if total<80 then
        chat(158,'[BLU FC] Cast-time cap shortfall: '..tostring(80-total)..' points before external effects/instant-cast procs.')
    end
end

local function report_haste()
    update_native_haste_dw(true)
    local gi_alive = gearinfo_last and os.clock() - gearinfo_last <= GEARINFO_STALE_SECONDS or false
    chat(158, string.format(
        '[BLU Haste] native=%d/819 (%.1f%%): engaged gear=%d + magic=%d; manual magic adj=%+.1f%%',
        native_haste, native_haste / 1024 * 100,
        player and player.status == 'Engaged' and 256 or 0,
        refresh_magic_haste(), haste_manual_magic / 1024 * 100))
    if gi_alive then
        chat(158, string.format(
            '[BLU Haste] GearInfo comparison=%d/1024 (%.1f%%), DW need=%d.',
            gi_haste, gi_haste / 1024 * 100, gi_dw_need))
    else
        chat(158, '[BLU Haste] GearInfo offline/stale; native tracking remains authoritative.')
    end
    chat(158, '[BLU Haste] Haste icon tier='..tostring(state.HasteTier.value)
        ..'; use "gs c hasteadj <percent>" for invisible Geo-Haste.')
end

local function report_burst()
    chat(158, string.format(
        '[BLU Burst] Auto=%s | manual=%s | affinity-capable=%s | window=%s | target=%s | %.1fs',
        bool_word(state.AutoBurst.value), bool_word(state.MagicBurst.value),
        tostring(auto_burst_affinity_active()), tostring(sc_window.name),
        tostring(sc_window.target_id), math.max(0, sc_window.expires - os.clock())))
    chat(158, '[BLU Burst] Auto requires Burst Affinity or Azure Lore plus matching target/element.')
    chat(158, '[BLU Burst] F11 manual mode is an explicit gear override and does not claim the spell can burst.')
end

local function report_th()
    local id = th_sync_target()
    chat(158, string.format('[BLU TH] mode=%s | target=%s | tagged=%s',
        tostring(state.TreasureMode.value), tostring(id), tostring(th_tracker.tagged)))
end

local function report_ring_info()
    for _, slot in ipairs({'ring1','ring2'}) do
        local name = current_ring_name(slot)
        chat(158, string.format('[BLU Rings] %s=%s | protected=%s | releasing=%s',
            slot, tostring(name), tostring(NO_SWAP_GEAR[name] == true),
            tostring(releasing[slot])))
    end
end

local function policy_lookup_case_insensitive(query)
    local wanted = (query or ''):lower()
    for name, policy in pairs(BLUE_MAGIC_POLICY) do
        if name:lower() == wanted then return name, policy end
    end
end

local function report_spell_info(query)
    local name, policy = policy_lookup_case_insensitive(query)
    if not policy then
        chat(123, '[BLU Policy] No exact spell entry for "'..tostring(query)..'".')
        return
    end
    chat(158, '[BLU Policy] '..name)
    chat(158, '  family='..policy.family)
    chat(158, '  source='..policy.source_set)
    chat(158, '  objective='..policy.objective)
    chat(158, '  set='..tostring(spell_is_set(name))
        ..' | unbridled='..tostring(UNBRIDLED_SPELLS[name] == true))
end

local function validate_blue_policy_resources()
    local resource_names = {}
    local resource_count = 0
    for _, spell in pairs(blu_res.spells or {}) do
        if type(spell) == 'table' and spell.type == 'BlueMagic' then
            local name = spell.en or spell.english
            if name and name ~= '' and not resource_names[name] then
                resource_names[name] = true
                resource_count = resource_count + 1
            end
        end
    end
    local invalid, missing = {}, {}
    for name in pairs(BLUE_MAGIC_MAP) do
        if not resource_names[name] then invalid[#invalid + 1] = name end
    end
    for name in pairs(resource_names) do
        if not BLUE_MAGIC_MAP[name] then missing[#missing + 1] = name end
    end
    table.sort(invalid)
    table.sort(missing)
    return invalid, missing, resource_count
end

local function report_sird()
    chat(158, string.format(
        '[BLU SIRD] owned set=%d/%d | first-hit TH Tag=%d/%d',
        BLU_SIRD_TOTALS.base, BLU_SIRD_TOTALS.cap,
        BLU_SIRD_TOTALS.th_tag, BLU_SIRD_TOTALS.cap))
    chat(158, '[BLU SIRD] Staunch 11 + Carmine legs 20 + Magnetic 8 + Evanescence 5 + Murky 3 + Rumination 10.')
    chat(123, '[BLU SIRD] This is the owned maximum, not the 102-point interruption cap; Aquaveil still matters.')
end

local function report_policy()
    local family_names = {}
    for family in pairs(BLUE_FAMILY_COUNTS) do family_names[#family_names + 1] = family end
    table.sort(family_names)
    local summary = {}
    local total = 0
    for _, family in ipairs(family_names) do
        summary[#summary + 1] = family..'='..BLUE_FAMILY_COUNTS[family]
        total = total + BLUE_FAMILY_COUNTS[family]
    end
    local invalid, missing, resource_count = validate_blue_policy_resources()
    local color = (#invalid == 0 and #missing == 0 and #BLUE_POLICY_DUPLICATES == 0) and 158 or 123
    chat(color, string.format('[BLU Policy] %d routes / %d resource spells across %d families; duplicates=%d; invalid=%d; missing=%d.',
        total, resource_count, #family_names, #BLUE_POLICY_DUPLICATES, #invalid, #missing))
    chat(158, '  '..table.concat(summary, ' | '))
    if #BLUE_POLICY_DUPLICATES > 0 then
        chat(123, '  duplicate routes: '..table.concat(BLUE_POLICY_DUPLICATES, ', '))
    end
    if #invalid > 0 then chat(123, '  invalid resource names: '..table.concat(invalid, ', ')) end
    if #missing > 0 then chat(123, '  unrouted resource spells: '..table.concat(missing, ', ')) end
    chat(158, '  Use: gs c spellinfo <exact English spell name>')
end

local function report_unbridled()
    local count = 0
    for _ in pairs(UNBRIDLED_SPELLS) do count = count + 1 end
    chat(158, string.format(
        '[BLU Unbridled] auto=%s | access=%s | UL recast=%s | pending=%s | tracked spells=%d',
        bool_word(state.AutoUnbridled.value), tostring(unbridled_access_active()),
        ability_recast_remaining('Unbridled Learning') == math.huge and '?'
            or tostring(ability_recast_remaining('Unbridled Learning')),
        unbridled_ctl.pending and unbridled_ctl.pending.spell or 'none', count))
end

-------------------------------------------------------------------------------------------------------------------
-- Self commands
-------------------------------------------------------------------------------------------------------------------

function job_self_command(cmdParams, eventArgs)
    local cmd = (cmdParams[1] or ''):lower()
    if cmd == '_movementrefresh' then
        movement_monitor.refresh_queued=false; eventArgs.handled=true
        if BLU_RUNTIME.unloading or cmdParams[2]~=BLU_RUNTIME.token then return end
        if not movement_monitor.refresh_pending then update_hud(false); return end
        check_moving()
        if pause_swaps_active() or (type(midaction)=='function' and midaction()) then return end
        local slot=moving and movement_ring_slot() or nil
        if slot and not protected_ring_active(slot) then enable(slot); ring_lock_state[slot]=false end
        movement_monitor.refresh_pending=false
        if type(handle_equipping_gear)=='function' and player then
            handle_equipping_gear(player.status); if fishing_mode_active() then apply_fishing_slot_policy() end
        end
        update_hud(false)
        return
    end
    if handle_gearinfo_command(cmdParams) then
        eventArgs.handled = true
        return
    end

    if cmd == '_startupkeys' then
        if cmdParams[2] == BLU_RUNTIME.token and not BLU_RUNTIME.unloading then
            report_keybinds(true)
        end
        eventArgs.handled = true
    elseif cmd == '_unbridledcast' then
        execute_pending_unbridled(cmdParams[2], cmdParams[3])
        eventArgs.handled = true
    elseif cmd == 'bluprofile' or cmd == 'profile' then
        local action = tostring(cmdParams[2] or 'show'):lower()
        if action == 'list' then
            list_spell_profiles()
        elseif action == 'next' or action == 'previous' or action == 'prev' then
            select_spell_profile(action == 'prev' and 'previous' or action)
        elseif action == 'preview' or action == 'show' then
            local key = resolve_profile_key(cmdParams[3])
                or resolve_profile_key(state.SpellProfile.value)
            report_spell_profile(key, action == 'preview')
        elseif action == 'apply' or action == 'install' then
            apply_spell_profile(cmdParams[3] or state.SpellProfile.value)
        elseif action == 'cancel' or action == 'stop' then
            cancel_profile_install('Install canceled by user.')
        else
            local key = resolve_profile_key(cmdParams[2])
            if not key then
                chat(123, '[BLU Profile] Unknown profile. Use: gs c bluprofile list')
            elseif tostring(cmdParams[3] or ''):lower() == 'apply' then
                apply_spell_profile(key)
            else
                state.SpellProfile:set(key)
                report_spell_profile(key, false)
                chat(158, '  Selection only; apply explicitly with: gs c bluprofile apply')
            end
        end
        eventArgs.handled=true
    elseif cmd == 'entombmode' or cmd == 'entomb' then
        local objective = tostring(cmdParams[2] or ''):lower()
        if objective == 'damage' then state.EntombMode:set('Damage')
        elseif objective == 'control' or objective == 'macc' then state.EntombMode:set('Control')
        else state.EntombMode:cycle() end
        chat(158, '[BLU Entomb] Objective: '..tostring(state.EntombMode.value)..'.')
        eventArgs.handled=true
    elseif cmd == 'bluweapon' or cmd == 'weapon' then
        local arg=(cmdParams[2] or 'next'):lower()
        if arg=='next' or arg=='forward' then cycle_weapon_profile('next')
        elseif arg=='previous' or arg=='prev' or arg=='back' then cycle_weapon_profile('previous')
        else apply_weapon_profile(cmdParams[2]) end
        eventArgs.handled=true
    elseif cmd == 'bludefense' or cmd == 'defense' then
        local arg=(cmdParams[2] or 'cycle'):lower()
        if arg=='next' or arg=='cycle' then cycle_defense_control() else apply_defense_control(arg) end
        eventArgs.handled=true
    elseif cmd == 'primaryws' or cmd == 'bestws' then
        execute_context_weaponskill(); eventArgs.handled=true
    elseif cmd == 'hudlayout' then
        set_hud_layout(cmdParams[2]); eventArgs.handled=true
    elseif cmd == 'hudscale' then
        set_hud_scale(cmdParams[2]); eventArgs.handled=true
    elseif cmd == 'hudopacity' then
        set_hud_opacity(cmdParams[2]); eventArgs.handled=true
    elseif cmd == 'hudsection' then
        set_hud_section(cmdParams[2],cmdParams[3]); eventArgs.handled=true
    elseif cmd == 'moveinfo' then
        chat(158,string.format('[BLU Move] moving=%s | route=%s | pending=%s | queued=%s | sample=%.2fs | stop=%.2fs',
            tostring(moving),movement_route_label(),tostring(movement_monitor.refresh_pending),
            tostring(movement_monitor.refresh_queued),movement_monitor.sample_interval,movement_monitor.stop_debounce))
        eventArgs.handled=true
    elseif cmd == 'version' then
        chat(158, 'Falurian BLU GearSwap v'..BLU_RELEASE_VERSION..' ('..BLU_RELEASE_DATE..')')
        eventArgs.handled = true
    elseif cmd == 'keybinds' or cmd == 'keys' then
        report_keybinds()
        eventArgs.handled = true
    elseif cmd == 'hud' then
        toggle_hud()
        eventArgs.handled = true
    elseif cmd == 'hudlock' then
        toggle_hud_lock()
        eventArgs.handled = true
    elseif cmd == 'traits' or cmd == 'traitinfo' or cmd == 'spellset' then
        report_traits()
        eventArgs.handled = true
    elseif cmd == 'dwinfo' or cmd == 'dw' then
        report_dw()
        eventArgs.handled = true
    elseif cmd == 'fcinfo' or cmd == 'fastcast' then
        report_fc()
        eventArgs.handled = true
    elseif cmd == 'sirdinfo' or cmd == 'sird' then
        report_sird()
        eventArgs.handled = true
    elseif cmd == 'hasteinfo' or cmd == 'hastecheck' then
        report_haste()
        eventArgs.handled = true
    elseif cmd == 'hastetier' then
        local tier = tonumber(cmdParams[2])
        if tier == 1 or tier == 2 then
            state.HasteTier:set(tier)
            invalidate_haste_cache()
            update_native_haste_dw(true)
            if type(handle_equipping_gear) == 'function' and player then
                handle_equipping_gear(player.status)
            end
        end
        chat(158, '[BLU Haste] Shared Haste icon assumed tier '..tostring(state.HasteTier.value)..'.')
        eventArgs.handled = true
    elseif cmd == 'hasteadj' then
        local percent = tonumber(cmdParams[2]) or 0
        haste_manual_magic = math.floor(percent / 100 * 1024 + (percent >= 0 and 0.5 or -0.5))
        invalidate_haste_cache()
        update_native_haste_dw(true)
        if type(handle_equipping_gear) == 'function' and player then
            handle_equipping_gear(player.status)
        end
        chat(158, string.format('[BLU Haste] Manual magic adjustment=%+.1f%%.', percent))
        eventArgs.handled = true
    elseif cmd == 'burstinfo' then
        report_burst()
        eventArgs.handled = true
    elseif cmd == 'unbridledinfo' or cmd == 'ulinfo' then
        report_unbridled()
        eventArgs.handled = true
    elseif cmd == 'thinfo' then
        report_th()
        eventArgs.handled = true
    elseif cmd == 'threset' then
        reset_th_tracker(true)
        if type(handle_equipping_gear) == 'function' and player then
            handle_equipping_gear(player.status)
        end
        eventArgs.handled = true
    elseif cmd == 'ringinfo' then
        report_ring_info()
        eventArgs.handled = true
    elseif cmd == 'spellinfo' then
        report_spell_info(table.concat(cmdParams, ' ', 2))
        eventArgs.handled = true
    elseif cmd == 'policy' or cmd == 'gearpolicy' then
        report_policy()
        eventArgs.handled = true
    elseif cmd == 'utility' or cmd == 'blu' then
        cast_utility(cmdParams[2])
        eventArgs.handled = true
    elseif cmd == 'asets' or cmd == 'azureset' then
        local profile = table.concat(cmdParams, ' ', 2)
        if profile == '' or profile:find('[^%w_%-]') then
            chat(123, '[BLU AzureSets] Usage: gs c asets <saved_name> (letters/numbers/_/- only).')
        else
            send_command('aset spellset '..profile)
            chat(158, '[BLU AzureSets] Applying saved spell set: '..profile
                ..'. Trait cache will refresh on the next GearSwap update/cast.')
        end
        eventArgs.handled = true
    elseif cmd == 'perf' then
        local sub = (cmdParams[2] or ''):lower()
        if sub == 'on' then
            perf.enabled = true
            perf_reset()
            chat(158, '[BLU Perf] ON')
        elseif sub == 'off' then
            perf_report()
            perf.enabled = false
            chat(158, '[BLU Perf] OFF')
        elseif sub == 'reset' then
            perf_reset()
            chat(158, '[BLU Perf] reset')
        else
            perf_report()
        end
        eventArgs.handled = true
    end
end

-------------------------------------------------------------------------------------------------------------------
-- Appearance. Macro switching is deliberately opt-in so this file never overwrites an existing BLU book.
-------------------------------------------------------------------------------------------------------------------

BLU_CONFIG = {
    macro_book = nil, -- set to a number (1-20) if desired
    macro_page = 1,
    lockstyle = 24,
}

function select_default_macro_book()
    if BLU_CONFIG.macro_book then
        send_command(string.format('input /macro book %d; wait 0.1; input /macro set %d',
            BLU_CONFIG.macro_book, BLU_CONFIG.macro_page or 1))
    end
end

function set_lockstyle()
    if BLU_CONFIG.lockstyle then
        send_command('wait 2; input /lockstyleset '..tostring(BLU_CONFIG.lockstyle))
    end
end
