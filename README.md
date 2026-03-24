# SubStop

SubStop is a Flutter app for tracking personal subscriptions, renewal dates, and cancellation deadlines.

## Current Scope

- Local-first storage with SQLite
- Subscription list, detail, archive, and analytics screens
- Cancellation deadline notifications on supported mobile platforms
- Manual exchange-rate support for non-JPY plans

## Development

```bash
flutter pub get
flutter analyze
flutter test
```

## Notes

- Windows uses `sqflite_common_ffi` for SQLite access.
- Local notifications are intentionally skipped on web and Windows.
- Data is stored locally in the app database; no cloud sync is implemented yet.
