-- Falurian NIN GearSwap v1.6.9
-- Full release: v1.5 QoL foundation + bounded NIN utility layer (Fishing/TH/Shadows/Stance/Element/DNC/readiness).
-- Architecture: Mote-based, derived from lessons learned in Falurian RDM.
-- Inventory policy: source-set gear is restricted to the supplied owned/NIN-valid wardrobe.
-- Runtime Gear Audit is intentionally absent. Heavy inventory validation is offline only.

local NIN_RELEASE_VERSION = '1.6.9'
local NIN_RELEASE_DATE = '2026-07-19'
local nin_res = require('resources')
local elemental_wheel_reset
local skillchain_reset


-- Runtime lifecycle registry. Every custom Windower event owned by this job is tracked and
-- explicitly unregistered on unload/reload. Delayed callbacks also check `unloading`/token.
local NIN_RUNTIME = {
    unloading=false,
    event_ids={},
    token=tostring(os.time())..'-'..tostring(math.floor(os.clock()*1000000)),
}

local function track_nin_event(id)
    if id ~= nil then NIN_RUNTIME.event_ids[#NIN_RUNTIME.event_ids+1]=id end
    return id
end

local function unregister_nin_events()
    if windower and type(windower.unregister_event)=='function' then
        for _,id in ipairs(NIN_RUNTIME.event_ids) do pcall(windower.unregister_event,id) end
    end
    NIN_RUNTIME.event_ids={}
end

local ALL_EQUIP_SLOTS={'main','sub','range','ammo','head','neck','ear1','ear2','body','hands','ring1','ring2','back','waist','legs','feet'}
local WARP_GEAR={['Warp Ring']=true,['Dim. Ring (Dem)']=true,['Dim. Ring (Holla)']=true,['Dim. Ring (Mea)']=true}
local BOOST_GEAR={['Trizek Ring']=true,['Echad Ring']=true,['Facility Ring']=true,['Capacity Ring']=true,['Jubilee Ring']=true,['Empress Band']=true}
local NO_SWAP_GEAR={}
for name in pairs(WARP_GEAR) do NO_SWAP_GEAR[name]=true end
for name in pairs(BOOST_GEAR) do NO_SWAP_GEAR[name]=true end
local BOOST_BUFFS={dedication=true,commitment=true}
local releasing={ring1=false,ring2=false}
local handle_th_action=function(act) end
local ring_lock_state={ring1=nil,ring2=nil}
local moving=false
local gearinfo_last=nil
local GEARINFO_STALE_SECONDS=12

local function current_ring_name(slot)
    local eq=player and player.equipment or nil
    if not eq then return nil end
    if slot=='ring1' then return eq.left_ring or eq.ring1 end
    return eq.right_ring or eq.ring2
end

local function invalidate_ring_lock_cache()
    ring_lock_state.ring1=nil
    ring_lock_state.ring2=nil
end

local function apply_ring_lock(slot,should_lock)
    if ring_lock_state[slot]==should_lock then return end
    if should_lock then disable(slot) else enable(slot) end
    ring_lock_state[slot]=should_lock
end

local function protected_ring_check()
    if not state then return end
    if state.PauseSwaps and state.PauseSwaps.value then return end
    if state.FishingMode and state.FishingMode.value then return end
    if buffactive and buffactive.doom then return end
    apply_ring_lock('ring1',NO_SWAP_GEAR[current_ring_name('ring1')]==true and not releasing.ring1)
    apply_ring_lock('ring2',NO_SWAP_GEAR[current_ring_name('ring2')]==true and not releasing.ring2)
end

local function reapply_runtime_locks()
    if state and ((state.PauseSwaps and state.PauseSwaps.value) or (state.FishingMode and state.FishingMode.value)) then
        disable(unpack(ALL_EQUIP_SLOTS))
        return
    end
    enable(unpack(ALL_EQUIP_SLOTS))
    invalidate_ring_lock_cache()
    if state and state.WeaponLock and state.WeaponLock.value then disable('main','sub') end
    if buffactive and buffactive.doom and sets and sets.buff and sets.buff.Doom then
        enable('neck','ring1','ring2','waist')
        equip(sets.buff.Doom)
        disable('neck','ring1','ring2','waist')
        return
    end
    protected_ring_check()
end

local function settle_released_ring_slots(slots)
    local token=NIN_RUNTIME.token
    coroutine.schedule(function()
        if NIN_RUNTIME.unloading or token~=NIN_RUNTIME.token then return end
        for _,slot in ipairs(slots or {}) do releasing[slot]=false end
        protected_ring_check()
    end,1)
end

local function release_protected_ring_slots(slots,reason)
    local any=false
    for _,slot in ipairs(slots or {}) do
        releasing[slot]=true
        ring_lock_state[slot]=false
        any=true
    end
    if not any then return end
    if reason then add_to_chat(158,'[NIN Ring] Releasing protected ring: '..reason) end
    if state and state.PauseSwaps and state.PauseSwaps.value then
        add_to_chat(158,'[NIN Ring] Release deferred until GearSwap resumes.')
        return
    end
    for _,slot in ipairs(slots) do enable(slot) end
    if type(handle_equipping_gear)=='function' and player then handle_equipping_gear(player.status) end
    settle_released_ring_slots(slots)
end

-------------------------------------------------------------------------------------------------------------------
-- Bounded utility controllers added in v1.6.
-- Defaults intentionally avoid Silmaril overlap: ShadowMode=Off, Stance=None; elemental nuke is key-driven only.
-------------------------------------------------------------------------------------------------------------------

-- Treasure Hunter: lightweight per-target Tag tracking, no Mote-TreasureHunter dependency.
local th_tracker={target_id=nil,tagged=false,pending_target_id=nil}

local function current_target_mob()
    local fn=windower and windower.ffxi and windower.ffxi.get_mob_by_target
    return type(fn)=='function' and fn('t') or nil
end

local function th_sync_target()
    if not state or not state.TreasureMode then return nil end
    local mob=current_target_mob()
    local id=mob and mob.id or nil
    if id~=th_tracker.target_id then
        th_tracker.target_id=id
        th_tracker.tagged=false
        th_tracker.pending_target_id=nil
    end
    return id
end

local function th_should_apply(target_id)
    if not state or not state.TreasureMode then return false end
    local mode=state.TreasureMode.value
    if mode=='Off' then return false end
    if mode=='Fulltime' then return true end
    if mode~='Tag' then return false end
    th_sync_target()
    if target_id and th_tracker.target_id~=target_id then
        th_tracker.target_id=target_id; th_tracker.tagged=false; th_tracker.pending_target_id=nil
    end
    return target_id~=nil and not th_tracker.tagged
end

local function th_mark_tagged(target_id,source)
    if not target_id or not state or not state.TreasureMode or state.TreasureMode.value~='Tag' then return end
    if th_tracker.target_id~=target_id then return end
    if th_tracker.tagged then return end
    th_tracker.tagged=true
    th_tracker.pending_target_id=nil
    add_to_chat(158,'[NIN TH] Target tagged'..(source and (' via '..source) or '')..'; restoring combat gear.')
    if not NIN_RUNTIME.unloading and not midaction() and type(handle_equipping_gear)=='function' and player then handle_equipping_gear(player.status) end
    if type(update_hud)=='function' then update_hud(true) end
end

handle_th_action=function(act)
    if NIN_RUNTIME.unloading or not act or not player or act.actor_id~=player.id then return end
    if not state or not state.TreasureMode or state.TreasureMode.value~='Tag' or th_tracker.tagged then return end
    -- Category 1 is a normal melee round. Tag mode wears TH gear until this first player action lands.
    if act.category==1 and act.targets then
        for _,target in pairs(act.targets) do
            if target and target.id and target.id==th_tracker.target_id then th_mark_tagged(target.id,'melee'); return end
        end
    end
end

local function th_action_overlay(spell)
    if not spell or not spell.target or spell.target.type~='MONSTER' then return false end
    if not th_should_apply(spell.target.id) then return false end
    th_tracker.pending_target_id=spell.target.id
    return true
end

local function reset_th_tracker(verbose)
    th_tracker.target_id=nil; th_tracker.tagged=false; th_tracker.pending_target_id=nil
    th_sync_target()
    if verbose then add_to_chat(158,'[NIN TH] Tag state reset for current target.') end
end

-- Weapon-skill range safety. Approximate resource formula published by Windower staff; fail only when clearly out.
local WS_RANGE_MULT={[0]=0,[2]=1.70,[3]=1.490909,[4]=1.44,[5]=1.377778,[6]=1.30,[7]=1.20,[8]=1.30,[9]=1.377778,[10]=1.45,[11]=1.490909,[12]=1.70}
local function ws_max_distance(spell)
    if not spell or not spell.target then return nil end
    local range=tonumber(spell.range)
    local mult=range and WS_RANGE_MULT[range]
    if not mult then return nil end
    return (tonumber(spell.target.model_size) or 0)+(range*mult)
end

local function ws_out_of_range(spell)
    if not spell or spell.type~='WeaponSkill' or not spell.target or spell.target.type~='MONSTER' then return false,nil end
    local actual=tonumber(spell.target.distance)
    local maxd=ws_max_distance(spell)
    if not actual or not maxd then return false,maxd end
    return actual>(maxd+0.20),maxd
end

-- Desired stance is explicit opt-in only. No stance is selected automatically.
local stance_runtime={pending=false,last_attempt=0}
local function ability_ready(name)
    local ja=nin_res.job_abilities and nin_res.job_abilities:with('en',name)
    local fn=windower and windower.ffxi and windower.ffxi.get_ability_recasts
    if not ja or type(fn)~='function' then return false end
    local recasts=fn() or {}
    return (tonumber(recasts[ja.recast_id]) or 0)==0
end

local function maintain_selected_stance(reason)
    if NIN_RUNTIME.unloading or not state or not state.Stance or state.Stance.value=='None' then return end
    if not player or player.status~='Engaged' or midaction() then return end
    if state.PauseSwaps and state.PauseSwaps.value then return end
    if state.FishingMode and state.FishingMode.value then return end
    if buffactive and buffactive.amnesia then return end
    local desired=state.Stance.value
    if buffactive and buffactive[desired:lower()] then stance_runtime.pending=false; return end
    if stance_runtime.pending or os.clock()-(stance_runtime.last_attempt or 0)<2.5 then return end
    if not ability_ready(desired) then return end
    stance_runtime.pending=true; stance_runtime.last_attempt=os.clock()
    add_to_chat(158,'[NIN Stance] Reapplying selected stance: '..desired..'.')
    send_command('input /ja "'..desired..'" <me>')
    local token=NIN_RUNTIME.token
    coroutine.schedule(function()
        if NIN_RUNTIME.unloading or token~=NIN_RUNTIME.token then return end
        stance_runtime.pending=false
    end,3)
end

-- Shadow manager. Off = manual-only smart Ichi handling; Safe = auto-cast only at 0 shadows;
-- Tank = auto-refresh at 0, and at 1 shadow with San/Ni. Event-driven only; no frame polling.
local shadow_runtime={pending=nil,last_attempt=0,ichi_generation=0}
local function shadow_count_numeric()
    if buffactive and buffactive['Copy Image (4+)'] then return 4 end
    if buffactive and buffactive['Copy Image (3)'] then return 3 end
    if buffactive and buffactive['Copy Image (2)'] then return 2 end
    if buffactive and buffactive['Copy Image'] then return 1 end
    return 0
end

local function spell_ready(name)
    local sp=nin_res.spells and nin_res.spells:with('en',name)
    local fn=windower and windower.ffxi and windower.ffxi.get_spell_recasts
    if not sp or type(fn)~='function' then return false end
    local recasts=fn() or {}
    return (tonumber(recasts[sp.id]) or 0)==0
end

local function spell_recast_remaining(name)
    local sp=nin_res.spells and nin_res.spells:with('en',name)
    local fn=windower and windower.ffxi and windower.ffxi.get_spell_recasts
    if not sp or type(fn)~='function' then return 0 end
    local recasts=fn() or {}
    return math.max(0,tonumber(recasts[sp.id]) or 0)
end

local function shadow_pick_spell(count,mode)
    if count<=0 then
        if spell_ready('Utsusemi: San') then return 'Utsusemi: San' end
        if spell_ready('Utsusemi: Ni') then return 'Utsusemi: Ni' end
        if spell_ready('Utsusemi: Ichi') then return 'Utsusemi: Ichi' end
    elseif mode=='Tank' and count<=1 then
        if spell_ready('Utsusemi: San') then return 'Utsusemi: San' end
        if spell_ready('Utsusemi: Ni') then return 'Utsusemi: Ni' end
    end
    return nil
end

local function shadow_auto_check(reason)
    if NIN_RUNTIME.unloading or not state or not state.ShadowMode or state.ShadowMode.value=='Off' then return end
    if not player or player.status~='Engaged' or midaction() or moving then return end
    if state.PauseSwaps and state.PauseSwaps.value then return end
    if state.FishingMode and state.FishingMode.value then return end
    if buffactive and (buffactive.silence or buffactive['mute']) then return end
    if shadow_runtime.pending or os.clock()-(shadow_runtime.last_attempt or 0)<2.0 then return end
    local count=shadow_count_numeric()
    local mode=state.ShadowMode.value
    if mode=='Safe' and count>0 then return end
    if mode=='Tank' and count>1 then return end
    local spell=shadow_pick_spell(count,mode)
    if not spell then return end
    shadow_runtime.pending=spell; shadow_runtime.last_attempt=os.clock()
    add_to_chat(158,string.format('[NIN Shadows] %s mode: %d shadows -> %s.',mode,count,spell))
    send_command('input /ma "'..spell..'" <me>')
end

local function schedule_shadow_check(reason,delay)
    if NIN_RUNTIME.unloading then return end
    local token=NIN_RUNTIME.token
    coroutine.schedule(function()
        if NIN_RUNTIME.unloading or token~=NIN_RUNTIME.token then return end
        shadow_auto_check(reason)
    end,delay or 0.4)
end

local function smart_utsusemi_precast(spell,eventArgs)
    if not spell or spell.english~='Utsusemi: Ichi' then return false end
    local count=shadow_count_numeric()
    if count>=3 then
        cancel_spell(); eventArgs.handled=true
        add_to_chat(123,'[NIN Shadows] Utsusemi: Ichi canceled: 3+ shadows already active.')
        return true
    elseif count>0 then
        -- Ichi cannot safely replace every existing Utsusemi source. Keep current shadows during most of the cast,
        -- then cancel near completion; generation invalidates the callback if the cast ends/interruption wins first.
        shadow_runtime.ichi_generation=shadow_runtime.ichi_generation+1
        local gen=shadow_runtime.ichi_generation
        local token=NIN_RUNTIME.token
        coroutine.schedule(function()
            if NIN_RUNTIME.unloading or token~=NIN_RUNTIME.token or gen~=shadow_runtime.ichi_generation then return end
            if type(midaction)=='function' and midaction() then
                send_command('cancel 66; cancel 444; cancel 445')
            end
        end,1.6)
    end
    return false
end

-- Manual elemental selector: one chosen element, highest READY tier San -> Ni -> Ichi.
local ELEMENT_NUKE_SPELLS={
    Fire={'Katon: San','Katon: Ni','Katon: Ichi'}, Water={'Suiton: San','Suiton: Ni','Suiton: Ichi'},
    Lightning={'Raiton: San','Raiton: Ni','Raiton: Ichi'}, Earth={'Doton: San','Doton: Ni','Doton: Ichi'},
    Wind={'Huton: San','Huton: Ni','Huton: Ichi'}, Ice={'Hyoton: San','Hyoton: Ni','Hyoton: Ichi'},
}
local ELEMENT_ALIASES={fire='Fire',water='Water',lightning='Lightning',thunder='Lightning',earth='Earth',wind='Wind',ice='Ice'}
local function cast_selected_element()
    if not state or not state.ElementMode then return end
    if midaction() then add_to_chat(123,'[NIN Element] Already midaction.'); return end
    if buffactive and buffactive.silence then add_to_chat(123,'[NIN Element] Silenced.'); return end
    local mob=current_target_mob()
    if not mob or not mob.id then add_to_chat(123,'[NIN Element] No valid <t> target.'); return end
    local element=state.ElementMode.value
    for _,name in ipairs(ELEMENT_NUKE_SPELLS[element] or {}) do
        if spell_ready(name) then
            add_to_chat(158,'[NIN Element] '..element..': casting highest ready tier -> '..name)
            send_command('input /ma "'..name..'" <t>')
            return
        end
    end
    add_to_chat(123,'[NIN Element] No '..element..' elemental ninjutsu tier is ready.')
end

local function set_element_mode(value)
    local e=ELEMENT_ALIASES[(value or ''):lower()]
    if not e then return false end
    state.ElementMode:set(e); return true
end

-- Readiness report only: scans enabled/accesssible bags on demand; never moves or consumes anything.
local READINESS_ITEMS={
    {name='Shihei',min=20,kind='tool'}, {name='Inoshishinofuda',min=20,kind='tool'},
    {name='Chonofuda',min=20,kind='tool'}, {name='Shikanofuda',min=20,kind='tool'},
    {name='Echo Drops',min=3,kind='recovery'}, {name='Holy Water',min=5,kind='recovery'},
    {name='Remedy',min=3,kind='recovery'}, {name='Panacea',min=3,kind='recovery'},
    {name="Lu Shang's F. Rod",min=1,kind='fishing'}, {name="Fisherman's Tunica",min=1,kind='fishing'},
    {name="Fisherman's Gloves",min=1,kind='fishing'}, {name="Fisherman's Hose",min=1,kind='fishing'},
    {name="Fisherman's Boots",min=1,kind='fishing'}, {name='Per. Lucky Egg',min=1,kind='TH'}, {name='Hoxne Ring',min=1,kind='TH'},
}
local readiness_item_ids=nil
local function init_readiness_ids()
    if readiness_item_ids then return end
    readiness_item_ids={}
    local wanted={}; for _,entry in ipairs(READINESS_ITEMS) do wanted[entry.name]=true end
    for id,item in pairs(nin_res.items or {}) do if item and item.name and wanted[item.name] then readiness_item_ids[item.name]=id end end
end

local function accessible_item_count(item_id)
    if not item_id then return 0 end
    local total=0
    for bag_id,bag in pairs(nin_res.bags or {}) do
        if type(bag_id)=='number' then
            local bag_name=bag and (bag.english or bag.name) or ''
            if bag_name~='Temporary' then
                local info=windower.ffxi.get_bag_info(bag_id)
                if info and info.enabled then
                    local items=windower.ffxi.get_items(bag_id)
                    if items then for _,item in ipairs(items) do if item.id==item_id then total=total+(item.count or 0) end end end
                end
            end
        end
    end
    return total
end

local function report_inventory_readiness()
    init_readiness_ids()
    add_to_chat(158,'=== NIN Inventory Readiness (report-only; no automation) ===')
    local missing=0
    for _,entry in ipairs(READINESS_ITEMS) do
        local n=accessible_item_count(readiness_item_ids[entry.name])
        local ok=n>=entry.min
        if not ok then missing=missing+1 end
        add_to_chat(ok and 158 or 123,string.format('  [%s] %-20s %d / %d %s',entry.kind,entry.name,n,entry.min,ok and 'OK' or 'LOW/MISSING'))
    end
    add_to_chat(missing==0 and 158 or 123,missing==0 and '[NIN Ready] Core tools/recovery/fishing/TH checklist is ready.' or ('[NIN Ready] '..missing..' checklist item(s) low/missing.'))
end

-- Auto Magic Burst detection. One raw action hook opens a short target-specific window
-- from real skillchain add-effects made by any actor. NIN elemental ninjutsu validates
-- target + element at cast time; Alt+M remains a manual force override.
local sc_window={name=nil,target_id=nil,expires=0}
local SC_BURST_SECONDS=10
local SC_MESSAGES={
    [288]='Light',[289]='Darkness',[290]='Gravitation',[291]='Fragmentation',[292]='Distortion',[293]='Fusion',
    [294]='Compression',[295]='Liquefaction',[296]='Induration',[297]='Reverberation',[298]='Transfixion',[299]='Scission',
    [300]='Detonation',[301]='Impaction',[385]='Light',[386]='Darkness',[387]='Gravitation',[388]='Fragmentation',
    [389]='Distortion',[390]='Fusion',[391]='Compression',[392]='Liquefaction',[393]='Induration',[394]='Reverberation',
    [395]='Transfixion',[396]='Scission',[397]='Detonation',[398]='Impaction',[767]='Radiance',[768]='Umbra',[769]='Radiance',[770]='Umbra',
}
local SC_BURST_ELEMENTS={
    Liquefaction={Fire=true},Scission={Earth=true},Reverberation={Water=true},Detonation={Wind=true},Induration={Ice=true},
    Impaction={Lightning=true},Transfixion={Light=true},Compression={Dark=true},Fusion={Fire=true,Light=true},
    Fragmentation={Wind=true,Lightning=true},Gravitation={Earth=true,Dark=true},Distortion={Ice=true,Water=true},
    Light={Fire=true,Wind=true,Lightning=true,Light=true},Darkness={Ice=true,Earth=true,Water=true,Dark=true},
    Radiance={Fire=true,Wind=true,Lightning=true,Light=true},Umbra={Ice=true,Earth=true,Water=true,Dark=true},
}
local SC_BURST_LABEL={
    Liquefaction='Fire',Scission='Earth',Reverberation='Water',Detonation='Wind',Induration='Ice',Impaction='Lightning',
    Transfixion='Light',Compression='Dark',Fusion='Fire/Light',Fragmentation='Wind/Lightning',Gravitation='Earth/Dark',
    Distortion='Ice/Water',Light='Fire/Wind/Lightning/Light',Darkness='Ice/Earth/Water/Dark',
    Radiance='Fire/Wind/Lightning/Light',Umbra='Ice/Earth/Water/Dark',
}

local function clear_burst_window()
    sc_window.name=nil; sc_window.target_id=nil; sc_window.expires=0
end

local function burst_target_exists(target_id)
    if not target_id then return false end
    local fn=windower and windower.ffxi and windower.ffxi.get_mob_by_id
    if type(fn)~='function' then return true end
    local mob=fn(target_id)
    if not mob then return false end
    if mob.hpp~=nil and tonumber(mob.hpp) and tonumber(mob.hpp)<=0 then return false end
    return true
end

local function burst_window_active(spell)
    local now=os.clock()
    if not sc_window.name or sc_window.expires<=now then clear_burst_window(); return false end
    if not burst_target_exists(sc_window.target_id) then clear_burst_window(); return false end
    if not spell or not spell.target or spell.target.id~=sc_window.target_id then return false end
    local elems=SC_BURST_ELEMENTS[sc_window.name]
    return elems and elems[spell.element]==true or false
end

local function handle_nin_action(act)
    if NIN_RUNTIME.unloading or not act or not act.targets then return end
    handle_th_action(act)
    if not state or not state.AutoBurst or not state.AutoBurst.value then return end
    local now=nil
    local seen={}
    for _,target in pairs(act.targets) do
        if target and target.id and target.actions then
            for _,a in pairs(target.actions) do
                local chain=a and a.has_add_effect and SC_MESSAGES[a.add_effect_message]
                if chain then
                    local sig=tostring(target.id)..':'..chain
                    if not seen[sig] then
                        seen[sig]=true
                        now=now or os.clock()
                        sc_window.name=chain
                        sc_window.target_id=target.id
                        sc_window.expires=now+SC_BURST_SECONDS
                        add_to_chat(158,'[NIN AutoBurst] '..chain..' window: '..(SC_BURST_LABEL[chain] or '?')..' (~10s)')
                        if type(update_hud)=='function' then update_hud(true) end
                        local token=NIN_RUNTIME.token
                        local expiry=sc_window.expires
                        coroutine.schedule(function()
                            if NIN_RUNTIME.unloading or token~=NIN_RUNTIME.token then return end
                            if sc_window.expires==expiry and os.clock()>=expiry then
                                clear_burst_window()
                                if type(update_hud)=='function' then update_hud(true) end
                            end
                        end,SC_BURST_SECONDS+0.1)
                    end
                end
            end
        end
    end
end

-- Bounded automatic Silence recovery. At most three Echo Drops attempts per silence instance.
local silence_echo={attempts=0,active=false,generation=0}
local function try_echo_drops(generation)
    if NIN_RUNTIME.unloading or generation~=silence_echo.generation then return end
    if not buffactive or not buffactive.silence then
        if silence_echo.active and silence_echo.attempts>0 then add_to_chat(158,'[NIN] Silence removed.') end
        silence_echo.active=false; silence_echo.attempts=0
        if type(update_hud)=='function' then update_hud(true) end
        return
    end
    if silence_echo.attempts>=3 then
        add_to_chat(123,'[NIN] Echo Drops cap (3) reached; Silence remains.')
        silence_echo.active=false
    shadow_runtime.pending=nil; shadow_runtime.ichi_generation=shadow_runtime.ichi_generation+1
    stance_runtime.pending=false
    reset_th_tracker(false)
        return
    end
    silence_echo.attempts=silence_echo.attempts+1
    send_command('input /item "Echo Drops" <me>')
    add_to_chat(123,'[NIN] Silenced: Echo Drops '..silence_echo.attempts..'/3')
    coroutine.schedule(function() try_echo_drops(generation) end,4)
end

local function set_doom_policy(gain)
    if not sets or not sets.buff or not sets.buff.Doom then return end
    if gain then
        enable('neck','ring1','ring2','waist')
        equip(sets.buff.Doom)
        disable('neck','ring1','ring2','waist')
        add_to_chat(123,'[NIN] DOOMED: recovery gear equipped/locked. Spam Holy Water.')
        send_command('@input /p Doomed.')
    else
        enable('neck','ring1','ring2','waist')
        invalidate_ring_lock_cache()
        reapply_runtime_locks()
        if state and state.PauseSwaps and not state.PauseSwaps.value and type(handle_equipping_gear)=='function' and player then
            handle_equipping_gear(player.status)
        end
    end
end

-- GearInfo is optional for haste/DW, but its movement token is the authoritative low-cost
-- movement signal for automatic Shneddick Ring kiting, matching the RDM Lua architecture.
local function handle_gearinfo_command(cmdParams)
    if not cmdParams or cmdParams[1]~='gearinfo' then return false end
    local new_dw=tonumber(cmdParams[2])
    local dw_inactive=cmdParams[2]=='false'
    local new_haste=tonumber(cmdParams[3])
    local mv=cmdParams[4]
    if (not new_dw and not dw_inactive) or not new_haste or (mv~='true' and mv~='false') then return true end
    gearinfo_last=os.clock()
    local new_moving=(mv=='true')
    if moving~=new_moving then
        moving=new_moving
        if state and state.Auto_Kite then state.Auto_Kite:set(new_moving) end
        if not midaction() and type(handle_equipping_gear)=='function' and player then handle_equipping_gear(player.status) end
        if type(update_hud)=='function' then update_hud(true) end
    end
    return true
end

local function register_nin_events()
    unregister_nin_events()
    if windower and type(windower.raw_register_event)=='function' then
        track_nin_event(windower.raw_register_event('action',handle_nin_action))
    end
    if windower and type(windower.register_event)=='function' then
        track_nin_event(windower.register_event('zone change',function()
            if NIN_RUNTIME.unloading then return end
            clear_burst_window()
            if type(skillchain_reset)=='function' then skillchain_reset(true) end
            if type(elemental_wheel_reset)=='function' then elemental_wheel_reset(true) end
            reset_th_tracker(false)
            shadow_runtime.pending=nil
            local slots={}
            if WARP_GEAR[current_ring_name('ring1')] then slots[#slots+1]='ring1' end
            if WARP_GEAR[current_ring_name('ring2')] then slots[#slots+1]='ring2' end
            if #slots>0 then release_protected_ring_slots(slots,'zone change') end
            if type(update_hud)=='function' then update_hud(true) end
        end))
    end
end

-- @ai:core | Separate NIN implementation; do not couple ownership/state to RDM.
-- @ai:progression | NIN has 1800 total spent JP, is NOT mastered, and has no Master Levels.
-- @ai:dw | Native NIN Dual Wield V = 35%. Patentia Sash is owner-verified Dual Wield +5% (dw=5).
-- @ai:sange | Date Shuriken is protected: automatic Sange policy forces ammo empty.
-- @ai:tools | Tool logistics are bounded/event-driven only; no prerender/postrender polling.
-- @ai:toolpriority | NIN prefers spell-specific tools when available, then universal category tools.
-- @ai:toolrefill | AutoRefill defaults ON + ToolbagMode Always; <=20 triggers refill toward 80 even while engaged.
-- @ai:toolretry | Midaction/menu-blocked toolbag work is persisted and retried after action settle;
--               bounded per-key retries only, no prerender/postrender polling.
--                  Utsusemi is the deliberate exception: use Shikanofuda and protect/park Shihei for /NIN jobs.
-- @ai:fastcast | NIN has no modeled native main-job FC. Owned non-weapon precast FC = 13%;
--              Shuhansadamune adds 5% only when already equipped. Never weapon-swap for FC/lose TP.
-- @ai:itemizer | NIN owns ninja-tool logistics. One persisted handoff disables Itemizer AutoNinjaTools;
--              Itemizer remains loaded for AutoItems/manual item commands.
-- @ai:intelligence | Gear policy metadata is cold-path; exact spell routing remains O(1).
-- @ai:wheel | Win+N starts/stops one bounded six-cast San resistance wheel; auto-advance only after successful aftercast.
-- @ai:skillchains | Win+F5-F8 run guarded 2/4-step Light/Darkness sequences; one WS per press, advance only on successful aftercast.
-- @ai:qol | v1.6 adds Fishing freeze, TH Off/Tag/Fulltime, bounded Shadow modes, WS range safety, desired stance, manual element nuke, /DNC routing, readiness report.
-- @ai:lifecycle | Custom events/delayed callbacks are generation-safe and deterministically cleaned on unload.

function get_sets()
    mote_include_version = 2
    include('Mote-Include.lua')
end

-------------------------------------------------------------------------------------------------------------------
-- Character progression / job model
-------------------------------------------------------------------------------------------------------------------

NIN_PROFILE = {
    job = 'NIN', level = 99, jp_spent = 1800, jp_cap = 2100,
    mastered = false, master_level = 0, native_dual_wield = 35,
    gifts = {
        utsusemi_san=true, superior=4, ninjutsu_skill=23, daken_effect=9,
        ninjutsu_duration=10, weaponskill_damage=5, physical_defense=56,
        physical_attack=70, physical_accuracy=56, physical_evasion=64,
        magic_attack=28, magic_evasion=50, magic_accuracy=32,
    },
    locked_gifts = {
        {jp=1805,effect='Magic Accuracy +18'}, {jp=1900,effect='Ninjutsu Skill +13'},
        {jp=2000,effect='Daken Effect +5%'}, {jp=2100,effect='Master designation / Su5'},
    },
    assumptions = {
        haste_icon='Haste/Haste II share an icon; state.HasteTier selects the assumed potency.',
        march='March potency is approximate; use hasteadj for unknown/invisible external magic haste.',
        merits='No NIN-specific merit allocation is invented.',
    },
}

-------------------------------------------------------------------------------------------------------------------
-- Small profiler: zero timing work while disabled.
-------------------------------------------------------------------------------------------------------------------

local perf = {enabled=false,counters={},timers={}}
local function perf_count(name,amount)
    if not perf.enabled then return end
    perf.counters[name]=(perf.counters[name] or 0)+(amount or 1)
end
local function perf_begin() if perf.enabled then return os.clock() end end
local function perf_finish(name,started)
    if not perf.enabled or not started then return end
    local dt=(os.clock()-started)*1000
    local t=perf.timers[name]
    if not t then t={calls=0,total=0,max=0}; perf.timers[name]=t end
    t.calls=t.calls+1; t.total=t.total+dt; if dt>t.max then t.max=dt end
end
local function perf_reset() perf.counters={}; perf.timers={} end
local function perf_report()
    add_to_chat(158,'[NIN Perf] enabled='..tostring(perf.enabled))
    local names={}
    for k in pairs(perf.counters) do names[#names+1]=k end
    table.sort(names)
    for _,k in ipairs(names) do add_to_chat(158,string.format('  %s=%s',k,tostring(perf.counters[k]))) end
    names={}
    for k in pairs(perf.timers) do names[#names+1]=k end
    table.sort(names)
    for _,k in ipairs(names) do
        local t=perf.timers[k]
        add_to_chat(158,string.format('  %s: %d calls | %.3f ms total | %.3f avg | %.3f max',
            k,t.calls,t.total,t.calls>0 and t.total/t.calls or 0,t.max))
    end
end

-------------------------------------------------------------------------------------------------------------------
-- Exact spell routing + cold-path spell intelligence.
-------------------------------------------------------------------------------------------------------------------

local NINJUTSU_MAP = {}
local NIN_SPELL_POLICY = {}
local function add_ninjutsu_policy(map,source_set,objective,names)
    for _,name in ipairs(names) do
        NINJUTSU_MAP[name]=map
        NIN_SPELL_POLICY[name]={map=map,source_set=source_set,objective=objective}
    end
end
add_ninjutsu_policy('Utsusemi','sets.midcast.Utsusemi','shadow reliability / SIRD / Utsusemi +1',
    {'Utsusemi: Ichi','Utsusemi: Ni','Utsusemi: San'})
add_ninjutsu_policy('ElementalNinjutsu','sets.midcast.ElementalNinjutsu',
    'elemental damage; CastingMode selects landing tier and MagicBurst composes afterward',{
    'Katon: Ichi','Katon: Ni','Katon: San','Hyoton: Ichi','Hyoton: Ni','Hyoton: San',
    'Huton: Ichi','Huton: Ni','Huton: San','Doton: Ichi','Doton: Ni','Doton: San',
    'Raiton: Ichi','Raiton: Ni','Raiton: San','Suiton: Ichi','Suiton: Ni','Suiton: San'})
add_ninjutsu_policy('EnfeeblingNinjutsu','sets.midcast.EnfeeblingNinjutsu',
    'land hostile ninjutsu effects with high Magic Accuracy',{
    'Kurayami: Ichi','Kurayami: Ni','Hojo: Ichi','Hojo: Ni','Jubaku: Ichi',
    'Dokumori: Ichi','Aisha: Ichi','Yurin: Ichi'})
add_ninjutsu_policy('EnhancingNinjutsu','sets.midcast.EnhancingNinjutsu',
    'self-buff reliability/safety; no resistance-potency tradeoff',{
    'Kakka: Ichi','Myoshu: Ichi','Gekka: Ichi','Yain: Ichi','Migawari: Ichi',
    'Monomi: Ichi','Tonko: Ichi','Tonko: Ni'})
NIN_SPELL_POLICY['Migawari: Ichi'].source_set='sets.midcast.Migawari'
NIN_SPELL_POLICY['Migawari: Ichi'].objective='Migawari-specific set with owned Andartia Migawari +5'


-------------------------------------------------------------------------------------------------------------------
-- Elemental Wheel controller
--
-- Ninjutsu's resistance chain is distinct from the ordinary elemental weakness wheel:
--   Hyoton (Ice -> lowers Fire) -> Katon (Fire -> lowers Water)
--   -> Suiton (Water -> lowers Lightning) -> Raiton (Lightning -> lowers Earth)
--   -> Doton (Earth -> lowers Wind) -> Huton (Wind -> lowers Ice).
--
-- Win+N now STARTS one bounded automatic six-cast San pass. The controller advances only
-- after each spell completes successfully. A second Win+N press stops the active pass.
-- Target changes, Pause/Fishing, or Silence stop the pass safely. Recast/tool-retrieval
-- delays are event/timer driven; no frame polling is used.
-------------------------------------------------------------------------------------------------------------------
local ELEMENTAL_WHEEL = {
    {spell='Hyoton: San', element='Ice',       lowers='Fire'},
    {spell='Katon: San',  element='Fire',      lowers='Water'},
    {spell='Suiton: San', element='Water',     lowers='Lightning'},
    {spell='Raiton: San', element='Lightning', lowers='Earth'},
    {spell='Doton: San',  element='Earth',     lowers='Wind'},
    {spell='Huton: San',  element='Wind',      lowers='Ice'},
}
local ELEMENTAL_WHEEL_PRIMER = {
    fire=1, water=2, lightning=3, thunder=3, earth=4, wind=5, ice=6,
}

local elemental_wheel = {
    index=1,
    pending=nil,
    target_id=nil,
    seeded=false,
    active=false,
    generation=0,
    schedule_serial=0,
    cast_count=0,
    waiting=nil,
}

local function elemental_wheel_step()
    return ELEMENTAL_WHEEL[elemental_wheel.index]
end

local function elemental_wheel_invalidate_schedule()
    elemental_wheel.schedule_serial=(elemental_wheel.schedule_serial or 0)+1
end

local function elemental_wheel_stop(reason,silent)
    local was_active=elemental_wheel.active
    elemental_wheel.active=false
    elemental_wheel.pending=nil
    elemental_wheel.waiting=nil
    elemental_wheel.generation=(elemental_wheel.generation or 0)+1
    elemental_wheel_invalidate_schedule()
    if not silent and (was_active or reason) then
        add_to_chat(158,'[NIN AutoWheel] STOPPED'..(reason and (': '..reason) or '.'))
    end
    if type(update_hud)=='function' then update_hud(true) end
end

elemental_wheel_reset = function(silent)
    elemental_wheel_stop(nil,true)
    elemental_wheel.index=1
    elemental_wheel.target_id=nil
    elemental_wheel.seeded=false
    elemental_wheel.cast_count=0
    if not silent then
        add_to_chat(158,'[NIN AutoWheel] Reset: Hyoton: San -> Katon -> Suiton -> Raiton -> Doton -> Huton.')
    end
    if type(update_hud)=='function' then update_hud(true) end
end

local function elemental_wheel_seed(weakness,silent)
    local key=(weakness or ''):lower()
    local idx=ELEMENTAL_WHEEL_PRIMER[key]
    if not idx then return false end

    elemental_wheel_stop(nil,true)
    elemental_wheel.index=idx
    elemental_wheel.cast_count=0
    elemental_wheel.pending=nil

    local target=windower and windower.ffxi and windower.ffxi.get_mob_by_target and windower.ffxi.get_mob_by_target('t')
    elemental_wheel.target_id=target and target.id or nil
    elemental_wheel.seeded=true

    if not silent then
        local step=ELEMENTAL_WHEEL[idx]
        local next_step=ELEMENTAL_WHEEL[idx % #ELEMENTAL_WHEEL + 1]
        add_to_chat(158,string.format(
            '[NIN AutoWheel] Weakness %s seeded: start %s, then %s exploits lowered %s resistance.',
            key:upper(),step.spell,next_step.spell,step.lowers))
    end
    if type(update_hud)=='function' then update_hud(true) end
    return true
end

local function elemental_wheel_schedule(delay)
    if not elemental_wheel.active or NIN_RUNTIME.unloading then return end
    elemental_wheel.schedule_serial=(elemental_wheel.schedule_serial or 0)+1
    local serial=elemental_wheel.schedule_serial
    send_command(string.format(
        'wait %.2f;gs c _wheelauto %s %d %d',
        delay or 0.90,NIN_RUNTIME.token,elemental_wheel.generation,serial))
end

local function elemental_wheel_try_cast()
    if not elemental_wheel.active or NIN_RUNTIME.unloading then return end

    if state and state.PauseSwaps and state.PauseSwaps.value then
        elemental_wheel_stop('GearSwap is paused.',false)
        return
    end
    if state and state.FishingMode and state.FishingMode.value then
        elemental_wheel_stop('Fishing Mode is active.',false)
        return
    end
    if buffactive and buffactive.silence then
        elemental_wheel_stop('Silenced.',false)
        return
    end

    local target=windower and windower.ffxi and windower.ffxi.get_mob_by_target and windower.ffxi.get_mob_by_target('t')
    if not target or not target.id then
        elemental_wheel_stop('No valid <t> target.',false)
        return
    end
    if elemental_wheel.target_id and target.id~=elemental_wheel.target_id then
        elemental_wheel_stop('Target changed; sequence preserved at current step.',false)
        return
    end
    elemental_wheel.target_id=target.id

    if type(midaction)=='function' and midaction() then
        elemental_wheel.waiting='ACTION'
        elemental_wheel_schedule(0.90)
        if type(update_hud)=='function' then update_hud(false) end
        return
    end

    local step=elemental_wheel_step()
    if not step then
        elemental_wheel_stop('Invalid wheel state.',false)
        return
    end

    local recast=spell_recast_remaining(step.spell)
    if recast>0 then
        elemental_wheel.waiting='RECAST '..tostring(math.ceil(recast))..'s'
        -- One scheduled wake near recast completion; clamp to avoid pathological API values.
        elemental_wheel_schedule(math.max(1.0,math.min(recast+0.25,60.0)))
        if type(update_hud)=='function' then update_hud(false) end
        return
    end

    elemental_wheel.waiting=nil
    elemental_wheel.pending=step.spell
    local next_step=ELEMENTAL_WHEEL[elemental_wheel.index % #ELEMENTAL_WHEEL + 1]
    add_to_chat(158,string.format(
        '[NIN AutoWheel] %d/6: %s (%s) -> lowers %s; next %s.',
        elemental_wheel.cast_count+1,step.spell,step.element,step.lowers,next_step.spell))
    send_command('input /ma "'..step.spell..'" <t>')
    if type(update_hud)=='function' then update_hud(false) end
end

local function elemental_wheel_start()
    if elemental_wheel.active then
        elemental_wheel_stop('Canceled by Win+N.',false)
        return
    end

    local target=windower and windower.ffxi and windower.ffxi.get_mob_by_target and windower.ffxi.get_mob_by_target('t')
    if not target or not target.id then
        add_to_chat(123,'[NIN AutoWheel] No valid <t> target.')
        return
    end

    if not elemental_wheel.seeded and elemental_wheel.target_id and elemental_wheel.target_id~=target.id then
        elemental_wheel.index=1
    end

    elemental_wheel.active=true
    elemental_wheel.generation=(elemental_wheel.generation or 0)+1
    elemental_wheel.cast_count=0
    elemental_wheel.pending=nil
    elemental_wheel.waiting=nil
    elemental_wheel.target_id=target.id

    local step=elemental_wheel_step()
    add_to_chat(158,string.format(
        '[NIN AutoWheel] STARTED on target %s. Six-cast San pass begins with %s. Win+N again = STOP.',
        tostring(target.name or target.id),step and step.spell or '?'))

    elemental_wheel_schedule(0.05)
    if type(update_hud)=='function' then update_hud(true) end
end

local function elemental_wheel_aftercast(spell)
    if not elemental_wheel.active or not elemental_wheel.pending or not spell or
       spell.english~=elemental_wheel.pending then return end

    if spell.interrupted then
        local retry_spell=elemental_wheel.pending
        elemental_wheel.pending=nil
        elemental_wheel.waiting='RETRY'
        add_to_chat(123,'[NIN AutoWheel] '..retry_spell..' interrupted/canceled; same step queued for retry.')
        -- Tool-priority retrieval retries normally fire before this. schedule_serial prevents a
        -- stale retry from double-casting if that tool retry succeeds first.
        elemental_wheel_schedule(1.80)
        if type(update_hud)=='function' then update_hud(false) end
        return
    end

    elemental_wheel.pending=nil
    elemental_wheel.cast_count=elemental_wheel.cast_count+1
    elemental_wheel.index=elemental_wheel.index % #ELEMENTAL_WHEEL + 1
    elemental_wheel.seeded=false
    elemental_wheel_invalidate_schedule()

    if elemental_wheel.cast_count>=#ELEMENTAL_WHEEL then
        local next_step=elemental_wheel_step()
        elemental_wheel.active=false
        elemental_wheel.waiting=nil
        add_to_chat(158,string.format(
            '[NIN AutoWheel] COMPLETE: six successful San casts. Next pass will begin with %s.',
            next_step and next_step.spell or 'Hyoton: San'))
        if type(update_hud)=='function' then update_hud(true) end
        return
    end

    elemental_wheel_schedule(0.90)
    if type(update_hud)=='function' then update_hud(false) end
end

local function report_elemental_wheel()
    local step=elemental_wheel_step()
    add_to_chat(158,'[NIN AutoWheel] San chain: Hyoton -> Katon -> Suiton -> Raiton -> Doton -> Huton.')
    add_to_chat(158,string.format(
        '[NIN AutoWheel] mode=%s | progress=%d/6 | next=%s | lowers=%s | wait=%s',
        elemental_wheel.active and 'RUNNING' or 'READY',
        elemental_wheel.cast_count or 0,
        step and step.spell or '?',
        step and step.lowers or '?',
        tostring(elemental_wheel.waiting or '-')))
    add_to_chat(158,'[NIN AutoWheel] Win+N = START/STOP one six-cast pass | gs c wheelstart <element> = seed known weakness.')
end

-------------------------------------------------------------------------------------------------------------------
-- Self-skillchain controller
--
-- Research-backed NIN sequences used here:
--   2-step Light:    Blade: Kamu -> Blade: Shun
--   2-step Darkness: Blade: Hi -> Blade: Hi
--   4-step Light:    Blade: Shun -> Blade: Hi -> Blade: Kamu -> Blade: Shun
--   4-step Darkness: Blade: Ku -> Blade: Retsu -> Blade: Hi -> Blade: Hi
--
-- One key press executes ONE weapon skill. GearSwap's normal WeaponSkill routing equips the dedicated set for
-- that exact WS. The controller advances only after a successful aftercast, rejects non-katana weapon profiles,
-- refuses to fire without 1000 TP, resets on target changes, and guards the skillchain timing windows.
--
-- Timing methodology: BG Wiki documents a 3-10 second valid window, shortening by about two seconds per
-- additional skillchain step. os.time() has whole-second resolution, so safe integer windows are used:
--   step 2: 4..9 seconds, step 3: 4..7 seconds, step 4: 4..5 seconds after the previous successful WS.
-- These bounds deliberately avoid both the too-early and too-late edges.
-------------------------------------------------------------------------------------------------------------------
local NIN_SKILLCHAINS = {
    ['2light'] = {
        label='2-Step Light',
        steps={
            {ws='Blade: Kamu', note='Opener: Fragmentation'},
            {ws='Blade: Shun', note='Closes Light'},
        },
        prerequisite='Blade: Kamu must be unlocked via Unlocking a Myth (Ninja).',
    },
    ['2dark'] = {
        label='2-Step Darkness',
        steps={
            {ws='Blade: Hi', note='Opener: Darkness'},
            {ws='Blade: Hi', note='Closes Darkness'},
        },
    },
    ['4light'] = {
        label='4-Step Light',
        steps={
            {ws='Blade: Shun', note='Opener: Fusion'},
            {ws='Blade: Hi', note='Creates Gravitation'},
            {ws='Blade: Kamu', note='Creates Fragmentation'},
            {ws='Blade: Shun', note='Closes Light'},
        },
        prerequisite='Blade: Kamu must be unlocked via Unlocking a Myth (Ninja).',
    },
    ['4dark'] = {
        label='4-Step Darkness',
        steps={
            {ws='Blade: Ku', note='Opener: Gravitation / Transfixion'},
            {ws='Blade: Retsu', note='Creates Distortion'},
            {ws='Blade: Hi', note='Creates Darkness'},
            {ws='Blade: Hi', note='Closes Double Darkness'},
        },
    },
}

local SKILLCHAIN_SAFE_MIN_ELAPSED = 4
local SKILLCHAIN_SAFE_MAX_BY_STEP = {[2]=9,[3]=7,[4]=5}
local skillchain_ctl = {active=nil,index=1,pending=nil,target_id=nil,last_success=nil}

skillchain_reset = function(silent,reason)
    skillchain_ctl.active=nil
    skillchain_ctl.index=1
    skillchain_ctl.pending=nil
    skillchain_ctl.target_id=nil
    skillchain_ctl.last_success=nil
    if not silent then
        add_to_chat(158,'[NIN SC] Reset'..(reason and (': '..reason) or '.'))
    end
end

local function skillchain_target()
    if not windower or not windower.ffxi or not windower.ffxi.get_mob_by_target then return nil end
    return windower.ffxi.get_mob_by_target('t')
end

local function skillchain_katana_profile_ok()
    if not state or not state.WeaponSet then return true end
    local p=state.WeaponSet.value
    return p~='Naegling/Blurred' and p~='Tauret/Blurred'
end

local function skillchain_start_or_continue(id)
    local chain=NIN_SKILLCHAINS[id]
    if not chain then
        add_to_chat(123,'[NIN SC] Unknown chain. Use 2light, 2dark, 4light, or 4dark.')
        return
    end
    if type(midaction)=='function' and midaction() then
        add_to_chat(123,'[NIN SC] Already midaction; no WS sent and sequence did not advance.')
        return
    end
    if not skillchain_katana_profile_ok() then
        add_to_chat(123,'[NIN SC] Katana profile required. Refusing to weapon-swap because changing main hand would erase TP.')
        return
    end

    local target=skillchain_target()
    if not target or not target.id then
        add_to_chat(123,'[NIN SC] No valid <t> target; sequence did not advance.')
        return
    end

    if skillchain_ctl.active~=id then
        skillchain_ctl.active=id
        skillchain_ctl.index=1
        skillchain_ctl.pending=nil
        skillchain_ctl.target_id=target.id
        skillchain_ctl.last_success=nil
        add_to_chat(158,'[NIN SC] Selected '..chain.label..': '..table.concat((function()
            local t={}; for _,s in ipairs(chain.steps) do t[#t+1]=s.ws end; return t
        end)(),' -> '))
    elseif skillchain_ctl.target_id and skillchain_ctl.target_id~=target.id then
        skillchain_ctl.index=1
        skillchain_ctl.pending=nil
        skillchain_ctl.target_id=target.id
        skillchain_ctl.last_success=nil
        add_to_chat(158,'[NIN SC] New target detected; '..chain.label..' restarted at step 1.')
    else
        skillchain_ctl.target_id=target.id
    end

    -- A stale continuation cannot make the intended chain. Restart immediately, then use this same press as opener.
    if skillchain_ctl.index>1 and skillchain_ctl.last_success then
        local elapsed=os.time()-skillchain_ctl.last_success
        local max_elapsed=SKILLCHAIN_SAFE_MAX_BY_STEP[skillchain_ctl.index] or 5
        if elapsed<SKILLCHAIN_SAFE_MIN_ELAPSED then
            add_to_chat(123,string.format('[NIN SC] Too early for step %d. Wait until at least ~3 seconds after the prior WS; sequence held.',skillchain_ctl.index))
            return
        elseif elapsed>max_elapsed then
            add_to_chat(123,string.format('[NIN SC] Window expired before step %d (%ds elapsed). Restarting %s.',skillchain_ctl.index,elapsed,chain.label))
            skillchain_ctl.index=1
            skillchain_ctl.pending=nil
            skillchain_ctl.last_success=nil
        end
    end

    if (player.tp or 0)<1000 then
        local step=chain.steps[skillchain_ctl.index]
        add_to_chat(123,string.format('[NIN SC] Need 1000 TP for step %d/%d: %s. Sequence held.',skillchain_ctl.index,#chain.steps,step.ws))
        return
    end

    local step=chain.steps[skillchain_ctl.index]
    if not step then
        skillchain_ctl.index=1
        step=chain.steps[1]
    end
    skillchain_ctl.pending={id=id,index=skillchain_ctl.index,ws=step.ws,target_id=target.id}
    add_to_chat(158,string.format('[NIN SC] %s step %d/%d: %s | %s',chain.label,skillchain_ctl.index,#chain.steps,step.ws,step.note))
    send_command('input /ws "'..step.ws..'" <t>')
end

local function skillchain_aftercast(spell)
    if not spell or spell.type~='WeaponSkill' then return end
    local pending=skillchain_ctl.pending
    if not pending then
        if skillchain_ctl.active and skillchain_ctl.index>1 then
            skillchain_reset(false,'manual/non-controller WS interrupted the planned sequence')
        end
        return
    end
    if spell.english~=pending.ws then
        skillchain_reset(false,'unexpected WS '..tostring(spell.english)..' replaced expected '..pending.ws)
        return
    end
    if spell.interrupted then
        add_to_chat(123,'[NIN SC] '..pending.ws..' failed/interrupted; retry the same step when ready.')
        skillchain_ctl.pending=nil
        return
    end

    local chain=NIN_SKILLCHAINS[pending.id]
    if not chain then skillchain_reset(true); return end
    skillchain_ctl.pending=nil
    skillchain_ctl.last_success=os.time()
    if pending.index>=#chain.steps then
        add_to_chat(158,'[NIN SC] '..chain.label..' complete. Sequence reset for the next chain.')
        skillchain_ctl.index=1
        skillchain_ctl.last_success=nil
    else
        skillchain_ctl.index=pending.index+1
        local next_step=chain.steps[skillchain_ctl.index]
        add_to_chat(158,string.format('[NIN SC] Next step %d/%d: %s. Build 1000 TP and press the SAME bind inside the chain window.',skillchain_ctl.index,#chain.steps,next_step.ws))
    end
end

local function report_skillchains()
    add_to_chat(158,'=== NIN Self-Skillchains ===')
    add_to_chat(158,'Win+F5  2-Step Light:    Kamu -> Shun')
    add_to_chat(158,'Win+F6  2-Step Darkness: Hi -> Hi')
    add_to_chat(158,'Win+F7  4-Step Light:    Shun -> Hi -> Kamu -> Shun')
    add_to_chat(158,'Win+F8  4-Step Darkness: Ku -> Retsu -> Hi -> Hi')
    add_to_chat(158,'Method: one press = one WS; successful aftercast advances; same target + katana profile required.')
    add_to_chat(158,'Timing guard: safe ~3-10s opening window, shrinking on later steps. TP/target/failure checks never auto-advance.')
    add_to_chat(158,'Kamu prerequisite: Unlocking a Myth (Ninja). External party/trust WS can still alter or break the resonance.')
    if skillchain_ctl.active then
        local c=NIN_SKILLCHAINS[skillchain_ctl.active]
        local s=c and c.steps[skillchain_ctl.index]
        if c and s then add_to_chat(158,string.format('[NIN SC] Active: %s | next %d/%d %s',c.label,skillchain_ctl.index,#c.steps,s.ws)) end
    end
end

-------------------------------------------------------------------------------------------------------------------
-- Fast Cast / spell-recast model.
--
-- Known owned, NIN-usable non-weapon FC:
--   Taeon Tabard 4 + Loquac. Earring 2 + Enchntr. Earring +1 2
--   + Kishar Ring 4 + Naji's Loop 1 = 13%.
-- Impatiens is Quick Magic +2%, tracked separately and NOT counted as Fast Cast.
-- Shuhansadamune is FC+5%, but this Lua never swaps weapons merely for Fast Cast because doing so can erase TP.
-------------------------------------------------------------------------------------------------------------------
local NIN_FAST_CAST = {
    cap = 80,
    owned_nonweapon = 13,
    quick_magic = 2,
    shuhansadamune = 5,
}

local function current_fc_gear()
    local total = NIN_FAST_CAST.owned_nonweapon
    local eq = player and player.equipment or {}
    if eq.main == 'Shuhansadamune' or eq.sub == 'Shuhansadamune' then
        total = total + NIN_FAST_CAST.shuhansadamune
    end
    return total
end

local function report_fc()
    local current = current_fc_gear()
    add_to_chat(158,string.format(
        '[NIN FC] Gear Fast Cast=%d/%d | Quick Magic=%d%% | non-weapon FC=13%% | Shuhansadamune +5%% only when already equipped.',
        current,NIN_FAST_CAST.cap,NIN_FAST_CAST.quick_magic))
    add_to_chat(158,'[NIN FC] Contributors: Taeon body 4 + Loquacious 2 + Enchanter +1 2 + Kishar 4 + Naji Loop 1.')
    add_to_chat(158,'[NIN FC] Weapons are never swapped just to gain FC; preserving TP/WeaponLock takes priority.')
end

-------------------------------------------------------------------------------------------------------------------
-- Haste / Dual Wield engine.
-- IMPORTANT: all cache state and helpers are declared BEFORE init_gear_sets().
-- This eliminates the v1.1 lexical-scope nil crash during initialization.
-------------------------------------------------------------------------------------------------------------------

local equipment_snapshot_slots={
    'main','sub','range','ammo','head','neck','ear1','ear2','body','hands','ring1','ring2','back','waist','legs','feet'
}
local equipment_snapshot={initialized=false,names={},gear_haste=0}
local haste_buff_cache={dirty=true,magic=0}
local haste_manual_magic=0
local native_state_haste=-1
local native_state_gear_need=-1
local dw_overlay_need_cache=-1
local dw_overlay={}
local dw_plan={}

local dw_candidates={
    {slot='ear1',name='Eabani Earring',dw=4,cost=2},
    {slot='ear2',name='Suppanomimi',dw=5,cost=3},
    {slot='waist',name='Patentia Sash',dw=5,cost=4}, -- owner-verified Dual Wield +5%
    {slot='feet',name='Hiza. Sune-Ate +2',dw=8,cost=5},
    {slot='legs',name='Naga Hakama',dw=4,cost=8},
}

local function invalidate_haste_cache() haste_buff_cache.dirty=true end

local function refresh_haste_cache()
    if not haste_buff_cache.dirty then perf_count('haste_cache_hits'); return haste_buff_cache.magic end
    local magic=0
    if buffactive then
        if buffactive['Haste'] then magic=magic+((state and state.HasteTier and state.HasteTier.value==1) and 150 or 307) end
        local march=tonumber(buffactive['March']) or (buffactive['March'] and 1 or 0)
        magic=magic+march*170
        if buffactive['Embrava'] then magic=magic+266 end
        if buffactive['Mighty Guard'] then magic=magic+150 end
    end
    haste_buff_cache.magic=math.min(magic,448)
    haste_buff_cache.dirty=false
    perf_count('haste_cache_rebuilds')
    return haste_buff_cache.magic
end

local function get_equipment_snapshot()
    local eq=player and player.equipment
    if not eq then return equipment_snapshot end
    local names=equipment_snapshot.names
    local changed=not equipment_snapshot.initialized
    if not changed then
        for i,slot in ipairs(equipment_snapshot_slots) do
            if names[i]~=(eq[slot] or '') then changed=true; break end
        end
    end
    if not changed then perf_count('equipment_snapshot_hits'); return equipment_snapshot end
    local haste=0
    for i,slot in ipairs(equipment_snapshot_slots) do
        local n=eq[slot] or ''
        names[i]=n
        local st=item_stats and item_stats[n]
        if st then haste=haste+(st.haste or 0) end
    end
    equipment_snapshot.gear_haste=math.min(haste,256)
    equipment_snapshot.initialized=true
    perf_count('equipment_snapshot_rebuilds')
    return equipment_snapshot
end

local function dw_needed_at_haste(h)
    if h>=819 then return 0 end
    return math.ceil((1-0.2/((1024-h)/1024))*100)
end

local function build_dw_plan()
    for need=0,50 do
        local best=nil
        local maxmask=2^#dw_candidates
        for mask=0,maxmask-1 do
            local have,cost,set=0,0,{}
            for i,c in ipairs(dw_candidates) do
                local bit=2^(i-1)
                if math.floor(mask/bit)%2==1 then
                    have=have+c.dw; cost=cost+c.cost; set[c.slot]=c.name
                end
            end
            local short=math.max(0,need-have)
            local excess=math.max(0,have-need)
            local score=short*10000+excess*50+cost
            if not best or score<best.score then best={score=score,have=have,set=set,short=short} end
        end
        dw_plan[need]=best or {have=0,set={},short=need}
    end
end
build_dw_plan()

function update_dw_overlay()
    local need=math.max(0,native_state_gear_need or 0)
    if need==dw_overlay_need_cache then perf_count('dw_cache_hits'); return dw_overlay end
    local plan=dw_plan[math.min(50,need)] or {set={},have=0,short=need}
    dw_overlay={}
    for slot,item in pairs(plan.set) do dw_overlay[slot]=item end
    dw_overlay_need_cache=need
    perf_count('dw_rebuilds')
    return dw_overlay
end

local function native_dual_wield_active()
    -- Current weapon profiles are all dual-wield profiles; engaged state is the stable
    -- authority used by v1.1, avoiding transient empty-sub equipment snapshots.
    return player and player.status=='Engaged' or false
end

function update_native_haste_dw(force)
    local t=perf_begin()
    local active=native_dual_wield_active()
    local magic=math.min(448,refresh_haste_cache()+haste_manual_magic)
    -- Every reviewed engaged family is built around the 25% equipment-haste bucket.
    -- Use 256 while engaged to avoid transient idle->engaged equipment snapshots.
    local gear_haste=active and 256 or get_equipment_snapshot().gear_haste
    local total=math.min(819,gear_haste+magic)
    local total_dw=active and dw_needed_at_haste(total) or 0
    local gear_need=active and math.max(0,total_dw-NIN_PROFILE.native_dual_wield) or 0
    if not force and total==native_state_haste and gear_need==native_state_gear_need then
        perf_finish('native_dw',t); return false
    end
    native_state_haste=total
    native_state_gear_need=gear_need
    perf_count('native_dw_changes')
    update_dw_overlay()
    perf_finish('native_dw',t)
    return true
end

local function dw_have()
    local plan=dw_plan[math.min(50,math.max(0,native_state_gear_need or 0))]
    return plan and plan.have or 0
end
local function dw_shortfall() return math.max(0,(native_state_gear_need or 0)-dw_have()) end

-------------------------------------------------------------------------------------------------------------------
-- Proactive ninja-tool logistics. Bounded, accessible-bag scans only.
-------------------------------------------------------------------------------------------------------------------

local TOOL_CATEGORY_ORDER={'utsusemi','elemental','enfeebling','enhancing'}
local TOOL_CATEGORY_BY_MAP={Utsusemi='utsusemi',ElementalNinjutsu='elemental',EnfeeblingNinjutsu='enfeebling',EnhancingNinjutsu='enhancing'}
local NIN_TOOL_POLICY={
    -- Utsusemi intentionally uses the universal buff tool on NIN. Shihei is protected for /NIN jobs.
    -- The Enhancing category owns the actual Shikanofuda reserve/refill; Utsusemi mirrors that count.
    utsusemi={label='Utsusemi Universal',tool='Shikanofuda',toolbag='Toolbag (Shika)',low=20,target=80,protected='Shihei',refill_owner='enhancing'},
    elemental={label='Elemental Universal',tool='Inoshishinofuda',toolbag='Toolbag (Ino)',low=20,target=80},
    enfeebling={label='Enfeebling Universal',tool='Chonofuda',toolbag='Toolbag (Cho)',low=20,target=80},
    enhancing={label='Enhancing Universal',tool='Shikanofuda',toolbag='Toolbag (Shika)',low=20,target=80},
}

-- Spell-specific tools. When one is already in Inventory, FFXI naturally consumes it before the
-- category universal tool. If it exists in an enabled accessible bag, this Lua retrieves it on demand
-- and retries the cast once the move completes. If no specific tool/reserve exists, casting proceeds
-- with the universal category tool. Utsusemi is excluded on purpose.
local NIN_SPECIFIC_TOOL_POLICY={
    Katon={tool='Uchitake',toolbag='Toolbag (Uchi)'},
    Suiton={tool='Mizu-Deppo',toolbag='Toolbag (Mizu)'},
    Raiton={tool='Hiraishin',toolbag='Toolbag (Hira)'},
    Doton={tool='Makibishi',toolbag='Toolbag (Maki)'},
    Huton={tool='Kawahori-Ogi',toolbag='Toolbag (Kawa)'},
    Hyoton={tool='Tsurara',toolbag='Toolbag (Tsura)'},
    Kurayami={tool='Sairui-Ran',toolbag='Toolbag (Sai)'},
    Hojo={tool='Kaginawa',toolbag='Toolbag (Kagi)'},
    Dokumori={tool='Kodoku',toolbag='Toolbag (Kodo)'},
    Jubaku={tool='Jusatsu',toolbag='Toolbag (Jusa)'},
    Aisha={tool='Soshi',toolbag='Toolbag (Soshi)'},
    Yurin={tool='Jinko',toolbag='Toolbag (Jinko)'},
    Tonko={tool='Shinobi-Tabi',toolbag='Toolbag (Shino)'},
    Monomi={tool='Sanjaku-Tenugui',toolbag='Toolbag (Sanja)'},
    Myoshu={tool='Kabenro',toolbag='Toolbag (Kaben)'},
    Migawari={tool='Mokujin',toolbag='Toolbag (Moku)'},
    Gekka={tool='Ranka',toolbag='Toolbag (Ranka)'},
    Yain={tool='Furusumi',toolbag='Toolbag (Furu)'},
    Kakka={tool='Ryuno',toolbag='Toolbag (Ryuno)'},
}
local tool_manager={enabled=true,toolbag_mode='Always',inventory_bag=0,pending={},deferred_open={},deferred_attempts={},retry_serial={},warned={},open_attempts={},initialized=false,hud_counts={}}

local function tool_warn_once(key,reason,msg)
    local token=key..':'..reason
    if tool_manager.warned[token] then return end
    tool_manager.warned[token]=true; add_to_chat(123,msg)
end
local function tool_clear_warnings(key)
    local prefix=key..':'
    for token in pairs(tool_manager.warned) do if token:sub(1,#prefix)==prefix then tool_manager.warned[token]=nil end end
end
local function init_tool_policy()
    if tool_manager.initialized then return end
    local wanted={}
    for _,key in ipairs(TOOL_CATEGORY_ORDER) do
        local p=NIN_TOOL_POLICY[key]
        wanted[p.tool]=true; wanted[p.toolbag]=true
        if p.protected then wanted[p.protected]=true end
    end
    for _,p in pairs(NIN_SPECIFIC_TOOL_POLICY) do
        wanted[p.tool]=true; wanted[p.toolbag]=true
    end
    local ids={}
    for id,item in pairs(nin_res.items) do if item and item.name and wanted[item.name] then ids[item.name]=id end end
    for _,key in ipairs(TOOL_CATEGORY_ORDER) do
        local p=NIN_TOOL_POLICY[key]
        p.tool_id=ids[p.tool]; p.toolbag_id=ids[p.toolbag]; p.protected_id=p.protected and ids[p.protected] or nil
    end
    for _,p in pairs(NIN_SPECIFIC_TOOL_POLICY) do
        p.tool_id=ids[p.tool]; p.toolbag_id=ids[p.toolbag]
    end
    for id,bag in pairs(nin_res.bags) do
        local name=bag and (bag.english or bag.name)
        if type(id)=='number' and name=='Inventory' then tool_manager.inventory_bag=id; break end
    end
    tool_manager.initialized=true
end
local function tool_inventory_count(item_id)
    if not item_id then return 0 end
    local items=windower.ffxi.get_items(tool_manager.inventory_bag)
    if not items then return 0 end
    local total=0
    for _,item in ipairs(items) do if item.id==item_id then total=total+(item.count or 0) end end
    return total
end
local function tool_inventory_free_slots()
    local info=windower.ffxi.get_bag_info(tool_manager.inventory_bag)
    return info and math.max(0,(info.max or 0)-(info.count or 0)) or 0
end
local function tool_find_accessible(item_id)
    if not item_id then return nil,0 end
    local first,total=nil,0
    for bag_id,bag in pairs(nin_res.bags) do
        if type(bag_id)=='number' and bag_id~=tool_manager.inventory_bag then
            local bag_name=bag and (bag.english or bag.name) or ''
            if bag_name~='Temporary' then
                local info=windower.ffxi.get_bag_info(bag_id)
                if info and info.enabled then
                    local items=windower.ffxi.get_items(bag_id)
                    if items then
                        for _,item in ipairs(items) do
                            if item.id==item_id and (item.count or 0)>0 then
                                total=total+item.count
                                if not first then first={bag=bag_id,slot=item.slot,count=item.count} end
                            end
                        end
                    end
                end
            end
        end
    end
    return first,total
end
local function tool_mark_pending(key,kind,seconds) tool_manager.pending[key]={kind=kind,until_time=os.clock()+(seconds or 1.5)} end
local function tool_is_pending(key)
    local p=tool_manager.pending[key]
    if not p then return false end
    if os.clock()>=(p.until_time or 0) then tool_manager.pending[key]=nil; return false end
    return true
end
local function queue_tool_step(key,delay)
    if NIN_RUNTIME.unloading then return end
    send_command(string.format('wait %.2f;gs c _toolstep %s %s',delay or 1.0,key,NIN_RUNTIME.token))
end

local TOOL_DEFERRED_RETRY_MAX=12

local function invalidate_tool_deferred_retry(key)
    tool_manager.retry_serial[key]=(tool_manager.retry_serial[key] or 0)+1
end

local function clear_tool_deferred(key)
    tool_manager.deferred_open[key]=nil
    tool_manager.deferred_attempts[key]=0
    invalidate_tool_deferred_retry(key)
end

local function queue_tool_deferred_retry(key,delay)
    if NIN_RUNTIME.unloading or not tool_manager.enabled or tool_manager.toolbag_mode=='Off' then return false end
    local attempts=(tool_manager.deferred_attempts[key] or 0)+1
    tool_manager.deferred_attempts[key]=attempts
    if attempts>TOOL_DEFERRED_RETRY_MAX then
        tool_warn_once(key,'deferred_exhausted',
            '[NIN Tools] Deferred retry limit reached for '..tostring(key)..'. Next aftercast/toolcheck will wake it again.')
        return false
    end
    local serial=(tool_manager.retry_serial[key] or 0)+1
    tool_manager.retry_serial[key]=serial
    send_command(string.format('wait %.2f;gs c _tooldeferred %s %s %d',
        delay or 0.85,key,NIN_RUNTIME.token,serial))
    return true
end

local function defer_toolbag_open(key,reason,delay)
    tool_manager.deferred_open[key]=reason or true
    return queue_tool_deferred_retry(key,delay or 0.85)
end
local function tool_can_auto_open()
    if tool_manager.toolbag_mode=='Off' then return false,'disabled' end
    if midaction() then return false,'midaction' end
    local info=windower.ffxi.get_info()
    if info and info.menu_open then return false,'menu' end
    if tool_manager.toolbag_mode=='Safe' and player and player.status=='Engaged' then return false,'engaged' end
    return true,nil
end
local function open_toolbag_from_inventory(key,manual)
    local p=NIN_TOOL_POLICY[key]
    if not p or tool_inventory_count(p.toolbag_id)<=0 then return false end

    -- A /item dispatch can lose a race if another action begins just after our state check.
    -- Verify up to three attempts, but every attempt is still gated by midaction/menu policy.
    if not manual and (tool_manager.open_attempts[key] or 0)>=3 then
        tool_warn_once(key,'open_failed',
            '[NIN Tools] Auto-opening '..p.toolbag..' did not replenish '..p.tool..
            ' after 3 attempts. Use gs c toolopen '..key..' or gs c toolcheck.')
        return false
    end

    local ok,why=tool_can_auto_open()
    if not ok then
        if why=='midaction' then
            defer_toolbag_open(key,why,0.85)
        elseif why=='menu' then
            defer_toolbag_open(key,why,1.10)
        elseif why=='engaged' then
            -- Optional Safe mode only. Status changes will wake this without a combat retry loop.
            tool_manager.deferred_open[key]=why
        end
        tool_warn_once(key,why,
            '[NIN Tools] '..p.label..' reserve low; '..p.toolbag..
            ' opening deferred ('..tostring(why)..').')
        return false
    end

    tool_manager.open_attempts[key]=(tool_manager.open_attempts[key] or 0)+1
    clear_tool_deferred(key)
    windower.chat.input('/item "'..p.toolbag..'" <me>')
    tool_mark_pending(key,'open',4.0)
    queue_tool_step(key,4.0)
    add_to_chat(158,'[NIN Tools] Opening '..p.toolbag..' to replenish '..p.tool..'.')
    return true
end
local tool_check_category

tool_check_category = function(key,verbose)
    init_tool_policy()
    local p=NIN_TOOL_POLICY[key]
    if not p then return false end
    if not tool_manager.enabled then if verbose then add_to_chat(158,'[NIN Tools] Proactive refill is OFF.') end; return false end
    if tool_is_pending(key) then return false end
    -- Utsusemi shares Shikanofuda with Enhancing. Mirror the count here, then delegate
    -- threshold/refill ownership so Utsusemi consumption can actually trigger Toolbag (Shika).
    if key=='utsusemi' then
        local inv_count=tool_inventory_count(p.tool_id)
        tool_manager.hud_counts.utsusemi=inv_count
        tool_manager.hud_counts.shihei=p.protected_id and tool_inventory_count(p.protected_id) or 0
        if verbose then
            add_to_chat(158,string.format('[NIN Tools] Utsusemi: Shikanofuda=%d | Shihei in Inventory=%d (target=0/protected).',
                inv_count,tool_manager.hud_counts.shihei or 0))
        end
        local owner=p.refill_owner
        if owner and owner~=key then
            return tool_check_category(owner,verbose)
        end
        return false
    end
    if not p.tool_id or not p.toolbag_id then tool_warn_once(key,'resource','[NIN Tools] Resource lookup failed for '..p.label..'.'); return false end
    local inv_count=tool_inventory_count(p.tool_id)
    tool_manager.hud_counts[key]=inv_count
    if inv_count>p.low then
        tool_clear_warnings(key); clear_tool_deferred(key); tool_manager.open_attempts[key]=0
        if verbose then add_to_chat(158,string.format('[NIN Tools] %s: %s=%d healthy.',p.label,p.tool,inv_count)) end
        return false
    end
    local loose=tool_find_accessible(p.tool_id)
    if loose then
        if inv_count==0 and tool_inventory_free_slots()<=0 then tool_warn_once(key,'full','[NIN Tools] Inventory full; cannot retrieve '..p.tool..'.'); return false end
        local move_count=math.max(1,math.min(loose.count,p.target-inv_count))
        windower.ffxi.get_item(loose.bag,loose.slot,move_count); tool_mark_pending(key,'loose',1.2); queue_tool_step(key,1.2)
        add_to_chat(158,string.format('[NIN Tools] %s low (%d). Retrieving %d %s.',p.label,inv_count,move_count,p.tool)); return true
    end
    if tool_inventory_count(p.toolbag_id)>0 then return open_toolbag_from_inventory(key,false) end
    local bag_match=tool_find_accessible(p.toolbag_id)
    if bag_match then
        if tool_inventory_free_slots()<=0 then tool_warn_once(key,'fullbag','[NIN Tools] Inventory full; cannot retrieve '..p.toolbag..'.'); return false end
        windower.ffxi.get_item(bag_match.bag,bag_match.slot,1); tool_manager.deferred_open[key]='toolbag_fetch'; tool_mark_pending(key,'toolbag_fetch',1.4); queue_tool_step(key,1.4)
        add_to_chat(158,'[NIN Tools] Retrieving '..p.toolbag..'.'); return true
    end
    local extra=''
    if p.fallback_id then local n=tool_inventory_count(p.fallback_id); if n>0 then extra=' Fallback '..p.fallback..'='..n..'.' end end
    tool_warn_once(key,'empty','[NIN Tools] LOW: '..p.tool..'='..inv_count..'; no accessible reserve/toolbag.'..extra)
    return false
end

-- Tool-priority runtime state. No frame polling; only cast events and bounded delayed retries.
local tool_cast_retry={generation=0,pending=nil}

local function tool_inventory_first(item_id)
    if not item_id then return nil end
    local items=windower.ffxi.get_items(tool_manager.inventory_bag)
    if not items then return nil end
    for slot,item in ipairs(items) do
        if item and item.id==item_id and (item.count or 0)>0 and (item.status or 0)==0 then
            return {slot=slot,count=item.count}
        end
    end
    return nil
end

local function tool_retry_target(spell,spellMap)
    if spellMap=='Utsusemi' or spellMap=='EnhancingNinjutsu' then return '<me>' end
    if spell and spell.target and spell.target.id and player and spell.target.id==player.id then return '<me>' end
    return '<t>'
end

local function queue_tool_cast_retry(spell,spellMap,delay,reason)
    tool_cast_retry.generation=tool_cast_retry.generation+1
    local gen=tool_cast_retry.generation
    tool_cast_retry.pending={
        generation=gen,
        spell=spell.english,
        target=tool_retry_target(spell,spellMap),
        reason=reason or 'tool move',
    }
    send_command(string.format('wait %.1f;gs c _toolcastretry %s %d',delay or 0.8,NIN_RUNTIME.token,gen))
end

local SHIHEI_PARK_BAGS={['Mog Satchel']=1,['Mog Sack']=2,['Mog Case']=3}
local function find_shihei_parking_bag()
    local candidates={}
    for id,bag in pairs(nin_res.bags or {}) do
        local name=bag and (bag.english or bag.name)
        local rank=name and SHIHEI_PARK_BAGS[name]
        if rank and type(id)=='number' then
            local info=windower.ffxi.get_bag_info(id)
            if info and info.enabled and (info.count or 0)<(info.max or 0) then
                candidates[#candidates+1]={id=id,rank=rank,name=name}
            end
        end
    end
    table.sort(candidates,function(a,b) return a.rank<b.rank end)
    return candidates[1]
end

local function park_shihei_once(verbose)
    init_tool_policy()
    local p=NIN_TOOL_POLICY.utsusemi
    if not p or not p.protected_id then return false,'resource' end
    local stack=tool_inventory_first(p.protected_id)
    tool_manager.hud_counts.shihei=stack and stack.count or 0
    if not stack then return false,'none' end
    local dest=find_shihei_parking_bag()
    if not dest then
        tool_warn_once('utsusemi','shihei_space',
            '[NIN Tools] SHIHEI PROTECTION: no free Mog Satchel/Sack/Case slot. Utsusemi will be blocked rather than consume Shihei.')
        return false,'no_space'
    end
    windower.ffxi.put_item(dest.id,stack.slot,stack.count)
    if verbose then
        add_to_chat(158,string.format('[NIN Tools] Parking %d Shihei -> %s. NIN Utsusemi policy uses Shikanofuda.',stack.count,dest.name))
    end
    -- If multiple stacks exist, continue parking them one at a time after inventory updates.
    send_command(string.format('wait 1.0;gs c _parkshihei %s',NIN_RUNTIME.token))
    return true,'moved'
end

local function cancel_for_tool_retry(spell,spellMap,eventArgs,delay,reason)
    cancel_spell()
    eventArgs.cancel=true
    eventArgs.handled=true
    queue_tool_cast_retry(spell,spellMap,delay,reason)
    return true
end

local function ensure_utsusemi_universal(spell,spellMap,eventArgs)
    init_tool_policy()
    local p=NIN_TOOL_POLICY.utsusemi
    if not p then return false end

    -- Shihei must not remain in Inventory on NIN, because specific tools are consumed before universal tools.
    if p.protected_id and tool_inventory_count(p.protected_id)>0 then
        local moved,why=park_shihei_once(true)
        if moved then
            return cancel_for_tool_retry(spell,spellMap,eventArgs,0.9,'park Shihei')
        end
        if why=='no_space' then
            cancel_spell(); eventArgs.cancel=true; eventArgs.handled=true
            add_to_chat(123,'[NIN Tools] Utsusemi canceled to preserve Shihei. Free a Satchel/Sack/Case slot or move Shihei manually.')
            return true
        end
    end

    -- Hard policy: NIN Utsusemi requires Shikanofuda. Do not silently consume Shihei.
    if tool_inventory_count(p.tool_id)>0 then
        tool_manager.hud_counts.utsusemi=tool_inventory_count(p.tool_id)
        return false
    end

    local loose=tool_find_accessible(p.tool_id)
    if loose then
        if tool_inventory_free_slots()<=0 then
            cancel_spell(); eventArgs.cancel=true; eventArgs.handled=true
            add_to_chat(123,'[NIN Tools] Utsusemi canceled: Inventory full; cannot retrieve Shikanofuda.')
            return true
        end
        windower.ffxi.get_item(loose.bag,loose.slot,loose.count)
        add_to_chat(158,'[NIN Tools] Retrieving Shikanofuda for Utsusemi; Shihei remains protected.')
        return cancel_for_tool_retry(spell,spellMap,eventArgs,0.9,'retrieve Shikanofuda')
    end

    if tool_inventory_count(p.toolbag_id)>0 then
        if open_toolbag_from_inventory('utsusemi',true) then
            return cancel_for_tool_retry(spell,spellMap,eventArgs,1.4,'open Toolbag (Shika)')
        end
    end

    local bag_match=tool_find_accessible(p.toolbag_id)
    if bag_match then
        if tool_inventory_free_slots()<=0 then
            cancel_spell(); eventArgs.cancel=true; eventArgs.handled=true
            add_to_chat(123,'[NIN Tools] Utsusemi canceled: Inventory full; cannot retrieve Toolbag (Shika).')
            return true
        end
        windower.ffxi.get_item(bag_match.bag,bag_match.slot,1)
        add_to_chat(158,'[NIN Tools] Retrieving Toolbag (Shika) for Utsusemi.')
        return cancel_for_tool_retry(spell,spellMap,eventArgs,0.9,'retrieve Toolbag (Shika)')
    end

    cancel_spell(); eventArgs.cancel=true; eventArgs.handled=true
    add_to_chat(123,'[NIN Tools] Utsusemi canceled: no Shikanofuda or Toolbag (Shika) available. Shihei was NOT consumed.')
    return true
end

local function prepare_specific_tool_priority(spell,spellMap,eventArgs)
    if not spell or spell.skill~='Ninjutsu' or not player or player.main_job~='NIN' then return false end
    init_tool_policy()

    if spellMap=='Utsusemi' then
        return ensure_utsusemi_universal(spell,spellMap,eventArgs)
    end

    local root=spell.english and spell.english:match('^([^:]+)')
    local p=root and NIN_SPECIFIC_TOOL_POLICY[root]
    if not p or not p.tool_id then return false end

    -- Specific already in Inventory: let FFXI consume it naturally before the universal tool.
    if tool_inventory_count(p.tool_id)>0 then return false end

    -- Prefer a loose specific stack from accessible bags.
    local loose=tool_find_accessible(p.tool_id)
    if loose then
        if tool_inventory_free_slots()<=0 then
            tool_warn_once('specific_'..root,'full',
                '[NIN Tools] '..p.tool..' available but Inventory is full; falling back to universal tool.')
            return false
        end
        windower.ffxi.get_item(loose.bag,loose.slot,loose.count)
        add_to_chat(158,'[NIN Tools] Specific-first: retrieving '..p.tool..' for '..spell.english..'.')
        return cancel_for_tool_retry(spell,spellMap,eventArgs,0.9,'retrieve '..p.tool)
    end

    -- If a specific toolbag is already/accessible, open/retrieve it before falling back.
    if p.toolbag_id and tool_inventory_count(p.toolbag_id)>0 and not midaction() then
        windower.chat.input('/item "'..p.toolbag..'" <me>')
        add_to_chat(158,'[NIN Tools] Specific-first: opening '..p.toolbag..' for '..spell.english..'.')
        return cancel_for_tool_retry(spell,spellMap,eventArgs,1.4,'open '..p.toolbag)
    end

    local bag_match=p.toolbag_id and tool_find_accessible(p.toolbag_id) or nil
    if bag_match then
        if tool_inventory_free_slots()<=0 then
            tool_warn_once('specific_'..root,'fullbag',
                '[NIN Tools] '..p.toolbag..' available but Inventory is full; falling back to universal tool.')
            return false
        end
        windower.ffxi.get_item(bag_match.bag,bag_match.slot,1)
        add_to_chat(158,'[NIN Tools] Specific-first: retrieving '..p.toolbag..' for '..spell.english..'.')
        return cancel_for_tool_retry(spell,spellMap,eventArgs,0.9,'retrieve '..p.toolbag)
    end

    -- No specific reserve found: universal fallback remains valid and no cast delay is introduced.
    return false
end

local function report_ninja_tool_priority()
    init_tool_policy()
    local shika=tool_inventory_count(NIN_TOOL_POLICY.utsusemi.tool_id)
    local shihei=NIN_TOOL_POLICY.utsusemi.protected_id and tool_inventory_count(NIN_TOOL_POLICY.utsusemi.protected_id) or 0
    add_to_chat(158,'[NIN Tool Priority] NIN main: spell-specific tool -> universal category tool.')
    add_to_chat(158,'[NIN Tool Priority] EXCEPTION Utsusemi: Shikanofuda ONLY; Shihei is parked/protected for /NIN jobs.')
    add_to_chat(158,string.format('[NIN Tool Priority] Current Inventory: Shikanofuda=%d | Shihei=%d (desired Shihei=0).',shika,shihei))
end

local function queue_tool_sweep()
    if NIN_RUNTIME.unloading then return end
    -- First protect Shihei, then perform normal universal reserve checks.
    send_command(string.format('wait 0.1;gs c _parkshihei %s',NIN_RUNTIME.token))
    for i,key in ipairs(TOOL_CATEGORY_ORDER) do send_command(string.format('wait %.1f;gs c _toolstep %s %s',0.4+(i-1)*1.0,key,NIN_RUNTIME.token)) end
end
local function report_tools()
    init_tool_policy(); add_to_chat(158,'[NIN Tools] proactive='..tostring(tool_manager.enabled)..' | mode='..tool_manager.toolbag_mode..' | threshold<=20 | target=80')
    local deferred={}
    for _,dkey in ipairs(TOOL_CATEGORY_ORDER) do
        if tool_manager.deferred_open[dkey] then
            deferred[#deferred+1]=dkey..'('..tostring(tool_manager.deferred_open[dkey])..')'
        end
    end
    add_to_chat(158,'[NIN Tools] deferred='..(#deferred>0 and table.concat(deferred,', ') or 'none'))
    add_to_chat(158,'[NIN Tools] priority=SPECIFIC FIRST -> UNIVERSAL | Utsusemi exception=SHIKANOFUDA ONLY / SHIHEI PROTECTED')
    for _,key in ipairs(TOOL_CATEGORY_ORDER) do
        local p=NIN_TOOL_POLICY[key]; local inv=tool_inventory_count(p.tool_id); tool_manager.hud_counts[key]=inv; local _,loose=tool_find_accessible(p.tool_id)
        local binv=tool_inventory_count(p.toolbag_id); local _,bags=tool_find_accessible(p.toolbag_id)
        add_to_chat(158,string.format('  %s: %s inv=%d + accessible=%d | %s inv=%d + accessible=%d',p.label,p.tool,inv,loose,p.toolbag,binv,bags))
    end
    if type(update_hud)=='function' then update_hud(true) end
end
local function force_toolbag_open(key)
    init_tool_policy()
    local p=NIN_TOOL_POLICY[key]
    if not p then
        add_to_chat(123,'[NIN Tools] Use: utsusemi | elemental | enfeebling | enhancing')
        return
    end

    if tool_inventory_count(p.toolbag_id)>0 then
        tool_manager.open_attempts[key]=0
        if not open_toolbag_from_inventory(key,true) then
            defer_toolbag_open(key,'manual_wait',0.85)
            add_to_chat(158,'[NIN Tools] Manual toolbag open queued for the next idle action window.')
        end
        return
    end

    local match=tool_find_accessible(p.toolbag_id)
    if not match then
        add_to_chat(123,'[NIN Tools] '..p.toolbag..' not found in accessible bags.')
        return
    end
    if tool_inventory_free_slots()<=0 then
        add_to_chat(123,'[NIN Tools] Inventory full.')
        return
    end

    windower.ffxi.get_item(match.bag,match.slot,1)
    tool_manager.deferred_open[key]='manual_toolbag_fetch'
    tool_mark_pending(key,'manual_toolbag_fetch',1.4)
    queue_tool_step(key,1.4)
end

local function process_deferred_toolbags()
    if not tool_manager.enabled or tool_manager.toolbag_mode=='Off' then return end
    for _,key in ipairs(TOOL_CATEGORY_ORDER) do
        if tool_manager.deferred_open[key] then
            -- Resume the complete retrieve/open/check state machine from wherever it stopped.
            if tool_check_category(key,false) then return end
        end
    end
end

-------------------------------------------------------------------------------------------------------------------
-- Gear-intelligence metadata. Diagnostics only; no runtime gear selection scans these tables.
-------------------------------------------------------------------------------------------------------------------

NIN_WEAPON_POLICY={
    ['Kaja/Tancho']={main='Kaja Katana',sub='Tancho +1',primary_ws='Blade: Ku',objective='Kaja Ku synergy + Tancho utility'},
    ['Kaja/Blurred']={main='Kaja Katana',sub='Blurred Knife +1',primary_ws='Blade: Ku',objective='Kaja Ku synergy + Blurred offhand'},
    ['Kaja/Tauret']={main='Kaja Katana',sub='Tauret',primary_ws='Blade: Ku',objective='Kaja Katana main-hand with Tauret offhand'},
    ['Naegling/Blurred']={main='Naegling',sub='Blurred Knife +1',primary_ws='Savage Blade',objective='Savage Blade profile'},
    ['Tauret/Blurred']={main='Tauret',sub='Blurred Knife +1',primary_ws='Evisceration',objective='Evisceration profile'},
    ['Tank']={main='Shuhansadamune',sub='Tancho +1',primary_ws='defensive',objective='defensive/evasion profile'},
}
NIN_WEAPONSKILL_POLICY={
    ['Blade: Ku']={family='physical_multi',source_set="sets.precast.WS['Blade: Ku']",objective='multi-hit STR/DEX with Kaja synergy'},
    ['Blade: Ten']={family='physical_wsd',source_set="sets.precast.WS['Blade: Ten']",objective='single-hit TP-scaling WSD',tp_behavior='damage'},
    ['Blade: Shun']={family='physical_multi',source_set="sets.precast.WS['Blade: Shun']",objective='DEX-heavy multi-hit',assumption='merit rank not invented'},
    ['Blade: Hi']={family='critical_physical',source_set="sets.precast.WS['Blade: Hi']",objective='AGI/critical damage'},
    ['Blade: Jin']={family='critical_multi',source_set="sets.precast.WS['Blade: Jin']",objective='STR/DEX critical multi-hit'},
    ['Blade: Kamu']={family='physical_wsd',source_set="sets.precast.WS['Blade: Kamu']",objective='single-hit STR/INT physical connector for Light chains; TP affects Accuracy Down duration, not damage'},
    ['Blade: Retsu']={family='physical_multi',source_set="sets.precast.WS['Blade: Retsu']",objective='two-hit DEX/STR physical connector for Distortion/Darkness chains; TP affects paralysis duration'},
    ['Savage Blade']={family='physical_wsd',source_set="sets.precast.WS['Savage Blade']",objective='STR/MND TP-scaling WSD',preferred_weapon='Naegling'},
    ['Evisceration']={family='critical_multi',source_set="sets.precast.WS['Evisceration']",objective='DEX critical multi-hit',preferred_weapon='Tauret'},
    ['Blade: Ei']={family='magical',source_set="sets.precast.WS['Blade: Ei']",objective='Dark magical STR/INT TP-scaling'},
    ['Blade: Yu']={family='magical',source_set="sets.precast.WS['Blade: Yu']",objective='Water magical; TP mainly poison duration'},
    ['Blade: Chi']={family='hybrid',source_set="sets.precast.WS['Blade: Chi']",objective='Earth hybrid TP-scaling'},
    ['Blade: To']={family='hybrid',source_set="sets.precast.WS['Blade: To']",objective='Ice hybrid TP-scaling'},
    ['Blade: Teki']={family='hybrid',source_set="sets.precast.WS['Blade: Teki']",objective='Water hybrid TP-scaling'},
}
NIN_ACTION_GEAR_POLICY={
    ['Engaged: Normal']={source_set='sets.engaged',objective='TP efficiency + Daken'},
    ['Engaged: Hybrid']={source_set='sets.engaged.DTOverlay',objective='DT cap overlay'},
    ['Defense: PDT']={source_set='sets.defense.PDT',objective='durable emergency physical state'},
    ['Defense: MDT']={source_set='sets.defense.MDT',objective='durable emergency magical state'},
    ['Defense: Evasion']={source_set='sets.defense.Evasion',objective='evasion/defense'},
    ['Defense: Yonin']={source_set='sets.defense.Yonin',objective='named Yonin defensive source',invariant='never auto-switch modes'},
    ['Ranged: Manual Throwing']={source_set='sets.midcast.RA',objective='manual throwing accuracy; not Daken'},
    ['Ranged: Daken']={source_set='engaged ammo policy',objective='automatic Daken contribution',invariant='Date Shuriken outside Sange'},
    ['Ranged: Sange']={source_set='sets.buff.SangeSafe',objective='protect Date Shuriken',invariant='ammo forced empty automatically'},
    ['Ninjutsu: Elemental MaxAcc']={source_set='sets.midcast.ElementalNinjutsu.MaxAcc',objective='emergency max MAcc source set'},
    ['Ninjutsu: Elemental Wheel']={source_set='sets.midcast.ElementalNinjutsu',objective='Win+N controlled San resistance chain: Hyoton -> Katon -> Suiton -> Raiton -> Doton -> Huton'},
    ['Skillchains: Controller']={source_set='dedicated WS sets',objective='Win+F5-F8 guarded 2/4-step Light/Darkness self-skillchains',invariant='one press per WS; no advance on failure/interrupt/TP shortage'},
    ['Utility: Fishing']={source_set='sets.Fishing',objective='Win+F fixed fishing gear + all-slot GearSwap freeze'},
    ['Utility: Treasure Hunter']={source_set='sets.TreasureHunter',objective='Off/Tag/Fulltime TH+3 overlay with per-target Tag state'},
    ['Utility: Shadows']={source_set='sets.precast.FC.Utsusemi / sets.midcast.Utsusemi',objective='manual smart Ichi + opt-in Safe/Tank event-driven shadow upkeep'},
}

-------------------------------------------------------------------------------------------------------------------
-- Setup
-------------------------------------------------------------------------------------------------------------------

function job_setup()
    include('ItemStats.lua')
    state.Buff.Migawari=buffactive.migawari or false
    state.Buff.Yonin=buffactive.yonin or false
    state.Buff.Innin=buffactive.innin or false
    state.Buff.Futae=buffactive.futae or false
    state.Buff.Sange=buffactive.sange or false
    state.Buff.Doom=buffactive.doom or false
    init_tool_policy()
end

-------------------------------------------------------------------------------------------------------------------
-- Itemizer compatibility / tool-ownership handoff
--
-- Itemizer AutoNinjaTools intercepts outgoing ninjutsu and checks old spell-specific tools before universal
-- tools unless its per-spell universal flags are changed. That can produce misleading "missing ninja tool"
-- messages even when this NIN profile has the correct universal tool available.
--
-- This profile already owns proactive universal-tool logistics. Itemizer's `ant` command is a toggle, so
-- blindly issuing it on every GearSwap reload would alternate ON/OFF. v1.5.0 performs the handoff once,
-- then persists a per-character marker under GearSwap/data so later reloads never toggle it again.
--
-- Migration assumption: the observed Itemizer missing-tool messages indicate AutoNinjaTools is ON before
-- the first v1.5.0 load. That first load toggles it OFF. Itemizer itself stays loaded.
-------------------------------------------------------------------------------------------------------------------
local function itemizer_handoff_marker_path()
    local base = (windower and windower.addon_path) or '.'
    local pname = (player and player.name) or 'default'
    pname = tostring(pname):gsub('[^%w_%-]','_')
    return base..'/data/NIN_Itemizer_AutoNinjaTools_DISABLED_'..pname..'.flag'
end

local function itemizer_handoff_done()
    local f = io.open(itemizer_handoff_marker_path(),'r')
    if not f then return false end
    f:close()
    return true
end

local function persist_itemizer_handoff()
    local f = io.open(itemizer_handoff_marker_path(),'w')
    if not f then
        add_to_chat(123,'[NIN Itemizer] Could not persist handoff marker; Itemizer was NOT toggled.')
        return false
    end
    f:write('NIN v1.6.1 owns ninja-tool logistics; Itemizer AutoNinjaTools toggled OFF once for this character.\n')
    f:close()
    return true
end

local function ensure_nin_owns_tool_logistics()
    if itemizer_handoff_done() then return end
    if not persist_itemizer_handoff() then return end
    send_command('wait 0.5;itemizer ant')
    add_to_chat(158,'[NIN Itemizer] One-time handoff: AutoNinjaTools OFF; NIN Lua owns ninja-tool reserves.')
end

local function report_itemizer_policy()
    add_to_chat(158,'[NIN Itemizer] Tool owner: NIN Lua (universal tools + toolbags).')
    add_to_chat(158,'[NIN Itemizer] AutoNinjaTools expected OFF | handoff marker='..
        (itemizer_handoff_done() and 'PRESENT' or 'MISSING'))
    add_to_chat(158,'[NIN Itemizer] Itemizer remains available for AutoItems and manual item commands.')
end

function user_setup()
    NIN_RUNTIME.unloading=false
    state.OffenseMode:options('Normal','MidAcc','HighAcc')
    state.HybridMode:options('Normal','DT')
    state.WeaponskillMode:options('Normal','Acc')
    state.CastingMode:options('Normal','Resistant','SIRD')
    state.IdleMode:options('Normal','DT')
    state.PhysicalDefenseMode:options('PDT','Evasion')
    if state.MagicalDefenseMode then state.MagicalDefenseMode:options('MDT') end
    state.WeaponSet=M{['description']='Weapon Set','Kaja/Tancho','Kaja/Blurred','Kaja/Tauret','Naegling/Blurred','Tauret/Blurred','Tank'}
    state.WeaponLock=M(true,'Weapon Lock')
    state.MagicBurst=M(false,'Magic Burst')
    state.AutoBurst=M(true,'Auto Burst Detect')
    state.PauseSwaps=M(false,'Pause Gear Swapping')
    state.FishingMode=M(false,'Fishing Mode')
    state.TreasureMode=M{['description']='Treasure Hunter','Off','Tag','Fulltime'}
    state.ShadowMode=M{['description']='Shadow Mode','Off','Safe','Tank'}
    state.Stance=M{['description']='Desired Stance','None','Yonin','Innin'}
    state.ElementMode=M{['description']='Element','Fire','Water','Lightning','Earth','Wind','Ice'}
    state.Auto_Kite=M(false,'Auto Kiting')
    state.HasteTier=M{['description']='Haste Tier',2,1}
    send_command('bind @w gs c toggle WeaponLock')
    send_command('bind @r gs c cycle WeaponSet')
    send_command('bind @e gs c cycleback WeaponSet')
    send_command('bind !m gs c toggle MagicBurst')
    send_command('bind @g gs c toggle AutoBurst')
    send_command('bind @p gs c toggle PauseSwaps')
    send_command('bind @h gs c hud')
    send_command('bind @f gs c toggle FishingMode')
    send_command('bind @t gs c cycle TreasureMode')
    send_command('bind @s gs c cycle ShadowMode')
    send_command('bind @y gs c cycle Stance')
    send_command('bind @j gs c cycle ElementMode')
    send_command('bind @k gs c nuke')
    send_command('bind @n gs c wheel')
    send_command('bind @f5 gs c sc 2light')
    send_command('bind @f6 gs c sc 2dark')
    send_command('bind @f7 gs c sc 4light')
    send_command('bind @f8 gs c sc 4dark')
    init_hud()
    register_nin_events()
    if buffactive and buffactive.silence then
        silence_echo.generation=silence_echo.generation+1
        silence_echo.active=true; silence_echo.attempts=0
        try_echo_drops(silence_echo.generation)
    end
    ensure_nin_owns_tool_logistics()
    send_command('wait 1;gs c _startupkeys '..NIN_RUNTIME.token)
    send_command('wait 2;gs c _toolsweep '..NIN_RUNTIME.token)
end

function user_unload()
    NIN_RUNTIME.unloading=true
    NIN_RUNTIME.token='unloaded-'..tostring(os.clock())
    unregister_nin_events()
    clear_burst_window()
    silence_echo.generation=silence_echo.generation+1
    silence_echo.active=false
    if tool_manager then
        tool_manager.enabled=false
        tool_manager.pending={}
        tool_manager.deferred_open={}
        tool_manager.deferred_attempts={}
        tool_manager.retry_serial={}
    end
    if tool_cast_retry then
        tool_cast_retry.generation=tool_cast_retry.generation+1
        tool_cast_retry.pending=nil
    end
    elemental_wheel_reset(true)
    skillchain_reset(true)
    enable(unpack(ALL_EQUIP_SLOTS))
    send_command('unbind @w'); send_command('unbind @r'); send_command('unbind @e'); send_command('unbind !m')
    send_command('unbind @g'); send_command('unbind @p'); send_command('unbind @h'); send_command('unbind @n')
    send_command('unbind @f'); send_command('unbind @t'); send_command('unbind @s'); send_command('unbind @y'); send_command('unbind @j'); send_command('unbind @k')
    send_command('unbind @f5'); send_command('unbind @f6'); send_command('unbind @f7'); send_command('unbind @f8')
    if nin_hud then nin_hud:hide() end
end

-------------------------------------------------------------------------------------------------------------------
-- Owned gear sets
-------------------------------------------------------------------------------------------------------------------

function init_gear_sets()
    nin_gear=nin_gear or {}
    nin_gear.andartia={name="Andartia's Mantle",augments={'DEX+20','Accuracy+20 Attack+20','"Dbl.Atk."+10'}}
    nin_gear.hattori_ear={name='Hattori Earring',augments={'System: 1 ID: 1676 Val: 0','Accuracy+6','Mag. Acc.+6'}}
    nin_gear.moonshade={name='Moonshade Earring',augments={'Accuracy+4','TP Bonus +250'}}
    nin_gear.ghastly={name='Ghastly Tathlum +1',augments={'Path: A'}}
    nin_gear.murky={name='Murky Ring',augments={'Path: A'}}
    nin_gear.sailfi={name='Sailfi Belt +1',augments={'Path: A'}}

    sets.weapons={
        ['Kaja/Tancho']={main='Kaja Katana',sub='Tancho +1'},
        ['Kaja/Blurred']={main='Kaja Katana',sub='Blurred Knife +1'},
        ['Kaja/Tauret']={main='Kaja Katana',sub='Tauret'},
        ['Naegling/Blurred']={main='Naegling',sub='Blurred Knife +1'},
        ['Tauret/Blurred']={main='Tauret',sub='Blurred Knife +1'},
        ['Tank']={main='Shuhansadamune',sub='Tancho +1'},
    }

    -- Maximum verified owned non-weapon FC = 13%. Free armor/waist slots are filled with haste so
    -- the precast snapshot is also gear-haste capped without sacrificing any Fast Cast.
    sets.precast.FC={ammo='Impatiens',head='Malignance Chapeau',body='Taeon Tabard',hands='Malignance Gloves',legs='Malignance Tights',feet='Malignance Boots',neck='Null Loop',ear1='Loquac. Earring',ear2='Enchntr. Earring +1',ring1='Kishar Ring',ring2="Naji's Loop",waist=nin_gear.sailfi}
    sets.precast.FC.Utsusemi=set_combine(sets.precast.FC,{back=nin_gear.andartia})
    sets.precast.RA={ammo='Yamarang',head='Malignance Chapeau',body='Malignance Tabard',hands='Malignance Gloves',legs='Malignance Tights',feet='Malignance Boots'}
    sets.precast.JA['Futae']={}; sets.precast.JA['Yonin']={}; sets.precast.JA['Innin']={}; sets.precast.JA['Sange']={}

    -- /DNC utility routing. Only NIN/ALL-valid owned gear is used; no DNC-main-only pieces.
    sets.precast.Waltz={ammo='Yamarang',head='Mummu Bonnet +2',body='Mummu Jacket +2',hands='Mummu Wrists +2',legs='Mummu Kecks +2',feet='Mummu Gamash. +2'}
    sets.precast.Waltz['Healing Waltz']={}
    sets.precast.Step={ammo='Yamarang',head='Malignance Chapeau',body='Malignance Tabard',hands='Malignance Gloves',legs='Malignance Tights',feet='Malignance Boots',neck='Null Loop',ear1='Telos Earring',ring1='Varar Ring +1',ring2='Chirich Ring +1',back='Null Shawl',waist='Null Belt'}
    sets.precast.Flourish1=set_combine(sets.precast.Step,{})
    sets.precast.Flourish1['Violent Flourish']={ammo='Yamarang',head='Malignance Chapeau',body='Malignance Tabard',hands='Malignance Gloves',legs='Malignance Tights',feet='Malignance Boots',neck='Null Loop',ear1='Enchntr. Earring +1',ear2=nin_gear.hattori_ear,ring1='Stikini Ring +1',ring2='Stikini Ring +1',back='Null Shawl',waist='Null Belt'}

    sets.precast.WS={ammo="Oshasha's Treatise",head='Nyame Helm',body='Nyame Mail',hands='Nyame Gauntlets',legs='Nyame Flanchard',feet='Nyame Sollerets',neck='Rep. Plat. Medal',ear1='Mache Earring +1',ear2=nin_gear.hattori_ear,ring1="Epaminondas's Ring",ring2='Chirich Ring +1',back=nin_gear.andartia,waist='Grunfeld Rope'}
    sets.precast.WS.Acc=set_combine(sets.precast.WS,{ammo='Yamarang',neck='Null Loop',ear1='Telos Earring',ring1='Varar Ring +1',ring2='Chirich Ring +1',back='Null Shawl',waist='Null Belt'})

    sets.precast.WS['Savage Blade']={ammo="Oshasha's Treatise",head='Nyame Helm',body='Nyame Mail',hands='Nyame Gauntlets',legs='Nyame Flanchard',feet='Nyame Sollerets',neck='Rep. Plat. Medal',ear1=nin_gear.moonshade,ear2=nin_gear.hattori_ear,ring1="Epaminondas's Ring",ring2='Sroda Ring',back=nin_gear.andartia,waist='Grunfeld Rope'}
    sets.precast.WS['Savage Blade'].Acc=set_combine(sets.precast.WS['Savage Blade'],{ammo='Yamarang',neck='Null Loop',ear2='Telos Earring',ring2='Varar Ring +1',back='Null Shawl',waist='Null Belt'})
    sets.precast.WS['Savage Blade'].MaxTP=set_combine(sets.precast.WS['Savage Blade'],{ear1='Mache Earring +1'})

    sets.precast.WS['Evisceration']={ammo='Yetshila +1',head="Mpaca's Cap",body="Mpaca's Doublet",hands='Ken. Tekko',legs="Mpaca's Hose",feet='Mummu Gamash. +2',neck='Ninja Nodowa',ear1='Odr Earring',ear2=nin_gear.hattori_ear,ring1='Mummu Ring',ring2='Ramuh Ring +1',back=nin_gear.andartia,waist='Windbuffet Belt +1'}
    sets.precast.WS['Evisceration'].Acc=set_combine(sets.precast.WS['Evisceration'],{ammo='Yamarang',head='Malignance Chapeau',body='Malignance Tabard',hands='Malignance Gloves',legs='Malignance Tights',feet='Malignance Boots',neck='Null Loop',ear1='Telos Earring',ring1='Varar Ring +1',ring2='Chirich Ring +1',back='Null Shawl',waist='Null Belt'})

    sets.precast.WS['Blade: Ku']={ammo='Date Shuriken',head='Ken. Jinpachi',body='Ken. Samue',hands='Ken. Tekko',legs="Mpaca's Hose",feet='Ken. Sune-Ate',neck='Ninja Nodowa',ear1='Telos Earring',ear2=nin_gear.hattori_ear,ring1="Epaminondas's Ring",ring2='Chirich Ring +1',back=nin_gear.andartia,waist='Windbuffet Belt +1'}
    sets.precast.WS['Blade: Ku'].Acc=set_combine(sets.precast.WS['Blade: Ku'],{ammo='Yamarang',head='Malignance Chapeau',body='Malignance Tabard',hands='Malignance Gloves',legs='Malignance Tights',feet='Malignance Boots',neck='Null Loop',ear1='Telos Earring',ring1='Varar Ring +1',ring2='Chirich Ring +1',back='Null Shawl',waist='Null Belt'})

    sets.precast.WS['Blade: Ten']={ammo="Oshasha's Treatise",head="Mpaca's Cap",body='Nyame Mail',hands='Nyame Gauntlets',legs='Nyame Flanchard',feet='Nyame Sollerets',neck='Rep. Plat. Medal',ear1=nin_gear.moonshade,ear2=nin_gear.hattori_ear,ring1="Epaminondas's Ring",ring2='Ramuh Ring +1',back=nin_gear.andartia,waist='Grunfeld Rope'}
    sets.precast.WS['Blade: Ten'].Acc=set_combine(sets.precast.WS['Blade: Ten'],{ammo='Yamarang',neck='Null Loop',ear2='Telos Earring',ring2='Varar Ring +1',back='Null Shawl',waist='Null Belt'})
    sets.precast.WS['Blade: Ten'].MaxTP=set_combine(sets.precast.WS['Blade: Ten'],{ear1='Mache Earring +1'})

    sets.precast.WS['Blade: Shun']={ammo='Date Shuriken',head='Ken. Jinpachi',body='Ken. Samue',hands='Ken. Tekko',legs='Ken. Hakama',feet='Ken. Sune-Ate',neck='Ninja Nodowa',ear1='Telos Earring',ear2=nin_gear.hattori_ear,ring1='Ramuh Ring +1',ring2='Chirich Ring +1',back=nin_gear.andartia,waist='Windbuffet Belt +1'}
    sets.precast.WS['Blade: Shun'].Acc=set_combine(sets.precast.WS['Blade: Shun'],{ammo='Yamarang',head='Malignance Chapeau',body='Malignance Tabard',hands='Malignance Gloves',legs='Malignance Tights',feet='Malignance Boots',neck='Null Loop',ring1='Varar Ring +1',ring2='Chirich Ring +1',back='Null Shawl',waist='Null Belt'})

    sets.precast.WS['Blade: Hi']={ammo='Yetshila +1',head='Mummu Bonnet +2',body='Mummu Jacket +2',hands='Mummu Wrists +2',legs='Mummu Kecks +2',feet='Mummu Gamash. +2',neck='Ninja Nodowa',ear1='Odr Earring',ear2=nin_gear.hattori_ear,ring1='Mummu Ring',ring2="Epaminondas's Ring",back=nin_gear.andartia,waist='Windbuffet Belt +1'}
    sets.precast.WS['Blade: Hi'].Acc=set_combine(sets.precast.WS['Blade: Hi'],{ammo='Yamarang',head='Malignance Chapeau',body='Malignance Tabard',hands='Malignance Gloves',legs='Malignance Tights',feet='Malignance Boots',neck='Null Loop',ear1='Telos Earring',ring1='Varar Ring +1',ring2='Chirich Ring +1',back='Null Shawl',waist='Null Belt'})

    sets.precast.WS['Blade: Jin']={ammo='Yetshila +1',head='Ken. Jinpachi',body='Mummu Jacket +2',hands='Mummu Wrists +2',legs="Mpaca's Hose",feet='Ken. Sune-Ate',neck='Ninja Nodowa',ear1='Odr Earring',ear2=nin_gear.hattori_ear,ring1='Mummu Ring',ring2='Ramuh Ring +1',back=nin_gear.andartia,waist='Windbuffet Belt +1'}
    sets.precast.WS['Blade: Jin'].Acc=set_combine(sets.precast.WS['Blade: Jin'],{ammo='Yamarang',head='Malignance Chapeau',body='Malignance Tabard',hands='Malignance Gloves',legs='Malignance Tights',feet='Malignance Boots',neck='Null Loop',ear1='Telos Earring',ring1='Varar Ring +1',ring2='Chirich Ring +1',back='Null Shawl',waist='Null Belt'})

    -- Blade: Kamu: physical single-hit, 60% STR / 60% INT, fixed 1.0 fTP; TP extends Accuracy Down rather than damage.
    -- Owned-gear objective: WSD/stat-heavy physical set; no Moonshade dependency for damage.
    sets.precast.WS['Blade: Kamu']={ammo="Oshasha's Treatise",head="Mpaca's Cap",body='Nyame Mail',hands='Nyame Gauntlets',legs="Mpaca's Hose",feet='Nyame Sollerets',neck='Ninja Nodowa',ear1='Mache Earring +1',ear2=nin_gear.hattori_ear,ring1="Epaminondas's Ring",ring2='Sroda Ring',back=nin_gear.andartia,waist=nin_gear.sailfi}
    sets.precast.WS['Blade: Kamu'].Acc=set_combine(sets.precast.WS['Blade: Kamu'],{ammo='Yamarang',head='Malignance Chapeau',body='Malignance Tabard',hands='Malignance Gloves',legs='Malignance Tights',feet='Malignance Boots',neck='Null Loop',ear1='Telos Earring',ring1='Varar Ring +1',ring2='Chirich Ring +1',back='Null Shawl',waist='Null Belt'})

    -- Blade: Retsu: physical two-hit, 60% DEX / 20% STR; TP extends paralysis duration rather than damage.
    -- Owned-gear objective: DEX/accuracy/multi-hit physical set for reliable Darkness-chain connection.
    sets.precast.WS['Blade: Retsu']={ammo='Date Shuriken',head='Ken. Jinpachi',body='Ken. Samue',hands='Ken. Tekko',legs='Ken. Hakama',feet='Ken. Sune-Ate',neck='Ninja Nodowa',ear1='Telos Earring',ear2=nin_gear.hattori_ear,ring1='Ramuh Ring +1',ring2='Chirich Ring +1',back=nin_gear.andartia,waist='Windbuffet Belt +1'}
    sets.precast.WS['Blade: Retsu'].Acc=set_combine(sets.precast.WS['Blade: Retsu'],{ammo='Yamarang',head='Malignance Chapeau',body='Malignance Tabard',hands='Malignance Gloves',legs='Malignance Tights',feet='Malignance Boots',neck='Null Loop',ear1='Telos Earring',ring1='Varar Ring +1',ring2='Chirich Ring +1',back='Null Shawl',waist='Null Belt'})

    sets.precast.WS.Magic={ammo=nin_gear.ghastly,head='Nyame Helm',body='Nyame Mail',hands='Nyame Gauntlets',legs='Nyame Flanchard',feet='Nyame Sollerets',neck='Sibyl Scarf',ear1='Friomisi Earring',ear2='Sortiarius Earring',ring1='Dingir Ring',ring2='Metamor. Ring +1',back='Toro Cape',waist='Skrymir Cord'}
    sets.precast.WS['Blade: Ei']=set_combine(sets.precast.WS.Magic,{head='Pixie Hairpin +1',ear1=nin_gear.moonshade})
    sets.precast.WS['Blade: Yu']=set_combine(sets.precast.WS.Magic,{})
    sets.precast.WS['Blade: Chi']=set_combine(sets.precast.WS.Magic,{ear1=nin_gear.moonshade})
    sets.precast.WS['Blade: To']=set_combine(sets.precast.WS.Magic,{ear1=nin_gear.moonshade})
    sets.precast.WS['Blade: Teki']=set_combine(sets.precast.WS.Magic,{ear1=nin_gear.moonshade})

    sets.midcast.RA={ammo='Yamarang',head='Malignance Chapeau',body='Malignance Tabard',hands='Malignance Gloves',legs='Malignance Tights',feet='Malignance Boots',neck='Null Loop',ear1='Telos Earring',ear2=nin_gear.hattori_ear,ring1='Chirich Ring +1',ring2='Chirich Ring +1',back='Null Shawl',waist='Null Belt'}
    -- Recast set: 13% FC plus capped equipment haste. Taeon body is intentional: replacing it with
    -- Malignance Tabard loses 4 FC while the remaining haste pieces already keep the gear-haste bucket capped.
    sets.midcast.FastRecast={head='Malignance Chapeau',body='Taeon Tabard',hands='Malignance Gloves',legs='Malignance Tights',feet='Malignance Boots',neck='Null Loop',ear1='Loquac. Earring',ear2='Enchntr. Earring +1',ring1='Kishar Ring',ring2="Naji's Loop",waist=nin_gear.sailfi}
    sets.midcast.SIRD={ammo='Staunch Tathlum +1',head='Malignance Chapeau',body='Malignance Tabard',hands='Malignance Gloves',legs='Malignance Tights',feet='Malignance Boots',neck='Null Loop',ear1='Magnetic Earring',ear2=nin_gear.hattori_ear,ring1='Evanescence Ring',ring2=nin_gear.murky,back=nin_gear.andartia,waist='Null Belt'}
    -- Normal Utsusemi favors recast speed while retaining Andartia's Utsusemi+1.
    -- Explicit CastingMode=SIRD remains the interruption-resistant safety choice.
    sets.midcast.Utsusemi=set_combine(sets.midcast.FastRecast,{ammo='Staunch Tathlum +1',back=nin_gear.andartia})
    sets.midcast.Utsusemi.Resistant=set_combine(sets.midcast.Utsusemi,{})
    sets.midcast.Utsusemi.SIRD=set_combine(sets.midcast.SIRD,{back=nin_gear.andartia})

    sets.midcast.ElementalNinjutsu={ammo=nin_gear.ghastly,head='Nyame Helm',body='Nyame Mail',hands='Nyame Gauntlets',legs='Nyame Flanchard',feet='Nyame Sollerets',neck='Sibyl Scarf',ear1='Friomisi Earring',ear2='Sortiarius Earring',ring1='Dingir Ring',ring2='Metamor. Ring +1',back='Toro Cape',waist='Skrymir Cord'}
    sets.midcast.ElementalNinjutsu.Resistant=set_combine(sets.midcast.ElementalNinjutsu,{ammo='Yamarang',neck='Null Loop',ear1='Enchntr. Earring +1',ear2=nin_gear.hattori_ear,ring1='Stikini Ring +1',ring2='Stikini Ring +1',back='Null Shawl',waist='Null Belt'})
    sets.midcast.ElementalNinjutsu.MaxAcc=set_combine(sets.midcast.ElementalNinjutsu.Resistant,{head='Malignance Chapeau',body='Malignance Tabard',hands='Malignance Gloves',legs='Malignance Tights',feet='Malignance Boots'})
    sets.midcast.ElementalNinjutsu.SIRD=sets.midcast.SIRD
    sets.midcast.ElementalNinjutsu.Burst=set_combine(sets.midcast.ElementalNinjutsu,{ring2='Mujin Band'})
    sets.midcast.ElementalNinjutsu.BurstResistant=set_combine(sets.midcast.ElementalNinjutsu.Resistant,{ring2='Mujin Band'})
    sets.magic_burst=sets.midcast.ElementalNinjutsu.Burst

    sets.midcast.EnfeeblingNinjutsu={ammo='Yamarang',head='Malignance Chapeau',body='Malignance Tabard',hands='Malignance Gloves',legs='Malignance Tights',feet='Malignance Boots',neck='Null Loop',ear1='Enchntr. Earring +1',ear2=nin_gear.hattori_ear,ring1='Stikini Ring +1',ring2='Stikini Ring +1',back='Null Shawl',waist='Null Belt'}
    sets.midcast.EnfeeblingNinjutsu.Resistant=set_combine(sets.midcast.EnfeeblingNinjutsu,{})
    sets.midcast.EnfeeblingNinjutsu.SIRD=sets.midcast.SIRD
    -- Self-enhancing ninjutsu has no enemy landing check; Normal mode therefore favors recast speed.
    -- SIRD remains available as an explicit safety mode. Migawari keeps Andartia for its job-specific bonus.
    sets.midcast.EnhancingNinjutsu=set_combine(sets.midcast.FastRecast,{ammo='Yamarang'})
    sets.midcast.EnhancingNinjutsu.Resistant=set_combine(sets.midcast.EnhancingNinjutsu,{})
    sets.midcast.EnhancingNinjutsu.SIRD=sets.midcast.SIRD
    sets.midcast.Migawari=set_combine(sets.midcast.FastRecast,{ammo='Yamarang',back=nin_gear.andartia})

    sets.engaged={ammo='Date Shuriken',head='Malignance Chapeau',body='Malignance Tabard',hands='Malignance Gloves',legs='Malignance Tights',feet='Malignance Boots',neck='Ninja Nodowa',ear1='Telos Earring',ear2=nin_gear.hattori_ear,ring1='Chirich Ring +1',ring2='Chirich Ring +1',back=nin_gear.andartia,waist='Windbuffet Belt +1'}
    sets.engaged.MidAcc=set_combine(sets.engaged,{neck='Null Loop',ear1='Mache Earring +1',waist='Null Belt'})
    sets.engaged.HighAcc=set_combine(sets.engaged,{ammo='Yamarang',neck='Null Loop',ear1='Telos Earring',ring1='Varar Ring +1',ring2='Chirich Ring +1',back='Null Shawl',waist='Null Belt'})
    sets.engaged.DTOverlay={neck='Null Loop',ear1='Alabaster Earring',ring1=nin_gear.murky}

    sets.idle={ammo='Yamarang',head='Malignance Chapeau',body='Malignance Tabard',hands='Malignance Gloves',legs='Malignance Tights',feet='Malignance Boots',neck='Null Loop',ear1='Alabaster Earring',ear2=nin_gear.hattori_ear,ring1=nin_gear.murky,ring2='Chirich Ring +1',back='Null Shawl',waist='Null Belt'}
    sets.idle.DT=set_combine(sets.idle,{})
    sets.Kiting={ring2='Shneddick Ring'}
    sets.TreasureHunter={ammo='Per. Lucky Egg',ring1='Hoxne Ring'}
    sets.Fishing={range="Lu Shang's F. Rod",body="Fisherman's Tunica",hands="Fisherman's Gloves",legs="Fisherman's Hose",feet="Fisherman's Boots"}
    sets.defense.PDT=sets.idle.DT
    sets.defense.MDT=sets.idle.DT
    sets.defense.Evasion={ammo='Yamarang',head='Malignance Chapeau',body='Malignance Tabard',hands='Malignance Gloves',legs='Malignance Tights',feet='Malignance Boots',neck='Null Loop',ear1='Eabani Earring',ear2=nin_gear.hattori_ear,ring1='Vengeful Ring',ring2='Chirich Ring +1',back='Null Shawl',waist='Null Belt'}
    sets.defense.Yonin=sets.defense.Evasion
    sets.buff.SangeSafe={ammo=empty}
    sets.buff.Doom={neck="Nicander's Necklace",ring1="Blenmot's Ring +1",ring2="Blenmot's Ring +1",waist='Gishdubar Sash'}

    equipment_snapshot.initialized=false
    native_state_haste=-1; native_state_gear_need=-1; dw_overlay_need_cache=-1; dw_overlay={}
    invalidate_haste_cache()
    update_native_haste_dw(true)
    check_weaponset(true)
    protected_ring_check()
    if state.Buff.Doom then set_doom_policy(true) end
    update_hud(true)
end

-------------------------------------------------------------------------------------------------------------------
-- Mote hooks / action routing
-------------------------------------------------------------------------------------------------------------------

function job_get_spell_map(spell,defaultSpellMap)
    if spell and spell.skill=='Ninjutsu' then return NINJUTSU_MAP[spell.english] or defaultSpellMap end
    return defaultSpellMap
end

function job_pretarget(spell,action,spellMap,eventArgs)
    if spell and spell.skill=='Ninjutsu' then
        if prepare_specific_tool_priority(spell,spellMap or NINJUTSU_MAP[spell.english],eventArgs) then return end
    end
    if spell and spell.type=='WeaponSkill' then
        local out,maxd=ws_out_of_range(spell)
        if out then
            local actual=tonumber(spell.target and spell.target.distance) or -1
            cancel_spell(); eventArgs.cancel=true; eventArgs.handled=true
            if skillchain_ctl.pending and skillchain_ctl.pending.ws==spell.english then
                skillchain_ctl.pending=nil
                add_to_chat(123,'[NIN SC] '..spell.english..' held: out of range; same chain step remains selected.')
            end
            add_to_chat(123,string.format('[NIN Range] %s canceled: %.1f yalms > safe %.1f.',spell.english,actual,maxd or 0))
            return
        end
    end
end

function job_precast(spell,action,spellMap,eventArgs)
    protected_ring_check()
    if spellMap=='Utsusemi' then
        if smart_utsusemi_precast(spell,eventArgs) then return end
    end
    if spell.type=='JobAbility' and spell.english=='Sange' then
        add_to_chat(123,'[NIN SAFETY] Sange consumes shuriken. Date Shuriken will be unequipped while Sange is active.')
    end
end

function job_post_precast(spell,action,spellMap,eventArgs)
    if th_action_overlay(spell) and sets.TreasureHunter then equip(sets.TreasureHunter) end
    if spell.type=='WeaponSkill' then
        local tp=player.tp or 0
        if spell.english=='Blade: Ten' and tp>=2550 then
            equip({ear1='Mache Earring +1'})
        elseif spell.english=='Savage Blade' and tp>=2750 then
            equip({ear1='Mache Earring +1'})
        elseif (spell.english=='Blade: Ei' or spell.english=='Blade: Chi' or spell.english=='Blade: To' or spell.english=='Blade: Teki') and tp>=2750 then
            equip({ear1='Friomisi Earring'})
        end
    end
    if state.Buff.Sange then equip(sets.buff.SangeSafe) end
end

function job_post_midcast(spell,action,spellMap,eventArgs)
    if spellMap=='ElementalNinjutsu' then
        local bursting=state.MagicBurst.value or (state.AutoBurst and state.AutoBurst.value and burst_window_active(spell))
        -- SIRD is an explicit safety mode; do not silently replace it with burst gear.
        if bursting and state.CastingMode.value~='SIRD' then
            if state.CastingMode.value=='Resistant' then equip(sets.midcast.ElementalNinjutsu.BurstResistant)
            else equip(sets.midcast.ElementalNinjutsu.Burst) end
        end
    end
    if spell.english=='Migawari: Ichi' then equip(sets.midcast.Migawari) end
    if th_action_overlay(spell) and sets.TreasureHunter then equip(sets.TreasureHunter) end
    if state.Buff.Sange then equip(sets.buff.SangeSafe) end
end

function job_aftercast(spell,action,spellMap,eventArgs)
    shadow_runtime.ichi_generation=shadow_runtime.ichi_generation+1
    if shadow_runtime.pending and spell and spell.english==shadow_runtime.pending then shadow_runtime.pending=nil end
    if spell and not spell.interrupted and th_tracker.pending_target_id and spell.target and spell.target.id==th_tracker.pending_target_id then th_mark_tagged(spell.target.id,spell.english) end
    skillchain_aftercast(spell)
    elemental_wheel_aftercast(spell)
    if spell and not spell.interrupted then
        local key=TOOL_CATEGORY_BY_MAP[spellMap or NINJUTSU_MAP[spell.english]]
        -- Let GearSwap/game action state settle before any toolbag /item command.
        if key and tool_manager.enabled then queue_tool_step(key,0.85) end
    end
    if tool_manager.enabled and next(tool_manager.deferred_open) then
        send_command(string.format('wait 0.90;gs c _tooldeferredsweep %s',NIN_RUNTIME.token))
    end
    update_native_haste_dw(false)
    check_weaponset(false)
    schedule_shadow_check('aftercast',0.5)
    maintain_selected_stance('aftercast')
    update_hud(false)
end

-------------------------------------------------------------------------------------------------------------------
-- Gear resolution / state changes
-------------------------------------------------------------------------------------------------------------------

function customize_melee_set(meleeSet)
    local t=perf_begin(); perf_count('melee_resolutions')
    local out=meleeSet
    local overlay=update_dw_overlay()
    if next(overlay) then out=set_combine(out,overlay) end
    if state.HybridMode.value=='DT' then out=set_combine(out,sets.engaged.DTOverlay) end
    if (state.Auto_Kite and state.Auto_Kite.value) or (state.Kiting and state.Kiting.value) then out=set_combine(out,sets.Kiting) end
    if th_should_apply(th_sync_target()) and sets.TreasureHunter then out=set_combine(out,sets.TreasureHunter) end
    if state.Buff.Sange then out=set_combine(out,sets.buff.SangeSafe) end
    protected_ring_check()
    perf_finish('melee',t)
    return out
end
function customize_idle_set(idleSet)
    local out=idleSet
    if (state.Auto_Kite and state.Auto_Kite.value) or (state.Kiting and state.Kiting.value) then out=set_combine(out,sets.Kiting) end
    if state.Buff.Sange then out=set_combine(out,sets.buff.SangeSafe) end
    protected_ring_check()
    return out
end

function job_buff_change(buff,gain)
    local b=buff:lower()
    if b=='haste' or b=='march' or b=='embrava' or b=='mighty guard' then
        invalidate_haste_cache(); update_native_haste_dw(false); job_update('buff change','user')
    elseif b=='sange' then
        state.Buff.Sange=gain
        if gain then equip(sets.buff.SangeSafe); add_to_chat(123,'[NIN SAFETY] Sange active: ammo forced empty to protect Date Shuriken.')
        else job_update('Sange ended','user') end
    elseif b=='yonin' then state.Buff.Yonin=gain
    elseif b=='innin' then state.Buff.Innin=gain
    elseif b=='migawari' then state.Buff.Migawari=gain
    elseif b=='futae' then state.Buff.Futae=gain
    elseif b=='doom' then
        state.Buff.Doom=gain
        set_doom_policy(gain)
    elseif b=='silence' then
        silence_echo.generation=silence_echo.generation+1
        if gain then
            silence_echo.active=true; silence_echo.attempts=0
            local generation=silence_echo.generation
            try_echo_drops(generation)
        else
            silence_echo.active=false; silence_echo.attempts=0
        end
    end

    if b:find('copy image',1,true) then schedule_shadow_check('shadow buff change',0.3) end
    if b=='yonin' or b=='innin' then
        stance_runtime.pending=false
        if not gain then maintain_selected_stance('stance expired') end
    end

    if gain and BOOST_BUFFS[b] then
        local slots={}
        if BOOST_GEAR[current_ring_name('ring1')] then slots[#slots+1]='ring1' end
        if BOOST_GEAR[current_ring_name('ring2')] then slots[#slots+1]='ring2' end
        release_protected_ring_slots(slots,buff..' active')
    end
    update_hud(true)
end

local function resume_swaps(message)
    enable(unpack(ALL_EQUIP_SLOTS))
    if state and state.FishingMode and state.FishingMode.value then
        if sets and sets.Fishing then equip(sets.Fishing) end
        disable(unpack(ALL_EQUIP_SLOTS))
        if message then add_to_chat(158,'[NIN] Fishing Mode still owns the gear freeze.') end
        return
    end
    invalidate_ring_lock_cache()
    reapply_runtime_locks()
    if not (buffactive and buffactive.doom) and type(handle_equipping_gear)=='function' and player then handle_equipping_gear(player.status) end
    local deferred={}
    if releasing.ring1 then deferred[#deferred+1]='ring1' end
    if releasing.ring2 then deferred[#deferred+1]='ring2' end
    if #deferred>0 then settle_released_ring_slots(deferred) end
    if message then add_to_chat(158,message) end
end

function job_state_change(descriptor,new_value,old_value)
    if descriptor=='PauseSwaps' or descriptor=='Pause Gear Swapping' then
        if state.PauseSwaps.value then
            disable(unpack(ALL_EQUIP_SLOTS))
            add_to_chat(167,'[NIN] GearSwap PAUSED: all automatic equipment swaps frozen.')
        elseif state.FishingMode and state.FishingMode.value then
            disable(unpack(ALL_EQUIP_SLOTS))
            add_to_chat(158,'[NIN] Pause off; Fishing Mode still owns the gear freeze.')
        else
            resume_swaps('[NIN] GearSwap RESUMED: automatic equipment swaps restored.')
        end
    end
    if descriptor=='FishingMode' or descriptor=='Fishing Mode' then
        if state.FishingMode.value then
            enable(unpack(ALL_EQUIP_SLOTS)); equip(sets.Fishing); disable(unpack(ALL_EQUIP_SLOTS))
            add_to_chat(167,'[NIN] FISHING MODE: rod/apparel equipped; all GearSwap slots frozen.')
        elseif state.PauseSwaps and state.PauseSwaps.value then
            disable(unpack(ALL_EQUIP_SLOTS)); add_to_chat(158,'[NIN] Fishing off; Pause still owns the gear freeze.')
        else
            resume_swaps('[NIN] Fishing Mode OFF: normal gear policy restored.')
        end
    end
    if descriptor=='Treasure Hunter' or descriptor=='TreasureMode' then
        reset_th_tracker(false)
        add_to_chat(158,'[NIN TH] Mode: '..tostring(state.TreasureMode.value))
        if not midaction() and type(handle_equipping_gear)=='function' and player then handle_equipping_gear(player.status) end
    end
    if descriptor=='Shadow Mode' or descriptor=='ShadowMode' then
        shadow_runtime.pending=nil
        add_to_chat(158,'[NIN Shadows] Mode: '..tostring(state.ShadowMode.value)..' (Off=manual only; Safe=auto at 0; Tank=auto at 0-1).')
        schedule_shadow_check('mode change',0.2)
    end
    if descriptor=='Desired Stance' or descriptor=='Stance' then
        stance_runtime.pending=false
        add_to_chat(158,'[NIN Stance] Desired: '..tostring(state.Stance.value)..'.')
        maintain_selected_stance('mode change')
    end
    if descriptor=='Element' or descriptor=='ElementMode' then add_to_chat(158,'[NIN Element] Selected: '..tostring(state.ElementMode.value)..'. Win+K casts highest ready tier.') end
    if descriptor=='Weapon Set' or descriptor=='WeaponSet' or descriptor=='Weapon Lock' or descriptor=='WeaponLock' then check_weaponset(true) end
    if descriptor=='Haste Tier' or descriptor=='HasteTier' then invalidate_haste_cache(); update_native_haste_dw(true) end
    if descriptor=='Auto Burst Detect' or descriptor=='AutoBurst' then
        if not state.AutoBurst.value then clear_burst_window() end
    end
    update_hud(true)
end

function job_status_change(newStatus,oldStatus,eventArgs)
    update_native_haste_dw(true)
    th_sync_target()
    if tool_manager.enabled and not midaction() and next(tool_manager.deferred_open) then process_deferred_toolbags() end
    protected_ring_check()
    if newStatus=='Engaged' then schedule_shadow_check('engage',0.5); maintain_selected_stance('engage') end
    update_hud(true)
end

function job_handle_equipping_gear(playerStatus,eventArgs)
    protected_ring_check()
    if state and state.Auto_Kite and state.DefenseMode and state.DefenseMode.value~='None' and state.Auto_Kite.value then
        state.Auto_Kite:set(false)
    elseif state and state.Auto_Kite and state.DefenseMode and state.DefenseMode.value=='None' and state.Auto_Kite.value~=moving then
        state.Auto_Kite:set(moving)
    end
end

function job_update(cmdParams,eventArgs)
    update_native_haste_dw(false)
    th_sync_target()
    if tool_manager.enabled and not midaction() and next(tool_manager.deferred_open) then process_deferred_toolbags() end
    protected_ring_check()
    check_weaponset(false)
    schedule_shadow_check('update',0.4)
    maintain_selected_stance('update')
    update_hud(false)
end

function check_weaponset(force)
    if not sets or not sets.weapons or not state or not state.WeaponSet then return end
    if state.PauseSwaps and state.PauseSwaps.value then return end
    if state.FishingMode and state.FishingMode.value then return end
    local desired=sets.weapons[state.WeaponSet.value]
    if not desired then return end
    local eq=player and player.equipment or {}
    local mismatch=(eq.main~=desired.main or eq.sub~=desired.sub)
    if not force and not mismatch then perf_count('weapon_reassert_hits'); return end
    enable('main','sub')
    if mismatch then equip(desired); perf_count('weapon_reassert_changes') end
    if state.WeaponLock.value then disable('main','sub') end
end

-------------------------------------------------------------------------------------------------------------------
-- NIN HUD 2.2 compact-wide layout with explicit Fast Cast visibility. Fixed at the RDM anchor (675,950); Win+H show/hide.
-- Presentation-only: no inventory/resource scans occur in update_hud(). Tool counts are cached by the tool manager.
-------------------------------------------------------------------------------------------------------------------

nin_hud=nil
local nin_hud_visible=true
local hud_cache={}

local function shadow_status()
    if buffactive['Copy Image (4+)'] then return '4+' end
    if buffactive['Copy Image (3)'] then return '3' end
    if buffactive['Copy Image (2)'] then return '2' end
    if buffactive['Copy Image'] then return '1' end
    return '0'
end

local function skillchain_hud_status()
    if not skillchain_ctl.active then return '-' end
    local chain=NIN_SKILLCHAINS[skillchain_ctl.active]
    local step=chain and chain.steps[skillchain_ctl.index]
    if not chain or not step then return '-' end
    return string.format('%s %d/%d -> %s',chain.label,skillchain_ctl.index,#chain.steps,step.ws)
end

local function wheel_hud_status()
    local step=elemental_wheel_step()
    if not step then return '-' end
    if elemental_wheel.active then
        local status=elemental_wheel.waiting and (' ['..elemental_wheel.waiting..']') or ''
        return string.format('AUTO %d/6 -> %s%s',elemental_wheel.cast_count+1,step.spell,status)
    end
    return 'READY -> '..step.spell..' -> lowers '..step.lowers
end

local function tool_count_label(key)
    local n=tool_manager and tool_manager.hud_counts and tool_manager.hud_counts[key]
    return n==nil and '?' or tostring(n)
end

local function tool_low_warning()
    if not tool_manager or not tool_manager.hud_counts then return false end
    for _,key in ipairs(TOOL_CATEGORY_ORDER) do
        local n=tool_manager.hud_counts[key]
        local p=NIN_TOOL_POLICY[key]
        if n~=nil and p and n<=p.low then return true end
    end
    return false
end

local function burst_hud_status()
    if state and state.MagicBurst and state.MagicBurst.value then return 'MANUAL FORCE' end
    if not state or not state.AutoBurst or not state.AutoBurst.value then return 'AUTO OFF' end
    if sc_window.name and sc_window.expires>os.clock() then return sc_window.name..' ACTIVE ('..(SC_BURST_LABEL[sc_window.name] or '?')..')' end
    return 'AUTO READY'
end

function init_hud()
    local ok,texts=pcall(require,'texts')
    if not ok then add_to_chat(123,'[NIN HUD] texts library unavailable.'); return end
    nin_hud=texts.new('',{pos={x=675,y=950},padding=5,bg={alpha=170},text={font='Consolas',size=9,alpha=255},flags={draggable=false}})
    if nin_hud_visible then nin_hud:show() end
end

local function toggle_hud()
    if not nin_hud then return end
    nin_hud_visible=not nin_hud_visible
    if nin_hud_visible then update_hud(true); nin_hud:show() else nin_hud:hide() end
end

function update_hud(force)
    if not nin_hud or (not nin_hud_visible and not force) then return end
    perf_count('hud_calls')
    local vals={
        weapon=state.WeaponSet and state.WeaponSet.value or '?',offense=state.OffenseMode and state.OffenseMode.value or '?',
        hybrid=state.HybridMode and state.HybridMode.value or '?',casting=state.CastingMode and state.CastingMode.value or '?',
        defense=state.DefenseMode and state.DefenseMode.value or 'None',lock=state.WeaponLock and state.WeaponLock.value or false,paused=state.PauseSwaps and state.PauseSwaps.value or false,
        fishing=state.FishingMode and state.FishingMode.value or false,th=state.TreasureMode and state.TreasureMode.value or 'Off',shadowmode=state.ShadowMode and state.ShadowMode.value or 'Off',
        stance=state.Stance and state.Stance.value or 'None',toolbagmode=tool_manager and tool_manager.toolbag_mode or 'Off',element=state.ElementMode and state.ElementMode.value or 'Fire',
        autokite=state.Auto_Kite and state.Auto_Kite.value or false,haste=native_state_haste,need=native_state_gear_need,have=dw_have(),fc=current_fc_gear(),
        shadows=shadow_status(),sc=skillchain_hud_status(),wheel=wheel_hud_status(),burst=burst_hud_status(),
        yonin=state.Buff.Yonin,innin=state.Buff.Innin,futae=state.Buff.Futae,migawari=state.Buff.Migawari,sange=state.Buff.Sange,
        doom=state.Buff.Doom or (buffactive and buffactive.doom),silence=buffactive and buffactive.silence or false,
        t2=tool_count_label('elemental'),t3=tool_count_label('enfeebling'),t4=tool_count_label('enhancing'),t5=tool_count_label('shihei'),
    }
    local warnings={}
    if vals.paused then warnings[#warnings+1]='!! PAUSED !!' end
    if vals.fishing then warnings[#warnings+1]='FISHING' end
    if vals.doom then warnings[#warnings+1]='!! DOOM !!' end
    if vals.silence then warnings[#warnings+1]='SILENCED' end
    if tool_manager and not tool_manager.enabled then warnings[#warnings+1]='TOOLS AUTO OFF'
    elseif tool_low_warning() then warnings[#warnings+1]='TOOLS LOW' end
    if tonumber(vals.t5) and tonumber(vals.t5)>0 then warnings[#warnings+1]='SHIHEI NOT PARKED' end
    local short=dw_shortfall()
    if short>0 then warnings[#warnings+1]='DW SHORT '..short end
    local warn=(#warnings>0) and table.concat(warnings,' | ') or 'OK'
    local key=table.concat({vals.weapon,vals.offense,vals.hybrid,vals.casting,vals.defense,tostring(vals.lock),tostring(vals.paused),tostring(vals.fishing),vals.th,vals.shadowmode,vals.stance,vals.element,tostring(vals.autokite),
        vals.haste,vals.need,vals.have,vals.fc,vals.shadows,vals.sc,vals.wheel,vals.burst,vals.t2,vals.t3,vals.t4,vals.t5,vals.toolbagmode,warn,
        tostring(vals.yonin),tostring(vals.innin),tostring(vals.futae),tostring(vals.migawari),tostring(vals.sange)},'|')
    if not force and hud_cache.key==key then return end
    hud_cache.key=key
    -- Compact-wide HUD: same fixed anchor, shared Shikanofuda shown once for Utsusemi/Enhancing.
    local text=string.format(
        'NIN v%s | Weapon %s [%s] | STATUS %s\nOffense %s | Hybrid %s | Casting %s | Defense %s | Kiting %s | TH %s | Stance %s | Toolbags %s\nHaste %d/819 | DW %d/%d | Fast Cast Gear %d/80 | Shadows %s/%s | Element %s | Burst %s\nSC %s | Wheel %s\nTools Ino %s | Shika %s | Cho %s | Shihei Reserve %s | Yonin %s | Innin %s | Futae %s | Migawari %s | Sange %s',
        NIN_RELEASE_VERSION,vals.weapon,vals.lock and 'LOCK' or 'FREE',warn,
        vals.offense,vals.hybrid,vals.casting,vals.defense,vals.autokite and 'MOVE' or '-',vals.th,vals.stance,vals.toolbagmode,
        vals.haste or 0,vals.have or 0,vals.need or 0,vals.fc or 0,vals.shadows,vals.shadowmode,vals.element,vals.burst,
        vals.sc,vals.wheel,vals.t2,vals.t4,vals.t3,vals.t5,
        vals.yonin and 'ON' or 'OFF',vals.innin and 'ON' or 'OFF',vals.futae and 'ON' or 'OFF',vals.migawari and 'ON' or 'OFF',vals.sange and 'ON' or 'OFF')
    nin_hud:text(text)
    if nin_hud_visible then nin_hud:show() end
    perf_count('hud_renders')
end

-------------------------------------------------------------------------------------------------------------------
-- Diagnostics / commands
-------------------------------------------------------------------------------------------------------------------

local function report_keybinds()
    add_to_chat(158,'=== NIN v'..NIN_RELEASE_VERSION..' Keybind Map ===')
    add_to_chat(158,'[Modes] F9 Offense | Ctrl+F9 Hybrid | Win+F9 WS Mode | Ctrl+F11 Casting | Ctrl+F12 Idle | F12 Update')
    add_to_chat(158,'[Defense] F10 PDT/Evasion | F11 MDT | Alt+F12 cancel defense')
    add_to_chat(158,'[Safety/QoL] Win+P Pause | Win+H HUD | Win+G AutoBurst | Win+F Fishing | Win+T TH Off/Tag/Fulltime')
    add_to_chat(158,'[NIN Utility] Win+S Shadows Off/Safe/Tank | Win+Y Stance None/Yonin/Innin | Win+J element | Win+K highest-ready nuke')
    add_to_chat(158,'[Weapons] Win+R next weapon | Win+E previous weapon | Win+W weapon lock')
    add_to_chat(158,'[Magic] Alt+M force Magic Burst | Win+N Auto Elemental Wheel START/STOP (one 6-cast San pass)')
    add_to_chat(158,'[Skillchains] Win+F5 2-Light | Win+F6 2-Dark | Win+F7 4-Light | Win+F8 4-Dark')
    add_to_chat(158,'[Auto] Doom gear lock | Echo Drops x3 on Silence | protected Warp/Dim/EXP/CP rings | Shneddick while moving via GearInfo')
    add_to_chat(158,'[Wheel] AUTO: Hyoton -> Katon -> Suiton -> Raiton -> Doton -> Huton | Win+N start/stop | wheelstart <element> seeds')
    add_to_chat(158,'[Info] keybinds | scinfo | wheelinfo | shadowinfo | thinfo | stanceinfo | elementinfo | inventorycheck | dwinfo | fcinfo | tools | toolpriority | burstinfo | ringinfo')
end

local function report_baseline()
    local g=NIN_PROFILE.gifts
    add_to_chat(158,string.format('[NIN] Lv99 | JP %d/%d | Master=%s | ML=%d | Native DW=%d%%',NIN_PROFILE.jp_spent,NIN_PROFILE.jp_cap,tostring(NIN_PROFILE.mastered),NIN_PROFILE.master_level,NIN_PROFILE.native_dual_wield))
    add_to_chat(158,string.format('[NIN Gifts @1800] NinjutsuSkill+%d | Daken+%d%% | Duration+%d%% | WSD+%d%% | MAcc+%d | MAB+%d',g.ninjutsu_skill,g.daken_effect,g.ninjutsu_duration,g.weaponskill_damage,g.magic_accuracy,g.magic_attack))
end
local function report_dw()
    add_to_chat(158,string.format('[NIN DW] native=%d | haste=%d/819 (%.1f%%) | gear need=%d | modeled have=%d | shortfall=%d',NIN_PROFILE.native_dual_wield,native_state_haste,native_state_haste/1024*100,native_state_gear_need,dw_have(),dw_shortfall()))
    add_to_chat(158,'[NIN DW] exact pool: Eabani 4%, Suppanomimi 5%, Patentia Sash 5%, Hiza feet 8%, Naga legs 4%.')
end
local function policy_lookup_ci(tbl,query)
    local q=(query or ''):lower()
    for name,entry in pairs(tbl) do if name:lower()==q then return name,entry end end
end
local function report_policy_entry(kind,name,entry)
    if not entry then return false end
    add_to_chat(158,string.format('[NIN Policy:%s] %s',kind,name))
    for _,k in ipairs({'family','source_set','objective','tp_behavior','preferred_weapon','invariant','assumption'}) do if entry[k] then add_to_chat(158,'  '..k..'='..tostring(entry[k])) end end
    return true
end
local function report_nin_intelligence()
    add_to_chat(158,'[NIN Intelligence] Weapon/WS/action/spell policy metadata is diagnostic-only; hot routing uses exact maps.')
    add_to_chat(158,'[NIN Intelligence] WS: Ku Ten Shun Hi Jin Kamu Retsu Savage Evisceration Ei Yu Chi To Teki')
    add_to_chat(158,'Usage: gs c policy <exact WS, spell, weapon profile, or action label>')
end
local function report_nin_policy(query)
    local q=(query or ''):gsub('^%s+',''):gsub('%s+$','')
    if q=='' then report_nin_intelligence(); return end
    local n,e=policy_lookup_ci(NIN_WEAPONSKILL_POLICY,q); if e and report_policy_entry('WS',n,e) then return end
    n,e=policy_lookup_ci(NIN_WEAPON_POLICY,q); if e and report_policy_entry('Weapon',n,e) then return end
    n,e=policy_lookup_ci(NIN_SPELL_POLICY,q); if e and report_policy_entry('Spell',n,e) then return end
    n,e=policy_lookup_ci(NIN_ACTION_GEAR_POLICY,q); if e and report_policy_entry('Action',n,e) then return end
    add_to_chat(123,'[NIN Policy] No exact policy entry for "'..q..'".')
end

local function report_th()
    local id=th_sync_target()
    add_to_chat(158,string.format('[NIN TH] mode=%s | target=%s | tagged=%s',tostring(state.TreasureMode.value),tostring(id),tostring(th_tracker.tagged)))
end
local function report_shadows()
    add_to_chat(158,string.format('[NIN Shadows] mode=%s | current=%d | pending=%s',tostring(state.ShadowMode.value),shadow_count_numeric(),tostring(shadow_runtime.pending)))
    add_to_chat(158,'  Off=manual smart Ichi only | Safe=auto only at 0 | Tank=auto at 0-1; event-driven, no polling.')
end
local function report_stance()
    add_to_chat(158,string.format('[NIN Stance] desired=%s | Yonin=%s | Innin=%s',tostring(state.Stance.value),tostring(buffactive and buffactive.yonin or false),tostring(buffactive and buffactive.innin or false)))
end
local function report_element()
    local e=state.ElementMode.value
    add_to_chat(158,'[NIN Element] selected='..tostring(e)..' | priority='..table.concat(ELEMENT_NUKE_SPELLS[e] or {},' -> '))
end

function job_self_command(cmdParams,eventArgs)
    local cmd=(cmdParams[1] or ''):lower()
    if cmd=='gearinfo' then
        handle_gearinfo_command(cmdParams); eventArgs.handled=true; return
    end
    if cmd=='_startupkeys' then
        if cmdParams[2]==NIN_RUNTIME.token and not NIN_RUNTIME.unloading then report_keybinds() end
        eventArgs.handled=true
    elseif cmd=='_toolsweep' then
        if cmdParams[2]==NIN_RUNTIME.token and not NIN_RUNTIME.unloading and tool_manager.enabled then queue_tool_sweep() end
        eventArgs.handled=true
    elseif cmd=='version' then
        add_to_chat(158,'Falurian NIN GearSwap v'..NIN_RELEASE_VERSION..' ('..NIN_RELEASE_DATE..')'); eventArgs.handled=true
    elseif cmd=='keybinds' or cmd=='keys' then
        report_keybinds(); eventArgs.handled=true
    elseif cmd=='hud' then
        toggle_hud(); eventArgs.handled=true
    elseif cmd=='thinfo' then report_th(); eventArgs.handled=true
    elseif cmd=='threset' then reset_th_tracker(true); if type(handle_equipping_gear)=='function' and player then handle_equipping_gear(player.status) end; eventArgs.handled=true
    elseif cmd=='shadowinfo' then report_shadows(); eventArgs.handled=true
    elseif cmd=='stanceinfo' then report_stance(); eventArgs.handled=true
    elseif cmd=='elementinfo' then report_element(); eventArgs.handled=true
    elseif cmd=='element' then
        if not set_element_mode(cmdParams[2]) then add_to_chat(123,'[NIN Element] Use fire|water|lightning|earth|wind|ice.') end
        report_element(); eventArgs.handled=true
    elseif cmd=='nuke' or cmd=='elementnuke' then cast_selected_element(); eventArgs.handled=true
    elseif cmd=='inventorycheck' or cmd=='ready' or cmd=='readiness' then report_inventory_readiness(); eventArgs.handled=true
    elseif cmd=='burstinfo' then
        add_to_chat(158,'[NIN AutoBurst] mode='..tostring(state.AutoBurst and state.AutoBurst.value)..' | window='..burst_hud_status())
        eventArgs.handled=true
    elseif cmd=='ringinfo' then
        add_to_chat(158,'[NIN Rings] ring1='..tostring(current_ring_name('ring1'))..' protected='..tostring(NO_SWAP_GEAR[current_ring_name('ring1')]==true))
        add_to_chat(158,'[NIN Rings] ring2='..tostring(current_ring_name('ring2'))..' protected='..tostring(NO_SWAP_GEAR[current_ring_name('ring2')]==true))
        eventArgs.handled=true
    elseif cmd=='sc' or cmd=='skillchain' then
        local id=(cmdParams[2] or ''):lower():gsub('[^%w]','')
        skillchain_start_or_continue(id); eventArgs.handled=true
    elseif cmd=='screset' then
        skillchain_reset(false); eventArgs.handled=true
    elseif cmd=='scinfo' or cmd=='skillchains' then
        report_skillchains(); eventArgs.handled=true
    elseif cmd=='_wheelauto' then
        local token=cmdParams[2]
        local generation=tonumber(cmdParams[3])
        local serial=tonumber(cmdParams[4])
        if token==NIN_RUNTIME.token and not NIN_RUNTIME.unloading and elemental_wheel.active and
           generation==elemental_wheel.generation and serial==elemental_wheel.schedule_serial then
            elemental_wheel_try_cast()
        end
        eventArgs.handled=true
    elseif cmd=='wheel' or cmd=='elementalwheel' then
        if cmdParams[2] and cmdParams[2]~='' then
            if elemental_wheel_seed(cmdParams[2],false) then elemental_wheel_start()
            else add_to_chat(123,'[NIN AutoWheel] Unknown weakness. Use fire, water, lightning/thunder, earth, wind, or ice.') end
        else
            elemental_wheel_start()
        end
        eventArgs.handled=true
    elseif cmd=='wheelstart' then
        if not elemental_wheel_seed(cmdParams[2],false) then
            add_to_chat(123,'[NIN Wheel] Usage: gs c wheelstart <fire|water|lightning|earth|wind|ice>')
        end
        eventArgs.handled=true
    elseif cmd=='wheelreset' then
        elemental_wheel_reset(false); eventArgs.handled=true
    elseif cmd=='wheelinfo' then
        report_elemental_wheel(); eventArgs.handled=true
    elseif cmd=='baseline' or cmd=='jp' then report_baseline(); eventArgs.handled=true
    elseif cmd=='fcinfo' or cmd=='fastcast' then report_fc(); eventArgs.handled=true
    elseif cmd=='dwinfo' or cmd=='hastecheck' then update_native_haste_dw(true); report_dw(); eventArgs.handled=true
    elseif cmd=='hastetier' then
        local n=tonumber(cmdParams[2]); if n==1 or n==2 then state.HasteTier:set(n); invalidate_haste_cache(); update_native_haste_dw(true); job_update('hastetier','user') end
        add_to_chat(158,'[NIN] Haste icon assumption: Haste '..tostring(state.HasteTier.value)); eventArgs.handled=true
    elseif cmd=='hasteadj' then
        local pct=tonumber(cmdParams[2]) or 0; haste_manual_magic=math.floor(pct/100*1024+0.5); update_native_haste_dw(true); job_update('hasteadj','user')
        add_to_chat(158,string.format('[NIN] Manual magic haste adjustment: %.1f%%',haste_manual_magic/1024*100)); eventArgs.handled=true
    elseif cmd=='perf' then
        local sub=(cmdParams[2] or ''):lower()
        if sub=='on' then perf.enabled=true; perf_reset(); add_to_chat(158,'[NIN Perf] ON')
        elseif sub=='off' then perf_report(); perf.enabled=false; add_to_chat(158,'[NIN Perf] OFF')
        elseif sub=='reset' then perf_reset() else perf_report() end
        eventArgs.handled=true
    elseif cmd=='itemizerpolicy' or cmd=='toolowner' then report_itemizer_policy(); eventArgs.handled=true
    elseif cmd=='ninjatoolpolicy' or cmd=='toolpriority' then report_ninja_tool_priority(); eventArgs.handled=true
    elseif cmd=='tools' then report_tools(); eventArgs.handled=true
    elseif cmd=='toolcheck' then if tool_manager.enabled then queue_tool_sweep() else add_to_chat(158,'[NIN Tools] proactive refill OFF') end; eventArgs.handled=true
    elseif cmd=='toolauto' then
        local v=(cmdParams[2] or ''):lower(); if v=='on' then tool_manager.enabled=true elseif v=='off' then tool_manager.enabled=false end
        add_to_chat(158,'[NIN Tools] proactive refill='..(tool_manager.enabled and 'ON' or 'OFF')); if tool_manager.enabled then queue_tool_sweep() end; eventArgs.handled=true
    elseif cmd=='toolbagmode' then
        local v=(cmdParams[2] or ''):lower()
        if v=='safe' then
            tool_manager.toolbag_mode='Safe'
        elseif v=='always' or v=='on' then
            tool_manager.toolbag_mode='Always'
        elseif v=='off' then
            tool_manager.toolbag_mode='Off'
        end
        add_to_chat(158,'[NIN Tools] toolbag mode='..tool_manager.toolbag_mode..
            ' | Always opens at threshold while engaged; Safe defers until disengaged.')
        if tool_manager.enabled and tool_manager.toolbag_mode~='Off' then queue_tool_sweep() end
        update_hud(true)
        eventArgs.handled=true
    elseif cmd=='toolopen' then force_toolbag_open((cmdParams[2] or ''):lower()); eventArgs.handled=true
    elseif cmd=='_toolcastretry' then
        local token=cmdParams[2]; local gen=tonumber(cmdParams[3])
        if token==NIN_RUNTIME.token and not NIN_RUNTIME.unloading and tool_cast_retry.pending and tool_cast_retry.pending.generation==gen then
            local p=tool_cast_retry.pending; tool_cast_retry.pending=nil
            windower.chat.input('/ma "'..p.spell..'" '..p.target)
        end
        eventArgs.handled=true
    elseif cmd=='_parkshihei' then
        if cmdParams[2]==NIN_RUNTIME.token and not NIN_RUNTIME.unloading then
            park_shihei_once(false)
            tool_check_category('utsusemi',false)
            update_hud(false)
        end
        eventArgs.handled=true
    elseif cmd=='_tooldeferred' then
        local key=(cmdParams[2] or ''):lower()
        local token=cmdParams[3]
        local serial=tonumber(cmdParams[4])
        if token==NIN_RUNTIME.token and not NIN_RUNTIME.unloading and
           tool_manager.deferred_open[key] and serial==(tool_manager.retry_serial[key] or 0) then
            if tool_is_pending(key) then
                queue_tool_deferred_retry(key,0.85)
            else
                tool_check_category(key,false)
            end
            update_hud(false)
        end
        eventArgs.handled=true
    elseif cmd=='_tooldeferredsweep' then
        if cmdParams[2]==NIN_RUNTIME.token and not NIN_RUNTIME.unloading and
           tool_manager.enabled and not midaction() then
            process_deferred_toolbags()
            update_hud(false)
        end
        eventArgs.handled=true
    elseif cmd=='_toolstep' then
        local key=(cmdParams[2] or ''):lower(); if cmdParams[3]~=NIN_RUNTIME.token or NIN_RUNTIME.unloading then eventArgs.handled=true; return end; tool_manager.pending[key]=nil; tool_check_category(key,false); update_hud(false); eventArgs.handled=true
    elseif cmd=='_toolopenstep' then
        local key=(cmdParams[2] or ''):lower(); if cmdParams[3]~=NIN_RUNTIME.token or NIN_RUNTIME.unloading then eventArgs.handled=true; return end; tool_manager.pending[key]=nil; local p=NIN_TOOL_POLICY[key]
        if p and tool_inventory_count(p.toolbag_id)>0 then tool_manager.open_attempts[key]=0; open_toolbag_from_inventory(key,true) end
        eventArgs.handled=true
    elseif cmd=='intelligence' or cmd=='gearintel' then report_nin_intelligence(); eventArgs.handled=true
    elseif cmd=='policy' or cmd=='gearpolicy' then report_nin_policy(table.concat(cmdParams,' ',2)); eventArgs.handled=true
    end
end
