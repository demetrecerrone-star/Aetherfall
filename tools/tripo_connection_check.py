#!/usr/bin/env python3
"""Read-only Tripo API credential check for the Aetherfall experiment branch.

Only calls account balance GET endpoints; never creates a billable generation task.
Never prints the API key, the account balance, or response bodies.
"""
import json
import os
import sys
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

ENDPOINTS = (
    ("v3", "https://openapi.tripo3d.ai/v3/account/balance"),
    ("v2", "https://api.tripo3d.ai/v2/openapi/user/balance"),
)


def check_connection() -> int:
    key = os.environ.get("TRIPO_API_KEY", "").strip()
    if not key:
        print("ERROR: GitHub Actions secret TRIPO_API_KEY is missing or empty.")
        return 1

    outcomes = []
    for version, endpoint in ENDPOINTS:
        request = Request(
            endpoint,
            headers={
                "Authorization": f"Bearer {key}",
                "Accept": "application/json",
                "User-Agent": "Aetherfall-Tripo-Connection-Check/1.0",
            },
            method="GET",
        )
        try:
            with urlopen(request, timeout=20) as response:
                status = response.status
                payload = json.loads(response.read().decode("utf-8"))
        except HTTPError as exc:
            outcomes.append(f"{version}: HTTP {exc.code}")
            continue
        except (URLError, TimeoutError, OSError) as exc:
            outcomes.append(f"{version}: network error ({type(exc).__name__})")
            continue
        except (ValueError, UnicodeError):
            outcomes.append(f"{version}: invalid JSON response")
            continue

        if status == 200 and isinstance(payload, dict) and payload.get("code") == 0 and isinstance(payload.get("data"), dict) and "balance" in payload["data"]:
            print(f"SUCCESS: Tripo {version} API key is valid; read-only account endpoint is accessible.")
            print("No model was generated, no account balance was printed, and no credits were consumed by generation.")
            return 0

        api_code = payload.get("code") if isinstance(payload, dict) else None
        outcomes.append(f"{version}: HTTP {status}, API code {api_code!r}")

    print("ERROR: Tripo credential check failed (" + "; ".join(outcomes) + ").")
    print("Confirm the repository secret is named TRIPO_API_KEY and contains a Tripo API key (not a client ID).")
    return 1


if __name__ == "__main__":
    sys.exit(check_connection())
