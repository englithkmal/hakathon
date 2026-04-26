# hakathon

تطبيق إدارة مالية شخصية، شغل أول هاكاثون.

## إيش سويت لين الحين

نشيت المشروع بـ Flutter وجهزت الهيكلة كلها على نمط Clean Architecture، الملفات لسى فاضية بس المسارات والتقسيم جاهز عشان أبدأ أكتب فيها على راحتي.

## الـ Stack

- **Flutter** (sdk ^3.8.1)
- **Riverpod** للـ state management (مع `riverpod_generator`)
- **go_router** للتنقل بين الشاشات
- **Dio** للـ APIs
- **freezed** + **json_serializable** للموديلات
- **shared_preferences** + **flutter_secure_storage** للتخزين
- **fl_chart** للرسوم البيانية في الـ Insights
- **intl** للترجمة عربي/إنجليزي

## هيكلة المجلدات

```
lib/
├── main.dart
├── app.dart
└── core/        ← اللي مشترك بين كل الـ features
│   ├── constants/      الألوان، النصوص، المقاسات، الأصول
│   ├── theme/          الثيم وأنماط الخط
│   ├── routes/         go_router والمسارات
│   ├── localization/   الترجمة و provider اللغة
│   ├── utils/          validators / formatters / helpers
│   ├── network/        Dio client و endpoints
│   ├── storage/        local + secure storage
│   ├── errors/         failures و exceptions
│   ├── widgets/        widgets مشتركة (button, text field, dialog…)
│   └── extensions/     على BuildContext / String / num
│
└── features/    ← كل feature لحالها
    ├── onboarding/         اختيار اللغة + تعريف بالتطبيق + الهدف المالي
    ├── auth/               تسجيل دخول / إنشاء حساب / استرجاع كلمة المرور
    ├── home/               الـ Dashboard (الرصيد، المصاريف، الادخار، التنبيهات)
    ├── budget/             إنشاء وتقسيم ومتابعة الميزانية
    ├── transactions/       إضافة/تعديل المصاريف والدخل + سجل العمليات
    ├── savings_goals/      أهداف الادخار + متابعة التقدم + التذكيرات
    ├── insights/           تقارير شهرية + نصائح + تحليل المصاريف
    ├── notifications/      الإشعارات
    └── profile/            البروفايل + العملة + اللغة + الخصوصية
```

كل feature فيها نفس التقسيم:

```
feature/
├── data/
│   ├── models/
│   └── repositories/
└── presentation/
    ├── providers/    ← Riverpod
    ├── screens/
    └── widgets/
```

## كيف تشغّله

```bash
flutter pub get
flutter run
```

ولما يصير في موديلات بـ freezed أو providers بـ riverpod_generator:

```bash
dart run build_runner watch -d
```

## الـ Assets

```
assets/
├── images/
├── icons/
├── fonts/
└── translations/   ← ar.json / en.json
```

## ملاحظات

- الملفات كلها فاضية لسى، أنا بكتب فيها وحدة وحدة وأنا ماشي.
- لو في feature بزيدها بحط نفس البنية (`data/` + `presentation/`) عشان كل شي ينضبط.
