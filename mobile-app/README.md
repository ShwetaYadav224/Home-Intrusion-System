# Home Security Mobile App

## Local Backend Setup (Port 8001)

The app is configured to target a backend running on port `8001`.

- Same Wi-Fi (phone + laptop) uses `http://172.20.10.10:8001`
- Android USB debug with `adb reverse` can use `http://127.0.0.1:8001`
- iOS simulator / desktop uses `http://localhost:8001`

This is handled automatically in [lib/config/app_config.dart](lib/config/app_config.dart).

You can override the backend URL at runtime:

```bash
flutter run --dart-define=BASE_URL=http://172.20.10.10:8001
```

## Run Locally

```bash
flutter pub get
flutter run
```

## Android Install Error: "Requested internal only, but not enough space"

If install fails with low storage on emulator/device:

```bash
adb uninstall com.homesecurity.home_security
adb shell pm trim-caches 128G
adb shell df -h /data
flutter clean
flutter pub get
flutter run
```

If space is still low, wipe emulator data in Android Studio Device Manager and run again.
