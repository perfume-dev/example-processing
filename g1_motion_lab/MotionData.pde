// Copyright (c) 2026 Daito Manabe
// SPDX-License-Identifier: MIT; see LICENSE
JSONObject requiredJson(String filename) {
  if (!new java.io.File(dataPath(filename)).isFile()) {
    throw new IllegalArgumentException("Missing data/" + filename + "; install the generated, validated data package");
  }
  JSONObject json = loadJSONObject(filename);
  if (json == null) throw new IllegalArgumentException("Cannot parse " + filename);
  return json;
}

int exactInteger(Object value, String label) {
  // Processing getInt() silently truncates both Double and overflowing Long values.
  if (!(value instanceof Integer) && !(value instanceof Long)) {
    throw new IllegalArgumentException(label + " must be an exact JSON integer");
  }
  long number = ((Number) value).longValue();
  if (number < Integer.MIN_VALUE || number > Integer.MAX_VALUE) {
    throw new IllegalArgumentException(label + " is outside the 32-bit integer range");
  }
  return (int) number;
}

float[] finiteArray(JSONArray data, int expected, String label) {
  if (data == null || data.size() != expected) throw new IllegalArgumentException(label + " has the wrong array length");
  float[] values = new float[expected];
  for (int i = 0; i < expected; i++) {
    if (!(data.get(i) instanceof Number)) throw new IllegalArgumentException(label + " must contain JSON numbers");
    values[i] = data.getFloat(i);
    if (!Float.isFinite(values[i])) throw new IllegalArgumentException(label + " contains a non-finite value");
  }
  return values;
}

String[] namesArray(JSONArray array, String label) {
  if (array == null || array.size() == 0) throw new IllegalArgumentException(label + " is empty");
  String[] names = new String[array.size()];
  java.util.HashSet<String> seen = new java.util.HashSet<>();
  for (int i = 0; i < names.length; i++) {
    names[i] = array.getString(i);
    if (names[i].isEmpty() || !seen.add(names[i])) throw new IllegalArgumentException(label + " contains an empty/duplicate name");
  }
  return names;
}

int[] parentsArray(JSONArray array, int count, String label) {
  if (array == null || array.size() != count) throw new IllegalArgumentException(label + " has the wrong array length");
  int[] parents = new int[count];
  for (int i = 0; i < count; i++) parents[i] = exactInteger(array.get(i), label);
  for (int i = 0; i < count; i++) {
    if (parents[i] < -1 || parents[i] >= count || (parents[i] == i && i != 0)) {
      throw new IllegalArgumentException(label + " contains an invalid parent");
    }
    int current = i;
    for (int depth = 0; current >= 0 && parents[current] != current; depth++) {
      if (depth >= count) throw new IllegalArgumentException(label + " contains a cycle");
      current = parents[current];
      if (current >= count || current < -1) throw new IllegalArgumentException(label + " contains an invalid parent");
    }
  }
  return parents;
}

void normalizeQuaternion(float[] q, int start) {
  float length = sqrt(sq(q[start]) + sq(q[start + 1]) + sq(q[start + 2]) + sq(q[start + 3]));
  if (!Float.isFinite(length) || length < 0.00001) throw new IllegalArgumentException("Invalid zero/non-finite quaternion");
  for (int i = 0; i < 4; i++) q[start + i] /= length;
}

class G1Motion {
  final float fps;
  final String[] bodyNames;
  final int[] bodyParents;
  final float[] bodyOffsets;
  final String[] sourceNames;
  final int[] sourceParents;
  final List<MotionClip> clips = new ArrayList<>();
  final List<Integer> handBodies = new ArrayList<>();
  final int rootBody;
  final boolean poseQaPassed;

  G1Motion(JSONObject data) {
    if (exactInteger(data.get("schema_version"), "motion schema_version") != 1) throw new IllegalArgumentException("Unsupported motion schema");
    fps = data.getFloat("fps");
    if (!Float.isFinite(fps) || fps <= 0) throw new IllegalArgumentException("Invalid motion frame rate");
    JSONObject validation = data.getJSONObject("validation");
    if (!VALIDATION_LABEL.equals(validation.getString("label"))) {
      throw new IllegalArgumentException("Missing expected kinematic-reference validation label");
    }
    // Missing, pending and failed pose checks all remain diagnostic, never approved.
    poseQaPassed = "pass".equals(validation.getString("pose_status", "unknown"));
    bodyNames = namesArray(data.getJSONArray("body_names"), "body_names");
    bodyParents = parentsArray(data.getJSONArray("body_parents"), bodyNames.length, "body_parents");
    if (bodyParents[0] != -1) throw new IllegalArgumentException("body_parents must start with one root (-1)");
    for (int i = 1; i < bodyParents.length; i++) {
      if (bodyParents[i] < 0 || bodyParents[i] >= i) throw new IllegalArgumentException("body_parents must be in parent-before-child order");
    }
    JSONArray offsets = data.getJSONArray("body_offsets");
    if (offsets == null || offsets.size() != bodyNames.length) throw new IllegalArgumentException("body_offsets has the wrong array length");
    bodyOffsets = new float[bodyNames.length * 3];
    for (int i = 0; i < bodyNames.length; i++) {
      float[] xyz = finiteArray(offsets.getJSONArray(i), 3, "body_offsets XYZ");
      System.arraycopy(xyz, 0, bodyOffsets, i * 3, 3);
    }
    sourceNames = namesArray(data.getJSONArray("source_names"), "source_names");
    sourceParents = parentsArray(data.getJSONArray("source_parents"), sourceNames.length, "source_parents");
    rootBody = 0;
    // Prefer actual hand links; use wrist roll links for models without hands.
    for (String side : new String[] { "left", "right" }) {
      int candidate = -1;
      for (int i = 0; i < bodyNames.length; i++) {
        String name = bodyNames[i].toLowerCase();
        if (name.contains(side) && (name.contains("hand") || name.contains("wrist_roll"))) candidate = i;
      }
      if (candidate >= 0) handBodies.add(candidate);
    }
    JSONArray recordings = data.getJSONArray("clips");
    if (recordings == null || recordings.size() != 3) throw new IllegalArgumentException("Expected A, B and C motion clips");
    for (int i = 0; i < recordings.size(); i++) {
      MotionClip clip = new MotionClip(recordings.getJSONObject(i), bodyParents, bodyOffsets, sourceNames.length);
      if (!clip.name.equals(new String[] { "A", "B", "C" }[i])) throw new IllegalArgumentException("Clip order must be A, B, C");
      clips.add(clip);
    }
  }
}

class Pose {
  final float[] positions;
  final float[] rotations;
  final float[] localRotations;
  final float[] source;

  Pose(JSONObject frame, int bodies, int sources) {
    positions = finiteArray(frame.getJSONArray("positions"), bodies * 3, "body positions");
    rotations = finiteArray(frame.getJSONArray("rotations"), bodies * 4, "body rotations");
    localRotations = new float[bodies * 4];
    source = finiteArray(frame.getJSONArray("source_positions"), sources * 3, "source positions");
    for (int i = 0; i < rotations.length; i += 4) normalizeQuaternion(rotations, i);
  }

  Pose(int bodies, int sources) {
    positions = new float[bodies * 3];
    rotations = new float[bodies * 4];
    localRotations = new float[bodies * 4];
    source = new float[sources * 3];
  }
}

class MotionClip {
  final String name;
  final Pose[] frames;
  final Pose current;
  final Pose trailPose;
  final int[] parents;
  final float[] offsets;
  final PVector start;

  MotionClip(JSONObject clip, int[] parents, float[] offsets, int sources) {
    this.parents = parents;
    this.offsets = offsets;
    int bodies = parents.length;
    name = clip.getString("name");
    JSONArray values = clip.getJSONArray("frames");
    if (values == null || values.size() < 2) throw new IllegalArgumentException("A motion clip needs at least two frames");
    frames = new Pose[values.size()];
    for (int i = 0; i < frames.length; i++) {
      frames[i] = new Pose(values.getJSONObject(i), bodies, sources);
      RigidPoseMath.localRotations(frames[i].rotations, parents, frames[i].localRotations);
      // World key positions are evidence, not independently interpolated anchors.
      // Reject exports whose fixed hierarchy would silently change their poses.
      float[] expected = frames[i].positions.clone();
      for (int body = 1; body < bodies; body++) {
        RigidPoseMath.childPosition(expected, parents[body], frames[i].rotations, offsets, body);
        for (int axis = 0; axis < 3; axis++) {
          if (abs(expected[body * 3 + axis] - frames[i].positions[body * 3 + axis]) > 0.00002) {
            throw new IllegalArgumentException("body_offsets do not match world key positions");
          }
        }
      }
    }
    current = new Pose(bodies, sources);
    trailPose = new Pose(bodies, sources);
    start = new PVector(frames[0].positions[0], frames[0].positions[1], 0);
  }

  PVector displayOffset(int slot) {
    // Remove only the initial horizontal origin, equally for robot and source.
    return new PVector(-start.x, slot * 1.8 - start.y, 0);
  }

  float frameAt(float seconds, float fps) {
    return (seconds * fps) % frames.length;
  }

  Pose sample(float seconds, float fps) {
    sampleInto(seconds, fps, current, true);
    return current;
  }

  void sampleInto(float seconds, float fps, Pose output, boolean includeSource) {
    float frame = frameAt(seconds, fps);
    int a = floor(frame), b = min(a + 1, frames.length - 1);
    float blend = frame - a;
    RigidPoseMath.interpolate(frames[a].positions, frames[b].positions, frames[a].localRotations, frames[b].localRotations,
      parents, offsets, blend, output.positions, output.rotations);
    if (includeSource) for (int i = 0; i < output.source.length; i++) output.source[i] = lerp(frames[a].source[i], frames[b].source[i], blend);
  }

  PVector bodyPoint(float seconds, float fps, int body) {
    sampleInto(seconds, fps, trailPose, false);
    int index = body * 3;
    return new PVector(trailPose.positions[index], trailPose.positions[index + 1], trailPose.positions[index + 2]);
  }
}
