/* Firebase Cloud Messaging service worker for Flutter Web.
 *
 * Firebase public config is intentionally not hardcoded here. The Flutter app
 * passes config from --dart-define through window.maiaPush, and this worker
 * stores it in Cache Storage so background restarts can initialize FCM.
 */

importScripts("https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js");

const CONFIG_CACHE = "maia-push-config-v1";
const CONFIG_URL = "/__maia_firebase_config.json";

let messaging = null;

async function saveConfig(config) {
  const cache = await caches.open(CONFIG_CACHE);
  await cache.put(CONFIG_URL, new Response(JSON.stringify(config)));
}

async function loadConfig() {
  const cache = await caches.open(CONFIG_CACHE);
  const response = await cache.match(CONFIG_URL);
  if (!response) return null;
  return response.json();
}

async function ensureMessaging(config) {
  const next = config || (await loadConfig());
  if (!next || !next.apiKey || !next.projectId || !next.messagingSenderId || !next.appId) {
    return null;
  }
  if (!firebase.apps.length) {
    firebase.initializeApp({
      apiKey: next.apiKey,
      authDomain: next.authDomain,
      projectId: next.projectId,
      messagingSenderId: next.messagingSenderId,
      appId: next.appId,
    });
  }
  if (!messaging) {
    messaging = firebase.messaging();
    messaging.onBackgroundMessage((payload) => {
      const data = payload.data || {};
      const title = data.title || "M.AI.A";
      const body = data.body || "";
      self.registration.showNotification(title, {
        body,
        icon: "/icon-192.png",
        badge: "/icon-192.png",
        tag: data.tag || "maia-checkin",
        data: {
          project_id: data.project_id || null,
          url: data.url || "/",
        },
      });
    });
  }
  return messaging;
}

self.addEventListener("message", (event) => {
  if (event.data?.type !== "MAIA_FIREBASE_CONFIG") return;
  event.waitUntil(saveConfig(event.data.config).then(() => ensureMessaging(event.data.config)));
});

self.addEventListener("activate", (event) => {
  event.waitUntil(self.clients.claim().then(() => ensureMessaging()));
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  const target = event.notification.data?.url || "/";
  event.waitUntil(
    self.clients.matchAll({ type: "window", includeUncontrolled: true }).then((windows) => {
      for (const w of windows) {
        if ("focus" in w) {
          w.navigate(target);
          return w.focus();
        }
      }
      if (self.clients.openWindow) return self.clients.openWindow(target);
    }),
  );
});
