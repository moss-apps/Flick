// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'song_entity.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetSongEntityCollection on Isar {
  IsarCollection<SongEntity> get songEntitys => this.collection();
}

const SongEntitySchema = CollectionSchema(
  name: r'SongEntity',
  id: -4322515446108572550,
  properties: {
    r'accurateRip': PropertySchema(
      id: 0,
      name: r'accurateRip',
      type: IsarType.bool,
    ),
    r'album': PropertySchema(id: 1, name: r'album', type: IsarType.string),
    r'albumArtPath': PropertySchema(
      id: 2,
      name: r'albumArtPath',
      type: IsarType.string,
    ),
    r'albumArtist': PropertySchema(
      id: 3,
      name: r'albumArtist',
      type: IsarType.string,
    ),
    r'artist': PropertySchema(id: 4, name: r'artist', type: IsarType.string),
    r'bitDepth': PropertySchema(id: 5, name: r'bitDepth', type: IsarType.long),
    r'bitrate': PropertySchema(id: 6, name: r'bitrate', type: IsarType.long),
    r'channels': PropertySchema(id: 7, name: r'channels', type: IsarType.long),
    r'copyCrc': PropertySchema(id: 8, name: r'copyCrc', type: IsarType.string),
    r'dateAdded': PropertySchema(
      id: 9,
      name: r'dateAdded',
      type: IsarType.dateTime,
    ),
    r'discNumber': PropertySchema(
      id: 10,
      name: r'discNumber',
      type: IsarType.long,
    ),
    r'durationMs': PropertySchema(
      id: 11,
      name: r'durationMs',
      type: IsarType.long,
    ),
    r'endOffsetMs': PropertySchema(
      id: 12,
      name: r'endOffsetMs',
      type: IsarType.long,
    ),
    r'filePath': PropertySchema(
      id: 13,
      name: r'filePath',
      type: IsarType.string,
    ),
    r'fileSize': PropertySchema(id: 14, name: r'fileSize', type: IsarType.long),
    r'fileType': PropertySchema(
      id: 15,
      name: r'fileType',
      type: IsarType.string,
    ),
    r'folderUri': PropertySchema(
      id: 16,
      name: r'folderUri',
      type: IsarType.string,
    ),
    r'genre': PropertySchema(id: 17, name: r'genre', type: IsarType.string),
    r'hasLocalEdits': PropertySchema(
      id: 18,
      name: r'hasLocalEdits',
      type: IsarType.bool,
    ),
    r'lastModified': PropertySchema(
      id: 19,
      name: r'lastModified',
      type: IsarType.dateTime,
    ),
    r'mediaStoreUri': PropertySchema(
      id: 20,
      name: r'mediaStoreUri',
      type: IsarType.string,
    ),
    r'metadataComplete': PropertySchema(
      id: 21,
      name: r'metadataComplete',
      type: IsarType.bool,
    ),
    r'readMode': PropertySchema(
      id: 22,
      name: r'readMode',
      type: IsarType.string,
    ),
    r'ripper': PropertySchema(id: 23, name: r'ripper', type: IsarType.string),
    r'sampleRate': PropertySchema(
      id: 24,
      name: r'sampleRate',
      type: IsarType.long,
    ),
    r'startOffsetMs': PropertySchema(
      id: 25,
      name: r'startOffsetMs',
      type: IsarType.long,
    ),
    r'testCrc': PropertySchema(id: 26, name: r'testCrc', type: IsarType.string),
    r'title': PropertySchema(id: 27, name: r'title', type: IsarType.string),
    r'trackNumber': PropertySchema(
      id: 28,
      name: r'trackNumber',
      type: IsarType.long,
    ),
    r'year': PropertySchema(id: 29, name: r'year', type: IsarType.long),
  },

  estimateSize: _songEntityEstimateSize,
  serialize: _songEntitySerialize,
  deserialize: _songEntityDeserialize,
  deserializeProp: _songEntityDeserializeProp,
  idName: r'id',
  indexes: {
    r'filePath_startOffsetMs': IndexSchema(
      id: 46708853494516510,
      name: r'filePath_startOffsetMs',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'filePath',
          type: IndexType.hash,
          caseSensitive: true,
        ),
        IndexPropertySchema(
          name: r'startOffsetMs',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
    r'mediaStoreUri': IndexSchema(
      id: 5993154885152836577,
      name: r'mediaStoreUri',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'mediaStoreUri',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'title': IndexSchema(
      id: -7636685945352118059,
      name: r'title',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'title',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'folderUri': IndexSchema(
      id: -6159925735266607609,
      name: r'folderUri',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'folderUri',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'dateAdded': IndexSchema(
      id: 7425792204428031576,
      name: r'dateAdded',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'dateAdded',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
    r'lastModified': IndexSchema(
      id: 5953778071269117195,
      name: r'lastModified',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'lastModified',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
    r'metadataComplete': IndexSchema(
      id: -9193673874484274742,
      name: r'metadataComplete',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'metadataComplete',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
    r'hasLocalEdits': IndexSchema(
      id: -7363271847272433542,
      name: r'hasLocalEdits',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'hasLocalEdits',
          type: IndexType.value,
          caseSensitive: false,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _songEntityGetId,
  getLinks: _songEntityGetLinks,
  attach: _songEntityAttach,
  version: '3.3.0',
);

int _songEntityEstimateSize(
  SongEntity object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.album;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.albumArtPath;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.albumArtist;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.artist.length * 3;
  {
    final value = object.copyCrc;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.filePath.length * 3;
  {
    final value = object.fileType;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.folderUri;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.genre;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.mediaStoreUri;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.readMode;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.ripper;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.testCrc;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.title.length * 3;
  return bytesCount;
}

void _songEntitySerialize(
  SongEntity object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeBool(offsets[0], object.accurateRip);
  writer.writeString(offsets[1], object.album);
  writer.writeString(offsets[2], object.albumArtPath);
  writer.writeString(offsets[3], object.albumArtist);
  writer.writeString(offsets[4], object.artist);
  writer.writeLong(offsets[5], object.bitDepth);
  writer.writeLong(offsets[6], object.bitrate);
  writer.writeLong(offsets[7], object.channels);
  writer.writeString(offsets[8], object.copyCrc);
  writer.writeDateTime(offsets[9], object.dateAdded);
  writer.writeLong(offsets[10], object.discNumber);
  writer.writeLong(offsets[11], object.durationMs);
  writer.writeLong(offsets[12], object.endOffsetMs);
  writer.writeString(offsets[13], object.filePath);
  writer.writeLong(offsets[14], object.fileSize);
  writer.writeString(offsets[15], object.fileType);
  writer.writeString(offsets[16], object.folderUri);
  writer.writeString(offsets[17], object.genre);
  writer.writeBool(offsets[18], object.hasLocalEdits);
  writer.writeDateTime(offsets[19], object.lastModified);
  writer.writeString(offsets[20], object.mediaStoreUri);
  writer.writeBool(offsets[21], object.metadataComplete);
  writer.writeString(offsets[22], object.readMode);
  writer.writeString(offsets[23], object.ripper);
  writer.writeLong(offsets[24], object.sampleRate);
  writer.writeLong(offsets[25], object.startOffsetMs);
  writer.writeString(offsets[26], object.testCrc);
  writer.writeString(offsets[27], object.title);
  writer.writeLong(offsets[28], object.trackNumber);
  writer.writeLong(offsets[29], object.year);
}

SongEntity _songEntityDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = SongEntity();
  object.accurateRip = reader.readBoolOrNull(offsets[0]);
  object.album = reader.readStringOrNull(offsets[1]);
  object.albumArtPath = reader.readStringOrNull(offsets[2]);
  object.albumArtist = reader.readStringOrNull(offsets[3]);
  object.artist = reader.readString(offsets[4]);
  object.bitDepth = reader.readLongOrNull(offsets[5]);
  object.bitrate = reader.readLongOrNull(offsets[6]);
  object.channels = reader.readLongOrNull(offsets[7]);
  object.copyCrc = reader.readStringOrNull(offsets[8]);
  object.dateAdded = reader.readDateTime(offsets[9]);
  object.discNumber = reader.readLongOrNull(offsets[10]);
  object.durationMs = reader.readLongOrNull(offsets[11]);
  object.endOffsetMs = reader.readLongOrNull(offsets[12]);
  object.filePath = reader.readString(offsets[13]);
  object.fileSize = reader.readLongOrNull(offsets[14]);
  object.fileType = reader.readStringOrNull(offsets[15]);
  object.folderUri = reader.readStringOrNull(offsets[16]);
  object.genre = reader.readStringOrNull(offsets[17]);
  object.hasLocalEdits = reader.readBool(offsets[18]);
  object.id = id;
  object.lastModified = reader.readDateTimeOrNull(offsets[19]);
  object.mediaStoreUri = reader.readStringOrNull(offsets[20]);
  object.metadataComplete = reader.readBool(offsets[21]);
  object.readMode = reader.readStringOrNull(offsets[22]);
  object.ripper = reader.readStringOrNull(offsets[23]);
  object.sampleRate = reader.readLongOrNull(offsets[24]);
  object.startOffsetMs = reader.readLongOrNull(offsets[25]);
  object.testCrc = reader.readStringOrNull(offsets[26]);
  object.title = reader.readString(offsets[27]);
  object.trackNumber = reader.readLongOrNull(offsets[28]);
  object.year = reader.readLongOrNull(offsets[29]);
  return object;
}

P _songEntityDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readBoolOrNull(offset)) as P;
    case 1:
      return (reader.readStringOrNull(offset)) as P;
    case 2:
      return (reader.readStringOrNull(offset)) as P;
    case 3:
      return (reader.readStringOrNull(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readLongOrNull(offset)) as P;
    case 6:
      return (reader.readLongOrNull(offset)) as P;
    case 7:
      return (reader.readLongOrNull(offset)) as P;
    case 8:
      return (reader.readStringOrNull(offset)) as P;
    case 9:
      return (reader.readDateTime(offset)) as P;
    case 10:
      return (reader.readLongOrNull(offset)) as P;
    case 11:
      return (reader.readLongOrNull(offset)) as P;
    case 12:
      return (reader.readLongOrNull(offset)) as P;
    case 13:
      return (reader.readString(offset)) as P;
    case 14:
      return (reader.readLongOrNull(offset)) as P;
    case 15:
      return (reader.readStringOrNull(offset)) as P;
    case 16:
      return (reader.readStringOrNull(offset)) as P;
    case 17:
      return (reader.readStringOrNull(offset)) as P;
    case 18:
      return (reader.readBool(offset)) as P;
    case 19:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 20:
      return (reader.readStringOrNull(offset)) as P;
    case 21:
      return (reader.readBool(offset)) as P;
    case 22:
      return (reader.readStringOrNull(offset)) as P;
    case 23:
      return (reader.readStringOrNull(offset)) as P;
    case 24:
      return (reader.readLongOrNull(offset)) as P;
    case 25:
      return (reader.readLongOrNull(offset)) as P;
    case 26:
      return (reader.readStringOrNull(offset)) as P;
    case 27:
      return (reader.readString(offset)) as P;
    case 28:
      return (reader.readLongOrNull(offset)) as P;
    case 29:
      return (reader.readLongOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _songEntityGetId(SongEntity object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _songEntityGetLinks(SongEntity object) {
  return [];
}

void _songEntityAttach(IsarCollection<dynamic> col, Id id, SongEntity object) {
  object.id = id;
}

extension SongEntityByIndex on IsarCollection<SongEntity> {
  Future<SongEntity?> getByFilePathStartOffsetMs(
    String filePath,
    int? startOffsetMs,
  ) {
    return getByIndex(r'filePath_startOffsetMs', [filePath, startOffsetMs]);
  }

  SongEntity? getByFilePathStartOffsetMsSync(
    String filePath,
    int? startOffsetMs,
  ) {
    return getByIndexSync(r'filePath_startOffsetMs', [filePath, startOffsetMs]);
  }

  Future<bool> deleteByFilePathStartOffsetMs(
    String filePath,
    int? startOffsetMs,
  ) {
    return deleteByIndex(r'filePath_startOffsetMs', [filePath, startOffsetMs]);
  }

  bool deleteByFilePathStartOffsetMsSync(String filePath, int? startOffsetMs) {
    return deleteByIndexSync(r'filePath_startOffsetMs', [
      filePath,
      startOffsetMs,
    ]);
  }

  Future<List<SongEntity?>> getAllByFilePathStartOffsetMs(
    List<String> filePathValues,
    List<int?> startOffsetMsValues,
  ) {
    final len = filePathValues.length;
    assert(
      startOffsetMsValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([filePathValues[i], startOffsetMsValues[i]]);
    }

    return getAllByIndex(r'filePath_startOffsetMs', values);
  }

  List<SongEntity?> getAllByFilePathStartOffsetMsSync(
    List<String> filePathValues,
    List<int?> startOffsetMsValues,
  ) {
    final len = filePathValues.length;
    assert(
      startOffsetMsValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([filePathValues[i], startOffsetMsValues[i]]);
    }

    return getAllByIndexSync(r'filePath_startOffsetMs', values);
  }

  Future<int> deleteAllByFilePathStartOffsetMs(
    List<String> filePathValues,
    List<int?> startOffsetMsValues,
  ) {
    final len = filePathValues.length;
    assert(
      startOffsetMsValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([filePathValues[i], startOffsetMsValues[i]]);
    }

    return deleteAllByIndex(r'filePath_startOffsetMs', values);
  }

  int deleteAllByFilePathStartOffsetMsSync(
    List<String> filePathValues,
    List<int?> startOffsetMsValues,
  ) {
    final len = filePathValues.length;
    assert(
      startOffsetMsValues.length == len,
      'All index values must have the same length',
    );
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([filePathValues[i], startOffsetMsValues[i]]);
    }

    return deleteAllByIndexSync(r'filePath_startOffsetMs', values);
  }

  Future<Id> putByFilePathStartOffsetMs(SongEntity object) {
    return putByIndex(r'filePath_startOffsetMs', object);
  }

  Id putByFilePathStartOffsetMsSync(
    SongEntity object, {
    bool saveLinks = true,
  }) {
    return putByIndexSync(
      r'filePath_startOffsetMs',
      object,
      saveLinks: saveLinks,
    );
  }

  Future<List<Id>> putAllByFilePathStartOffsetMs(List<SongEntity> objects) {
    return putAllByIndex(r'filePath_startOffsetMs', objects);
  }

  List<Id> putAllByFilePathStartOffsetMsSync(
    List<SongEntity> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(
      r'filePath_startOffsetMs',
      objects,
      saveLinks: saveLinks,
    );
  }
}

extension SongEntityQueryWhereSort
    on QueryBuilder<SongEntity, SongEntity, QWhere> {
  QueryBuilder<SongEntity, SongEntity, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterWhere> anyDateAdded() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'dateAdded'),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterWhere> anyLastModified() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'lastModified'),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterWhere> anyMetadataComplete() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'metadataComplete'),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterWhere> anyHasLocalEdits() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'hasLocalEdits'),
      );
    });
  }
}

extension SongEntityQueryWhere
    on QueryBuilder<SongEntity, SongEntity, QWhereClause> {
  QueryBuilder<SongEntity, SongEntity, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterWhereClause> idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterWhereClause>
  filePathEqualToAnyStartOffsetMs(String filePath) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'filePath_startOffsetMs',
          value: [filePath],
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterWhereClause>
  filePathNotEqualToAnyStartOffsetMs(String filePath) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'filePath_startOffsetMs',
                lower: [],
                upper: [filePath],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'filePath_startOffsetMs',
                lower: [filePath],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'filePath_startOffsetMs',
                lower: [filePath],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'filePath_startOffsetMs',
                lower: [],
                upper: [filePath],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterWhereClause>
  filePathEqualToStartOffsetMsIsNull(String filePath) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'filePath_startOffsetMs',
          value: [filePath, null],
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterWhereClause>
  filePathEqualToStartOffsetMsIsNotNull(String filePath) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'filePath_startOffsetMs',
          lower: [filePath, null],
          includeLower: false,
          upper: [filePath],
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterWhereClause>
  filePathStartOffsetMsEqualTo(String filePath, int? startOffsetMs) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'filePath_startOffsetMs',
          value: [filePath, startOffsetMs],
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterWhereClause>
  filePathEqualToStartOffsetMsNotEqualTo(String filePath, int? startOffsetMs) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'filePath_startOffsetMs',
                lower: [filePath],
                upper: [filePath, startOffsetMs],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'filePath_startOffsetMs',
                lower: [filePath, startOffsetMs],
                includeLower: false,
                upper: [filePath],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'filePath_startOffsetMs',
                lower: [filePath, startOffsetMs],
                includeLower: false,
                upper: [filePath],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'filePath_startOffsetMs',
                lower: [filePath],
                upper: [filePath, startOffsetMs],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterWhereClause>
  filePathEqualToStartOffsetMsGreaterThan(
    String filePath,
    int? startOffsetMs, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'filePath_startOffsetMs',
          lower: [filePath, startOffsetMs],
          includeLower: include,
          upper: [filePath],
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterWhereClause>
  filePathEqualToStartOffsetMsLessThan(
    String filePath,
    int? startOffsetMs, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'filePath_startOffsetMs',
          lower: [filePath],
          upper: [filePath, startOffsetMs],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterWhereClause>
  filePathEqualToStartOffsetMsBetween(
    String filePath,
    int? lowerStartOffsetMs,
    int? upperStartOffsetMs, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'filePath_startOffsetMs',
          lower: [filePath, lowerStartOffsetMs],
          includeLower: includeLower,
          upper: [filePath, upperStartOffsetMs],
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterWhereClause>
  mediaStoreUriIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'mediaStoreUri', value: [null]),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterWhereClause>
  mediaStoreUriIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'mediaStoreUri',
          lower: [null],
          includeLower: false,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterWhereClause> mediaStoreUriEqualTo(
    String? mediaStoreUri,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'mediaStoreUri',
          value: [mediaStoreUri],
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterWhereClause>
  mediaStoreUriNotEqualTo(String? mediaStoreUri) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'mediaStoreUri',
                lower: [],
                upper: [mediaStoreUri],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'mediaStoreUri',
                lower: [mediaStoreUri],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'mediaStoreUri',
                lower: [mediaStoreUri],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'mediaStoreUri',
                lower: [],
                upper: [mediaStoreUri],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterWhereClause> titleEqualTo(
    String title,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'title', value: [title]),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterWhereClause> titleNotEqualTo(
    String title,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'title',
                lower: [],
                upper: [title],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'title',
                lower: [title],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'title',
                lower: [title],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'title',
                lower: [],
                upper: [title],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterWhereClause> folderUriIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'folderUri', value: [null]),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterWhereClause> folderUriIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'folderUri',
          lower: [null],
          includeLower: false,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterWhereClause> folderUriEqualTo(
    String? folderUri,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'folderUri', value: [folderUri]),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterWhereClause> folderUriNotEqualTo(
    String? folderUri,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'folderUri',
                lower: [],
                upper: [folderUri],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'folderUri',
                lower: [folderUri],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'folderUri',
                lower: [folderUri],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'folderUri',
                lower: [],
                upper: [folderUri],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterWhereClause> dateAddedEqualTo(
    DateTime dateAdded,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'dateAdded', value: [dateAdded]),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterWhereClause> dateAddedNotEqualTo(
    DateTime dateAdded,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'dateAdded',
                lower: [],
                upper: [dateAdded],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'dateAdded',
                lower: [dateAdded],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'dateAdded',
                lower: [dateAdded],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'dateAdded',
                lower: [],
                upper: [dateAdded],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterWhereClause> dateAddedGreaterThan(
    DateTime dateAdded, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'dateAdded',
          lower: [dateAdded],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterWhereClause> dateAddedLessThan(
    DateTime dateAdded, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'dateAdded',
          lower: [],
          upper: [dateAdded],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterWhereClause> dateAddedBetween(
    DateTime lowerDateAdded,
    DateTime upperDateAdded, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'dateAdded',
          lower: [lowerDateAdded],
          includeLower: includeLower,
          upper: [upperDateAdded],
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterWhereClause> lastModifiedIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'lastModified', value: [null]),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterWhereClause>
  lastModifiedIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'lastModified',
          lower: [null],
          includeLower: false,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterWhereClause> lastModifiedEqualTo(
    DateTime? lastModified,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'lastModified',
          value: [lastModified],
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterWhereClause>
  lastModifiedNotEqualTo(DateTime? lastModified) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'lastModified',
                lower: [],
                upper: [lastModified],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'lastModified',
                lower: [lastModified],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'lastModified',
                lower: [lastModified],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'lastModified',
                lower: [],
                upper: [lastModified],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterWhereClause>
  lastModifiedGreaterThan(DateTime? lastModified, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'lastModified',
          lower: [lastModified],
          includeLower: include,
          upper: [],
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterWhereClause> lastModifiedLessThan(
    DateTime? lastModified, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'lastModified',
          lower: [],
          upper: [lastModified],
          includeUpper: include,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterWhereClause> lastModifiedBetween(
    DateTime? lowerLastModified,
    DateTime? upperLastModified, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.between(
          indexName: r'lastModified',
          lower: [lowerLastModified],
          includeLower: includeLower,
          upper: [upperLastModified],
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterWhereClause>
  metadataCompleteEqualTo(bool metadataComplete) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'metadataComplete',
          value: [metadataComplete],
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterWhereClause>
  metadataCompleteNotEqualTo(bool metadataComplete) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'metadataComplete',
                lower: [],
                upper: [metadataComplete],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'metadataComplete',
                lower: [metadataComplete],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'metadataComplete',
                lower: [metadataComplete],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'metadataComplete',
                lower: [],
                upper: [metadataComplete],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterWhereClause> hasLocalEditsEqualTo(
    bool hasLocalEdits,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(
          indexName: r'hasLocalEdits',
          value: [hasLocalEdits],
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterWhereClause>
  hasLocalEditsNotEqualTo(bool hasLocalEdits) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'hasLocalEdits',
                lower: [],
                upper: [hasLocalEdits],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'hasLocalEdits',
                lower: [hasLocalEdits],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'hasLocalEdits',
                lower: [hasLocalEdits],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'hasLocalEdits',
                lower: [],
                upper: [hasLocalEdits],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension SongEntityQueryFilter
    on QueryBuilder<SongEntity, SongEntity, QFilterCondition> {
  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  accurateRipIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'accurateRip'),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  accurateRipIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'accurateRip'),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  accurateRipEqualTo(bool? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'accurateRip', value: value),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> albumIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'album'),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> albumIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'album'),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> albumEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'album',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> albumGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'album',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> albumLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'album',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> albumBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'album',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> albumStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'album',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> albumEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'album',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> albumContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'album',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> albumMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'album',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> albumIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'album', value: ''),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  albumIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'album', value: ''),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  albumArtPathIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'albumArtPath'),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  albumArtPathIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'albumArtPath'),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  albumArtPathEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'albumArtPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  albumArtPathGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'albumArtPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  albumArtPathLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'albumArtPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  albumArtPathBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'albumArtPath',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  albumArtPathStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'albumArtPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  albumArtPathEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'albumArtPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  albumArtPathContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'albumArtPath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  albumArtPathMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'albumArtPath',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  albumArtPathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'albumArtPath', value: ''),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  albumArtPathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'albumArtPath', value: ''),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  albumArtistIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'albumArtist'),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  albumArtistIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'albumArtist'),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  albumArtistEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'albumArtist',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  albumArtistGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'albumArtist',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  albumArtistLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'albumArtist',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  albumArtistBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'albumArtist',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  albumArtistStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'albumArtist',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  albumArtistEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'albumArtist',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  albumArtistContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'albumArtist',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  albumArtistMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'albumArtist',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  albumArtistIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'albumArtist', value: ''),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  albumArtistIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'albumArtist', value: ''),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> artistEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'artist',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> artistGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'artist',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> artistLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'artist',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> artistBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'artist',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> artistStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'artist',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> artistEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'artist',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> artistContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'artist',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> artistMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'artist',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> artistIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'artist', value: ''),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  artistIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'artist', value: ''),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> bitDepthIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'bitDepth'),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  bitDepthIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'bitDepth'),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> bitDepthEqualTo(
    int? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'bitDepth', value: value),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  bitDepthGreaterThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'bitDepth',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> bitDepthLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'bitDepth',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> bitDepthBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'bitDepth',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> bitrateIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'bitrate'),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  bitrateIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'bitrate'),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> bitrateEqualTo(
    int? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'bitrate', value: value),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  bitrateGreaterThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'bitrate',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> bitrateLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'bitrate',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> bitrateBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'bitrate',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> channelsIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'channels'),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  channelsIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'channels'),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> channelsEqualTo(
    int? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'channels', value: value),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  channelsGreaterThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'channels',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> channelsLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'channels',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> channelsBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'channels',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> copyCrcIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'copyCrc'),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  copyCrcIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'copyCrc'),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> copyCrcEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'copyCrc',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  copyCrcGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'copyCrc',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> copyCrcLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'copyCrc',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> copyCrcBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'copyCrc',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> copyCrcStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'copyCrc',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> copyCrcEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'copyCrc',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> copyCrcContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'copyCrc',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> copyCrcMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'copyCrc',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> copyCrcIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'copyCrc', value: ''),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  copyCrcIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'copyCrc', value: ''),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> dateAddedEqualTo(
    DateTime value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'dateAdded', value: value),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  dateAddedGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'dateAdded',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> dateAddedLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'dateAdded',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> dateAddedBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'dateAdded',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  discNumberIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'discNumber'),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  discNumberIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'discNumber'),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> discNumberEqualTo(
    int? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'discNumber', value: value),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  discNumberGreaterThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'discNumber',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  discNumberLessThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'discNumber',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> discNumberBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'discNumber',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  durationMsIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'durationMs'),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  durationMsIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'durationMs'),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> durationMsEqualTo(
    int? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'durationMs', value: value),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  durationMsGreaterThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'durationMs',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  durationMsLessThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'durationMs',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> durationMsBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'durationMs',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  endOffsetMsIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'endOffsetMs'),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  endOffsetMsIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'endOffsetMs'),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  endOffsetMsEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'endOffsetMs', value: value),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  endOffsetMsGreaterThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'endOffsetMs',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  endOffsetMsLessThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'endOffsetMs',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  endOffsetMsBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'endOffsetMs',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> filePathEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'filePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  filePathGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'filePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> filePathLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'filePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> filePathBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'filePath',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  filePathStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'filePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> filePathEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'filePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> filePathContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'filePath',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> filePathMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'filePath',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  filePathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'filePath', value: ''),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  filePathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'filePath', value: ''),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> fileSizeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'fileSize'),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  fileSizeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'fileSize'),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> fileSizeEqualTo(
    int? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'fileSize', value: value),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  fileSizeGreaterThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'fileSize',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> fileSizeLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'fileSize',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> fileSizeBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'fileSize',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> fileTypeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'fileType'),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  fileTypeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'fileType'),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> fileTypeEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'fileType',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  fileTypeGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'fileType',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> fileTypeLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'fileType',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> fileTypeBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'fileType',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  fileTypeStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'fileType',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> fileTypeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'fileType',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> fileTypeContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'fileType',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> fileTypeMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'fileType',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  fileTypeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'fileType', value: ''),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  fileTypeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'fileType', value: ''),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  folderUriIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'folderUri'),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  folderUriIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'folderUri'),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> folderUriEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'folderUri',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  folderUriGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'folderUri',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> folderUriLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'folderUri',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> folderUriBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'folderUri',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  folderUriStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'folderUri',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> folderUriEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'folderUri',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> folderUriContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'folderUri',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> folderUriMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'folderUri',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  folderUriIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'folderUri', value: ''),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  folderUriIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'folderUri', value: ''),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> genreIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'genre'),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> genreIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'genre'),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> genreEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'genre',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> genreGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'genre',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> genreLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'genre',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> genreBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'genre',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> genreStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'genre',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> genreEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'genre',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> genreContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'genre',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> genreMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'genre',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> genreIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'genre', value: ''),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  genreIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'genre', value: ''),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  hasLocalEditsEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'hasLocalEdits', value: value),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> idEqualTo(
    Id value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  lastModifiedIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'lastModified'),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  lastModifiedIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'lastModified'),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  lastModifiedEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'lastModified', value: value),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  lastModifiedGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'lastModified',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  lastModifiedLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'lastModified',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  lastModifiedBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'lastModified',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  mediaStoreUriIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'mediaStoreUri'),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  mediaStoreUriIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'mediaStoreUri'),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  mediaStoreUriEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'mediaStoreUri',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  mediaStoreUriGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'mediaStoreUri',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  mediaStoreUriLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'mediaStoreUri',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  mediaStoreUriBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'mediaStoreUri',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  mediaStoreUriStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'mediaStoreUri',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  mediaStoreUriEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'mediaStoreUri',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  mediaStoreUriContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'mediaStoreUri',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  mediaStoreUriMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'mediaStoreUri',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  mediaStoreUriIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'mediaStoreUri', value: ''),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  mediaStoreUriIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'mediaStoreUri', value: ''),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  metadataCompleteEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'metadataComplete', value: value),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> readModeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'readMode'),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  readModeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'readMode'),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> readModeEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'readMode',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  readModeGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'readMode',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> readModeLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'readMode',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> readModeBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'readMode',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  readModeStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'readMode',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> readModeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'readMode',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> readModeContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'readMode',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> readModeMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'readMode',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  readModeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'readMode', value: ''),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  readModeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'readMode', value: ''),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> ripperIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'ripper'),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  ripperIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'ripper'),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> ripperEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'ripper',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> ripperGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'ripper',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> ripperLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'ripper',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> ripperBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'ripper',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> ripperStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'ripper',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> ripperEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'ripper',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> ripperContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'ripper',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> ripperMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'ripper',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> ripperIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'ripper', value: ''),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  ripperIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'ripper', value: ''),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  sampleRateIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'sampleRate'),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  sampleRateIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'sampleRate'),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> sampleRateEqualTo(
    int? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'sampleRate', value: value),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  sampleRateGreaterThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'sampleRate',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  sampleRateLessThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'sampleRate',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> sampleRateBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'sampleRate',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  startOffsetMsIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'startOffsetMs'),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  startOffsetMsIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'startOffsetMs'),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  startOffsetMsEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'startOffsetMs', value: value),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  startOffsetMsGreaterThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'startOffsetMs',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  startOffsetMsLessThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'startOffsetMs',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  startOffsetMsBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'startOffsetMs',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> testCrcIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'testCrc'),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  testCrcIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'testCrc'),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> testCrcEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'testCrc',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  testCrcGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'testCrc',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> testCrcLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'testCrc',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> testCrcBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'testCrc',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> testCrcStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'testCrc',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> testCrcEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'testCrc',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> testCrcContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'testCrc',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> testCrcMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'testCrc',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> testCrcIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'testCrc', value: ''),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  testCrcIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'testCrc', value: ''),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> titleEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> titleGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> titleLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> titleBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'title',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> titleStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> titleEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> titleContains(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'title',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> titleMatches(
    String pattern, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'title',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> titleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'title', value: ''),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  titleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'title', value: ''),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  trackNumberIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'trackNumber'),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  trackNumberIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'trackNumber'),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  trackNumberEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'trackNumber', value: value),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  trackNumberGreaterThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'trackNumber',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  trackNumberLessThan(int? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'trackNumber',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition>
  trackNumberBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'trackNumber',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> yearIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'year'),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> yearIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'year'),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> yearEqualTo(
    int? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'year', value: value),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> yearGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'year',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> yearLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'year',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterFilterCondition> yearBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'year',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }
}

extension SongEntityQueryObject
    on QueryBuilder<SongEntity, SongEntity, QFilterCondition> {}

extension SongEntityQueryLinks
    on QueryBuilder<SongEntity, SongEntity, QFilterCondition> {}

extension SongEntityQuerySortBy
    on QueryBuilder<SongEntity, SongEntity, QSortBy> {
  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> sortByAccurateRip() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'accurateRip', Sort.asc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> sortByAccurateRipDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'accurateRip', Sort.desc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> sortByAlbum() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'album', Sort.asc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> sortByAlbumDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'album', Sort.desc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> sortByAlbumArtPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'albumArtPath', Sort.asc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> sortByAlbumArtPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'albumArtPath', Sort.desc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> sortByAlbumArtist() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'albumArtist', Sort.asc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> sortByAlbumArtistDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'albumArtist', Sort.desc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> sortByArtist() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'artist', Sort.asc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> sortByArtistDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'artist', Sort.desc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> sortByBitDepth() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bitDepth', Sort.asc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> sortByBitDepthDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bitDepth', Sort.desc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> sortByBitrate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bitrate', Sort.asc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> sortByBitrateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bitrate', Sort.desc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> sortByChannels() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'channels', Sort.asc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> sortByChannelsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'channels', Sort.desc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> sortByCopyCrc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'copyCrc', Sort.asc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> sortByCopyCrcDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'copyCrc', Sort.desc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> sortByDateAdded() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dateAdded', Sort.asc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> sortByDateAddedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dateAdded', Sort.desc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> sortByDiscNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'discNumber', Sort.asc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> sortByDiscNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'discNumber', Sort.desc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> sortByDurationMs() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'durationMs', Sort.asc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> sortByDurationMsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'durationMs', Sort.desc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> sortByEndOffsetMs() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'endOffsetMs', Sort.asc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> sortByEndOffsetMsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'endOffsetMs', Sort.desc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> sortByFilePath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'filePath', Sort.asc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> sortByFilePathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'filePath', Sort.desc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> sortByFileSize() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fileSize', Sort.asc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> sortByFileSizeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fileSize', Sort.desc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> sortByFileType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fileType', Sort.asc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> sortByFileTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fileType', Sort.desc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> sortByFolderUri() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'folderUri', Sort.asc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> sortByFolderUriDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'folderUri', Sort.desc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> sortByGenre() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'genre', Sort.asc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> sortByGenreDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'genre', Sort.desc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> sortByHasLocalEdits() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hasLocalEdits', Sort.asc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> sortByHasLocalEditsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hasLocalEdits', Sort.desc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> sortByLastModified() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastModified', Sort.asc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> sortByLastModifiedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastModified', Sort.desc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> sortByMediaStoreUri() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mediaStoreUri', Sort.asc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> sortByMediaStoreUriDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mediaStoreUri', Sort.desc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> sortByMetadataComplete() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadataComplete', Sort.asc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy>
  sortByMetadataCompleteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadataComplete', Sort.desc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> sortByReadMode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'readMode', Sort.asc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> sortByReadModeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'readMode', Sort.desc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> sortByRipper() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ripper', Sort.asc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> sortByRipperDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ripper', Sort.desc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> sortBySampleRate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sampleRate', Sort.asc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> sortBySampleRateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sampleRate', Sort.desc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> sortByStartOffsetMs() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startOffsetMs', Sort.asc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> sortByStartOffsetMsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startOffsetMs', Sort.desc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> sortByTestCrc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'testCrc', Sort.asc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> sortByTestCrcDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'testCrc', Sort.desc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> sortByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> sortByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> sortByTrackNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'trackNumber', Sort.asc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> sortByTrackNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'trackNumber', Sort.desc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> sortByYear() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'year', Sort.asc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> sortByYearDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'year', Sort.desc);
    });
  }
}

extension SongEntityQuerySortThenBy
    on QueryBuilder<SongEntity, SongEntity, QSortThenBy> {
  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> thenByAccurateRip() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'accurateRip', Sort.asc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> thenByAccurateRipDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'accurateRip', Sort.desc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> thenByAlbum() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'album', Sort.asc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> thenByAlbumDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'album', Sort.desc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> thenByAlbumArtPath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'albumArtPath', Sort.asc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> thenByAlbumArtPathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'albumArtPath', Sort.desc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> thenByAlbumArtist() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'albumArtist', Sort.asc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> thenByAlbumArtistDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'albumArtist', Sort.desc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> thenByArtist() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'artist', Sort.asc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> thenByArtistDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'artist', Sort.desc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> thenByBitDepth() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bitDepth', Sort.asc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> thenByBitDepthDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bitDepth', Sort.desc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> thenByBitrate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bitrate', Sort.asc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> thenByBitrateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bitrate', Sort.desc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> thenByChannels() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'channels', Sort.asc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> thenByChannelsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'channels', Sort.desc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> thenByCopyCrc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'copyCrc', Sort.asc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> thenByCopyCrcDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'copyCrc', Sort.desc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> thenByDateAdded() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dateAdded', Sort.asc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> thenByDateAddedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dateAdded', Sort.desc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> thenByDiscNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'discNumber', Sort.asc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> thenByDiscNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'discNumber', Sort.desc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> thenByDurationMs() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'durationMs', Sort.asc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> thenByDurationMsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'durationMs', Sort.desc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> thenByEndOffsetMs() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'endOffsetMs', Sort.asc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> thenByEndOffsetMsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'endOffsetMs', Sort.desc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> thenByFilePath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'filePath', Sort.asc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> thenByFilePathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'filePath', Sort.desc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> thenByFileSize() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fileSize', Sort.asc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> thenByFileSizeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fileSize', Sort.desc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> thenByFileType() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fileType', Sort.asc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> thenByFileTypeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fileType', Sort.desc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> thenByFolderUri() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'folderUri', Sort.asc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> thenByFolderUriDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'folderUri', Sort.desc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> thenByGenre() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'genre', Sort.asc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> thenByGenreDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'genre', Sort.desc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> thenByHasLocalEdits() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hasLocalEdits', Sort.asc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> thenByHasLocalEditsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'hasLocalEdits', Sort.desc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> thenByLastModified() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastModified', Sort.asc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> thenByLastModifiedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastModified', Sort.desc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> thenByMediaStoreUri() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mediaStoreUri', Sort.asc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> thenByMediaStoreUriDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'mediaStoreUri', Sort.desc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> thenByMetadataComplete() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadataComplete', Sort.asc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy>
  thenByMetadataCompleteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'metadataComplete', Sort.desc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> thenByReadMode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'readMode', Sort.asc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> thenByReadModeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'readMode', Sort.desc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> thenByRipper() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ripper', Sort.asc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> thenByRipperDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'ripper', Sort.desc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> thenBySampleRate() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sampleRate', Sort.asc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> thenBySampleRateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sampleRate', Sort.desc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> thenByStartOffsetMs() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startOffsetMs', Sort.asc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> thenByStartOffsetMsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'startOffsetMs', Sort.desc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> thenByTestCrc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'testCrc', Sort.asc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> thenByTestCrcDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'testCrc', Sort.desc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> thenByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> thenByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> thenByTrackNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'trackNumber', Sort.asc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> thenByTrackNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'trackNumber', Sort.desc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> thenByYear() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'year', Sort.asc);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QAfterSortBy> thenByYearDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'year', Sort.desc);
    });
  }
}

extension SongEntityQueryWhereDistinct
    on QueryBuilder<SongEntity, SongEntity, QDistinct> {
  QueryBuilder<SongEntity, SongEntity, QDistinct> distinctByAccurateRip() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'accurateRip');
    });
  }

  QueryBuilder<SongEntity, SongEntity, QDistinct> distinctByAlbum({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'album', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QDistinct> distinctByAlbumArtPath({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'albumArtPath', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QDistinct> distinctByAlbumArtist({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'albumArtist', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QDistinct> distinctByArtist({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'artist', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QDistinct> distinctByBitDepth() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'bitDepth');
    });
  }

  QueryBuilder<SongEntity, SongEntity, QDistinct> distinctByBitrate() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'bitrate');
    });
  }

  QueryBuilder<SongEntity, SongEntity, QDistinct> distinctByChannels() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'channels');
    });
  }

  QueryBuilder<SongEntity, SongEntity, QDistinct> distinctByCopyCrc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'copyCrc', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QDistinct> distinctByDateAdded() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'dateAdded');
    });
  }

  QueryBuilder<SongEntity, SongEntity, QDistinct> distinctByDiscNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'discNumber');
    });
  }

  QueryBuilder<SongEntity, SongEntity, QDistinct> distinctByDurationMs() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'durationMs');
    });
  }

  QueryBuilder<SongEntity, SongEntity, QDistinct> distinctByEndOffsetMs() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'endOffsetMs');
    });
  }

  QueryBuilder<SongEntity, SongEntity, QDistinct> distinctByFilePath({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'filePath', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QDistinct> distinctByFileSize() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'fileSize');
    });
  }

  QueryBuilder<SongEntity, SongEntity, QDistinct> distinctByFileType({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'fileType', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QDistinct> distinctByFolderUri({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'folderUri', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QDistinct> distinctByGenre({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'genre', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QDistinct> distinctByHasLocalEdits() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'hasLocalEdits');
    });
  }

  QueryBuilder<SongEntity, SongEntity, QDistinct> distinctByLastModified() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastModified');
    });
  }

  QueryBuilder<SongEntity, SongEntity, QDistinct> distinctByMediaStoreUri({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(
        r'mediaStoreUri',
        caseSensitive: caseSensitive,
      );
    });
  }

  QueryBuilder<SongEntity, SongEntity, QDistinct> distinctByMetadataComplete() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'metadataComplete');
    });
  }

  QueryBuilder<SongEntity, SongEntity, QDistinct> distinctByReadMode({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'readMode', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QDistinct> distinctByRipper({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'ripper', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QDistinct> distinctBySampleRate() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sampleRate');
    });
  }

  QueryBuilder<SongEntity, SongEntity, QDistinct> distinctByStartOffsetMs() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'startOffsetMs');
    });
  }

  QueryBuilder<SongEntity, SongEntity, QDistinct> distinctByTestCrc({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'testCrc', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QDistinct> distinctByTitle({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'title', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SongEntity, SongEntity, QDistinct> distinctByTrackNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'trackNumber');
    });
  }

  QueryBuilder<SongEntity, SongEntity, QDistinct> distinctByYear() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'year');
    });
  }
}

extension SongEntityQueryProperty
    on QueryBuilder<SongEntity, SongEntity, QQueryProperty> {
  QueryBuilder<SongEntity, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<SongEntity, bool?, QQueryOperations> accurateRipProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'accurateRip');
    });
  }

  QueryBuilder<SongEntity, String?, QQueryOperations> albumProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'album');
    });
  }

  QueryBuilder<SongEntity, String?, QQueryOperations> albumArtPathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'albumArtPath');
    });
  }

  QueryBuilder<SongEntity, String?, QQueryOperations> albumArtistProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'albumArtist');
    });
  }

  QueryBuilder<SongEntity, String, QQueryOperations> artistProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'artist');
    });
  }

  QueryBuilder<SongEntity, int?, QQueryOperations> bitDepthProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'bitDepth');
    });
  }

  QueryBuilder<SongEntity, int?, QQueryOperations> bitrateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'bitrate');
    });
  }

  QueryBuilder<SongEntity, int?, QQueryOperations> channelsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'channels');
    });
  }

  QueryBuilder<SongEntity, String?, QQueryOperations> copyCrcProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'copyCrc');
    });
  }

  QueryBuilder<SongEntity, DateTime, QQueryOperations> dateAddedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'dateAdded');
    });
  }

  QueryBuilder<SongEntity, int?, QQueryOperations> discNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'discNumber');
    });
  }

  QueryBuilder<SongEntity, int?, QQueryOperations> durationMsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'durationMs');
    });
  }

  QueryBuilder<SongEntity, int?, QQueryOperations> endOffsetMsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'endOffsetMs');
    });
  }

  QueryBuilder<SongEntity, String, QQueryOperations> filePathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'filePath');
    });
  }

  QueryBuilder<SongEntity, int?, QQueryOperations> fileSizeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'fileSize');
    });
  }

  QueryBuilder<SongEntity, String?, QQueryOperations> fileTypeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'fileType');
    });
  }

  QueryBuilder<SongEntity, String?, QQueryOperations> folderUriProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'folderUri');
    });
  }

  QueryBuilder<SongEntity, String?, QQueryOperations> genreProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'genre');
    });
  }

  QueryBuilder<SongEntity, bool, QQueryOperations> hasLocalEditsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'hasLocalEdits');
    });
  }

  QueryBuilder<SongEntity, DateTime?, QQueryOperations> lastModifiedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastModified');
    });
  }

  QueryBuilder<SongEntity, String?, QQueryOperations> mediaStoreUriProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'mediaStoreUri');
    });
  }

  QueryBuilder<SongEntity, bool, QQueryOperations> metadataCompleteProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'metadataComplete');
    });
  }

  QueryBuilder<SongEntity, String?, QQueryOperations> readModeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'readMode');
    });
  }

  QueryBuilder<SongEntity, String?, QQueryOperations> ripperProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'ripper');
    });
  }

  QueryBuilder<SongEntity, int?, QQueryOperations> sampleRateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sampleRate');
    });
  }

  QueryBuilder<SongEntity, int?, QQueryOperations> startOffsetMsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'startOffsetMs');
    });
  }

  QueryBuilder<SongEntity, String?, QQueryOperations> testCrcProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'testCrc');
    });
  }

  QueryBuilder<SongEntity, String, QQueryOperations> titleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'title');
    });
  }

  QueryBuilder<SongEntity, int?, QQueryOperations> trackNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'trackNumber');
    });
  }

  QueryBuilder<SongEntity, int?, QQueryOperations> yearProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'year');
    });
  }
}
