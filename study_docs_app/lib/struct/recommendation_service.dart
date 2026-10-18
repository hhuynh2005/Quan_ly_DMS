import 'dart:math';

import 'document_model.dart';
import 'tag_service.dart';

/// Một tài liệu kèm điểm gợi ý (0.0 - 1.0, càng cao càng liên quan).
class ScoredDocument {
  final Document document;
  final double score;
  const ScoredDocument(this.document, this.score);
}

/// Độ đo tương đồng dùng cho tập tag của 2 tài liệu.
enum TagSimilarityMetric {
  /// Jaccard: |A∩B| / |A∪B| — độ đo chuẩn cho tập hợp tag rời rạc.
  jaccard,

  /// Cosine: |A∩B| / (√|A| · √|B|) — xem mỗi tập tag là một vector nhị phân
  /// trên từ vựng tag, đo cosin góc giữa 2 vector.
  cosine,
}

/// Thuật toán gợi ý tài liệu theo nội dung (content-based filtering).
///
/// Ý tưởng: tài liệu giống nhau nếu có tag chung, cùng môn học,
/// cùng loại tài liệu và tiêu đề có từ khoá chung.
/// Mỗi yếu tố có trọng số riêng, tổng điểm nằm trong [0, 1].
/// Chạy offline hoàn toàn, không cần server hay thư viện ML ngoài.
class RecommendationService {
  RecommendationService._();

  // Trọng số từng yếu tố (tổng = 1.0). Tag là tín hiệu mạnh nhất.
  static const double wTags = 0.50;
  static const double wSubject = 0.25;
  static const double wType = 0.15;
  static const double wTitle = 0.10;

  /// Độ tương đồng Jaccard giữa 2 tập hợp: |giao| / |hợp|.
  /// = 1.0 khi 2 tập giống hệt, = 0.0 khi không có phần tử chung.
  static double _jaccard(Set<String> a, Set<String> b) {
    if (a.isEmpty || b.isEmpty) return 0.0;
    final intersection = a.intersection(b).length;
    final union = a.union(b).length;
    return union == 0 ? 0.0 : intersection / union;
  }

  /// Độ tương đồng Cosine giữa 2 tập tag.
  ///
  /// Mỗi tập được xem là một vector nhị phân trên từ vựng tag
  /// (1 = tag có mặt, 0 = không). Vì vector nhị phân nên:
  /// cosine(A, B) = |A∩B| / (√|A| · √|B|).
  /// = 1.0 khi 2 tập giống hệt, = 0.0 khi không có tag chung.
  static double cosineSimilarity(Set<String> a, Set<String> b) {
    if (a.isEmpty || b.isEmpty) return 0.0;
    final intersection = a.intersection(b).length;
    final denominator = sqrt(a.length) * sqrt(b.length);
    return denominator == 0 ? 0.0 : intersection / denominator;
  }

  /// Tách tiêu đề thành tập từ khoá (bỏ từ ngắn <= 2 ký tự).
  static Set<String> _titleTokens(Document doc) {
    return doc.title
        .toLowerCase()
        .split(RegExp(r'[^a-zà-ỹ0-9]+'))
        .where((w) => w.length > 2)
        .toSet();
  }

  /// Điểm tương đồng 0..1 giữa 2 tài liệu.
  ///
  /// [tagMetric] chọn độ đo cho thành phần tag: [TagSimilarityMetric.jaccard]
  /// (mặc định) hoặc [TagSimilarityMetric.cosine].
  static double similarity(
    Document a,
    Document b, {
    TagSimilarityMetric tagMetric = TagSimilarityMetric.jaccard,
  }) {
    if (a.id == b.id) return 1.0;

    final tagsA = TagService.normalizeTags(a.tags).toSet();
    final tagsB = TagService.normalizeTags(b.tags).toSet();
    final tagScore = switch (tagMetric) {
      TagSimilarityMetric.jaccard => _jaccard(tagsA, tagsB),
      TagSimilarityMetric.cosine => cosineSimilarity(tagsA, tagsB),
    };
    final subjectScore = a.subjectId.isNotEmpty && a.subjectId == b.subjectId
        ? 1.0
        : 0.0;
    final typeScore = a.documentType == b.documentType ? 1.0 : 0.0;
    final titleScore = _jaccard(_titleTokens(a), _titleTokens(b));

    return wTags * tagScore +
        wSubject * subjectScore +
        wType * typeScore +
        wTitle * titleScore;
  }

  /// "Tài liệu liên quan": top [limit] tài liệu giống [doc] nhất,
  /// loại trừ chính nó. Dùng ở màn hình chi tiết tài liệu.
  static List<ScoredDocument> getRelatedDocuments(
    Document doc,
    List<Document> all, {
    int limit = 5,
  }) {
    final scored = <ScoredDocument>[];
    for (final other in all) {
      if (other.id == doc.id) continue;
      final score = similarity(doc, other);
      if (score > 0) scored.add(ScoredDocument(other, score));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(limit).toList();
  }

  /// "Gợi ý cho bạn": cộng dồn điểm liên quan từ các tài liệu seed.
  /// Seed = tài liệu đã đánh dấu yêu thích; nếu chưa có favorite nào
  /// thì dùng toàn bộ thư viện làm seed. Tài liệu seed không bao giờ
  /// xuất hiện trong kết quả. Dùng ở trang chủ/dashboard.
  ///
  /// Nếu thư viện quá ít dữ liệu để tính điểm, fallback về
  /// danh sách tài liệu mới sửa gần nhất.
  static List<ScoredDocument> getRecommendedForUser(
    List<Document> all, {
    int limit = 8,
  }) {
    if (all.isEmpty) return [];

    final seeds = all.where((d) => d.isFavorite).toList();
    final seedSet = (seeds.isNotEmpty ? seeds : all).toSet();
    final seedIds = seedSet.map((d) => d.id).toSet();

    final totalScores = <String, double>{};
    for (final seed in seedSet) {
      for (final rel in getRelatedDocuments(seed, all, limit: all.length)) {
        if (seedIds.contains(rel.document.id)) continue;
        totalScores[rel.document.id] =
            (totalScores[rel.document.id] ?? 0) + rel.score;
      }
    }

    final byId = {for (final d in all) d.id: d};

    if (totalScores.isEmpty) {
      // Fallback: chưa đủ tín hiệu -> gợi ý tài liệu mới nhất.
      final sorted = [...all]
        ..sort((a, b) => b.dateModified.compareTo(a.dateModified));
      return sorted.take(limit).map((d) => ScoredDocument(d, 0)).toList();
    }

    final result =
        totalScores.entries
            .map((e) => ScoredDocument(byId[e.key]!, e.value))
            .toList()
          ..sort((a, b) => b.score.compareTo(a.score));
    return result.take(limit).toList();
  }
}
