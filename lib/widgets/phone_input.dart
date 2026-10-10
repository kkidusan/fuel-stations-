import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/countries.dart';

/// Digits only (strips spaces, dashes, "+", parentheses, …).
String onlyDigits(String value) => value.replaceAll(RegExp(r'[^0-9]'), '');

/// Combine a country dial code and a locally typed number into the stored
/// format: digits including the country code (e.g. 251 948931932).
String combinePhone(String dialCode, String local) {
  final digits = onlyDigits(local);
  if (digits.isEmpty) return '';
  return dialCode + (digits.startsWith('0') ? digits.substring(1) : digits);
}

/// Group sizes for a national number of [length] digits.
///   9  → [3, 3, 3]     (Ethiopia)
///   10 → [3, 3, 4]
///   7  → [3, 4]
List<int> phoneGroups(int length) {
  final groups = <int>[];
  var remaining = length;
  while (remaining > 4) {
    groups.add(3);
    remaining -= 3;
  }
  if (remaining > 0) groups.add(remaining);
  return groups;
}

/// Render the typed digits, showing dashes for the still-empty slots:
///   ''         → '--- --- ---'
///   '9'        → '9-- --- ---'
///   '948'      → '948 --- ---'
///   '948931932'→ '948 931 932'
String maskPhone(String digits, int length, {String separator = ' '}) {
  final clean = onlyDigits(digits);
  final limited = clean.length > length ? clean.substring(0, length) : clean;
  final groups = phoneGroups(length);
  final buffer = StringBuffer();
  var index = 0;
  for (var g = 0; g < groups.length; g++) {
    if (g > 0) buffer.write(separator);
    for (var i = 0; i < groups[g]; i++) {
      buffer.write(index < limited.length ? limited[index] : '-');
      index++;
    }
  }
  return buffer.toString();
}

/// Pretty display for a stored phone number, e.g. "251948931932" → "+251 948 931 932".
String formatPhoneDisplay(String? stored) {
  final raw = (stored ?? '').trim();
  if (raw.isEmpty) return '—';
  final digits = onlyDigits(raw);
  if (digits.isEmpty) return raw; // e.g. a legacy "pending-<uid>" placeholder

  final country = matchCountryFor(digits);
  final dialCode = country?.dialCode ?? '';
  final local = dialCode.isNotEmpty ? digits.substring(dialCode.length) : digits;
  if (local.isEmpty) return '+$dialCode';

  final groups = phoneGroups(local.length);
  final buffer = StringBuffer();
  var index = 0;
  for (var g = 0; g < groups.length && index < local.length; g++) {
    if (g > 0) buffer.write(' ');
    final end = (index + groups[g] <= local.length) ? index + groups[g] : local.length;
    buffer.write(local.substring(index, end));
    index = end;
  }
  return dialCode.isEmpty ? '+${buffer.toString()}' : '+$dialCode ${buffer.toString()}';
}

/// Formats the field so it always shows the full mask with dashes for the
/// empty slots and never accepts more than [length] digits.
class PhoneMaskFormatter extends TextInputFormatter {
  PhoneMaskFormatter({required this.length});

  final int length;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = onlyDigits(newValue.text);
    final oldDigits = onlyDigits(oldValue.text);

    // Deleting a dash/space (no digit actually removed) should step the number
    // backwards — otherwise the mask would swallow backspaces.
    if (newValue.text.length < oldValue.text.length &&
        digits == oldDigits &&
        digits.isNotEmpty) {
      digits = digits.substring(0, digits.length - 1);
    }

    if (digits.length > length) digits = digits.substring(0, length);

    final masked = maskPhone(digits, length);
    return TextEditingValue(
      text: masked,
      selection: TextSelection.collapsed(offset: masked.length),
    );
  }
}

/// Holds the text controller plus the selected country for a phone input.
class PhoneController extends ChangeNotifier {
  PhoneController({String? initial, Country? country}) {
    number = TextEditingController();
    this.country = country ?? kDefaultCountry;
    setFromStored(initial);
  }

  late final TextEditingController number;
  Country country = kDefaultCountry;

  /// How many national digits the current country accepts.
  int get maxDigits => country.length;

  /// The digits the user actually typed (mask dashes stripped).
  String get digits => onlyDigits(number.text);

  /// The value to send to the API: digits including the country code.
  String get fullPhone => combinePhone(country.dialCode, digits);

  bool get isEmpty => digits.isEmpty;

  bool get isComplete => digits.length == country.length;

  void setCountry(Country value) {
    if (value.dialCode == country.dialCode && value.length == country.length) return;
    country = value;
    final d = digits.length > country.length ? digits.substring(0, country.length) : digits;
    number.text = maskPhone(d, country.length);
    notifyListeners();
  }

  /// A phone number is required and should be filled to the country's length.
  String? validate({bool required = true}) {
    if (digits.isEmpty) {
      return required ? 'Phone number is required' : null;
    }
    if (digits.length < country.length) {
      return 'Enter all ${country.length} digits';
    }
    return null;
  }

  /// Seed the field from a stored value such as "251948931932" or "+251...".
  void setFromStored(String? stored) {
    final raw = (stored ?? '').trim();
    final all = onlyDigits(raw);
    if (all.isEmpty) {
      number.text = maskPhone('', country.length);
      return;
    }

    final match = matchCountryFor(all);
    if (match != null) {
      country = match;
      var local = all.substring(match.dialCode.length);
      if (local.startsWith('0')) local = local.substring(1);
      if (local.length > country.length) local = local.substring(0, country.length);
      number.text = maskPhone(local, country.length);
    } else {
      country = kDefaultCountry;
      final local = all.length > country.length ? all.substring(0, country.length) : all;
      number.text = maskPhone(local, country.length);
    }
  }

  @override
  void dispose() {
    number.dispose();
    super.dispose();
  }
}

/// Country-code selector **and** number field inside a single bordered box,
/// e.g. `[ 🇪🇹 +251 | 948 931 932 ]`.
class PhoneField extends StatefulWidget {
  const PhoneField({
    super.key,
    required this.controller,
    this.label,
    this.hint = '9xx xxx xxx',
    this.enabled = true,
    this.validator,
    this.fillColor = const Color(0xFFF0F8F4),
    this.borderRadius = 16,
    this.textInputAction,
    this.autofocus = false,
    this.onSubmitted,
  });

  final PhoneController controller;
  final String? label;
  final String hint;
  final bool enabled;
  final String? Function(String?)? validator;
  final Color fillColor;
  final double borderRadius;
  final TextInputAction? textInputAction;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;

  @override
  State<PhoneField> createState() => _PhoneFieldState();
}

class _PhoneFieldState extends State<PhoneField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()..addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.borderRadius);
    final focused = _focusNode.hasFocus;
    final borderColor = focused ? const Color(0xFF2E7D32) : Colors.grey.shade400;

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.label != null && widget.label!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 6),
                child: Text(
                  widget.label!,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            // ── One single border wraps both the country code and the number ──
            Container(
              decoration: BoxDecoration(
                color: widget.fillColor,
                borderRadius: radius,
                border: Border.all(color: borderColor, width: focused ? 1.6 : 1.0),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  DropdownButtonHideUnderline(
                    child: DropdownButton<Country>(
                      value: widget.controller.country,
                      isDense: true,
                      borderRadius: BorderRadius.circular(12),
                      items: kCountries
                          .map(
                            (c) => DropdownMenuItem<Country>(
                              value: c,
                              child: Text(
                                '${c.flag} +${c.dialCode}',
                                style: const TextStyle(fontSize: 15),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: widget.enabled
                          ? (c) { if (c != null) widget.controller.setCountry(c); }
                          : null,
                    ),
                  ),
                  Container(
                    height: 26,
                    width: 1,
                    color: Colors.grey.shade300,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  Expanded(
                    child: TextFormField(
                      controller: widget.controller.number,
                      focusNode: _focusNode,
                      enabled: widget.enabled,
                      autofocus: widget.autofocus,
                      keyboardType: TextInputType.phone,
                      textInputAction: widget.textInputAction,
                      onFieldSubmitted: widget.onSubmitted,
                      // The mask strips anything that is not a digit, so special
                      // characters (+, -, spaces, …) are accepted and ignored.
                      inputFormatters: [
                        PhoneMaskFormatter(length: widget.controller.maxDigits),
                      ],
                      validator: widget.validator ?? ((_) => widget.controller.validate()),
                      decoration: InputDecoration(
                        hintText: widget.hint,
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                        errorStyle: const TextStyle(fontSize: 11, height: 1.1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
