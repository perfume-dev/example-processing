// The original parser is unchanged. Retained shapes are updated in place.
class PBvh {
  final BvhParser parser = new BvhParser();
  final PShape bones;
  final PShape joints;

  PBvh(String[] data, int ink) {
    if (data == null) throw new IllegalArgumentException("BVH data could not be loaded");
    parser.parse(data);
    bones = createShape();
    bones.beginShape(LINES);
    bones.noFill();
    bones.stroke(ink, 150);
    bones.strokeWeight(1.3);
    joints = createShape();
    joints.beginShape(POINTS);
    joints.stroke(ink);
    joints.strokeWeight(5);
    for (BvhBone bone : parser.getBones()) {
      joints.vertex(0, 0, 0);
      if (bone.getParent() != null) { bones.vertex(0, 0, 0); bones.vertex(0, 0, 0); }
      if (!bone.hasChildren()) {
        joints.vertex(0, 0, 0);
        bones.vertex(0, 0, 0);
        bones.vertex(0, 0, 0);
      }
    }
    bones.endShape();
    joints.endShape();
  }

  void update(float seconds) {
    parser.moveMsTo(round(seconds * 1000));
    parser.update();
    PVector root = parser.getBones().get(0).absPos;
    int jointIndex = 0;
    int boneIndex = 0;
    for (BvhBone bone : parser.getBones()) {
      PVector position = stagePosition(bone.absPos, root);
      joints.setVertex(jointIndex++, position);
      if (bone.getParent() != null) {
        bones.setVertex(boneIndex++, stagePosition(bone.getParent().absPos, root));
        bones.setVertex(boneIndex++, position);
      }
      if (!bone.hasChildren()) {
        PVector end = stagePosition(bone.absEndPos, root);
        joints.setVertex(jointIndex++, end);
        bones.setVertex(boneIndex++, position);
        bones.setVertex(boneIndex++, end);
      }
    }
  }

  PVector stagePosition(PVector point, PVector root) {
    return new PVector(-(point.x - root.x) * 1.55, (85 - point.y) * 1.55,
      -(point.z - root.z) * 1.55);
  }
}
