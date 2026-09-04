# Perfume Global Site Project — Processing example

[![Processing 4](https://github.com/perfume-dev/example-processing/actions/workflows/processing.yml/badge.svg)](https://github.com/perfume-dev/example-processing/actions/workflows/processing.yml)

A Processing sketch that visualizes the three bundled BVH motion-capture files as animated point skeletons. This repository originated with the 2012 Perfume Global Site Project and is preserved as a small, runnable creative-coding example.

## Compatibility

- [Processing 4.5.6](https://processing.org/download/) (Java mode)
- macOS, Windows, or Linux with OpenGL support for the `P3D` renderer
- No separately installed Processing libraries

The bundled `p5f_sample/code/BVHParser.jar` is built from the source in `p5f_sample/lib/src` against Processing Core 4.5.6 and Java 17.

## Run the sketch

1. Install Processing 4.5.6.
2. Open `p5f_sample/p5f_sample.pde` in Processing.
3. Press **Run**.

The sketch loads `A_test.bvh`, `B_test.bvh`, and `C_test.bvh` from its `data` directory and plays all three motions in a continuously orbiting 3D view.

## Development and verification

The library and its parser tests require a Java 17 JDK and are checked against Processing Core 4.5.6:

```sh
mvn -B clean verify
```

After changing the Java library source, rebuild the bundled Processing JAR and its API documentation:

```sh
mvn -B package javadoc:javadoc
cp target/BVHParser.jar p5f_sample/code/BVHParser.jar
rm -rf p5f_sample/lib/doc
cp -R target/reports/apidocs p5f_sample/lib/doc
find p5f_sample/lib/doc -type f \( -name '*.html' -o -name '*.css' -o -name '*.js' \
  -o -name 'ADDITIONAL_LICENSE_INFO' \) \
  -exec perl -pi -e 's/[ \t]+$//' {} +
```

CI additionally compiles the complete PDE sketch with the official Processing 4.5.6 command-line tool and verifies that the committed JAR is identical to the reproducible Maven build.

## Project stewardship and credits

The [`perfume-dev` project](https://github.com/perfume-dev) and its repositories were established by [Daito Manabe](https://github.com/daitomanabe), who continues to maintain and administer them. [Perfume](https://www.perfume-web.jp/profile/) is a Japanese artist group; Manabe's documented collaborations with Perfume date to [2010](https://www.daito.ws/en/archive/perfume_12345678910/), and his credited roles across projects include [programming](https://www.bunka.go.jp/j-mediaarts-festival/award/single/perfume_global_site_project/index.html) as well as [creative direction, technical direction, and sound-effect design](https://www.daito.ws/archive/perfume-imaginary-museum-time-warp/). The 2012 project background and credits are documented by Japan's [Agency for Cultural Affairs](https://www.bunka.go.jp/j-mediaarts-festival/award/single/perfume_global_site_project/index.html) and in the [Daito Manabe archive](https://www.daito.ws/en/archive/perfume_globalsiteproject/).

The repository history credits [Satoru Higa](https://github.com/satoruhiga) for the original 2012 import and Hiroyuki at Rhizomatiks for the subsequent parser and library work. Their original source and authorship history are retained.

## License

No license file was included in the original repository. Unless and until the maintainers add one, the source and bundled motion data remain subject to their respective owners' copyright; public availability does not by itself grant reuse rights.
