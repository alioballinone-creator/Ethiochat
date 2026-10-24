# Android Build Setup

## Package Name
`com.ethiochat.myapp`

## GitHub Secrets Required
Add these in Settings → Secrets and variables → Actions:

- `KEYSTORE_BASE64` - Base64 encoded keystore file
- `KEYSTORE_PASSWORD` - Keystore password
- `KEY_ALIAS` - Key alias
- `KEY_PASSWORD` - Key password

## Build
Workflow: Build AAB (runs on push to main or manual trigger)
Output: `build/app/outputs/bundle/release/app-release.aab`
