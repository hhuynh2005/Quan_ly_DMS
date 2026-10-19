/// Định nghĩa cấu trúc Schema các bảng SQLite theo phong cách kiến trúc Cashew
class AppTables {
  // Tên các bảng
  static const String tableDocuments = 'documents';
  static const String tableSubjects = 'subjects';
  static const String tableDeleteLogs = 'delete_logs';
  static const String tableAppSettings = 'app_settings';
  static const String tableBorrowRequests = 'borrow_requests';

  // Câu lệnh tạo bảng Môn học (Subjects)
  static const String createTableSubjects = '''
    CREATE TABLE IF NOT EXISTS $tableSubjects (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      code TEXT NOT NULL UNIQUE,
      color_hex TEXT NOT NULL DEFAULT '#00796B',
      icon_name TEXT NOT NULL DEFAULT 'book',
      semester TEXT DEFAULT '',
      date_created TEXT NOT NULL,
      date_modified TEXT NOT NULL
    );
  ''';

  // Câu lệnh tạo bảng Tài liệu học tập (Documents)
  static const String createTableDocuments = '''
    CREATE TABLE IF NOT EXISTS $tableDocuments (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      description TEXT,
      subject_id TEXT NOT NULL,
      document_type TEXT NOT NULL,
      file_format TEXT NOT NULL DEFAULT 'pdf',
      file_path TEXT,
      file_url TEXT,
      file_size_bytes INTEGER DEFAULT 0,
      is_favorite INTEGER NOT NULL DEFAULT 0,
      status TEXT NOT NULL DEFAULT 'new',
      priority TEXT NOT NULL DEFAULT 'medium',
      due_date TEXT,
      tags TEXT,
      date_created TEXT NOT NULL,
      date_modified TEXT NOT NULL,
      FOREIGN KEY (subject_id) REFERENCES $tableSubjects (id) ON DELETE CASCADE
    );
  ''';

  // Câu lệnh tạo bảng Nhật ký xóa (Delete Logs - Tương tự Cashew để audit / đồng bộ delta)
  static const String createTableDeleteLogs = '''
    CREATE TABLE IF NOT EXISTS $tableDeleteLogs (
      id TEXT PRIMARY KEY,
      item_id TEXT NOT NULL,
      table_name TEXT NOT NULL,
      date_deleted TEXT NOT NULL
    );
  ''';

  // Câu lệnh tạo bảng Cài đặt ứng dụng (App Settings)
  static const String createTableAppSettings = '''
    CREATE TABLE IF NOT EXISTS $tableAppSettings (
      key TEXT PRIMARY KEY,
      value TEXT,
      date_modified TEXT NOT NULL
    );
  ''';

  // Câu lệnh tạo bảng Yêu cầu mượn tài liệu (Borrow Requests - TH2 Mục 4)
  static const String createTableBorrowRequests = '''
    CREATE TABLE IF NOT EXISTS $tableBorrowRequests (
      id TEXT PRIMARY KEY,
      document_id TEXT NOT NULL,
      document_title TEXT NOT NULL,
      borrower_id TEXT NOT NULL,
      borrower_email TEXT NOT NULL,
      borrower_name TEXT NOT NULL,
      owner_id TEXT NOT NULL,
      owner_email TEXT NOT NULL,
      owner_name TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'pending',
      request_date TEXT NOT NULL,
      approved_date TEXT,
      due_date TEXT,
      returned_date TEXT,
      note TEXT,
      rejection_reason TEXT
    );
  ''';

  // Các chỉ mục (Indexes) để tăng tốc độ truy vấn
  static const List<String> createIndexes = [
    'CREATE INDEX IF NOT EXISTS idx_docs_subject ON $tableDocuments (subject_id);',
    'CREATE INDEX IF NOT EXISTS idx_docs_type ON $tableDocuments (document_type);',
    'CREATE INDEX IF NOT EXISTS idx_docs_status ON $tableDocuments (status);',
    'CREATE INDEX IF NOT EXISTS idx_docs_created ON $tableDocuments (date_created DESC);',
    'CREATE INDEX IF NOT EXISTS idx_borrow_document ON $tableBorrowRequests (document_id);',
    'CREATE INDEX IF NOT EXISTS idx_borrow_borrower ON $tableBorrowRequests (borrower_email);',
    'CREATE INDEX IF NOT EXISTS idx_borrow_owner ON $tableBorrowRequests (owner_email);',
  ];
}
