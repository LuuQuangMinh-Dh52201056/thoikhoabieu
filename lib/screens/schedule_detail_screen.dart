import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../models/schedule_item.dart';
import '../services/local_storage_service.dart';
import 'add_schedule_screen.dart';

class ScheduleDetailScreen extends StatefulWidget {
  final ScheduleItem item;
  final AppUser currentUser;

  const ScheduleDetailScreen({
    super.key,
    required this.item,
    required this.currentUser,
  });

  @override
  State<ScheduleDetailScreen> createState() => _ScheduleDetailScreenState();
}

class _ScheduleDetailScreenState extends State<ScheduleDetailScreen> {
  final _storageService = LocalStorageService();

  bool _isDeleting = false;

  bool get _canModify {
    return widget.currentUser.isAdmin ||
        widget.item.createdBy.isEmpty ||
        widget.item.createdBy == widget.currentUser.uid;
  }

  String _formatDate(DateTime date) {
    switch (date.weekday) {
      case 1:
        return 'Thứ 2, ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
      case 2:
        return 'Thứ 3, ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
      case 3:
        return 'Thứ 4, ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
      case 4:
        return 'Thứ 5, ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
      case 5:
        return 'Thứ 6, ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
      case 6:
        return 'Thứ 7, ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
      default:
        return 'Chủ nhật, ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    }
  }

  String _categoryLabel(String category) {
    switch (category) {
      case 'dat':
        return 'DAT';
      case 'sa_hinh':
        return 'Sa hình';
      case 'tap_xe':
        return 'Tập xe';
      case 'tap_xe_chuan_bi_dat':
        return 'Tập xe chuẩn bị chạy DAT';
      case 'cabin':
        return 'Cabin';
      case 'off':
        return 'OFF';
      default:
        return 'Khác';
    }
  }

  Future<void> _editItem() async {
    if (!_canModify) return;

    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddScheduleScreen(existingItem: widget.item),
      ),
    );

    if (changed == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _deleteItem() async {
    if (!_canModify) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Xóa lịch này?',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: Text(
            'Lịch của "${widget.item.studentName}" sẽ bị xóa khỏi ứng dụng.',
            style: const TextStyle(height: 1.45),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
              ),
              child: const Text('Xóa lịch'),
            ),
          ],
        );
      },
    );

    if (confirm != true || _isDeleting) return;

    setState(() => _isDeleting = true);

    try {
      await _storageService.deleteSchedule(widget.item.id);

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Xóa lịch thất bại: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'Chi tiết lịch',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (_canModify)
                        IconButton(
                          onPressed: _editItem,
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: Colors.white,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.studentName.isEmpty
                              ? 'Chưa có học viên'
                              : item.studentName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${item.course} • ${item.timeRange}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(item.date),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            _categoryLabel(item.category),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _InfoTile(
                    icon: Icons.badge_outlined,
                    label: 'Giáo viên',
                    value: item.teacherName,
                  ),
                  const SizedBox(height: 12),
                  _InfoTile(
                    icon: Icons.menu_book_outlined,
                    label: 'Khóa học',
                    value: item.course,
                  ),
                  const SizedBox(height: 12),
                  _InfoTile(
                    icon: Icons.access_time_rounded,
                    label: 'Giờ tập',
                    value: item.timeRange,
                  ),
                  const SizedBox(height: 12),
                  _InfoTile(
                    icon: Icons.description_outlined,
                    label: 'Nội dung tập',
                    value: item.content,
                  ),
                  const SizedBox(height: 12),
                  _InfoTile(
                    icon: Icons.directions_car_outlined,
                    label: 'Xe / biển số',
                    value: item.vehicle,
                  ),
                  const SizedBox(height: 12),
                  _InfoTile(
                    icon: Icons.location_on_outlined,
                    label: 'Địa điểm',
                    value: item.location,
                  ),
                  const SizedBox(height: 12),
                  _InfoTile(
                    icon: Icons.sticky_note_2_outlined,
                    label: 'Ghi chú',
                    value: item.note,
                  ),
                  const SizedBox(height: 20),
                  if (_canModify)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _editItem,
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Sửa lịch'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isDeleting ? null : _deleteItem,
                            icon: _isDeleting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.delete_outline),
                            label: const Text('Xóa lịch'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDC2626),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final displayValue = value.trim().isEmpty ? '---' : value;

    return Card(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.035),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFFEFF6FF),
              child: Icon(icon, color: const Color(0xFF2563EB)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    displayValue,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
