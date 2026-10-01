# Metadata Manager: Mobil Cihazlar İçin Çevrimdışı ve Kapsamlı Üstveri Yönetimi ve Gizlilik Uygulaması

## Özet
Günümüzde dijital ayak izimizin en büyük ve en az bilinen bölümünü, oluşturduğumuz ve paylaştığımız dosyaların içerisine gömülü olan "metadata" (üstveri) oluşturmaktadır. Bu çalışma, kullanıcıların dijital gizliliklerini korumalarını sağlamak amacıyla geliştirilen "Metadata Manager" adlı mobil uygulamanın tasarımını, mimarisini, algoritma detaylarını ve literatürdeki diğer çözümlerden ayrışan yönlerini sunmaktadır. Uygulama; resim, video, ses, belge ve arşiv dosyalarındaki gizli verileri, cihazın dışına hiçbir veri sızdırmadan, tamamen çevrimdışı (lokal) olarak okuma, silme ve manipüle etme işlevlerini, son kullanıcı odaklı bir arayüzle sunmaktadır. Bu tez, projenin kavramsal altyapısını, teknik mimarisini ve byte seviyesinde çalışan çekirdek motorlarının (Reader, Cleaner, Injector) implementasyon detaylarını derinlemesine incelemektedir.

---

## 1. Giriş

### 1.1. Metadata Nedir?
En temel tanımıyla metadata, "veri hakkında veri" (data about data) anlamına gelmektedir. Bir dosyayı veya veri kümesini tanımlayan, açıklayan, konumlandıran ve sınıflandıran yapılandırılmış bilgilerdir. Verinin asıl içeriğini barındırmaz; bunun yerine içeriğin bağlamını, kökenini ve özelliklerini tarif eder. Örneğin; bir dijital fotoğrafın kendisi (piksellerden oluşan görüntü) asıl veriyken, o fotoğrafın çekildiği tarih, saat, coğrafi konum (GPS), kullanılan cihazın marka ve modeli, pozlama ayarları ve hatta lens serisine kadar tüm ek bilgiler metadatadır.

Metadata, işlevlerine göre literatürde genellikle üç ana gruba ayrılır:
*   **Tanımlayıcı (Descriptive):** Dosyanın bulunmasını ve tanımlanmasını sağlayan bilgilerdir. Bir kitabın başlığı, yazarı, konusu ve anahtar kelimeleri bu gruba girer.
*   **Yapısal (Structural):** Bileşik objelerin veya veri kümelerinin iç yapısını tanımlayan bilgilerdir. Örneğin, bir PDF dosyasındaki sayfaların sıralanışı veya bir ZIP arşivindeki dosyaların hiyerarşisi yapısal metadatadır.
*   **Yönetimsel ve Teknik (Administrative/Technical):** Bir dosyanın nasıl oluşturulduğu, teknik özellikleri, erişim hakları ve korunması ile ilgili bilgilerdir. Dosya türü, sıkıştırma algoritması, renk uzayı, oluşturulma ve son değiştirilme tarihleri bu kategoridedir.

### 1.2. Metadata'nın Tarihçesi
Metadatanın kavramsal kökenleri, dijital çağdan çok daha eskiye, antik kütüphanelere dayanmaktadır. M.Ö. 3. yüzyılda İskenderiye Kütüphanesi'nde, parşömen rulolarının açılmadan içeriğinin (başlık, yazar, konu) anlaşılabilmesi için kenarlarına eklenen küçük etiketler (`sillyboi`), metadatanın ilk ilkel örnekleri olarak kabul edilir. Bu etiketler, binlerce rulo arasından istenen eserin bulunmasını sağlıyordu.

Dijital dünyada ise "metadata" terimi ilk kez 1968 yılında Philip Bagley tarafından bir makalede kullanılmıştır. Ancak kavramın gelişimi 1960'larda başlamıştır:
- **1960'lar:** Veritabanı sistemlerinin gelişmesiyle, veri şemaları (alan adları, veri türleri) metadatanın temelini oluşturdu.
- **1970'ler:** Gazetecilik ve basın endüstrisi için IPTC (International Press Telecommunications Council) standardı geliştirildi. Bu standart, fotoğraflara kimin çektiği, nerede çekildiği, telif hakkı gibi bilgilerin eklenmesini sağlıyordu.
- **1990'lar:** Dijital fotoğrafçılığın yaygınlaşmasıyla, EXIF (Exchangeable Image File Format) standardı ortaya çıktı. Kameralar artık çektikleri her karenin içine otomatik olarak enstantane, diyafram, ISO gibi teknik detayları ve daha sonra GPS modülleriyle konum bilgisini gömmeye başladı. Adobe, XMP (Extensible Metadata Platform) standardını geliştirerek bu süreci daha esnek ve platformlar arası hale getirdi.
- **2000'ler ve sonrası:** Web 2.0, sosyal medya ve büyük verinin yükselişiyle metadata, "veri madenciliği" ve "yapay zeka" için en değerli kaynaklardan biri haline geldi. Arama motorları, e-ticaret siteleri ve sosyal ağlar, kullanıcı davranışlarını analiz etmek, içerik önermek ve hedefli reklamlar sunmak için yoğun bir şekilde metadatadan faydalanmaktadır.

---

## 2. Dosya Yapıları ve Metadata Depolama Mimarisi

### 2.1. Metadata İçerebilecek Dosya Türleri
Dijital dünyadaki hemen hemen her dosya formatı, kendi standardının izin verdiği ölçüde metadata barındırabilir. Bu proje, özellikle kişisel gizliliği tehdit edebilecek zengin metadata içeren ve günlük hayatta en sık kullanılan dosya türlerine odaklanmıştır:
*   **Resim Dosyaları:** JPEG, PNG, WEBP
*   **Video Dosyaları:** MP4, MOV
*   **Ses Dosyaları:** MP3, M4A
*   **Belge Dosyaları:** PDF, DOCX, XLSX, PPTX
*   **Arşiv Dosyaları:** ZIP, GZ, TAR

### 2.2. Dosya Türlerinin Genel Yapısı: Bit Düzeyinde İnceleme
Bir dosya, disk üzerinde sıralı bir bit dizisi (byte array) olarak saklanır. Her dosya formatı, o dosyanın hangi uygulama tarafından okunacağını belirleyen ve yapısını tanımlayan belirli kurallara uyar. Bu kurallar genellikle dosyanın en başında yer alan "sihirli sayılar" (magic numbers) veya bir başlık (header) ile başlar ve bir bitiş bloğu (footer/EOF) ile sonlanabilir.

Asıl veriyi (örneğin, resmin pikselleri veya sesin ses dalgaları) taşıyan veri bloklarının yanı sıra, format standartları metadata saklamak için özel segmentler, bloklar (chunk'lar) veya atomlar ayırır.
- **JPEG** dosyalarında, `0xFFD8` (SOI - Start of Image) ve `0xFFD9` (EOI - End of Image) marker'ları arasında, `APPn` (Application Marker) olarak bilinen segmentler bulunur. Özellikle `APP1` segmenti, EXIF verilerini barındıran bir TIFF yapısı içerir.
- **PNG** dosyaları, `IHDR` (Image Header), `PLTE` (Palette), `IDAT` (Image Data) gibi "kritik" blokların yanı sıra, `tEXt`, `zTXt`, `iTXt` (metin), `tIME` (zaman) ve `eXIf` (EXIF) gibi metadata içeren "yardımcı" bloklardan oluşur.
- **MP4** gibi video formatları, "atom" adı verilen hiyerarşik bir kutu yapısı kullanır. `moov` (movie) atomu, videonun nasıl oynatılacağına dair tüm bilgileri ve `udta` (user data) veya `meta` gibi alt atomlarda kullanıcı tarafından eklenen başlık, konum gibi verileri saklar.

Bu yapıların en tehlikeli yanı, içerdikleri metadatanın hassasiyetidir. Bir resim dosyasındaki metadata, sadece basit bir tarih bilgisinden ibaret olmayıp, kişinin evinin veya iş yerinin net GPS koordinatlarını, kullandığı telefonun benzersiz modelini, hatta bazen cihazın seri numarasını ifşa edebilir.

### 2.3. Dosyalarda Metadata Konumları ve Çıkarım Yöntemleri (`Reader` Motoru)
"Metadata Manager" uygulaması, dosyaları uzantılarına göre değil, `readers.dart` dosyasında tanımlanan ve her format için özelleştirilmiş sınıflar aracılığıyla bit seviyesinde analiz ederek okur (`MetadataDispatcher` sınıfı).

*   **Resim (JPEG/PNG - `ImageReader`):**
    -   **JPEG:** Dosyanın byte dizisi, `exif` paketi kullanılarak okunur. Paket, dosya içindeki `APP1` segmentini bulur, içerisindeki TIFF başlığını (byte sırası - little/big endian) okur ve IFD (Image File Directory) ağacını (IFD0, ExifIFD, GPSIFD) çözümler. Bu yapıdan enlem, boylam, kamera modeli gibi tüm etiketler (tag) ayıklanır.
    -   **PNG:** Dosya, standart 8 byte'lık PNG imzasından başlayarak blok (chunk) blok okunur. `IHDR`, `IDAT` gibi kritik bloklar atlanırken, `tEXt`, `zTXt`, `iTXt`, `eXIf`, `tIME` gibi metadata içeren tüm yardımcı blokların içeriği okunur ve kullanıcıya sunulur.

*   **Belge (PDF/DOCX - `PdfReader`, `DocxReader`):**
    -   **PDF:** Dosyanın byte dizisi, `latin1` kodlamasıyla bir string'e dönüştürülür. Bu string üzerinde `RegExp` (Regular Expression) kullanılarak `/Info` objesi bulunur. `/Title (...)`, `/Author (...)` gibi anahtar-değer çiftleri aranır. Değerler, parantez içinde normal metin veya `<...>` içinde onaltılık (hexadecimal) formatta olabilir. Hex formatındaki metinler (genellikle UTF-16BE veya UTF-16LE), `_hexDecode` fonksiyonu ile karakter dizisine dönüştürülür.
    -   **DOCX/XLSX/PPTX:** Bu dosyalar aslında birer ZIP arşividir. `archive` paketi kullanılarak bellek üzerinde açılır (`ZipDecoder`). Arşivin içindeki `docProps/core.xml` (Dublin Core metadatası: yazar, başlık, konu) ve `docProps/app.xml` (Uygulama istatistikleri: sayfa sayısı, kelime sayısı, uygulama versiyonu) dosyaları bulunur, içerikleri okunur ve XML etiketleri ayrıştırılarak metadata elde edilir.

*   **Ses (MP3 - `AudioReader`):**
    -   Uygulama, MP3 dosyalarını tamamen Dart dilinde yazılmış bir parser ile işler. İlk olarak dosyanın en başındaki `ID3v2` etiketi aranır. `ID3` başlığı bulunduğunda, versiyon (v2.2, v2.3, v2.4) ve etiket boyutu okunur. Boyut, "synchsafe" formatında (her byte'ın en değerli biti 0'dır) kodlanmış olabilir, bu nedenle doğru şekilde hesaplanır. Ardından, etiket içindeki `TIT2` (Başlık), `TPE1` (Sanatçı), `TALB` (Albüm) gibi çerçeveler (frame'ler) tek tek okunur. Çerçeve içeriğinin metin kodlaması (ISO-8859-1, UTF-16, UTF-8) çerçeve başlığından tespit edilerek doğru şekilde çözümlenir. Son olarak, dosyanın son 128 byte'ı kontrol edilerek `ID3v1` etiketi olup olmadığına bakılır.

*   **Video & Diğer Ses Türleri (MP4/MOV/M4A - `VideoReader`, `_native` metodu):**
    -   Bu formatlar karmaşık atomik yapılar içerdiğinden ve donanım seviyesinde optimizasyonlar gerektirdiğinden, bu işlem doğrudan Flutter/Dart üzerinde yapılmaz. Bunun yerine, Flutter'ın `MethodChannel` mekanizması kullanılır. Dosyanın cihazdaki yolu (path), `com.example.metadata_app/media` adlı kanal üzerinden `MainActivity.kt` dosyasında çalışan Android native katmanına gönderilir.
    -   Kotlin tarafında, Android'in kendi `MediaMetadataRetriever` sınıfı kullanılır. Bu sınıf, işletim sisteminin donanım hızlandırmalı medya kodeklerinden faydalanarak `METADATA_KEY_LOCATION`, `METADATA_KEY_VIDEO_ROTATION`, `METADATA_KEY_BITRATE` gibi birçok teknik metadatayı güvenilir ve hızlı bir şekilde çeker. Sonuçlar bir harita (map) olarak tekrar Dart katmanına geri gönderilir. Bu hibrit yaklaşım, hem platformun gücünden faydalanmayı hem de arayüzün akıcılığını korumayı sağlar.

---

## 3. Metadata ve Bilgi Güvenliği

### 3.1. Metadatanın Gizlilikteki Önemi ve Kötü Niyetli Kullanımı
Metadata, veri organizasyonu ve erişimi için vazgeçilmez olsa da, siber güvenlik ve kişisel gizlilik için devasa bir tehdit oluşturur. Farkında olmadan paylaşılan metadata, kötü niyetli kişiler tarafından şu şekillerde kullanılabilir:
*   **Fiziksel Takip ve Profilleme:** Bir kişinin sosyal medyada "evimden manzara" notuyla paylaştığı bir fotoğrafın EXIF metadatası, o kişinin evinin enlem ve boylamını santim hassasiyetinde ifşa edebilir. Bu verileri toplayan bir saldırgan, kişinin günlük rutinlerini, sık gittiği yerleri ve hatta boş bıraktığı zamanları tespit ederek hırsızlık veya taciz gibi suçlar işleyebilir.
*   **Sosyal Mühendislik ve Oltalama (Phishing):** Bir şirket çalışanının internete yüklediği masum bir PDF veya DOCX belgesinin metadatası, o şirketin kullandığı yazılım versiyonlarını (`Creator`, `Producer`), şirket içi sunucu veya dosya yollarını, çalışanların tam adlarını (`Author`, `LastModifiedBy`) ve hatta şirket adını (`Company`) ortaya çıkarabilir. Bu bilgilerle donatılmış bir hacker, "IT Departmanı: Acil Office Güncellemesi" gibi son derece inandırıcı ve hedefe yönelik oltalama e-postaları hazırlayarak çalışanların parolalarını veya şirket verilerini çalabilir.
*   **İstihbarat ve Gözetim:** Devletler veya büyük şirketler, toplu halde paylaşılan dosyalardan elde ettikleri metadaları analiz ederek toplumsal hareketleri, protestoların organizasyonunu veya belirli grupların iletişim ağlarını haritalandırabilir.

### 3.2. Dijital Adli Bilişim (Forensics) ve Analiz
Madalyonun diğer yüzünde ise metadata, dijital adli bilişim uzmanları için bir suçun veya siber saldırının aydınlatılmasında kritik bir kanıt niteliği taşır.
- Bir dosyanın ne zaman oluşturulduğu (`CreationDate`), en son ne zaman ve kim tarafından değiştirildiği (`ModDate`, `LastModifiedBy`), hangi yazılımla oluşturulduğu (`Creator`) gibi bilgiler, bir olayın zaman çizelgesini çıkarmada kullanılır.
- Bir fotoğrafın orijinal olup olmadığı, üzerinde oynama yapılıp yapılmadığı, EXIF verileri ile fotoğrafın içeriğindeki gölgeler veya ışıklandırma arasındaki tutarsızlıklar analiz edilerek anlaşılabilir.
- Bir şantaj e-postasında gönderilen belgenin metadatasından elde edilen kullanıcı adı, o belgeyi oluşturan kişinin veya bilgisayarın kimliğini tespit etmede ilk ipucu olabilir.
Metadatanın adli bilişimdeki bu gücü, aynı zamanda sıradan bir kullanıcının bilgisi ve izni dışında ne kadar fazla verinin sızdırılabileceğinin de en net kanıtıdır.

---

## 4. Önerilen Çözüm: Metadata Manager Uygulaması

### 4.1. Uygulamanın Temel İşlevleri ve Çekirdek Motorları
"Metadata Manager", kullanıcının gizliliğini korumak için üç temel ve modüler işlevi yerine getiren çekirdek motorlar üzerine inşa edilmiştir:

1.  **Okuma (`MetadataDispatcher` / `readers.dart`):** Yukarıda detaylandırıldığı gibi, dosyaları byte seviyesinde analiz ederek içlerindeki tüm gizli verileri şeffaf bir şekilde listeler.
2.  **Temizleme (`MetadataCleaner` / `cleaner.dart`):** Bu motor, dosyayı "arındırma" (sanitization) görevini üstlenir. Amacı, dosyanın görsel veya işitsel bütünlüğünü bozmadan, yalnızca metadata içeren segmentleri, blokları veya atomları ortadan kaldırmaktır.
    -   **JPEG (`_stripJpeg`):** Dosya `0xFFD8` (SOI) marker'ından itibaren okunur. `APPn` ve `COM` gibi tüm metadata segmentleri atlanırken, `SOF`, `DHT`, `DQT` gibi yapısal segmentler ve `SOS`'dan sonraki asıl görüntü verisi korunarak yeni bir dosya oluşturulur.
    -   **PNG (`_stripPng`):** Sadece `IHDR`, `PLTE`, `IDAT`, `IEND` ve `tRNS` gibi "kritik" bloklar korunur. Diğer tüm yardımcı bloklar atılır.
    -   **MP4 (`_stripVideo`):** `moov` atomunun içi taranır ve `udta` (user data) ile `meta` atomları dışarıda bırakılarak atom ağacı yeniden inşa edilir. Yeni yapıya göre üst atomların boyutları güncellenir.
    -   **DOCX (`_stripOffice`):** ZIP arşivi yeniden oluşturulur. `docProps/core.xml` ve `docProps/app.xml` dosyaları, sadece standart XML başlıklarını içeren boş iskelet dosyalar ile değiştirilir.
3.  **Manipüle Etme (`MetadataInjector` / `injector.dart`):** Bu motor, gizliliği bir adım öteye taşıyarak "sahtecilik" (spoofing) yapar. `_FakePool` sınıfından rastgele ama gerçekçi veriler (örn. "Nikon Z8" kamera, "Istanbul" GPS koordinatları) seçerek, temizlenmiş dosyanın içine sıfırdan geçerli metadata yapıları inşa eder ve enjekte eder.
    -   **JPEG (`_injectJpeg`):** Little-endian (Intel) byte sırasında, tam teşekküllü bir TIFF başlığı ve IFD ağacı (IFD0, ExifIFD, GPSIFD) sıfırdan oluşturulur. Rasyonel sayılar (diyafram, pozlama) için pay/payda (numerator/denominator) dönüşümleri yapılır ve bu yapı bir `APP1` segmenti içine paketlenerek temiz JPEG verisinin başına eklenir.
    -   **PNG (`_injectPng`):** `IHDR` bloğundan hemen sonra gelmek üzere `tEXt` (Textual data) blokları oluşturulur. Her blok için "Author", "Title" gibi anahtarlar ve sahte veriler kullanılır. Blok bütünlüğünü sağlamak için CRC-32 sağlama toplamı (checksum) hesaplanır ve bloğun sonuna eklenir.
    -   **MP3 (`_injectMp3`):** ISO-8859-1 veya UTF-8 kodlama bayraklarına dikkat edilerek, `TIT2`, `TPE1` gibi ID3v2.3 çerçeveleri sıfırdan oluşturulur. Boyutları synchsafe formata dönüştürülerek bir başlığa yazılır ve bu başlık, ham ses verisinin önüne eklenir.

### 4.2. Uygulamanın Öne Çıkan Özellikleri ve Literatürdeki Farkı
Piyasada bulunan güçlü `ExifTool` gibi komut satırı araçları veya çeşitli online "metadata remover" web siteleri ile kıyaslandığında, "Metadata Manager" uygulaması şu devrimsel yenilikleri sunmaktadır:

#### 4.2.1. Yerel (Çevrimdışı) İşleme ve Mutlak Gizlilik
Online metadata silme servisleri, doğaları gereği kullanıcının en hassas dosyasını kendi sunucularına yüklemesini talep eder. Dosya işlendikten sonra "sildik" deseler bile, o dosyanın ağ trafiği üzerinden izlenmesi, sunucu loglarında indekslenmesi veya kötü niyetli bir sunucu yöneticisi tarafından kopyalanması riski her zaman mevcuttur. **Metadata Manager tamamen lokal çalışır.** Seçilen dosya, cihazın RAM'i üzerinde işlenir, asla internete yüklenmez veya cihaz dışına çıkarılmaz. Bu, "sıfır bilgi" (zero-knowledge) prensibine dayalı mutlak bir gizlilik garantisi sunar.

#### 4.2.2. Kapsamlı ve Özyineli Arşiv (ZIP) İşleme Yeteneği
Diğer birçok aracın aksine, bu uygulama sadece tekil dosyaları değil, ZIP, TAR, GZ gibi arşiv dosyalarını da akıllı bir şekilde işleyebilir. Arşiv dosyasını bellek üzerinde açar, içindeki her bir dosyayı tek tek `MetadataCleaner` veya `MetadataInjector` motorundan geçirir. Her bir iç dosya kendi formatına göre (resim ise resim, belge ise belge olarak) temizlenir/manipüle edilir. Son olarak, bu temizlenmiş dosyalarla yeni bir ZIP arşivi oluşturulur ve kullanıcıya sunulur. Bu özyineli (recursive) temizlik, sektördeki araçlarda nadir bulunan bir özelliktir.

#### 4.2.3. Son Kullanıcı Odaklı Basit ve Anlaşılır Arayüz
`ExifTool` gibi en güçlü araçlar dahi, komut satırı (terminal) bilgisi gerektirir ve bu da onları teknoloji meraklısı olmayan büyük bir kullanıcı kitlesi için erişilmez kılar. Metadata Manager, "dijital meşru müdafaa" hakkının sadece mühendislere değil, herkese ait olduğu vizyonuyla tasarlanmıştır. Karmaşık işlemler, "Dosya Seç", "Temizle", "Kaydet" gibi üç basit adıma indirgenmiştir.

#### 4.2.4. Mobil Ekosistem Odaklılık ve Taşınabilirlik
Günümüzde dijital içeriklerin büyük çoğunluğu akıllı telefonlar ile üretilip yine bu cihazlar üzerinden paylaşılmaktadır. Buna rağmen, kapsamlı metadata araçları hala büyük ölçüde masaüstü platformlara odaklanmıştır. Bu proje, bu boşluğu doldurarak, bir masaüstü bilgisayara ihtiyaç duymadan, herkesin, her yerde, anında paylaşımdan bir saniye önce dosyasının gizliliğini güvence altına almasını sağlar.

#### 4.2.5. Hibrit Mimari ve Platform Optimizasyonu
Sektördeki birçok popüler araç (özellikle `ExifTool` gibi Perl ile yazılmış olanlar), mobil platformların ARM tabanlı işlemci mimarilerinde verimsiz çalışabilir veya hiç derlenemeyebilir. Metadata Manager ise modern bir hibrit mimari kullanır:
- Arayüz ve genel mantık, platformlar arası çalışan **Flutter (Dart)** ile yazılmıştır. Dart'ın asenkron (`Future`) yapısı, yoğun byte manipülasyonu işlemlerinin arayüzü kilitlemesini (UI blocking) engeller.
- Video gibi donanım-yoğun işlemler ise **Kotlin** ile yazılarak ve `MethodChannel` üzerinden çağrılarak, doğrudan Android'in native medya API'lerinin ve donanım hızlandırmasının gücünden faydalanır. Bu, uygulamanın `armeabi-v7a`, `arm64-v8a` gibi farklı CPU mimarilerinde (`--split-per-abi` derleme seçeneği ile) en yüksek performansta çalışmasını garanti eder. Bu yaklaşım, platformun en iyi yönlerini birleştiren, sektörde benzeri az olan bir çözümdür.

---

## 5. Sonuç
"Metadata Manager", dijital çağın en büyük ve en görünmez tehditlerinden biri olan kontrolsüz üstveri sızıntılarına karşı, sıradan kullanıcının eline güçlü, taşınabilir ve anlaşılır bir savunma aracı vermektedir. Tamamen çevrimdışı çalışmasıyla sağladığı mutlak gizlilik, sahte veri enjekte etme (`spoofing`) gibi proaktif savunma yeteneği, karmaşık arşivleri işleyebilmesi ve mobil platformdaki kritik bir boşluğu doldurmasıyla, hem akademik literatüre hem de pratik bilgi güvenliği alanına önemli bir katkı sunmaktadır. Bu proje, dijital okuryazarlığın ötesinde, her bireyin kendi verisi üzerinde tam kontrol sahibi olması gerektiği felsefesini somutlaştıran bir adımdır.
