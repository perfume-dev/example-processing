import com.rhizomatiks.bvh.BvhBone;
import com.rhizomatiks.bvh.BvhParser;
import java.util.List;
import java.util.ArrayList;

final List<PBvh> dancers = new ArrayList<>();
SketchRun run;
boolean showHelp = true;
float orbit = 0;

void settings() {
  size(1280, 800, P3D);
  pixelDensity(1);
  smooth(4);
}

void setup() {
  surface.setTitle("Perfume / point skeletons");
  surface.setResizable(true);
  frameRate(60);
  run = new SketchRun();
  showHelp = !run.automated;
  int[] palette = { color(110, 224, 219), color(255, 142, 124), color(238, 232, 210) };
  String[] files = { "A_test.bvh", "B_test.bvh", "C_test.bvh" };
  for (int i = 0; i < files.length; i++) dancers.add(new PBvh(loadStrings(files[i]), palette[i]));
  textFont(createFont("SansSerif", 13));
}

void draw() {
  float time = run.seconds();
  background(8, 13, 23);
  float distance = max(650, 900.0 * height / width);
  perspective(PI / 3, float(width) / height, 1, max(3000, distance + 1500));
  camera(distance * sin(orbit), -90, distance * cos(orbit), 0, -5, 0, 0, 1, 0);
  stroke(39, 52, 64);
  strokeWeight(1);
  for (int x = -450; x <= 450; x += 50) line(x, 145, -250, x, 145, 250);
  for (int z = -250; z <= 250; z += 50) line(-450, 145, z, 450, 145, z);
  for (int i = 0; i < dancers.size(); i++) {
    PBvh dancer = dancers.get(i);
    dancer.update(time);
    pushMatrix();
    translate((i - 1) * 240, 0, 0);
    shape(dancer.bones);
    shape(dancer.joints);
    popMatrix();
  }
  if (showHelp) {
    hint(DISABLE_DEPTH_TEST);
    camera();
    fill(225, 233, 236);
    text("PERFUME  /  POINT SKELETONS", 38, 43);
    fill(126, 145, 160);
    text("PShape + PVector   /   three original BVH recordings", 38, 66);
    text("SPACE pause     drag orbit     R reset     H labels     S screenshot", 38, height - 32);
    hint(ENABLE_DEPTH_TEST);
  }
  run.finishFrame("p5f_sample", 3);
}

void mouseDragged() { orbit += (mouseX - pmouseX) * 0.006; }
void keyPressed() {
  if (key == ' ') run.togglePause();
  if (key == 'r' || key == 'R') { run.reset(); orbit = 0; }
  if (key == 'h' || key == 'H') showHelp = !showHelp;
  if (key == 's' || key == 'S') saveFrame("captures/points-####.png");
}
