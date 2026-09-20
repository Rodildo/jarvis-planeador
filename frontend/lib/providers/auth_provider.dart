import 'package:flutter/material.dart';
import '../core/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  bool isLoading = false;
  String? errorMessage;

  bool get isLoggedIn => ApiService.isLoggedIn;

  Future<bool> login(String email, String password) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _api.login(email, password);
      return true;
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register(String email, String password, String firstName, String lastName) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _api.register(email, password, firstName, lastName);
      return true;
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _api.logout();
    notifyListeners();
  }

  Future<bool> updateProfile(String firstName, String lastName) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _api.updateProfile(firstName, lastName);
      return true;
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> changePassword(String currentPassword, String newPassword) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _api.changePassword(currentPassword, newPassword);
      return true;
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> uploadAvatar(String dataUri) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _api.uploadAvatar(dataUri);
      return true;
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> removeAvatar() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _api.removeAvatar();
      return true;
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteAccount(String password) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _api.deleteAccount(password);
      return true;
    } catch (e) {
      errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
