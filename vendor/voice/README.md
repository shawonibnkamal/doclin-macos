# Bundled local voice

Doclin's separate `doclin-voice` executable uses Kokoro v1.0 int8 with af_heart (speaker 3). It receives bounded text on stdin, uses no network, and writes a private WAV file. The app deletes that file after loading, cancellation, or next launch following a crash.

Pinned upstream inputs:
- sherpa-onnx v1.13.7: https://github.com/k2-fsa/sherpa-onnx/releases/tag/v1.13.7
- arm64 runtime build: sherpa-onnx-v1.13.7-onnxruntime-1.17.1-osx-arm64-shared.tar.bz2
- x86_64 runtime build: sherpa-onnx-v1.13.7-osx-x64-shared.tar.bz2
- model: https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/kokoro-int8-multi-lang-v1_0.tar.bz2

The universal dylibs combine the matching architecture slices. The arm64 dependency name `@rpath/libonnxruntime.1.17.1.dylib` is normalized to `@rpath/libonnxruntime.dylib`; no model or runtime source code was changed. Headers match sherpa v1.13.7. Build the small C helper using scripts/build.sh. SHA256.json records packaged inputs prior to release signing.

Apple silicon supports macOS 13+. The upstream Intel ONNX runtime requires macOS 15.5+, so older Intel Macs automatically use Apple speech. The universal main app still supports macOS 13+.

Licenses: Kokoro and sherpa-onnx Apache-2.0; ONNX Runtime MIT; eSpeak NG GPL-3.0; piper-phonemize MIT. License texts and upstream source archives are included. The separate speech helper source is scripts/voice/main.c and is distributed under GPL-3.0-or-later with the GPL-linked runtime. Doclin communicates with that helper only through process input and a WAV file.

Corresponding eSpeak NG and piper sources are the exact revisions selected by sherpa's cmake/espeak-ng-for-piper.cmake and cmake/piper-phonemize.cmake. The sherpa source archive includes its build scripts and remaining dependency references. Preserve these sources and license files when redistributing this preview.
