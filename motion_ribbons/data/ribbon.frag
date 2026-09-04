// Copyright (c) 2026 Daito Manabe
// SPDX-License-Identifier: MIT
#ifdef GL_ES
precision mediump float;
precision mediump int;
#endif
uniform vec3 ink;
uniform float time;
varying vec4 ribbon;
varying vec3 position;

void main() {
  float age = ribbon.r;
  float across = ribbon.g;
  float edge = abs(across * 2.0 - 1.0);
  float filament = smoothstep(0.72, 0.99, edge);
  float sheen = pow(max(0.0, sin(across * 3.14159 + position.y * 0.008)), 12.0);
  float pulse = 0.86 + 0.14 * sin(age * 24.0 - time * 2.0 + ribbon.b * 6.0);
  vec3 body = ink * (0.22 + 0.52 * age) * pulse;
  body += mix(ink, vec3(1.0), 0.6) * (filament * 0.7 + sheen * 0.28);
  float fade = smoothstep(0.0, 0.18, age);
  gl_FragColor = vec4(body * fade, 1.0);
}
