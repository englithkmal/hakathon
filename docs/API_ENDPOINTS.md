# Waffer API Endpoints

**Base URL:** `http://127.0.0.1:8000/api/v1`

**Headers الموحَّدة لكل الطلبات:**
```
Content-Type: application/json
Accept: application/json
Accept-Language: ar | en
Authorization: Bearer {token}      ← فقط للـ Endpoints المحمية 🔒
```

---

## 1. Authentication

### `POST /auth/send-otp`
**ماذا يفعل:** يرسل رمز OTP للمستخدم. يكتشف تلقائياً إذا كان الرقم لمستخدم موجود (login) أو جديد (register).

**Body:**
```json
{
  "phone": "+966555555555",
  "device_token": "FCM_TOKEN",   // اختياري - لاستلام OTP كإشعار push
  "platform": "android",          // اختياري - android | ios | web
  "locale": "ar"                  // اختياري - ar | en
}
```

**Response:**
```json
{
  "success": true,
  "message": "تم إرسال رمز تسجيل الدخول",
  "data": {
    "is_new_user": false,
    "expires_in": 120,
    "cooldown_seconds": 60,
    "delivery": "push",
    "hint": "الرمز تم إرساله كإشعار على جهازك"
  }
}
```

---

### `POST /auth/verify-otp`
**ماذا يفعل:** يتحقق من OTP. للمستخدم الموجود يُسجّله ويُصدر token. للجديد يُرجع `is_new_user: true` لاستكمال التسجيل.

**Body:**
```json
{
  "phone": "+966555555555",
  "code": "847291"
}
```

**Response (مستخدم موجود):**
```json
{
  "data": {
    "user": { /* UserResource */ },
    "token": "1|abc123...",
    "is_new_user": false
  }
}
```

**Response (مستخدم جديد):**
```json
{
  "data": { "verified": true, "is_new_user": true }
}
```

---

### `POST /auth/register`
**ماذا يفعل:** يكمل تسجيل مستخدم جديد. يُستدعى فقط بعد `verify-otp` بـ `is_new_user: true`.

**Body:**
```json
{
  "phone": "+966555555555",
  "code": "847291",
  "name": "أحمد محمد",
  "email": "ahmed@example.com",       // اختياري
  "monthly_income": 8500,              // اختياري
  "currency": "SAR",                    // SAR|JOD|USD|AED|EUR
  "language": "ar"                      // ar|en
}
```

---

### `POST /auth/firebase`
**ماذا يفعل:** بديل عن send-otp/verify-otp — يقبل Firebase ID Token من Phone Auth ويصدر Sanctum token.

**Body:**
```json
{
  "id_token": "eyJhbGciOiJSUzI1NiIs...",
  "name": "أحمد",                  // اختياري (للمستخدم الجديد)
  "monthly_income": 8500,           // اختياري
  "currency": "SAR",                 // اختياري
  "language": "ar"                   // اختياري
}
```

---

### `GET /auth/me` 🔒
**ماذا يفعل:** يُرجع بيانات المستخدم الحالي.

**Body:** —

---

### `PUT /auth/profile` 🔒
**ماذا يفعل:** يُحدّث بيانات المستخدم.

**Body (كل الحقول اختيارية):**
```json
{
  "name": "أحمد محمد",
  "email": "new@email.com",
  "monthly_income": 9500,
  "currency": "SAR",
  "language": "ar"
}
```

---

### `POST /auth/logout` 🔒
**ماذا يفعل:** يُسجّل خروج الجهاز الحالي (يحذف الـ token الحالي فقط).

**Body:** —

---

### `POST /auth/logout-all` 🔒
**ماذا يفعل:** يُسجّل خروج من جميع الأجهزة (يحذف كل الـ tokens).

**Body:** —

---

## 2. Devices (FCM Tokens)

### `POST /devices/register` 🔒
**ماذا يفعل:** يُسجّل FCM token لجهاز المستخدم لاستلام Push Notifications.

**Body:**
```json
{
  "token": "FCM_TOKEN",
  "platform": "android",            // android | ios | web
  "device_name": "Samsung S22",      // اختياري
  "device_model": "SM-S901U",        // اختياري
  "app_version": "1.0.0",            // اختياري
  "locale": "ar"                     // اختياري
}
```

---

### `POST /devices/unregister` 🔒
**ماذا يفعل:** يُلغي تسجيل FCM token (عند logout).

**Body:**
```json
{ "token": "FCM_TOKEN" }
```

---

### `GET /devices` 🔒
**ماذا يفعل:** قائمة بكل الأجهزة المسجَّلة للمستخدم.

**Body:** —

---

### `POST /devices/test-push` 🔒
**ماذا يفعل:** يرسل إشعار تجريبي لكل أجهزة المستخدم (لاختبار FCM).

**Body:**
```json
{
  "title": "إشعار تجريبي",       // اختياري
  "body": "محتوى الإشعار"        // اختياري
}
```

---

## 3. Dashboard

### `GET /dashboard` 🔒
**ماذا يفعل:** يُرجع البيانات الكاملة للوحة التحكم الرئيسية: ملخّص الشهر + ميزانية + آخر معاملات + أهداف نشطة + تنبيهات + نصيحة اليوم.

**Body:** —

**Response:**
```json
{
  "data": {
    "currency": "SAR",
    "period": { "month": 4, "year": 2026 },
    "summary": {
      "income": 8500.00,
      "expenses": 4307.00,
      "savings": 1500.00,
      "balance": 2693.00,
      "monthly_income": 8500.00
    },
    "budget": { /* BudgetResource أو null */ },
    "recent_transactions": [ /* آخر 5 معاملات */ ],
    "active_goals": [ /* أحدث 3 أهداف */ ],
    "unread_alerts_count": 3,
    "recent_alerts": [ /* أحدث 5 تنبيهات */ ],
    "tip_of_the_day": { /* نصيحة عشوائية */ }
  }
}
```

---

## 4. Transactions

### `GET /transactions` 🔒
**ماذا يفعل:** قائمة معاملات المستخدم مع pagination وفلاتر.

**Query Parameters (كلها اختيارية):**
```
?type=expense              // expense | income | saving
&category_id=3
&from=2026-04-01           // YYYY-MM-DD
&to=2026-04-30
&search=بقالة
&per_page=20
&page=1
```

---

### `POST /transactions` 🔒
**ماذا يفعل:** يُضيف معاملة جديدة (مصروف/دخل/ادخار).

**Body:**
```json
{
  "amount": 250.50,                    // مطلوب
  "type": "expense",                    // expense | income | saving
  "category_id": 3,                     // اختياري
  "description": "بقالة",               // اختياري
  "merchant": "Carrefour",              // اختياري
  "currency": "SAR",                     // اختياري - يأخذ من المستخدم
  "transaction_date": "2026-04-26",      // اختياري - افتراضي الآن
  "source": "manual",                    // اختياري - manual|mock_bank|imported
  "reference": "TXN-001"                 // اختياري
}
```

---

### `GET /transactions/{id}` 🔒
**ماذا يفعل:** عرض تفاصيل معاملة واحدة.

**Body:** —

---

### `PUT /transactions/{id}` 🔒
**ماذا يفعل:** تحديث معاملة. **Body** مثل `POST /transactions`.

---

### `DELETE /transactions/{id}` 🔒
**ماذا يفعل:** حذف معاملة.

**Body:** —

---

## 5. Budgets

### `GET /budgets` 🔒
**ماذا يفعل:** قائمة بكل الميزانيات (مع pagination، أحدث أولاً).

**Query:** `?per_page=12&page=1`

---

### `GET /budgets/current` 🔒
**ماذا يفعل:** ميزانية الشهر الحالي فقط (أو null إذا لا توجد).

**Body:** —

---

### `POST /budgets` 🔒
**ماذا يفعل:** ينشئ ميزانية جديدة (أو يُحدّث الموجودة لنفس الشهر) مع توزيع على الفئات.

**Body:**
```json
{
  "month": 4,                         // اختياري - افتراضي الشهر الحالي
  "year": 2026,                       // اختياري
  "total_income": 8500,
  "total_amount": 6500,
  "currency": "SAR",                   // اختياري
  "status": "active",                  // draft | active | closed
  "notes": "ميزانية الإجازة",
  "categories": [
    {
      "category_id": 1,
      "allocated_amount": 2000,
      "alert_threshold": 80          // 50-100 - نسبة الإنذار
    }
  ]
}
```

---

### `GET /budgets/{id}` 🔒
**ماذا يفعل:** تفاصيل ميزانية محددة مع فئاتها.

---

### `PUT /budgets/{id}` 🔒
**ماذا يفعل:** تحديث ميزانية. **Body** مثل `POST /budgets`.

---

### `DELETE /budgets/{id}` 🔒
**ماذا يفعل:** حذف ميزانية.

---

## 6. Saving Goals

### `GET /saving-goals` 🔒
**ماذا يفعل:** قائمة أهداف الادخار للمستخدم.

**Query:** `?status=active` (اختياري - active | completed | paused)

---

### `POST /saving-goals` 🔒
**ماذا يفعل:** إنشاء هدف ادخار جديد.

**Body:**
```json
{
  "title": "رحلة دبي",
  "description": "ادخار للسفر",       // اختياري
  "icon": "flight",                    // اختياري
  "color": "#3B82F6",                  // اختياري
  "target_amount": 8000,
  "currency": "SAR",                    // اختياري
  "start_date": "2026-04-01",           // اختياري - افتراضي اليوم
  "deadline": "2026-12-31"              // اختياري
}
```

---

### `GET /saving-goals/{id}` 🔒
**ماذا يفعل:** عرض تفاصيل هدف.

---

### `PUT /saving-goals/{id}` 🔒
**ماذا يفعل:** تحديث هدف. **Body** مثل `POST /saving-goals`.

---

### `POST /saving-goals/{id}/deposit` 🔒
**ماذا يفعل:** إضافة مبلغ إلى رصيد الهدف (current_amount).

**Body:**
```json
{ "amount": 500 }
```

---

### `DELETE /saving-goals/{id}` 🔒
**ماذا يفعل:** حذف هدف.

---

## 7. Categories

### `GET /categories` 🔒
**ماذا يفعل:** قائمة الفئات (طعام، نقل، ترفيه، ...) — تأتي ثنائية اللغة.

**Query:** `?type=expense` (اختياري - expense | income)

**Body:** —

---

## 8. Alerts (التنبيهات)

### `GET /alerts` 🔒
**ماذا يفعل:** قائمة التنبيهات (مرتبة من الأحدث).

**Query:**
```
?unread=true       // اختياري - فقط غير المقروءة
&per_page=20
&page=1
```

---

### `PUT /alerts/{id}/read` 🔒
**ماذا يفعل:** تعليم تنبيه واحد كمقروء.

**Body:** —

---

### `PUT /alerts/read-all` 🔒
**ماذا يفعل:** تعليم كل التنبيهات كمقروءة.

**Body:** —

---

### `DELETE /alerts/{id}` 🔒
**ماذا يفعل:** حذف تنبيه.

**Body:** —

---

## 9. Insights (التحليلات)

### `GET /insights/expense-analysis` 🔒
**ماذا يفعل:** تحليل المصروفات لشهر محدد، مع التوزيع على الفئات والنسب المئوية (لـ Pie Chart).

**Query:**
```
?month=4           // اختياري - افتراضي الشهر الحالي
&year=2026         // اختياري - افتراضي السنة الحالية
```

**Response:**
```json
{
  "data": {
    "period": { "month": 4, "year": 2026 },
    "total_expenses": 4307.00,
    "by_category": [
      {
        "category": { "id": 1, "name": "طعام", "icon": "restaurant", "color": "#F59E0B" },
        "total": 1850.00,
        "count": 23,
        "percentage": 42.95
      }
    ]
  }
}
```

---

### `GET /insights/monthly-report` 🔒
**ماذا يفعل:** تقرير مالي للأشهر الأخيرة (دخل/مصروف/ادخار/رصيد) — لـ Bar Chart.

**Query:** `?months=6` (اختياري - عدد الأشهر، افتراضي 6)

**Response:**
```json
{
  "data": {
    "months": [
      {
        "month": 11, "year": 2025, "label": "نوفمبر 2025",
        "income": 8500, "expenses": 4200, "savings": 1500, "balance": 2800
      }
    ]
  }
}
```

---

## 10. Tips (النصائح)

### `GET /tips` 🔒
**ماذا يفعل:** قائمة النصائح المالية (ثنائية اللغة).

**Body:** —

---

### `GET /tips/{id}` 🔒
**ماذا يفعل:** عرض نصيحة محددة.

**Body:** —

---

## 11. Mock Bank (للاختبار فقط)

### `POST /mock-bank/import` 🔒
**ماذا يفعل:** يستورد معاملات تجريبية من JSON file (`database/data/mock_transactions.json`) لتجربة سريعة.

**Body:** —

---

### `DELETE /mock-bank/clear` 🔒
**ماذا يفعل:** يحذف كل المعاملات المُستوردة من Mock Bank.

**Body:** —

---

## ملاحظات عامة

### نموذج الاستجابة الموحَّد

**نجاح:**
```json
{
  "success": true,
  "message": "نص اختياري",
  "data": { /* الحمولة */ }
}
```

**خطأ:**
```json
{
  "success": false,
  "message": "نص الخطأ",
  "errors": { /* تفاصيل اختيارية */ }
}
```

### HTTP Status Codes
| Code | المعنى |
|---|---|
| 200 | OK |
| 201 | Created |
| 401 | غير مُسجّل دخول (token غير صالح) |
| 403 | لا صلاحية / حساب معطّل |
| 404 | غير موجود |
| 422 | Validation failed |
| 429 | Too Many Requests (cooldown) |

### العملات المدعومة
`SAR` · `JOD` · `USD` · `AED` · `EUR`

### اللغات المدعومة
`ar` · `en` (الـ Backend يُرجع النصوص بناءً على header `Accept-Language`)
