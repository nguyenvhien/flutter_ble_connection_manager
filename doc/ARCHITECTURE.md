# Architecture & Internal Design

This document describes the internal architecture of `flutter_ble_connection_manager`. 

If you are just looking to use the package, please read [`USAGE_AND_COMPARISON.md`](USAGE_AND_COMPARISON.md). This document is for contributors and maintainers who want to understand *how* the package works under the hood.

---

## 1. Domain-Driven Package Structure

The `lib/src/` directory is organized strictly by domain concepts, not by layer (like "models", "views", "controllers"). This makes the mental model of the package immediately obvious when you look at the file tree.

```text
lib/src/
├── connection/       # The public facade and configuration
├── lifecycle/        # State machines, events, and disconnect reasons
├── recovery/         # Retry strategies and backoff math
├── errors/           # Exception normalization
└── infrastructure/   # Core mechanical tools (Serialization, Cancellation)
```

Each folder represents an isolated boundary of concern. For example, the `recovery` domain knows nothing about the `lifecycle` domain. They are orchestrated together by the `BleConnectionManager` in the `connection` domain.

---

## 2. Core Components

### `BleConnectionManager` (The Facade)
Located in `connection/ble_connection_manager.dart`.
This is the only class the end-user interacts with. It acts as a Facade, hiding the complexity of the internal components. It manages the `flutter_blue_plus` device instance, holds the `ConnectionConfig`, and orchestrates the `LifecycleSerializer` and `RetryScheduler`.

### `LifecycleSerializer` (The Brain)
Located in `infrastructure/lifecycle_serializer.dart`.
This is arguably the most critical piece of infrastructure in the package. Mobile users are unpredictable—they might tap "Connect" multiple times, or tap "Connect" and immediately tap "Disconnect".

The `LifecycleSerializer` guarantees **Sequential Execution**:
- It ensures that no two lifecycle operations (`connect`, `disconnect`, `dispose`) can run concurrently.
- If `connect()` is already running, a second call to `connect()` will return the *same Future* (Deduplication).
- If `connect()` is running and the user calls `disconnect()`, the `disconnect()` operation is safely queued and will execute immediately after `connect()` finishes (or is cancelled).

### `RetryScheduler`
Located in `recovery/retry_scheduler.dart`.
This class takes a `RecoveryPolicy` (e.g., Exponential Backoff) and a `Future` returning function. It handles the math, the delays (`Future.delayed`), and the `while` loops needed to retry a failed connection safely.

### `CancellationToken`
Located in `infrastructure/cancellation_token.dart`.
Since Dart does not have native cooperative cancellation for `Futures`, we implemented a `CancellationToken`. This token is passed to the `onSetup` callback. The user can call `token.throwIfCancelled()` at any point in their setup logic to gracefully abort if the `BleConnectionManager` is commanded to disconnect.

---

## 3. Error Normalization

Vanilla BLE throws unpredictable errors (`FlutterBluePlusException`, generic `Exception`, etc.) depending on the underlying OS (iOS CoreBluetooth vs Android RxAndroidBle).

We normalize all these into a single sealed class hierarchy: **`BleConnectionException`** (located in `errors/ble_connection_exception.dart`).

- `TransportFailure`: Errors originating from the OS/Radio layer (e.g., GATT errors, timeout from the OS).
- `SetupFailure`: Errors thrown by the user's `onSetup` callback (e.g., Service not found, failed to enable notifications).
- `TimeoutFailure`: Thrown when our internal `ConnectionConfig.timeout` or `setupTimeout` triggers.
- `CancellationFailure`: Thrown when an operation is intentionally aborted.

By strictly normalizing errors, the `BleConnectionManager` and the end-user can exhaustively `switch` on failure types without guessing.

---

## 4. State Management and Events

We strictly separate **State** from **Events**.

**State (`BleConnectionState`)** is what the UI binds to:
- `disconnected`, `connecting`, `ready`, `disconnecting`.

**Events (`BleLifecycleEvent`)** are ephemeral milestones used for logging, analytics, or advanced debugging:
- `ConnectionAttemptStarted`
- `RetryScheduled`
- `ConnectionFailed`
- `Disconnected`

This separation means the UI does not have to filter out "Retry" events just to figure out what to render on screen.

---

## Conclusion

By keeping the public API surface small, relying on domain-driven structure, and pushing concurrency complexity into the `LifecycleSerializer`, we ensure that this package remains maintainable and highly resilient in production environments.
