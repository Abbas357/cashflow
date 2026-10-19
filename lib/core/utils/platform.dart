import 'package:flutter/foundation.dart';

/// Desktop apps and the web get the resizable, collapsible sidebar with
/// search. Android and iOS keep the drawer.
bool get isDesktopLike =>
    kIsWeb ||
    switch (defaultTargetPlatform) {
      TargetPlatform.windows || TargetPlatform.macOS || TargetPlatform.linux => true,
      _ => false,
    };
