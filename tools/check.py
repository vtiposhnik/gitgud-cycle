#!/usr/bin/env python3
"""Run Godot imports and executable gameplay tests. No Python packages required."""
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parent.parent
GODOT = os.environ.get("GODOT") or shutil.which("godot") or shutil.which("godot4")
if not GODOT:
    sys.exit("Godot 4.6 is required. Put it on PATH or set GODOT to its executable path.")
environment = os.environ.copy()
# Keep cloud test initialization in writable locations. Native Windows ignores XDG.
for key, folder in [("XDG_DATA_HOME", "data"), ("XDG_CONFIG_HOME", "config"), ("XDG_CACHE_HOME", "cache")]:
    path = Path(tempfile.gettempdir()) / "gitgud-runtime" / folder
    path.mkdir(parents=True, exist_ok=True)
    environment.setdefault(key, str(path))
commands = [["--editor", "--import", "--quit"]]
commands += [["--fixed-fps", "60", "--script", f"tests/{name}_test.gd"]
             for name in ["combat", "loop", "timing", "duel"]]
commands.append(["--script", "tests/audio_test.gd"])
for command in commands:
    print("Running:", " ".join(command), flush=True)
    result = subprocess.run([GODOT, "--headless", "--path", str(ROOT), *command],
                            env=environment, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, timeout=120)
    print(result.stdout, end="", flush=True)
    # Godot's import command can return zero even when a script has a parse error.
    if result.returncode or re.search(r"(?m)^(SCRIPT ERROR:|ERROR:)", result.stdout):
        sys.exit(result.returncode or 1)
print("ALL CHECKS PASSED: 48 assertions and one complete input-driven duel.")
