# ADR-002 — Canonical release command (Phase 1.9, requirements §7)

## Decision

The release build type declares its shrink config explicitly
(`isMinifyEnabled`, `isShrinkResources`, `proguard-rules.pro` — see
`app/android/app/build.gradle.kts`), and releases are built with one
canonical command. No other release invocation is used, so two builds
of the same commit shrink identically.

## Canonical commands

Submission build (AAB only — Play does not take APKs for new apps):

```sh
flutter build appbundle --release \
  --obfuscate --split-debug-info=build/symbols/<version>/
```

`<version>` is the pubspec version (e.g. `1.0.0+1`). The symbols
directory is archived per version OUTSIDE git (root `.gitignore`
already ignores `**/build/`) before any `flutter clean`, because
obfuscated stack traces are unreadable without it. Suggested archive
location: durable owner storage under
`klara-symbols/<version>/`, copied from `build/symbols/<version>/`
immediately after the build.

QA builds (installable APKs, per-ABI so sizes stay comparable):

```sh
flutter build apk --release --split-per-abi \
  --obfuscate --split-debug-info=build/symbols/<version>/
```

QA builds use the same shrink + obfuscation flags as the submission
build, so what is tested is what ships.

## Signing — human-only checklist (never automated, never committed)

The release block still uses the debug signing config (see the TODO
in `build.gradle.kts`). Store submission requires the owner's
signing config; no keystore, key, or `key.properties` is created,
used, or committed by any agent:

1. Owner creates ONE upload keystore (keep the file + passwords
   offline; losing them blocks future updates of the same app).
2. Owner creates `app/android/key.properties` locally (storeFile,
   storePassword, keyAlias, keyPassword). Root `.gitignore` already
   ignores `**/key.properties`, `**/*.jks`, `**/*.keystore` — verify
   `git status` shows none of them before any commit.
3. Owner replaces the debug `signingConfig` in the release block
   with the release signing config reading `key.properties`.
4. Owner runs the canonical AAB command above and uploads the AAB
   from `build/app/outputs/bundle/release/`.

## Verification (owner, on an SDK machine — not verifiable on the VM)

- Build the same commit twice with the canonical command; the
  shrinking behaviour (R8 mapping + resource table) must be
  identical across both builds.
- Inspect the merged manifest and `--analyze-size` output for the
  release AAB (see ADR-001 open items); confirm only the three
  manifest permissions from requirements §5 survive.
- Confirm `build/symbols/<version>/` exists after the build and is
  archived before cleaning.
