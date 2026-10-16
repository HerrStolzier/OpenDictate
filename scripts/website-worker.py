#!/usr/bin/env python3
"""Pin website/worker.js to the website files of one commit.

`python3 scripts/website-worker.py <commit>` rewrites COMMIT and FILES in
website/worker.js from `git show <commit>:website/...`. `--check` verifies
that the pinned commit still yields exactly the listed files and hashes.
"""

import argparse
import hashlib
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WORKER = ROOT / "website" / "worker.js"
# Files in website/ that describe or run the site but are not served by it.
NOT_SERVED = {"README.md", "worker.js", "wrangler.toml"}
# Sources of the generated pages (scripts/website-i18n.py), also not served.
NOT_SERVED_DIRS = ("i18n/",)
# Keep in step with KINDS in website/worker.js.
SERVED_TYPES = {"html", "css", "js", "svg", "woff2", "txt", "png", "xml", "jpg", "mp4", "webp", "vtt"}
COMMIT_LINE = re.compile(r'^const COMMIT = "([0-9a-f]{40})";$', re.M)
FILES_BLOCK = re.compile(r"^const FILES = \{\n(?:.*\n)*?\};$", re.M)


def git(*args: str) -> bytes:
    return subprocess.run(["git", *args], cwd=ROOT, check=True, capture_output=True).stdout


def digest(body: bytes) -> str:
    return hashlib.sha256(body).hexdigest()[:32]


def served_files(commit: str) -> dict[str, str]:
    names = git("ls-tree", "-r", "-z", "--name-only", commit, "--", "website/").decode().split("\0")[:-1]
    files = {}
    for name in sorted(names):
        relative = name.removeprefix("website/")
        if relative in NOT_SERVED or relative.startswith(NOT_SERVED_DIRS):
            continue
        if relative.rsplit(".", 1)[-1] not in SERVED_TYPES:
            raise ValueError(f"no content type for website/{relative}")
        files["/" + relative] = digest(git("show", f"{commit}:{name}"))
    if "/index.html" not in files:
        raise ValueError(f"{commit} has no website/index.html")
    return files


def render(source: str, commit: str, files: dict[str, str]) -> str:
    block = "const FILES = {\n" + "".join(f'  "{path}": "{hash}",\n' for path, hash in files.items()) + "};"
    source, commits = COMMIT_LINE.subn(f'const COMMIT = "{commit}";', source)
    source, blocks = FILES_BLOCK.subn(lambda _: block, source)
    if commits != 1 or blocks != 1:
        raise ValueError("website/worker.js lacks one COMMIT line and one FILES block")
    return source


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("commit", nargs="?", help="commit whose website/ files the worker serves")
    parser.add_argument("--check", action="store_true", help="verify the pinned commit and hashes")
    args = parser.parse_args(argv)
    if args.check == bool(args.commit):
        parser.error("give either a commit or --check")
    source = WORKER.read_text()
    try:
        if args.check:
            match = COMMIT_LINE.search(source)
            if not match:
                raise ValueError("website/worker.js has no COMMIT line")
            commit = match.group(1)
        else:
            commit = git("rev-parse", "--verify", f"{args.commit}^{{commit}}").decode().strip()
        expected = render(source, commit, served_files(commit))
    except (ValueError, subprocess.CalledProcessError) as error:
        print(f"website-worker: {error}", file=sys.stderr)
        return 1
    if args.check:
        if expected != source:
            print(f"website/worker.js does not match the website files of {commit}", file=sys.stderr)
            return 1
        return 0
    WORKER.write_text(expected)
    print(f"website/worker.js now serves website/ from {commit}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
