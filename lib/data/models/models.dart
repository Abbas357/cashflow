import 'dart:convert';

/// What a person may do in an account.
///
/// The owner made it. Editors can add, change and delete entries. Viewers
/// only read, but still see every entry and its change history.
enum AccountRole {
  owner,
  editor,
  viewer;

  bool get canEdit => this != AccountRole.viewer;
  bool get canManage => this == AccountRole.owner;

  String get label => switch (this) {
    AccountRole.owner => 'Owner',
    AccountRole.editor => 'Can edit',
    AccountRole.viewer => 'View only',
  };

  static AccountRole parse(String? v) =>
      AccountRole.values.firstWhere((r) => r.name == v, orElse: () => owner);
}

enum EntryType {
  cashIn('in'),
  cashOut('out');

  final String code;
  const EntryType(this.code);

  bool get isIn => this == EntryType.cashIn;
  String get label => isIn ? 'Cash In' : 'Cash Out';

  static EntryType parse(String v) => v == 'in' ? cashIn : cashOut;
}

/// Timestamps are stored as UTC ISO-8601 text. The same shape works in
/// SQLite, in Postgres `timestamptz`, and in a sync layer such as PowerSync.
String isoNow() => DateTime.now().toUtc().toIso8601String();
String toIso(DateTime d) => d.toUtc().toIso8601String();
DateTime fromIso(String s) => DateTime.parse(s).toLocal();

/// A book of entries, such as "Flat Expenditures".
class Account {
  final String id;
  final String name;
  final String description;
  final String ownerId;

  /// The local user's role in this account. Always owner until the
  /// account comes from someone else through sharing.
  final AccountRole role;
  final bool isShared;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Account({
    required this.id,
    required this.name,
    this.description = '',
    required this.ownerId,
    this.role = AccountRole.owner,
    this.isShared = false,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get canEdit => role.canEdit;

  Account copyWith({String? name, String? description, int? sortOrder}) =>
      Account(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        ownerId: ownerId,
        role: role,
        isShared: isShared,
        sortOrder: sortOrder ?? this.sortOrder,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );

  factory Account.fromRow(Map<String, Object?> r) => Account(
    id: r['id'] as String,
    name: r['name'] as String,
    description: (r['description'] as String?) ?? '',
    ownerId: r['owner_id'] as String,
    role: AccountRole.parse(r['role'] as String?),
    isShared: (r['is_shared'] as int? ?? 0) == 1,
    sortOrder: r['sort_order'] as int? ?? 0,
    createdAt: fromIso(r['created_at'] as String),
    updatedAt: fromIso(r['updated_at'] as String),
  );

  Map<String, Object?> toRow() => {
    'id': id,
    'name': name,
    'description': description,
    'owner_id': ownerId,
    'role': role.name,
    'is_shared': isShared ? 1 : 0,
    'sort_order': sortOrder,
    'created_at': toIso(createdAt),
    'updated_at': toIso(updatedAt),
  };
}

/// One cash in or cash out line.
class Entry {
  final String id;
  final String accountId;
  final EntryType type;
  final double amount;
  final String note;
  final DateTime occurredAt;
  final String? attachment;

  /// Set on both halves of a transfer between two accounts.
  final String? transferId;
  final String createdBy;
  final String updatedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Bumped on every edit. Lets a sync layer spot conflicting edits.
  final int version;

  const Entry({
    required this.id,
    required this.accountId,
    required this.type,
    required this.amount,
    this.note = '',
    required this.occurredAt,
    this.attachment,
    this.transferId,
    required this.createdBy,
    required this.updatedBy,
    required this.createdAt,
    required this.updatedAt,
    this.version = 1,
  });

  bool get isIn => type.isIn;
  double get signed => isIn ? amount : -amount;
  bool get wasEdited => version > 1;
  String get title => note.trim().isEmpty ? type.label : note.trim();

  Entry copyWith({
    EntryType? type,
    double? amount,
    String? note,
    DateTime? occurredAt,
    String? attachment,
    bool clearAttachment = false,
    String? accountId,
  }) => Entry(
    id: id,
    accountId: accountId ?? this.accountId,
    type: type ?? this.type,
    amount: amount ?? this.amount,
    note: note ?? this.note,
    occurredAt: occurredAt ?? this.occurredAt,
    attachment: clearAttachment ? null : (attachment ?? this.attachment),
    transferId: transferId,
    createdBy: createdBy,
    updatedBy: updatedBy,
    createdAt: createdAt,
    updatedAt: updatedAt,
    version: version,
  );

  factory Entry.fromRow(Map<String, Object?> r) => Entry(
    id: r['id'] as String,
    accountId: r['account_id'] as String,
    type: EntryType.parse(r['type'] as String),
    amount: (r['amount'] as num).toDouble(),
    note: (r['note'] as String?) ?? '',
    occurredAt: fromIso(r['occurred_at'] as String),
    attachment: r['attachment'] as String?,
    transferId: r['transfer_id'] as String?,
    createdBy: r['created_by'] as String,
    updatedBy: r['updated_by'] as String,
    createdAt: fromIso(r['created_at'] as String),
    updatedAt: fromIso(r['updated_at'] as String),
    version: r['version'] as int? ?? 1,
  );

  Map<String, Object?> toRow() => {
    'id': id,
    'account_id': accountId,
    'type': type.code,
    'amount': amount,
    'note': note,
    'occurred_at': toIso(occurredAt),
    'attachment': attachment,
    'transfer_id': transferId,
    'created_by': createdBy,
    'updated_by': updatedBy,
    'created_at': toIso(createdAt),
    'updated_at': toIso(updatedAt),
    'version': version,
  };

  /// The fields a person cares about when comparing before and after.
  Map<String, Object?> snapshot() => {
    'type': type.code,
    'amount': amount,
    'note': note,
    'occurred_at': toIso(occurredAt),
  };
}

enum ChangeAction {
  created,
  updated,
  deleted;

  static ChangeAction parse(String v) =>
      ChangeAction.values.firstWhere((a) => a.name == v, orElse: () => updated);
}

/// One line of an entry's history: who changed what, and the values
/// before and after. This is what lets people sharing an account see that
/// "Milk" went from 100 to 120.
class EntryChange {
  final String id;
  final String accountId;
  final String entryId;
  final ChangeAction action;
  final Map<String, Object?>? before;
  final Map<String, Object?>? after;
  final String changedBy;
  final String changedByName;
  final DateTime changedAt;

  const EntryChange({
    required this.id,
    required this.accountId,
    required this.entryId,
    required this.action,
    this.before,
    this.after,
    required this.changedBy,
    required this.changedByName,
    required this.changedAt,
  });

  factory EntryChange.fromRow(Map<String, Object?> r) {
    Map<String, Object?>? decode(Object? v) =>
        v == null ? null : (jsonDecode(v as String) as Map).cast<String, Object?>();
    return EntryChange(
      id: r['id'] as String,
      accountId: r['account_id'] as String,
      entryId: r['entry_id'] as String,
      action: ChangeAction.parse(r['action'] as String),
      before: decode(r['old_data']),
      after: decode(r['new_data']),
      changedBy: r['changed_by'] as String,
      changedByName: (r['changed_by_name'] as String?) ?? '',
      changedAt: fromIso(r['changed_at'] as String),
    );
  }

  Map<String, Object?> toRow() => {
    'id': id,
    'account_id': accountId,
    'entry_id': entryId,
    'action': action.name,
    'old_data': before == null ? null : jsonEncode(before),
    'new_data': after == null ? null : jsonEncode(after),
    'changed_by': changedBy,
    'changed_by_name': changedByName,
    'changed_at': toIso(changedAt),
  };

  /// Field names whose value differs between [before] and [after].
  List<String> get changedFields {
    if (before == null || after == null) return const [];
    return after!.keys.where((k) => before![k] != after![k]).toList();
  }
}

/// Where an invite stands. Pending invites wait on this device until
/// cloud sync is switched on, then go to whoever signs in with that mobile
/// number. They see the invitation and accept or decline it; only after
/// accepting do they see the account and its change history.
enum MemberStatus {
  active,
  pending,
  declined;

  static MemberStatus parse(String? v) =>
      MemberStatus.values.firstWhere((s) => s.name == v, orElse: () => active);
}

/// A person who can see an account: the owner, or someone it was shared
/// with by email or QR code.
///
/// People are found by the Google address they sign in with (older
/// invites by mobile number still work). The row's id stays a UUID.
class AccountMember {
  final String id;
  final String accountId;

  /// The person's user id once known; until then, `email:<address>` (or
  /// `phone:<number>`).
  final String userId;
  final String displayName;
  final String email;
  final String phone;
  final AccountRole role;
  final MemberStatus status;
  final DateTime joinedAt;

  const AccountMember({
    required this.id,
    required this.accountId,
    required this.userId,
    required this.displayName,
    this.email = '',
    this.phone = '',
    required this.role,
    this.status = MemberStatus.active,
    required this.joinedAt,
  });

  bool get isPending => status == MemberStatus.pending;

  /// The best way to name them: their name, else the address or number.
  String get label => displayName.isNotEmpty ? displayName : (email.isNotEmpty ? email : phone);

  factory AccountMember.fromRow(Map<String, Object?> r) => AccountMember(
    id: r['id'] as String,
    accountId: r['account_id'] as String,
    userId: r['user_id'] as String,
    displayName: (r['display_name'] as String?) ?? '',
    email: (r['email'] as String?) ?? '',
    phone: (r['phone'] as String?) ?? '',
    role: AccountRole.parse(r['role'] as String?),
    status: MemberStatus.parse(r['status'] as String?),
    joinedAt: fromIso(r['joined_at'] as String),
  );

  Map<String, Object?> toRow() => {
    'id': id,
    'account_id': accountId,
    'user_id': userId,
    'display_name': displayName,
    'email': email,
    'phone': phone,
    'role': role.name,
    'status': status.name,
    'joined_at': toIso(joinedAt),
  };
}

/// Phone numbers in one shape, digits only with a leading +, so the same
/// person matches however they were saved ("0300 1234567", "+92 300...").
String normalizePhone(String raw, {String defaultCountryCode = '92'}) {
  var d = raw.replaceAll(RegExp(r'[^0-9+]'), '');
  if (d.startsWith('00')) d = '+${d.substring(2)}';
  if (d.startsWith('+')) return '+${d.substring(1).replaceAll('+', '')}';
  if (d.startsWith('0')) return '+$defaultCountryCode${d.substring(1)}';
  return d.isEmpty ? '' : '+$d';
}
