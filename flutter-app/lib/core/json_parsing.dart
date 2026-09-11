/// Tolerant JSON scalar parsing.
///
/// The production MySQL/Laravel API serializes some numerics as strings
/// ("id": "1", "price": "12.00") and booleans as 0/1, while local dev
/// returned native types. These helpers accept every representation.
library;

int? asIntOrNull(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? double.tryParse(v)?.toInt();
  return null;
}

int asInt(dynamic v, [int fallback = 0]) => asIntOrNull(v) ?? fallback;

double? asDoubleOrNull(dynamic v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

double asDouble(dynamic v, [double fallback = 0.0]) =>
    asDoubleOrNull(v) ?? fallback;

/// Coerces any scalar to a String — numeric ids/codes sometimes arrive as
/// numbers where a string is expected.
String asString(dynamic v, [String fallback = '']) {
  if (v == null) return fallback;
  if (v is String) return v;
  return v.toString();
}

bool asBool(dynamic v, [bool fallback = false]) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final s = v.toLowerCase();
    if (s == 'true' || s == '1') return true;
    if (s == 'false' || s == '0') return false;
  }
  return fallback;
}
