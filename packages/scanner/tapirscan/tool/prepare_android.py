#!/usr/bin/env python3
"""Build the exact 1.4.0 Android binding in a separate clean Tapirscan checkout."""
import argparse
import hashlib
from pathlib import Path
import subprocess
import sys
import zipfile

# Commit of Tapirscan's v1.4.0 tag; update it with the version in README.md.
REVISION = '383c84b97659c0587777335c2d2ca914adc1e219'
ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    args = parser.parse_args()
    source = args.source.resolve()
    revision = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=source, text=True).strip()
    dirty = subprocess.check_output(['git', 'status', '--porcelain', '--untracked-files=no'], cwd=source, text=True)
    if revision != REVISION or dirty:
        parser.error('Use a clean, separate checkout at v1.4.0 (' + REVISION + ')')
    subprocess.run([sys.executable, 'scripts/build_android.py'], cwd=source, check=True)
    aar = source / 'build/android/tapirscan-android.aar'
    if not aar.exists():
        sys.exit(f'{aar} was not built')
    outputs = {'classes.jar': ROOT / 'android/libs/tapirscan-1.4.0.jar'}
    for abi in ('arm64-v8a', 'x86_64'):
        outputs[f'jni/{abi}/libtapirscan_jni.so'] = ROOT / f'android/src/main/jniLibs/{abi}/libtapirscan_jni.so'
    with zipfile.ZipFile(aar) as archive:
        payloads = {destination: archive.read(member) for member, destination in outputs.items()}
    for destination, data in payloads.items():
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(data)
    (ROOT / 'android/libs/PROVENANCE.txt').write_text(
        f'Tapirscan 1.4.0\nCommit: {REVISION}\nAAR SHA256: {hashlib.sha256(aar.read_bytes()).hexdigest()}\n'
    )
    print('Prepared Tapirscan 1.4.0 Android libraries')


if __name__ == '__main__':
    main()
