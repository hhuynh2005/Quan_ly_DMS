import 'package:intl/intl.dart';

/// Tiện ích định dạng ngày giờ, kích thước tệp và xử lý chuỗi
class AppFunctions {
  /// Định dạng ngày tháng hiển thị dạng: dd/MM/yyyy
  static String formatDate(DateTime? date) {
    if (date == null) return 'Không có';
    
    return DateFormat('dd/MM/yyyy').format(date);
  }

  /// Định dạng ngày giờ hiển thị dạng: dd/MM/yyyy HH:mm
  static String formatDateTime(DateTime? date) {
    if (date == null) return 'Không có';
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  /// Định dạng ngày tương đối (Hôm nay, Hôm qua, X ngày trước, hoặc dd/MM/yyyy)
  static String formatRelativeDate(DateTime? date) {
    if (date == null) return 'Không có';
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0 && now.day == date.day) {
      return 'Hôm nay ${DateFormat('HH:mm').format(date)}';
    } else if (difference.inDays == 1 || (difference.inDays == 0 && now.day != date.day)) {
      return 'Hôm qua';
    } else if (difference.inDays < 7 && difference.inDays > 0) {
      return '${difference.inDays} ngày trước';
    } else {
      return DateFormat('dd/MM/yyyy').format(date);
    }
  }

  /// Định dạng dung lượng tệp tin từ số bytes sang B, KB, MB, GB
  static String formatFileSize(int? bytes) {
    if (bytes == null || bytes <= 0) return '0 KB';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Loại bỏ dấu tiếng Việt để phục vụ tìm kiếm không dấu
  static String removeVietnameseDiacritics(String str) {
    var result = str.toLowerCase();
    const vietnamese = [
      'aàảãáạăằẳẵắặâầẩẫấậ',
      'dđ',
      'eèẻẽéẹêềểễếệ',
      'iìỉĩíị',
      'oòỏõóọôồổỗốộơờởỡớợ',
      'uùủũúụưừửữứự',
      'yỳỷỹýỵ',
    ];
    const latin = ['a', 'd', 'e', 'i', 'o', 'u', 'y'];

    for (var i = 0; i < vietnamese.length; i++) {
      for (var char in vietnamese[i].split('')) {
        result = result.replaceAll(char, latin[i]);
      }
    }
    return result;
  }

  /// Kiểm tra chuỗi nguồn có khớp từ khóa tìm kiếm (không phân biệt dấu và hoa thường)
  static bool matchesSearch(String source, String query) {
    if (query.trim().isEmpty) return true;
    final normalizedSource = removeVietnameseDiacritics(source);
    final normalizedQuery = removeVietnameseDiacritics(query.trim());
    return normalizedSource.contains(normalizedQuery);
  }

  /// Kiểm tra URL hợp lệ
  static bool isValidUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    final uri = Uri.tryParse(url.trim());
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
  }
}
