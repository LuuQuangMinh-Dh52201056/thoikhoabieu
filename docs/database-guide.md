# Hướng dẫn cơ sở dữ liệu cho app lịch dạy

App hiện tại đã được code theo hướng Firebase:

- Firebase Authentication: đăng nhập email/mật khẩu.
- Cloud Firestore: lưu tài khoản và lịch dạy.
- Firebase Hosting: host bản web.

Đây là hướng nhanh nhất để chạy web thật vì không cần tự vận hành server.

## Cấu trúc dữ liệu Firebase đang dùng

### Collection `users`

Mỗi document có ID là `uid` của Firebase Auth user.

```text
users/{uid}
  uid: string
  email: string
  displayName: string
  role: "admin" | "user"
  active: boolean
  deleted: boolean
  createdAt: timestamp
  createdBy: string
  updatedAt: timestamp
  updatedBy: string
  deletedAt: timestamp?
  deletedBy: string?
```

### Collection `schedules`

```text
schedules/{scheduleId}
  id: string
  date: string
  startHour: number
  endHour: number
  teacherName: string
  studentName: string
  course: string
  content: string
  vehicle: string
  assistantName: string
  location: string
  note: string
  category: string
  createdBy: string
  createdByEmail: string
  createdAt: timestamp
  updatedAt: timestamp
  updatedBy: string
```

## Tạo admin đầu tiên trên Firebase

1. Firebase Console > Authentication > Users > Add user.
2. Tạo email/mật khẩu admin.
3. Copy UID của user vừa tạo.
4. Firestore Database > tạo collection `users`.
5. Tạo document có ID đúng bằng UID đó.
6. Thêm field:

```text
uid: "<UID admin>"
email: "<email admin>"
displayName: "Admin"
role: "admin"
active: true
deleted: false
```

Sau đó đăng nhập vào app bằng tài khoản admin này. Admin có thể tạo, sửa,
khóa, xóa mềm và khôi phục tài khoản khác ngay trong app.

## Có kết nối trực tiếp SQL Server được không?

Không nên kết nối trực tiếp SQL Server từ Flutter web/mobile.

Lý do:

- Chuỗi kết nối SQL Server sẽ bị lộ trong app/web bundle.
- User có thể lấy username/password DB từ mã build.
- SQL Server không phải API public cho trình duyệt.
- Không có lớp kiểm quyền an toàn giữa người dùng và database.

Kiến trúc đúng nếu dùng SQL Server:

```text
Flutter Web/App -> HTTPS REST API -> SQL Server
```

API có thể viết bằng ASP.NET Core, Node.js, Laravel hoặc framework khác.
SQL Server chỉ mở cho backend, không mở trực tiếp ra internet cho app.

## SQL Server của bạn

Mình đã tạo sẵn backend mẫu tại:

```text
api/ThoiKhoaBieu.Api
```

Chỗ đặt chuỗi kết nối chính là:

```text
api/ThoiKhoaBieu.Api/appsettings.Development.json
```

Đã điền theo thông tin bạn đưa:

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=DESKTOP-TL2BT7J;Database=thoikhoabieu;Trusted_Connection=True;TrustServerCertificate=True;MultipleActiveResultSets=True"
  }
}
```

Nếu SQL Server của bạn là SQL Express, sửa `Server` thành:

```text
DESKTOP-TL2BT7J\SQLEXPRESS
```

Nếu dùng tài khoản SQL Server như `sa`, sửa chuỗi kết nối thành:

```text
Server=DESKTOP-TL2BT7J;Database=thoikhoabieu;User Id=sa;Password=MAT_KHAU_CUA_BAN;TrustServerCertificate=True;MultipleActiveResultSets=True
```

Script tạo database và bảng nằm tại:

```text
api/ThoiKhoaBieu.Api/database/schema.sql
```

Chạy API kiểm tra kết nối:

```powershell
cd api/ThoiKhoaBieu.Api
dotnet run
```

Sau đó mở:

```text
https://localhost:<port>/api/health/sql
```

Nếu kết nối đúng, API trả về `status: connected`.

## Schema SQL Server gợi ý

```sql
CREATE TABLE AppUsers (
    Id UNIQUEIDENTIFIER NOT NULL PRIMARY KEY DEFAULT NEWID(),
    Email NVARCHAR(256) NOT NULL UNIQUE,
    PasswordHash NVARCHAR(MAX) NOT NULL,
    DisplayName NVARCHAR(160) NOT NULL,
    Role NVARCHAR(20) NOT NULL DEFAULT 'user',
    Active BIT NOT NULL DEFAULT 1,
    Deleted BIT NOT NULL DEFAULT 0,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CreatedBy UNIQUEIDENTIFIER NULL,
    UpdatedAt DATETIME2 NULL,
    UpdatedBy UNIQUEIDENTIFIER NULL,
    DeletedAt DATETIME2 NULL,
    DeletedBy UNIQUEIDENTIFIER NULL
);

CREATE TABLE Schedules (
    Id UNIQUEIDENTIFIER NOT NULL PRIMARY KEY DEFAULT NEWID(),
    Date DATE NOT NULL,
    StartHour INT NOT NULL,
    EndHour INT NOT NULL,
    TeacherName NVARCHAR(160) NOT NULL,
    StudentName NVARCHAR(160) NOT NULL,
    Course NVARCHAR(30) NOT NULL,
    Content NVARCHAR(500) NOT NULL,
    Vehicle NVARCHAR(80) NULL,
    AssistantName NVARCHAR(160) NULL,
    Location NVARCHAR(240) NULL,
    Note NVARCHAR(1000) NULL,
    Category NVARCHAR(80) NOT NULL,
    CreatedBy UNIQUEIDENTIFIER NOT NULL,
    CreatedByEmail NVARCHAR(256) NOT NULL,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    UpdatedAt DATETIME2 NULL,
    UpdatedBy UNIQUEIDENTIFIER NULL,
    CONSTRAINT FK_Schedules_AppUsers
        FOREIGN KEY (CreatedBy) REFERENCES AppUsers(Id)
);
```

## REST API cần có nếu dùng SQL Server

```text
POST   /api/auth/login
POST   /api/auth/forgot-password
GET    /api/users
POST   /api/users
PUT    /api/users/{id}
POST   /api/users/{id}/lock
POST   /api/users/{id}/unlock
DELETE /api/users/{id}

GET    /api/schedules
POST   /api/schedules
PUT    /api/schedules/{id}
DELETE /api/schedules/{id}
```

Quy tắc quyền:

- Chỉ admin được gọi `/api/users`.
- User đăng nhập mới được xem/tạo lịch.
- Admin sửa/xóa được mọi lịch.
- User chỉ sửa/xóa lịch do chính user đó tạo.
- `DELETE /api/users/{id}` nên là xóa mềm: `Deleted = 1`, `Active = 0`.

## Mẫu backend ASP.NET Core tối giản

Tạo project:

```powershell
dotnet new webapi -n DrivingScheduleApi
cd DrivingScheduleApi
dotnet add package Microsoft.EntityFrameworkCore.SqlServer
dotnet add package Microsoft.EntityFrameworkCore.Design
dotnet add package Microsoft.AspNetCore.Authentication.JwtBearer
```

`appsettings.json`:

```json
{
  "ConnectionStrings": {
    "Default": "Server=localhost;Database=DrivingSchedule;User Id=sa;Password=YOUR_PASSWORD;TrustServerCertificate=True"
  },
  "Jwt": {
    "Issuer": "DrivingScheduleApi",
    "Audience": "DrivingScheduleApp",
    "Key": "CHANGE_THIS_TO_A_LONG_RANDOM_SECRET_KEY"
  }
}
```

Sau đó backend cần:

- `AppDbContext` dùng `UseSqlServer`.
- Entity `AppUser`, `Schedule`.
- Service hash password, ví dụ `PasswordHasher<AppUser>`.
- JWT login.
- Middleware `[Authorize]`.
- Policy hoặc helper kiểm role admin.

Nếu chọn SQL Server, app Flutter hiện tại sẽ cần đổi `AuthService` và
`LocalStorageService` để gọi REST API thay vì Firebase. Còn nếu muốn nhanh,
giữ Firebase là hướng ít rủi ro và đã có code sẵn trong repo này.
