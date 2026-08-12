
#include "esp_camera.h"
#include <WiFi.h>
#include <HTTPClient.h>
#include <WebServer.h>
#include <ESPmDNS.h>
#include "mbedtls/base64.h"

#define PWDN_GPIO_NUM     32
#define RESET_GPIO_NUM    -1
#define XCLK_GPIO_NUM      0
#define SIOD_GPIO_NUM     26
#define SIOC_GPIO_NUM     27
#define Y9_GPIO_NUM       35
#define Y8_GPIO_NUM       34
#define Y7_GPIO_NUM       39
#define Y6_GPIO_NUM       36
#define Y5_GPIO_NUM       21
#define Y4_GPIO_NUM       19
#define Y3_GPIO_NUM       18
#define Y2_GPIO_NUM        5
#define VSYNC_GPIO_NUM    25
#define HREF_GPIO_NUM     23
#define PCLK_GPIO_NUM     22

#define TRIGGER_PIN       13
#define FLASH_LED_PIN      4

const char* DETECT_URL = "http://172.20.10.10:8001/api/v1/detect/arcface/";
const char* DEVICE_ID  = "strangerfinder-001";

struct WiFiCredential {
  const char* ssid;  const char* password;
};
 
const WiFiCredential wifiList[] = {
  {"JioFiber-AEh6c",     "heefeaG6eemei4qu"},
  {"JioFiber-AEh6c_5G",  "heefeaG6eemei4qu"},
  {"shweta22y",             "123abcde"},
  {"OmkarMesh5G-Main",   "darkmatter"}
};

const int WIFI_COUNT = sizeof(wifiList) / sizeof(wifiList[0]);

const unsigned long CAPTURE_COOLDOWN_MS = 5000;
const unsigned long HTTP_TRIGGER_COOLDOWN_MS = 3000;
const unsigned long TRIGGER_DEBOUNCE_MS = 500;
const int MAX_RETRIES = 2;
const unsigned long RETRY_DELAY_MS = 2000;
const int MAX_CONSECUTIVE_FAILURES = 3;

volatile bool triggerReceived = false;
volatile unsigned long lastTriggerISR = 0;
unsigned long lastCaptureTime = 0;
unsigned long lastHTTPTriggerTime = 0;
bool captureInProgress = false;
String localIP = "";
int consecutiveCaptureFailures = 0;

WiFiClient streamClient;
bool streamActive = false;
unsigned long lastStreamFrame = 0;

WebServer streamServer(81);

void handleStreamStart();
void sendStreamFrame();
void handleStreamIndex();
void handleCaptureTrigger();
void handleStatus();
String captureAndSend();

void IRAM_ATTR onTrigger() {
  unsigned long now = millis();
  if (now - lastTriggerISR > TRIGGER_DEBOUNCE_MS) {
    triggerReceived = true;
    lastTriggerISR = now;
  }
}

bool connectToWiFi() {
  Serial.println("\n[WIFI] Starting WiFi connection...");
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
      Serial.print("[WIFI] Connected to: ");
      Serial.println(wifiList[i].ssid);
      Serial.print("[WIFI] IP Address:   ");
      Serial.println(WiFi.localIP());
      Serial.print("[WIFI] MAC Address:  ");
      Serial.println(WiFi.macAddress());
      Serial.println("[WIFI] ================================");
      localIP = WiFi.localIP().toString();
      return true;
    }

    Serial.println(" Failed");
    WiFi.disconnect();
    delay(200);
  }

  Serial.println("[WIFI] Could not connect to any WiFi network!");
  return false;
}

bool initCamera() {
  camera_config_t config;
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer   = LEDC_TIMER_0;
  config.pin_d0       = Y2_GPIO_NUM;
  config.pin_d1       = Y3_GPIO_NUM;
  config.pin_d2       = Y4_GPIO_NUM;
  config.pin_d3       = Y5_GPIO_NUM;
  config.pin_d4       = Y6_GPIO_NUM;
  config.pin_d5       = Y7_GPIO_NUM;
  config.pin_d6       = Y8_GPIO_NUM;
  config.pin_d7       = Y9_GPIO_NUM;
  config.pin_xclk     = XCLK_GPIO_NUM;
  config.pin_pclk     = PCLK_GPIO_NUM;
  config.pin_vsync    = VSYNC_GPIO_NUM;
  config.pin_href     = HREF_GPIO_NUM;
  config.pin_sscb_sda = SIOD_GPIO_NUM;
  config.pin_sscb_scl = SIOC_GPIO_NUM;
  config.pin_pwdn     = PWDN_GPIO_NUM;
  config.pin_reset    = RESET_GPIO_NUM;
  config.xclk_freq_hz = 20000000;
  config.pixel_format = PIXFORMAT_JPEG;

  if (psramFound()) {
    config.frame_size   = FRAMESIZE_QVGA;
    config.jpeg_quality = 15;
    config.fb_count     = 2;
    Serial.println("[CAM] PSRAM found, using QVGA for stable streaming");
  } else {
    config.frame_size   = FRAMESIZE_QVGA;
    config.jpeg_quality = 20;
    config.fb_count     = 1;
    Serial.println("[CAM] No PSRAM, using QVGA resolution");
  }

  esp_err_t err = esp_camera_init(&config);
  if (err != ESP_OK) {
    Serial.print("[CAM] Init FAILED: 0x");
    Serial.println(err, HEX);
    return false;
  }

  Serial.println("[CAM] Camera initialized successfully");
  return true;
}

void handleStreamStart() {
  if (streamActive && streamClient.connected()) {
    Serial.println("[STREAM] Replacing existing stream client");
    streamClient.stop();
  }

  streamClient = streamServer.client();
  if (!streamClient.connected()) {
    return;
  }

  String response = "HTTP/1.1 200 OK\r\n";
  response += "Access-Control-Allow-Origin: *\r\n";
  response += "Content-Type: multipart/x-mixed-replace; boundary=frame\r\n\r\n";
  streamClient.print(response);
  streamClient.flush();

  streamActive = true;
  lastStreamFrame = 0;
  Serial.println("[STREAM] Client connected — streaming started");
}

void sendStreamFrame() {
  if (!streamActive) return;

  if (!streamClient.connected()) {
    streamActive = false;
    Serial.println("[STREAM] Client disconnected");
    return;
  }

  if (captureInProgress) return;

  unsigned long now = millis();
  if (now - lastStreamFrame < 100) return;

  camera_fb_t* fb = esp_camera_fb_get();
  if (!fb) return;

  if (fb->len == 0 || fb->buf == NULL) {
    esp_camera_fb_return(fb);
    return;
  }

  String header = "--frame\r\nContent-Type: image/jpeg\r\nContent-Length: " + String(fb->len) + "\r\n\r\n";

  if (!streamClient.connected()) {
    esp_camera_fb_return(fb);
    streamActive = false;
    return;
  }

  streamClient.print(header);

  const size_t chunkSize = 1024;
  size_t offset = 0;
  while (offset < fb->len && streamClient.connected()) {
    size_t toSend = min(chunkSize, fb->len - offset);
    streamClient.write(fb->buf + offset, toSend);
    offset += toSend;
  }

  if (streamClient.connected()) {
    streamClient.print("\r\n");
  } else {
    streamActive = false;
  }

  esp_camera_fb_return(fb);
  lastStreamFrame = millis();
}

void handleStreamIndex() {
  String html = "<!DOCTYPE html><html><head>";
  html += "<meta name='viewport' content='width=device-width,initial-scale=1'>";
  html += "<title>ESP32-CAM Stream</title>";
  html += "<style>body{font-family:Arial,sans-serif;text-align:center;margin:20px;}";
  html += "img{max-width:100%;height:auto;border:2px solid #333;border-radius:8px;}";
  html += ".info{background:#f0f0f0;padding:10px;border-radius:5px;margin:10px 0;}";
  html += "</style></head><body>";
  html += "<h1>ESP32-CAM Stream</h1>";
  html += "<div class='info'><strong>Device:</strong> " + String(DEVICE_ID) + "<br>";
  html += "<strong>IP:</strong> " + localIP + "</div>";
  html += "<img src='/stream' alt='Camera Stream'/>";
  html += "<p><a href='/capture' target='_blank'>Trigger Capture</a> | ";
  html += "<a href='/status' target='_blank'>Status</a></p>";
  html += "</body></html>";
  streamServer.send(200, "text/html", html);
}

void handleStatus() {
  unsigned long now = millis();
  unsigned long captureCooldownRemaining = 0;
  unsigned long httpCooldownRemaining = 0;
  
  if (now - lastCaptureTime < CAPTURE_COOLDOWN_MS) {
    captureCooldownRemaining = (CAPTURE_COOLDOWN_MS - (now - lastCaptureTime)) / 1000;
  }
  if (now - lastHTTPTriggerTime < HTTP_TRIGGER_COOLDOWN_MS) {
    httpCooldownRemaining = (HTTP_TRIGGER_COOLDOWN_MS - (now - lastHTTPTriggerTime)) / 1000;
  }
  
  String status = "{";
  status += "\"device_id\":\"" + String(DEVICE_ID) + "\",";
  status += "\"ip\":\"" + localIP + "\",";
  status += "\"capture_in_progress\":" + String(captureInProgress ? "true" : "false") + ",";
  status += "\"capture_cooldown_sec\":" + String(captureCooldownRemaining) + ",";
  status += "\"http_cooldown_sec\":" + String(httpCooldownRemaining) + ",";
  status += "\"wifi_connected\":" + String(WiFi.status() == WL_CONNECTED ? "true" : "false") + ",";
  status += "\"wifi_rssi\":" + String(WiFi.RSSI()) + ",";
  status += "\"uptime_sec\":" + String(now / 1000);
  status += "}";
  
  streamServer.send(200, "application/json", status);
}

void handleCaptureTrigger() {
  unsigned long now = millis();
  
  if (now - lastHTTPTriggerTime < HTTP_TRIGGER_COOLDOWN_MS) {
    unsigned long remaining = (HTTP_TRIGGER_COOLDOWN_MS - (now - lastHTTPTriggerTime)) / 1000;
    String response = "{\"status\":\"cooldown\", \"message\":\"Please wait " + String(remaining) + " seconds\"}";
    streamServer.send(429, "application/json", response);
    return;
  }
  
  if (captureInProgress) {
    streamServer.send(503, "application/json", "{\"status\":\"busy\", \"message\":\"Capture in progress\"}");
    return;
  }
  
  Serial.println("[CAM] >>> HTTP trigger received! <<<");
  lastHTTPTriggerTime = now;
  
  String djangoResponse = captureAndSend();
  
  if (djangoResponse == "") {
    streamServer.send(500, "application/json", "{\"status\":\"error\", \"message\":\"Capture failed\"}");
  } else {
    streamServer.send(200, "application/json", djangoResponse);
  }
}

String captureAndSend() {
  captureInProgress = true;
  Serial.println("[CAM] Starting capture sequence...");

  digitalWrite(FLASH_LED_PIN, HIGH);
  delay(150);

  camera_fb_t* fb = esp_camera_fb_get();
  if (fb) {
    esp_camera_fb_return(fb);
    delay(100);
  }

  fb = esp_camera_fb_get();
  digitalWrite(FLASH_LED_PIN, LOW);

  if (!fb) {
    Serial.println("[CAM] Capture FAILED!");
    captureInProgress = false;
    return "";
  }

  Serial.print("[CAM] Photo captured, size: ");
  Serial.print(fb->len);
  Serial.println(" bytes");

  if (fb->len < 1000) {
    Serial.println("[CAM] Image too small, retrying...");
    esp_camera_fb_return(fb);
    delay(200);
    fb = esp_camera_fb_get();
    if (!fb || fb->len < 1000) {
      Serial.println("[CAM] Retry also failed!");
      if (fb) esp_camera_fb_return(fb);
      captureInProgress = false;
      return "";
    }
  }

  size_t base64Len = 0;
  mbedtls_base64_encode(NULL, 0, &base64Len, fb->buf, fb->len);

  uint8_t* base64Buf = (uint8_t*)(psramFound() ? ps_malloc(base64Len + 1) : malloc(base64Len + 1));
  if (!base64Buf) {
    Serial.println("[CAM] Memory allocation failed!");
    esp_camera_fb_return(fb);
    captureInProgress = false;
    consecutiveCaptureFailures++;
    return "";
  }

  size_t written = 0;
  mbedtls_base64_encode(base64Buf, base64Len, &written, fb->buf, fb->len);
  base64Buf[written] = '\0';

  esp_camera_fb_return(fb);
  lastCaptureTime = millis();

  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[CAM] WiFi not connected, reconnecting...");
    if (!connectToWiFi()) {
      free(base64Buf);
      captureInProgress = false;
      return "";
    }
  }

  String payload;
  payload.reserve(written + 96);
  payload += "{\"deviceId\":\"";
  payload += DEVICE_ID;
  payload += "\",\"type\":\"person_detected\",\"image\":\"";
  payload += (char*)base64Buf;
  payload += "\"}";

  free(base64Buf);

  Serial.print("[CAM] Sending to server (");
  Serial.print(payload.length());
  Serial.println(" bytes)...");

  String finalResponse = "";
  
  for (int attempt = 1; attempt <= MAX_RETRIES; attempt++) {
    HTTPClient http;
    http.begin(DETECT_URL);
    http.addHeader("Content-Type", "application/json");
    http.setTimeout(30000);
    http.setReuse(false);

    Serial.print("[CAM] Attempt ");
    Serial.print(attempt);
    Serial.print("/");
    Serial.println(MAX_RETRIES);

    int httpCode = http.POST(payload);

    if (httpCode > 0) {
      finalResponse = http.getString();
      Serial.print("[CAM] Server response (");
      Serial.print(httpCode);
      Serial.print("): ");
      Serial.println(finalResponse);
      http.end();
      break;
    } else {
      Serial.print("[CAM] HTTP Error: ");
      Serial.println(http.errorToString(httpCode));
      http.end();
      
      if (attempt < MAX_RETRIES) {
        Serial.println("[CAM] Retrying...");
        delay(RETRY_DELAY_MS);
      }
    }
  }

  captureInProgress = false;
  if (finalResponse.length() > 0) {
    consecutiveCaptureFailures = 0;
  } else {
    consecutiveCaptureFailures++;
    Serial.print("[CAM] Consecutive failures: ");
    Serial.println(consecutiveCaptureFailures);
    if (consecutiveCaptureFailures >= MAX_CONSECUTIVE_FAILURES) {
      Serial.println("[CAM] Too many failures, restarting camera module...");
      delay(1000);
      ESP.restart();
    }
  }
  return finalResponse;
}

void setup() {
  Serial.begin(115200);
  delay(1000);
  
  Serial.println("\n============================================");
  Serial.println("  STRANGER FINDER - ESP32-CAM (ROBUST v3)");
  Serial.println("============================================");

  pinMode(FLASH_LED_PIN, OUTPUT);
  digitalWrite(FLASH_LED_PIN, LOW);
  pinMode(TRIGGER_PIN, INPUT_PULLDOWN);
  attachInterrupt(digitalPinToInterrupt(TRIGGER_PIN), onTrigger, RISING);

  Serial.println("[CONFIG] Settings:");
  Serial.print("  - Capture cooldown: ");
  Serial.print(CAPTURE_COOLDOWN_MS / 1000);
  Serial.println(" sec");
  Serial.print("  - Max retries: ");
  Serial.println(MAX_RETRIES);
  Serial.println("============================================\n");

  if (!initCamera()) {
    Serial.println("[CAM] Camera init failed! Restarting...");
    delay(5000);
    ESP.restart();
  }

  if (!connectToWiFi()) {
    Serial.println("[WIFI] Connection failed! Restarting...");
    delay(5000);
    ESP.restart();
  }

  if (MDNS.begin("strangerfinder-cam")) {
    Serial.println("[MDNS] Started: http://strangerfinder-cam.local");
  }

  streamServer.on("/", handleStreamIndex);
  streamServer.on("/stream", HTTP_GET, handleStreamStart);
  streamServer.on("/capture", HTTP_GET, handleCaptureTrigger);
  streamServer.on("/status", HTTP_GET, handleStatus);
  streamServer.begin();

  Serial.println("\n============================================");
  Serial.println("  STREAM SERVER READY");
  Serial.println("============================================");
  Serial.print("  Local:  http://");
  Serial.print(localIP);
  Serial.println(":81/stream");
  Serial.print("  mDNS:   http://strangerfinder-cam.local:81/stream");
  Serial.println("\n============================================\n");
}

void loop() {
  streamServer.handleClient();

  sendStreamFrame();

  if (triggerReceived) {
    triggerReceived = false;
    unsigned long now = millis();

    if (now - lastCaptureTime > CAPTURE_COOLDOWN_MS && !captureInProgress) {
      Serial.println("[CAM] >>> GPIO Trigger received! <<<");
      captureAndSend();
    } else {
      unsigned long remaining = (CAPTURE_COOLDOWN_MS - (now - lastCaptureTime)) / 1000;
      Serial.print("[CAM] Trigger ignored (cooldown: ");
      Serial.print(remaining);
      Serial.println(" sec)");
    }
  }

  static unsigned long lastWiFiCheck = 0;
  unsigned long now = millis();
  if (now - lastWiFiCheck > 10000) {
    lastWiFiCheck = now;
    if (WiFi.status() != WL_CONNECTED) {
      Serial.println("[WIFI] Connection lost, reconnecting...");
      connectToWiFi();
    } 
  }

  delay(10);
}
