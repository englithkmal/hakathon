# رحلة المستخدم الكاملة — Waffer API

> توثيق سرديّ مرتب حسب ما يحدث فعلياً من لحظة فتح التطبيق وحتى تسجيل الخروج. كل خطوة تحتوي: **متى تحدث**، **الـ endpoint**، **الـ body**، **مثال request/response**.
>
> للمرجع الكامل بكل المسارات والحقول راجع [`API_ENDPOINTS.md`](API_ENDPOINTS.md).

**Base URL تطوير:** `http://192.168.x.x:8000/api/v1`
**Auth:** `Authorization: Bearer {token}` لكل endpoint محمي 🔒.
**Headers موحّدة:**
```
Content-Type: application/json
Accept: application/json
Accept-Language: ar | en
```

---

## القاعدة الذهبية: الفترة الموحّدة (Active Period)

كل ما يتعلق بـ Dashboard / Budget / Insights / Monthly Summaries يستخدم **مصدراً واحداً** للفترة (`PeriodResolver`). لا تحسب الفترة محلياً في Flutter.

**أولوية القرار في السيرفر:**
1. `?month=&year=` معاً → فترة صريحة.
2. `?period_start=YYYY-MM-DD` → يُشتق منها.
3. آخر ميزانية `active` للمستخدم → ينتقل لشهرها تلقائياً.
4. شهر السيرفر الحالي.

كل رد متأثر بالفترة يحوي `meta.period` (أو `data.period` في الداشبورد):
```json
{ "month": 5, "year": 2026, "period_start": "2026-05-01", "period_end": "2026-05-31", "source": "latest_budget", "budget_id": 27 }
```

**العقد على Flutter:** نادِ `GET /period` مرة على cold-start، خزّن `SelectedPeriod`، ثم مرّر نفس `month`/`year` لكل الشاشات. لا تُرسل قيم محسوبة محلياً.

---

# المرحلة 0 — قبل الدخول (ضيف)

## 0.1 — تسجيل الجهاز كضيف (لاستقبال إشعارات عامة)

**متى:** عند فتح التطبيق لأول مرة، بعد قبول إذن الإشعارات وقبل وصول المستخدم لشاشة OTP.

```
POST /devices/register-guest
```

**Body:**
```json
{
  "token": "fGcM_DEVICE_TOKEN_FROM_FIREBASE",
  "platform": "android",
  "locale": "ar",
  "device_name": "Pixel 7",
  "device_model": "Pixel 7",
  "app_version": "1.0.0"
}
```

**Response 200:**
```json
{
  "success": true,
  "message": "تم تسجيل الجهاز لاستقبال الإشعارات العامة",
  "data": {
    "device_token": {
      "id": 22,
      "platform": "android",
      "locale": "ar",
      "is_active": true,
      "last_used_at": "2026-04-30T00:49:33+00:00"
    }
  }
}
```

> الجهاز الضيف يستقبل **النصائح اليومية ورسائل النظام العامة فقط**. تنبيهات المستخدم (ميزانية، أهداف، تقرير شهري) لا تصل إلا بعد ربط الجهاز بحساب في الخطوة 1.

---

## 0.2 — طلب OTP

**متى:** بعد إدخال المستخدم لرقم هاتفه في شاشة الدخول.

```
POST /auth/send-otp
```

**Body:**
```json
{ "phone": "+966512345678" }
```

**Response 200:**
```json
{
  "success": true,
  "message": "تم إرسال رمز التحقق",
  "data": {
    "phone": "+966512345678",
    "is_new_user": true,
    "expires_in_seconds": 300
  }
}
```

> في بيئة التطوير، الرمز يُطبع في `storage/logs/laravel.log` وقد يُعرض كـ `dev_code` في الـ response.

---

# المرحلة 1 — المصادقة

## 1.1 — التحقق من OTP (لمستخدم موجود)

**متى:** بعد إدخال رمز OTP من شاشة Verify. **مهم:** أرسل `device_token` نفسه الذي استُعمل في `register-guest` لربط الجهاز بالحساب.

```
POST /auth/verify-otp
```

**Body:**
```json
{
  "phone": "+966512345678",
  "code": "123456",
  "device_token": "fGcM_DEVICE_TOKEN_FROM_FIREBASE",
  "platform": "android",
  "locale": "ar",
  "device_name": "Pixel 7",
  "app_version": "1.0.0"
}
```

**Response 200:**
```json
{
  "success": true,
  "message": "تم تسجيل الدخول",
  "data": {
    "token": "1|abcdef...",
    "user": {
      "id": 12,
      "phone": "+966512345678",
      "name": "محمد أحمد",
      "currency": "SAR",
      "monthly_income": 8000,
      "language": "ar",
      "is_admin": false
    },
    "is_new_user": false
  }
}
```

**خزّن `token` في Secure Storage** واستخدمه `Authorization: Bearer {token}` في كل طلب لاحق.

---

## 1.2 — تسجيل مستخدم جديد

**متى:** إذا أعاد `send-otp` قيمة `is_new_user: true` و رمز OTP صحيح.

```
POST /auth/register
```

**Body:**
```json
{
  "phone": "+966512345678",
  "code": "123456",
  "name": "محمد أحمد",
  "currency": "SAR",
  "monthly_income": 8000,
  "language": "ar",
  "device_token": "fGcM_DEVICE_TOKEN_FROM_FIREBASE",
  "platform": "android",
  "locale": "ar"
}
```

**Response 201:** نفس شكل `verify-otp` مع `"is_new_user": true`.

---

## 1.3 — Firebase Login (بديل لـ OTP)

**متى:** بدلاً من OTP، إذا اعتمد التطبيق Firebase Phone Auth.

```
POST /auth/firebase
```

**Body:**
```json
{
  "id_token": "eyJhbGciOi...",
  "device_token": "fGcM_DEVICE_TOKEN",
  "platform": "android"
}
```

---

# المرحلة 2 — بعد الدخول مباشرة

## 2.1 — جلب الـ profile

**متى:** فور استلام الـ token، لتأكيد الجلسة وجلب أحدث بيانات المستخدم.

```
GET /auth/me 🔒
```

**Response 200:**
```json
{
  "success": true,
  "data": {
    "id": 12,
    "phone": "+966512345678",
    "name": "محمد أحمد",
    "currency": "SAR",
    "monthly_income": 8000,
    "language": "ar",
    "is_admin": false,
    "is_active": true,
    "created_at": "2026-04-15T10:00:00+00:00"
  }
}
```

---

## 2.2 — تعديل الـ profile (اختياري)

**متى:** من شاشة الإعدادات.

```
PUT /auth/profile 🔒
```

**Body:** أي مجموعة من الحقول:
```json
{
  "name": "محمد أحمد المهدي",
  "monthly_income": 9000,
  "currency": "SAR",
  "language": "ar"
}
```

---

# المرحلة 3 — تحديد الفترة النشطة

## 3.1 — جلب الفترة المركزية

**متى:** على cold-start بعد المصادقة، **قبل** أي طلب للداشبورد أو الميزانية.

```
GET /period 🔒
```

**Query (اختياري):** `?month=5&year=2026` أو `?period_start=2026-05-01`. بدون query → القرار التلقائي.

**Response 200:**
```json
{
  "success": true,
  "data": {
    "period": {
      "month": 5,
      "year": 2026,
      "period_start": "2026-05-01",
      "period_end": "2026-05-31",
      "source": "latest_budget",
      "budget_id": 27
    }
  }
}
```

> اعرض في الـ UI شريطاً مساعداً عند `source == "latest_budget"`: «تعرض شهر مايو لأن لا توجد ميزانية لشهر السيرفر الحالي».

---

# المرحلة 4 — الشاشة الرئيسية (Dashboard)

## 4.1 — تحميل الداشبورد

**متى:** بعد جلب `period`. مرّر نفس `month`/`year` المحلولة.

```
GET /dashboard?month=5&year=2026 🔒
```

**Response 200 (مختصر):**
```json
{
  "success": true,
  "data": {
    "currency": "SAR",
    "period": { "month": 5, "year": 2026, "period_start": "2026-05-01", "period_end": "2026-05-31", "source": "latest_budget", "budget_id": 27 },
    "has_active_budget": true,
    "summary": {
      "income": 6500,
      "monthly_income": 8000,
      "total_income": 14500,
      "expenses": 2300,
      "savings": 500,
      "balance": 11700
    },
    "budget": {
      "id": 27, "exists": true, "total_amount": 5000, "total_spent": 2300, "remaining": 2700, "progress_percentage": 46,
      "categories": [ { "category": { "id": 1, "name": "طعام" }, "allocated_amount": 1500, "spent_amount": 980, "usage_percentage": 65.33 } ]
    },
    "quick_insights": [
      { "category": { "id": 1, "name": "طعام" }, "total": 980, "count": 12, "percentage": 6.76 }
    ],
    "month_weekly_series": [
      { "week": 1, "label": "1-7 مايو", "income": 0, "expense": 450, "saving": 0 },
      { "week": 2, "label": "8-14 مايو", "income": 6500, "expense": 600, "saving": 500 }
    ],
    "savings_overview": { "total_saved_this_month": 500, "active_goals_count": 2 },
    "monthly_summary": {
      "has_unread_summary": true,
      "latest": {
        "id": 6, "year": 2026, "month": 5,
        "period_start": "2026-05-01", "period_end": "2026-05-31",
        "total_income": 3500, "total_expenses": 1500,
        "total_goal_deposits": 0, "unallocated_savings": 2000, "unallocated_remaining": 2000,
        "budget_adherence_pct": 46.0, "allocation_status": "unallocated",
        "closed_at": "2026-05-01T14:41:28+00:00", "closed_by": "manual",
        "is_alert_unread": true, "alert_id": 240,
        "deeplink": "/monthly-summaries/2026/5",
        "allocate_endpoint": "/api/v1/monthly-summaries/6/allocate"
      },
      "pending_unallocated_count": 1,
      "pending_unallocated_total": 2000
    },
    "recent_transactions": [ /* ... */ ],
    "active_goals": [ /* ... */ ],
    "unread_alerts_count": 3,
    "recent_alerts": [ /* ... */ ],
    "tip_of_the_day": { "id": 5, "title": "💡 سجّل كل معاملة فور حدوثها", "body": "..." }
  }
}
```

> **حقل مهم:** `quick_insights[].percentage` = حصة الفئة من **`summary.total_income`**، ليس من إجمالي المصروف فقط (لتجنب 100% عند فئة واحدة).

### 4.x — قسم `monthly_summary` (الإغلاق الشهري على الـ Dashboard)

> **لا تحتاج polling لشاشة التقارير.** الـ dashboard نفسه يخبر الـ Mobile بكل جديد عن آخر إغلاق شهري.

**متى يُملأ؟** عندما يُنشئ `MonthlyCloser` (تلقائي أو يدوي من الأدمن) snapshot جديد ⇒ السيرفر يُنشئ Alert من نوع `monthly_summary_ready` تلقائياً، ويظهر هنا فوراً عند أول استدعاء `/dashboard`.

**حقول `monthly_summary.latest`:**

| الحقل | الاستخدام في Mobile |
|---|---|
| `id`, `year`, `month` | مفاتيح الـ snapshot |
| `period_start`, `period_end` | لعرض النطاق `1 → 31 مايو` |
| `total_income`, `total_expenses`, `total_goal_deposits` | الأرقام الرئيسية في البطاقة |
| `unallocated_savings` | إجمالي ما وفّره (لو سالب → عرض حرف "تجاوز") |
| `unallocated_remaining` | ما لم يُخصَّص بعد لأهداف. = `unallocated_savings - allocated_amount` |
| `budget_adherence_pct` | يكون `null` لو لم تكن هناك ميزانية. وإلا قيمة % (أحمر إذا > 100) |
| `allocation_status` | `unallocated` / `partially_allocated` / `fully_allocated` |
| `closed_by` | `cron` (تلقائي) / `manual` (من الأدمن) |
| `is_alert_unread` | إذا `true` ⇒ اعرض البطاقة بشكل مميّز (badge، توهج) |
| `alert_id` | ضع PATCH `/alerts/{id}/read` عند فتح البانر |
| `deeplink` | `/monthly-summaries/{year}/{month}` ⇒ يستدعي `GET /monthly-summaries/{year}/{month}` |
| `allocate_endpoint` | يُستدعى مباشرةً بـ `POST` لتخصيص الوفر إلى هدف |

**Aggregates على مستوى المستخدم:**

| الحقل | المعنى |
|---|---|
| `pending_unallocated_count` | كم من الأشهر السابقة فيها وفر مفكوك (`partial` أو `unallocated`) |
| `pending_unallocated_total` | إجمالي الوفر الذي لم يُخصَّص بعد عبر كل الأشهر |

استخدمها لرسم زر **"خصّص وفرك إلى أهداف"** على الداشبورد لو كانت > 0.

**سلوك الـ Mobile الموصى به:**
1. لو `monthly_summary.latest === null` ⇒ لا تعرض القسم.
2. لو `is_alert_unread === true` ⇒ اعرض بطاقة "📊 تقرير {الشهر} جاهز" بشكل مميّز فوق الـ Dashboard.
3. عند ضغط البطاقة ⇒ افتح `deeplink`، استدعِ `GET /monthly-summaries/{year}/{month}` لتفاصيل كاملة (Top categories، الميزانية المغلقة، إلخ)، وحدّث الـ alert كمقروء بـ `PATCH /alerts/{alert_id}/read`.
4. عند ضغط "خصّص الوفر" ⇒ افتح شاشة اختيار هدف، ثم استدعِ `POST {allocate_endpoint}` بـ `{ saving_goal_id, amount, note? }`.

**ثلاث طرق متوازية يصل بها الإغلاق إلى المستخدم** (تكرار مقصود لضمان الوصول):

| القناة | السلوك |
|---|---|
| **Dashboard payload** | متاح فوراً عند فتح التطبيق ⇒ لا يحتاج FCM |
| **`GET /alerts`** | البانر يظهر في صفحة الإشعارات (alert من نوع `monthly_summary_ready`) |
| **FCM push** | إشعار النظام عند الإغلاق (`data.type = monthly_summary_ready`، `data.monthly_summary_id`، `data.year`، `data.month`) |

---

# المرحلة 5 — التحليلات (Insights)

## 5.1 — تحليل المصروفات (Pie chart)

**متى:** عند فتح تبويب «التقارير» أو «وين راحت فلوسك».

```
GET /insights/expense-analysis?month=5&year=2026 🔒
```

**Response 200:**
```json
{
  "success": true,
  "data": {
    "period": { "month": 5, "year": 2026, "period_start": "...", "period_end": "...", "source": "latest_budget", "budget_id": 27 },
    "total_expenses": 2300,
    "by_category": [
      { "category": { "id": 1, "name": "طعام", "icon": "restaurant", "color": "#F59E0B" }, "total": 980, "count": 12, "percentage": 42.61 },
      { "category": { "id": 2, "name": "مواصلات", "icon": "bus", "color": "#3B82F6" }, "total": 520, "count": 7, "percentage": 22.61 }
    ]
  }
}
```

---

## 5.2 — تقرير شهري متعدد الأشهر (Bar chart)

**متى:** لرسم 6 أشهر تاريخية (دخل/مصروف/توفير).

```
GET /insights/monthly-report?months=6 🔒
```

**Response 200:**
```json
{
  "success": true,
  "data": [
    { "year_month": "2025-12", "label": "ديسمبر", "income": 8000, "expenses": 4500, "savings": 3500, "balance": 3500 },
    { "year_month": "2026-01", "label": "يناير", "income": 8000, "expenses": 5200, "savings": 2800, "balance": 6300 }
  ]
}
```

---

# المرحلة 6 — الميزانية الشهرية

## 6.1 — جلب الفئات المتاحة

**متى:** قبل إنشاء ميزانية أو إضافة سطر جديد.

```
GET /categories?type=expense 🔒
```

**Response 200:**
```json
{
  "success": true,
  "data": [
    { "id": 1, "name": "طعام", "name_ar": "طعام", "name_en": "Food", "icon": "restaurant", "color": "#F59E0B", "type": "expense" },
    { "id": 2, "name": "مواصلات", "name_ar": "مواصلات", "name_en": "Transport", "icon": "bus", "color": "#3B82F6", "type": "expense" }
  ]
}
```

---

## 6.2 — إنشاء ميزانية شهرية

**متى:** عند ضغط زر «إنشاء ميزانية» في تبويب الميزانية.

```
POST /budgets 🔒
```

**Body (الأبسط — يستخدم month/year الحاليين):**
```json
{
  "month": 5,
  "year": 2026,
  "total_amount": 5000,
  "currency": "SAR",
  "status": "active",
  "categories": [
    { "category_id": 1, "allocated_amount": 1500, "alert_threshold": 80 },
    { "category_id": 2, "allocated_amount": 800,  "alert_threshold": 75 }
  ]
}
```

**Body (بديل — تاريخ بدء صريح):**
```json
{
  "period_start": "2026-05-01",
  "total_amount": 5000,
  "categories": [ /* ... */ ]
}
```

**Response 201:**
```json
{
  "success": true,
  "message": "تم إنشاء الميزانية بنجاح",
  "data": {
    "id": 27, "month": 5, "year": 2026, "period_start": "2026-05-01", "period_end": "2026-05-31",
    "total_amount": 5000, "total_spent": 0, "remaining": 5000, "status": "active",
    "categories": [ /* with category objects */ ]
  }
}
```

---

## 6.3 — جلب ميزانية الشهر النشط

**متى:** عند فتح تبويب الميزانية. مرّر نفس `month`/`year` من `SelectedPeriod`.

```
GET /budgets/current?month=5&year=2026 🔒
```

**Response 200 (وُجدت):**
```json
{
  "success": true,
  "data": { /* BudgetResource */ },
  "meta": {
    "period": { "month": 5, "year": 2026, "period_start": "...", "period_end": "...", "source": "explicit", "budget_id": 27 },
    "budget_month": 5, "budget_year": 2026
  }
}
```

**Response 200 (لم توجد):**
```json
{
  "success": true,
  "message": "لا توجد ميزانية لهذا الشهر",
  "data": null,
  "meta": { "period": { "month": 5, "year": 2026, ..., "source": "explicit" } }
}
```

> **اقرأ `meta.period.source`:** إن كان `latest_budget` فالشاشة تعرض ميزانية شهر مختلف عمّا طلبه المستخدم — أظهر شريطاً.

---

## 6.4 — تعديل ميزانية موجودة

**متى:** عند تغيير `allocated_amount` لفئة، أو إضافة/حذف فئات.

```
PUT /budgets/27 🔒
```

**Body:** نفس شكل `POST /budgets`، **يحب أن يحوي قائمة `categories[]` كاملة** (الموجودة + الجديدة). الفئات غير المذكورة في القائمة تُحذف.

> `period_start` يُتجاهل في `PUT` — لا يمكن تغيير شهر/سنة ميزانية موجودة.

---

## 6.5 — قائمة الميزانيات (تاريخ المستخدم)

```
GET /budgets?year=2026&status=closed&per_page=12 🔒
```

---

# المرحلة 7 — المعاملات

## 7.1 — تسجيل معاملة جديدة

**متى:** كل مرة يصرف/يستلم/يدخر المستخدم.

```
POST /transactions 🔒
```

**Body — مصروف:**
```json
{
  "amount": 250.50,
  "type": "expense",
  "category_id": 1,
  "description": "بقالة الأسبوع",
  "merchant": "Carrefour",
  "transaction_date": "2026-05-12"
}
```

**Body — دخل:**
```json
{
  "amount": 8000,
  "type": "income",
  "description": "راتب مايو",
  "transaction_date": "2026-05-01"
}
```

**Body — ادخار لهدف:**
```json
{
  "amount": 500,
  "type": "saving",
  "saving_goal_id": 4,
  "description": "إيداع شهري"
}
```

**Body — ادخار عام (بدون هدف):**
```json
{ "amount": 200, "type": "saving" }
```

> **`budget_id` لا تُرسله** — السيرفر يكتبه ويُعيد مزامنته تلقائياً من تاريخ المعاملة.
> **`saving_goal_id` يُتجاهل** إلا إذا `type == "saving"` والهدف ملك للمستخدم.

**Response 201:**
```json
{
  "success": true,
  "message": "تمت إضافة المعاملة",
  "data": {
    "id": 1024, "amount": 250.5, "type": "expense", "currency": "SAR",
    "category": { /* ... */ },
    "budget_id": 27, "saving_goal_id": 0, "monthly_summary_id": 0,
    "transaction_date": "2026-05-12T00:00:00+00:00",
    "created_at": "2026-05-12T08:30:00+00:00"
  }
}
```

---

## 7.2 — قائمة المعاملات مع فلاتر

```
GET /transactions?type=expense&category_id=1&from=2026-05-01&to=2026-05-31&search=بقالة&per_page=20 🔒
```

---

## 7.3 — تعديل / حذف

```
PUT /transactions/1024 🔒        ← نفس body الـ POST
DELETE /transactions/1024 🔒
```

> تغيير `transaction_date` أو `category_id` أو `type` يُعيد ربط المعاملة بالميزانية الصحيحة تلقائياً، ويعيد حساب إجماليات **الفترتين** القديمة والجديدة.

---

# المرحلة 8 — أهداف الادخار

## 8.1 — إنشاء هدف

```
POST /saving-goals 🔒
```

**Body:**
```json
{
  "title": "صندوق الطوارئ",
  "description": "3 أشهر من المصاريف",
  "target_amount": 18000,
  "currency": "SAR",
  "icon": "shield-check",
  "color": "#10B981",
  "start_date": "2026-05-01",
  "deadline": "2026-12-31",
  "status": "active"
}
```

**Response 201:**
```json
{
  "success": true,
  "data": {
    "id": 4, "title": "صندوق الطوارئ", "target_amount": 18000, "current_amount": 0,
    "remaining": 18000, "progress_percentage": 0, "status": "active",
    "start_date": "2026-05-01", "deadline": "2026-12-31",
    "pace": {
      "expected_at_today": 0,
      "monthly_target": 2250,
      "delta": 0,
      "status": "on_track"
    }
  }
}
```

> **`pace.status`** القيم: `ahead` \| `on_track` \| `off_track` \| `inactive` (للـ paused/cancelled/achieved) \| `unscheduled` (بدون تواريخ).

---

## 8.2 — إيداع في هدف

**متى:** زر «أودع» على بطاقة الهدف.

```
POST /saving-goals/4/deposit 🔒
```

**Body:**
```json
{ "amount": 500, "note": "إيداع مايو", "transaction_date": "2026-05-15" }
```

**Response 200:**
```json
{
  "success": true,
  "message": "تمت إضافة المبلغ إلى الهدف",
  "data": {
    "id": 4, "current_amount": 500, "remaining": 17500, "progress_percentage": 2.78,
    "pace": { "monthly_target": 2250, "expected_at_today": 84.62, "delta": 415.38, "status": "ahead" }
  }
}
```

> داخلياً يُنشئ السيرفر `transaction(type=saving, saving_goal_id=4)` — هذه هي source of truth.

---

## 8.3 — قائمة إيداعات الهدف

**متى:** شاشة تفاصيل الهدف، تبويب «الإيداعات».

```
GET /saving-goals/4/deposits?year=2026&month=5 🔒
```

**Response 200:** قائمة معاملات `type=saving` للهدف، مع pagination.

---

## 8.4 — التقدم الشهري للهدف

**متى:** رسم بياني داخل تفاصيل الهدف («كم وفّرت كل شهر؟»).

```
GET /saving-goals/4/monthly-progress 🔒
```

**Response 200:**
```json
{
  "success": true,
  "data": {
    "items": [
      { "year": 2026, "month": 5, "deposited": 500, "transaction_count": 1, "expected": 2250, "delta": -1750, "on_track": false },
      { "year": 2026, "month": 6, "deposited": 2300, "transaction_count": 2, "expected": 2250, "delta": 50, "on_track": true }
    ],
    "meta": { "monthly_target": 2250, "goal_id": 4, "currency": "SAR" }
  }
}
```

---

## 8.5 — تعديل / حذف هدف

```
PUT /saving-goals/4 🔒        ← نفس body الـ POST
DELETE /saving-goals/4 🔒
```

---

# المرحلة 9 — الملخصات الشهرية (إغلاق الشهر)

## 9.1 — قائمة الشهور المغلقة

**متى:** تبويب «الأشهر السابقة».

```
GET /monthly-summaries?year=2026&per_page=12 🔒
```

**Response 200:**
```json
{
  "success": true,
  "data": {
    "items": [
      {
        "id": 7, "year": 2026, "month": 4, "period_start": "2026-04-01", "period_end": "2026-04-30",
        "cash_flow": { "income": 8000, "expenses": 4500, "goal_deposits": 1000, "unallocated_savings": 2500 },
        "allocation": { "status": "partially_allocated", "allocated_amount": 1500, "unallocated_remaining": 1000 },
        "budget": { "budget_id": 25, "total_amount": 5000, "total_spent": 4500, "adherence_pct": 90 },
        "top_categories": [
          { "category_id": 1, "name_ar": "طعام", "name_en": "Food", "total": 1800, "count": 23, "percentage": 40 }
        ],
        "transaction_count": 38, "closed_at": "2026-05-01T02:00:00+00:00", "closed_by": "cron"
      }
    ],
    "meta": { "current_page": 1, "last_page": 1, "total": 1 }
  }
}
```

---

## 9.2 — تفاصيل ملخص شهر محدد

```
GET /monthly-summaries/2026/4 🔒
```

**Response 200:** نفس شكل عنصر `items[]` أعلاه. `data: null` + `meta` إذا الشهر غير مغلق.

---

## 9.3 — تخصيص «وفر الشهر» إلى هدف

**متى:** زر «حوّل الوفر إلى هدف» في شاشة تفاصيل الشهر السابق.

```
POST /monthly-summaries/7/allocate 🔒
```

**Body:**
```json
{
  "goal_id": 4,
  "amount": 1000,
  "note": "تحويل وفر أبريل"
}
```

**Response 201:**
```json
{
  "success": true,
  "message": "تم تخصيص المبلغ من وفر الشهر إلى الهدف",
  "data": {
    "transaction_id": 1099,
    "monthly_summary": { /* السطر بعد التحديث، allocation_status صار fully_allocated */ },
    "saving_goal": { "id": 4, "current_amount": 1500, "target_amount": 18000, "status": "active" }
  }
}
```

> القيود: المبلغ لا يتجاوز `unallocated_remaining`، الهدف ملك للمستخدم، حالته `active` أو `paused`.

---

# المرحلة 10 — الإشعارات (in-app)

## 10.1 — قائمة الإشعارات

**متى:** فتح شاشة الإشعارات.

```
GET /notifications?cursor=&limit=20&type=&unread_only=false 🔒
```

**فلاتر `type`:** `tip`, `goal_milestone`, `goal_off_track`, `budget_alert`, `monthly_summary`, `bank_sync`, `system`, `transaction`.

**Response 200:** قائمة Alert موحّدة.

---

## 10.2 — وضع علامة مقروء

```
POST /notifications/{id}/read 🔒
POST /notifications/read-all 🔒
```

---

## 10.3 — عدّاد غير المقروءة (Badge)

**متى:** كل بضع ثوانٍ في الخلفية أو عند فتح التطبيق.

```
GET /notifications/unread-count 🔒
```

**Response 200:**
```json
{ "success": true, "data": { "unread_count": 3 } }
```

---

## 10.4 — حذف إشعار

```
DELETE /notifications/{id} 🔒
```

---

# المرحلة 11 — النصائح اليومية

```
GET /tips 🔒
GET /tips/{id} 🔒
```

> «نصيحة اليوم» مرفقة بالفعل في `GET /dashboard → tip_of_the_day`. هذه الـ endpoints لقائمة كاملة قابلة للتصفح.

---

# المرحلة 12 — الأجهزة (FCM)

## 12.1 — تسجيل/تحديث جهاز

**متى:** يتم تلقائياً مع `verify-otp`/`register`/`firebase`. لكن يمكن أيضاً صراحة:

```
POST /devices/register 🔒
```

**Body:** نفس `register-guest`. الفرق أن الجهاز مرتبط بحساب.

---

## 12.2 — قائمة أجهزتي

```
GET /devices 🔒
```

---

## 12.3 — إلغاء تسجيل جهاز

**متى:** عند تسجيل الخروج من جهاز محدد، أو لإيقاف push عن جهاز.

```
POST /devices/unregister 🔒
```

**Body:** `{ "token": "..." }`

---

## 12.4 — اختبار push

```
POST /devices/test-push 🔒
```

**Body:** `{ "title": "test", "body": "hello" }`

---

# المرحلة 13 — تسجيل الخروج

## 13.1 — خروج من الجلسة الحالية

```
POST /auth/logout 🔒
```

ينهي توكن البريرir الحالي فقط. الأجهزة الأخرى تبقى داخلة.

---

## 13.2 — خروج من كل الأجهزة

**متى:** المستخدم يطلب «تسجيل الخروج من كل الأجهزة» في الإعدادات.

```
POST /auth/logout-all 🔒
```

ينهي جميع توكنات Sanctum + يعطّل كل DeviceTokens المرتبطة.

---

# الملحق أ — أنواع الإشعارات (FCM data.type)

| `data.type` | المعنى | deeplink |
|--------------|------|----------|
| `monthly_summary_ready` | تقرير الشهر السابق جاهز | `/monthly-summaries/{year}/{month}` |
| `monthly_report` | الـ push الشهري الموجز | `/monthly-summaries/{id}` |
| `goal_off_track` | هدف ادخار متأخر عن الخطة | `/goals/{goal_id}` |
| `goal_progress` / `goal_achieved` (legacy) | إنجاز/تقدم هدف | `/goals/{goal_id}` |
| `budget_alert` (`threshold_50/80/100`, `exceeded`) | تنبيه ميزانية | `/budget/{budget_id}` |
| `tip` | نصيحة اليوم | `/tips/{id}` |
| `system` / `admin_message` | رسائل عامة من الإدارة | — |

---

# الملحق ب — Cron Jobs السيرفر

| Command | متى | ماذا يفعل |
|---------|-----|----------|
| `waffer:close-month` | يوم 1، 02:00 | يُنشئ `monthly_summaries` للشهر السابق ويُغلق ميزانيته. |
| `waffer:monthly-report` | يوم 1، 08:00 | يبعث push بالتقرير الشهري (يقرأ من snapshot). |
| `waffer:goal-pace-check` | يوم 1، 10:00 | يصدر `goal_off_track` للأهداف المتأخرة (deduped شهرياً). |
| `waffer:daily-tip` | يومياً 09:00 | يبعث نصيحة عشوائية. |
| `waffer:goal-deadline-reminders` | يومياً 10:00/10:15 | تذكير قبل deadline بـ 7/1 أيام. |
| `waffer:budget-month-end` | يومياً 19:00 | تذكير ميزانية في آخر 3 أيام من الشهر. |
| `waffer:inactivity-reminder` | يومياً 18:00 | إعادة جذب (5+ أيام بدون نشاط). |
| `transactions:relink` | يدوي | يصلح `budget_id` على المعاملات. |
| `saving-goals:resync` | يدوي | يعيد حساب `current_amount` للأهداف. |

---

# الملحق ج — قائمة تحقق سريعة لـ Flutter

- [ ] استدعاء `POST /devices/register-guest` فور قبول إذن الإشعارات.
- [ ] حقن `device_token` في `verify-otp`/`register`/`firebase` لربط الجهاز بالحساب.
- [ ] استدعاء `GET /period` على cold-start، تخزين في `SelectedPeriod` state.
- [ ] تمرير نفس `month`/`year` لكل من Dashboard و Budgets/current و Insights.
- [ ] قراءة `meta.period.source` لعرض شريط مساعد عند `latest_budget`.
- [ ] **عدم إرسال** `budget_id` في `POST /transactions`.
- [ ] استخدام `pace.status` على Goal لتلوين البطاقة (ahead/on_track/off_track).
- [ ] التحقق من `unallocation_remaining` قبل عرض زر التخصيص في شاشة الشهر السابق.
- [ ] عرض `monthly_summary_ready` و `goal_off_track` كأنواع إشعارات معروفة.
- [ ] استخدام `POST /auth/logout-all` لإنهاء كل الأجهزة عند الحاجة.

---

# الملحق د — الاستجابة الموحّدة

نجاح:
```json
{ "success": true, "message": "...", "data": { } }
```

خطأ:
```json
{ "success": false, "message": "...", "errors": { /* validation */ } }
```

عند 401: `{ "success": false, "message": "Unauthenticated." }` — وقت لتجديد الجلسة أو إعادة المستخدم لشاشة OTP.
