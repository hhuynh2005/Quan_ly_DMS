import 'package:flutter_test/flutter_test.dart';
import 'package:study_docs_app/struct/document_enums.dart';
import 'package:study_docs_app/struct/document_model.dart';
import 'package:study_docs_app/struct/recommendation_service.dart';

/// Helper tạo nhanh 1 Document để test.
Document _doc({
  required String id,
  List<String> tags = const [],
  String title = 'Tài liệu',
  String subjectId = 's1',
  DocumentType type = DocumentType.lecture,
  bool isFavorite = false,
}) {
  return Document(
    id: id,
    title: title,
    subjectId: subjectId,
    documentType: type,
    tags: tags,
    isFavorite: isFavorite,
  );
}

void main() {
  group('RecommendationService.cosineSimilarity', () {
    test('2 tập giống hệt nhau -> xấp xỉ 1.0 (sai số làm tròn float)', () {
      expect(
        RecommendationService.cosineSimilarity({'a', 'b'}, {'a', 'b'}),
        closeTo(1.0, 1e-9),
      );
    });

    test('không có tag chung -> 0.0', () {
      expect(RecommendationService.cosineSimilarity({'a'}, {'b'}), 0.0);
    });

    test('tập rỗng -> 0.0', () {
      expect(RecommendationService.cosineSimilarity({}, {'a'}), 0.0);
      expect(RecommendationService.cosineSimilarity({'a'}, {}), 0.0);
    });

    test('đúng công thức |giao| / (√|A| · √|B|)', () {
      // giao = {a} (1 phần tử), |A| = 2, |B| = 3
      final s = RecommendationService.cosineSimilarity(
        {'a', 'b'},
        {'a', 'c', 'd'},
      );
      expect(s, closeTo(1 / (1.41421356 * 1.7320508), 1e-6));
    });
  });

  group('RecommendationService.similarity', () {
    test('2 tài liệu giống hệt (khác id) -> 1.0', () {
      final a = _doc(id: '1', tags: ['flutter'], title: 'Flutter cơ bản');
      final b = _doc(id: '2', tags: ['flutter'], title: 'Flutter cơ bản');
      expect(RecommendationService.similarity(a, b), 1.0);
    });

    test('so với chính mình -> 1.0', () {
      final a = _doc(id: '1', tags: ['flutter']);
      expect(RecommendationService.similarity(a, a), 1.0);
    });

    test('càng nhiều điểm chung thì điểm càng cao', () {
      final base = _doc(
        id: '0',
        tags: ['flutter', 'dart'],
        title: 'Flutter Dart',
        subjectId: 's1',
      );
      final close = _doc(
        id: '1',
        tags: ['flutter', 'dart'],
        title: 'Flutter Dart nâng cao',
        subjectId: 's1',
      );
      final far = _doc(
        id: '2',
        tags: ['thiết kế'],
        title: 'Thiết kế UI',
        subjectId: 's2',
        type: DocumentType.note,
      );
      expect(
        RecommendationService.similarity(base, close),
        greaterThan(RecommendationService.similarity(base, far)),
      );
    });

    test('chế độ cosine cho tag: điểm nằm trong [0, 1]', () {
      final a = _doc(id: '1', tags: ['flutter', 'dart']);
      final b = _doc(id: '2', tags: ['flutter']);
      final s = RecommendationService.similarity(
        a,
        b,
        tagMetric: TagSimilarityMetric.cosine,
      );
      expect(s, inInclusiveRange(0.0, 1.0));
      expect(s, greaterThan(0.0));
    });

    test('tag chuẩn hoá trước khi so sánh (hoa/thường như nhau)', () {
      final a = _doc(id: '1', tags: ['Flutter']);
      final b = _doc(id: '2', tags: ['flutter']);
      final c = _doc(id: '3', tags: ['firebase']);
      expect(
        RecommendationService.similarity(a, b),
        greaterThan(RecommendationService.similarity(a, c)),
      );
    });
  });

  group('RecommendationService.getRelatedDocuments', () {
    final docs = [
      _doc(
        id: '0',
        tags: ['flutter'],
        title: 'Flutter cơ bản',
        subjectId: 's1',
      ),
      _doc(
        id: '1',
        tags: ['flutter', 'dart'],
        title: 'Flutter nâng cao',
        subjectId: 's1',
      ),
      _doc(
        id: '2',
        tags: ['thiết kế'],
        title: 'Thiết kế',
        subjectId: 's9',
        type: DocumentType.note,
      ),
    ];

    test('loại trừ chính tài liệu gốc', () {
      final related = RecommendationService.getRelatedDocuments(docs[0], docs);
      expect(related.any((r) => r.document.id == '0'), isFalse);
    });

    test('sắp xếp giảm dần theo điểm', () {
      final related = RecommendationService.getRelatedDocuments(docs[0], docs);
      for (var i = 0; i < related.length - 1; i++) {
        expect(related[i].score, greaterThanOrEqualTo(related[i + 1].score));
      }
    });

    test('tài liệu cùng tag và cùng môn xếp đầu', () {
      final related = RecommendationService.getRelatedDocuments(docs[0], docs);
      expect(related.first.document.id, '1');
    });

    test('tôn trọng giới hạn limit', () {
      final related = RecommendationService.getRelatedDocuments(
        docs[0],
        docs,
        limit: 1,
      );
      expect(related.length, 1);
    });
  });

  group('RecommendationService.getRecommendedForUser', () {
    test('ưu tiên tài liệu liên quan tới favorite, loại seed khỏi kết quả', () {
      final docs = [
        _doc(id: '0', tags: ['flutter'], subjectId: 's1', isFavorite: true),
        _doc(id: '1', tags: ['flutter'], subjectId: 's1'),
        _doc(
          id: '2',
          tags: ['nấu ăn'],
          subjectId: 's9',
          type: DocumentType.note,
        ),
      ];
      final recommended = RecommendationService.getRecommendedForUser(docs);
      expect(recommended.first.document.id, '1');
      expect(recommended.any((r) => r.document.id == '0'), isFalse);
    });

    test('không có favorite -> fallback, vẫn trả về gợi ý', () {
      final docs = [
        _doc(id: '0', tags: ['a'], subjectId: 's1'),
        _doc(id: '1', tags: ['b'], subjectId: 's2'),
      ];
      final recommended = RecommendationService.getRecommendedForUser(docs);
      expect(recommended, isNotEmpty);
    });

    test('thư viện rỗng -> danh sách rỗng', () {
      expect(RecommendationService.getRecommendedForUser([]), isEmpty);
    });

    test('tôn trọng giới hạn limit', () {
      final docs = List.generate(
        10,
        (i) => _doc(id: '$i', tags: ['flutter'], subjectId: 's1'),
      );
      final recommended = RecommendationService.getRecommendedForUser(
        docs,
        limit: 3,
      );
      expect(recommended.length, 3);
    });
  });
}
