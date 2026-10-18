import 'package:flutter/material.dart';

import '../struct/document_enums.dart';
import '../struct/document_model.dart';
import '../struct/tag_service.dart';

/// Chế độ hoạt động của [SmartTaggingWidget].
enum SmartTaggingMode {
  /// Gắn thẻ cho một tài liệu: ô nhập tag + gợi ý autocomplete
  /// + nút tự trích xuất tag từ tiêu đề/mô tả.
  edit,

  /// Lọc nhiều thẻ: chọn nhiều tag trong thư viện để lọc danh sách,
  /// kèm chế độ khớp linh hoạt AND ("tất cả") / OR ("bất kỳ").
  filter,
}

/// Hệ thống Gắn thẻ thông minh (Smart Tagging) — Nhóm 16, Trần Anh Tuấn.
///
/// - `SmartTaggingWidget.edit(...)`: dùng ở màn hình thêm/sửa tài liệu.
///   Quản lý danh sách tag dưới dạng chip, gợi ý tag khi gõ, tự trích xuất
///   ứng viên tag từ tiêu đề/mô tả. Báo danh sách tag qua [onTagsChanged].
/// - `SmartTaggingWidget.filter(...)`: dùng ở màn hình tìm kiếm/danh sách.
///   Hiển thị toàn bộ tag trong thư viện kèm số lượng, cho chọn nhiều tag,
///   chuyển chế độ khớp AND/OR. Báo tập tag đã chọn qua [onFilterChanged].
class SmartTaggingWidget extends StatefulWidget {
  final SmartTaggingMode mode;

  // --- Chế độ edit ---
  final List<String> initialTags;
  final List<Document> allDocuments;
  final TextEditingController? titleController;
  final TextEditingController? descriptionController;
  final ValueChanged<List<String>>? onTagsChanged;

  // --- Chế độ filter ---
  final Map<String, int> tagUsage;
  final Set<String> initialSelectedTags;
  final bool initialMatchAll;
  final ValueChanged<Set<String>>? onFilterChanged;
  final ValueChanged<bool>? onMatchModeChanged;

  const SmartTaggingWidget.edit({
    super.key,
    this.initialTags = const [],
    this.allDocuments = const [],
    this.titleController,
    this.descriptionController,
    this.onTagsChanged,
  }) : mode = SmartTaggingMode.edit,
       tagUsage = const {},
       initialSelectedTags = const {},
       initialMatchAll = true,
       onFilterChanged = null,
       onMatchModeChanged = null;

  const SmartTaggingWidget.filter({
    super.key,
    this.tagUsage = const {},
    this.initialSelectedTags = const {},
    this.initialMatchAll = true,
    this.onFilterChanged,
    this.onMatchModeChanged,
  }) : mode = SmartTaggingMode.filter,
       initialTags = const [],
       allDocuments = const [],
       titleController = null,
       descriptionController = null,
       onTagsChanged = null;

  @override
  State<SmartTaggingWidget> createState() => _SmartTaggingWidgetState();
}

class _SmartTaggingWidgetState extends State<SmartTaggingWidget> {
  // --- State chế độ edit ---
  late List<String> _tags;
  final TextEditingController _inputController = TextEditingController();
  List<String> _suggestions = [];
  List<String> _candidates = [];

  // --- State chế độ filter ---
  late Set<String> _selected;
  late bool _matchAll;

  @override
  void initState() {
    super.initState();
    _tags = TagService.normalizeTags(widget.initialTags);
    _selected = widget.initialSelectedTags.map(TagService.normalizeTag).toSet();
    _matchAll = widget.initialMatchAll;
    _inputController.addListener(_refreshSuggestions);
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  // =====================================================================
  // CHẾ ĐỘ EDIT: gắn thẻ cho tài liệu
  // =====================================================================

  /// Refresh gợi ý autocomplete theo từ đang gõ (đoạn sau dấu phẩy cuối).
  void _refreshSuggestions() {
    if (widget.mode != SmartTaggingMode.edit || !mounted) return;
    final word = _inputController.text.split(',').last;
    final selected = _tags.toSet();
    final suggestions = TagService.suggestTags(
      widget.allDocuments,
      word,
    ).where((s) => !selected.contains(s)).toList();
    if (!_listEquals(_suggestions, suggestions)) {
      setState(() => _suggestions = suggestions);
    }
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _notifyTagsChanged() =>
      widget.onTagsChanged?.call(List.unmodifiable(_tags));

  /// Thêm 1 tag (đã chuẩn hoá), bỏ qua tag rỗng/trùng.
  void _addTag(String raw) {
    final tag = TagService.normalizeTag(raw);
    if (tag.isEmpty) return;
    setState(() {
      if (!_tags.contains(tag)) _tags.add(tag);
      _inputController.clear();
    });
    _notifyTagsChanged();
  }

  void _removeTag(String tag) {
    setState(() => _tags.remove(tag));
    _notifyTagsChanged();
  }

  /// Tự trích xuất ứng viên tag từ tiêu đề/mô tả hiện tại.
  /// Người dùng bấm từng chip để thêm (không tự gắn ẩu).
  void _autoExtract() {
    final temp = Document(
      id: 'temp-autotag',
      title: widget.titleController?.text ?? '',
      description: widget.descriptionController?.text ?? '',
      subjectId: '',
      documentType: DocumentType.lecture,
      tags: _tags,
    );
    final selected = _tags.toSet();
    final candidates = TagService.extractCandidateTags(temp)
        .where((c) => !selected.contains(c))
        .toList();
    setState(() => _candidates = candidates);
    if (candidates.isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Không trích xuất được tag mới từ tiêu đề/mô tả. Hãy nhập thêm mô tả.',
          ),
        ),
      );
    }
  }

  Widget _buildEditMode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tag đã chọn
        if (_tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _tags
                  .map(
                    (t) => InputChip(
                      label: Text('#$t'),
                      onDeleted: () => _removeTag(t),
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(),
            ),
          ),
        // Ô nhập tag
        TextField(
          controller: _inputController,
          decoration: InputDecoration(
            labelText: 'Thẻ tag (gõ rồi bấm + hoặc Enter)',
            hintText: 'VD: flutter, slide, TH1',
            prefixIcon: const Icon(Icons.tag_rounded),
            suffixIcon: IconButton(
              icon: const Icon(Icons.add_circle_rounded),
              tooltip: 'Thêm tag',
              onPressed: () => _addTag(_inputController.text.split(',').last),
            ),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _addTag(_inputController.text.split(',').last),
        ),
        // Gợi ý autocomplete
        if (_suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Chip(
                avatar: Icon(Icons.auto_awesome_rounded, size: 16),
                label: Text('Gợi ý:', style: TextStyle(fontSize: 12)),
                visualDensity: VisualDensity.compact,
              ),
              ..._suggestions.map(
                (s) => ActionChip(
                  label: Text(s),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _addTag(s),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        // Nút tự trích xuất tag
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
            label: const Text(
              'Tự động gợi ý tag từ tiêu đề/mô tả',
              style: TextStyle(fontSize: 13),
            ),
            onPressed: _autoExtract,
          ),
        ),
        if (_candidates.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _candidates
                .map(
                  (c) => ActionChip(
                    avatar: const Icon(Icons.add_rounded, size: 16),
                    label: Text(c),
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      _addTag(c);
                      setState(
                        () => _candidates = _candidates
                            .where((t) => t != c)
                            .toList(),
                      );
                    },
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

  // =====================================================================
  // CHẾ ĐỘ FILTER: lọc nhiều thẻ
  // =====================================================================

  void _toggleTag(String tag) {
    setState(() {
      if (_selected.contains(tag)) {
        _selected.remove(tag);
      } else {
        _selected.add(tag);
      }
    });
    widget.onFilterChanged?.call(Set.unmodifiable(_selected));
  }

  void _setMatchAll(bool value) {
    if (_matchAll == value) return;
    setState(() => _matchAll = value);
    widget.onMatchModeChanged?.call(value);
  }

  void _clearFilter() {
    setState(() => _selected.clear());
    widget.onFilterChanged?.call(const {});
  }

  Widget _buildFilterMode() {
    final sortedTags = widget.tagUsage.keys.toList()
      ..sort((a, b) => widget.tagUsage[b]!.compareTo(widget.tagUsage[a]!));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.tag_rounded, size: 18),
            const SizedBox(width: 6),
            const Text(
              'Lọc theo thẻ',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            ChoiceChip(
              label: const Text('Tất cả', style: TextStyle(fontSize: 11)),
              selected: _matchAll,
              showCheckmark: false,
              visualDensity: VisualDensity.compact,
              tooltip: 'Tài liệu phải chứa TẤT CẢ thẻ đã chọn (AND)',
              onSelected: (_) => _setMatchAll(true),
            ),
            const SizedBox(width: 6),
            ChoiceChip(
              label: const Text('Bất kỳ', style: TextStyle(fontSize: 11)),
              selected: !_matchAll,
              showCheckmark: false,
              visualDensity: VisualDensity.compact,
              tooltip: 'Tài liệu chứa ÍT NHẤT 1 thẻ đã chọn (OR)',
              onSelected: (_) => _setMatchAll(false),
            ),
            if (_selected.isNotEmpty)
              TextButton(
                onPressed: _clearFilter,
                child: const Text('Xóa', style: TextStyle(fontSize: 12)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (sortedTags.isEmpty)
          const Text(
            'Chưa có thẻ nào trong thư viện.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: sortedTags.map((tag) {
              final count = widget.tagUsage[tag]!;
              return FilterChip(
                label: Text(
                  '$tag ($count)',
                  style: const TextStyle(fontSize: 12),
                ),
                selected: _selected.contains(tag),
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => _toggleTag(tag),
              );
            }).toList(),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.mode == SmartTaggingMode.edit
        ? _buildEditMode()
        : _buildFilterMode();
  }
}
