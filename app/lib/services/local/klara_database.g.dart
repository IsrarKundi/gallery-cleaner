// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'klara_database.dart';

// ignore_for_file: type=lint
class $AssetInfosTable extends AssetInfos
    with TableInfo<$AssetInfosTable, AssetInfoRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AssetInfosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _assetIdMeta = const VerificationMeta(
    'assetId',
  );
  @override
  late final GeneratedColumn<String> assetId = GeneratedColumn<String>(
    'asset_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<int> width = GeneratedColumn<int>(
    'width',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<int> height = GeneratedColumn<int>(
    'height',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta(
    'sizeBytes',
  );
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'size_bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modifiedDateMsMeta = const VerificationMeta(
    'modifiedDateMs',
  );
  @override
  late final GeneratedColumn<int> modifiedDateMs = GeneratedColumn<int>(
    'modified_date_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isEditedMeta = const VerificationMeta(
    'isEdited',
  );
  @override
  late final GeneratedColumn<bool> isEdited = GeneratedColumn<bool>(
    'is_edited',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_edited" IN (0, 1))',
    ),
  );
  static const VerificationMeta _isScreenshotMeta = const VerificationMeta(
    'isScreenshot',
  );
  @override
  late final GeneratedColumn<bool> isScreenshot = GeneratedColumn<bool>(
    'is_screenshot',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_screenshot" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    assetId,
    type,
    width,
    height,
    sizeBytes,
    modifiedDateMs,
    isEdited,
    isScreenshot,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'asset_infos';
  @override
  VerificationContext validateIntegrity(
    Insertable<AssetInfoRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('asset_id')) {
      context.handle(
        _assetIdMeta,
        assetId.isAcceptableOrUnknown(data['asset_id']!, _assetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_assetIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    } else if (isInserting) {
      context.missing(_widthMeta);
    }
    if (data.containsKey('height')) {
      context.handle(
        _heightMeta,
        height.isAcceptableOrUnknown(data['height']!, _heightMeta),
      );
    } else if (isInserting) {
      context.missing(_heightMeta);
    }
    if (data.containsKey('size_bytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta),
      );
    }
    if (data.containsKey('modified_date_ms')) {
      context.handle(
        _modifiedDateMsMeta,
        modifiedDateMs.isAcceptableOrUnknown(
          data['modified_date_ms']!,
          _modifiedDateMsMeta,
        ),
      );
    }
    if (data.containsKey('is_edited')) {
      context.handle(
        _isEditedMeta,
        isEdited.isAcceptableOrUnknown(data['is_edited']!, _isEditedMeta),
      );
    } else if (isInserting) {
      context.missing(_isEditedMeta);
    }
    if (data.containsKey('is_screenshot')) {
      context.handle(
        _isScreenshotMeta,
        isScreenshot.isAcceptableOrUnknown(
          data['is_screenshot']!,
          _isScreenshotMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_isScreenshotMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {assetId};
  @override
  AssetInfoRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AssetInfoRow(
      assetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asset_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}width'],
      )!,
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}height'],
      )!,
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      ),
      modifiedDateMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}modified_date_ms'],
      ),
      isEdited: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_edited'],
      )!,
      isScreenshot: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_screenshot'],
      )!,
    );
  }

  @override
  $AssetInfosTable createAlias(String alias) {
    return $AssetInfosTable(attachedDatabase, alias);
  }
}

class AssetInfoRow extends DataClass implements Insertable<AssetInfoRow> {
  final String assetId;

  /// MediaAssetType.name ('image' / 'video').
  final String type;
  final int width;
  final int height;
  final int? sizeBytes;
  final int? modifiedDateMs;
  final bool isEdited;
  final bool isScreenshot;
  const AssetInfoRow({
    required this.assetId,
    required this.type,
    required this.width,
    required this.height,
    this.sizeBytes,
    this.modifiedDateMs,
    required this.isEdited,
    required this.isScreenshot,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['asset_id'] = Variable<String>(assetId);
    map['type'] = Variable<String>(type);
    map['width'] = Variable<int>(width);
    map['height'] = Variable<int>(height);
    if (!nullToAbsent || sizeBytes != null) {
      map['size_bytes'] = Variable<int>(sizeBytes);
    }
    if (!nullToAbsent || modifiedDateMs != null) {
      map['modified_date_ms'] = Variable<int>(modifiedDateMs);
    }
    map['is_edited'] = Variable<bool>(isEdited);
    map['is_screenshot'] = Variable<bool>(isScreenshot);
    return map;
  }

  AssetInfosCompanion toCompanion(bool nullToAbsent) {
    return AssetInfosCompanion(
      assetId: Value(assetId),
      type: Value(type),
      width: Value(width),
      height: Value(height),
      sizeBytes: sizeBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(sizeBytes),
      modifiedDateMs: modifiedDateMs == null && nullToAbsent
          ? const Value.absent()
          : Value(modifiedDateMs),
      isEdited: Value(isEdited),
      isScreenshot: Value(isScreenshot),
    );
  }

  factory AssetInfoRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AssetInfoRow(
      assetId: serializer.fromJson<String>(json['assetId']),
      type: serializer.fromJson<String>(json['type']),
      width: serializer.fromJson<int>(json['width']),
      height: serializer.fromJson<int>(json['height']),
      sizeBytes: serializer.fromJson<int?>(json['sizeBytes']),
      modifiedDateMs: serializer.fromJson<int?>(json['modifiedDateMs']),
      isEdited: serializer.fromJson<bool>(json['isEdited']),
      isScreenshot: serializer.fromJson<bool>(json['isScreenshot']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'assetId': serializer.toJson<String>(assetId),
      'type': serializer.toJson<String>(type),
      'width': serializer.toJson<int>(width),
      'height': serializer.toJson<int>(height),
      'sizeBytes': serializer.toJson<int?>(sizeBytes),
      'modifiedDateMs': serializer.toJson<int?>(modifiedDateMs),
      'isEdited': serializer.toJson<bool>(isEdited),
      'isScreenshot': serializer.toJson<bool>(isScreenshot),
    };
  }

  AssetInfoRow copyWith({
    String? assetId,
    String? type,
    int? width,
    int? height,
    Value<int?> sizeBytes = const Value.absent(),
    Value<int?> modifiedDateMs = const Value.absent(),
    bool? isEdited,
    bool? isScreenshot,
  }) => AssetInfoRow(
    assetId: assetId ?? this.assetId,
    type: type ?? this.type,
    width: width ?? this.width,
    height: height ?? this.height,
    sizeBytes: sizeBytes.present ? sizeBytes.value : this.sizeBytes,
    modifiedDateMs: modifiedDateMs.present
        ? modifiedDateMs.value
        : this.modifiedDateMs,
    isEdited: isEdited ?? this.isEdited,
    isScreenshot: isScreenshot ?? this.isScreenshot,
  );
  AssetInfoRow copyWithCompanion(AssetInfosCompanion data) {
    return AssetInfoRow(
      assetId: data.assetId.present ? data.assetId.value : this.assetId,
      type: data.type.present ? data.type.value : this.type,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      modifiedDateMs: data.modifiedDateMs.present
          ? data.modifiedDateMs.value
          : this.modifiedDateMs,
      isEdited: data.isEdited.present ? data.isEdited.value : this.isEdited,
      isScreenshot: data.isScreenshot.present
          ? data.isScreenshot.value
          : this.isScreenshot,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AssetInfoRow(')
          ..write('assetId: $assetId, ')
          ..write('type: $type, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('modifiedDateMs: $modifiedDateMs, ')
          ..write('isEdited: $isEdited, ')
          ..write('isScreenshot: $isScreenshot')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    assetId,
    type,
    width,
    height,
    sizeBytes,
    modifiedDateMs,
    isEdited,
    isScreenshot,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AssetInfoRow &&
          other.assetId == this.assetId &&
          other.type == this.type &&
          other.width == this.width &&
          other.height == this.height &&
          other.sizeBytes == this.sizeBytes &&
          other.modifiedDateMs == this.modifiedDateMs &&
          other.isEdited == this.isEdited &&
          other.isScreenshot == this.isScreenshot);
}

class AssetInfosCompanion extends UpdateCompanion<AssetInfoRow> {
  final Value<String> assetId;
  final Value<String> type;
  final Value<int> width;
  final Value<int> height;
  final Value<int?> sizeBytes;
  final Value<int?> modifiedDateMs;
  final Value<bool> isEdited;
  final Value<bool> isScreenshot;
  final Value<int> rowid;
  const AssetInfosCompanion({
    this.assetId = const Value.absent(),
    this.type = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.modifiedDateMs = const Value.absent(),
    this.isEdited = const Value.absent(),
    this.isScreenshot = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AssetInfosCompanion.insert({
    required String assetId,
    required String type,
    required int width,
    required int height,
    this.sizeBytes = const Value.absent(),
    this.modifiedDateMs = const Value.absent(),
    required bool isEdited,
    required bool isScreenshot,
    this.rowid = const Value.absent(),
  }) : assetId = Value(assetId),
       type = Value(type),
       width = Value(width),
       height = Value(height),
       isEdited = Value(isEdited),
       isScreenshot = Value(isScreenshot);
  static Insertable<AssetInfoRow> custom({
    Expression<String>? assetId,
    Expression<String>? type,
    Expression<int>? width,
    Expression<int>? height,
    Expression<int>? sizeBytes,
    Expression<int>? modifiedDateMs,
    Expression<bool>? isEdited,
    Expression<bool>? isScreenshot,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (assetId != null) 'asset_id': assetId,
      if (type != null) 'type': type,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (modifiedDateMs != null) 'modified_date_ms': modifiedDateMs,
      if (isEdited != null) 'is_edited': isEdited,
      if (isScreenshot != null) 'is_screenshot': isScreenshot,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AssetInfosCompanion copyWith({
    Value<String>? assetId,
    Value<String>? type,
    Value<int>? width,
    Value<int>? height,
    Value<int?>? sizeBytes,
    Value<int?>? modifiedDateMs,
    Value<bool>? isEdited,
    Value<bool>? isScreenshot,
    Value<int>? rowid,
  }) {
    return AssetInfosCompanion(
      assetId: assetId ?? this.assetId,
      type: type ?? this.type,
      width: width ?? this.width,
      height: height ?? this.height,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      modifiedDateMs: modifiedDateMs ?? this.modifiedDateMs,
      isEdited: isEdited ?? this.isEdited,
      isScreenshot: isScreenshot ?? this.isScreenshot,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (assetId.present) {
      map['asset_id'] = Variable<String>(assetId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (width.present) {
      map['width'] = Variable<int>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<int>(height.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (modifiedDateMs.present) {
      map['modified_date_ms'] = Variable<int>(modifiedDateMs.value);
    }
    if (isEdited.present) {
      map['is_edited'] = Variable<bool>(isEdited.value);
    }
    if (isScreenshot.present) {
      map['is_screenshot'] = Variable<bool>(isScreenshot.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AssetInfosCompanion(')
          ..write('assetId: $assetId, ')
          ..write('type: $type, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('modifiedDateMs: $modifiedDateMs, ')
          ..write('isEdited: $isEdited, ')
          ..write('isScreenshot: $isScreenshot, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ScanGroupsTable extends ScanGroups
    with TableInfo<$ScanGroupsTable, ScanGroupRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScanGroupsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seedIdMeta = const VerificationMeta('seedId');
  @override
  late final GeneratedColumn<String> seedId = GeneratedColumn<String>(
    'seed_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _keeperIdMeta = const VerificationMeta(
    'keeperId',
  );
  @override
  late final GeneratedColumn<String> keeperId = GeneratedColumn<String>(
    'keeper_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, kind, seedId, keeperId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scan_groups';
  @override
  VerificationContext validateIntegrity(
    Insertable<ScanGroupRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('seed_id')) {
      context.handle(
        _seedIdMeta,
        seedId.isAcceptableOrUnknown(data['seed_id']!, _seedIdMeta),
      );
    }
    if (data.containsKey('keeper_id')) {
      context.handle(
        _keeperIdMeta,
        keeperId.isAcceptableOrUnknown(data['keeper_id']!, _keeperIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ScanGroupRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScanGroupRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      seedId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}seed_id'],
      ),
      keeperId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}keeper_id'],
      ),
    );
  }

  @override
  $ScanGroupsTable createAlias(String alias) {
    return $ScanGroupsTable(attachedDatabase, alias);
  }
}

class ScanGroupRow extends DataClass implements Insertable<ScanGroupRow> {
  final int id;

  /// ScanGroupKind.name: 'similar' / 'duplicate' / 'blurry' /
  /// 'dark'.
  final String kind;
  final String? seedId;
  final String? keeperId;
  const ScanGroupRow({
    required this.id,
    required this.kind,
    this.seedId,
    this.keeperId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || seedId != null) {
      map['seed_id'] = Variable<String>(seedId);
    }
    if (!nullToAbsent || keeperId != null) {
      map['keeper_id'] = Variable<String>(keeperId);
    }
    return map;
  }

  ScanGroupsCompanion toCompanion(bool nullToAbsent) {
    return ScanGroupsCompanion(
      id: Value(id),
      kind: Value(kind),
      seedId: seedId == null && nullToAbsent
          ? const Value.absent()
          : Value(seedId),
      keeperId: keeperId == null && nullToAbsent
          ? const Value.absent()
          : Value(keeperId),
    );
  }

  factory ScanGroupRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScanGroupRow(
      id: serializer.fromJson<int>(json['id']),
      kind: serializer.fromJson<String>(json['kind']),
      seedId: serializer.fromJson<String?>(json['seedId']),
      keeperId: serializer.fromJson<String?>(json['keeperId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'kind': serializer.toJson<String>(kind),
      'seedId': serializer.toJson<String?>(seedId),
      'keeperId': serializer.toJson<String?>(keeperId),
    };
  }

  ScanGroupRow copyWith({
    int? id,
    String? kind,
    Value<String?> seedId = const Value.absent(),
    Value<String?> keeperId = const Value.absent(),
  }) => ScanGroupRow(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    seedId: seedId.present ? seedId.value : this.seedId,
    keeperId: keeperId.present ? keeperId.value : this.keeperId,
  );
  ScanGroupRow copyWithCompanion(ScanGroupsCompanion data) {
    return ScanGroupRow(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      seedId: data.seedId.present ? data.seedId.value : this.seedId,
      keeperId: data.keeperId.present ? data.keeperId.value : this.keeperId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScanGroupRow(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('seedId: $seedId, ')
          ..write('keeperId: $keeperId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, kind, seedId, keeperId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScanGroupRow &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.seedId == this.seedId &&
          other.keeperId == this.keeperId);
}

class ScanGroupsCompanion extends UpdateCompanion<ScanGroupRow> {
  final Value<int> id;
  final Value<String> kind;
  final Value<String?> seedId;
  final Value<String?> keeperId;
  const ScanGroupsCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.seedId = const Value.absent(),
    this.keeperId = const Value.absent(),
  });
  ScanGroupsCompanion.insert({
    this.id = const Value.absent(),
    required String kind,
    this.seedId = const Value.absent(),
    this.keeperId = const Value.absent(),
  }) : kind = Value(kind);
  static Insertable<ScanGroupRow> custom({
    Expression<int>? id,
    Expression<String>? kind,
    Expression<String>? seedId,
    Expression<String>? keeperId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (seedId != null) 'seed_id': seedId,
      if (keeperId != null) 'keeper_id': keeperId,
    });
  }

  ScanGroupsCompanion copyWith({
    Value<int>? id,
    Value<String>? kind,
    Value<String?>? seedId,
    Value<String?>? keeperId,
  }) {
    return ScanGroupsCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      seedId: seedId ?? this.seedId,
      keeperId: keeperId ?? this.keeperId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (seedId.present) {
      map['seed_id'] = Variable<String>(seedId.value);
    }
    if (keeperId.present) {
      map['keeper_id'] = Variable<String>(keeperId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScanGroupsCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('seedId: $seedId, ')
          ..write('keeperId: $keeperId')
          ..write(')'))
        .toString();
  }
}

class $ScanGroupMembersTable extends ScanGroupMembers
    with TableInfo<$ScanGroupMembersTable, ScanGroupMemberRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScanGroupMembersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _groupRowIdMeta = const VerificationMeta(
    'groupRowId',
  );
  @override
  late final GeneratedColumn<int> groupRowId = GeneratedColumn<int>(
    'group_row_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _assetIdMeta = const VerificationMeta(
    'assetId',
  );
  @override
  late final GeneratedColumn<String> assetId = GeneratedColumn<String>(
    'asset_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _memberIndexMeta = const VerificationMeta(
    'memberIndex',
  );
  @override
  late final GeneratedColumn<int> memberIndex = GeneratedColumn<int>(
    'member_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [groupRowId, assetId, memberIndex];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scan_group_members';
  @override
  VerificationContext validateIntegrity(
    Insertable<ScanGroupMemberRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('group_row_id')) {
      context.handle(
        _groupRowIdMeta,
        groupRowId.isAcceptableOrUnknown(
          data['group_row_id']!,
          _groupRowIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_groupRowIdMeta);
    }
    if (data.containsKey('asset_id')) {
      context.handle(
        _assetIdMeta,
        assetId.isAcceptableOrUnknown(data['asset_id']!, _assetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_assetIdMeta);
    }
    if (data.containsKey('member_index')) {
      context.handle(
        _memberIndexMeta,
        memberIndex.isAcceptableOrUnknown(
          data['member_index']!,
          _memberIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_memberIndexMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {groupRowId, assetId};
  @override
  ScanGroupMemberRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScanGroupMemberRow(
      groupRowId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}group_row_id'],
      )!,
      assetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asset_id'],
      )!,
      memberIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}member_index'],
      )!,
    );
  }

  @override
  $ScanGroupMembersTable createAlias(String alias) {
    return $ScanGroupMembersTable(attachedDatabase, alias);
  }
}

class ScanGroupMemberRow extends DataClass
    implements Insertable<ScanGroupMemberRow> {
  final int groupRowId;
  final String assetId;
  final int memberIndex;
  const ScanGroupMemberRow({
    required this.groupRowId,
    required this.assetId,
    required this.memberIndex,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['group_row_id'] = Variable<int>(groupRowId);
    map['asset_id'] = Variable<String>(assetId);
    map['member_index'] = Variable<int>(memberIndex);
    return map;
  }

  ScanGroupMembersCompanion toCompanion(bool nullToAbsent) {
    return ScanGroupMembersCompanion(
      groupRowId: Value(groupRowId),
      assetId: Value(assetId),
      memberIndex: Value(memberIndex),
    );
  }

  factory ScanGroupMemberRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScanGroupMemberRow(
      groupRowId: serializer.fromJson<int>(json['groupRowId']),
      assetId: serializer.fromJson<String>(json['assetId']),
      memberIndex: serializer.fromJson<int>(json['memberIndex']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'groupRowId': serializer.toJson<int>(groupRowId),
      'assetId': serializer.toJson<String>(assetId),
      'memberIndex': serializer.toJson<int>(memberIndex),
    };
  }

  ScanGroupMemberRow copyWith({
    int? groupRowId,
    String? assetId,
    int? memberIndex,
  }) => ScanGroupMemberRow(
    groupRowId: groupRowId ?? this.groupRowId,
    assetId: assetId ?? this.assetId,
    memberIndex: memberIndex ?? this.memberIndex,
  );
  ScanGroupMemberRow copyWithCompanion(ScanGroupMembersCompanion data) {
    return ScanGroupMemberRow(
      groupRowId: data.groupRowId.present
          ? data.groupRowId.value
          : this.groupRowId,
      assetId: data.assetId.present ? data.assetId.value : this.assetId,
      memberIndex: data.memberIndex.present
          ? data.memberIndex.value
          : this.memberIndex,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScanGroupMemberRow(')
          ..write('groupRowId: $groupRowId, ')
          ..write('assetId: $assetId, ')
          ..write('memberIndex: $memberIndex')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(groupRowId, assetId, memberIndex);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScanGroupMemberRow &&
          other.groupRowId == this.groupRowId &&
          other.assetId == this.assetId &&
          other.memberIndex == this.memberIndex);
}

class ScanGroupMembersCompanion extends UpdateCompanion<ScanGroupMemberRow> {
  final Value<int> groupRowId;
  final Value<String> assetId;
  final Value<int> memberIndex;
  final Value<int> rowid;
  const ScanGroupMembersCompanion({
    this.groupRowId = const Value.absent(),
    this.assetId = const Value.absent(),
    this.memberIndex = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ScanGroupMembersCompanion.insert({
    required int groupRowId,
    required String assetId,
    required int memberIndex,
    this.rowid = const Value.absent(),
  }) : groupRowId = Value(groupRowId),
       assetId = Value(assetId),
       memberIndex = Value(memberIndex);
  static Insertable<ScanGroupMemberRow> custom({
    Expression<int>? groupRowId,
    Expression<String>? assetId,
    Expression<int>? memberIndex,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (groupRowId != null) 'group_row_id': groupRowId,
      if (assetId != null) 'asset_id': assetId,
      if (memberIndex != null) 'member_index': memberIndex,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ScanGroupMembersCompanion copyWith({
    Value<int>? groupRowId,
    Value<String>? assetId,
    Value<int>? memberIndex,
    Value<int>? rowid,
  }) {
    return ScanGroupMembersCompanion(
      groupRowId: groupRowId ?? this.groupRowId,
      assetId: assetId ?? this.assetId,
      memberIndex: memberIndex ?? this.memberIndex,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (groupRowId.present) {
      map['group_row_id'] = Variable<int>(groupRowId.value);
    }
    if (assetId.present) {
      map['asset_id'] = Variable<String>(assetId.value);
    }
    if (memberIndex.present) {
      map['member_index'] = Variable<int>(memberIndex.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScanGroupMembersCompanion(')
          ..write('groupRowId: $groupRowId, ')
          ..write('assetId: $assetId, ')
          ..write('memberIndex: $memberIndex, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DuplicateReferencesTable extends DuplicateReferences
    with TableInfo<$DuplicateReferencesTable, DuplicateReferenceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DuplicateReferencesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _mainIdMeta = const VerificationMeta('mainId');
  @override
  late final GeneratedColumn<String> mainId = GeneratedColumn<String>(
    'main_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, mainId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'duplicate_references';
  @override
  VerificationContext validateIntegrity(
    Insertable<DuplicateReferenceRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('main_id')) {
      context.handle(
        _mainIdMeta,
        mainId.isAcceptableOrUnknown(data['main_id']!, _mainIdMeta),
      );
    } else if (isInserting) {
      context.missing(_mainIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DuplicateReferenceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DuplicateReferenceRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      mainId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}main_id'],
      )!,
    );
  }

  @override
  $DuplicateReferencesTable createAlias(String alias) {
    return $DuplicateReferencesTable(attachedDatabase, alias);
  }
}

class DuplicateReferenceRow extends DataClass
    implements Insertable<DuplicateReferenceRow> {
  final int id;
  final String mainId;
  const DuplicateReferenceRow({required this.id, required this.mainId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['main_id'] = Variable<String>(mainId);
    return map;
  }

  DuplicateReferencesCompanion toCompanion(bool nullToAbsent) {
    return DuplicateReferencesCompanion(id: Value(id), mainId: Value(mainId));
  }

  factory DuplicateReferenceRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DuplicateReferenceRow(
      id: serializer.fromJson<int>(json['id']),
      mainId: serializer.fromJson<String>(json['mainId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'mainId': serializer.toJson<String>(mainId),
    };
  }

  DuplicateReferenceRow copyWith({int? id, String? mainId}) =>
      DuplicateReferenceRow(id: id ?? this.id, mainId: mainId ?? this.mainId);
  DuplicateReferenceRow copyWithCompanion(DuplicateReferencesCompanion data) {
    return DuplicateReferenceRow(
      id: data.id.present ? data.id.value : this.id,
      mainId: data.mainId.present ? data.mainId.value : this.mainId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DuplicateReferenceRow(')
          ..write('id: $id, ')
          ..write('mainId: $mainId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, mainId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DuplicateReferenceRow &&
          other.id == this.id &&
          other.mainId == this.mainId);
}

class DuplicateReferencesCompanion
    extends UpdateCompanion<DuplicateReferenceRow> {
  final Value<int> id;
  final Value<String> mainId;
  const DuplicateReferencesCompanion({
    this.id = const Value.absent(),
    this.mainId = const Value.absent(),
  });
  DuplicateReferencesCompanion.insert({
    this.id = const Value.absent(),
    required String mainId,
  }) : mainId = Value(mainId);
  static Insertable<DuplicateReferenceRow> custom({
    Expression<int>? id,
    Expression<String>? mainId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (mainId != null) 'main_id': mainId,
    });
  }

  DuplicateReferencesCompanion copyWith({
    Value<int>? id,
    Value<String>? mainId,
  }) {
    return DuplicateReferencesCompanion(
      id: id ?? this.id,
      mainId: mainId ?? this.mainId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (mainId.present) {
      map['main_id'] = Variable<String>(mainId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DuplicateReferencesCompanion(')
          ..write('id: $id, ')
          ..write('mainId: $mainId')
          ..write(')'))
        .toString();
  }
}

class $DuplicateReferenceMembersTable extends DuplicateReferenceMembers
    with
        TableInfo<
          $DuplicateReferenceMembersTable,
          DuplicateReferenceMemberRow
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DuplicateReferenceMembersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _referenceRowIdMeta = const VerificationMeta(
    'referenceRowId',
  );
  @override
  late final GeneratedColumn<int> referenceRowId = GeneratedColumn<int>(
    'reference_row_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _assetIdMeta = const VerificationMeta(
    'assetId',
  );
  @override
  late final GeneratedColumn<String> assetId = GeneratedColumn<String>(
    'asset_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _memberIndexMeta = const VerificationMeta(
    'memberIndex',
  );
  @override
  late final GeneratedColumn<int> memberIndex = GeneratedColumn<int>(
    'member_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [referenceRowId, assetId, memberIndex];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'duplicate_reference_members';
  @override
  VerificationContext validateIntegrity(
    Insertable<DuplicateReferenceMemberRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('reference_row_id')) {
      context.handle(
        _referenceRowIdMeta,
        referenceRowId.isAcceptableOrUnknown(
          data['reference_row_id']!,
          _referenceRowIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_referenceRowIdMeta);
    }
    if (data.containsKey('asset_id')) {
      context.handle(
        _assetIdMeta,
        assetId.isAcceptableOrUnknown(data['asset_id']!, _assetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_assetIdMeta);
    }
    if (data.containsKey('member_index')) {
      context.handle(
        _memberIndexMeta,
        memberIndex.isAcceptableOrUnknown(
          data['member_index']!,
          _memberIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_memberIndexMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {referenceRowId, assetId};
  @override
  DuplicateReferenceMemberRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DuplicateReferenceMemberRow(
      referenceRowId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reference_row_id'],
      )!,
      assetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asset_id'],
      )!,
      memberIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}member_index'],
      )!,
    );
  }

  @override
  $DuplicateReferenceMembersTable createAlias(String alias) {
    return $DuplicateReferenceMembersTable(attachedDatabase, alias);
  }
}

class DuplicateReferenceMemberRow extends DataClass
    implements Insertable<DuplicateReferenceMemberRow> {
  final int referenceRowId;
  final String assetId;
  final int memberIndex;
  const DuplicateReferenceMemberRow({
    required this.referenceRowId,
    required this.assetId,
    required this.memberIndex,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['reference_row_id'] = Variable<int>(referenceRowId);
    map['asset_id'] = Variable<String>(assetId);
    map['member_index'] = Variable<int>(memberIndex);
    return map;
  }

  DuplicateReferenceMembersCompanion toCompanion(bool nullToAbsent) {
    return DuplicateReferenceMembersCompanion(
      referenceRowId: Value(referenceRowId),
      assetId: Value(assetId),
      memberIndex: Value(memberIndex),
    );
  }

  factory DuplicateReferenceMemberRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DuplicateReferenceMemberRow(
      referenceRowId: serializer.fromJson<int>(json['referenceRowId']),
      assetId: serializer.fromJson<String>(json['assetId']),
      memberIndex: serializer.fromJson<int>(json['memberIndex']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'referenceRowId': serializer.toJson<int>(referenceRowId),
      'assetId': serializer.toJson<String>(assetId),
      'memberIndex': serializer.toJson<int>(memberIndex),
    };
  }

  DuplicateReferenceMemberRow copyWith({
    int? referenceRowId,
    String? assetId,
    int? memberIndex,
  }) => DuplicateReferenceMemberRow(
    referenceRowId: referenceRowId ?? this.referenceRowId,
    assetId: assetId ?? this.assetId,
    memberIndex: memberIndex ?? this.memberIndex,
  );
  DuplicateReferenceMemberRow copyWithCompanion(
    DuplicateReferenceMembersCompanion data,
  ) {
    return DuplicateReferenceMemberRow(
      referenceRowId: data.referenceRowId.present
          ? data.referenceRowId.value
          : this.referenceRowId,
      assetId: data.assetId.present ? data.assetId.value : this.assetId,
      memberIndex: data.memberIndex.present
          ? data.memberIndex.value
          : this.memberIndex,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DuplicateReferenceMemberRow(')
          ..write('referenceRowId: $referenceRowId, ')
          ..write('assetId: $assetId, ')
          ..write('memberIndex: $memberIndex')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(referenceRowId, assetId, memberIndex);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DuplicateReferenceMemberRow &&
          other.referenceRowId == this.referenceRowId &&
          other.assetId == this.assetId &&
          other.memberIndex == this.memberIndex);
}

class DuplicateReferenceMembersCompanion
    extends UpdateCompanion<DuplicateReferenceMemberRow> {
  final Value<int> referenceRowId;
  final Value<String> assetId;
  final Value<int> memberIndex;
  final Value<int> rowid;
  const DuplicateReferenceMembersCompanion({
    this.referenceRowId = const Value.absent(),
    this.assetId = const Value.absent(),
    this.memberIndex = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DuplicateReferenceMembersCompanion.insert({
    required int referenceRowId,
    required String assetId,
    required int memberIndex,
    this.rowid = const Value.absent(),
  }) : referenceRowId = Value(referenceRowId),
       assetId = Value(assetId),
       memberIndex = Value(memberIndex);
  static Insertable<DuplicateReferenceMemberRow> custom({
    Expression<int>? referenceRowId,
    Expression<String>? assetId,
    Expression<int>? memberIndex,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (referenceRowId != null) 'reference_row_id': referenceRowId,
      if (assetId != null) 'asset_id': assetId,
      if (memberIndex != null) 'member_index': memberIndex,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DuplicateReferenceMembersCompanion copyWith({
    Value<int>? referenceRowId,
    Value<String>? assetId,
    Value<int>? memberIndex,
    Value<int>? rowid,
  }) {
    return DuplicateReferenceMembersCompanion(
      referenceRowId: referenceRowId ?? this.referenceRowId,
      assetId: assetId ?? this.assetId,
      memberIndex: memberIndex ?? this.memberIndex,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (referenceRowId.present) {
      map['reference_row_id'] = Variable<int>(referenceRowId.value);
    }
    if (assetId.present) {
      map['asset_id'] = Variable<String>(assetId.value);
    }
    if (memberIndex.present) {
      map['member_index'] = Variable<int>(memberIndex.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DuplicateReferenceMembersCompanion(')
          ..write('referenceRowId: $referenceRowId, ')
          ..write('assetId: $assetId, ')
          ..write('memberIndex: $memberIndex, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SessionsTable extends Sessions with TableInfo<$SessionsTable, Session> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _filterKeyMeta = const VerificationMeta(
    'filterKey',
  );
  @override
  late final GeneratedColumn<String> filterKey = GeneratedColumn<String>(
    'filter_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currentIndexMeta = const VerificationMeta(
    'currentIndex',
  );
  @override
  late final GeneratedColumn<int> currentIndex = GeneratedColumn<int>(
    'current_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [filterKey, currentIndex];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<Session> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('filter_key')) {
      context.handle(
        _filterKeyMeta,
        filterKey.isAcceptableOrUnknown(data['filter_key']!, _filterKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_filterKeyMeta);
    }
    if (data.containsKey('current_index')) {
      context.handle(
        _currentIndexMeta,
        currentIndex.isAcceptableOrUnknown(
          data['current_index']!,
          _currentIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_currentIndexMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {filterKey};
  @override
  Session map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Session(
      filterKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}filter_key'],
      )!,
      currentIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current_index'],
      )!,
    );
  }

  @override
  $SessionsTable createAlias(String alias) {
    return $SessionsTable(attachedDatabase, alias);
  }
}

class Session extends DataClass implements Insertable<Session> {
  final String filterKey;
  final int currentIndex;
  const Session({required this.filterKey, required this.currentIndex});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['filter_key'] = Variable<String>(filterKey);
    map['current_index'] = Variable<int>(currentIndex);
    return map;
  }

  SessionsCompanion toCompanion(bool nullToAbsent) {
    return SessionsCompanion(
      filterKey: Value(filterKey),
      currentIndex: Value(currentIndex),
    );
  }

  factory Session.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Session(
      filterKey: serializer.fromJson<String>(json['filterKey']),
      currentIndex: serializer.fromJson<int>(json['currentIndex']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'filterKey': serializer.toJson<String>(filterKey),
      'currentIndex': serializer.toJson<int>(currentIndex),
    };
  }

  Session copyWith({String? filterKey, int? currentIndex}) => Session(
    filterKey: filterKey ?? this.filterKey,
    currentIndex: currentIndex ?? this.currentIndex,
  );
  Session copyWithCompanion(SessionsCompanion data) {
    return Session(
      filterKey: data.filterKey.present ? data.filterKey.value : this.filterKey,
      currentIndex: data.currentIndex.present
          ? data.currentIndex.value
          : this.currentIndex,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Session(')
          ..write('filterKey: $filterKey, ')
          ..write('currentIndex: $currentIndex')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(filterKey, currentIndex);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Session &&
          other.filterKey == this.filterKey &&
          other.currentIndex == this.currentIndex);
}

class SessionsCompanion extends UpdateCompanion<Session> {
  final Value<String> filterKey;
  final Value<int> currentIndex;
  final Value<int> rowid;
  const SessionsCompanion({
    this.filterKey = const Value.absent(),
    this.currentIndex = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SessionsCompanion.insert({
    required String filterKey,
    required int currentIndex,
    this.rowid = const Value.absent(),
  }) : filterKey = Value(filterKey),
       currentIndex = Value(currentIndex);
  static Insertable<Session> custom({
    Expression<String>? filterKey,
    Expression<int>? currentIndex,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (filterKey != null) 'filter_key': filterKey,
      if (currentIndex != null) 'current_index': currentIndex,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionsCompanion copyWith({
    Value<String>? filterKey,
    Value<int>? currentIndex,
    Value<int>? rowid,
  }) {
    return SessionsCompanion(
      filterKey: filterKey ?? this.filterKey,
      currentIndex: currentIndex ?? this.currentIndex,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (filterKey.present) {
      map['filter_key'] = Variable<String>(filterKey.value);
    }
    if (currentIndex.present) {
      map['current_index'] = Variable<int>(currentIndex.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionsCompanion(')
          ..write('filterKey: $filterKey, ')
          ..write('currentIndex: $currentIndex, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MarksTable extends Marks with TableInfo<$MarksTable, Mark> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MarksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _filterKeyMeta = const VerificationMeta(
    'filterKey',
  );
  @override
  late final GeneratedColumn<String> filterKey = GeneratedColumn<String>(
    'filter_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _assetIdMeta = const VerificationMeta(
    'assetId',
  );
  @override
  late final GeneratedColumn<String> assetId = GeneratedColumn<String>(
    'asset_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _markMeta = const VerificationMeta('mark');
  @override
  late final GeneratedColumn<String> mark = GeneratedColumn<String>(
    'mark',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [filterKey, assetId, mark];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'marks';
  @override
  VerificationContext validateIntegrity(
    Insertable<Mark> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('filter_key')) {
      context.handle(
        _filterKeyMeta,
        filterKey.isAcceptableOrUnknown(data['filter_key']!, _filterKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_filterKeyMeta);
    }
    if (data.containsKey('asset_id')) {
      context.handle(
        _assetIdMeta,
        assetId.isAcceptableOrUnknown(data['asset_id']!, _assetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_assetIdMeta);
    }
    if (data.containsKey('mark')) {
      context.handle(
        _markMeta,
        mark.isAcceptableOrUnknown(data['mark']!, _markMeta),
      );
    } else if (isInserting) {
      context.missing(_markMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {filterKey, assetId};
  @override
  Mark map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Mark(
      filterKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}filter_key'],
      )!,
      assetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asset_id'],
      )!,
      mark: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mark'],
      )!,
    );
  }

  @override
  $MarksTable createAlias(String alias) {
    return $MarksTable(attachedDatabase, alias);
  }
}

class Mark extends DataClass implements Insertable<Mark> {
  final String filterKey;
  final String assetId;
  final String mark;
  const Mark({
    required this.filterKey,
    required this.assetId,
    required this.mark,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['filter_key'] = Variable<String>(filterKey);
    map['asset_id'] = Variable<String>(assetId);
    map['mark'] = Variable<String>(mark);
    return map;
  }

  MarksCompanion toCompanion(bool nullToAbsent) {
    return MarksCompanion(
      filterKey: Value(filterKey),
      assetId: Value(assetId),
      mark: Value(mark),
    );
  }

  factory Mark.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Mark(
      filterKey: serializer.fromJson<String>(json['filterKey']),
      assetId: serializer.fromJson<String>(json['assetId']),
      mark: serializer.fromJson<String>(json['mark']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'filterKey': serializer.toJson<String>(filterKey),
      'assetId': serializer.toJson<String>(assetId),
      'mark': serializer.toJson<String>(mark),
    };
  }

  Mark copyWith({String? filterKey, String? assetId, String? mark}) => Mark(
    filterKey: filterKey ?? this.filterKey,
    assetId: assetId ?? this.assetId,
    mark: mark ?? this.mark,
  );
  Mark copyWithCompanion(MarksCompanion data) {
    return Mark(
      filterKey: data.filterKey.present ? data.filterKey.value : this.filterKey,
      assetId: data.assetId.present ? data.assetId.value : this.assetId,
      mark: data.mark.present ? data.mark.value : this.mark,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Mark(')
          ..write('filterKey: $filterKey, ')
          ..write('assetId: $assetId, ')
          ..write('mark: $mark')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(filterKey, assetId, mark);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Mark &&
          other.filterKey == this.filterKey &&
          other.assetId == this.assetId &&
          other.mark == this.mark);
}

class MarksCompanion extends UpdateCompanion<Mark> {
  final Value<String> filterKey;
  final Value<String> assetId;
  final Value<String> mark;
  final Value<int> rowid;
  const MarksCompanion({
    this.filterKey = const Value.absent(),
    this.assetId = const Value.absent(),
    this.mark = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MarksCompanion.insert({
    required String filterKey,
    required String assetId,
    required String mark,
    this.rowid = const Value.absent(),
  }) : filterKey = Value(filterKey),
       assetId = Value(assetId),
       mark = Value(mark);
  static Insertable<Mark> custom({
    Expression<String>? filterKey,
    Expression<String>? assetId,
    Expression<String>? mark,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (filterKey != null) 'filter_key': filterKey,
      if (assetId != null) 'asset_id': assetId,
      if (mark != null) 'mark': mark,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MarksCompanion copyWith({
    Value<String>? filterKey,
    Value<String>? assetId,
    Value<String>? mark,
    Value<int>? rowid,
  }) {
    return MarksCompanion(
      filterKey: filterKey ?? this.filterKey,
      assetId: assetId ?? this.assetId,
      mark: mark ?? this.mark,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (filterKey.present) {
      map['filter_key'] = Variable<String>(filterKey.value);
    }
    if (assetId.present) {
      map['asset_id'] = Variable<String>(assetId.value);
    }
    if (mark.present) {
      map['mark'] = Variable<String>(mark.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MarksCompanion(')
          ..write('filterKey: $filterKey, ')
          ..write('assetId: $assetId, ')
          ..write('mark: $mark, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SessionFavouritesTable extends SessionFavourites
    with TableInfo<$SessionFavouritesTable, SessionFavourite> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionFavouritesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _filterKeyMeta = const VerificationMeta(
    'filterKey',
  );
  @override
  late final GeneratedColumn<String> filterKey = GeneratedColumn<String>(
    'filter_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _assetIdMeta = const VerificationMeta(
    'assetId',
  );
  @override
  late final GeneratedColumn<String> assetId = GeneratedColumn<String>(
    'asset_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [filterKey, assetId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'session_favourites';
  @override
  VerificationContext validateIntegrity(
    Insertable<SessionFavourite> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('filter_key')) {
      context.handle(
        _filterKeyMeta,
        filterKey.isAcceptableOrUnknown(data['filter_key']!, _filterKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_filterKeyMeta);
    }
    if (data.containsKey('asset_id')) {
      context.handle(
        _assetIdMeta,
        assetId.isAcceptableOrUnknown(data['asset_id']!, _assetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_assetIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {filterKey, assetId};
  @override
  SessionFavourite map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionFavourite(
      filterKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}filter_key'],
      )!,
      assetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asset_id'],
      )!,
    );
  }

  @override
  $SessionFavouritesTable createAlias(String alias) {
    return $SessionFavouritesTable(attachedDatabase, alias);
  }
}

class SessionFavourite extends DataClass
    implements Insertable<SessionFavourite> {
  final String filterKey;
  final String assetId;
  const SessionFavourite({required this.filterKey, required this.assetId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['filter_key'] = Variable<String>(filterKey);
    map['asset_id'] = Variable<String>(assetId);
    return map;
  }

  SessionFavouritesCompanion toCompanion(bool nullToAbsent) {
    return SessionFavouritesCompanion(
      filterKey: Value(filterKey),
      assetId: Value(assetId),
    );
  }

  factory SessionFavourite.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionFavourite(
      filterKey: serializer.fromJson<String>(json['filterKey']),
      assetId: serializer.fromJson<String>(json['assetId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'filterKey': serializer.toJson<String>(filterKey),
      'assetId': serializer.toJson<String>(assetId),
    };
  }

  SessionFavourite copyWith({String? filterKey, String? assetId}) =>
      SessionFavourite(
        filterKey: filterKey ?? this.filterKey,
        assetId: assetId ?? this.assetId,
      );
  SessionFavourite copyWithCompanion(SessionFavouritesCompanion data) {
    return SessionFavourite(
      filterKey: data.filterKey.present ? data.filterKey.value : this.filterKey,
      assetId: data.assetId.present ? data.assetId.value : this.assetId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionFavourite(')
          ..write('filterKey: $filterKey, ')
          ..write('assetId: $assetId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(filterKey, assetId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionFavourite &&
          other.filterKey == this.filterKey &&
          other.assetId == this.assetId);
}

class SessionFavouritesCompanion extends UpdateCompanion<SessionFavourite> {
  final Value<String> filterKey;
  final Value<String> assetId;
  final Value<int> rowid;
  const SessionFavouritesCompanion({
    this.filterKey = const Value.absent(),
    this.assetId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SessionFavouritesCompanion.insert({
    required String filterKey,
    required String assetId,
    this.rowid = const Value.absent(),
  }) : filterKey = Value(filterKey),
       assetId = Value(assetId);
  static Insertable<SessionFavourite> custom({
    Expression<String>? filterKey,
    Expression<String>? assetId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (filterKey != null) 'filter_key': filterKey,
      if (assetId != null) 'asset_id': assetId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionFavouritesCompanion copyWith({
    Value<String>? filterKey,
    Value<String>? assetId,
    Value<int>? rowid,
  }) {
    return SessionFavouritesCompanion(
      filterKey: filterKey ?? this.filterKey,
      assetId: assetId ?? this.assetId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (filterKey.present) {
      map['filter_key'] = Variable<String>(filterKey.value);
    }
    if (assetId.present) {
      map['asset_id'] = Variable<String>(assetId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionFavouritesCompanion(')
          ..write('filterKey: $filterKey, ')
          ..write('assetId: $assetId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TrashEntriesTable extends TrashEntries
    with TableInfo<$TrashEntriesTable, TrashEntryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TrashEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _assetIdMeta = const VerificationMeta(
    'assetId',
  );
  @override
  late final GeneratedColumn<String> assetId = GeneratedColumn<String>(
    'asset_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeIntMeta = const VerificationMeta(
    'typeInt',
  );
  @override
  late final GeneratedColumn<int> typeInt = GeneratedColumn<int>(
    'type_int',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<int> width = GeneratedColumn<int>(
    'width',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<int> height = GeneratedColumn<int>(
    'height',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta(
    'sizeBytes',
  );
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'size_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _trashedAtMsMeta = const VerificationMeta(
    'trashedAtMs',
  );
  @override
  late final GeneratedColumn<int> trashedAtMs = GeneratedColumn<int>(
    'trashed_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    assetId,
    typeInt,
    width,
    height,
    sizeBytes,
    trashedAtMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'trash_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<TrashEntryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('asset_id')) {
      context.handle(
        _assetIdMeta,
        assetId.isAcceptableOrUnknown(data['asset_id']!, _assetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_assetIdMeta);
    }
    if (data.containsKey('type_int')) {
      context.handle(
        _typeIntMeta,
        typeInt.isAcceptableOrUnknown(data['type_int']!, _typeIntMeta),
      );
    } else if (isInserting) {
      context.missing(_typeIntMeta);
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    } else if (isInserting) {
      context.missing(_widthMeta);
    }
    if (data.containsKey('height')) {
      context.handle(
        _heightMeta,
        height.isAcceptableOrUnknown(data['height']!, _heightMeta),
      );
    } else if (isInserting) {
      context.missing(_heightMeta);
    }
    if (data.containsKey('size_bytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta),
      );
    } else if (isInserting) {
      context.missing(_sizeBytesMeta);
    }
    if (data.containsKey('trashed_at_ms')) {
      context.handle(
        _trashedAtMsMeta,
        trashedAtMs.isAcceptableOrUnknown(
          data['trashed_at_ms']!,
          _trashedAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_trashedAtMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {assetId};
  @override
  TrashEntryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TrashEntryRow(
      assetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asset_id'],
      )!,
      typeInt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}type_int'],
      )!,
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}width'],
      )!,
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}height'],
      )!,
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      )!,
      trashedAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}trashed_at_ms'],
      )!,
    );
  }

  @override
  $TrashEntriesTable createAlias(String alias) {
    return $TrashEntriesTable(attachedDatabase, alias);
  }
}

class TrashEntryRow extends DataClass implements Insertable<TrashEntryRow> {
  final String assetId;
  final int typeInt;
  final int width;
  final int height;
  final int sizeBytes;
  final int trashedAtMs;
  const TrashEntryRow({
    required this.assetId,
    required this.typeInt,
    required this.width,
    required this.height,
    required this.sizeBytes,
    required this.trashedAtMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['asset_id'] = Variable<String>(assetId);
    map['type_int'] = Variable<int>(typeInt);
    map['width'] = Variable<int>(width);
    map['height'] = Variable<int>(height);
    map['size_bytes'] = Variable<int>(sizeBytes);
    map['trashed_at_ms'] = Variable<int>(trashedAtMs);
    return map;
  }

  TrashEntriesCompanion toCompanion(bool nullToAbsent) {
    return TrashEntriesCompanion(
      assetId: Value(assetId),
      typeInt: Value(typeInt),
      width: Value(width),
      height: Value(height),
      sizeBytes: Value(sizeBytes),
      trashedAtMs: Value(trashedAtMs),
    );
  }

  factory TrashEntryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TrashEntryRow(
      assetId: serializer.fromJson<String>(json['assetId']),
      typeInt: serializer.fromJson<int>(json['typeInt']),
      width: serializer.fromJson<int>(json['width']),
      height: serializer.fromJson<int>(json['height']),
      sizeBytes: serializer.fromJson<int>(json['sizeBytes']),
      trashedAtMs: serializer.fromJson<int>(json['trashedAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'assetId': serializer.toJson<String>(assetId),
      'typeInt': serializer.toJson<int>(typeInt),
      'width': serializer.toJson<int>(width),
      'height': serializer.toJson<int>(height),
      'sizeBytes': serializer.toJson<int>(sizeBytes),
      'trashedAtMs': serializer.toJson<int>(trashedAtMs),
    };
  }

  TrashEntryRow copyWith({
    String? assetId,
    int? typeInt,
    int? width,
    int? height,
    int? sizeBytes,
    int? trashedAtMs,
  }) => TrashEntryRow(
    assetId: assetId ?? this.assetId,
    typeInt: typeInt ?? this.typeInt,
    width: width ?? this.width,
    height: height ?? this.height,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    trashedAtMs: trashedAtMs ?? this.trashedAtMs,
  );
  TrashEntryRow copyWithCompanion(TrashEntriesCompanion data) {
    return TrashEntryRow(
      assetId: data.assetId.present ? data.assetId.value : this.assetId,
      typeInt: data.typeInt.present ? data.typeInt.value : this.typeInt,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      trashedAtMs: data.trashedAtMs.present
          ? data.trashedAtMs.value
          : this.trashedAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TrashEntryRow(')
          ..write('assetId: $assetId, ')
          ..write('typeInt: $typeInt, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('trashedAtMs: $trashedAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(assetId, typeInt, width, height, sizeBytes, trashedAtMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrashEntryRow &&
          other.assetId == this.assetId &&
          other.typeInt == this.typeInt &&
          other.width == this.width &&
          other.height == this.height &&
          other.sizeBytes == this.sizeBytes &&
          other.trashedAtMs == this.trashedAtMs);
}

class TrashEntriesCompanion extends UpdateCompanion<TrashEntryRow> {
  final Value<String> assetId;
  final Value<int> typeInt;
  final Value<int> width;
  final Value<int> height;
  final Value<int> sizeBytes;
  final Value<int> trashedAtMs;
  final Value<int> rowid;
  const TrashEntriesCompanion({
    this.assetId = const Value.absent(),
    this.typeInt = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.trashedAtMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TrashEntriesCompanion.insert({
    required String assetId,
    required int typeInt,
    required int width,
    required int height,
    required int sizeBytes,
    required int trashedAtMs,
    this.rowid = const Value.absent(),
  }) : assetId = Value(assetId),
       typeInt = Value(typeInt),
       width = Value(width),
       height = Value(height),
       sizeBytes = Value(sizeBytes),
       trashedAtMs = Value(trashedAtMs);
  static Insertable<TrashEntryRow> custom({
    Expression<String>? assetId,
    Expression<int>? typeInt,
    Expression<int>? width,
    Expression<int>? height,
    Expression<int>? sizeBytes,
    Expression<int>? trashedAtMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (assetId != null) 'asset_id': assetId,
      if (typeInt != null) 'type_int': typeInt,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (trashedAtMs != null) 'trashed_at_ms': trashedAtMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TrashEntriesCompanion copyWith({
    Value<String>? assetId,
    Value<int>? typeInt,
    Value<int>? width,
    Value<int>? height,
    Value<int>? sizeBytes,
    Value<int>? trashedAtMs,
    Value<int>? rowid,
  }) {
    return TrashEntriesCompanion(
      assetId: assetId ?? this.assetId,
      typeInt: typeInt ?? this.typeInt,
      width: width ?? this.width,
      height: height ?? this.height,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      trashedAtMs: trashedAtMs ?? this.trashedAtMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (assetId.present) {
      map['asset_id'] = Variable<String>(assetId.value);
    }
    if (typeInt.present) {
      map['type_int'] = Variable<int>(typeInt.value);
    }
    if (width.present) {
      map['width'] = Variable<int>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<int>(height.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (trashedAtMs.present) {
      map['trashed_at_ms'] = Variable<int>(trashedAtMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TrashEntriesCompanion(')
          ..write('assetId: $assetId, ')
          ..write('typeInt: $typeInt, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('trashedAtMs: $trashedAtMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HistoryRecordsTable extends HistoryRecords
    with TableInfo<$HistoryRecordsTable, HistoryRecordRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HistoryRecordsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _dateMsMeta = const VerificationMeta('dateMs');
  @override
  late final GeneratedColumn<int> dateMs = GeneratedColumn<int>(
    'date_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _countMeta = const VerificationMeta('count');
  @override
  late final GeneratedColumn<int> count = GeneratedColumn<int>(
    'count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mbTrashedMeta = const VerificationMeta(
    'mbTrashed',
  );
  @override
  late final GeneratedColumn<double> mbTrashed = GeneratedColumn<double>(
    'mb_trashed',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mbFreedMeta = const VerificationMeta(
    'mbFreed',
  );
  @override
  late final GeneratedColumn<double> mbFreed = GeneratedColumn<double>(
    'mb_freed',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, dateMs, count, mbTrashed, mbFreed];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'history_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<HistoryRecordRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('date_ms')) {
      context.handle(
        _dateMsMeta,
        dateMs.isAcceptableOrUnknown(data['date_ms']!, _dateMsMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMsMeta);
    }
    if (data.containsKey('count')) {
      context.handle(
        _countMeta,
        count.isAcceptableOrUnknown(data['count']!, _countMeta),
      );
    } else if (isInserting) {
      context.missing(_countMeta);
    }
    if (data.containsKey('mb_trashed')) {
      context.handle(
        _mbTrashedMeta,
        mbTrashed.isAcceptableOrUnknown(data['mb_trashed']!, _mbTrashedMeta),
      );
    } else if (isInserting) {
      context.missing(_mbTrashedMeta);
    }
    if (data.containsKey('mb_freed')) {
      context.handle(
        _mbFreedMeta,
        mbFreed.isAcceptableOrUnknown(data['mb_freed']!, _mbFreedMeta),
      );
    } else if (isInserting) {
      context.missing(_mbFreedMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HistoryRecordRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HistoryRecordRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      dateMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}date_ms'],
      )!,
      count: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}count'],
      )!,
      mbTrashed: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}mb_trashed'],
      )!,
      mbFreed: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}mb_freed'],
      )!,
    );
  }

  @override
  $HistoryRecordsTable createAlias(String alias) {
    return $HistoryRecordsTable(attachedDatabase, alias);
  }
}

class HistoryRecordRow extends DataClass
    implements Insertable<HistoryRecordRow> {
  final int id;
  final int dateMs;
  final int count;
  final double mbTrashed;
  final double mbFreed;
  const HistoryRecordRow({
    required this.id,
    required this.dateMs,
    required this.count,
    required this.mbTrashed,
    required this.mbFreed,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['date_ms'] = Variable<int>(dateMs);
    map['count'] = Variable<int>(count);
    map['mb_trashed'] = Variable<double>(mbTrashed);
    map['mb_freed'] = Variable<double>(mbFreed);
    return map;
  }

  HistoryRecordsCompanion toCompanion(bool nullToAbsent) {
    return HistoryRecordsCompanion(
      id: Value(id),
      dateMs: Value(dateMs),
      count: Value(count),
      mbTrashed: Value(mbTrashed),
      mbFreed: Value(mbFreed),
    );
  }

  factory HistoryRecordRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HistoryRecordRow(
      id: serializer.fromJson<int>(json['id']),
      dateMs: serializer.fromJson<int>(json['dateMs']),
      count: serializer.fromJson<int>(json['count']),
      mbTrashed: serializer.fromJson<double>(json['mbTrashed']),
      mbFreed: serializer.fromJson<double>(json['mbFreed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'dateMs': serializer.toJson<int>(dateMs),
      'count': serializer.toJson<int>(count),
      'mbTrashed': serializer.toJson<double>(mbTrashed),
      'mbFreed': serializer.toJson<double>(mbFreed),
    };
  }

  HistoryRecordRow copyWith({
    int? id,
    int? dateMs,
    int? count,
    double? mbTrashed,
    double? mbFreed,
  }) => HistoryRecordRow(
    id: id ?? this.id,
    dateMs: dateMs ?? this.dateMs,
    count: count ?? this.count,
    mbTrashed: mbTrashed ?? this.mbTrashed,
    mbFreed: mbFreed ?? this.mbFreed,
  );
  HistoryRecordRow copyWithCompanion(HistoryRecordsCompanion data) {
    return HistoryRecordRow(
      id: data.id.present ? data.id.value : this.id,
      dateMs: data.dateMs.present ? data.dateMs.value : this.dateMs,
      count: data.count.present ? data.count.value : this.count,
      mbTrashed: data.mbTrashed.present ? data.mbTrashed.value : this.mbTrashed,
      mbFreed: data.mbFreed.present ? data.mbFreed.value : this.mbFreed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HistoryRecordRow(')
          ..write('id: $id, ')
          ..write('dateMs: $dateMs, ')
          ..write('count: $count, ')
          ..write('mbTrashed: $mbTrashed, ')
          ..write('mbFreed: $mbFreed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, dateMs, count, mbTrashed, mbFreed);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HistoryRecordRow &&
          other.id == this.id &&
          other.dateMs == this.dateMs &&
          other.count == this.count &&
          other.mbTrashed == this.mbTrashed &&
          other.mbFreed == this.mbFreed);
}

class HistoryRecordsCompanion extends UpdateCompanion<HistoryRecordRow> {
  final Value<int> id;
  final Value<int> dateMs;
  final Value<int> count;
  final Value<double> mbTrashed;
  final Value<double> mbFreed;
  const HistoryRecordsCompanion({
    this.id = const Value.absent(),
    this.dateMs = const Value.absent(),
    this.count = const Value.absent(),
    this.mbTrashed = const Value.absent(),
    this.mbFreed = const Value.absent(),
  });
  HistoryRecordsCompanion.insert({
    this.id = const Value.absent(),
    required int dateMs,
    required int count,
    required double mbTrashed,
    required double mbFreed,
  }) : dateMs = Value(dateMs),
       count = Value(count),
       mbTrashed = Value(mbTrashed),
       mbFreed = Value(mbFreed);
  static Insertable<HistoryRecordRow> custom({
    Expression<int>? id,
    Expression<int>? dateMs,
    Expression<int>? count,
    Expression<double>? mbTrashed,
    Expression<double>? mbFreed,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (dateMs != null) 'date_ms': dateMs,
      if (count != null) 'count': count,
      if (mbTrashed != null) 'mb_trashed': mbTrashed,
      if (mbFreed != null) 'mb_freed': mbFreed,
    });
  }

  HistoryRecordsCompanion copyWith({
    Value<int>? id,
    Value<int>? dateMs,
    Value<int>? count,
    Value<double>? mbTrashed,
    Value<double>? mbFreed,
  }) {
    return HistoryRecordsCompanion(
      id: id ?? this.id,
      dateMs: dateMs ?? this.dateMs,
      count: count ?? this.count,
      mbTrashed: mbTrashed ?? this.mbTrashed,
      mbFreed: mbFreed ?? this.mbFreed,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (dateMs.present) {
      map['date_ms'] = Variable<int>(dateMs.value);
    }
    if (count.present) {
      map['count'] = Variable<int>(count.value);
    }
    if (mbTrashed.present) {
      map['mb_trashed'] = Variable<double>(mbTrashed.value);
    }
    if (mbFreed.present) {
      map['mb_freed'] = Variable<double>(mbFreed.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HistoryRecordsCompanion(')
          ..write('id: $id, ')
          ..write('dateMs: $dateMs, ')
          ..write('count: $count, ')
          ..write('mbTrashed: $mbTrashed, ')
          ..write('mbFreed: $mbFreed')
          ..write(')'))
        .toString();
  }
}

class $SnoozesTable extends Snoozes with TableInfo<$SnoozesTable, Snooze> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SnoozesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _assetIdMeta = const VerificationMeta(
    'assetId',
  );
  @override
  late final GeneratedColumn<String> assetId = GeneratedColumn<String>(
    'asset_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _untilMsMeta = const VerificationMeta(
    'untilMs',
  );
  @override
  late final GeneratedColumn<int> untilMs = GeneratedColumn<int>(
    'until_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [assetId, untilMs];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'snoozes';
  @override
  VerificationContext validateIntegrity(
    Insertable<Snooze> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('asset_id')) {
      context.handle(
        _assetIdMeta,
        assetId.isAcceptableOrUnknown(data['asset_id']!, _assetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_assetIdMeta);
    }
    if (data.containsKey('until_ms')) {
      context.handle(
        _untilMsMeta,
        untilMs.isAcceptableOrUnknown(data['until_ms']!, _untilMsMeta),
      );
    } else if (isInserting) {
      context.missing(_untilMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {assetId};
  @override
  Snooze map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Snooze(
      assetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asset_id'],
      )!,
      untilMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}until_ms'],
      )!,
    );
  }

  @override
  $SnoozesTable createAlias(String alias) {
    return $SnoozesTable(attachedDatabase, alias);
  }
}

class Snooze extends DataClass implements Insertable<Snooze> {
  final String assetId;
  final int untilMs;
  const Snooze({required this.assetId, required this.untilMs});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['asset_id'] = Variable<String>(assetId);
    map['until_ms'] = Variable<int>(untilMs);
    return map;
  }

  SnoozesCompanion toCompanion(bool nullToAbsent) {
    return SnoozesCompanion(assetId: Value(assetId), untilMs: Value(untilMs));
  }

  factory Snooze.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Snooze(
      assetId: serializer.fromJson<String>(json['assetId']),
      untilMs: serializer.fromJson<int>(json['untilMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'assetId': serializer.toJson<String>(assetId),
      'untilMs': serializer.toJson<int>(untilMs),
    };
  }

  Snooze copyWith({String? assetId, int? untilMs}) => Snooze(
    assetId: assetId ?? this.assetId,
    untilMs: untilMs ?? this.untilMs,
  );
  Snooze copyWithCompanion(SnoozesCompanion data) {
    return Snooze(
      assetId: data.assetId.present ? data.assetId.value : this.assetId,
      untilMs: data.untilMs.present ? data.untilMs.value : this.untilMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Snooze(')
          ..write('assetId: $assetId, ')
          ..write('untilMs: $untilMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(assetId, untilMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Snooze &&
          other.assetId == this.assetId &&
          other.untilMs == this.untilMs);
}

class SnoozesCompanion extends UpdateCompanion<Snooze> {
  final Value<String> assetId;
  final Value<int> untilMs;
  final Value<int> rowid;
  const SnoozesCompanion({
    this.assetId = const Value.absent(),
    this.untilMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SnoozesCompanion.insert({
    required String assetId,
    required int untilMs,
    this.rowid = const Value.absent(),
  }) : assetId = Value(assetId),
       untilMs = Value(untilMs);
  static Insertable<Snooze> custom({
    Expression<String>? assetId,
    Expression<int>? untilMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (assetId != null) 'asset_id': assetId,
      if (untilMs != null) 'until_ms': untilMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SnoozesCompanion copyWith({
    Value<String>? assetId,
    Value<int>? untilMs,
    Value<int>? rowid,
  }) {
    return SnoozesCompanion(
      assetId: assetId ?? this.assetId,
      untilMs: untilMs ?? this.untilMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (assetId.present) {
      map['asset_id'] = Variable<String>(assetId.value);
    }
    if (untilMs.present) {
      map['until_ms'] = Variable<int>(untilMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SnoozesCompanion(')
          ..write('assetId: $assetId, ')
          ..write('untilMs: $untilMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CompletionsTable extends Completions
    with TableInfo<$CompletionsTable, Completion> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CompletionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dayMsMeta = const VerificationMeta('dayMs');
  @override
  late final GeneratedColumn<int> dayMs = GeneratedColumn<int>(
    'day_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [dayMs];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'completions';
  @override
  VerificationContext validateIntegrity(
    Insertable<Completion> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('day_ms')) {
      context.handle(
        _dayMsMeta,
        dayMs.isAcceptableOrUnknown(data['day_ms']!, _dayMsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {dayMs};
  @override
  Completion map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Completion(
      dayMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}day_ms'],
      )!,
    );
  }

  @override
  $CompletionsTable createAlias(String alias) {
    return $CompletionsTable(attachedDatabase, alias);
  }
}

class Completion extends DataClass implements Insertable<Completion> {
  final int dayMs;
  const Completion({required this.dayMs});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['day_ms'] = Variable<int>(dayMs);
    return map;
  }

  CompletionsCompanion toCompanion(bool nullToAbsent) {
    return CompletionsCompanion(dayMs: Value(dayMs));
  }

  factory Completion.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Completion(dayMs: serializer.fromJson<int>(json['dayMs']));
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{'dayMs': serializer.toJson<int>(dayMs)};
  }

  Completion copyWith({int? dayMs}) => Completion(dayMs: dayMs ?? this.dayMs);
  Completion copyWithCompanion(CompletionsCompanion data) {
    return Completion(
      dayMs: data.dayMs.present ? data.dayMs.value : this.dayMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Completion(')
          ..write('dayMs: $dayMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => dayMs.hashCode;
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Completion && other.dayMs == this.dayMs);
}

class CompletionsCompanion extends UpdateCompanion<Completion> {
  final Value<int> dayMs;
  const CompletionsCompanion({this.dayMs = const Value.absent()});
  CompletionsCompanion.insert({this.dayMs = const Value.absent()});
  static Insertable<Completion> custom({Expression<int>? dayMs}) {
    return RawValuesInsertable({if (dayMs != null) 'day_ms': dayMs});
  }

  CompletionsCompanion copyWith({Value<int>? dayMs}) {
    return CompletionsCompanion(dayMs: dayMs ?? this.dayMs);
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (dayMs.present) {
      map['day_ms'] = Variable<int>(dayMs.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CompletionsCompanion(')
          ..write('dayMs: $dayMs')
          ..write(')'))
        .toString();
  }
}

class $MetaEntriesTable extends MetaEntries
    with TableInfo<$MetaEntriesTable, MetaEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MetaEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meta_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<MetaEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  MetaEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MetaEntry(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $MetaEntriesTable createAlias(String alias) {
    return $MetaEntriesTable(attachedDatabase, alias);
  }
}

class MetaEntry extends DataClass implements Insertable<MetaEntry> {
  final String key;
  final String value;
  const MetaEntry({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  MetaEntriesCompanion toCompanion(bool nullToAbsent) {
    return MetaEntriesCompanion(key: Value(key), value: Value(value));
  }

  factory MetaEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MetaEntry(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  MetaEntry copyWith({String? key, String? value}) =>
      MetaEntry(key: key ?? this.key, value: value ?? this.value);
  MetaEntry copyWithCompanion(MetaEntriesCompanion data) {
    return MetaEntry(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MetaEntry(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MetaEntry &&
          other.key == this.key &&
          other.value == this.value);
}

class MetaEntriesCompanion extends UpdateCompanion<MetaEntry> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const MetaEntriesCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MetaEntriesCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<MetaEntry> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MetaEntriesCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return MetaEntriesCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MetaEntriesCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$KlaraDatabase extends GeneratedDatabase {
  _$KlaraDatabase(QueryExecutor e) : super(e);
  $KlaraDatabaseManager get managers => $KlaraDatabaseManager(this);
  late final $AssetInfosTable assetInfos = $AssetInfosTable(this);
  late final $ScanGroupsTable scanGroups = $ScanGroupsTable(this);
  late final $ScanGroupMembersTable scanGroupMembers = $ScanGroupMembersTable(
    this,
  );
  late final $DuplicateReferencesTable duplicateReferences =
      $DuplicateReferencesTable(this);
  late final $DuplicateReferenceMembersTable duplicateReferenceMembers =
      $DuplicateReferenceMembersTable(this);
  late final $SessionsTable sessions = $SessionsTable(this);
  late final $MarksTable marks = $MarksTable(this);
  late final $SessionFavouritesTable sessionFavourites =
      $SessionFavouritesTable(this);
  late final $TrashEntriesTable trashEntries = $TrashEntriesTable(this);
  late final $HistoryRecordsTable historyRecords = $HistoryRecordsTable(this);
  late final $SnoozesTable snoozes = $SnoozesTable(this);
  late final $CompletionsTable completions = $CompletionsTable(this);
  late final $MetaEntriesTable metaEntries = $MetaEntriesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    assetInfos,
    scanGroups,
    scanGroupMembers,
    duplicateReferences,
    duplicateReferenceMembers,
    sessions,
    marks,
    sessionFavourites,
    trashEntries,
    historyRecords,
    snoozes,
    completions,
    metaEntries,
  ];
}

typedef $$AssetInfosTableCreateCompanionBuilder = AssetInfosCompanion Function({
  required String assetId,
  required String type,
  required int width,
  required int height,
  Value<int?> sizeBytes,
  Value<int?> modifiedDateMs,
  required bool isEdited,
  required bool isScreenshot,
  Value<int> rowid,
});
typedef $$AssetInfosTableUpdateCompanionBuilder = AssetInfosCompanion Function({
  Value<String> assetId,
  Value<String> type,
  Value<int> width,
  Value<int> height,
  Value<int?> sizeBytes,
  Value<int?> modifiedDateMs,
  Value<bool> isEdited,
  Value<bool> isScreenshot,
  Value<int> rowid,
});

class $$AssetInfosTableFilterComposer
    extends Composer<_$KlaraDatabase, $AssetInfosTable> {
  $$AssetInfosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get assetId => $composableBuilder(
    column: $table.assetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get modifiedDateMs => $composableBuilder(
    column: $table.modifiedDateMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isEdited => $composableBuilder(
    column: $table.isEdited,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isScreenshot => $composableBuilder(
    column: $table.isScreenshot,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AssetInfosTableOrderingComposer
    extends Composer<_$KlaraDatabase, $AssetInfosTable> {
  $$AssetInfosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get assetId => $composableBuilder(
    column: $table.assetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get modifiedDateMs => $composableBuilder(
    column: $table.modifiedDateMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isEdited => $composableBuilder(
    column: $table.isEdited,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isScreenshot => $composableBuilder(
    column: $table.isScreenshot,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AssetInfosTableAnnotationComposer
    extends Composer<_$KlaraDatabase, $AssetInfosTable> {
  $$AssetInfosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get assetId =>
      $composableBuilder(column: $table.assetId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<int> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<int> get modifiedDateMs => $composableBuilder(
    column: $table.modifiedDateMs,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isEdited =>
      $composableBuilder(column: $table.isEdited, builder: (column) => column);

  GeneratedColumn<bool> get isScreenshot => $composableBuilder(
    column: $table.isScreenshot,
    builder: (column) => column,
  );
}

class $$AssetInfosTableTableManager
    extends
        RootTableManager<
          _$KlaraDatabase,
          $AssetInfosTable,
          AssetInfoRow,
          $$AssetInfosTableFilterComposer,
          $$AssetInfosTableOrderingComposer,
          $$AssetInfosTableAnnotationComposer,
          $$AssetInfosTableCreateCompanionBuilder,
          $$AssetInfosTableUpdateCompanionBuilder,
          (
            AssetInfoRow,
            BaseReferences<_$KlaraDatabase, $AssetInfosTable, AssetInfoRow>,
          ),
          AssetInfoRow,
          PrefetchHooks Function()
        > {
  $$AssetInfosTableTableManager(_$KlaraDatabase db, $AssetInfosTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AssetInfosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AssetInfosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AssetInfosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> assetId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<int> width = const Value.absent(),
                Value<int> height = const Value.absent(),
                Value<int?> sizeBytes = const Value.absent(),
                Value<int?> modifiedDateMs = const Value.absent(),
                Value<bool> isEdited = const Value.absent(),
                Value<bool> isScreenshot = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AssetInfosCompanion(
                assetId: assetId,
                type: type,
                width: width,
                height: height,
                sizeBytes: sizeBytes,
                modifiedDateMs: modifiedDateMs,
                isEdited: isEdited,
                isScreenshot: isScreenshot,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String assetId,
                required String type,
                required int width,
                required int height,
                Value<int?> sizeBytes = const Value.absent(),
                Value<int?> modifiedDateMs = const Value.absent(),
                required bool isEdited,
                required bool isScreenshot,
                Value<int> rowid = const Value.absent(),
              }) => AssetInfosCompanion.insert(
                assetId: assetId,
                type: type,
                width: width,
                height: height,
                sizeBytes: sizeBytes,
                modifiedDateMs: modifiedDateMs,
                isEdited: isEdited,
                isScreenshot: isScreenshot,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AssetInfosTable, AssetInfoRow>(table),
                  BaseReferences<
                    _$KlaraDatabase,
                    $AssetInfosTable,
                    AssetInfoRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AssetInfosTableProcessedTableManager =
    ProcessedTableManager<
      _$KlaraDatabase,
      $AssetInfosTable,
      AssetInfoRow,
      $$AssetInfosTableFilterComposer,
      $$AssetInfosTableOrderingComposer,
      $$AssetInfosTableAnnotationComposer,
      $$AssetInfosTableCreateCompanionBuilder,
      $$AssetInfosTableUpdateCompanionBuilder,
      (
        AssetInfoRow,
        BaseReferences<_$KlaraDatabase, $AssetInfosTable, AssetInfoRow>,
      ),
      AssetInfoRow,
      PrefetchHooks Function()
    >;
typedef $$ScanGroupsTableCreateCompanionBuilder = ScanGroupsCompanion Function({
  Value<int> id,
  required String kind,
  Value<String?> seedId,
  Value<String?> keeperId,
});
typedef $$ScanGroupsTableUpdateCompanionBuilder = ScanGroupsCompanion Function({
  Value<int> id,
  Value<String> kind,
  Value<String?> seedId,
  Value<String?> keeperId,
});

class $$ScanGroupsTableFilterComposer
    extends Composer<_$KlaraDatabase, $ScanGroupsTable> {
  $$ScanGroupsTableFilterComposer({
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

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get seedId => $composableBuilder(
    column: $table.seedId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get keeperId => $composableBuilder(
    column: $table.keeperId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ScanGroupsTableOrderingComposer
    extends Composer<_$KlaraDatabase, $ScanGroupsTable> {
  $$ScanGroupsTableOrderingComposer({
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

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get seedId => $composableBuilder(
    column: $table.seedId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get keeperId => $composableBuilder(
    column: $table.keeperId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ScanGroupsTableAnnotationComposer
    extends Composer<_$KlaraDatabase, $ScanGroupsTable> {
  $$ScanGroupsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get seedId =>
      $composableBuilder(column: $table.seedId, builder: (column) => column);

  GeneratedColumn<String> get keeperId =>
      $composableBuilder(column: $table.keeperId, builder: (column) => column);
}

class $$ScanGroupsTableTableManager
    extends
        RootTableManager<
          _$KlaraDatabase,
          $ScanGroupsTable,
          ScanGroupRow,
          $$ScanGroupsTableFilterComposer,
          $$ScanGroupsTableOrderingComposer,
          $$ScanGroupsTableAnnotationComposer,
          $$ScanGroupsTableCreateCompanionBuilder,
          $$ScanGroupsTableUpdateCompanionBuilder,
          (
            ScanGroupRow,
            BaseReferences<_$KlaraDatabase, $ScanGroupsTable, ScanGroupRow>,
          ),
          ScanGroupRow,
          PrefetchHooks Function()
        > {
  $$ScanGroupsTableTableManager(_$KlaraDatabase db, $ScanGroupsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScanGroupsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ScanGroupsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ScanGroupsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String?> seedId = const Value.absent(),
                Value<String?> keeperId = const Value.absent(),
              }) => ScanGroupsCompanion(
                id: id,
                kind: kind,
                seedId: seedId,
                keeperId: keeperId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String kind,
                Value<String?> seedId = const Value.absent(),
                Value<String?> keeperId = const Value.absent(),
              }) => ScanGroupsCompanion.insert(
                id: id,
                kind: kind,
                seedId: seedId,
                keeperId: keeperId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ScanGroupsTable, ScanGroupRow>(table),
                  BaseReferences<
                    _$KlaraDatabase,
                    $ScanGroupsTable,
                    ScanGroupRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ScanGroupsTableProcessedTableManager =
    ProcessedTableManager<
      _$KlaraDatabase,
      $ScanGroupsTable,
      ScanGroupRow,
      $$ScanGroupsTableFilterComposer,
      $$ScanGroupsTableOrderingComposer,
      $$ScanGroupsTableAnnotationComposer,
      $$ScanGroupsTableCreateCompanionBuilder,
      $$ScanGroupsTableUpdateCompanionBuilder,
      (
        ScanGroupRow,
        BaseReferences<_$KlaraDatabase, $ScanGroupsTable, ScanGroupRow>,
      ),
      ScanGroupRow,
      PrefetchHooks Function()
    >;
typedef $$ScanGroupMembersTableCreateCompanionBuilder =
    ScanGroupMembersCompanion Function({
      required int groupRowId,
      required String assetId,
      required int memberIndex,
      Value<int> rowid,
    });
typedef $$ScanGroupMembersTableUpdateCompanionBuilder =
    ScanGroupMembersCompanion Function({
      Value<int> groupRowId,
      Value<String> assetId,
      Value<int> memberIndex,
      Value<int> rowid,
    });

class $$ScanGroupMembersTableFilterComposer
    extends Composer<_$KlaraDatabase, $ScanGroupMembersTable> {
  $$ScanGroupMembersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get groupRowId => $composableBuilder(
    column: $table.groupRowId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get assetId => $composableBuilder(
    column: $table.assetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get memberIndex => $composableBuilder(
    column: $table.memberIndex,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ScanGroupMembersTableOrderingComposer
    extends Composer<_$KlaraDatabase, $ScanGroupMembersTable> {
  $$ScanGroupMembersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get groupRowId => $composableBuilder(
    column: $table.groupRowId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get assetId => $composableBuilder(
    column: $table.assetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get memberIndex => $composableBuilder(
    column: $table.memberIndex,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ScanGroupMembersTableAnnotationComposer
    extends Composer<_$KlaraDatabase, $ScanGroupMembersTable> {
  $$ScanGroupMembersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get groupRowId => $composableBuilder(
    column: $table.groupRowId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get assetId =>
      $composableBuilder(column: $table.assetId, builder: (column) => column);

  GeneratedColumn<int> get memberIndex => $composableBuilder(
    column: $table.memberIndex,
    builder: (column) => column,
  );
}

class $$ScanGroupMembersTableTableManager
    extends
        RootTableManager<
          _$KlaraDatabase,
          $ScanGroupMembersTable,
          ScanGroupMemberRow,
          $$ScanGroupMembersTableFilterComposer,
          $$ScanGroupMembersTableOrderingComposer,
          $$ScanGroupMembersTableAnnotationComposer,
          $$ScanGroupMembersTableCreateCompanionBuilder,
          $$ScanGroupMembersTableUpdateCompanionBuilder,
          (
            ScanGroupMemberRow,
            BaseReferences<
              _$KlaraDatabase,
              $ScanGroupMembersTable,
              ScanGroupMemberRow
            >,
          ),
          ScanGroupMemberRow,
          PrefetchHooks Function()
        > {
  $$ScanGroupMembersTableTableManager(
    _$KlaraDatabase db,
    $ScanGroupMembersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScanGroupMembersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ScanGroupMembersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ScanGroupMembersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> groupRowId = const Value.absent(),
                Value<String> assetId = const Value.absent(),
                Value<int> memberIndex = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ScanGroupMembersCompanion(
                groupRowId: groupRowId,
                assetId: assetId,
                memberIndex: memberIndex,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int groupRowId,
                required String assetId,
                required int memberIndex,
                Value<int> rowid = const Value.absent(),
              }) => ScanGroupMembersCompanion.insert(
                groupRowId: groupRowId,
                assetId: assetId,
                memberIndex: memberIndex,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ScanGroupMembersTable, ScanGroupMemberRow>(
                    table,
                  ),
                  BaseReferences<
                    _$KlaraDatabase,
                    $ScanGroupMembersTable,
                    ScanGroupMemberRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ScanGroupMembersTableProcessedTableManager =
    ProcessedTableManager<
      _$KlaraDatabase,
      $ScanGroupMembersTable,
      ScanGroupMemberRow,
      $$ScanGroupMembersTableFilterComposer,
      $$ScanGroupMembersTableOrderingComposer,
      $$ScanGroupMembersTableAnnotationComposer,
      $$ScanGroupMembersTableCreateCompanionBuilder,
      $$ScanGroupMembersTableUpdateCompanionBuilder,
      (
        ScanGroupMemberRow,
        BaseReferences<
          _$KlaraDatabase,
          $ScanGroupMembersTable,
          ScanGroupMemberRow
        >,
      ),
      ScanGroupMemberRow,
      PrefetchHooks Function()
    >;
typedef $$DuplicateReferencesTableCreateCompanionBuilder =
    DuplicateReferencesCompanion Function({
      Value<int> id,
      required String mainId,
    });
typedef $$DuplicateReferencesTableUpdateCompanionBuilder =
    DuplicateReferencesCompanion Function({
      Value<int> id,
      Value<String> mainId,
    });

class $$DuplicateReferencesTableFilterComposer
    extends Composer<_$KlaraDatabase, $DuplicateReferencesTable> {
  $$DuplicateReferencesTableFilterComposer({
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

  ColumnFilters<String> get mainId => $composableBuilder(
    column: $table.mainId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DuplicateReferencesTableOrderingComposer
    extends Composer<_$KlaraDatabase, $DuplicateReferencesTable> {
  $$DuplicateReferencesTableOrderingComposer({
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

  ColumnOrderings<String> get mainId => $composableBuilder(
    column: $table.mainId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DuplicateReferencesTableAnnotationComposer
    extends Composer<_$KlaraDatabase, $DuplicateReferencesTable> {
  $$DuplicateReferencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get mainId =>
      $composableBuilder(column: $table.mainId, builder: (column) => column);
}

class $$DuplicateReferencesTableTableManager
    extends
        RootTableManager<
          _$KlaraDatabase,
          $DuplicateReferencesTable,
          DuplicateReferenceRow,
          $$DuplicateReferencesTableFilterComposer,
          $$DuplicateReferencesTableOrderingComposer,
          $$DuplicateReferencesTableAnnotationComposer,
          $$DuplicateReferencesTableCreateCompanionBuilder,
          $$DuplicateReferencesTableUpdateCompanionBuilder,
          (
            DuplicateReferenceRow,
            BaseReferences<
              _$KlaraDatabase,
              $DuplicateReferencesTable,
              DuplicateReferenceRow
            >,
          ),
          DuplicateReferenceRow,
          PrefetchHooks Function()
        > {
  $$DuplicateReferencesTableTableManager(
    _$KlaraDatabase db,
    $DuplicateReferencesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DuplicateReferencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DuplicateReferencesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$DuplicateReferencesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> mainId = const Value.absent(),
          }) => DuplicateReferencesCompanion(id: id, mainId: mainId),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String mainId,
          }) => DuplicateReferencesCompanion.insert(id: id, mainId: mainId),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DuplicateReferencesTable, DuplicateReferenceRow>(
                    table,
                  ),
                  BaseReferences<
                    _$KlaraDatabase,
                    $DuplicateReferencesTable,
                    DuplicateReferenceRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DuplicateReferencesTableProcessedTableManager =
    ProcessedTableManager<
      _$KlaraDatabase,
      $DuplicateReferencesTable,
      DuplicateReferenceRow,
      $$DuplicateReferencesTableFilterComposer,
      $$DuplicateReferencesTableOrderingComposer,
      $$DuplicateReferencesTableAnnotationComposer,
      $$DuplicateReferencesTableCreateCompanionBuilder,
      $$DuplicateReferencesTableUpdateCompanionBuilder,
      (
        DuplicateReferenceRow,
        BaseReferences<
          _$KlaraDatabase,
          $DuplicateReferencesTable,
          DuplicateReferenceRow
        >,
      ),
      DuplicateReferenceRow,
      PrefetchHooks Function()
    >;
typedef $$DuplicateReferenceMembersTableCreateCompanionBuilder =
    DuplicateReferenceMembersCompanion Function({
      required int referenceRowId,
      required String assetId,
      required int memberIndex,
      Value<int> rowid,
    });
typedef $$DuplicateReferenceMembersTableUpdateCompanionBuilder =
    DuplicateReferenceMembersCompanion Function({
      Value<int> referenceRowId,
      Value<String> assetId,
      Value<int> memberIndex,
      Value<int> rowid,
    });

class $$DuplicateReferenceMembersTableFilterComposer
    extends Composer<_$KlaraDatabase, $DuplicateReferenceMembersTable> {
  $$DuplicateReferenceMembersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get referenceRowId => $composableBuilder(
    column: $table.referenceRowId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get assetId => $composableBuilder(
    column: $table.assetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get memberIndex => $composableBuilder(
    column: $table.memberIndex,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DuplicateReferenceMembersTableOrderingComposer
    extends Composer<_$KlaraDatabase, $DuplicateReferenceMembersTable> {
  $$DuplicateReferenceMembersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get referenceRowId => $composableBuilder(
    column: $table.referenceRowId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get assetId => $composableBuilder(
    column: $table.assetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get memberIndex => $composableBuilder(
    column: $table.memberIndex,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DuplicateReferenceMembersTableAnnotationComposer
    extends Composer<_$KlaraDatabase, $DuplicateReferenceMembersTable> {
  $$DuplicateReferenceMembersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get referenceRowId => $composableBuilder(
    column: $table.referenceRowId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get assetId =>
      $composableBuilder(column: $table.assetId, builder: (column) => column);

  GeneratedColumn<int> get memberIndex => $composableBuilder(
    column: $table.memberIndex,
    builder: (column) => column,
  );
}

class $$DuplicateReferenceMembersTableTableManager
    extends
        RootTableManager<
          _$KlaraDatabase,
          $DuplicateReferenceMembersTable,
          DuplicateReferenceMemberRow,
          $$DuplicateReferenceMembersTableFilterComposer,
          $$DuplicateReferenceMembersTableOrderingComposer,
          $$DuplicateReferenceMembersTableAnnotationComposer,
          $$DuplicateReferenceMembersTableCreateCompanionBuilder,
          $$DuplicateReferenceMembersTableUpdateCompanionBuilder,
          (
            DuplicateReferenceMemberRow,
            BaseReferences<
              _$KlaraDatabase,
              $DuplicateReferenceMembersTable,
              DuplicateReferenceMemberRow
            >,
          ),
          DuplicateReferenceMemberRow,
          PrefetchHooks Function()
        > {
  $$DuplicateReferenceMembersTableTableManager(
    _$KlaraDatabase db,
    $DuplicateReferenceMembersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DuplicateReferenceMembersTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$DuplicateReferenceMembersTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$DuplicateReferenceMembersTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> referenceRowId = const Value.absent(),
                Value<String> assetId = const Value.absent(),
                Value<int> memberIndex = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DuplicateReferenceMembersCompanion(
                referenceRowId: referenceRowId,
                assetId: assetId,
                memberIndex: memberIndex,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int referenceRowId,
                required String assetId,
                required int memberIndex,
                Value<int> rowid = const Value.absent(),
              }) => DuplicateReferenceMembersCompanion.insert(
                referenceRowId: referenceRowId,
                assetId: assetId,
                memberIndex: memberIndex,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $DuplicateReferenceMembersTable,
                    DuplicateReferenceMemberRow
                  >(table),
                  BaseReferences<
                    _$KlaraDatabase,
                    $DuplicateReferenceMembersTable,
                    DuplicateReferenceMemberRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DuplicateReferenceMembersTableProcessedTableManager =
    ProcessedTableManager<
      _$KlaraDatabase,
      $DuplicateReferenceMembersTable,
      DuplicateReferenceMemberRow,
      $$DuplicateReferenceMembersTableFilterComposer,
      $$DuplicateReferenceMembersTableOrderingComposer,
      $$DuplicateReferenceMembersTableAnnotationComposer,
      $$DuplicateReferenceMembersTableCreateCompanionBuilder,
      $$DuplicateReferenceMembersTableUpdateCompanionBuilder,
      (
        DuplicateReferenceMemberRow,
        BaseReferences<
          _$KlaraDatabase,
          $DuplicateReferenceMembersTable,
          DuplicateReferenceMemberRow
        >,
      ),
      DuplicateReferenceMemberRow,
      PrefetchHooks Function()
    >;
typedef $$SessionsTableCreateCompanionBuilder = SessionsCompanion Function({
  required String filterKey,
  required int currentIndex,
  Value<int> rowid,
});
typedef $$SessionsTableUpdateCompanionBuilder = SessionsCompanion Function({
  Value<String> filterKey,
  Value<int> currentIndex,
  Value<int> rowid,
});

class $$SessionsTableFilterComposer
    extends Composer<_$KlaraDatabase, $SessionsTable> {
  $$SessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get filterKey => $composableBuilder(
    column: $table.filterKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get currentIndex => $composableBuilder(
    column: $table.currentIndex,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SessionsTableOrderingComposer
    extends Composer<_$KlaraDatabase, $SessionsTable> {
  $$SessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get filterKey => $composableBuilder(
    column: $table.filterKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currentIndex => $composableBuilder(
    column: $table.currentIndex,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SessionsTableAnnotationComposer
    extends Composer<_$KlaraDatabase, $SessionsTable> {
  $$SessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get filterKey =>
      $composableBuilder(column: $table.filterKey, builder: (column) => column);

  GeneratedColumn<int> get currentIndex => $composableBuilder(
    column: $table.currentIndex,
    builder: (column) => column,
  );
}

class $$SessionsTableTableManager
    extends
        RootTableManager<
          _$KlaraDatabase,
          $SessionsTable,
          Session,
          $$SessionsTableFilterComposer,
          $$SessionsTableOrderingComposer,
          $$SessionsTableAnnotationComposer,
          $$SessionsTableCreateCompanionBuilder,
          $$SessionsTableUpdateCompanionBuilder,
          (Session, BaseReferences<_$KlaraDatabase, $SessionsTable, Session>),
          Session,
          PrefetchHooks Function()
        > {
  $$SessionsTableTableManager(_$KlaraDatabase db, $SessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> filterKey = const Value.absent(),
                Value<int> currentIndex = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionsCompanion(
                filterKey: filterKey,
                currentIndex: currentIndex,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String filterKey,
                required int currentIndex,
                Value<int> rowid = const Value.absent(),
              }) => SessionsCompanion.insert(
                filterKey: filterKey,
                currentIndex: currentIndex,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SessionsTable, Session>(table),
                  BaseReferences<_$KlaraDatabase, $SessionsTable, Session>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$KlaraDatabase,
      $SessionsTable,
      Session,
      $$SessionsTableFilterComposer,
      $$SessionsTableOrderingComposer,
      $$SessionsTableAnnotationComposer,
      $$SessionsTableCreateCompanionBuilder,
      $$SessionsTableUpdateCompanionBuilder,
      (Session, BaseReferences<_$KlaraDatabase, $SessionsTable, Session>),
      Session,
      PrefetchHooks Function()
    >;
typedef $$MarksTableCreateCompanionBuilder = MarksCompanion Function({
  required String filterKey,
  required String assetId,
  required String mark,
  Value<int> rowid,
});
typedef $$MarksTableUpdateCompanionBuilder = MarksCompanion Function({
  Value<String> filterKey,
  Value<String> assetId,
  Value<String> mark,
  Value<int> rowid,
});

class $$MarksTableFilterComposer
    extends Composer<_$KlaraDatabase, $MarksTable> {
  $$MarksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get filterKey => $composableBuilder(
    column: $table.filterKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get assetId => $composableBuilder(
    column: $table.assetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mark => $composableBuilder(
    column: $table.mark,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MarksTableOrderingComposer
    extends Composer<_$KlaraDatabase, $MarksTable> {
  $$MarksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get filterKey => $composableBuilder(
    column: $table.filterKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get assetId => $composableBuilder(
    column: $table.assetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mark => $composableBuilder(
    column: $table.mark,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MarksTableAnnotationComposer
    extends Composer<_$KlaraDatabase, $MarksTable> {
  $$MarksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get filterKey =>
      $composableBuilder(column: $table.filterKey, builder: (column) => column);

  GeneratedColumn<String> get assetId =>
      $composableBuilder(column: $table.assetId, builder: (column) => column);

  GeneratedColumn<String> get mark =>
      $composableBuilder(column: $table.mark, builder: (column) => column);
}

class $$MarksTableTableManager
    extends
        RootTableManager<
          _$KlaraDatabase,
          $MarksTable,
          Mark,
          $$MarksTableFilterComposer,
          $$MarksTableOrderingComposer,
          $$MarksTableAnnotationComposer,
          $$MarksTableCreateCompanionBuilder,
          $$MarksTableUpdateCompanionBuilder,
          (Mark, BaseReferences<_$KlaraDatabase, $MarksTable, Mark>),
          Mark,
          PrefetchHooks Function()
        > {
  $$MarksTableTableManager(_$KlaraDatabase db, $MarksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MarksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MarksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MarksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> filterKey = const Value.absent(),
                Value<String> assetId = const Value.absent(),
                Value<String> mark = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MarksCompanion(
                filterKey: filterKey,
                assetId: assetId,
                mark: mark,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String filterKey,
                required String assetId,
                required String mark,
                Value<int> rowid = const Value.absent(),
              }) => MarksCompanion.insert(
                filterKey: filterKey,
                assetId: assetId,
                mark: mark,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MarksTable, Mark>(table),
                  BaseReferences<_$KlaraDatabase, $MarksTable, Mark>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MarksTableProcessedTableManager =
    ProcessedTableManager<
      _$KlaraDatabase,
      $MarksTable,
      Mark,
      $$MarksTableFilterComposer,
      $$MarksTableOrderingComposer,
      $$MarksTableAnnotationComposer,
      $$MarksTableCreateCompanionBuilder,
      $$MarksTableUpdateCompanionBuilder,
      (Mark, BaseReferences<_$KlaraDatabase, $MarksTable, Mark>),
      Mark,
      PrefetchHooks Function()
    >;
typedef $$SessionFavouritesTableCreateCompanionBuilder =
    SessionFavouritesCompanion Function({
      required String filterKey,
      required String assetId,
      Value<int> rowid,
    });
typedef $$SessionFavouritesTableUpdateCompanionBuilder =
    SessionFavouritesCompanion Function({
      Value<String> filterKey,
      Value<String> assetId,
      Value<int> rowid,
    });

class $$SessionFavouritesTableFilterComposer
    extends Composer<_$KlaraDatabase, $SessionFavouritesTable> {
  $$SessionFavouritesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get filterKey => $composableBuilder(
    column: $table.filterKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get assetId => $composableBuilder(
    column: $table.assetId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SessionFavouritesTableOrderingComposer
    extends Composer<_$KlaraDatabase, $SessionFavouritesTable> {
  $$SessionFavouritesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get filterKey => $composableBuilder(
    column: $table.filterKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get assetId => $composableBuilder(
    column: $table.assetId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SessionFavouritesTableAnnotationComposer
    extends Composer<_$KlaraDatabase, $SessionFavouritesTable> {
  $$SessionFavouritesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get filterKey =>
      $composableBuilder(column: $table.filterKey, builder: (column) => column);

  GeneratedColumn<String> get assetId =>
      $composableBuilder(column: $table.assetId, builder: (column) => column);
}

class $$SessionFavouritesTableTableManager
    extends
        RootTableManager<
          _$KlaraDatabase,
          $SessionFavouritesTable,
          SessionFavourite,
          $$SessionFavouritesTableFilterComposer,
          $$SessionFavouritesTableOrderingComposer,
          $$SessionFavouritesTableAnnotationComposer,
          $$SessionFavouritesTableCreateCompanionBuilder,
          $$SessionFavouritesTableUpdateCompanionBuilder,
          (
            SessionFavourite,
            BaseReferences<
              _$KlaraDatabase,
              $SessionFavouritesTable,
              SessionFavourite
            >,
          ),
          SessionFavourite,
          PrefetchHooks Function()
        > {
  $$SessionFavouritesTableTableManager(
    _$KlaraDatabase db,
    $SessionFavouritesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionFavouritesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionFavouritesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionFavouritesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> filterKey = const Value.absent(),
                Value<String> assetId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionFavouritesCompanion(
                filterKey: filterKey,
                assetId: assetId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String filterKey,
                required String assetId,
                Value<int> rowid = const Value.absent(),
              }) => SessionFavouritesCompanion.insert(
                filterKey: filterKey,
                assetId: assetId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SessionFavouritesTable, SessionFavourite>(table),
                  BaseReferences<
                    _$KlaraDatabase,
                    $SessionFavouritesTable,
                    SessionFavourite
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SessionFavouritesTableProcessedTableManager =
    ProcessedTableManager<
      _$KlaraDatabase,
      $SessionFavouritesTable,
      SessionFavourite,
      $$SessionFavouritesTableFilterComposer,
      $$SessionFavouritesTableOrderingComposer,
      $$SessionFavouritesTableAnnotationComposer,
      $$SessionFavouritesTableCreateCompanionBuilder,
      $$SessionFavouritesTableUpdateCompanionBuilder,
      (
        SessionFavourite,
        BaseReferences<
          _$KlaraDatabase,
          $SessionFavouritesTable,
          SessionFavourite
        >,
      ),
      SessionFavourite,
      PrefetchHooks Function()
    >;
typedef $$TrashEntriesTableCreateCompanionBuilder =
    TrashEntriesCompanion Function({
      required String assetId,
      required int typeInt,
      required int width,
      required int height,
      required int sizeBytes,
      required int trashedAtMs,
      Value<int> rowid,
    });
typedef $$TrashEntriesTableUpdateCompanionBuilder =
    TrashEntriesCompanion Function({
      Value<String> assetId,
      Value<int> typeInt,
      Value<int> width,
      Value<int> height,
      Value<int> sizeBytes,
      Value<int> trashedAtMs,
      Value<int> rowid,
    });

class $$TrashEntriesTableFilterComposer
    extends Composer<_$KlaraDatabase, $TrashEntriesTable> {
  $$TrashEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get assetId => $composableBuilder(
    column: $table.assetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get typeInt => $composableBuilder(
    column: $table.typeInt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get trashedAtMs => $composableBuilder(
    column: $table.trashedAtMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TrashEntriesTableOrderingComposer
    extends Composer<_$KlaraDatabase, $TrashEntriesTable> {
  $$TrashEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get assetId => $composableBuilder(
    column: $table.assetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get typeInt => $composableBuilder(
    column: $table.typeInt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get trashedAtMs => $composableBuilder(
    column: $table.trashedAtMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TrashEntriesTableAnnotationComposer
    extends Composer<_$KlaraDatabase, $TrashEntriesTable> {
  $$TrashEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get assetId =>
      $composableBuilder(column: $table.assetId, builder: (column) => column);

  GeneratedColumn<int> get typeInt =>
      $composableBuilder(column: $table.typeInt, builder: (column) => column);

  GeneratedColumn<int> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<int> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<int> get trashedAtMs => $composableBuilder(
    column: $table.trashedAtMs,
    builder: (column) => column,
  );
}

class $$TrashEntriesTableTableManager
    extends
        RootTableManager<
          _$KlaraDatabase,
          $TrashEntriesTable,
          TrashEntryRow,
          $$TrashEntriesTableFilterComposer,
          $$TrashEntriesTableOrderingComposer,
          $$TrashEntriesTableAnnotationComposer,
          $$TrashEntriesTableCreateCompanionBuilder,
          $$TrashEntriesTableUpdateCompanionBuilder,
          (
            TrashEntryRow,
            BaseReferences<_$KlaraDatabase, $TrashEntriesTable, TrashEntryRow>,
          ),
          TrashEntryRow,
          PrefetchHooks Function()
        > {
  $$TrashEntriesTableTableManager(_$KlaraDatabase db, $TrashEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TrashEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TrashEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TrashEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> assetId = const Value.absent(),
                Value<int> typeInt = const Value.absent(),
                Value<int> width = const Value.absent(),
                Value<int> height = const Value.absent(),
                Value<int> sizeBytes = const Value.absent(),
                Value<int> trashedAtMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TrashEntriesCompanion(
                assetId: assetId,
                typeInt: typeInt,
                width: width,
                height: height,
                sizeBytes: sizeBytes,
                trashedAtMs: trashedAtMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String assetId,
                required int typeInt,
                required int width,
                required int height,
                required int sizeBytes,
                required int trashedAtMs,
                Value<int> rowid = const Value.absent(),
              }) => TrashEntriesCompanion.insert(
                assetId: assetId,
                typeInt: typeInt,
                width: width,
                height: height,
                sizeBytes: sizeBytes,
                trashedAtMs: trashedAtMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TrashEntriesTable, TrashEntryRow>(table),
                  BaseReferences<
                    _$KlaraDatabase,
                    $TrashEntriesTable,
                    TrashEntryRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TrashEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$KlaraDatabase,
      $TrashEntriesTable,
      TrashEntryRow,
      $$TrashEntriesTableFilterComposer,
      $$TrashEntriesTableOrderingComposer,
      $$TrashEntriesTableAnnotationComposer,
      $$TrashEntriesTableCreateCompanionBuilder,
      $$TrashEntriesTableUpdateCompanionBuilder,
      (
        TrashEntryRow,
        BaseReferences<_$KlaraDatabase, $TrashEntriesTable, TrashEntryRow>,
      ),
      TrashEntryRow,
      PrefetchHooks Function()
    >;
typedef $$HistoryRecordsTableCreateCompanionBuilder =
    HistoryRecordsCompanion Function({
      Value<int> id,
      required int dateMs,
      required int count,
      required double mbTrashed,
      required double mbFreed,
    });
typedef $$HistoryRecordsTableUpdateCompanionBuilder =
    HistoryRecordsCompanion Function({
      Value<int> id,
      Value<int> dateMs,
      Value<int> count,
      Value<double> mbTrashed,
      Value<double> mbFreed,
    });

class $$HistoryRecordsTableFilterComposer
    extends Composer<_$KlaraDatabase, $HistoryRecordsTable> {
  $$HistoryRecordsTableFilterComposer({
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

  ColumnFilters<int> get dateMs => $composableBuilder(
    column: $table.dateMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get count => $composableBuilder(
    column: $table.count,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get mbTrashed => $composableBuilder(
    column: $table.mbTrashed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get mbFreed => $composableBuilder(
    column: $table.mbFreed,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HistoryRecordsTableOrderingComposer
    extends Composer<_$KlaraDatabase, $HistoryRecordsTable> {
  $$HistoryRecordsTableOrderingComposer({
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

  ColumnOrderings<int> get dateMs => $composableBuilder(
    column: $table.dateMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get count => $composableBuilder(
    column: $table.count,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get mbTrashed => $composableBuilder(
    column: $table.mbTrashed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get mbFreed => $composableBuilder(
    column: $table.mbFreed,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HistoryRecordsTableAnnotationComposer
    extends Composer<_$KlaraDatabase, $HistoryRecordsTable> {
  $$HistoryRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get dateMs =>
      $composableBuilder(column: $table.dateMs, builder: (column) => column);

  GeneratedColumn<int> get count =>
      $composableBuilder(column: $table.count, builder: (column) => column);

  GeneratedColumn<double> get mbTrashed =>
      $composableBuilder(column: $table.mbTrashed, builder: (column) => column);

  GeneratedColumn<double> get mbFreed =>
      $composableBuilder(column: $table.mbFreed, builder: (column) => column);
}

class $$HistoryRecordsTableTableManager
    extends
        RootTableManager<
          _$KlaraDatabase,
          $HistoryRecordsTable,
          HistoryRecordRow,
          $$HistoryRecordsTableFilterComposer,
          $$HistoryRecordsTableOrderingComposer,
          $$HistoryRecordsTableAnnotationComposer,
          $$HistoryRecordsTableCreateCompanionBuilder,
          $$HistoryRecordsTableUpdateCompanionBuilder,
          (
            HistoryRecordRow,
            BaseReferences<
              _$KlaraDatabase,
              $HistoryRecordsTable,
              HistoryRecordRow
            >,
          ),
          HistoryRecordRow,
          PrefetchHooks Function()
        > {
  $$HistoryRecordsTableTableManager(
    _$KlaraDatabase db,
    $HistoryRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HistoryRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HistoryRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HistoryRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> dateMs = const Value.absent(),
                Value<int> count = const Value.absent(),
                Value<double> mbTrashed = const Value.absent(),
                Value<double> mbFreed = const Value.absent(),
              }) => HistoryRecordsCompanion(
                id: id,
                dateMs: dateMs,
                count: count,
                mbTrashed: mbTrashed,
                mbFreed: mbFreed,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int dateMs,
                required int count,
                required double mbTrashed,
                required double mbFreed,
              }) => HistoryRecordsCompanion.insert(
                id: id,
                dateMs: dateMs,
                count: count,
                mbTrashed: mbTrashed,
                mbFreed: mbFreed,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$HistoryRecordsTable, HistoryRecordRow>(table),
                  BaseReferences<
                    _$KlaraDatabase,
                    $HistoryRecordsTable,
                    HistoryRecordRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HistoryRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$KlaraDatabase,
      $HistoryRecordsTable,
      HistoryRecordRow,
      $$HistoryRecordsTableFilterComposer,
      $$HistoryRecordsTableOrderingComposer,
      $$HistoryRecordsTableAnnotationComposer,
      $$HistoryRecordsTableCreateCompanionBuilder,
      $$HistoryRecordsTableUpdateCompanionBuilder,
      (
        HistoryRecordRow,
        BaseReferences<_$KlaraDatabase, $HistoryRecordsTable, HistoryRecordRow>,
      ),
      HistoryRecordRow,
      PrefetchHooks Function()
    >;
typedef $$SnoozesTableCreateCompanionBuilder = SnoozesCompanion Function({
  required String assetId,
  required int untilMs,
  Value<int> rowid,
});
typedef $$SnoozesTableUpdateCompanionBuilder = SnoozesCompanion Function({
  Value<String> assetId,
  Value<int> untilMs,
  Value<int> rowid,
});

class $$SnoozesTableFilterComposer
    extends Composer<_$KlaraDatabase, $SnoozesTable> {
  $$SnoozesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get assetId => $composableBuilder(
    column: $table.assetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get untilMs => $composableBuilder(
    column: $table.untilMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SnoozesTableOrderingComposer
    extends Composer<_$KlaraDatabase, $SnoozesTable> {
  $$SnoozesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get assetId => $composableBuilder(
    column: $table.assetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get untilMs => $composableBuilder(
    column: $table.untilMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SnoozesTableAnnotationComposer
    extends Composer<_$KlaraDatabase, $SnoozesTable> {
  $$SnoozesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get assetId =>
      $composableBuilder(column: $table.assetId, builder: (column) => column);

  GeneratedColumn<int> get untilMs =>
      $composableBuilder(column: $table.untilMs, builder: (column) => column);
}

class $$SnoozesTableTableManager
    extends
        RootTableManager<
          _$KlaraDatabase,
          $SnoozesTable,
          Snooze,
          $$SnoozesTableFilterComposer,
          $$SnoozesTableOrderingComposer,
          $$SnoozesTableAnnotationComposer,
          $$SnoozesTableCreateCompanionBuilder,
          $$SnoozesTableUpdateCompanionBuilder,
          (Snooze, BaseReferences<_$KlaraDatabase, $SnoozesTable, Snooze>),
          Snooze,
          PrefetchHooks Function()
        > {
  $$SnoozesTableTableManager(_$KlaraDatabase db, $SnoozesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SnoozesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SnoozesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SnoozesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> assetId = const Value.absent(),
                Value<int> untilMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SnoozesCompanion(
                assetId: assetId,
                untilMs: untilMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String assetId,
                required int untilMs,
                Value<int> rowid = const Value.absent(),
              }) => SnoozesCompanion.insert(
                assetId: assetId,
                untilMs: untilMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SnoozesTable, Snooze>(table),
                  BaseReferences<_$KlaraDatabase, $SnoozesTable, Snooze>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SnoozesTableProcessedTableManager =
    ProcessedTableManager<
      _$KlaraDatabase,
      $SnoozesTable,
      Snooze,
      $$SnoozesTableFilterComposer,
      $$SnoozesTableOrderingComposer,
      $$SnoozesTableAnnotationComposer,
      $$SnoozesTableCreateCompanionBuilder,
      $$SnoozesTableUpdateCompanionBuilder,
      (Snooze, BaseReferences<_$KlaraDatabase, $SnoozesTable, Snooze>),
      Snooze,
      PrefetchHooks Function()
    >;
typedef $$CompletionsTableCreateCompanionBuilder =
    CompletionsCompanion Function({Value<int> dayMs});
typedef $$CompletionsTableUpdateCompanionBuilder =
    CompletionsCompanion Function({Value<int> dayMs});

class $$CompletionsTableFilterComposer
    extends Composer<_$KlaraDatabase, $CompletionsTable> {
  $$CompletionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get dayMs => $composableBuilder(
    column: $table.dayMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CompletionsTableOrderingComposer
    extends Composer<_$KlaraDatabase, $CompletionsTable> {
  $$CompletionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get dayMs => $composableBuilder(
    column: $table.dayMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CompletionsTableAnnotationComposer
    extends Composer<_$KlaraDatabase, $CompletionsTable> {
  $$CompletionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get dayMs =>
      $composableBuilder(column: $table.dayMs, builder: (column) => column);
}

class $$CompletionsTableTableManager
    extends
        RootTableManager<
          _$KlaraDatabase,
          $CompletionsTable,
          Completion,
          $$CompletionsTableFilterComposer,
          $$CompletionsTableOrderingComposer,
          $$CompletionsTableAnnotationComposer,
          $$CompletionsTableCreateCompanionBuilder,
          $$CompletionsTableUpdateCompanionBuilder,
          (
            Completion,
            BaseReferences<_$KlaraDatabase, $CompletionsTable, Completion>,
          ),
          Completion,
          PrefetchHooks Function()
        > {
  $$CompletionsTableTableManager(_$KlaraDatabase db, $CompletionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CompletionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CompletionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CompletionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> dayMs = const Value.absent(),
          }) => CompletionsCompanion(dayMs: dayMs),
          createCompanionCallback: ({
            Value<int> dayMs = const Value.absent(),
          }) => CompletionsCompanion.insert(dayMs: dayMs),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CompletionsTable, Completion>(table),
                  BaseReferences<
                    _$KlaraDatabase,
                    $CompletionsTable,
                    Completion
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CompletionsTableProcessedTableManager =
    ProcessedTableManager<
      _$KlaraDatabase,
      $CompletionsTable,
      Completion,
      $$CompletionsTableFilterComposer,
      $$CompletionsTableOrderingComposer,
      $$CompletionsTableAnnotationComposer,
      $$CompletionsTableCreateCompanionBuilder,
      $$CompletionsTableUpdateCompanionBuilder,
      (
        Completion,
        BaseReferences<_$KlaraDatabase, $CompletionsTable, Completion>,
      ),
      Completion,
      PrefetchHooks Function()
    >;
typedef $$MetaEntriesTableCreateCompanionBuilder =
    MetaEntriesCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$MetaEntriesTableUpdateCompanionBuilder =
    MetaEntriesCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$MetaEntriesTableFilterComposer
    extends Composer<_$KlaraDatabase, $MetaEntriesTable> {
  $$MetaEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MetaEntriesTableOrderingComposer
    extends Composer<_$KlaraDatabase, $MetaEntriesTable> {
  $$MetaEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MetaEntriesTableAnnotationComposer
    extends Composer<_$KlaraDatabase, $MetaEntriesTable> {
  $$MetaEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$MetaEntriesTableTableManager
    extends
        RootTableManager<
          _$KlaraDatabase,
          $MetaEntriesTable,
          MetaEntry,
          $$MetaEntriesTableFilterComposer,
          $$MetaEntriesTableOrderingComposer,
          $$MetaEntriesTableAnnotationComposer,
          $$MetaEntriesTableCreateCompanionBuilder,
          $$MetaEntriesTableUpdateCompanionBuilder,
          (
            MetaEntry,
            BaseReferences<_$KlaraDatabase, $MetaEntriesTable, MetaEntry>,
          ),
          MetaEntry,
          PrefetchHooks Function()
        > {
  $$MetaEntriesTableTableManager(_$KlaraDatabase db, $MetaEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MetaEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MetaEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MetaEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => MetaEntriesCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => MetaEntriesCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MetaEntriesTable, MetaEntry>(table),
                  BaseReferences<_$KlaraDatabase, $MetaEntriesTable, MetaEntry>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MetaEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$KlaraDatabase,
      $MetaEntriesTable,
      MetaEntry,
      $$MetaEntriesTableFilterComposer,
      $$MetaEntriesTableOrderingComposer,
      $$MetaEntriesTableAnnotationComposer,
      $$MetaEntriesTableCreateCompanionBuilder,
      $$MetaEntriesTableUpdateCompanionBuilder,
      (
        MetaEntry,
        BaseReferences<_$KlaraDatabase, $MetaEntriesTable, MetaEntry>,
      ),
      MetaEntry,
      PrefetchHooks Function()
    >;

class $KlaraDatabaseManager {
  final _$KlaraDatabase _db;
  $KlaraDatabaseManager(this._db);
  $$AssetInfosTableTableManager get assetInfos =>
      $$AssetInfosTableTableManager(_db, _db.assetInfos);
  $$ScanGroupsTableTableManager get scanGroups =>
      $$ScanGroupsTableTableManager(_db, _db.scanGroups);
  $$ScanGroupMembersTableTableManager get scanGroupMembers =>
      $$ScanGroupMembersTableTableManager(_db, _db.scanGroupMembers);
  $$DuplicateReferencesTableTableManager get duplicateReferences =>
      $$DuplicateReferencesTableTableManager(_db, _db.duplicateReferences);
  $$DuplicateReferenceMembersTableTableManager get duplicateReferenceMembers =>
      $$DuplicateReferenceMembersTableTableManager(
        _db,
        _db.duplicateReferenceMembers,
      );
  $$SessionsTableTableManager get sessions =>
      $$SessionsTableTableManager(_db, _db.sessions);
  $$MarksTableTableManager get marks =>
      $$MarksTableTableManager(_db, _db.marks);
  $$SessionFavouritesTableTableManager get sessionFavourites =>
      $$SessionFavouritesTableTableManager(_db, _db.sessionFavourites);
  $$TrashEntriesTableTableManager get trashEntries =>
      $$TrashEntriesTableTableManager(_db, _db.trashEntries);
  $$HistoryRecordsTableTableManager get historyRecords =>
      $$HistoryRecordsTableTableManager(_db, _db.historyRecords);
  $$SnoozesTableTableManager get snoozes =>
      $$SnoozesTableTableManager(_db, _db.snoozes);
  $$CompletionsTableTableManager get completions =>
      $$CompletionsTableTableManager(_db, _db.completions);
  $$MetaEntriesTableTableManager get metaEntries =>
      $$MetaEntriesTableTableManager(_db, _db.metaEntries);
}
