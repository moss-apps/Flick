// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'song_audio_cache_entity.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetSongAudioCacheEntityCollection on Isar {
  IsarCollection<SongAudioCacheEntity> get songAudioCacheEntitys =>
      this.collection();
}

const SongAudioCacheEntitySchema = CollectionSchema(
  name: r'SongAudioCacheEntity',
  id: -2769901146832887679,
  properties: {
    r'clipping': PropertySchema(id: 0, name: r'clipping', type: IsarType.bool),
    r'computedAt': PropertySchema(
      id: 1,
      name: r'computedAt',
      type: IsarType.long,
    ),
    r'dr': PropertySchema(id: 2, name: r'dr', type: IsarType.double),
    r'lra': PropertySchema(id: 3, name: r'lra', type: IsarType.double),
    r'lufs': PropertySchema(id: 4, name: r'lufs', type: IsarType.double),
    r'peaks': PropertySchema(id: 5, name: r'peaks', type: IsarType.doubleList),
    r'truePeakDb': PropertySchema(
      id: 6,
      name: r'truePeakDb',
      type: IsarType.double,
    ),
    r'version': PropertySchema(id: 7, name: r'version', type: IsarType.long),
  },

  estimateSize: _songAudioCacheEntityEstimateSize,
  serialize: _songAudioCacheEntitySerialize,
  deserialize: _songAudioCacheEntityDeserialize,
  deserializeProp: _songAudioCacheEntityDeserializeProp,
  idName: r'songId',
  indexes: {
    r'computedAt': IndexSchema(
      id: -6611996734690586031,
      name: r'computedAt',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'computedAt',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _songAudioCacheEntityGetId,
  getLinks: _songAudioCacheEntityGetLinks,
  attach: _songAudioCacheEntityAttach,
  version: '3.3.2',
);

int _songAudioCacheEntityEstimateSize(
  SongAudioCacheEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.peaks.length * 8;
  return bytesCount;
}

void _songAudioCacheEntitySerialize(
  SongAudioCacheEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeBool(offsets[0], object.clipping);
  writer.writeLong(offsets[1], object.computedAt);
  writer.writeDouble(offsets[2], object.dr);
  writer.writeDouble(offsets[3], object.lra);
  writer.writeDouble(offsets[4], object.lufs);
  writer.writeDoubleList(offsets[5], object.peaks);
  writer.writeDouble(offsets[6], object.truePeakDb);
  writer.writeLong(offsets[7], object.version);
}

SongAudioCacheEntity _songAudioCacheEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = SongAudioCacheEntity();
  object.clipping = reader.readBool(offsets[0]);
  object.computedAt = reader.readLong(offsets[1]);
  object.dr = reader.readDoubleOrNull(offsets[2]);
  object.lra = reader.readDoubleOrNull(offsets[3]);
  object.lufs = reader.readDoubleOrNull(offsets[4]);
  object.peaks = reader.readDoubleList(offsets[5]) ?? [];
  object.songId = id;
  object.truePeakDb = reader.readDoubleOrNull(offsets[6]);
  object.version = reader.readLong(offsets[7]);
  return object;
}

P _songAudioCacheEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readBool(offset)) as P;
    case 1:
      return (reader.readLong(offset)) as P;
    case 2:
      return (reader.readDoubleOrNull(offset)) as P;
    case 3:
      return (reader.readDoubleOrNull(offset)) as P;
    case 4:
      return (reader.readDoubleOrNull(offset)) as P;
    case 5:
      return (reader.readDoubleList(offset) ?? []) as P;
    case 6:
      return (reader.readDoubleOrNull(offset)) as P;
    case 7:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _songAudioCacheEntityGetId(SongAudioCacheEntity object) {
  return object.songId;
}

List<IsarLinkBase<dynamic>> _songAudioCacheEntityGetLinks(
  SongAudioCacheEntity object,
) {
  return [];
}

void _songAudioCacheEntityAttach(
  IsarCollection<dynamic> col,
  Id id,
  SongAudioCacheEntity object,
) {
  object.songId = id;
}

extension SongAudioCacheEntityQueryWhereSort
    on QueryBuilder<SongAudioCacheEntity, SongAudioCacheEntity, QWhere> {
  QueryBuilder<SongAudioCacheEntity, SongAudioCacheEntity, QAfterWhere>
  anySongId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<SongAudioCacheEntity, SongAudioCacheEntity, QAfterWhere>
  anyComputedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'computedAt'),
      );
    });
  }
}

extension SongAudioCacheEntityQueryWhere
    on QueryBuilder<SongAudioCacheEntity, SongAudioCacheEntity, QWhereClause> {
  QueryBuilder<SongAudioCacheEntity, SongAudioCacheEntity, QAfterWhereClause>
  songIdEqualTo(Id songId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(lower: songId, upper: songId),
      );
    });
  }

  QueryBuilder<SongAudioCacheEntity, SongAudioCacheEntity, QAfterWhereClause>
  songIdNotEqualTo(Id songId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: songId, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: songId, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: songId, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: songId, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<SongAudioCacheEntity, SongAudioCacheEntity, QAfterWhereClause>
  songIdGreaterThan(Id songId, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: songId, includeLower: include),
      );
    });
  }

  QueryBuilder<SongAudioCacheEntity, SongAudioCacheEntity, QAfterWhereClause>
  songIdLessThan(Id songId, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: songId, includeUpper: include),
      );
    });
  }

  QueryBuilder<SongAudioCacheEntity, SongAudioCacheEntity, QAfterWhereClause>
  songIdBetween(
    Id lowerSongId,
    Id upperSongId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerSongId,
          includeLower: includeLower,
          upper: upperSongId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<SongAudioCacheEntity, SongAudioCacheEntity, QAfterWhereClause>
  computedAtEqualTo(int computedAt) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'computedAt', value: [computedAt]),
      );
    });
  }

  QueryBuilder<SongAudioCacheEntity, SongAudioCacheEntity, QAfterWhereClause>
  computedAtNotEqualTo(int computedAt) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'computedAt',
                lower: [],
                upper: [computedAt],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'computedAt',
                lower: [computedAt],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'computedAt',
                lower: [computedAt],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'computedAt',
                lower: [],
                upper: [computedAt],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<SongAudioCacheEntity, SongAudioCacheEntity, QAfterWhereClause>
  computedAtGreaterThan(int computedAt, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'computedAt',
          lower: [computedAt],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<SongAudioCacheEntity, SongAudioCacheEntity, QAfterWhereClause>
  computedAtLessThan(int computedAt, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'computedAt',
          lower: [],
          upper: [computedAt],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<SongAudioCacheEntity, SongAudioCacheEntity, QAfterWhereClause>
  computedAtBetween(
    int lowerComputedAt,
    int upperComputedAt, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'computedAt',
          lower: [lowerComputedAt],
          includeLower: includeLower,
          upper: [upperComputedAt],
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension SongAudioCacheEntityQueryFilter
    on
        QueryBuilder<
          SongAudioCacheEntity,
          SongAudioCacheEntity,
          QFilterCondition
        > {
  QueryBuilder<
    SongAudioCacheEntity,
    SongAudioCacheEntity,
    QAfterFilterCondition
  >
  clippingEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'clipping', value: value),
      );
    });
  }

  QueryBuilder<
    SongAudioCacheEntity,
    SongAudioCacheEntity,
    QAfterFilterCondition
  >
  computedAtEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'computedAt', value: value),
      );
    });
  }

  QueryBuilder<
    SongAudioCacheEntity,
    SongAudioCacheEntity,
    QAfterFilterCondition
  >
  computedAtGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'computedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    SongAudioCacheEntity,
    SongAudioCacheEntity,
    QAfterFilterCondition
  >
  computedAtLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'computedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    SongAudioCacheEntity,
    SongAudioCacheEntity,
    QAfterFilterCondition
  >
  computedAtBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'computedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    SongAudioCacheEntity,
    SongAudioCacheEntity,
    QAfterFilterCondition
  >
  drIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'dr'),
      );
    });
  }

  QueryBuilder<
    SongAudioCacheEntity,
    SongAudioCacheEntity,
    QAfterFilterCondition
  >
  drIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'dr'),
      );
    });
  }

  QueryBuilder<
    SongAudioCacheEntity,
    SongAudioCacheEntity,
    QAfterFilterCondition
  >
  drEqualTo(double? value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'dr',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    SongAudioCacheEntity,
    SongAudioCacheEntity,
    QAfterFilterCondition
  >
  drGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'dr',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    SongAudioCacheEntity,
    SongAudioCacheEntity,
    QAfterFilterCondition
  >
  drLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'dr',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    SongAudioCacheEntity,
    SongAudioCacheEntity,
    QAfterFilterCondition
  >
  drBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'dr',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    SongAudioCacheEntity,
    SongAudioCacheEntity,
    QAfterFilterCondition
  >
  lraIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'lra'),
      );
    });
  }

  QueryBuilder<
    SongAudioCacheEntity,
    SongAudioCacheEntity,
    QAfterFilterCondition
  >
  lraIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'lra'),
      );
    });
  }

  QueryBuilder<
    SongAudioCacheEntity,
    SongAudioCacheEntity,
    QAfterFilterCondition
  >
  lraEqualTo(double? value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'lra',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    SongAudioCacheEntity,
    SongAudioCacheEntity,
    QAfterFilterCondition
  >
  lraGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'lra',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    SongAudioCacheEntity,
    SongAudioCacheEntity,
    QAfterFilterCondition
  >
  lraLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'lra',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    SongAudioCacheEntity,
    SongAudioCacheEntity,
    QAfterFilterCondition
  >
  lraBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'lra',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    SongAudioCacheEntity,
    SongAudioCacheEntity,
    QAfterFilterCondition
  >
  lufsIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'lufs'),
      );
    });
  }

  QueryBuilder<
    SongAudioCacheEntity,
    SongAudioCacheEntity,
    QAfterFilterCondition
  >
  lufsIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'lufs'),
      );
    });
  }

  QueryBuilder<
    SongAudioCacheEntity,
    SongAudioCacheEntity,
    QAfterFilterCondition
  >
  lufsEqualTo(double? value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'lufs',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    SongAudioCacheEntity,
    SongAudioCacheEntity,
    QAfterFilterCondition
  >
  lufsGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'lufs',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    SongAudioCacheEntity,
    SongAudioCacheEntity,
    QAfterFilterCondition
  >
  lufsLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'lufs',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    SongAudioCacheEntity,
    SongAudioCacheEntity,
    QAfterFilterCondition
  >
  lufsBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'lufs',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    SongAudioCacheEntity,
    SongAudioCacheEntity,
    QAfterFilterCondition
  >
  peaksElementEqualTo(double value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'peaks',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    SongAudioCacheEntity,
    SongAudioCacheEntity,
    QAfterFilterCondition
  >
  peaksElementGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'peaks',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    SongAudioCacheEntity,
    SongAudioCacheEntity,
    QAfterFilterCondition
  >
  peaksElementLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'peaks',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    SongAudioCacheEntity,
    SongAudioCacheEntity,
    QAfterFilterCondition
  >
  peaksElementBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'peaks',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    SongAudioCacheEntity,
    SongAudioCacheEntity,
    QAfterFilterCondition
  >
  peaksLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'peaks', length, true, length, true);
    });
  }

  QueryBuilder<
    SongAudioCacheEntity,
    SongAudioCacheEntity,
    QAfterFilterCondition
  >
  peaksIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'peaks', 0, true, 0, true);
    });
  }

  QueryBuilder<
    SongAudioCacheEntity,
    SongAudioCacheEntity,
    QAfterFilterCondition
  >
  peaksIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'peaks', 0, false, 999999, true);
    });
  }

  QueryBuilder<
    SongAudioCacheEntity,
    SongAudioCacheEntity,
    QAfterFilterCondition
  >
  peaksLengthLessThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'peaks', 0, true, length, include);
    });
  }

  QueryBuilder<
    SongAudioCacheEntity,
    SongAudioCacheEntity,
    QAfterFilterCondition
  >
  peaksLengthGreaterThan(int length, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(r'peaks', length, include, 999999, true);
    });
  }

  QueryBuilder<
    SongAudioCacheEntity,
    SongAudioCacheEntity,
    QAfterFilterCondition
  >
  peaksLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'peaks',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<
    SongAudioCacheEntity,
    SongAudioCacheEntity,
    QAfterFilterCondition
  >
  songIdEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'songId', value: value),
      );
    });
  }

  QueryBuilder<
    SongAudioCacheEntity,
    SongAudioCacheEntity,
    QAfterFilterCondition
  >
  songIdGreaterThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'songId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    SongAudioCacheEntity,
    SongAudioCacheEntity,
    QAfterFilterCondition
  >
  songIdLessThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'songId',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    SongAudioCacheEntity,
    SongAudioCacheEntity,
    QAfterFilterCondition
  >
  songIdBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'songId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<
    SongAudioCacheEntity,
    SongAudioCacheEntity,
    QAfterFilterCondition
  >
  truePeakDbIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'truePeakDb'),
      );
    });
  }

  QueryBuilder<
    SongAudioCacheEntity,
    SongAudioCacheEntity,
    QAfterFilterCondition
  >
  truePeakDbIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'truePeakDb'),
      );
    });
  }

  QueryBuilder<
    SongAudioCacheEntity,
    SongAudioCacheEntity,
    QAfterFilterCondition
  >
  truePeakDbEqualTo(double? value, {double epsilon = Query.epsilon}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'truePeakDb',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    SongAudioCacheEntity,
    SongAudioCacheEntity,
    QAfterFilterCondition
  >
  truePeakDbGreaterThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'truePeakDb',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    SongAudioCacheEntity,
    SongAudioCacheEntity,
    QAfterFilterCondition
  >
  truePeakDbLessThan(
    double? value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'truePeakDb',
          value: value,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    SongAudioCacheEntity,
    SongAudioCacheEntity,
    QAfterFilterCondition
  >
  truePeakDbBetween(
    double? lower,
    double? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'truePeakDb',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,

          epsilon: epsilon,
        ),
      );
    });
  }

  QueryBuilder<
    SongAudioCacheEntity,
    SongAudioCacheEntity,
    QAfterFilterCondition
  >
  versionEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'version', value: value),
      );
    });
  }

  QueryBuilder<
    SongAudioCacheEntity,
    SongAudioCacheEntity,
    QAfterFilterCondition
  >
  versionGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'version',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    SongAudioCacheEntity,
    SongAudioCacheEntity,
    QAfterFilterCondition
  >
  versionLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'version',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<
    SongAudioCacheEntity,
    SongAudioCacheEntity,
    QAfterFilterCondition
  >
  versionBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'version',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension SongAudioCacheEntityQueryObject
    on
        QueryBuilder<
          SongAudioCacheEntity,
          SongAudioCacheEntity,
          QFilterCondition
        > {}

extension SongAudioCacheEntityQueryLinks
    on
        QueryBuilder<
          SongAudioCacheEntity,
          SongAudioCacheEntity,
          QFilterCondition
        > {}

extension SongAudioCacheEntityQuerySortBy
    on QueryBuilder<SongAudioCacheEntity, SongAudioCacheEntity, QSortBy> {
  QueryBuilder<SongAudioCacheEntity, SongAudioCacheEntity, QAfterSortBy>
  sortByClipping() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'clipping', Sort.asc);
    });
  }

  QueryBuilder<SongAudioCacheEntity, SongAudioCacheEntity, QAfterSortBy>
  sortByClippingDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'clipping', Sort.desc);
    });
  }

  QueryBuilder<SongAudioCacheEntity, SongAudioCacheEntity, QAfterSortBy>
  sortByComputedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'computedAt', Sort.asc);
    });
  }

  QueryBuilder<SongAudioCacheEntity, SongAudioCacheEntity, QAfterSortBy>
  sortByComputedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'computedAt', Sort.desc);
    });
  }

  QueryBuilder<SongAudioCacheEntity, SongAudioCacheEntity, QAfterSortBy>
  sortByDr() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dr', Sort.asc);
    });
  }

  QueryBuilder<SongAudioCacheEntity, SongAudioCacheEntity, QAfterSortBy>
  sortByDrDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dr', Sort.desc);
    });
  }

  QueryBuilder<SongAudioCacheEntity, SongAudioCacheEntity, QAfterSortBy>
  sortByLra() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lra', Sort.asc);
    });
  }

  QueryBuilder<SongAudioCacheEntity, SongAudioCacheEntity, QAfterSortBy>
  sortByLraDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lra', Sort.desc);
    });
  }

  QueryBuilder<SongAudioCacheEntity, SongAudioCacheEntity, QAfterSortBy>
  sortByLufs() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lufs', Sort.asc);
    });
  }

  QueryBuilder<SongAudioCacheEntity, SongAudioCacheEntity, QAfterSortBy>
  sortByLufsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lufs', Sort.desc);
    });
  }

  QueryBuilder<SongAudioCacheEntity, SongAudioCacheEntity, QAfterSortBy>
  sortByTruePeakDb() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'truePeakDb', Sort.asc);
    });
  }

  QueryBuilder<SongAudioCacheEntity, SongAudioCacheEntity, QAfterSortBy>
  sortByTruePeakDbDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'truePeakDb', Sort.desc);
    });
  }

  QueryBuilder<SongAudioCacheEntity, SongAudioCacheEntity, QAfterSortBy>
  sortByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.asc);
    });
  }

  QueryBuilder<SongAudioCacheEntity, SongAudioCacheEntity, QAfterSortBy>
  sortByVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.desc);
    });
  }
}

extension SongAudioCacheEntityQuerySortThenBy
    on QueryBuilder<SongAudioCacheEntity, SongAudioCacheEntity, QSortThenBy> {
  QueryBuilder<SongAudioCacheEntity, SongAudioCacheEntity, QAfterSortBy>
  thenByClipping() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'clipping', Sort.asc);
    });
  }

  QueryBuilder<SongAudioCacheEntity, SongAudioCacheEntity, QAfterSortBy>
  thenByClippingDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'clipping', Sort.desc);
    });
  }

  QueryBuilder<SongAudioCacheEntity, SongAudioCacheEntity, QAfterSortBy>
  thenByComputedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'computedAt', Sort.asc);
    });
  }

  QueryBuilder<SongAudioCacheEntity, SongAudioCacheEntity, QAfterSortBy>
  thenByComputedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'computedAt', Sort.desc);
    });
  }

  QueryBuilder<SongAudioCacheEntity, SongAudioCacheEntity, QAfterSortBy>
  thenByDr() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dr', Sort.asc);
    });
  }

  QueryBuilder<SongAudioCacheEntity, SongAudioCacheEntity, QAfterSortBy>
  thenByDrDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dr', Sort.desc);
    });
  }

  QueryBuilder<SongAudioCacheEntity, SongAudioCacheEntity, QAfterSortBy>
  thenByLra() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lra', Sort.asc);
    });
  }

  QueryBuilder<SongAudioCacheEntity, SongAudioCacheEntity, QAfterSortBy>
  thenByLraDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lra', Sort.desc);
    });
  }

  QueryBuilder<SongAudioCacheEntity, SongAudioCacheEntity, QAfterSortBy>
  thenByLufs() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lufs', Sort.asc);
    });
  }

  QueryBuilder<SongAudioCacheEntity, SongAudioCacheEntity, QAfterSortBy>
  thenByLufsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lufs', Sort.desc);
    });
  }

  QueryBuilder<SongAudioCacheEntity, SongAudioCacheEntity, QAfterSortBy>
  thenBySongId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'songId', Sort.asc);
    });
  }

  QueryBuilder<SongAudioCacheEntity, SongAudioCacheEntity, QAfterSortBy>
  thenBySongIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'songId', Sort.desc);
    });
  }

  QueryBuilder<SongAudioCacheEntity, SongAudioCacheEntity, QAfterSortBy>
  thenByTruePeakDb() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'truePeakDb', Sort.asc);
    });
  }

  QueryBuilder<SongAudioCacheEntity, SongAudioCacheEntity, QAfterSortBy>
  thenByTruePeakDbDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'truePeakDb', Sort.desc);
    });
  }

  QueryBuilder<SongAudioCacheEntity, SongAudioCacheEntity, QAfterSortBy>
  thenByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.asc);
    });
  }

  QueryBuilder<SongAudioCacheEntity, SongAudioCacheEntity, QAfterSortBy>
  thenByVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'version', Sort.desc);
    });
  }
}

extension SongAudioCacheEntityQueryWhereDistinct
    on QueryBuilder<SongAudioCacheEntity, SongAudioCacheEntity, QDistinct> {
  QueryBuilder<SongAudioCacheEntity, SongAudioCacheEntity, QDistinct>
  distinctByClipping() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'clipping');
    });
  }

  QueryBuilder<SongAudioCacheEntity, SongAudioCacheEntity, QDistinct>
  distinctByComputedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'computedAt');
    });
  }

  QueryBuilder<SongAudioCacheEntity, SongAudioCacheEntity, QDistinct>
  distinctByDr() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'dr');
    });
  }

  QueryBuilder<SongAudioCacheEntity, SongAudioCacheEntity, QDistinct>
  distinctByLra() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lra');
    });
  }

  QueryBuilder<SongAudioCacheEntity, SongAudioCacheEntity, QDistinct>
  distinctByLufs() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lufs');
    });
  }

  QueryBuilder<SongAudioCacheEntity, SongAudioCacheEntity, QDistinct>
  distinctByPeaks() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'peaks');
    });
  }

  QueryBuilder<SongAudioCacheEntity, SongAudioCacheEntity, QDistinct>
  distinctByTruePeakDb() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'truePeakDb');
    });
  }

  QueryBuilder<SongAudioCacheEntity, SongAudioCacheEntity, QDistinct>
  distinctByVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'version');
    });
  }
}

extension SongAudioCacheEntityQueryProperty
    on
        QueryBuilder<
          SongAudioCacheEntity,
          SongAudioCacheEntity,
          QQueryProperty
        > {
  QueryBuilder<SongAudioCacheEntity, int, QQueryOperations> songIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'songId');
    });
  }

  QueryBuilder<SongAudioCacheEntity, bool, QQueryOperations>
  clippingProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'clipping');
    });
  }

  QueryBuilder<SongAudioCacheEntity, int, QQueryOperations>
  computedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'computedAt');
    });
  }

  QueryBuilder<SongAudioCacheEntity, double?, QQueryOperations> drProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'dr');
    });
  }

  QueryBuilder<SongAudioCacheEntity, double?, QQueryOperations> lraProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lra');
    });
  }

  QueryBuilder<SongAudioCacheEntity, double?, QQueryOperations> lufsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lufs');
    });
  }

  QueryBuilder<SongAudioCacheEntity, List<double>, QQueryOperations>
  peaksProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'peaks');
    });
  }

  QueryBuilder<SongAudioCacheEntity, double?, QQueryOperations>
  truePeakDbProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'truePeakDb');
    });
  }

  QueryBuilder<SongAudioCacheEntity, int, QQueryOperations> versionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'version');
    });
  }
}
