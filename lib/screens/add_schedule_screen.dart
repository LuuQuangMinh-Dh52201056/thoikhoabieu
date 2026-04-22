import 'package:flutter/material.dart';

import '../models/schedule_item.dart';
import '../services/local_storage_service.dart';

class AddScheduleScreen extends StatefulWidget {
  final ScheduleItem? existingItem;

  const AddScheduleScreen({super.key, this.existingItem});

  @override
  State<AddScheduleScreen> createState() => _AddScheduleScreenState();
}

class _AddScheduleScreenState extends State<AddScheduleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _storageService = LocalStorageService();

  late final TextEditingController _teacherNameController;
  late final TextEditingController _studentNameController;
  late final TextEditingController _contentController;
  late final TextEditingController _vehicleController;
  late final TextEditingController _assistantNameController;
  late final TextEditingController _locationController;
  late final TextEditingController _noteController;

  DateTime? _selectedDate;
  late String _selectedCourse;
  late String _selectedCategory;
  late int _startHour;
  late int _endHour;

  bool _isSaving = false;

  bool get _isEditMode => widget.existingItem != null;

  final List<String> _courses = const ['C1', 'BSS', 'BTĐ'];

  final Map<String, String> _categories = const {
    'dat': 'DAT',
    'sa_hinh': 'Sa hình',
    'tap_xe': 'Tập xe',
    'tap_xe_chuan_bi_dat': 'Tập xe chuẩn bị chạy DAT',
    'cabin': 'Cabin',
    'off': 'OFF',
    'khac': 'Khác',
  };

  @override
  void initState() {
    super.initState();
    final item = widget.existingItem;

    _teacherNameController = TextEditingController(
      text: item?.teacherName ?? '',
    );
    _studentNameController = TextEditingController(
      text: item?.studentName ?? '',
    );
    _contentController = TextEditingController(text: item?.content ?? '');
    _vehicleController = TextEditingController(text: item?.vehicle ?? '');
    _assistantNameController = TextEditingController(
      text: item?.assistantName ?? '',
    );
    _locationController = TextEditingController(
      text: item?.location.trim().isNotEmpty == true
          ? item!.location
          : 'Sân Đồng An',
    );
    _noteController = TextEditingController(text: item?.note ?? '');

    _selectedDate = item?.date;
    _selectedCourse = ScheduleItem.normalizeCourse(item?.course);
    _selectedCategory = ScheduleItem.normalizeCategory(item?.category);
    _startHour = ScheduleItem.normalizeStartHour(item?.startHour ?? 7);
    _endHour = ScheduleItem.normalizeEndHour(_startHour, item?.endHour ?? 8);
  }

  @override
  void dispose() {
    _teacherNameController.dispose();
    _studentNameController.dispose();
    _contentController.dispose();
    _vehicleController.dispose();
    _assistantNameController.dispose();
    _locationController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _formatHour(int hour) => '${hour.toString().padLeft(2, '0')}:00';

  String _hourRangeLabel(int start, int end) {
    return '${_formatHour(start)} - ${_formatHour(end)}';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _saveSchedule() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDate == null) {
      _showSnack('Vui lòng chọn ngày dạy');
      return;
    }

    if (_endHour <= _startHour) {
      _showSnack('Giờ kết thúc phải lớn hơn giờ bắt đầu');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final item = ScheduleItem(
        id:
            widget.existingItem?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        date: DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
        ),
        startHour: _startHour,
        endHour: _endHour,
        teacherName: _teacherNameController.text.trim(),
        studentName: _studentNameController.text.trim(),
        course: _selectedCourse,
        content: _contentController.text.trim(),
        vehicle: _vehicleController.text.trim(),
        assistantName: _assistantNameController.text.trim(),
        location: _locationController.text.trim(),
        note: _noteController.text.trim(),
        category: _selectedCategory,
      );

      if (_isEditMode) {
        await _storageService.updateSchedule(item);
      } else {
        await _storageService.addSchedule(item);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      _showSnack('Lưu lịch thất bại: $e');
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    IconData? icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon) : null,
      ),
    );
  }

  Widget _buildPickerField({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
        child: Text(
          value,
          style: TextStyle(
            color: value.contains('Chọn')
                ? Colors.grey.shade500
                : Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateText = _selectedDate == null
        ? 'Chọn ngày dạy'
        : _formatDate(_selectedDate!);

    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(28),
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
                        Expanded(
                          child: Text(
                            _isEditMode ? 'Sửa lịch dạy' : 'Thêm lịch dạy',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Text(
                        'Khóa học chọn từ danh sách có sẵn. Giờ tập chia theo từng khung 1 tiếng từ 07:00 đến 18:00.',
                        style: TextStyle(color: Colors.white, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _SectionCard(
                        title: 'Thời gian',
                        icon: Icons.schedule_rounded,
                        child: Column(
                          children: [
                            _buildPickerField(
                              label: 'Ngày dạy',
                              value: dateText,
                              icon: Icons.calendar_today_outlined,
                              onTap: _pickDate,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<int>(
                                    initialValue: _startHour,
                                    decoration: const InputDecoration(
                                      labelText: 'Giờ bắt đầu',
                                      prefixIcon: Icon(
                                        Icons.access_time_rounded,
                                      ),
                                    ),
                                    isExpanded: true,
                                    items: List.generate(
                                      11,
                                      (index) => DropdownMenuItem<int>(
                                        value: 7 + index,
                                        child: Text(_formatHour(7 + index)),
                                      ),
                                    ),
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() {
                                          _startHour = value;
                                          _endHour =
                                              ScheduleItem.normalizeEndHour(
                                                _startHour,
                                                _endHour,
                                              );
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<int>(
                                    initialValue: _endHour,
                                    decoration: const InputDecoration(
                                      labelText: 'Giờ kết thúc',
                                      prefixIcon: Icon(Icons.timelapse_rounded),
                                    ),
                                    isExpanded: true,
                                    items: List.generate(
                                      11,
                                      (index) => DropdownMenuItem<int>(
                                        value: 8 + index,
                                        child: Text(_formatHour(8 + index)),
                                      ),
                                    ),
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() {
                                          _endHour =
                                              ScheduleItem.normalizeEndHour(
                                                _startHour,
                                                value,
                                              );
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.watch_later_outlined),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Khung giờ: ${_hourRangeLabel(_startHour, _endHour)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SectionCard(
                        title: 'Thông tin lớp học',
                        icon: Icons.school_outlined,
                        child: Column(
                          children: [
                            _buildTextField(
                              _teacherNameController,
                              'Giáo viên',
                              icon: Icons.badge_outlined,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Nhập tên giáo viên';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            _buildTextField(
                              _studentNameController,
                              'Học viên',
                              icon: Icons.person_outline,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Nhập tên học viên';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedCourse,
                              decoration: const InputDecoration(
                                labelText: 'Khóa học / loại xe',
                                prefixIcon: Icon(Icons.menu_book_outlined),
                              ),
                              isExpanded: true,
                              items: _courses
                                  .map(
                                    (course) => DropdownMenuItem<String>(
                                      value: course,
                                      child: Text(course),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _selectedCourse = value);
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedCategory,
                              decoration: const InputDecoration(
                                labelText: 'Loại lịch',
                                prefixIcon: Icon(Icons.category_outlined),
                              ),
                              isExpanded: true,
                              menuMaxHeight: 320,
                              items: _categories.entries
                                  .map(
                                    (entry) => DropdownMenuItem<String>(
                                      value: entry.key,
                                      child: Text(entry.value),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _selectedCategory = value);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SectionCard(
                        title: 'Nội dung buổi tập',
                        icon: Icons.drive_file_rename_outline_outlined,
                        child: Column(
                          children: [
                            _buildTextField(
                              _contentController,
                              'Nội dung tập',
                              icon: Icons.description_outlined,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Nhập nội dung tập';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            _buildTextField(
                              _vehicleController,
                              'Xe / biển số',
                              icon: Icons.directions_car_outlined,
                            ),
                            const SizedBox(height: 12),
                            _buildTextField(
                              _assistantNameController,
                              'GV hỗ trợ / GV DAT',
                              icon: Icons.groups_outlined,
                            ),
                            const SizedBox(height: 12),
                            _buildTextField(
                              _locationController,
                              'Địa điểm',
                              icon: Icons.location_on_outlined,
                            ),
                            const SizedBox(height: 12),
                            _buildTextField(
                              _noteController,
                              'Ghi chú',
                              icon: Icons.sticky_note_2_outlined,
                              maxLines: 3,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveSchedule,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(
                          _isEditMode ? 'Lưu thay đổi' : 'Lưu lịch dạy',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFFEFF6FF),
                  child: Icon(icon, size: 18, color: const Color(0xFF2563EB)),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}
