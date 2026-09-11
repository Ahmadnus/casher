// Picks the printer backend at compile time so the web build never links
// the USB plugin (which has no web implementation) and the desktop build
// never links dart:html.
export 'printer_backend_stub.dart'
    if (dart.library.io) 'printer_backend_io.dart'
    if (dart.library.js_interop) 'printer_backend_web.dart';
