import 'package:uuid/uuid.dart';
import '../struct/document_enums.dart';
import '../struct/document_location_model.dart';
import '../struct/document_model.dart';
import '../struct/subject_model.dart';

class MockData {
  static const uuid = Uuid();

  // Danh sách môn học mẫu
  static final List<Subject> initialSubjects = [
    Subject(
      id: 'subj_cse441',
      name: 'Lập trình Di động',
      code: 'CSE441',
      colorHex: '#00796B', // Emerald - Cashew branding
      iconName: 'code',
      semester: 'Học kỳ 1 - 2026',
      dateCreated: DateTime.now().subtract(const Duration(days: 30)),
    ),
    Subject(
      id: 'subj_cse380',
      name: 'Cơ sở Dữ liệu & SQLite',
      code: 'CSE380',
      colorHex: '#1976D2', // Blue
      iconName: 'database',
      semester: 'Học kỳ 1 - 2026',
      dateCreated: DateTime.now().subtract(const Duration(days: 30)),
    ),
    Subject(
      id: 'subj_cse370',
      name: 'Kiến trúc MT & Hệ điều hành',
      code: 'CSE370',
      colorHex: '#E65100', // Deep Orange
      iconName: 'laptop',
      semester: 'Học kỳ 1 - 2026',
      dateCreated: DateTime.now().subtract(const Duration(days: 28)),
    ),
    Subject(
      id: 'subj_cse484',
      name: 'Mạng Máy tính',
      code: 'CSE484',
      colorHex: '#6A1B9A', // Purple
      iconName: 'network',
      semester: 'Học kỳ 1 - 2026',
      dateCreated: DateTime.now().subtract(const Duration(days: 25)),
    ),
    Subject(
      id: 'subj_cse281',
      name: 'Cấu trúc Dữ liệu & Giải thuật',
      code: 'CSE281',
      colorHex: '#2E7D32', // Green
      iconName: 'calculate',
      semester: 'Học kỳ 1 - 2026',
      dateCreated: DateTime.now().subtract(const Duration(days: 25)),
    ),
  ];

  // Danh sách tài liệu mẫu
  static List<Document> getInitialDocuments() {
    final now = DateTime.now();
    return [
      Document(
        id: 'doc_th1_cashew',
        title: 'TH1: Xây dựng Ứng dụng Quản lý Tài liệu theo Kiến trúc Cashew',
        description: 'Bài thực hành yêu cầu phân tách các lớp (Database, Logic, UI), mô-đun hóa, CRUD tài liệu và viết báo cáo kiến trúc.',
        subjectId: 'subj_cse441',
        documentType: DocumentType.assignment,
        fileFormat: DocumentFormat.docx,
        filePath: 'documents/TH1_Kien_Truc_Cashew.docx',
        fileSizeBytes: 2450000, // 2.45 MB
        isFavorite: true,
        status: DocumentStatus.inProgress,
        priority: DocumentPriority.high,
        dueDate: now.add(const Duration(days: 3)),
        tags: ['TH1', 'Cashew', 'Flutter', 'KTPM'],
        dateCreated: now.subtract(const Duration(days: 2)),
      ),
      Document(
        id: 'doc_slide_kientruc',
        title: 'Slide Bài giảng: Tổng quan Kiến trúc Phần mềm Local-First & Drift ORM',
        description: 'Phân tích mô hình Monolithic Client, Reactive stream watchers và xử lý dữ liệu offline-first.',
        subjectId: 'subj_cse441',
        documentType: DocumentType.lecture,
        fileFormat: DocumentFormat.pptx,
        filePath: 'lectures/Chuong1_KienTruc_LocalFirst.pptx',
        fileSizeBytes: 8520000, // 8.52 MB
        isFavorite: true,
        status: DocumentStatus.completed,
        priority: DocumentPriority.high,
        tags: ['Slide', 'Lecture', 'Architecture'],
        dateCreated: now.subtract(const Duration(days: 5)),
      ),
      Document(
        id: 'doc_giaotrinh_flutter',
        title: 'Giáo trình Lập trình Ứng dụng Di động Đa nền tảng với Flutter & Dart',
        description: 'Tài liệu tham khảo chính thức về Widget tree, Provider pattern, Animation và Material You Design 3.',
        subjectId: 'subj_cse441',
        documentType: DocumentType.reference,
        fileFormat: DocumentFormat.pdf,
        filePath: 'books/Flutter_Complete_Guide_2026.pdf',
        fileUrl: 'https://flutter.dev/docs',
        fileSizeBytes: 18450000, // 18.45 MB
        isFavorite: true,
        status: DocumentStatus.completed,
        priority: DocumentPriority.medium,
        tags: ['GiaoTrinh', 'Flutter', 'Dart'],
        dateCreated: now.subtract(const Duration(days: 10)),
      ),
      Document(
        id: 'doc_csdl_sqlite',
        title: 'Tài liệu Thực hành Thiết kế Schema và Tối ưu hóa Truy vấn SQLite',
        description: 'Hướng dẫn viết DDL, Transaction, B-Tree Indexing và phân tích Execution Plan trong SQLite Database.',
        subjectId: 'subj_cse380',
        documentType: DocumentType.lecture,
        fileFormat: DocumentFormat.pdf,
        filePath: 'lectures/SQLite_Optimization_Guide.pdf',
        fileSizeBytes: 3200000, // 3.2 MB
        isFavorite: false,
        status: DocumentStatus.inProgress,
        priority: DocumentPriority.medium,
        tags: ['SQLite', 'Database', 'Index'],
        dateCreated: now.subtract(const Duration(days: 4)),
      ),
      Document(
        id: 'doc_bt_csdl',
        title: 'Bài tập 2: Thiết kế Lược đồ Thực thể Liên kết (ERD) và Chuẩn hóa 3NF',
        description: 'Bài tập nhóm mô hình hóa cơ sở dữ liệu hệ thống thông tin quản lý sinh viên.',
        subjectId: 'subj_cse380',
        documentType: DocumentType.assignment,
        fileFormat: DocumentFormat.docx,
        filePath: 'assignments/BT2_ERD_3NF.docx',
        fileSizeBytes: 1150000, // 1.15 MB
        isFavorite: false,
        status: DocumentStatus.newDoc,
        priority: DocumentPriority.medium,
        dueDate: now.add(const Duration(days: 6)),
        tags: ['BaiTap', 'ERD', '3NF'],
        dateCreated: now.subtract(const Duration(days: 1)),
      ),
      Document(
        id: 'doc_hdh_thread',
        title: 'Slide Bài giảng Chương 3: Quản lý Tiến trình, Tiểu trình và Bộ nhớ Ảo',
        description: 'Nguyên lý lập lịch CPU, đồng bộ tiến trình (Mutex, Semaphore) và cơ chế phân trang (Paging).',
        subjectId: 'subj_cse370',
        documentType: DocumentType.lecture,
        fileFormat: DocumentFormat.pptx,
        filePath: 'lectures/OS_Chapter3_Threads_Memory.pptx',
        fileSizeBytes: 6400000, // 6.4 MB
        isFavorite: false,
        status: DocumentStatus.completed,
        priority: DocumentPriority.low,
        tags: ['HDH', 'OS', 'Process', 'Thread'],
        dateCreated: now.subtract(const Duration(days: 8)),
      ),
      Document(
        id: 'doc_dethi_mang',
        title: 'Bộ Đề thi Mẫu Trắc nghiệm và Tự luận Môn Mạng Máy tính (Có Đáp án)',
        description: 'Tuyển tập 200 câu hỏi trắc nghiệm mô hình OSI, giao thức TCP/IP, định tuyến IP và subnetting.',
        subjectId: 'subj_cse484',
        documentType: DocumentType.exam,
        fileFormat: DocumentFormat.pdf,
        filePath: 'exams/DeThi_Mau_MangMayTinh_2026.pdf',
        fileSizeBytes: 4780000, // 4.78 MB
        isFavorite: true,
        status: DocumentStatus.newDoc,
        priority: DocumentPriority.high,
        dueDate: now.add(const Duration(days: 12)),
        tags: ['DeThi', 'MangMayTinh', 'TracNghiem'],
        dateCreated: now.subtract(const Duration(days: 3)),
      ),
      Document(
        id: 'doc_note_dijkstra',
        title: 'Ghi chú Tóm tắt: Phân tích Độ phức tạp Giải thuật Đồ thị (Dijkstra & Kruskal)',
        description: 'Ghi chép nhanh các dạng bài tập tìm đường đi ngắn nhất và cây khung nhỏ nhất.',
        subjectId: 'subj_cse281',
        documentType: DocumentType.note,
        fileFormat: DocumentFormat.txt,
        filePath: 'notes/Graph_Algorithms_Summary.txt',
        fileSizeBytes: 45000, // 45 KB
        isFavorite: false,
        status: DocumentStatus.inProgress,
        priority: DocumentPriority.low,
        tags: ['CTDL', 'GhiChu', 'Graph', 'Dijkstra'],
        dateCreated: now.subtract(const Duration(days: 6)),
      ),
    ];
  }

  // Danh sách vị trí vật lý mẫu của tài liệu tại ĐH Thủy Lợi (TH2)
  static List<DocumentLocation> getInitialLocations() {
    final now = DateTime.now();
    return [
      DocumentLocation(
        id: 'loc_th1_cashew',
        documentId: 'doc_th1_cashew',
        building: 'Nhà A4 (Khoa CNTT)',
        room: 'Phòng 301 - Lab Công nghệ Phần mềm',
        shelf: 'Tủ tài liệu KTPM - Ngăn 1',
        latitude: 21.00715,
        longitude: 105.82425,
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      DocumentLocation(
        id: 'loc_slide_kientruc',
        documentId: 'doc_slide_kientruc',
        building: 'Thư viện ĐH Thủy Lợi',
        room: 'Phòng mượn Tầng 2',
        shelf: 'Kệ TH-02 (Tin học)',
        latitude: 21.00742,
        longitude: 105.82491,
        createdAt: now.subtract(const Duration(days: 5)),
      ),
      DocumentLocation(
        id: 'loc_giaotrinh_flutter',
        documentId: 'doc_giaotrinh_flutter',
        building: 'Thư viện ĐH Thủy Lợi',
        room: 'Phòng tự học Tầng 3',
        shelf: 'Kệ GT-05 (Giáo trình CNTT)',
        latitude: 21.00746,
        longitude: 105.82498,
        createdAt: now.subtract(const Duration(days: 10)),
      ),
      DocumentLocation(
        id: 'loc_csdl_sqlite',
        documentId: 'doc_csdl_sqlite',
        building: 'Nhà A4 (Khoa CNTT)',
        room: 'Phòng 204 - Văn phòng Khoa',
        shelf: 'Ngăn CSDL & HTTT',
        latitude: 21.00712,
        longitude: 105.82420,
        createdAt: now.subtract(const Duration(days: 8)),
      ),
    ];
  }
}
