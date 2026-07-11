# Contributing

Thanks for your interest in contributing!

## Getting started

1. Fork and clone the repo.
2. `flutter pub get`
3. Run checks locally before opening a PR:
   - `dart format lib test`
   - `flutter analyze` (must be clean)
   - `flutter test` (must pass)

## Pull requests

- Keep PRs focused — one change per PR.
- Add tests for any behavior change in the Dart layer.
- Native (Swift/Kotlin) changes must keep the method-channel contract documented in the README.
- Update `CHANGELOG.md` under an `Unreleased` heading.

## Reporting issues

Use the issue tracker and include: Flutter version, platform (iOS/Android + OS version), and a minimal reproduction.
