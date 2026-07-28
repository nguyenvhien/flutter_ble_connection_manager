## 0.2.2

* **Documentation:** Completely redesigned `example/lib/main.dart` to showcase a minimal, real-world `DeviceConnectionScreen` directly in the pub.dev Example tab.

## 0.2.1

* **Documentation:** Added "When should I use this package?" and "Why FlutterBluePlus 1.x?" sections to the `README.md` to clarify the target audience and licensing decisions.
* **Metadata:** Refined the package description in `pubspec.yaml` to focus on concrete pain points (setup, readiness, cancellation, retries).
* **Maintenance:** Improved package hygiene by:
  * Renaming `docs/` to `doc/` to satisfy pub.dev analysis.
  * Adding `.pubignore` to exclude development files, reducing the published archive to ~78 KB.
  * Fixing `.gitignore` so the `example/` project is included in source control.

## 0.2.0

* **Stability, testing, and CI improvements.**
* **Testing:** Achieved 100% test coverage for the core connection lifecycle components:
  * `BleConnectionManager`
  * `LifecycleSerializer`
  * `RetryScheduler`
* **Testing:** Added integration smoke tests covering five common BLE connection scenarios.
* **CI/CD:** Integrated a GitHub Actions workflow to run `flutter test` and `dart analyze` for the core package and example app on every push and pull request.
* **Bug Fix:** Fixed an issue in `MockBleConnectionManager` where `stateStream` did not behave as a `BehaviorSubject`, causing late subscribers to miss the initial state.
* **Bug Fix:** Added `Zone`-based deadlock detection to `LifecycleSerializer` to prevent recursive lifecycle operations during setup callbacks.

## 0.1.0

* Initial public release.
