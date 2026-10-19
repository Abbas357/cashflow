import 'package:flutter/material.dart';

import '../data/models/models.dart';
import '../data/repositories/ledger_repository.dart';
import 'period.dart';
import 'settings_controller.dart';

enum SortField { date, notes }

/// Totals for a set of entries.
class Totals {
  final double cashIn;
  final double cashOut;
  final int count;

  const Totals(this.cashIn, this.cashOut, this.count);

  double get balance => cashIn - cashOut;

  static Totals of(Iterable<Entry> entries) {
    var i = 0.0, o = 0.0, n = 0;
    for (final e in entries) {
      if (e.isIn) {
        i += e.amount;
      } else {
        o += e.amount;
      }
      n++;
    }
    return Totals(i, o, n);
  }
}

/// The open account, its entries, and how they are being looked at
/// (period, search, sort). Screens listen to this.
class LedgerController extends ChangeNotifier {
  final LedgerRepository repo;
  final SettingsController settings;

  LedgerController(this.repo, this.settings) {
    settings.addListener(_onSettings);
  }

  bool loading = true;
  List<Account> accounts = [];
  Account? current;

  /// Entries of [current], oldest first.
  List<Entry> _entries = [];

  /// Balance after each entry, across all time, keyed by entry id.
  Map<String, double> _running = {};

  /// Bumped on every write so pages that load their own data (reports,
  /// all-accounts views) know to reload.
  int revision = 0;

  PeriodKind _kind = PeriodKind.all;
  DateTime _anchor = DateTime.now();
  DateTimeRange? _range;
  String search = '';
  SortField sortField = SortField.date;
  bool ascending = false;

  Period get period => Period(
    kind: _kind,
    anchor: _anchor,
    range: _range,
    weekStart: settings.weekStart,
  );

  bool get canEdit => current?.canEdit ?? false;

  void _onSettings() {
    repo.actor = Actor(settings.userId, settings.displayName);
    notifyListeners();
  }

  @override
  void dispose() {
    settings.removeListener(_onSettings);
    super.dispose();
  }

  // ------------------------------------------------------------------ load

  Future<void> load() async {
    accounts = await repo.accounts();
    if (accounts.isEmpty) {
      await repo.createAccount('Personal');
      accounts = await repo.accounts();
    }
    final last = settings.lastAccountId;
    current = accounts.firstWhere(
      (a) => a.id == last,
      orElse: () => accounts.first,
    );
    await _loadEntries();
    loading = false;
    notifyListeners();
  }

  Future<void> _loadEntries() async {
    final acc = current;
    _entries = acc == null ? [] : await repo.entries(accountId: acc.id);
    var bal = 0.0;
    _running = {
      for (final e in _entries) e.id: bal += e.signed,
    };
  }

  Future<void> _refresh() async {
    revision++;
    accounts = await repo.accounts();
    if (current != null) {
      current = accounts.where((a) => a.id == current!.id).firstOrNull ??
          (accounts.isEmpty ? null : accounts.first);
    }
    await _loadEntries();
    notifyListeners();
  }

  /// Reloads everything, after a restore or a wipe.
  Future<void> reload() async {
    loading = true;
    notifyListeners();
    await load();
    revision++;
    notifyListeners();
  }

  // ------------------------------------------------------------- accounts

  Future<void> selectAccount(Account a) async {
    current = a;
    await settings.setLastAccount(a.id);
    await _loadEntries();
    notifyListeners();
  }

  Future<Account> createAccount(String name, {String description = ''}) async {
    final a = await repo.createAccount(name, description: description);
    await _refresh();
    return a;
  }

  Future<void> renameAccount(Account a, String name, {String? description}) async {
    await repo.updateAccount(a.copyWith(name: name, description: description));
    await _refresh();
  }

  Future<void> deleteAccount(Account a) async {
    await repo.deleteAccount(a.id);
    if (current?.id == a.id) current = null;
    accounts = await repo.accounts();
    if (accounts.isEmpty) {
      await repo.createAccount('Personal');
      accounts = await repo.accounts();
    }
    current ??= accounts.first;
    await settings.setLastAccount(current!.id);
    await _refresh();
  }

  Future<void> reorderAccounts(int oldIndex, int newIndex) async {
    // newIndex already accounts for the item being removed first.
    final list = [...accounts];
    list.insert(newIndex, list.removeAt(oldIndex));
    accounts = list;
    notifyListeners();
    for (var i = 0; i < list.length; i++) {
      if (list[i].sortOrder != i) {
        await repo.updateAccount(list[i].copyWith(sortOrder: i));
      }
    }
    await _refresh();
  }

  // -------------------------------------------------------------- entries

  Future<Entry> addEntry({
    required EntryType type,
    required double amount,
    String note = '',
    required DateTime at,
    String? attachment,
  }) async {
    final e = await repo.addEntry(
      accountId: current!.id,
      type: type,
      amount: amount,
      note: note,
      occurredAt: at,
      attachment: attachment,
    );
    await _refresh();
    return e;
  }

  Future<void> updateEntry(Entry e) async {
    await repo.updateEntry(e);
    await _refresh();
  }

  Future<void> deleteEntry(Entry e) async {
    await repo.deleteEntry(e);
    await _refresh();
  }

  Future<void> transfer({
    required Account from,
    required Account to,
    required double amount,
    required DateTime at,
    String note = '',
  }) async {
    await repo.transfer(from: from, to: to, amount: amount, at: at, note: note);
    await _refresh();
  }

  /// Called after a write made elsewhere, such as a restore.
  Future<void> changed() => _refresh();

  // ------------------------------------------------------------ the view

  void setPeriodKind(PeriodKind k) {
    _kind = k;
    if (k != PeriodKind.custom) {
      _range = null;
      _anchor = DateTime.now();
    }
    notifyListeners();
  }

  void setRange(DateTimeRange r) {
    _range = r;
    _kind = PeriodKind.custom;
    notifyListeners();
  }

  void stepPeriod(int by) {
    final p = period.step(by);
    _anchor = p.anchor;
    notifyListeners();
  }

  void jumpTo(DateTime d) {
    _anchor = d;
    notifyListeners();
  }

  void setSearch(String q) {
    search = q;
    notifyListeners();
  }

  void setSort(SortField f, {bool? ascending}) {
    sortField = f;
    if (ascending != null) this.ascending = ascending;
    notifyListeners();
  }

  void setAscending(bool asc) {
    ascending = asc;
    notifyListeners();
  }

  /// All entries of the open account, oldest first.
  List<Entry> get allEntries => _entries;

  /// Entries in the period and matching the search, sorted as chosen.
  List<Entry> get visible {
    final p = period;
    final q = search.trim().toLowerCase();
    final list = _entries.where((e) {
      if (!p.contains(e.occurredAt)) return false;
      if (q.isEmpty) return true;
      return e.note.toLowerCase().contains(q) ||
          e.amount.toString().contains(q);
    }).toList();
    if (sortField == SortField.notes) {
      list.sort((a, b) {
        final c = a.title.toLowerCase().compareTo(b.title.toLowerCase());
        return c != 0 ? c : a.occurredAt.compareTo(b.occurredAt);
      });
      return ascending ? list : list.reversed.toList();
    }
    // _entries is already oldest first.
    return ascending ? list : list.reversed.toList();
  }

  Totals get visibleTotals => Totals.of(visible);
  Totals get accountTotals => Totals.of(_entries);

  double? runningBalance(String entryId) => _running[entryId];

  /// Balance before the period starts, for "opening balance" lines.
  double get openingBalance {
    final b = period.bounds;
    if (b == null) return 0;
    return _entries
        .where((e) => e.occurredAt.isBefore(b.$1))
        .fold(0.0, (s, e) => s + e.signed);
  }
}
