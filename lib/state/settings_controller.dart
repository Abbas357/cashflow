import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../core/utils/currencies.dart';
import '../core/utils/formatters.dart';

/// The person's preferences and profile, kept in shared preferences.
class SettingsController extends ChangeNotifier {
  final SharedPreferences _prefs;

  SettingsController(this._prefs) {
    _apply();
  }

  static const _kTheme = 'theme_mode';
  static const _kCurrency = 'currency';
  static const _kCurrencyCode = 'currency_code';
  static const _kGrouping = 'grouping';
  static const _kDecimals = 'decimals';
  static const _kWeekStart = 'week_start';
  static const _kName = 'profile_name';
  static const _kAddress = 'profile_address';
  static const _kPhone = 'profile_phone';
  static const _kUserId = 'local_user_id';
  static const _kLastAccount = 'last_account';
  static const _kOnboarded = 'onboarded';

  ThemeMode get themeMode => ThemeMode.values.firstWhere(
    (m) => m.name == _prefs.getString(_kTheme),
    orElse: () => ThemeMode.system,
  );

  /// The picked currency. Before one is picked: the one this device's
  /// region uses, or, for books started when the app only knew rupees,
  /// whichever matches the symbol they set.
  Currency get currencyInfo {
    final picked = Currency.byCode(_prefs.getString(_kCurrencyCode));
    if (picked != null) return picked;
    final symbol = _prefs.getString(_kCurrency);
    if (symbol != null) {
      return currencies.where((c) => c.symbol == symbol).firstOrNull ?? Currency.byCode('PKR')!;
    }
    return Currency.forCountry(country) ??
        Currency.forCountry(PlatformDispatcher.instance.locale.countryCode) ??
        Currency.byCode('USD')!;
  }

  static const _kCountry = 'country_code';

  /// The country found when the app first opened here (see DeviceRegion), as
  /// an ISO code. Null if it could not be worked out.
  String? get country => _prefs.getString(_kCountry);
  Future<void> setCountry(String code) => _set(_prefs.setString(_kCountry, code));

  static const _kInstallId = 'install_id';
  static const _kInstallReported = 'install_reported';

  /// A random id for this install, for counting people per country. Separate
  /// from [userId], so it cannot be tied to their account or their books.
  String get installId {
    var id = _prefs.getString(_kInstallId);
    if (id == null) {
      id = const Uuid().v4();
      _prefs.setString(_kInstallId, id);
    }
    return id;
  }

  /// What the cloud last heard from this install (see InstallReport).
  String? get installReported => _prefs.getString(_kInstallReported);
  Future<void> setInstallReported(String what) => _prefs.setString(_kInstallReported, what);
  Future<void> clearInstallReported() => _set(_prefs.remove(_kInstallReported));

  static const _kInstallStatsOff = 'install_stats_off';

  /// They deleted what this install reported, so it reports nothing more.
  bool get installStatsOff => _prefs.getBool(_kInstallStatsOff) ?? false;
  Future<void> setInstallStatsOff(bool v) => _set(_prefs.setBool(_kInstallStatsOff, v));

  /// The symbol shown beside amounts: the currency's own, unless changed.
  String get currency => _prefs.getString(_kCurrency) ?? currencyInfo.symbol;
  NumberGrouping get grouping => NumberGrouping.values.firstWhere(
    (g) => g.name == _prefs.getString(_kGrouping),
    orElse: () => currencyInfo.grouping,
  );
  int get decimals => _prefs.getInt(_kDecimals) ?? 0;

  /// DateTime.monday or DateTime.sunday.
  int get weekStart => _prefs.getInt(_kWeekStart) ?? DateTime.monday;

  String get name => _prefs.getString(_kName) ?? '';
  String get address => _prefs.getString(_kAddress) ?? '';
  String get phone => _prefs.getString(_kPhone) ?? '';
  String? get lastAccountId => _prefs.getString(_kLastAccount);
  bool get onboarded => _prefs.getBool(_kOnboarded) ?? false;

  /// A stable id for this device's user, created on first launch.
  String get userId {
    var id = _prefs.getString(_kUserId);
    if (id == null) {
      id = const Uuid().v4();
      _prefs.setString(_kUserId, id);
    }
    return id;
  }

  String get displayName => name.trim().isEmpty ? 'You' : name.trim();

  static const _kCloudUser = 'cloud_user_id';

  /// The signed-in account this device's books belong to, or null when
  /// they have never been tied to one (or were signed out of).
  String? get cloudUserId => _prefs.getString(_kCloudUser);

  /// Ties this device's books to the cloud user [id], who becomes the
  /// author of every change from here on.
  Future<void> setCloudUser(String id) async {
    await _prefs.setString(_kCloudUser, id);
    await _set(_prefs.setString(_kUserId, id));
  }

  /// After signing out: a fresh local id for whatever is written next.
  Future<void> forgetCloudUser() async {
    await _prefs.remove(_kCloudUser);
    await _set(_prefs.setString(_kUserId, const Uuid().v4()));
  }

  /// After deleting the account: everything kept here goes, as on a fresh
  /// install. The next write gets a new local id.
  Future<void> eraseAll() => _set(_prefs.clear());

  Future<void> setName(String v) => _set(_prefs.setString(_kName, v.trim()));

  static const _kNotifyChanges = 'notify_changes';

  /// Whether to show a notification when someone you share an account
  /// with adds, edits or deletes an entry.
  bool get notifyChanges => _prefs.getBool(_kNotifyChanges) ?? true;
  Future<void> setNotifyChanges(bool v) => _set(_prefs.setBool(_kNotifyChanges, v));

  static const _kUnread = 'unread_changes';

  /// Changes by other people (entry_changes ids) not yet seen in the bell.
  /// Kept on this device.
  Set<String> get unreadChanges => {...?_prefs.getStringList(_kUnread)};
  Future<void> setUnreadChanges(Set<String> ids) async {
    // The newest few hundred are plenty for a badge.
    final list = ids.toList();
    await _prefs.setStringList(_kUnread, list.length > 500 ? list.sublist(list.length - 500) : list);
  }

  static const _kPendingJoin = 'pending_join';

  /// A QR code scanned before signing in, to offer once signed in.
  String? get pendingJoin => _prefs.getString(_kPendingJoin);
  Future<void> setPendingJoin(String? code) =>
      code == null ? _prefs.remove(_kPendingJoin) : _prefs.setString(_kPendingJoin, code);

  static const _kPendingDelete = 'pending_delete_account';

  /// Opened the delete account page signed out, to return to once signed in.
  bool get pendingDeleteAccount => _prefs.getBool(_kPendingDelete) ?? false;
  Future<void> setPendingDeleteAccount(bool v) =>
      v ? _prefs.setBool(_kPendingDelete, true) : _prefs.remove(_kPendingDelete);

  /// Whether dark colours are showing right now, given the system setting.
  bool isDark(BuildContext context) => switch (themeMode) {
    ThemeMode.dark => true,
    ThemeMode.light => false,
    ThemeMode.system =>
      MediaQuery.platformBrightnessOf(context) == Brightness.dark,
  };

  void _apply() {
    Fmt.currency = currency;
    Fmt.grouping = grouping;
    Fmt.decimals = decimals;
  }

  Future<void> _set(Future<bool> write) async {
    await write;
    _apply();
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode m) => _set(_prefs.setString(_kTheme, m.name));

  Future<void> toggleDark(BuildContext context) =>
      setThemeMode(isDark(context) ? ThemeMode.light : ThemeMode.dark);

  Future<void> setCurrency(String v) => _set(_prefs.setString(_kCurrency, v.trim()));

  /// Picks a currency, with its symbol and usual grouping. Both can still
  /// be changed on their own afterwards.
  Future<void> setCurrencyCode(String code) async {
    final c = Currency.byCode(code);
    if (c == null) return;
    await _prefs.setString(_kCurrencyCode, c.code);
    await _prefs.setString(_kGrouping, c.grouping.name);
    await _set(_prefs.setString(_kCurrency, c.symbol));
  }

  /// Keeps the currency showing now, so one guessed from the device's region
  /// stays put. A currency or symbol already set is left as it is.
  Future<void> keepCurrency() async {
    if (_prefs.getString(_kCurrency) == null) await setCurrencyCode(currencyInfo.code);
  }

  Future<void> setGrouping(NumberGrouping g) =>
      _set(_prefs.setString(_kGrouping, g.name));
  Future<void> setDecimals(int d) => _set(_prefs.setInt(_kDecimals, d));
  Future<void> setWeekStart(int d) => _set(_prefs.setInt(_kWeekStart, d));
  Future<void> setOnboarded() => _set(_prefs.setBool(_kOnboarded, true));

  Future<void> setProfile({
    required String name,
    required String address,
    required String phone,
  }) async {
    await _prefs.setString(_kName, name.trim());
    await _prefs.setString(_kAddress, address.trim());
    await _set(_prefs.setString(_kPhone, phone.trim()));
  }

  Future<void> setLastAccount(String id) => _prefs.setString(_kLastAccount, id);

  static const _kSidebarWidth = 'sidebar_width';
  static const _kSidebarCollapsed = 'sidebar_collapsed';

  /// The desktop sidebar's width and folded state. Saved quietly (no
  /// rebuild of the app) since the sidebar keeps its own copy while used.
  double? get sidebarWidth => _prefs.getDouble(_kSidebarWidth);
  bool get sidebarCollapsed => _prefs.getBool(_kSidebarCollapsed) ?? false;
  Future<void> saveSidebar({required double width, required bool collapsed}) async {
    await _prefs.setDouble(_kSidebarWidth, width);
    await _prefs.setBool(_kSidebarCollapsed, collapsed);
  }

  static const _kEntryDraft = 'entry_draft';

  /// The half-typed Cash In / Cash Out form, as JSON, so a browser refresh
  /// does not lose it. Not a preference, so it does not notify listeners.
  String? get entryDraft => _prefs.getString(_kEntryDraft);

  Future<void> setEntryDraft(String? json) =>
      json == null ? _prefs.remove(_kEntryDraft) : _prefs.setString(_kEntryDraft, json);
}
