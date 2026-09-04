// Copyright (c) 2026 Daito Manabe
// SPDX-License-Identifier: MIT; see ../LICENSE-new-examples
import java.nio.IntBuffer;
import processing.opengl.PGL;
import processing.opengl.PShader;

// Automated runs retain an OpenGL window, but suppress its focus request.
protected PSurface initSurface() {
  PSurface result = super.initSurface();
  if (args != null) for (String arg : args) {
    if (arg.equals("--smoke-test") || arg.startsWith("--capture=")) {
      ((com.jogamp.newt.opengl.GLWindow) result.getNative()).setFocusAction(() -> true);
    }
  }
  return result;
}

class SketchRun {
  boolean automated = false;
  boolean paused = false;
  String capturePath;
  float captureTime = 8;
  float elapsed = 0;
  int previousMillis = millis();
  final int captureFrame = 12;

  SketchRun() {
    if (args != null) for (String arg : args) {
      if (arg.equals("--smoke-test")) automated = true;
      if (arg.startsWith("--capture=")) {
        capturePath = arg.substring("--capture=".length());
        if (!new java.io.File(capturePath).isAbsolute()) {
          throw new IllegalArgumentException("--capture requires an absolute output path");
        }
        automated = true;
      }
      if (arg.startsWith("--time=")) captureTime = Float.parseFloat(arg.substring(7));
    }
    if (!Float.isFinite(captureTime) || captureTime < 0 || captureTime > 3600) {
      throw new IllegalArgumentException("--time must be finite, between 0 and 3600 seconds");
    }
  }

  float seconds() {
    int now = millis();
    if (!paused) elapsed += min((now - previousMillis) / 1000.0, 0.1);
    previousMillis = now;
    return automated ? max(0, captureTime + (frameCount - captureFrame) / 60.0) : elapsed;
  }

  void togglePause() { paused = !paused; }
  void reset() { elapsed = 0; paused = false; previousMillis = millis(); }

  PShader checkedShader(String fragment, String vertex) {
    try {
      if (!new java.io.File(dataPath(fragment)).isFile() ||
          (vertex != null && !new java.io.File(dataPath(vertex)).isFile())) {
        throw new IllegalStateException("A required shader file is missing");
      }
      PShader program = vertex == null ? loadShader(fragment) : loadShader(fragment, vertex);
      // Processing can print a shader error and continue. Make that a test failure.
      program.init();
      PGL gl = beginPGL();
      IntBuffer linked = IntBuffer.allocate(1);
      gl.getProgramiv(program.glProgram, PGL.LINK_STATUS, linked);
      String log = gl.getProgramInfoLog(program.glProgram);
      endPGL();
      if (linked.get(0) != 1) throw new IllegalStateException("Shader did not link: " + log);
      return program;
    } catch (RuntimeException failure) {
      System.err.println("SHADER_ERROR: " + failure.getMessage());
      // JOGL shutdown hooks can deadlock when compilation fails on its draw
      // thread. Test failures exit immediately; normal runs use exit().
      if (automated) Runtime.getRuntime().halt(1);
      throw failure;
    }
  }

  void finishFrame(String name, int motions) {
    if (!automated || frameCount < captureFrame) return;
    loadPixels();
    int litPixels = 0;
    for (int pixel : pixels) {
      if (max((pixel >> 16) & 255, max((pixel >> 8) & 255, pixel & 255)) > 65) litPixels++;
    }
    if (litPixels < 600) {
      System.err.println("SMOKE_TEST_FAILED: rendered frame is unexpectedly empty");
      Runtime.getRuntime().halt(1);
    }
    if (capturePath != null) {
      save(capturePath);
      java.io.File output = new java.io.File(capturePath);
      if (!output.isFile() || output.length() < 1000) throw new IllegalStateException("Capture was not saved");
    }
    println("SMOKE_TEST_OK sketch=" + name + " frames=" + frameCount +
      " motions=" + motions + " litPixels=" + litPixels + " focused=" + focused);
    exit();
  }
}
