# Binance Spot Pro

منصة تحليل وتداول احترافية لـ **Binance Spot فقط**، تعمل بالكامل من داخل تطبيق Android — بدون أي Backend Server، بدون VPS، بدون أي خادم خارجي. كل التحليل والمؤشرات والـ SMC والإشارات والتنبيهات تُحسب محلياً على الجهاز، والاتصال الوحيد هو بين التطبيق وBinance API/WebSocket مباشرة.

> ⚠️ **قبل أي شيء آخر**: هذا المشروع كُتب بالكامل خارج بيئة Flutter SDK حقيقية (لا يوجد وصول لـ `pub.dev` في بيئة الكتابة)، لذلك **لم يتم تشغيل `flutter pub get` أو `flutter build` فعلياً على هذا الكود**. الكود مكتوب ومُراجَع بعناية، لكن يجب عليك تشغيل الأوامر أدناه على جهازك والتحقق من نجاح البناء، وإصلاح أي خطأ توافق إصدارات قد يظهر (خصوصاً في `flutter_foreground_task` الحساس لإصدار الحزمة — راجع التعليق في أعلى `lib/core/background/background_monitoring_service.dart`).

---

## 1. إعداد المشروع (خطوة ضرورية قبل أول تشغيل)

الكود المُسلَّم يحتوي على **كل** ملفات Dart/Flutter (`lib/`, `pubspec.yaml`, `test/`) لكن **لا يحتوي على مشروع Android الأصلي الكامل** (ملفات Gradle wrapper، إلخ) لأن هذه الملفات تُولَّد تلقائياً ولا تُكتب يدوياً بأمان. لذلك أول خطوة:

```bash
cd binance_spot_pro

# 1. يولّد مجلدي android/ و ios/ الكاملين مع كل ملفات Gradle
flutter create . --platforms=android --org com.yourcompany --project-name binance_spot_pro

# 2. استبدل AndroidManifest.xml المولَّد تلقائياً بالنسخة الجاهزة
#    (تحتوي كل الصلاحيات المطلوبة، موثّقة سطراً بسطر)
cp android_overlay/AndroidManifest.xml android/app/src/main/AndroidManifest.xml

# 3. ثبّت الحزم
flutter pub get

# 4. ولّد كود Drift (قاعدة البيانات) — ضروري قبل أول build
dart run build_runner build --delete-conflicting-outputs
```

بعد هذه الخطوات المشروع جاهز للتشغيل الطبيعي:

```bash
flutter run
```

---

## 2. طريقة وضع Binance API Key

1. من القائمة الجانبية (☰) → **Settings** → **Binance API** (أو من Portfolio → أيقونة الحساب).
2. أدخل **API Key** و **API Secret** الخاصين بحسابك على Binance.
3. اضغط **Connect** — يتم تشفير المفتاحين فوراً عبر **Android Keystore** (`flutter_secure_storage`)، ولا يُكتبان أبداً في قاعدة البيانات أو الـ Logs أو الكود.
4. التطبيق يفحص صلاحيات المفتاح تلقائياً عبر Binance API:
   - إذا كانت صلاحية التداول **غير مفعّلة** على المفتاح → يظهر "Trading Disabled".
   - إذا كانت **مفعّلة** → يظهر تحذير واضح بأن هذا المفتاح يمكنه تنفيذ صفقات حقيقية.
5. لفصل الحساب: نفس الشاشة → **Disconnect** (يطلب تأكيداً صريحاً لأن الحذف نهائي).

**نصيحة أمان**: أنشئ مفتاح API من Binance بصلاحية **Spot Trading فقط** (بدون Withdrawals)، وقيّده بـ IP جهازك إن أمكن.

---

## 3. طريقة تشغيل Alerts

1. القائمة الجانبية → **Alerts**.
2. اضغط **+** لإنشاء تنبيه: اختر الرمز، نوع التنبيه (من 14 نوعاً: Price, RSI, EMA Cross, MACD Cross, Volume Spike, Breakout, Support/Resistance Break, BOS, CHoCH, FVG, SMC Signal, BUY Signal, Score Threshold)، والشرط (Operator + Value للأنواع الرقمية).
3. فعّل **Repeating** إذا أردت أن يبقى التنبيه نشطاً بعد إطلاقه (بدلاً من إيقافه تلقائياً كـ one-shot).
4. التنبيهات تُفحص:
   - يدوياً عند فتح شاشة Alerts (pull-to-refresh).
   - تلقائياً وبشكل دوري إذا فعّلت **Background Monitoring** (القسم التالي).
5. سجل كل تنبيه أُطلق متاح من أيقونة 🕐 (History) أعلى الشاشة.

---

## 4. طريقة تشغيل Background Monitoring

1. من شاشة **Alerts**، فعّل مفتاح **Background Monitoring: OFF/ON** في أعلى الشاشة (أو من Settings → General لاحقاً).
2. عند التفعيل الأول سيطلب التطبيق:
   - صلاحية الإشعارات (Android 13+).
   - استثناء من تحسين البطارية (Battery Optimization) — ضروري لمنع Android من إيقاف الخدمة.
3. يبدأ **Foreground Service** حقيقي مع إشعار دائم "Monitoring ON"، يقوم بـ:
   - إبقاء اتصال WebSocket حياً وإعادة الاتصال تلقائياً عند الانقطاع.
   - فحص كل التنبيهات النشطة كل 60 ثانية (قابل للتعديل لاحقاً).
   - إطلاق إشعارات محلية عند تحقق أي شرط.
4. لإيقافه: نفس المفتاح → OFF، أو من إعدادات النظام Android مباشرة.
5. **ملاحظة**: `autoRunOnBoot: false` عمداً — بعد إعادة تشغيل الهاتف يجب إعادة تفعيل المراقبة يدوياً، احتراماً لقيود Android الحديثة وعدم استهلاك البطارية بلا إذن صريح متجدد.

---

## 5. طريقة تشغيل Live Spot Trading

**هذه الميزة مُعطّلة تماماً افتراضياً.** خطوات التفعيل:

1. اربط حساب Binance أولاً (القسم 2 أعلاه)، وتأكد من أن المفتاح لديه صلاحية Spot Trading.
2. Settings → **Binance API** → مفتاح **"Enable Live Spot Trading"**.
3. يظهر تأكيد صريح يوضح أن الأوامر ستستخدم أموالاً حقيقية — يجب الموافقة الصريحة.
4. بعد التفعيل، أي أمر (Market/Limit Buy/Sell) من أي مكان في التطبيق **يمر إلزامياً** عبر:
   - نافذة **تأكيد الطلب** (Symbol/Side/Quantity/Price/Estimated Total/Estimated Fee + CONFIRM ORDER).
   - فحص **Risk Management** (Max Trade Amount / Max Position Size / Max Open Orders / Max Daily Risk) من Settings → Risk Management.
   - التحقق من فلاتر Binance الحقيقية (Lot Size / Price Filter / Min Notional) قبل الإرسال.
5. زر **EMERGENCY STOP** (نفس شاشة Risk Management) يوقف أي أمر جديد فوراً بغض النظر عن أي إعداد آخر.

**لا يوجد في الكود أي مسار لفتح صفقة Short أو Margin أو Futures — Spot فقط، دائماً.**

---

## 6. طريقة Build APK

```bash
flutter build apk --release
```

الناتج: `build/app/outputs/flutter-apk/app-release.apk`

للتوقيع بمفتاح إنتاج حقيقي (بدل مفتاح debug):
1. أنشئ `android/key.properties` (لا يُرفع لأي Git — موجود في `.gitignore`).
2. اربطه في `android/app/build.gradle` (`signingConfigs.release`) — هذا الجزء من ملفات Gradle التي يولّدها `flutter create .`؛ اتبع [دليل Flutter الرسمي لتوقيع Android](https://docs.flutter.dev/deployment/android#signing-the-app) بالضبط.

## 7. طريقة Build AAB (لرفعه على Google Play)

```bash
flutter build appbundle --release
```

الناتج: `build/app/outputs/bundle/release/app-release.aab`

(نفس متطلبات التوقيع أعلاه تنطبق هنا أيضاً.)

---

## 8. شرح Architecture مختصر

```
Binance (REST + WebSocket)
        │
        ▼
Market Data Manager  ─── memory cache (fast) ─── SQLite (Drift, offline-friendly)
        │
        ▼
Indicator Engine (18 مؤشراً)  +  SMC Engine (BOS/CHoCH/OB/FVG/Liquidity/Zones)
        │
        ▼
Strategy Engine (RSI+EMA + 6 فلاتر اختيارية)  →  Score System (0-100)
        │
        ▼
Signal Engine (BUY/HOLD/EXIT + Entry/Invalidation/TP1/TP2)
        │
        ├──► Scanner/Screener (Isolate منفصل لفحص عشرات الرموز دفعة واحدة)
        ├──► Alert Engine → Local Notifications (+ Foreground Service للخلفية)
        └──► UI (Home / Markets / Chart / Screener / Signals + كل الشاشات الفرعية)

Trading Engine (منفصل تماماً، بوابات أمان متعددة) ──► Binance Spot Orders API
AI Analysis (منفصل تماماً عن التداول) ──► مزود AI الذي يحدده المستخدم
```

**هيكل المجلدات** (`lib/`):
- `core/` — API client, WebSocket manager, قاعدة البيانات (Drift)، الأمان (Keystore)، الإشعارات، الخدمة الخلفية، الثيم، Providers المشتركة
- `data/models/` + `data/repositories/` — نماذج البيانات وطبقة الوصول لقاعدة البيانات
- `services/` — كل المحركات: `indicator_engine`, `smc_engine`, `strategy_engine`, `signal_engine`, `scanner`, `alert_engine`, `trading_engine`, `market_data`, `ai`
- `features/` — كل شاشة UI، منظمة حسب الميزة (`home`, `markets`, `chart`, `screener`, `signals`, `alerts`, `watchlists`, `portfolio`, `trading`, `settings`, `ai`)
- `test/` — اختبارات تطابق نفس هيكل `lib/`

---

## 9. قائمة Dependencies الرئيسية

| الحزمة | الاستخدام |
|---|---|
| `flutter_riverpod` | إدارة الحالة الرئيسية |
| `provider` | حالة شاشة Chart تحديداً (ChangeNotifier عالي التردد أثناء اللمس) |
| `dio` | REST client لـ Binance وAI provider |
| `web_socket_channel` | WebSocket المباشر مع Binance |
| `drift` + `sqlite3_flutter_libs` | قاعدة البيانات المحلية |
| `flutter_secure_storage` | تخزين API Keys عبر Android Keystore |
| `crypto` | توقيع HMAC-SHA256 لطلبات Binance الموقّعة |
| `flutter_foreground_task` | Background Monitoring (Foreground Service) |
| `flutter_local_notifications` | الإشعارات المحلية |
| `fl_chart` | رسوم بيانية مصغّرة (الشارت الرئيسي مبني يدوياً بـ CustomPainter) |
| `intl` | تنسيق الأرقام والتواريخ |
| `connectivity_plus` | كشف حالة الاتصال (Offline Mode) |

القائمة الكاملة في `pubspec.yaml`.

---

## 10. صلاحيات Android المطلوبة

كلها موثّقة سطراً بسطر داخل `android_overlay/AndroidManifest.xml`:

| الصلاحية | لماذا |
|---|---|
| `INTERNET` | كل اتصالات REST/WebSocket مع Binance |
| `ACCESS_NETWORK_STATE` | كشف حالة الاتصال (Offline Mode) |
| `POST_NOTIFICATIONS` | إشعارات Alerts وBackground Monitoring |
| `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_DATA_SYNC` | خدمة Background Monitoring |
| `RECEIVE_BOOT_COMPLETED` | استئناف المراقبة بعد إعادة التشغيل **فقط** إذا كانت مفعّلة مسبقاً (لا تشغيل تلقائي بلا إذن) |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | منع Android من إيقاف الخدمة الخلفية، يُطلب بسياق واضح فقط عند تفعيل Monitoring |

**لا توجد أي صلاحية أخرى** — لا وصول للكاميرا، لا جهات الاتصال، لا الموقع الجغرافي.

---

## ملاحظات أمان نهائية

- لا يوجد Backend/Server في أي مكان — كل شيء REST/WebSocket مباشر إلى `api.binance.com` / `stream.binance.com`.
- API Keys: Android Keystore فقط، أبداً في SQLite أو الكود أو الـ Logs (راجع `core/utils/safe_logger.dart` للتحقق من آلية إخفاء الأسرار).
- Live Trading: OFF افتراضياً، تأكيد إلزامي قبل كل أمر، Emergency Stop متاح دائماً.
- Spot فقط: لا Margin، لا Futures، لا Leverage، لا Short — هذا مطبّق على مستوى الكود (`OrderSide` = buy/sell فقط) وليس مجرد واجهة.

---

## تشغيل الاختبارات

```bash
flutter test
```

تغطي الاختبارات: RSI, EMA/SMA/WMA, MACD, Bollinger Bands, ATR, SMC (Swing Points, BOS/CHoCH, FVG)، Strategy Evaluation، Score System، Signal Engine، Setup Detector (Scanner)، Alert Evaluator، Order Validator، Risk Manager، Entry/SL/TP Calculator، AI Context Builder، Chart Transform، Drawing Tools، وHeikin Ashi.
