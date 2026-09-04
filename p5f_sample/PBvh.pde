class PBvh {
  final BvhParser parser;

  PBvh(String[] data) {
    if (data == null) {
      throw new IllegalArgumentException("BVH data could not be loaded");
    }

    parser = new BvhParser();
    parser.parse(data);
  }

  void update(int ms) {
    parser.moveMsTo(ms);
    parser.update();
  }

  void draw() {
    fill(255);

    for (BvhBone bone : parser.getBones()) {
      pushMatrix();
      translate(bone.absPos.x, bone.absPos.y, bone.absPos.z);
      ellipse(0, 0, 2, 2);
      popMatrix();

      if (!bone.hasChildren()) {
        pushMatrix();
        translate(bone.absEndPos.x, bone.absEndPos.y, bone.absEndPos.z);
        ellipse(0, 0, 10, 10);
        popMatrix();
      }
    }
  }
}
