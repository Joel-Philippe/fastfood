// Give the service worker access to Firebase Messaging.
// Note that you can only use Firebase SDKs that don't require a DOM.
importScripts('https://www.gstatic.com/firebasejs/9.22.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.22.1/firebase-messaging-compat.js');

// Initialize the Firebase app in the service worker by passing in
// your app's Firebase config object.
// https://firebase.google.com/docs/web/setup#config-object
// DO NOT STORE SECRETS IN THIS FILE.
// This configuration should be injected at build time from environment variables.
const firebaseConfig = {
  apiKey: "YOUR_API_KEY",
  appId: "YOUR_APP_ID",
  messagingSenderId: "YOUR_MESSAGING_SENDER_ID",
  projectId: "YOUR_PROJECT_ID",
  authDomain: "YOUR_AUTH_DOMAIN",
  storageBucket: "YOUR_STORAGE_BUCKET"
};

// Retrieve your Firebase project configuration from `firebase_options.dart`
// and copy the web configuration here. This will be visible on your Firebase console -> Project settings -> General -> Your apps -> Web app.

firebase.initializeApp(firebaseConfig);

// Retrieve an instance of Firebase Messaging so that it can handle background
// messages.
const messaging = firebase.messaging();

messaging.onBackgroundMessage(function(payload) {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  // Customize notification here
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/firebase-logo.png' // Replace with your app icon
  };

  return self.registration.showNotification(
    notificationTitle,
    notificationOptions
  );
});
