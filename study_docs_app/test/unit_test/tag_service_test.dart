import 'package:flutter_test/flutter_test.dart';
import 'package:study_docs_app/struct/document_enums.dart';
import 'package:study_docs_app/struct/document_model.dart';
import 'package:study_docs_app/struct/tag_service.dart';

/// Helper tạo nhanh 1 Document để test.
Document _doc({
  required String id,
  List<String> tags = const [],
  String title = 'Bài giảng Flutter',
  String description = '',
  String subjectId = 's1',
  DocumentType type = DocumentType.lecture,
}) {
  return Document(
    id: id,
    title: title,
    description: description,
    subjectId: subjectId,
    documentType: type,
    tags: tags,
  );
}

void main() {
  group('TagService.normalizeTag', () {
    test('cắt khoảng trắng, viết thường, gộp khoảng trắng thừa', () {
      expect(
        TagService.normalizeTag('  Machine  Learning '),
        'machine learning',
      );
    });

    test('chuỗi toàn khoảng trắng -> rỗng', () {
      expect(TagService.normalizeTag('   '), isEmpty);
    });
  });

  group('TagService.normalizeTags', () {
    test('loại trùng lặp (không phân biệt hoa thường), giữ thứ tự', () {
      expect(
        TagService.normalizeTags(['AI', 'ai', ' Flutter ', 'flutter', '']),
        ['ai', 'flutter'],
      );
    });
  });

  group('TagService.parseTagsInput', () {
    test('tách chuỗi phân cách dấu phẩy và chuẩn hoá', () {
      expect(TagService.parseTagsInput('TH1, Flutter,  flutter ,'), [
        'th1',
        'flutter',
      ]);
    });

    test('chuỗi rỗng -> danh sách rỗng', () {
      expect(TagService.parseTagsInput(''), isEmpty);
    });
  });

  group('TagService.tagUsage', () {
    test('đếm số tài liệu dùng mỗi tag (gộp hoa thường)', () {
      final docs = [
        _doc(id: '1', tags: ['flutter', 'mobile']),
        _doc(id: '2', tags: ['Flutter']),
      ];
      final usage = TagService.tagUsage(docs);
      expect(usage['flutter'], 2);
      expect(usage['mobile'], 1);
    });
  });

  group('TagService.suggestTags', () {
    final docs = [
      _doc(id: '1', tags: ['flutter', 'mobile']),
      _doc(id: '2', tags: ['flutter', 'dart']),
      _doc(id: '3', tags: ['firebase']),
    ];

    test('gợi ý theo tiền tố, ưu tiên tag dùng nhiều nhất', () {
      final suggestions = TagService.suggestTags(docs, 'f');
      expect(suggestions.first, 'flutter');
      expect(suggestions, contains('firebase'));
    });

    test('tiền tố rỗng -> không gợi ý', () {
      expect(TagService.suggestTags(docs, ''), isEmpty);
    });

    test('không có tag nào khớp tiền tố -> rỗng', () {
      expect(TagService.suggestTags(docs, 'xyz'), isEmpty);
    });

    test('giới hạn số lượng theo limit', () {
      final suggestions = TagService.suggestTags(docs, 'f', limit: 1);
      expect(suggestions.length, 1);
    });
  });

  group('TagService.extractCandidateTags', () {
    test('trích từ khoá tần suất cao, bỏ stopword và từ ngắn', () {
      final doc = _doc(
        id: '1',
        title: 'Bài giảng Flutter cơ bản',
        description: 'Flutter là framework của Google. Học Flutter qua ví dụ Flutter thực tế.',
      );
      final candidates = TagService.extractCandidateTags(doc);
      expect(candidates.first, 'flutter');
      expect(candidates, isNot(contains('là')));
      expect(candidates, isNot(contains('của')));
    });

    test('giới hạn số lượng theo limit', () {
      final doc = _doc(
        id: '1',
        title: 'Một hai ba bốn năm sáu bảy',
        description: 'tám chín mười',
      );
      expect(TagService.extractCandidateTags(doc, limit: 3).length, 3);
    });
  });

  group('TagService.renameTag / deleteTag', () {
    final docs = [
      _doc(id: '1', tags: ['AI', 'ml']),
      _doc(id: '2', tags: ['ai']),
    ];

    test('renameTag: gộp tag trên toàn bộ tài liệu', () {
      final renamed = TagService.renameTag(docs, 'AI', 'trí tuệ nhân tạo');
      expect(renamed[0].tags, contains('trí tuệ nhân tạo'));
      expect(renamed[1].tags, contains('trí tuệ nhân tạo'));
      expect(renamed.every((d) => !d.tags.contains('ai')), isTrue);
    });

    test('deleteTag: xoá tag khỏi mọi tài liệu', () {
      final cleaned = TagService.deleteTag(docs, 'ml');
      expect(cleaned[0].tags, isNot(contains('ml')));
      expect(cleaned[1].tags, ['ai']);
    });
  });
}
