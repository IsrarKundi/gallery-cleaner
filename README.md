# Klara

A photo-cleaning app for Android. Swipe to triage your gallery: left = Keep, right = Delete, up = Maybe, down = Favourite. Swipes only mark photos — deletion happens after a review screen and the Android confirmation, into a 30-day Trash.

- Android first, English v1. No paywall, ads, or subscriptions in Phase 1.
- Spec: `requirements.md` (product truth).
- Design system: `design.md`.
- Agent rules: `AGENTS.md`.
- The Flutter app lives in `app/` (created in Phase 1).

## Run (once the Flutter project exists in `app/`)

```sh
cd app
flutter run
```

## Trust flow

Mark-only swipes → review → native confirmation → 30-day Trash → restore / empty / expiry. Nothing is auto-deleted, and space is never claimed as freed while a photo sits in Trash.
