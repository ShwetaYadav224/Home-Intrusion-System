# ESP32 Stranger Finder — Setup & Wiring Guide

Complete guide to wire, flash, and connect the ESP32-DEV + ESP32-CAM boards to the Home Security app.

---

## 🔌 Hardware Required

| Component | Qty | Notes |
|-----------|-----|-------|
| ESP32 Dev Board | 1 | Any ESP32 dev module (30-pin or 38-pin) |
| ESP32-CAM (AI-Thinker) | 1 | With OV2640 camera module |
| PIR Motion Sensor (HC-SR501) | 1 | Digital output |
| Active Buzzer | 1 | 3.3V or 5V |
| LED + 220Ω Resistor | 1 | Status indicator |
| FTDI USB-to-Serial Adapter | 1 | For flashing ESP32-CAM (it has no USB port) |
| Jumper Wires | ~15 | Male-to-female recommended |
| Breadboard | 1 | Optional but recommended |

---

## 🔧 Wiring Diagram

### ESP32 DEV Board

```
ESP32 DEV          Component
─────────          ─────────
GPIO 18  ────────→ PIR Sensor OUT
GPIO 21  ────────→ Buzzer (+)
GPIO 19  ────────→ LED (+) → 220Ω → GND
GPIO 5   ────────→ ESP32-CAM GPIO 13 (trigger wire)
3.3V     ────────→ PIR VCC
GND      ────────→ PIR GND, Buzzer GND, LED GND
```

### ESP32-CAM (AI-Thinker)

```
ESP32-CAM          Component
─────────          ─────────
GPIO 13  ←──────── ESP32 DEV GPIO 5 (trigger input)
GPIO 4   ────────→ Onboard Flash LED (built-in)
5V       ←──────── Power supply 5V
GND      ←──────── Power supply GND
```

### Inter-Board Connection

```
ESP32 DEV GPIO 5  ──────→  ESP32-CAM GPIO 13
ESP32 DEV GND     ──────→  ESP32-CAM GND  (common ground!)
```

> ⚠️ **IMPORTANT**: Both boards MUST share a common GND for the trigger signal to work.

---

## 📥 Flashing — Arduino IDE Setup

### 1. Install Arduino IDE
Download from [arduino.cc](https://www.arduino.cc/en/software)

### 2. Add ESP32 Board Support
- Go to **File → Preferences**
- In "Additional Board Manager URLs", add:
  ```
  https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json
  ```
- Go to **Tools → Board → Board Manager**
- Search "ESP32" and install **esp32 by Espressif Systems**

### 3. Flash ESP32 DEV Board

| Setting | Value |
|---------|-------|
| Board | ESP32 Dev Module |
| Upload Speed | 115200 |
| Port | (your USB port) |

1. Open `esp32/esp32_dev.ino`
2. Select the correct board and port
3. Click **Upload** ▶️

### 4. Flash ESP32-CAM (via FTDI adapter)

```
FTDI Adapter       ESP32-CAM
────────────       ─────────
GND         ────→  GND
VCC (5V)    ────→  5V
TX          ────→  U0R (GPIO 3)
RX          ────→  U0T (GPIO 1)
                   GPIO 0 ────→ GND  (for flashing mode!)
```

| Setting | Value |
|---------|-------|
| Board | AI Thinker ESP32-CAM |
| Upload Speed | 115200 |
| Port | (your FTDI port) |

1. Open `esp32/esp32_cam.ino`
2. Connect **GPIO 0 to GND** (puts the board in flash mode)
3. Press the **RST** button on the ESP32-CAM
4. Click **Upload** ▶️
5. After upload, **disconnect GPIO 0 from GND**
6. Press **RST** again to boot normally

---

## 🌐 Local Testing

To test against your local Django server instead of Render:

### 1. Find your PC's local IP
```bash
# Linux/Mac
ip addr show | grep "inet "
# or
hostname -I
```

### 2. Update the ESP32 code
In both `.ino` files, the active URL already points to localhost. Just replace `X` with your PC's last IP octet:
```cpp
const char* SERVER_URL = "http://192.168.1.100:8000/api/v1/detect/arcface/";
```

### 3. Run Django locally
```bash
python manage.py migrate
python manage.py runserver 0.0.0.0:8000
```

> The `0.0.0.0` is important — it makes Django accessible from other devices on your network, not just localhost.

---

## 📱 Connecting to the Flutter App

### 1. Register the Device
- Open the app → **Devices** tab → tap **+** (FAB)
- Enter:
  - **Device ID**: `strangerfinder-001` (must match the code)
  - **Name**: e.g. "Front Door Camera"
  - **Location**: e.g. "Main Entrance"

### 2. Set the Stream URL (for live feed)
After the ESP32-CAM connects to WiFi, check the Serial Monitor for:
```
[STREAM] View at: http://192.168.1.50:81/stream
```
Then update the device via the API or Django admin:
- **stream_url**: `http://192.168.1.50:81/stream`

Once set, a **"Live"** button will appear on the device card in the app.

### 3. Test the Pipeline
1. Power on both boards
2. Wave your hand in front of the PIR sensor
3. Watch Serial Monitor for: `[PIR] >>> PERSON DETECTED <<<`
4. The ESP32-DEV triggers the CAM → photo captured → sent to server
5. Check the app **Dashboard** for the new detection event

---

## 🔍 Troubleshooting

| Problem | Solution |
|---------|----------|
| "Could not connect to any WiFi" | Check SSID/password in the code. Make sure ESP32 is within range. |
| Camera init failed | Make sure the camera ribbon cable is properly seated |
| HTTP Error on send | Verify server URL, check if server is running. Open Serial Monitor at 115200 baud. |
| Trigger not working | Verify GPIO 5 (DEV) → GPIO 13 (CAM) wire + common GND |
| PIR triggers constantly | Let PIR warm up for 60 seconds. Adjust sensitivity potentiometer on the PIR module. |
| Live stream not loading in app | ESP32-CAM must be on same WiFi as your phone. The stream URL must include port 81. |
| Flash upload fails on CAM | Make sure GPIO 0 is connected to GND during upload, then disconnect after. |
