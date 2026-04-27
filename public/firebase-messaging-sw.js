// Firebase Messaging Service Worker
// يستلم إشعارات FCM في الخلفية حتى لو كانت الصفحة مغلقة

importScripts('https://www.gstatic.com/firebasejs/10.13.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.0/firebase-messaging-compat.js');

// نستلم الـ Firebase config من الصفحة الرئيسية عبر postMessage
let firebaseInitialized = false;

self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'FIREBASE_CONFIG' && !firebaseInitialized) {
    try {
      firebase.initializeApp(event.data.config);
      const messaging = firebase.messaging();

      messaging.onBackgroundMessage((payload) => {
        const title = payload.notification?.title || 'Waffer';
        const options = {
          body: payload.notification?.body || '',
          icon: '/favicon.ico',
          badge: '/favicon.ico',
          data: payload.data || {},
          requireInteraction: true,
        };
        self.registration.showNotification(title, options);
      });

      firebaseInitialized = true;
      console.log('[SW] Firebase Messaging initialized');
    } catch (e) {
      console.error('[SW] Failed to init Firebase:', e);
    }
  }
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(
    clients.openWindow('/fcm-tester.html')
  );
});
