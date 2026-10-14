#!/usr/bin/env python3
"""One-time, bounded-cost Tripo text-to-model experiment for Aetherfall.

Produces untextured GLB prototypes; NOT fitted, rigged, or gameplay-ready.
Only run through the explicitly scoped GitHub Actions workflow.
"""
from __future__ import annotations
import hashlib
import json
import os
from pathlib import Path
import sys
import time
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

BASE = "https://api.tripo3d.ai/v2/openapi"
OUT = Path("builds/tripo-bald-bases-20261014")
MODEL_VERSION = "v3.1-20260211"
ESTIMATED_CREDITS_EACH = 10  # Base model only; verified against Oct 2026 Tripo price sheet.
NEGATIVE = ("hair, wig, beard, eyelashes as hair strands, headwear, helmets, armor, "
            "weapons, dresses, skirts, fantasy robes, jewelry, body markings, props, "
            "scenery, textures, colors, realism, photo style, exaggerated chibi head, extra limbs")
PROMPTS = {
    "male": (
        "Full-body neutral untextured 3D base mesh for an adult Japanese-anime fantasy RPG male "
        "player character. Handsome stylized masculine anime face, complete smooth bald scalp, "
        "defined eye sockets and eyelids with neutral blank irises. Muscular athletic hero build, "
        "broad shoulders, sculpted chest and arms, narrow athletic waist, powerful legs, "
        "symmetrical proportions. Neutral seamless close-fitting modest bodysuit, no sculpted "
        "clothes seams or accessories, no hair. Centered symmetrical relaxed A-pose with arms "
        "downward 40 degrees away from body, fingers separate, legs apart, feet flat. "
        "Single whole standing character, front-facing, clean game character basemesh."
    ),
    "female": (
        "Full-body neutral untextured 3D base mesh for an adult Japanese-anime fantasy RPG female "
        "player character. Attractive mature stylized anime face, complete smooth bald scalp, "
        "defined eye sockets and eyelids with neutral blank irises. Voluptuous yet athletic "
        "heroine build: fuller rounded bust, defined narrow waist, wide feminine hips, curvy "
        "thighs, natural balanced anatomy, shapely silhouette. Neutral seamless close-fitting "
        "modest bodysuit, no sculpted clothes seams or accessories, no hair. "
        "Centered symmetrical relaxed A-pose, arms downward 40 degrees away from body, "
        "fingers separate, legs apart, feet flat. Single whole standing character, "
        "front-facing, clean game character basemesh."
    ),
}


def request(path: str, key: str, payload=None):
    req = Request(
        BASE + path,
        headers={
            "Authorization": "Bearer " + key,
            "Content-Type": "application/json",
            "Accept": "application/json",
            "User-Agent": "Aetherfall-Character-Prototype/1.0",
        },
        data=(json.dumps(payload).encode("utf-8") if payload is not None else None),
        method="POST" if payload is not None else "GET",
    )
    try:
        with urlopen(req, timeout=45) as resp:
            result = json.load(resp)
    except HTTPError as e:
        raise RuntimeError(f"Tripo returned HTTP {e.code} for {path.split('/')[1]}") from None
    except (URLError, TimeoutError) as e:
        raise RuntimeError(f"Tripo network failure: {type(e).__name__}") from None
    if result.get("code") != 0:
        raise RuntimeError(f"Tripo rejected request with API code {result.get('code')}")
    return result["data"]


def save_manifest(manifest):
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


def get_balance(key):
    result = request("/user/balance", key)
    return float(result["balance"])


def poll(task_id, key, gender, seconds=960):
    deadline = time.monotonic() + seconds
    last = None
    while time.monotonic() < deadline:
        result = request("/task/" + task_id, key)
        status = result.get("status", "unknown")
        if status != last:
            print(f"TRIPO_{gender.upper()}_STATUS={status}", flush=True)
            last = status
        if status == "success":
            output = result.get("output") or {}
            url = next((output.get(n) for n in ("base_model", "model", "pbr_model") if output.get(n)), None)
            if not url:
                raise RuntimeError(f"{gender}: task succeeded without a downloadable 3D model")
            return url
        if status in ("failed", "cancelled", "banned", "expired"):
            raise RuntimeError(f"{gender}: generation ended with status {status}")
        time.sleep(16)
    raise TimeoutError(f"{gender}: generation still running after {seconds} seconds")


def download_glb(url, destination):
    # Tripo output URLs may be temporary signed links; never log them.
    req = Request(url, headers={"User-Agent": "Aetherfall-Character-Prototype/1.0"})
    with urlopen(req, timeout=120) as response, destination.open("wb") as f:
        while True:
            chunk = response.read(1024 * 1024)
            if not chunk:
                break
            f.write(chunk)
    data = destination.read_bytes()
    if len(data) < 50000 or data[:4] != b"glTF":
        destination.unlink(missing_ok=True)
        raise RuntimeError("Tripo model is not a valid GLB payload")
    return {"file": destination.name, "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def main():
    if os.environ.get("GITHUB_RUN_ATTEMPT", "1") != "1":
        raise SystemExit("SAFETY: workflow reruns are blocked to avoid duplicate credit charges.")
    key = os.environ.get("TRIPO_API_KEY", "").strip()
    if not key:
        raise SystemExit("TRIPO_API_KEY repository secret missing")
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = {
        "purpose": "non-production review only",
        "source": "new text-based Tripo prototype; NOT converted from backed-up approved GLBs",
        "model_version": MODEL_VERSION,
        "texture": False, "pbr": False, "rigged": False,
        "estimated_credits_per_model": ESTIMATED_CREDITS_EACH,
        "gender_candidates": {},
    }
    balance = get_balance(key)
    minimum = 2 * ESTIMATED_CREDITS_EACH
    if balance < minimum:
        raise SystemExit(f"Insufficient balance for two prototypes: {balance:g} available; estimated {minimum} required.")
    print(f"TRIPO_PRECHECK_OK: balance sufficient for two untextured models; estimated budget {minimum} credits.")
    save_manifest(manifest)

    # Submit exactly TWO tasks, one per character. No implicit retries and no paid downstream tasks.
    tasks = {}
    for gender, prompt in PROMPTS.items():
        payload = {
            "type": "text_to_model",
            "model_version": MODEL_VERSION,
            "prompt": prompt,
            "negative_prompt": NEGATIVE,
            "texture": False,
            "pbr": False,
            "geometry_quality": "standard",
            "quad": False,
        }
        response = request("/task", key, payload)
        task_id = response.get("task_id")
        if not task_id:
            raise RuntimeError(f"Tripo did not supply task_id for {gender}")
        tasks[gender] = task_id
        manifest["gender_candidates"][gender] = {"task_id": task_id, "status": "submitted", "prompt": prompt}
        save_manifest(manifest)
        print(f"TRIPO_{gender.upper()}_TASK_SUBMITTED={task_id}", flush=True)

    errors = []
    for gender, task_id in tasks.items():
        try:
            url = poll(task_id, key, gender)
            fileinfo = download_glb(url, OUT / f"aetherfall_{gender}_bald_candidate.glb")
            manifest["gender_candidates"][gender].update(fileinfo)
            manifest["gender_candidates"][gender]["status"] = "downloaded"
            print(f"TRIPO_{gender.upper()}_GLB_READY={fileinfo['bytes']}bytes", flush=True)
        except Exception as e:
            manifest["gender_candidates"][gender]["status"] = "error"
            errors.append(f"{gender}: {e}")
            print(f"TRIPO_{gender.upper()}_ERROR={type(e).__name__}", flush=True)
        finally:
            save_manifest(manifest)

    if errors:
        raise SystemExit("; ".join(errors))
    print("TRIPO_TWO_BARE_BASE_CANDIDATES_READY: review before any Godot or Configura import")


if __name__ == "__main__":
    main()
