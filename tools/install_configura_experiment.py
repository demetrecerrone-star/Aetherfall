#!/usr/bin/env python3
"""Install the pinned Configura addon without its large bundled examples.

This is a deliberately isolated feasibility experiment. For a source checkout:
  git submodule update --init third_party/configura
  python3 tools/install_configura_experiment.py
"""
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "third_party/configura/addons/Configura"
TARGET = ROOT / "addons/Configura"

def main() -> None:
    if not (SOURCE / "plugin.cfg").is_file():
        raise SystemExit("Configura submodule missing. Run: git submodule update --init third_party/configura")
    if TARGET.exists():
        raise SystemExit("addons/Configura already exists; refusing to replace an existing addon.")
    TARGET.parent.mkdir(parents=True, exist_ok=True)
    shutil.copytree(
        SOURCE, TARGET,
        ignore=shutil.ignore_patterns("!example", "*.blend", "*.blend1", "*.import", ".DS_Store"),
    )
    required = [
        TARGET / "plugin.cfg",
        TARGET / "configura_plugin.gd",
        TARGET / "data/character_config.gd",
        TARGET / "data/character_state.gd",
        TARGET / "runtime/creator_manager.gd",
    ]
    for path in required:
        if not path.is_file():
            raise SystemExit("Configura install incomplete: " + str(path))
    print("AETHERFALL_CONFIGURA_ADDON_STAGED: pinned upstream source, demo assets excluded")

if __name__ == "__main__":
    main()
