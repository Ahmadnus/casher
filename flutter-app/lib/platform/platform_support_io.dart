import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';

/// Desktop / Android implementation — identical to what the app did before
/// the web port: files are real paths on disk.
const bool isWebPlatform = false;
bool get isWindowsPlatform => Platform.isWindows;

Widget localImage(
  String path, {
  BoxFit? fit,
  double? width,
  double? height,
  ImageErrorWidgetBuilder? errorBuilder,
}) =>
    Image.file(
      File(path),
      fit: fit,
      width: width,
      height: height,
      errorBuilder: errorBuilder,
    );

Future<MultipartFile> multipartFromPath(String path, {String? filename}) =>
    MultipartFile.fromFile(path, filename: filename);

/// Browser printing does not exist on desktop; the thermal printer path in
/// PrinterService is the only print route there.
Future<bool> openPrintWindow(String html, {String title = ''}) async => false;
