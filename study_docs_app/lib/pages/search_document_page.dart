import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../struct/document_enums.dart';
import '../struct/document_model.dart';
import '../struct/document_state_provider.dart';
import '../struct/tag_service.dart';
import '../widgets/document_card.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/smart_tagging_widget.dart';
import 'document_detail_page.dart';

/// Màn hình Tìm kiếm Toàn diện (Live Search & Multi-criteria Filter)
class SearchDocumentPage extends StatefulWidget {
  const SearchDocumentPage({super.key});

  @override
  State<SearchDocumentPage> createState() => _SearchDocumentPageState();
}

class _SearchDocumentPageState extends State<SearchDocumentPage> {
  final TextEditingController _searchController = TextEditingController();

  // --- Bộ lọc đa thẻ (Trần Anh Tuấn, SmartTaggingWidget) ---
  /// Các thẻ đang được chọn để lọc.
  Set<String> _selectedTags = {};

  /// true = tài liệu phải chứa TẤT CẢ thẻ đã chọn (AND),
  /// false = chỉ cần chứa ÍT NHẤT 1 thẻ (OR).
  bool _matchAllTags = true;

  /// Tăng mỗi khi bấm "Xóa tất cả bộ lọc" để ép SmartTaggingWidget
  /// dựng lại state nội bộ (xóa các chip đang chọn).
  int _tagFilterKey = 0;

  @override
  void initState() {
    super.initState();
    final provider = context.read<DocumentStateProvider>();
    _searchController.text = provider.searchQuery;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Áp bộ lọc đa thẻ lên kết quả đã lọc bởi provider.
  List<Document> _applyTagFilter(List<Document> base) {
    if (_selectedTags.isEmpty) return base;
    return base.where((doc) {
      final tags = TagService.normalizeTags(doc.tags).toSet();
      return _matchAllTags
          ? _selectedTags.every(tags.contains)
          : _selectedTags.any(tags.contains);
    }).toList();
  }

  void _clearAllFilters(DocumentStateProvider provider) {
    _searchController.clear();
    provider.clearFilters();
    setState(() {
      _selectedTags = {};
      _matchAllTags = true;
      _tagFilterKey++;
    });
  }

  bool _hasAnyFilter(DocumentStateProvider provider) {
    return provider.searchQuery.isNotEmpty ||
        provider.selectedSubjectId != null ||
        provider.selectedType != null ||
        provider.selectedStatus != null ||
        _selectedTags.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DocumentStateProvider>();
    final theme = Theme.of(context);

    final results = _applyTagFilter(provider.filteredDocuments);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Tìm bài giảng, bài tập, đề thi...',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            contentPadding: EdgeInsets.zero,
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 20),
                    onPressed: () {
                      _searchController.clear();
                      provider.setSearchQuery('');
                    },
                  )
                : null,
          ),
          onChanged: (val) {
            provider.setSearchQuery(val);
          },
        ),
      ),
      body: Column(
        children: [
          // Filter Chips trên thanh tìm kiếm
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Lọc theo Phân quyền đám mây
                DropdownButton<String>(
                  value: provider.accessFilter,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('Tất cả quyền')),
                    DropdownMenuItem(value: 'my_docs', child: Text('Của tôi')),
                    DropdownMenuItem(
                      value: 'shared_with_me',
                      child: Text('Được chia sẻ'),
                    ),
                    DropdownMenuItem(value: 'public', child: Text('Công khai')),
                  ],
                  onChanged: (val) {
                    if (val != null) provider.setAccessFilter(val);
                  },
                ),
                const SizedBox(width: 8),

                // Lọc theo Môn
                DropdownButton<String?>(
                  value: provider.selectedSubjectId,
                  hint: const Text('Tất cả môn'),
                  underline: const SizedBox(),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Tất cả môn'),
                    ),
                    ...provider.subjects.map(
                      (s) => DropdownMenuItem(value: s.id, child: Text(s.code)),
                    ),
                  ],
                  onChanged: (val) => provider.setSelectedSubject(val),
                ),
                const SizedBox(width: 8),

                // Lọc theo Loại
                DropdownButton<DocumentType?>(
                  value: provider.selectedType,
                  hint: const Text('Loại tài liệu'),
                  underline: const SizedBox(),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Tất cả loại'),
                    ),
                    ...DocumentType.values.map(
                      (t) => DropdownMenuItem(
                        value: t,
                        child: Text(t.displayName),
                      ),
                    ),
                  ],
                  onChanged: (val) => provider.setSelectedType(val),
                ),
                const SizedBox(width: 8),

                // Lọc theo Trạng thái
                DropdownButton<DocumentStatus?>(
                  value: provider.selectedStatus,
                  hint: const Text('Trạng thái'),
                  underline: const SizedBox(),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Tất cả trạng thái'),
                    ),
                    ...DocumentStatus.values.map(
                      (st) => DropdownMenuItem(
                        value: st,
                        child: Text(st.displayName),
                      ),
                    ),
                  ],
                  onChanged: (val) => provider.setSelectedStatus(val),
                ),
              ],
            ),
          ),

          // Bộ lọc đa thẻ linh hoạt (SmartTaggingWidget - Trần Anh Tuấn)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SmartTaggingWidget.filter(
              key: ValueKey('tag-filter-$_tagFilterKey'),
              tagUsage: TagService.tagUsage(provider.allDocuments),
              initialSelectedTags: _selectedTags,
              initialMatchAll: _matchAllTags,
              onFilterChanged: (tags) => setState(() => _selectedTags = tags),
              onMatchModeChanged: (matchAll) =>
                  setState(() => _matchAllTags = matchAll),
            ),
          ),
          const Divider(height: 1),

          // Số lượng kết quả
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  'Tìm thấy ${results.length} tài liệu',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.textTheme.bodySmall?.color?.withValues(
                      alpha: 0.7,
                    ),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (_hasAnyFilter(provider))
                  InkWell(
                    onTap: () => _clearAllFilters(provider),
                    child: Text(
                      'Xóa tất cả bộ lọc',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Danh sách kết quả
          Expanded(
            child: results.isEmpty
                ? const EmptyStateView(
                    icon: Icons.search_off_rounded,
                    title: 'Không tìm thấy tài liệu phù hợp',
                    message: 'Vui lòng kiểm tra lại từ khóa hoặc xóa bớt tiêu chí lọc để mở rộng phạm vi tìm kiếm.',
                  )
                : ListView.builder(
                    itemCount: results.length,
                    itemBuilder: (ctx, idx) {
                      final doc = results[idx];
                      return DocumentCard(
                        document: doc,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  DocumentDetailPage(documentId: doc.id),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
