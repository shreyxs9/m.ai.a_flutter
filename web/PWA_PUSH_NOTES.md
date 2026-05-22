# M.AI.A Flutter Web PWA and Push Notes

PWA assets are copied from the React frontend and wired through `web/index.html`
and `web/manifest.json`.

Push uses Firebase Cloud Messaging through a small browser JavaScript bridge.
Firebase public config is not hardcoded in the app or service worker. Pass it at
runtime/build time with Dart defines:

```powershell
flutter run -d chrome `
  --dart-define=GOOGLE_PICKER_API_KEY=... `
  --dart-define=GOOGLE_APP_ID=... `
  --dart-define=GOOGLE_OAUTH_CLIENT_ID=... `
  --dart-define=FIREBASE_API_KEY=... `
  --dart-define=FIREBASE_AUTH_DOMAIN=... `
  --dart-define=FIREBASE_PROJECT_ID=... `
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=... `
  --dart-define=FIREBASE_APP_ID=... `
  --dart-define=FIREBASE_VAPID_KEY=...
```

Limitations:

- Browser push only works on web targets with Notification, Service Worker, and
  PushManager support.
- iOS Safari can receive web push only after the site is installed to the home
  screen as a PWA.
- If Firebase config or the VAPID key is missing, the banner is suppressed as
  unsupported and no token is requested.
- Foreground notification rendering is handled by the JavaScript bridge because
  Firebase Messaging foreground callbacks are browser SDK APIs.
