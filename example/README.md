# Example App: Executable Documentation

This example application serves as the **Interactive Playground & Executable Documentation** for `flutter_ble_connection_manager`.

Instead of providing only a minimal code snippet, this application demonstrates how the package behaves in real-world scenarios, including lifecycle transitions, concurrent connections, safe cancellations, and automatic recovery.

## Features

- **Quick Start:** A multi-device connection management demo.
- **Lifecycle Walkthrough:** A visual timeline of BLE states (Connecting -> Discovering -> Setup -> Ready).
- **API Reference:** Interactive core concepts and mental models.
- **Mock Mode:** 100% Simulator/Emulator support without physical BLE hardware.

## Running the Example

```bash
cd example
flutter pub get
flutter run
```

## Mock Mode (Simulators & Emulators)

The example includes a built-in **Mock Mode** that simulates 5 different BLE devices, each representing a specific technical challenge (Happy Path, Timeout, Setup Failure, Auto-Reconnect Success/Failure).

This allows developers to:
- Run the example directly on Android Emulators or iOS Simulators.
- Develop and test UI without needing physical BLE hardware.
- Observe lifecycle transitions, race conditions, and recovery behaviors seamlessly.

## Real Device Mode

To test with actual BLE hardware:
1. Disable **Mock Mode** from the Home screen.
2. Grant the required Bluetooth & Location permissions.
3. Scan and select a nearby BLE device.
4. Explore the different demo pages.

## Learn More

- Package overview: [README.md](../README.md)
- Example architecture: [EXAMPLE_ARCHITECTURE.md](../docs/EXAMPLE_ARCHITECTURE.md)
