import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize services here (Supabase, Firebase, etc.)
  runApp(const ProviderScope(child: EthioChatApp()));
}
