import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:campusos_mobile/services/document_text_extractor.dart';

void main() {
  test('rejects renamed non-PDF files before parsing', () {
    expect(DocumentTextExtractor.isPdf(Uint8List.fromList([1,2,3,4,5])), false);
    expect(() => DocumentTextExtractor.validatePdf(Uint8List.fromList([1,2,3,4,5])),
      throwsFormatException);
  });
  test('accepts a PDF header within safe bounds', () {
    expect(DocumentTextExtractor.isPdf(Uint8List.fromList([37,80,68,70,45,49])), true);
  });
  test('rejects empty and oversized PDF uploads', () {
    expect(() => DocumentTextExtractor.validatePdf(Uint8List(0)), throwsFormatException);
    expect(() => DocumentTextExtractor.validatePdf(
      Uint8List(DocumentTextExtractor.maximumPdfBytes + 1)), throwsFormatException);
  });
}
