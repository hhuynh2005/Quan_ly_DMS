import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../functions.dart';
import '../struct/document_enums.dart';
import '../struct/document_model.dart';
import '../struct/document_state_provider.dart';
import 'cloud_sync_badge.dart';

/// Thẻ hiển thị Tài liệu học tập theo phong cách Material 3 / Cashew
class DocumentCard extends StatelessWidget {
  final Document document;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const DocumentCard({
    super.key,
    required this.document,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DocumentStateProvider>();
    final subject = provider.getSubjectById(document.subjectId);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final typeColor = document.documentType.color;
    final formatColor = document.fileFormat.color;
    final statusColor = document.status.color;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hàng 1: Icon định dạng + Tên môn học + Nút Favorite
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Icon định dạng file (PDF, DOCX, PPTX...)
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: formatColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      document.fileFormat.icon,
                      color: formatColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Môn học Badge
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subject?.name ?? 'Chưa phân môn',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: subject?.color ?? theme.colorScheme.primary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${document.fileFormat.extensionName} • ${AppFunctions.formatFileSize(document.fileSizeBytes)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Nút yêu thích
                  IconButton(
                    icon: Icon(
                      document.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: document.isFavorite ? Colors.amber : Colors.grey,
                      size: 24,
                    ),
                    onPressed: () {
                      provider.toggleFavorite(document.id);
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 20,
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Hàng 2: Tiêu đề tài liệu
              Text(
                document.title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              if (document.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  document.description,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.75),
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              const SizedBox(height: 12),

              // Hàng 3: Loại tài liệu (Badge) + Trạng thái học tập + Hạn nộp
              Row(
                children: [
                  // Badge Loại tài liệu (Bài giảng / Bài tập...)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(document.documentType.icon, size: 12, color: typeColor),
                        const SizedBox(width: 4),
                        Text(
                          document.documentType.displayName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: typeColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Badge Trạng thái học tập
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      document.status.displayName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Huy hiệu Cloud Sync Badge (Nguyễn Trung Kiên)
                  CloudSyncBadge(
                    status: document.cloudSyncStatus,
                    compact: false,
                  ),
                  if (document.tags.contains('shared') || document.tags.any((t) => t.startsWith('owner:'))) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.share_rounded, size: 10, color: Colors.blue),
                          SizedBox(width: 3),
                          Text(
                            'Được chia sẻ',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const Spacer(),

                  // Hạn nộp hoặc Ngày tạo
                  if (document.dueDate != null)
                    Row(
                      children: [
                        Icon(
                          Icons.alarm_rounded,
                          size: 13,
                          color: document.dueDate!.isBefore(DateTime.now())
                              ? Colors.red
                              : Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          AppFunctions.formatDate(document.dueDate),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: document.dueDate!.isBefore(DateTime.now())
                                ? Colors.red
                                : Colors.orange,
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      AppFunctions.formatRelativeDate(document.dateCreated),
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
