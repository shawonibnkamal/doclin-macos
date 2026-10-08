#!/usr/bin/env python3
"""Fetch pinned public voice dependencies; never reads app preferences or keys."""
import hashlib
import json
import pathlib
import shutil
import subprocess
import tarfile
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
VOICE = ROOT / 'vendor/voice'
CACHE = ROOT / '.build/voice-downloads'
RELEASE = 'https://github.com/k2-fsa/sherpa-onnx/releases/download/'
INPUTS = {
    'arm64.tar.bz2': (RELEASE + 'v1.13.7/sherpa-onnx-v1.13.7-onnxruntime-1.17.1-osx-arm64-shared.tar.bz2', '911d5fdf547161bee00d991e9b8b85a3c60c26a9e9e55b961ae4e99252af19d0'),
    'x86_64.tar.bz2': (RELEASE + 'v1.13.7/sherpa-onnx-v1.13.7-osx-x64-shared.tar.bz2', '41f721066362eb80dd5cf648922978577b254183fc47199bb4902fcca2221e7d'),
    'model.tar.bz2': (RELEASE + 'tts-models/kokoro-int8-multi-lang-v1_0.tar.bz2', '4c3052abaa60943a341f193888cf6abd68787dae6ab8ae5c925a706caa247e4e'),
    'sherpa-onnx.tar.gz': ('https://github.com/k2-fsa/sherpa-onnx/archive/refs/tags/v1.13.7.tar.gz', 'ee0c20cafb34cc1f86afb2845babd941c26e46de4a9925cbe86fd55ff3557818'),
    'espeak-ng.zip': ('https://github.com/csukuangfj/espeak-ng/archive/ed530aa113046142eb5115cf2fc9157854d0ffe1.zip', 'e4e262cbe34f7fe21f91f1ba3397f2728e1f30eafbae7853f2b753a9ed13f0dd'),
    'piper-phonemize.zip': ('https://github.com/csukuangfj/piper-phonemize/archive/f3ff95afc03640bc1399e113e83361192a2fafb4.zip', 'd9cca4e2bdc7d6dd8dffb96a4668283dbd3f77a9c194a3e530c1e8eba9406a5d'),
}


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def fetch(name, url, expected):
    path = CACHE / name
    if not path.exists():
        partial = path.with_suffix(path.suffix + '.partial')
        print('Downloading', name, flush=True)
        subprocess.run(['curl', '--fail', '--location', '--silent', '--show-error', '--retry', '2', url, '-o', str(partial)], check=True)
        if digest(partial) != expected:
            raise SystemExit('Checksum mismatch: ' + name)
        partial.replace(path)
    if digest(path) != expected:
        raise SystemExit('Checksum mismatch in cache: ' + name)
    return path


def unpack(path, destination):
    # Read only regular files. Dependency aliases are resolved explicitly below.
    with tarfile.open(path) as archive:
        for member in archive.getmembers():
            name = pathlib.PurePosixPath(member.name)
            if name.is_absolute() or '..' in name.parts:
                raise SystemExit('Unsafe archive path')
            if member.isfile():
                target = destination.joinpath(*name.parts)
                target.parent.mkdir(parents=True, exist_ok=True)
                with archive.extractfile(member) as source, target.open('wb') as out:
                    shutil.copyfileobj(source, out)
    return next(destination.iterdir())


def main():
    CACHE.mkdir(parents=True, exist_ok=True)
    archives = {name: fetch(name, *spec) for name, spec in INPUTS.items()}
    with tempfile.TemporaryDirectory(prefix='doclin-voice-') as scratch:
        scratch = pathlib.Path(scratch)
        arm = unpack(archives['arm64.tar.bz2'], scratch / 'arm')
        intel = unpack(archives['x86_64.tar.bz2'], scratch / 'intel')
        model = unpack(archives['model.tar.bz2'], scratch / 'model')
        arm_api = arm / 'lib/libsherpa-onnx-c-api.dylib'
        subprocess.run(['install_name_tool', '-change', '@rpath/libonnxruntime.1.17.1.dylib', '@rpath/libonnxruntime.dylib', str(arm_api)], check=True)
        lib = VOICE / 'lib'
        lib.mkdir(parents=True, exist_ok=True)
        for name, arm_name in [('libsherpa-onnx-c-api.dylib', 'libsherpa-onnx-c-api.dylib'), ('libonnxruntime.dylib', 'libonnxruntime.1.17.1.dylib')]:
            subprocess.run(['lipo', '-create', str(arm / 'lib' / arm_name), str(intel / 'lib' / name), '-output', str(lib / name)], check=True)
        shutil.copytree(model, VOICE / 'model', dirs_exist_ok=True)
        sources = VOICE / 'sources'
        sources.mkdir(parents=True, exist_ok=True)
        for name in ['sherpa-onnx.tar.gz', 'espeak-ng.zip', 'piper-phonemize.zip']:
            shutil.copy2(archives[name], sources / name)
        manifest = json.loads((VOICE / 'DOWNLOAD-SHA256.json').read_text())
        for name, expected in manifest.items():
            if name.startswith(('model/', 'sources/', 'include/')) and digest(VOICE / name) != expected:
                raise SystemExit('Dependency file mismatch: ' + name)
    print('Verified voice model, headers and source archives; built universal runtime libraries.')


if __name__ == '__main__':
    main()
