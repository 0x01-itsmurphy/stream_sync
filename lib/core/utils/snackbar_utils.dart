import 'package:flutter/material.dart';
import '../../app/app.dart';

class SnackbarUtils {
  static void showMessage(String message, {bool isError = false}) {
    final state = scaffoldMessengerKey.currentState;
    if (state == null) return;

    state.clearSnackBars();
    state.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF2E2E48),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  static void showSuccess(String message) {
    showMessage(message, isError: false);
  }

  static void showError(String message) {
    showMessage(message, isError: true);
  }
}
