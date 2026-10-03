# ApexHUD

A landscape-oriented Kivy/KivyMD control dashboard for the MIRANA ESP8266 ApexHUD. The app provides drive and steering controls, a telemetry HUD, a Wi-Fi connection panel, optional microphone streaming, and local sound effects. It can be run as a desktop development app or packaged as an Android APK with Buildozer.

> **Hardware note:** The matching ESP8266 firmware lives in [`../apex-rover`](../apex-rover). The rover creates its own Wi-Fi access point (`MIRANA_RC_CAR`, `192.168.4.1`).

## Contents

- [Features](#features)
- [Project structure](#project-structure)
- [Runtime and hardware protocol](#runtime-and-hardware-protocol)
- [Requirements and tools](#requirements-and-tools)
- [Run locally](#run-locally)
- [Build an Android APK](#build-an-android-apk)
- [Configuration](#configuration)
- [Assets](#assets)
- [Validation and known limitations](#validation-and-known-limitations)
- [License](#license)

## Features

- Landscape HUD with Orbitron typography, speed, distance, battery, and mission-time displays.
- On-screen forward, reverse, left, and right controls. A stop command is sent when a direction button is released.
- Headlight toggle and horn command.
- UDP command sender and telemetry listener.
- Optional mono microphone stream to the car over UDP.
- Wi-Fi connection dialog and Android shortcut to Wi-Fi settings.
- Local engine, control, and interface audio effects, plus a master mute toggle.
- Android runtime request for microphone permission.

## Project structure

```text
.
├── main.py                         # Desktop/app entry point
├── config.py                       # Network defaults and app configurations
├── buildozer.spec                  # Android packaging configuration
├── requirements.txt                # Local Python and build tooling
└── app/
    ├── __init__.py                 # KivyMD application, startup, and service wiring
    ├── app.kv                      # Main HUD layout
    ├── assets/
    │   ├── fonts/                  # Orbitron font
    │   ├── icons/                  # Android launcher icon
    │   ├── images/                 # HUD backgrounds
    │   ├── lottie/                 # Loading animation
    │   └── sfx/                    # WAV sound effects
    ├── services/
    │   ├── mic/                    # Microphone capture and UDP audio sender
    │   ├── sound/                  # Sound loading and playback
    │   └── wifi/                   # UDP command sender and telemetry receiver
    ├── utils/                      # Android permission and connection helpers
    └── widgets/
        ├── connection_modal/       # Connection dialog
        ├── control_pad/            # Drive, steering, horn, and light controls
        ├── telemetry/              # Speed and mission-time HUD
        └── top_bar/                # Wi-Fi, distance, battery, speaker, and mic controls
```

## Runtime and hardware protocol

### Network defaults

The default ESP access-point address is `192.168.4.1`. Change the values in `config.py` if the firmware uses a different address or ports.

| Traffic | Direction | Default port | Payload |
|---|---|---:|---|
| Control commands | App → ESP8266 | UDP `4210` | UTF-8 single-character command |
| Telemetry | ESP8266 → app | UDP `4210` | JSON object, or legacy `key:value` fields separated by `|` |
| Microphone audio | App → ESP8266 | UDP `8081` | Raw mono PCM, signed 16-bit, 8 kHz chunks |

The app expects telemetry keys `B` (battery percentage), `S` (speed, displayed as km/h), and `D` (distance, displayed in metres). An example JSON packet is:

```json
{"B":"85","S":"24","D":"152"}
```

The legacy format is `B:85|S:24|D:152`.

### Commands currently emitted by the UI

| Command | Meaning in the app |
|---|---|
| `F` / `B` | Forward / reverse while the corresponding control is held |
| `L` / `R` | Left / right while the corresponding control is held |
| `H` | Stop/release command when a direction control is released |
| `S` | Horn |
| `X` / `x` | Headlights on / off |
| `Z` / `z` | Microphone streaming on / off |

The firmware is authoritative for what these bytes do. Confirm that its command handler and telemetry destination match the table before connecting the vehicle.

### Connection check caveat

The app pings the rover with a UDP `P` every second. The rover answers with a telemetry packet; the app is marked connected only if a packet arrived within the last 3 seconds, and drops back to offline (Wi-Fi icon turns orange) when replies stop.

## Requirements and tools

- Python for desktop development.
- Kivy `2.3.1` and KivyMD from the upstream development branch. The UI uses the newer KivyMD widget API.
- PyAudio for microphone capture on desktop only. Android capture uses `AudioRecord` through python-for-android/pyjnius.
- Buildozer for Android packaging. The SDK, NDK, Gradle, and python-for-android toolchain are obtained/configured by Buildozer.
- Pylance is an optional **VS Code extension**, not a Python package; see [Pylance installation](https://marketplace.visualstudio.com/items?itemName=ms-python.vscode-pylance). It is therefore documented in `requirements.txt` as a comment rather than as an invalid pip dependency.

`requirements.txt` includes desktop and host-side tools. `buildozer.spec` separately lists only the packages that belong inside the Android app; do not add PyAudio, Buildozer, Pylance, `android`, or `jnius` to the APK requirements.

For microphone capture on macOS, install PortAudio before installing PyAudio:

```sh
brew install portaudio
```

On Debian/Ubuntu desktop development, install the PortAudio headers before PyAudio:

```sh
sudo apt-get update
sudo apt-get install -y portaudio19-dev python3-dev
```

## Run locally

From the repository root:

```sh
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
python main.py
```

On Windows, activate the virtual environment with `.venv\Scripts\activate`. PyAudio installation may require a compatible wheel or system PortAudio development files, depending on the platform.

To use the microphone, grant microphone access to the desktop process/terminal when prompted by the operating system. On Android, grant the in-app audio permission when requested.

## Build an Android APK

Buildozer's Android toolchain is intended to run on Linux. On macOS, use a Linux VM or another Linux build host; having the Buildozer Python package installed on macOS does not by itself provide a supported Android build environment.

On an Ubuntu Linux build host, install the host packages required by the current Buildozer/python-for-android documentation (including Java, Git, and the Android build prerequisites), then from the project root run:

```sh
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
buildozer android debug
```

The first build downloads the Android SDK/NDK and compiles dependencies, so it can take a while and use substantial disk space. The debug APK is written to `bin/`. To deploy to a connected, USB-debugging-enabled Android device:

```sh
buildozer android debug deploy run
```

For a release artifact, use `buildozer android release` and configure app signing securely; do not commit keystores or passwords. Review the Android API, NDK, architecture, and permission settings in `buildozer.spec` before producing a release. The checked-in API/NDK versions are set for the current project configuration and may need updating to meet a distribution store's target-API requirements.

Connect the Android device to the car's Wi-Fi access point before opening the connection panel. The access point may have no internet; keep the device connected to it when Android asks whether to switch networks.

## Configuration

`config.py` defines the settings consumed by the app:

| Setting | Default | Purpose |
|---|---|---|
| `ESP_IP` | `192.168.4.1` | ESP8266 access-point address |
| `UDP_PORT` | `4210` | Control datagrams and the connection probe |
| `TELEMETRY_PORT` | `4210` | Local UDP port bound for telemetry |
| `VOICE_PORT` | `8081` | Destination port for microphone audio |

`main.py` starts `ApexHUDApp` with `DevelopmentConfig`. `ProductionConfig` retains a list of Android permissions, while the actual manifest permissions are declared in `buildozer.spec` and runtime microphone permission is requested by `app/utils/permissions.py`.

The Buildozer package identity is `dev.hacksmiths.rccar`, the displayed title is `ApexHUD`, and the configured orientation is landscape. Change the package domain/name before publishing if you need a unique application ID.

## Assets

- `app/assets/icons/icon.png` is the Buildozer launcher icon.
- `app/assets/fonts/Orbitron-Regular.ttf` is registered by the app and used in the HUD.
- `app/assets/images/` contains HUD/background images.
- `app/assets/lottie/loading.json` is configured as the Android presplash animation.
- `app/assets/sfx/` contains the sound effects loaded by `AudioLoader`.

The PNG icon/background and WAV sound files have been checked against their file contents. No local horn sound is configured yet: the `S` command is still sent, but the app has no horn sound effect until one is supplied.

## Validation and known limitations

- There is no automated test suite.
- A successful UDP send is not a hardware handshake; see [Connection check caveat](#connection-check-caveat).
- The microphone stream is raw PCM and must be decoded/configured the same way by the receiver firmware.
- Desktop microphone capture requires PyAudio and the platform's PortAudio support. Android uses the Android recording API instead.
- Pylance may show `android` and `jnius` as unresolved in a desktop interpreter; those imports are Android-only and supplied by python-for-android in the APK.
- The engine idle WAV is about 35 MB and is included in the APK, increasing its size.
- The project license applies to the project code. Verify that you have rights to redistribute the bundled font, images, and sound assets before publishing.

Before testing on a powered ApexHUD, raise the drive wheels and verify the direction/stop commands with the vehicle secured.

## License

This project is licensed under the MIT License; see [LICENSE](LICENSE).
