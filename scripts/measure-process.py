#!/usr/bin/env python3
"""Sample one explicitly selected macOS process without inspecting its arguments."""

from __future__ import annotations

import argparse
import json
import math
import os
from pathlib import Path
import subprocess
import sys
import time
from typing import Any


MIN_DURATION_SECONDS = 60.0
MAX_DURATION_SECONDS = 300.0
MIN_INTERVAL_SECONDS = 1.0


class ProcessUnavailable(Exception):
    """The selected process exited or could no longer be inspected."""


def parse_cpu_time(value: str) -> float:
    """Convert macOS ps cumulative CPU time to seconds."""
    value = value.strip()
    days = 0
    if "-" in value:
        day_text, value = value.split("-", 1)
        days = int(day_text)
    parts = value.split(":")
    if len(parts) == 3:
        hours, minutes, seconds = parts
    elif len(parts) == 2:
        hours = "0"
        minutes, seconds = parts
    else:
        raise ValueError(f"unexpected CPU time from ps: {value!r}")
    return days * 86400 + int(hours) * 3600 + int(minutes) * 60 + float(seconds)


def ps_value(pid: int, field: str) -> str:
    result = subprocess.run(
        ["/bin/ps", "-p", str(pid), "-o", f"{field}="],
        check=False,
        capture_output=True,
        text=True,
        env={"LC_ALL": "C", "PATH": "/usr/bin:/bin"},
    )
    value = result.stdout.strip()
    if result.returncode != 0 or not value:
        raise ProcessUnavailable(f"PID {pid} is no longer available")
    return value


def process_identity(pid: int) -> dict[str, str]:
    return {
        "start_time": ps_value(pid, "lstart"),
        "executable": os.path.realpath(ps_value(pid, "comm")),
    }


def sample(pid: int, expected_identity: dict[str, str]) -> dict[str, float]:
    before = process_identity(pid)
    if before != expected_identity:
        raise ProcessUnavailable("process identity changed; PID may have been reused")
    cpu_seconds = parse_cpu_time(ps_value(pid, "time"))
    rss_kib = int(ps_value(pid, "rss"))
    after = process_identity(pid)
    if after != expected_identity:
        raise ProcessUnavailable("process identity changed while sampling")
    return {
        "elapsed_seconds": time.monotonic(),
        "cpu_seconds": cpu_seconds,
        "rss_kib": rss_kib,
    }


def output_path(value: str) -> Path:
    path = Path(value).expanduser()
    if not path.is_absolute():
        raise argparse.ArgumentTypeError("--output must be an absolute path")
    return path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Measure cumulative CPU delta and sampled resident memory for one macOS PID."
    )
    parser.add_argument("--pid", type=int, required=True, help="exact process ID to sample")
    parser.add_argument(
        "--executable",
        type=Path,
        required=True,
        help="exact executable path expected for that PID",
    )
    parser.add_argument(
        "--duration",
        type=float,
        required=True,
        help="sampling duration in seconds (60 through 300)",
    )
    parser.add_argument(
        "--interval",
        type=float,
        default=1.0,
        help="sampling interval in seconds (at least 1; default: 1)",
    )
    parser.add_argument("--output", type=output_path, required=True, help="absolute JSON output path")
    args = parser.parse_args()
    if args.pid <= 0:
        parser.error("--pid must be positive")
    if not math.isfinite(args.duration) or not MIN_DURATION_SECONDS <= args.duration <= MAX_DURATION_SECONDS:
        parser.error("--duration must be between 60 and 300 seconds")
    if not math.isfinite(args.interval) or args.interval < MIN_INTERVAL_SECONDS:
        parser.error("--interval must be at least 1 second")
    if args.interval > args.duration:
        parser.error("--interval cannot exceed --duration")
    expected = args.executable.expanduser()
    if not expected.is_absolute():
        parser.error("--executable must be an absolute path")
    args.executable = Path(os.path.realpath(expected))
    if not args.output.parent.is_dir():
        parser.error(f"output directory does not exist: {args.output.parent}")
    return args


def write_result(path: Path, result: dict[str, Any]) -> None:
    if not path.parent.is_dir():
        raise ValueError(f"output directory does not exist: {path.parent}")
    temporary = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    created_temporary = False
    try:
        with temporary.open("x", encoding="utf-8") as handle:
            created_temporary = True
            json.dump(result, handle, indent=2, sort_keys=True)
            handle.write("\n")
        os.link(temporary, path)
    finally:
        if created_temporary:
            try:
                temporary.unlink()
            except FileNotFoundError:
                pass


def main() -> int:
    if sys.platform != "darwin":
        print("error: this sampler supports macOS only", file=sys.stderr)
        return 2
    args = parse_args()
    if args.output.exists():
        print(f"error: refusing to overwrite existing output: {args.output}", file=sys.stderr)
        return 2
    expected_identity = process_identity(args.pid)
    expected_executable = str(args.executable)
    if expected_identity["executable"] != expected_executable:
        print(
            "error: PID executable does not match --executable: "
            f"{expected_identity['executable']!r} != {expected_executable!r}",
            file=sys.stderr,
        )
        return 2

    started_wall = time.time()
    first = sample(args.pid, expected_identity)
    first_monotonic = first["elapsed_seconds"]
    raw_samples = [first]
    status = "completed"
    stop_reason = "requested duration elapsed"
    deadline = first_monotonic + args.duration
    next_sample = first_monotonic + args.interval

    while True:
        now = time.monotonic()
        target = min(next_sample, deadline)
        if now < target:
            time.sleep(target - now)
        try:
            raw_samples.append(sample(args.pid, expected_identity))
        except ProcessUnavailable as error:
            status = "stopped"
            stop_reason = str(error)
            break
        if raw_samples[-1]["elapsed_seconds"] >= deadline:
            break
        next_sample += args.interval

    baseline = raw_samples[0]
    samples = [
        {
            "elapsed_seconds": round(item["elapsed_seconds"] - first_monotonic, 6),
            "cpu_seconds": item["cpu_seconds"],
            "rss_kib": item["rss_kib"],
        }
        for item in raw_samples
    ]
    elapsed = raw_samples[-1]["elapsed_seconds"] - first_monotonic
    cpu_delta = raw_samples[-1]["cpu_seconds"] - baseline["cpu_seconds"]
    result = {
        "schema_version": 1,
        "status": status,
        "stop_reason": stop_reason,
        "pid": args.pid,
        "executable": expected_executable,
        "process_start_time": expected_identity["start_time"],
        "started_unix_seconds": started_wall,
        "requested_duration_seconds": args.duration,
        "interval_seconds": args.interval,
        "observed_elapsed_seconds": round(elapsed, 6),
        "cpu_delta_seconds": round(cpu_delta, 6),
        "average_cpu_percent": round(cpu_delta / elapsed * 100, 3) if elapsed > 0 else None,
        "peak_sampled_rss_kib": max(item["rss_kib"] for item in raw_samples),
        "samples": samples,
        "limitations": [
            "RSS is sampled current resident memory, so peaks between samples are not observed.",
            "This does not report historical peak RSS from before sampling began.",
            "CPU percent is cumulative CPU-time delta divided by elapsed wall time and may exceed 100 on multicore work.",
            "Energy use is not measured.",
        ],
    }
    write_result(args.output, result)
    print(str(args.output))
    return 0 if status == "completed" else 3


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ProcessUnavailable as error:
        print(f"error: {error}", file=sys.stderr)
        raise SystemExit(3)
    except (OSError, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        raise SystemExit(2)
