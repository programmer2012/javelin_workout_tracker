# Progress Summary

Working session on the Javelin Workout Tracker. Starting point was a code
review of the whole app; the work since then has been, in order: make the
core tracking loops correct, get the app building on Android again, close the
gaps the review found, and build the Coach's Zone.

**Status: all work is verified but uncommitted, and two things are not yet
live.** See [Outstanding actions](#outstanding-actions).

| Check | Result |
|---|---|
| `flutter analyze` | **No issues found** (was 13 infos) |
| `flutter test` | **47 passing** (was 7 passing, 1 failing) |
| `flutter build apk --debug` | **succeeds** |
| `flutter build web` | **succeeds** |
| Firestore / Storage rules deployed | **No — action required** |
| New build installed on device | **No — blocked by Samsung Auto Blocker** |
| Committed to git | **No** — last commit is still `b2ad32c` |

---

## 1. Correctness fixes

### Workout duration was systematically wrong

The timer added a fixed one second per `Timer.periodic` tick. Mobile
platforms suspend timers for backgrounded apps, so every minute the phone
spent locked in a pocket between sets was lost — a 75-minute session could
record as 20.

Elapsed time is now derived from the wall clock. `WorkoutTimerState` stores
the instant the clock started plus the time already banked; the periodic
timer only triggers repaints and never contributes to the value.

### Resumed workouts recorded a duration of zero

Exercises round-tripped through Firestore but elapsed time never did, and the
timer only auto-started from "choose exercise". Closing the app mid-workout
restored the exercises with the clock at `00:00:00`, and saving wrote
`Duration.zero`.

The clock is now persisted to `currentWorkoutTimer` and restored on load,
including whether it was running. Writes happen only on start/stop/reset via
a dedicated `onTransition` callback — never on the once-a-second repaint, so
this does not write to Firestore every second. A test pins that distinction.

### Sign-in could hang forever

The spinner dialog was dismissed only on success or `FirebaseAuthException`.
Any network or platform error escaped the `catch`, leaving an undismissable
spinner. Now a `finally` always dismisses it, the navigator is captured
*before* the await (a successful sign-in unmounts the page, so the old
`mounted` guard could itself strand the spinner), and `barrierDismissible:
false` stops a stray tap from popping the login page instead.

### Dead masked field on the login screen

The login form had a `Username` field with `obscureText: true` that no code
ever read — two bullet-masked boxes, one of them inert. Removed.

### Profile pictures stored as the wrong type

`putData(file)` was called with no metadata, so uploads landed as
`application/octet-stream` and downloaded rather than rendered. Content type
is now set from `XFile.mimeType`, falling back to sniffing magic bytes
(JPEG/PNG/GIF/BMP/WebP/HEIC). This also had to be fixed before the storage
rules could require an `image/*` type. A failed upload no longer leaves the
new picture displayed as though it worked.

### Smaller fixes

- Seven `TextEditingController`s leaked in the auth pages — now disposed.
- Number/date coercion was duplicated across three models; extracted to
  `utils/coerce.dart`.
- `Map<dynamic, dynamic>` page parameters tightened to `Map<String, dynamic>`.

---

## 2. Features

### Body weight is readable

Weight logging wrote to Firestore and nothing ever read it back — the only
place it would have appeared was a hardcoded sample chart.

`weight_entry.dart` reads `weightHistory`, tolerating both epoch-millis and
`Timestamp` dates and comma decimals, dropping unplottable records rather
than throwing, sorted oldest-first. The overview card now shows
`Last: 84.3 kg (20.10.)` so a submit is visibly confirmed.

### Real charts, replacing 387 lines of sample data

`line_chart_widget.dart` was the unmodified `fl_chart` demo — hardcoded
`FlSpot`s and a y-axis reading "1m, 2m, 3m, 5m, 6m". It drove both the
overview's progression card and the entire fifth tab. Deleted.

`progress_chart.dart` plots real data. The x axis is **days since the first
point**, not list position, so a month without training renders as a gap
rather than an even step. Handles the empty state, a single point (which
would otherwise collapse the axis to zero width), and a flat value. Gridlines
snap to round numbers.

Axis labels add a two-digit year **only** when the history crosses a year
boundary — verified on-device, where a history running Oct 2025 → Oct 2026
labelled both ends "x.10." and read as a few weeks.

### Progress tab with an exercise picker

A **Show** dropdown lists Body Weight plus every exercise found in the
workout history, and picking an exercise reveals an **as** dropdown:

| Metric | Meaning |
|---|---|
| Heaviest set | top working weight that session |
| Total volume | reps × weight, summed |
| Total reps | reps, summed |

Decisions in `models/progression.dart`:

- The same exercise listed twice in one workout collapses to one point —
  heaviest wins for max weight, the others sum.
- Matching is case-insensitive, displaying the first spelling seen, so
  "Bench Press" and "bench press" are not two picker entries.
- **A weight typed with 0 reps is ignored** — that is an unfilled row, not a
  set. Without this, typing `200` into an empty row would spike the chart.
- Zero-valued workouts are dropped, so a bodyweight exercise shows nothing
  under "heaviest set" but full data under "total reps".
- A deleted exercise falls back to Body Weight rather than charting nothing.

### Coach's Zone

Access is always granted **by the athlete** and is read-only:

1. Coach taps **Create my code** → a six-character code at
   `coachInvites/{code}`.
2. The athlete enters it, writing the coach's uid onto the **athlete's own**
   document.
3. The coach's athlete list appears; tapping one opens their workout history.
4. The athlete can revoke at any time.

Because user documents are owner-write-only, a coach cannot add themselves to
anyone — that is enforced by the rules, not just hidden in the UI. The page
serves both roles at once, since a user is often both.

Two fields carry the link, deliberately:

- `coachUids` — a flat array, so a coach can query
  `where('coachUids', arrayContains: myUid)`.
- `coaches` — a uid-keyed map of display names only, so an athlete can see
  who has access without being able to read a coach's profile document.

Revoking clears both; leaving a uid in `coachUids` would silently keep access
alive.

Invite codes avoid user enumeration — there is no lookup by email, so nobody
can probe which addresses have accounts. The alphabet excludes `0/O` and
`1/I/L`, the pairs people misread when a code is read aloud, and collisions
are checked before use.

### Workout history list

The app had **no way to view past workouts at all** — nothing read the
`workouts` subcollection except the totals. `workout_history_list.dart` shows
expandable cards per session: weekday and date, duration, an
exercise/rep/volume summary, and every set as `8 × 60 kg`. Built as a shared
component, so it can be reused for the athlete's own history.

---

## 3. Infrastructure and security

### Security rules now exist

There were none in the repo — the entire access policy lived unversioned in
the Firebase console.

- `firestore.rules` — every document scoped to `request.auth.uid`, plus the
  coaching read path. Catch-all deny, which also closes the global `note`
  collection left by a tutorial.
- `storage.rules` — profile-picture writes restricted to the owner, with an
  `image/*` content-type requirement and a 5 MB cap. That path was previously
  an open upload endpoint.
- `firebase.json`, `.firebaserc`, `firestore.indexes.json` — so the rules are
  deployable and pinned to `workout-tracker-javelin`.

Note the client config files (`google-services.json`, `firebase_options.dart`)
being committed is **not** a problem — those are public by Firebase's design,
which is exactly why the rules matter.

### The Android build was broken

The lockfile had resolved every Firebase plugin to its **compileSdk 34**
generation, while the toolchain (AGP 7.3.0 / Gradle 7.5 / JDK 11 /
build-tools 33) tops out at 33.

Six plugins are now pinned to their last compileSdk-33 release, and
`android/app/build.gradle` pins `compileSdkVersion 33` / `targetSdkVersion 33`
rather than using `flutter.compileSdkVersion`, which is 34 on Flutter 3.19.5.
Exact pins, not ranges, so a later `pub get` cannot silently re-break it.

**That pinning then broke the web build** — `firebase_core_web` resolved to
2.17.5, which removed `PromiseJsImpl`, while the pinned web implementations
still reference it. Android was unaffected, so the APK builds hid it. Pinning
`firebase_core_web: 2.9.0` fixes web and changes nothing on Android.

### Dead code removed

`home_page.dart` (a "Notes von" tutorial page), `services/firestore.dart` (its
global `note` collection service), `models/user.dart` (unused), the
`stop_watch_timer` dependency, and the stale `widget_test.dart` counter
template that was failing the suite.

### Duplicate data fetching

The overview and progress pages each opened their own listener on the whole
workouts collection. `MainView` now owns one listener and passes the list to
both. Chosen over denormalised counters because the progress page needs the
history anyway for the exercise charts, so this removes the second stream
with no backfill and no double-count risk.

### Layout fragility

A `height: 500` card containing a `height: 400` list, and a per-exercise set
list in a fixed 150px scroller sized by `50 * sets.length`. Both now use
`Expanded` and natural height, so the screen adapts instead of overflowing on
a small phone or at a large font scale.

---

## 4. Verified on device

Installed and driven on an SM G996B (Galaxy S21+, Android 15):

- In-progress workout restored correctly.
- **The timer counted real wall-clock time** — `00:00:02` → `00:00:15` across
  ~13 seconds, the exact bug that was broken.
- Progress tab rendered real data: 3 weight entries, current 84.3 kg,
  +0.9 kg since 5.10.2025, y-axis auto-scaled 82.4–86.3.

The device currently runs the **first** build. It does not have: year-aware
axis labels, the exercise picker, the Coach's Zone, the layout fixes, or the
content-type fix.

---

## Outstanding actions

### 1. Deploy the security rules

Nothing is live yet, so the backend still runs whatever the console has.
**Coaching will not work until this runs** — the athlete list and workout
reads will be permission-denied.

```bash
firebase deploy --only firestore:rules
```

The rules changed meaningfully when coaching was added — they now permit
cross-user reads for the first time. Worth reading before deploying.

Deploy the storage rules **only after** the new build is on the device, since
they require the `image/*` content type that only the new build sends:

```bash
firebase deploy --only storage
```

### 2. Install the new build

Blocked by the device, not the code — `INSTALL_FAILED_VERIFICATION_FAILURE`.
On the phone: Settings → Security and privacy → **Auto Blocker** → off, and
Developer options → **Verify apps over USB** → off. Then:

```bash
flutter install --debug -d RFCR60G1VBA
```

### 3. Commit

All of the above is uncommitted; the last commit is `b2ad32c`.

---

## Deliberately deferred

| Item | Why |
|---|---|
| `weightHistory` → subcollection | Needs a migration; the array is fine at single-digit entries. Revisit as it grows, since the whole array re-downloads on every user-document change. |
| Denormalised workout totals | Adds a backfill and a double-count risk for little gain at current scale. The single shared stream already removed the duplicate fetch. |
| Charts / summary tiles / notes in the coach view | Scoped out — workout history only. The repository and rules already support charts cheaply, since `watchWorkoutsOf` returns the same `Workout` list the picker consumes. |
| Javelin-specific tracking | The model is a general gym tracker: `reps` and `weight [kg]`. Nothing records throws, distances, run-up, or implement weight. Worth deciding before more code accretes around `WorkoutSet`. |
| `path_provider_android` SDK 34 warning | Transitive via `google_fonts`. Warns at build time but compiles and runs. First suspect if font or file-path oddities appear. |

---

## Test coverage

47 tests, all passing:

| File | Tests | Covers |
|---|---|---|
| `coach_test.dart` | 13 | invite code generation, normalisation, coach link parsing |
| `workout_timer_test.dart` | 12 | wall-clock elapsed, the backgrounded-app regression, clock moving backwards, Firestore round trips, tick-is-not-a-transition |
| `progression_test.dart` | 10 | exercise name collection, per-metric progression, duplicate exercises, unfilled sets |
| `workout_model_test.dart` | 7 | model round trips including the legacy `workoutHistory` formats |
| `weight_entry_test.dart` | 5 | weight parsing, sorting, dropping bad records |
