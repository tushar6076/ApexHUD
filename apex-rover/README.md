# ApexHUD Rover (ESP8266 firmware)

Firmware for the NodeMCU/ESP8266 in the rover. It creates its **own Wi-Fi access point** (no external router), executes UDP commands from the app and streams telemetry back.

## Network
| Item | Value |
|---|---|
| SSID / password | `MIRANA_RC_CAR` / `apexhud1` (change in `apex-rover.ino`) |
| Rover IP | `192.168.4.1` |
| Commands (app → rover) | UDP `4210`, one ASCII char |
| Telemetry (rover → app) | UDP `4210`, `{"B":"85","S":"4","D":"152"}` |

Commands: `F` `B` `L` `R` move, `H` stop, `X`/`x` headlight on/off, `S` horn, `Z`/`z` mic on/off (no audio hardware, ignored), `P` ping (answered immediately with telemetry; the app uses this to decide if it is connected).

Telemetry: `B` battery %, `S` speed km/h (estimated from PWM), `D` front distance in cm (HC-SR04). Battery is computed on the ESP from A0, so all calibration lives in the constants at the top of `apex-rover.ino`.

Failsafe: motors stop if nothing is received from the app for 3 s.

## Wiring (NodeMCU)
| Function | Pin |
|---|---|
| Left motor IN1/IN2 | D1 / D2 |
| Right motor IN3/IN4 | D5 / D6 |
| Headlight | D7 |
| HC-SR04 TRIG / ECHO | D8 / D0 (ECHO via 5V→3.3V divider) |
| Active buzzer (to 3V3, active-low) | D4 |
| Battery sense | A0 through a voltage divider |

Jumper the L298N ENA/ENB pins high; speed is set by PWM on the IN pins.

## Build
Arduino IDE or `arduino-cli` with the ESP8266 core, board *NodeMCU 1.0*, open `apex-rover.ino` and upload.
