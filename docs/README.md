# توثيق Waffer (وفّر) — نقطة الدخول

للإنتاج: **أربعة ملفات** تغطي الـ API والتطبيق؛ تجنّب تكرار التوثيق خارجها.

| الملف | الغرض |
|--------|--------|
| **[USER_JOURNEY.md](USER_JOURNEY.md)** | **ابدأ من هنا.** رحلة المستخدم الكاملة بالخطوات: من فتح التطبيق حتى تسجيل الخروج، مع endpoint وbody ومثال لكل خطوة. |
| **[API_ENDPOINTS.md](API_ENDPOINTS.md)** | المرجع الكامل لكل المسارات، الحقول، والـ enums. |
| **[MOBILE_INTEGRATION.md](MOBILE_INTEGRATION.md)** | ربط الشاشات بالطلبات، ما يُحسب في Flutter، وقائمة تحقق المتبقي. |
| **[NOTIFICATIONS_API.md](NOTIFICATIONS_API.md)** | التنبيهات، الـ cursor، وFCM. |

## Postman

- `Waffer.postman_collection.json`
- `Waffer.postman_environment.json`

## تطوير محلي

- في `APP_ENV=local` رمز OTP ثابت **`123456`** (انظر `API_ENDPOINTS.md` → Auth).

## استقرار الإنتاج

- ثبّت `APP_URL` و`FCM_ENABLED` والاعتماديات على `.env`؛ لا تلتزم بمسارات توثيق قديمة — أي مرجع خارج الجدول أعلاه أُزيل لتقليل التشتت.
