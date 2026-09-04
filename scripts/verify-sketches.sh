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
  first_frame=
  for seconds in 8 16; do
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
  done
done
cmp "$repo_root/motion_ribbons/MotionData.pde" "$repo_root/motion_field/MotionData.pde"

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
echo "All three sketches rendered at two timestamps; shader failure checks passed."
