import 'package:flutter/material.dart';

class AudioPlayer extends StatelessWidget {
  final String url;

  const AudioPlayer({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.audiotrack, color: Color(0xFF6b4bbd)),
          const SizedBox(width: 12),
          const Text(
            '音频播放',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.play_circle_outline),
            onPressed: () {
              // TODO: 实现音频播放功能
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('音频播放功能即将上线')));
            },
          ),
        ],
      ),
    );
  }
}
