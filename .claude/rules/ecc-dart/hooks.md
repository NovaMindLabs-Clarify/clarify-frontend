---
paths:
  - "**/*.dart"
  - "**/pubspec.yaml"
  - "**/analysis_options.yaml"
---
# Dart/Flutter Hooks & CLI Reference

> Источник: [ECC](https://github.com/affaan-m/ecc) `rules/dart/hooks.md`. Справочный текст —
> ничего здесь не настроено автоматически, ни один хук в `settings.json` этим файлом не
> включается. **`dart analyze --fatal-infos` ниже — это апстрим-рекомендация ECC, не практика
> этого проекта**: здесь принято мириться с уже существующими info-уровня подсказками
> анализатора как известной базовой линией (см. `flutter analyze` в CLAUDE.md — важны
> предупреждения/ошибки, не info).

## Possible PostToolUse Hooks (not configured here)

If ever wired up in `~/.claude/settings.json`, these are the standard ECC recommendations:
- **dart format**: Auto-format `.dart` files after edit
- **dart analyze**: Run static analysis after editing Dart files and surface warnings
- **flutter test**: Optionally run affected tests after significant changes

## Pre-commit Checks (upstream ECC recommendation)

```bash
dart format --set-exit-if-changed .
dart analyze --fatal-infos   # это строже, чем принято в этом проекте — см. предупреждение выше
flutter test
```

## Useful One-liners

```bash
# Format all Dart files
dart format .

# Analyze and report issues
dart analyze

# Run all tests with coverage
flutter test --coverage

# Regenerate code-gen files
dart run build_runner build --delete-conflicting-outputs

# Check for outdated packages
flutter pub outdated

# Upgrade packages within constraints
flutter pub upgrade
```
