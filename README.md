Here is the updated root `README.md` reflecting the migration from Python/Kivy to Flutter, the calibrated **HM/H** and **DM** telemetry, the kinematics sound engine, and the modernized hardware pinout:

```markdown
# ApexHUD

Cyberpunk-themed HUD mobile controller and telemetry console for an ESP8266-powered Wi-Fi rover.

| Directory | Stack | Contents |
|---|---|---|
| [`apex-app/`](apex-app) | **Flutter** (Dart) | Cyberpunk landscape HUD controller with kinematic sound engine, dual virtual joysticks, dynamic turn blinkers, and real-time telemetry gauges. |
| [`apex-rover/`](apex-rover) | **C++ / Arduino** | ESP8266 NodeMCU firmware: hosts softAP, drives L298N dual-bridge PWM motors, calculates battery % via ADC, measures obstacle proximity, and streams JSON telemetry. |

---

## System Architecture

```text
┌────────────────────────┐                   ┌────────────────────────┐
│     ApexHUD Mobile     │  UDP Command (4210) │   ESP8266 NodeMCU      │
│     (Flutter App)      │──────────────────>│   (SoftAP: APEX_ROVER) │
│                        │<──────────────────│                        │
│ • Dual-Stick Joysticks │  JSON Telemetry   │ • L298N Motor Driver   │
│ • Kinematic Audio Mix  │      (4210)       │ • HC-SR04 Ultrasonic   │
│ • Dynamic Turn HUD     │                   │ • Headlight & Blinkers │
└────────────────────────┘                   └────────────────────────┘

```

---

## Quick Start

### 1. Hardware & Firmware

1. Open `apex-rover/apex-rover.ino` in Arduino IDE or PlatformIO.
2. Ensure you have the `esp8266` board definitions installed.
3. Flash the sketch to your NodeMCU and power on the chassis.
4. The rover broadcasts an autonomous Wi-Fi access point:
* **SSID:** `APEX_ROVER`
* **Password:** `apexhud1`
* **Gateway IP:** `192.168.4.1`



### 2. Mobile Controller (Flutter)

1. Connect your mobile device (iOS/Android) to the `APEX_ROVER` Wi-Fi network.
2. Navigate to the app directory and launch the HUD:
```bash
cd apex-app
flutter pub get
flutter run

```


3. Once the app binds port `4210` and handshakes with the rover (`P`), the HUD signal indicator turns solid cyan and live telemetry begins streaming.

---

## Telemetry & Physics Units

Telemetry calculations are handled directly on the microcontroller to keep the mobile client calibration-free:

* **Speed (`S`):** Calibrated in **HM/H** (Hectometers per hour: $1\text{ hm} = 100\text{ m}$). Standard full throttle corresponds to $\approx 58\text{ HM/H}$ ($\approx 1.6\text{ m/s}$).
* **Distance (`D`):** Time-of-flight acoustic echolocation via HC-SR04, reported in **cm** (or decimeters) with an auto-cutoff at $999\text{ cm}$.
* **Battery (`B`):** 0%–100% smoothed state-of-charge read from pin `A0` using an external resistor divider on a 2S Li-ion pack ($6.4\text{V}$ cutoff to $8.4\text{V}$ peak), filtered against motor voltage sag.

---

## Communication Protocol (UDP Port `4210`)

### Control Commands (App $\to$ Rover)

Single-character ASCII payloads sent via UDP datagrams:

| Command | Action | Command | Action |
| --- | --- | --- | --- |
| **`F`** | Drive Forward | **`X`** / **`x`** | Headlight ON / OFF |
| **`B`** | Drive Reverse | **`I`** / **`i`** | Left Turn Indicator ON / OFF |
| **`L`** | Pivot Left | **`O`** / **`o`** | Right Turn Indicator ON / OFF |
| **`R`** | Pivot Right | **`S`** | Horn Buzzer Burst (300 ms) |
| **`H`** | Halt / Neutral | **`P`** | Ping / Heartbeat Handshake |

### Telemetry Stream (Rover $\to$ App)

JSON packet broadcast every 200 ms:

```json
{"B":"85","S":"58","D":"42"}

```

---

## Pinout Map (NodeMCU)

| Pin | Function | Notes |
| --- | --- | --- |
| **`D1`, `D2**` | Left Motor (IN1, IN2) | Connected to L298N driver |
| **`D5`, `D6**` | Right Motor (IN3, IN4) | Connected to L298N driver |
| **`D7`** | Headlight LED | Active-High transistor switch |
| **`D3`** | Left Turn Blinker | GPIO0 |
| **`RX` (GPIO3)** | Right Turn Blinker | Reconfigured as standard GPIO |
| **`TX` (GPIO1)** | Connection Status LED | Solid ON when client heartbeat active |
| **`D4`** | Horn Buzzer | Active-Low buzzer |
| **`D8` / `D0**` | HC-SR04 Trig / Echo | *Use 5V $\to$ 3.3V divider on Echo (`D0`)* |
| **`A0`** | Battery Voltage Divider | External $(R_1 + R_2)/R_2 = 3.0$ divider |

---

## License

Distributed under the MIT License. See [LICENSE](https://www.google.com/search?q=LICENSE) for details.

```

```