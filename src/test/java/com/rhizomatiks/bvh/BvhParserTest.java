package com.rhizomatiks.bvh;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import org.junit.jupiter.api.Test;

class BvhParserTest {
  private static final Path DATA_DIRECTORY = Path.of("p5f_sample", "data");

  @Test
  void parsesAndUpdatesEveryBundledMotion() throws IOException {
    for (String filename : List.of("A_test.bvh", "B_test.bvh", "C_test.bvh")) {
      BvhParser parser = parse(DATA_DIRECTORY.resolve(filename));

      assertEquals(1300, parser.getNbFrames(), filename);
      assertEquals(0.025f, parser.getFrameTime(), 0.000001f, filename);
      assertEquals(23, parser.getBones().size(), filename);

      parser.moveFrameTo(1);
      parser.update();

      assertEquals(1, parser.getCurrentFrame(), filename);
      assertEquals("Hips", parser.getBones().get(0).getName(), filename);
    }
  }

  @Test
  void loopsAndClampsFrameSelection() throws IOException {
    BvhParser parser = parse(DATA_DIRECTORY.resolve("A_test.bvh"));

    parser.moveFrameTo(parser.getNbFrames());
    assertEquals(0, parser.getCurrentFrame());

    parser.moveFrameTo(-1);
    assertEquals(parser.getNbFrames() - 1, parser.getCurrentFrame());

    parser.setMotionLoop(false);
    parser.moveFrameTo(-1);
    assertEquals(0, parser.getCurrentFrame());

    parser.moveFrameTo(parser.getNbFrames());
    assertEquals(parser.getNbFrames() - 1, parser.getCurrentFrame());
  }

  @Test
  void acceptsOrdinaryBvhWhitespace() {
    BvhParser parser = new BvhParser();
    parser.parse(new String[] {
        "HIERARCHY",
        "ROOT Root",
        "{",
        "\tOFFSET   0  0  0",
        "CHANNELS 6 Xposition Yposition Zposition Xrotation Yrotation Zrotation",
        "End Site",
        "{",
        "OFFSET 0 1 0",
        "}",
        "}",
        "MOTION",
        "Frames: 1",
        "Frame Time: 0.033333",
        "0 0 0 0 0 0"
    });

    parser.update();
    assertEquals(1, parser.getNbFrames());
    assertEquals(1, parser.getBones().size());
  }

  @Test
  void rejectsIncompleteInputWithAUsefulError() {
    BvhParser parser = new BvhParser();
    assertThrows(IllegalArgumentException.class,
        () -> parser.parse(new String[] {"HIERARCHY", "ROOT Root"}));
  }

  private static BvhParser parse(Path path) throws IOException {
    BvhParser parser = new BvhParser();
    parser.parse(Files.readAllLines(path).toArray(String[]::new));
    return parser;
  }
}
