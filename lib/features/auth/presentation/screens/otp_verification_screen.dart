import 'package:flutter/material.dart';

class OtpVerificationScreen extends StatelessWidget {
  final String phone;
  const OtpVerificationScreen({super.key, required this.phone});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text('OTP for $phone')),
    );
  }
}
