import 'dart:js_interop';

@JS('document.baseURI')
external String get _baseUri;

/// The address the web app is served from, from the page's `<base href>`:
/// `https://example.github.io/cashflow/` when hosted in a sub-folder.
String pageBase() => _baseUri;
