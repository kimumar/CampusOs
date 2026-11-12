import 'dart:typed_data';
import 'package:pdfrx/pdfrx.dart';

/// Small, local-only document imports. Original documents are never persisted.
class DocumentTextExtractor {
  DocumentTextExtractor._();
  static const int maximumPdfBytes = 8 * 1024 * 1024;
  static const int maximumPages = 30;
  static const int maximumTextCharacters = 30000;

  static bool isPdf(Uint8List bytes) => bytes.length >= 5 &&
      bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 &&
      bytes[3] == 0x46 && bytes[4] == 0x2D;

  static void validatePdf(Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > maximumPdfBytes) {
      throw const FormatException('Select a PDF smaller than 8 MB.');
    }
    if (!isPdf(bytes)) {
      throw const FormatException('This file is not a valid PDF.');
    }
  }

  static Future<String> extractPdf(Uint8List bytes) async {
    validatePdf(bytes);
    await pdfrxFlutterInitialize();
    final document = await PdfDocument.openData(bytes);
    try {
      if (document.pages.length > maximumPages) {
        throw const FormatException('This PDF has more than 30 pages. Split it into smaller sections.');
      }
      final result = StringBuffer();
      for (final page in document.pages) {
        final text = (await page.loadText())?.fullText.trim() ?? '';
        if (text.isNotEmpty) result.writeln(text);
        if (result.length > maximumTextCharacters) {
          throw const FormatException('Too much extracted text. Choose a shorter document.');
        }
      }
      final extracted = result.toString().trim();
      if (extracted.isEmpty) {
        throw const FormatException('No selectable text found. This may be a scanned PDF; use photo OCR on the installed app instead.');
      }
      return extracted;
    } finally {
      await document.dispose();
    }
  }
}
