# Klara ProGuard / R8 rules (Phase 1.9, requirements §7).
#
# Deliberately comments-only: this project needs NO hand-written keep
# rules today.
#
# - The Flutter Gradle plugin supplies the rules that keep the Flutter
#   engine embedding and Dart entry points alive.
# - Every native plugin (photo_manager, video_compress_advanced,
#   disk_space_plus, flutter_local_notifications, share_plus, ...)
#   ships its own consumer rules inside its AAR; R8 applies those
#   automatically. Inventing keeps here would only bloat the release.
#
# If a release-only crash ever traces to a stripped class, add a
# targeted -keep for exactly that class, with a comment citing the
# crash (class name + stack-trace line). Never add a blanket keep.
