import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../functions.dart';
import '../struct/document_enums.dart';
import '../struct/document_model.dart';
import '../struct/document_state_provider.dart';
import '../struct/tag_service.dart';
import '../theme.dart';
import '../widgets/cloud_transfer_progress.dart';
import '../widgets/smart_tagging_widget.dart';

/// Màn hình Thêm mới hoặc Chỉnh sửa Tài liệu học tập (CRUD Create / Update)
class AddEditDocumentPage extends StatefulWidget {
  final Document? documentToEdit;
  final String? initialSubjectId;

  const AddEditDocumentPage({
    super.key,
    this.documentToEdit,
    this.initialSubjectId,
  });

  bool get isEditing => documentToEdit != null;

  @override
  State<AddEditDocumentPage> createState() => _AddEditDocumentPageState();
}

class _AddEditDocumentPageState extends State<AddEditDocumentPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _urlController;
  late TextEditingController _pathController;
  List<String> _tags = [];
  late TextEditingController _fileSizeController;

  String? _selectedSubjectId;
  DocumentType _selectedType = DocumentType.lecture;
  DocumentFormat _selectedFormat = DocumentFormat.pdf;
  DocumentStatus _selectedStatus = DocumentStatus.newDoc;
  DocumentPriority _selectedPriority = DocumentPriority.medium;
  DateTime? _selectedDueDate;
  bool _isFavorite = false;
  bool _isSaving = false;
  bool _syncToCloud = true;

  @override
  void initState() {
    super.initState();
    final doc = widget.documentToEdit;

    _titleController = TextEditingController(text: doc?.title ?? '');
    _descController = TextEditingController(text: doc?.description ?? '');
    _urlController = TextEditingController(text: doc?.fileUrl ?? '');
    _pathController = TextEditingController(text: doc?.filePath ?? '');
    _tags = TagService.normalizeTags(doc?.tags ?? []);
    _fileSizeController = TextEditingController(
      text: doc != null && doc.fileSizeBytes > 0
          ? (doc.fileSizeBytes / (1024 * 1024)).toStringAsFixed(2)
          : '2.5',
    );

    _selectedSubjectId = doc?.subjectId ?? widget.initialSubjectId;
    if (doc != null) {
      _selectedType = doc.documentType;
      _selectedFormat = doc.fileFormat;
      _selectedStatus = doc.status;
      _selectedPriority = doc.priority;
      _selectedDueDate = doc.dueDate;
      _isFavorite = doc.isFavorite;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_selectedSubjectId == null) {
      final subjects = context.read<DocumentStateProvider>().subjects;
      if (subjects.isNotEmpty) {
        _selectedSubjectId = subjects.first.id;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _urlController.dispose();
    _pathController.dispose();
    _fileSizeController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? now.add(const Duration(days: 7)),
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );

    if (pickedDate != null && mounted) {
      setState(() {
        _selectedDueDate = pickedDate;
      });
    }
  }

  Future<void> _saveDocument() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedSubjectId == null || _selectedSubjectId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn môn học cho tài liệu.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final provider = context.read<DocumentStateProvider>();
      final tags = _tags;

      final sizeMb = double.tryParse(_fileSizeController.text.trim()) ?? 0.0;
      final sizeBytes = (sizeMb * 1024 * 1024).round();

      // Kích hoạt thanh tiến trình tải tệp Cloud Upload Progress (Nguyễn Trung Kiên)
      if (_syncToCloud) {
        final uploadOk = await CloudTransferProgress.showTransferSheet(
          context: context,
          type: TransferType.upload,
          fileName: '${_titleController.text.trim()}.${_selectedFormat.name}',
          totalBytes: sizeBytes > 0 ? sizeBytes : (2.5 * 1024 * 1024).round(),
          fileFormat: _selectedFormat,
        );
        if (!uploadOk && mounted) {
          setState(() => _isSaving = false);
          return;
        }
      }

      final resolvedUrl = _urlController.text.trim().isNotEmpty
          ? _urlController.text.trim()
          : (_syncToCloud
              ? 'https://firebasestorage.googleapis.com/v0/b/cashew-study-docs.appspot.com/o/${Uri.encodeComponent(_titleController.text.trim())}?alt=media'
              : null);

      if (widget.isEditing) {
        final currentDoc = widget.documentToEdit!;
        final updated = currentDoc.copyWith(
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          subjectId: _selectedSubjectId!,
          documentType: _selectedType,
          fileFormat: _selectedFormat,
          filePath: _pathController.text.trim().isEmpty ? null : _pathController.text.trim(),
          fileUrl: resolvedUrl,
          fileSizeBytes: sizeBytes,
          isFavorite: _isFavorite,
          status: _selectedStatus,
          priority: _selectedPriority,
          dueDate: _selectedDueDate,
          tags: tags,
          cloudSyncStatus: _syncToCloud ? CloudSyncStatus.synced : CloudSyncStatus.pending,
        );
        await provider.updateDocument(updated);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã cập nhật thông tin tài liệu thành công!')),
          );
          Navigator.of(context).pop(updated);
        }
      } else {
        final newDoc = await provider.addDocument(
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          subjectId: _selectedSubjectId!,
          documentType: _selectedType,
          fileFormat: _selectedFormat,
          filePath: _pathController.text.trim().isEmpty ? null : _pathController.text.trim(),
          fileUrl: resolvedUrl,
          fileSizeBytes: sizeBytes,
          isFavorite: _isFavorite,
          status: _selectedStatus,
          priority: _selectedPriority,
          dueDate: _selectedDueDate,
          tags: tags,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã thêm tài liệu mới thành công!')),
          );
          Navigator.of(context).pop(newDoc);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DocumentStateProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Sửa Tài Liệu' : 'Thêm Tài Liệu Mới'),
        actions: [
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
              color: _isFavorite ? Colors.amber : null,
              size: 26,
            ),
            tooltip: 'Đánh dấu yêu thích',
            onPressed: () {
              setState(() => _isFavorite = !_isFavorite);
            },
          ),
          IconButton(
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
            tooltip: 'Lưu',
            onPressed: _isSaving ? null : _saveDocument,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 1. Tiêu đề tài liệu
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Tiêu đề tài liệu *',
                hintText: 'Nhập tên bài giảng, bài tập, đề thi...',
                prefixIcon: Icon(Icons.title_rounded),
              ),
              textInputAction: TextInputAction.next,
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Tiêu đề không được để trống';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // 2. Chọn Môn học
            DropdownButtonFormField<String>(
              initialValue: _selectedSubjectId,
              decoration: const InputDecoration(
                labelText: 'Môn học *',
                prefixIcon: Icon(Icons.category_rounded),
              ),
              items: provider.subjects.map((sub) {
                return DropdownMenuItem<String>(
                  value: sub.id,
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: sub.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${sub.code} - ${sub.name}'),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) {
                setState(() => _selectedSubjectId = val);
              },
              validator: (val) => val == null ? 'Vui lòng chọn môn học' : null,
            ),
            const SizedBox(height: 16),

            // 3. Phân loại tài liệu & Định dạng tệp
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<DocumentType>(
                    initialValue: _selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Loại tài liệu',
                      prefixIcon: Icon(Icons.class_rounded),
                    ),
                    items: DocumentType.values.map((type) {
                      return DropdownMenuItem<DocumentType>(
                        value: type,
                        child: Row(
                          children: [
                            Icon(type.icon, size: 18, color: type.color),
                            const SizedBox(width: 8),
                            Text(type.displayName),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedType = val);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<DocumentFormat>(
                    initialValue: _selectedFormat,
                    decoration: const InputDecoration(
                      labelText: 'Định dạng',
                      prefixIcon: Icon(Icons.file_present_rounded),
                    ),
                    items: DocumentFormat.values.map((fmt) {
                      return DropdownMenuItem<DocumentFormat>(
                        value: fmt,
                        child: Row(
                          children: [
                            Icon(fmt.icon, size: 18, color: fmt.color),
                            const SizedBox(width: 8),
                            Text(fmt.extensionName),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedFormat = val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 4. Trạng thái học & Mức độ ưu tiên
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<DocumentStatus>(
                    initialValue: _selectedStatus,
                    decoration: const InputDecoration(
                      labelText: 'Trạng thái',
                      prefixIcon: Icon(Icons.flaky_rounded),
                    ),
                    items: DocumentStatus.values.map((st) {
                      return DropdownMenuItem<DocumentStatus>(
                        value: st,
                        child: Text(st.displayName),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedStatus = val);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<DocumentPriority>(
                    initialValue: _selectedPriority,
                    decoration: const InputDecoration(
                      labelText: 'Mức ưu tiên',
                      prefixIcon: Icon(Icons.priority_high_rounded),
                    ),
                    items: DocumentPriority.values.map((p) {
                      return DropdownMenuItem<DocumentPriority>(
                        value: p,
                        child: Text(p.displayName),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedPriority = val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 5. Hạn nộp / Deadline (Date Picker)
            InkWell(
              onTap: _pickDueDate,
              borderRadius: BorderRadius.circular(14),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Hạn nộp / Ngày kiểm tra',
                  prefixIcon: const Icon(Icons.calendar_month_rounded),
                  suffixIcon: _selectedDueDate != null
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () => setState(() => _selectedDueDate = null),
                        )
                      : null,
                ),
                child: Text(
                  _selectedDueDate != null
                      ? AppFunctions.formatDate(_selectedDueDate)
                      : 'Không có hạn chót',
                  style: TextStyle(
                    color: _selectedDueDate != null ? null : Colors.grey,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 6. Mô tả / Ghi chú
            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Mô tả tóm tắt nội dung',
                hintText: 'Ghi chú các phần cần chú ý trong bài giảng hoặc bài tập...',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // 7. Đường dẫn tệp / URL & Dung lượng
            TextFormField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'Liên kết tải / Google Drive URL (nếu có)',
                hintText: 'https://drive.google.com/...',
                prefixIcon: Icon(Icons.link_rounded),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _pathController,
                    decoration: const InputDecoration(
                      labelText: 'Đường dẫn tệp máy (File path)',
                      hintText: 'documents/lecture1.pdf',
                      prefixIcon: Icon(Icons.folder_open_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _fileSizeController,
                    decoration: const InputDecoration(
                      labelText: 'Kích thước (MB)',
                      prefixIcon: Icon(Icons.data_usage_rounded),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 8. Tags phân loại (SmartTaggingWidget - Trần Anh Tuấn)
            SmartTaggingWidget.edit(
              initialTags: _tags,
              allDocuments: provider.allDocuments,
              titleController: _titleController,
              descriptionController: _descController,
              onTagsChanged: (tags) => setState(() => _tags = tags),
            ),
            const SizedBox(height: 18),

            // 9. Tùy chọn đồng bộ Cloud (Nguyễn Trung Kiên)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: AppTheme.primaryColor.withValues(alpha: 0.35),
                  width: 1.2,
                ),
              ),
              child: SwitchListTile.adaptive(
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cloud_upload_rounded,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Đồng bộ lên Firebase Cloud Storage',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'Tải tệp lên đám mây (Asia-Southeast1) và kích hoạt thanh tiến trình',
                  style: TextStyle(fontSize: 11.5),
                ),
                value: _syncToCloud,
                activeTrackColor: AppTheme.primaryColor,
                onChanged: (val) => setState(() => _syncToCloud = val),
              ),
            ),
            const SizedBox(height: 24),

            // Nút Lưu tài liệu
            FilledButton.icon(
              onPressed: _isSaving ? null : _saveDocument,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(
                widget.isEditing ? 'LƯU THAY ĐỔI' : 'TẠO TÀI LIỆU MỚI',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
