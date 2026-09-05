-------------------------------------------------------------------------------------------------------------------
-- falcheck.lua -- minimal assertion runner for the Falurian GearSwap test suite.
--
-- WHY THIS EXISTS: the v1.0.x tests printed "PASS"/"FAIL" lines and then exited 0
-- regardless.  That is fine while a human reads the output and useless as a regression
-- gate -- a test could print a wrong answer and still be reported as green.  Every
-- invariant now goes through check.eq / check.ok / check.err, and check.finish() calls
-- os.exit(1) when anything failed, so CI (or `&&` in a shell) actually stops.
-------------------------------------------------------------------------------------------------------------------

local C = {passed = 0, failed = 0, failures = {}, group = ''}

local function record(ok, label, detail)
    if ok then
        C.passed = C.passed + 1
        io.write(string.format('  ok    %s\n', label))
    else
        C.failed = C.failed + 1
        C.failures[#C.failures + 1] = (C.group ~= '' and (C.group..' / ') or '')..label..
            (detail and ('  -- '..detail) or '')
        io.write(string.format('  FAIL  %s%s\n', label, detail and ('  -- '..detail) or ''))
    end
    return ok
end

function C.section(name)
    C.group = name
    io.write('\n'..name..'\n')
end

function C.ok(value, label)
    return record(value and true or false, label,
        (not value) and ('expected truthy, got '..tostring(value)) or nil)
end

function C.eq(actual, expected, label)
    return record(actual == expected, label,
        (actual ~= expected) and ('expected '..tostring(expected)..', got '..tostring(actual)) or nil)
end

function C.ne(actual, unexpected, label)
    return record(actual ~= unexpected, label,
        (actual == unexpected) and ('expected anything but '..tostring(unexpected)) or nil)
end

function C.nilv(actual, label)
    return record(actual == nil, label,
        (actual ~= nil) and ('expected nil, got '..tostring(actual)) or nil)
end

-- Assert that fn() raises, and (optionally) that the message contains `pattern`.
function C.err(fn, pattern, label)
    local ok, e = pcall(fn)
    if ok then return record(false, label, 'expected an error, none raised') end
    if pattern and not tostring(e):find(pattern, 1, true) then
        return record(false, label, 'error did not contain "'..pattern..'": '..tostring(e))
    end
    return record(true, label)
end

-- Assert that fn() does NOT raise.
function C.noerr(fn, label)
    local ok, e = pcall(fn)
    return record(ok, label, (not ok) and tostring(e) or nil)
end

function C.finish(suite)
    io.write(string.format('\n%s: %d passed, %d failed\n',
        suite or 'suite', C.passed, C.failed))
    if C.failed > 0 then
        io.write('\nFAILURES:\n')
        for _, f in ipairs(C.failures) do io.write('  * '..f..'\n') end
        os.exit(1)
    end
    os.exit(0)
end

return C
