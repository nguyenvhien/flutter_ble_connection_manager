# Usage Guide & Comparison

This document accurately reflects 100% of the current implementation in `flutter_ble_connection_manager`. More importantly, it clarifies the **core philosophy** and **Mental Model** of the package compared to traditional approaches.

---

## 1. The Core Contract - "Killer Feature"

The biggest differentiator of this package is not its minor utilities, but the fact that it redefines the concept of a **Successful Connection**.

With vanilla BLE, `connected` only means the device is paired at the Radio layer. However, from the application's perspective, you cannot do anything until you discover services, enable notifications, or perform authentication.

`flutter_ble_connection_manager` enforces a strict linear flow:

```text
Disconnected
   ↓
Connecting
   ↓
Connected (Native BLE)
   ↓
Setup (Discover Services, Request MTU, Enable Notify...)
   ↓
Ready (Application Ready)
```

**The Contract:** The `await manager.connect();` command does NOT resolve at the `Connected (Native)` step. It ONLY resolves when the device has reached the **Application Ready** state (`ready`).

---

## 2. Usage

The package's approach is **Declarative Configuration**. You simply define "how this connection should behave", and the Manager handles the entire lifecycle coordination.

### Step 1: Initialize the Manager
You create a single instance (Facade) for each BLE device. This prevents complex adapters or repositories from leaking into your application logic.

```dart
final manager = BleConnectionManager(
  device: bluetoothDevice,
  config: ConnectionConfig(
    timeout: const Duration(seconds: 15),
    
    // Declare the Recovery Strategy for network interruptions
    recoveryPolicy: RecoveryPolicy.exponentialBackoff(maxAttempts: 3),
    
    // Declare the necessary steps for the device to reach the 'Ready' state
    onSetup: (device, token) async {
      final services = await device.discoverServices();
      token.throwIfCancelled(); // Supports cooperative safe cancellation
      
      final myChar = services.first.characteristics.first;
      await myChar.setNotifyValue(true);
    },
  ),
);
```

### Step 2: Listen to the State
There are exactly 4 states, perfectly reflecting the Mental Model.

```dart
manager.state.listen((state) {
  switch (state) {
    case BleConnectionState.disconnected:
      // Show "Connect" button
    case BleConnectionState.connecting:
      // Show Loading spinner
    case BleConnectionState.ready:
      // Navigate to the device control screen
    case BleConnectionState.disconnecting:
      // Show cleanup indicator...
  }
});
```

### Step 3: Issue Commands
The only thing your UI needs to do is issue commands.

```dart
// Resolves ONLY when the device is 'Ready'
await manager.connect();

// Interact directly with the device
await manager.device.writeCharacteristic(myChar, [0x01]);

await manager.disconnect();
```

---

## 3. Comparison: Mental Model vs Vanilla `flutter_blue_plus`

The greatest value of this package isn't helping you write fewer lines of code (Code Reduction). The greatest value is the **Shift in Mental Model**.

### ❌ With Vanilla `flutter_blue_plus`: You manage the Implementation
In plain code, the developer's brain must constantly juggle numerous low-level concepts:
- **Timer** (To handle manual timeouts)
- **StreamSubscription** (To listen for network drops and remember to cancel them)
- **Retry Count & Backoff Math** (Calculating wait times between retries manually)
- **Mutex / Flags** (Checking `_isConnecting` manually to prevent users from spamming the connect button)
- **Cancellation** (How do you stop `discoverServices` if the user hits the Back button?)

The code becomes flooded with `while` loops, `try/catch/finally` blocks, and state flags.

### ✅ With Manager: You describe the Policy
You don't need to care *How* to connect safely. You only declare the *Policy*:
- *"Timeout is 15 seconds."*
- *"If the connection drops, use Exponential Backoff for a maximum of 3 attempts."*
- *"For the device to be considered Ready, this onSetup block must complete."*

All the complexity is encapsulated and resolved entirely by the internal architecture:

1. **Lifecycle Operation Coordinator (`LifecycleSerializer`)**: This is not merely "anti-spam" (Deduplication). It is the brain that synchronizes all `connect`, `disconnect`, `dispose`, and `retry` flows. All competing operations are safely queued (Serialized).
2. **Normalized Structured Errors**: The package doesn't just "Wrap" errors; it **Normalizes** them. Obscure Native Android/iOS errors (`CBError`, `GATT_ERROR`) are mapped into a single standard exception interface (`TimeoutFailure`, `SetupFailure`, `TransportFailure`), clearly separating Application Errors from Native Errors.
3. **Recovery vs Retry**: Retry is just one Strategy under the `RecoveryPolicy`. In the future, the system can expand to support Circuit Breakers, Cooldowns, or Aborts without changing the Manager's public API.
