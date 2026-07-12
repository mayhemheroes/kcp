#!/usr/bin/env bash
#
# mayhem/build.sh — build the kcp cargo-fuzz target (sanitized libFuzzer binary)
# and pre-build the project's own test suite (normal flags) for mayhem/test.sh.
#
# Runs inside the commit image (RUST mayhem/Dockerfile) as `mayhem` in /mayhem.
# The Rust toolchain + cargo registry live at $CARGO_HOME=/opt/toolchains/rust/cargo.
#
# AIR-GAPPED CONTRACT (SPEC §6.5): the PATCH tier re-runs THIS script OFFLINE.
# This first (online) build populates the cargo registry under $CARGO_HOME; the
# offline re-run resolves crates from that cache (runtime sets CARGO_NET_OFFLINE=true).
set -euo pipefail

# clang rejects SOURCE_DATE_EPOCH='' — must be unset or a valid integer.
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

: "${MAYHEM_JOBS:=$(nproc)}"
# cargo-fuzz has no --jobs flag; cargo reads parallelism from CARGO_BUILD_JOBS.
export CARGO_BUILD_JOBS="$MAYHEM_JOBS"

cd "$SRC"

# 1) Pre-build the project's OWN test suite with the project's NORMAL flags
#    (no sanitizer RUSTFLAGS) so mayhem/test.sh only RUNS it.
echo "=== cargo test --no-run (normal flags; pre-build the upstream suite) ==="
cargo test --no-run

# 2) Sanitized libFuzzer fuzz targets (OSS-Fuzz Rust path: cargo-fuzz + ASan via
#    RUSTFLAGS — the clang-oriented $SANITIZER_FLAGS from the base ENV are not
#    rustc flags, so the sanitizer is threaded through RUSTFLAGS instead).
#    $RUST_DEBUG_FLAGS keeps triage-readable DWARF (< 4, §6.2 item 10).
: "${RUST_DEBUG_FLAGS:=-Cdebuginfo=1 -Zdwarf-version=3}"
export RUSTFLAGS="${RUSTFLAGS:-} --cfg fuzzing -Zsanitizer=address ${RUST_DEBUG_FLAGS} -Cforce-frame-pointers"
# libfuzzer-sys compiles the C++ libFuzzer runtime via the cc crate; clang-19's
# plain -g emits DWARF-5, so pin those objects to DWARF-3 too.
export CFLAGS="${CFLAGS:-} -gdwarf-3" CXXFLAGS="${CXXFLAGS:-} -gdwarf-3"

# rustc's precompiled ASan runtime archive ships DWARF-5 CUs and would land first
# in .debug_info; link a DWARF-3 anchor CU at offset 0 via a linker wrapper so the
# leading CU is triage-readable (the sanctioned Rust-asan recipe — DWARF gate §6.2).
printf 'int mayhem_dwarf3_anchor(void){return 0;}\n' > /tmp/dwarf3-anchor.c
clang -c -g -gdwarf-3 -o /tmp/dwarf3-anchor.o /tmp/dwarf3-anchor.c
cat > /tmp/cc-anchor-wrap.sh <<'EOF'
#!/bin/bash
exec clang /tmp/dwarf3-anchor.o "$@"
EOF
chmod +x /tmp/cc-anchor-wrap.sh
export RUSTFLAGS="$RUSTFLAGS -Clinker=/tmp/cc-anchor-wrap.sh"

FUZZ_DIR="mayhem/fuzz"
TRIPLE="x86_64-unknown-linux-gnu"

FUZZ_TARGETS=()
for f in "$FUZZ_DIR"/fuzz_targets/*.rs; do
  FUZZ_TARGETS+=("$(basename "${f%.*}")")
done
[ "${#FUZZ_TARGETS[@]}" -gt 0 ] || { echo "ERROR: no fuzz targets under $FUZZ_DIR/fuzz_targets/" >&2; exit 1; }

echo "=== cargo fuzz build (image nightly, ASan via RUSTFLAGS) ==="
echo "RUSTFLAGS=$RUSTFLAGS"
echo "targets: ${FUZZ_TARGETS[*]}"

for t in "${FUZZ_TARGETS[@]}"; do
  echo "--- building fuzz target: $t ---"
  cargo fuzz build --fuzz-dir "$FUZZ_DIR" -O --debug-assertions "$t"
  bin="$SRC/$FUZZ_DIR/target/$TRIPLE/release/$t"
  [ -x "$bin" ] || { echo "ERROR: expected fuzz binary not found at $bin" >&2; exit 1; }
  cp "$bin" "/mayhem/$t"
  echo "built /mayhem/$t"
done

echo "build.sh complete"
