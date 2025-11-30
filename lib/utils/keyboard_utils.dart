import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class KeyboardUtils {
  /// Dismisses the keyboard if it's currently visible
  static void dismissKeyboard(BuildContext context) {
    FocusScope.of(context).unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
  }
  
  /// Dismisses keyboard and then navigates
  static Future<T?> pushAndDismissKeyboard<T>(
    BuildContext context,
    Widget route,
  ) {
    dismissKeyboard(context);
    return Navigator.push<T>(
      context,
      MaterialPageRoute(builder: (_) => route),
    );
  }
}

