# Hướng dẫn áp dụng bản vá Flutter (`ThueThietBi_APP_dot1.zip` & `ThueThietBi_APP_dot2.zip`)

1. Giải nén đè trực tiếp vào thư mục gốc của project Flutter (cùng cấp với `lib/` và `pubspec.yaml`):
   ```bash
   unzip -o ThueThietBi_APP_dot1.zip
   ```
2. Thêm thư viện quét mã vạch `mobile_scanner` vào `pubspec.yaml` (cần cho màn quét barcode ở Đợt 2):
   ```bash
   flutter pub add mobile_scanner
   flutter pub get
   ```
   *(Lưu ý: Trên Android đảm bảo `minSdkVersion >= 21` và có `<uses-permission android:name="android.permission.CAMERA"/>` trong `android/app/src/main/AndroidManifest.xml`; trên iOS thêm `NSCameraUsageDescription` vào `ios/Runner/Info.plist`.)*
