# Copyright (c) 2026 Daito Manabe
# SPDX-License-Identifier: MIT; see LICENSE
"""Compile/test the exact PDE interpolation helper with Java, without a GPU."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


class RigidPoseMathTests(unittest.TestCase):
    def test_exact_viewer_code_preserves_rigid_anchors(self):
        here = Path(__file__).resolve().parent
        source = here.parents[1] / "g1_motion_lab" / "RigidPoseMath.pde"
        java_home = os.environ.get("JAVA_HOME")
        javac = str(Path(java_home) / "bin" / "javac") if java_home else shutil.which("javac")
        java = str(Path(java_home) / "bin" / "java") if java_home else shutil.which("java")
        self.assertTrue(javac and java, "A JDK is required for the actual viewer math regression")
        with tempfile.TemporaryDirectory(prefix="g1-rigid-math-") as temporary:
            folder = Path(temporary)
            harness = folder / "RigidPoseMathTest.java"
            harness.write_text("public class RigidPoseMathTest {\n" + source.read_text()
                               + "\n" + (here / "RigidPoseMathChecks.java").read_text() + "\n}\n")
            subprocess.run([javac, "--release", "17", str(harness)], check=True, capture_output=True, text=True, timeout=30)
            result = subprocess.run([java, "-cp", temporary, "RigidPoseMathTest"],
                                    check=True, capture_output=True, text=True, timeout=30)
            self.assertIn("RIGID_POSE_MATH_OK", result.stdout)


if __name__ == "__main__":
    unittest.main()
