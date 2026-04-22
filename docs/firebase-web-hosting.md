# Deploy web bằng Firebase Hosting

App đã có sẵn đăng nhập Firebase Auth, dữ liệu Cloud Firestore và cấu hình
Hosting trong `firebase.json`.

## 1. Tạo Firebase project

1. Vào Firebase Console và tạo project mới.
2. Thêm Web app trong project, sau đó copy các giá trị cấu hình:
   - `apiKey`
   - `appId`
   - `messagingSenderId`
   - `projectId`
   - `authDomain`
   - `storageBucket`
3. Vào Authentication > Sign-in method và bật Email/Password.
4. Vào Firestore Database và tạo database.

## 2. Tạo admin đầu tiên

1. Vào Authentication > Users > Add user.
2. Tạo email và mật khẩu admin của bạn.
3. Copy UID của user vừa tạo.
4. Vào Firestore Database, tạo collection `users`.
5. Tạo document có ID đúng bằng UID admin, với các field:

```text
uid: "<UID admin>"
email: "<email admin>"
displayName: "Admin"
role: "admin"
active: true
```

Sau khi admin đầu tiên đăng nhập, admin có thể vào mục `Quản trị nhân sự`
trong app để tạo, sửa, khóa, xóa mềm, khôi phục tài khoản và gửi email đặt lại
mật khẩu cho người khác.

## 3. Build web

Chạy lệnh này bằng PowerShell, thay giá trị Firebase thật của bạn:

```powershell
flutter build web --release `
  --dart-define=FIREBASE_API_KEY="..." `
  --dart-define=FIREBASE_APP_ID="..." `
  --dart-define=FIREBASE_MESSAGING_SENDER_ID="..." `
  --dart-define=FIREBASE_PROJECT_ID="..." `
  --dart-define=FIREBASE_AUTH_DOMAIN="..." `
  --dart-define=FIREBASE_STORAGE_BUCKET="..."
```

Nếu chỉ muốn test trên Chrome:

```powershell
flutter run -d chrome `
  --dart-define=FIREBASE_API_KEY="..." `
  --dart-define=FIREBASE_APP_ID="..." `
  --dart-define=FIREBASE_MESSAGING_SENDER_ID="..." `
  --dart-define=FIREBASE_PROJECT_ID="..." `
  --dart-define=FIREBASE_AUTH_DOMAIN="..." `
  --dart-define=FIREBASE_STORAGE_BUCKET="..."
```

## 4. Deploy

Cài Firebase CLI nếu máy chưa có:

```powershell
npm install -g firebase-tools
firebase login
firebase use --add
firebase deploy --only firestore:rules
firebase deploy --only hosting
```

Firebase Hosting sẽ upload thư mục `build/web`.
