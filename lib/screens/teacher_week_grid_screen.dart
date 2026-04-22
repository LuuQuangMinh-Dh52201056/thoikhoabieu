import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../models/schedule_item.dart';
import '../services/auth_service.dart';
import '../services/local_storage_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/teacher_schedule_block.dart';
import 'add_schedule_screen.dart';
import 'admin_users_screen.dart';
import 'export_summary_screen.dart';
import 'schedule_detail_screen.dart';
import 'weekly_schedule_screen.dart';

class TeacherWeekGridScreen extends StatefulWidget {
  final AppUser currentUser;

  const TeacherWeekGridScreen({super.key, required this.currentUser});

  @override
  State<TeacherWeekGridScreen> createState() => _TeacherWeekGridScreenState();
}

class _TeacherWeekGridScreenState extends State<TeacherWeekGridScreen> {
  final LocalStorageService _storageService = LocalStorageService();

  final ScrollController _horizontalController = ScrollController();

  List<ScheduleItem> _allSchedules = [];
  bool _isLoading = true;
  late DateTime _weekStart;
  String _selectedTeacher = 'Tất cả';

  static const int _visibleStartHour = 7;
  static const int _visibleEndHour = 18;

  static const double _leftColumnWidth = 98;
  static const double _dayColumnWidth = 180;
  static const double _rowHeight = 100;

  late final List<int> _hours = List.generate(
    _visibleEndHour - _visibleStartHour,
    (index) => _visibleStartHour + index,
  );

  @override
  void initState() {
    super.initState();
    _weekStart = _getStartOfWeek(DateTime.now());
    _loadSchedules();
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  DateTime _getStartOfWeek(DateTime date) {
    final onlyDate = DateTime(date.year, date.month, date.day);
    return onlyDate.subtract(Duration(days: onlyDate.weekday - 1));
  }

  List<DateTime> get _weekDays {
    return List.generate(7, (index) => _weekStart.add(Duration(days: index)));
  }

  List<String> get _teacherOptions {
    final names =
        _allSchedules
            .map((e) => e.teacherName.trim())
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return ['Tất cả', ...names];
  }

  Future<void> _loadSchedules() async {
    setState(() => _isLoading = true);

    final items = await _storageService.getSchedules();
    if (!mounted) return;

    setState(() {
      _allSchedules = items;
      _isLoading = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _jumpToFirstSchedule();
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

  void _openWeeklyScreen() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => WeeklyScheduleScreen(currentUser: widget.currentUser),
      ),
    );
  }

  Future<void> _openDetail(ScheduleItem item) async {
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

  void _changeWeek(int offset) {
    setState(() {
      _weekStart = _weekStart.add(Duration(days: 7 * offset));
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _jumpToFirstSchedule();
    });
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
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

  String _formatWeekRange() {
    final end = _weekStart.add(const Duration(days: 6));
    return '${_formatDate(_weekStart)} - ${_formatDate(end)}';
  }

  List<ScheduleItem> _currentWeekItems() {
    final weekEnd = _weekStart.add(const Duration(days: 6));

    final result = _allSchedules.where((item) {
      final itemDate = DateTime(item.date.year, item.date.month, item.date.day);
      final inWeek =
          !itemDate.isBefore(_weekStart) && !itemDate.isAfter(weekEnd);
      final sameTeacher =
          _selectedTeacher == 'Tất cả' || item.teacherName == _selectedTeacher;
      return inWeek && sameTeacher;
    }).toList();

    result.sort((a, b) {
      final aDateTime = DateTime(
        a.date.year,
        a.date.month,
        a.date.day,
        a.startHour,
      );
      final bDateTime = DateTime(
        b.date.year,
        b.date.month,
        b.date.day,
        b.startHour,
      );
      return aDateTime.compareTo(bDateTime);
    });

    return result;
  }

  List<ScheduleItem> _itemsForDay(DateTime date) {
    final result = _currentWeekItems().where((item) {
      return item.date.year == date.year &&
          item.date.month == date.month &&
          item.date.day == date.day;
    }).toList();

    result.sort((a, b) => a.startHour.compareTo(b.startHour));
    return result;
  }

  bool _isVisibleInGrid(ScheduleItem item) {
    return item.endHour > _visibleStartHour &&
        item.startHour < _visibleEndHour &&
        item.endHour > item.startHour;
  }

  int _safeStartHour(ScheduleItem item) {
    if (item.startHour < _visibleStartHour) return _visibleStartHour;
    if (item.startHour > _visibleEndHour - 1) return _visibleEndHour - 1;
    return item.startHour;
  }

  int _safeEndHour(ScheduleItem item) {
    if (item.endHour <= _visibleStartHour) return _visibleStartHour + 1;
    if (item.endHour > _visibleEndHour) return _visibleEndHour;
    return item.endHour;
  }

  int _weekCount() => _currentWeekItems().length;

  Future<void> _scrollToDay(DateTime date) async {
    if (!_horizontalController.hasClients) return;

    final dayIndex = _weekDays.indexWhere(
      (d) => d.year == date.year && d.month == date.month && d.day == date.day,
    );
    if (dayIndex == -1) return;

    final target = (_leftColumnWidth + (dayIndex * _dayColumnWidth) - 12).clamp(
      0.0,
      _horizontalController.position.maxScrollExtent,
    );

    await _horizontalController.animateTo(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
    );
  }

  Future<void> _jumpToFirstSchedule() async {
    final items = _currentWeekItems();
    if (items.isEmpty) return;
    await _scrollToDay(items.first.date);
  }

  void _openExportPreview() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExportSummaryScreen(
          items: _currentWeekItems(),
          title: 'LỊCH TẬP SA HÌNH THÔ',
        ),
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

  Widget _buildQuickScheduleStrip() {
    final items = _currentWeekItems();

    if (items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Text(
          'Tuần này chưa có lịch.',
          style: TextStyle(
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return SizedBox(
      height: 102,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = items[index];

          return GestureDetector(
            onTap: () => _scrollToDay(item.date),
            child: Container(
              width: 240,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_weekdayTitle(item.date)} • ${_formatDate(item.date)}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.studentName.isEmpty
                        ? 'Chưa có học viên'
                        : item.studentName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.course} • ${item.vehicle} • ${item.timeRange}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDayHeader(DateTime date) {
    return Container(
      width: _dayColumnWidth,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _weekdayTitle(date),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
          ),
          const SizedBox(height: 2),
          Text(
            _formatDate(date),
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildHourColumn() {
    return SizedBox(
      width: _leftColumnWidth,
      child: Column(
        children: List.generate(_hours.length, (index) {
          final start = _hours[index];
          final end = start + 1;

          return Container(
            height: _rowHeight,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  '${start.toString().padLeft(2, '0')}:00 - ${end.toString().padLeft(2, '0')}:00',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDayColumn(DateTime date) {
    final items = _itemsForDay(date).where(_isVisibleInGrid).toList();
    final gridHeight = _hours.length * _rowHeight;

    return Container(
      width: _dayColumnWidth,
      height: gridHeight,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: Colors.grey.shade300),
          left: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Stack(
        children: [
          Column(
            children: List.generate(_hours.length, (index) {
              return Container(
                height: _rowHeight,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              );
            }),
          ),
          ...items.map((item) {
            final safeStart = _safeStartHour(item);
            final safeEnd = _safeEndHour(item);

            final top = (safeStart - _visibleStartHour) * _rowHeight + 4;
            final height = ((safeEnd - safeStart) * _rowHeight) - 8;

            return Positioned(
              left: 4,
              right: 4,
              top: top,
              height: height < 72 ? 72 : height,
              child: TeacherScheduleBlock(
                item: item,
                onTap: () => _openDetail(item),
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gridWidth = _leftColumnWidth + (_dayColumnWidth * 7);
    final selectedTeacherCount = _weekCount();

    return Scaffold(
      drawer: AppDrawer(
        currentUser: widget.currentUser,
        onOpenWeekly: _openWeeklyScreen,
        onOpenTeacherWeek: () {},
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
                        child: Text(
                          'Lịch tuần giáo viên',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _openExportPreview,
                        icon: const Icon(
                          Icons.download_rounded,
                          color: Colors.white,
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
                    child: Column(
                      children: [
                        Row(
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
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedTeacher,
                          decoration: InputDecoration(
                            labelText: 'Chọn giáo viên',
                            labelStyle: const TextStyle(color: Colors.white),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.16),
                            prefixIcon: const Icon(
                              Icons.badge_outlined,
                              color: Colors.white,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: Colors.white.withValues(alpha: 0.18),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Colors.white),
                            ),
                          ),
                          dropdownColor: Colors.white,
                          style: const TextStyle(color: Colors.black87),
                          iconEnabledColor: Colors.white,
                          items: _teacherOptions
                              .map(
                                (teacher) => DropdownMenuItem<String>(
                                  value: teacher,
                                  child: Text(teacher),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _selectedTeacher = value);
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                _jumpToFirstSchedule();
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedTeacher == 'Tất cả'
                          ? 'Hiển thị tất cả giáo viên'
                          : 'Giáo viên: $_selectedTeacher',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Text(
                    '$selectedTeacherCount lịch',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _buildQuickScheduleStrip(),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                      child: SingleChildScrollView(
                        controller: _horizontalController,
                        scrollDirection: Axis.horizontal,
                        child: Container(
                          width: gridWidth,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: _leftColumnWidth,
                                      height: 56,
                                      alignment: Alignment.center,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF0F5DAA),
                                      ),
                                      child: const Text(
                                        'Giờ',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    for (final day in _weekDays)
                                      _buildDayHeader(day),
                                  ],
                                ),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildHourColumn(),
                                    for (final day in _weekDays)
                                      _buildDayColumn(day),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
