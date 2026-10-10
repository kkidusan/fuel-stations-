// ─────────────────────────────────────────────────────────────────────
// Country dial codes for the phone-number input.
//
// Ethiopia (+251) is the default. The list is intentionally a curated
// "common set" — add more entries here and they appear everywhere.
//
// `length` is the national significant number length (the number of digits
// typed after the country code). It drives how many slots the phone field
// exposes and where the mask dashes stop.
// ─────────────────────────────────────────────────────────────────────

class Country {
  const Country(this.name, this.dialCode, this.flag, [this.length = 9]);

  final String name;

  /// Digits only, without the leading "+". e.g. '251'.
  final String dialCode;

  /// Flag emoji, e.g. '🇪🇹'.
  final String flag;

  /// National significant number length (digits after the country code).
  final int length;
}

const Country kDefaultCountry = Country('Ethiopia', '251', '🇪🇹', 9);

const List<Country> kCountries = <Country>[
  kDefaultCountry,
  Country('Eritrea', '291', '🇪🇷', 7),
  Country('Djibouti', '253', '🇩🇯', 8),
  Country('Somalia', '252', '🇸🇴', 9),
  Country('Kenya', '254', '🇰🇪', 9),
  Country('South Sudan', '211', '🇸🇸', 9),
  Country('Sudan', '249', '🇸🇩', 9),
  Country('Uganda', '256', '🇺🇬', 9),
  Country('Tanzania', '255', '🇹🇿', 9),
  Country('Rwanda', '250', '🇷🇼', 9),
  Country('Burundi', '257', '🇧🇮', 8),
  Country('Egypt', '20', '🇪🇬', 10),
  Country('Saudi Arabia', '966', '🇸🇦', 9),
  Country('United Arab Emirates', '971', '🇦🇪', 9),
  Country('Qatar', '974', '🇶🇦', 8),
  Country('Turkey', '90', '🇹🇷', 10),
  Country('United States', '1', '🇺🇸', 10),
  Country('Canada', '1', '🇨🇦', 10),
  Country('United Kingdom', '44', '🇬🇧', 10),
  Country('Germany', '49', '🇩🇪', 11),
  Country('France', '33', '🇫🇷', 9),
  Country('Italy', '39', '🇮🇹', 10),
  Country('Netherlands', '31', '🇳🇱', 9),
  Country('Sweden', '46', '🇸🇪', 9),
  Country('Norway', '47', '🇳🇴', 8),
  Country('China', '86', '🇨🇳', 11),
  Country('India', '91', '🇮🇳', 10),
  Country('Japan', '81', '🇯🇵', 10),
  Country('South Africa', '27', '🇿🇦', 9),
  Country('Nigeria', '234', '🇳🇬', 10),
  Country('Ghana', '233', '🇬🇭', 9),
  Country('Brazil', '55', '🇧🇷', 11),
  Country('Australia', '61', '🇦🇺', 9),
  Country('Russia', '7', '🇷🇺', 10),
];

/// Longest dial code that prefixes [digits], or null when none matches.
Country? matchCountryFor(String digits) {
  Country? best;
  for (final c in kCountries) {
    if (digits.startsWith(c.dialCode) &&
        digits.length > c.dialCode.length &&
        (best == null || c.dialCode.length > best.dialCode.length)) {
      best = c;
    }
  }
  return best;
}
