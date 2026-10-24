import 'package:flutter/material.dart';

class MomentsFeedScreen extends StatelessWidget {
  const MomentsFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Moments')),
      body: ListView.builder(
        itemCount: 0,
        itemBuilder: (context, index) => const SizedBox.shrink(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.camera_alt),
      ),
    );
  }
}
