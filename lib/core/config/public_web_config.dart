class PublicWebConfig {
  const PublicWebConfig._();

  static const googlePickerApiKey = String.fromEnvironment(
    'GOOGLE_PICKER_API_KEY',
  );
  static const googleAppId = String.fromEnvironment('GOOGLE_APP_ID');
  static const googleOAuthClientId = String.fromEnvironment(
    'GOOGLE_OAUTH_CLIENT_ID',
  );

  static const firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const firebaseAuthDomain = String.fromEnvironment(
    'FIREBASE_AUTH_DOMAIN',
  );
  static const firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
  );
  static const firebaseMessagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const firebaseAppId = String.fromEnvironment('FIREBASE_APP_ID');
  static const firebaseVapidKey = String.fromEnvironment('FIREBASE_VAPID_KEY');

  static Map<String, String> get firebaseConfig => <String, String>{
    'apiKey': firebaseApiKey,
    'authDomain': firebaseAuthDomain,
    'projectId': firebaseProjectId,
    'messagingSenderId': firebaseMessagingSenderId,
    'appId': firebaseAppId,
    'vapidKey': firebaseVapidKey,
  };

  static bool get hasFirebasePushConfig {
    return firebaseApiKey.isNotEmpty &&
        firebaseProjectId.isNotEmpty &&
        firebaseMessagingSenderId.isNotEmpty &&
        firebaseAppId.isNotEmpty &&
        firebaseVapidKey.isNotEmpty;
  }
}
