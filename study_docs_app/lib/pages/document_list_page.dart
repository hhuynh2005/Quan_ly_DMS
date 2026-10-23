import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../struct/document_enums.dart';
import '../struct/document_state_provider.dart';
import '../widgets/document_card.dart';
import '../widgets/empty_state_view.dart';
import 'add_edit_document_page.dart';
import 'document_detail_page.dart';
import 'search_document_page.dart';
import '../struct/responsive_breakpoints.dart';

/// Màn hình Quản lý Danh sách Toàn bộ Tài liệu với phân loại Tab & Sắp xếp
class DocumentListPage extends StatefulWidget {
  const DocumentListPage({super.key});

  @override
  State<DocumentListPage> createState() => _DocumentListPageState();
}

class _DocumentListPageState extends State<DocumentListPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<DocumentType?> _tabTypes = [
    null, // Tất cả
    DocumentType.lecture,
    DocumentType.assignment,
    DocumentType.reference,
    DocumentType.exam,
    DocumentType.note,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabTypes.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final provider = context.read<DocumentStateProvider>();
        provider.setSelectedType(_tabTypes[_tabController.index]);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showSortBottomSheet(BuildContext context) {
    final provider = context.read<DocumentStateProvider>();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    'Sắp xếp tài liệu theo',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.access_time_rounded),
                  title: const Text('Mới nhất trước (Mặc định)'),
                  trailing: provider.sortBy == 'date_desc'
                      ? Icon(Icons.check_rounded, color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () {
                    provider.setSortBy('date_desc');
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.history_rounded),
                  title: const Text('Cũ nhất trước'),
                  trailing: provider.sortBy == 'date_asc'
                      ? Icon(Icons.check_rounded, color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () {
                    provider.setSortBy('date_asc');
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.sort_by_alpha_rounded),
                  title: const Text('Tiêu đề A - Z'),
                  trailing: provider.sortBy == 'title_asc'
                      ? Icon(Icons.check_rounded, color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () {
                    provider.setSortBy('title_asc');
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.alarm_rounded),
                  title: const Text('Hạn nộp / Deadline gần nhất'),
                  trailing: provider.sortBy == 'due_date'
                      ? Icon(Icons.check_rounded, color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () {
                    provider.setSortBy('due_date');
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DocumentStateProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh Sách Tài Liệu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Tìm kiếm',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SearchDocumentPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.sort_rounded),
            tooltip: 'Sắp xếp',
            onPressed: () => _showSortBottomSheet(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Tất cả'),
            Tab(text: 'Bài giảng'),
            Tab(text: 'Bài tập'),
            Tab(text: 'Tham khảo'),
            Tab(text: 'Đề thi'),
            Tab(text: 'Ghi chú'),
          ],
        ),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Thanh lọc môn học (nếu có)
                if (provider.subjects.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: const Text('Tất cả môn'),
                            selected: provider.selectedSubjectId == null,
                            onSelected: (_) => provider.setSelectedSubject(null),
                          ),
                          const SizedBox(width: 8),
                          ...provider.subjects.map((sub) {
                            final isSel = provider.selectedSubjectId == sub.id;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(sub.name),
                                selected: isSel,
                                selectedColor: sub.color.withValues(alpha: 0.2),
                                labelStyle: TextStyle(
                                  color: isSel ? sub.color : null,
                                  fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                ),
                                onSelected: (_) =>
                                    provider.setSelectedSubject(isSel ? null : sub.id),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),

                // Danh sách tài liệu
                Expanded(
                  child: provider.filteredDocuments.isEmpty
                      ? EmptyStateView(
                          title: 'Không có tài liệu phù hợp',
                          message: 'Chưa có tài liệu nào trong danh mục hoặc bộ lọc này.',
                          actionText: 'Thêm tài liệu mới',
                          onAction: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => AddEditDocumentPage(
                                  initialSubjectId: provider.selectedSubjectId,
                                ),
                              ),
                            );
                          },
                        )
                      : context.isWide
                          ? GridView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisExtent: 205,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                              itemCount: provider.filteredDocuments.length,
                              itemBuilder: (ctx, index) {
                                final doc = provider.filteredDocuments[index];
                                return DocumentCard(
                                  document: doc,
                                  margin: EdgeInsets.zero,
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => DocumentDetailPage(documentId: doc.id),
                                      ),
                                    );
                                  },
                                );
                              },
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.only(top: 8, bottom: 80),
                              itemCount: provider.filteredDocuments.length,
                              itemBuilder: (ctx, index) {
                                final doc = provider.filteredDocuments[index];
                                return DocumentCard(
                                  document: doc,
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => DocumentDetailPage(documentId: doc.id),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AddEditDocumentPage(
                initialSubjectId: provider.selectedSubjectId,
              ),
            ),
          );
        },
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}
