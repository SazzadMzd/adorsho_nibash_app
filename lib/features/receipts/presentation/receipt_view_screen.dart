import 'package:flutter/material.dart';
import '../../../core/constants/app_strings.dart';
// Receipt view will be implemented with PDF generation in Phase 5

class ReceiptViewScreen extends StatelessWidget {
  const ReceiptViewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.receipt)),
      body: const Center(
        child: Text('রসিদ তৈরি হবে ফেজ ৫ এ'),
      ),
    );
  }
}
