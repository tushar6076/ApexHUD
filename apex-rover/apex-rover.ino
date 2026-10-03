// ApexHUD rover firmware (ESP8266 / NodeMCU)
// The ESP creates its own Wi-Fi access point (no router needed), receives
// single-character UDP commands and streams JSON telemetry back to the app.
// Battery %, speed and distance are all computed here, so the app needs no
// hardcoded calibration values.
#include <ESP8266WiFi.h>
#include <WiFiUdp.h>

// ---------- Network (must match app/config.py) ----------
const char *AP_SSID = "MIRANA_RC_CAR";
const char *AP_PASS = "apexhud1";       // min 8 chars
const uint16_t CMD_PORT = 4210;         // app -> rover
const uint16_t TELEMETRY_PORT = 4210;   // rover -> app (app binds this)

// ---------- Pins (NodeMCU labels) ----------
const uint8_t IN1 = D1, IN2 = D2;       // left motor  (L298N IN1/IN2, ENA jumpered)
const uint8_t IN3 = D5, IN4 = D6;       // right motor (L298N IN3/IN4, ENB jumpered)
const uint8_t LIGHT_PIN = D7;           // headlight, active-high
const uint8_t TRIG_PIN = D8;            // HC-SR04 trigger
const uint8_t ECHO_PIN = D0;            // HC-SR04 echo (use 5V->3.3V divider!)
const uint8_t BUZZER_PIN = D4;          // active buzzer between 3V3 and pin (active-low)

// ---------- Calibration (edit here, never in the app) ----------
const int DRIVE_PWM = 1023;             // 0..1023 straight drive
const int TURN_PWM = 800;               // 0..1023 turning
const float MAX_SPEED_KMH = 6.0;        // measured speed at full PWM
const float VBAT_FULL = 8.4;            // 2S Li-ion full
const float VBAT_EMPTY = 6.4;           // 2S Li-ion cutoff
// NodeMCU A0 already divides internally (0-3.2V full scale). Set EXTERNAL_DIVIDER to
// your external (R1+R2)/R2 and fine-tune it against a multimeter reading.
const float ADC_VOLT_PER_COUNT = 3.2 / 1023.0;
const float EXTERNAL_DIVIDER = 3.0;     // (R1+R2)/R2 of your external divider

const unsigned long TELEMETRY_MS = 200;
const unsigned long CLIENT_TIMEOUT_MS = 3000;
const unsigned long HORN_MS = 300;

WiFiUDP udp;
IPAddress clientIP;
bool haveClient = false;
unsigned long lastRx = 0, lastTx = 0, hornUntil = 0;
float speedKmh = 0;
float batteryPct = 100;

void setMotors(int l1, int l2, int r1, int r2, float speed) {
  analogWrite(IN1, l1);
  analogWrite(IN2, l2);
  analogWrite(IN3, r1);
  analogWrite(IN4, r2);
  speedKmh = speed;
}

void stopMotors() { setMotors(0, 0, 0, 0, 0); }

void handleCommand(char c) {
  const float v = DRIVE_PWM / 1023.0 * MAX_SPEED_KMH;
  switch (c) {
    case 'F': setMotors(DRIVE_PWM, 0, DRIVE_PWM, 0, v); break;
    case 'B': setMotors(0, DRIVE_PWM, 0, DRIVE_PWM, v); break;
    case 'L': setMotors(0, TURN_PWM, TURN_PWM, 0, 0); break;
    case 'R': setMotors(TURN_PWM, 0, 0, TURN_PWM, 0); break;
    case 'H': stopMotors(); break;
    case 'X': digitalWrite(LIGHT_PIN, HIGH); break;
    case 'x': digitalWrite(LIGHT_PIN, LOW); break;
    case 'S': hornUntil = millis() + HORN_MS; break;
    case 'Z': case 'z': break;  // mic stream: no audio output hardware
    case 'P': break;            // ping: telemetry reply is sent right away
  }
}

int readDistanceCm() {
  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);
  unsigned long us = pulseIn(ECHO_PIN, HIGH, 12000);  // ~2 m max
  if (us == 0) return 999;
  return min(999, (int)(us / 58));
}

void updateBattery() {
  long sum = 0;
  for (int i = 0; i < 8; i++) sum += analogRead(A0);
  float volts = (sum / 8.0) * ADC_VOLT_PER_COUNT * EXTERNAL_DIVIDER;
  float pct = (volts - VBAT_EMPTY) / (VBAT_FULL - VBAT_EMPTY) * 100.0;
  pct = constrain(pct, 0.0, 100.0);
  batteryPct = 0.9 * batteryPct + 0.1 * pct;  // smooth motor-load ripple
}

void sendTelemetry() {
  if (!haveClient) return;
  char buf[64];
  snprintf(buf, sizeof(buf), "{\"B\":\"%d\",\"S\":\"%d\",\"D\":\"%d\"}",
           (int)(batteryPct + 0.5), (int)(speedKmh + 0.5), readDistanceCm());
  udp.beginPacket(clientIP, TELEMETRY_PORT);
  udp.write(buf);
  udp.endPacket();
  lastTx = millis();
}

void setup() {
  pinMode(LIGHT_PIN, OUTPUT);
  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);
  pinMode(BUZZER_PIN, OUTPUT);
  digitalWrite(BUZZER_PIN, HIGH);
  analogWriteRange(1023);
  const uint8_t motorPins[] = {IN1, IN2, IN3, IN4};
  for (uint8_t p : motorPins) pinMode(p, OUTPUT);
  stopMotors();

  WiFi.mode(WIFI_AP);
  WiFi.softAPConfig(IPAddress(192, 168, 4, 1), IPAddress(192, 168, 4, 1),
                    IPAddress(255, 255, 255, 0));
  WiFi.softAP(AP_SSID, AP_PASS);
  udp.begin(CMD_PORT);
  updateBattery();
  batteryPct = constrain((analogRead(A0) * ADC_VOLT_PER_COUNT * EXTERNAL_DIVIDER - VBAT_EMPTY)
                         / (VBAT_FULL - VBAT_EMPTY) * 100.0, 0.0, 100.0);
}

void loop() {
  int len = udp.parsePacket();
  if (len > 0) {
    char c = udp.read();
    udp.flush();
    clientIP = udp.remoteIP();
    haveClient = true;
    lastRx = millis();
    handleCommand(c);
    if (c == 'P') sendTelemetry();  // immediate reply drives the app's handshake
  }

  // Failsafe: client gone -> stop and mute
  if (haveClient && millis() - lastRx > CLIENT_TIMEOUT_MS) {
    stopMotors();
    haveClient = false;
  }

  digitalWrite(BUZZER_PIN, millis() < hornUntil ? LOW : HIGH);

  if (millis() - lastTx >= TELEMETRY_MS) {
    updateBattery();
    sendTelemetry();
    lastTx = millis();
  }
}
