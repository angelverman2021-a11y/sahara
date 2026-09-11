import 'package:flutter/services.dart';

/// Formats keyboard input into DD/MM/YYYY automatically.
/// Maximum length is 10 characters.
/// Automatically inserts '/' after day and month.
class DateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // If the user deleted characters, handle backspacing cleanly
    if (newValue.text.length < oldValue.text.length) {
      return newValue;
    }

    // Strip non-digits
    final digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');
    final formatted = formatDigits(digitsOnly);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  /// Formats raw digits into DD/MM/YYYY
  static String formatDigits(String digitsOnly) {
    final truncated = digitsOnly.length > 8 ? digitsOnly.substring(0, 8) : digitsOnly;
    final buffer = StringBuffer();
    for (int i = 0; i < truncated.length; i++) {
      if (i == 2 || i == 4) {
        buffer.write('/');
      }
      buffer.write(truncated[i]);
    }
    return buffer.toString();
  }

  /// Validates whether a DD/MM/YYYY string represents a real, non-future calendar date
  static bool isValidDate(String? input) {
    if (input == null || input.trim().length != 10) return false;

    final parts = input.trim().split('/');
    if (parts.length != 3) return false;

    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);

    if (day == null || month == null || year == null) return false;

    final currentYear = DateTime.now().year;
    if (year < 1900 || year > currentYear) return false;
    if (month < 1 || month > 12) return false;

    final daysInMonth = _getDaysInMonth(year, month);
    if (day < 1 || day > daysInMonth) return false;

    final parsedDate = DateTime(year, month, day);
    final now = DateTime.now();
    if (parsedDate.isAfter(now)) return false;

    return true;
  }

  static int _getDaysInMonth(int year, int month) {
    if (month == 2) {
      final isLeapYear = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
      return isLeapYear ? 29 : 28;
    }
    const days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    return days[month - 1];
  }
}
