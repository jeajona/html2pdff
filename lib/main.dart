import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';

void main() {
  runApp(const Html2PdfApp());
}

class Html2PdfApp extends StatelessWidget {
  const Html2PdfApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZIP → PDF',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A1A2E),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0F0F1A),
      ),
      home: const HomeScreen(),
    );
  }
}

enum ConvertStatus { idle, picking, extracting, converting, done, error }

class ConvertResult {
  final String htmlFile;
  final String pdfPath;
  final bool success;
  final String? error;
  const ConvertResult({
    required this.htmlFile,
    required this.pdfPath,
    required this.success,
    this.error,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  ConvertStatus _status = ConvertStatus.idle;
  String _statusMsg = '';
  List<ConvertResult> _results = [];
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndConvert() async {
    setState(() {
      _status = ConvertStatus.picking;
      _statusMsg = 'ZIP dosyası seçiliyor…';
      _results = [];
    });

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );

    if (result == null || result.files.single.path == null) {
      setState(() => _status = ConvertStatus.idle);
      return;
    }

    await _processZip(result.files.single.path!);
  }

  Future<void> _processZip(String zipPath) async {
    try {
      setState(() {
        _status = ConvertStatus.extracting;
        _statusMsg = 'ZIP açılıyor…';
      });

      final tmpDir = await getTemporaryDirectory();
      final extractDir = Directory('${tmpDir.path}/html2pdf_extract');
      if (await extractDir.exists()) await extractDir.delete(recursive: true);
      await extractDir.create(recursive: true);

      final bytes = await File(zipPath).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      final List<String> htmlFiles = [];
      for (final file in archive) {
        final outPath = '${extractDir.path}/${file.name}';
        if (file.isFile) {
          final outFile = File(outPath);
          await outFile.create(recursive: true);
          await outFile.writeAsBytes(file.content as List<int>);
          if (file.name.toLowerCase().endsWith('.html') ||
              file.name.toLowerCase().endsWith('.htm')) {
            htmlFiles.add(outPath);
          }
        }
      }

      if (htmlFiles.isEmpty) {
        setState(() {
          _status = ConvertStatus.error;
          _statusMsg = 'ZIP içinde HTML dosyası bulunamadı!';
        });
        return;
      }

      setState(() {
        _status = ConvertStatus.converting;
        _statusMsg = '${htmlFiles.length} HTML dosyası dönüştürülüyor…';
      });

      final outputDir = await getExternalStorageDirectory() ?? tmpDir;
      final pdfOutDir = Directory('${outputDir.path}/HTML2PDF');
      await pdfOutDir.create(recursive: true);

      final List<ConvertResult> results = [];
      for (int i = 0; i < htmlFiles.length; i++) {
        final htmlPath = htmlFiles[i];
        final baseName = htmlPath
            .split('/')
            .last
            .replaceAll(RegExp(r'\.html?$', caseSensitive: false), '');
        final pdfPath = '${pdfOutDir.path}/$baseName.pdf';

        setState(() {
          _statusMsg = 'Dönüştürülüyor (${i + 1}/${htmlFiles.length}): $baseName';
        });

        try {
          await _htmlToPdf(htmlPath, pdfPath, extractDir.path);
          results.add(ConvertResult(
            htmlFile: baseName,
            pdfPath: pdfPath,
            success: true,
          ));
        } catch (e) {
          results.add(ConvertResult(
            htmlFile: baseName,
            pdfPath: pdfPath,
            success: false,
            error: e.toString(),
          ));
        }
      }

      setState(() {
        _status = ConvertStatus.done;
        _statusMsg = '${results.where((r) => r.success).length} PDF oluşturuldu!';
        _results = results;
      });
    } catch (e) {
      setState(() {
        _status = ConvertStatus.error;
        _statusMsg = 'Hata: $e';
      });
    }
  }

  Future<void> _htmlToPdf(String htmlPath, String pdfPath, String baseDir) async {
    String htmlContent;
    try {
      htmlContent = await File(htmlPath).readAsString(encoding: utf8);
    } catch (_) {
      final bytes = await File(htmlPath).readAsBytes();
      htmlContent = latin1.decode(bytes);
    }

    htmlContent = _fixRelativePaths(htmlContent, baseDir);
    final wrappedHtml = _wrapHtml(htmlContent);

    final pdfBytes = await Printing.convertHtml(
      format: PdfPageFormat.a4,
      html: wrappedHtml,
    );

    await File(pdfPath).writeAsBytes(pdfBytes);
  }

  String _wrapHtml(String content) {
    const css = '''
      body{font-family:Arial,sans-serif;font-size:10pt;line-height:1.6;margin:1cm;word-wrap:break-word;}
      table{width:100%;border-collapse:collapse;}
      td,th{border:1px solid #000;padding:4px;word-wrap:break-word;}
      img{max-width:100%;height:auto;}
      pre,code{white-space:pre-wrap;word-wrap:break-word;}
    ''';

    if (content.trim().toLowerCase().startsWith('<!doctype') ||
        content.trim().toLowerCase().startsWith('<html')) {
      return content.replaceFirst(
        RegExp(r'<head[^>]*>', caseSensitive: false),
        '<head><meta charset="UTF-8"><style>$css</style>',
      );
    }

    return '''<!DOCTYPE html>
<html><head><meta charset="UTF-8"><style>$css</style></head>
<body>$content</body></html>''';
  }

  String _fixRelativePaths(String html, String baseDir) {
    return html
        .replaceAllMapped(
          RegExp(r'src="(?!https?://|data:)([^"]+)"', caseSensitive: false),
          (m) => 'src="file://$baseDir/${m[1]}"',
        )
        .replaceAllMapped(
          RegExp(r"src='(?!https?://|data:)([^']+)'", caseSensitive: false),
          (m) => "src='file://$baseDir/${m[1]}'",
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const SizedBox(height: 40),
              _buildDropZone(),
              const SizedBox(height: 24),
              _buildStatusArea(),
              const SizedBox(height: 16),
              if (_results.isNotEmpty) Expanded(child: _buildResultList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6C63FF), Color(0xFFE040FB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.picture_as_pdf, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ZIP → PDF',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5)),
            Text('HTML\'leri PDF\'e dönüştür',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.45), fontSize: 12)),
          ],
        ),
      ],
    );
  }

  Widget _buildDropZone() {
    final bool loading = _status == ConvertStatus.picking ||
        _status == ConvertStatus.extracting ||
        _status == ConvertStatus.converting;

    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, child) =>
          Transform.scale(scale: loading ? _pulseAnim.value : 1.0, child: child),
      child: GestureDetector(
        onTap: loading ? null : _pickAndConvert,
        child: Container(
          height: 200,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: loading
                  ? [const Color(0xFF1F1F3A), const Color(0xFF2A1A4A)]
                  : [const Color(0xFF1A1A35), const Color(0xFF1F1F40)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: loading
                  ? const Color(0xFF6C63FF)
                  : Colors.white.withOpacity(0.08),
              width: loading ? 2 : 1,
            ),
            boxShadow: loading
                ? [BoxShadow(
                    color: const Color(0xFF6C63FF).withOpacity(0.3),
                    blurRadius: 30,
                    spreadRadius: 2)]
                : [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                const SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                      color: Color(0xFF6C63FF), strokeWidth: 3),
                )
              else
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF).withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.folder_zip_outlined,
                      color: Color(0xFF6C63FF), size: 32),
                ),
              const SizedBox(height: 16),
              Text(
                loading ? 'İşleniyor…' : 'ZIP Dosyası Seç',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                loading ? _statusMsg : 'İçindeki HTML\'ler PDF\'e dönüştürülür',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.45), fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusArea() {
    if (_status == ConvertStatus.idle ||
        _status == ConvertStatus.converting ||
        _status == ConvertStatus.extracting) {
      return const SizedBox.shrink();
    }

    Color chipColor;
    IconData icon;
    if (_status == ConvertStatus.done) {
      chipColor = const Color(0xFF00C853);
      icon = Icons.check_circle_outline;
    } else {
      chipColor = const Color(0xFFFF5252);
      icon = Icons.error_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: chipColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: chipColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
              child: Text(_statusMsg,
                  style: TextStyle(color: chipColor, fontSize: 13))),
          TextButton(
            onPressed: () => setState(() {
              _status = ConvertStatus.idle;
              _results = [];
            }),
            child: const Text('Temizle'),
          ),
        ],
      ),
    );
  }

  Widget _buildResultList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('OLUŞTURULAN PDF\'LER',
            style: TextStyle(
                color: Colors.white.withOpacity(0.35),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5)),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.separated(
            itemCount: _results.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _buildResultCard(_results[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildResultCard(ConvertResult r) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: r.success ? const Color(0xFF1A2E1A) : const Color(0xFF2E1A1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: r.success
              ? const Color(0xFF00C853).withOpacity(0.3)
              : const Color(0xFFFF5252).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            r.success ? Icons.picture_as_pdf : Icons.error_outline,
            color: r.success ? const Color(0xFF00C853) : const Color(0xFFFF5252),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.htmlFile,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                if (r.error != null)
                  Text(r.error!,
                      style: const TextStyle(
                          color: Color(0xFFFF5252), fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (r.success) ...[
            IconButton(
              icon: const Icon(Icons.open_in_new,
                  color: Colors.white54, size: 20),
              onPressed: () => OpenFile.open(r.pdfPath),
              tooltip: 'Aç',
            ),
            IconButton(
              icon: const Icon(Icons.share, color: Colors.white54, size: 20),
              onPressed: () => Share.shareXFiles([XFile(r.pdfPath)]),
              tooltip: 'Paylaş',
            ),
          ],
        ],
      ),
    );
  }
}
