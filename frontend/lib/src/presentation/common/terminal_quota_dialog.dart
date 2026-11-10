import 'package:flutter/material.dart';

class TerminalQuotaDialog extends StatelessWidget {
  const TerminalQuotaDialog({
    super.key,
    required this.message,
    this.allowedMax,
  });

  final String message;
  final int? allowedMax;

  static Future<void> show(BuildContext context, {required String message, int? allowedMax}) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TerminalQuotaDialog(message: message, allowedMax: allowedMax),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.devices_other, color: Colors.amber, size: 28),
          SizedBox(width: 10),
          Text('Terminal Seat Limit Reached'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'To add more cash counters or desktop terminals, please request a license seat upgrade on the Provider Platform.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Understood'),
        ),
      ],
    );
  }
}
