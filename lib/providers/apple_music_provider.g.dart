// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'apple_music_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(appleMusicMetadataService)
final appleMusicMetadataServiceProvider = AppleMusicMetadataServiceProvider._();

final class AppleMusicMetadataServiceProvider
    extends
        $FunctionalProvider<
          AppleMusicMetadataService,
          AppleMusicMetadataService,
          AppleMusicMetadataService
        >
    with $Provider<AppleMusicMetadataService> {
  AppleMusicMetadataServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appleMusicMetadataServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appleMusicMetadataServiceHash();

  @$internal
  @override
  $ProviderElement<AppleMusicMetadataService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AppleMusicMetadataService create(Ref ref) {
    return appleMusicMetadataService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppleMusicMetadataService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppleMusicMetadataService>(value),
    );
  }
}

String _$appleMusicMetadataServiceHash() =>
    r'2ba21aa8053b9fe91c8c014b245bebf32b2a3dab';

/// Apple Music metadata for an artist page. Auto-disposes when the page
/// closes; durable caching lives in [AppleMusicMetadataService].

@ProviderFor(AppleMusicArtistNotifier)
final appleMusicArtistProvider = AppleMusicArtistNotifierFamily._();

/// Apple Music metadata for an artist page. Auto-disposes when the page
/// closes; durable caching lives in [AppleMusicMetadataService].
final class AppleMusicArtistNotifierProvider
    extends
        $AsyncNotifierProvider<
          AppleMusicArtistNotifier,
          AppleMusicArtistData?
        > {
  /// Apple Music metadata for an artist page. Auto-disposes when the page
  /// closes; durable caching lives in [AppleMusicMetadataService].
  AppleMusicArtistNotifierProvider._({
    required AppleMusicArtistNotifierFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'appleMusicArtistProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$appleMusicArtistNotifierHash();

  @override
  String toString() {
    return r'appleMusicArtistProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  AppleMusicArtistNotifier create() => AppleMusicArtistNotifier();

  @override
  bool operator ==(Object other) {
    return other is AppleMusicArtistNotifierProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$appleMusicArtistNotifierHash() =>
    r'8ac727b9403b1a687fffeda9de0f249d557e6743';

/// Apple Music metadata for an artist page. Auto-disposes when the page
/// closes; durable caching lives in [AppleMusicMetadataService].

final class AppleMusicArtistNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          AppleMusicArtistNotifier,
          AsyncValue<AppleMusicArtistData?>,
          AppleMusicArtistData?,
          FutureOr<AppleMusicArtistData?>,
          String
        > {
  AppleMusicArtistNotifierFamily._()
    : super(
        retry: null,
        name: r'appleMusicArtistProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Apple Music metadata for an artist page. Auto-disposes when the page
  /// closes; durable caching lives in [AppleMusicMetadataService].

  AppleMusicArtistNotifierProvider call(String artistName) =>
      AppleMusicArtistNotifierProvider._(argument: artistName, from: this);

  @override
  String toString() => r'appleMusicArtistProvider';
}

/// Apple Music metadata for an artist page. Auto-disposes when the page
/// closes; durable caching lives in [AppleMusicMetadataService].

abstract class _$AppleMusicArtistNotifier
    extends $AsyncNotifier<AppleMusicArtistData?> {
  late final _$args = ref.$arg as String;
  String get artistName => _$args;

  FutureOr<AppleMusicArtistData?> build(String artistName);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<AppleMusicArtistData?>, AppleMusicArtistData?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<AppleMusicArtistData?>,
                AppleMusicArtistData?
              >,
              AsyncValue<AppleMusicArtistData?>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}

/// Apple Music metadata for an album page, keyed by `(album, artist)`.

@ProviderFor(AppleMusicAlbumNotifier)
final appleMusicAlbumProvider = AppleMusicAlbumNotifierFamily._();

/// Apple Music metadata for an album page, keyed by `(album, artist)`.
final class AppleMusicAlbumNotifierProvider
    extends
        $AsyncNotifierProvider<AppleMusicAlbumNotifier, AppleMusicAlbumData?> {
  /// Apple Music metadata for an album page, keyed by `(album, artist)`.
  AppleMusicAlbumNotifierProvider._({
    required AppleMusicAlbumNotifierFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'appleMusicAlbumProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$appleMusicAlbumNotifierHash();

  @override
  String toString() {
    return r'appleMusicAlbumProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  AppleMusicAlbumNotifier create() => AppleMusicAlbumNotifier();

  @override
  bool operator ==(Object other) {
    return other is AppleMusicAlbumNotifierProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$appleMusicAlbumNotifierHash() =>
    r'0575473b3d0b18f286ea326914c98e96f832d90a';

/// Apple Music metadata for an album page, keyed by `(album, artist)`.

final class AppleMusicAlbumNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          AppleMusicAlbumNotifier,
          AsyncValue<AppleMusicAlbumData?>,
          AppleMusicAlbumData?,
          FutureOr<AppleMusicAlbumData?>,
          (String, String)
        > {
  AppleMusicAlbumNotifierFamily._()
    : super(
        retry: null,
        name: r'appleMusicAlbumProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Apple Music metadata for an album page, keyed by `(album, artist)`.

  AppleMusicAlbumNotifierProvider call((String, String) key) =>
      AppleMusicAlbumNotifierProvider._(argument: key, from: this);

  @override
  String toString() => r'appleMusicAlbumProvider';
}

/// Apple Music metadata for an album page, keyed by `(album, artist)`.

abstract class _$AppleMusicAlbumNotifier
    extends $AsyncNotifier<AppleMusicAlbumData?> {
  late final _$args = ref.$arg as (String, String);
  (String, String) get key => _$args;

  FutureOr<AppleMusicAlbumData?> build((String, String) key);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<AppleMusicAlbumData?>, AppleMusicAlbumData?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<AppleMusicAlbumData?>,
                AppleMusicAlbumData?
              >,
              AsyncValue<AppleMusicAlbumData?>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
