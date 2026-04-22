import 'package:flutter/material.dart';

import '../models/schedule_item.dart';

class TeacherScheduleBlock extends StatelessWidget {
  final ScheduleItem item;
  final VoidCallback? onTap;

  const TeacherScheduleBlock({super.key, required this.item, this.onTap});

  Color _backgroundColor(String course) {
    switch (course) {
      case 'C1':
        return const Color(0xFFF5F0D7);
      case 'BTĐ':
        return const Color(0xFFF4DDD2);
      case 'BSS':
        return const Color(0xFFDDEAF7);
      default:
        return const Color(0xFFE8F1E1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = _backgroundColor(item.course);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF98A2B3), width: 0.8),
          ),
          child: DefaultTextStyle(
            style: const TextStyle(
              fontSize: 10.4,
              color: Colors.black87,
              height: 1.2,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.studentName.isEmpty
                      ? 'Chưa có học viên'
                      : item.studentName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Loại xe: ${item.course}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  item.vehicle.trim().isEmpty
                      ? 'Biển số: ---'
                      : 'Biển số: ${item.vehicle}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Giờ: ${item.timeRange}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
