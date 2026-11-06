# VideoStarMacroTool (iOS Tweak / Dylib)

Mã nguồn hoàn chỉnh của iOS Tweak / Dynamic Library (.dylib) tự động hóa thao tác trong ứng dụng **VideoStar** (Bundle ID: `com.videostar.ios` / `com.frontierdesign.videostar`).

---

## 📁 Cấu Trúc Thư Mục

```text
VideoStarMacroTool/
├── Makefile                     # Cấu hình biên dịch Theos (arm64, arm64e, ARC)
├── control                      # Metadata gói Debian (.deb)
├── VideoStarMacroTool.plist     # Filter bundle ID ứng dụng mục tiêu
├── Tweak.h                      # Khai báo lớp, forward declarations & tiện ích an toàn
├── Tweak.xm                     # Mã nguồn hook Logos, Floating UI & Automation Engine
└── README.md                    # Hướng dẫn biên dịch và sử dụng
```

---

## 🚀 Hướng Dẫn Biên Dịch (Build Instructions)

### 1. Biên dịch qua Theos trên macOS / Linux / iOS (MobileTheos)

Đảm bảo bạn đã cài đặt Theos và thiết lập biến môi trường `$THEOS`:

```bash
# Di chuyển vào thư mục dự án
cd VideoStarMacroTool

# Kiểm tra cú pháp và build gói .deb
make clean
make package FINALPACKAGE=1
```

Sau khi hoàn tất, file `.deb` sẽ nằm trong thư mục `packages/`.

### 2. Trích xuất file `.dylib` để Sideload (TrollStore, Esign, Sideloadly)

Nếu muốn nhúng trực tiếp file `.dylib` vào file `VideoStar.ipa` đã decrypted:
1. File `.dylib` sau khi chạy `make` sẽ nằm tại: `.theos/obj/debug/VideoStarMacroTool.dylib` (hoặc `.theos/obj/VideoStarMacroTool.dylib`).
2. Dùng công cụ `optool` hoặc **Esign / Azule / Sideloadly** để inject dylib vào binary chính của VideoStar:
   ```bash
   optool install -c load -p "@executable_path/Frameworks/VideoStarMacroTool.dylib" -t VideoStar.app/VideoStar
   ```

---

## 🛠️ Tính Năng Tự Động Hóa

1. **Auto Nhập Ảnh / Video vào Lớp (Tái tạo từ `nhapanh.json`):**
   - Quét toàn bộ cây phân cấp view để tìm `Video_Star.MLLayerButtonsCellLayerView`.
   - Thuật toán lọc thông minh: Bỏ qua tuyệt đối các lớp rỗng (`empty`), lớp màu (`color`), hiệu ứng (`zap`), chữ (`text`), lớp phủ (`overlay`).
   - Tự động mô phỏng chạm chọn lớp -> Mở popup thay thế (`CustomPopup` / `CustomUIButton`) -> Nạp phương tiện từ `ClipPickerCollectionViewCellImageView`.
2. **Auto Chia Beat & Cắt Phân Cảnh (Tái tạo từ `chiadoan.json`):**
   - Bật bảng điều khiển beat trên `Video_Star.BeatControlsView` qua selector `toggleAction`.
   - Lặp chuỗi điều hướng nhịp (`nextAction`) kết hợp đặt điểm chia (`setSplitPoint`) trên `MultiSplitView` với độ trễ (delay) mượt mà tránh nghẽn luồng.
   - Kích hoạt selector `doSplit` trên `MultiSplitView` để hoàn tất cắt phân cảnh.
3. **Nút bấm nổi (Floating Controller):**
   - Hỗ trợ kéo thả tự do, tự động hút vào mép màn hình.
   - Giao diện ActionSheet dễ thao tác, có cảnh báo HUD trạng thái và dừng khẩn cấp.
