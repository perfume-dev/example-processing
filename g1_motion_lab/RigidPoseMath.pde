// Copyright (c) 2026 Daito Manabe
// SPDX-License-Identifier: MIT; see LICENSE
// Pure Java so the exact viewer interpolation can also be regression-tested without OpenGL.
static class RigidPoseMath {
  static void product(float[] a, int ai, float[] b, int bi, float[] out, int oi, boolean inverseA) {
    float aw = a[ai], ax = a[ai + 1], ay = a[ai + 2], az = a[ai + 3];
    if (inverseA) { ax = -ax; ay = -ay; az = -az; }
    float bw = b[bi], bx = b[bi + 1], by = b[bi + 2], bz = b[bi + 3];
    out[oi] = aw*bw - ax*bx - ay*by - az*bz;
    out[oi + 1] = aw*bx + ax*bw + ay*bz - az*by;
    out[oi + 2] = aw*by - ax*bz + ay*bw + az*bx;
    out[oi + 3] = aw*bz + ax*by - ay*bx + az*bw;
    normalize(out, oi);
  }

  static void normalize(float[] q, int i) {
    double norm = Math.sqrt(q[i]*q[i] + q[i + 1]*q[i + 1] + q[i + 2]*q[i + 2] + q[i + 3]*q[i + 3]);
    if (!Double.isFinite(norm) || norm < 0.00001) throw new IllegalArgumentException("Invalid quaternion");
    for (int k = 0; k < 4; k++) q[i + k] /= norm;
  }

  static void slerp(float[] a, float[] b, int i, float t, float[] out) {
    double dot = 0;
    for (int k = 0; k < 4; k++) dot += a[i + k] * b[i + k];
    double sign = dot < 0 ? -1 : 1;
    dot = Math.min(1, Math.abs(dot));
    double wa = 1 - t, wb = t;
    if (dot < 0.9995) {
      double angle = Math.acos(dot), denominator = Math.sin(angle);
      wa = Math.sin((1 - t) * angle) / denominator;
      wb = Math.sin(t * angle) / denominator;
    }
    for (int k = 0; k < 4; k++) out[i + k] = (float)(wa * a[i + k] + wb * sign * b[i + k]);
    normalize(out, i);
  }

  static void childPosition(float[] positions, int parent, float[] rotations, float[] offsets, int body) {
    int p = parent * 3, q = parent * 4, c = body * 3;
    float w = rotations[q], x = rotations[q + 1], y = rotations[q + 2], z = rotations[q + 3];
    float vx = offsets[c], vy = offsets[c + 1], vz = offsets[c + 2];
    float tx = 2 * (y*vz - z*vy), ty = 2 * (z*vx - x*vz), tz = 2 * (x*vy - y*vx);
    positions[c] = positions[p] + vx + w*tx + y*tz - z*ty;
    positions[c + 1] = positions[p + 1] + vy + w*ty + z*tx - x*tz;
    positions[c + 2] = positions[p + 2] + vz + w*tz + x*ty - y*tx;
  }

  static void localRotations(float[] world, int[] parents, float[] local) {
    System.arraycopy(world, 0, local, 0, 4);
    for (int body = 1; body < parents.length; body++) {
      product(world, parents[body] * 4, world, body * 4, local, body * 4, true);
    }
  }

  static void interpolate(float[] aPosition, float[] bPosition, float[] aLocal, float[] bLocal,
                          int[] parents, float[] offsets, float t, float[] positions, float[] rotations) {
    for (int axis = 0; axis < 3; axis++) positions[axis] = aPosition[axis] + (bPosition[axis] - aPosition[axis]) * t;
    slerp(aLocal, bLocal, 0, t, rotations); // Root local orientation is its world orientation.
    for (int body = 1; body < parents.length; body++) {
      int parent = parents[body];
      childPosition(positions, parent, rotations, offsets, body);
      slerp(aLocal, bLocal, body * 4, t, rotations);
      product(rotations, parent * 4, rotations, body * 4, rotations, body * 4, false);
    }
  }
}
