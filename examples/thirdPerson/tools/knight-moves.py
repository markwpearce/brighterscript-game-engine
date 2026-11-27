# Keys the moves Flare's knight doesn't have (a roll, a backstep and a side-step strafe) onto its
# rig, as new frames after its own. Run with Blender 5 on the converted files (see README):
#
#   Blender -b --python tools/knight-moves.py -- <converted>
#
# Poses the rig in steel_armor.blend, keys frames 41-60 of its action, and keys the same frames
# into male_head1.blend, longsword.blend and shield.blend: each of those has its own copy of the
# rig (same bones and rotations, at twice the size in the sword's and shield's), which
# render-character.py keeps in step by playing the same frame. Saves the files in place.
#
# Each pose starts from one of Flare's frames and turns bones in the rig's space: x is the
# knight's left, -y his front, z up.
import math
import os
import sys

import bpy
from bpy_extras import anim_utils
from mathutils import Matrix, Vector

FILES = ["steel_armor.blend", "male_head1.blend", "longsword.blend", "shield.blend"]
RIG = "MaleArm"
ARMS = ("Upperarm", "Forearm", "Hand", "Fingers", "Thumb")
FEET = ["Foot.Left", "Foot.Right", "Toes.Left", "Toes.Right"]
SIDES = {"L": "Left", "R": "Right"}
# Flare's idle, and the block (shield raised)
IDLE, GUARD = 1, 17
ROLL, BACKSTEP, STRAFE = 41, 49, 53

X, Y = Vector((1, 0, 0)), Vector((0, 1, 0))


class Pose:
    def __init__(self, rig):
        self.rig = rig

    def bone(self, name):
        return self.rig.pose.bones[name]

    def turn(self, name, axis, degrees, pivot=None):
        """Turns a bone (and so everything below it) about an axis through its head, or `pivot`."""
        pb = self.bone(name)
        m = pb.matrix.copy()
        p = m.translation.copy() if pivot is None else pivot
        pb.matrix = Matrix.Translation(p) @ Matrix.Rotation(math.radians(degrees), 4, axis) @ Matrix.Translation(-p) @ m
        bpy.context.view_layer.update()

    def move(self, offset):
        pb = self.bone("Back")
        pb.matrix = Matrix.Translation(Vector(offset)) @ pb.matrix
        bpy.context.view_layer.update()

    def bend(self, degrees):
        """Bends forward at the waist, leaving the legs as they were."""
        waist = self.bone("Hip").head.copy()
        self.turn("Back", X, degrees, waist)
        self.turn("Hip", X, -degrees, waist)

    def leg(self, side, lift=0.0, knee=0.0, out=0.0, flat=True):
        """Lifts a thigh forward, bends the knee, swings the leg out to the knight's right
        (negative: his left), keeping the foot level."""
        s = SIDES[side]
        self.turn("Thigh." + s, Y, out)
        self.turn("Thigh." + s, X, -lift)
        self.turn("Shin." + s, X, knee)
        if flat:
            self.turn("Foot." + s, X, lift - knee)
            self.turn("Foot." + s, Y, -out)

    def straighten(self):
        """Stands both legs straight under the hips, feet level, as in the rest pose."""
        for s in SIDES.values():
            for part in ("Thigh", "Shin", "Foot", "Toes"):
                self.bone(part + "." + s).rotation_quaternion = (1, 0, 0, 0)
        bpy.context.view_layer.update()

    def lowest(self, names):
        return min(min(self.bone(n).head.z, self.bone(n).tail.z) for n in names)

    def ground(self, z, names=FEET, lift=0.0):
        """Moves the body so the lowest of `names` sits at z (plus lift)."""
        self.move((0, 0, z + lift - self.lowest(names)))

    def roll(self, degrees, z, radius):
        """Turns the whole body forward about its middle, held radius above z."""
        middle = (self.bone("Back").head + self.bone("Hip").tail) / 2
        self.turn("Back", X, degrees, middle)
        self.move((-middle.x, -middle.y, z + radius - middle.z))


def frame_values(rig, frame):
    bpy.context.scene.frame_set(int(frame), subframe=frame - int(frame))
    return {pb.name: (pb.location.copy(), pb.rotation_quaternion.copy(), pb.scale.copy()) for pb in rig.pose.bones}


def set_values(rig, values):
    for pb in rig.pose.bones:
        pb.location, pb.rotation_quaternion, pb.scale = values[pb.name]
    bpy.context.view_layer.update()


def is_arm(name):
    return name.startswith(ARMS)


def lerp(a, b, t):
    return a + (b - a) * t


# Each move is a list of (base frame, arms frame, function posing it)
def roll_frames(z):
    def crouch(bend, lift, knee):
        def pose(p):
            p.bend(bend)
            p.leg("L", lift, knee)
            p.leg("R", lift, knee)
            p.ground(z)
        return pose

    def tucked(degrees):
        def pose(p):
            p.bend(60)
            p.leg("L", 120, 140, flat=False)
            p.leg("R", 110, 130, flat=False)
            p.roll(degrees, z, 0.42)
            p.ground(z, [pb.name for pb in p.rig.pose.bones], 0.08)
        return pose

    return [
        (IDLE, GUARD, crouch(35, 60, 90)),
        (IDLE, GUARD, tucked(50)),
        (IDLE, GUARD, tucked(115)),
        (IDLE, GUARD, tucked(180)),
        (IDLE, GUARD, tucked(245)),
        (IDLE, GUARD, tucked(310)),
        (IDLE, GUARD, crouch(40, 85, 120)),
        (IDLE, GUARD, crouch(20, 45, 70)),
    ]


def backstep_frames(z):
    # Each leg is (thigh lifted forward, knee bend), from Flare's guard stance: left foot forward
    def step(bend, left, right, lift=0.0):
        def pose(p):
            p.bend(bend)
            p.leg("L", *left)
            p.leg("R", *right)
            p.ground(z, lift=lift)
        return pose

    return [
        (GUARD, GUARD, step(8, (10, 25), (10, 25))),
        (GUARD, GUARD, step(-5, (30, 35), (-15, 10), 0.12)),
        (GUARD, GUARD, step(10, (15, 35), (-5, 30))),
        (GUARD, GUARD, step(4, (5, 15), (5, 15))),
    ]


# A side-step to the knight's right, 8 frames a cycle: the right foot steps out while the left
# pushes, then the left closes in. Played backwards it steps to the left.
LEG = 0.95
# How far each foot reaches past its hip: in, closing up, and out, stepping wide
NEAR, FAR = 0.06, 0.4


def strafe_frames(z):
    def pose_at(i):
        # Each foot's offset to the right of its hip, and how high it's lifted (0..1). A planted
        # foot slides left under the body as it moves right; a lifted one swings right.
        t = (i % 4) / 4
        swing, up = lerp(0, 1, (1 - math.cos(math.pi * t)) / 2), math.sin(math.pi * t)
        if i < 4:
            right, right_up = lerp(-NEAR, FAR, swing), up
            left, left_up = lerp(NEAR, -FAR, t), 0.0
        else:
            right, right_up = lerp(FAR, -NEAR, t), 0.0
            left, left_up = lerp(-FAR, NEAR, swing), up

        def pose(p):
            p.straighten()
            for side, offset, up in (("R", right, right_up), ("L", left, left_up)):
                p.leg(side, 10 + 35 * up, 20 + 55 * up, math.degrees(math.asin(offset / LEG)))
            p.ground(z)
        return pose

    return [(IDLE, IDLE, pose_at(i)) for i in range(8)]


def make_keys(rig):
    """{frame: bone values} for every new frame"""
    rig.data.pose_position = "POSE"
    bpy.context.scene.frame_set(IDLE)
    base_pose = Pose(rig)
    z = base_pose.lowest(FEET)
    action = rig.animation_data.action
    sources = {}
    moves = [(ROLL, roll_frames(z)), (BACKSTEP, backstep_frames(z)), (STRAFE, strafe_frames(z))]
    for _, frames in moves:
        for base, arms, _ in frames:
            for f in (base, arms):
                if f not in sources:
                    sources[f] = frame_values(rig, f)
    rig.animation_data.action = None
    keys = {}
    for start, frames in moves:
        for i, (base, arms, pose) in enumerate(frames):
            values = {name: (sources[arms] if is_arm(name) else sources[base])[name] for name in sources[base]}
            set_values(rig, values)
            pose(Pose(rig))
            keys[start + i] = frame_values(rig, start + i)
    rig.animation_data.action = action
    return keys


def fcurves(rig):
    action = rig.animation_data.action
    slot = rig.animation_data.action_slot
    return anim_utils.action_get_channelbag_for_slot(action, slot).fcurves


def write_keys(rig, keys, scale):
    curves = fcurves(rig)
    for frame, values in keys.items():
        for name, (loc, rot, size) in values.items():
            if name == "Back":
                loc = loc * scale
            for prop, vector in (("location", loc), ("rotation_quaternion", rot), ("scale", size)):
                for i, value in enumerate(vector):
                    path = 'pose.bones["%s"].%s' % (name, prop)
                    curve = curves.find(path, index=i) or curves.new(path, index=i, group_name=name)
                    curve.keyframe_points.insert(frame, value).interpolation = "LINEAR"
    for curve in curves:
        curve.update()


def main():
    folder = sys.argv[sys.argv.index("--") + 1]
    keys, back = None, None
    for filename in FILES:
        bpy.ops.wm.open_mainfile(filepath=os.path.join(folder, filename))
        rig = bpy.data.objects[RIG]
        length = rig.data.bones["Back"].length
        if keys is None:
            keys, back = make_keys(rig), length
        write_keys(rig, keys, length / back)
        bpy.ops.wm.save_mainfile()
        print("KEYED %s frames %d-%d" % (filename, min(keys), max(keys)))


main()
