# Product Overview: Metadata Manager

## 1. Sistem Mimarisi ve Genel Bakış
Metadata Manager, çeşitli medya ve belge formatlarındaki üstverileri (metadata) okuma (extract), temizleme (strip) ve manipüle etme (inject) yeteneklerine sahip modüler bir mobil uygulamadır. Görüntü (JPEG, PNG, WEBP), Belge (PDF, DOCX vb.), Ses (MP3, M4A), Video (MP4, MOV) ve Arşiv (ZIP) dosyaları üzerinde byte seviyesinde (byte-level manipulation) işlem yapar. Uygulama, Flutter (Dart) altyapısı üzerine inşa edilmiş olup, donanım optimizasyonu gerektiren medya işlemleri için Kotlin üzerinden Android native API'leri (JNI/MethodChannels) ile entegre çalışmaktadır.

## 2. Core Engines (Çekirdek Motorlar)
Uygulamanın veri işleme mantığı üç temel motor (engine) üzerine kuruludur: `MetadataDispatcher` (Okuma), `MetadataCleaner` (Temizleme), ve `MetadataInjector` (Manipülasyon). İşlemler, dosya tiplerini algılayan statik sınıflar aracılığıyla delege edilir.

### 2.1. Reader Engine (`readers.dart`)
`MetadataDispatcher` sınıfı, gelen dosyanın uzantısına ve `FileKind` numaralandırmasına (enum) göre ilgili Reader sınıfını tetikler.

*   **Görüntü İşleme (`ImageReader`):** `exif` kütüphanesi kullanılarak dosyanın byte array'i (Uint8List) parse edilir. `EXIF`, `GPS`, ve `Image` etiketleri (tags) TIFF dizin yapısından (IFD0, ExifIFD, GPSIFD) çözümlenir.
*   **Belge İşleme (`PdfReader` & `DocxReader`):**
    *   **PDF:** Dosya byte'ları `latin1` ile decode edilip, Regex (`RegExp`) kuralları ile Document Information Dictionary (`/Info` objesi) taranarak `/Title`, `/Author`, `/CreationDate` gibi anahtarlar çıkartılır. `Hex` formatında kodlanmış alanlar (örn. UTF-16BE veya UTF-16LE) tespit edilip özel fonksiyonlarla (`_hexDecode`) decode edilir.
    *   **DOCX/XLSX:** `archive` paketi ile dosya bir ZIP arşivi olarak decode edilir (`ZipDecoder`). `docProps/core.xml` (Dublin Core metadata) ve `docProps/app.xml` (Uygulama istatistikleri) dosyaları okunup XML tag'leri ayıklanır.
*   **Ses İşleme (`AudioReader`):** Özel bir Dart parser'ı ile MP3 dosyalarının başındaki ID3v2 (v2.2, v2.3, v2.4) frame'leri (örn: `TIT2`, `TPE1`) senkronizasyon güvenli (synchsafe) boyut hesaplamaları yapılarak çözülür. Dosya sonundaki ID3v1 etiketleri (son 128 byte) de taranır. Text encoding (ISO-8859-1, UTF-16, UTF-8) tespiti yapılarak doğru okuma sağlanır.
*   **Video İşleme (`VideoReader`):** `MethodChannel` üzerinden Android native katmanında çalışan `MainActivity.kt`'ye dosya yolu (URI) gönderilir. Android'in native `MediaMetadataRetriever` sınıfı kullanılarak QuickTime/MP4 container içerisindeki `moov` atomlarından (örn: `METADATA_KEY_DURATION`, `METADATA_KEY_LOCATION`) güvenilir donanım tabanlı veri çekimi yapılır.
*   **Arşiv İşleme (`ZipReader`):** Recursive (özyineli) bir mantıkla çalışmaz; ancak içerisindeki ilk 15 dosyayı (20MB'a kadar) belleğe açıp her biri için alt türüne (image, pdf vb.) uygun Reader'ı tetikleyerek genişletilmiş bir analiz ağacı (tree) oluşturur.

### 2.2. Cleaner Engine (`cleaner.dart`)
`MetadataCleaner` motoru, seçilen dosyadaki gizli verileri, dosyanın kendi standardını (RFC/ISO spec) bozmadan siler (sanitization).

*   **JPEG Temizleme (`_stripJpeg`):** JPEG marker'ları (SOI `0xFFD8`'den EOI `0xFFD9`'a kadar) ardışık olarak okunur. `APP1` (EXIF/XMP), `APP2` (ICC), `APP13` (IPTC) ve `COM` marker segmentleri atlanırken (skip), görüntü verisi (`SOS` marker'ı sonrası) ve diğer yapısal marker'lar korunur.
*   **PNG Temizleme (`_stripPng`):** Dosya imzasından (PNG magic number) sonra chunk'lar iteratif olarak okunur. Yalnızca kritik (critical) chunk'lar (`IHDR`, `PLTE`, `IDAT`, `IEND`) ve şeffaflık (`tRNS`) korunur. Geri kalan `tEXt`, `zTXt`, `eXIf`, `tIME` gibi tüm metadata chunk'ları silinir.
*   **Belge Temizleme:**
    *   **PDF:** `latin1` decode edilmiş veri üzerinde, Info dictionary değerleri Regex ile boş `()` parantezlere dönüştürülür. XMP packet alanları (`<?xpacket begin...`) tamamen silinir.
    *   **DOCX:** ZIP arşivi yeniden inşa edilir (rebuild). Mevcut `core.xml` ve `app.xml` dosyaları boş (sadece namespace tanımları olan) standart XML iskeletleri ile değiştirilerek `ZipEncoder` ile tekrar sıkıştırılır.
*   **Medya Temizleme (MP3/MP4):**
    *   **MP3:** ID3v2 header'ının synchsafe boyutu hesaplanarak dosya başından ilgili byte miktarı atılır. Dosya sonundan ID3v1 (128 byte) varlığı kontrol edilip kesilir. Yalnızca MPEG audio frame'leri kalır.
    *   **MP4:** MP4 atom ağacı taranır. `moov` (movie) atomu içine girilerek `udta` (user data) ve `meta` atomları tespit edilir ve dışarıda bırakılarak dosya yeniden yapılandırılır. Atom boyutları (32-bit unsigned integer) yeni yapıya göre güncellenir.
*   **ZIP Temizleme (Recursive Stripping):** Arşiv `ZipDecoder` ile açılır. İçerisindeki her bir dosya tek tek `MetadataCleaner.strip` metodundan geçirilip sanitize edilmiş byte dizileri yeni bir `Archive` objesine eklenir.

### 2.3. Injector Engine (`injector.dart`)
`MetadataInjector` motoru, rastgele sahte (fake) profil verileri (`FakeMetadata`) oluşturarak hedeflenen formatların meta veri alanlarına byte array (veya XML/Regex) düzeyinde ekler (spoofing).

*   **Fake Pool:** Rastgele kameralar (örn. "Nikon Z8"), EXIF değerleri (rasyonel exposure time, f-number), GPS koordinatları, isimler ve ISO 8601 zaman damgaları üreten bir statik veri havuzu mevcuttur.
*   **JPEG Enjeksiyonu (`_injectJpeg`):** Little-endian formatında, statik ofset hesaplamalarıyla tam teşekküllü bir TIFF başlığı ve IFD (Image File Directory) ağacı (IFD0, ExifIFD, GPSIFD) oluşturulur. Rasyonel veri tipleri için pay/payda (numerator/denominator) dönüşümleri yapılarak APP1 segmenti (0xFFE1) baştan yazılıp JPEG SOI marker'ının arkasına enjekte edilir.
*   **PNG Enjeksiyonu (`_injectPng`):** `IHDR` chunk'ından hemen sonra gelmek üzere `tEXt` (Textual data) chunk'ları oluşturulur (Author, Title, vb.). Her chunk için tip ve veri byte'ları kullanılarak CRC32 sağlama toplamı (checksum) hesaplanır ve chunk yapısına eklenir.
*   **PDF ve DOCX Enjeksiyonu:** PDF tarafında Regex ile mevcut Info entry'leri `FakeMetadata` stringleri ile override edilir. DOCX tarafında ise ZIP arşivi içine müdahale edilip `core.xml` (Dublin Core namespace ile) ve `app.xml` elementleri (Uygulama adı, revizyon, kelime/karakter sayıları) sahte verilerle dinamik olarak doldurulur.
*   **MP3 Enjeksiyonu (`_injectMp3`):** ISO-8859-1 veya UTF-8 flag'lerine dikkat edilerek sıfırdan geçerli ID3v2.3 frame'leri (TIT2, TPE1, COMM vb.) oluşturulur. Boyutlar synchsafe formata dönüştürülerek header'a yazılır ve ses byte'larının başına eklenir.
*   **MP4 Enjeksiyonu (`_injectVideo`):** `moov` atomu tespit edilir. İçine QuickTime spesifikasyonlarına uygun şekilde bir `udta` (User Data) atomu inşa edilir (alt string atomları: `©nam`, `©ART`, `©day` vb.). Atom boyutları (Big-Endian) güncellenerek dosya başlığı yeniden düzenlenir.

## 3. Arayüz ve Asenkron Mimari
*   **Kullanıcı Arayüzü (UI):** Seçilen dosyaların türüne uygun dinamik `MetadataSection` (ExpansionTile veya Card yapısında) bileşenleri ile sonuçlar sunulur. İşlemler için iki farklı mod vardır: "Temizle ve Kaydet" veya "Sahte Metadata (Inject) ve Kaydet".
*   **Dosya Yönetimi:** `file_picker` eklentisinin API'leri ile kullanıcıdan okuma erişimi alınır, değiştirilen (Uint8List) dosyalar bellekte (RAM) işlenerek sistem `saveFile` diyaloğu aracılığıyla `_temiz` veya `_sahte` son ekleriyle sisteme yazdırılır.
*   **Senkron/Asenkron Akış:** Byte manipülasyonu yapan algoritmaların tamamı UI iş parçacığını (Main thread) bloklamaması için Dart'ın asenkron `Future` yapısıyla çalışır.

## 4. Platform Bağlılıkları ve Derleme
Android üzerindeki yerel `MediaMetadataRetriever` kullanımı sebebiyle (JNI çağrıları C++ katmanında gerçekleştiğinden) uygulamanın derleme (build) sürecinde APK'nın CPU mimarilerine (armeabi-v7a, arm64-v8a, x86_64) özel ayrıştırılması (`--split-per-abi`) gereklidir. Bu, cihaz uyumsuzluğu (ABI architecture mismatch) kaynaklı yükleme hatalarını önler.
