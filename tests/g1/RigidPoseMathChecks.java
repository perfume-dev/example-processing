// Copyright (c) 2026 Daito Manabe
// SPDX-License-Identifier: MIT; see LICENSE
// Inserted into a Java harness beside the unmodified RigidPoseMath.pde by the Python test.
static void near(float actual, float expected) {
  if (Math.abs(actual - expected) > 0.000002) throw new AssertionError(actual + " != " + expected);
}

static float[] identity(int bodies) {
  float[] result = new float[bodies * 4];
  for (int i = 0; i < bodies; i++) result[i * 4] = 1;
  return result;
}

public static void main(String[] args) {
  int[] parents = {-1, 0, 1};
  float[] offsets = {123, 456, 789, 1, 0, 0, 1, 0, 0}; // Root offset is intentionally unused.
  float[] aWorld = identity(3), bWorld = identity(3);
  float sin45 = (float)Math.sqrt(0.5);
  // Root turns +90 around Z. Child counter-rotates -90 locally, so its world q stays identity.
  bWorld[0] = sin45; bWorld[3] = sin45;
  float[] aLocal = new float[12], bLocal = new float[12];
  RigidPoseMath.localRotations(aWorld, parents, aLocal);
  RigidPoseMath.localRotations(bWorld, parents, bLocal);
  near(bLocal[4], sin45); near(bLocal[7], -sin45);
  float[] aPosition = {0, 0, 0, 1, 0, 0, 2, 0, 0};
  float[] bPosition = {2, 0, 0, 2, 1, 0, 3, 1, 0};
  float[] p = new float[9], q = new float[12];
  for (float t : new float[]{0, 0.1f, 0.25f, 0.5f, 0.9f, 1}) {
    RigidPoseMath.interpolate(aPosition, bPosition, aLocal, bLocal, parents, offsets, t, p, q);
    near(p[0], 2*t); near(p[1], 0);
    near(p[3], 2*t + (float)Math.cos(t * Math.PI / 2));
    near(p[4], (float)Math.sin(t * Math.PI / 2));
    // Parent-relative interpolation preserves a rigid unit anchor at every subframe.
    near((float)Math.hypot(p[3] - p[0], p[4] - p[1]), 1);
    near(p[6], p[3] + 1); near(p[7], p[4]);
    near(q[4], 1); near(q[7], 0);
  }
  // q and -q describe exactly the same pose; never spin through the long arc.
  for (int i = 0; i < bLocal.length; i++) bLocal[i] = -aLocal[i];
  RigidPoseMath.interpolate(aPosition, aPosition, aLocal, bLocal, parents, offsets, 0.5f, p, q);
  for (int i = 0; i < p.length; i++) near(p[i], aPosition[i]);
  for (int i = 0; i < q.length; i++) near(q[i], aWorld[i]);
  System.out.println("RIGID_POSE_MATH_OK endpoint=true subframe=true hierarchy=true shortestArc=true");
}
