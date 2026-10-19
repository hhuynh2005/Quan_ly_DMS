import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../functions.dart';
import '../struct/document_enums.dart';
import '../struct/document_model.dart';
import '../struct/document_state_provider.dart';
import '../theme.dart';
import '../widgets/cloud_sync_badge.dart';
import '../widgets/cloud_transfer_progress.dart';
import '../widgets/confirm_dialog.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../struct/firebase_storage_service.dart';
import '../struct/google_auth_service.dart';
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
        body: const Center(child: Text('Tài liệu không tồn tại hoặc đã bị xóa.')),
      );
    }

    final document = doc;
    final subject = provider.getSubjectById(document.subjectId);
    final typeColor = document.documentType.color;
    final formatColor = document.fileFormat.color;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi Tiết Tài Liệu'),
        actions: [
          // Nút Favorite
          IconButton(
            icon: Icon(
              document.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
              color: document.isFavorite ? Colors.amber : null,
              size: 26,
            ),
            tooltip: 'Yêu thích',
            onPressed: () {
              provider.toggleFavorite(document.id);
            },
          ),
          // Nút Sửa
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            tooltip: 'Chỉnh sửa tài liệu',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AddEditDocumentPage(documentToEdit: document),
                ),
              );
            },
          ),
          // Nút Xóa
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
            tooltip: 'Xóa tài liệu',
            onPressed: () async {
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                        child: Icon(document.fileFormat.icon, color: formatColor, size: 28),
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
                                color: subject?.color ?? theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Mã môn: ${subject?.code ?? "N/A"} • ${subject?.semester ?? ""}',
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
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
                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                                    : (isDark ? Colors.white10 : Colors.grey.shade100),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected ? st.color : Colors.transparent,
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
                                      fontWeight:
                                          isSelected ? FontWeight.bold : FontWeight.normal,
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  _buildDetailWidgetRow(
                    context,
                    icon: document.cloudSyncStatus.icon,
                    iconColor: document.cloudSyncStatus.color,
                    label: 'Đồng bộ Đám mây Cloud',
                    trailing: CloudSyncBadge(
                      status: document.cloudSyncStatus,
                    ),
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
                    iconColor: document.dueDate != null ? Colors.orange : Colors.grey,
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tệp đính kèm & Liên kết',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (document.filePath != null && document.filePath!.isNotEmpty)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.folder_open_rounded),
                        title: Text(document.filePath!, style: const TextStyle(fontSize: 13)),
                        subtitle: const Text('Đường dẫn lưu trên thiết bị'),
                      ),
                    if (document.fileUrl != null && document.fileUrl!.isNotEmpty)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.open_in_browser_rounded, color: Colors.blue),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.cloud_sync_rounded, color: AppTheme.primaryColor, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Truyền tải Cloud Storage (Firebase)',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
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
                          icon: const Icon(Icons.cloud_download_rounded, size: 18),
                          label: const Text('Tải về máy'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0288D1),
                            side: const BorderSide(color: Color(0xFF0288D1)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () async {
                            final success = await CloudTransferProgress.showTransferSheet(
                              context: context,
                              type: TransferType.download,
                              fileName: '${document.title}.${document.fileFormat.name}',
                              totalBytes: document.fileSizeBytes > 0
                                  ? document.fileSizeBytes
                                  : 2 * 1024 * 1024,
                              fileFormat: document.fileFormat,
                            );
                            if (success && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: Color(0xFF0288D1),
                                  content: Text('Đã tải tài liệu về bộ nhớ ngoại tuyến thành công!'),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(Icons.cloud_upload_rounded, size: 18),
                          label: const Text('Đồng bộ Cloud'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () async {
                            final success = await CloudTransferProgress.showTransferSheet(
                              context: context,
                              type: TransferType.upload,
                              fileName: '${document.title}.${document.fileFormat.name}',
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
                                    content: Text('Đã đồng bộ tài liệu lên Firebase Cloud Storage!'),
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

          // 5. Firebase Cloud Storage Card
          _CloudStorageCard(document: document),
          const SizedBox(height: 16),

          // 6. Thẻ Tags
          if (document.tags.isNotEmpty)
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Thẻ phân loại (Tags)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: document.tags.map((tag) {
                        return Chip(
                          label: Text('#$tag'),
                          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.08),
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

          const SizedBox(height: 30),
        ],
      ),
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
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
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

  Future<void> _handleUploadToCloud() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final provider = context.read<DocumentStateProvider>();
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      final user = GoogleAuthService().currentUser;
      final uploaderUid = user?.uid ?? 'student_2351170599';
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
        fileUrl: result.downloadUrl,
        fileSizeBytes: result.fileSizeBytes,
      );
      await provider.updateDocument(updatedDoc);

      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Đã đồng bộ lên Firebase Cloud Storage thành công!'),
            backgroundColor: Colors.teal,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Lỗi khi tải lên Cloud Storage: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0.0;
        });
      }
    }
  }

  Future<void> _handleDeleteFromCloud() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final provider = context.read<DocumentStateProvider>();
    final confirm = await ConfirmDialog.show(
      context: context,
      title: 'Xóa tệp trên Cloud?',
      message: 'Bạn có chắc muốn xóa tệp này khỏi Firebase Cloud Storage?',
    );
    if (!confirm || !mounted) return;

    try {
      final user = GoogleAuthService().currentUser;
      final uploaderUid = user?.uid ?? 'student_2351170599';
      final fileName =
          '${widget.document.title.replaceAll(" ", "_")}.${widget.document.fileFormat.name}';
      final path = FirebaseStorageService.buildStoragePath(
        uploaderUid: uploaderUid,
        documentId: widget.document.id,
        fileName: fileName,
      );

      await FirebaseStorageService().deleteDocumentFile(path);

      // Cập nhật Document gỡ bỏ link Cloud
      final updatedDoc = widget.document.copyWith(fileUrl: '');
      await provider.updateDocument(updatedDoc);

      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Đã xóa tệp khỏi Firebase Cloud Storage.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Lỗi khi xóa tệp: $e'), backgroundColor: Colors.red),
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
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
              LinearProgressIndicator(value: _uploadProgress > 0 ? _uploadProgress : null),
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
                    const Icon(Icons.link_rounded, size: 16, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.document.fileUrl!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: Colors.blue),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      tooltip: 'Sao chép URL',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: widget.document.fileUrl!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Đã sao chép link Cloud Storage!')),
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
                    onPressed: _isUploading ? null : _handleUploadToCloud,
                    icon: Icon(
                        _isStoredOnCloud ? Icons.cloud_sync_rounded : Icons.cloud_upload_rounded),
                    label: Text(_isStoredOnCloud ? 'Tải lên lại' : 'Tải lên Cloud Storage'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                if (_isStoredOnCloud) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                    tooltip: 'Xóa tệp khỏi Cloud Storage',
                    onPressed: _handleDeleteFromCloud,
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
