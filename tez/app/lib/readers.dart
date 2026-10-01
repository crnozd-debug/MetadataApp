import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:exif/exif.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Dispatcher
// ─────────────────────────────────────────────────────────────────────────────

class MetadataDispatcher {
  static const _channel = MethodChannel('com.example.metadata_app/media');

  static Future<List<MetadataSection>> read({
    required Uint8List bytes,
    required String fileName,
    required String? filePath,
    required FileKind kind,
  }) async {
    final ext = _ext(fileName);
    final basic = _basicSection(fileName, bytes.length, ext);

    try {
      switch (kind) {
        case FileKind.image:
          return [basic, ...await ImageReader.read(bytes)];
        case FileKind.pdf:
          return [basic, ...PdfReader.read(bytes)];
        case FileKind.zip:
          // ZipReader async — ZIP içindeki her dosyanın metadata'sını okur
          return [basic, ...await ZipReader.read(bytes, ext)];
        case FileKind.docx:
          return [basic, ...DocxReader.read(bytes, ext)];
        case FileKind.audio:
          final media = filePath != null ? await _native(filePath) : null;
          return [basic, ...AudioReader.read(bytes, media)];
        case FileKind.video:
          final media = filePath != null ? await _native(filePath) : null;
          return [basic, ...VideoReader.read(media)];
        case FileKind.unknown:
          return [basic];
      }
    } catch (e) {
      return [
        basic,
        MetadataSection(
          title: 'Hata',
          icon: Icons.error_outline_rounded,
          color: const Color(0xFFFF6584),
          fields: [MetadataField(label: 'Açıklama', value: e.toString())],
        ),
      ];
    }
  }

  static Future<Map<String, String>?> _native(String path) async {
    try {
      return await _channel.invokeMapMethod<String, String>(
          'getMediaMetadata', {'path': path});
    } catch (_) {
      return null;
    }
  }

  static MetadataSection _basicSection(String name, int size, String ext) {
    return MetadataSection(
      title: 'Dosya Bilgileri',
      icon: Icons.insert_drive_file_rounded,
      color: const Color(0xFF6C63FF),
      fields: [
        MetadataField(label: 'Dosya Adı', value: name),
        MetadataField(label: 'Boyut', value: fmtSize(size)),
        MetadataField(
            label: 'Format', value: ext.isEmpty ? 'N/A' : ext.toUpperCase()),
      ],
    );
  }

  static String _ext(String name) =>
      name.contains('.') ? name.split('.').last.toLowerCase() : '';
}

// ─────────────────────────────────────────────────────────────────────────────
// Ortak yardımcılar
// ─────────────────────────────────────────────────────────────────────────────

String fmtSize(int b) {
  if (b < 1024) return '$b B';
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
  return '${(b / (1024 * 1024)).toStringAsFixed(2)} MB';
}

MetadataSection rawSection(String title, List<MetadataField> fields) {
  return MetadataSection(
    title: title,
    icon: Icons.data_object_rounded,
    color: const Color(0xFF636E72),
    fields: fields.isEmpty
        ? [const MetadataField(label: 'Sonuç', value: 'Ham veri bulunamadı')]
        : fields,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. Görüntü — EXIF
// ─────────────────────────────────────────────────────────────────────────────

class ImageReader {
  static Future<List<MetadataSection>> read(Uint8List bytes) async {
    String dimensions = 'N/A';
    try {
      final img = await decodeImageFromList(bytes);
      dimensions = '${img.width} × ${img.height}';
    } catch (_) {}

    final exif = await readExifFromBytes(bytes);
    final noExif = exif.isEmpty;

    // helper fonksiyonlar
    String tag(String key) {
      if (noExif) return 'N/A';
      final t = exif[key];
      if (t == null) return 'N/A';
      final v = t.printable.trim();
      return v.isEmpty ? 'N/A' : v;
    }

    String tagFb(List<String> keys) {
      for (final k in keys) {
        final v = tag(k);
        if (v != 'N/A') return v;
      }
      return 'N/A';
    }

    String rational(String key, {String prefix = '', String suffix = ''}) {
      if (noExif) return 'N/A';
      final t = exif[key];
      if (t == null) return 'N/A';
      try {
        final p = t.printable.split('/');
        if (p.length == 2) {
          final v = double.parse(p[0]) / double.parse(p[1]);
          return '$prefix${v.toStringAsFixed(1)}$suffix';
        }
      } catch (_) {}
      return '$prefix${t.printable}$suffix';
    }

    String shutter(String key) {
      if (noExif) return 'N/A';
      final t = exif[key];
      if (t == null) return 'N/A';
      try {
        final p = t.printable.trim().split('/');
        if (p.length == 2) {
          final n = double.parse(p[0]);
          final d = double.parse(p[1]);
          if (n == 1) return '1/${d.toInt()} sn';
          final v = n / d;
          return v >= 1 ? '${v.toStringAsFixed(1)} sn' : '1/${(d / n).round()} sn';
        }
      } catch (_) {}
      return '${t.printable} sn';
    }

    String focal(String key) {
      if (noExif) return 'N/A';
      final t = exif[key];
      if (t == null) return 'N/A';
      try {
        final p = t.printable.trim().split('/');
        if (p.length == 2) {
          return '${(double.parse(p[0]) / double.parse(p[1])).toStringAsFixed(0)} mm';
        }
      } catch (_) {}
      return '${t.printable} mm';
    }

    String flash(String key) {
      if (noExif) return 'N/A';
      final t = exif[key];
      if (t == null) return 'N/A';
      try {
        final v = int.parse(t.printable.trim());
        if (v == 0) return 'Kullanılmadı';
        if (v & 0x1 == 1) return 'Kullanıldı';
      } catch (_) {}
      return t.printable;
    }

    String date(String raw) {
      if (raw == 'N/A') return 'N/A';
      try {
        final p = raw.split(' ');
        if (p.length == 2) {
          final d = p[0].split(':');
          return '${d[2]}.${d[1]}.${d[0]}  ${p[1]}';
        }
      } catch (_) {}
      return raw;
    }

    double? gps(String key) {
      final t = exif[key];
      if (t == null) return null;
      try {
        final p = t.printable.trim().split(', ');
        if (p.length != 3) return null;
        double rat(String s) {
          final r = s.trim().split('/');
          return r.length == 2
              ? double.parse(r[0]) / double.parse(r[1])
              : double.parse(s);
        }
        return rat(p[0]) + rat(p[1]) / 60 + rat(p[2]) / 3600;
      } catch (_) {
        return null;
      }
    }

    String lat() {
      if (noExif) return 'N/A';
      final v = gps('GPS GPSLatitude');
      if (v == null) return 'N/A';
      return '${v.toStringAsFixed(6)}° ${exif['GPS GPSLatitudeRef']?.printable.trim() ?? 'N'}';
    }

    String lon() {
      if (noExif) return 'N/A';
      final v = gps('GPS GPSLongitude');
      if (v == null) return 'N/A';
      return '${v.toStringAsFixed(6)}° ${exif['GPS GPSLongitudeRef']?.printable.trim() ?? 'E'}';
    }

    String alt() {
      if (noExif) return 'N/A';
      final t = exif['GPS GPSAltitude'];
      if (t == null) return 'N/A';
      try {
        final p = t.printable.trim().split('/');
        final v = p.length == 2
            ? double.parse(p[0]) / double.parse(p[1])
            : double.parse(t.printable.trim());
        final ref = exif['GPS GPSAltitudeRef']?.printable.trim() ?? '0';
        return '${ref == "1" ? "-" : ""}${v.toStringAsFixed(1)} m';
      } catch (_) {
        return 'N/A';
      }
    }

    return [
      MetadataSection(
        title: 'Görüntü',
        icon: Icons.image_rounded,
        color: const Color(0xFF6C63FF),
        fields: [
          MetadataField(label: 'Boyutlar', value: dimensions),
          MetadataField(label: 'Yön', value: tag('Image Orientation')),
          MetadataField(label: 'Renk Uzayı', value: tag('EXIF ColorSpace')),
          MetadataField(label: 'Bit Derinliği', value: tag('Image BitsPerSample')),
          MetadataField(label: 'X Çözünürlük', value: tag('Image XResolution')),
          MetadataField(label: 'Y Çözünürlük', value: tag('Image YResolution')),
        ],
      ),
      MetadataSection(
        title: 'Kamera',
        icon: Icons.camera_alt_rounded,
        color: const Color(0xFF00D4FF),
        fields: [
          MetadataField(label: 'Marka', value: tag('Image Make')),
          MetadataField(label: 'Model', value: tag('Image Model')),
          MetadataField(label: 'Lens', value: tag('EXIF LensModel')),
          MetadataField(label: 'Yazılım', value: tag('Image Software')),
        ],
      ),
      MetadataSection(
        title: 'Çekim Ayarları',
        icon: Icons.tune_rounded,
        color: const Color(0xFFFF6584),
        fields: [
          MetadataField(label: 'ISO', value: tag('EXIF ISOSpeedRatings')),
          MetadataField(label: 'Diyafram', value: rational('EXIF FNumber', prefix: 'f/')),
          MetadataField(label: 'Enstantane', value: shutter('EXIF ExposureTime')),
          MetadataField(label: 'Odak Uzaklığı', value: focal('EXIF FocalLength')),
          MetadataField(label: 'Flaş', value: flash('EXIF Flash')),
          MetadataField(
              label: 'Beyaz Dengesi',
              value: tag('EXIF WhiteBalance') == '0' ? 'Otomatik' : tag('EXIF WhiteBalance')),
          MetadataField(
              label: 'Pozlama Modu',
              value: switch (tag('EXIF ExposureMode')) {
                '0' => 'Otomatik',
                '1' => 'Manuel',
                '2' => 'ABD',
                final v => v,
              }),
          MetadataField(label: 'Program', value: tag('EXIF ExposureProgram')),
          MetadataField(label: 'Ölçüm Modu', value: tag('EXIF MeteringMode')),
        ],
      ),
      MetadataSection(
        title: 'Konum (GPS)',
        icon: Icons.location_on_rounded,
        color: const Color(0xFF43E97B),
        fields: [
          MetadataField(label: 'Enlem', value: lat()),
          MetadataField(label: 'Boylam', value: lon()),
          MetadataField(label: 'Yükseklik', value: alt()),
          MetadataField(label: 'GPS Hızı', value: tag('GPS GPSSpeed')),
          MetadataField(label: 'GPS Tarihi', value: tag('GPS GPSDate')),
        ],
      ),
      MetadataSection(
        title: 'Tarih & Saat',
        icon: Icons.schedule_rounded,
        color: const Color(0xFFFA8231),
        fields: [
          MetadataField(
              label: 'Çekim Tarihi',
              value: date(tagFb(['EXIF DateTimeOriginal', 'Image DateTime']))),
          MetadataField(
              label: 'Dijitalleştirme',
              value: date(tag('EXIF DateTimeDigitized'))),
          MetadataField(
              label: 'Son Değiştirilme', value: date(tag('Image DateTime'))),
        ],
      ),
      // Ham EXIF tag'leri
      rawSection(
        'Ham EXIF Tag\'leri (${exif.length} adet)',
        noExif
            ? [const MetadataField(label: 'Sonuç', value: 'EXIF verisi bulunamadı')]
            : exif.entries
                .map((e) => MetadataField(
                      label: e.key,
                      value: e.value.printable.trim().isEmpty
                          ? '(boş)'
                          : e.value.printable.trim(),
                    ))
                .toList(),
      ),
    ];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. PDF
// ─────────────────────────────────────────────────────────────────────────────

class PdfReader {
  static List<MetadataSection> read(Uint8List bytes) {
    final raw = latin1.decode(bytes, allowInvalid: true);

    // Info sözlüğünden tek bir değer al
    String get(String key) {
      var m = RegExp('/$key\\s*\\(([^)]{0,500})\\)').firstMatch(raw);
      if (m != null) return _clean(m.group(1)!.trim());
      m = RegExp('/$key\\s*<([0-9A-Fa-f\\s]+)>').firstMatch(raw);
      if (m != null) return _hexDecode(m.group(1)!);
      return 'N/A';
    }

    // Sayfa sayısı
    final countMatches = RegExp(r'/Count\s+(\d+)').allMatches(raw).toList();
    final pageCount = countMatches.isNotEmpty
        ? (countMatches.last.group(1) ?? 'N/A')
        : 'N/A';

    // PDF versiyonu
    final verMatch = RegExp(r'%PDF-(\d+\.\d+)').firstMatch(raw);
    final version = verMatch != null ? 'PDF ${verMatch.group(1)}' : 'N/A';

    // Ham: TÜM /Key (Value) çiftleri
    final rawFields = <MetadataField>[];
    final seen = <String>{};
    for (final m in RegExp(r'/(\w+)\s*\(([^)]{1,300})\)').allMatches(raw)) {
      final k = m.group(1)!;
      final v = _clean(m.group(2)!.trim());
      if (v.isNotEmpty && seen.add('$k:$v')) {
        rawFields.add(MetadataField(label: '/$k', value: v));
      }
    }
    for (final m
        in RegExp(r'/(\w+)\s*<([0-9A-Fa-f\s]{4,300})>').allMatches(raw)) {
      final k = m.group(1)!;
      final v = _hexDecode(m.group(2)!);
      if (v != 'N/A' && v.isNotEmpty && seen.add('$k:$v')) {
        rawFields.add(MetadataField(label: '/$k', value: v));
      }
    }

    return [
      MetadataSection(
        title: 'PDF Bilgileri',
        icon: Icons.picture_as_pdf_rounded,
        color: const Color(0xFFFF6584),
        fields: [
          MetadataField(label: 'Versiyon', value: version),
          MetadataField(label: 'Sayfa Sayısı', value: pageCount),
          MetadataField(
              label: 'Şifreli', value: raw.contains('/Encrypt') ? 'Evet' : 'Hayır'),
          MetadataField(label: 'Başlık', value: get('Title')),
          MetadataField(label: 'Yazar', value: get('Author')),
          MetadataField(label: 'Konu', value: get('Subject')),
          MetadataField(label: 'Anahtar Kelimeler', value: get('Keywords')),
          MetadataField(label: 'Oluşturan', value: get('Creator')),
          MetadataField(label: 'Üretici', value: get('Producer')),
          MetadataField(
              label: 'Oluşturma Tarihi',
              value: _pdfDate(get('CreationDate'))),
          MetadataField(
              label: 'Değiştirme Tarihi', value: _pdfDate(get('ModDate'))),
        ],
      ),
      rawSection('Ham PDF Verileri (${rawFields.length} adet)', rawFields),
    ];
  }

  static String _clean(String s) =>
      s.replaceAll(RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f]'), '').trim();

  static String _hexDecode(String hex) {
    try {
      final clean = hex.replaceAll(RegExp(r'\s'), '');
      if (clean.isEmpty) return 'N/A';
      if (clean.toUpperCase().startsWith('FEFF')) {
        final chars = <int>[];
        for (int i = 4; i < clean.length - 3; i += 4) {
          chars.add(int.parse(clean.substring(i, i + 4), radix: 16));
        }
        return String.fromCharCodes(chars);
      }
      final bs = <int>[];
      for (int i = 0; i < clean.length - 1; i += 2) {
        bs.add(int.parse(clean.substring(i, i + 2), radix: 16));
      }
      return latin1.decode(bs);
    } catch (_) {
      return 'N/A';
    }
  }

  static String _pdfDate(String raw) {
    if (raw == 'N/A' || raw.isEmpty) return 'N/A';
    try {
      final s = raw.replaceFirst('D:', '').replaceAll("'", '');
      if (s.length >= 8) {
        return '${s.substring(6, 8)}.${s.substring(4, 6)}.${s.substring(0, 4)}'
            '  ${s.length >= 10 ? s.substring(8, 10) : '00'}:${s.length >= 12 ? s.substring(10, 12) : '00'}';
      }
    } catch (_) {}
    return raw;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. ZIP — İçindeki her dosyanın metadata'sı ayrı ayrı okunur
// ─────────────────────────────────────────────────────────────────────────────

class ZipReader {
  static const int _maxFiles = 15;
  static const int _maxFileBytes = 20 * 1024 * 1024; // 20 MB

  static Future<List<MetadataSection>> read(
      Uint8List bytes, String ext) async {
    try {
      final Archive archive;
      switch (ext) {
        case 'gz':
          archive = TarDecoder().decodeBytes(GZipDecoder().decodeBytes(bytes));
          break;
        case 'tar':
          archive = TarDecoder().decodeBytes(bytes);
          break;
        default:
          archive = ZipDecoder().decodeBytes(bytes);
      }

      int totalUncomp = 0, totalComp = 0, fileCount = 0, dirCount = 0;
      for (final f in archive.files) {
        if (f.isFile) {
          fileCount++;
          totalUncomp += f.size;
          totalComp += f.rawContent?.length ?? f.size;
        } else {
          dirCount++;
        }
      }

      final ratio = totalUncomp > 0
          ? '${(100 - totalComp / totalUncomp * 100).toStringAsFixed(1)}%'
          : 'N/A';

      final sections = <MetadataSection>[
        // Arşiv özeti
        MetadataSection(
          title: 'Arşiv Özeti',
          icon: Icons.folder_zip_rounded,
          color: const Color(0xFFFA8231),
          fields: [
            MetadataField(label: 'Toplam Dosya', value: '$fileCount'),
            MetadataField(label: 'Toplam Klasör', value: '$dirCount'),
            MetadataField(label: 'Açık Boyut', value: fmtSize(totalUncomp)),
            MetadataField(
                label: 'Sıkıştırılmış Boyut', value: fmtSize(totalComp)),
            MetadataField(label: 'Sıkıştırma Oranı', value: ratio),
            if (archive.comment != null && archive.comment!.isNotEmpty)
              MetadataField(label: 'Yorum', value: archive.comment!),
          ],
        ),
      ];

      // Her dosyanın kendi metadata'sı
      final processable = archive.files
          .where((f) => f.isFile && f.size > 0)
          .take(_maxFiles)
          .toList();

      if (processable.isEmpty) {
        sections.add(rawSection('İçerik', [
          const MetadataField(label: 'Durum', value: 'Arşiv boş')
        ]));
        return sections;
      }

      for (int i = 0; i < processable.length; i++) {
        final file = processable[i];
        final fileExt = file.name.contains('.')
            ? file.name.split('.').last.toLowerCase()
            : '';
        final kind = detectFileKind(fileExt);

        // Dosya başlık kartı
        sections.add(MetadataSection(
          title: '📄 ${file.name}',
          icon: kind.icon,
          color: kind.color,
          fields: [
            MetadataField(label: 'Boyut (açık)', value: fmtSize(file.size)),
            MetadataField(
                label: 'Boyut (sıkıştırılmış)',
                value: fmtSize(file.rawContent?.length ?? file.size)),
            MetadataField(
                label: 'Tür', value: fileExt.isEmpty ? 'Bilinmiyor' : fileExt.toUpperCase()),
          ],
        ));

        // Çok büyük dosyaları içerik olarak okuma
        if (file.size > _maxFileBytes) {
          sections.add(rawSection('  ↳ Metadata (${file.name})', [
            MetadataField(
                label: 'Not',
                value: 'Dosya çok büyük (${fmtSize(file.size)}) — atlandı')
          ]));
          continue;
        }

        // Desteklenmeyen türler
        if (kind == FileKind.unknown || kind == FileKind.video) {
          continue;
        }

        try {
          final fileBytes =
              Uint8List.fromList(file.content as List<int>);
          final subSections =
              await _readFileMeta(fileBytes, file.name, fileExt, kind);

          for (final s in subSections) {
            sections.add(MetadataSection(
              title: '  ↳ ${s.title}',
              icon: s.icon,
              color: s.color,
              fields: s.fields,
            ));
          }
        } catch (e) {
          sections.add(rawSection('  ↳ Hata (${file.name})', [
            MetadataField(label: 'Hata', value: e.toString())
          ]));
        }
      }

      if (fileCount > _maxFiles) {
        sections.add(MetadataSection(
          title: 'ℹ️ Not',
          icon: Icons.info_outline_rounded,
          color: const Color(0xFF636E72),
          fields: [
            MetadataField(
                label: 'Gösterilmeyen',
                value: '${fileCount - _maxFiles} dosya daha var'),
          ],
        ));
      }

      return sections;
    } catch (e) {
      return [
        MetadataSection(
          title: 'Arşiv Okunamadı',
          icon: Icons.error_outline_rounded,
          color: const Color(0xFFFF6584),
          fields: [MetadataField(label: 'Hata', value: e.toString())],
        )
      ];
    }
  }

  static Future<List<MetadataSection>> _readFileMeta(
      Uint8List bytes, String name, String ext, FileKind kind) async {
    switch (kind) {
      case FileKind.image:
        return await ImageReader.read(bytes);
      case FileKind.pdf:
        return PdfReader.read(bytes);
      case FileKind.docx:
        return DocxReader.read(bytes, ext);
      case FileKind.audio:
        return AudioReader.read(bytes, null);
      case FileKind.zip:
        // İç içe ZIP — sadece özet, recursive değil
        return await ZipReader.read(bytes, ext);
      default:
        return [];
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. DOCX / XLSX / PPTX
// ─────────────────────────────────────────────────────────────────────────────

class DocxReader {
  static List<MetadataSection> read(Uint8List bytes, String ext) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);

      String coreXml = '';
      String appXml = '';
      for (final f in archive.files) {
        if (!f.isFile) continue;
        if (f.name == 'docProps/core.xml') {
          coreXml =
              utf8.decode(f.content as List<int>, allowMalformed: true);
        } else if (f.name == 'docProps/app.xml') {
          appXml =
              utf8.decode(f.content as List<int>, allowMalformed: true);
        }
      }

      // Tek bir XML tag'ı oku
      String xTag(String xml, String tag) {
        final m = RegExp('<$tag[^>]*>([^<]*)</$tag>').firstMatch(xml);
        final v = m?.group(1)?.trim() ?? 'N/A';
        return v.isEmpty ? 'N/A' : v;
      }

      // ISO tarihi formatla
      String isoDate(String raw) {
        if (raw == 'N/A') return 'N/A';
        try {
          final dt = DateTime.parse(raw);
          return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}  '
              '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
        } catch (_) {
          return raw;
        }
      }

      // Tüm XML alanları (ham)
      final rawFields = <MetadataField>[];
      final seen = <String>{};
      for (final xmlSrc in [coreXml, appXml]) {
        for (final m
            in RegExp(r'<([^/?!][^>]*?)>([^<]{1,400})</[^>]+>').allMatches(xmlSrc)) {
          final tagName = m.group(1)!.trim().split(' ').first;
          final val = m.group(2)!.trim();
          if (val.isNotEmpty && seen.add('$tagName:$val')) {
            rawFields.add(MetadataField(label: tagName, value: val));
          }
        }
      }

      final docType = switch (ext) {
        'xlsx' => 'Excel Çalışma Kitabı',
        'pptx' => 'PowerPoint Sunusu',
        'odt' => 'OpenDocument Metin',
        _ => 'Word Belgesi',
      };

      return [
        MetadataSection(
          title: 'Belge Bilgileri',
          icon: Icons.description_rounded,
          color: const Color(0xFF00D4FF),
          fields: [
            MetadataField(label: 'Belge Türü', value: docType),
            MetadataField(label: 'Başlık', value: xTag(coreXml, 'dc:title')),
            MetadataField(label: 'Konu', value: xTag(coreXml, 'dc:subject')),
            MetadataField(label: 'Yazar', value: xTag(coreXml, 'dc:creator')),
            MetadataField(
                label: 'Son Düzenleyen',
                value: xTag(coreXml, 'cp:lastModifiedBy')),
            MetadataField(
                label: 'Açıklama', value: xTag(coreXml, 'dc:description')),
            MetadataField(
                label: 'Anahtar Kelimeler',
                value: xTag(coreXml, 'cp:keywords')),
            MetadataField(
                label: 'Kategori', value: xTag(coreXml, 'cp:category')),
            MetadataField(
                label: 'Revizyon', value: xTag(coreXml, 'cp:revision')),
            MetadataField(
                label: 'Oluşturma Tarihi',
                value: isoDate(xTag(coreXml, 'dcterms:created'))),
            MetadataField(
                label: 'Değiştirme Tarihi',
                value: isoDate(xTag(coreXml, 'dcterms:modified'))),
          ],
        ),
        MetadataSection(
          title: 'Uygulama Bilgileri',
          icon: Icons.computer_rounded,
          color: const Color(0xFF00D4FF).withValues(alpha: 0.7),
          fields: [
            MetadataField(label: 'Uygulama', value: xTag(appXml, 'Application')),
            MetadataField(label: 'Versiyon', value: xTag(appXml, 'AppVersion')),
            MetadataField(label: 'Şirket', value: xTag(appXml, 'Company')),
            MetadataField(label: 'Sayfa Sayısı', value: xTag(appXml, 'Pages')),
            MetadataField(
                label: 'Kelime Sayısı', value: xTag(appXml, 'Words')),
            MetadataField(
                label: 'Karakter Sayısı', value: xTag(appXml, 'Characters')),
            MetadataField(label: 'Satır Sayısı', value: xTag(appXml, 'Lines')),
            MetadataField(
                label: 'Paragraf Sayısı', value: xTag(appXml, 'Paragraphs')),
            MetadataField(
                label: 'Slayt Sayısı', value: xTag(appXml, 'Slides')),
          ],
        ),
        rawSection(
            'Ham XML Verileri (${rawFields.length} alan)', rawFields),
      ];
    } catch (e) {
      return [
        MetadataSection(
          title: 'Belge Okunamadı',
          icon: Icons.error_outline_rounded,
          color: const Color(0xFFFF6584),
          fields: [MetadataField(label: 'Hata', value: e.toString())],
        )
      ];
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. Ses — ID3v1 / ID3v2 (pure Dart)
// ─────────────────────────────────────────────────────────────────────────────

class AudioReader {
  static List<MetadataSection> read(
      Uint8List bytes, Map<String, String>? media) {
    String title = 'N/A',
        artist = 'N/A',
        album = 'N/A',
        year = 'N/A',
        genre = 'N/A',
        track = 'N/A',
        comment = 'N/A',
        duration = 'N/A',
        bitrate = 'N/A',
        mimeType = 'N/A';

    final rawNative = <MetadataField>[];

    if (media != null) {
      title = _nvl(media['title']);
      artist = _nvl(media['artist']);
      album = _nvl(media['album']);
      year = _nvl(media['year']);
      genre = _nvl(media['genre']);
      bitrate = _fmtBitrate(media['bitrate']);
      mimeType = _nvl(media['mimeType']);
      final dur = int.tryParse(media['duration'] ?? '');
      if (dur != null) duration = _fmtDur(dur);
      // Ham native alanlar
      for (final e in media.entries) {
        if (e.value.isNotEmpty) {
          rawNative.add(MetadataField(label: e.key, value: e.value));
        }
      }
    }

    // ID3 parse (native yoksa veya eksikse)
    final id3Result = _parseId3Full(bytes);
    final id3Map = id3Result.$1;
    final id3Raw = id3Result.$2;

    if (title == 'N/A') title = _nvl(id3Map['title']);
    if (artist == 'N/A') artist = _nvl(id3Map['artist']);
    if (album == 'N/A') album = _nvl(id3Map['album']);
    if (year == 'N/A') year = _nvl(id3Map['year']);
    if (genre == 'N/A') genre = _nvl(id3Map['genre']);
    if (track == 'N/A') track = _nvl(id3Map['track']);
    if (comment == 'N/A') comment = _nvl(id3Map['comment']);
    if (duration == 'N/A' && id3Map['duration'] != null) {
      duration = id3Map['duration']!;
    }

    final rawFields = rawNative.isNotEmpty ? rawNative : id3Raw;

    return [
      MetadataSection(
        title: 'Ses Bilgileri',
        icon: Icons.music_note_rounded,
        color: const Color(0xFF43E97B),
        fields: [
          MetadataField(label: 'Başlık', value: title),
          MetadataField(label: 'Sanatçı', value: artist),
          MetadataField(label: 'Albüm', value: album),
          MetadataField(label: 'Yıl', value: year),
          MetadataField(label: 'Tür / Genre', value: genre),
          MetadataField(label: 'Parça No', value: track),
          MetadataField(label: 'Yorum', value: comment),
          MetadataField(label: 'Süre', value: duration),
          MetadataField(label: 'Bit Hızı', value: bitrate),
          MetadataField(label: 'MIME Türü', value: mimeType),
        ],
      ),
      rawSection('Ham Ses Tag\'leri (${rawFields.length} adet)', rawFields),
    ];
  }

  // Hem parsed map hem tüm ham frame'leri döndürür
  static (Map<String, String>, List<MetadataField>) _parseId3Full(
      Uint8List bytes) {
    final result = <String, String>{};
    final rawFrames = <MetadataField>[];

    // ID3v2
    if (bytes.length > 10 &&
        bytes[0] == 0x49 &&
        bytes[1] == 0x44 &&
        bytes[2] == 0x33) {
      final version = bytes[3];
      final tagSize = ((bytes[6] & 0x7F) << 21) |
          ((bytes[7] & 0x7F) << 14) |
          ((bytes[8] & 0x7F) << 7) |
          (bytes[9] & 0x7F);

      int offset = 10;
      final hSz = version == 2 ? 6 : 10;

      while (offset + hSz < tagSize + 10 && offset + hSz < bytes.length) {
        final frameId = String.fromCharCodes(
            bytes.sublist(offset, offset + (version == 2 ? 3 : 4)));
        if (frameId.trim().isEmpty || frameId[0] == '\x00') break;

        int frameSize;
        if (version == 2) {
          frameSize = (bytes[offset + 3] << 16) |
              (bytes[offset + 4] << 8) |
              bytes[offset + 5];
        } else if (version == 4) {
          frameSize = ((bytes[offset + 4] & 0x7F) << 21) |
              ((bytes[offset + 5] & 0x7F) << 14) |
              ((bytes[offset + 6] & 0x7F) << 7) |
              (bytes[offset + 7] & 0x7F);
        } else {
          frameSize = (bytes[offset + 4] << 24) |
              (bytes[offset + 5] << 16) |
              (bytes[offset + 6] << 8) |
              bytes[offset + 7];
        }

        if (frameSize <= 0 || frameSize > bytes.length) break;
        final dOff = offset + hSz;
        if (dOff + frameSize > bytes.length) break;

        final data = bytes.sublist(dOff, dOff + frameSize);
        final text = _decodeId3(data);
        if (text.isNotEmpty) {
          rawFrames.add(MetadataField(label: frameId, value: text));
        }

        switch (frameId) {
          case 'TIT2':
          case 'TT2':
            result['title'] = text;
            break;
          case 'TPE1':
          case 'TP1':
            result['artist'] = text;
            break;
          case 'TALB':
          case 'TAL':
            result['album'] = text;
            break;
          case 'TYER':
          case 'TDRC':
          case 'TYE':
            result['year'] = text;
            break;
          case 'TCON':
          case 'TCO':
            result['genre'] = _parseGenre(text);
            break;
          case 'TRCK':
          case 'TRK':
            result['track'] = text;
            break;
          case 'COMM':
          case 'COM':
            if (data.length > 4) result['comment'] = _decodeId3(data.sublist(4));
            break;
          case 'TLEN':
          case 'TLE':
            final ms = int.tryParse(text.trim());
            if (ms != null) result['duration'] = _fmtDur(ms);
            break;
        }

        offset = dOff + frameSize;
      }
    }

    // ID3v1 — son 128 byte
    if (bytes.length >= 128) {
      final v1 = bytes.sublist(bytes.length - 128);
      if (v1[0] == 0x54 && v1[1] == 0x41 && v1[2] == 0x47) {
        void add(String key, String val) {
          final t = val.split('\x00').first.trim();
          if (t.isNotEmpty) {
            result.putIfAbsent(key, () => t);
            rawFrames.add(MetadataField(label: 'ID3v1/$key', value: t));
          }
        }
        add('title', latin1.decode(v1.sublist(3, 33)));
        add('artist', latin1.decode(v1.sublist(33, 63)));
        add('album', latin1.decode(v1.sublist(63, 93)));
        add('year', latin1.decode(v1.sublist(93, 97)));
        add('comment', latin1.decode(v1.sublist(97, 127)));
        final gIdx = v1[127];
        if (gIdx < _genres.length) {
          result.putIfAbsent('genre', () => _genres[gIdx]);
          rawFrames
              .add(MetadataField(label: 'ID3v1/genre', value: _genres[gIdx]));
        }
      }
    }

    return (result, rawFrames);
  }

  static String _decodeId3(List<int> data) {
    if (data.isEmpty) return '';
    final enc = data[0];
    final content = data.sublist(1);
    try {
      if (enc == 1 || enc == 2) {
        if (content.length >= 2 && content[0] == 0xFF && content[1] == 0xFE) {
          return _utf16Le(content.sublist(2));
        }
        if (content.length >= 2 && content[0] == 0xFE && content[1] == 0xFF) {
          return _utf16Be(content.sublist(2));
        }
        return _utf16Le(content);
      } else if (enc == 3) {
        return utf8.decode(content, allowMalformed: true);
      } else {
        return latin1.decode(content, allowInvalid: true);
      }
    } catch (_) {
      return latin1.decode(content, allowInvalid: true);
    }
  }

  static String _utf16Le(List<int> b) {
    final chars = <int>[];
    for (int i = 0; i + 1 < b.length; i += 2) {
      final cp = b[i] | (b[i + 1] << 8);
      if (cp == 0) break;
      chars.add(cp);
    }
    return String.fromCharCodes(chars);
  }

  static String _utf16Be(List<int> b) {
    final chars = <int>[];
    for (int i = 0; i + 1 < b.length; i += 2) {
      final cp = (b[i] << 8) | b[i + 1];
      if (cp == 0) break;
      chars.add(cp);
    }
    return String.fromCharCodes(chars);
  }

  static String _parseGenre(String raw) {
    final m = RegExp(r'\((\d+)\)').firstMatch(raw);
    if (m != null) {
      final i = int.tryParse(m.group(1)!);
      if (i != null && i < _genres.length) return _genres[i];
    }
    return raw;
  }

  static String _nvl(String? s) =>
      (s == null || s.trim().isEmpty) ? 'N/A' : s.trim();

  static String _fmtDur(int ms) {
    final s = ms ~/ 1000;
    final m = s ~/ 60;
    final h = m ~/ 60;
    if (h > 0) {
      return '$h:${(m % 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
    }
    return '$m:${(s % 60).toString().padLeft(2, '0')}';
  }

  static String _fmtBitrate(String? bps) {
    final v = int.tryParse(bps ?? '');
    return v == null ? 'N/A' : '${(v / 1000).round()} kbps';
  }

  static const _genres = [
    'Blues', 'Classic Rock', 'Country', 'Dance', 'Disco', 'Funk', 'Grunge',
    'Hip-Hop', 'Jazz', 'Metal', 'New Age', 'Oldies', 'Other', 'Pop', 'R&B',
    'Rap', 'Reggae', 'Rock', 'Techno', 'Industrial', 'Alternative', 'Ska',
    'Death Metal', 'Pranks', 'Soundtrack', 'Euro-Techno', 'Ambient',
    'Trip-Hop', 'Vocal', 'Jazz+Funk', 'Fusion', 'Trance', 'Classical',
    'Instrumental', 'Acid', 'House', 'Game', 'Sound Clip', 'Gospel', 'Noise',
    'AlternRock', 'Bass', 'Soul', 'Punk', 'Space', 'Meditative',
    'Instrumental Pop', 'Instrumental Rock', 'Ethnic', 'Gothic', 'Darkwave',
    'Techno-Industrial', 'Electronic', 'Pop-Folk', 'Eurodance', 'Dream',
    'Southern Rock', 'Comedy', 'Cult', 'Gangsta', 'Top 100', 'Christian Rap',
    'Pop/Funk', 'Jungle', 'Native American', 'Cabaret', 'New Wave',
    'Psychadelic', 'Rave', 'Showtunes', 'Trailer', 'Lo-Fi', 'Tribal',
    'Acid Punk', 'Acid Jazz', 'Polka', 'Retro', 'Musical', 'Rock & Roll',
    'Hard Rock',
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// 6. Video — MethodChannel (MediaMetadataRetriever)
// ─────────────────────────────────────────────────────────────────────────────

class VideoReader {
  static List<MetadataSection> read(Map<String, String>? media) {
    String get(String key) {
      final v = media?[key];
      return (v == null || v.trim().isEmpty) ? 'N/A' : v.trim();
    }

    String duration() {
      final ms = int.tryParse(media?['duration'] ?? '');
      if (ms == null) return 'N/A';
      final s = ms ~/ 1000;
      final m = s ~/ 60;
      final h = m ~/ 60;
      if (h > 0) {
        return '$h:${(m % 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
      }
      return '$m:${(s % 60).toString().padLeft(2, '0')}';
    }

    String resolution() {
      final w = media?['width'];
      final h = media?['height'];
      return (w?.isNotEmpty == true && h?.isNotEmpty == true)
          ? '$w × $h'
          : 'N/A';
    }

    String bitrate() {
      final v = int.tryParse(media?['bitrate'] ?? '');
      return v == null ? 'N/A' : '${(v / 1000).round()} kbps';
    }

    // Ham native alanlar (tümü)
    final rawFields = (media ?? {})
        .entries
        .where((e) => e.value.isNotEmpty)
        .map((e) => MetadataField(label: e.key, value: e.value))
        .toList();

    return [
      MetadataSection(
        title: 'Video Bilgileri',
        icon: Icons.videocam_rounded,
        color: const Color(0xFFA29BFE),
        fields: [
          MetadataField(label: 'Çözünürlük', value: resolution()),
          MetadataField(label: 'Süre', value: duration()),
          MetadataField(label: 'Bit Hızı', value: bitrate()),
          MetadataField(
              label: 'Döndürme',
              value: get('rotation') == 'N/A' ? 'N/A' : '${get("rotation")}°'),
          MetadataField(label: 'MIME Türü', value: get('mimeType')),
          MetadataField(label: 'Başlık', value: get('title')),
          MetadataField(label: 'Sanatçı', value: get('artist')),
          MetadataField(label: 'Albüm', value: get('album')),
          MetadataField(label: 'Parça Sayısı', value: get('numTracks')),
          MetadataField(label: 'Video Kanalı', value: get('hasVideo')),
          MetadataField(label: 'Ses Kanalı', value: get('hasAudio')),
          MetadataField(label: 'Kayıt Tarihi', value: get('date')),
          MetadataField(label: 'Konum', value: get('location')),
          MetadataField(label: 'Yazar', value: get('author')),
          MetadataField(label: 'Besteci', value: get('composer')),
          MetadataField(label: 'Albüm Sanatçısı', value: get('albumArtist')),
          MetadataField(label: 'Disk No', value: get('discNumber')),
        ],
      ),
      rawSection(
        'Ham Media Verileri (${rawFields.length} adet)',
        rawFields.isEmpty
            ? [const MetadataField(label: 'Durum', value: 'Native metadata alınamadı — dosya yolu gerekli')]
            : rawFields,
      ),
    ];
  }
}
