// Copyright (c) 2026 Daito Manabe
// SPDX-License-Identifier: MIT; see LICENSE
import java.util.ArrayList;
import java.util.List;

final float WORLD_SCALE = 260;
final String VALIDATION_LABEL = "KINEMATIC REFERENCE — PHYSICS NOT VALIDATED";
final List<RobotMesh> robotMeshes = new ArrayList<>();
G1Motion motion;
LabRun run;
int selected = -1; // -1 = all three recordings; 0/1/2 = A/B/C.
boolean sourceOverlay = false;
boolean showHelp = true;
float orbit = -0.3;
float elevation = 0.18;

void settings() {
  size(1280, 820, P3D);
  pixelDensity(1);
  smooth(4);
}

void setup() {
  surface.setTitle("Perfume / G1 Motion Lab");
  surface.setResizable(true);
  frameRate(60);
  run = new LabRun();
  showHelp = !run.automated;
  try {
    motion = new G1Motion(requiredJson("g1-motion.json"));
    JSONObject model = requiredJson("g1-model.json");
    if (exactInteger(model.get("schema_version"), "model schema_version") != 1) throw new IllegalArgumentException("Unsupported model schema");
    JSONArray meshes = model.getJSONArray("meshes");
    if (meshes == null || meshes.size() == 0) throw new IllegalArgumentException("Model contains no meshes");
    for (int i = 0; i < meshes.size(); i++) robotMeshes.add(new RobotMesh(meshes.getJSONObject(i), motion.bodyNames.length));
    textFont(createFont("SansSerif", 13));
  } catch (RuntimeException problem) {
    run.fail("G1_DATA_ERROR: " + problem.getMessage());
  }
}

void draw() {
  float seconds = run.seconds();
  background(13, 18, 23);
  float distance = max(1080, 1600.0 * height / max(1, width));
  if (selected >= 0) distance *= 0.68;
  perspective(PI / 3, float(width) / max(1, height), 1, distance + 5000);
  camera(distance * sin(orbit), -260 - distance * elevation, -distance * cos(orbit),
    0, -210, 0, 0, 1, 0);
  lightSpecular(0, 0, 0);
  ambientLight(80, 88, 98);
  directionalLight(202, 211, 210, -0.4, 0.6, 0.6);
  // Cool reflected light separates the dark head shell from the ink backdrop.
  lightSpecular(105, 135, 145);
  directionalLight(70, 110, 120, 0.8, -0.1, -0.6);
  drawFloor();
  int shown = 0;
  for (int i = 0; i < motion.clips.size(); i++) {
    if (selected >= 0 && i != selected) continue;
    MotionClip clip = motion.clips.get(i);
    Pose pose = clip.sample(seconds, motion.fps);
    // This camera looks from negative drawing Z, so reverse world slots for A/B/C left to right.
    PVector offset = clip.displayOffset(selected < 0 ? 1 - i : 0);
    pushMatrix();
    // Right-handed Z-up metres -> Processing's Y-down drawing coordinates.
    applyMatrix(0, WORLD_SCALE, 0, 0,
                0, 0, -WORLD_SCALE, 0,
                -WORLD_SCALE, 0, 0, 0,
                0, 0, 0, 1);
    translate(offset.x, offset.y, offset.z);
    for (RobotMesh mesh : robotMeshes) mesh.draw(pose);
    drawHandTrails(clip, seconds);
    if (sourceOverlay) drawSource(pose);
    popMatrix();
    shown++;
  }
  drawLabels();
  run.finishFrame(shown);
}

void drawFloor() {
  noFill();
  stroke(36, 48, 56);
  strokeWeight(1);
  for (int i = -12; i <= 12; i++) {
    float step = i * WORLD_SCALE * 0.25;
    line(-3 * WORLD_SCALE, 0, step, 3 * WORLD_SCALE, 0, step);
    line(step, 0, -3 * WORLD_SCALE, step, 0, 3 * WORLD_SCALE);
  }
}

void drawSource(Pose pose) {
  stroke(99, 206, 212, 120);
  // P3D scales line width with the metre-to-pixel model matrix as well.
  strokeWeight(1.2 / WORLD_SCALE);
  for (int i = 0; i < motion.sourceNames.length; i++) {
    int parent = motion.sourceParents[i];
    if (parent < 0 || parent == i) continue;
    int a = i * 3, b = parent * 3;
    line(pose.source[a], pose.source[a + 1], pose.source[a + 2],
      pose.source[b], pose.source[b + 1], pose.source[b + 2]);
  }
}

void drawHandTrails(MotionClip clip, float seconds) {
  noFill();
  strokeWeight(1.7 / WORLD_SCALE);
  float duration = clip.frames.length / motion.fps;
  float loopStart = floor(seconds / duration) * duration;
  for (int hand : motion.handBodies) {
    for (int k = 1; k < 32; k++) {
      float before = max(loopStart, seconds - 0.65 + (k - 1) * 0.65 / 31);
      float after = max(loopStart, seconds - 0.65 + k * 0.65 / 31);
      PVector a = clip.bodyPoint(before, motion.fps, hand);
      PVector b = clip.bodyPoint(after, motion.fps, hand);
      stroke(106, 213, 216, 140.0 * k / 31);
      line(a.x, a.y, a.z, b.x, b.y, b.z);
    }
  }
}

void drawLabels() {
  hint(DISABLE_DEPTH_TEST);
  camera();
  noLights();
  fill(126, 147, 157);
  textSize(11);
  // Keep the validation boundary visible even in clean artwork captures.
  text(VALIDATION_LABEL, 30, height - 26);
  if (!motion.poseQaPassed) {
    fill(230, 170, 112);
    text("POSE QA FAILED — DIAGNOSTIC ONLY", 30, height - 46);
  }
  if (showHelp) {
    fill(232, 235, 235);
    textSize(15);
    text("PERFUME  /  G1 MOTION LAB", 30, 39);
    fill(129, 151, 162);
    textSize(12);
    text((selected < 0 ? "A + B + C" : motion.clips.get(selected).name) +
      "   /   official G1 body meshes   /   " + nf(motion.fps, 0, 0) + " Hz motion reference", 30, 63);
    text("1 / 2 / 3 single     0 all     O source     SPACE pause     R reset     drag orbit     H labels     S save", 30, 84);
  }
  hint(ENABLE_DEPTH_TEST);
}

void mouseDragged() {
  orbit += (mouseX - pmouseX) * 0.006;
  elevation = constrain(elevation + (mouseY - pmouseY) * 0.002, -0.12, 0.7);
}

void keyPressed() {
  if (key >= '1' && key <= '3') selected = key - '1';
  if (key == '0') selected = -1;
  if (key == 'o' || key == 'O') sourceOverlay = !sourceOverlay;
  if (key == ' ') run.paused = !run.paused;
  if (key == 'r' || key == 'R') { run.reset(); orbit = -0.3; elevation = 0.18; }
  if (key == 'h' || key == 'H') showHelp = !showHelp;
  if (key == 's' || key == 'S') saveFrame("captures/g1-####.png");
}
