# Copyright (c) 2026 Daito Manabe
# SPDX-License-Identifier: MIT; see LICENSE
"""Test fixture isolation/mutation only; the tiny inputs are never rendered."""

import json
from pathlib import Path
import tempfile
import unittest

from make_negative_fixture import CASES, make_fixture


class NegativeFixtureTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.source = self.root / "source" / "g1_motion_lab"
        data_dir = self.source / "data"
        data_dir.mkdir(parents=True)
        (self.source / "g1_motion_lab.pde").write_text("// Fixture-helper test only; never rendered.\n")
        motion = {"schema_version": 1, "body_parents": [-1, 0, 1],
                  "body_offsets": [[0, 0, 0], [1, 0, 0], [0, 1, 0]], "validation": {"label": "fixture marker"},
                  "clips": [{"frames": [{"positions": [0, 0, 0], "rotations": [1, 0, 0, 0]}]}]}
        model = {"schema_version": 1, "meshes": [{"body": 0, "vertices": [0, 0, 0, 1, 0, 0, 0, 1, 0], "indices": [0, 1, 2]}]}
        (data_dir / "g1-motion.json").write_text(json.dumps(motion))
        (data_dir / "g1-model.json").write_text(json.dumps(model))
        self.original = self.snapshot()

    def tearDown(self):
        self.temporary.cleanup()

    def snapshot(self):
        return {str(path.relative_to(self.source)): path.read_bytes()
                for path in self.source.rglob("*") if path.is_file()}

    def test_each_corruption_keeps_original_unchanged(self):
        for case in CASES:
            with self.subTest(case=case):
                destination = self.root / case / "g1_motion_lab"
                make_fixture(self.source, destination, case)
                self.assertEqual(self.snapshot(), self.original)
                data_dir = destination / "data"
                if case in ("missing-motion", "missing-model"):
                    filename = "g1-motion.json" if case == "missing-motion" else "g1-model.json"
                    self.assertFalse((data_dir / filename).exists())
                    self.assertTrue((data_dir / (filename + ".disabled")).is_file())
                    continue
                model_case = case in ("index", "model-schema", "fractional-body", "fractional-index", "overflow-index")
                filename = "g1-model.json" if model_case else "g1-motion.json"
                data = json.loads((data_dir / filename).read_text())
                if case in ("schema", "model-schema"):
                    self.assertEqual(data["schema_version"], 999)
                elif case == "fractional-schema":
                    self.assertEqual(data["schema_version"], 1.5)
                elif case == "fractional-parent":
                    self.assertEqual(data["body_parents"][0], -0.5)
                elif case == "non-topological-parent":
                    self.assertEqual(data["body_parents"][1:3], [2, 0])
                elif case == "multiple-roots":
                    self.assertEqual(data["body_parents"][1], -1)
                elif case == "root-self-parent":
                    self.assertEqual(data["body_parents"][0], 0)
                elif case == "missing-offsets":
                    self.assertNotIn("body_offsets", data)
                elif case == "offset-shape":
                    self.assertEqual(len(data["body_offsets"][1]), 2)
                elif case == "offset-nonfinite":
                    self.assertEqual(data["body_offsets"][1][0], 1e300)
                elif case == "offset-mismatch":
                    self.assertEqual(data["body_offsets"][1][0], 1.02)
                elif case == "fractional-body":
                    self.assertEqual(data["meshes"][0]["body"], 0.5)
                elif case == "fractional-index":
                    self.assertEqual(data["meshes"][0]["indices"][0], 0.5)
                elif case == "overflow-index":
                    self.assertEqual(data["meshes"][0]["indices"][0], 4294967297)
                elif case == "quaternion":
                    self.assertEqual(data["clips"][0]["frames"][0]["rotations"], [0, 0, 0, 0])
                elif case == "index":
                    self.assertEqual(data["meshes"][0]["indices"][0], 3)
                elif case == "frame-size":
                    self.assertEqual(len(data["clips"][0]["frames"][0]["positions"]), 2)
                elif case == "validation-label":
                    self.assertEqual(data["validation"]["label"], "INVALID TEST LABEL")

    def test_original_nested_and_existing_destinations_are_refused(self):
        for destination in [self.source, self.source / "nested" / "g1_motion_lab"]:
            with self.subTest(destination=str(destination)), self.assertRaises(ValueError):
                make_fixture(self.source, destination, "schema")
        existing = self.root / "existing" / "g1_motion_lab"
        existing.mkdir(parents=True)
        with self.assertRaises(FileExistsError):
            make_fixture(self.source, existing, "schema")
        self.assertEqual(self.snapshot(), self.original)


if __name__ == "__main__":
    unittest.main()
