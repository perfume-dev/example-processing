#!/usr/bin/env python3
# Copyright (c) 2026 Daito Manabe
# SPDX-License-Identifier: MIT; see LICENSE
"""Make one invalid G1 input in a NEW copied sketch; never modify the original."""

import argparse
import json
from pathlib import Path
import shutil


CASES = (
    "missing-motion", "missing-model", "schema", "quaternion", "index",
    "frame-size", "validation-label",
    "model-schema", "fractional-schema", "fractional-parent", "fractional-body",
    "fractional-index", "overflow-index",
    "missing-offsets", "offset-shape", "offset-nonfinite", "offset-mismatch",
    "non-topological-parent", "multiple-roots", "root-self-parent",
)


def make_fixture(source: Path, destination: Path, case: str) -> None:
    if case not in CASES:
        raise ValueError("Unknown negative-data case")
    source, destination = source.resolve(), destination.resolve()
    if destination == source or source in destination.parents:
        raise ValueError("Negative fixtures must be outside the source sketch")
    if not (source / "g1_motion_lab.pde").is_file():
        raise ValueError("Source is not the G1 sketch")
    if destination.name != "g1_motion_lab":
        raise ValueError("Destination must retain Processing's g1_motion_lab sketch name")
    # copytree refuses existing destinations; no force/overwrite mode is offered.
    shutil.copytree(source, destination, ignore=shutil.ignore_patterns("captures"))
    data_dir = destination / "data"
    if case in ("missing-motion", "missing-model"):
        path = data_dir / ("g1-motion.json" if case == "missing-motion" else "g1-model.json")
        path.rename(path.with_suffix(".json.disabled"))
        return
    model_case = case in ("index", "model-schema", "fractional-body", "fractional-index", "overflow-index")
    path = data_dir / ("g1-model.json" if model_case else "g1-motion.json")
    data = json.loads(path.read_text(encoding="utf-8"))
    if case in ("schema", "model-schema"):
        data["schema_version"] = 999
    elif case == "fractional-schema":
        data["schema_version"] = 1.5
    elif case == "fractional-parent":
        data["body_parents"][0] = -0.5
    elif case == "non-topological-parent":
        data["body_parents"][1] = 2
        data["body_parents"][2] = 0
    elif case == "multiple-roots":
        data["body_parents"][1] = -1
    elif case == "root-self-parent":
        data["body_parents"][0] = 0
    elif case == "missing-offsets":
        del data["body_offsets"]
    elif case == "offset-shape":
        data["body_offsets"][1].pop()
    elif case == "offset-nonfinite":
        data["body_offsets"][1][0] = 1e300  # Finite JSON number, non-finite float in the viewer.
    elif case == "offset-mismatch":
        data["body_offsets"][1][0] += 0.02
    elif case == "fractional-body":
        data["meshes"][0]["body"] = 0.5
    elif case == "fractional-index":
        data["meshes"][0]["indices"][0] = 0.5
    elif case == "overflow-index":
        data["meshes"][0]["indices"][0] = 4294967297
    elif case == "quaternion":
        data["clips"][0]["frames"][0]["rotations"][:4] = [0, 0, 0, 0]
    elif case == "index":
        data["meshes"][0]["indices"][0] = len(data["meshes"][0]["vertices"]) // 3
    elif case == "frame-size":
        data["clips"][0]["frames"][0]["positions"].pop()
    elif case == "validation-label":
        data["validation"]["label"] = "INVALID TEST LABEL"
    path.write_text(json.dumps(data, allow_nan=False, separators=(",", ":")) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    parser.add_argument("case", choices=CASES)
    args = parser.parse_args()
    make_fixture(args.source, args.destination, args.case)


if __name__ == "__main__":
    main()
