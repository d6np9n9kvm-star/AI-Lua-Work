#!/bin/sh
# run-tests.sh -- the whole gate. Exits non-zero if anything fails.
#
# NOTE: this does NOT pipe test output into `tail`. A pipeline's exit status is the LAST
# command's, so `lua5.1 test.lua | tail -3` reports success even when the test exits 1 --
# which made an earlier version of this script pass against a deliberately broken Core.
# Each suite is run bare, its status captured, and the summary line grepped from a file.

fail=0
run() {                     # run <label> <command...>
    label=$1 ; shift
    out=$(mktemp)
    if "$@" > "$out" 2>&1; then
        printf '  PASS  %-22s %s\n' "$label" "$(grep -E '[0-9]+ passed|ALL FILES PASS' "$out" | tail -1)"
    else
        fail=1
        printf '  FAIL  %-22s\n' "$label"
        sed 's/^/        /' "$out" | tail -25
    fi
    rm -f "$out"
}

echo "=== syntax ==="
for f in fal-core.lua fal-owned.lua WAR.lua RDM.lua BLU.lua ItemStats.lua; do
    if luac5.1 -p "$f" 2>/dev/null; then printf '  PASS  %s\n' "$f"
    else fail=1 ; printf '  FAIL  %s\n' "$f" ; luac5.1 -p "$f" ; fi
done

echo
echo "=== suites ==="
run "fal-core contract" lua5.1 test_core.lua
run "movement"          lua5.1 test_moving.lua
run "job regression"    lua5.1 test_jobs.lua
run "gear validation"   lua5.1 validate.lua WAR.lua WAR RDM.lua RDM BLU.lua BLU

echo
if [ "$fail" -eq 0 ]; then echo "ALL SUITES PASSED"; exit 0
else echo "SUITE FAILURES -- see above"; exit 1; fi
