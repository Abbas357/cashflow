typedef AuthPopupResult = ({String? code, String? error});

/// Only the web app signs in through a small window.
class AuthPopup {
  static const callbackPage = '';

  static AuthPopup? open() => null;

  void go(String url) {}
  void focus() {}
  void close() {}
  Future<AuthPopupResult> get result async => (code: null, error: null);
}
