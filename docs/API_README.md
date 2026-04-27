# Waffer API — وفر

دليل استخدام الـ API الخاص بتطبيق Waffer (الإصدار v1).

## المتطلبات الأساسية

| البيئة | القيمة |
|---|---|
| Base URL | `http://127.0.0.1:8000/api/v1` |
| Auth | Laravel Sanctum (Bearer Token) |
| Headers | `Accept: application/json`, `Accept-Language: ar` أو `en` |

## استيراد Postman Collection

1. افتح Postman → **Import**
2. اختر الملفين:
   - `docs/Waffer.postman_collection.json`
   - `docs/Waffer.postman_environment.json`
3. اختر بيئة **Waffer — Local** من أعلى يمين الشاشة
4. ابدأ بطلبات Auth أولاً

## رموز OTP في بيئة التطوير

- في `APP_ENV=local` أو `testing`، الرمز دائماً **`123456`**.
- صلاحية الرمز: **دقيقتان (120 ثانية)** فقط.
- إعادة الإرسال (cooldown): 60 ثانية بين كل طلب.

## تدفق المصادقة الذكي (Smart Auth Flow)

النظام يقرر تلقائياً سواء كان المستخدم جديداً أو موجوداً — العميل يُرسل **رقم الهاتف فقط** ولا يحتاج تحديد `purpose`.

### الخطوة 1 (موحدة): طلب OTP

```http
POST /auth/send-otp
{ "phone": "+967777172034" }
```

**Response:**
```json
{
  "data": {
    "is_new_user": false,    // أو true إذا الرقم جديد
    "expires_in": 120,
    "cooldown_seconds": 60
  },
  "message": "تم إرسال رمز تسجيل الدخول"
}
```

### الخطوة 2 (موحدة): التحقق

```http
POST /auth/verify-otp
{ "phone": "+966555555555", "code": "123456" }
```

#### إذا الرقم لمستخدم موجود (`is_new_user: false` في الخطوة 1)
```json
{
  "data": {
    "user": { ... },
    "token": "1|abc...",
    "is_new_user": false
  },
  "message": "تم تسجيل الدخول بنجاح"
}
```
✅ **انتهى الفلو** — استخدم الـ token.

#### إذا الرقم جديد (`is_new_user: true` في الخطوة 1)
```json
{
  "data": {
    "verified": true,
    "is_new_user": true
  },
  "message": "تم التحقق، أكمل بيانات التسجيل"
}
```
ثم انتقل إلى الخطوة 3.

### الخطوة 3 (للجدد فقط): إكمال التسجيل

```http
POST /auth/register
{
  "phone": "+966555555555",
  "code": "123456",          // نفس الكود من الخطوة 2 — لم يُستهلك بعد
  "name": "Ahmed",
  "email": "ahmed@example.com",
  "monthly_income": 8500,
  "currency": "SAR",
  "language": "ar"
}
```

**Response:**
```json
{
  "data": {
    "user": { ... },
    "token": "1|abc..."
  },
  "message": "تم إنشاء الحساب بنجاح"
}
```

### مثال Flutter كامل (الفلو الذكي)

```dart
Future<void> authenticate(String phone) async {
  // الخطوة 1: أرسل OTP
  final r1 = await dio.post('/auth/send-otp', data: {'phone': phone});
  final isNewUser = r1.data['data']['is_new_user'] as bool;

  // المستخدم يدخل الكود
  final code = await askUserForCode();

  // الخطوة 2: تحقّق
  final r2 = await dio.post('/auth/verify-otp', data: {
    'phone': phone,
    'code': code,
  });

  if (!isNewUser) {
    // مستخدم موجود — تسجيل دخول جاهز
    saveToken(r2.data['data']['token']);
    return;
  }

  // مستخدم جديد — استكمل البيانات
  final profile = await askUserForProfile();
  final r3 = await dio.post('/auth/register', data: {
    'phone': phone,
    'code': code,                       // نفس الكود
    ...profile,
  });
  saveToken(r3.data['data']['token']);
}
```

## شجرة الـ Endpoints الكاملة (38 endpoint)

### Auth (7)
| Method | Endpoint | Description |
|---|---|---|
| POST | `/auth/send-otp` | إرسال OTP |
| POST | `/auth/verify-otp` | التحقق من OTP وتسجيل الدخول |
| POST | `/auth/register` | تسجيل مستخدم جديد |
| GET | `/auth/me` | بيانات المستخدم الحالي |
| PUT | `/auth/profile` | تحديث الملف الشخصي |
| POST | `/auth/logout` | تسجيل خروج (الجهاز الحالي) |
| POST | `/auth/logout-all` | تسجيل خروج (جميع الأجهزة) |

### Dashboard & Insights (3)
| Method | Endpoint | Description |
|---|---|---|
| GET | `/dashboard` | ملخص الصفحة الرئيسية |
| GET | `/insights/expense-analysis` | تحليل المصاريف بالتصنيف |
| GET | `/insights/monthly-report` | تقرير شهري للأشهر السابقة |

### Categories (1)
| Method | Endpoint | Description |
|---|---|---|
| GET | `/categories` | قائمة التصنيفات |

### Budgets (6)
| Method | Endpoint | Description |
|---|---|---|
| GET | `/budgets/current` | الميزانية الحالية النشطة |
| GET | `/budgets` | قائمة كل الميزانيات |
| POST | `/budgets` | إنشاء ميزانية شهرية |
| GET | `/budgets/{id}` | عرض ميزانية محددة |
| PUT | `/budgets/{id}` | تحديث ميزانية |
| DELETE | `/budgets/{id}` | حذف ميزانية |

### Transactions (5)
| Method | Endpoint | Description |
|---|---|---|
| GET | `/transactions` | قائمة المعاملات (مع pagination + filters) |
| POST | `/transactions` | إضافة معاملة |
| GET | `/transactions/{id}` | عرض معاملة |
| PUT | `/transactions/{id}` | تحديث معاملة |
| DELETE | `/transactions/{id}` | حذف معاملة |

### Saving Goals (6)
| Method | Endpoint | Description |
|---|---|---|
| GET | `/saving-goals` | قائمة الأهداف |
| POST | `/saving-goals` | إنشاء هدف |
| GET | `/saving-goals/{id}` | عرض هدف |
| PUT | `/saving-goals/{id}` | تحديث هدف |
| POST | `/saving-goals/{id}/deposit` | إيداع مبلغ في الهدف |
| DELETE | `/saving-goals/{id}` | حذف هدف |

### Alerts (4)
| Method | Endpoint | Description |
|---|---|---|
| GET | `/alerts` | قائمة التنبيهات |
| PUT | `/alerts/{id}/read` | وضع علامة مقروء |
| PUT | `/alerts/read-all` | تعليم الكل كمقروء |
| DELETE | `/alerts/{id}` | حذف تنبيه |

### Tips (2)
| Method | Endpoint | Description |
|---|---|---|
| GET | `/tips` | قائمة النصائح |
| GET | `/tips/{id}` | عرض نصيحة |

### Mock Bank Data (2) ⭐
| Method | Endpoint | Description |
|---|---|---|
| POST | `/mock-bank/import` | استيراد 30 معاملة تجريبية |
| DELETE | `/mock-bank/clear` | حذف المعاملات التجريبية |

## أين تُستخدم Mock Data؟

### 1. للعروض التوضيحية والهاكاثون
عند تجربة المستخدم للتطبيق لأول مرة، يستطيع الضغط على زر **"تعبئة بيانات تجريبية"** ليرى التطبيق ممتلئاً بالمعاملات والإحصائيات الجاهزة دون الحاجة لإدخال يدوي.

### 2. لاختبار الـ API بدون كتابة بيانات يدوياً
أي مطور يحتاج 30 معاملة جاهزة في ثانية واحدة:
```bash
POST /api/v1/mock-bank/import { "clear": true }
```

### 3. من لوحة التحكم Filament
في صفحة **المستخدمون**، كل صف فيه قائمة منسدلة بثلاثة خيارات:
- **تعديل** (Edit)
- **استيراد بيانات تجريبية** (Import Mock Data) — مع تأكيد
- **حذف البيانات التجريبية** (Clear Mock Data)

### 4. عبر CLI أثناء التطوير
```bash
php artisan waffer:import-mock-transactions +966555555555 --clear
```

## شكل الاستجابة الموحد

### نجاح
```json
{
    "success": true,
    "message": "تم بنجاح",
    "data": { ... }
}
```

### فشل
```json
{
    "success": false,
    "message": "حدث خطأ",
    "errors": { "phone": ["رقم الهاتف مطلوب"] }
}
```

## رموز الحالة (Status Codes)

| Code | المعنى |
|---|---|
| 200 | نجح الطلب |
| 201 | تم الإنشاء |
| 400 | طلب غير صالح |
| 401 | غير مصرّح (token مفقود/منتهي) |
| 403 | ممنوع (لا تملك الصلاحية) |
| 404 | غير موجود |
| 422 | بيانات غير صالحة (validation) |
| 429 | كثرة الطلبات (مثلاً OTP cooldown) |
| 500 | خطأ في السيرفر |

## أمثلة سريعة

### تسجيل الدخول
```bash
curl -X POST http://127.0.0.1:8000/api/v1/auth/send-otp \
  -H "Content-Type: application/json" \
  -d '{"phone":"+966555555555","purpose":"login"}'

curl -X POST http://127.0.0.1:8000/api/v1/auth/verify-otp \
  -H "Content-Type: application/json" \
  -d '{"phone":"+966555555555","code":"123456","purpose":"login"}'
```

### استخدام Token
```bash
curl http://127.0.0.1:8000/api/v1/dashboard \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -H "Accept: application/json"
```

## Firebase Phone Authentication (موصى بها للإنتاج)

بدلاً من نظام OTP المحلي، يمكن للتطبيق الاعتماد على Firebase Phone Auth:
- ✅ إرسال SMS مجاني عبر بنية Firebase
- ✅ لا تحتاج spend على gateway SMS
- ✅ حماية تلقائية ضد الـ spam (reCAPTCHA / Play Integrity)
- ✅ يدعم 200+ دولة

### Endpoint

```http
POST /api/v1/auth/firebase
Content-Type: application/json

{
  "id_token": "eyJhbGc...",
  "name": "Ahmed",         // optional, عند التسجيل لأول مرة
  "currency": "SAR",       // optional
  "language": "ar"         // optional
}
```

**Response (200/201):**
```json
{
  "success": true,
  "data": {
    "user": { "id": 5, "name": "Ahmed", "phone": "+966555555555", ... },
    "token": "10|abcdef...",
    "is_new_user": false
  },
  "message": "تم تسجيل الدخول بنجاح"
}
```

### تكامل Flutter كامل

```yaml
# pubspec.yaml
dependencies:
  firebase_core: ^2.x
  firebase_auth: ^4.x
  dio: ^5.x
```

```dart
import 'package:firebase_auth/firebase_auth.dart';

class WafferAuth {
  final _auth = FirebaseAuth.instance;
  final Dio dio;

  WafferAuth(this.dio);

  /// 1) أرسل OTP عبر Firebase
  Future<String> sendOtp(String phone) async {
    final completer = Completer<String>();
    await _auth.verifyPhoneNumber(
      phoneNumber: phone,
      verificationCompleted: (_) {},
      verificationFailed: (e) => completer.completeError(e),
      codeSent: (verificationId, _) => completer.complete(verificationId),
      codeAutoRetrievalTimeout: (_) {},
    );
    return completer.future;
  }

  /// 2) تحقق من OTP، احصل على ID token، أرسله للسيرفر
  Future<String> verifyAndLogin({
    required String verificationId,
    required String smsCode,
    String? name,
  }) async {
    final cred = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    final userCred = await _auth.signInWithCredential(cred);
    final idToken = await userCred.user!.getIdToken();

    final response = await dio.post('/auth/firebase', data: {
      'id_token': idToken,
      if (name != null) 'name': name,
      'currency': 'SAR',
      'language': 'ar',
    });

    return response.data['data']['token'] as String; // Sanctum token
  }
}
```

### في إعدادات Firebase Console

1. اذهب إلى **Authentication → Sign-in method**
2. فعّل **Phone**
3. أضف رقم تجريبي: **+966555555555 / 123456** (للاختبار بدون SMS حقيقي)
4. للأندرويد: تأكد من رفع SHA-1 و SHA-256 لـ `google-services.json`

### مقارنة بين OTP المحلي و Firebase Phone Auth

| | OTP المحلي (الحالي) | Firebase Phone Auth |
|---|---|---|
| إرسال SMS | يحتاج gateway مدفوع | مجاني (Spark plan: 10K/شهر) |
| التحقق | في قاعدة بياناتنا | في Firebase |
| الكود في الديف | `123456` ثابت | أرقام تجريبية في Firebase Console |
| Endpoint | `send-otp` + `verify-otp` | `auth/firebase` (واحد فقط) |
| التوصية | للاختبار / fallback | **للإنتاج** |

> 💡 الـ endpoints القديمة (`send-otp`, `verify-otp`, `register`) **لا تزال تعمل** كـ fallback. اختر ما يناسبك.

## Push Notifications (FCM)

التطبيق متكامل مع Firebase Cloud Messaging لإرسال إشعارات Push تلقائياً.

### كيف تعمل المنظومة؟

```
Flutter App
    ↓ (1) جلب FCM token من firebase_messaging
    ↓ (2) POST /devices/register
Laravel Backend
    ↓ يحفظ التوكن في device_tokens
    ↓
أي حدث ينشئ Alert (تجاوز ميزانية، تحقيق هدف، رسالة admin):
    ↓ AlertObserver يلتقطه تلقائياً
    ↓ يستدعي FcmService::sendForAlert()
Firebase
    ↓
يصل الإشعار للجهاز
```

### Endpoints

| Method | Endpoint | الوصف |
|---|---|---|
| `POST` | `/devices/register` | تسجيل/تحديث FCM token (يُستدعى عند login) |
| `POST` | `/devices/unregister` | إلغاء (يُستدعى عند logout) |
| `GET` | `/devices` | قائمة أجهزتي |
| `POST` | `/devices/test-push` | إرسال إشعار تجريبي لأجهزتي |

### مثال تسجيل توكن من Flutter

```dart
final token = await FirebaseMessaging.instance.getToken();
await dio.post('/devices/register', data: {
  'token': token,
  'platform': 'android',
  'device_name': 'My Phone',
  'app_version': '1.0.0',
  'locale': 'ar',
});
```

### بنية الـ Notification المُرسل

```json
{
  "notification": {
    "title": "تجاوزت ميزانية الطعام",
    "body": "لقد تجاوزت الميزانية المخصصة بنسبة 15%"
  },
  "data": {
    "alert_id": "42",
    "alert_type": "exceeded",
    "severity": "critical",
    "click_action": "FLUTTER_NOTIFICATION_CLICK"
  }
}
```

### إعدادات `.env` المطلوبة

```env
FIREBASE_CREDENTIALS=storage/app/firebase/firebase-credentials.json
FIREBASE_PROJECT_ID=molly-9a63d
FCM_ENABLED=true
```

> ⚠️ ملف `firebase-credentials.json` **سرّي** ومُستثنى من Git عبر `.gitignore`.
