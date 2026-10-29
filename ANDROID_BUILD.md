# Android Build Setup

## Package Name
`com.ethiochat.myapp`

## GitHub Secrets Required
Add these in Settings → Secrets and variables → Actions:

- `KEYSTORE_BASE64` - Base64 encoded keystore file
- `ANDROID_KEYSTORE_PASSWORD` - Keystore password
- `ANDROID_KEY_ALIAS` - Upload-key alias
- `ANDROID_KEY_PASSWORD` - Upload-key password
- `SUPABASE_URL` and `SUPABASE_ANON_KEY` - Supabase client configuration
- `LIVEKIT_URL` - LiveKit WebSocket URL
- `FIREBASE_PROJECT_ID`, `FIREBASE_APP_ID`, `FIREBASE_API_KEY`,
  `FIREBASE_MESSAGING_SENDER_ID`, and `FIREBASE_STORAGE_BUCKET` - Firebase
  client configuration

The release workflow currently reports these missing configuration names:
`LIVEKIT_URL`, `FIREBASE_PROJECT_ID`, `FIREBASE_APP_ID`, `FIREBASE_API_KEY`,
and `FIREBASE_MESSAGING_SENDER_ID`. It also reports the
`PLAY_UPLOAD_CERT_SHA256` repository variable as missing. Add the secrets and
variable before expecting a release build to proceed.

Also add the public `PLAY_UPLOAD_CERT_SHA256` repository variable under
Settings → Secrets and variables → Actions → Variables. Set it to the SHA-256
fingerprint shown for the app's **upload key certificate** in Play Console
(App integrity). The release workflow fails closed if this fingerprint is
missing or does not match both the decoded keystore and the AAB signer.

The committed Gradle 8.11.1 wrapper is checked against its pinned SHA-256 in
CI. Its distribution checksum is pinned in
`android/gradle/wrapper/gradle-wrapper.properties`. The release workflow does
not download or replace wrapper files.

## Build
Workflow: **Build AAB** (`workflow_dispatch`).
Command: `flutter build appbundle --release --no-tree-shake-icons`.
The AAB is uploaded only after strict `jarsigner` verification and confirmation
that its signing certificate matches `PLAY_UPLOAD_CERT_SHA256`. The temporary
keystore is kept under the runner's temporary directory and removed at job end.

## Supabase Deployment

The Supabase deployment workflow requires these repository Actions secrets:
`SUPABASE_ACCESS_TOKEN`, `SUPABASE_DB_PASSWORD`, and `SUPABASE_PROJECT_REF`.
The latest deployment run reports `SUPABASE_PROJECT_REF` as missing. Add it at
repository Settings → Secrets and variables → Actions → New repository secret.
`SUPABASE_PROJECT_REF` must be the project's 20-character reference, not its
URL or an API key. The deployment workflow checks it against the reference in
`SUPABASE_URL` when that URL uses the canonical `*.supabase.co` host.

LiveKit requires `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET`, and `LIVEKIT_URL`
together. Push dispatch requires `FCM_SERVICE_ACCOUNT_JSON` and
`PUSH_WEBHOOK_SECRET` together. `PAYMENT_WEBHOOK_SECRET` enables payment
webhook verification. Missing optional service credentials are reported as
warnings and those services remain unavailable or fail closed; they are not
reported as production-ready.
