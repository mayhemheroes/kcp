#!/usr/bin/env bash
#
# mayhem/test.sh — RUN kcp's OWN upstream test suite (pre-built by mayhem/build.sh
# via `cargo test --no-run`) and report CTRF counts.
#
# The suite is upstream's full `cargo test`: the integration tests in tests/kcp.rs
# (send/recv round-trips through a simulated lossy network, mode/window behavior)
# plus any unit/doc tests. These assert real protocol behavior (echoed payload
# contents, RTT bounds), so a neutered/exit(0) binary cannot pass them.
set -uo pipefail
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH
: "${MAYHEM_JOBS:=$(nproc)}"
cd "$SRC"

# emit_ctrf <tool> <passed> <failed> [skipped] [pending] [other]
emit_ctrf() {
  local tool="$1" passed="$2" failed="$3" skipped="${4:-0}" pending="${5:-0}" other="${6:-0}"
  local tests=$(( passed + failed + skipped + pending + other ))
  cat > "${CTRF_REPORT:-$SRC/ctrf-report.json}" <<JSON
{
  "results": {
    "tool": { "name": "$tool" },
    "summary": {
      "tests": $tests,
      "passed": $passed,
      "failed": $failed,
      "pending": $pending,
      "skipped": $skipped,
      "other": $other
    }
  }
}
JSON
  printf 'CTRF {"results":{"tool":{"name":"%s"},"summary":{"tests":%d,"passed":%d,"failed":%d,"pending":%d,"skipped":%d,"other":%d}}}\n' \
    "$tool" "$tests" "$passed" "$failed" "$pending" "$skipped" "$other"
  [ "$failed" -eq 0 ]
}

LOG=/tmp/kcp-cargo-test.log
export CARGO_BUILD_JOBS="$MAYHEM_JOBS"
# Everything is already compiled by build.sh; this only runs the test binaries.
cargo test 2>&1 | tee "$LOG"
rc=${PIPESTATUS[0]}

# Sum every per-suite summary line: "test result: ok. N passed; M failed; K ignored; ..."
read -r PASSED FAILED IGNORED SUITES < <(awk '
  /^test result: / {
    for (i = 1; i <= NF; i++) {
      if ($(i+1) ~ /^passed/)  p += $i
      if ($(i+1) ~ /^failed/)  f += $i
      if ($(i+1) ~ /^ignored/) s += $i
    }
    n += 1
  }
  END { printf "%d %d %d %d\n", p, f, s, n }' "$LOG")

# Strict behavioral gate: the upstream suite has 6 integration tests in tests/kcp.rs.
# If cargo produced no summaries or ran fewer tests than upstream ships, something
# swallowed the suite (e.g. a neutered runner) — that is a FAILURE, not a pass.
if [ "$SUITES" -lt 1 ] || [ "$PASSED" -lt 6 ] || [ "$rc" -ne 0 ]; then
  echo "ERROR: cargo test did not run the full upstream suite (rc=$rc suites=$SUITES passed=$PASSED failed=$FAILED)" >&2
  [ "$FAILED" -ge 1 ] || FAILED=1
fi

emit_ctrf "cargo-test" "$PASSED" "$FAILED" "$IGNORED"
