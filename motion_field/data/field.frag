// Copyright (c) 2026 Daito Manabe
// SPDX-License-Identifier: MIT
#ifdef GL_ES
#extension GL_OES_standard_derivatives : enable
precision highp float;
precision mediump int;
#endif
#define PROCESSING_COLOR_SHADER
uniform vec2 resolution;
uniform float time;
uniform float density;
uniform vec3 sources[18];

vec3 palette(float id) {
  if (id < 0.5) return vec3(0.24, 0.86, 0.84);
  if (id < 1.5) return vec3(1.0, 0.38, 0.30);
  return vec3(0.94, 0.86, 0.66);
}

void main() {
  float fieldScale = min(resolution.y, resolution.x / 1.6);
  vec2 p = (gl_FragCoord.xy - resolution * 0.5) / fieldScale;
  vec3 ink = vec3(0.0);
  float total = 0.0;
  float wave = 0.0;
  float nearest = 10.0;
  for (int i = 0; i < 18; i++) {
    float d = length(p - sources[i].xy);
    float influence = 0.007 / (d * d + 0.006);
    total += influence;
    ink += palette(sources[i].z) * influence;
    wave += sin(d * 49.0 - time * 1.6 + float(i) * 0.36) * exp(-d * 7.0);
    nearest = min(nearest, d);
  }
  ink /= max(total, 0.001);
  float level = log(1.0 + total) * 14.0 * density + wave * 0.24;
  float band = abs(fract(level) - 0.5);
  float pixelWidth = max(fwidth(level), 0.004);
  float line = 1.0 - smoothstep(pixelWidth * 0.45, pixelWidth * 1.4, band);
  float envelope = smoothstep(0.14, 0.9, total);
  float halo = exp(-nearest * 17.0);
  vec3 base = vec3(0.022, 0.037, 0.060);
  vec3 color = base + ink * (line * 0.58 * envelope + halo * 0.07);
  color += vec3(0.50, 0.64, 0.69) * pow(halo, 9.0) * 0.25;
  float vignette = 1.0 - smoothstep(0.42, 1.0, length(p * vec2(0.65, 1.0)));
  gl_FragColor = vec4(color * (0.4 + 0.6 * vignette), 1.0);
}
