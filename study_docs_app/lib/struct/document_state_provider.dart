import 'dart:async';

import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../functions.dart';
import 'document_enums.dart';
import 'cloud_sync_service.dart';
import 'document_location_model.dart';
import 'document_model.dart';
import 'document_repository.dart';
import 'subject_model.dart';

/// Provider quản lý State toàn cục cho ứng dụng theo chuẩn Provider/ChangeNotifier của Cashew
class DocumentStateProvider extends ChangeNotifier {
  final DocumentRepository _repository;
  final CloudSyncService? _cloudSync;

  List<Document> _allDocuments = [];
  List<Subject> _subjects = [];
  List<DocumentLocation> _locations = [];
  Map<String, int> _stats = {
    'total_documents': 0,
    'total_subjects': 0,
    'lectures_count': 0,
    'assignments_count': 0,
    'completed_count': 0,
    'in_progress_count': 0,
    'favorites_count': 0,
  };

  bool _isLoading = true;
  String _searchQuery = '';
  String? _selectedSubjectId;
  DocumentType? _selectedType;
  DocumentStatus? _selectedStatus;
  bool _showFavoritesOnly = false;
  String _sortBy = 'date_desc';

  // Stream Subscriptions
  StreamSubscription<List<Document>>? _docsSub;
  StreamSubscription<List<Subject>>? _subjectsSub;
  StreamSubscription<List<DocumentLocation>>? _locationsSub;
  StreamSubscription<Map<String, int>>? _statsSub;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _syncDebounce;
  User? _currentUser;
  bool _isOnline = true;
  bool _isSyncing = false;
  bool _syncAgainAfterCurrent = false;
  String? _syncError;
  DateTime? _lastSyncedAt;
  CloudSyncResult? _lastSyncResult;

  DocumentStateProvider({
    DocumentRepository? repository,
    CloudSyncService? cloudSync,
  }) : this._(repository ?? DocumentRepository(), cloudSync);

  DocumentStateProvider._(this._repository, this._cloudSync) {
    _init();
  }

  // Getters
  bool get isLoading => _isLoading;
  List<Document> get allDocuments => _allDocuments;
  List<Subject> get subjects => _subjects;
  List<DocumentLocation> get locations => _locations;
  Map<String, int> get stats => _stats;
  String get searchQuery => _searchQuery;
  String? get selectedSubjectId => _selectedSubjectId;
  DocumentType? get selectedType => _selectedType;
  DocumentStatus? get selectedStatus => _selectedStatus;
  bool get showFavoritesOnly => _showFavoritesOnly;
  String get sortBy => _sortBy;
  bool get cloudSyncAvailable => _cloudSync != null;
  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  String? get syncError => _syncError;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  CloudSyncResult? get lastSyncResult => _lastSyncResult;
  User? get currentUser => _currentUser;
  bool get localDatabaseIsPersistent =>
      !_repository.databaseIsUsingMemoryFallback;

  /// Danh sách tài liệu sau khi áp dụng toàn bộ các bộ lọc đang kích hoạt
  List<Document> get filteredDocuments {
    var result = List<Document>.from(_allDocuments);

    // Lọc theo Môn học
    if (_selectedSubjectId != null && _selectedSubjectId!.isNotEmpty) {
      result = result.where((d) => d.subjectId == _selectedSubjectId).toList();
    }

    // Lọc theo Loại tài liệu
    if (_selectedType != null) {
      result = result.where((d) => d.documentType == _selectedType).toList();
    }

    // Lọc theo Trạng thái học tập
    if (_selectedStatus != null) {
      result = result.where((d) => d.status == _selectedStatus).toList();
    }

    // Lọc theo Mục yêu thích
    if (_showFavoritesOnly) {
      result = result.where((d) => d.isFavorite).toList();
    }

    // Lọc theo Từ khóa tìm kiếm (hỗ trợ không dấu tiếng Việt)
    if (_searchQuery.trim().isNotEmpty) {
      result = result.where((d) {
        return AppFunctions.matchesSearch(d.title, _searchQuery) ||
            AppFunctions.matchesSearch(d.description, _searchQuery) ||
            d.tags.any((t) => AppFunctions.matchesSearch(t, _searchQuery));
      }).toList();
    }

    // Sắp xếp
    switch (_sortBy) {
      case 'date_asc':
        result.sort((a, b) => a.dateCreated.compareTo(b.dateCreated));
        break;
      case 'title_asc':
        result.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
        break;
      case 'due_date':
        result.sort((a, b) {
          if (a.dueDate == null && b.dueDate == null) return 0;
          if (a.dueDate == null) return 1;
          if (b.dueDate == null) return -1;
          return a.dueDate!.compareTo(b.dueDate!);
        });
        break;
      case 'date_desc':
      default:
        result.sort((a, b) => b.dateCreated.compareTo(a.dateCreated));
        break;
    }

    return result;
  }

  /// Tài liệu gần đây nhất (Recent 5)
  List<Document> get recentDocuments {
    final list = List<Document>.from(_allDocuments);
    list.sort((a, b) => b.dateCreated.compareTo(a.dateCreated));
    return list.take(5).toList();
  }

  /// Tài liệu yêu thích
  List<Document> get favoriteDocuments {
    return _allDocuments.where((d) => d.isFavorite).toList();
  }

  /// Khởi tạo và lắng nghe Reactive Streams
  void _init() {
    _isLoading = true;
    notifyListeners();

    // Lắng nghe stream tài liệu
    _docsSub = _repository.watchAllDocuments().listen(
      (docs) {
        _allDocuments = docs;
        _isLoading = false;
        notifyListeners();
      },
      onError: (err) {
        debugPrint('Provider error watching docs: $err');
        _isLoading = false;
        notifyListeners();
      },
    );

    // Lắng nghe stream môn học
    _subjectsSub = _repository.watchSubjects().listen(
      (subs) {
        _subjects = subs;
        notifyListeners();
      },
      onError: (err) {
        debugPrint('Provider error watching subjects: $err');
      },
    );

    // Lắng nghe stream thống kê
    _statsSub = _repository.watchStats().listen(
      (s) {
        _stats = s;
        notifyListeners();
      },
      onError: (err) {
        debugPrint('Provider error watching stats: $err');
      },
    );

    // Lắng nghe stream vị trí vật lý tài liệu (TH2)
    _locationsSub = _repository.watchDocumentLocations().listen(
      (locs) {
        _locations = locs;
        notifyListeners();
      },
      onError: (err) {
        debugPrint('Provider error watching locations: $err');
      },
    );

    if (_cloudSync != null) {
      _authSub = _cloudSync.authChanges.listen(
        (user) {
          _currentUser = user;
          _syncError = null;
          if (user == null) {
            _lastSyncedAt = null;
            _lastSyncResult = null;
          }
          notifyListeners();
          if (user != null) _scheduleSync();
        },
        onError: (Object error) {
          _syncError = error.toString();
          notifyListeners();
        },
      );
      _connectivitySub = Connectivity().onConnectivityChanged.listen(
        _updateConnectivity,
        onError: (Object error) {
          _syncError = 'Không theo dõi được kết nối mạng: $error';
          notifyListeners();
        },
      );
      unawaited(_checkConnectivity());
    }
  }

  Future<void> _checkConnectivity() async {
    try {
      _updateConnectivity(await Connectivity().checkConnectivity());
    } catch (error) {
      _syncError = 'Không kiểm tra được kết nối mạng: $error';
      notifyListeners();
    }
  }

  void _updateConnectivity(List<ConnectivityResult> results) {
    final online = results.any((result) => result != ConnectivityResult.none);
    final becameOnline = online && !_isOnline;
    _isOnline = online;
    if (online) _syncError = null;
    notifyListeners();
    if (becameOnline && _currentUser != null) _scheduleSync();
  }

  void _scheduleSync() {
    if (_cloudSync == null || _currentUser == null) return;
    _syncDebounce?.cancel();
    _syncDebounce = Timer(const Duration(milliseconds: 700), () {
      unawaited(
        syncNow().catchError((Object error) {
          debugPrint('Automatic cloud sync failed: $error');
        }),
      );
    });
  }

  Future<void> signIn(String email, String password) async {
    final cloudSync = _cloudSync;
    if (cloudSync == null) throw StateError('Firebase chưa được khởi tạo.');
    await cloudSync.signIn(email, password);
  }

  Future<void> createCloudAccount(String email, String password) async {
    final cloudSync = _cloudSync;
    if (cloudSync == null) throw StateError('Firebase chưa được khởi tạo.');
    await cloudSync.createAccount(email, password);
  }

  Future<void> signOutCloudAccount() async {
    final cloudSync = _cloudSync;
    if (cloudSync == null) return;
    _syncDebounce?.cancel();
    await cloudSync.signOut();
  }

  Future<void> syncNow() async {
    final cloudSync = _cloudSync;
    if (cloudSync == null) {
      const message =
          'Firebase chưa được khởi tạo. Kiểm tra cấu hình ứng dụng.';
      _syncError = message;
      notifyListeners();
      throw StateError(message);
    }
    if (_currentUser == null) {
      const message = 'Đăng nhập Firebase trước khi đồng bộ.';
      _syncError = message;
      notifyListeners();
      throw StateError(message);
    }
    if (!_isOnline) {
      _syncError = 'Đang offline. Thay đổi vẫn được lưu cục bộ.';
      notifyListeners();
      return;
    }
    if (_isSyncing) {
      _syncAgainAfterCurrent = true;
      return;
    }

    _isSyncing = true;
    _syncError = null;
    notifyListeners();
    try {
      _lastSyncResult = await cloudSync.sync();
      _lastSyncedAt = DateTime.now();
    } catch (error) {
      _syncError = error.toString();
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
      if (_syncAgainAfterCurrent) {
        _syncAgainAfterCurrent = false;
        _scheduleSync();
      }
    }
  }

  void handleAppResumed() {
    if (_currentUser != null) _scheduleSync();
  }

  // ===========================================================================
  // CÁC THAO TÁC LỌC VÀ TÌM KIẾM
  // ===========================================================================

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSelectedSubject(String? subjectId) {
    _selectedSubjectId = subjectId;
    notifyListeners();
  }

  void setSelectedType(DocumentType? type) {
    _selectedType = type;
    notifyListeners();
  }

  void setSelectedStatus(DocumentStatus? status) {
    _selectedStatus = status;
    notifyListeners();
  }

  void toggleFavoritesOnly() {
    _showFavoritesOnly = !_showFavoritesOnly;
    notifyListeners();
  }

  void setSortBy(String sortBy) {
    _sortBy = sortBy;
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedSubjectId = null;
    _selectedType = null;
    _selectedStatus = null;
    _showFavoritesOnly = false;
    _sortBy = 'date_desc';
    notifyListeners();
  }

  // ===========================================================================
  // TƯƠNG TÁC NGHIỆP VỤ CRUD
  // ===========================================================================

  Subject? getSubjectById(String subjectId) {
    try {
      return _subjects.firstWhere((s) => s.id == subjectId);
    } catch (_) {
      return null;
    }
  }

  int getDocumentCountBySubject(String subjectId) {
    return _allDocuments.where((d) => d.subjectId == subjectId).length;
  }

  Future<Document> addDocument({
    required String title,
    String description = '',
    required String subjectId,
    required DocumentType documentType,
    DocumentFormat fileFormat = DocumentFormat.pdf,
    String? filePath,
    String? fileUrl,
    int fileSizeBytes = 0,
    bool isFavorite = false,
    DocumentStatus status = DocumentStatus.newDoc,
    DocumentPriority priority = DocumentPriority.medium,
    DateTime? dueDate,
    List<String>? tags,
  }) async {
    final doc = await _repository.createDocument(
      title: title,
      description: description,
      subjectId: subjectId,
      documentType: documentType,
      fileFormat: fileFormat,
      filePath: filePath,
      fileUrl: fileUrl,
      fileSizeBytes: fileSizeBytes,
      isFavorite: isFavorite,
      status: status,
      priority: priority,
      dueDate: dueDate,
      tags: tags,
    );
    _scheduleSync();
    return doc;
  }

  Future<Document> updateDocument(Document doc) async {
    final updated = await _repository.updateDocument(doc);
    _scheduleSync();
    return updated;
  }

  Future<void> deleteDocument(String id) async {
    await _repository.deleteDocument(id);
    _scheduleSync();
  }

  Future<bool> toggleFavorite(String id) async {
    final updated = await _repository.toggleFavorite(id);
    _scheduleSync();
    return updated;
  }

  Future<void> updateDocumentStatus(String id, DocumentStatus newStatus) async {
    await _repository.updateDocumentStatus(id, newStatus);
    _scheduleSync();
  }

  Future<Subject> addSubject({
    required String name,
    required String code,
    String colorHex = '#00796B',
    String iconName = 'book',
    String semester = '',
  }) async {
    final subject = await _repository.createSubject(
      name: name,
      code: code,
      colorHex: colorHex,
      iconName: iconName,
      semester: semester,
    );
    _scheduleSync();
    return subject;
  }

  Future<Subject> updateSubject(Subject subject) async {
    final updated = await _repository.updateSubject(subject);
    _scheduleSync();
    return updated;
  }

  Future<void> deleteSubject(String id) async {
    await _repository.deleteSubject(id);
    _scheduleSync();
    if (_selectedSubjectId == id) {
      _selectedSubjectId = null;
    }
  }

  Future<void> resetToDefault() async {
    await _repository.resetData();
    _scheduleSync();
  }

  // ===========================================================================
  // VỊ TRÍ VẬT LÝ TÀI LIỆU (DOCUMENT LOCATIONS - TH2)
  // ===========================================================================

  /// Lấy vị trí vật lý của tài liệu theo documentId
  DocumentLocation? getLocationForDocument(String documentId) {
    try {
      return _locations.firstWhere((l) => l.documentId == documentId);
    } catch (_) {
      return null;
    }
  }

  /// Lưu hoặc cập nhật vị trí vật lý của tài liệu
  Future<void> saveDocumentLocation(DocumentLocation location) async {
    await _repository.saveDocumentLocation(location);
    _scheduleSync();
    notifyListeners();
  }

  /// Xóa vị trí vật lý của tài liệu
  Future<void> deleteDocumentLocation(String documentId) async {
    await _repository.deleteDocumentLocation(documentId);
    _scheduleSync();
    notifyListeners();
  }

  /// Lấy danh sách tài liệu đang đặt tại một tòa nhà cụ thể
  List<Document> getDocumentsInBuilding(String building) {
    final docIds = _locations
        .where((l) => l.building.toLowerCase().contains(building.toLowerCase()))
        .map((l) => l.documentId)
        .toSet();
    return _allDocuments.where((d) => docIds.contains(d.id)).toList();
  }

  @override
  void dispose() {
    _docsSub?.cancel();
    _subjectsSub?.cancel();
    _locationsSub?.cancel();
    _statsSub?.cancel();
    _authSub?.cancel();
    _connectivitySub?.cancel();
    _syncDebounce?.cancel();
    super.dispose();
  }
}
