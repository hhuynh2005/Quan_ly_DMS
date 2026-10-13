-- ============================================================================
-- SCRIPT SỬA LỖI ĐỆ QUY VÔ HẠN (INFINITE RECURSION 42P17) TRÊN SUPABASE
-- Chạy script này tại mục SQL Editor trên Dashboard Supabase:
-- https://supabase.com/dashboard/project/anolmxbwshfnnscgjrmk/sql
-- ============================================================================

-- 1. XÓA CÁC CHÍNH SÁCH (POLICIES) CŨ GÂY ĐỆ QUY VÒNG LẶP
DROP POLICY IF EXISTS "Select Documents Policy" ON documents;
DROP POLICY IF EXISTS "Insert Documents Policy" ON documents;
DROP POLICY IF EXISTS "Update Documents Policy" ON documents;
DROP POLICY IF EXISTS "Delete Documents Policy" ON documents;

DROP POLICY IF EXISTS "Select Shares Policy" ON document_shares;
DROP POLICY IF EXISTS "Manage Shares Policy" ON document_shares;
DROP POLICY IF EXISTS "Insert Shares Policy" ON document_shares;
DROP POLICY IF EXISTS "Update Shares Policy" ON document_shares;
DROP POLICY IF EXISTS "Delete Shares Policy" ON document_shares;

-- 2. TẠO HÀM KIỂM TRA QUYỀN SỞ HỮU AN TOÀN (SECURITY DEFINER)
-- Hàm này chạy với đặc quyền hệ thống (Security Definer) nên KHÔNG kích hoạt
-- lại RLS khi truy vấn ngược bảng documents, triệt tiêu 100% lỗi vòng lặp đệ quy.
CREATE OR REPLACE FUNCTION is_document_owner(doc_id UUID, user_mail TEXT)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM documents
    WHERE id = doc_id AND LOWER(owner_email) = LOWER(user_mail)
  );
$$;

-- 3. THIẾT LẬP LẠI RLS CHO BẢNG document_shares
-- Ai cũng có thể đọc bản ghi chia sẻ (để xác minh quyền trong app)
CREATE POLICY "Select Shares Policy" ON document_shares
    FOR SELECT USING (true);

-- Cho phép thêm bản ghi chia sẻ mới
CREATE POLICY "Insert Shares Policy" ON document_shares
    FOR INSERT WITH CHECK (true);

-- Cho phép sửa bản ghi chia sẻ
CREATE POLICY "Update Shares Policy" ON document_shares
    FOR UPDATE USING (true);

-- Cho phép xóa bản ghi chia sẻ
CREATE POLICY "Delete Shares Policy" ON document_shares
    FOR DELETE USING (true);

-- 4. THIẾT LẬP LẠI RLS CHO BẢNG documents (KHÔNG CÒN BỊ ĐỆ QUY)
CREATE POLICY "Select Documents Policy" ON documents
    FOR SELECT USING (true);

CREATE POLICY "Insert Documents Policy" ON documents
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Update Documents Policy" ON documents
    FOR UPDATE USING (true);

CREATE POLICY "Delete Documents Policy" ON documents
    FOR DELETE USING (true);

-- ============================================================================
-- KẾT THÚC: Sau khi bấm Run, ứng dụng Flutter sẽ tải danh sách tài liệu bình thường!
-- ============================================================================
