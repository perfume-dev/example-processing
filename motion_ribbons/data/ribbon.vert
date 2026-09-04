// Copyright (c) 2026 Daito Manabe
// SPDX-License-Identifier: MIT
#define PROCESSING_COLOR_SHADER
uniform mat4 transform;
attribute vec4 vertex;
attribute vec4 color;
varying vec4 ribbon;
varying vec3 position;

void main() {
  ribbon = color;
  position = vertex.xyz;
  gl_Position = transform * vertex;
}
