// Copyright (c) 2026 Daito Manabe
// SPDX-License-Identifier: MIT; see ../LICENSE-new-examples
import com.rhizomatiks.bvh.BvhBone;
import com.rhizomatiks.bvh.BvhParser;
import java.util.List;
import java.util.ArrayList;

final List<RibbonDancer> dancers = new ArrayList<>();
PShader ribbonShader;
SketchRun run;
boolean showHelp = true;
float orbit = 0.15;

void settings() {
  size(1280, 800, P3D);
  pixelDensity(1);
  smooth(4);
}

void setup() {
  surface.setTitle("Perfume / motion ribbons");
  surface.setResizable(true);
  frameRate(60);
  run = new SketchRun();
  showHelp = !run.automated;
  ribbonShader = run.checkedShader("ribbon.frag", "ribbon.vert");
  String[] files = { "A_test.bvh", "B_test.bvh", "C_test.bvh" };
  for (int i = 0; i < files.length; i++) dancers.add(new RibbonDancer(files[i]));
  textFont(createFont("SansSerif", 13));
}

void draw() {
  float time = run.seconds();
  background(7, 12, 21);
  float distance = max(580, 870.0 * height / width);
  perspective(PI / 3, float(width) / height, 1, max(3000, distance + 1500));
  camera(distance * sin(orbit), -125, distance * cos(orbit), 0, -10, 0, 0, 1, 0);
  drawStage();
  float[][] palette = { {0.30, 0.90, 0.87}, {1.0, 0.46, 0.37}, {0.94, 0.88, 0.72} };
  ribbonShader.set("time", time);
  for (int i = 0; i < dancers.size(); i++) {
    RibbonDancer dancer = dancers.get(i);
    dancer.update(time, new PVector(sin(orbit), -115 / distance, cos(orbit)).normalize());
    pushMatrix();
    translate((i - 1) * 235, 0, 0);
    ribbonShader.set("ink", palette[i][0], palette[i][1], palette[i][2]);
    shader(ribbonShader);
    for (PShape ribbon : dancer.ribbons) shape(ribbon);
    resetShader();
    stroke(220, 232, 235, 95);
    strokeWeight(1);
    noFill();
    beginShape(LINES);
    for (BvhBone bone : dancer.motion.parser.getBones()) {
      if (bone.getParent() != null) {
        PVector a = dancer.motion.position(bone.getParent().absPos);
        PVector b = dancer.motion.position(bone.absPos);
        vertex(a.x, a.y, a.z);
        vertex(b.x, b.y, b.z);
      }
    }
    endShape();
    popMatrix();
  }
  if (showHelp) drawLabels();
  run.finishFrame("motion_ribbons", dancers.size());
}

void drawStage() {
  stroke(24, 37, 49);
  strokeWeight(1);
  for (int x = -500; x <= 500; x += 50) line(x, 144, -220, x, 144, 220);
  for (int z = -220; z <= 220; z += 55) line(-500, 144, z, 500, 144, z);
}

void drawLabels() {
  hint(DISABLE_DEPTH_TEST);
  camera();
  fill(228, 237, 239);
  text("PERFUME  /  MOTION RIBBONS", 38, 43);
  fill(126, 145, 160);
  text("01   /   BVH > triangle strip > vertex + fragment shader", 38, 66);
  text("SPACE pause     drag orbit     R reset     H labels     S screenshot", 38, height - 32);
  hint(ENABLE_DEPTH_TEST);
}

void mouseDragged() { orbit += (mouseX - pmouseX) * 0.006; }
void keyPressed() {
  if (key == ' ') run.togglePause();
  if (key == 'r' || key == 'R') { run.reset(); orbit = 0.15; }
  if (key == 'h' || key == 'H') showHelp = !showHelp;
  if (key == 's' || key == 'S') saveFrame("captures/ribbons-####.png");
}
