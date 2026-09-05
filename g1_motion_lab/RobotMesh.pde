// Copyright (c) 2026 Daito Manabe
// SPDX-License-Identifier: MIT; see LICENSE
PMatrix3D rigidTransform(float[] position, int p, float[] quaternion, int q) {
  float w = quaternion[q], x = quaternion[q + 1], y = quaternion[q + 2], z = quaternion[q + 3];
  return new PMatrix3D(
    1 - 2 * (y*y + z*z), 2 * (x*y - z*w), 2 * (x*z + y*w), position[p],
    2 * (x*y + z*w), 1 - 2 * (x*x + z*z), 2 * (y*z - x*w), position[p + 1],
    2 * (x*z - y*w), 2 * (y*z + x*w), 1 - 2 * (x*x + y*y), position[p + 2],
    0, 0, 0, 1);
}

class RobotMesh {
  final int body;
  final PShape shape;
  final PMatrix3D localTransform;

  RobotMesh(JSONObject mesh, int bodyCount) {
    body = exactInteger(mesh.get("body"), "mesh body");
    if (body < 0 || body >= bodyCount) throw new IllegalArgumentException("Mesh references an invalid body");
    JSONArray vertices = mesh.getJSONArray("vertices");
    if (vertices == null || vertices.size() < 9 || vertices.size() % 3 != 0) throw new IllegalArgumentException("Invalid mesh vertices");
    float[] positions = finiteArray(vertices, vertices.size(), "mesh vertices");
    JSONArray triangles = mesh.getJSONArray("indices");
    if (triangles == null || triangles.size() == 0 || triangles.size() % 3 != 0) throw new IllegalArgumentException("Invalid mesh triangles");
    float[] offset = finiteArray(mesh.getJSONArray("position"), 3, "mesh position");
    float[] rotation = finiteArray(mesh.getJSONArray("quaternion"), 4, "mesh quaternion");
    normalizeQuaternion(rotation, 0);
    localTransform = rigidTransform(offset, 0, rotation, 0);
    float[] material = finiteArray(mesh.getJSONArray("color"), 4, "mesh color");
    for (float component : material) if (component < 0 || component > 1) throw new IllegalArgumentException("Mesh color must be in 0..1");
    float brightness = (material[0] + material[1] + material[2]) / 3;
    int ink = brightness < 0.28 ? color(44, 53, 61) : color(224, 230, 229);
    shape = createShape();
    shape.beginShape(TRIANGLES);
    shape.noStroke();
    shape.fill(ink);
    shape.ambient(ink);
    shape.specular(90);
    shape.shininess(12);
    for (int i = 0; i < triangles.size(); i += 3) {
      PVector[] corners = new PVector[3];
      for (int k = 0; k < 3; k++) {
        int index = exactInteger(triangles.get(i + k), "triangle index");
        if (index < 0 || index >= positions.length / 3) throw new IllegalArgumentException("Triangle index is out of bounds");
        corners[k] = new PVector(positions[index * 3], positions[index * 3 + 1], positions[index * 3 + 2]);
      }
      PVector normal = PVector.sub(corners[1], corners[0]).cross(PVector.sub(corners[2], corners[0]));
      if (normal.magSq() < 0.000000000001) continue;
      normal.normalize();
      shape.normal(normal.x, normal.y, normal.z);
      for (PVector point : corners) shape.vertex(point.x, point.y, point.z);
    }
    shape.endShape();
    if (shape.getVertexCount() == 0) throw new IllegalArgumentException("Mesh contains no drawable triangles");
  }

  void draw(Pose pose) {
    pushMatrix();
    applyMatrix(rigidTransform(pose.positions, body * 3, pose.rotations, body * 4));
    applyMatrix(localTransform);
    shape(shape);
    popMatrix();
  }
}
