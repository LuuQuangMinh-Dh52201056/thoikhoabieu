# Deploy Render

Project này deploy lên Render bằng Docker web service.

## 1. Commit và push code

Chạy ở thư mục gốc project:

```powershell
git status
git add .
git commit -m "Fix Render deploy"
git push origin main
```

Render chỉ build code đã có trên GitHub. Nếu chỉ sửa ở máy mà chưa push, Render vẫn dùng code cũ và có thể báo lỗi file không tồn tại.

## 2. Tạo service trên Render

1. Vào Render Dashboard.
2. Chọn New > Web Service.
3. Connect repo GitHub của project.
4. Chọn branch `main`.
5. Chọn runtime/language là Docker.
6. Dockerfile Path: `./Dockerfile`.
7. Docker Context Directory: `.`.
8. Không nhập Build Command.
9. Không nhập Start Command.
10. Bấm Create Web Service hoặc Deploy.

Render dùng port `10000` mặc định. File `nginx.conf` đang listen đúng port này.

## 3. Environment variables

Thêm các biến này trong Environment của service:

```text
FIREBASE_API_KEY=...
FIREBASE_APP_ID=...
FIREBASE_MESSAGING_SENDER_ID=...
FIREBASE_PROJECT_ID=...
FIREBASE_AUTH_DOMAIN=...
FIREBASE_STORAGE_BUCKET=...
LOCAL_ADMIN_USERNAME=...
LOCAL_ADMIN_PASSWORD=...
```

Bốn biến bắt buộc để app bật Firebase là:

```text
FIREBASE_API_KEY
FIREBASE_APP_ID
FIREBASE_MESSAGING_SENDER_ID
FIREBASE_PROJECT_ID
```

`FIREBASE_AUTH_DOMAIN` và `FIREBASE_STORAGE_BUCKET` có thể bỏ trống; app sẽ tự suy ra từ `FIREBASE_PROJECT_ID`.

Nếu chưa cấu hình Firebase, app dùng tài khoản admin local. Để chỉ bạn biết tài khoản này, đặt:

```text
LOCAL_ADMIN_USERNAME=tenadmin01
LOCAL_ADMIN_PASSWORD=matkhau-rieng-cua-ban
```

`LOCAL_ADMIN_USERNAME` phải có cả chữ và số, ví dụ `admin01`, `minh2026`, `quantri9`.

## 4. Deploy lại sau khi sửa code

Mỗi lần sửa code:

```powershell
git add .
git commit -m "Update app"
git push origin main
```

Sau đó Render sẽ auto deploy. Nếu không auto deploy, vào service trên Render và bấm Manual Deploy > Deploy latest commit.

## 5. Nếu vẫn thấy lỗi docker-entrypoint

Lỗi dạng này:

```text
"/docker-entrypoint.d/10-runtime-config.sh": not found
```

có nghĩa Render đang build code cũ. Dockerfile hiện tại không còn dùng file đó nữa. Kiểm tra:

1. Render đang chọn đúng branch `main`.
2. GitHub đã có commit mới nhất.
3. Trong Render, bấm Manual Deploy > Clear build cache & deploy.

## Vì sao không dùng dart-define trên Render?

Flutter web build ra file tĩnh. Docker image này tạo file:

```text
/usr/share/nginx/html/assets/config/firebase_config.json
```

khi container khởi động, rồi app đọc file đó lúc chạy. Vì vậy bạn chỉ cần sửa Environment variables trên Render rồi redeploy, không phải sửa code hay build command.
