// Copyright (c) 2026 Daito Manabe
// SPDX-License-Identifier: MIT; see LICENSE
protected PSurface initSurface() {
  PSurface result = super.initSurface();
  if (args != null) for (String arg : args) {
    if (arg.equals("--smoke-test") || arg.startsWith("--capture=")) {
      ((com.jogamp.newt.opengl.GLWindow) result.getNative()).setFocusAction(() -> true);
    }
  }
  return result;
}

class LabRun {
  boolean automated;
  boolean paused;
  String capture;
  float time = 8;
  float elapsed;
  int previousMillis = millis();
  final int finalFrame = 12;

  LabRun() {
    if (args != null) for (String arg : args) {
      if (arg.equals("--smoke-test")) automated = true;
      if (arg.startsWith("--capture=")) { capture = arg.substring(10); automated = true; }
      if (arg.startsWith("--time=")) time = Float.parseFloat(arg.substring(7));
      if (arg.equals("--source-overlay")) sourceOverlay = true;
      if (arg.startsWith("--clip=")) {
        String clip = arg.substring(7);
        if (!clip.matches("[ABC]")) fail("--clip must be A, B or C");
        selected = clip.charAt(0) - 'A';
      }
    }
    if (!Float.isFinite(time) || time < 0 || time > 3600) fail("Invalid --time value");
    if (capture != null && !new java.io.File(capture).isAbsolute()) fail("--capture requires an absolute output path");
  }

  float seconds() {
    int now = millis();
    if (!paused) elapsed += min(0.1, (now - previousMillis) / 1000.0);
    previousMillis = now;
    return automated ? max(0, time + (frameCount - finalFrame) / 60.0) : elapsed;
  }

  void reset() { elapsed = 0; paused = false; previousMillis = millis(); }

  void fail(String message) {
    System.err.println(message);
    if (automated) Runtime.getRuntime().halt(1);
    throw new IllegalStateException(message);
  }

  void finishFrame(int clips) {
    if (!automated || frameCount < finalFrame) return;
    loadPixels();
    int bright = 0;
    // Exclude the validation footer: text cannot make an empty robot view pass.
    for (int y = 100; y < height - 80; y++) for (int x = 10; x < width - 10; x++) {
      int pixel = pixels[y * width + x];
      if (((pixel >> 16) & 255) > 75 && ((pixel >> 8) & 255) > 75 && (pixel & 255) > 75) bright++;
    }
    if (bright < 500 || robotMeshes.isEmpty()) fail("SMOKE_TEST_FAILED: no visible G1 geometry");
    if (capture != null) {
      save(capture);
      java.io.File output = new java.io.File(capture);
      if (!output.isFile() || output.length() < 1000) fail("SMOKE_TEST_FAILED: capture not written");
    }
    println("SMOKE_TEST_OK sketch=g1_motion_lab frames=" + frameCount + " clips=" + clips +
      " meshes=" + robotMeshes.size() + " brightPixels=" + bright + " focused=" + focused +
      " time=" + time + " sourceOverlay=" + sourceOverlay + " poseQaPassed=" + motion.poseQaPassed +
      " scope=rendering-only");
    exit();
  }
}
