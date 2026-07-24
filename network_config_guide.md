# FarmFeed Network Configuration Guide

Use this guide to update your application settings whenever you switch to a new network or need to change your server's IP/Port.

## 1. Summary of Required Changes

| Component | File Path | What to Change | Purpose |
| :--- | :--- | :--- | :--- |
| **Flutter App** | `farmfeed/lib/core/constants.dart` | `baseUrl` (Line 7) | Points the app to the server's new IP. |
| **Backend** | `backend/config.py` | `PORT` (Line 23) | Sets the port the server listens on. |
| **Backend** | `backend/app.py` | `print(...)` (Line 61) | Updates the helper message in the terminal. |

---

## 2. Step-by-Step Instructions

### A. Frontend (Flutter)
Open `farmfeed/lib/core/constants.dart`. Update the IP address to match your computer's current local IP (found via `ipconfig` in terminal).

```dart
// Line 7
static const String baseUrl = 'http://192.168.1.XXX:5000/api';
```

### B. Backend (Python/Flask)
Open `backend/config.py`. Ensure the `HOST` is set to `"0.0.0.0"` so it can be reached from other devices on the network.

```python
# Lines 22-23
HOST = "0.0.0.0"
PORT = 5000
```

---

## 3. Quick Reference for Different Devices

| Device Type | Recommended IP in `constants.dart` |
| :--- | :--- |
| **Android Emulator** | `http://10.0.2.2:5000/api` |
| **iOS Simulator** | `http://127.0.0.1:5000/api` |
| **Physical Phone** | `http://<YOUR_PC_IP>:5000/api` |

---

## 4. Troubleshooting
1. **Firewall**: Ensure your computer's firewall allows incoming connections on the chosen port (default 5000).
2. **Same Network**: Ensure both your computer and the physical phone are connected to the **same Wi-Fi network**.
3. **Restart Server**: Always restart the backend server (`python app.py`) after changing settings in `config.py`.
