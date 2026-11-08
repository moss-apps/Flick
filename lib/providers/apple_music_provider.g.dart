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

@ProviderFor(appleMusicSettings)
final appleMusicSettingsProvider = AppleMusicSettingsProvider._();

final class AppleMusicSettingsProvider
    extends
        $FunctionalProvider<
          AppleMusicSettings,
          AppleMusicSettings,
          AppleMusicSettings
        >
    with $Provider<AppleMusicSettings> {
  AppleMusicSettingsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appleMusicSettingsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appleMusicSettingsHash();

  @$internal
  @override
  $ProviderElement<AppleMusicSettings> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AppleMusicSettings create(Ref ref) {
    return appleMusicSettings(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppleMusicSettings value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppleMusicSettings>(value),
    );
  }
}

String _$appleMusicSettingsHash() =>
    r'9503a051107dd9de72c031eed153abdaa98269f7';

/// Whether artist and album pages may load Apple Music page information.
/// Keep-alive so the persisted preference is read once and shared by every
/// open detail page and the settings toggle.

@ProviderFor(AppleMusicPageInfoEnabledNotifier)
final appleMusicPageInfoEnabledProvider =
    AppleMusicPageInfoEnabledNotifierProvider._();

/// Whether artist and album pages may load Apple Music page information.
/// Keep-alive so the persisted preference is read once and shared by every
/// open detail page and the settings toggle.
final class AppleMusicPageInfoEnabledNotifierProvider
    extends $AsyncNotifierProvider<AppleMusicPageInfoEnabledNotifier, bool> {
  /// Whether artist and album pages may load Apple Music page information.
  /// Keep-alive so the persisted preference is read once and shared by every
  /// open detail page and the settings toggle.
  AppleMusicPageInfoEnabledNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appleMusicPageInfoEnabledProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() =>
      _$appleMusicPageInfoEnabledNotifierHash();

  @$internal
  @override
  AppleMusicPageInfoEnabledNotifier create() =>
      AppleMusicPageInfoEnabledNotifier();
}

String _$appleMusicPageInfoEnabledNotifierHash() =>
    r'46b6964c43c7874f976f0eea5377dc9edcbd25ed';

/// Whether artist and album pages may load Apple Music page information.
/// Keep-alive so the persisted preference is read once and shared by every
/// open detail page and the settings toggle.

abstract class _$AppleMusicPageInfoEnabledNotifier
    extends $AsyncNotifier<bool> {
  FutureOr<bool> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<bool>, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<bool>, bool>,
              AsyncValue<bool>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

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
    r'b1e56596d9893d13855ba17ca517bf7e0c69a583';

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
    r'52f048d76d305e098089c2ea3d3d39b5cb2ac23a';

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
