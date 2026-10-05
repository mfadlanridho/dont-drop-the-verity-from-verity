#!/usr/bin/env python3
"""Builds the stack carry animation and uploads it to Roblox through Open Cloud.

    python3 tools/carry_animation.py            build the .rbxm only
    python3 tools/carry_animation.py --upload   build, upload, print the asset id

Needs `rojo` on PATH. Uploading reads ROBLOX_OPEN_CLOUD_KEY from .env at the
repo root (a key with the Assets API, read and write) and creates the asset
under the group that owns the game. Each upload creates a new asset: put the
printed id in Config.Stack.CarryAnimationId.

R15 only. Both arms reach up to steady the bottom orb and rock gently from
side to side. Only the arms are keyed, so walk, idle and jump show through.
Keep the pose numbers in step with tools/build_carry_animation.luau, which
builds the same animation inside Studio for previewing.
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

# Shoulder: how far the upper arm swings up from hanging (180 is straight up).
RAISE = math.radians(165)
# Shoulder: how far the raised arm leans in toward the head.
TILT = math.radians(22)
# Elbow bend, bringing the hands in over the head.
ELBOW = math.radians(20)
# How far the arms rock to each side.
SWAY = math.radians(4)
LENGTH = 1.2

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


def arm(prefix, side, phase):
    """`side` is 1 for the right arm and -1 for the left; `phase` runs -1 to 1."""
    sway = SWAY * phase
    hand = pose(prefix + "Hand", IDENTITY)
    lower = pose(prefix + "LowerArm", rotate_x(ELBOW + side * sway), [hand])
    return pose(prefix + "UpperArm", multiply(rotate_z(side * TILT + sway), rotate_x(RAISE)), [lower])


def build_model():
    keyframes = []
    for index, phase in enumerate([0, 1, 0, -1, 0]):
        torso = pose("UpperTorso", children=[arm("Right", 1, phase), arm("Left", -1, phase)])
        root = pose("HumanoidRootPart", children=[pose("LowerTorso", children=[torso])])
        keyframes.append(
            {
                "ClassName": "Keyframe",
                "Name": "Keyframe",
                "Properties": {"Time": index / 4 * LENGTH},
                "Children": [root],
            }
        )
    return {
        "ClassName": "KeyframeSequence",
        "Name": "Carry",
        "Properties": {"Loop": True, "Priority": {"Enum": PRIORITY_ACTION}},
        "Children": keyframes,
    }


def build_rbxm(directory):
    (directory / "Carry.model.json").write_text(json.dumps(build_model()))
    (directory / "default.project.json").write_text(
        json.dumps({"name": "Carry", "tree": {"$path": "Carry.model.json"}})
    )
    output = directory / "Carry.rbxm"
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


def upload(rbxm, key):
    metadata = {
        "assetType": "Animation",
        "displayName": "Verity Carry",
        "description": "Don't Drop the Verity: arms-up carry loop.",
        "creationContext": {"creator": {"groupId": GROUP_ID}},
    }
    boundary = uuid.uuid4().hex
    body = b"".join(
        [
            f"--{boundary}\r\n".encode(),
            b'Content-Disposition: form-data; name="request"\r\n\r\n',
            json.dumps(metadata).encode(),
            f"\r\n--{boundary}\r\n".encode(),
            b'Content-Disposition: form-data; name="fileContent"; filename="Carry.rbxm"\r\n',
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
    with tempfile.TemporaryDirectory() as directory:
        rbxm = build_rbxm(Path(directory))
        print(f"built Carry.rbxm ({rbxm.stat().st_size} bytes)")
        if "--upload" in sys.argv:
            result = upload(rbxm, read_key())
            print(f"uploaded: asset id {result.get('assetId')} ({result.get('moderationResult', {})})")


if __name__ == "__main__":
    main()
