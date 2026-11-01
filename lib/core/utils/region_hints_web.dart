import 'dart:js_interop';

extension type _DateFormat._(JSObject _) implements JSObject {
  external _DateFormatOptions resolvedOptions();
}

extension type _DateFormatOptions._(JSObject _) implements JSObject {
  external String? get timeZone;
}

@JS('Intl.DateTimeFormat')
external _DateFormat _dateFormat();

/// A browser only knows its time zone, such as Asia/Karachi.
Future<({String? sim, String? network, String? zone})> regionHints() async {
  try {
    return (sim: null, network: null, zone: _dateFormat().resolvedOptions().timeZone);
  } catch (_) {
    return (sim: null, network: null, zone: null);
  }
}
