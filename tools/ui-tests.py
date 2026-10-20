#!/usr/bin/env python3
"""Runs the UI tests of Haylen Runner on an Apple simulator with the probe app of `ui-tests/probe`.

It serves the probe with "haylen serve", hands its address and its folder to the tests through the prefix "TEST_RUNNER_" of xcodebuild, runs "haylen test --ui" with the options it does not know, such as "--platform" and "--device", and stops the server at the end. It uses the standard library of Python alone.
"""

from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
import threading
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PROBE = ROOT / "ui-tests" / "probe"
ADDRESS = re.compile(r"http://\S+/haylen/[0-9a-f]+/app\.zip")
# How long the server may take to print its address, since it compiles the shaders of the probe first.
SERVE_SECONDS = 120


def relay(stream) -> None:
    for line in stream:
        print(line, end="", flush=True)


def main(arguments: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Run the UI tests of Haylen Runner on an Apple simulator with the probe app. Every other option goes to \"haylen test --ui\", such as \"--platform\" and \"--device\".")
    parser.add_argument("--haylen", default="haylen", help="The command haylen of a checkout of Haylen, \"haylen\" on the path by default.")
    parser.add_argument("--port", default="8791", help="The port that serves the probe, 8791 by default.")
    options, rest = parser.parse_known_args(arguments)
    command = shutil.which(options.haylen)
    if command is None:
        print(f'The command "{options.haylen}" is not on the path. Put the root of a checkout of Haylen on the path, or name its command haylen with "--haylen".', file=sys.stderr)
        return 1

    server = subprocess.Popen([command, "serve", str(PROBE), "--port", options.port], stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, env={**os.environ, "NO_COLOR": "1"})
    try:
        deadline = time.monotonic() + SERVE_SECONDS
        address = None
        while address is None and time.monotonic() < deadline:
            line = server.stdout.readline()
            if not line:
                break
            print(line, end="", flush=True)
            found = ADDRESS.search(line)
            address = found[0] if found else None
        if address is None:
            print(f"The probe was not served within {SERVE_SECONDS} seconds.", file=sys.stderr)
            return 1
        # The server prints what the probe did while the tests run.
        threading.Thread(target=relay, args=(server.stdout,), daemon=True).start()
        environment = {**os.environ, "TEST_RUNNER_RUNNER_ADDRESS": address, "TEST_RUNNER_RUNNER_PROBE": str(PROBE)}
        return subprocess.run([command, "test", "--ui", str(ROOT), *rest], env=environment).returncode
    finally:
        server.terminate()
        server.wait(timeout=10)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
