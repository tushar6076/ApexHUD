// ApexHUD rover firmware (ESP8266 / NodeMCU)
#include <ESP8266WiFi.h>
#include <WiFiUdp.h>

// ---------- Network Configuration ----------
const char *AP_SSID = "APEX_ROVER";
const char *AP_PASS = "apexhud1";
const uint16_t CMD_PORT = 4210;         // app -> rover
const uint16_t TELEMETRY_PORT = 4210;   // rover -> app

// ---------- Pin Assignments ----------
const uint8_t IN1 = D1, IN2 = D2;       // Left motor  (L298N IN1/IN2)
const uint8_t IN3 = D5, IN4 = D6;       // Right motor (L298N IN3/IN4)
const uint8_t LIGHT_PIN = D7;           // Headlight (active-high)
const uint8_t TRIG_PIN = D8;            // HC-SR04 trigger
const uint8_t ECHO_PIN = D0;            // HC-SR04 echo
const uint8_t BUZZER_PIN = D4;          // Active buzzer (active-low)

// Indicator LEDs & Signal LED
const uint8_t IND_LEFT_PIN = D3;        // Left indicator (GPIO0)
const uint8_t IND_RIGHT_PIN = 3;        // Right indicator (RX / GPIO3)
const uint8_t SIGNAL_LED_PIN = 1;       // Yellow Signal LED (TX / GPIO1)

// ---------- Calibration ----------
const int DRIVE_PWM = 1023;
const int TURN_PWM = 800;

// 1.6 m/s = 5760 m/h = 57.6 hm/h (rounded to 58 HM/H)
const float MAX_SPEED_HMH = 58.0;

const float VBAT_FULL = 8.4;
const float VBAT_EMPTY = 6.4;
const float ADC_VOLT_PER_COUNT = 3.2 / 1023.0;
const float EXTERNAL_DIVIDER = 3.0;

const unsigned long TELEMETRY_MS = 200;
const unsigned long CLIENT_TIMEOUT_MS = 3000;
const unsigned long HORN_MS = 300;
const unsigned long BLINK_INTERVAL_MS = 450;

WiFiUDP udp;
IPAddress clientIP;
bool haveClient = false;
unsigned long lastRx = 0, lastTx = 0, hornUntil = 0;
float speedHmh = 0.0;
float batteryPct = 100.0;

// State flags
bool indLeftActive = false;
bool indRightActive = false;
unsigned long lastBlinkToggle = 0;
bool blinkState = false;
bool micAudioActive = false;

void setMotors(int l1, int l2, int r1, int r2, float speed) {
  analogWrite(IN1, l1);
  analogWrite(IN2, l2);
  analogWrite(IN3, r1);
  analogWrite(IN4, r2);
  speedHmh = speed;
}

void stopMotors() { setMotors(0, 0, 0, 0, 0.0); }

void handleCommand(char c) {
  const float v = (DRIVE_PWM / 1023.0) * MAX_SPEED_HMH;
  switch (c) {
    case 'F': setMotors(DRIVE_PWM, 0, DRIVE_PWM, 0, v); break;
    case 'B': setMotors(0, DRIVE_PWM, 0, DRIVE_PWM, v); break;
    case 'L': setMotors(0, TURN_PWM, TURN_PWM, 0, 0.0); break;
    case 'R': setMotors(TURN_PWM, 0, 0, TURN_PWM, 0.0); break;
    case 'H': stopMotors(); break;
    
    // Headlight
    case 'X': digitalWrite(LIGHT_PIN, HIGH); break;
    case 'x': digitalWrite(LIGHT_PIN, LOW); break;
    
    // Horn
    case 'S': hornUntil = millis() + HORN_MS; break;
    
    // Indicators
    case 'I': indLeftActive = true; indRightActive = false; break;
    case 'i': indLeftActive = false; digitalWrite(IND_LEFT_PIN, LOW); break;
    case 'O': indRightActive = true; indLeftActive = false; break;
    case 'o': indRightActive = false; digitalWrite(IND_RIGHT_PIN, LOW); break;
    
    // Microphone / Speaker Stream
    case 'Z': micAudioActive = true; break;
    case 'z': micAudioActive = false; break;
    
    // Handshake
    case 'P': break;
  }
}

int readDistanceCm() {
  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);
  unsigned long us = pulseIn(ECHO_PIN, HIGH, 12000);  // ~2m cutoff
  if (us == 0) return 999;
  return min(999, (int)(us / 58));
}

void updateBattery() {
  long sum = 0;
  for (int i = 0; i < 8; i++) sum += analogRead(A0);
  float volts = (sum / 8.0) * ADC_VOLT_PER_COUNT * EXTERNAL_DIVIDER;
  float pct = (volts - VBAT_EMPTY) / (VBAT_FULL - VBAT_EMPTY) * 100.0;
  pct = constrain(pct, 0.0, 100.0);
  batteryPct = 0.9 * batteryPct + 0.1 * pct;
}

void sendTelemetry() {
  if (!haveClient) return;
  char buf[64];
  snprintf(buf, sizeof(buf), "{\"B\":\"%d\",\"S\":\"%d\",\"D\":\"%d\"}",
           (int)(batteryPct + 0.5), (int)(speedHmh + 0.5), readDistanceCm());
  udp.beginPacket(clientIP, TELEMETRY_PORT);
  udp.write(buf);
  udp.endPacket();
  lastTx = millis();
}

void updateBlinkers() {
  if (!indLeftActive && !indRightActive) {
    digitalWrite(IND_LEFT_PIN, LOW);
    digitalWrite(IND_RIGHT_PIN, LOW);
    return;
  }

  if (millis() - lastBlinkToggle >= BLINK_INTERVAL_MS) {
    lastBlinkToggle = millis();
    blinkState = !blinkState;

    if (indLeftActive) {
      digitalWrite(IND_LEFT_PIN, blinkState ? HIGH : LOW);
    }
    if (indRightActive) {
      digitalWrite(IND_RIGHT_PIN, blinkState ? HIGH : LOW);
    }
  }
}

void setup() {
  pinMode(IND_RIGHT_PIN, FUNCTION_3);
  pinMode(SIGNAL_LED_PIN, FUNCTION_3);

  pinMode(LIGHT_PIN, OUTPUT);
  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);
  pinMode(BUZZER_PIN, OUTPUT);
  pinMode(IND_LEFT_PIN, OUTPUT);
  pinMode(IND_RIGHT_PIN, OUTPUT);
  pinMode(SIGNAL_LED_PIN, OUTPUT);

  digitalWrite(BUZZER_PIN, HIGH);
  digitalWrite(LIGHT_PIN, LOW);
  digitalWrite(IND_LEFT_PIN, LOW);
  digitalWrite(IND_RIGHT_PIN, LOW);
  digitalWrite(SIGNAL_LED_PIN, LOW);

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
    if (c == 'P') sendTelemetry();
  }

  if (haveClient && millis() - lastRx > CLIENT_TIMEOUT_MS) {
    stopMotors();
    digitalWrite(LIGHT_PIN, LOW);
    indLeftActive = false;
    indRightActive = false;
    haveClient = false;
  }

  digitalWrite(SIGNAL_LED_PIN, haveClient ? HIGH : LOW);
  digitalWrite(BUZZER_PIN, millis() < hornUntil ? LOW : HIGH);
  updateBlinkers();

  if (millis() - lastTx >= TELEMETRY_MS) {
    updateBattery();
    sendTelemetry();
  }
}