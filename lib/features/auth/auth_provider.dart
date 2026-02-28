// lib/features/auth/auth_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';

enum AuthState { idle, loading, success, error }

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState.idle);

  final _api = ApiClient();
  String _errorMessage = '';

  String get errorMessage => _errorMessage;

  Future<bool> login(String username, String password) async {
    state = AuthState.loading;
    try {
      final res = await _api.login(username, password);
      if (res['status'] == 'success') {
        state = AuthState.success;
        return true;
      } else {
        _errorMessage = res['message'] ?? 'Login မအောင်မြင်ပါ';
        state = AuthState.error;
        return false;
      }
    } catch (e) {
      _errorMessage = 'Server နဲ့ ချိတ်ဆက်မရပါ: $e';
      state = AuthState.error;
      return false;
    }
  }

  Future<void> logout() async {
    await _api.logout();
    state = AuthState.idle;
  }

  void reset() => state = AuthState.idle;
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);
