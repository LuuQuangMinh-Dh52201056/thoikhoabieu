import 'package:flutter/material.dart';

import '../firebase_options.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';

enum _UserAction { edit, resetPassword, lock, unlock, archive, restore }

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _authService = AuthService();
  final _searchController = TextEditingController();

  List<AppUser> _users = [];
  bool _isLoading = true;
  String? _busyUid;
  String _filter = 'active';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AppUser> get _filteredUsers {
    final query = _searchController.text.trim().toLowerCase();

    return _users.where((user) {
      final matchesFilter = switch (_filter) {
        'active' => user.active && !user.deleted,
        'locked' => !user.active && !user.deleted,
        'admin' => user.isAdmin && !user.deleted,
        'archived' => user.deleted,
        _ => true,
      };

      if (!matchesFilter) return false;
      if (query.isEmpty) return true;

      final searchable =
          '${user.displayLabel} ${user.email} ${user.roleLabel} ${user.statusLabel}'
              .toLowerCase();
      return searchable.contains(query);
    }).toList();
  }

  int get _activeCount =>
      _users.where((user) => user.active && !user.deleted).length;

  int get _lockedCount =>
      _users.where((user) => !user.active && !user.deleted).length;

  int get _adminCount =>
      _users.where((user) => user.isAdmin && !user.deleted).length;

  int get _deletedCount => _users.where((user) => user.deleted).length;

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);

    try {
      final users = await _authService.getUsers();
      if (!mounted) return;
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnack(e);
    }
  }

  Future<void> _openCreateUser() async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _UserFormSheet(authService: _authService),
    );

    if (changed == true) {
      await _loadUsers();
    }
  }

  Future<void> _openEditUser(AppUser user) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          _UserFormSheet(authService: _authService, existingUser: user),
    );

    if (changed == true) {
      await _loadUsers();
    }
  }

  Future<void> _handleAction(AppUser user, _UserAction action) async {
    switch (action) {
      case _UserAction.edit:
        await _openEditUser(user);
      case _UserAction.resetPassword:
        await _sendResetPassword(user);
      case _UserAction.lock:
        await _toggleActive(user, false);
      case _UserAction.unlock:
        await _toggleActive(user, true);
      case _UserAction.archive:
        await _archiveUser(user);
      case _UserAction.restore:
        await _restoreUser(user);
    }
  }

  Future<void> _toggleActive(AppUser user, bool active) async {
    final currentUid = (await _authService.currentProfile())?.uid;
    if (user.uid == currentUid && !active) {
      _showSnack('Bạn không thể tự khóa tài khoản admin đang dùng.');
      return;
    }

    setState(() => _busyUid = user.uid);
    try {
      await _authService.updateUserActive(uid: user.uid, active: active);
      await _loadUsers();
      _showSnack(active ? 'Đã mở khóa tài khoản.' : 'Đã khóa tài khoản.');
    } catch (e) {
      _showSnack(e);
    } finally {
      if (mounted) setState(() => _busyUid = null);
    }
  }

  Future<void> _sendResetPassword(AppUser user) async {
    final confirm = await _confirm(
      title: FirebaseEnv.isConfigured
          ? 'Gửi đặt lại mật khẩu?'
          : 'Đặt lại mật khẩu local?',
      message: FirebaseEnv.isConfigured
          ? 'Firebase sẽ gửi email đặt lại mật khẩu đến ${user.email}. Người dùng tự đặt mật khẩu mới qua email này.'
          : 'Mật khẩu local của ${user.email} sẽ được đặt về 123456.',
      actionText: FirebaseEnv.isConfigured ? 'Gửi email' : 'Đặt về 123456',
      icon: Icons.mark_email_read_outlined,
    );
    if (confirm != true) return;

    setState(() => _busyUid = user.uid);
    try {
      await _authService.sendPasswordReset(user.email);
      _showSnack(
        FirebaseEnv.isConfigured
            ? 'Đã gửi email đặt lại mật khẩu.'
            : 'Đã đặt mật khẩu local về 123456.',
      );
    } catch (e) {
      _showSnack(e);
    } finally {
      if (mounted) setState(() => _busyUid = null);
    }
  }

  Future<void> _archiveUser(AppUser user) async {
    final currentUid = (await _authService.currentProfile())?.uid;
    if (user.uid == currentUid) {
      _showSnack('Bạn không thể tự lưu trữ tài khoản admin đang dùng.');
      return;
    }

    final confirm = await _confirm(
      title: 'Xóa tài khoản?',
      message:
          'Tài khoản ${user.displayLabel} sẽ bị xóa mềm, không đăng nhập được nữa. Dữ liệu lịch đã tạo vẫn được giữ lại để tra cứu.',
      actionText: 'Xóa tài khoản',
      destructive: true,
      icon: Icons.inventory_2_outlined,
    );
    if (confirm != true) return;

    setState(() => _busyUid = user.uid);
    try {
      await _authService.archiveUser(user.uid);
      await _loadUsers();
      _showSnack('Đã xóa mềm tài khoản.');
    } catch (e) {
      _showSnack(e);
    } finally {
      if (mounted) setState(() => _busyUid = null);
    }
  }

  Future<void> _restoreUser(AppUser user) async {
    setState(() => _busyUid = user.uid);
    try {
      await _authService.restoreUser(user.uid);
      await _loadUsers();
      _showSnack('Đã khôi phục tài khoản.');
    } catch (e) {
      _showSnack(e);
    } finally {
      if (mounted) setState(() => _busyUid = null);
    }
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String actionText,
    required IconData icon,
    bool destructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          icon: Icon(
            icon,
            color: destructive
                ? const Color(0xFFDC2626)
                : const Color(0xFF2563EB),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          content: Text(message, style: const TextStyle(height: 1.45)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: destructive ? const Color(0xFFDC2626) : null,
              ),
              child: Text(actionText),
            ),
          ],
        );
      },
    );
  }

  void _showSnack(Object error) {
    if (!mounted) return;
    final text = error is AuthServiceException
        ? error.message
        : error.toString();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1D4ED8), Color(0xFF0F766E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
              const SizedBox(width: 4),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quản trị nhân sự',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Tạo tài khoản, phân quyền và kiểm soát truy cập',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _loadUsers,
                tooltip: 'Tải lại',
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              ),
              IconButton(
                onPressed: _openCreateUser,
                tooltip: 'Tạo tài khoản',
                icon: const Icon(
                  Icons.person_add_alt_1_rounded,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  icon: Icons.verified_user_outlined,
                  label: 'Hoạt động',
                  value: '$_activeCount',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  icon: Icons.lock_clock_outlined,
                  label: 'Đang khóa',
                  value: '$_lockedCount',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  icon: Icons.admin_panel_settings_outlined,
                  label: 'Admin',
                  value: '$_adminCount',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final filters = [
      ('active', 'Hoạt động', Icons.check_circle_outline_rounded),
      ('all', 'Tất cả', Icons.people_alt_outlined),
      ('locked', 'Đang khóa', Icons.lock_outline_rounded),
      ('admin', 'Admin', Icons.admin_panel_settings_outlined),
      ('archived', 'Đã xóa', Icons.inventory_2_outlined),
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Tìm theo tên, email, quyền hoặc trạng thái',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.trim().isEmpty
                  ? null
                  : IconButton(
                      onPressed: _searchController.clear,
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
        ),
        SizedBox(
          height: 46,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: filters.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final filter = filters[index];
              final selected = _filter == filter.$1;

              return ChoiceChip(
                selected: selected,
                avatar: Icon(filter.$3, size: 18),
                label: Text(filter.$2),
                onSelected: (_) => setState(() => _filter = filter.$1),
                labelStyle: TextStyle(
                  color: selected ? Colors.white : const Color(0xFF0F172A),
                  fontWeight: FontWeight.w800,
                ),
                selectedColor: const Color(0xFF2563EB),
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: selected
                      ? const Color(0xFF2563EB)
                      : const Color(0xFFE2E8F0),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final users = _filteredUsers;
    if (users.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.manage_search_rounded,
                color: Color(0xFF64748B),
                size: 44,
              ),
              const SizedBox(height: 12),
              const Text(
                'Không có tài khoản phù hợp',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                'Thử đổi bộ lọc hoặc tạo tài khoản mới cho nhân sự.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadUsers,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        itemCount: users.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final user = users[index];
          final isBusy = _busyUid == user.uid;

          return _UserAccountCard(
            user: user,
            isBusy: isBusy,
            onAction: (action) => _handleAction(user, action),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateUser,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Tạo tài khoản'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildFilters(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_filteredUsers.length} tài khoản',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Text(
                    'Đã xóa: $_deletedCount',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UserAccountCard extends StatelessWidget {
  final AppUser user;
  final bool isBusy;
  final ValueChanged<_UserAction> onAction;

  const _UserAccountCard({
    required this.user,
    required this.isBusy,
    required this.onAction,
  });

  Color get _statusColor {
    if (user.deleted) return const Color(0xFF64748B);
    if (!user.active) return const Color(0xFFDC2626);
    return const Color(0xFF16A34A);
  }

  Color get _roleColor {
    return user.isAdmin ? const Color(0xFFEA580C) : const Color(0xFF2563EB);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: _roleColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                user.isAdmin
                    ? Icons.admin_panel_settings_rounded
                    : Icons.person_outline_rounded,
                color: _roleColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    user.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Badge(
                        text: user.roleLabel,
                        icon: Icons.badge_outlined,
                        color: _roleColor,
                      ),
                      _Badge(
                        text: user.statusLabel,
                        icon: user.active && !user.deleted
                            ? Icons.check_circle_outline_rounded
                            : Icons.lock_outline_rounded,
                        color: _statusColor,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isBusy)
              const Padding(
                padding: EdgeInsets.all(10),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              PopupMenuButton<_UserAction>(
                tooltip: 'Thao tác tài khoản',
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: onAction,
                itemBuilder: (_) {
                  if (user.deleted) {
                    return const [
                      PopupMenuItem(
                        value: _UserAction.restore,
                        child: _MenuItem(
                          icon: Icons.restore_rounded,
                          text: 'Khôi phục',
                        ),
                      ),
                    ];
                  }

                  return [
                    const PopupMenuItem(
                      value: _UserAction.edit,
                      child: _MenuItem(
                        icon: Icons.edit_outlined,
                        text: 'Sửa thông tin',
                      ),
                    ),
                    const PopupMenuItem(
                      value: _UserAction.resetPassword,
                      child: _MenuItem(
                        icon: Icons.mark_email_read_outlined,
                        text: 'Gửi đổi mật khẩu',
                      ),
                    ),
                    PopupMenuItem(
                      value: user.active
                          ? _UserAction.lock
                          : _UserAction.unlock,
                      child: _MenuItem(
                        icon: user.active
                            ? Icons.lock_outline_rounded
                            : Icons.lock_open_rounded,
                        text: user.active ? 'Khóa tài khoản' : 'Mở khóa',
                      ),
                    ),
                    const PopupMenuItem(
                      value: _UserAction.archive,
                      child: _MenuItem(
                        icon: Icons.inventory_2_outlined,
                        text: 'Xóa tài khoản',
                        destructive: true,
                      ),
                    ),
                  ];
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;

  const _Badge({required this.text, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool destructive;

  const _MenuItem({
    required this.icon,
    required this.text,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? const Color(0xFFDC2626)
        : const Color(0xFF0F172A);

    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Text(
          text,
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _UserFormSheet extends StatefulWidget {
  final AuthService authService;
  final AppUser? existingUser;

  const _UserFormSheet({required this.authService, this.existingUser});

  @override
  State<_UserFormSheet> createState() => _UserFormSheetState();
}

class _UserFormSheetState extends State<_UserFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();

  late String _role;
  late bool _active;
  bool _isSaving = false;

  bool get _isEdit => widget.existingUser != null;

  @override
  void initState() {
    super.initState();
    final user = widget.existingUser;
    _emailController.text = user?.email ?? '';
    _displayNameController.text = user?.displayName ?? '';
    _role = user?.role ?? 'user';
    _active = user?.active ?? true;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final user = widget.existingUser;
      if (user == null) {
        await widget.authService.createUser(
          email: _emailController.text,
          password: _passwordController.text,
          displayName: _displayNameController.text,
          role: _role,
        );
      } else {
        await widget.authService.updateUserProfile(
          uid: user.uid,
          displayName: _displayNameController.text,
          role: _role,
          active: _active,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      final text = e is AuthServiceException ? e.message : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      _isEdit
                          ? Icons.manage_accounts_outlined
                          : Icons.person_add_alt_1_rounded,
                      color: const Color(0xFF2563EB),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEdit ? 'Sửa tài khoản' : 'Tạo tài khoản mới',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isEdit
                              ? 'Cập nhật tên, quyền và trạng thái truy cập'
                              : 'Tài khoản sẽ dùng email và mật khẩu để đăng nhập',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _displayNameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Tên hiển thị',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Nhập tên hiển thị';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                enabled: !_isEdit,
                keyboardType: TextInputType.emailAddress,
                textInputAction: _isEdit
                    ? TextInputAction.done
                    : TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Email đăng nhập',
                  prefixIcon: Icon(Icons.mail_outline_rounded),
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return 'Nhập email';
                  if (!text.contains('@')) return 'Email không hợp lệ';
                  return null;
                },
              ),
              if (!_isEdit) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Mật khẩu ban đầu',
                    prefixIcon: Icon(Icons.lock_outline_rounded),
                  ),
                  validator: (value) {
                    if ((value ?? '').length < 6) {
                      return 'Mật khẩu cần ít nhất 6 ký tự';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: const InputDecoration(
                  labelText: 'Quyền hệ thống',
                  prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'user', child: Text('Nhân viên')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _role = value);
                },
              ),
              if (_isEdit) ...[
                const SizedBox(height: 12),
                SwitchListTile(
                  value: _active,
                  onChanged: (value) => setState(() => _active = value),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  title: const Text(
                    'Cho phép đăng nhập',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    _active
                        ? 'Tài khoản đang hoạt động'
                        : 'Tài khoản bị khóa đăng nhập',
                  ),
                ),
              ],
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        _isEdit
                            ? Icons.save_outlined
                            : Icons.person_add_alt_1_rounded,
                      ),
                label: Text(
                  _isSaving
                      ? 'Đang lưu'
                      : _isEdit
                      ? 'Lưu thay đổi'
                      : 'Tạo tài khoản',
                ),
              ),
              if (_isEdit) ...[
                const SizedBox(height: 10),
                Text(
                  'Muốn đổi mật khẩu, dùng menu “Gửi đổi mật khẩu” ở danh sách tài khoản.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
