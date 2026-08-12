
#include <WiFi.h>
#include <HTTPClient.h>
#include <ESPmDNS.h>

#define BUZZER_PIN    21
#define CAM_TRIGGER   5
#define LED_PIN       19
#define PIR_PIN       18
#define REED_PIN      4

const char* CAM_HOST = "strangerfinder-cam";
const char* CAM_IP   = "  ";
const int CAM_PORT   = 81;

const char* BACKEND_URL = "http://172.20.10.10:8001/api/v1/door-status/";

struct WiFiCredential {
  const char* ssid;
  const char* password;
};

const WiFiCredential wifiList[] = {
  {"JioFiber-AEh6c",     "heefeaG6eemei4qu"},
  {"JioFiber-AEh6c_5G",  "heefeaG6eemei4qu"},
  {"iPhone",             "pass1234"},
  {"OmkarMesh5G-Main",   "darkmatter"}
};

const int WIFI_COUNT = sizeof(wifiList) / sizeof(wifiList[0]);

const unsigned long PIR_COOLDOWN_MS = 10000;
unsigned long lastCaptureTime = 0;
int captureCount = 0;
bool pirTriggered = false;
String lastKnownCamIp = "";
bool mdnsReady = false;

bool ledState = false;
unsigned long lastLedToggle = 0;
const unsigned long LED_BLINK_MS = 500;

bool lastDoorOpen = false;
bool doorStateInitialized = false;
unsigned long lastDoorChangeTime = 0;
const unsigned long DOOR_DEBOUNCE_MS = 200;

void buzzerBeep(int times, int onMs, int offMs) {
  for (int i = 0; i < times; i++) {
    digitalWrite(BUZZER_PIN, HIGH);
    delay(onMs);
    digitalWrite(BUZZER_PIN, LOW);
    if (i < times - 1) delay(offMs);
  }
}

void buzzerNoFace()      { buzzerBeep(1, 100, 100); }
void buzzerKnownPerson() { buzzerBeep(2, 150, 100); }
void buzzerStranger()    { buzzerBeep(5, 300, 150); }
void buzzerWiFiConnected() { buzzerBeep(3, 100, 100); }
void buzzerError()       { buzzerBeep(2, 500, 200); }
void buzzerDoorOpen()    { buzzerBeep(3, 200, 100); }
void buzzerMotion()      { buzzerBeep(1, 80, 0); }

void sendDoorStatus(bool isOpen) {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[DOOR] WiFi not connected, skipping HTTP POST");
    return;
  }

  HTTPClient http;
  http.begin(BACKEND_URL);
  http.addHeader("Content-Type", "application/json");
  http.setTimeout(10000);

  String deviceId = WiFi.macAddress();
  deviceId.replace(":", "");

  String payload = "{\"deviceId\":\"" + deviceId + "\",\"status\":\"";
  payload += isOpen ? "open" : "closed";
  payload += "\"}";

  Serial.print("[DOOR] Sending status: ");
  Serial.println(payload);

  int httpCode = http.POST(payload);
  if (httpCode > 0) {
    Serial.print("[DOOR] Server response: ");
    Serial.println(httpCode);
    String response = http.getString();
    Serial.println(response);
  } else {
    Serial.print("[DOOR] HTTP Error: ");
    Serial.println(http.errorToString(httpCode));
  }
  http.end();
}

bool connectToWiFi() {
  Serial.println("\n[WIFI] Starting connection...");
  WiFi.mode(WIFI_STA);
  WiFi.setSleep(false);
  
  for (int i = 0; i < WIFI_COUNT; i++) {
    Serial.print("[WIFI] Trying ");
    Serial.print(i + 1);
    Serial.print("/");
    Serial.print(WIFI_COUNT);
    Serial.print(": ");
    Serial.println(wifiList[i].ssid);

    WiFi.begin(wifiList[i].ssid, wifiList[i].password);

    int attempts = 0;
    while (WiFi.status() != WL_CONNECTED && attempts < 30) {
      delay(500);
      Serial.print(".");
      attempts++;
    }

    if (WiFi.status() == WL_CONNECTED) {
      Serial.println("\n[WIFI] ================================");
      Serial.print("[WIFI] Connected: ");
      Serial.println(wifiList[i].ssid);
      Serial.print("[WIFI] IP: ");
      Serial.println(WiFi.localIP());
      Serial.print("[WIFI] MAC: ");
      Serial.println(WiFi.macAddress());
      Serial.println("[WIFI] ================================");
      buzzerWiFiConnected();
      return true;
    }

    Serial.println(" Failed");
    WiFi.disconnect();
    delay(200);
  }

  Serial.println("[WIFI] All networks failed!");
  return false;
}

String getCamUrl() {
  if (mdnsReady) {
    IPAddress camIP = MDNS.queryHost(CAM_HOST);
    if (camIP.toString() != "0.0.0.0") {
      lastKnownCamIp = camIP.toString();
      Serial.print("[MDNS] Found camera at: ");
      Serial.println(lastKnownCamIp);
      return "http://" + lastKnownCamIp + ":" + String(CAM_PORT) + "/capture";
    }
    Serial.println("[MDNS] Camera lookup failed");
  }

  if (lastKnownCamIp.length() > 0) {
    Serial.print("[MDNS] Using cached camera IP: ");
    Serial.println(lastKnownCamIp);
    return "http://" + lastKnownCamIp + ":" + String(CAM_PORT) + "/capture";
  }

  String fallbackIp = String(CAM_IP);
  fallbackIp.trim();
  if (fallbackIp.length() > 0) {
    Serial.print("[MDNS] Using configured fallback IP: ");
    Serial.println(fallbackIp);
    return "http://" + fallbackIp + ":" + String(CAM_PORT) + "/capture";
  }

  Serial.println("[MDNS] No valid camera IP available");
  return "";
}

void pulseCameraTrigger() {
  Serial.println("[CAM] Pulsing GPIO fallback trigger");
  digitalWrite(CAM_TRIGGER, HIGH);
  delay(150);
  digitalWrite(CAM_TRIGGER, LOW);
}

int triggerCameraAndProcess() {
  Serial.println("\n[CAM] Triggering capture...");

  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[CAM] WiFi not connected!");
    return 0;
  }

  String camUrl = getCamUrl();
  Serial.print("[CAM] URL: ");
  Serial.println(camUrl);

  if (camUrl.length() == 0) {
    pulseCameraTrigger();
    return 0;
  }

  HTTPClient http;  
  http.begin(camUrl);
  http.setTimeout(30000);
  http.setReuse(false);
  http.addHeader("Connection", "close");
  
  int httpCode = http.GET();
  int result = 0;
  
  if (httpCode == 200) {
    String response = http.getString();
    Serial.print("[CAM] Response: ");
    Serial.println(response);

    if (response.indexOf("\"stranger\"") != -1 || response.indexOf("\"status\":\"stranger\"") != -1) {
      result = 1;
    } else if (response.indexOf("\"family\"") != -1 || response.indexOf("\"status\":\"family\"") != -1) {
      result = 2;
    } else if (response.indexOf("\"no_face\"") != -1 || response.indexOf("\"status\":\"no_face\"") != -1) {
      result = 3;
    } else if (response.indexOf("\"cooldown\"") != -1) {
      Serial.println("[CAM] Cooldown active");
      result = 3;
    } else {
      Serial.println("[CAM] Unknown response format");
      result = 3;
    }
  } else if (httpCode == 429) {
    Serial.println("[CAM] Cooldown active (429)");
    result = 3;
  } else if (httpCode == 503) {
    Serial.println("[CAM] Camera busy (503)");
    result = 0;
  } else {
    Serial.print("[CAM] HTTP Error: ");
    Serial.print(httpCode);
    Serial.print(" - ");
    Serial.println(http.errorToString(httpCode));
    pulseCameraTrigger();
    result = 0;
  }
  
  http.end();
  return result;
}

void setup() {
  Serial.begin(115200);
  delay(1000);

  pinMode(BUZZER_PIN, OUTPUT);
  pinMode(CAM_TRIGGER, OUTPUT);
  pinMode(LED_PIN, OUTPUT);
  pinMode(PIR_PIN, INPUT);

  digitalWrite(BUZZER_PIN, LOW);
  digitalWrite(CAM_TRIGGER, LOW);
  digitalWrite(LED_PIN, LOW);

  pinMode(REED_PIN, INPUT_PULLUP);
  lastDoorOpen = digitalRead(REED_PIN) == HIGH;
  doorStateInitialized = true;
  Serial.print("[DOOR] Initial state: ");
  Serial.println(lastDoorOpen ? "OPEN" : "CLOSED");

  Serial.println("\n============================================");
  Serial.println("  STRANGER FINDER - DEV BOARD (v3 PIR+REED)");
  Serial.println("============================================");
  Serial.println("  Mode: PIR motion-triggered capture");
  Serial.print("  Cooldown: ");
  Serial.print(PIR_COOLDOWN_MS / 1000);
  Serial.println(" seconds between captures");
  Serial.println("  Beeps: 1=empty, 2=known, 5=stranger");
  Serial.println("  Door: Reed switch on D4");
  Serial.println("============================================\n");

  if (!connectToWiFi()) {
    Serial.println("[ERROR] WiFi failed! Restarting...");
    buzzerError();
    delay(5000);
    ESP.restart();
  }

  mdnsReady = MDNS.begin("strangerfinder-dev");
  if (mdnsReady) {
    Serial.println("[MDNS] Started: strangerfinder-dev.local");
  } else {
    Serial.println("[MDNS] Failed to start responder");
  }

  Serial.println("[READY] Starting captures...\n");
}

void loop() {
  unsigned long now = millis();

  if (now - lastLedToggle >= LED_BLINK_MS) {
    ledState = !ledState;
    digitalWrite(LED_PIN, ledState ? HIGH : LOW);
    lastLedToggle = now;
  }

  if (doorStateInitialized && (now - lastDoorChangeTime >= DOOR_DEBOUNCE_MS)) {
    bool currentDoorOpen = digitalRead(REED_PIN) == HIGH;
    if (currentDoorOpen != lastDoorOpen) {
      lastDoorChangeTime = now;
      lastDoorOpen = currentDoorOpen;

      Serial.print("[DOOR] State changed: ");
      Serial.println(currentDoorOpen ? "OPEN" : "CLOSED");

      if (currentDoorOpen) {
        buzzerDoorOpen();
      }

      sendDoorStatus(currentDoorOpen);
    }
  }

  bool motionDetected = digitalRead(PIR_PIN) == HIGH;

  if (motionDetected && (now - lastCaptureTime >= PIR_COOLDOWN_MS)) {
    lastCaptureTime = now;
    captureCount++;

    Serial.print("\n========== MOTION DETECTED - CAPTURE #");
    Serial.print(captureCount);
    Serial.println(" ==========");

    buzzerMotion();

    int result = triggerCameraAndProcess();

    switch (result) {
      case 1:
        Serial.println("[ALERT] STRANGER DETECTED!");
        buzzerStranger();
        break;
      case 2:
        Serial.println("[INFO] Known person");
        buzzerKnownPerson();
        break;
      case 3:
        Serial.println("[INFO] No face detected");
        buzzerNoFace();
        break;
      default:
        Serial.println("[ERROR] Capture failed");
        buzzerError();
        break;
    }
  }

  static unsigned long lastWiFiCheck = 0;
  if (now - lastWiFiCheck > 30000) {
    lastWiFiCheck = now;
    if (WiFi.status() != WL_CONNECTED) {
      Serial.println("[WIFI] Reconnecting...");
      connectToWiFi();
    }
  }

  delay(100);
}
