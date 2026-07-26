# flutter_ble_connection_manager

[![pub package](https://img.shields.io/pub/v/flutter_ble_connection_manager.svg)](https://pub.dev/packages/flutter_ble_connection_manager)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![CI](https://github.com/nguyenvhien/flutter_ble_connection_manager/actions/workflows/ci.yml/badge.svg)](https://github.com/nguyenvhien/flutter_ble_connection_manager/actions)
[![Coverage](https://codecov.io/gh/nguyenvhien/flutter_ble_connection_manager/branch/main/graph/badge.svg)](https://codecov.io/gh/nguyenvhien/flutter_ble_connection_manager)

A Flutter package that manages the complete BLE connection lifecycle on top of `flutter_blue_plus`.

## Why

Handling Bluetooth Low Energy (BLE) connections in mobile applications is difficult. A successful radio connection does not mean the device is ready to use. Applications must handle timeouts, discover services, enable notifications, manage race conditions (e.g., users repeatedly pressing "Connect"), and recover from unexpected disconnections.

Most production BLE applications eventually implement the same connection management logic. This package extracts that logic into a reusable component.

Instead of scattering `try/catch` blocks and state management across your UI, this package provides a structured, observable lifecycle manager.

## Solution

`flutter_ble_connection_manager` provides a single facade that handles the connection lifecycle, concurrent operation serialization, and recovery logic. It complements `flutter_blue_plus` by managing *how* the connection is maintained, while leaving the actual BLE transport to the underlying library.

## Architecture

```text
Flutter App
        │
        ▼
flutter_ble_connection_manager  (Lifecycle, Retry, Serialization, State)
        │
        ▼
flutter_blue_plus               (Scanning, Services, Characteristics, Transport)
        │
        ▼
Android / iOS BLE
```

## Responsibilities

This package manages:
- **Strict Lifecycle State Machine**: Enforces `disconnected`, `connecting`, `ready`, and `disconnecting`.
- **Concurrency Serialization**: Automatically deduplicates concurrent `connect()` requests and queues `disconnect()` requests to prevent race conditions.
- **Retry & Recovery**: Built-in exponential backoff for handling transient failures.
- **Cancellation**: Gracefully aborts in-flight connection attempts.
- **Lifecycle Events**: Detailed event stream broadcasting every milestone, retry, or failure.

## Non-goals

This package focuses **strictly on the Connection Lifecycle**. It is **NOT** a general-purpose BLE library. It does not wrap or replace `flutter_blue_plus`. 

To prevent scope creep, we will **NOT** add features for:
- Scanning for devices.
- Reading/Writing characteristics or Write Queues.
- OTA (Over-the-Air) updates.
- Protocol parsing.
- Auto MTU negotiation (do it in `onSetup`).

`flutter_blue_plus` remains fully responsible for all underlying BLE transport.

## Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_ble_connection_manager:
    path: ./path/to/flutter_ble_connection_manager
```

## Quick Start

```dart
// 1. Initialize the manager for a specific device
final manager = BleConnectionManager(
  device: myBluetoothDevice,
  config: ConnectionConfig(
    autoReconnect: true,
    recoveryPolicy: RecoveryPolicy.exponentialBackoff(maxAttempts: 3),
    onSetup: (device, token) async {
      // 2. Discover services & subscribe to characteristics BEFORE the connection is marked "ready"
      final services = await device.discoverServices();
      final characteristic = _findCharacteristic(services);
      await characteristic.setNotifyValue(true);
    }
  ),
);

// 3. Await the connection. It ONLY resolves when fully connected AND setup is complete.
await manager.connect();

// 4. The device is now ready. Use flutter_blue_plus directly.
await characteristic.write([0x01]);
```

## Lifecycle Model

Vanilla BLE libraries typically stop at the `Connected` state. This package enforces a strict progression:

`Disconnected` → `Connecting` → `Native BLE Connected` → `Setup (App Config)` → **`Ready`**

The `connect()` method does not resolve until the device successfully completes the entire progression and reaches the `Ready` state. 

## Core Concepts

### The `onSetup` Callback
The `onSetup` block is where you define what makes a device "Ready" for your specific application. It executes immediately after the native connection succeeds. This is the optimal place to discover services, negotiate MTU, and subscribe to required notifications.

```dart
final manager = BleConnectionManager(
  device: device,
  config: ConnectionConfig(
    onSetup: (device, token) async {
      // 1. Discover services using flutter_blue_plus
      final services = await device.discoverServices();
      
      // 2. Check for cancellation (e.g., user tapped "Disconnect" mid-setup)
      token.throwIfCancelled(); 
      
      // 3. Enable notifications
      final myChar = _findCharacteristic(services);
      await myChar.setNotifyValue(true);
    },
  ),
);
```

If anything within `onSetup` fails, the manager's `RecoveryPolicy` will automatically retry the entire connection flow.

## Which Stream Should I Listen To?

The manager exposes two streams. It is critical to use them correctly:

- **`manager.stateStream` (For UI)**: Emits high-level states (`disconnected`, `connecting`, `ready`, `disconnecting`). Use this to drive your UI (e.g., show a loading spinner, or enable a button).
- **`manager.events` (For Logs/Analytics)**: Emits granular milestones (`ConnectionAttemptStarted`, `SetupFailed`, `RetryScheduled`). Use this for Crashlytics, debugging, or analytics. **Do NOT use this to drive UI state.**

## API Overview

| Class                | Responsibility      |
| -------------------- | ------------------- |
| `BleConnectionManager` | Main entry point    |
| `ConnectionConfig`     | Configure lifecycle |
| `RecoveryPolicy`       | Retry behavior      |
| `BleLifecycleEvent`    | Event stream        |
| `BleConnectionState`   | State stream        |

## FAQ

### Does this package replace flutter_blue_plus?

No. `flutter_blue_plus` remains responsible for scanning, characteristic operations, and BLE transport. This package only manages the connection lifecycle.

### Can I manage multiple devices?

Yes. Create one `BleConnectionManager` per `BluetoothDevice`.

## Example App

The `example/` folder in this repository serves as **Executable Documentation**. Run it to see interactive demonstrations of:
- **Quick Start:** A basic connection flow.
- **Lifecycle Walkthrough:** A visual timeline of the exact states the manager progresses through.
- **API Reference:** Detailed in-app explanations of the core classes.

## Roadmap

- Structured logging.
- Heartbeat extension (application-level ping).

## Contributing

Contributions are welcome. Please read `docs/ARCHITECTURE.md` before proposing architectural changes.

## License

MIT License
