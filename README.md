# LR17 Notes App: Firebase Firestore Database

Навчальний Flutter Beginner project для лабораторної роботи LR17. Додаток реалізує Firebase Authentication, Firestore CRUD для нотаток, real-time updates через `StreamBuilder` і зберігання даних окремо для кожного користувача у структурі:

```text
users/{userId}/notes/{noteId}
```

## Що створити у Firebase Console

1. Створіть Firebase project або відкрийте наявний.
2. Додайте Android app з package name:

```text
com.example.flutter_firestore_app
```

3. Увімкніть Authentication -> Sign-in method -> Email/Password.
4. Створіть Firestore Database у production або test mode, після цього замініть rules на наведені нижче.

## Android Firebase config

Файл `google-services.json` потрібно взяти у Firebase Console:

Firebase project -> Project settings -> Your apps -> Android app -> Download `google-services.json`.

Покладіть його сюди:

```text
android/app/google-services.json
```

У цьому проєкті файл уже є в `android/app/`.

Перевірте `android/settings.gradle.kts`, що є Google Services plugin:

```kotlin
id("com.google.gms.google-services") version "4.4.4" apply false
```

Перевірте `android/app/build.gradle.kts`, що plugin застосований:

```kotlin
id("com.google.gms.google-services")
```

Також перевірте, що `applicationId` збігається з package name у Firebase:

```kotlin
applicationId = "com.example.flutter_firestore_app"
```

## Flutter Firebase initialization

У `lib/main.dart` уже є:

```dart
WidgetsFlutterBinding.ensureInitialized();
await Firebase.initializeApp();
FirebaseFirestore.instance.settings = const Settings(
  persistenceEnabled: true,
);
```

Якщо ви не використовуєте FlutterFire CLI, для Android достатньо правильного `google-services.json` і Gradle plugin. Якщо пізніше додасте `firebase_options.dart`, тоді замініть initialization на:

```dart
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

## Firestore Security Rules

Вставте ці rules у Firebase Console -> Firestore Database -> Rules:

```text
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/notes/{noteId} {
      allow read, create, update, delete: if request.auth != null
        && request.auth.uid == userId;
    }
  }
}
```

## Коли запускати flutter pub get

Після зміни `pubspec.yaml` запустіть:

```bash
flutter pub get
```

## Команди після внесення змін

```bash
flutter pub get
flutter analyze
flutter run
```

Якщо Android build не підхопив Firebase config, зробіть clean:

```bash
flutter clean
flutter pub get
flutter run
```

## Що перевірити після запуску

1. Екран login/register відкривається без помилок.
2. Реєстрація через email/password працює.
3. Після входу відкривається список нотаток.
4. Кнопка `Add note` створює нотатку.
5. Нотатка з'являється автоматично без ручного refresh.
6. Натискання на картку або edit icon відкриває редагування.
7. Delete icon показує confirmation dialog.
8. Після видалення нотатка зникає автоматично.
9. У Firebase Console дані зберігаються в `users/{uid}/notes/{noteId}`.
10. Для іншого користувача список нотаток окремий.
