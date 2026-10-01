### 🛡️ Metadata Reader (Manager)

Flutter (Dart) ve Android Native (Kotlin) kullanılarak geliştirilmiş; medya ve belge dosyalarındaki üstverileri (metadata) cihaz üzerinde okuyan, tamamen temizleyen (sanitization) ve sahte verilerle manipüle edebilen (spoofing) gelişmiş bir dijital gizlilik uygulaması.

Bu proje, Osmaniye Korkut Ata Üniversitesi Bilgisayar Mühendisliği Bölümü lisans bitirme tezi olarak geliştirilmiştir.

### ✨ Temel Özellikler

Uygulamanın mimarisi üç temel "Çekirdek Motor" (Core Engine) üzerine kuruludur:

- 🔍 Okuma (Reader Engine): Dosya formatlarının binary (byte) yapısını analiz ederek EXIF, ID3, QuickTime atomları ve Dublin Core XML verilerini ayrıştırır.

- 🧹 Temizleme (Cleaner Engine): Dosyanın standart yapısını (RFC/ISO spec) bozmadan, gömülü hassas verileri (GPS, yazar, cihaz modeli) RAM üzerinde kalıcı olarak siler.

- 💉 Enjeksiyon ve Manipülasyon (Injector Engine): Mevcut araçların aksine sadece silmekle kalmaz; aktif bir anti-forensics yöntemi olarak dosyalara rastgele, tutarlı görünen sahte metadata (spoofing) enjekte eder.

- 🔒 %100 Yerel İşleme: Hiçbir internet bağlantısı veya uzak sunucu gerektirmez. Tüm işlemler (byte-level manipulation) geçici diske yazılmadan doğrudan RAM üzerinde gerçekleştirilir, böylece maksimum gizlilik sağlanır.

### 📁 Desteklenen Dosya Formatları

Özel geliştirilmiş binary parser'lar ile harici kütüphane bağımlılığı en aza indirilmiştir:

- Görüntü: JPEG (APP segment okuma/yazma), PNG (Chunk manipülasyonu), WEBP

- Belge: PDF (Info Dictionary regex analizi), DOCX / XLSX / PPTX (OOXML, docProps XML yapılandırması)

- Ses: MP3 (ID3v1 ve ID3v2.x synchsafe boyut hesaplamaları)

- Video: MP4 / MOV (Android native MediaMetadataRetriever ve QuickTime atom ağacı manipülasyonu)

- Arşiv: ZIP (Özyineli - recursive - olarak arşiv içindeki dosyaları belleğe açıp işleme ve yeniden paketleme)

### 🛠️ Kullanılan Teknolojiler

- Mobil Framework: Flutter (Dart)

- Native Katman: Kotlin (Android JNI/MethodChannels entegrasyonu)

- Dosya Yönetimi: file_picker, archive paketi

- Görüntü Ayrıştırma: exif (sadece tag okuma için, manipülasyonlar Pure Dart ile yazılmıştır)

### 🚀 Kurulum ve Derleme (Build)

Projeyi yerel bilgisayarınızda çalıştırmak veya APK çıktısı almak için aşağıdaki adımları izleyin:

- Depoyu klonlayın ve klasöre girin:

git clone https://github.com/KULLANICI_ADIN/MetadataReader.git
cd MetadataReader


- Bağımlılıkları yükleyin:

flutter pub get


Önemli: Uygulama, Android Native (C++) medya kütüphanelerini kullandığı için APK oluştururken CPU mimarilerine göre ayrıştırma yapılmalıdır. Bu, ABI (Application Binary Interface) uyumsuzluklarını önler:

flutter build apk --split-per-abi


- Uygulamayı cihazda/emülatörde başlatın:

flutter run


👨‍💻 Geliştirici

Bu proje Ceren Özdemir tarafından, Dr. Öğr. Üyesi Muhammet Talha KAKIZ danışmanlığında geliştirilmiştir.