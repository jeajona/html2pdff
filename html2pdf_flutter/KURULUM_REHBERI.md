# ZIP → PDF Android Uygulaması — Kurulum Rehberi

## Nasıl Çalışır?
- ZIP dosyası seçersin
- İçindeki tüm HTML dosyaları otomatik çıkarılır
- Her HTML → A4 PDF'e dönüştürülür (Türkçe karakter desteğiyle)
- PDF'leri açabilir veya paylaşabilirsin

---

## APK Oluşturmak İçin Gerekenler

| Araç | Versiyon | İndirme |
|------|----------|---------|
| Flutter SDK | 3.16+ | https://docs.flutter.dev/get-started/install |
| Android Studio | 2023.1+ | https://developer.android.com/studio |
| Java JDK | 17 | Android Studio ile gelir |

---

## Adım Adım Kurulum

### 1. Flutter SDK'yı Kur
```bash
# Windows için: flutter.dev'den zip indir, PATH'e ekle
# Mac için:
brew install --cask flutter

# Kurulumu doğrula:
flutter doctor
```

### 2. Android Studio'da SDK Kur
- Android Studio'yu aç
- SDK Manager → Android 14 (API 34) SDK'yı indir
- Android Emulator veya gerçek cihaz bağla

### 3. Projeyi Aç
```bash
# ZIP'i çıkart, klasöre gir:
cd html2pdf_flutter

# Bağımlılıkları yükle:
flutter pub get
```

### 4. APK Derle
```bash
# Debug APK (test için, hemen çalışır):
flutter build apk --debug

# Release APK (dağıtım için):
flutter build apk --release

# APK dosyasının yeri:
# build/app/outputs/flutter-apk/app-release.apk
```

### 5. Telefona Yükle
```bash
# USB ile bağlı telefona direkt yükle:
flutter install

# Ya da APK dosyasını telefona kopyala,
# "Bilinmeyen kaynaklardan yükleme" iznini ver ve kur.
```

---

## Olası Hatalar ve Çözümleri

### `flutter doctor` hataları
```
✗ Android toolchain
```
→ Android Studio'yu kur, `flutter doctor --android-licenses` komutunu çalıştır

### `Gradle build failed`
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter build apk
```

### Türkçe karakterler bozuk çıkıyorsa
- HTML dosyan `<meta charset="UTF-8">` içermeli
- Uygulama otomatik olarak UTF-8 ve Windows-1254 encoding'i dener

### PDF boş çıkıyorsa
- HTML dosyasının içeriği düzgün mi kontrol et
- Çok büyük resimleri olan HTML'ler daha uzun sürebilir

---

## Proje Yapısı
```
html2pdf_flutter/
├── lib/
│   └── main.dart          ← Tüm uygulama kodu burada
├── android/
│   ├── app/
│   │   ├── build.gradle
│   │   └── src/main/
│   │       ├── AndroidManifest.xml
│   │       ├── kotlin/.../MainActivity.kt
│   │       └── res/
│   │           ├── xml/file_paths.xml
│   │           └── values/styles.xml
│   ├── build.gradle
│   ├── settings.gradle
│   └── gradle.properties
└── pubspec.yaml           ← Bağımlılıklar burada
```

---

## Uygulama Özellikleri
- ✅ ZIP'ten çoklu HTML dosyası desteği
- ✅ Türkçe karakter desteği (UTF-8, Windows-1254, ISO-8859-9)
- ✅ A4 sayfa formatı, 1cm kenar boşluğu
- ✅ Tablo, resim, kod bloğu desteği
- ✅ PDF'i aç / paylaş
- ✅ Android 5.0+ (API 21) uyumlu
- ✅ Karanlık tema arayüz
