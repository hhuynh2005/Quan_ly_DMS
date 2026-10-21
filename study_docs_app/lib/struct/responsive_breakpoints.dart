import 'package:flutter/material.dart';

/// Các phân loại kích thước màn hình theo chuẩn Material 3 Adaptive Design
enum DeviceScreenType {
  /// Điện thoại di động (chiều rộng < 600dp)
  mobile,

  /// Máy tính bảng / Màn hình gập (600dp <= chiều rộng < 1024dp)
  tablet,

  /// Máy tính để bàn / Web màn hình rộng (chiều rộng >= 1024dp)
  desktop,
}

/// Hệ thống Breakpoints và tiện ích Responsive cho giao diện Đa nền tảng (TH2)
/// Phụ trách: NGUYỄN TRUNG KIÊN (MSSV: 2251172394)
class ResponsiveBreakpoints {
  // Điểm ngắt chuẩn Material Design 3
  static const double mobileBreakpoint = 600.0;
  static const double tabletBreakpoint = 1024.0;
  static const double desktopBreakpoint = 1440.0;

  /// Giới hạn chiều rộng nội dung tối đa trên Desktop để đảm bảo trải nghiệm đọc tối ưu
  static const double maxContentWidth = 1200.0;

  /// Xác định loại thiết bị từ chiều rộng (Width)
  static DeviceScreenType getScreenTypeFromWidth(double width) {
    if (width < mobileBreakpoint) {
      return DeviceScreenType.mobile;
    } else if (width < tabletBreakpoint) {
      return DeviceScreenType.tablet;
    } else {
      return DeviceScreenType.desktop;
    }
  }

  /// Xác định loại thiết bị từ BuildContext
  static DeviceScreenType getScreenType(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return getScreenTypeFromWidth(width);
  }

  /// Kiểm tra có phải giao diện Mobile hay không
  static bool isMobile(BuildContext context) {
    return getScreenType(context) == DeviceScreenType.mobile;
  }

  /// Kiểm tra có phải giao diện Tablet hay không
  static bool isTablet(BuildContext context) {
    return getScreenType(context) == DeviceScreenType.tablet;
  }

  /// Kiểm tra có phải giao diện Desktop / Web lớn hay không
  static bool isDesktop(BuildContext context) {
    return getScreenType(context) == DeviceScreenType.desktop;
  }

  /// Kiểm tra màn hình có đủ rộng cho bố cục dạng ngang (Tablet hoặc Desktop)
  static bool isWide(BuildContext context) {
    return !isMobile(context);
  }

  /// Chọn giá trị tương ứng theo từng kích thước màn hình (Pattern matching đa nền tảng)
  static T value<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    final screenType = getScreenType(context);
    switch (screenType) {
      case DeviceScreenType.mobile:
        return mobile;
      case DeviceScreenType.tablet:
        return tablet ?? mobile;
      case DeviceScreenType.desktop:
        return desktop ?? tablet ?? mobile;
    }
  }

  /// Tính toán số cột lưới (Grid columns) thích ứng theo kích thước màn hình
  static int getGridColumnCount(
    BuildContext context, {
    int mobile = 1,
    int tablet = 2,
    int desktop = 3,
    int wide = 4,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= desktopBreakpoint) {
      return wide;
    } else if (width >= tabletBreakpoint) {
      return desktop;
    } else if (width >= mobileBreakpoint) {
      return tablet;
    } else {
      return mobile;
    }
  }

  /// Khoảng đệm trang (Page Padding) tự động co giãn theo nền tảng
  static EdgeInsets getPagePadding(BuildContext context) {
    return value<EdgeInsets>(
      context,
      mobile: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      tablet: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      desktop: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
    );
  }
}

/// Tiện ích Extension trên BuildContext giúp truy xuất thuộc tính Responsive nhanh gọn
extension ResponsiveContextExtensions on BuildContext {
  /// Loại màn hình hiện tại
  DeviceScreenType get screenType => ResponsiveBreakpoints.getScreenType(this);

  /// Chiều rộng màn hình
  double get screenWidth => MediaQuery.sizeOf(this).width;

  /// Chiều cao màn hình
  double get screenHeight => MediaQuery.sizeOf(this).height;

  /// Là Mobile (< 600dp)
  bool get isMobile => ResponsiveBreakpoints.isMobile(this);

  /// Là Tablet (600dp - 1024dp)
  bool get isTablet => ResponsiveBreakpoints.isTablet(this);

  /// Là Desktop (>= 1024dp)
  bool get isDesktop => ResponsiveBreakpoints.isDesktop(this);

  /// Màn hình ngang (Tablet hoặc Desktop)
  bool get isWide => ResponsiveBreakpoints.isWide(this);

  /// Lấy giá trị thích ứng
  T responsive<T>({
    required T mobile,
    T? tablet,
    T? desktop,
  }) =>
      ResponsiveBreakpoints.value<T>(
        this,
        mobile: mobile,
        tablet: tablet,
        desktop: desktop,
      );

  /// Số cột lưới hiển thị
  int responsiveGridColumns({
    int mobile = 1,
    int tablet = 2,
    int desktop = 3,
    int wide = 4,
  }) =>
      ResponsiveBreakpoints.getGridColumnCount(
        this,
        mobile: mobile,
        tablet: tablet,
        desktop: desktop,
        wide: wide,
      );
}

/// Widget bọc tự động căn giữa và giới hạn chiều rộng nội dung tối đa cho Desktop/Web
class ResponsiveContentContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsets? padding;

  const ResponsiveContentContainer({
    super.key,
    required this.child,
    this.maxWidth = ResponsiveBreakpoints.maxContentWidth,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding ?? ResponsiveBreakpoints.getPagePadding(context),
          child: child,
        ),
      ),
    );
  }
}
