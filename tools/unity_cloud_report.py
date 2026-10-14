#!/usr/bin/env python3
"""Read-only Unity Build Automation build report for Aetherfall.

Never prints credential values, raw API JSON, full logs, or signed artifact URLs.
The GitHub Actions summary is public because the repository is public.
"""
import argparse
import base64
import json
import os
import re
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone
from urllib.parse import quote

API = "https://build-automation.services.api.unity.com/v2"
DASHBOARD = (
    "https://cloud.unity.com/organizations/2476066025878/"
    "projects/92204c56-3bcf-41b8-8eec-43d1069287a1/"
    "cloud-build/buildtargets/aetherfall-android"
)
MAX_BYTES = 2_000_000
ALLOWED_ID = re.compile(r"^[A-Za-z0-9_.-]+$")
CODE_PATTERN = re.compile(
    r"\\b(?:CS[0-9]{4}|IL2CPP|Gradle|IOException|BuildFailedException|"
    r"Unauthorized|PackageManager|NullReferenceException)\\b",
    re.IGNORECASE,
)


class UnityApiError(Exception):
    pass


def safe_id(value):
    if not value or not ALLOWED_ID.fullmatch(value):
        raise ValueError("Unity API identifier contains unsupported characters")
    return quote(value, safe="")


def get_json(url, key_id, secret):
    auth = base64.b64encode((key_id + ":" + secret).encode("utf-8")).decode("ascii")
    request = urllib.request.Request(
        url,
        headers={
            "Authorization": "Basic " + auth,
            "Accept": "application/json",
            "User-Agent": "aetherfall-unity-status-reporter/1",
        },
        method="GET",
    )
    try:
        with urllib.request.urlopen(request, timeout=25) as response:
            raw = response.read(MAX_BYTES + 1)
        if len(raw) > MAX_BYTES:
            raise UnityApiError("Response exceeds safe size limit")
        return json.loads(raw)
    except urllib.error.HTTPError as err:
        # Never print err.body, err.url, raw credentials, or API response headers.
        raise UnityApiError("Unity API returned HTTP " + str(err.code)) from None
    except urllib.error.URLError:
        raise UnityApiError("Unity API could not be reached") from None
    except (ValueError, UnicodeError, json.JSONDecodeError):
        raise UnityApiError("Unity API returned an unexpected response") from None


def build_list(obj):
    if isinstance(obj, list):
        return [v for v in obj if isinstance(v, dict)]
    if isinstance(obj, dict):
        for key in ("builds", "results", "items", "data"):
            val = obj.get(key)
            if isinstance(val, list):
                return [v for v in val if isinstance(v, dict)]
        if "build" in obj and "buildStatus" in obj:
            return [obj]
    return []


def build_number(obj):
    for key in ("build", "buildNumber", "number"):
        value = obj.get(key)
        if str(value).isdigit():
            return int(value)
    return -1


def short_text(value, max_len=95):
    text = str(value)
    # Only allow simple metadata through the public summary.
    text = re.sub(r"[^a-zA-Z0-9 /_.:,()\\-]", "", text)
    return text[:max_len]


def error_codes(payload):
    # Deliberately only emit whitelisted error identifiers, not raw error messages.
    raw = json.dumps(payload, ensure_ascii=True)[:MAX_BYTES]
    return list(dict.fromkeys(m.group(0) for m in CODE_PATTERN.finditer(raw)))[:8]


def make_summary(build, chosen, org, project, target):
    status = short_text(build.get("buildStatus") or build.get("status") or "Unknown")
    platform = short_text(build.get("platform") or build.get("platformName") or "Android")
    result = [
        "## Aetherfall Unity Cloud build report",
        "",
        "**Build #" + str(chosen) + ": " + status + "**",
        "",
        "- Target: \`" + short_text(target) + "\`",
        "- Platform: " + platform,
        "- API version: Build Automation v2 (read-only)",
        "- Checked: " + datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC"),
        "- Build page: " + DASHBOARD + "/builds/" + str(chosen),
    ]
    for field, label in (
        ("buildStartTime", "Started"), ("buildEndTime", "Finished"),
        ("totalTime", "Elapsed time"), ("branch", "Branch"),
    ):
        if build.get(field) is not None:
            result.append("- " + label + ": " + short_text(build[field]))
    failure = build.get("failureDetails", [])
    if isinstance(failure, (list, dict)) and failure:
        count = len(failure) if isinstance(failure, list) else len(failure.keys())
        result.append("- Failure detail entries: " + str(count))
        codes = error_codes(failure)
        if codes:
            result.append("- Recognized error identifiers: " + ", ".join(codes))
    links = build.get("links", {})
    artifacts = build.get("artifacts", [])
    if isinstance(artifacts, list) and artifacts:
        result.append("- Artifact metadata: available (open the Unity build page to download)")
    elif isinstance(links, dict) and links.get("artifacts") is not None:
        result.append("- Artifact link metadata: present; check the Unity Artifacts tab")
    else:
        result.append("- Artifacts: not confirmed by this response")
    result += [
        "",
        "Full Unity logs and authenticated APK download links stay inside Unity Cloud.",
        "This report intentionally excludes raw logs, secret values, and signed URLs.",
    ]
    return "\\n".join(result).replace("\\n", "\n") + "\n"


def report(message):
    print(message)
    location = os.getenv("GITHUB_STEP_SUMMARY")
    if location:
        with open(location, "a", encoding="utf-8") as output:
            output.write(message + ("" if message.endswith("\n") else "\n"))


def self_test():
    assert build_number({"build": 7}) == 7
    assert build_number({"buildNumber": "19"}) == 19
    assert len(build_list({"builds": [{"build": 1}]})) == 1
    assert error_codes({"message": "Assets/A.cs: error CS0103: example.com?token=secret"}) == ["CS0103"]
    test = make_summary(
        {"buildStatus": "failure", "failureDetails": ["error CS0103: secret=mykey"]},
        1, "org", "project", "aetherfall-android",
    )
    assert "CS0103" in test and "mykey" not in test and "secret=" not in test
    try:
        safe_id("../../etc/passwd")
        raise AssertionError("Invalid identifier was accepted")
    except ValueError:
        pass
    print("PASS: Unity status parsing, safe output, and identifier validation")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--build", default="latest", help="Build number or latest")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return 0

    key_id = os.getenv("UNITY_SERVICE_ACCOUNT_KEY_ID", "").strip()
    secret = os.getenv("UNITY_SERVICE_ACCOUNT_SECRET_KEY", "").strip()
    if not key_id or not secret:
        report(
            "## Aetherfall Unity Cloud reporting needs authorization\n\n"
            "Add the repository Actions secrets "
            "\`UNITY_SERVICE_ACCOUNT_KEY_ID\` and "
            "\`UNITY_SERVICE_ACCOUNT_SECRET_KEY\`, then rerun this workflow.\n\n"
            "No Unity build was started or modified.\n"
        )
        print("::notice::Unity service-account secrets are not configured")
        return 0

    org = safe_id(os.getenv("UNITY_CLOUD_ORG_ID", ""))
    project = safe_id(os.getenv("UNITY_CLOUD_PROJECT_ID", ""))
    target = safe_id(os.getenv("UNITY_CLOUD_TARGET_ID", ""))
    base = API + "/orgs/" + org + "/projects/" + project + "/buildtargets/" + target + "/builds"

    try:
        selected = args.build.strip() or "latest"
        if selected.lower() == "latest":
            recent = build_list(get_json(base + "?per_page=20", key_id, secret))
            if not recent:
                raise UnityApiError("No builds were returned for this target")
            chosen = max(build_number(b) for b in recent)
            if chosen < 0:
                raise UnityApiError("Could not identify a build number")
        elif selected.isdigit() and int(selected) > 0:
            chosen = int(selected)
        else:
            raise ValueError("Build number must be a positive integer or latest")

        endpoint = base + "/" + str(chosen)
        try:
            details = get_json(
                endpoint + "?include=failureDetails&include=links.artifacts",
                key_id, secret,
            )
        except UnityApiError as err:
            if str(err) not in ("Unity API returned HTTP 400", "Unity API returned HTTP 422"):
                raise
            details = get_json(endpoint, key_id, secret)
        if not isinstance(details, dict):
            raise UnityApiError("Build metadata was not an object")
        report(make_summary(details, chosen, org, project, target))
        return 0
    except (UnityApiError, ValueError) as err:
        message = (
            "## Aetherfall Unity Cloud API check needs attention\n\n"
            + short_text(str(err), 150)
            + ".\n\nCheck the service-account project role, GitHub secrets, "
            "and Unity organization/project identifiers. No credentials are printed.\n"
        )
        report(message)
        print("::error::Unity Cloud build lookup failed; see safe job summary")
        return 1


if __name__ == "__main__":
    sys.exit(main())
