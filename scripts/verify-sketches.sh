#!/usr/bin/env bash
# Copyright (c) 2026 Daito Manabe
# SPDX-License-Identifier: MIT; see ../LICENSE-new-examples
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 /path/to/Processing /path/to/test-output" >&2
  exit 2
fi
processing_bin=$1
mkdir -p "$2"
test_output=$(cd "$2" && pwd)
repo_root=$(cd "$(dirname "$0")/.." && pwd)
python3 -B -m unittest discover -s "$repo_root/tests/g1" -p 'test_*.py'
test -s "$repo_root/g1_motion_lab/data/MODEL-LICENSE"

run_processing() {
  # A fresh process group bounds the launcher and its child JVM on Linux/macOS.
  perl -MPOSIX -e '
    my $limit = shift @ARGV;
    my $child = fork();
    defined $child or die "Cannot fork: $!";
    if (!$child) { POSIX::setsid(); exec @ARGV; die "Cannot launch: $!"; }
    my $status;
    eval {
      local $SIG{ALRM} = sub { die "Processing timed out\n"; };
      alarm $limit;
      waitpid($child, 0);
      $status = $?;
      alarm 0;
    };
    if ($@) {
      warn $@;
      kill "TERM", -$child;
      sleep 1;
      kill "KILL", -$child;
      waitpid($child, 0);
      exit 124;
    }
    exit(($status & 127) ? 128 + ($status & 127) : ($status >> 8));
  ' 60 "$processing_bin" "$@"
}

for sketch in p5f_sample motion_ribbons motion_field; do
  cmp "$repo_root/p5f_sample/code/BVHParser.jar" "$repo_root/$sketch/code/BVHParser.jar"
  cmp "$repo_root/p5f_sample/SketchRun.pde" "$repo_root/$sketch/SketchRun.pde"
done
cmp "$repo_root/motion_ribbons/MotionData.pde" "$repo_root/motion_field/MotionData.pde"

# G1 uses exported JSON and its own runner; it needs neither the parser JAR nor SketchRun.pde.
g1_first_frame=
for sketch in p5f_sample motion_ribbons motion_field g1_motion_lab; do
  first_frame=
  timestamps=(8 16)
  if [[ "$sketch" == g1_motion_lab ]]; then timestamps+=(14.3 14.3125); fi
  for seconds in "${timestamps[@]}"; do
    # Each run compiles before rendering. New output directories avoid --force.
    run_dir=$(mktemp -d "$test_output/$sketch-$seconds.XXXXXX")
    run_processing cli --sketch="$repo_root/$sketch" --output="$run_dir/build" \
      --run --smoke-test --time="$seconds" --capture="$run_dir/frame.png" 2>&1 | tee "$run_dir/runtime.log"
    grep -q "SMOKE_TEST_OK sketch=$sketch" "$run_dir/runtime.log"
    test -s "$run_dir/frame.png"
    if [[ -n "$first_frame" ]] && cmp -s "$first_frame" "$run_dir/frame.png"; then
      echo "$sketch did not change between the two motion timestamps" >&2
      exit 1
    fi
    first_frame="$run_dir/frame.png"
    if [[ "$sketch" == g1_motion_lab && "$seconds" == 8 ]]; then
      g1_first_frame="$run_dir/frame.png"
    fi
  done
done

# This is a graphics check, not a pose/physics approval: diagnostic pose_status may render.
overlay_dir=$(mktemp -d "$test_output/g1-source-overlay.XXXXXX")
run_processing cli --sketch="$repo_root/g1_motion_lab" --output="$overlay_dir/build" \
  --run --smoke-test --time=8 --source-overlay --capture="$overlay_dir/frame.png" 2>&1 | tee "$overlay_dir/runtime.log"
grep -q 'SMOKE_TEST_OK sketch=g1_motion_lab' "$overlay_dir/runtime.log"
grep -q 'sourceOverlay=true' "$overlay_dir/runtime.log"
grep -q 'scope=rendering-only' "$overlay_dir/runtime.log"
test -s "$overlay_dir/frame.png"
if cmp -s "$g1_first_frame" "$overlay_dir/frame.png"; then
  echo "G1 source overlay did not change the rendered frame" >&2
  exit 1
fi

# Shader failure must never pass via Processing's fallback renderer.
for failure in invalid missing; do
  negative_dir=$(mktemp -d "$test_output/shader-$failure.XXXXXX")
  cp -R "$repo_root/motion_field" "$negative_dir/motion_field"
  if [[ "$failure" == invalid ]]; then
    cp "$repo_root/tests/shaders/invalid.frag" "$negative_dir/motion_field/data/field.frag"
  else
    mv "$negative_dir/motion_field/data/field.frag" "$negative_dir/field.frag.disabled"
  fi
  if run_processing cli --sketch="$negative_dir/motion_field" --output="$negative_dir/build" \
    --run --smoke-test > "$negative_dir/runtime.log" 2>&1; then
    # Processing's launcher may return zero even when the sketch exits nonzero.
    echo "Launcher returned zero; checking explicit shader failure evidence."
  fi
  cat "$negative_dir/runtime.log"
  grep -a -q 'SHADER_ERROR:' "$negative_dir/runtime.log"
  if grep -a -q 'Processing timed out' "$negative_dir/runtime.log"; then exit 1; fi
  if grep -q 'SMOKE_TEST_OK' "$negative_dir/runtime.log"; then
    echo "A $failure shader incorrectly passed the render test" >&2
    exit 1
  fi
done

# Generate failures only in disposable sketch copies. The installed exports stay untouched.
for failure in missing-motion missing-model schema quaternion index frame-size validation-label \
  model-schema fractional-schema fractional-parent fractional-body fractional-index overflow-index \
  missing-offsets offset-shape offset-nonfinite offset-mismatch non-topological-parent multiple-roots root-self-parent; do
  negative_dir=$(mktemp -d "$test_output/g1-data-$failure.XXXXXX")
  python3 "$repo_root/tests/g1/make_negative_fixture.py" "$repo_root/g1_motion_lab" \
    "$negative_dir/g1_motion_lab" "$failure"
  if run_processing cli --sketch="$negative_dir/g1_motion_lab" --output="$negative_dir/build" \
    --run --smoke-test --capture="$negative_dir/frame.png" > "$negative_dir/runtime.log" 2>&1; then
    echo "Launcher returned zero; checking explicit G1 data failure evidence."
  fi
  cat "$negative_dir/runtime.log"
  grep -a -q 'G1_DATA_ERROR:' "$negative_dir/runtime.log"
  if grep -a -q 'Processing timed out' "$negative_dir/runtime.log"; then exit 1; fi
  if grep -q 'SMOKE_TEST_OK' "$negative_dir/runtime.log" || [[ -e "$negative_dir/frame.png" ]]; then
    echo "Invalid G1 data ($failure) incorrectly passed or wrote a capture" >&2
    exit 1
  fi
done
echo "All four sketches rendered at two timestamps; G1 key/subframe timestamps, overlay, shader and G1 data failure checks passed (rendering only)."
