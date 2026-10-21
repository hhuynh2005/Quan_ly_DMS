-- ===================================================================================
-- BÀI TẬP THỰC HÀNH 2 (TH2): PHÁT TRIỂN HỆ THỐNG QUẢN LÝ TÀI LIỆU ĐA NỀN TẢNG (SMART DMS)
-- THIẾT KẾ KIẾN TRÚC HỆ THỐNG VÀ MÔ HÌNH DỮ LIỆU POSTGRESQL TRÊN SUPABASE (MỤC 1)
-- Nhóm trưởng phụ trách: Nguyễn Văn Huỳnh (MSV: 2351170599) - Nhóm 16
-- ===================================================================================

-- 1. BẬT CÁC EXTENSION CẦN THIẾT
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ===================================================================================
-- 2. TẠO CÁC KIỂU DỮ LIỆU ENUM (ĐỒNG BỘ VỚI FLUTTER MODEL)
-- ===================================================================================
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'document_type_enum') THEN
        CREATE TYPE document_type_enum AS ENUM ('lecture', 'assignment', 'exam', 'reference', 'note');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'file_format_enum') THEN
        CREATE TYPE file_format_enum AS ENUM ('pdf', 'docx', 'xlsx', 'pptx', 'txt', 'zip');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'document_status_enum') THEN
        CREATE TYPE document_status_enum AS ENUM ('new', 'in_progress', 'completed', 'archived');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'borrow_status_enum') THEN
        CREATE TYPE borrow_status_enum AS ENUM ('pending', 'approved', 'rejected', 'returned', 'overdue');
    END IF;
END $$;

-- ===================================================================================
-- 3. BẢNG MÔN HỌC (SUBJECTS)
-- ===================================================================================
CREATE TABLE IF NOT EXISTS subjects (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    name TEXT NOT NULL,
    code TEXT NOT NULL UNIQUE,
    color_hex TEXT NOT NULL DEFAULT '#00796B',
    icon_name TEXT NOT NULL DEFAULT 'book',
    semester TEXT DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- ===================================================================================
-- 4. BẢNG TÀI LIỆU HỌC TẬP (DOCUMENTS)
-- Kết hợp metadata lưu trữ đám mây Supabase / Firebase Storage
-- ===================================================================================
CREATE TABLE IF NOT EXISTS documents (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    title TEXT NOT NULL,
    description TEXT,
    subject_id TEXT NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
    document_type document_type_enum NOT NULL DEFAULT 'lecture',
    file_format file_format_enum NOT NULL DEFAULT 'pdf',
    file_path TEXT,
    file_url TEXT,
    file_size_bytes BIGINT NOT NULL DEFAULT 0,
    is_favorite BOOLEAN NOT NULL DEFAULT FALSE,
    status document_status_enum NOT NULL DEFAULT 'new',
    priority TEXT NOT NULL DEFAULT 'medium',
    due_date TIMESTAMPTZ,
    tags TEXT[] NOT NULL DEFAULT '{}',
    uploader_uid TEXT NOT NULL DEFAULT 'anonymous',
    uploader_email TEXT NOT NULL DEFAULT 'student@e.tlu.edu.vn',
    is_public BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- ===================================================================================
-- 5. BẢNG VỊ TRÍ VẬT LÝ TÀI LIỆU TẠI ĐH THỦY LỢI (DOCUMENT_LOCATIONS - MỤC 3)
-- Phụ trách: Nguyễn Trung Kiên & Nguyễn Văn Huỳnh
-- ===================================================================================
CREATE TABLE IF NOT EXISTS document_locations (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    document_id TEXT NOT NULL UNIQUE REFERENCES documents(id) ON DELETE CASCADE,
    building TEXT NOT NULL,
    room TEXT NOT NULL,
    shelf TEXT,
    latitude DOUBLE PRECISION NOT NULL DEFAULT 21.00742,
    longitude DOUBLE PRECISION NOT NULL DEFAULT 105.82479,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- ===================================================================================
-- 6. BẢNG YÊU CẦU MƯỢN / TRẢ TÀI LIỆU (BORROW_REQUESTS - MỤC 4)
-- Phụ trách: Lê Anh Tuấn & Nguyễn Văn Huỳnh
-- ===================================================================================
CREATE TABLE IF NOT EXISTS borrow_requests (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    document_id TEXT NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    document_title TEXT NOT NULL,
    borrower_id TEXT NOT NULL,
    borrower_email TEXT NOT NULL,
    borrower_name TEXT NOT NULL,
    owner_id TEXT NOT NULL,
    owner_email TEXT NOT NULL,
    owner_name TEXT NOT NULL,
    status borrow_status_enum NOT NULL DEFAULT 'pending',
    request_date TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    approved_date TIMESTAMPTZ,
    due_date TIMESTAMPTZ,
    returned_date TIMESTAMPTZ,
    note TEXT,
    rejection_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- ===================================================================================
-- 7. BẢNG QUẢN LÝ THẺ TAG VÀ TỪ KHÓA GỢI Ý (TAGS - MỤC 3 & MỤC 5)
-- Phụ trách: Trần Anh Tuấn & Nguyễn Văn Huỳnh
-- ===================================================================================
CREATE TABLE IF NOT EXISTS tags (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    name TEXT NOT NULL UNIQUE,
    slug TEXT NOT NULL UNIQUE,
    usage_count INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Bảng liên kết nhiều-nhiều giữa Document và Tag (Hỗ trợ truy vấn Content-based)
CREATE TABLE IF NOT EXISTS document_tags (
    document_id TEXT NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    tag_id TEXT NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
    PRIMARY KEY (document_id, tag_id)
);

-- ===================================================================================
-- 8. BẢNG SỞ THÍCH NGƯỜI DÙNG CHO RECOMMENDATION (USER_PREFERENCES - MỤC 5)
-- ===================================================================================
CREATE TABLE IF NOT EXISTS user_preferences (
    user_email TEXT PRIMARY KEY,
    favorite_subjects TEXT[] DEFAULT '{}',
    frequent_tags TEXT[] DEFAULT '{}',
    recent_read_document_ids TEXT[] DEFAULT '{}',
    notification_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- ===================================================================================
-- 9. TỐI ƯU HÓA CHỈ MỤC TRUY VẤN (INDEXES)
-- ===================================================================================
CREATE INDEX IF NOT EXISTS idx_documents_subject ON documents(subject_id);
CREATE INDEX IF NOT EXISTS idx_documents_status ON documents(status);
CREATE INDEX IF NOT EXISTS idx_documents_type ON documents(document_type);
CREATE INDEX IF NOT EXISTS idx_documents_uploader ON documents(uploader_email);
CREATE INDEX IF NOT EXISTS idx_documents_tags ON documents USING GIN(tags);

CREATE INDEX IF NOT EXISTS idx_locations_doc ON document_locations(document_id);
CREATE INDEX IF NOT EXISTS idx_locations_building ON document_locations(building);

CREATE INDEX IF NOT EXISTS idx_borrow_doc ON borrow_requests(document_id);
CREATE INDEX IF NOT EXISTS idx_borrow_borrower ON borrow_requests(borrower_email);
CREATE INDEX IF NOT EXISTS idx_borrow_owner ON borrow_requests(owner_email);
CREATE INDEX IF NOT EXISTS idx_borrow_status ON borrow_requests(status);

-- ===================================================================================
-- 10. TRIGGER TỰ ĐỘNG CẬP NHẬT UPDATED_AT
-- ===================================================================================
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = timezone('utc'::text, now());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_set_updated_at_documents ON documents;
CREATE TRIGGER trigger_set_updated_at_documents
    BEFORE UPDATE ON documents
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trigger_set_updated_at_borrow_requests ON borrow_requests;
CREATE TRIGGER trigger_set_updated_at_borrow_requests
    BEFORE UPDATE ON borrow_requests
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trigger_set_updated_at_locations ON document_locations;
CREATE TRIGGER trigger_set_updated_at_locations
    BEFORE UPDATE ON document_locations
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ===================================================================================
-- 11. BẢO MẬT ROW LEVEL SECURITY (RLS) ĐA TẦNG CHO TH2
-- ===================================================================================
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE document_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE borrow_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_preferences ENABLE ROW LEVEL SECURITY;

-- 11.1 Chính sách phân quyền bảng Documents:
-- Người dùng đọc được tài liệu nếu là công khai (is_public = true) hoặc là chủ sở hữu hoặc đang được duyệt mượn
CREATE POLICY "Public or Owned documents can be viewed"
    ON documents FOR SELECT
    USING (
        is_public = TRUE
        OR auth.jwt() ->> 'email' = uploader_email
        OR EXISTS (
            SELECT 1 FROM borrow_requests
            WHERE borrow_requests.document_id = documents.id
            AND borrow_requests.borrower_email = auth.jwt() ->> 'email'
            AND borrow_requests.status = 'approved'
        )
    );

CREATE POLICY "Users can create their own documents"
    ON documents FOR INSERT
    WITH CHECK (auth.jwt() ->> 'email' IS NOT NULL);

CREATE POLICY "Owners can update their own documents"
    ON documents FOR UPDATE
    USING (auth.jwt() ->> 'email' = uploader_email);

CREATE POLICY "Owners can delete their own documents"
    ON documents FOR DELETE
    USING (auth.jwt() ->> 'email' = uploader_email);

-- 11.2 Chính sách phân quyền bảng Borrow Requests:
-- Người mượn và chủ sở hữu đều xem được yêu cầu liên quan đến mình
CREATE POLICY "Users can view borrow requests involving them"
    ON borrow_requests FOR SELECT
    USING (
        auth.jwt() ->> 'email' = borrower_email
        OR auth.jwt() ->> 'email' = owner_email
    );

CREATE POLICY "Borrowers can create borrow requests"
    ON borrow_requests FOR INSERT
    WITH CHECK (auth.jwt() ->> 'email' = borrower_email);

CREATE POLICY "Owners can approve or reject borrow requests"
    ON borrow_requests FOR UPDATE
    USING (auth.jwt() ->> 'email' = owner_email);

-- 11.3 Chính sách phân quyền bảng Document Locations:
CREATE POLICY "Anyone can view document locations"
    ON document_locations FOR SELECT
    USING (TRUE);

CREATE POLICY "Document owners can modify locations"
    ON document_locations FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM documents
            WHERE documents.id = document_locations.document_id
            AND documents.uploader_email = auth.jwt() ->> 'email'
        )
    );

-- ===================================================================================
-- 12. CẤU HÌNH SUPABASE STORAGE BUCKET: study_documents
-- ===================================================================================
INSERT INTO storage.buckets (id, name, public)
VALUES ('study_documents', 'study_documents', true)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "Public read access for study_documents bucket"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'study_documents');

CREATE POLICY "Authenticated users can upload study documents"
    ON storage.objects FOR INSERT
    WITH CHECK (bucket_id = 'study_documents' AND auth.role() = 'authenticated');

-- ===================================================================================
-- 13. KÍCH HOẠT SUPABASE REALTIME STREAM CHO TH2
-- ===================================================================================
DO $$ BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE documents;
    ALTER PUBLICATION supabase_realtime ADD TABLE borrow_requests;
    ALTER PUBLICATION supabase_realtime ADD TABLE document_locations;
EXCEPTION WHEN OTHERS THEN
    -- Bỏ qua nếu bảng đã nằm trong publication
    NULL;
END $$;

-- Hoàn tất thiết kế Kiến trúc dữ liệu TH2 (Nguyễn Văn Huỳnh - 2351170599)
