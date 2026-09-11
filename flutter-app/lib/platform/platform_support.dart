// Platform seam: everything that differs between the desktop/mobile build
// (dart:io available) and the web build (browser APIs only) goes through
// here, so no screen or repository ever imports dart:io directly.
//
// The right implementation is picked at compile time, so the desktop app
// keeps its exact previous behaviour and the web build never links code
// that would fail to compile there.
export 'platform_support_stub.dart'
    if (dart.library.io) 'platform_support_io.dart'
    if (dart.library.js_interop) 'platform_support_web.dart';
