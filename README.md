# Javelin Workout Tracker

A Flutter + Firebase training tracker: log workouts set by set, track body
weight, and chart progression over time.

## Features

- Email/password and Google sign-in (Firebase Auth)
- A per-athlete exercise catalogue, searchable, with custom exercises
- An in-progress workout that syncs live and survives the app closing,
  including its clock
- Finished workouts stored per user, with totals on the overview
- Body-weight logging and a progression chart
- Progress tab charting body weight or any exercise's heaviest set, total
  volume, or total reps
- Coaching: share a code, and the athletes who redeem it let you read their
  workout history

## Running it

```bash
flutter pub get
flutter run
```

## Android toolchain constraint

The Firebase, `google_sign_in` and `image_picker` dependencies are **pinned to
exact versions** in `pubspec.yaml`, not ranges. The next release of each builds
against `compileSdk 34`, which this project's Android toolchain cannot compile:

| | version |
|---|---|
| Android Gradle Plugin | 7.3.0 |
| Gradle | 7.5 |
| JDK | 11 (Android Studio's bundled JRE) |
| build-tools | 33 |

`android/app/build.gradle` therefore pins `compileSdkVersion 33` and
`targetSdkVersion 33` rather than using `flutter.compileSdkVersion`, which is
34 on Flutter 3.19.5.

To move to compileSdk 34, upgrade **all** of it together: AGP to 8.1.1+,
Gradle to 8.x, the JDK to 17, install build-tools 34.0.0, and accept the SDK
licences (`flutter doctor --android-licenses`). Then the version pins can
become ranges again.

## Firebase

Security rules live in `firestore.rules` and `storage.rules`. They scope every
document and upload to its owning `uid`. Deploy them with:

```bash
firebase deploy --only firestore:rules,storage
```

Data layout:

```
users/{uid}                         profile, exercise catalogue,
                                    currentWorkout, currentWorkoutTimer,
                                    weightHistory, coachCode,
                                    coachUids, coaches
users/{uid}/workouts/{workoutId}    finished workouts
coachInvites/{code}                 code -> coach uid and display name
```

### Coaching

Access is always granted **by the athlete**, never taken by the coach:

1. A coach creates an invite code, stored as `coachInvites/{code}` and
   mirrored onto their own `coachCode`.
2. The athlete enters the code. That writes the coach's uid to the athlete's
   own `coachUids` array, plus a display entry in `coaches`.
3. The coach lists athletes with
   `users.where('coachUids', arrayContains: myUid)` and reads each athlete's
   `workouts` subcollection.

Because user documents are owner-write-only, a coach cannot add themselves to
anyone. Coach access is read-only, and the athlete can revoke it at any time.
`coachUids` is the array the rules check, while `coaches` carries only display
names, so the athlete can see who has access without being able to read a
coach's profile document.

Workouts used to live in a `workoutHistory` array on the user document.
`WorkoutRepository.migrateLegacyWorkoutHistory` moves them into the
subcollection on launch and is a no-op once done.

## Tests

```bash
flutter test
```

Covers the Firestore model round trips (including the legacy formats), the
wall-clock workout timer, and the exercise progression calculations.
