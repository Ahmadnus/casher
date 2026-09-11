import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';

/// Fallback implementation — never used at runtime; exists so the
/// conditional export always has a default target.
const bool isWebPlatform = false;
const bool isWindowsPlatform = false;

Widget localImage(
  String path, {
  BoxFit? fit,
  double? width,
  double? height,
  ImageErrorWidgetBuilder? errorBuilder,
}) =>
    const SizedBox.shrink();

Future<MultipartFile> multipartFromPath(String path, {String? filename}) =>
    throw UnsupportedError('multipartFromPath is not supported here');

Future<bool> openPrintWindow(String html, {String title = ''}) async => false;
