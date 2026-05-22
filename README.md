# M.AI.A Flutter

Flutter Web migration of the M.AI.A team workspace app. The app mirrors the React frontend flows for Google OAuth login, tenant/workspace selection, workspace and project invites, project chat, SSE streaming, relays, broadcasts, profile settings, admin workspace management, and Google Sheets project connectors.

## Project Overview

- `go_router` handles `/`, invite, profile, admin, project, and fallback routes.
- `flutter_riverpod` owns auth/session state, theme selection, project dashboard state, and admin controller state.
- `dio` talks to the FastAPI backend under `/api/v1`, adding `Authorization: Bearer ...` and `X-Tenant-Id` from persisted session state.
- `shared_preferences` persists Flutter-side session and theme keys. Web-only browser helpers use `localStorage` for OAuth callback, timezone, pending stream, and push-prompt state.
- `flutter_markdown` renders chat markdown content.

## Run Locally

Start the FastAPI backend first, then run Flutter Web:

```powershell
flutter pub get
flutter run -d chrome --web-port 3000
```

The default API target is:

```text
MAIA_API_BASE_URL=http://localhost:8000
MAIA_API_BASE_PATH=/api/v1
API_ORIGIN=http://localhost:8000
```

## API_ORIGIN

`API_ORIGIN` controls the browser navigation target for Google login redirects. Pass it with `--dart-define` when the backend origin is different from the API base URL:

```powershell
flutter run -d chrome --web-port 3000 --dart-define=API_ORIGIN=http://localhost:8000
```

For phone testing on the same Wi-Fi, use LAN origins for both the app API and login redirect:

```powershell
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 3000 --dart-define=MAIA_API_BASE_URL=http://192.168.1.10:8000 --dart-define=API_ORIGIN=http://192.168.1.10:8000
```

## Build Flutter Web

```powershell
flutter build web --release --dart-define=MAIA_API_BASE_URL=https://api.example.com --dart-define=API_ORIGIN=https://api.example.com
```

If the backend is mounted behind the same Firebase Hosting origin, keep `MAIA_API_BASE_URL` pointed at that origin and set `MAIA_API_BASE_PATH=/api/v1` unless the rewrite changes the API path.

## Firebase Hosting Deployment Notes

- Deploy the contents of `build/web`.
- Configure rewrites so Flutter deep links resolve to `/index.html`.
- Configure API rewrites or CORS so `/api/v1` requests reach the FastAPI backend.
- Configure Google OAuth redirect URLs to return to the hosted Flutter origin with the `token` query parameter expected by `AuthController`.
- Push notifications require valid Firebase web app values and VAPID key passed through the existing web configuration bridge.

Example `firebase.json` shape:

```json
{
  "hosting": {
    "public": "build/web",
    "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
    "rewrites": [
      { "source": "/api/v1/**", "function": "api" },
      { "source": "**", "destination": "/index.html" }
    ]
  }
}
```

## Known Limitations

- Google Sheets supports status, connect, disconnect, attach, and detach flows; it does not recreate the full React Google picker UI.
- Admin audit feed is represented as a placeholder until the backend exposes the audit history endpoint.
- Push notification support depends on browser capability, service worker support, Firebase config, and iOS PWA install state.
- Mobile validation is web-first; native Android APK readiness still depends on the local Java/JDK toolchain.
