#!/usr/bin/env python3
"""Builds a stack carry animation and uploads it to Roblox through Open Cloud.

    python3 tools/carry_animation.py Carry            build the .rbxm only
    python3 tools/carry_animation.py Strain --upload  build, upload, print the asset id

Needs `rojo` on PATH. Uploading reads ROBLOX_OPEN_CLOUD_KEY from .env at the
repo root (a key with the Assets API, read and write) and creates the asset
under the group that owns the game. Each upload creates a new asset: put the
printed id in Config.Stack.CarryAnimationId or StrainAnimationId.

R15 only. Only the upper body is keyed, so walk, idle and jump show through.
Carry: both arms reach up to steady the bottom orb and rock gently.
Strain: the same hold with the torso hunched, the head tucked and the arms
trembling. CarryController cross-fades from Carry to Strain as the stack fills.
Keep the pose numbers in step with tools/build_carry_animation.luau, which
builds the same animations inside Studio for previewing.
"""

import json
import math
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
import uuid
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
GROUP_ID = "613837"
API = "https://apis.roblox.com/assets/v1"

# Angles in degrees.
# Raise: how far the upper arm swings up from hanging (180 is straight up the torso).
# Tilt: how far the raised arm leans in toward the head.
# Elbow: elbow bend, bringing the hands in over the head.
# Sway: how far the arms rock to each side over one loop.
# Lean: how far the torso hunches forward. Tuck: how far the head drops.
ANIMATIONS = {
    "Carry": dict(Length=1.2, Raise=165, Tilt=22, Elbow=20, Sway=4, Lean=0, Tuck=0),
    "Strain": dict(Length=0.3, Raise=152, Tilt=26, Elbow=30, Sway=2.5, Lean=14, Tuck=12),
}

# Enum values: AnimationPriority.Action, PoseEasingStyle.Cubic, PoseEasingDirection.InOut.
PRIORITY_ACTION = 2
EASING_CUBIC = 3
EASING_IN_OUT = 2

IDENTITY = [[1, 0, 0], [0, 1, 0], [0, 0, 1]]


def rotate_x(angle):
    c, s = math.cos(angle), math.sin(angle)
    return [[1, 0, 0], [0, c, -s], [0, s, c]]


def rotate_z(angle):
    c, s = math.cos(angle), math.sin(angle)
    return [[c, -s, 0], [s, c, 0], [0, 0, 1]]


def multiply(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def pose(name, rotation=None, children=()):
    # Weight 0 leaves a joint to whatever else is playing.
    return {
        "ClassName": "Pose",
        "Name": name,
        "Properties": {
            "Weight": 1 if rotation else 0,
            "CFrame": {"CFrame": {"position": [0, 0, 0], "orientation": rotation or IDENTITY}},
            "EasingStyle": {"Enum": EASING_CUBIC},
            "EasingDirection": {"Enum": EASING_IN_OUT},
        },
        "Children": list(children),
    }


def arm(spec, prefix, side, sway):
    """`side` is 1 for the right arm and -1 for the left."""
    raise_, tilt, elbow = (math.radians(spec[key]) for key in ("Raise", "Tilt", "Elbow"))
    hand = pose(prefix + "Hand", IDENTITY)
    lower = pose(prefix + "LowerArm", rotate_x(elbow + side * sway), [hand])
    return pose(prefix + "UpperArm", multiply(rotate_z(side * tilt + sway), rotate_x(raise_)), [lower])


def build_model(name):
    spec = ANIMATIONS[name]
    keyframes = []
    for index, phase in enumerate([0, 1, 0, -1, 0]):
        sway = math.radians(spec["Sway"]) * phase
        children = [arm(spec, "Right", 1, sway), arm(spec, "Left", -1, sway)]
        if spec["Tuck"]:
            children.insert(0, pose("Head", rotate_x(-math.radians(spec["Tuck"]))))
        torso = pose("UpperTorso", rotate_x(-math.radians(spec["Lean"])) if spec["Lean"] else None, children)
        root = pose("HumanoidRootPart", children=[pose("LowerTorso", children=[torso])])
        keyframes.append(
            {
                "ClassName": "Keyframe",
                "Name": "Keyframe",
                "Properties": {"Time": index / 4 * spec["Length"]},
                "Children": [root],
            }
        )
    return {
        "ClassName": "KeyframeSequence",
        "Name": name,
        "Properties": {"Loop": True, "Priority": {"Enum": PRIORITY_ACTION}},
        "Children": keyframes,
    }


def build_rbxm(name, directory):
    (directory / f"{name}.model.json").write_text(json.dumps(build_model(name)))
    (directory / "default.project.json").write_text(
        json.dumps({"name": name, "tree": {"$path": f"{name}.model.json"}})
    )
    output = directory / f"{name}.rbxm"
    subprocess.run(["rojo", "build", str(directory), "-o", str(output)], check=True, capture_output=True)
    return output


def read_key():
    for line in (REPO / ".env").read_text().splitlines():
        name, _, value = line.partition("=")
        if name.strip() == "ROBLOX_OPEN_CLOUD_KEY":
            return value.strip().strip("\"'")
    sys.exit("ROBLOX_OPEN_CLOUD_KEY is not set in .env")


def call(request):
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            return json.loads(response.read())
    except urllib.error.HTTPError as error:
        sys.exit(f"Roblox returned {error.code}: {error.read().decode(errors='replace')}")


def upload(name, rbxm, key):
    metadata = {
        "assetType": "Animation",
        "displayName": f"Verity {name}",
        "description": f"Don't Drop the Verity: stack {name.lower()} loop.",
        "creationContext": {"creator": {"groupId": GROUP_ID}},
    }
    boundary = uuid.uuid4().hex
    body = b"".join(
        [
            f"--{boundary}\r\n".encode(),
            b'Content-Disposition: form-data; name="request"\r\n\r\n',
            json.dumps(metadata).encode(),
            f"\r\n--{boundary}\r\n".encode(),
            b'Content-Disposition: form-data; name="fileContent"; filename="animation.rbxm"\r\n',
            b"Content-Type: model/x-rbxm\r\n\r\n",
            rbxm.read_bytes(),
            f"\r\n--{boundary}--\r\n".encode(),
        ]
    )
    operation = call(
        urllib.request.Request(
            f"{API}/assets",
            data=body,
            headers={"x-api-key": key, "Content-Type": f"multipart/form-data; boundary={boundary}"},
        )
    )

    for _ in range(30):
        if operation.get("done"):
            break
        time.sleep(2)
        operation = call(
            urllib.request.Request(f"{API}/operations/{operation['operationId']}", headers={"x-api-key": key})
        )
    if not operation.get("done"):
        sys.exit(f"Upload did not finish: {operation}")
    if "response" not in operation:
        sys.exit(f"Upload failed: {operation}")
    return operation["response"]


def main():
    names = [argument for argument in sys.argv[1:] if not argument.startswith("--")]
    if len(names) != 1 or names[0] not in ANIMATIONS:
        sys.exit(f"usage: carry_animation.py {'|'.join(ANIMATIONS)} [--upload]")
    name = names[0]

    with tempfile.TemporaryDirectory() as directory:
        rbxm = build_rbxm(name, Path(directory))
        print(f"built {name}.rbxm ({rbxm.stat().st_size} bytes)")
        if "--upload" in sys.argv:
            result = upload(name, rbxm, read_key())
            print(f"uploaded {name}: asset id {result.get('assetId')} ({result.get('moderationResult', {})})")


if __name__ == "__main__":
    main()
