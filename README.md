# Perfume Global Site Project — Processing examples

[![Processing 4](https://github.com/perfume-dev/example-processing/actions/workflows/processing.yml/badge.svg)](https://github.com/perfume-dev/example-processing/actions/workflows/processing.yml)

Four small, runnable motion-visualization sketches for Processing 4.5.6. The original 2012 Perfume Global Site Project example now uses retained `PShape` geometry, `PVector` coordinates, typed collections, and an explicit playback clock. Two new shader studies turn the same BVH recordings into ribbons and contour fields. G1 Motion Lab adds robot-reference playback and source skeleton comparison, without robot control. Its three references pass complete 40 Hz pose checks; [measured results and physical limitations](g1_motion_lab/VALIDATION.md) distinguish this from real-robot feasibility.

![Actual G1 Motion Lab capture; kinematic references, physics not validated](docs/images/g1-motion-lab.png)

| Sketch | What to learn | Renderer |
| --- | --- | --- |
| [`p5f_sample`](p5f_sample/p5f_sample.pde) | BVH playback; update a retained skeleton with `PShape.setVertex()` | P3D |
| [`motion_ribbons`](motion_ribbons/) | Cached joint trajectories; triangle strips; vertex + fragment shaders | P3D |
| [`motion_field`](motion_field/) | Send joint positions as uniforms; draw isocontours and interference in one fragment pass | P2D |
| [`g1_motion_lab`](g1_motion_lab/) | Retained robot-link meshes, WXYZ transforms and original human skeleton comparison | P3D |

![Motion ribbons, rendered by Processing](docs/images/motion-ribbons.png)

![Motion field, rendered by Processing](docs/images/motion-field.png)

These are actual rendered frames from the bundled recordings, at 16 seconds and 8 seconds respectively.

## Compatibility

- [Processing 4.5.6](https://processing.org/download/) (Java mode)
- macOS, Windows, or Linux with OpenGL support for the `P2D` and `P3D` renderers
- No separately installed Processing libraries

The bundled `code/BVHParser.jar` in the three BVH sketches is the same small library built from `p5f_sample/lib/src` against Processing Core 4.5.6 and Java 17. CI checks all copies against the reproducible Maven build. G1 Motion Lab reads precomputed JSON and needs no parser JAR. [Processing's `PShader`](https://processing.org/reference/PShader) exposes vertex and fragment stages; the ribbon topology is generated on the CPU. These sketches do not require a geometry-shader extension or a separately installed library.

## Run the sketch

1. Install Processing 4.5.6.
2. Download or clone this entire repository.
3. Open the matching `.pde` in `p5f_sample`, `motion_ribbons`, `motion_field`, or `g1_motion_lab` in Processing.
4. Press **Run**.

The original BVH files remain in `p5f_sample/data/`. The new sketches resolve this directory relative to their own sketch directory, so the repository can live anywhere. For **Export Application** or a standalone sketch folder, copy `A_test.bvh`, `B_test.bvh`, and `C_test.bvh` into that sketch's own `data/` directory first; local files take priority. The original data has not been modified or duplicated in Git.

The three BVH views recenter each dancer's root X/Z position and place the dancers side by side, retaining the recorded joint poses and vertical movement. This is a visualization layout, not the original stage formation. `MotionData.position()` (or `PBvh.stagePosition()`) is the small coordinate-conversion function to change when preserving the original translation is desired. G1 Motion Lab instead uses robot Z-up coordinates, removes only the initial horizontal origin and retains later travel; its source overlay receives the identical display translation.

`Space` pauses; `R` restarts; `H` toggles labels; `S` saves a PNG under the sketch's `captures/` folder. Drag to orbit the 3D views. In the field sketch, `+` / `-` change contour density and `J` displays the driving joints. The views adapt to window size, and playback continues while another application has focus.

日本語: Processingで各フォルダーの同名 `.pde` を開けば実行できます。リボンは「関節の軌跡 → 三角形ストリップ → 頂点・フラグメントシェーダー」、フィールドは「関節座標 → uniform → 等高線」という最小構成です。元のモーションデータを共有するため、最初はリポジトリ全体をダウンロードしてください。

## Development and verification

The library and its parser tests require a Java 17 JDK and are checked against Processing Core 4.5.6:

```sh
mvn -B clean verify
```

After changing the Java library source, rebuild the bundled Processing JAR and its API documentation:

```sh
mvn -B package javadoc:javadoc
cp target/BVHParser.jar p5f_sample/code/BVHParser.jar
cp target/BVHParser.jar motion_ribbons/code/BVHParser.jar
cp target/BVHParser.jar motion_field/code/BVHParser.jar
rm -rf p5f_sample/lib/doc
cp -R target/reports/apidocs p5f_sample/lib/doc
find p5f_sample/lib/doc -type f \( -name '*.html' -o -name '*.css' -o -name '*.js' \
  -o -name 'ADDITIONAL_LICENSE_INFO' \) \
  -exec perl -pi -e 's/[ \t]+$//' {} +
```

Use the official Processing executable (`Processing` on macOS, `processing` on Linux) to compile and render all sketches:

```sh
./scripts/verify-sketches.sh /path/to/Processing /path/to/test-output
```

On Linux without a desktop, prefix the command with `xvfb-run --auto-servernum`. Each run has a 60-second timeout. CI uses this same script, renders all four sketches at 8 and 16 seconds, checks that the two images differ, verifies nonempty framebuffers and shader link status, and confirms that missing or malformed shaders and G1 data fail. PNGs and runtime logs are retained as workflow artifacts. The BVH helper tabs (`SketchRun.pde` and the shader studies' `MotionData.pde`) are kept byte-identical across their copies so that each sketch opens directly in the PDE without preprocessing or extra setup. G1 Motion Lab has its own independent loader. Rendering tests do not approve the retargeting or physics of a motion package.

For one deterministic capture (the parent output directory must exist):

```sh
/path/to/Processing cli --sketch="$(pwd)/motion_ribbons" \
  --output=/path/to/a-new-build-directory --run \
  --smoke-test --time=16 --capture=/path/to/ribbons.png
```

`--smoke-test` / `--capture` use a fixed timeline, hide labels, suppress window focus requests, and exit after the captured frame. Normal interactive playback uses elapsed time. For automated captures on macOS, `JAVA_TOOL_OPTIONS=-Dapple.awt.UIElement=true` also prevents a transient Dock application from activating.

## Project stewardship and credits

The [`perfume-dev` project](https://github.com/perfume-dev) and its repositories were established by [Daito Manabe](https://github.com/daitomanabe), who continues to maintain and administer them. [Perfume](https://www.perfume-web.jp/profile/) is a Japanese artist group; Manabe's documented collaborations with Perfume date to [2010](https://www.daito.ws/en/archive/perfume_12345678910/), and his credited roles across projects include [programming](https://www.bunka.go.jp/j-mediaarts-festival/award/single/perfume_global_site_project/index.html) as well as [creative direction, technical direction, and sound-effect design](https://www.daito.ws/archive/perfume-imaginary-museum-time-warp/). The 2012 project background and credits are documented by Japan's [Agency for Cultural Affairs](https://www.bunka.go.jp/j-mediaarts-festival/award/single/perfume_global_site_project/index.html) and in the [Daito Manabe archive](https://www.daito.ws/en/archive/perfume_globalsiteproject/).

The repository history credits [Satoru Higa](https://github.com/satoruhiga) for the original 2012 import and Hiroyuki at Rhizomatiks for the subsequent parser and library work. Their original source and authorship history are retained.

## License

The newly written shader examples and test helper are MIT-licensed as scoped explicitly in [`LICENSE-new-examples`](LICENSE-new-examples), copyright 2026 Daito Manabe. This does **not** relicense the pre-existing source, original parser (including its copied JARs), or motion data. No license file was included with those original materials; they remain subject to their respective owners' copyright, and public availability does not by itself grant reuse rights.

[G1 Motion Lab's new source](g1_motion_lab/LICENSE) is separately MIT-licensed,
Copyright (c) 2026 Daito Manabe. Its robot geometry retains the upstream
[Unitree BSD-3-Clause license](g1_motion_lab/data/MODEL-LICENSE). Neither license
relicenses the original or derived dance recording. The viewer always states
**KINEMATIC REFERENCE — PHYSICS NOT VALIDATED**. It contains no physics engine,
learned policy or hardware transport, and does not establish that a physical
robot can safely execute the recording.
