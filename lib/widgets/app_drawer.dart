import 'package:flutter/material.dart';

import '../models/app_user.dart';

class AppDrawer extends StatelessWidget {
  final AppUser currentUser;
  final VoidCallback onOpenWeekly;
  final VoidCallback onOpenTeacherWeek;
  final VoidCallback onOpenAdd;
  final VoidCallback onOpenAdminUsers;
  final VoidCallback onLogout;

  const AppDrawer({
    super.key,
    required this.currentUser,
    required this.onOpenWeekly,
    required this.onOpenTeacherWeek,
    required this.onOpenAdd,
    required this.onOpenAdminUsers,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFFF8FAFC),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.white24,
                    child: Icon(
                      Icons.calendar_month_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Lịch dạy lái xe',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currentUser.displayLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _DrawerMenuTile(
              icon: Icons.view_week_rounded,
              title: 'Thời khóa biểu tuần',
              subtitle: 'Xem dạng danh sách theo ngày',
              onTap: () {
                Navigator.pop(context);
                onOpenWeekly();
              },
            ),
            _DrawerMenuTile(
              icon: Icons.grid_view_rounded,
              title: 'Lịch tuần giáo viên',
              subtitle: 'Xem dạng bảng theo giờ',
              onTap: () {
                Navigator.pop(context);
                onOpenTeacherWeek();
              },
            ),
            _DrawerMenuTile(
              icon: Icons.add_circle_outline_rounded,
              title: 'Thêm lịch dạy',
              subtitle: 'Điền form và lưu lên dữ liệu chung',
              onTap: () {
                Navigator.pop(context);
                onOpenAdd();
              },
            ),
            if (currentUser.isAdmin)
              _DrawerMenuTile(
                icon: Icons.admin_panel_settings_outlined,
                title: 'Quản lý tài khoản',
                subtitle: 'Tạo tài khoản và cấp quyền',
                onTap: () {
                  Navigator.pop(context);
                  onOpenAdminUsers();
                },
              ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  currentUser.isAdmin
                      ? 'Bạn đang dùng quyền admin.'
                      : 'Bạn có thể thêm lịch. Chỉ admin hoặc người tạo lịch mới sửa/xóa lịch đó.',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  onLogout();
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Đăng xuất'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerMenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DrawerMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: const Color(0xFF2563EB)),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      onTap: onTap,
    );
  }
}
