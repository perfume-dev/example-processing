// Copyright (c) 2026 Daito Manabe
// SPDX-License-Identifier: MIT; see ../LICENSE-new-examples
import com.rhizomatiks.bvh.BvhBone;
import com.rhizomatiks.bvh.BvhParser;
import java.util.List;
import java.util.ArrayList;

final List<MotionData> dancers = new ArrayList<>();
final String[] jointNames = { "Head", "RightWrist", "LeftWrist", "RightAnkle", "LeftAnkle", "Hips" };
final float[] sources = new float[18 * 3];
PShader fieldShader;
SketchRun run;
boolean showHelp = true;
boolean showJoints = false;
float contourDensity = 1;

void settings() {
  size(1280, 800, P2D);
  pixelDensity(1);
  noSmooth();
}

void setup() {
  surface.setTitle("Perfume / motion field");
  surface.setResizable(true);
  frameRate(60);
  run = new SketchRun();
  showHelp = !run.automated;
  fieldShader = run.checkedShader("field.frag", null);
  for (String filename : new String[] { "A_test.bvh", "B_test.bvh", "C_test.bvh" }) {
    dancers.add(new MotionData(filename));
  }
  textFont(createFont("SansSerif", 13));
}

void draw() {
  float time = run.seconds();
  for (int dancer = 0; dancer < dancers.size(); dancer++) {
    MotionData motion = dancers.get(dancer);
    motion.update(time);
    for (int joint = 0; joint < jointNames.length; joint++) {
      PVector p = motion.position(motion.joint(jointNames[joint]).absPos);
      int index = (dancer * jointNames.length + joint) * 3;
      sources[index] = (dancer - 1) * 0.48 + p.x / 640.0;
      sources[index + 1] = -p.y / 540.0;
      sources[index + 2] = dancer;
    }
  }
  fieldShader.set("resolution", float(width), float(height));
  fieldShader.set("time", time);
  fieldShader.set("density", contourDensity);
  fieldShader.set("sources", sources, 3);
  shader(fieldShader);
  noStroke();
  fill(255);
  rect(0, 0, width, height);
  resetShader();
  if (showJoints) {
    fill(245, 246, 235);
    float fieldScale = min(height, width / 1.6);
    for (int i = 0; i < sources.length; i += 3) {
      circle(width / 2.0 + sources[i] * fieldScale, height / 2.0 - sources[i + 1] * fieldScale, 4);
    }
  }
  if (showHelp) {
    fill(228, 237, 239);
    text("PERFUME  /  MOTION FIELD", 38, 43);
    fill(126, 145, 160);
    text("02   /   eighteen BVH joints > uniforms > fragment shader", 38, 66);
    text("SPACE pause     +/- contours     J joints     R reset     H labels     S screenshot", 38, height - 32);
  }
  run.finishFrame("motion_field", dancers.size());
}

void keyPressed() {
  if (key == ' ') run.togglePause();
  if (key == 'r' || key == 'R') { run.reset(); contourDensity = 1; }
  if (key == 'j' || key == 'J') showJoints = !showJoints;
  if (key == 'h' || key == 'H') showHelp = !showHelp;
  if (key == '+' || key == '=') contourDensity = min(2.5, contourDensity + 0.1);
  if (key == '-') contourDensity = max(0.3, contourDensity - 0.1);
  if (key == 's' || key == 'S') saveFrame("captures/field-####.png");
}
