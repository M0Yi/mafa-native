#!/usr/bin/env python3
"""Collect OS resident memory; sampling failures are not process completion."""
import argparse
import csv
import subprocess
import time
from pathlib import Path


def read_sample(pid):
    result = subprocess.run(
        ["ps", "-p", str(pid), "-o", "rss=,pcpu=,state="],
        capture_output=True, text=True,
    )
    if result.returncode == 1 and not result.stdout.strip() and not result.stderr.strip():
        return None  # ps reports no matching process.
    if result.returncode != 0:
        raise RuntimeError(f"ps failed ({result.returncode}): {result.stderr.strip()}")
    parts = result.stdout.split()
    if len(parts) != 3:
        raise RuntimeError(f"Unexpected ps output: {result.stdout!r}")
    if "Z" in parts[2]:
        return None
    return parts


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--pid", type=int, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.pid <= 0:
        parser.error("--pid must be positive")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w", encoding="utf-8", newline="") as file:
        writer = csv.writer(file)
        writer.writerow(["unix_seconds", "rss_kib", "cpu_percent", "state"])
        while True:
            parts = read_sample(args.pid)
            if parts is None:
                break
            writer.writerow([time.time(), *parts])
            file.flush()
            time.sleep(5)


if __name__ == "__main__":
    main()
