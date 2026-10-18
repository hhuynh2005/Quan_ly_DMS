import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../functions.dart';
import '../struct/document_enums.dart';
import '../struct/document_model.dart';
import '../struct/document_share_model.dart';
import '../struct/document_state_provider.dart';
import '../struct/firebase_storage_service.dart';
import '../struct/google_auth_service.dart';
import '../struct/recommendation_service.dart';
import '../struct/supabase_service.dart';
import '../theme.dart';
import '../widgets/cloud_sync_badge.dart';
import '../widgets/cloud_transfer_progress.dart';
import '../widgets/confirm_dialog.dart';
import 'add_edit_document_page.dart';

/// Màn hình Chi tiết Tài liệu học tập (Xem, Chuyển trạng thái, Sửa, Xóa)
class DocumentDetailPage extends StatelessWidget {
  final String documentId;

  const DocumentDetailPage({super.key, required this.documentId});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DocumentStateProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Document? doc;
    try {
      doc = provider.allDocuments.firstWhere((d) => d.id == documentId);
    } catch (_) {
      doc = null;
    }

    if (doc == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết tài liệu')),
        body: const Center(
          child: Text('Tài liệu không tồn tại hoặc đã bị xóa.'),
        ),
      );
    }

    final document = doc;
    final subject = provider.getSubjectById(document.subjectId);
    final typeColor = document.documentType.color;
    final formatColor = document.fileFormat.color;

    final perm = provider.getDocumentPermission(document);
    final isOwner = SupabaseService().isOwner(
      document,
      provider.currentUserId,
      provider.currentUserEmail,
    );
    final canEdit = isOwner || (perm != null && perm.canEdit);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi Tiết Tài Liệu'),
        actions: [
          // Nút Favorite
          IconButton(
            icon: Icon(
              document.isFavorite
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
              color: document.isFavorite ? Colors.amber : null,
              size: 26,
            ),
            tooltip: 'Yêu thích',
            onPressed: () {
              provider.toggleFavorite(document.id);
            },
          ),
          // Nút Phân quyền & Chia sẻ
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Phân quyền & Chia sẻ (Supabase RLS)',
            onPressed: () => _showShareDialog(context, document),
          ),
          // Nút Sửa
          IconButton(
            icon: Icon(
              Icons.edit_rounded,
              color: canEdit ? null : Colors.grey.withValues(alpha: 0.5),
            ),
            tooltip: canEdit
                ? 'Chỉnh sửa tài liệu'
                : 'Chỉ xem (Viewer) - Không thể sửa',
            onPressed: () {
              if (!canEdit) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Từ chối truy cập (RLS): Bạn chỉ có quyền Xem (Viewer), không được chỉnh sửa tài liệu.',
                    ),
                    backgroundColor: Colors.orange,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AddEditDocumentPage(documentToEdit: document),
                ),
              );
            },
          ),
          // Nút Xóa (Duy nhất Owner có quyền xóa)
          IconButton(
            icon: Icon(
              Icons.delete_outline_rounded,
              color: isOwner ? Colors.red : Colors.grey.withValues(alpha: 0.4),
            ),
            tooltip: isOwner
                ? 'Xóa tài liệu (Chủ sở hữu)'
                : 'Chỉ chủ sở hữu mới có quyền xóa',
            onPressed: () async {
              if (!isOwner) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Từ chối truy cập (RLS): Chỉ chủ sở hữu (Owner) mới có quyền xóa tài liệu này.',
                    ),
                    backgroundColor: Colors.redAccent,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }

              final confirm = await ConfirmDialog.show(
                context: context,
                title: 'Xóa tài liệu này?',
                message:
                    'Bạn có chắc chắn muốn xóa "${document.title}"? Dữ liệu sẽ được lưu vào delete_logs của hệ thống.',
              );

              if (confirm && context.mounted) {
                try {
                  await provider.deleteDocument(document.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đã xóa tài liệu thành công!'),
                      ),
                    );
                    Navigator.of(context).pop();
                  }
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Không thể xóa tài liệu: $error'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Thẻ Header tổng quan
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: formatColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          document.fileFormat.icon,
                          color: formatColor,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subject?.name ?? 'Chưa phân môn',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color:
                                    subject?.color ?? theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Mã môn: ${subject?.code ?? "N/A"} • ${subject?.semester ?? ""}',
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.textTheme.bodySmall?.color
                                    ?.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    document.title,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                  if (document.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      document.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.textTheme.bodyMedium?.color?.withValues(
                          alpha: 0.8,
                        ),
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 2. Chuyển đổi trạng thái học tập nhanh (Status Selector Bar)
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Trạng thái tiến độ học tập',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: DocumentStatus.values.map((st) {
                      final isSelected = document.status == st;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: InkWell(
                            onTap: () {
                              provider.updateDocumentStatus(document.id, st);
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? st.color.withValues(alpha: 0.18)
                                    : (isDark
                                          ? Colors.white10
                                          : Colors.grey.shade100),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? st.color
                                      : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    isSelected
                                        ? Icons.radio_button_checked_rounded
                                        : Icons.radio_button_off_rounded,
                                    size: 16,
                                    color: isSelected ? st.color : Colors.grey,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    st.displayName,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isSelected ? st.color : null,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 3. Bảng thông số chi tiết (Metadata Table)
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  _buildDetailWidgetRow(
                    context,
                    icon: document.cloudSyncStatus.icon,
                    iconColor: document.cloudSyncStatus.color,
                    label: 'Đồng bộ Đám mây Cloud',
                    trailing: CloudSyncBadge(status: document.cloudSyncStatus),
                  ),
                  const Divider(height: 1),
                  _buildDetailRow(
                    context,
                    icon: document.documentType.icon,
                    iconColor: typeColor,
                    label: 'Phân loại tài liệu',
                    value: document.documentType.displayName,
                  ),
                  const Divider(height: 1),
                  _buildDetailRow(
                    context,
                    icon: document.fileFormat.icon,
                    iconColor: formatColor,
                    label: 'Định dạng & Dung lượng',
                    value:
                        '${document.fileFormat.extensionName} (${AppFunctions.formatFileSize(document.fileSizeBytes)})',
                  ),
                  const Divider(height: 1),
                  _buildDetailRow(
                    context,
                    icon: Icons.priority_high_rounded,
                    iconColor: document.priority.color,
                    label: 'Mức độ ưu tiên',
                    value: document.priority.displayName,
                  ),
                  const Divider(height: 1),
                  _buildDetailRow(
                    context,
                    icon: Icons.alarm_rounded,
                    iconColor: document.dueDate != null
                        ? Colors.orange
                        : Colors.grey,
                    label: 'Hạn chót / Deadline',
                    value: document.dueDate != null
                        ? AppFunctions.formatDate(document.dueDate)
                        : 'Không có hạn',
                  ),
                  const Divider(height: 1),
                  _buildDetailRow(
                    context,
                    icon: Icons.calendar_today_rounded,
                    iconColor: Colors.blueGrey,
                    label: 'Ngày tạo',
                    value: AppFunctions.formatDateTime(document.dateCreated),
                  ),
                  const Divider(height: 1),
                  _buildDetailRow(
                    context,
                    icon: Icons.update_rounded,
                    iconColor: Colors.blueGrey,
                    label: 'Lần sửa cuối',
                    value: AppFunctions.formatDateTime(document.dateModified),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 4. File Path / URL link
          if ((document.fileUrl != null && document.fileUrl!.isNotEmpty) ||
              (document.filePath != null && document.filePath!.isNotEmpty))
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tệp đính kèm & Liên kết',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (document.filePath != null &&
                        document.filePath!.isNotEmpty)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.folder_open_rounded),
                        title: Text(
                          document.filePath!,
                          style: const TextStyle(fontSize: 13),
                        ),
                        subtitle: const Text('Đường dẫn lưu trên thiết bị'),
                      ),
                    if (document.fileUrl != null &&
                        document.fileUrl!.isNotEmpty)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.open_in_browser_rounded,
                          color: Colors.blue,
                        ),
                        title: Text(
                          document.fileUrl!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        subtitle: const Text('Liên kết tham khảo trực tuyến'),
                      ),
                  ],
                ),
              ),
            ),
          // 4.1 Thao tác truyền tải Cloud Storage (Nguyễn Trung Kiên)
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.cloud_sync_rounded,
                        color: AppTheme.primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Truyền tải Cloud Storage (Firebase)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      CloudSyncBadge(status: document.cloudSyncStatus),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Vị trí lưu trữ: gs://cashew-study-docs.appspot.com/docs/\nKhu vực: asia-southeast1 (Singapore) • Kiểm tra toàn vẹn Checksum MD5.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(
                            Icons.cloud_download_rounded,
                            size: 18,
                          ),
                          label: const Text('Tải về máy'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0288D1),
                            side: const BorderSide(color: Color(0xFF0288D1)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () async {
                            final success =
                                await CloudTransferProgress.showTransferSheet(
                                  context: context,
                                  type: TransferType.download,
                                  fileName:
                                      '${document.title}.${document.fileFormat.name}',
                                  totalBytes: document.fileSizeBytes > 0
                                      ? document.fileSizeBytes
                                      : 2 * 1024 * 1024,
                                  fileFormat: document.fileFormat,
                                );
                            if (success && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: Color(0xFF0288D1),
                                  content: Text(
                                    'Đã tải tài liệu về bộ nhớ ngoại tuyến thành công!',
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(
                            Icons.cloud_upload_rounded,
                            size: 18,
                          ),
                          label: const Text('Đồng bộ Cloud'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () async {
                            final success =
                                await CloudTransferProgress.showTransferSheet(
                                  context: context,
                                  type: TransferType.upload,
                                  fileName:
                                      '${document.title}.${document.fileFormat.name}',
                                  totalBytes: document.fileSizeBytes > 0
                                      ? document.fileSizeBytes
                                      : 3 * 1024 * 1024,
                                  fileFormat: document.fileFormat,
                                );
                            if (success && context.mounted) {
                              await provider.updateDocument(
                                document.copyWith(
                                  fileUrl:
                                      'https://firebasestorage.googleapis.com/v0/b/cashew-study-docs.appspot.com/o/${Uri.encodeComponent(document.title)}?alt=media',
                                  cloudSyncStatus: CloudSyncStatus.synced,
                                ),
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    backgroundColor: AppTheme.primaryColor,
                                    content: Text(
                                      'Đã đồng bộ tài liệu lên Firebase Cloud Storage!',
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 5. Thẻ Phân quyền & Chia sẻ Supabase RLS
          _PermissionsCard(
            document: document,
            isOwner: isOwner,
            perm: perm,
            onManageShares: () => _showShareDialog(context, document),
          ),
          const SizedBox(height: 16),

          // 6. Firebase Cloud Storage Card
          _CloudStorageCard(document: document),
          const SizedBox(height: 16),

          // 6. Thẻ Tags
          if (document.tags.isNotEmpty)
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Thẻ phân loại (Tags)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: document.tags.map((tag) {
                        return Chip(
                          label: Text('#$tag'),
                          backgroundColor: theme.colorScheme.primary.withValues(
                            alpha: 0.08,
                          ),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                          visualDensity: VisualDensity.compact,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

          // 7. Tài liệu liên quan (Thuật toán Recommendation - Trần Anh Tuấn)
          _buildRelatedCard(context, provider, document),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  /// Thẻ "Tài liệu liên quan": top 5 tài liệu giống nhất theo thuật toán
  /// content-based (tag chung, cùng môn, cùng loại, từ khoá tiêu đề).
  /// Bấm vào 1 dòng để mở chi tiết tài liệu đó.
  Widget _buildRelatedCard(
    BuildContext context,
    DocumentStateProvider provider,
    Document document,
  ) {
    final related = RecommendationService.getRelatedDocuments(
      document,
      provider.allDocuments,
      limit: 5,
    );
    if (related.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Column(
      children: [
        const SizedBox(height: 16),
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Tài liệu liên quan',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    const Tooltip(
                      message: 'Gợi ý dựa trên tag chung, cùng môn học, cùng loại tài liệu và từ khoá tiêu đề',
                      child: Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ...related.map((scored) {
                  final rel = scored.document;
                  final relSubject = provider.getSubjectById(rel.subjectId);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: rel.fileFormat.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        rel.fileFormat.icon,
                        color: rel.fileFormat.color,
                        size: 22,
                      ),
                    ),
                    title: Text(
                      rel.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      '${relSubject?.name ?? 'Chưa phân môn'} • ${(scored.score * 100).round()}% liên quan',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.grey,
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              DocumentDetailPage(documentId: rel.id),
                        ),
                      );
                    },
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailWidgetRow(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required Widget trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          const Spacer(),
          trailing,
        ],
      ),
    );
  }

  void _showShareDialog(BuildContext context, Document document) {
    showDialog(
      context: context,
      builder: (ctx) => _ShareDialog(document: document),
    );
  }
}

/// Thẻ tương tác và hiển thị trạng thái Firebase Cloud Storage
class _CloudStorageCard extends StatefulWidget {
  final Document document;

  const _CloudStorageCard({required this.document});

  @override
  State<_CloudStorageCard> createState() => _CloudStorageCardState();
}

class _CloudStorageCardState extends State<_CloudStorageCard> {
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  bool get _isStoredOnCloud =>
      widget.document.fileUrl != null &&
      widget.document.fileUrl!.contains('firebasestorage.googleapis.com');

  Future<void> _handleUploadToCloud(BuildContext context) async {
    final provider = context.read<DocumentStateProvider>();
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      final auth = GoogleAuthService();
      final uploaderUid = auth.currentUid ?? 'student_2351170599';
      final fileName =
          '${widget.document.title.replaceAll(" ", "_")}.${widget.document.fileFormat.name}';

      final dummyContent = utf8.encode(
        'StudyDocs DMS - Tài liệu: ${widget.document.title}\n'
        'Môn học: ${widget.document.subjectId}\n'
        'Người tải: $uploaderUid\n'
        'Thời gian: ${DateTime.now().toIso8601String()}',
      );

      final result = await FirebaseStorageService().uploadDocumentFile(
        uploaderUid: uploaderUid,
        documentId: widget.document.id,
        fileName: fileName,
        bytes: Uint8List.fromList(dummyContent),
        onProgress: (p) {
          if (mounted) {
            setState(() => _uploadProgress = p);
          }
        },
        customMetadata: {
          'subjectId': widget.document.subjectId,
          'documentType': widget.document.documentType.displayName,
        },
      );

      // Cập nhật Document với URL Cloud Storage mới
      final updatedDoc = widget.document.copyWith(
        filePath: result.storagePath,
        fileUrl: result.downloadUrl,
        fileSizeBytes: result.fileSizeBytes,
      );
      await provider.updateDocument(updatedDoc);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã đồng bộ lên Firebase Cloud Storage thành công!'),
            backgroundColor: Colors.teal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi tải lên Cloud Storage: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleDeleteFromCloud(BuildContext context) async {
    final confirm = await ConfirmDialog.show(
      context: context,
      title: 'Xóa tệp trên Cloud?',
      message: 'Bạn có chắc muốn xóa tệp này khỏi Firebase Cloud Storage?',
    );
    if (!confirm) return;

    final provider = context.read<DocumentStateProvider>();
    try {
      final auth = GoogleAuthService();
      final uploaderUid = auth.currentUid ?? 'student_2351170599';
      final fileName =
          '${widget.document.title.replaceAll(" ", "_")}.${widget.document.fileFormat.name}';
      final storedPath = widget.document.filePath;
      final path = storedPath != null && storedPath.startsWith('documents/')
          ? storedPath
          : FirebaseStorageService.buildStoragePath(
              uploaderUid: uploaderUid,
              documentId: widget.document.id,
              fileName: fileName,
            );

      await FirebaseStorageService().deleteDocumentFile(path);

      // Cập nhật Document gỡ bỏ link Cloud
      final updatedDoc = widget.document.copyWith(filePath: '', fileUrl: '');
      await provider.updateDocument(updatedDoc);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xóa tệp khỏi Firebase Cloud Storage.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi xóa tệp: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _isStoredOnCloud
                        ? Colors.teal.withValues(alpha: 0.15)
                        : Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _isStoredOnCloud
                        ? Icons.cloud_done_rounded
                        : Icons.cloud_upload_outlined,
                    color: _isStoredOnCloud ? Colors.teal : Colors.orange,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Firebase Cloud Storage',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _isStoredOnCloud
                            ? 'Đã đồng bộ lên Bucket đám mây'
                            : 'Chưa đồng bộ lên Cloud Storage',
                        style: TextStyle(
                          fontSize: 12,
                          color: _isStoredOnCloud ? Colors.teal : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _isStoredOnCloud
                        ? Colors.teal.withValues(alpha: 0.15)
                        : (isDark ? Colors.white10 : Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _isStoredOnCloud ? 'ĐÃ ĐỒNG BỘ' : 'OFFLINE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _isStoredOnCloud ? Colors.teal : Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
            if (_isUploading) ...[
              const SizedBox(height: 14),
              LinearProgressIndicator(
                value: _uploadProgress > 0 ? _uploadProgress : null,
              ),
              const SizedBox(height: 6),
              Text(
                'Đang tải lên Cloud Storage... ${(_uploadProgress * 100).toInt()}%',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
            if (_isStoredOnCloud && widget.document.fileUrl != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.link_rounded,
                      size: 16,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.document.fileUrl!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      tooltip: 'Sao chép URL',
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: widget.document.fileUrl!),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã sao chép link Cloud Storage!'),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isUploading
                        ? null
                        : () => _handleUploadToCloud(context),
                    icon: Icon(
                      _isStoredOnCloud
                          ? Icons.cloud_sync_rounded
                          : Icons.cloud_upload_rounded,
                    ),
                    label: Text(
                      _isStoredOnCloud
                          ? 'Tải lên lại'
                          : 'Tải lên Cloud Storage',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                if (_isStoredOnCloud) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.red,
                    ),
                    tooltip: 'Xóa tệp khỏi Cloud Storage',
                    onPressed: () => _handleDeleteFromCloud(context),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Thẻ hiển thị thông tin Chủ sở hữu & Phân quyền truy cập (Supabase RLS)
class _PermissionsCard extends StatelessWidget {
  final Document document;
  final bool isOwner;
  final SharePermission? perm;
  final VoidCallback onManageShares;

  const _PermissionsCard({
    required this.document,
    required this.isOwner,
    required this.perm,
    required this.onManageShares,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final permissionLabel = isOwner
        ? 'Chủ sở hữu (Owner - Toàn quyền)'
        : (perm != null
              ? perm!.displayName
              : (document.isPublic ? 'Công khai (Viewer)' : 'Chưa phân quyền'));

    final permissionColor = isOwner
        ? Colors.green
        : (perm != null
              ? perm!.color
              : (document.isPublic ? Colors.blue : Colors.grey));

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: permissionColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.security_rounded,
                    color: permissionColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Phân Quyền Truy Cập (Supabase RLS)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        isOwner
                            ? 'Bạn sở hữu tài liệu này với đầy đủ quyền CRUD'
                            : (perm?.canEdit == true
                                  ? 'Bạn có quyền sửa nội dung (Editor)'
                                  : 'Bạn có quyền xem và tải tệp (Viewer)'),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: permissionColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: permissionColor.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    isOwner
                        ? 'OWNER'
                        : (perm?.id.toUpperCase() ??
                              (document.isPublic ? 'PUBLIC' : 'VIEW')),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: permissionColor,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                const Icon(
                  Icons.person_pin_rounded,
                  size: 18,
                  color: Colors.blueGrey,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Chủ sở hữu:',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    document.ownerEmail != null &&
                            document.ownerEmail!.isNotEmpty
                        ? '${document.ownerEmail} ${isOwner ? "(Bạn)" : ""}'
                        : 'Nguyễn Văn Huỳnh (Nhóm trưởng)',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  document.isPublic
                      ? Icons.public_rounded
                      : Icons.lock_outline_rounded,
                  size: 18,
                  color: document.isPublic ? Colors.blue : Colors.orange,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Chế độ chia sẻ:',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey),
                ),
                const SizedBox(width: 6),
                Text(
                  document.isPublic
                      ? 'Công khai (Mọi người có thể đọc)'
                      : 'Riêng tư (Chỉ cấp cho người dùng cụ thể)',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: document.isPublic ? Colors.blue : Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.shield_outlined, size: 18, color: permissionColor),
                const SizedBox(width: 8),
                const Text(
                  'Quyền của bạn:',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey),
                ),
                const SizedBox(width: 6),
                Text(
                  permissionLabel,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: permissionColor,
                  ),
                ),
              ],
            ),
            if (isOwner) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('Quản lý Phân quyền & Chia sẻ'),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: onManageShares,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Hộp thoại Quản lý Chia sẻ Tài liệu & Phân quyền Supabase (Permissions Sheet)
class _ShareDialog extends StatefulWidget {
  final Document document;

  const _ShareDialog({required this.document});

  @override
  State<_ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<_ShareDialog> {
  final TextEditingController _emailController = TextEditingController();
  SharePermission _selectedPermission = SharePermission.view;
  bool _isSharing = false;

  final List<String> _suggestedEmails = [
    'chotommt123@gmail.com',
    'anhtuan160205@gmail.com',
    'trungkienn10a6@gmail.com',
  ];

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleShare(BuildContext context) async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập địa chỉ email hợp lệ.')),
      );
      return;
    }

    setState(() => _isSharing = true);
    final provider = context.read<DocumentStateProvider>();

    try {
      await provider.shareDocument(
        documentId: widget.document.id,
        sharedWithEmail: email,
        permission: _selectedPermission,
      );

      _emailController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.teal,
            behavior: SnackBarBehavior.floating,
            content: Text(
              'Đã cấp quyền ${_selectedPermission.displayName} cho $email!',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<void> _handleRevoke(
    BuildContext context,
    String shareId,
    String email,
  ) async {
    final provider = context.read<DocumentStateProvider>();
    try {
      await provider.revokeShare(shareId, widget.document.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            content: Text('Đã thu hồi quyền truy cập của $email!'),
          ),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DocumentStateProvider>();
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.share_rounded, color: AppTheme.primaryColor),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Phân Quyền & Chia Sẻ',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tài liệu: "${widget.document.title}"',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),

              // Nhập email
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email người nhận',
                  hintText: 'sinhvien@e.tlu.edu.vn',
                  prefixIcon: const Icon(Icons.email_outlined),
                  suffixIcon: DropdownButtonHideUnderline(
                    child: DropdownButton<SharePermission>(
                      value: _selectedPermission,
                      items: [
                        DropdownMenuItem(
                          value: SharePermission.view,
                          child: Text(
                            'Chỉ xem',
                            style: TextStyle(
                              color: SharePermission.view.color,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        DropdownMenuItem(
                          value: SharePermission.edit,
                          child: Text(
                            'Chỉnh sửa',
                            style: TextStyle(
                              color: SharePermission.edit.color,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null)
                          setState(() => _selectedPermission = val);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Gợi ý thành viên nhóm 16
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _suggestedEmails.map((email) {
                  return ActionChip(
                    label: Text(
                      email.split('@').first,
                      style: const TextStyle(fontSize: 11),
                    ),
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      _emailController.text = email;
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // Nút Thêm quyền
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: _isSharing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: const Text('Cấp quyền chia sẻ'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _isSharing ? null : () => _handleShare(context),
                ),
              ),

              const Divider(height: 28),
              const Text(
                'Danh sách người được chia sẻ:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              FutureBuilder<List<DocumentShare>>(
                future: provider.getSharesForDocument(widget.document.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }
                  final shares = snapshot.data ?? [];
                  if (shares.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Text(
                          'Chưa chia sẻ cho người dùng nào. Tài liệu đang ở chế độ riêng tư.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: shares.map((share) {
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: share.permission.color.withValues(
                            alpha: 0.15,
                          ),
                          child: Icon(
                            share.permission.icon,
                            color: share.permission.color,
                            size: 16,
                          ),
                        ),
                        title: Text(
                          share.sharedWithEmail,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          share.permission.displayName,
                          style: TextStyle(
                            fontSize: 11,
                            color: share.permission.color,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.remove_circle_outline,
                            color: Colors.redAccent,
                            size: 20,
                          ),
                          tooltip: 'Thu hồi quyền truy cập',
                          onPressed: () => _handleRevoke(
                            context,
                            share.id,
                            share.sharedWithEmail,
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Đóng'),
        ),
      ],
    );
  }
}
