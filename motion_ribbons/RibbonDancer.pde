// Copyright (c) 2026 Daito Manabe
// SPDX-License-Identifier: MIT; see ../LICENSE-new-examples
class RibbonDancer {
  final MotionData motion;
  final int steps = 76;
  final float historySeconds = 3.2;
  final String[] jointNames = { "RightWrist", "LeftWrist", "RightAnkle", "LeftAnkle", "Head" };
  final List<PShape> ribbons = new ArrayList<>();
  final PVector[][] history = new PVector[jointNames.length][steps];
  final BvhBone[] joints = new BvhBone[jointNames.length];
  final PVector[][] poses;

  RibbonDancer(String filename) {
    motion = new MotionData(filename);
    poses = new PVector[jointNames.length][motion.parser.getNbFrames()];
    for (int j = 0; j < jointNames.length; j++) {
      joints[j] = motion.joint(jointNames[j]);
      PShape strip = createShape();
      strip.beginShape(TRIANGLE_STRIP);
      strip.noStroke();
      for (int k = 0; k < steps; k++) {
        history[j][k] = new PVector();
        // Vertex colors transport age, edge coordinate and strand number.
        strip.fill(255.0 * k / (steps - 1), 0, 255.0 * j / jointNames.length);
        strip.vertex(0, 0, 0);
        strip.fill(255.0 * k / (steps - 1), 255, 255.0 * j / jointNames.length);
        strip.vertex(0, 0, 0);
      }
      strip.endShape();
      ribbons.add(strip);
    }
    // Cache only these five joints once. Drawing never reparses old poses.
    for (int frame = 0; frame < motion.parser.getNbFrames(); frame++) {
      motion.parser.moveFrameTo(frame);
      motion.parser.update();
      for (int j = 0; j < joints.length; j++) poses[j][frame] = motion.position(joints[j].absPos);
    }
  }

  void update(float seconds, PVector viewDirection) {
    // Resample a fixed time window: trails are identical at any frame rate.
    // Interpolate the cached positions; shapes and arrays stay allocated.
    float duration = motion.parser.getNbFrames() * motion.parser.getFrameTime();
    float loopStart = floor(seconds / duration) * duration;
    for (int k = 0; k < steps; k++) {
      float sampleTime = max(loopStart, seconds - historySeconds * (1 - float(k) / (steps - 1)));
      float frame = (sampleTime - loopStart) / motion.parser.getFrameTime();
      int a = min(floor(frame), poses[0].length - 1);
      int b = min(a + 1, poses[0].length - 1);
      for (int j = 0; j < joints.length; j++) {
        history[j][k].set(poses[j][a]);
        history[j][k].lerp(poses[j][b], frame - a);
      }
    }
    for (int j = 0; j < joints.length; j++) {
      PShape strip = ribbons.get(j);
      for (int k = 0; k < steps; k++) {
        PVector tangent = PVector.sub(history[j][min(k + 1, steps - 1)], history[j][max(k - 1, 0)]);
        PVector side = tangent.cross(viewDirection);
        if (side.magSq() < 0.001) side.set(1, 0, 0);
        side.normalize();
        float life = float(k) / (steps - 1);
        float halfWidth = (j == 4 ? 2.7 : 6.5) * sin(PI * life) + 0.12;
        side.mult(halfWidth);
        PVector point = history[j][k];
        strip.setVertex(k * 2, point.x - side.x, point.y - side.y, point.z - side.z);
        strip.setVertex(k * 2 + 1, point.x + side.x, point.y + side.y, point.z + side.z);
      }
    }
    motion.update(seconds);
  }
}
