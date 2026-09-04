import com.rhizomatiks.bvh.BvhBone;
import com.rhizomatiks.bvh.BvhParser;

PBvh bvh1;
PBvh bvh2;
PBvh bvh3;
boolean smokeTest;

void settings() {
  size(1280, 720, P3D);
}

void setup() {
  background(0);
  noStroke();
  frameRate(30);

  smokeTest = false;
  if (args != null) {
    for (String arg : args) {
      smokeTest |= "--smoke-test".equals(arg);
    }
  }

  bvh1 = new PBvh(loadStrings("A_test.bvh"));
  bvh2 = new PBvh(loadStrings("B_test.bvh"));
  bvh3 = new PBvh(loadStrings("C_test.bvh"));
}

void draw() {
  background(0);

  // Camera
  float orbitCos = cos(millis() / 5000.0f);
  float orbitSin = sin(millis() / 5000.0f);
  camera(
    width / 4.0f + width / 4.0f * orbitCos + 200,
    height / 2.0f - 100,
    550 + 150 * orbitSin,
    width / 2.0f,
    height / 2.0f,
    -400,
    0,
    1,
    0
  );

  // Ground
  fill(255);
  stroke(127);
  line(width / 2.0f, height / 2.0f, -30, width / 2.0f, height / 2.0f, 30);
  line(width / 2.0f - 30, height / 2.0f, 0, width / 2.0f + 30, height / 2.0f, 0);
  stroke(255);

  pushMatrix();
  translate(width / 2.0f, height / 2.0f - 10, 0);
  scale(-1, -1, -1);

  // Models
  bvh1.update(millis());
  bvh2.update(millis());
  bvh3.update(millis());
  bvh1.draw();
  bvh2.draw();
  bvh3.draw();
  popMatrix();

  if (smokeTest && frameCount >= 10) {
    println("SMOKE_TEST_OK frames=" + frameCount + " motions=3");
    exit();
  }
}
