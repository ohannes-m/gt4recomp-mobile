# Public Android ARM64 runtime linkage probe (step 9)

This **offline CI-only** diagnostic links the unmodified, pinned MIT
`ps2-web-recomp` runtime for Android `arm64-v8a` into a real shared ELF
library. It forces extraction of **every** static runtime object with
`WHOLE_ARCHIVE`, rejects unresolved symbols with `--no-undefined`, and
checks the AArch64 ELF header and the exported synthetic EE-dispatch probe.

This is intentionally **not** `libgt4.so`, an APK, a game, or a substitute
for GT4's private runtime overlays. No disc, ELF, copyrighted translated EE,
VU images, VU-generated code, or signing material is accepted by this test.
The fixture only registers one authored synthetic EE unit and never boots GT4.

The Android game CMake still requires private qualified runtime/port capsules,
adapted EE units, generated VU sources, CoreGS shader sources, SDL3 and the
launcher. Passing this test proves only the public donor's cross-linking
compatibility. It does not qualify GT4 startup, rendering, or performance.

See `.github/workflows/gt4-etapa9-runtime-link-arm64.yml` for the reproducible
NDK 26.1.10909125 build, SHA-pinned donor commit and CI artifact/diagnostics.
