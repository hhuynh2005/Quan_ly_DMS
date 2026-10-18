import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../functions.dart';
import '../struct/document_enums.dart';
import '../struct/document_model.dart';
import '../struct/document_state_provider.dart';
import '../struct/supabase_storage_service.dart';
import '../struct/supabase_service.dart';
import '../struct/tag_service.dart';
import '../theme.dart';
import '../widgets/cloud_transfer_progress.dart';

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
  bool _isPublic = false;
  Uint8List? _pickedFileBytes;
  String? _pickedFileName;

  // --- Tag nâng cao (Trần Anh Tuấn) ---
  /// Gợi ý autocomplete khi người dùng đang gõ tag.
  List<String> _tagSuggestions = [];

  /// Ứng viên tag do máy tự trích xuất từ tiêu đề/mô tả.
  List<String> _autoTagCandidates = [];

  @override
  void initState() {
    super.initState();
    final doc = widget.documentToEdit;

    _titleController = TextEditingController(text: doc?.title ?? '');
    _descController = TextEditingController(text: doc?.description ?? '');
    _urlController = TextEditingController(text: doc?.fileUrl ?? '');
    _pathController = TextEditingController(text: doc?.filePath ?? '');
    _tagsController = TextEditingController(text: doc?.tags.join(', ') ?? '');
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
      _isPublic = doc.isPublic;
    }

    // Lắng nghe ô nhập tag để refresh gợi ý autocomplete theo từng ký tự.
    _tagsController.addListener(_onTagsChanged);
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

  /// Refresh gợi ý autocomplete mỗi khi nội dung ô tag thay đổi.
  /// Chỉ gợi ý theo "từ đang gõ" (đoạn sau dấu phẩy cuối cùng),
  /// và loại bỏ tag đã có trong ô nhập.
  void _onTagsChanged() {
    if (!mounted) return;
    final docs = context.read<DocumentStateProvider>().allDocuments;
    final currentWord = _tagsController.text.split(',').last;
    final existing = TagService.parseTagsInput(_tagsController.text).toSet();
    final suggestions = TagService.suggestTags(
      docs,
      currentWord,
    ).where((s) => !existing.contains(s)).toList();
    if (!_stringListsEqual(_tagSuggestions, suggestions)) {
      setState(() => _tagSuggestions = suggestions);
    }
  }

  bool _stringListsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Áp dụng 1 gợi ý: thêm vào cuối ô nhập, giữ định dạng "a, b, ".
  void _applyTagSuggestion(String suggestion) {
    final existing = TagService.parseTagsInput(_tagsController.text);
    if (!existing.contains(suggestion)) existing.add(suggestion);
    _tagsController.text = existing.isEmpty ? '' : '${existing.join(', ')}, ';
    _tagsController.selection = TextSelection.fromPosition(
      TextPosition(offset: _tagsController.text.length),
    );
  }

  /// Tự động trích xuất ứng viên tag từ tiêu đề + mô tả hiện tại.
  /// Người dùng bấm vào từng chip để thêm (không tự gắn ẩu).
  void _generateAutoTags() {
    final existing = TagService.parseTagsInput(_tagsController.text).toSet();
    final tempDoc = Document(
      id: 'temp-autotag',
      title: _titleController.text,
      description: _descController.text,
      subjectId: _selectedSubjectId ?? '',
      documentType: _selectedType,
      tags: existing.toList(),
    );
    final candidates = TagService.extractCandidateTags(tempDoc)
        .where((c) => !existing.contains(c))
        .toList();
    setState(() => _autoTagCandidates = candidates);
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

  /// Thêm 1 ứng viên tag vào ô nhập và gỡ nó khỏi danh sách ứng viên.
  void _addAutoTag(String tag) {
    _applyTagSuggestion(tag);
    setState(
      () => _autoTagCandidates = _autoTagCandidates
          .where((t) => t != tag)
          .toList(),
    );
  }

  /// Chọn tệp tin thực tế từ máy tính / điện thoại của người dùng
  /// (file_picker v13: FilePicker.pickFiles() trả về List<PlatformFile>,
  /// đọc nội dung bằng await file.readAsBytes())
  Future<void> _pickFileFromDevice() async {
    try {
      final files = await FilePicker.pickFiles(
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
          'md',
          'png',
          'jpg',
          'jpeg',
          'zip',
        ],
      );

      if (files.isNotEmpty) {
        final file = files.first;
        final bytes = await file.readAsBytes();
        final fileSize = bytes.length;
        final nameParts = file.name.split('.');
        final ext = nameParts.length > 1 ? nameParts.last.toLowerCase() : '';

        setState(() {
          _pickedFileBytes = bytes;
          _pickedFileName = file.name;

          // Tự động điền tiêu đề nếu chưa có
          if (_titleController.text.trim().isEmpty) {
            final dotIdx = file.name.lastIndexOf('.');
            _titleController.text = dotIdx > 0
                ? file.name.substring(0, dotIdx)
                : file.name;
          }

          // Tự động nhận diện định dạng tệp
          _selectedFormat = DocumentFormatExtension.fromString(ext);

          // Cập nhật kích thước tệp theo MB
          final mb = fileSize / (1024 * 1024);
          _fileSizeController.text = mb.toStringAsFixed(2);
          _pathController.text = file.name;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.teal,
              behavior: SnackBarBehavior.floating,
              content: Text(
                'Đã chọn tệp: ${file.name} (${AppFunctions.formatFileSize(fileSize)})',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể chọn tệp: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
      // Tag nâng cao: chuẩn hoá (viết thường, bỏ trùng, gộp khoảng trắng).
      final tags = TagService.parseTagsInput(_tagsController.text);

      final sizeMb = double.tryParse(_fileSizeController.text.trim()) ?? 0.0;
      var sizeBytes = (sizeMb * 1024 * 1024).round();

      String? resolvedUrl = _urlController.text.trim().isNotEmpty
          ? _urlController.text.trim()
          : null;
      String? resolvedFilePath = _pathController.text.trim().isEmpty
          ? null
          : _pathController.text.trim();
      String? newDocumentId;

      // 1. TẢI TỆP VẬT LÝ LÊN SUPABASE STORAGE (NẾU CÓ CHỌN TỆP TỪ MÁY)
      if (_pickedFileBytes != null && _pickedFileBytes!.isNotEmpty) {
        final uploaderUid = provider.currentUserId ?? 'uid_huynh_group16_owner';
        final fileName =
            _pickedFileName ??
            '${_titleController.text.trim().replaceAll(" ", "_")}.${_selectedFormat.name}';
        final targetDocId = widget.documentToEdit?.id ?? const Uuid().v4();
        newDocumentId = targetDocId;

        // Hiển thị dialog "đang tải" (Supabase SDK không hỗ trợ báo %
        // tiến trình nên dùng vòng xoay vô định kèm tên file/dung lượng).
        final totalBytes = _pickedFileBytes!.length;
        BuildContext? dialogCtx;

        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) {
              dialogCtx = ctx;
              return PopScope(
                canPop: false,
                child: AlertDialog(
                  title: const Text('Đang tải tệp lên...'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppFunctions.formatFileSize(totalBytes),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(),
                      const SizedBox(height: 8),
                      const Text(
                        'Vui lòng giữ màn hình này cho đến khi tải xong.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        }

        try {
          final uploadResult = await SupabaseStorageService()
              .uploadDocumentFile(
                uploaderUid: uploaderUid,
                documentId: targetDocId,
                fileName: fileName,
                bytes: _pickedFileBytes!,
              );

          resolvedUrl = uploadResult.downloadUrl;
          resolvedFilePath = uploadResult.storagePath;
          sizeBytes = uploadResult.fileSizeBytes;
        } finally {
          final ctx = dialogCtx;
          if (ctx != null && ctx.mounted) {
            Navigator.of(ctx).pop();
          }
        }
      } else if (_syncToCloud) {
        // Mô phỏng thanh tiến trình upload nếu chưa có URL
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
        // Không tự chế URL giả: giữ resolvedUrl = null khi chưa có file thật
        // để tránh lưu link 404 vào database.
      }

      // 2. LƯU THÔNG TIN METADATA VÀO SUPABASE & CƠ SỞ DỮ LIỆU CỤC BỘ
      if (widget.isEditing) {
        final currentDoc = widget.documentToEdit!;
        final updated = currentDoc.copyWith(
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          subjectId: _selectedSubjectId!,
          documentType: _selectedType,
          fileFormat: _selectedFormat,
          filePath: resolvedFilePath,
          fileUrl: resolvedUrl,
          fileSizeBytes: sizeBytes,
          isFavorite: _isFavorite,
          isPublic: _isPublic,
          status: _selectedStatus,
          priority: _selectedPriority,
          dueDate: _selectedDueDate,
          tags: tags,
          cloudSyncStatus: _syncToCloud
              ? CloudSyncStatus.synced
              : CloudSyncStatus.pending,
        );
        await provider.updateDocument(updated);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.teal,
              content: Text(
                'Đã cập nhật thông tin tài liệu lên Supabase thành công!',
              ),
            ),
          );
          Navigator.of(context).pop(updated);
        }
      } else {
        final newDoc = await provider.addDocument(
          id: newDocumentId,
          title: _titleController.text.trim(),
          subjectId: _selectedSubjectId!,
          description: _descController.text.trim(),
          documentType: _selectedType,
          fileFormat: _selectedFormat,
          filePath: resolvedFilePath,
          fileUrl: resolvedUrl,
          fileSizeBytes: sizeBytes,
          isFavorite: _isFavorite,
          isPublic: _isPublic,
          status: _selectedStatus,
          priority: _selectedPriority,
          dueDate: _selectedDueDate,
          tags: tags,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.teal,
              content: Text('Đã thêm tài liệu mới vào Supabase thành công!'),
            ),
          );
          Navigator.of(context).pop(newDoc);
        }
      }
    } on PermissionDeniedException catch (pde) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(pde.message),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
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
              value: _selectedSubjectId,
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
                    value: _selectedType,
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
                    value: _selectedFormat,
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
                    value: _selectedStatus,
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
                    value: _selectedPriority,
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
                          onPressed: () =>
                              setState(() => _selectedDueDate = null),
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

            // 7. Chọn tệp vật lý từ máy tính / thiết bị (File Picker)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: _pickedFileBytes != null
                      ? Colors.teal
                      : (Theme.of(context).brightness == Brightness.dark
                            ? Colors.white24
                            : Colors.grey.shade300),
                  width: 1.3,
                ),
              ),
              color: _pickedFileBytes != null
                  ? Colors.teal.withValues(alpha: 0.08)
                  : null,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _pickedFileBytes != null
                              ? Icons.check_circle_rounded
                              : Icons.upload_file_rounded,
                          color: _pickedFileBytes != null
                              ? Colors.teal
                              : AppTheme.primaryColor,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Tệp tin vật lý (Từ máy cá nhân)',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (_pickedFileBytes != null)
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            tooltip: 'Gỡ tệp đã chọn',
                            onPressed: () {
                              setState(() {
                                _pickedFileBytes = null;
                                _pickedFileName = null;
                              });
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (_pickedFileBytes != null) ...[
                      Text(
                        'Đã chọn: $_pickedFileName',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.teal,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Dung lượng: ${AppFunctions.formatFileSize(_pickedFileBytes!.length)} • Định dạng: ${_selectedFormat.extensionName}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ] else ...[
                      Text(
                        'Tải tệp từ máy tính (PDF, Word, Slide, Excel, Zip) trực tiếp lên Supabase Storage (bucket documents).',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white70
                              : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    OutlinedButton.icon(
                      icon: const Icon(Icons.folder_open_rounded, size: 18),
                      label: Text(
                        _pickedFileBytes != null
                            ? 'Chọn tệp khác từ máy'
                            : 'Chọn tệp từ máy cá nhân',
                        style: const TextStyle(fontSize: 13),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        side: const BorderSide(color: AppTheme.primaryColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _pickFileFromDevice,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 8. Đường dẫn tệp / URL & Dung lượng
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
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 9. Tags phân loại (nâng cao: autocomplete + auto-tag)
            TextFormField(
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText: 'Thẻ tag (phân cách bằng dấu phẩy)',
                hintText: 'TH1, Flutter, Slide, Chuẩn 3NF',
                prefixIcon: Icon(Icons.tag_rounded),
              ),
            ),
            // Gợi ý autocomplete theo từng ký tự đang gõ
            if (_tagSuggestions.isNotEmpty) ...[
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
                  ..._tagSuggestions.map(
                    (s) => ActionChip(
                      label: Text(s),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _applyTagSuggestion(s),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            // Nút tự động trích xuất tag từ tiêu đề/mô tả
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                label: const Text(
                  'Tự động gợi ý tag từ tiêu đề/mô tả',
                  style: TextStyle(fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  side: const BorderSide(color: AppTheme.primaryColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _generateAutoTags,
              ),
            ),
            if (_autoTagCandidates.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _autoTagCandidates
                    .map(
                      (c) => ActionChip(
                        avatar: const Icon(Icons.add_rounded, size: 16),
                        label: Text(c),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _addAutoTag(c),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 18),

            // 10. Phân quyền chia sẻ công khai (RLS is_public)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Colors.blue.withValues(alpha: 0.35),
                  width: 1.2,
                ),
              ),
              child: SwitchListTile.adaptive(
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.public_rounded,
                    color: Colors.blue,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Chia sẻ công khai (Public Access)',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'Cho phép tất cả thành viên đọc tài liệu này mà không cần cấp quyền riêng',
                  style: TextStyle(fontSize: 11.5),
                ),
                value: _isPublic,
                activeTrackColor: Colors.blue,
                onChanged: (val) => setState(() => _isPublic = val),
              ),
            ),
            const SizedBox(height: 12),

            // 11. Tùy chọn đồng bộ Cloud (Nguyễn Trung Kiên)
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
                  'Đồng bộ lên Supabase Storage',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'Tải tệp lên Supabase Storage, metadata lưu vào database',
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
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(
                widget.isEditing ? 'LƯU THAY ĐỔI' : 'TẠO TÀI LIỆU MỚI',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
