import 'package:flutter/material.dart';

class MiniProgramContainer extends StatelessWidget {
  final String appId;
  const MiniProgramContainer({super.key, required this.appId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text('Mini Program $appId')),
    );
  }
}
