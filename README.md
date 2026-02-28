# 📱 Recap Maker — Flutter Android App

မင်းရဲ့ Recap Maker Flask backend နဲ့ ချိတ်ဆက်တဲ့ Flutter Android App

---

## 🗂️ Project Structure

```
recap_maker/
├── lib/
│   ├── main.dart                          ← App entry point
│   ├── core/
│   │   ├── constants.dart                 ← BASE_URL ဒီမှာ ပြောင်းပါ ⚠️
│   │   ├── api_client.dart                ← HTTP + Cookie Manager
│   │   └── models/
│   │       └── history_model.dart
│   └── features/
│       ├── auth/
│       │   ├── login_screen.dart          ← Login UI
│       │   └── auth_provider.dart
│       ├── dashboard/
│       │   └── dashboard_screen.dart      ← Dashboard + History
│       └── subtitle/
│           └── subtitle_screen.dart       ← Video Upload + Process
├── android/
│   └── app/src/main/
│       └── AndroidManifest.xml           ← Permissions
├── pubspec.yaml                           ← Dependencies
└── README.md
```

---

## ⚡ Setup Steps (အဆင့်ဆင့်)

### Step 1 — Flutter Install

```bash
# flutter.dev မှ SDK download ဆွဲပါ
# PATH ထဲ ထည့်ပြီး စစ်ပါ
flutter doctor
```

### Step 2 — Project Setup

```bash
# Flutter project အသစ်ဆောက်ပါ
flutter create recap_maker
cd recap_maker

# ဒီ README ရဲ့ files တွေကို မင်းရဲ့ project ထဲ ထည့်ပါ
# (lib/ folder နဲ့ pubspec.yaml ကို replace လုပ်ပါ)

# Dependencies install
flutter pub get
```

### Step 3 — BASE_URL ပြောင်းပါ ⚠️

`lib/core/constants.dart` ဖိုင်ကို ဖွင့်ပြီး:

```dart
static const String baseUrl = 'https://YOUR_SERVER_URL_HERE';
// ↑ ဒါကို မင်းရဲ့ server address နဲ့ ပြောင်းပါ
// Example: 'https://myapp.hf.space'
```

### Step 4 — Backend CORS ထည့်ပါ

မင်းရဲ့ `app.py` ထဲ ဒီကောင် ထည့်ပါ:

```bash
pip install flask-cors
```

```python
from flask_cors import CORS
# app = Flask(...) ပြီးနောက် ထည့်ပါ
CORS(app, supports_credentials=True)
```

### Step 5 — Run / Build

```bash
# Emulator/Device မှာ test run
flutter run

# APK build (phone ထဲ install အတွက်)
flutter build apk --release

# APK ရှိနေမည့် path:
# build/app/outputs/flutter-apk/app-release.apk
```

---

## 🔌 API Endpoints (Backend ဘက်)

| Method | Endpoint | ရှင်းလင်းချက် |
|--------|----------|--------------|
| POST | `/login` | Username/Password Login |
| GET | `/logout` | Session ဖျက်ပြီး Logout |
| GET | `/api/my_history` | Video history စာရင်း |
| POST | `/upload-init` | Chunk upload session ဖွင့် |
| POST | `/upload-chunk` | Video chunk တစ်ခုချင်း upload |
| POST | `/upload-complete` | Upload ပြီးစီးကြောင်း ပြောပြ |
| POST | `/process-subtitles` | Subtitle processing job စတင် |
| GET | `/status/{job_id}` | Job status စစ်ဆေး |

---

## 📋 Features

- ✅ **Login Screen** — Username/Password, Session auto-keep
- ✅ **Dashboard** — History list, Status display, Download link
- ✅ **Subtitle Screen** — Video picker, Chunked upload (3MB), Font size/position/opacity settings, Job polling

---

## ❓ မေးခွန်းများ

**Q: Login ဝင်လို့ မရရင်?**
→ constants.dart မှာ baseUrl မှန်မမှန် စစ်ပါ
→ Backend မှာ flask-cors install ဖြစ်မဖြစ် စစ်ပါ

**Q: Upload မရရင်?**
→ AndroidManifest.xml မှာ INTERNET permission ရှိမရှိ စစ်ပါ
→ Backend server running ဖြစ်နေမဖြစ် စစ်ပါ

**Q: APK ကို phone ထဲ install လို့မရရင်?**
→ Phone settings > Security > Unknown sources ဖွင့်ပါ
