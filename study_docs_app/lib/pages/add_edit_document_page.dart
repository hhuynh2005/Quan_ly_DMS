import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../functions.dart';
import '../struct/document_enums.dart';
import '../struct/document_model.dart';
import '../struct/document_state_provider.dart';
import '../struct/firebase_storage_service.dart';
import '../struct/google_auth_service.dart';
import '../struct/supabase_service.dart';
import '../theme.dart';
import '../widgets/cloud_transfer_progress.dart';

/// Màn hình Thêm mới hoặc Chỉnh sửa Tài liệu học tập (CRUD Create / Update)
class AddEditDocumentPage extends StatefulWidget {
  final Document? documentToEdit;
  final String? initialSubjectId;
  final String? initialFileName;
  final Uint8List? initialFileBytes;
  final int? initialFileSize;

  const AddEditDocumentPage({
    super.key,
    this.documentToEdit,
    this.initialSubjectId,
    this.initialFileName,
    this.initialFileBytes,
    this.initialFileSize,
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
  late TextEditingController _tagsController;
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

  String? _pickedFileName;
  Uint8List? _pickedFileBytes;
  int? _pickedFileSize;

  @override
  void initState() {
    super.initState();
    final doc = widget.documentToEdit;

    _pickedFileName = widget.initialFileName;
    _pickedFileBytes = widget.initialFileBytes;
    _pickedFileSize = widget.initialFileSize;

    if (_pickedFileName != null) {
      final nameWithoutExt = _pickedFileName!.contains('.')
          ? _pickedFileName!.substring(0, _pickedFileName!.lastIndexOf('.'))
          : _pickedFileName!;
      _titleController = TextEditingController(text: nameWithoutExt.replaceAll('_', ' '));
      _pathController = TextEditingController(text: _pickedFileName!);
      final ext = _pickedFileName!.contains('.') ? _pickedFileName!.split('.').last : '';
      _selectedFormat = DocumentFormatExtension.fromString(ext);
      if (_pickedFileSize != null) {
        _fileSizeController = TextEditingController(
          text: (_pickedFileSize! / (1024 * 1024)).toStringAsFixed(2),
        );
      } else {
        _fileSizeController = TextEditingController(text: '2.5');
      }
    } else {
      _titleController = TextEditingController(text: doc?.title ?? '');
      _pathController = TextEditingController(text: doc?.filePath ?? '');
      _fileSizeController = TextEditingController(
        text: doc != null && doc.fileSizeBytes > 0
            ? (doc.fileSizeBytes / (1024 * 1024)).toStringAsFixed(2)
            : '2.5',
      );
    }

    _descController = TextEditingController(text: doc?.description ?? '');
    _urlController = TextEditingController(text: doc?.fileUrl ?? '');
    _tagsController = TextEditingController(text: doc?.tags.join(', ') ?? '');

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
    _tagsController.dispose();
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

  /// Chọn tệp tài liệu trực tiếp từ máy tính / thiết bị
  Future<void> _pickFileFromDevice() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'doc',
          'docx',
          'ppt',
          'pptx',
          'xls',
          'xlsx',
          'txt',
          'png',
          'jpg',
          'jpeg',
          'zip',
        ],
      );

      if (file != null) {
        final bytes = await file.readAsBytes();
        final size = (await file.length()) ?? bytes.length;
        setState(() {
          _pickedFileName = file.name;
          _pickedFileBytes = bytes;
          _pickedFileSize = size;

          // Tự động điền tiêu đề từ tên file (loại bỏ phần mở rộng)
          final nameWithoutExt = file.name.contains('.')
              ? file.name.substring(0, file.name.lastIndexOf('.'))
              : file.name;
          _titleController.text = nameWithoutExt.replaceAll('_', ' ');

          // Tự động nhận diện định dạng file
          final ext = file.extension ?? '';
          _selectedFormat = DocumentFormatExtension.fromString(ext);

          // Cập nhật kích thước file dạng MB
          final sizeMb = size / (1024 * 1024);
          _fileSizeController.text = sizeMb.toStringAsFixed(2);

          // Điền đường dẫn tệp
          _pathController.text = file.name;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF3ECF8E),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Đã chọn tệp: ${file.name} (${(size / 1024).toStringAsFixed(1)} KB)'),
                  ),
                ],
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[AddEditDocumentPage] Lỗi chọn tệp: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            content: Text('Lỗi khi tải tệp từ máy tính: $e'),
          ),
        );
      }
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
      final tags = _tagsController.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      final sizeMb = double.tryParse(_fileSizeController.text.trim()) ?? 0.0;
      final sizeBytes = (sizeMb * 1024 * 1024).round();

      // Kích hoạt thanh tiến trình tải tệp Cloud Upload Progress (Nguyễn Trung Kiên)
      if (_syncToCloud) {
        final uploadOk = await CloudTransferProgress.showTransferSheet(
          context: context,
          type: TransferType.upload,
          fileName: _pickedFileName ?? '${_titleController.text.trim()}.${_selectedFormat.name}',
          totalBytes: sizeBytes > 0 ? sizeBytes : (2.5 * 1024 * 1024).round(),
          fileFormat: _selectedFormat,
        );
        if (!uploadOk && mounted) {
          setState(() => _isSaving = false);
          return;
        }
      }

      String? uploadedUrl;
      String? storagePath;

      final docId = widget.isEditing ? widget.documentToEdit!.id : const Uuid().v4();
      final authEmail = GoogleAuthService().currentUserEmail.isNotEmpty
          ? GoogleAuthService().currentUserEmail
          : 'anonymous@tlu.edu.vn';
      final authUid = GoogleAuthService().currentUserId.isNotEmpty
          ? GoogleAuthService().currentUserId
          : 'user_local';

      // 1. Tải tệp vật lý từ máy tính lên Firebase Storage
      if (_pickedFileBytes != null && _syncToCloud) {
        final fileName = _pickedFileName ?? '${_titleController.text.trim()}.${_selectedFormat.name}';
        try {
          final uploadRes = await FirebaseStorageService().uploadDocumentFile(
            uploaderUid: authUid,
            documentId: docId,
            fileName: fileName,
            bytes: _pickedFileBytes!,
          );
          uploadedUrl = uploadRes.downloadUrl;
          storagePath = uploadRes.storagePath;
          debugPrint('[AddEditDocumentPage] Tải tệp thành công lên Firebase Storage: $uploadedUrl');
        } catch (e) {
          debugPrint('[AddEditDocumentPage] Cảnh báo tải Firebase Storage: $e');
        }
      }

      final resolvedUrl = uploadedUrl ?? (_urlController.text.trim().isNotEmpty
          ? _urlController.text.trim()
          : (_syncToCloud
              ? 'https://firebasestorage.googleapis.com/v0/b/cashew-study-docs.appspot.com/o/${Uri.encodeComponent(_titleController.text.trim())}?alt=media'
              : null));

      final resolvedPath = storagePath ?? (_pathController.text.trim().isEmpty ? null : _pathController.text.trim());

      // 2. Lưu Metadata tài liệu lên Supabase PostgreSQL (có đầy đủ owner_email và owner_id)
      if (_syncToCloud) {
        try {
          await SupabaseService().createDocument(
            title: _titleController.text.trim(),
            description: _descController.text.trim(),
            subject: provider.getSubjectById(_selectedSubjectId!)?.name ?? 'Chung',
            fileFormat: _selectedFormat.name,
            fileSizeBytes: sizeBytes,
            fileUrl: resolvedUrl ?? '',
            storagePath: resolvedPath ?? 'documents/$docId',
            ownerId: authUid,
            ownerEmail: authEmail,
            isPublic: false,
          );
          debugPrint('[AddEditDocumentPage] Đã lưu vào bảng documents trên Supabase (Owner: $authEmail)');
        } catch (e) {
          debugPrint('[AddEditDocumentPage] Cảnh báo lưu Supabase: $e');
        }
      }

      if (widget.isEditing) {
        final currentDoc = widget.documentToEdit!;
        final updated = currentDoc.copyWith(
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          subjectId: _selectedSubjectId!,
          documentType: _selectedType,
          fileFormat: _selectedFormat,
          filePath: resolvedPath,
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
          filePath: resolvedPath,
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
            // 0. Khối chọn và tải tệp trực tiếp từ máy tính
            _buildFilePickerCard(theme, isDark),
            const SizedBox(height: 18),

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

            // 8. Tags phân loại
            TextFormField(
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText: 'Thẻ tag (phân cách bằng dấu phẩy)',
                hintText: 'TH1, Flutter, Slide, Chuẩn 3NF',
                prefixIcon: Icon(Icons.tag_rounded),
              ),
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

  Widget _buildFilePickerCard(ThemeData theme, bool isDark) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: _pickedFileName != null
              ? const Color(0xFF3ECF8E)
              : theme.colorScheme.primary.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      color: _pickedFileName != null
          ? const Color(0xFF3ECF8E).withValues(alpha: 0.08)
          : (isDark ? Colors.grey.shade900 : Colors.grey.shade50),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _pickedFileName != null
                        ? const Color(0xFF3ECF8E).withValues(alpha: 0.2)
                        : theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _pickedFileName != null
                        ? _selectedFormat.icon
                        : Icons.upload_file_rounded,
                    color: _pickedFileName != null
                        ? const Color(0xFF3ECF8E)
                        : theme.colorScheme.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _pickedFileName != null
                            ? 'Tệp từ máy tính đã chọn'
                            : 'Tải tệp từ máy tính / thiết bị',
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _pickedFileName != null
                            ? '$_pickedFileName (${(_pickedFileSize! / 1024).toStringAsFixed(1)} KB)'
                            : 'Hỗ trợ PDF, DOCX, PPTX, XLSX, TXT, Hình ảnh...',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: Icon(
                _pickedFileName != null ? Icons.change_circle_rounded : Icons.folder_open_rounded,
                size: 20,
              ),
              label: Text(
                _pickedFileName != null ? 'Chọn tệp khác từ máy tính' : 'Chọn tệp từ máy tính',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _pickedFileName != null
                    ? const Color(0xFF3ECF8E)
                    : theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _pickFileFromDevice,
            ),
          ],
        ),
      ),
    );
  }
}
