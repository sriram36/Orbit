# Orbit — Daily Routine & Habit Tracker

Orbit is a cross-platform mobile app built with Flutter that helps you build and maintain daily habits through routines, streaks, and visual progress tracking. Designed around a clean, modern UI with smooth animations and satisfying feedback.

---

## Features

### Core
- **Daily Routines** — Create routines made up of tasks and subtasks. Everything resets automatically each day so you start fresh.
- **Streak Tracking** — A fire-emoji streak counter rewards consistent daily completion. Persisted locally, updates the Android home screen widget.
- **Subtasks** — Every task inside a routine can have its own nested subtasks (steps).
- **Importance Flagging** — Star any task to mark it as important.
- **Pinned Routines** — Pin a routine to keep it at the top of the list.

### Organization
- **Categories** — Filter routines by built-in categories (All, Work, Personal, Health) or create your own.
- **Search** — Full-text search across routine titles and task names.
- **Drag & Drop Reorder** — Reorder both routines on the home screen and tasks inside a routine via drag-and-drop.
- **Grid / List Views** — Toggle between a card grid and a compact list on the home screen.

### Productivity
- **Notifications** — Schedule a daily reminder per task. Timezone-aware, repeats daily.
- **Daily Auto-Reset** — Routines reset at 3:00 AM (configurable in Settings). Tracks last reset time per routine.
- **Progress Bars** — Each routine card shows a live progress bar and item counter (e.g., 5 / 10 items done).

### History & Insights
- **History Screen** — Interactive monthly/weekly calendar view. Each day is color-coded: green (complete), orange (partial), grey (none).

### Polish
- **Confetti** — Confetti animation fires when you complete all tasks in a routine.
- **Haptic Feedback** — Subtle vibration on key actions.
- **Animations** — Splash screen, category filter transitions, list fade-ins, and more via `flutter_animate`.
- **Light & Dark Themes** — Neon cyan accent on dark navy (dark mode) or soft teal on white (light mode). Outfit font throughout.
- **Android Home Widget** — Displays current streak directly on the home screen.

---

## Screens

| Screen | Description |
|---|---|
| **Splash** | Animated logo with scale/fade/shimmer, 3-second boot sequence |
| **Home** | Routine grid/list, category filter chips, search, streak badge |
| **Checklist** | Task & subtask checklist, importance stars, reminder picker, confetti |
| **History** | Calendar heatmap of daily completion rates |
| **Settings** | Theme toggle, daily reset time picker, data management |

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter 3.38.5 / Dart 3.10.4 |
| Local Storage | `shared_preferences` |
| Notifications | `flutter_local_notifications` + `timezone` |
| Fonts | `google_fonts` (Outfit) |
| Calendar UI | `table_calendar` |
| Reordering | `flutter_reorderable_grid_view` |
| Animations | `flutter_animate`, `confetti` |
| Home Widget | `home_widget` |
| Internationalization | `intl` |

---

## Project Structure

```
to_do/
├── lib/
│   ├── main.dart                    # Entry point, theme config
│   ├── screens/
│   │   ├── splash_screen.dart
│   │   ├── home_screen.dart
│   │   ├── checklist_screen.dart
│   │   ├── history_screen.dart
│   │   └── settings_screen.dart
│   └── services/
│       ├── notification_service.dart
│       └── widget_service.dart
├── android/                         # Android platform code + home widget
├── ios/                             # iOS platform code
├── web/                             # Web manifest
├── assets/icon/icon.jpg
└── pubspec.yaml
```

---

## Data Model

All data is stored locally as JSON via `shared_preferences`. No backend or account required.

```jsonc
// A single routine
{
  "id": 1,
  "title": "Morning Routine",
  "color": 4278255615,       // ARGB int
  "isPinned": false,
  "category": "Health",
  "items": [
    {
      "id": 1,
      "text": "Drink water",
      "checked": false,
      "isImportant": true,
      "notifyTime": "07:00",  // null if no reminder
      "subtasks": [
        { "id": 1, "text": "500ml", "checked": false }
      ]
    }
  ]
}
```

---

## Getting Started

### Prerequisites
- Flutter SDK installed — run `flutter doctor` to verify.
- Android Studio or VS Code with the Flutter extension.

### Run locally

```bash
git clone <repository-url>
cd Orbit/to_do
flutter pub get
flutter run
```

### Build for Android

```bash
flutter build apk --release
```

---

## Platform Support

| Platform | Status |
|---|---|
| Android | Primary |
| iOS | Supported |
| Web | Supported |
| Windows | Supported |
| macOS | Supported |
| Linux | Supported |

---

## Color Palette

| Role | Dark Mode | Light Mode |
|---|---|---|
| Primary | `#00FFFF` Neon Cyan | `#00CED1` Dark Turquoise |
| Background | `#1A2132` Dark Navy | `#F5FDFD` Soft Cyan Tint |
| Card | `#252D40` Lighter Navy | White |
| Accent / Streak | `#FF9800` Orange | `#FF9800` Orange |

---

## Built With

- [Flutter](https://flutter.dev/)
- [shared_preferences](https://pub.dev/packages/shared_preferences)
- [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications)
- [flutter_reorderable_grid_view](https://pub.dev/packages/flutter_reorderable_grid_view)
- [flutter_animate](https://pub.dev/packages/flutter_animate)
- [table_calendar](https://pub.dev/packages/table_calendar)
- [confetti](https://pub.dev/packages/confetti)
- [home_widget](https://pub.dev/packages/home_widget)
- [google_fonts](https://pub.dev/packages/google_fonts)
