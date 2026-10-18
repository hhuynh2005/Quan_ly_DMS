import 'document_model.dart';

/// Service xử lý Tag nâng cao cho StudyDocs DMS.
///
/// Nhiệm vụ: chuẩn hoá tag, gợi ý tag khi gõ (autocomplete),
/// tự động trích xuất ứng viên tag từ tiêu đề/mô tả,
/// thống kê mức độ sử dụng tag trong thư viện.
class TagService {
  TagService._();

  /// Chuẩn hoá 1 tag: cắt khoảng trắng 2 đầu, viết thường,
  /// gộp khoảng trắng thừa thành 1 dấu cách.
  /// Ví dụ: "  Machine  Learning " -> "machine learning"
  static String normalizeTag(String tag) {
    return tag.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Chuẩn hoá cả danh sách: bỏ tag rỗng, loại trùng, giữ nguyên thứ tự.
  static List<String> normalizeTags(Iterable<String> tags) {
    final seen = <String>{};
    final result = <String>[];
    for (final t in tags) {
      final normalized = normalizeTag(t);
      if (normalized.isNotEmpty && seen.add(normalized)) {
        result.add(normalized);
      }
    }
    return result;
  }

  /// Parse chuỗi người dùng nhập tay ("ai, machine learning, AI")
  /// thành danh sách tag đã chuẩn hoá: ["ai", "machine learning"].
  /// Dùng thay cho đoạn split(',') thủ công ở màn hình thêm/sửa tài liệu.
  static List<String> parseTagsInput(String input) {
    return normalizeTags(input.split(','));
  }

  /// Gom toàn bộ tag đã dùng trong thư viện kèm số tài liệu dùng mỗi tag.
  /// Kết quả sắp xếp giảm dần theo số lượng (tag phổ biến nhất trước).
  static Map<String, int> tagUsage(List<Document> docs) {
    final counts = <String, int>{};
    for (final doc in docs) {
      for (final tag in normalizeTags(doc.tags)) {
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
    return counts;
  }

  /// Gợi ý tag khi người dùng đang gõ [prefix] (autocomplete).
  /// Ưu tiên tag được dùng nhiều nhất. Trả về tối đa [limit] gợi ý.
  static List<String> suggestTags(
    List<Document> documents,
    String prefix, {
    int limit = 8,
  }) {
    final p = normalizeTag(prefix);
    if (p.isEmpty) return [];
    final counts = tagUsage(documents);
    final matches = counts.keys.where((t) => t.startsWith(p)).toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return matches.take(limit).toList();
  }

  /// Từ dừng tiếng Việt: không bao giờ được chọn làm tag tự động.
  static const Set<String> _stopwords = {
    'của',
    'và',
    'là',
    'các',
    'một',
    'những',
    'trong',
    'với',
    'cho',
    'được',
    'có',
    'không',
    'đã',
    'sẽ',
    'này',
    'đó',
    'kia',
    'về',
    'từ',
    'tại',
    'như',
    'khi',
    'để',
    'mà',
    'thì',
    'rất',
    'cũng',
    'bị',
    'do',
    'hay',
    'hoặc',
    'nhưng',
    'nếu',
    'vì',
    'nên',
    'the',
    'and',
    'for',
    'with',
    'from',
  };

  /// Tự động trích xuất ứng viên tag từ tiêu đề + mô tả của tài liệu.
  ///
  /// Cách làm đơn giản, chạy offline hoàn toàn trên máy:
  /// tách từ -> bỏ stopword + từ ngắn (<= 2 ký tự) -> đếm tần suất
  /// -> trả về [limit] từ xuất hiện nhiều nhất.
  /// Người dùng xem lại và bấm chọn trước khi lưu (không tự gắn ẩu).
  static List<String> extractCandidateTags(Document doc, {int limit = 6}) {
    final text = '${doc.title} ${doc.description}'.toLowerCase();
    final words = RegExp(r'[a-zà-ỹ0-9]+')
        .allMatches(text)
        .map((m) => m.group(0)!)
        .where((w) => w.length > 2 && !_stopwords.contains(w));

    final freq = <String, int>{};
    for (final w in words) {
      freq[w] = (freq[w] ?? 0) + 1;
    }
    final sorted = freq.keys.toList()
      ..sort((a, b) => freq[b]!.compareTo(freq[a]!));
    return sorted.take(limit).toList();
  }

  /// Gộp 2 tag thành 1 (đổi tên tag): thay mọi lần xuất hiện của [oldTag]
  /// bằng [newTag] trong toàn bộ tài liệu. Trả về danh sách đã cập nhật.
  static List<Document> renameTag(
    List<Document> documents,
    String oldTag,
    String newTag,
  ) {
    final oldN = normalizeTag(oldTag);
    final newN = normalizeTag(newTag);
    if (oldN.isEmpty || newN.isEmpty || oldN == newN) return documents;
    return documents.map((doc) {
      final tags = normalizeTags(doc.tags)
          .map((t) => t == oldN ? newN : t)
          .toList();
      return doc.copyWith(tags: normalizeTags(tags));
    }).toList();
  }

  /// Xoá 1 tag khỏi toàn bộ tài liệu.
  static List<Document> deleteTag(List<Document> documents, String tag) {
    final target = normalizeTag(tag);
    if (target.isEmpty) return documents;
    return documents.map((doc) {
      final tags = normalizeTags(doc.tags).where((t) => t != target).toList();
      return doc.copyWith(tags: tags);
    }).toList();
  }
}
