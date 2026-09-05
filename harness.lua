-- Offline GearSwap/Mote test harness.  Loads a job file with a mocked Windower
-- environment so sets and routing can be resolved without the game running.
local H = {}

local function deepcopy(t)
    if type(t)~='table' then return t end
    local r={} ; for k,v in pairs(t) do r[k]=deepcopy(v) end ; return r
end
H.deepcopy = deepcopy

function H.build_env(opts)
    opts = opts or {}
    local env = {}
    env._G = env
    for _,k in ipairs{'pairs','ipairs','type','tostring','tonumber','table','string','math',
                      'os','select','next','error','pcall','xpcall','unpack','setmetatable',
                      'getmetatable','rawget','rawset','assert','print','coroutine','loadfile','dofile'} do
        env[k]=_G[k]
    end

    env.empty = {}
    env.chat_log = {}
    env.add_to_chat = function(c,t) env.chat_log[#env.chat_log+1]=tostring(t) end
    env.send_command = function(c) env.last_command=c end
    env.windower = {
        add_to_chat=env.add_to_chat,
        register_event=function() return 1 end,
        unregister_event=function() end,
        raw_register_event=function() return 1 end,
        raw_unregister_event=function() end,
        send_command=function() end,
        text={ new=function() return setmetatable({},{__index=function() return function() end end}) end },
        prim={ new=function() return setmetatable({},{__index=function() return function() end end}) end },
        packets={ parse_action=function() return {} end, parse_incoming=function() return {} end },
        ffxi = {
            get_player=function() return env.player end,
            get_mob_by_target=function() return opts.target end,
            get_abilities=function() return {job_traits={}} end,
            get_ability_recasts=function() return setmetatable({},{__index=function() return 0 end}) end,
            get_spell_recasts=function() return setmetatable({},{__index=function() return 0 end}) end,
            get_items=function() return {} end,
            get_info=function() return {day=0,weather=0} end,
        },
        chat={input=function(s) env.last_input=s end},
        get_windower_settings=function() return {ui_x_res=1920,ui_y_res=1080} end,
        dir_exists=function() return true end,
        file_exists=function() return false end,
    }
    -- Mote/GearSwap globals
    -- Mote-Include normally creates these skeletons before init_gear_sets runs.
    env.sets = {
        precast  = {JA={},WS={},FC={}},
        midcast  = {RA={}},
        aftercast= {},
        buff     = {},
        engaged  = {},
        idle     = {},
        defense  = {},
        weapons  = {},
        resting  = {},
    }
    -- The job identity MUST be settable: validate.lua used to load RDM and BLU with
    -- main_job='WAR', so any job-conditional branch ran under the wrong identity.
    env.player  = opts.player or {name='Falurian',
                                  main_job=opts.job or 'WAR',
                                  sub_job=opts.sub_job or 'NIN',
                                  tp=1000,status='Engaged',
                                  equipment={},hpp=100,index=1,
                                  main_job_level=99,sub_job_level=49}
    env.player.equipment = opts.equipment or env.player.equipment or {}
    env.buffactive = setmetatable(opts.buffactive or {}, {__index=function() return false end})
    env.world = {day='Firesday',weather='None',time=0,area='Test'}
    env.equip_log = {}
    env.equip = function(t) env.equip_log[#env.equip_log+1]=deepcopy(t) end
    env.cancel_spell = function() env.cancelled=true end
    env.disable=function() end ; env.enable=function() end
    -- Faithful stand-in for GearSwap's include_user(str, tbl): lowercases the name,
    -- and for the table form does setmetatable(tbl,{__index=user_env._G}) + setfenv +
    -- pcall (error DISCARDED, exactly like the real thing).
    env.include = function(f, tbl)
        local name = tostring(f):lower()
        if name=='itemstats.lua' then
            local fn=assert(loadfile('ItemStats.lua')) ; setfenv(fn,env) ; fn() ; return
        end
        if name=='fal-core.lua' then
            tbl = tbl or {}
            setmetatable(tbl, {__index = env})
            local fn=assert(loadfile('fal-core.lua'))
            setfenv(fn, tbl)
            local ok,err = pcall(fn, tbl)
            env.__include_error = (not ok) and err or nil
            return tbl
        end
        -- Mote-Include and friends are mocked, not loaded.
    end
    env.set_combine = function(...)
        local out={}
        for i=1,select('#',...) do
            local t=select(i,...)
            if type(t)=='table' then for k,v in pairs(t) do out[k]=v end end
        end
        return out
    end
    env.coroutine = setmetatable({schedule=function(f,d) env.scheduled=env.scheduled or {}
        env.scheduled[#env.scheduled+1]={fn=f,delay=d} end}, {__index=coroutine})
    -- A chainable no-op object: every field is a function returning itself, so HUD code
    -- like texts.new(...):show():append('x') works without a real Windower.
    local function noop_obj()
        local o = {}
        return setmetatable(o, {__index=function() return function(...) return o end end})
    end
    env.require = function(name)
        if name=='resources' then
            return {spells=H.mock_list(), job_abilities=H.mock_list(),
                    weapon_skills=H.mock_list(), items=H.mock_list(), job_traits=H.mock_list()}
        end
        if name=='texts' or name=='images' or name=='primitives' then
            return {new=function() return noop_obj() end}
        end
        if name=='config' then
            return {load=function(_,d) return d or {} end, save=function() end}
        end
        return setmetatable({}, {__index=function() return function() end end})
    end
    env.gearswap = {res={}}
    env.T=function(t) return t end
    -- Windower's S{} sets are iterable and carry methods. The old mock returned `false`
    -- for every unknown key, so `myset:it()` evaluated to false and job code calling it
    -- died with "attempt to call method 'it' (a boolean value)".
    env.S=function(t)
        local items={} ; for _,v in ipairs(t or {}) do items[v]=true end
        local set={}
        local methods={
            it       = function(self) return pairs(items) end,
            contains = function(self,v) return items[v]==true end,
            add      = function(self,v) items[v]=true ; return self end,
            remove   = function(self,v) items[v]=nil ; return self end,
            length   = function(self) local n=0 for _ in pairs(items) do n=n+1 end return n end,
            clear    = function(self) for k in pairs(items) do items[k]=nil end return self end,
            empty    = function(self) return next(items)==nil end,
            copy     = function(self) local c={} for k in pairs(items) do c[#c+1]=k end return env.S(c) end,
        }
        return setmetatable(set,{
            __index=function(_,k)
                if methods[k] then return methods[k] end
                return items[k]==true
            end,
            __call=function(_,v) return items[v]==true end,
            __len =function() return methods.length() end,
        })
    end
    -- Windower's L{} lists carry methods too. classes.CustomMeleeGroups is one, and
    -- Mote job files call :clear() / :append() on it during setup.
    env.L=function(t)
        local items={} ; for i,v in ipairs(t or {}) do items[i]=v end
        local methods={
            clear   = function(self) for i=#items,1,-1 do items[i]=nil end return self end,
            append  = function(self,v) items[#items+1]=v ; return self end,
            add     = function(self,v) items[#items+1]=v ; return self end,
            it      = function(self) return ipairs(items) end,
            length  = function(self) return #items end,
            contains= function(self,v) for _,x in ipairs(items) do if x==v then return true end end return false end,
            empty   = function(self) return #items==0 end,
        }
        return setmetatable(items,{__index=function(_,k) return methods[k] end,
                                   __len=function() return #items end})
    end

    -- Mote state Mode objects
    local function M(spec)
        local o={}
        if type(spec)=='table' and spec[1]~=nil then
            o._opts={} ; for i,v in ipairs(spec) do o._opts[i]=v end
            o.value=spec[1] ; o.current=spec[1]
        elseif type(spec)=='table' then
            o.value=spec.value ; o.current=spec.value ; o._opts={}
        else
            o.value=spec ; o.current=spec ; o._opts={}
        end
        o.set=function(self,v) self.value=v ; self.current=v end
        o.reset=function(self) if self._opts[1]~=nil then self.value=self._opts[1] ; self.current=self._opts[1] end end
        o.options=function(self,...) local a={...}
            if type(a[1])=='table' then a=a[1] end
            self._opts=a ; if self.value==nil then self.value=a[1] ; self.current=a[1] end
            return self end
        o.cycle=function(self) end ; o.toggle=function(self) self.value=not self.value ; self.current=self.value end
        o.describe=function(self) return tostring(self.value) end
        o.unset=function(self) self.value=false ; self.current=false end
        return o
    end
    env.M = function(spec,...) return M(spec) end
    -- Mote auto-creates state modes on first touch, so the harness must too -- but in
    -- strict mode it records every auto-created name. A typo like state.TreasureHuntr
    -- would otherwise look perfectly valid in a test.
    env.autocreated_states = {}
    env.state = setmetatable({}, {__index=function(t,k)
        env.autocreated_states[#env.autocreated_states+1]=k
        local v=M('Normal') ; rawset(t,k,v) ; return v end})
    env.state.Buff = setmetatable({},{__index=function() return false end})
    env.state.WeaponLock = M(false)
    env.state.PauseSwaps = M(false)
    env.state.FishingMode = M(false)
    env.state.Auto_Kite = M(false)
    env.moving=false
    env.info={}
    env.classes={ CustomMeleeGroups=env.L{}, CustomIdleGroups=env.L{},
                  NoSkillSpells=env.S{}, SkipSkillCheck=false, CustomClass=nil }
    env.options={}
    env.get_current_job_state=function() end
    -- Globals GearSwap/Mote provide that job files call during setup.
    env.set_macro_page=function() end
    env.set_lockstyle=function() end
    env.send_cmd=function() end
    env.midaction=function() return false end
    env.pet_midaction=function() return false end
    env.handle_equipping_gear=function() end
    env.status_change=function() end
    env.gearswap_disabled=false
    env.lockstyleset=nil
    env.mote_include_version=2
    env.setfenv=setfenv ; env.getfenv=getfenv
    return env
end

-- A stand-in for a Windower resources table. Indexing an unknown key must yield
-- another mock list (resources are nested), never `false`, or job code doing
-- res.spells[id]:it() blows up in a way the real game never would.
function H.mock_list()
    local t={}
    t.with=function() return nil end
    t.it=function() return function() return nil end end
    t.count=function() return 0 end
    return setmetatable(t,{__index=function(self,k)
                              if type(k)=='string' then return nil end
                              return nil end,
                           __call=function() return nil end})
end

-- Load a job file into a mocked env, running Mote's real hook order.
-- EVERY stage failure is fatal and named. The previous version pcall'd get_sets,
-- job_setup and user_setup and DISCARDED their errors, so a job whose initialization
-- genuinely failed could still be reported as loaded and validated as passing.
function H.load(jobfile, opts)
    local env=H.build_env(opts)
    local fn,err=loadfile(jobfile)
    if not fn then return nil,'loadfile: '..tostring(err) end
    setfenv(fn,env)
    local ok,e=pcall(fn)
    if not ok then return nil,'chunk: '..tostring(e) end
    -- Mote's order: get_sets -> job_setup -> user_setup -> init_gear_sets.
    -- FalCore.init() lives in user_setup, so it must run before gear sets are built.
    for _,stage in ipairs{'get_sets','job_setup','user_setup','init_gear_sets'} do
        if type(env[stage])=='function' then
            local sok,serr=pcall(env[stage])
            if not sok then return nil,stage..': '..tostring(serr) end
        end
    end
    if env.__include_error then
        return nil,'include(fal-core.lua) faulted: '..tostring(env.__include_error)
    end
    return env
end

return H
