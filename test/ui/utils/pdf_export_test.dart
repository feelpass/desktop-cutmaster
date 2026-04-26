import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  // SheetPainter raster 경로(toByteData PNG)는 host VM에서 동작하지 않아 이 테스트는
  // exportSheetsToPdf E2E를 직접 검증하지 않는다. 대신 `pdf` 패키지가 정상 로드되고
  // 페이지를 추가한 Document가 유효한 PDF 바이트를 만들어내는지(magic %PDF) 확인한다.
  // E2E 검증은 앱 실행으로 수동 진행.
  test('pdf document with one page produces non-empty bytes starting with %PDF',
      () async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (ctx) => pw.Center(child: pw.Text('test')),
      ),
    );
    final bytes = await doc.save();
    expect(bytes.length, greaterThan(100));
    // PDF magic bytes: %PDF
    expect(bytes[0], 0x25); // %
    expect(bytes[1], 0x50); // P
    expect(bytes[2], 0x44); // D
    expect(bytes[3], 0x46); // F
  });
}
