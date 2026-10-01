import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

import 'cleaner.dart';
import 'models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Fake data havuzu
// ─────────────────────────────────────────────────────────────────────────────

class _FakePool {
  static const cameraMakes = [
    'Apple', 'Samsung', 'Canon', 'Nikon', 'Sony',
    'Huawei', 'Google', 'Xiaomi', 'DJI', 'Leica',
  ];

  static const cameraModels = <String, List<String>>{
    'Apple':   ['iPhone 15 Pro Max', 'iPhone 14 Pro', 'iPhone 13', 'iPhone 12 Pro Max'],
    'Samsung': ['Galaxy S24 Ultra', 'Galaxy S23+', 'Galaxy Note 20 Ultra', 'Galaxy A54 5G'],
    'Canon':   ['EOS R6 Mark II', 'EOS 5D Mark IV', 'PowerShot G7 X III', 'EOS R50'],
    'Nikon':   ['Z8', 'D850', 'Z6 III', 'Coolpix P1000'],
    'Sony':    ['ILCE-7RM5', 'DSC-RX100M7', 'Xperia 5 IV', 'ZV-E1'],
    'Huawei':  ['P60 Pro', 'Mate 50 Pro', 'nova 11 Pro', 'P40 Pro+'],
    'Google':  ['Pixel 8 Pro', 'Pixel 7a', 'Pixel 6 Pro', 'Pixel Fold'],
    'Xiaomi':  ['14 Ultra', '13 Pro', 'Redmi Note 13 Pro+', 'POCO X6 Pro'],
    'DJI':     ['Osmo Action 4', 'Pocket 3', 'Mavic 3 Pro Cine', 'Air 3'],
    'Leica':   ['Q3', 'M11', 'SL3', 'Q2 Monochrom'],
  };

  static const softwareList = [
    'Camera 16.0', 'Camera 15.1.2', 'Lightroom Classic 13.0',
    'Snapseed 2.21', 'VSCO 310', 'Capture One 23.5',
    'Photoshop 25.7', 'Adobe Camera Raw 15.4',
    'Gallery 15.0.2.101', 'Google Photos 6.45',
  ];

  // (şehir, lat, lon)
  static const cities = <(String, double, double)>[
    ('Istanbul',    41.0082,   28.9784),
    ('London',      51.5074,   -0.1278),
    ('New York',    40.7128,  -74.0060),
    ('Tokyo',       35.6762,  139.6503),
    ('Paris',       48.8566,    2.3522),
    ('Sydney',     -33.8688,  151.2093),
    ('Dubai',       25.2048,   55.2708),
    ('Singapore',    1.3521,  103.8198),
    ('Berlin',      52.5200,   13.4050),
    ('Rome',        41.9028,   12.4964),
    ('Amsterdam',   52.3676,    4.9041),
    ('Barcelona',   41.3851,    2.1734),
    ('Moscow',      55.7558,   37.6173),
    ('Beijing',     39.9042,  116.4074),
    ('Mumbai',      19.0760,   72.8777),
    ('Cairo',       30.0444,   31.2357),
    ('Toronto',     43.6532,  -79.3832),
    ('Los Angeles', 34.0522, -118.2437),
    ('São Paulo',  -23.5505,  -46.6333),
    ('Jakarta',     -6.2088,  106.8456),
  ];

  static const firstNames = [
    'James', 'Emma', 'Oliver', 'Sophia', 'William', 'Ava',
    'Benjamin', 'Isabella', 'Lucas', 'Mia', 'Henry', 'Charlotte',
    'Mustafa', 'Zeynep', 'Ahmet', 'Fatima', 'Mehmet', 'Ayşe',
    'Daniel', 'Elena', 'Marco', 'Yuki', 'Carlos', 'Priya',
  ];

  static const lastNames = [
    'Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia',
    'Miller', 'Davis', 'Wilson', 'Martinez', 'Anderson', 'Taylor',
    'Yılmaz', 'Kaya', 'Demir', 'Şahin', 'Çelik', 'Arslan',
    'Müller', 'Rossi', 'Tanaka', 'Patel', 'Santos', 'Nguyen',
  ];

  static const companies = [
    'Acme Corporation', 'Global Dynamics', 'Stark Industries',
    'Wayne Enterprises', 'Umbrella Corp', 'Cyberdyne Systems',
    'Weyland Industries', 'Initech', 'Hooli Ltd', 'Virtucon',
    'Pied Piper Inc', 'Veridian Dynamics', 'Soylent Corp',
  ];

  static const docTitles = [
    'Annual Report 2024', 'Q3 Financial Summary', 'Project Proposal Draft',
    'Technical Specification v2', 'Meeting Minutes – March 2024',
    'Strategic Plan 2024–2026', 'Product Roadmap Q2', 'Research Paper',
    'User Manual v3.1', 'Contract Agreement', 'Presentation Draft',
  ];

  static const docSubjects = [
    'Finance', 'Technology', 'Marketing', 'Research & Development',
    'Human Resources', 'Operations', 'Legal Affairs', 'Corporate Strategy',
  ];

  static const docKeywords = [
    'confidential, internal, 2024',
    'report, analysis, quarterly',
    'draft, review, pending approval',
    'technical, documentation, api',
    'presentation, slides, corporate',
    'finance, budget, forecast',
  ];

  static const songTitles = [
    'Midnight Dreams', 'Broken Roads', 'Falling Stars', 'Neon Lights',
    'Ocean Waves', 'Silent Storm', 'Golden Hour', 'Last Dance',
    'Electric Feel', 'Paper Planes', 'Summer Haze', 'Winter Song',
    'City Lights', 'Desert Rain', 'Purple Sunset', 'Morning Dew',
    'Echoes', 'Cascade', 'Fragments', 'Horizon',
  ];

  static const artistNames = [
    'Luna Eclipse', 'The Midnight', 'Crystal Waves', 'Nova Sound',
    'Echo Valley', 'Static Radio', 'Prism Light', 'Apex Theory',
    'Silver Lining', 'Hollow Moon', 'Bright Futures', 'Dark Matter',
    'Velvet Sky', 'Neon Atlas', 'Amber Run', 'Glass Animals',
  ];

  static const albumNames = [
    'Dreamscape', 'Neon Horizon', 'Beyond the Veil', 'Electric Youth',
    'Synthetic Soul', 'Digital Love', 'Analog Hearts', 'Chrome Dreams',
    'Signal & Noise', 'Quantum Leap', 'Axiom', 'Reverie',
    'Ultraviolet', 'Parallax', 'Entropy', 'Cascade',
  ];

  static const genres = [
    'Pop', 'Rock', 'Electronic', 'Jazz', 'Classical', 'Hip-Hop',
    'R&B', 'Country', 'Metal', 'Indie', 'Folk', 'Ambient',
    'Techno', 'House', 'Reggae', 'Soul',
  ];

  static const isoValues   = [50, 100, 200, 400, 800, 1600, 3200, 6400];
  // (pay, payda) → 1/8000 ... 1/1
  static const exposures   = [
    (1, 8000), (1, 4000), (1, 2000), (1, 1000), (1, 500),
    (1, 250),  (1, 125),  (1, 60),   (1, 30),   (1, 15),
    (1, 8),    (1, 4),    (1, 2),    (1, 1),
  ];
  // f/1.4 … f/16
  static const fNumbers = [
    (14, 10), (18, 10), (20, 10), (22, 10), (28, 10),
    (35, 10), (40, 10), (56, 10), (80, 10), (110, 10), (160, 10),
  ];
  static const focalLengths = [12, 16, 20, 24, 28, 35, 50, 70, 85, 100, 135, 200];
  static const altitudes    = [0.0, 12.5, 25.0, 45.3, 98.7, 250.0, 512.0, 876.5, 1200.0];
}

// ─────────────────────────────────────────────────────────────────────────────
// FakeMetadata — üretilen sahte veri seti
// ─────────────────────────────────────────────────────────────────────────────

class FakeMetadata {
  // Kamera
  final String cameraMake;
  final String cameraModel;
  final String software;
  final String artist;
  // Tarih (farklı formatlarda)
  final String dateTimeExif;    // "YYYY:MM:DD HH:MM:SS"
  final String dateTimeIso;     // "YYYY-MM-DDTHH:MM:SSZ"
  final String dateTimePdf;     // "D:YYYYMMDDHHMMSS+00'00'"
  final String dateTimeDisplay; // "DD.MM.YYYY HH:MM"
  final String yearStr;
  // Çekim ayarları
  final int iso;
  final int exposureNum, exposureDen;
  final int fNumberNum, fNumberDen;
  final int focalLengthMm;
  // GPS
  final double latitude, longitude, altitude;
  final String cityName;
  // Belge
  final String title, docAuthor, subject, keywords, company;
  // Ses
  final String songTitle, songArtist, songAlbum, songYear, songGenre, songTrack;

  const FakeMetadata({
    required this.cameraMake,
    required this.cameraModel,
    required this.software,
    required this.artist,
    required this.dateTimeExif,
    required this.dateTimeIso,
    required this.dateTimePdf,
    required this.dateTimeDisplay,
    required this.yearStr,
    required this.iso,
    required this.exposureNum,
    required this.exposureDen,
    required this.fNumberNum,
    required this.fNumberDen,
    required this.focalLengthMm,
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.cityName,
    required this.title,
    required this.docAuthor,
    required this.subject,
    required this.keywords,
    required this.company,
    required this.songTitle,
    required this.songArtist,
    required this.songAlbum,
    required this.songYear,
    required this.songGenre,
    required this.songTrack,
  });

  static FakeMetadata generate() {
    final rng = Random();
    T pick<T>(List<T> list) => list[rng.nextInt(list.length)];

    final make   = pick(_FakePool.cameraMakes);
    final model  = pick(_FakePool.cameraModels[make]!);
    final sw     = pick(_FakePool.softwareList);
    final fn     = pick(_FakePool.firstNames);
    final ln     = pick(_FakePool.lastNames);
    final name   = '$fn $ln';

    final year  = 2019 + rng.nextInt(6);
    final month = 1 + rng.nextInt(12);
    final day   = 1 + rng.nextInt(28);
    final hour  = rng.nextInt(24);
    final min   = rng.nextInt(60);
    final sec   = rng.nextInt(60);
    final y  = '$year';
    final mo = month.toString().padLeft(2, '0');
    final d  = day.toString().padLeft(2, '0');
    final h  = hour.toString().padLeft(2, '0');
    final mi = min.toString().padLeft(2, '0');
    final s  = sec.toString().padLeft(2, '0');

    final city  = pick(_FakePool.cities);
    final lat   = city.$2 + (rng.nextDouble() - 0.5) * 0.1;
    final lon   = city.$3 + (rng.nextDouble() - 0.5) * 0.1;
    final alt   = pick(_FakePool.altitudes);

    final iso  = pick(_FakePool.isoValues);
    final exp  = pick(_FakePool.exposures);
    final fnum = pick(_FakePool.fNumbers);
    final foc  = pick(_FakePool.focalLengths);

    final songArtist = pick(_FakePool.artistNames);

    return FakeMetadata(
      cameraMake:    make,
      cameraModel:   model,
      software:      sw,
      artist:        name,
      dateTimeExif:  '$y:$mo:$d $h:$mi:$s',
      dateTimeIso:   '$y-$mo-${d}T$h:$mi:${s}Z',
      dateTimePdf:   "D:$y$mo$d$h$mi$s+00'00'",
      dateTimeDisplay: '$d.$mo.$y $h:$mi',
      yearStr:       '$year',
      iso:           iso,
      exposureNum:   exp.$1,
      exposureDen:   exp.$2,
      fNumberNum:    fnum.$1,
      fNumberDen:    fnum.$2,
      focalLengthMm: foc,
      latitude:      lat,
      longitude:     lon,
      altitude:      alt,
      cityName:      city.$1,
      title:         pick(_FakePool.docTitles),
      docAuthor:     name,
      subject:       pick(_FakePool.docSubjects),
      keywords:      pick(_FakePool.docKeywords),
      company:       pick(_FakePool.companies),
      songTitle:     pick(_FakePool.songTitles),
      songArtist:    songArtist,
      songAlbum:     pick(_FakePool.albumNames),
      songYear:      '$year',
      songGenre:     pick(_FakePool.genres),
      songTrack:     '${1 + rng.nextInt(16)}',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MetadataInjector
// ─────────────────────────────────────────────────────────────────────────────

class MetadataInjector {
  /// Belirtilen dosyaya sahte metadata enjekte eder.
  /// Desteklenmeyen format için null döner.
  static Future<Uint8List?> inject({
    required Uint8List bytes,
    required String fileName,
    required FileKind kind,
    FakeMetadata? fake,
  }) async {
    final f   = fake ?? FakeMetadata.generate();
    final ext = _ext(fileName);

    switch (kind) {
      case FileKind.image:
        if (ext == 'jpg' || ext == 'jpeg') {
          final clean = await MetadataCleaner.strip(
                  bytes: bytes, fileName: fileName, kind: kind) ??
              bytes;
          return _injectJpeg(clean, f);
        }
        if (ext == 'png') {
          final clean = await MetadataCleaner.strip(
                  bytes: bytes, fileName: fileName, kind: kind) ??
              bytes;
          return _injectPng(clean, f);
        }
        return null;

      case FileKind.pdf:
        return _injectPdf(bytes, f);

      case FileKind.docx:
        return _injectOffice(bytes, f);

      case FileKind.audio:
        if (ext == 'mp3') {
          final clean = await MetadataCleaner.strip(
                  bytes: bytes, fileName: fileName, kind: kind) ??
              bytes;
          return _injectMp3(clean, f);
        }
        if (ext == 'm4a') return _injectVideo(bytes, f);
        return null;

      case FileKind.video:
        return _injectVideo(bytes, f);

      case FileKind.zip:
        return await _injectZip(bytes);

      case FileKind.unknown:
        return null;
    }
  }

  /// UI için "ne enjekte edilecek" açıklaması
  static List<String> whatWillBeInjected(FileKind kind, String ext) {
    switch (kind) {
      case FileKind.image:
        if (ext == 'jpg' || ext == 'jpeg') {
          return [
            'Sahte kamera markası ve modeli',
            'Rastgele GPS koordinatları (gerçek şehir ismi)',
            'Rastgele çekim tarihi ve saati',
            'Sahte ISO, diyafram, enstantane, odak uzaklığı',
            'Sahte yazılım ve fotoğrafçı adı',
          ];
        }
        if (ext == 'png') {
          return [
            'tEXt chunk: Yazar, Başlık, Yazılım',
            'tEXt chunk: Konum yorumu ve Telif Hakkı',
            'tEXt chunk: Oluşturma tarihi',
          ];
        }
        return ['Bu görüntü formatı için metadata ekleme desteklenmiyor'];

      case FileKind.pdf:
        return [
          'Sahte Başlık, Yazar, Konu',
          'Sahte oluşturma ve değiştirme tarihleri',
          'Sahte oluşturucu yazılım ve üretici',
          'Sahte anahtar kelimeler',
        ];

      case FileKind.docx:
        return [
          'Sahte Yazar ve Son Düzenleyen',
          'Sahte Şirket adı',
          'Rastgele oluşturma & değiştirme tarihleri',
          'Rastgele revizyon sayısı, kelime/sayfa istatistikleri',
          'Sahte uygulama adı ve versiyonu',
        ];

      case FileKind.audio:
        if (ext == 'mp3') {
          return [
            'ID3v2: Sahte şarkı başlığı ve sanatçı',
            'ID3v2: Sahte albüm adı ve yıl',
            'ID3v2: Sahte tür (genre) ve parça numarası',
            'ID3v2: Sahte besteci ve şifreli yorum',
          ];
        }
        return ['Bu ses formatı için metadata ekleme desteklenmiyor (sadece MP3)'];

      case FileKind.video:
        return [
          'QuickTime udta atom: Sahte başlık ve sanatçı',
          'QuickTime udta atom: Sahte kayıt tarihi',
          'QuickTime udta atom: Sahte yazılım ve konum yorumu',
        ];

      case FileKind.zip:
        return [
          'İçindeki tüm dosyalara sahte metadata enjekte edilir',
          'Her dosya kendi formatına göre işlenir',
          'Her dosya için farklı rastgele metadata üretilir',
        ];

      case FileKind.unknown:
        return ['Bu dosya türü desteklenmiyor'];
    }
  }

  // ── JPEG ──────────────────────────────────────────────────────────────────
  static Uint8List _injectJpeg(Uint8List stripped, FakeMetadata f) {
    if (stripped.length < 2 || stripped[0] != 0xFF || stripped[1] != 0xD8) {
      return stripped;
    }
    final app1 = Uint8List.fromList(_buildExifApp1(f));
    final out  = BytesBuilder();
    out.add([0xFF, 0xD8]);         // SOI
    out.add(app1);                 // Bizim EXIF APP1
    out.add(stripped.sublist(2));  // Geri kalan JPEG (SOI'dan sonrası)
    return out.toBytes();
  }

  /// Minimal TIFF/EXIF yapısını inşa eder ve APP1 segmenti olarak döner.
  /// Little-Endian (Intel) byte sırası kullanılır.
  static List<int> _buildExifApp1(FakeMetadata f) {
    // Yardımcılar
    List<int> le2(int v) => [v & 0xFF, (v >> 8) & 0xFF];
    List<int> le4(int v) => [
      v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF
    ];
    List<int> rat(int n, int d) => [...le4(n), ...le4(d)];

    // ASCII: char + null + (eğer tek sayı ise padding)
    int strCount(String s) => s.length + 1;
    List<int> strBytes(String s) {
      final b = <int>[...s.codeUnits, 0];
      if (b.length % 2 != 0) b.add(0);
      return b;
    }

    // Sabit 20 byte EXIF tarih: "YYYY:MM:DD HH:MM:SS\0"
    List<int> dtBytes(String dt) {
      final b = List<int>.filled(20, 0);
      for (int i = 0; i < dt.length && i < 19; i++) { b[i] = dt.codeUnitAt(i); }
      return b;
    }

    // DMS rasyonelleri (derece → gün/dakika/saniye)
    List<int> dmsRat(double deg) {
      final abs = deg.abs();
      final d   = abs.toInt();
      final mf  = (abs - d) * 60;
      final m   = mf.toInt();
      final sNum = ((mf - m) * 60 * 10000).round();
      return [...rat(d, 1), ...rat(m, 1), ...rat(sNum, 10000)];
    }

    // IFD girişi: 12 byte
    List<int> ifdEntry(int tag, int type, int count, int val) =>
        [...le2(tag), ...le2(type), ...le4(count), ...le4(val)];

    // SHORT girişi (4 byte değer alanına 2 byte + 2 byte pad)
    List<int> shortEntry(int tag, int val) =>
        [...le2(tag), ...le2(3), ...le4(1), ...le2(val), 0, 0];

    // String byte dizileri hazırla
    final makeB  = strBytes(f.cameraMake);
    final modelB = strBytes(f.cameraModel);
    final swB    = strBytes(f.software);
    final artB   = strBytes(f.artist);
    final dtB    = dtBytes(f.dateTimeExif);

    // Ofset hesaplama (TIFF başlangıcına göre)
    // TIFF başlığı: 8 byte
    // IFD0: 2 + 11*12 + 4 = 138 byte  →  bitiş: 8+138 = 146
    const ifd0End = 146;

    int off = ifd0End;
    final makeOff  = off; off += makeB.length;
    final modelOff = off; off += modelB.length;
    final swOff    = off; off += swB.length;
    final artOff   = off; off += artB.length;
    final dtOff    = off; off += 20;    // DateTime 20 byte sabit
    final xresOff  = off; off += 8;
    final yresOff  = off; off += 8;

    // ExifIFD: 2 + 7*12 + 4 = 90 byte
    final exifIfdOff    = off;
    final exifDataStart = exifIfdOff + 90;
    int eoff = exifDataStart;
    final expOff    = eoff; eoff += 8;
    final fnumOff   = eoff; eoff += 8;
    final dtOrigOff = eoff; eoff += 20;
    final dtDigOff  = eoff; eoff += 20;
    final focalOff  = eoff; eoff += 8;

    // GPSIFD: 2 + 7*12 + 4 = 90 byte
    final gpsIfdOff    = eoff;
    final gpsDataStart = gpsIfdOff + 90;
    int goff = gpsDataStart;
    final gpsLatOff = goff; goff += 24;
    final gpsLonOff = goff; goff += 24;
    final gpsAltOff = goff; goff += 8;

    // TIFF oluştur
    final tiff = <int>[];

    // TIFF başlığı  (II + 42 LE + IFD0 ofseti=8)
    tiff.addAll([0x49, 0x49, 42, 0, 8, 0, 0, 0]);

    // IFD0 (11 giriş, tag sırasına göre artan)
    tiff.addAll(le2(11));
    tiff.addAll(ifdEntry(0x010F, 2, strCount(f.cameraMake),  makeOff));
    tiff.addAll(ifdEntry(0x0110, 2, strCount(f.cameraModel), modelOff));
    tiff.addAll(shortEntry(0x0112, 1));                           // Orientation
    tiff.addAll(ifdEntry(0x011A, 5, 1, xresOff));                // XResolution
    tiff.addAll(ifdEntry(0x011B, 5, 1, yresOff));                // YResolution
    tiff.addAll(shortEntry(0x0128, 2));                           // ResolutionUnit
    tiff.addAll(ifdEntry(0x0131, 2, strCount(f.software), swOff));
    tiff.addAll(ifdEntry(0x0132, 2, 20, dtOff));                 // DateTime
    tiff.addAll(ifdEntry(0x013B, 2, strCount(f.artist),  artOff));
    tiff.addAll(ifdEntry(0x8769, 4, 1, exifIfdOff));             // ExifIFD
    tiff.addAll(ifdEntry(0x8825, 4, 1, gpsIfdOff));              // GPSIFD
    tiff.addAll(le4(0));                                          // next IFD

    // IFD0 veri bölümü
    tiff.addAll(makeB);
    tiff.addAll(modelB);
    tiff.addAll(swB);
    tiff.addAll(artB);
    tiff.addAll(dtB);
    tiff.addAll(rat(72, 1));  // XRes
    tiff.addAll(rat(72, 1));  // YRes

    // ExifIFD (7 giriş)
    tiff.addAll(le2(7));
    tiff.addAll(ifdEntry(0x829A, 5, 1, expOff));         // ExposureTime
    tiff.addAll(ifdEntry(0x829D, 5, 1, fnumOff));        // FNumber
    tiff.addAll(shortEntry(0x8827, f.iso));              // ISOSpeedRatings
    tiff.addAll(ifdEntry(0x9003, 2, 20, dtOrigOff));     // DateTimeOriginal
    tiff.addAll(ifdEntry(0x9004, 2, 20, dtDigOff));      // DateTimeDigitized
    tiff.addAll(ifdEntry(0x920A, 5, 1, focalOff));       // FocalLength
    tiff.addAll(shortEntry(0xA405, f.focalLengthMm));    // FocalIn35mm
    tiff.addAll(le4(0));                                 // ExifIFD next

    // ExifIFD veri
    tiff.addAll(rat(f.exposureNum, f.exposureDen));
    tiff.addAll(rat(f.fNumberNum,  f.fNumberDen));
    tiff.addAll(dtB);
    tiff.addAll(dtB);
    tiff.addAll(rat(f.focalLengthMm, 1));

    // GPSIFD (7 giriş)
    tiff.addAll(le2(7));
    tiff.addAll(ifdEntry(0x0000, 7, 4, 0x00000202));            // GPSVersionID [2,2,0,0]
    tiff.addAll(ifdEntry(0x0001, 2, 2, f.latitude  >= 0 ? 0x4E : 0x53)); // LatRef N/S
    tiff.addAll(ifdEntry(0x0002, 5, 3, gpsLatOff));
    tiff.addAll(ifdEntry(0x0003, 2, 2, f.longitude >= 0 ? 0x45 : 0x57)); // LonRef E/W
    tiff.addAll(ifdEntry(0x0004, 5, 3, gpsLonOff));
    tiff.addAll(ifdEntry(0x0005, 1, 1, 0));                     // AltitudeRef=0
    tiff.addAll(ifdEntry(0x0006, 5, 1, gpsAltOff));
    tiff.addAll(le4(0));                                         // GPS next

    // GPS veri
    tiff.addAll(dmsRat(f.latitude));
    tiff.addAll(dmsRat(f.longitude));
    tiff.addAll(rat((f.altitude * 10).round(), 10));

    // APP1 segmenti: FF E1 + uzunluk(BE) + "Exif\0\0" + tiff
    final exifId = [0x45, 0x78, 0x69, 0x66, 0x00, 0x00]; // "Exif\0\0"
    final app1Len = 2 + exifId.length + tiff.length;      // uzunluk alanı dahil

    return [
      0xFF, 0xE1,
      (app1Len >> 8) & 0xFF, app1Len & 0xFF,
      ...exifId,
      ...tiff,
    ];
  }

  // ── PNG ───────────────────────────────────────────────────────────────────
  static Uint8List _injectPng(Uint8List stripped, FakeMetadata f) {
    if (stripped.length < 33) return stripped; // PNG sig(8) + IHDR(25)

    final out = BytesBuilder();
    out.add(stripped.sublist(0, 8));   // PNG imzası
    out.add(stripped.sublist(8, 33)); // IHDR chunk (sabit 25 byte)

    // tEXt chunk'ları ekle (IHDR'dan hemen sonra)
    out.add(_pngTextChunk('Author',        f.artist));
    out.add(_pngTextChunk('Title',         f.title));
    out.add(_pngTextChunk('Software',      f.software));
    out.add(_pngTextChunk('Creation Time', f.dateTimeDisplay));
    out.add(_pngTextChunk('Comment',       'Photo taken in ${f.cityName}'));
    out.add(_pngTextChunk('Copyright',
        'Copyright ${f.yearStr} ${f.artist}'));
    out.add(_pngTextChunk('Source',        '${f.cameraMake} ${f.cameraModel}'));

    out.add(stripped.sublist(33)); // PLTE + IDAT + IEND
    return out.toBytes();
  }

  static List<int> _pngTextChunk(String keyword, String text) {
    // tEXt: keyword + \0 + text  (text NULL-terminated değil)
    final data     = <int>[...keyword.codeUnits, 0, ...text.codeUnits];
    final typeBytes = 'tEXt'.codeUnits.toList();
    final crc      = _crc32([...typeBytes, ...data]);
    return [
      (data.length >> 24) & 0xFF,
      (data.length >> 16) & 0xFF,
      (data.length >> 8)  & 0xFF,
       data.length        & 0xFF,
      ...typeBytes,
      ...data,
      (crc >> 24) & 0xFF,
      (crc >> 16) & 0xFF,
      (crc >> 8)  & 0xFF,
       crc        & 0xFF,
    ];
  }

  static int _crc32(List<int> data) {
    int crc = 0xFFFFFFFF;
    for (final b in data) {
      crc ^= b;
      for (int i = 0; i < 8; i++) {
        crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
      }
    }
    return crc ^ 0xFFFFFFFF;
  }

  // ── PDF ───────────────────────────────────────────────────────────────────
  static Uint8List _injectPdf(Uint8List bytes, FakeMetadata f) {
    var content = latin1.decode(bytes, allowInvalid: true);

    final fields = {
      'Title':        f.title,
      'Author':       f.docAuthor,
      'Subject':      f.subject,
      'Keywords':     f.keywords,
      'Creator':      f.software,
      'Producer':     'Metadata Reader 2.0',
      'CreationDate': f.dateTimePdf,
      'ModDate':      f.dateTimePdf,
    };

    for (final e in fields.entries) {
      // /Key (eski değer) → /Key (yeni değer)
      content = content.replaceAllMapped(
        RegExp('/${e.key}\\s*\\([^)]{0,500}\\)'),
        (_) => '/${e.key} (${e.value})',
      );
      // /Key <hex> → /Key (yeni değer)
      content = content.replaceAllMapped(
        RegExp('/${e.key}\\s*<[0-9A-Fa-f\\s]{0,500}>'),
        (_) => '/${e.key} (${e.value})',
      );
    }

    return Uint8List.fromList(latin1.encode(content));
  }

  // ── Office (DOCX / XLSX / PPTX) ──────────────────────────────────────────
  static Uint8List _injectOffice(Uint8List bytes, FakeMetadata f) {
    try {
      final archive    = ZipDecoder().decodeBytes(bytes);
      final newArchive = Archive();
      final rng        = Random();

      for (final file in archive.files) {
        if (!file.isFile) {
          newArchive.addFile(ArchiveFile(file.name, 0, <int>[]));
          continue;
        }

        if (file.name == 'docProps/core.xml') {
          final xml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
              '<cp:coreProperties '
              'xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties"'
              ' xmlns:dc="http://purl.org/dc/elements/1.1/"'
              ' xmlns:dcterms="http://purl.org/dc/terms/"'
              ' xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
              '<dc:title>${f.title}</dc:title>'
              '<dc:subject>${f.subject}</dc:subject>'
              '<dc:creator>${f.docAuthor}</dc:creator>'
              '<cp:keywords>${f.keywords}</cp:keywords>'
              '<cp:lastModifiedBy>${f.docAuthor}</cp:lastModifiedBy>'
              '<cp:revision>${1 + rng.nextInt(50)}</cp:revision>'
              '<dcterms:created xsi:type="dcterms:W3CDTF">${f.dateTimeIso}</dcterms:created>'
              '<dcterms:modified xsi:type="dcterms:W3CDTF">${f.dateTimeIso}</dcterms:modified>'
              '<cp:category>${f.subject}</cp:category>'
              '</cp:coreProperties>';
          final b = utf8.encode(xml);
          newArchive.addFile(ArchiveFile(file.name, b.length, b));
        } else if (file.name == 'docProps/app.xml') {
          final xml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
              '<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties">'
              '<Application>Microsoft Office Word 16.0</Application>'
              '<AppVersion>16.0000</AppVersion>'
              '<Company>${f.company}</Company>'
              '<Pages>${1 + rng.nextInt(120)}</Pages>'
              '<Words>${200 + rng.nextInt(15000)}</Words>'
              '<Characters>${1000 + rng.nextInt(80000)}</Characters>'
              '<Lines>${10 + rng.nextInt(600)}</Lines>'
              '<Paragraphs>${5 + rng.nextInt(200)}</Paragraphs>'
              '</Properties>';
          final b = utf8.encode(xml);
          newArchive.addFile(ArchiveFile(file.name, b.length, b));
        } else {
          newArchive.addFile(file);
        }
      }

      return Uint8List.fromList(ZipEncoder().encode(newArchive));
    } catch (_) {
      return bytes;
    }
  }

  // ── MP3 (ID3v2.3) ─────────────────────────────────────────────────────────
  static Uint8List _injectMp3(Uint8List audioData, FakeMetadata f) {
    final frames = <int>[];

    // Metin frame yardımcısı
    void addText(String frameId, String text) {
      final payload = <int>[3, ...utf8.encode(text)]; // encoding=UTF-8 + text
      frames.addAll([
        frameId.codeUnitAt(0), frameId.codeUnitAt(1),
        frameId.codeUnitAt(2), frameId.codeUnitAt(3),
        (payload.length >> 24) & 0xFF, (payload.length >> 16) & 0xFF,
        (payload.length >> 8)  & 0xFF,  payload.length        & 0xFF,
        0, 0, // flags
        ...payload,
      ]);
    }

    // COMM frame (özel format: encoding + lang + descriptor\0 + text)
    void addComment(String text) {
      final payload = <int>[
        3,                          // encoding = UTF-8
        0x65, 0x6E, 0x67,           // "eng"
        0,                          // boş content descriptor + null
        ...utf8.encode(text),
      ];
      frames.addAll([
        0x43, 0x4F, 0x4D, 0x4D,
        (payload.length >> 24) & 0xFF, (payload.length >> 16) & 0xFF,
        (payload.length >> 8)  & 0xFF,  payload.length        & 0xFF,
        0, 0,
        ...payload,
      ]);
    }

    addText('TIT2', f.songTitle);
    addText('TPE1', f.songArtist);
    addText('TALB', f.songAlbum);
    addText('TYER', f.songYear);
    addText('TCON', f.songGenre);
    addText('TRCK', f.songTrack);
    addText('TCOM', f.docAuthor);   // besteci
    addText('TENC', f.software);   // encoding tool
    addText('TPUB', f.company);
    addComment('Recorded in ${f.cityName} — ${f.dateTimeDisplay}');

    // Synchsafe boyut (her byte'ta bit 7 = 0)
    int sz = frames.length;
    final synchsafe = [
      (sz >> 21) & 0x7F,
      (sz >> 14) & 0x7F,
      (sz >> 7)  & 0x7F,
       sz        & 0x7F,
    ];

    final out = BytesBuilder();
    out.add([
      0x49, 0x44, 0x33, // "ID3"
      0x03, 0x00,       // version 2.3, rev 0
      0x00,             // flags
      ...synchsafe,
    ]);
    out.add(frames);
    out.add(audioData);
    return out.toBytes();
  }

  // ── Video (MP4 / MOV) ─────────────────────────────────────────────────────
  static Uint8List _injectVideo(Uint8List bytes, FakeMetadata f) {
    if (bytes.length < 8) return bytes;
    final firstType = String.fromCharCodes(bytes.sublist(4, 8));
    if (!{'ftyp', 'moov', 'mdat', 'free', 'wide', 'skip'}.contains(firstType)) {
      return bytes;
    }

    // QuickTime string sub-atom: [size(4)][type(4)][utf8 text]
    List<int> qtAtom(String type4, String text) {
      final textBytes = utf8.encode(text);
      final sz = 8 + textBytes.length;
      return [
        (sz >> 24) & 0xFF, (sz >> 16) & 0xFF, (sz >> 8) & 0xFF, sz & 0xFF,
        ...type4.codeUnits,
        ...textBytes,
      ];
    }

    final udtaContent = <int>[
      ...qtAtom('©nam', f.title),
      ...qtAtom('©ART', f.songArtist),
      ...qtAtom('©day', f.yearStr),
      ...qtAtom('©cmt', 'Recorded in ${f.cityName} — ${f.dateTimeDisplay}'),
      ...qtAtom('©swr', f.software),
      ...qtAtom('©aut', f.docAuthor),
    ];
    final udtaSz = 8 + udtaContent.length;
    final udtaAtom = <int>[
      (udtaSz >> 24) & 0xFF, (udtaSz >> 16) & 0xFF,
      (udtaSz >> 8)  & 0xFF,  udtaSz        & 0xFF,
      0x75, 0x64, 0x74, 0x61, // 'udta'
      ...udtaContent,
    ];

    final out = BytesBuilder();
    int pos = 0;

    while (pos + 8 <= bytes.length) {
      final atomSz = _uint32(bytes, pos);
      if (atomSz < 8 || pos + atomSz > bytes.length) {
        out.add(bytes.sublist(pos));
        break;
      }
      final type = String.fromCharCodes(bytes.sublist(pos + 4, pos + 8));

      if (type == 'moov') {
        // moov yeniden oluştur: eski udta/free çıkar, yeni udta ekle
        final moovBody = <int>[];
        int mpos = pos + 8;
        while (mpos + 8 <= pos + atomSz) {
          final msz = _uint32(bytes, mpos);
          if (msz < 8 || mpos + msz > pos + atomSz) break;
          final mtype = String.fromCharCodes(bytes.sublist(mpos + 4, mpos + 8));
          if (mtype != 'udta' && mtype != 'free') {
            moovBody.addAll(bytes.sublist(mpos, mpos + msz));
          }
          mpos += msz;
        }
        moovBody.addAll(udtaAtom);
        final newMoovSz = 8 + moovBody.length;
        out.add([
          (newMoovSz >> 24) & 0xFF, (newMoovSz >> 16) & 0xFF,
          (newMoovSz >> 8)  & 0xFF,  newMoovSz        & 0xFF,
          0x6D, 0x6F, 0x6F, 0x76, // 'moov'
          ...moovBody,
        ]);
      } else {
        out.add(bytes.sublist(pos, pos + atomSz));
      }
      pos += atomSz;
    }

    return out.toBytes();
  }

  // ── ZIP (recursive) ──────────────────────────────────────────────────────
  static Future<Uint8List> _injectZip(Uint8List bytes) async {
    try {
      final archive    = ZipDecoder().decodeBytes(bytes);
      final newArchive = Archive();

      for (final f in archive.files) {
        if (!f.isFile) {
          newArchive.addFile(ArchiveFile(f.name, 0, <int>[]));
          continue;
        }

        final fileBytes = Uint8List.fromList(f.content as List<int>);
        final ext  = _ext(f.name);
        final kind = detectFileKind(ext);

        Uint8List injected = fileBytes;
        try {
          injected = await inject(
                bytes:    fileBytes,
                fileName: f.name,
                kind:     kind,
                fake:     FakeMetadata.generate(), // her dosyaya farklı veri
              ) ??
              fileBytes;
        } catch (_) {}

        newArchive.addFile(ArchiveFile(f.name, injected.length, injected));
      }

      return Uint8List.fromList(ZipEncoder().encode(newArchive));
    } catch (_) {
      return bytes;
    }
  }

  // ── Yardımcılar ───────────────────────────────────────────────────────────
  static String _ext(String name) =>
      name.contains('.') ? name.split('.').last.toLowerCase() : '';

  static int _uint32(Uint8List b, int o) =>
      ((b[o] & 0xFF) << 24) | ((b[o + 1] & 0xFF) << 16) |
      ((b[o + 2] & 0xFF) << 8) |  (b[o + 3] & 0xFF);
}

// ─────────────────────────────────────────────────────────────────────────────
// InjectAndSaveService — inject + FilePicker.saveFile
// ─────────────────────────────────────────────────────────────────────────────

class InjectAndSaveService {
  static Future<CleanResult> run({
    required Uint8List bytes,
    required String fileName,
    required FileKind kind,
    required FakeMetadata fake,
  }) async {
    try {
      final injected = await MetadataInjector.inject(
        bytes: bytes, fileName: fileName, kind: kind, fake: fake,
      );

      if (injected == null) return CleanResult.unsupported();

      final dot      = fileName.lastIndexOf('.');
      final fakeName = dot >= 0
          ? '${fileName.substring(0, dot)}_sahte${fileName.substring(dot)}'
          : '${fileName}_sahte';

      final savedPath = await FilePicker.saveFile(
        fileName: fakeName,
        bytes:    injected,
      );

      if (savedPath == null) return CleanResult.cancelled();
      return CleanResult.success(savedPath, injected.length);
    } on PlatformException catch (e) {
      return CleanResult.error(e.message ?? e.toString());
    } catch (e) {
      return CleanResult.error(e.toString());
    }
  }
}
