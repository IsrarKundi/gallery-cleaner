// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'klara_database.dart';

// ignore_for_file: type=lint
class $AnalysesTable extends Analyses with TableInfo<$AnalysesTable, Analyse> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AnalysesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _hashMeta = const VerificationMeta('hash');
  @override
  late final GeneratedColumn<int> hash = GeneratedColumn<int>(
    'hash',
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
  static const VerificationMeta _blurScoreMeta = const VerificationMeta(
    'blurScore',
  );
  @override
  late final GeneratedColumn<double> blurScore = GeneratedColumn<double>(
    'blur_score',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _meanLuminanceMeta = const VerificationMeta(
    'meanLuminance',
  );
  @override
  late final GeneratedColumn<double> meanLuminance = GeneratedColumn<double>(
    'mean_luminance',
    aliasedName,
    false,
    type: DriftSqlType.double,
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
  static const VerificationMeta _algorithmVersionMeta = const VerificationMeta(
    'algorithmVersion',
  );
  @override
  late final GeneratedColumn<int> algorithmVersion = GeneratedColumn<int>(
    'algorithm_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    assetId,
    hash,
    width,
    height,
    blurScore,
    meanLuminance,
    sizeBytes,
    modifiedDateMs,
    algorithmVersion,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'analyses';
  @override
  VerificationContext validateIntegrity(
    Insertable<Analyse> instance, {
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
    if (data.containsKey('hash')) {
      context.handle(
        _hashMeta,
        hash.isAcceptableOrUnknown(data['hash']!, _hashMeta),
      );
    } else if (isInserting) {
      context.missing(_hashMeta);
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
    if (data.containsKey('blur_score')) {
      context.handle(
        _blurScoreMeta,
        blurScore.isAcceptableOrUnknown(data['blur_score']!, _blurScoreMeta),
      );
    } else if (isInserting) {
      context.missing(_blurScoreMeta);
    }
    if (data.containsKey('mean_luminance')) {
      context.handle(
        _meanLuminanceMeta,
        meanLuminance.isAcceptableOrUnknown(
          data['mean_luminance']!,
          _meanLuminanceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_meanLuminanceMeta);
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
    if (data.containsKey('algorithm_version')) {
      context.handle(
        _algorithmVersionMeta,
        algorithmVersion.isAcceptableOrUnknown(
          data['algorithm_version']!,
          _algorithmVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_algorithmVersionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {assetId};
  @override
  Analyse map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Analyse(
      assetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}asset_id'],
      )!,
      hash: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hash'],
      )!,
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}width'],
      )!,
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}height'],
      )!,
      blurScore: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}blur_score'],
      )!,
      meanLuminance: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}mean_luminance'],
      )!,
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      ),
      modifiedDateMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}modified_date_ms'],
      ),
      algorithmVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}algorithm_version'],
      )!,
    );
  }

  @override
  $AnalysesTable createAlias(String alias) {
    return $AnalysesTable(attachedDatabase, alias);
  }
}

class Analyse extends DataClass implements Insertable<Analyse> {
  final String assetId;
  final int hash;
  final int width;
  final int height;
  final double blurScore;
  final double meanLuminance;
  final int? sizeBytes;
  final int? modifiedDateMs;
  final int algorithmVersion;
  const Analyse({
    required this.assetId,
    required this.hash,
    required this.width,
    required this.height,
    required this.blurScore,
    required this.meanLuminance,
    this.sizeBytes,
    this.modifiedDateMs,
    required this.algorithmVersion,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['asset_id'] = Variable<String>(assetId);
    map['hash'] = Variable<int>(hash);
    map['width'] = Variable<int>(width);
    map['height'] = Variable<int>(height);
    map['blur_score'] = Variable<double>(blurScore);
    map['mean_luminance'] = Variable<double>(meanLuminance);
    if (!nullToAbsent || sizeBytes != null) {
      map['size_bytes'] = Variable<int>(sizeBytes);
    }
    if (!nullToAbsent || modifiedDateMs != null) {
      map['modified_date_ms'] = Variable<int>(modifiedDateMs);
    }
    map['algorithm_version'] = Variable<int>(algorithmVersion);
    return map;
  }

  AnalysesCompanion toCompanion(bool nullToAbsent) {
    return AnalysesCompanion(
      assetId: Value(assetId),
      hash: Value(hash),
      width: Value(width),
      height: Value(height),
      blurScore: Value(blurScore),
      meanLuminance: Value(meanLuminance),
      sizeBytes: sizeBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(sizeBytes),
      modifiedDateMs: modifiedDateMs == null && nullToAbsent
          ? const Value.absent()
          : Value(modifiedDateMs),
      algorithmVersion: Value(algorithmVersion),
    );
  }

  factory Analyse.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Analyse(
      assetId: serializer.fromJson<String>(json['assetId']),
      hash: serializer.fromJson<int>(json['hash']),
      width: serializer.fromJson<int>(json['width']),
      height: serializer.fromJson<int>(json['height']),
      blurScore: serializer.fromJson<double>(json['blurScore']),
      meanLuminance: serializer.fromJson<double>(json['meanLuminance']),
      sizeBytes: serializer.fromJson<int?>(json['sizeBytes']),
      modifiedDateMs: serializer.fromJson<int?>(json['modifiedDateMs']),
      algorithmVersion: serializer.fromJson<int>(json['algorithmVersion']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'assetId': serializer.toJson<String>(assetId),
      'hash': serializer.toJson<int>(hash),
      'width': serializer.toJson<int>(width),
      'height': serializer.toJson<int>(height),
      'blurScore': serializer.toJson<double>(blurScore),
      'meanLuminance': serializer.toJson<double>(meanLuminance),
      'sizeBytes': serializer.toJson<int?>(sizeBytes),
      'modifiedDateMs': serializer.toJson<int?>(modifiedDateMs),
      'algorithmVersion': serializer.toJson<int>(algorithmVersion),
    };
  }

  Analyse copyWith({
    String? assetId,
    int? hash,
    int? width,
    int? height,
    double? blurScore,
    double? meanLuminance,
    Value<int?> sizeBytes = const Value.absent(),
    Value<int?> modifiedDateMs = const Value.absent(),
    int? algorithmVersion,
  }) => Analyse(
    assetId: assetId ?? this.assetId,
    hash: hash ?? this.hash,
    width: width ?? this.width,
    height: height ?? this.height,
    blurScore: blurScore ?? this.blurScore,
    meanLuminance: meanLuminance ?? this.meanLuminance,
    sizeBytes: sizeBytes.present ? sizeBytes.value : this.sizeBytes,
    modifiedDateMs: modifiedDateMs.present
        ? modifiedDateMs.value
        : this.modifiedDateMs,
    algorithmVersion: algorithmVersion ?? this.algorithmVersion,
  );
  Analyse copyWithCompanion(AnalysesCompanion data) {
    return Analyse(
      assetId: data.assetId.present ? data.assetId.value : this.assetId,
      hash: data.hash.present ? data.hash.value : this.hash,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
      blurScore: data.blurScore.present ? data.blurScore.value : this.blurScore,
      meanLuminance: data.meanLuminance.present
          ? data.meanLuminance.value
          : this.meanLuminance,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      modifiedDateMs: data.modifiedDateMs.present
          ? data.modifiedDateMs.value
          : this.modifiedDateMs,
      algorithmVersion: data.algorithmVersion.present
          ? data.algorithmVersion.value
          : this.algorithmVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Analyse(')
          ..write('assetId: $assetId, ')
          ..write('hash: $hash, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('blurScore: $blurScore, ')
          ..write('meanLuminance: $meanLuminance, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('modifiedDateMs: $modifiedDateMs, ')
          ..write('algorithmVersion: $algorithmVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    assetId,
    hash,
    width,
    height,
    blurScore,
    meanLuminance,
    sizeBytes,
    modifiedDateMs,
    algorithmVersion,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Analyse &&
          other.assetId == this.assetId &&
          other.hash == this.hash &&
          other.width == this.width &&
          other.height == this.height &&
          other.blurScore == this.blurScore &&
          other.meanLuminance == this.meanLuminance &&
          other.sizeBytes == this.sizeBytes &&
          other.modifiedDateMs == this.modifiedDateMs &&
          other.algorithmVersion == this.algorithmVersion);
}

class AnalysesCompanion extends UpdateCompanion<Analyse> {
  final Value<String> assetId;
  final Value<int> hash;
  final Value<int> width;
  final Value<int> height;
  final Value<double> blurScore;
  final Value<double> meanLuminance;
  final Value<int?> sizeBytes;
  final Value<int?> modifiedDateMs;
  final Value<int> algorithmVersion;
  final Value<int> rowid;
  const AnalysesCompanion({
    this.assetId = const Value.absent(),
    this.hash = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.blurScore = const Value.absent(),
    this.meanLuminance = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.modifiedDateMs = const Value.absent(),
    this.algorithmVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AnalysesCompanion.insert({
    required String assetId,
    required int hash,
    required int width,
    required int height,
    required double blurScore,
    required double meanLuminance,
    this.sizeBytes = const Value.absent(),
    this.modifiedDateMs = const Value.absent(),
    required int algorithmVersion,
    this.rowid = const Value.absent(),
  }) : assetId = Value(assetId),
       hash = Value(hash),
       width = Value(width),
       height = Value(height),
       blurScore = Value(blurScore),
       meanLuminance = Value(meanLuminance),
       algorithmVersion = Value(algorithmVersion);
  static Insertable<Analyse> custom({
    Expression<String>? assetId,
    Expression<int>? hash,
    Expression<int>? width,
    Expression<int>? height,
    Expression<double>? blurScore,
    Expression<double>? meanLuminance,
    Expression<int>? sizeBytes,
    Expression<int>? modifiedDateMs,
    Expression<int>? algorithmVersion,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (assetId != null) 'asset_id': assetId,
      if (hash != null) 'hash': hash,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (blurScore != null) 'blur_score': blurScore,
      if (meanLuminance != null) 'mean_luminance': meanLuminance,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (modifiedDateMs != null) 'modified_date_ms': modifiedDateMs,
      if (algorithmVersion != null) 'algorithm_version': algorithmVersion,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AnalysesCompanion copyWith({
    Value<String>? assetId,
    Value<int>? hash,
    Value<int>? width,
    Value<int>? height,
    Value<double>? blurScore,
    Value<double>? meanLuminance,
    Value<int?>? sizeBytes,
    Value<int?>? modifiedDateMs,
    Value<int>? algorithmVersion,
    Value<int>? rowid,
  }) {
    return AnalysesCompanion(
      assetId: assetId ?? this.assetId,
      hash: hash ?? this.hash,
      width: width ?? this.width,
      height: height ?? this.height,
      blurScore: blurScore ?? this.blurScore,
      meanLuminance: meanLuminance ?? this.meanLuminance,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      modifiedDateMs: modifiedDateMs ?? this.modifiedDateMs,
      algorithmVersion: algorithmVersion ?? this.algorithmVersion,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (assetId.present) {
      map['asset_id'] = Variable<String>(assetId.value);
    }
    if (hash.present) {
      map['hash'] = Variable<int>(hash.value);
    }
    if (width.present) {
      map['width'] = Variable<int>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<int>(height.value);
    }
    if (blurScore.present) {
      map['blur_score'] = Variable<double>(blurScore.value);
    }
    if (meanLuminance.present) {
      map['mean_luminance'] = Variable<double>(meanLuminance.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (modifiedDateMs.present) {
      map['modified_date_ms'] = Variable<int>(modifiedDateMs.value);
    }
    if (algorithmVersion.present) {
      map['algorithm_version'] = Variable<int>(algorithmVersion.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AnalysesCompanion(')
          ..write('assetId: $assetId, ')
          ..write('hash: $hash, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('blurScore: $blurScore, ')
          ..write('meanLuminance: $meanLuminance, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('modifiedDateMs: $modifiedDateMs, ')
          ..write('algorithmVersion: $algorithmVersion, ')
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
  static const VerificationMeta _marksJsonMeta = const VerificationMeta(
    'marksJson',
  );
  @override
  late final GeneratedColumn<String> marksJson = GeneratedColumn<String>(
    'marks_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _favouritesJsonMeta = const VerificationMeta(
    'favouritesJson',
  );
  @override
  late final GeneratedColumn<String> favouritesJson = GeneratedColumn<String>(
    'favourites_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    filterKey,
    currentIndex,
    marksJson,
    favouritesJson,
  ];
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
    if (data.containsKey('marks_json')) {
      context.handle(
        _marksJsonMeta,
        marksJson.isAcceptableOrUnknown(data['marks_json']!, _marksJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_marksJsonMeta);
    }
    if (data.containsKey('favourites_json')) {
      context.handle(
        _favouritesJsonMeta,
        favouritesJson.isAcceptableOrUnknown(
          data['favourites_json']!,
          _favouritesJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_favouritesJsonMeta);
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
      marksJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}marks_json'],
      )!,
      favouritesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}favourites_json'],
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
  final String marksJson;
  final String favouritesJson;
  const Session({
    required this.filterKey,
    required this.currentIndex,
    required this.marksJson,
    required this.favouritesJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['filter_key'] = Variable<String>(filterKey);
    map['current_index'] = Variable<int>(currentIndex);
    map['marks_json'] = Variable<String>(marksJson);
    map['favourites_json'] = Variable<String>(favouritesJson);
    return map;
  }

  SessionsCompanion toCompanion(bool nullToAbsent) {
    return SessionsCompanion(
      filterKey: Value(filterKey),
      currentIndex: Value(currentIndex),
      marksJson: Value(marksJson),
      favouritesJson: Value(favouritesJson),
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
      marksJson: serializer.fromJson<String>(json['marksJson']),
      favouritesJson: serializer.fromJson<String>(json['favouritesJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'filterKey': serializer.toJson<String>(filterKey),
      'currentIndex': serializer.toJson<int>(currentIndex),
      'marksJson': serializer.toJson<String>(marksJson),
      'favouritesJson': serializer.toJson<String>(favouritesJson),
    };
  }

  Session copyWith({
    String? filterKey,
    int? currentIndex,
    String? marksJson,
    String? favouritesJson,
  }) => Session(
    filterKey: filterKey ?? this.filterKey,
    currentIndex: currentIndex ?? this.currentIndex,
    marksJson: marksJson ?? this.marksJson,
    favouritesJson: favouritesJson ?? this.favouritesJson,
  );
  Session copyWithCompanion(SessionsCompanion data) {
    return Session(
      filterKey: data.filterKey.present ? data.filterKey.value : this.filterKey,
      currentIndex: data.currentIndex.present
          ? data.currentIndex.value
          : this.currentIndex,
      marksJson: data.marksJson.present ? data.marksJson.value : this.marksJson,
      favouritesJson: data.favouritesJson.present
          ? data.favouritesJson.value
          : this.favouritesJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Session(')
          ..write('filterKey: $filterKey, ')
          ..write('currentIndex: $currentIndex, ')
          ..write('marksJson: $marksJson, ')
          ..write('favouritesJson: $favouritesJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(filterKey, currentIndex, marksJson, favouritesJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Session &&
          other.filterKey == this.filterKey &&
          other.currentIndex == this.currentIndex &&
          other.marksJson == this.marksJson &&
          other.favouritesJson == this.favouritesJson);
}

class SessionsCompanion extends UpdateCompanion<Session> {
  final Value<String> filterKey;
  final Value<int> currentIndex;
  final Value<String> marksJson;
  final Value<String> favouritesJson;
  final Value<int> rowid;
  const SessionsCompanion({
    this.filterKey = const Value.absent(),
    this.currentIndex = const Value.absent(),
    this.marksJson = const Value.absent(),
    this.favouritesJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SessionsCompanion.insert({
    required String filterKey,
    required int currentIndex,
    required String marksJson,
    required String favouritesJson,
    this.rowid = const Value.absent(),
  }) : filterKey = Value(filterKey),
       currentIndex = Value(currentIndex),
       marksJson = Value(marksJson),
       favouritesJson = Value(favouritesJson);
  static Insertable<Session> custom({
    Expression<String>? filterKey,
    Expression<int>? currentIndex,
    Expression<String>? marksJson,
    Expression<String>? favouritesJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (filterKey != null) 'filter_key': filterKey,
      if (currentIndex != null) 'current_index': currentIndex,
      if (marksJson != null) 'marks_json': marksJson,
      if (favouritesJson != null) 'favourites_json': favouritesJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionsCompanion copyWith({
    Value<String>? filterKey,
    Value<int>? currentIndex,
    Value<String>? marksJson,
    Value<String>? favouritesJson,
    Value<int>? rowid,
  }) {
    return SessionsCompanion(
      filterKey: filterKey ?? this.filterKey,
      currentIndex: currentIndex ?? this.currentIndex,
      marksJson: marksJson ?? this.marksJson,
      favouritesJson: favouritesJson ?? this.favouritesJson,
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
    if (marksJson.present) {
      map['marks_json'] = Variable<String>(marksJson.value);
    }
    if (favouritesJson.present) {
      map['favourites_json'] = Variable<String>(favouritesJson.value);
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
          ..write('marksJson: $marksJson, ')
          ..write('favouritesJson: $favouritesJson, ')
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
  late final $AnalysesTable analyses = $AnalysesTable(this);
  late final $SessionsTable sessions = $SessionsTable(this);
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
    analyses,
    sessions,
    trashEntries,
    historyRecords,
    snoozes,
    completions,
    metaEntries,
  ];
}

typedef $$AnalysesTableCreateCompanionBuilder = AnalysesCompanion Function({
  required String assetId,
  required int hash,
  required int width,
  required int height,
  required double blurScore,
  required double meanLuminance,
  Value<int?> sizeBytes,
  Value<int?> modifiedDateMs,
  required int algorithmVersion,
  Value<int> rowid,
});
typedef $$AnalysesTableUpdateCompanionBuilder = AnalysesCompanion Function({
  Value<String> assetId,
  Value<int> hash,
  Value<int> width,
  Value<int> height,
  Value<double> blurScore,
  Value<double> meanLuminance,
  Value<int?> sizeBytes,
  Value<int?> modifiedDateMs,
  Value<int> algorithmVersion,
  Value<int> rowid,
});

class $$AnalysesTableFilterComposer
    extends Composer<_$KlaraDatabase, $AnalysesTable> {
  $$AnalysesTableFilterComposer({
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

  ColumnFilters<int> get hash => $composableBuilder(
    column: $table.hash,
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

  ColumnFilters<double> get blurScore => $composableBuilder(
    column: $table.blurScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get meanLuminance => $composableBuilder(
    column: $table.meanLuminance,
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

  ColumnFilters<int> get algorithmVersion => $composableBuilder(
    column: $table.algorithmVersion,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AnalysesTableOrderingComposer
    extends Composer<_$KlaraDatabase, $AnalysesTable> {
  $$AnalysesTableOrderingComposer({
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

  ColumnOrderings<int> get hash => $composableBuilder(
    column: $table.hash,
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

  ColumnOrderings<double> get blurScore => $composableBuilder(
    column: $table.blurScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get meanLuminance => $composableBuilder(
    column: $table.meanLuminance,
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

  ColumnOrderings<int> get algorithmVersion => $composableBuilder(
    column: $table.algorithmVersion,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AnalysesTableAnnotationComposer
    extends Composer<_$KlaraDatabase, $AnalysesTable> {
  $$AnalysesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get assetId =>
      $composableBuilder(column: $table.assetId, builder: (column) => column);

  GeneratedColumn<int> get hash =>
      $composableBuilder(column: $table.hash, builder: (column) => column);

  GeneratedColumn<int> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<int> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<double> get blurScore =>
      $composableBuilder(column: $table.blurScore, builder: (column) => column);

  GeneratedColumn<double> get meanLuminance => $composableBuilder(
    column: $table.meanLuminance,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<int> get modifiedDateMs => $composableBuilder(
    column: $table.modifiedDateMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get algorithmVersion => $composableBuilder(
    column: $table.algorithmVersion,
    builder: (column) => column,
  );
}

class $$AnalysesTableTableManager
    extends
        RootTableManager<
          _$KlaraDatabase,
          $AnalysesTable,
          Analyse,
          $$AnalysesTableFilterComposer,
          $$AnalysesTableOrderingComposer,
          $$AnalysesTableAnnotationComposer,
          $$AnalysesTableCreateCompanionBuilder,
          $$AnalysesTableUpdateCompanionBuilder,
          (Analyse, BaseReferences<_$KlaraDatabase, $AnalysesTable, Analyse>),
          Analyse,
          PrefetchHooks Function()
        > {
  $$AnalysesTableTableManager(_$KlaraDatabase db, $AnalysesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AnalysesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AnalysesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AnalysesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> assetId = const Value.absent(),
                Value<int> hash = const Value.absent(),
                Value<int> width = const Value.absent(),
                Value<int> height = const Value.absent(),
                Value<double> blurScore = const Value.absent(),
                Value<double> meanLuminance = const Value.absent(),
                Value<int?> sizeBytes = const Value.absent(),
                Value<int?> modifiedDateMs = const Value.absent(),
                Value<int> algorithmVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AnalysesCompanion(
                assetId: assetId,
                hash: hash,
                width: width,
                height: height,
                blurScore: blurScore,
                meanLuminance: meanLuminance,
                sizeBytes: sizeBytes,
                modifiedDateMs: modifiedDateMs,
                algorithmVersion: algorithmVersion,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String assetId,
                required int hash,
                required int width,
                required int height,
                required double blurScore,
                required double meanLuminance,
                Value<int?> sizeBytes = const Value.absent(),
                Value<int?> modifiedDateMs = const Value.absent(),
                required int algorithmVersion,
                Value<int> rowid = const Value.absent(),
              }) => AnalysesCompanion.insert(
                assetId: assetId,
                hash: hash,
                width: width,
                height: height,
                blurScore: blurScore,
                meanLuminance: meanLuminance,
                sizeBytes: sizeBytes,
                modifiedDateMs: modifiedDateMs,
                algorithmVersion: algorithmVersion,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AnalysesTable, Analyse>(table),
                  BaseReferences<_$KlaraDatabase, $AnalysesTable, Analyse>(
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

typedef $$AnalysesTableProcessedTableManager =
    ProcessedTableManager<
      _$KlaraDatabase,
      $AnalysesTable,
      Analyse,
      $$AnalysesTableFilterComposer,
      $$AnalysesTableOrderingComposer,
      $$AnalysesTableAnnotationComposer,
      $$AnalysesTableCreateCompanionBuilder,
      $$AnalysesTableUpdateCompanionBuilder,
      (Analyse, BaseReferences<_$KlaraDatabase, $AnalysesTable, Analyse>),
      Analyse,
      PrefetchHooks Function()
    >;
typedef $$SessionsTableCreateCompanionBuilder = SessionsCompanion Function({
  required String filterKey,
  required int currentIndex,
  required String marksJson,
  required String favouritesJson,
  Value<int> rowid,
});
typedef $$SessionsTableUpdateCompanionBuilder = SessionsCompanion Function({
  Value<String> filterKey,
  Value<int> currentIndex,
  Value<String> marksJson,
  Value<String> favouritesJson,
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

  ColumnFilters<String> get marksJson => $composableBuilder(
    column: $table.marksJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get favouritesJson => $composableBuilder(
    column: $table.favouritesJson,
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

  ColumnOrderings<String> get marksJson => $composableBuilder(
    column: $table.marksJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get favouritesJson => $composableBuilder(
    column: $table.favouritesJson,
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

  GeneratedColumn<String> get marksJson =>
      $composableBuilder(column: $table.marksJson, builder: (column) => column);

  GeneratedColumn<String> get favouritesJson => $composableBuilder(
    column: $table.favouritesJson,
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
                Value<String> marksJson = const Value.absent(),
                Value<String> favouritesJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionsCompanion(
                filterKey: filterKey,
                currentIndex: currentIndex,
                marksJson: marksJson,
                favouritesJson: favouritesJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String filterKey,
                required int currentIndex,
                required String marksJson,
                required String favouritesJson,
                Value<int> rowid = const Value.absent(),
              }) => SessionsCompanion.insert(
                filterKey: filterKey,
                currentIndex: currentIndex,
                marksJson: marksJson,
                favouritesJson: favouritesJson,
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
  $$AnalysesTableTableManager get analyses =>
      $$AnalysesTableTableManager(_db, _db.analyses);
  $$SessionsTableTableManager get sessions =>
      $$SessionsTableTableManager(_db, _db.sessions);
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
