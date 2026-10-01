import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'cleaner.dart';
import 'injector.dart';
import 'models.dart';
import 'readers.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  // ── Dosya durumu ────────────────────────────────────────────────────────────
  File? _selectedImage;
  Uint8List? _currentBytes;
  FileKind _fileKind = FileKind.unknown;
  String _fileName = '';

  // ── UI durumu ───────────────────────────────────────────────────────────────
  bool _isLoading = false;
  bool _isStripping = false;
  bool _isInjecting = false;
  List<MetadataSection> _sections = [];
  String? _errorMessage;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;
  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  // ── Dosya Seçme ─────────────────────────────────────────────────────────────
  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'tiff', 'tif', 'heic', 'heif',
          'pdf', 'docx', 'xlsx', 'pptx', 'odt',
          'zip', 'gz', 'tar',
          'mp3', 'flac', 'ogg', 'aac', 'wav', 'm4a', 'wma',
          'mp4', 'mov', 'avi', 'mkv', 'webm', 'm4v', '3gp',
        ],
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final pf = result.files.first;
      final bytes = pf.bytes;
      if (bytes == null) {
        _showSnackBar('Dosya okunamadı — lütfen tekrar deneyin.');
        return;
      }

      final ext = p.extension(pf.name).replaceFirst('.', '');
      final kind = detectFileKind(ext);

      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _sections = [];
        _fileKind = kind;
        _fileName = pf.name;
        _currentBytes = bytes;
        _selectedImage = (kind == FileKind.image && pf.path != null)
            ? File(pf.path!)
            : null;
      });

      await _extractMetadata(
          bytes: bytes, fileName: pf.name, filePath: pf.path, kind: kind);
    } catch (e) {
      if (mounted) _showSnackBar('Dosya seçilirken hata: ${e.toString()}');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _extractMetadata({
    required Uint8List bytes,
    required String fileName,
    required String? filePath,
    required FileKind kind,
  }) async {
    try {
      final sections = await MetadataDispatcher.read(
        bytes: bytes,
        fileName: fileName,
        filePath: filePath,
        kind: kind,
      );
      if (!mounted) return;
      setState(() {
        _sections = sections;
        _isLoading = false;
      });
      _fadeCtrl.forward(from: 0);
      _slideCtrl.forward(from: 0);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Metadata okunamadı: ${e.toString()}';
      });
    }
  }

  // ── Metadata Silme ──────────────────────────────────────────────────────────
  void _showCleanerSheet() {
    if (_currentBytes == null) return;
    final ext = p.extension(_fileName).replaceFirst('.', '').toLowerCase();
    final willStrip =
        MetadataCleaner.whatWillBeStripped(_fileKind, ext);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CleanerSheet(
        fileName: _fileName,
        fileKind: _fileKind,
        fileSize: _currentBytes!.length,
        willStrip: willStrip,
        isStripping: _isStripping,
        onConfirm: () {
          Navigator.pop(context);
          _stripAndSave();
        },
      ),
    );
  }

  Future<void> _stripAndSave() async {
    if (_currentBytes == null) return;
    setState(() => _isStripping = true);

    final result = await CleanAndSaveService.run(
      bytes: _currentBytes!,
      fileName: _fileName,
      kind: _fileKind,
    );

    if (!mounted) return;
    setState(() => _isStripping = false);

    switch (result.status) {
      case CleanStatus.success:
        _showSnackBar(
          '✅ Kaydedildi — ${_fmtSize(result.cleanedSize ?? 0)}',
          success: true,
        );
      case CleanStatus.cancelled:
        _showSnackBar('Kaydetme iptal edildi.');
      case CleanStatus.unsupported:
        _showSnackBar(
            '⚠️ Bu format için metadata silme henüz desteklenmiyor.');
      case CleanStatus.error:
        _showSnackBar('Hata: ${result.error}');
    }
  }

  // ── Sahte Metadata Ekleme ────────────────────────────────────────────────────
  void _showInjectorSheet() {
    if (_currentBytes == null) return;
    final ext = p.extension(_fileName).replaceFirst('.', '').toLowerCase();
    final willInject = MetadataInjector.whatWillBeInjected(_fileKind, ext);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InjectorSheet(
        fileName:   _fileName,
        fileKind:   _fileKind,
        fileSize:   _currentBytes!.length,
        willInject: willInject,
        onConfirm:  (fake) {
          Navigator.pop(context);
          _injectAndSave(fake);
        },
      ),
    );
  }

  Future<void> _injectAndSave(FakeMetadata fake) async {
    if (_currentBytes == null) return;
    setState(() => _isInjecting = true);

    final result = await InjectAndSaveService.run(
      bytes:    _currentBytes!,
      fileName: _fileName,
      kind:     _fileKind,
      fake:     fake,
    );

    if (!mounted) return;
    setState(() => _isInjecting = false);

    switch (result.status) {
      case CleanStatus.success:
        _showSnackBar(
          '🎭 Kaydedildi — ${_fmtSize(result.cleanedSize ?? 0)}',
          success: true,
        );
      case CleanStatus.cancelled:
        _showSnackBar('Kaydetme iptal edildi.');
      case CleanStatus.unsupported:
        _showSnackBar('⚠️ Bu format için metadata ekleme desteklenmiyor.');
      case CleanStatus.error:
        _showSnackBar('Hata: ${result.error}');
    }
  }

  void _showSnackBar(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success
          ? const Color(0xFF43E97B).withValues(alpha: 0.9)
          : Theme.of(context).colorScheme.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  String _fmtSize(int b) {
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  // ── Build ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final hasFile = _fileName.isNotEmpty && _sections.isNotEmpty;

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 0, 20, hasFile ? 170 : 40),
              child: Column(children: [
                _buildPickButton(),
                const SizedBox(height: 24),
                _buildPreview(),
                const SizedBox(height: 24),
                _buildContent(),
              ]),
            ),
          ),
        ],
      ),

      // ── FAB: İki aksiyon (sahte ekle + sil) ────────────────────────────────
      floatingActionButton: AnimatedSlide(
        offset: hasFile ? Offset.zero : const Offset(0, 2),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: hasFile ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Sahte Metadata FAB
              _isInjecting
                  ? FloatingActionButton.extended(
                      heroTag: 'inject_loading',
                      onPressed: null,
                      backgroundColor: const Color(0xFF2D3436),
                      icon: const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      ),
                      label: const Text('Ekleniyor…',
                          style: TextStyle(color: Colors.white)),
                    )
                  : FloatingActionButton.extended(
                      heroTag: 'inject',
                      onPressed: _showInjectorSheet,
                      backgroundColor: const Color(0xFF6C63FF),
                      icon: const Icon(Icons.auto_fix_high_rounded,
                          color: Colors.white),
                      label: const Text(
                        'Sahte Metadata',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
              const SizedBox(height: 12),
              // Metadatayı Sil FAB
              _isStripping
                  ? FloatingActionButton.extended(
                      heroTag: 'strip_loading',
                      onPressed: null,
                      backgroundColor: const Color(0xFF2D3436),
                      icon: const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      ),
                      label: const Text('Temizleniyor…',
                          style: TextStyle(color: Colors.white)),
                    )
                  : FloatingActionButton.extended(
                      heroTag: 'strip',
                      onPressed: _showCleanerSheet,
                      backgroundColor: const Color(0xFFFF6584),
                      icon: const Icon(Icons.auto_delete_rounded,
                          color: Colors.white),
                      label: const Text(
                        'Metadatayı Sil',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  // ── AppBar ──────────────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 110,
      pinned: true,
      backgroundColor: const Color(0xFF0F0F1A),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        title: Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF00D4FF)]),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.manage_search_rounded,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          const Text('Metadata Reader',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 20)),
        ]),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A1A2E), Color(0xFF0F0F1A)],
            ),
          ),
        ),
      ),
    );
  }

  // ── Dosya Seç Butonu ────────────────────────────────────────────────────────
  Widget _buildPickButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _pickFile,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _isLoading
                ? [Colors.grey.shade700, Colors.grey.shade800]
                : [const Color(0xFF6C63FF), const Color(0xFF00D4FF)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: _isLoading
              ? []
              : [
                  BoxShadow(
                    color:
                        const Color(0xFF6C63FF).withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  )
                ],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(
            _isLoading
                ? Icons.hourglass_top_rounded
                : Icons.file_open_rounded,
            color: Colors.white,
            size: 21,
          ),
          const SizedBox(width: 10),
          Text(
            _isLoading ? 'Okunuyor...' : 'Dosya Seç',
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
                letterSpacing: 0.4),
          ),
        ]),
      ),
    );
  }

  // ── Önizleme ────────────────────────────────────────────────────────────────
  Widget _buildPreview() {
    final hasFile = _selectedImage != null ||
        (_fileName.isNotEmpty && _fileKind != FileKind.unknown);
    if (!hasFile && !_isLoading) return const SizedBox.shrink();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: _fileKind.color.withValues(alpha: 0.5), width: 2),
        boxShadow: [
          BoxShadow(
            color: _fileKind.color.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: _isLoading
            ? Container(
                color: const Color(0xFF1A1A2E),
                child: const Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFF6C63FF), strokeWidth: 3),
                ),
              )
            : _selectedImage != null
                ? Image.file(_selectedImage!, fit: BoxFit.cover,
                    width: double.infinity)
                : _fileIconPreview(),
      ),
    );
  }

  Widget _fileIconPreview() {
    return Container(
      color: const Color(0xFF1A1A2E),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: _fileKind.color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(_fileKind.icon, color: _fileKind.color, size: 36),
        ),
        const SizedBox(height: 12),
        Text(_fileKind.label,
            style: TextStyle(
                color: _fileKind.color,
                fontWeight: FontWeight.w700,
                fontSize: 13)),
        const SizedBox(height: 4),
        Text(
          _fileName,
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ]),
    );
  }

  // ── İçerik ──────────────────────────────────────────────────────────────────
  Widget _buildContent() {
    if (_isLoading) return const SizedBox.shrink();

    if (_errorMessage != null) {
      return _infoCard(Icons.error_outline_rounded, 'Hata', _errorMessage!,
          color: const Color(0xFFFF6584));
    }

    if (_fileName.isEmpty) return _emptyState();

    if (_sections.isEmpty) {
      return _infoCard(Icons.info_outline_rounded, 'Bilgi Bulunamadı',
          'Bu dosyadan metadata okunamadı.');
    }

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Column(
          children: _sections.map(_buildSectionCard).toList(),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 28),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              const Color(0xFF6C63FF).withValues(alpha: 0.2),
              const Color(0xFF00D4FF).withValues(alpha: 0.2),
            ]),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Icon(Icons.find_in_page_rounded,
              color: Color(0xFF6C63FF), size: 40),
        ),
        const SizedBox(height: 20),
        const Text('Dosya Seçilmedi',
            style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Text(
          'Desteklenen formatlar:\nGörüntü (JPEG, PNG, WEBP…) • PDF • ZIP\n'
          'DOCX / XLSX / PPTX • MP3 • MP4 / Video',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 13,
              height: 1.6),
        ),
      ]),
    );
  }

  Widget _infoCard(IconData icon, String title, String sub,
      {Color color = const Color(0xFF6C63FF)}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 36),
        const SizedBox(height: 12),
        Text(title,
            style: const TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(sub,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
      ]),
    );
  }

  // ── Seksiyon Kartı ──────────────────────────────────────────────────────────
  Widget _buildSectionCard(MetadataSection s) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Başlık
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: s.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(s.icon, color: s.color, size: 17),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(s.title,
                    style: TextStyle(
                        color: s.color,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        letterSpacing: 0.2)),
              ),
            ]),
          ),
          Divider(
              height: 1,
              thickness: 1,
              color: Colors.white.withValues(alpha: 0.06)),

          // Alanlar
          ...s.fields.asMap().entries.map((entry) {
            final idx = entry.key;
            final f = entry.value;
            final isLast = idx == s.fields.length - 1;
            return Column(children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 130,
                        child: Text(f.label,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500)),
                      ),
                      Expanded(
                        child: Text(f.value,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                color: f.value == 'N/A'
                                    ? Colors.white.withValues(alpha: 0.22)
                                    : Colors.white,
                                fontSize: 12.5,
                                fontWeight: f.value == 'N/A'
                                    ? FontWeight.w400
                                    : FontWeight.w600)),
                      ),
                    ]),
              ),
              if (!isLast)
                Divider(
                    height: 1,
                    thickness: 1,
                    indent: 16,
                    endIndent: 16,
                    color: Colors.white.withValues(alpha: 0.04)),
            ]);
          }),
          const SizedBox(height: 4),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CleanerSheet — Metadata silme onay bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _CleanerSheet extends StatelessWidget {
  final String fileName;
  final FileKind fileKind;
  final int fileSize;
  final List<String> willStrip;
  final bool isStripping;
  final VoidCallback onConfirm;

  const _CleanerSheet({
    required this.fileName,
    required this.fileKind,
    required this.fileSize,
    required this.willStrip,
    required this.isStripping,
    required this.onConfirm,
  });

  String _fmtSize(int b) {
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final unsupported = willStrip.length == 1 &&
        willStrip.first.contains('desteklenmiyor');

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6584).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.auto_delete_rounded,
                    color: Color(0xFFFF6584), size: 22),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Metadata\'yı Sil ve Kaydet',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800)),
                      SizedBox(height: 3),
                      Text('Bu işlem geri alınamaz',
                          style: TextStyle(
                              color: Color(0xFFFF6584), fontSize: 12)),
                    ]),
              ),
            ]),
          ),

          Divider(height: 1, color: Colors.white.withValues(alpha: 0.07)),

          // Dosya bilgisi
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: fileKind.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(fileKind.icon, color: fileKind.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fileName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(_fmtSize(fileSize),
                          style: TextStyle(
                              color:
                                  Colors.white.withValues(alpha: 0.5),
                              fontSize: 12)),
                    ]),
              ),
            ]),
          ),

          Divider(height: 1, color: Colors.white.withValues(alpha: 0.07)),

          // Silinecekler listesi
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
            child: Text(
              unsupported ? 'Uyarı' : 'Silinecek Metadata',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8),
            ),
          ),
          ...willStrip.map((item) => Padding(
                padding:
                    const EdgeInsets.fromLTRB(20, 4, 20, 4),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        unsupported
                            ? Icons.warning_amber_rounded
                            : Icons.remove_circle_outline_rounded,
                        color: unsupported
                            ? Colors.orange
                            : const Color(0xFFFF6584),
                        size: 14,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(item,
                            style: TextStyle(
                                color: Colors.white
                                    .withValues(alpha: 0.8),
                                fontSize: 13)),
                      ),
                    ]),
              )),

          const SizedBox(height: 10),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.07)),

          // Butonlar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Row(children: [
              // İptal
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.2)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('İptal',
                      style:
                          TextStyle(color: Colors.white, fontSize: 14)),
                ),
              ),
              const SizedBox(width: 12),
              // Temizle ve Kaydet
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: unsupported ? null : onConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6584),
                    disabledBackgroundColor:
                        Colors.grey.withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.save_alt_rounded,
                            color: Colors.white, size: 17),
                        const SizedBox(width: 8),
                        Text(
                          unsupported
                              ? 'Desteklenmiyor'
                              : 'Temizle ve Kaydet',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700),
                        ),
                      ]),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _InjectorSheet — Sahte metadata ekleme bottom sheet (StatefulWidget)
// ─────────────────────────────────────────────────────────────────────────────

class _InjectorSheet extends StatefulWidget {
  final String fileName;
  final FileKind fileKind;
  final int fileSize;
  final List<String> willInject;
  final void Function(FakeMetadata) onConfirm;

  const _InjectorSheet({
    required this.fileName,
    required this.fileKind,
    required this.fileSize,
    required this.willInject,
    required this.onConfirm,
  });

  @override
  State<_InjectorSheet> createState() => _InjectorSheetState();
}

class _InjectorSheetState extends State<_InjectorSheet> {
  FakeMetadata _fake = FakeMetadata.generate();

  void _regenerate() => setState(() => _fake = FakeMetadata.generate());

  String _fmtSize(int b) {
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final unsupported = widget.willInject.length == 1 &&
        widget.willInject.first.contains('desteklenmiyor');

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Başlık ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.auto_fix_high_rounded,
                    color: Color(0xFF6C63FF), size: 22),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sahte Metadata Ekle ve Kaydet',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800)),
                    SizedBox(height: 3),
                    Text('Rastgele üretilmiş sahte veriler enjekte edilir',
                        style:
                            TextStyle(color: Color(0xFF6C63FF), fontSize: 11)),
                  ],
                ),
              ),
            ]),
          ),

          Divider(height: 1, color: Colors.white.withValues(alpha: 0.07)),

          // ── Dosya bilgisi ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: widget.fileKind.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(widget.fileKind.icon,
                    color: widget.fileKind.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.fileName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(_fmtSize(widget.fileSize),
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 12)),
                  ],
                ),
              ),
            ]),
          ),

          Divider(height: 1, color: Colors.white.withValues(alpha: 0.07)),

          // ── Önizleme ────────────────────────────────────────────────────
          if (!unsupported) ..._previewRows(),
          if (!unsupported)
            Divider(height: 1, color: Colors.white.withValues(alpha: 0.07)),

          // ── Eklenecekler listesi ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
            child: Text(
              unsupported ? 'Uyarı' : 'Eklenecek Sahte Metadata',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8),
            ),
          ),
          ...widget.willInject.map((item) => Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      unsupported
                          ? Icons.warning_amber_rounded
                          : Icons.add_circle_outline_rounded,
                      color: unsupported
                          ? Colors.orange
                          : const Color(0xFF6C63FF),
                      size: 14,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(item,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 13)),
                    ),
                  ],
                ),
              )),

          const SizedBox(height: 10),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.07)),

          // ── Butonlar ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Row(children: [
              if (!unsupported)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _regenerate,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color:
                              const Color(0xFF6C63FF).withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    icon: const Icon(Icons.refresh_rounded,
                        color: Color(0xFF6C63FF), size: 16),
                    label: const Text('Yenile',
                        style: TextStyle(
                            color: Color(0xFF6C63FF), fontSize: 13)),
                  ),
                ),
              if (!unsupported) const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.2)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: const Text('İptal',
                      style: TextStyle(color: Colors.white, fontSize: 14)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed:
                      unsupported ? null : () => widget.onConfirm(_fake),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    disabledBackgroundColor:
                        Colors.grey.withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.save_alt_rounded,
                          color: Colors.white, size: 17),
                      const SizedBox(width: 8),
                      Text(
                        unsupported ? 'Desteklenmiyor' : 'Ekle ve Kaydet',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  List<Widget> _previewRows() {
    final rows = [
      ('Kamera',  '${_fake.cameraMake} ${_fake.cameraModel}'),
      ('Yazılım', _fake.software),
      ('Konum',
          '${_fake.cityName} (${_fake.latitude.toStringAsFixed(4)}°, '
          '${_fake.longitude.toStringAsFixed(4)}°)'),
      ('Tarih',   _fake.dateTimeDisplay),
      ('Yazar',   _fake.docAuthor),
      ('Şarkı',   '${_fake.songTitle} — ${_fake.songArtist}'),
    ];
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
        child: Text(
          'OLUŞTURULAN VERİ ÖNİZLEMESİ',
          style: TextStyle(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.7),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0),
        ),
      ),
      Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        decoration: BoxDecoration(
          color: const Color(0xFF6C63FF).withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.15)),
        ),
        child: Column(
          children: rows.asMap().entries.map((e) {
            final isLast = e.key == rows.length - 1;
            return Column(children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 70,
                      child: Text(e.value.$1,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600)),
                    ),
                    Expanded(
                      child: Text(e.value.$2,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Divider(
                    height: 1,
                    thickness: 1,
                    indent: 14,
                    endIndent: 14,
                    color: Colors.white.withValues(alpha: 0.05)),
            ]);
          }).toList(),
        ),
      ),
    ];
  }
}
