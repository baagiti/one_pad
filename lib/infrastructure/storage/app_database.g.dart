// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $PracticeSessionsTable extends PracticeSessions
    with TableInfo<$PracticeSessionsTable, PracticeSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PracticeSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _skillIdMeta = const VerificationMeta(
    'skillId',
  );
  @override
  late final GeneratedColumn<String> skillId = GeneratedColumn<String>(
    'skill_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _levelMeta = const VerificationMeta('level');
  @override
  late final GeneratedColumn<int> level = GeneratedColumn<int>(
    'level',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bpmMeta = const VerificationMeta('bpm');
  @override
  late final GeneratedColumn<int> bpm = GeneratedColumn<int>(
    'bpm',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, skillId, level, bpm, completedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'practice_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<PracticeSession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('skill_id')) {
      context.handle(
        _skillIdMeta,
        skillId.isAcceptableOrUnknown(data['skill_id']!, _skillIdMeta),
      );
    } else if (isInserting) {
      context.missing(_skillIdMeta);
    }
    if (data.containsKey('level')) {
      context.handle(
        _levelMeta,
        level.isAcceptableOrUnknown(data['level']!, _levelMeta),
      );
    } else if (isInserting) {
      context.missing(_levelMeta);
    }
    if (data.containsKey('bpm')) {
      context.handle(
        _bpmMeta,
        bpm.isAcceptableOrUnknown(data['bpm']!, _bpmMeta),
      );
    } else if (isInserting) {
      context.missing(_bpmMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_completedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PracticeSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PracticeSession(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      skillId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}skill_id'],
      )!,
      level: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}level'],
      )!,
      bpm: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bpm'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      )!,
    );
  }

  @override
  $PracticeSessionsTable createAlias(String alias) {
    return $PracticeSessionsTable(attachedDatabase, alias);
  }
}

class PracticeSession extends DataClass implements Insertable<PracticeSession> {
  final int id;
  final String skillId;
  final int level;
  final int bpm;
  final DateTime completedAt;
  const PracticeSession({
    required this.id,
    required this.skillId,
    required this.level,
    required this.bpm,
    required this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['skill_id'] = Variable<String>(skillId);
    map['level'] = Variable<int>(level);
    map['bpm'] = Variable<int>(bpm);
    map['completed_at'] = Variable<DateTime>(completedAt);
    return map;
  }

  PracticeSessionsCompanion toCompanion(bool nullToAbsent) {
    return PracticeSessionsCompanion(
      id: Value(id),
      skillId: Value(skillId),
      level: Value(level),
      bpm: Value(bpm),
      completedAt: Value(completedAt),
    );
  }

  factory PracticeSession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PracticeSession(
      id: serializer.fromJson<int>(json['id']),
      skillId: serializer.fromJson<String>(json['skillId']),
      level: serializer.fromJson<int>(json['level']),
      bpm: serializer.fromJson<int>(json['bpm']),
      completedAt: serializer.fromJson<DateTime>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'skillId': serializer.toJson<String>(skillId),
      'level': serializer.toJson<int>(level),
      'bpm': serializer.toJson<int>(bpm),
      'completedAt': serializer.toJson<DateTime>(completedAt),
    };
  }

  PracticeSession copyWith({
    int? id,
    String? skillId,
    int? level,
    int? bpm,
    DateTime? completedAt,
  }) => PracticeSession(
    id: id ?? this.id,
    skillId: skillId ?? this.skillId,
    level: level ?? this.level,
    bpm: bpm ?? this.bpm,
    completedAt: completedAt ?? this.completedAt,
  );
  PracticeSession copyWithCompanion(PracticeSessionsCompanion data) {
    return PracticeSession(
      id: data.id.present ? data.id.value : this.id,
      skillId: data.skillId.present ? data.skillId.value : this.skillId,
      level: data.level.present ? data.level.value : this.level,
      bpm: data.bpm.present ? data.bpm.value : this.bpm,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PracticeSession(')
          ..write('id: $id, ')
          ..write('skillId: $skillId, ')
          ..write('level: $level, ')
          ..write('bpm: $bpm, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, skillId, level, bpm, completedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PracticeSession &&
          other.id == this.id &&
          other.skillId == this.skillId &&
          other.level == this.level &&
          other.bpm == this.bpm &&
          other.completedAt == this.completedAt);
}

class PracticeSessionsCompanion extends UpdateCompanion<PracticeSession> {
  final Value<int> id;
  final Value<String> skillId;
  final Value<int> level;
  final Value<int> bpm;
  final Value<DateTime> completedAt;
  const PracticeSessionsCompanion({
    this.id = const Value.absent(),
    this.skillId = const Value.absent(),
    this.level = const Value.absent(),
    this.bpm = const Value.absent(),
    this.completedAt = const Value.absent(),
  });
  PracticeSessionsCompanion.insert({
    this.id = const Value.absent(),
    required String skillId,
    required int level,
    required int bpm,
    required DateTime completedAt,
  }) : skillId = Value(skillId),
       level = Value(level),
       bpm = Value(bpm),
       completedAt = Value(completedAt);
  static Insertable<PracticeSession> custom({
    Expression<int>? id,
    Expression<String>? skillId,
    Expression<int>? level,
    Expression<int>? bpm,
    Expression<DateTime>? completedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (skillId != null) 'skill_id': skillId,
      if (level != null) 'level': level,
      if (bpm != null) 'bpm': bpm,
      if (completedAt != null) 'completed_at': completedAt,
    });
  }

  PracticeSessionsCompanion copyWith({
    Value<int>? id,
    Value<String>? skillId,
    Value<int>? level,
    Value<int>? bpm,
    Value<DateTime>? completedAt,
  }) {
    return PracticeSessionsCompanion(
      id: id ?? this.id,
      skillId: skillId ?? this.skillId,
      level: level ?? this.level,
      bpm: bpm ?? this.bpm,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (skillId.present) {
      map['skill_id'] = Variable<String>(skillId.value);
    }
    if (level.present) {
      map['level'] = Variable<int>(level.value);
    }
    if (bpm.present) {
      map['bpm'] = Variable<int>(bpm.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PracticeSessionsCompanion(')
          ..write('id: $id, ')
          ..write('skillId: $skillId, ')
          ..write('level: $level, ')
          ..write('bpm: $bpm, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }
}

class $DailyUnlocksTable extends DailyUnlocks
    with TableInfo<$DailyUnlocksTable, DailyUnlock> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DailyUnlocksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _dateKeyMeta = const VerificationMeta(
    'dateKey',
  );
  @override
  late final GeneratedColumn<String> dateKey = GeneratedColumn<String>(
    'date_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _skillIdMeta = const VerificationMeta(
    'skillId',
  );
  @override
  late final GeneratedColumn<String> skillId = GeneratedColumn<String>(
    'skill_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _levelMeta = const VerificationMeta('level');
  @override
  late final GeneratedColumn<int> level = GeneratedColumn<int>(
    'level',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, dateKey, skillId, level];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'daily_unlocks';
  @override
  VerificationContext validateIntegrity(
    Insertable<DailyUnlock> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('date_key')) {
      context.handle(
        _dateKeyMeta,
        dateKey.isAcceptableOrUnknown(data['date_key']!, _dateKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_dateKeyMeta);
    }
    if (data.containsKey('skill_id')) {
      context.handle(
        _skillIdMeta,
        skillId.isAcceptableOrUnknown(data['skill_id']!, _skillIdMeta),
      );
    } else if (isInserting) {
      context.missing(_skillIdMeta);
    }
    if (data.containsKey('level')) {
      context.handle(
        _levelMeta,
        level.isAcceptableOrUnknown(data['level']!, _levelMeta),
      );
    } else if (isInserting) {
      context.missing(_levelMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DailyUnlock map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DailyUnlock(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      dateKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date_key'],
      )!,
      skillId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}skill_id'],
      )!,
      level: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}level'],
      )!,
    );
  }

  @override
  $DailyUnlocksTable createAlias(String alias) {
    return $DailyUnlocksTable(attachedDatabase, alias);
  }
}

class DailyUnlock extends DataClass implements Insertable<DailyUnlock> {
  final int id;
  final String dateKey;
  final String skillId;
  final int level;
  const DailyUnlock({
    required this.id,
    required this.dateKey,
    required this.skillId,
    required this.level,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['date_key'] = Variable<String>(dateKey);
    map['skill_id'] = Variable<String>(skillId);
    map['level'] = Variable<int>(level);
    return map;
  }

  DailyUnlocksCompanion toCompanion(bool nullToAbsent) {
    return DailyUnlocksCompanion(
      id: Value(id),
      dateKey: Value(dateKey),
      skillId: Value(skillId),
      level: Value(level),
    );
  }

  factory DailyUnlock.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DailyUnlock(
      id: serializer.fromJson<int>(json['id']),
      dateKey: serializer.fromJson<String>(json['dateKey']),
      skillId: serializer.fromJson<String>(json['skillId']),
      level: serializer.fromJson<int>(json['level']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'dateKey': serializer.toJson<String>(dateKey),
      'skillId': serializer.toJson<String>(skillId),
      'level': serializer.toJson<int>(level),
    };
  }

  DailyUnlock copyWith({
    int? id,
    String? dateKey,
    String? skillId,
    int? level,
  }) => DailyUnlock(
    id: id ?? this.id,
    dateKey: dateKey ?? this.dateKey,
    skillId: skillId ?? this.skillId,
    level: level ?? this.level,
  );
  DailyUnlock copyWithCompanion(DailyUnlocksCompanion data) {
    return DailyUnlock(
      id: data.id.present ? data.id.value : this.id,
      dateKey: data.dateKey.present ? data.dateKey.value : this.dateKey,
      skillId: data.skillId.present ? data.skillId.value : this.skillId,
      level: data.level.present ? data.level.value : this.level,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DailyUnlock(')
          ..write('id: $id, ')
          ..write('dateKey: $dateKey, ')
          ..write('skillId: $skillId, ')
          ..write('level: $level')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, dateKey, skillId, level);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DailyUnlock &&
          other.id == this.id &&
          other.dateKey == this.dateKey &&
          other.skillId == this.skillId &&
          other.level == this.level);
}

class DailyUnlocksCompanion extends UpdateCompanion<DailyUnlock> {
  final Value<int> id;
  final Value<String> dateKey;
  final Value<String> skillId;
  final Value<int> level;
  const DailyUnlocksCompanion({
    this.id = const Value.absent(),
    this.dateKey = const Value.absent(),
    this.skillId = const Value.absent(),
    this.level = const Value.absent(),
  });
  DailyUnlocksCompanion.insert({
    this.id = const Value.absent(),
    required String dateKey,
    required String skillId,
    required int level,
  }) : dateKey = Value(dateKey),
       skillId = Value(skillId),
       level = Value(level);
  static Insertable<DailyUnlock> custom({
    Expression<int>? id,
    Expression<String>? dateKey,
    Expression<String>? skillId,
    Expression<int>? level,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (dateKey != null) 'date_key': dateKey,
      if (skillId != null) 'skill_id': skillId,
      if (level != null) 'level': level,
    });
  }

  DailyUnlocksCompanion copyWith({
    Value<int>? id,
    Value<String>? dateKey,
    Value<String>? skillId,
    Value<int>? level,
  }) {
    return DailyUnlocksCompanion(
      id: id ?? this.id,
      dateKey: dateKey ?? this.dateKey,
      skillId: skillId ?? this.skillId,
      level: level ?? this.level,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (dateKey.present) {
      map['date_key'] = Variable<String>(dateKey.value);
    }
    if (skillId.present) {
      map['skill_id'] = Variable<String>(skillId.value);
    }
    if (level.present) {
      map['level'] = Variable<int>(level.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DailyUnlocksCompanion(')
          ..write('id: $id, ')
          ..write('dateKey: $dateKey, ')
          ..write('skillId: $skillId, ')
          ..write('level: $level')
          ..write(')'))
        .toString();
  }
}

class $PremiumSettingsTable extends PremiumSettings
    with TableInfo<$PremiumSettingsTable, PremiumSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PremiumSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _isPremiumMeta = const VerificationMeta(
    'isPremium',
  );
  @override
  late final GeneratedColumn<bool> isPremium = GeneratedColumn<bool>(
    'is_premium',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_premium" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [id, isPremium];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'premium_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<PremiumSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('is_premium')) {
      context.handle(
        _isPremiumMeta,
        isPremium.isAcceptableOrUnknown(data['is_premium']!, _isPremiumMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PremiumSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PremiumSetting(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      isPremium: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_premium'],
      )!,
    );
  }

  @override
  $PremiumSettingsTable createAlias(String alias) {
    return $PremiumSettingsTable(attachedDatabase, alias);
  }
}

class PremiumSetting extends DataClass implements Insertable<PremiumSetting> {
  final int id;
  final bool isPremium;
  const PremiumSetting({required this.id, required this.isPremium});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['is_premium'] = Variable<bool>(isPremium);
    return map;
  }

  PremiumSettingsCompanion toCompanion(bool nullToAbsent) {
    return PremiumSettingsCompanion(id: Value(id), isPremium: Value(isPremium));
  }

  factory PremiumSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PremiumSetting(
      id: serializer.fromJson<int>(json['id']),
      isPremium: serializer.fromJson<bool>(json['isPremium']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'isPremium': serializer.toJson<bool>(isPremium),
    };
  }

  PremiumSetting copyWith({int? id, bool? isPremium}) =>
      PremiumSetting(id: id ?? this.id, isPremium: isPremium ?? this.isPremium);
  PremiumSetting copyWithCompanion(PremiumSettingsCompanion data) {
    return PremiumSetting(
      id: data.id.present ? data.id.value : this.id,
      isPremium: data.isPremium.present ? data.isPremium.value : this.isPremium,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PremiumSetting(')
          ..write('id: $id, ')
          ..write('isPremium: $isPremium')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, isPremium);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PremiumSetting &&
          other.id == this.id &&
          other.isPremium == this.isPremium);
}

class PremiumSettingsCompanion extends UpdateCompanion<PremiumSetting> {
  final Value<int> id;
  final Value<bool> isPremium;
  const PremiumSettingsCompanion({
    this.id = const Value.absent(),
    this.isPremium = const Value.absent(),
  });
  PremiumSettingsCompanion.insert({
    this.id = const Value.absent(),
    this.isPremium = const Value.absent(),
  });
  static Insertable<PremiumSetting> custom({
    Expression<int>? id,
    Expression<bool>? isPremium,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (isPremium != null) 'is_premium': isPremium,
    });
  }

  PremiumSettingsCompanion copyWith({Value<int>? id, Value<bool>? isPremium}) {
    return PremiumSettingsCompanion(
      id: id ?? this.id,
      isPremium: isPremium ?? this.isPremium,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (isPremium.present) {
      map['is_premium'] = Variable<bool>(isPremium.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PremiumSettingsCompanion(')
          ..write('id: $id, ')
          ..write('isPremium: $isPremium')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $PracticeSessionsTable practiceSessions = $PracticeSessionsTable(
    this,
  );
  late final $DailyUnlocksTable dailyUnlocks = $DailyUnlocksTable(this);
  late final $PremiumSettingsTable premiumSettings = $PremiumSettingsTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    practiceSessions,
    dailyUnlocks,
    premiumSettings,
  ];
}

typedef $$PracticeSessionsTableCreateCompanionBuilder =
    PracticeSessionsCompanion Function({
      Value<int> id,
      required String skillId,
      required int level,
      required int bpm,
      required DateTime completedAt,
    });
typedef $$PracticeSessionsTableUpdateCompanionBuilder =
    PracticeSessionsCompanion Function({
      Value<int> id,
      Value<String> skillId,
      Value<int> level,
      Value<int> bpm,
      Value<DateTime> completedAt,
    });

class $$PracticeSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $PracticeSessionsTable> {
  $$PracticeSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get skillId => $composableBuilder(
    column: $table.skillId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bpm => $composableBuilder(
    column: $table.bpm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PracticeSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $PracticeSessionsTable> {
  $$PracticeSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get skillId => $composableBuilder(
    column: $table.skillId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bpm => $composableBuilder(
    column: $table.bpm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PracticeSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PracticeSessionsTable> {
  $$PracticeSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get skillId =>
      $composableBuilder(column: $table.skillId, builder: (column) => column);

  GeneratedColumn<int> get level =>
      $composableBuilder(column: $table.level, builder: (column) => column);

  GeneratedColumn<int> get bpm =>
      $composableBuilder(column: $table.bpm, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );
}

class $$PracticeSessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PracticeSessionsTable,
          PracticeSession,
          $$PracticeSessionsTableFilterComposer,
          $$PracticeSessionsTableOrderingComposer,
          $$PracticeSessionsTableAnnotationComposer,
          $$PracticeSessionsTableCreateCompanionBuilder,
          $$PracticeSessionsTableUpdateCompanionBuilder,
          (
            PracticeSession,
            BaseReferences<
              _$AppDatabase,
              $PracticeSessionsTable,
              PracticeSession
            >,
          ),
          PracticeSession,
          PrefetchHooks Function()
        > {
  $$PracticeSessionsTableTableManager(
    _$AppDatabase db,
    $PracticeSessionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PracticeSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PracticeSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PracticeSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> skillId = const Value.absent(),
                Value<int> level = const Value.absent(),
                Value<int> bpm = const Value.absent(),
                Value<DateTime> completedAt = const Value.absent(),
              }) => PracticeSessionsCompanion(
                id: id,
                skillId: skillId,
                level: level,
                bpm: bpm,
                completedAt: completedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String skillId,
                required int level,
                required int bpm,
                required DateTime completedAt,
              }) => PracticeSessionsCompanion.insert(
                id: id,
                skillId: skillId,
                level: level,
                bpm: bpm,
                completedAt: completedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PracticeSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PracticeSessionsTable,
      PracticeSession,
      $$PracticeSessionsTableFilterComposer,
      $$PracticeSessionsTableOrderingComposer,
      $$PracticeSessionsTableAnnotationComposer,
      $$PracticeSessionsTableCreateCompanionBuilder,
      $$PracticeSessionsTableUpdateCompanionBuilder,
      (
        PracticeSession,
        BaseReferences<_$AppDatabase, $PracticeSessionsTable, PracticeSession>,
      ),
      PracticeSession,
      PrefetchHooks Function()
    >;
typedef $$DailyUnlocksTableCreateCompanionBuilder =
    DailyUnlocksCompanion Function({
      Value<int> id,
      required String dateKey,
      required String skillId,
      required int level,
    });
typedef $$DailyUnlocksTableUpdateCompanionBuilder =
    DailyUnlocksCompanion Function({
      Value<int> id,
      Value<String> dateKey,
      Value<String> skillId,
      Value<int> level,
    });

class $$DailyUnlocksTableFilterComposer
    extends Composer<_$AppDatabase, $DailyUnlocksTable> {
  $$DailyUnlocksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dateKey => $composableBuilder(
    column: $table.dateKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get skillId => $composableBuilder(
    column: $table.skillId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DailyUnlocksTableOrderingComposer
    extends Composer<_$AppDatabase, $DailyUnlocksTable> {
  $$DailyUnlocksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dateKey => $composableBuilder(
    column: $table.dateKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get skillId => $composableBuilder(
    column: $table.skillId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DailyUnlocksTableAnnotationComposer
    extends Composer<_$AppDatabase, $DailyUnlocksTable> {
  $$DailyUnlocksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get dateKey =>
      $composableBuilder(column: $table.dateKey, builder: (column) => column);

  GeneratedColumn<String> get skillId =>
      $composableBuilder(column: $table.skillId, builder: (column) => column);

  GeneratedColumn<int> get level =>
      $composableBuilder(column: $table.level, builder: (column) => column);
}

class $$DailyUnlocksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DailyUnlocksTable,
          DailyUnlock,
          $$DailyUnlocksTableFilterComposer,
          $$DailyUnlocksTableOrderingComposer,
          $$DailyUnlocksTableAnnotationComposer,
          $$DailyUnlocksTableCreateCompanionBuilder,
          $$DailyUnlocksTableUpdateCompanionBuilder,
          (
            DailyUnlock,
            BaseReferences<_$AppDatabase, $DailyUnlocksTable, DailyUnlock>,
          ),
          DailyUnlock,
          PrefetchHooks Function()
        > {
  $$DailyUnlocksTableTableManager(_$AppDatabase db, $DailyUnlocksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DailyUnlocksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DailyUnlocksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DailyUnlocksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> dateKey = const Value.absent(),
                Value<String> skillId = const Value.absent(),
                Value<int> level = const Value.absent(),
              }) => DailyUnlocksCompanion(
                id: id,
                dateKey: dateKey,
                skillId: skillId,
                level: level,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String dateKey,
                required String skillId,
                required int level,
              }) => DailyUnlocksCompanion.insert(
                id: id,
                dateKey: dateKey,
                skillId: skillId,
                level: level,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DailyUnlocksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DailyUnlocksTable,
      DailyUnlock,
      $$DailyUnlocksTableFilterComposer,
      $$DailyUnlocksTableOrderingComposer,
      $$DailyUnlocksTableAnnotationComposer,
      $$DailyUnlocksTableCreateCompanionBuilder,
      $$DailyUnlocksTableUpdateCompanionBuilder,
      (
        DailyUnlock,
        BaseReferences<_$AppDatabase, $DailyUnlocksTable, DailyUnlock>,
      ),
      DailyUnlock,
      PrefetchHooks Function()
    >;
typedef $$PremiumSettingsTableCreateCompanionBuilder =
    PremiumSettingsCompanion Function({Value<int> id, Value<bool> isPremium});
typedef $$PremiumSettingsTableUpdateCompanionBuilder =
    PremiumSettingsCompanion Function({Value<int> id, Value<bool> isPremium});

class $$PremiumSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $PremiumSettingsTable> {
  $$PremiumSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPremium => $composableBuilder(
    column: $table.isPremium,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PremiumSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $PremiumSettingsTable> {
  $$PremiumSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPremium => $composableBuilder(
    column: $table.isPremium,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PremiumSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PremiumSettingsTable> {
  $$PremiumSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<bool> get isPremium =>
      $composableBuilder(column: $table.isPremium, builder: (column) => column);
}

class $$PremiumSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PremiumSettingsTable,
          PremiumSetting,
          $$PremiumSettingsTableFilterComposer,
          $$PremiumSettingsTableOrderingComposer,
          $$PremiumSettingsTableAnnotationComposer,
          $$PremiumSettingsTableCreateCompanionBuilder,
          $$PremiumSettingsTableUpdateCompanionBuilder,
          (
            PremiumSetting,
            BaseReferences<
              _$AppDatabase,
              $PremiumSettingsTable,
              PremiumSetting
            >,
          ),
          PremiumSetting,
          PrefetchHooks Function()
        > {
  $$PremiumSettingsTableTableManager(
    _$AppDatabase db,
    $PremiumSettingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PremiumSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PremiumSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PremiumSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<bool> isPremium = const Value.absent(),
              }) => PremiumSettingsCompanion(id: id, isPremium: isPremium),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<bool> isPremium = const Value.absent(),
              }) =>
                  PremiumSettingsCompanion.insert(id: id, isPremium: isPremium),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PremiumSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PremiumSettingsTable,
      PremiumSetting,
      $$PremiumSettingsTableFilterComposer,
      $$PremiumSettingsTableOrderingComposer,
      $$PremiumSettingsTableAnnotationComposer,
      $$PremiumSettingsTableCreateCompanionBuilder,
      $$PremiumSettingsTableUpdateCompanionBuilder,
      (
        PremiumSetting,
        BaseReferences<_$AppDatabase, $PremiumSettingsTable, PremiumSetting>,
      ),
      PremiumSetting,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$PracticeSessionsTableTableManager get practiceSessions =>
      $$PracticeSessionsTableTableManager(_db, _db.practiceSessions);
  $$DailyUnlocksTableTableManager get dailyUnlocks =>
      $$DailyUnlocksTableTableManager(_db, _db.dailyUnlocks);
  $$PremiumSettingsTableTableManager get premiumSettings =>
      $$PremiumSettingsTableTableManager(_db, _db.premiumSettings);
}
