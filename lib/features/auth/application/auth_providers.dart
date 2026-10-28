import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/account_service.dart';
import '../data/repositories/auth_repository_impl.dart';
import '../domain/repositories/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => const AuthRepositoryImpl(),
);

final accountServiceProvider = Provider<AccountService>(
  (ref) => const AccountService(),
);
