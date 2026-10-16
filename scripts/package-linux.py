#!/usr/bin/env python3
"""Build/verify local Linux archives. Never creates tags or publishes releases."""

from __future__ import annotations

import argparse
import gzip
import hashlib
import io
import json
import os
import platform
import re
import shutil
import subprocess
import tarfile
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TOOLCHAIN = "1.98.1"
ASSETS = ["LICENSE", "THIRD_PARTY_NOTICES.md", "linux/README.md", "linux/README.de.md",
          "linux/hyprland.conf.example", "linux/omarchy-bar.example.json", "linux/waybar.example.jsonc", "linux/waybar.example.css"]


def run(*command, cwd=ROOT, env=None) -> str:
    return subprocess.run(command, cwd=cwd, env=env, check=True, text=True, stdout=subprocess.PIPE).stdout.strip()


def digest(path: Path) -> str:
    with path.open('rb') as source:
        return hashlib.file_digest(source, 'sha256').hexdigest()


def build(tag: str, output: Path) -> None:
    if run('git', 'status', '--porcelain', '--untracked-files=all'):
        raise ValueError('Checkout is dirty; commit or preserve changes before packaging.')
    manifest = (ROOT / 'linux/Cargo.toml').read_text()
    version = re.search(r'^version = "([^"]+)"', manifest, re.M)[1]
    product = re.search(r'^name = "([^"]+)"', manifest, re.M)[1]
    package_version = re.search(r'^pkgver=([^\s]+)', (ROOT / 'linux/packaging/arch/PKGBUILD').read_text(), re.M)[1]
    if version != package_version or not re.fullmatch(r'linux-v' + re.escape(version) + r'(?:-beta\.\d+)?', tag):
        raise ValueError('Version mismatch: Cargo.toml, PKGBUILD and requested tag must agree.')
    output = output.resolve()
    if output.exists():
        raise ValueError('Output directory already exists.')
    if output == ROOT or ROOT in output.parents:
        raise ValueError('Output must be outside the checkout to keep repeated builds clean.')
    if platform.system() != 'Linux':
        raise ValueError('Real Linux builds and verification require a Linux host.')
    environment = {**os.environ, 'RUSTUP_AUTO_INSTALL': '0'}
    rust = run('rustc', '--version', env=environment)
    cargo = run('cargo', '--version', env=environment)
    if not rust.startswith(f'rustc {TOOLCHAIN} ') or not cargo.startswith(f'cargo {TOOLCHAIN} '):
        raise ValueError(f'Rust and Cargo {TOOLCHAIN} must already be selected; nothing is installed.')
    commit = run('git', 'rev-parse', 'HEAD')
    epoch = int(run('git', 'show', '-s', '--format=%ct', 'HEAD'))
    architecture = run('rustc', '-vV', env=environment).split('host: ', 1)[1].splitlines()[0]
    source_tar = subprocess.run(['git', 'archive', '--format=tar', commit], cwd=ROOT, check=True, stdout=subprocess.PIPE).stdout
    with tempfile.TemporaryDirectory(prefix='linux-package-') as directory:
        temporary = Path(directory)
        snapshot = temporary / 'source'
        snapshot.mkdir()
        # Build and package the captured commit, not a checkout that the user
        # could edit while compilation is running. The same bytes form source.
        with tarfile.open(fileobj=io.BytesIO(source_tar), mode='r:') as source:
            source.extractall(snapshot, filter='data')
        environment.update(SOURCE_DATE_EPOCH=str(epoch), CARGO_INCREMENTAL='0', CARGO_TARGET_DIR=str(temporary / 'target'))
        environment['RUSTFLAGS'] = ' '.join(filter(None, [environment.get('RUSTFLAGS'), f'--remap-path-prefix={snapshot}=/source', f'--remap-path-prefix={temporary}=/build', '-C debuginfo=0']))
        run('cargo', 'build', '--release', '--locked', '--manifest-path', str(snapshot / 'linux/Cargo.toml'), cwd=snapshot, env=environment)
        files = {f'bin/{product}': temporary / 'target/release' / product}
        files.update({name: snapshot / name for name in ASSETS})
        metadata = {'commit': commit, 'version': version, 'tag': tag, 'product': product,
                    'rust': rust, 'target': architecture, 'source_date_epoch': epoch,
                    'files': {name: digest(path) for name, path in sorted(files.items())}}
        metadata_bytes = (json.dumps(metadata, sort_keys=True, indent=2) + '\n').encode()
        binary_archive = temporary / f'{product}-{tag}-{architecture}.tar.gz'
        # Explicit metadata and gzip mtime make the container reproducible.
        with binary_archive.open('wb') as raw, gzip.GzipFile(fileobj=raw, mode='wb', filename='', mtime=epoch) as zipped, tarfile.open(fileobj=zipped, mode='w') as archive:
            contents = {name: path.read_bytes() for name, path in files.items()}
            contents['manifest.json'] = metadata_bytes
            for name, data in sorted(contents.items()):
                info = tarfile.TarInfo(name)
                info.size, info.mtime = len(data), epoch
                info.uid, info.gid, info.uname, info.gname = 0, 0, '', ''
                info.mode = 0o755 if name.startswith('bin/') else 0o644
                archive.addfile(info, io.BytesIO(data))
        source_archive = temporary / f'{product}-{tag}-source.tar.gz'
        with source_archive.open('wb') as raw, gzip.GzipFile(fileobj=raw, mode='wb', filename='', mtime=epoch) as zipped:
            zipped.write(source_tar)
        output.mkdir(parents=True, exist_ok=False)
        for archive in [binary_archive, source_archive]:
            shutil.copyfile(archive, output / archive.name)
        (output / 'manifest.json').write_bytes(metadata_bytes)
        (output / 'SHA256SUMS').write_text(''.join(f'{digest(output / archive.name)}  {archive.name}\n' for archive in [binary_archive, source_archive]))
        verify(output / binary_archive.name)
        print(output)


def verify(path: Path) -> None:
    path = path.resolve()
    if platform.system() != 'Linux':
        raise ValueError('Binary verification requires a Linux host.')
    checksums = {}
    for line in (path.parent / 'SHA256SUMS').read_text().splitlines():
        checksum, name = line.split('  ', 1)
        if name in checksums or not re.fullmatch('[0-9a-f]{64}', checksum):
            raise ValueError('Malformed or duplicate checksum entry.')
        checksums[name] = checksum
    if checksums.get(path.name) != digest(path):
        raise ValueError('Archive checksum mismatch.')
    with tempfile.TemporaryDirectory(prefix='linux-verify-') as directory, tarfile.open(path) as archive:
        members = archive.getmembers()
        names = [member.name for member in members]
        if len(set(names)) != len(names) or any(not member.isfile() or Path(member.name).is_absolute() or '..' in Path(member.name).parts for member in members):
            raise ValueError('Archive contains duplicate, linked or unsafe paths.')
        manifest_file = archive.extractfile('manifest.json')
        if manifest_file is None:
            raise ValueError('Manifest is missing.')
        metadata = json.load(manifest_file)
        expected = metadata['files']
        if set(names) != set(expected) | {'manifest.json'}:
            raise ValueError('Manifest file list mismatch.')
        if not re.fullmatch(r'[a-z][a-z0-9_-]*', metadata['product']):
            raise ValueError('Invalid product name.')
        for name, checksum in expected.items():
            content = archive.extractfile(name).read()
            if hashlib.sha256(content).hexdigest() != checksum:
                raise ValueError(f'Manifest checksum mismatch: {name}')
            destination = Path(directory) / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(content)
            destination.chmod(0o755 if name == f"bin/{metadata['product']}" else 0o644)
        binary = str(Path(directory) / 'bin' / metadata['product'])
        version = run(binary, '--version', cwd=directory)
        if version != f"{metadata['product']} {metadata['version']}":
            raise ValueError('Binary version does not match manifest.')
        if not run(binary, '--help', cwd=directory):
            raise ValueError('Binary help output is empty.')
    print(f'Verified {path.name}')


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--tag')
    parser.add_argument('--output', type=Path)
    parser.add_argument('--verify', type=Path)
    args = parser.parse_args()
    try:
        if args.verify and not args.tag and not args.output:
            verify(args.verify)
        elif args.tag and args.output and not args.verify:
            build(args.tag, args.output)
        else:
            parser.error('choose --tag TAG --output NEW_DIRECTORY or --verify ARCHIVE')
    except (OSError, ValueError, KeyError, tarfile.TarError, subprocess.CalledProcessError) as error:
        print(f'Packaging failed: {error}', file=__import__('sys').stderr)
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
