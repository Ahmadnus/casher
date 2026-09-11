import 'dart:async';
import 'dart:js_interop';

import 'package:cross_file/cross_file.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// Web implementation. There is no file system: image_picker hands back a
/// blob: URL, which the browser can both render and re-read as bytes.
const bool isWebPlatform = true;
const bool isWindowsPlatform = false;

Widget localImage(
  String path, {
  BoxFit? fit,
  double? width,
  double? height,
  ImageErrorWidgetBuilder? errorBuilder,
}) =>
    Image.network(
      path,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: errorBuilder,
    );

Future<MultipartFile> multipartFromPath(String path, {String? filename}) async {
  final bytes = await XFile(path).readAsBytes();
  return MultipartFile.fromBytes(bytes, filename: filename ?? 'upload.jpg');
}

/// Optional fallback print route on web: renders the receipt HTML inside a
/// hidden iframe and invokes the browser's print dialog for it. Used only
/// when the local print agent is unavailable — the agent is the primary
/// route. An iframe (not a popup) so popup blockers never interfere.
Future<bool> openPrintWindow(String markup, {String title = ''}) async {
  try {
    final iframe =
        web.document.createElement('iframe') as web.HTMLIFrameElement;
    iframe.style
      ..position = 'fixed'
      ..right = '0'
      ..bottom = '0'
      ..width = '0'
      ..height = '0'
      ..border = '0';
    iframe.setAttribute('srcdoc', markup);

    final loaded = Completer<void>();
    iframe.onload = ((web.Event _) {
      if (!loaded.isCompleted) loaded.complete();
    }).toJS;

    web.document.body!.appendChild(iframe);

    try {
      await loaded.future.timeout(const Duration(seconds: 3));
    } catch (_) {
      // Some browsers fire load before the listener attaches; continue.
    }

    final win = iframe.contentWindow;
    if (win == null) {
      iframe.remove();
      return false;
    }
    win.focus();
    win.print();
    // The print dialog is modal in most browsers; clean up afterwards.
    Future.delayed(const Duration(seconds: 60), () => iframe.remove());
    return true;
  } catch (_) {
    return false;
  }
}
