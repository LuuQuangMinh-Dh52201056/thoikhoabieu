import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../models/schedule_item.dart';
import '../services/auth_service.dart';
import '../services/local_storage_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/day_tab_bar.dart';
import '../widgets/schedule_card.dart';
import 'add_schedule_screen.dart';
import 'admin_users_screen.dart';
import 'schedule_detail_screen.dart';
import 'teacher_week_grid_screen.dart';

class WeeklyScheduleScreen extends StatefulWidget {
  final AppUser currentUser;

  const WeeklyScheduleScreen({super.key, required this.currentUser});

  @override
  State<WeeklyScheduleScreen> createState() => _WeeklyScheduleScreenState();
}

class _WeeklyScheduleScreenState extends State<WeeklyScheduleScreen> {
  final LocalStorageService _storageService = LocalStorageService();

  List<ScheduleItem> _allSchedules = [];
  bool _isLoading = true;
  late DateTime _weekStart;
  int _selectedDayIndex = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _weekStart = _getStartOfWeek(now);
    _selectedDayIndex = now.weekday - 1;
    _loadSchedules();
  }

  DateTime _getStartOfWeek(DateTime date) {
    final onlyDate = DateTime(date.year, date.month, date.day);
    return onlyDate.subtract(Duration(days: onlyDate.weekday - 1));
  }

  List<DateTime> get _weekDays {
    return List.generate(7, (index) => _weekStart.add(Duration(days: index)));
  }

  DateTime get _selectedDate => _weekDays[_selectedDayIndex];

  Future<void> _loadSchedules() async {
    setState(() => _isLoading = true);
    final items = await _storageService.getSchedules();
    if (!mounted) return;

    setState(() {
      _allSchedules = items;
      _isLoading = false;
    });
  }

  Future<void> _openAddScreen() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddScheduleScreen()),
    );

    if (created == true) {
      _loadSchedules();
    }
  }

  Future<void> _openDetailScreen(ScheduleItem item) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ScheduleDetailScreen(item: item, currentUser: widget.currentUser),
      ),
    );

    if (changed == true) {
      _loadSchedules();
    }
  }

  void _openTeacherWeek() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => TeacherWeekGridScreen(currentUser: widget.currentUser),
      ),
    );
  }

  void _openAdminUsers() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminUsersScreen()),
    );
  }

  Future<void> _logout() async {
    await AuthService().signOut();
  }

  void _changeWeek(int offset) {
    setState(() {
      _weekStart = _weekStart.add(Duration(days: 7 * offset));
      _selectedDayIndex = 0;
    });
  }

  List<ScheduleItem> _getSchedulesForSelectedDay() {
    final selected = _selectedDate;

    final items = _allSchedules.where((item) {
      return item.date.year == selected.year &&
          item.date.month == selected.month &&
          item.date.day == selected.day;
    }).toList();

    items.sort((a, b) => a.startHour.compareTo(b.startHour));
    return items;
  }

  int _countSchedulesByDate(DateTime date) {
    return _allSchedules.where((item) {
      return item.date.year == date.year &&
          item.date.month == date.month &&
          item.date.day == date.day;
    }).length;
  }

  List<int> _weekItemCounts() => _weekDays.map(_countSchedulesByDate).toList();

  int _countWeekSchedules() {
    var total = 0;
    for (final day in _weekDays) {
      total += _countSchedulesByDate(day);
    }
    return total;
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatWeekRange() {
    final end = _weekStart.add(const Duration(days: 6));
    return '${_formatDate(_weekStart)} - ${_formatDate(end)}';
  }

  String _weekdayTitle(DateTime date) {
    switch (date.weekday) {
      case 1:
        return 'Thứ 2';
      case 2:
        return 'Thứ 3';
      case 3:
        return 'Thứ 4';
      case 4:
        return 'Thứ 5';
      case 5:
        return 'Thứ 6';
      case 6:
        return 'Thứ 7';
      default:
        return 'Chủ nhật';
    }
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 14),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(color: Colors.white70, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedDaySchedules = _getSchedulesForSelectedDay();
    final weekCounts = _weekItemCounts();

    return Scaffold(
      drawer: AppDrawer(
        currentUser: widget.currentUser,
        onOpenWeekly: () {},
        onOpenTeacherWeek: _openTeacherWeek,
        onOpenAdd: _openAddScreen,
        onOpenAdminUsers: _openAdminUsers,
        onLogout: _logout,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddScreen,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Thêm lịch'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E3A8A).withValues(alpha: 0.18),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Builder(
                        builder: (context) {
                          return IconButton(
                            onPressed: () => Scaffold.of(context).openDrawer(),
                            icon: const Icon(
                              Icons.menu_rounded,
                              color: Colors.white,
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 4),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Thời khóa biểu tuần',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Danh sách lịch theo từng ngày',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _loadSchedules,
                        icon: const Icon(
                          Icons.refresh_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => _changeWeek(-1),
                          icon: const Icon(
                            Icons.chevron_left_rounded,
                            color: Colors.white,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            _formatWeekRange(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => _changeWeek(1),
                          icon: const Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _buildStatCard(
                        title: 'Lịch trong tuần',
                        value: '${_countWeekSchedules()}',
                        icon: Icons.calendar_view_week_rounded,
                      ),
                      const SizedBox(width: 10),
                      _buildStatCard(
                        title: 'Ngày đang chọn',
                        value: '${selectedDaySchedules.length}',
                        icon: Icons.event_note_rounded,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            DayTabBar(
              days: _weekDays,
              itemCounts: weekCounts,
              selectedIndex: _selectedDayIndex,
              onTap: (index) {
                setState(() => _selectedDayIndex = index);
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_weekdayTitle(_selectedDate)} • ${_formatDate(_selectedDate)}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    '${selectedDaySchedules.length} lịch',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : selectedDaySchedules.isEmpty
                  ? Center(
                      child: Text(
                        'Chưa có lịch cho ngày này',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 96, top: 2),
                      itemCount: selectedDaySchedules.length,
                      itemBuilder: (context, index) {
                        final item = selectedDaySchedules[index];
                        return ScheduleCard(
                          item: item,
                          onTap: () => _openDetailScreen(item),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
