import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Veri Modelleri
// ─────────────────────────────────────────────────────────────────────────────

class MetadataSection {
  final String title;
  final IconData icon;
  final Color color;
  final List<MetadataField> fields;

  const MetadataSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.fields,
  });
}

class MetadataField {
  final String label;
  final String value;

  const MetadataField({required this.label, required this.value});
}

// ─────────────────────────────────────────────────────────────────────────────
// Desteklenen Dosya Türleri
// ─────────────────────────────────────────────────────────────────────────────

enum FileKind { image, pdf, zip, docx, audio, video, unknown }

extension FileKindX on FileKind {
  IconData get icon => switch (this) {
        FileKind.image => Icons.image_rounded,
        FileKind.pdf => Icons.picture_as_pdf_rounded,
        FileKind.zip => Icons.folder_zip_rounded,
        FileKind.docx => Icons.description_rounded,
        FileKind.audio => Icons.music_note_rounded,
        FileKind.video => Icons.videocam_rounded,
        FileKind.unknown => Icons.insert_drive_file_rounded,
      };

  Color get color => switch (this) {
        FileKind.image => const Color(0xFF6C63FF),
        FileKind.pdf => const Color(0xFFFF6584),
        FileKind.zip => const Color(0xFFFA8231),
        FileKind.docx => const Color(0xFF00D4FF),
        FileKind.audio => const Color(0xFF43E97B),
        FileKind.video => const Color(0xFFA29BFE),
        FileKind.unknown => const Color(0xFFB2BEC3),
      };

  String get label => switch (this) {
        FileKind.image => 'Görüntü',
        FileKind.pdf => 'PDF',
        FileKind.zip => 'ZIP / Arşiv',
        FileKind.docx => 'Office Belgesi',
        FileKind.audio => 'Ses Dosyası',
        FileKind.video => 'Video',
        FileKind.unknown => 'Bilinmeyen',
      };
}

FileKind detectFileKind(String extension) {
  switch (extension.toLowerCase()) {
    case 'jpg':
    case 'jpeg':
    case 'png':
    case 'gif':
    case 'bmp':
    case 'webp':
    case 'tiff':
    case 'tif':
    case 'heic':
    case 'heif':
      return FileKind.image;
    case 'pdf':
      return FileKind.pdf;
    case 'zip':
    case 'rar':
    case '7z':
    case 'tar':
    case 'gz':
      return FileKind.zip;
    case 'docx':
    case 'xlsx':
    case 'pptx':
    case 'odt':
      return FileKind.docx;
    case 'mp3':
    case 'flac':
    case 'ogg':
    case 'aac':
    case 'wav':
    case 'm4a':
    case 'wma':
      return FileKind.audio;
    case 'mp4':
    case 'mov':
    case 'avi':
    case 'mkv':
    case 'webm':
    case 'm4v':
    case '3gp':
      return FileKind.video;
    default:
      return FileKind.unknown;
  }
}
