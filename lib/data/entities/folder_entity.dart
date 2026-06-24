import 'package:isar_community/isar.dart';

part 'folder_entity.g.dart';

/// Database entity for storing watched music folders.
@collection
class FolderEntity {
  Id id = Isar.autoIncrement;

  /// Content URI for the folder (SAF tree URI)
  @Index(unique: true)
  late String uri;

  /// Display name of the folder
  late String displayName;

  /// Date the folder was added to the library
  late DateTime dateAdded;

  /// Last time the folder was scanned
  DateTime? lastScanned;

  /// Number of songs found in this folder
  int songCount = 0;

  /// Per-folder deep scan override.
  /// null = use global default, true = always deep scan, false = never deep scan.
  bool? useDeepScan;

  /// Whether this folder lives on removable storage (USB/SD).
  bool? isRemovable;

  /// MediaStore volume name to target for this folder (null = default external).
  String? mediaStoreVolume;

  /// Last known mount state of the volume ("mounted", "unmounted", "unknown").
  String? volumeState;
}
