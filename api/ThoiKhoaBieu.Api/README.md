# ThoiKhoaBieu.Api

Backend mẫu để kết nối SQL Server cho app lịch dạy.

## Chỗ kết nối SQL Server

Chuỗi kết nối nằm tại:

```text
api/ThoiKhoaBieu.Api/appsettings.Development.json
```

Hiện đã điền theo thông tin bạn đưa:

```json
"DefaultConnection": "Server=DESKTOP-TL2BT7J;Database=thoikhoabieu;Trusted_Connection=True;TrustServerCertificate=True;MultipleActiveResultSets=True"
```

Nếu máy bạn dùng SQL Express thì đổi `Server` thành:

```text
Server=DESKTOP-TL2BT7J\\SQLEXPRESS
```

Nếu bạn dùng tài khoản `sa`, đổi thành:

```text
Server=DESKTOP-TL2BT7J;Database=thoikhoabieu;User Id=sa;Password=MAT_KHAU_CUA_BAN;TrustServerCertificate=True;MultipleActiveResultSets=True
```

## Tạo database và bảng

Mở SQL Server Management Studio, chạy file:

```text
api/ThoiKhoaBieu.Api/database/schema.sql
```

File này tạo database `thoikhoabieu`, bảng `AppUsers`, bảng `Schedules`.

## Chạy API

```powershell
cd api/ThoiKhoaBieu.Api
dotnet run
```

Mở endpoint kiểm tra:

```text
https://localhost:<port>/api/health/sql
```

Nếu thành công sẽ thấy:

```json
{
  "status": "connected",
  "server": "DESKTOP-TL2BT7J",
  "database": "thoikhoabieu"
}
```
