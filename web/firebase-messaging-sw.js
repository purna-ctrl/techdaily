/* TechDaily — Firebase Cloud Messaging service worker (web push).
 * Shows notifications that arrive while the site is in the background and
 * opens /article/<id> when one carrying data.articleId is clicked.
 * Requires a VAPID key in lib/core/config/app_config.dart (kWebPushVapidKey).
 */
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyBi0JdLslPtWpjckU7eE3HPHFKrrADu0vY',
  authDomain: 'techdaily-prod.firebaseapp.com',
  projectId: 'techdaily-prod',
  storageBucket: 'techdaily-prod.firebasestorage.app',
  messagingSenderId: '1015898924676',
  appId: '1:1015898924676:web:e38a6fee99ee7473e744d1',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  // Messages with a `notification` block are displayed by the SDK itself.
  if (payload.notification) return;
  const data = payload.data || {};
  const title = data.title || 'TechDaily';
  self.registration.showNotification(title, {
    body: data.body || '',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-maskable-192.png',
    data: { articleId: data.articleId || '' },
  });
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const fcmData = (event.notification.data && (event.notification.data.FCM_MSG || event.notification.data)) || {};
  const articleId = (fcmData.data && fcmData.data.articleId) || fcmData.articleId || '';
  const url = articleId ? '/article/' + encodeURIComponent(articleId) : '/';
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((list) => {
      for (const c of list) {
        if ('focus' in c) { c.navigate(url); return c.focus(); }
      }
      return clients.openWindow(url);
    })
  );
});
