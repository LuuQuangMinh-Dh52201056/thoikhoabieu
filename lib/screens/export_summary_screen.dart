import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

import '../models/schedule_item.dart';

class ExportSummaryScreen extends StatefulWidget {
  final List<ScheduleItem> items;
  final String title;

  const ExportSummaryScreen({
    super.key,
    required this.items,
    required this.title,
  });

  @override
  State<ExportSummaryScreen> createState() => _ExportSummaryScreenState();
}

class _ExportSummaryScreenState extends State<ExportSummaryScreen> {
  final GlobalKey _captureKey = GlobalKey();
  bool _isSaving = false;

  static const String _contactLine =
      'Anh Chị đến sân liên hệ: 0879.227.614 (Quốc Anh)';
  static const String _addressLine =
      'Đ/c Sân Tập Lái Đồng An: 300 Đ. Vành Đai ĐHQG HCM, KP, Dĩ An, Bình Dương, Việt Nam';

  static const double _studentWidth = 320;
  static const double _courseWidth = 150;
  static const double _dateWidth = 175;
  static const double _timeWidth = 165;
  static const double _vehicleWidth = 180;
  static const double _locationWidth = 310;
  static const double _rowHeight = 62;

  double get _tableWidth =>
      _studentWidth +
      _courseWidth +
      _dateWidth +
      _timeWidth +
      _vehicleWidth +
      _locationWidth;

  String get _exportTitle => widget.title.trim().isEmpty
      ? 'LỊCH TẬP SA HÌNH THÔ'
      : widget.title.trim();

  List<ScheduleItem> get _sortedItems {
    final items = [...widget.items];
    items.sort((a, b) {
      final aDate = DateTime(
        a.date.year,
        a.date.month,
        a.date.day,
        a.startHour,
      );
      final bDate = DateTime(
        b.date.year,
        b.date.month,
        b.date.day,
        b.startHour,
      );
      return aDate.compareTo(bDate);
    });
    return items;
  }

  Map<String, int> get _courseSummary {
    final result = <String, int>{};
    for (final item in _sortedItems) {
      final course = _normalizeCourseLabel(item.course);
      result[course] = (result[course] ?? 0) + 1;
    }
    return result;
  }

  int get _totalHours {
    var total = 0;
    for (final item in _sortedItems) {
      total += item.durationHours;
    }
    return total;
  }

  Color _rowColor(String course, int index) {
    switch (_normalizeCourseLabel(course)) {
      case 'C1':
        return const Color(0xFFE8EFDF);
      case 'BTĐ':
        return const Color(0xFFF3DED2);
      case 'BSS':
        return index.isEven ? const Color(0xFFDDE9F4) : const Color(0xFFE7F0E0);
      default:
        return const Color(0xFFF5F0DA);
    }
  }

  String _normalizeCourseLabel(String value) {
    final text = value.trim();
    if (text == 'BTÄ' || text == 'BTÃ„Â') return 'BTĐ';
    return text.isEmpty ? '---' : text;
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _formatHourRange(ScheduleItem item) {
    return '${item.startHour}H-${item.endHour}H';
  }

  String _safeUpper(String value, {String fallback = '---'}) {
    final text = value.trim();
    if (text.isEmpty) return fallback;
    return text.toUpperCase();
  }

  String _dateRangeLabel() {
    final items = _sortedItems;
    if (items.isEmpty) return 'Chưa có lịch';

    final start = items.first.date;
    final end = items.last.date;
    if (start.year == end.year &&
        start.month == end.month &&
        start.day == end.day) {
      return _formatDate(start);
    }

    return '${_formatDate(start)} - ${_formatDate(end)}';
  }

  String _generatedAtLabel() {
    final now = DateTime.now();
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    return '$hour:$minute • ${_formatDate(now)}';
  }

  Future<void> _saveImage() async {
    if (_isSaving) return;

    try {
      setState(() => _isSaving = true);

      await Future.delayed(const Duration(milliseconds: 120));
      final renderObject = _captureKey.currentContext?.findRenderObject();

      if (renderObject == null || renderObject is! RenderRepaintBoundary) {
        throw Exception('Không tìm thấy vùng xuất hình.');
      }

      final image = await renderObject.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw Exception('Không tạo được dữ liệu ảnh.');
      }

      final Uint8List pngBytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final fileName =
          'lich_tap_sa_hinh_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${tempDir.path}/$fileName');

      await file.writeAsBytes(pngBytes);
      await Gal.putImage(file.path);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã lưu ảnh vào thư viện.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Xuất hình thất bại: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _cell({
    required double width,
    required double height,
    required String text,
    required Color background,
    TextStyle? style,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(
      horizontal: 10,
      vertical: 8,
    ),
    TextAlign textAlign = TextAlign.center,
  }) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      padding: padding,
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: Colors.black87, width: 0.75),
      ),
      child: Text(
        text,
        textAlign: textAlign,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style:
            style ??
            const TextStyle(
              fontFamily: 'Times New Roman',
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
              height: 1.15,
            ),
      ),
    );
  }

  Widget _headerCell(String text, double width) {
    return _cell(
      width: width,
      height: 74,
      text: text,
      background: const Color(0xFFF8F8F8),
      style: const TextStyle(
        fontFamily: 'Times New Roman',
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Color(0xFFB03A2E),
        height: 1.15,
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Row(
      children: [
        _headerCell('HỌC VIÊN', _studentWidth),
        _headerCell('KHÓA HỌC', _courseWidth),
        _headerCell('NGÀY TẬP', _dateWidth),
        _headerCell('GIỜ TẬP', _timeWidth),
        _headerCell('BIỂN SỐ', _vehicleWidth),
        _headerCell('ĐỊA ĐIỂM', _locationWidth),
      ],
    );
  }

  Widget _buildDataRow(ScheduleItem item, int index) {
    final bg = _rowColor(item.course, index);

    return Row(
      children: [
        _cell(
          width: _studentWidth,
          height: _rowHeight,
          text: _safeUpper(item.studentName),
          background: bg,
        ),
        _cell(
          width: _courseWidth,
          height: _rowHeight,
          text: _safeUpper(_normalizeCourseLabel(item.course)),
          background: bg,
        ),
        _cell(
          width: _dateWidth,
          height: _rowHeight,
          text: _formatDate(item.date),
          background: bg,
        ),
        _cell(
          width: _timeWidth,
          height: _rowHeight,
          text: _formatHourRange(item),
          background: bg,
        ),
        _cell(
          width: _vehicleWidth,
          height: _rowHeight,
          text: _safeUpper(item.vehicle),
          background: bg,
        ),
        _cell(
          width: _locationWidth,
          height: _rowHeight,
          text: _safeUpper(item.location, fallback: 'SÂN ĐỒNG AN'),
          background: bg,
        ),
      ],
    );
  }

  Widget _buildExportTable() {
    final items = _sortedItems;

    return RepaintBoundary(
      key: _captureKey,
      child: Container(
        width: _tableWidth,
        color: Colors.white,
        child: Column(
          children: [
            Container(
              width: _tableWidth,
              height: 84,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F306),
                border: Border.all(color: Colors.black87, width: 0.9),
              ),
              child: Text(
                _exportTitle.toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Times New Roman',
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFD33A2C),
                  height: 1.0,
                ),
              ),
            ),
            _buildHeaderRow(),
            if (items.isEmpty)
              Row(
                children: [
                  _cell(
                    width: _tableWidth,
                    height: 78,
                    text: 'CHƯA CÓ DỮ LIỆU ĐỂ XUẤT',
                    background: Colors.white,
                    style: const TextStyle(
                      fontFamily: 'Times New Roman',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ],
              )
            else
              ...List.generate(
                items.length,
                (index) => _buildDataRow(items[index], index),
              ),
            Container(
              width: _tableWidth,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFECC9B5),
                border: Border.all(color: Colors.black87, width: 0.75),
              ),
              child: const Text(
                _addressLine,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Times New Roman',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                  height: 1.25,
                ),
              ),
            ),
            Container(
              width: _tableWidth,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFF9CD44B),
                border: Border.all(color: Colors.black87, width: 0.75),
              ),
              child: const Text(
                _contactLine,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Times New Roman',
                  fontSize: 16,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                  color: Colors.black,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.24),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF0B1120),
                    Color(0xFF143A7B),
                    Color(0xFF0F766E),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          Positioned.fill(child: CustomPaint(painter: _HeaderPatternPainter())),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Row(
                  children: [
                    _IconSurfaceButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'Quay lại',
                      onTap: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _StatusChip(
                            icon: Icons.auto_awesome_rounded,
                            text: 'Export Studio',
                            tinted: true,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _exportTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Bản preview sẵn sàng lưu ảnh chất lượng cao',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.76),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: _isSaving ? null : _saveImage,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0F4C81),
                        disabledBackgroundColor: Colors.white70,
                        minimumSize: const Size(132, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download_rounded),
                      label: Text(_isSaving ? 'Đang lưu' : 'Lưu ảnh'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _MetricTile(
                        icon: Icons.table_chart_rounded,
                        label: 'Dòng lịch',
                        value: '${_sortedItems.length}',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MetricTile(
                        icon: Icons.schedule_rounded,
                        label: 'Tổng giờ',
                        value: '${_totalHours}h',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MetricTile(
                        icon: Icons.date_range_rounded,
                        label: 'Khoảng ngày',
                        value: _dateRangeLabel(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _courseSummary.entries.isEmpty
                              ? [
                                  const _StatusChip(
                                    icon: Icons.directions_car_outlined,
                                    text: 'Chưa có khóa',
                                  ),
                                ]
                              : _courseSummary.entries
                                    .map(
                                      (entry) => Padding(
                                        padding: const EdgeInsets.only(
                                          right: 8,
                                        ),
                                        child: _StatusChip(
                                          icon: Icons
                                              .directions_car_filled_outlined,
                                          text: '${entry.key}: ${entry.value}',
                                        ),
                                      ),
                                    )
                                    .toList(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _StatusChip(
                      icon: Icons.history_rounded,
                      text: _generatedAtLabel(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 2, 18, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bản xem trước',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  'Ảnh lưu ra chỉ gồm bảng lịch bên dưới',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const _StatusChip(
            icon: Icons.open_in_full_rounded,
            text: 'Kéo để xem đủ bảng',
            darkText: true,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF0F7),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeroHeader(),
            _buildPreviewHeader(),
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.12),
                      blurRadius: 26,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(painter: _PreviewPatternPainter()),
                    ),
                    SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF0F172A,
                                ).withValues(alpha: 0.16),
                                blurRadius: 28,
                                offset: const Offset(0, 18),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _buildExportTable(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconSurfaceButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _IconSurfaceButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: 46,
            height: 46,
            child: Icon(icon, color: Colors.white),
          ),
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
      height: 82,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: Colors.white, size: 21),
          ),
          const SizedBox(width: 10),
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
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
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

class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool tinted;
  final bool darkText;

  const _StatusChip({
    required this.icon,
    required this.text,
    this.tinted = false,
    this.darkText = false,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = darkText ? const Color(0xFF334155) : Colors.white;
    final background = darkText
        ? Colors.white
        : tinted
        ? const Color(0xFFFBBF24).withValues(alpha: 0.18)
        : Colors.white.withValues(alpha: 0.12);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: darkText
              ? const Color(0xFFE2E8F0)
              : Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: foreground),
          const SizedBox(width: 7),
          Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: foreground,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    for (var i = -size.height; i < size.width; i += 34) {
      canvas.drawLine(
        Offset(i.toDouble(), size.height),
        Offset(i + size.height, 0),
        linePaint,
      );
    }

    final highlightPaint = Paint()
      ..color = const Color(0xFFFBBF24).withValues(alpha: 0.16)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(size.width * 0.66, 24),
      Offset(size.width - 28, size.height * 0.42),
      highlightPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PreviewPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFCBD5E1).withValues(alpha: 0.34)
      ..strokeWidth = 1;

    const gap = 28.0;
    for (var x = 0.0; x <= size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
