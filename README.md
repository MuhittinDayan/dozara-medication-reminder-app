# Dozara

Flutter ile geliştirilmiş, yapay zeka destekli ilaç takip ve hatırlatıcı uygulaması.

<p align="center">
  <a href="https://flutter.dev"><img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white"></a>
  <a href="https://dart.dev"><img alt="Dart" src="https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white"></a>
  <a href="https://supabase.com"><img alt="Supabase" src="https://img.shields.io/badge/Supabase-Backend-3ECF8E?logo=supabase&logoColor=white"></a>
  <a href="https://firebase.google.com"><img alt="Firebase" src="https://img.shields.io/badge/Firebase-FCM-FFCA28?logo=firebase&logoColor=black"></a>
  <img alt="Platform" src="https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web-lightgrey">
</p>

Dozara, ilaç programlarını, doz geçmişini, aile profillerini ve hatırlatıcıları tek yerde yönetmek için tasarlanmış modern bir Flutter uygulamasıdır. Uygulama yerel veri saklama, opsiyonel Supabase yedekleme, Firebase bildirimleri, Gemini destekli AI asistan, OCR ile ilaç tarama ve PDF raporlama özelliklerini bir araya getirir.

## Öne Çıkan Özellikler

- İlaç, doz, form, tekrar sıklığı, kullanım notu ve tedavi süresi tanımlama
- Günlük, haftalık ve özel aralıklı hatırlatıcı planları
- Yerel bildirimler, Firebase Cloud Messaging ve aile bildirim altyapısı
- Stok takibi, düşük stok uyarıları ve doz geçmişi
- Gemini destekli AI asistan ve OCR tabanlı reçete/ilaç kutusu tarama
- Çoklu profil desteği ile aile üyelerinin ilaç planlarını ayrı yönetme
- Haftalık, aylık ve 3 aylık uyum istatistikleri
- PDF rapor üretimi ve paylaşım desteği
- Hive tabanlı yerel veri saklama ve `flutter_secure_storage` ile güvenli anahtar yönetimi
- Karanlık/aydınlık tema, Türkçe yerelleştirme ve ana ekran widget desteği

## Teknoloji Yığını

| Katman | Teknoloji |
| --- | --- |
| Uygulama | Flutter, Dart |
| Durum yönetimi | flutter_bloc / Cubit |
| Yerel veri | Hive, Hive Flutter |
| Güvenli depolama | flutter_secure_storage, crypto |
| Backend ve yedekleme | Supabase Auth, PostgreSQL, Edge Functions |
| AI ve OCR | Gemini API, Google ML Kit Text Recognition |
| Bildirimler | flutter_local_notifications, Firebase Messaging |
| Raporlama | pdf, printing, share_plus |
| Grafikler | fl_chart |
| Ses | speech_to_text, flutter_tts |
| Widget | home_widget |
| CI/CD | Codemagic |

## Proje Yapısı

```text
lib/
  cubit/                  # Profil ve uygulama durumu
  data/
    backend/              # Supabase/Firebase bağlantı katmanı
    remote/               # Supabase veri kaynağı ve mapper'lar
    repositories/         # Profile, medicine ve dose repository'leri
    sync/                 # Yerel/uzak veri senkronizasyonu
  models/                 # Hive modelleri
  screens/                # Ana ekranlar
  services/               # AI, OCR, bildirim, PDF, widget ve veri servisleri
  theme/                  # Uygulama teması
  utils/                  # Yardımcı hesaplama ve form aracı sınıfları
  widgets/                # Yeniden kullanılabilir UI bileşenleri

supabase/
  migrations/             # Veritabanı şeması ve AI kota tabloları
  functions/gemini-proxy/ # Gemini proxy Edge Function
```

## Kurulum

### Gereksinimler

- Flutter SDK `>=3.0.0 <4.0.0`
- Dart SDK `>=3.0.0`
- Android Studio veya Xcode
- Opsiyonel: Supabase CLI
- Opsiyonel: Firebase projesi ve platform konfigürasyon dosyaları

### Adımlar

```bash
git clone https://github.com/MuhittinDayan/MediTrack.git
cd MediTrack
flutter pub get
```

Proje kök dizininde `.env` dosyası oluşturun:

```env
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_ANON_KEY=your_supabase_anon_key
```

Uygulamayı çalıştırın:

```bash
flutter run
```

## Supabase ve AI Kurulumu

AI asistan ve ilaç tarama özellikleri Gemini API anahtarını istemciye koymadan `supabase/functions/gemini-proxy` üzerinden çalışır.

```bash
supabase login
supabase link --project-ref your-project-ref
supabase db push
supabase secrets set GEMINI_API_KEY=your_gemini_api_key
supabase functions deploy gemini-proxy
```

Edge Function, Supabase oturumunu doğrular ve günlük AI kullanım limitlerini veritabanındaki kota fonksiyonu ile kontrol eder.

## Build

```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS
flutter build ios --release

# Web
flutter build web --release
```

## Test ve Kalite

```bash
flutter analyze
flutter test
```

Projede servis, model, dashboard, profil ve widget davranışları için Flutter testleri bulunur.

## Güvenlik Notları

- İlaç verileri cihazda Hive ile saklanır.
- Hassas anahtarlar `flutter_secure_storage` üzerinden yönetilir.
- Supabase yedekleme opsiyoneldir ve kullanıcı oturumu gerektirir.
- Gemini API anahtarı mobil uygulama içine gömülmez; istekler Edge Function proxy'si üzerinden geçer.
- Firebase Messaging aile bildirimi ve uzaktan bildirim akışları için kullanılır.

## Geliştirme Notları

- `.env` dosyası repoya eklenmemelidir.
- Android için Firebase kullanılıyorsa `android/app/google-services.json` dosyasının proje ortamına uygun olduğundan emin olun.
- iOS için Firebase kullanılıyorsa `ios/Runner/GoogleService-Info.plist` dosyası ilgili Firebase uygulaması ile eşleşmelidir.
- Ana ekran widget kurulumu için `docs/IOS_WIDGET_SETUP.md` dosyasındaki platform notlarını kontrol edin.

## Yol Haritasi

- Yakındaki eczane ve konum tabanlı yardım akışları
- Daha gelişmiş aile paylaşımı ve rol izinleri
- Sağlık verisi entegrasyonları
- Uyum raporlarında daha ayrıntılı trend analizi

---

Dozara, ilaç takibini daha anlaşılır, güvenli ve takip edilebilir hale getirmek için geliştirilmektedir.
