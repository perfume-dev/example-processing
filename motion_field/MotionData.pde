// Copyright (c) 2026 Daito Manabe
// SPDX-License-Identifier: MIT; see ../LICENSE-new-examples
class MotionData {
  final BvhParser parser = new BvhParser();

  MotionData(String filename) {
    // Prefer local data when exporting; share the original files in a checkout.
    java.io.File local = new java.io.File(dataPath(filename));
    java.io.File shared = new java.io.File(sketchPath("../p5f_sample/data/" + filename));
    java.io.File source = local.isFile() ? local : shared;
    if (!source.isFile()) throw new IllegalStateException(
      "Missing " + filename + ". Keep the full repository together, or copy the BVH files into this sketch's data folder.");
    parser.parse(loadStrings(source));
  }

  void update(float seconds) {
    parser.moveMsTo(round(seconds * 1000));
    parser.update();
  }

  BvhBone joint(String name) {
    for (BvhBone bone : parser.getBones()) if (bone.getName().equals(name)) return bone;
    throw new IllegalArgumentException("Required BVH joint not found: " + name);
  }

  PVector position(PVector point) {
    PVector root = parser.getBones().get(0).absPos;
    return new PVector(-(point.x - root.x) * 1.55, (85 - point.y) * 1.55,
      -(point.z - root.z) * 1.55);
  }
}
