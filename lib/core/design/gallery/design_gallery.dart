import 'package:flutter/material.dart';
import '../widgets/ethio_button.dart';

class DesignGallery extends StatelessWidget {
  const DesignGallery({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Design Gallery')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Buttons'),
          const SizedBox(height: 8),
          EthioButton(onPressed: () {}, label: 'Primary Button'),
          const SizedBox(height: 16),
          const Text('Colors'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              Container(width: 60, height: 60, color: const Color(0xFFB8860B)),
              Container(width: 60, height: 60, color: const Color(0xFFD4AF37)),
              Container(width: 60, height: 60, color: const Color(0xFFF4D77A)),
              Container(width: 60, height: 60, color: const Color(0xFFFFF8E7)),
              Container(width: 60, height: 60, color: const Color(0xFF0B0B0B)),
            ],
          ),
        ],
      ),
    );
  }
}
