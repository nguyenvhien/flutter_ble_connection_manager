## 0.2.0

* **Quality Assurance & Automation Release**.
* **Testing:** Added 100% test coverage for `BleConnectionManager`, `LifecycleSerializer`, and `RetryScheduler`.
* **Testing:** Added `MockBleConnectionManager` UI Smoke Tests in the `example` app for 5 real-world hardware scenarios.
* **CI/CD:** Integrated GitHub Actions workflow to run automatic `flutter test` and `dart analyze` for core package and example app on every Push/PR.
* **Bug Fix (Mock):** Fixed an issue in `MockBleConnectionManager` where `stateStream` did not behave as a `BehaviorSubject`, causing late subscribers to miss the initial state.
* **Bug Fix (Serializer):** Implemented strict `Zone`-based deadlock detection in `LifecycleSerializer` to prevent accidental recursion during setup callbacks.

## 0.1.0

- Initial development release.
