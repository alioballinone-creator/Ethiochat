# Audit findings

This is a record of issues found and changes made during the current audit
pass. It is not a claim that the full repository audit or release validation
has passed; Flutter, Android release signing, and GitHub Actions could not be
run from the available environment.

## Fixed

- **Outbox could mark messages sent without a transport, leak its connectivity
  subscription, or persist raw send exceptions.** The worker now requires a
  transport, cancels its subscription, stores a safe error marker, and keeps
  retryable failures visible. See
  [`outbox_worker.dart`](lib/features/chats/data/datasources/outbox_worker.dart).
- **Queued work could run after sign-out or remain paused after a later
  sign-in.** The worker now follows Supabase auth state. A failed remote
  sign-out no longer clears local account state. See
  [`app_providers.dart`](lib/core/providers/app_providers.dart) and
  [`settings_screen.dart`](lib/features/settings/presentation/screens/settings_screen.dart).
- **Connectivity monitoring leaked its platform stream subscription and could
  report stale online state after an initialization error.** It now owns and
  cancels the subscription, handles start/dispose races, and reports offline
  when the initial check fails in
  [`connectivity_service.dart`](lib/core/network/connectivity_service.dart).
- **Failure displays could leak backend messages and HTTP details.** Typed
  failures with an underlying exception now render category-based English or
  Amharic copy. Regression coverage is in
  [`failure_test.dart`](test/core/failure_test.dart).
- **Unexpected Flutter errors had no app-level recovery screen.** Added a
  retryable root fallback in
  [`global_error_boundary.dart`](lib/core/widgets/global_error_boundary.dart).
- **Message-history pagination could become permanently exhausted after a
  transient error.** A retry remains possible in
  [`chat_detail_screen.dart`](lib/features/chat/presentation/screens/chat_detail_screen.dart).
- **Account cleanup silently ignored failures in preferences and secure key
  storage.** Cleanup now continues through remaining stores and returns the
  first mapped failure in
  [`session_cleanup.dart`](lib/features/auth/application/session_cleanup.dart).
- **Release configuration referenced a missing custom ProGuard file.** The
  build now uses Android's default optimized R8 rules; minification and
  resource shrinking remain enabled in
  [`build.gradle`](android/app/build.gradle).
- **Release setup documentation named an obsolete keystore secret.** Corrected
  the secret names and noted the still-required Play upload-certificate
  fingerprint in [`ANDROID_BUILD.md`](ANDROID_BUILD.md).

## Not verified / remaining

- `flutter analyze`, `flutter test`, code generation, and Android builds were
  not run because the Flutter SDK is unavailable in this environment.
- No signed AAB, APK, or R8 mapping file has been produced or inspected.
- Play Console ownership of `com.ethiochat.myapp` and the highest uploaded
  `versionCode` are unconfirmed; neither the application ID nor version was
  changed on assumption.
- Release signing, service configuration, and `PLAY_UPLOAD_CERT_SHA256` must
  be configured in GitHub Actions before release workflow execution. GitHub
  CLI is not authenticated here, so no workflow was triggered.
- Review of all repository code paths, permissions, localization/RTL, cache
  retention, and navigation is incomplete and requires successful Flutter
  tooling and a full test/audit pass.
