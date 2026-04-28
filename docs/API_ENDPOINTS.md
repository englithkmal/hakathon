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
**ماذا يفعل:** يُرجع حزمة واحدة للشاشة الرئيسية في التطبيق: عملة المستخدم، الشهر المعروض، ملخص **معاملات** الشهر، ميزانية الشهر (إن وُجدت)، عينات من المعاملات والأهداف والتنبيهات، ونصيحة عشوائية.

**Query (اختياري):** `?month=4&year=2026` — لعرض نفس فترة صف الميزانية في لوحة Filament عند المقارنة. بدونها يُستخدم **شهر/سنة «الآن»** حسب `config('app.timezone')`.

**Body:** —

> **مقارنة مع Filament:** جدول «الميزانيات» في الإدارة يعرض **كل المستخدمين**. تأكد أن الصف الذي تقارنه يخص **نفس `user_id`** المرتبط بتوكن التطبيق (`GET /auth/me`). إن كانت حالة الميزانية في اللوحة «مسودة» أو «مغلقة» فلن تظهر في الـ API (`status` = `active` فقط).

> **بدون `null` في الرئيسية (للتطبيق):** استجابة `GET /dashboard` تُرجع دائماً كائناً لـ `budget` (مع `exists: true/false` و`id: 0` عند عدم وجود ميزانية)، وكائناً لـ `last_active_budget`، وكائناً لـ `tip_of_the_day` (أو شكل فارغ بـ `id: 0`). الحقل `message` في الجذر يكون نصاً فارغاً `""` بدلاً من `null`. الحقول النصية في الموارد المرتبطة تُستبدل بقيم افتراضية آمنة بدلاً من `null`.

> **هل الـ API «محدّث»؟** إذا ظهرت في الرد الحقول `last_active_budget`, `quick_insights`, `savings_overview`, `month_transactions_count` فأنت تستدعي **نسخة الكود الحالية**. القيم `null` / `[]` / أصفار تعني: **لمستخدم هذا التوكن** لا توجد ميزانية نشطة لهذا الشهر، ولا معاملات/أهداف في القاعدة — وليس أن الملف التوثيقي وحده تغيّر.

**اللغة في الرد:** أرسل الهيدر `Accept-Language: en` أو `ar` لتغيير الحقول المعتمدة على اللغة (مثل `name` في التصنيفات و`title`/`message` في التنبيهات). حقول `name_ar` و`name_en` تبقى متاحة حيث وُجدت.

#### أسماء الحقول — عربي + English (للمطوّر)

| الحقل `Field` | English (meaning) | العربية |
|----------------|-------------------|---------|
| `currency` | User default currency code | رمز العملة الافتراضي للمستخدم |
| `period.month` / `period.year` | Calendar month/year for aggregates | الشهر/السنة التي حُسبت عليها الأرقام |
| `has_active_budget` | Active budget exists for this exact month/year | توجد ميزانية نشطة لنفس `period` |
| `summary` | Month totals from **transactions** table only | ملخص معاملات الشهر (ليس صف الميزانية في الإدارة) |
| `summary.income` | Sum of `income` transactions this month | مجموع دخل المعاملات |
| `summary.expenses` | Sum of `expense` this month | مجموع المصروف |
| `summary.savings` | Sum of `saving` this month | مجموع الادخار من المعاملات |
| `summary.monthly_income` | Profile field `monthly_income` | الدخل الشهري من الملف الشخصي |
| `summary.balance` | Estimated balance (uses `monthly_income` if no income txs) | رصيد تقديري |
| `budget` | Always an object; real row includes `exists: true`, placeholder uses `exists: false` and `id: 0` | ميزانية الشهر (كائن دائماً) |
| `last_active_budget` | Always an object: `exists`, nested `budget`, `period`, `is_current_period` | غلاف مرجعي لآخر ميزانية نشطة |
| `quick_insights` | Top 3 expense categories this month | أعلى فئات مصروف (مع `name_ar` / `name_en`) |
| `savings_overview` | Aggregate of all active saving goals | ملخص أهداف الادخار النشطة |
| `month_transactions_count` | Count of transactions this month | عدد معاملات الشهر |
| `recent_transactions` | Last 5 transactions | آخر 5 معاملات |
| `active_goals` | Up to 3 active goals (preview) | حتى 3 أهداف للمعاينة |
| `unread_alerts_count` | Unread alerts count | عدد التنبيهات غير المقروءة |
| `recent_alerts` | Up to 5 unread alerts (preview) | آخر تنبيهات غير مقروءة |
| `tip_of_the_day` | Always an object (`id: 0` when no tip) | نصيحة اليوم + `category` |

**Response — مثال كامل (كل الحقول الظاهرة عند وجود بيانات):**

```json
{
  "success": true,
  "message": "",
  "data": {
    "currency": "SAR",
    "period": { "month": 4, "year": 2026 },
    "has_active_budget": true,
    "summary": {
      "income": 0,
      "expenses": 3107,
      "savings": 0,
      "balance": 5393,
      "monthly_income": 8500
    },
    "budget": {
      "id": 12,
      "month": 4,
      "year": 2026,
      "total_income": 8000,
      "total_amount": 8000,
      "total_spent": 3107,
      "remaining": 4893,
      "progress_percentage": 38.84,
      "currency": "SAR",
      "status": "active",
      "notes": "",
      "categories": [
        {
          "id": 101,
          "category": {
            "id": 3,
            "name": "طعام ومشروبات",
            "name_ar": "طعام ومشروبات",
            "name_en": "Food & Drinks",
            "slug": "food-drinks",
            "icon": "heroicon-o-cake",
            "color": "#F59E0B",
            "type": "expense",
            "is_default": true,
            "sort_order": 2
          },
          "allocated_amount": 2000,
          "spent_amount": 850.5,
          "remaining": 1149.5,
          "usage_percentage": 42.53,
          "alert_threshold": 80
        }
      ],
      "created_at": "2026-04-01T10:00:00+00:00",
      "updated_at": "2026-04-28T08:00:00+00:00",
      "exists": true
    },
    "last_active_budget": {
      "exists": false,
      "budget": {
        "exists": false,
        "id": 0,
        "month": 4,
        "year": 2026,
        "total_income": 0,
        "total_amount": 0,
        "total_spent": 0,
        "remaining": 0,
        "progress_percentage": 0,
        "currency": "SAR",
        "status": "none",
        "notes": "",
        "categories": [],
        "created_at": "",
        "updated_at": ""
      },
      "period": { "month": 4, "year": 2026 },
      "is_current_period": true
    },
    "quick_insights": [
      {
        "category": {
          "id": 3,
          "name": "طعام ومشروبات",
          "name_ar": "طعام ومشروبات",
          "name_en": "Food & Drinks",
          "icon": "heroicon-o-cake",
          "color": "#F59E0B"
        },
        "total": 1200.5,
        "count": 8,
        "percentage": 38.6
      }
    ],
    "savings_overview": {
      "count": 2,
      "total_target": 170000,
      "total_current": 82000,
      "progress_percentage": 48.24
    },
    "month_transactions_count": 14,
    "recent_transactions": [
      {
        "id": 500,
        "amount": 45.5,
        "currency": "SAR",
        "type": "expense",
        "description": "قهوة",
        "merchant": "Starbucks",
        "source": "manual",
        "reference": "TXN-ABC",
        "transaction_date": "2026-04-27T14:30:00+00:00",
        "category": {
          "id": 3,
          "name": "طعام ومشروبات",
          "name_ar": "طعام ومشروبات",
          "name_en": "Food & Drinks",
          "slug": "food-drinks",
          "icon": "heroicon-o-cake",
          "color": "#F59E0B",
          "type": "expense",
          "is_default": true,
          "sort_order": 2
        },
        "budget_id": 12,
        "created_at": "2026-04-27T14:31:00+00:00"
      }
    ],
    "active_goals": [
      {
        "id": 2,
        "title": "سيارة جديدة",
        "description": "",
        "icon": "heroicon-o-truck",
        "color": "#10B981",
        "target_amount": 50000,
        "current_amount": 40000,
        "remaining": 10000,
        "progress_percentage": 80,
        "currency": "SAR",
        "start_date": "2026-01-01",
        "deadline": "2026-12-31",
        "status": "active",
        "created_at": "2026-04-01T12:00:00+00:00"
      }
    ],
    "unread_alerts_count": 3,
    "recent_alerts": [
      {
        "id": 58,
        "type": "tip",
        "severity": "info",
        "title": "💡 سجّل كل معاملة فور حدوثها",
        "message": "الذاكرة خادعة — التسجيل الفوري يمنحك صورة دقيقة عن أين يذهب مالك.",
        "payload": { "icon": "heroicon-o-pencil-square", "source": "daily_scheduled", "tip_id": 5 },
        "is_read": false,
        "read_at": "",
        "created_at": "2026-04-28T02:06:47+00:00"
      }
    ],
    "tip_of_the_day": {
      "id": 8,
      "title": "راجع اشتراكاتك الشهرية",
      "title_ar": "راجع اشتراكاتك الشهرية",
      "title_en": "Review your monthly subscriptions",
      "content": "الاشتراكات الصامتة تستنزف بهدوء.",
      "content_ar": "الاشتراكات الصامتة تستنزف بهدوء.",
      "content_en": "Silent subscriptions drain quietly.",
      "icon": "heroicon-o-arrow-path-rounded-square",
      "image": "",
      "audience": "all",
      "category": {
        "id": 0,
        "name": "",
        "name_ar": "",
        "name_en": "",
        "slug": "",
        "icon": "",
        "color": "#94A3B8",
        "type": "expense",
        "is_default": false,
        "sort_order": 0
      }
    }
  }
}
```

**عندما لا توجد ميزانية نشطة للشهر:** `has_active_budget` = `false`، و`budget` يبقى **كائناً** بقيم صفرية و`exists: false` و`status: "none"` (وليس حذف المفتاح). `last_active_budget` يبقى كائنًا أيضاً؛ إن وُجدت ميزانية أقدم نشطة يملأ `exists: true` و`budget` بالبيانات الفعلية.

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
