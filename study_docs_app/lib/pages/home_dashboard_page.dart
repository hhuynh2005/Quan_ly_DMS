import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../struct/document_enums.dart';
import '../struct/document_state_provider.dart';
import '../struct/recommendation_service.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/cloud_sync_panel.dart';
import '../widgets/document_card.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/filter_chip_bar.dart';
import '../widgets/offline_mode_indicator.dart';
import '../widgets/stat_summary_card.dart';
import '../widgets/user_profile_header.dart';
import 'about_app_page.dart';
import 'add_edit_document_page.dart';
import 'borrow_management_page.dart';
import 'document_detail_page.dart';
import 'document_list_page.dart';
import 'login_page.dart';
import 'search_document_page.dart';
import 'subjects_manage_page.dart';

/// Màn hình chính Dashboard tổng quan
class HomeDashboardPage extends StatefulWidget {
  const HomeDashboardPage({super.key});

  @override
  State<HomeDashboardPage> createState() => _HomeDashboardPageState();
}

class _HomeDashboardPageState extends State<HomeDashboardPage>
    with WidgetsBindingObserver {
  int _navIndex = 0;
  bool _isOfflineMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<DocumentStateProvider>().handleAppResumed();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DocumentStateProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Gợi ý cho bạn (Thuật toán Recommendation - Trần Anh Tuấn):
    // dựa trên tài liệu đã đánh dấu yêu thích; chưa có favorite thì
    // fallback về tài liệu mới sửa gần nhất.
    final recommended = RecommendationService.getRecommendedForUser(
      provider.allDocuments,
      limit: 8,
    );

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.folder_shared_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tài Liệu Học Tập',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Kiến trúc Cashew • Local-First',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.textTheme.bodySmall?.color?.withValues(
                      alpha: 0.7,
                    ),
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              final user = snapshot.data;
              if (user != null) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 8,
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      );
                    },
                    child: Tooltip(
                      message: 'Hồ sơ: ${user.displayName ?? user.email}',
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 17,
                            backgroundColor: theme.colorScheme.primary
                                .withValues(alpha: 0.15),
                            backgroundImage:
                                user.photoURL != null &&
                                    user.photoURL!.isNotEmpty
                                ? NetworkImage(user.photoURL!)
                                : null,
                            child:
                                user.photoURL == null || user.photoURL!.isEmpty
                                ? Text(
                                    user.displayName?.isNotEmpty == true
                                        ? user.displayName![0].toUpperCase()
                                        : 'U',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                  )
                                : null,
                          ),
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Color(0xFF00E676),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
              return IconButton(
                icon: const Icon(Icons.account_circle_rounded),
                tooltip: 'Xác thực Google Cloud (Nhóm 16)',
                onPressed: () {
                  Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const LoginPage()));
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.handshake_rounded),
            tooltip: 'Quản lý Mượn/Trả tài liệu (TH2 - Lê Anh Tuấn)',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BorrowManagementPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Tìm kiếm tài liệu',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SearchDocumentPage()),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) async {
              if (value == 'borrow') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const BorrowManagementPage()),
                );
              } else if (value == 'subjects') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SubjectsManagePage()),
                );
              } else if (value == 'reset') {
                final primaryCol = theme.colorScheme.primary;
                final confirm = await ConfirmDialog.show(
                  context: context,
                  title: 'Đặt lại dữ liệu mẫu',
                  message: 'Khôi phục lại toàn bộ dữ liệu môn học và tài liệu mẫu mặc định ban đầu?',
                  confirmText: 'Đặt lại',
                  confirmColor: primaryCol,
                  icon: Icons.restore_rounded,
                );
                if (confirm && context.mounted) {
                  await provider.resetToDefault();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đã khôi phục dữ liệu mẫu thành công!'),
                      ),
                    );
                  }
                }
              } else if (value == 'about') {
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const AboutAppPage()));
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'borrow',
                child: Row(
                  children: [
                    Icon(Icons.handshake_rounded, size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 10),
                    const Text('Quản lý Mượn / Trả (TH2)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'subjects',
                child: Row(
                  children: [
                    Icon(Icons.category_rounded, size: 20),
                    SizedBox(width: 10),
                    Text('Quản lý Môn học'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'reset',
                child: Row(
                  children: [
                    Icon(Icons.restore_rounded, size: 20),
                    SizedBox(width: 10),
                    Text('Khôi phục dữ liệu mẫu'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'about',
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 20),
                    SizedBox(width: 10),
                    Text('Thông tin Đồ án TH1'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await Future.delayed(const Duration(milliseconds: 300));
              },
              child: CustomScrollView(
                slivers: [
                  // 0. Chỉ báo trạng thái Cloud và Ngoại tuyến (Nguyễn Trung Kiên)
                  SliverToBoxAdapter(
                    child: OfflineModeIndicator(
                      isOffline: _isOfflineMode,
                      onToggleOffline: (val) {
                        setState(() => _isOfflineMode = val);
                      },
                      pendingSyncCount: provider.allDocuments
                          .where(
                            (d) => d.cloudSyncStatus == CloudSyncStatus.pending,
                          )
                          .length,
                    ),
                  ),

                  // 0.1 Thẻ thông tin người dùng Google Cloud Profile (Nguyễn Trung Kiên)
                  SliverToBoxAdapter(
                    child: UserProfileHeader(
                      onOpenAuthPage: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                        );
                      },
                    ),
                  ),

                  // 0.2 Bảng điều khiển đồng bộ đám mây (Trần Anh Tuấn)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: CloudSyncPanel(
                        key: const ValueKey('cloud-sync-panel'),
                      ),
                    ),
                  ),
                  // 1. Thẻ chào mừng sinh viên & môn học
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDark
                                ? [
                                    const Color(0xFF004D40),
                                    const Color(0xFF00796B),
                                  ]
                                : [
                                    const Color(0xFF00796B),
                                    const Color(0xFF26A69A),
                                  ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00796B)
                                  .withValues(alpha: 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Học kỳ 1 - Năm học 2026',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white24,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'KTPM K65',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Kho Tài Liệu Học Tập',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${provider.stats['total_documents'] ?? 0} tài liệu • ${provider.stats['total_subjects'] ?? 0} môn học đã lưu trữ',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 2. Các chỉ số thống kê (Stats Grid)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              StatSummaryCard(
                                title: 'Tổng tài liệu',
                                value:
                                    '${provider.stats['total_documents'] ?? 0}',
                                icon: Icons.folder_rounded,
                                color: theme.colorScheme.primary,
                                onTap: () {
                                  provider.clearFilters();
                                },
                              ),
                              const SizedBox(width: 10),
                              StatSummaryCard(
                                title: 'Bài tập / Đồ án',
                                value:
                                    '${provider.stats['assignments_count'] ?? 0}',
                                icon: Icons.assignment_rounded,
                                color: const Color(0xFFFB8C00),
                                onTap: () {
                                  provider.setSelectedType(
                                    DocumentType.assignment,
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              StatSummaryCard(
                                title: 'Bài giảng / Slide',
                                value:
                                    '${provider.stats['lectures_count'] ?? 0}',
                                icon: Icons.menu_book_rounded,
                                color: const Color(0xFF1E88E5),
                                onTap: () {
                                  provider.setSelectedType(
                                    DocumentType.lecture,
                                  );
                                },
                              ),
                              const SizedBox(width: 10),
                              StatSummaryCard(
                                title: 'Đã hoàn thành',
                                value:
                                    '${provider.stats['completed_count'] ?? 0}',
                                icon: Icons.check_circle_rounded,
                                color: const Color(0xFF43A047),
                                onTap: () {
                                  provider.setSelectedStatus(
                                    DocumentStatus.completed,
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 2.5 Gợi ý cho bạn (Thuật toán Recommendation - Trần Anh Tuấn)
                  // Cuộn ngang, bấm vào thẻ để mở chi tiết tài liệu.
                  if (recommended.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 0, 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 16),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.auto_awesome_rounded,
                                    color: theme.colorScheme.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Gợi ý cho bạn',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Spacer(),
                                  const Tooltip(
                                    message: 'Dựa trên tài liệu bạn đã yêu thích: cùng tag, cùng môn học, cùng loại tài liệu',
                                    child: Icon(
                                      Icons.info_outline_rounded,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 148,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.only(right: 16),
                                itemCount: recommended.length,
                                itemBuilder: (ctx, index) {
                                  final scored = recommended[index];
                                  final doc = scored.document;
                                  final subject = provider.getSubjectById(
                                    doc.subjectId,
                                  );
                                  final matchLabel = scored.score > 0
                                      ? '${(scored.score * 100).round()}% phù hợp'
                                      : 'Mới cập nhật';
                                  return Container(
                                    width: 210,
                                    margin: const EdgeInsets.only(right: 10),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(14),
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => DocumentDetailPage(
                                              documentId: doc.id,
                                            ),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? const Color(0xFF1E1E1E)
                                              : Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          border: Border.all(
                                            color: isDark
                                                ? Colors.white12
                                                : Colors.grey.shade200,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  width: 36,
                                                  height: 36,
                                                  decoration: BoxDecoration(
                                                    color: doc.fileFormat.color
                                                        .withValues(
                                                          alpha: 0.12,
                                                        ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                  ),
                                                  child: Icon(
                                                    doc.fileFormat.icon,
                                                    color: doc.fileFormat.color,
                                                    size: 20,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 3,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: theme
                                                          .colorScheme
                                                          .primary
                                                          .withValues(
                                                            alpha: 0.1,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      matchLabel,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: theme
                                                            .colorScheme
                                                            .primary,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              doc.title,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                height: 1.3,
                                              ),
                                            ),
                                            const Spacer(),
                                            Text(
                                              subject?.name ?? 'Chưa phân môn',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: theme
                                                    .textTheme
                                                    .bodySmall
                                                    ?.color
                                                    ?.withValues(alpha: 0.7),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // 3. Danh sách Môn học (Cuộn ngang)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Môn Học',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const SubjectsManagePage(),
                                ),
                              );
                            },
                            child: const Text('Quản lý'),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 80,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: provider.subjects.length,
                        itemBuilder: (ctx, index) {
                          final subject = provider.subjects[index];
                          final isSelected =
                              provider.selectedSubjectId == subject.id;
                          final docCount = provider.getDocumentCountBySubject(
                            subject.id,
                          );

                          return Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: InkWell(
                              onTap: () {
                                provider.setSelectedSubject(
                                  isSelected ? null : subject.id,
                                );
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                width: 140,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? subject.color.withValues(alpha: 0.18)
                                      : (isDark
                                            ? const Color(0xFF1E1E1E)
                                            : Colors.white),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected
                                        ? subject.color
                                        : (isDark
                                              ? Colors.white12
                                              : Colors.grey.shade200),
                                    width: isSelected ? 1.8 : 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          subject.iconData,
                                          color: subject.color,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          subject.code,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: subject.color,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      subject.name,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '$docCount tài liệu',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: theme.textTheme.bodySmall?.color
                                            ?.withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // 4. Thanh lọc theo Loại tài liệu & Trạng thái
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: 14, bottom: 8),
                      child: FilterChipBar(),
                    ),
                  ),

                  // 5. Tiêu đề danh sách tài liệu
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            provider.selectedSubjectId != null
                                ? 'Tài liệu: ${provider.getSubjectById(provider.selectedSubjectId!)?.name ?? ""}'
                                : 'Tài Liệu Học Tập (${provider.filteredDocuments.length})',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (provider.selectedSubjectId != null ||
                              provider.selectedType != null ||
                              provider.selectedStatus != null ||
                              provider.showFavoritesOnly)
                            TextButton.icon(
                              onPressed: () => provider.clearFilters(),
                              icon: const Icon(
                                Icons.clear_all_rounded,
                                size: 16,
                              ),
                              label: const Text('Bỏ lọc'),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // 6. Danh sách thẻ tài liệu
                  if (provider.filteredDocuments.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyStateView(
                        title: 'Không tìm thấy tài liệu nào',
                        message: 'Thử bỏ lọc hoặc thêm tài liệu mới cho môn học này.',
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
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate((ctx, index) {
                        final doc = provider.filteredDocuments[index];
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
                      }, childCount: provider.filteredDocuments.length),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AddEditDocumentPage(
                initialSubjectId: provider.selectedSubjectId,
              ),
            ),
          );
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Thêm tài liệu'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: (idx) {
          if (idx == 1) {
            Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const DocumentListPage()));
          } else if (idx == 2) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SubjectsManagePage()),
            );
          } else if (idx == 3) {
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const AboutAppPage()));
          } else {
            setState(() => _navIndex = idx);
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Tổng quan',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book_rounded),
            label: 'Tài liệu',
          ),
          NavigationDestination(
            icon: Icon(Icons.category_outlined),
            selectedIcon: Icon(Icons.category_rounded),
            label: 'Môn học',
          ),
          NavigationDestination(
            icon: Icon(Icons.info_outline_rounded),
            selectedIcon: Icon(Icons.info_rounded),
            label: 'Thông tin',
          ),
        ],
      ),
    );
  }
}
