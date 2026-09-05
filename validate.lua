-- validate.lua -- job-file validator.  Loads a job lua in the offline harness and
-- checks it against ItemStats.lua.  Usage: lua5.1 validate.lua WAR.lua WAR [RDM.lua RDM ...]
local H=dofile('harness.lua')
-- Ownership counts for items owned in quantity > 1 (see fal-owned.lua). A set using the
-- same item in both rings/ears is only a problem when the player owns a single copy.
local OWNED = dofile('fal-owned.lua')

local SLOTS={'main','sub','range','ammo','head','neck','ear1','ear2',
             'body','hands','ring1','ring2','back','waist','legs','feet'}
local EAR_PAIR={ear1='ear2',ear2='ear1'} ; local RING_PAIR={ring1='ring2',ring2='ring1'}

local function nameof(v)
    if type(v)=='table' then return v.name end
    if type(v)=='string' then return v end
    return nil
end

local function walk(t, path, seen, visit)
    if type(t)~='table' or seen[t] then return end
    seen[t]=true
    -- a table is "a set" if it has any equipment slot key
    local is_set=false
    for _,s in ipairs(SLOTS) do if t[s]~=nil then is_set=true break end end
    if is_set then visit(t,path) end
    for k,v in pairs(t) do
        if type(v)=='table' and type(k)=='string' then
            walk(v, path..'.'..k, seen, visit)
        end
    end
end

local function validate(file, job)
    -- P1 fix: the job identity must reach the mock player. This previously loaded RDM
    -- and BLU with main_job='WAR', so any job-conditional branch ran under the wrong
    -- identity and could build a different set of gear sets than the game would.
    local env,err=H.load(file, {job=job})
    if not env then return {fatal='load failed: '..tostring(err)} end
    local stats=env.item_stats
    if not stats then return {fatal='ItemStats.lua did not load into the environment'} end

    local R={missing={},joblocked={},dupe_ear={},dupe_ring={},sets=0,items={}}
    local seen={}
    walk(env.sets,'sets',seen,function(set,path)
        R.sets=R.sets+1
        for _,slot in ipairs(SLOTS) do
            local n=nameof(set[slot])
            if n and n~='empty' then
                R.items[n]=true
                local e=stats[n]
                if not e then
                    R.missing[n]=R.missing[n] or path
                elseif e.jobs and e.jobs~='ALL' then
                    local ok=false
                    for j in tostring(e.jobs):gmatch('[^/]+') do if j==job then ok=true end end
                    if not ok then R.joblocked[n]=(R.joblocked[n] or path)..' ['..tostring(e.jobs)..']' end
                end
            end
        end
        -- same item in both ears / both rings needs two owned copies
        for a,b in pairs(EAR_PAIR) do
            local x,y=nameof(set[a]),nameof(set[b])
            if x and y and x==y and (OWNED[x] or 1) < 2 then R.dupe_ear[x]=path end
        end
        for a,b in pairs(RING_PAIR) do
            local x,y=nameof(set[a]),nameof(set[b])
            if x and y and x==y and (OWNED[x] or 1) < 2 then R.dupe_ring[x]=path end
        end
    end)
    return R
end

local function count(t) local n=0 for _ in pairs(t) do n=n+1 end return n end

local argv={...}
local overall=0
for i=1,#argv,2 do
    local file,job=argv[i],argv[i+1]
    io.write(string.format('\n=== %s  (job=%s) ===\n',file,job))
    local R=validate(file,job)
    if R.fatal then io.write('  FATAL: '..R.fatal..'\n') ; overall=overall+1
    else
        io.write(string.format('  %d gear sets resolved, %d distinct items referenced\n',R.sets,count(R.items)))
        local function report(label,tbl,fatal)
            local n=count(tbl)
            if n==0 then io.write(string.format('  OK    %-32s none\n',label))
            else
                io.write(string.format('  %-5s %-32s %d\n',fatal and 'FAIL' or 'WARN',label,n))
                local keys={} for k in pairs(tbl) do keys[#keys+1]=k end table.sort(keys)
                for _,k in ipairs(keys) do io.write('          '..k..'   <- '..tostring(tbl[k])..'\n') end
                if fatal then overall=overall+1 end
            end
        end
        report('items missing from ItemStats',R.missing,true)
        report('items not equippable by job',  R.joblocked,true)
        report('duplicate earring, only 1 owned', R.dupe_ear,true)
        report('duplicate ring, only 1 owned',    R.dupe_ring,true)
    end
end
io.write(overall==0 and '\nALL FILES PASS\n' or string.format('\n%d FILE(S) WITH FATAL FINDINGS\n',overall))
os.exit(overall==0 and 0 or 1)
