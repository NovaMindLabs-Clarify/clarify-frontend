---
paths:
  - "**/*.dart"
  - "**/pubspec.yaml"
  - "**/analysis_options.yaml"
---
# Dart/Flutter Security

> Источник: [ECC](https://github.com/affaan-m/ecc) `rules/dart/security.md`, взято без изменений
> (проверено на соответствие проекту — конфликтов не найдено).

This guide extends general security practices with mobile-specific guidance for Dart and Flutter development.

## Secrets Management

- Never hardcode credentials. Use `--dart-define` for compile-time configuration or `flutter_secure_storage` for runtime secrets.
- Never hardcode API keys, tokens, or credentials in Dart source.

## Network Security

- Enforce HTTPS exclusively.
- Configure platform-specific security policies (Android's `network_security_config.xml`, iOS's `NSAppTransportSecurity`).
- Always set request timeouts on HTTP clients.

## Input Validation

- Sanitize all user input before API calls or storage operations.
- Use parameterized queries to prevent SQL injection.
- Validate deep link URLs before navigation — validate scheme, host, and path parameters.

## Data Protection

- Store sensitive data only in secure storage.
- Never write sensitive data to SharedPreferences or local files in plaintext.
- Clear authentication state on logout and avoid logging sensitive information.

## Android

- Minimize declared permissions.
- Set `android:exported="false"` for components not requiring external access.
- Review intent filters for unintended exposure.

## iOS

- Declare only necessary usage descriptions in Info.plist.
- Leverage Keychain via `flutter_secure_storage` for secrets.

## WebView Security

- Use current `webview_flutter` v4+.
- Disable JavaScript by default.
- Never load arbitrary URLs from deep links — validate all navigation requests.

## Obfuscation

- Enable obfuscation in release builds with debug info splitting, keeping symbol files separate from version control.
