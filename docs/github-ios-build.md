# Build iOS bằng GitHub Actions

Project này có 2 workflow:

- `iOS build check`: build iOS không ký. Workflow này kiểm tra code trên máy macOS của GitHub, nhưng file xuất ra không cài trực tiếp lên iPhone được.
- `iOS TestFlight`: build file `.ipa` có ký và upload lên TestFlight. Workflow này cần Apple Developer account.

## Chạy build check

1. Đẩy project lên GitHub.
2. Vào tab `Actions`.
3. Chọn `iOS build check`.
4. Bấm `Run workflow`.

Nếu pass, GitHub sẽ có artifact `Runner-unsigned-ios-app`.

## Chạy TestFlight

Bạn cần tạo các GitHub secrets:

- `IOS_CERTIFICATE_BASE64`: file certificate `.p12` encode base64.
- `IOS_CERTIFICATE_PASSWORD`: mật khẩu file `.p12`.
- `IOS_PROVISION_PROFILE_BASE64`: file provisioning profile App Store encode base64.
- `IOS_TEAM_ID`: Apple Team ID.
- `APP_STORE_CONNECT_API_KEY_ID`: Key ID của App Store Connect API key.
- `APP_STORE_CONNECT_API_ISSUER_ID`: Issuer ID.
- `APP_STORE_CONNECT_API_KEY_BASE64`: file `.p8` encode base64.

Bạn cần tạo các GitHub variables:

- `IOS_BUNDLE_ID`: bundle id của app, ví dụ `com.tenban.thoikhoabieu`.
- `IOS_PROFILE_NAME`: tên provisioning profile App Store.

Trên Windows, encode base64 bằng PowerShell:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("ios_distribution.p12")) | Set-Clipboard
[Convert]::ToBase64String([IO.File]::ReadAllBytes("app_store.mobileprovision")) | Set-Clipboard
[Convert]::ToBase64String([IO.File]::ReadAllBytes("AuthKey_XXXXXXXXXX.p8")) | Set-Clipboard
```

Sau khi điền đủ secrets/variables:

1. Vào `Actions`.
2. Chọn `iOS TestFlight`.
3. Bấm `Run workflow`.

Workflow sẽ tạo file `.ipa`, upload artifact, rồi upload lên TestFlight.
