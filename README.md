# ApexHUD

Wi-Fi RC car with a HUD-style controller app.

| Folder | Contents |
|---|---|
| [`apex-app/`](apex-app) | Kivy/KivyMD controller app (desktop + Android via Buildozer) |
| [`apex-rover/`](apex-rover) | ESP8266 firmware: creates the Wi-Fi AP, drives motors, computes battery/speed/distance telemetry |

## Quick start
1. Flash `apex-rover/apex-rover.ino` to the ESP8266 and power the rover.
2. Join Wi-Fi `Apex Rover` (password `apexhud1`) on the phone/computer.
3. Run the app (see [`apex-app/README.md`](apex-app/README.md)). The Wi-Fi icon turns cyan once the rover answers.

Protocol: UDP `4210`, single-char commands app → rover, JSON telemetry rover → app (details in [`apex-rover/README.md`](apex-rover/README.md)).

## License
See [LICENSE](LICENSE).
