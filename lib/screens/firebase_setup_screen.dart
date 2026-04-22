import 'package:flutter/material.dart';

class FirebaseSetupScreen extends StatelessWidget {
  const FirebaseSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.cloud_done_rounded,
                        color: Color(0xFF2563EB),
                        size: 42,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Cần cấu hình Firebase',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'App đã có đăng nhập và dữ liệu dùng chung, nhưng cần thông tin Firebase project của bạn trước khi chạy bản web thật.',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const _SetupLine(
                        label: 'Auth',
                        text:
                            'Bật Email/Password trong Firebase Authentication.',
                      ),
                      const _SetupLine(
                        label: 'Data',
                        text:
                            'Tạo Cloud Firestore và publish rules trong firestore.rules.',
                      ),
                      const _SetupLine(
                        label: 'Build',
                        text:
                            'Truyền FIREBASE_API_KEY, FIREBASE_APP_ID, FIREBASE_PROJECT_ID và FIREBASE_MESSAGING_SENDER_ID khi build.',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SetupLine extends StatelessWidget {
  final String label;
  final String text;

  const _SetupLine({required this.label, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 58,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.grey.shade700, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
