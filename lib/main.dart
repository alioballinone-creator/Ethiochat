import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Supabase/Firebase initialization will be added when credentials are provided.
  runApp(const ProviderScope(child: EthioChatApp()));
}
