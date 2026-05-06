# Ilac Hatirlatici

Flutter ile gelistirilmis, cok profilli bir ilac takip ve hatirlatma uygulamasi.

## One Cikan Ozellikler

- Ilac ekleme, detay goruntuleme ve gunluk doz takibi
- Gunluk, haftalik ve aralikli doz planlama
- Stok takibi ve dusuk stok uyarilari
- Gecmis ekranı ve son 30 gun uyum istatistikleri
- PDF rapor olusturma ve paylasma
- Uygulama PIN'i, biyometrik kilit ve cihaz ici sifreli veri saklama
- Coklu profil destegi
- Kamera ile ilac tarama ve AI destekli asistan entegrasyonu

## Teknoloji Yigini

- Flutter
- Hive / Hive Flutter
- flutter_local_notifications
- local_auth
- flutter_secure_storage
- Supabase Edge Functions

## Kurulum

1. Flutter bagimliliklarini kur:

```bash
flutter pub get
```

2. Supabase baglantisini yerelde `.env` ile veya CI ortaminda
   `--dart-define` degerleriyle ayarla:

```env
SUPABASE_URL=https://project-ref.supabase.co
SUPABASE_ANON_KEY=your_anon_key_here
```

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://project-ref.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your_anon_key_here
```

Gemini API anahtari Flutter `.env` dosyasina konmaz. AI ozellikleri
`supabase/functions/gemini-proxy` uzerinden calisir ve `GEMINI_API_KEY`
Supabase secret olarak saklanir.

3. Uygulamayi calistir:

```bash
flutter run
```

## Test ve Kalite

Testleri calistirmak icin:

```bash
flutter test
```

Statik analiz icin:

```bash
flutter analyze
```

## Build

Android APK:

```bash
flutter build apk
```

## Guvenlik Notlari

- Uygulama verileri Hive AES sifreleme ile cihaz uzerinde sifreli tutulur.
- Sifreleme anahtari ve PIN bilgileri `flutter_secure_storage` uzerinden saklanir.
- Kullanici isterse biyometrik dogrulama ve uygulama kilidi etkinlestirilebilir.

## Proje Yapisi

```text
lib/
  models/      Veri modelleri
  screens/     Uygulama ekranlari
  services/    Bildirim, veri, AI, PDF ve guvenlik servisleri
  theme/       Tema tanimlari
  widgets/     Tekrar kullanilan bilesenler
test/          Widget ve servis testleri
```
