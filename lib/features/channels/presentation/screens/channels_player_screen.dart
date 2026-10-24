import 'package:flutter/material.dart';
import 'package:ethiochat/core/theme/ethio_colors.dart';

class ChannelsPlayerScreen extends StatelessWidget {
  const ChannelsPlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EthioColors.black,
      body: PageView.builder(
        scrollDirection: Axis.vertical,
        itemCount: 0,
        itemBuilder: (context, index) => const SizedBox.shrink(),
      ),
    );
  }
}
