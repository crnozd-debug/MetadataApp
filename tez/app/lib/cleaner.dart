import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';

import 'models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MetadataCleaner — tüm dosya türleri için metadata silme
// ─────────────────────────────────────────────────────────────────────────────

class MetadataCleaner {
  /// Dosyanın metadata'sını siler, temizlenmiş byte'ları döndürür.
  /// Desteklenmeyen format ise null döner.
  static Future<Uint8List?> strip({
    required Uint8List bytes,
    required String fileName,
    required FileKind kind,
  }) async {
    final ext = _ext(fileName);
    switch (kind) {
      case FileKind.image:
        if (ext == 'jpg' || ext == 'jpeg') return _stripJpeg(bytes);
        if (ext == 'png') return _stripPng(bytes);
        if (ext == 'webp') return _stripWebp(bytes);
        return null; // GIF, BMP, HEIC vb. — güvenli strip yok
      case FileKind.pdf:
        return _stripPdf(bytes);
      case FileKind.docx:
        return _stripOffice(bytes);
      case FileKind.audio:
        return _stripAudio(bytes, ext);
      case FileKind.video:
        return _stripVideo(bytes);
      case FileKind.zip:
        return await _stripZip(bytes);
      case FileKind.unknown:
        return null;
    }
  }

  /// UI için "bu dosyadan ne silinecek" açıklaması
  static List<String> whatWillBeStripped(FileKind kind, String ext) {
    switch (kind) {
      case FileKind.image:
        if (ext == 'jpg' || ext == 'jpeg') {
          return [
            'EXIF verisi (kamera bilgisi)',
            'GPS konum bilgisi',
            'Çekim tarihi ve saati',
            'Cihaz/yazılım bilgisi',
            'IPTC basın metadata\'sı',
            'XMP verisi',
            'Dosya yorumları',
          ];
        }
        if (ext == 'png') {
          return [
            'tEXt / zTXt / iTXt metin blokları',
            'eXIf gömülü EXIF verisi',
            'tIME oluşturma zamanı',
            'Renk profili (iCCP, gAMA, cHRM)',
          ];
        }
        return ['Bu format için metadata silme desteklenmiyor'];
      case FileKind.pdf:
        return [
          'Başlık, yazar, konu',
          'Anahtar kelimeler',
          'Oluşturan ve üretici yazılım',
          'Oluşturma ve değiştirme tarihleri',
          'XMP metadata paketi',
        ];
      case FileKind.docx:
        return [
          'Yazar ve son düzenleyen',
          'Oluşturma / değiştirme tarihleri',
          'Şirket adı ve kullanıcı adı',
          'Revizyon sayacı',
          'Uygulama ve versiyon bilgisi',
          'Kelime/sayfa/karakter istatistikleri',
        ];
      case FileKind.audio:
        if (ext == 'mp3') {
          return [
            'ID3v2 tüm etiketler (başlık, sanatçı, albüm, yıl, tür...)',
            'ID3v1 etiketi (son 128 byte)',
            'Kapak resmi (APIC frame)',
            'Şarkı sözleri (USLT frame)',
          ];
        }
        if (ext == 'm4a') {
          return ['MP4/M4A atom metadata (iTunes etiketleri)'];
        }
        return ['Bu ses formatı için metadata silme desteklenmiyor (sadece MP3/M4A)'];
      case FileKind.video:
        return [
          'udta (user data) atomu — başlık, yazar, konum',
          'Meta atom — iTunes/QuickTime metadata',
          'XMP gömülü metadata',
        ];
      case FileKind.zip:
        return [
          'ZIP yorum / ekstra alanlar',
          'İçindeki tüm dosyaların metadata\'sı (recursive)',
          'Her dosya kendi formatına göre temizlenir',
        ];
      case FileKind.unknown:
        return ['Bu dosya türü desteklenmiyor'];
    }
  }

  // ── JPEG ────────────────────────────────────────────────────────────────────
  static Uint8List _stripJpeg(Uint8List bytes) {
    if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8) return bytes;

    final out = BytesBuilder();
    out.add([0xFF, 0xD8]); // SOI
    int pos = 2;

    while (pos + 1 < bytes.length) {
      if (bytes[pos] != 0xFF) break;
      final marker = bytes[pos + 1];

      // EOI
      if (marker == 0xD9) {
        out.add([0xFF, 0xD9]);
        break;
      }
      // SOS — image data starts; copy everything to end
      if (marker == 0xDA) {
        out.add(bytes.sublist(pos));
        break;
      }
      // RST0-RST7 — no payload
      if (marker >= 0xD0 && marker <= 0xD7) {
        out.add([0xFF, marker]);
        pos += 2;
        continue;
      }
      // SOI duplicate
      if (marker == 0xD8) {
        pos += 2;
        continue;
      }

      // Segments with 2-byte length field
      if (pos + 3 >= bytes.length) break;
      final segLen = (bytes[pos + 2] << 8) | bytes[pos + 3];
      if (segLen < 2 || pos + 2 + segLen > bytes.length) break;

      // Metadata segments to remove:
      // APP1 (E1) = EXIF / XMP
      // APP2 (E2) = ICC / FlashPix XMP
      // APP3-APP15 = various
      // APP13 (ED) = IPTC / Photoshop
      // COM (FE) = comment
      const stripMarkers = {
        0xE1, 0xE2, 0xE3, 0xE4, 0xE5, 0xE6, 0xE7,
        0xE8, 0xE9, 0xEA, 0xEB, 0xEC, 0xED, 0xEE, 0xEF,
        0xFE
      };

      if (stripMarkers.contains(marker)) {
        pos += 2 + segLen; // skip
      } else {
        out.add(bytes.sublist(pos, pos + 2 + segLen));
        pos += 2 + segLen;
      }
    }

    return out.toBytes();
  }

  // ── PNG ─────────────────────────────────────────────────────────────────────
  static Uint8List _stripPng(Uint8List bytes) {
    const sig = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
    if (bytes.length < 8) return bytes;
    for (int i = 0; i < 8; i++) {
      if (bytes[i] != sig[i]) return bytes;
    }

    // Essential chunks only
    const keep = {'IHDR', 'PLTE', 'IDAT', 'IEND', 'tRNS'};

    final out = BytesBuilder();
    out.add(bytes.sublist(0, 8));

    int pos = 8;
    while (pos + 12 <= bytes.length) {
      final length = _uint32(bytes, pos);
      if (length < 0) break;
      final type = String.fromCharCodes(bytes.sublist(pos + 4, pos + 8));
      final total = 4 + 4 + length + 4;
      if (pos + total > bytes.length) break;

      if (keep.contains(type)) {
        out.add(bytes.sublist(pos, pos + total));
      }
      pos += total;
      if (type == 'IEND') break;
    }

    return out.toBytes();
  }

  // ── WEBP ─────────────────────────────────────────────────────────────────────
  static Uint8List _stripWebp(Uint8List bytes) {
    // RIFF WEBP — remove EXIF and XMP chunks, keep VP8/VP8L/VP8X/ANIM/ANMF/ICCP/ALPH
    if (bytes.length < 12) return bytes;
    // Check RIFF....WEBP header
    final riff = String.fromCharCodes(bytes.sublist(0, 4));
    final webp = String.fromCharCodes(bytes.sublist(8, 12));
    if (riff != 'RIFF' || webp != 'WEBP') return bytes;

    const strip = {'EXIF', 'XMP '};
    final out = BytesBuilder();
    out.add(bytes.sublist(0, 12)); // RIFF header

    int pos = 12;
    while (pos + 8 <= bytes.length) {
      final fourCC = String.fromCharCodes(bytes.sublist(pos, pos + 4));
      final chunkSize = _uint32LE(bytes, pos + 4);
      final padded = chunkSize + (chunkSize % 2); // RIFF chunks are word-aligned
      final total = 8 + padded;
      if (pos + total > bytes.length) {
        out.add(bytes.sublist(pos));
        break;
      }

      if (!strip.contains(fourCC)) {
        out.add(bytes.sublist(pos, pos + total));
      }
      pos += total;
    }

    // Fix RIFF file size
    final data = out.toBytes();
    final fileSize = data.length - 8;
    data[4] = fileSize & 0xFF;
    data[5] = (fileSize >> 8) & 0xFF;
    data[6] = (fileSize >> 16) & 0xFF;
    data[7] = (fileSize >> 24) & 0xFF;
    return data;
  }

  // ── PDF ─────────────────────────────────────────────────────────────────────
  static Uint8List _stripPdf(Uint8List bytes) {
    var content = latin1.decode(bytes, allowInvalid: true);

    const keys = [
      'Title', 'Author', 'Subject', 'Keywords',
      'Creator', 'Producer', 'CreationDate', 'ModDate', 'Trapped'
    ];
    for (final key in keys) {
      // /Key (value) → /Key ()
      content = content.replaceAll(
        RegExp('/$key\\s*\\([^)]{0,1000}\\)'),
        '/$key ()',
      );
      // /Key <hex> → /Key ()
      content = content.replaceAll(
        RegExp('/$key\\s*<[0-9A-Fa-f\\s]{0,1000}>'),
        '/$key ()',
      );
    }

    // XMP metadata packet
    content = content.replaceAll(
      RegExp(r'<\?xpacket[^>]*\?>.*?<\?xpacket\s+end[^>]*\?>',
          dotAll: true),
      '',
    );

    return Uint8List.fromList(latin1.encode(content));
  }

  // ── Office — DOCX / XLSX / PPTX ────────────────────────────────────────────
  static Uint8List _stripOffice(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final newArchive = Archive();

      const emptyCoreXml =
          '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<cp:coreProperties '
          'xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties"'
          ' xmlns:dc="http://purl.org/dc/elements/1.1/"'
          ' xmlns:dcterms="http://purl.org/dc/terms/"'
          ' xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
          '</cp:coreProperties>';

      const emptyAppXml =
          '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties">'
          '</Properties>';

      for (final f in archive.files) {
        if (!f.isFile) {
          newArchive.addFile(ArchiveFile(f.name, 0, <int>[]));
          continue;
        }
        Uint8List content;
        if (f.name == 'docProps/core.xml') {
          content = Uint8List.fromList(utf8.encode(emptyCoreXml));
        } else if (f.name == 'docProps/app.xml') {
          content = Uint8List.fromList(utf8.encode(emptyAppXml));
        } else {
          content = Uint8List.fromList(f.content as List<int>);
        }
        newArchive.addFile(ArchiveFile(f.name, content.length, content));
      }

      final encoded = ZipEncoder().encode(newArchive);
      return Uint8List.fromList(encoded);
    } catch (_) {
      return bytes;
    }
  }

  // ── Audio — MP3 / M4A ───────────────────────────────────────────────────────
  static Uint8List _stripAudio(Uint8List bytes, String ext) {
    if (ext == 'm4a') return _stripVideo(bytes); // M4A = MP4 container

    // MP3 — ID3v2 başından, ID3v1 sonundan sil
    int start = 0;
    int end = bytes.length;

    // ID3v2 başlangıcı
    if (bytes.length > 10 &&
        bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33) {
      final sz = ((bytes[6] & 0x7F) << 21) |
          ((bytes[7] & 0x7F) << 14) |
          ((bytes[8] & 0x7F) << 7) |
          (bytes[9] & 0x7F);
      start = 10 + sz;
      if (start >= bytes.length) start = 0;
    }

    // ID3v1 sonu
    if (end - start >= 128) {
      final idx = end - 128;
      if (bytes[idx] == 0x54 && bytes[idx + 1] == 0x41 && bytes[idx + 2] == 0x47) {
        end = idx;
      }
    }

    return (start == 0 && end == bytes.length)
        ? bytes
        : bytes.sublist(start, end);
  }

  // ── Video — MP4 / MOV ───────────────────────────────────────────────────────
  static Uint8List _stripVideo(Uint8List bytes) {
    if (bytes.length < 8) return bytes;
    final firstType = String.fromCharCodes(bytes.sublist(4, 8));
    if (!{'ftyp', 'mdat', 'moov', 'free', 'wide', 'skip'}.contains(firstType)) {
      return bytes;
    }

    final out = BytesBuilder();
    int pos = 0;

    while (pos + 8 <= bytes.length) {
      int atomSz = _uint32(bytes, pos);
      if (atomSz == 1 && pos + 16 <= bytes.length) {
        // Extended 64-bit size — copy as-is (too complex to modify)
        out.add(bytes.sublist(pos));
        break;
      }
      if (atomSz == 0) {
        out.add(bytes.sublist(pos));
        break;
      }
      if (atomSz < 8 || pos + atomSz > bytes.length) {
        out.add(bytes.sublist(pos));
        break;
      }

      final type = String.fromCharCodes(bytes.sublist(pos + 4, pos + 8));

      if (type == 'moov') {
        out.add(_stripMoov(bytes.sublist(pos, pos + atomSz)));
      } else {
        out.add(bytes.sublist(pos, pos + atomSz));
      }
      pos += atomSz;
    }

    return out.toBytes();
  }

  static Uint8List _stripMoov(Uint8List moov) {
    final inner = BytesBuilder();
    int pos = 8;

    while (pos + 8 <= moov.length) {
      final sz = _uint32(moov, pos);
      if (sz < 8 || pos + sz > moov.length) break;
      final type = String.fromCharCodes(moov.sublist(pos + 4, pos + 8));
      // Strip user-data and metadata atoms
      if (!{'udta', 'meta', 'free', 'skip'}.contains(type)) {
        inner.add(moov.sublist(pos, pos + sz));
      }
      pos += sz;
    }

    final innerBytes = inner.toBytes();
    final newSize = 8 + innerBytes.length;
    final header = ByteData(8);
    header.setUint32(0, newSize, Endian.big);
    // 'moov' = 6D 6F 6F 76
    header.buffer.asUint8List()[4] = 0x6D;
    header.buffer.asUint8List()[5] = 0x6F;
    header.buffer.asUint8List()[6] = 0x6F;
    header.buffer.asUint8List()[7] = 0x76;

    final out = BytesBuilder();
    out.add(header.buffer.asUint8List());
    out.add(innerBytes);
    return out.toBytes();
  }

  // ── ZIP — recursive ─────────────────────────────────────────────────────────
  static Future<Uint8List> _stripZip(Uint8List bytes) async {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final newArchive = Archive(); // Yorum yok

      for (final f in archive.files) {
        if (!f.isFile) {
          newArchive.addFile(ArchiveFile(f.name, 0, <int>[]));
          continue;
        }

        final fileBytes = Uint8List.fromList(f.content as List<int>);
        final ext = _ext(f.name);
        final kind = detectFileKind(ext);

        Uint8List stripped = fileBytes;
        try {
          stripped = await strip(
                bytes: fileBytes,
                fileName: f.name,
                kind: kind,
              ) ??
              fileBytes;
        } catch (_) {}

        newArchive.addFile(ArchiveFile(f.name, stripped.length, stripped));
      }

      final encoded = ZipEncoder().encode(newArchive);
      return Uint8List.fromList(encoded);
    } catch (_) {
      return bytes;
    }
  }

  // ── Yardımcılar ─────────────────────────────────────────────────────────────
  static String _ext(String name) =>
      name.contains('.') ? name.split('.').last.toLowerCase() : '';

  static int _uint32(Uint8List b, int o) =>
      ((b[o] & 0xFF) << 24) | ((b[o + 1] & 0xFF) << 16) |
      ((b[o + 2] & 0xFF) << 8) | (b[o + 3] & 0xFF);

  static int _uint32LE(Uint8List b, int o) =>
      (b[o] & 0xFF) |
      ((b[o + 1] & 0xFF) << 8) |
      ((b[o + 2] & 0xFF) << 16) |
      ((b[o + 3] & 0xFF) << 24);
}

// ─────────────────────────────────────────────────────────────────────────────
// Temizle & Kaydet — dosyayı işleyip sistem save diyaloğuyla kaydeder
// ─────────────────────────────────────────────────────────────────────────────

class CleanAndSaveService {
  static Future<CleanResult> run({
    required Uint8List bytes,
    required String fileName,
    required FileKind kind,
  }) async {
    try {
      final cleaned = await MetadataCleaner.strip(
        bytes: bytes,
        fileName: fileName,
        kind: kind,
      );

      if (cleaned == null) {
        return CleanResult.unsupported();
      }

      // Çıktı dosya adı — "_temiz" eki
      final dot = fileName.lastIndexOf('.');
      final cleanName = dot >= 0
          ? '${fileName.substring(0, dot)}_temiz${fileName.substring(dot)}'
          : '${fileName}_temiz';

      final savedPath = await FilePicker.saveFile(
        fileName: cleanName,
        bytes: cleaned,
      );

      if (savedPath == null) return CleanResult.cancelled();
      return CleanResult.success(savedPath, cleaned.length);
    } on PlatformException catch (e) {
      return CleanResult.error(e.message ?? e.toString());
    } catch (e) {
      return CleanResult.error(e.toString());
    }
  }
}

class CleanResult {
  final CleanStatus status;
  final String? savedPath;
  final int? cleanedSize;
  final String? error;

  const CleanResult._({
    required this.status,
    this.savedPath,
    this.cleanedSize,
    this.error,
  });

  factory CleanResult.success(String path, int size) => CleanResult._(
        status: CleanStatus.success,
        savedPath: path,
        cleanedSize: size,
      );

  factory CleanResult.cancelled() =>
      const CleanResult._(status: CleanStatus.cancelled);

  factory CleanResult.unsupported() =>
      const CleanResult._(status: CleanStatus.unsupported);

  factory CleanResult.error(String msg) =>
      CleanResult._(status: CleanStatus.error, error: msg);
}

enum CleanStatus { success, cancelled, unsupported, error }
