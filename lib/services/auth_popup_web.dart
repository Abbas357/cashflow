import 'dart:async';
import 'dart:js_interop';

@JS('window.open')
external _Window? _open(String url, String name, String features);

@JS('window.screenX')
external int get _screenX;
@JS('window.screenY')
external int get _screenY;
@JS('window.outerWidth')
external int get _outerWidth;
@JS('window.outerHeight')
external int get _outerHeight;

extension type _Window(JSObject _) implements JSObject {
  external bool get closed;
  external _Location get location;
  external _Document get document;
  external void close();
  external void focus();
}

extension type _Location(JSObject _) implements JSObject {
  external set href(String value);
}

extension type _Document(JSObject _) implements JSObject {
  external _Element? get body;
  external set title(String value);
}

extension type _Element(JSObject _) implements JSObject {
  external set textContent(String value);
}

@JS('BroadcastChannel')
extension type _Channel._(JSObject _) implements JSObject {
  external factory _Channel(String name);
  external set onmessage(JSFunction handler);
  external void close();
}

extension type _MessageEvent(JSObject _) implements JSObject {
  external _Result get data;
}

extension type _Result(JSObject _) implements JSObject {
  external String? get code;
  external String? get error;
}

/// What came back from the sign-in window. Both empty: it was closed first.
typedef AuthPopupResult = ({String? code, String? error});

/// The small window Google sign-in runs in on the web, so the app stays where
/// it is underneath. It ends on `web/auth-callback.html`, which sends the
/// result here and closes the window.
class AuthPopup {
  static const _width = 500;
  static const _height = 640;

  /// The page that ends sign-in, `web/auth-callback.html`, relative to the
  /// app's folder.
  static const callbackPage = 'auth-callback.html';

  /// How long to wait for the result after the window closes: the page sends
  /// it just before closing, and the two can arrive in either order.
  static const _lastCall = Duration(seconds: 2);

  final _Window _window;
  final _channel = _Channel('cash-flow-auth');
  final _done = Completer<AuthPopupResult>();
  Timer? _watch;

  AuthPopup._(this._window) {
    _channel.onmessage = ((_MessageEvent event) {
      final data = event.data;
      _finish((code: data.code, error: data.error));
    }).toJS;
    _watch = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!_window.closed) return;
      timer.cancel();
      _watch = Timer(_lastCall, () => _finish((code: null, error: null)));
    });
  }

  /// Opens an empty window centred over the page, or returns null when the
  /// browser blocks it. Call straight from the tap: browsers only allow a
  /// window that a person asked for.
  static AuthPopup? open() {
    final left = _screenX + (_outerWidth - _width) ~/ 2;
    final top = _screenY + (_outerHeight - _height) ~/ 2;
    final window = _open(
      '',
      'cash-flow-sign-in',
      'popup=yes,width=$_width,height=$_height,left=$left,top=$top',
    );
    if (window == null) return null;
    window.document.title = 'Cash Flow';
    window.document.body?.textContent = 'Opening Google…';
    return AuthPopup._(window);
  }

  void go(String url) => _window.location.href = url;

  void focus() => _window.focus();

  /// Closes the window, when sign-in could not start.
  void close() {
    _window.close();
    _finish((code: null, error: null));
  }

  Future<AuthPopupResult> get result => _done.future;

  void _finish(AuthPopupResult result) {
    if (_done.isCompleted) return;
    _watch?.cancel();
    _channel.close();
    _done.complete(result);
  }
}
