# Development Roadmap

This document outlines the strategic roadmap for the `flutter_ble_connection_manager` package. It helps maintainers and contributors align on upcoming features, testing strategies, and stable releases.

---

### 🎯 Version 0.1.0 (Current - Completed)
**Goal:** Build a rock-solid core and standard documentation.
- ✅ **Core Lifecycle:** Safe state transitions (`Disconnected` -> `Connecting` -> `Ready`).
- ✅ **Concurrency Control:** Implement `LifecycleSerializer` to prevent Race Conditions (e.g., spam clicking).
- ✅ **Auto-Recovery:** Exponential Backoff & automatic Retry when the connection drops.
- ✅ **Mock Testing & Example:** Full App Example with Mock Mode (5 simulated scenarios), supporting Simulator/Emulator.
- ✅ **Documentation:** `pub.dev` standard README, Architecture Specs (`EXAMPLE_ARCHITECTURE.md`, `ARCHITECTURE.md`, etc.).

---

### 🛡️ Version 0.2.0 (Current - Completed)
**Goal:** Quality Assurance (QA) and Automation.
- ✅ **Unit Tests & Mock Tests (High Coverage):** Write comprehensive test cases for `LifecycleSerializer`, `RetryScheduler`, and the error throwing flows (`BleConnectionException`).
- ✅ **Widget Tests:** Write UI tests (e.g., test spam-clicking the Connect button in Mock Mode to ensure the app doesn't crash).
- ✅ **CI/CD Pipeline:** Integrate **GitHub Actions** to automatically run `flutter analyze` and `flutter test` on every push and Pull Request.

---

### 🚀 Version 0.3.0 (Next Up)
**Goal:** Solve complex real-world community problems.
- [ ] **Advanced Logging:** Integrate a robust Logger system (customizable or exportable) to help developers easily trace issues on end-user devices.
- [ ] **Background Support (Optional):** Research maintaining the Connection Manager when the app enters the Background or is temporarily killed by the OS (iOS/Android constraints apply).
- [ ] **State Management Wrappers:** Provide additional example files or sub-packages demonstrating how to map `BleConnectionState` into Bloc/Riverpod/Provider.

---

### 👑 Version 1.0.0 (Stable Release)
**Goal:** Enterprise-ready.
- [ ] No remaining Breaking Changes.
- [ ] The core APIs (`BleConnectionManager`, `ConnectionConfig`) are proven stable in large-scale production projects.
- [ ] Official release on `pub.dev` with top-tier badges and scoring.
