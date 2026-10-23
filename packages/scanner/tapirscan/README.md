# scanner_tapirscan

Scanner implementation using [Tapirscan](https://github.com/kleinicke/tapirscan)
1.4.0 (Medium effort), next to `scanner_ml_kit` and `scanner_zxing`, to compare
them on real phones. It reads the same formats as the other two (EAN-8/13,
UPC-A/E, ITF, Code 39/93/128, Data Matrix, QR).

Android only: API 24+, arm64-v8a and x86_64. Frames come from the `camera`
plugin; a small Java plugin passes their Y plane to Tapirscan's Android
binding, one frame at a time on a background thread.

## Native library

Tapirscan's Android library is built from source and not committed. It needs
the Android NDK, Java 21 and Rust (see Tapirscan's
[Android prerequisites](https://github.com/kleinicke/tapirscan/tree/v1.4.0/bindings/android)).
In a separate, clean Tapirscan checkout at tag `v1.4.0`:

```sh
cargo fetch --locked --manifest-path core/Cargo.toml
cargo fetch --locked --manifest-path multiformat/Cargo.toml
cargo fetch --locked --manifest-path tools/package-source/Cargo.toml
cargo fetch --locked --manifest-path bindings/rust/Cargo.toml
rustup target add --toolchain 1.99.0 aarch64-linux-android x86_64-linux-android
```

Then, from this package:

```sh
ANDROID_NDK_HOME=/path/to/ndk python3 tool/prepare_android.py --source /path/to/tapirscan
```

This builds Tapirscan's AAR and copies its JAR and the two JNI libraries into
the git-ignored `android/libs` and `android/src/main/jniLibs`, with the source
commit and AAR hash in `android/libs/PROVENANCE.txt`. Gradle stops with an
explicit error while they are missing.

## Build the app with Tapirscan

From the repository root:

```sh
./ci/dependencies/scanner/enable_tapirscan_dependency.sh
cd packages/smooth_app
fvm flutter pub get
fvm flutter build apk --debug --target-platform android-arm64,android-x64 --target lib/entrypoints/android/main_tapirscan.dart
```

The script disables ML Kit and ZXing, enables this package and writes the
`main_tapirscan.dart` entrypoint.

## Status

- Unit tests cover the Y-plane copy and the method channel with a mocked
  native side; the native decoding runs only on a device.
- Not yet tested on a device. iOS is not implemented.
- 32-bit ARM (armeabi-v7a) is not supported.
