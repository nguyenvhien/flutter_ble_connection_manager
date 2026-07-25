# flutter_ble_connection_manager

[![pub package](https://img.shields.io/pub/v/flutter_ble_connection_manager.svg)](https://pub.dev/packages/flutter_ble_connection_manager)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![CI](https://github.com/nguyenvhien/flutter_ble_connection_manager/actions/workflows/ci.yml/badge.svg)](https://github.com/nguyenvhien/flutter_ble_connection_manager/actions)
[![Coverage](https://codecov.io/gh/nguyenvhien/flutter_ble_connection_manager/branch/main/graph/badge.svg)](https://codecov.io/gh/nguyenvhien/flutter_ble_connection_manager)

A production-grade BLE connection lifecycle manager built on top of `flutter_blue_plus`.

## Why This Package Exists

Most production BLE applications eventually implement the same connection management logic. Instead of rewriting that logic for every project, this package provides a reusable lifecycle manager.

Managing BLE connections in mobile apps is notoriously difficult. Applications often struggle with race conditions when users repeatedly press "Connect", unhandled edge cases during service discovery, and complex reconnection logic when devices unexpectedly drop.

This package provides a structured, observable, and resilient lifecycle manager to transition a BLE device from Disconnected to Application Ready.

## Architecture Overview

```text
Flutter App
        │
        ▼
flutter_ble_connection_manager
        │
        ▼
flutter_blue_plus
        │
        ▼
Android / iOS BLE
```

## Why not just use flutter_blue_plus?

`flutter_blue_plus` is an excellent BLE transport library. However, production applications often need additional connection lifecycle management such as retry strategies, lifecycle serialization, timeout handling and connection readiness. This package complements `flutter_blue_plus` rather than replacing it.

## Responsibilities

This package focuses strictly on connection lifecycle management:
- Connection lifecycle
- Connection state machine
- Retry & reconnection
- Timeout management
- Lifecycle serialization
- Connection readiness
- Lifecycle events
- Structured errors

## Non-goals

This package is **NOT** a general-purpose BLE library and does not replace `flutter_blue_plus`.

`flutter_blue_plus` remains fully responsible for:
- Scanning and discovering devices
- Reading and writing characteristics
- Subscribing to notifications
- Descriptors management
- Raw BLE transport

## Features

### Implemented
- **Lifecycle State Machine**: Strictly enforces states (`disconnected`, `connecting`, `ready`, `disconnecting`).
- **Retry Scheduler**: Built-in exponential backoff for handling transient connection failures.
- **Lifecycle Serialization**: Automatically deduplicates concurrent `connect()` or `disconnect()` calls.
- **Cancellation**: Allows in-flight connection attempts to be gracefully aborted.
- **Typed Exceptions**: Wraps unpredictable BLE errors into predictable exceptions.

### Design Principles
- **Minimal Public API**: Intentionally small surface area.
- **Predictable Lifecycle**: Expose strict states and explicit errors instead of silently swallowing failures.
- **Composition over Inheritance**: Designed to compose cleanly with `flutter_blue_plus`.

## Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_ble_connection_manager:
    path: ./path/to/flutter_ble_connection_manager
```

## Quick Start

```dart
final manager = BleConnectionManager(
  device: myBluetoothDevice,
  config: ConnectionConfig(
    timeout: const Duration(seconds: 15),
    recoveryPolicy: RecoveryPolicy.exponentialBackoff(maxAttempts: 3),
    onSetup: (device, token) async {
      // Define what "Ready" means for your app.
      final services = device.servicesList;
      final char = services.first.characteristics.first;
      await char.setNotifyValue(true);
      token.throwIfCancelled();
    },
  ),
);

// connect() completes ONLY when the device is Application Ready —
// not just BLE-connected.
await manager.connect();

// The device is ready. Use flutter_blue_plus directly.
await manager.disconnect();
await manager.dispose();
```

See [`example/`](example/) for complete usage patterns.

## Core Concepts

- **BleConnectionManager**: The central facade managing a single `BluetoothDevice`. You should instantiate one manager per device.
- **BleConnectionState**: A strictly enforced state machine (`disconnected`, `connecting`, `ready`, `disconnecting`).
- **BleLifecycleEvent**: A detailed event stream containing milestones (e.g., `ConnectionAttemptStarted`, `RetryScheduled`, `Disconnected`).
- **RecoveryPolicy**: Determines if and how a failed connection attempt should be retried.
- **Concurrent Operations**: Concurrent lifecycle operations are automatically serialized to prevent race conditions.

## Project Philosophy

- **Small Surface Area**: The public API is intentionally minimal.
- **Single Responsibility**: Manage the connection. Nothing else.
- **Predictability Over Magic**: Expose strict states and explicit errors instead of silently swallowing failures.
- **Domain-Driven Architecture**: The internal package structure reflects the developer's mental model (`connection`, `lifecycle`, `recovery`, `infrastructure`, `errors`).

## Current Status

- Core state machine and lifecycle events are implemented.
- Lifecycle serialization (race condition prevention) is implemented.
- Recovery policies and retry scheduler are implemented.
- Core unit tests are in place. Continuous integration validates formatting, analysis and test execution.

## Roadmap

Upcoming:
- Structured logging
- Heartbeat extension
- RSSI monitoring
- OTA extension points
- Stable public API

## Contributing

Contributions are welcome. Please read `docs/ARCHITECTURE.md` before proposing architectural changes.

## License

MIT License
