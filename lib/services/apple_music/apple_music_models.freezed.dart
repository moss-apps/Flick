// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'apple_music_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AppleMusicArtist {

 String get artistId; String get name; String? get genre; String? get url;
/// Create a copy of AppleMusicArtist
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppleMusicArtistCopyWith<AppleMusicArtist> get copyWith => _$AppleMusicArtistCopyWithImpl<AppleMusicArtist>(this as AppleMusicArtist, _$identity);

  /// Serializes this AppleMusicArtist to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppleMusicArtist&&(identical(other.artistId, artistId) || other.artistId == artistId)&&(identical(other.name, name) || other.name == name)&&(identical(other.genre, genre) || other.genre == genre)&&(identical(other.url, url) || other.url == url));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,artistId,name,genre,url);

@override
String toString() {
  return 'AppleMusicArtist(artistId: $artistId, name: $name, genre: $genre, url: $url)';
}


}

/// @nodoc
abstract mixin class $AppleMusicArtistCopyWith<$Res>  {
  factory $AppleMusicArtistCopyWith(AppleMusicArtist value, $Res Function(AppleMusicArtist) _then) = _$AppleMusicArtistCopyWithImpl;
@useResult
$Res call({
 String artistId, String name, String? genre, String? url
});




}
/// @nodoc
class _$AppleMusicArtistCopyWithImpl<$Res>
    implements $AppleMusicArtistCopyWith<$Res> {
  _$AppleMusicArtistCopyWithImpl(this._self, this._then);

  final AppleMusicArtist _self;
  final $Res Function(AppleMusicArtist) _then;

/// Create a copy of AppleMusicArtist
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? artistId = null,Object? name = null,Object? genre = freezed,Object? url = freezed,}) {
  return _then(_self.copyWith(
artistId: null == artistId ? _self.artistId : artistId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,genre: freezed == genre ? _self.genre : genre // ignore: cast_nullable_to_non_nullable
as String?,url: freezed == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [AppleMusicArtist].
extension AppleMusicArtistPatterns on AppleMusicArtist {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AppleMusicArtist value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AppleMusicArtist() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AppleMusicArtist value)  $default,){
final _that = this;
switch (_that) {
case _AppleMusicArtist():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AppleMusicArtist value)?  $default,){
final _that = this;
switch (_that) {
case _AppleMusicArtist() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String artistId,  String name,  String? genre,  String? url)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AppleMusicArtist() when $default != null:
return $default(_that.artistId,_that.name,_that.genre,_that.url);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String artistId,  String name,  String? genre,  String? url)  $default,) {final _that = this;
switch (_that) {
case _AppleMusicArtist():
return $default(_that.artistId,_that.name,_that.genre,_that.url);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String artistId,  String name,  String? genre,  String? url)?  $default,) {final _that = this;
switch (_that) {
case _AppleMusicArtist() when $default != null:
return $default(_that.artistId,_that.name,_that.genre,_that.url);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AppleMusicArtist implements AppleMusicArtist {
  const _AppleMusicArtist({required this.artistId, required this.name, this.genre, this.url});
  factory _AppleMusicArtist.fromJson(Map<String, dynamic> json) => _$AppleMusicArtistFromJson(json);

@override final  String artistId;
@override final  String name;
@override final  String? genre;
@override final  String? url;

/// Create a copy of AppleMusicArtist
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AppleMusicArtistCopyWith<_AppleMusicArtist> get copyWith => __$AppleMusicArtistCopyWithImpl<_AppleMusicArtist>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AppleMusicArtistToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AppleMusicArtist&&(identical(other.artistId, artistId) || other.artistId == artistId)&&(identical(other.name, name) || other.name == name)&&(identical(other.genre, genre) || other.genre == genre)&&(identical(other.url, url) || other.url == url));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,artistId,name,genre,url);

@override
String toString() {
  return 'AppleMusicArtist(artistId: $artistId, name: $name, genre: $genre, url: $url)';
}


}

/// @nodoc
abstract mixin class _$AppleMusicArtistCopyWith<$Res> implements $AppleMusicArtistCopyWith<$Res> {
  factory _$AppleMusicArtistCopyWith(_AppleMusicArtist value, $Res Function(_AppleMusicArtist) _then) = __$AppleMusicArtistCopyWithImpl;
@override @useResult
$Res call({
 String artistId, String name, String? genre, String? url
});




}
/// @nodoc
class __$AppleMusicArtistCopyWithImpl<$Res>
    implements _$AppleMusicArtistCopyWith<$Res> {
  __$AppleMusicArtistCopyWithImpl(this._self, this._then);

  final _AppleMusicArtist _self;
  final $Res Function(_AppleMusicArtist) _then;

/// Create a copy of AppleMusicArtist
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? artistId = null,Object? name = null,Object? genre = freezed,Object? url = freezed,}) {
  return _then(_AppleMusicArtist(
artistId: null == artistId ? _self.artistId : artistId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,genre: freezed == genre ? _self.genre : genre // ignore: cast_nullable_to_non_nullable
as String?,url: freezed == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$AppleMusicSimilarArtist {

 String get name;
/// Create a copy of AppleMusicSimilarArtist
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppleMusicSimilarArtistCopyWith<AppleMusicSimilarArtist> get copyWith => _$AppleMusicSimilarArtistCopyWithImpl<AppleMusicSimilarArtist>(this as AppleMusicSimilarArtist, _$identity);

  /// Serializes this AppleMusicSimilarArtist to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppleMusicSimilarArtist&&(identical(other.name, name) || other.name == name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name);

@override
String toString() {
  return 'AppleMusicSimilarArtist(name: $name)';
}


}

/// @nodoc
abstract mixin class $AppleMusicSimilarArtistCopyWith<$Res>  {
  factory $AppleMusicSimilarArtistCopyWith(AppleMusicSimilarArtist value, $Res Function(AppleMusicSimilarArtist) _then) = _$AppleMusicSimilarArtistCopyWithImpl;
@useResult
$Res call({
 String name
});




}
/// @nodoc
class _$AppleMusicSimilarArtistCopyWithImpl<$Res>
    implements $AppleMusicSimilarArtistCopyWith<$Res> {
  _$AppleMusicSimilarArtistCopyWithImpl(this._self, this._then);

  final AppleMusicSimilarArtist _self;
  final $Res Function(AppleMusicSimilarArtist) _then;

/// Create a copy of AppleMusicSimilarArtist
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [AppleMusicSimilarArtist].
extension AppleMusicSimilarArtistPatterns on AppleMusicSimilarArtist {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AppleMusicSimilarArtist value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AppleMusicSimilarArtist() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AppleMusicSimilarArtist value)  $default,){
final _that = this;
switch (_that) {
case _AppleMusicSimilarArtist():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AppleMusicSimilarArtist value)?  $default,){
final _that = this;
switch (_that) {
case _AppleMusicSimilarArtist() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AppleMusicSimilarArtist() when $default != null:
return $default(_that.name);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name)  $default,) {final _that = this;
switch (_that) {
case _AppleMusicSimilarArtist():
return $default(_that.name);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name)?  $default,) {final _that = this;
switch (_that) {
case _AppleMusicSimilarArtist() when $default != null:
return $default(_that.name);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AppleMusicSimilarArtist implements AppleMusicSimilarArtist {
  const _AppleMusicSimilarArtist({required this.name});
  factory _AppleMusicSimilarArtist.fromJson(Map<String, dynamic> json) => _$AppleMusicSimilarArtistFromJson(json);

@override final  String name;

/// Create a copy of AppleMusicSimilarArtist
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AppleMusicSimilarArtistCopyWith<_AppleMusicSimilarArtist> get copyWith => __$AppleMusicSimilarArtistCopyWithImpl<_AppleMusicSimilarArtist>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AppleMusicSimilarArtistToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AppleMusicSimilarArtist&&(identical(other.name, name) || other.name == name));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name);

@override
String toString() {
  return 'AppleMusicSimilarArtist(name: $name)';
}


}

/// @nodoc
abstract mixin class _$AppleMusicSimilarArtistCopyWith<$Res> implements $AppleMusicSimilarArtistCopyWith<$Res> {
  factory _$AppleMusicSimilarArtistCopyWith(_AppleMusicSimilarArtist value, $Res Function(_AppleMusicSimilarArtist) _then) = __$AppleMusicSimilarArtistCopyWithImpl;
@override @useResult
$Res call({
 String name
});




}
/// @nodoc
class __$AppleMusicSimilarArtistCopyWithImpl<$Res>
    implements _$AppleMusicSimilarArtistCopyWith<$Res> {
  __$AppleMusicSimilarArtistCopyWithImpl(this._self, this._then);

  final _AppleMusicSimilarArtist _self;
  final $Res Function(_AppleMusicSimilarArtist) _then;

/// Create a copy of AppleMusicSimilarArtist
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,}) {
  return _then(_AppleMusicSimilarArtist(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$AppleMusicArtistInfo {

 String get artistId; String get name; String get storefront; String get url; String? get biography; String? get imageUrl; List<AppleMusicSimilarArtist> get similarArtists;
/// Create a copy of AppleMusicArtistInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppleMusicArtistInfoCopyWith<AppleMusicArtistInfo> get copyWith => _$AppleMusicArtistInfoCopyWithImpl<AppleMusicArtistInfo>(this as AppleMusicArtistInfo, _$identity);

  /// Serializes this AppleMusicArtistInfo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppleMusicArtistInfo&&(identical(other.artistId, artistId) || other.artistId == artistId)&&(identical(other.name, name) || other.name == name)&&(identical(other.storefront, storefront) || other.storefront == storefront)&&(identical(other.url, url) || other.url == url)&&(identical(other.biography, biography) || other.biography == biography)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&const DeepCollectionEquality().equals(other.similarArtists, similarArtists));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,artistId,name,storefront,url,biography,imageUrl,const DeepCollectionEquality().hash(similarArtists));

@override
String toString() {
  return 'AppleMusicArtistInfo(artistId: $artistId, name: $name, storefront: $storefront, url: $url, biography: $biography, imageUrl: $imageUrl, similarArtists: $similarArtists)';
}


}

/// @nodoc
abstract mixin class $AppleMusicArtistInfoCopyWith<$Res>  {
  factory $AppleMusicArtistInfoCopyWith(AppleMusicArtistInfo value, $Res Function(AppleMusicArtistInfo) _then) = _$AppleMusicArtistInfoCopyWithImpl;
@useResult
$Res call({
 String artistId, String name, String storefront, String url, String? biography, String? imageUrl, List<AppleMusicSimilarArtist> similarArtists
});




}
/// @nodoc
class _$AppleMusicArtistInfoCopyWithImpl<$Res>
    implements $AppleMusicArtistInfoCopyWith<$Res> {
  _$AppleMusicArtistInfoCopyWithImpl(this._self, this._then);

  final AppleMusicArtistInfo _self;
  final $Res Function(AppleMusicArtistInfo) _then;

/// Create a copy of AppleMusicArtistInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? artistId = null,Object? name = null,Object? storefront = null,Object? url = null,Object? biography = freezed,Object? imageUrl = freezed,Object? similarArtists = null,}) {
  return _then(_self.copyWith(
artistId: null == artistId ? _self.artistId : artistId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,storefront: null == storefront ? _self.storefront : storefront // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,biography: freezed == biography ? _self.biography : biography // ignore: cast_nullable_to_non_nullable
as String?,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,similarArtists: null == similarArtists ? _self.similarArtists : similarArtists // ignore: cast_nullable_to_non_nullable
as List<AppleMusicSimilarArtist>,
  ));
}

}


/// Adds pattern-matching-related methods to [AppleMusicArtistInfo].
extension AppleMusicArtistInfoPatterns on AppleMusicArtistInfo {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AppleMusicArtistInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AppleMusicArtistInfo() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AppleMusicArtistInfo value)  $default,){
final _that = this;
switch (_that) {
case _AppleMusicArtistInfo():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AppleMusicArtistInfo value)?  $default,){
final _that = this;
switch (_that) {
case _AppleMusicArtistInfo() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String artistId,  String name,  String storefront,  String url,  String? biography,  String? imageUrl,  List<AppleMusicSimilarArtist> similarArtists)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AppleMusicArtistInfo() when $default != null:
return $default(_that.artistId,_that.name,_that.storefront,_that.url,_that.biography,_that.imageUrl,_that.similarArtists);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String artistId,  String name,  String storefront,  String url,  String? biography,  String? imageUrl,  List<AppleMusicSimilarArtist> similarArtists)  $default,) {final _that = this;
switch (_that) {
case _AppleMusicArtistInfo():
return $default(_that.artistId,_that.name,_that.storefront,_that.url,_that.biography,_that.imageUrl,_that.similarArtists);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String artistId,  String name,  String storefront,  String url,  String? biography,  String? imageUrl,  List<AppleMusicSimilarArtist> similarArtists)?  $default,) {final _that = this;
switch (_that) {
case _AppleMusicArtistInfo() when $default != null:
return $default(_that.artistId,_that.name,_that.storefront,_that.url,_that.biography,_that.imageUrl,_that.similarArtists);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AppleMusicArtistInfo implements AppleMusicArtistInfo {
  const _AppleMusicArtistInfo({required this.artistId, required this.name, required this.storefront, required this.url, this.biography, this.imageUrl, final  List<AppleMusicSimilarArtist> similarArtists = const <AppleMusicSimilarArtist>[]}): _similarArtists = similarArtists;
  factory _AppleMusicArtistInfo.fromJson(Map<String, dynamic> json) => _$AppleMusicArtistInfoFromJson(json);

@override final  String artistId;
@override final  String name;
@override final  String storefront;
@override final  String url;
@override final  String? biography;
@override final  String? imageUrl;
 final  List<AppleMusicSimilarArtist> _similarArtists;
@override@JsonKey() List<AppleMusicSimilarArtist> get similarArtists {
  if (_similarArtists is EqualUnmodifiableListView) return _similarArtists;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_similarArtists);
}


/// Create a copy of AppleMusicArtistInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AppleMusicArtistInfoCopyWith<_AppleMusicArtistInfo> get copyWith => __$AppleMusicArtistInfoCopyWithImpl<_AppleMusicArtistInfo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AppleMusicArtistInfoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AppleMusicArtistInfo&&(identical(other.artistId, artistId) || other.artistId == artistId)&&(identical(other.name, name) || other.name == name)&&(identical(other.storefront, storefront) || other.storefront == storefront)&&(identical(other.url, url) || other.url == url)&&(identical(other.biography, biography) || other.biography == biography)&&(identical(other.imageUrl, imageUrl) || other.imageUrl == imageUrl)&&const DeepCollectionEquality().equals(other._similarArtists, _similarArtists));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,artistId,name,storefront,url,biography,imageUrl,const DeepCollectionEquality().hash(_similarArtists));

@override
String toString() {
  return 'AppleMusicArtistInfo(artistId: $artistId, name: $name, storefront: $storefront, url: $url, biography: $biography, imageUrl: $imageUrl, similarArtists: $similarArtists)';
}


}

/// @nodoc
abstract mixin class _$AppleMusicArtistInfoCopyWith<$Res> implements $AppleMusicArtistInfoCopyWith<$Res> {
  factory _$AppleMusicArtistInfoCopyWith(_AppleMusicArtistInfo value, $Res Function(_AppleMusicArtistInfo) _then) = __$AppleMusicArtistInfoCopyWithImpl;
@override @useResult
$Res call({
 String artistId, String name, String storefront, String url, String? biography, String? imageUrl, List<AppleMusicSimilarArtist> similarArtists
});




}
/// @nodoc
class __$AppleMusicArtistInfoCopyWithImpl<$Res>
    implements _$AppleMusicArtistInfoCopyWith<$Res> {
  __$AppleMusicArtistInfoCopyWithImpl(this._self, this._then);

  final _AppleMusicArtistInfo _self;
  final $Res Function(_AppleMusicArtistInfo) _then;

/// Create a copy of AppleMusicArtistInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? artistId = null,Object? name = null,Object? storefront = null,Object? url = null,Object? biography = freezed,Object? imageUrl = freezed,Object? similarArtists = null,}) {
  return _then(_AppleMusicArtistInfo(
artistId: null == artistId ? _self.artistId : artistId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,storefront: null == storefront ? _self.storefront : storefront // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,biography: freezed == biography ? _self.biography : biography // ignore: cast_nullable_to_non_nullable
as String?,imageUrl: freezed == imageUrl ? _self.imageUrl : imageUrl // ignore: cast_nullable_to_non_nullable
as String?,similarArtists: null == similarArtists ? _self._similarArtists : similarArtists // ignore: cast_nullable_to_non_nullable
as List<AppleMusicSimilarArtist>,
  ));
}


}


/// @nodoc
mixin _$AppleMusicTopSong {

 String get trackName; String get artistName; String? get collectionName; int? get durationMs;
/// Create a copy of AppleMusicTopSong
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppleMusicTopSongCopyWith<AppleMusicTopSong> get copyWith => _$AppleMusicTopSongCopyWithImpl<AppleMusicTopSong>(this as AppleMusicTopSong, _$identity);

  /// Serializes this AppleMusicTopSong to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppleMusicTopSong&&(identical(other.trackName, trackName) || other.trackName == trackName)&&(identical(other.artistName, artistName) || other.artistName == artistName)&&(identical(other.collectionName, collectionName) || other.collectionName == collectionName)&&(identical(other.durationMs, durationMs) || other.durationMs == durationMs));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,trackName,artistName,collectionName,durationMs);

@override
String toString() {
  return 'AppleMusicTopSong(trackName: $trackName, artistName: $artistName, collectionName: $collectionName, durationMs: $durationMs)';
}


}

/// @nodoc
abstract mixin class $AppleMusicTopSongCopyWith<$Res>  {
  factory $AppleMusicTopSongCopyWith(AppleMusicTopSong value, $Res Function(AppleMusicTopSong) _then) = _$AppleMusicTopSongCopyWithImpl;
@useResult
$Res call({
 String trackName, String artistName, String? collectionName, int? durationMs
});




}
/// @nodoc
class _$AppleMusicTopSongCopyWithImpl<$Res>
    implements $AppleMusicTopSongCopyWith<$Res> {
  _$AppleMusicTopSongCopyWithImpl(this._self, this._then);

  final AppleMusicTopSong _self;
  final $Res Function(AppleMusicTopSong) _then;

/// Create a copy of AppleMusicTopSong
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? trackName = null,Object? artistName = null,Object? collectionName = freezed,Object? durationMs = freezed,}) {
  return _then(_self.copyWith(
trackName: null == trackName ? _self.trackName : trackName // ignore: cast_nullable_to_non_nullable
as String,artistName: null == artistName ? _self.artistName : artistName // ignore: cast_nullable_to_non_nullable
as String,collectionName: freezed == collectionName ? _self.collectionName : collectionName // ignore: cast_nullable_to_non_nullable
as String?,durationMs: freezed == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [AppleMusicTopSong].
extension AppleMusicTopSongPatterns on AppleMusicTopSong {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AppleMusicTopSong value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AppleMusicTopSong() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AppleMusicTopSong value)  $default,){
final _that = this;
switch (_that) {
case _AppleMusicTopSong():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AppleMusicTopSong value)?  $default,){
final _that = this;
switch (_that) {
case _AppleMusicTopSong() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String trackName,  String artistName,  String? collectionName,  int? durationMs)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AppleMusicTopSong() when $default != null:
return $default(_that.trackName,_that.artistName,_that.collectionName,_that.durationMs);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String trackName,  String artistName,  String? collectionName,  int? durationMs)  $default,) {final _that = this;
switch (_that) {
case _AppleMusicTopSong():
return $default(_that.trackName,_that.artistName,_that.collectionName,_that.durationMs);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String trackName,  String artistName,  String? collectionName,  int? durationMs)?  $default,) {final _that = this;
switch (_that) {
case _AppleMusicTopSong() when $default != null:
return $default(_that.trackName,_that.artistName,_that.collectionName,_that.durationMs);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AppleMusicTopSong implements AppleMusicTopSong {
  const _AppleMusicTopSong({required this.trackName, required this.artistName, this.collectionName, this.durationMs});
  factory _AppleMusicTopSong.fromJson(Map<String, dynamic> json) => _$AppleMusicTopSongFromJson(json);

@override final  String trackName;
@override final  String artistName;
@override final  String? collectionName;
@override final  int? durationMs;

/// Create a copy of AppleMusicTopSong
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AppleMusicTopSongCopyWith<_AppleMusicTopSong> get copyWith => __$AppleMusicTopSongCopyWithImpl<_AppleMusicTopSong>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AppleMusicTopSongToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AppleMusicTopSong&&(identical(other.trackName, trackName) || other.trackName == trackName)&&(identical(other.artistName, artistName) || other.artistName == artistName)&&(identical(other.collectionName, collectionName) || other.collectionName == collectionName)&&(identical(other.durationMs, durationMs) || other.durationMs == durationMs));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,trackName,artistName,collectionName,durationMs);

@override
String toString() {
  return 'AppleMusicTopSong(trackName: $trackName, artistName: $artistName, collectionName: $collectionName, durationMs: $durationMs)';
}


}

/// @nodoc
abstract mixin class _$AppleMusicTopSongCopyWith<$Res> implements $AppleMusicTopSongCopyWith<$Res> {
  factory _$AppleMusicTopSongCopyWith(_AppleMusicTopSong value, $Res Function(_AppleMusicTopSong) _then) = __$AppleMusicTopSongCopyWithImpl;
@override @useResult
$Res call({
 String trackName, String artistName, String? collectionName, int? durationMs
});




}
/// @nodoc
class __$AppleMusicTopSongCopyWithImpl<$Res>
    implements _$AppleMusicTopSongCopyWith<$Res> {
  __$AppleMusicTopSongCopyWithImpl(this._self, this._then);

  final _AppleMusicTopSong _self;
  final $Res Function(_AppleMusicTopSong) _then;

/// Create a copy of AppleMusicTopSong
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? trackName = null,Object? artistName = null,Object? collectionName = freezed,Object? durationMs = freezed,}) {
  return _then(_AppleMusicTopSong(
trackName: null == trackName ? _self.trackName : trackName // ignore: cast_nullable_to_non_nullable
as String,artistName: null == artistName ? _self.artistName : artistName // ignore: cast_nullable_to_non_nullable
as String,collectionName: freezed == collectionName ? _self.collectionName : collectionName // ignore: cast_nullable_to_non_nullable
as String?,durationMs: freezed == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}


/// @nodoc
mixin _$AppleMusicAlbumMatch {

 String get collectionId; String get name; String get artistName; String get url; String? get artworkUrl; String? get releaseDate; String? get genre; int? get trackCount;
/// Create a copy of AppleMusicAlbumMatch
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppleMusicAlbumMatchCopyWith<AppleMusicAlbumMatch> get copyWith => _$AppleMusicAlbumMatchCopyWithImpl<AppleMusicAlbumMatch>(this as AppleMusicAlbumMatch, _$identity);

  /// Serializes this AppleMusicAlbumMatch to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppleMusicAlbumMatch&&(identical(other.collectionId, collectionId) || other.collectionId == collectionId)&&(identical(other.name, name) || other.name == name)&&(identical(other.artistName, artistName) || other.artistName == artistName)&&(identical(other.url, url) || other.url == url)&&(identical(other.artworkUrl, artworkUrl) || other.artworkUrl == artworkUrl)&&(identical(other.releaseDate, releaseDate) || other.releaseDate == releaseDate)&&(identical(other.genre, genre) || other.genre == genre)&&(identical(other.trackCount, trackCount) || other.trackCount == trackCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,collectionId,name,artistName,url,artworkUrl,releaseDate,genre,trackCount);

@override
String toString() {
  return 'AppleMusicAlbumMatch(collectionId: $collectionId, name: $name, artistName: $artistName, url: $url, artworkUrl: $artworkUrl, releaseDate: $releaseDate, genre: $genre, trackCount: $trackCount)';
}


}

/// @nodoc
abstract mixin class $AppleMusicAlbumMatchCopyWith<$Res>  {
  factory $AppleMusicAlbumMatchCopyWith(AppleMusicAlbumMatch value, $Res Function(AppleMusicAlbumMatch) _then) = _$AppleMusicAlbumMatchCopyWithImpl;
@useResult
$Res call({
 String collectionId, String name, String artistName, String url, String? artworkUrl, String? releaseDate, String? genre, int? trackCount
});




}
/// @nodoc
class _$AppleMusicAlbumMatchCopyWithImpl<$Res>
    implements $AppleMusicAlbumMatchCopyWith<$Res> {
  _$AppleMusicAlbumMatchCopyWithImpl(this._self, this._then);

  final AppleMusicAlbumMatch _self;
  final $Res Function(AppleMusicAlbumMatch) _then;

/// Create a copy of AppleMusicAlbumMatch
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? collectionId = null,Object? name = null,Object? artistName = null,Object? url = null,Object? artworkUrl = freezed,Object? releaseDate = freezed,Object? genre = freezed,Object? trackCount = freezed,}) {
  return _then(_self.copyWith(
collectionId: null == collectionId ? _self.collectionId : collectionId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,artistName: null == artistName ? _self.artistName : artistName // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,artworkUrl: freezed == artworkUrl ? _self.artworkUrl : artworkUrl // ignore: cast_nullable_to_non_nullable
as String?,releaseDate: freezed == releaseDate ? _self.releaseDate : releaseDate // ignore: cast_nullable_to_non_nullable
as String?,genre: freezed == genre ? _self.genre : genre // ignore: cast_nullable_to_non_nullable
as String?,trackCount: freezed == trackCount ? _self.trackCount : trackCount // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [AppleMusicAlbumMatch].
extension AppleMusicAlbumMatchPatterns on AppleMusicAlbumMatch {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AppleMusicAlbumMatch value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AppleMusicAlbumMatch() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AppleMusicAlbumMatch value)  $default,){
final _that = this;
switch (_that) {
case _AppleMusicAlbumMatch():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AppleMusicAlbumMatch value)?  $default,){
final _that = this;
switch (_that) {
case _AppleMusicAlbumMatch() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String collectionId,  String name,  String artistName,  String url,  String? artworkUrl,  String? releaseDate,  String? genre,  int? trackCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AppleMusicAlbumMatch() when $default != null:
return $default(_that.collectionId,_that.name,_that.artistName,_that.url,_that.artworkUrl,_that.releaseDate,_that.genre,_that.trackCount);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String collectionId,  String name,  String artistName,  String url,  String? artworkUrl,  String? releaseDate,  String? genre,  int? trackCount)  $default,) {final _that = this;
switch (_that) {
case _AppleMusicAlbumMatch():
return $default(_that.collectionId,_that.name,_that.artistName,_that.url,_that.artworkUrl,_that.releaseDate,_that.genre,_that.trackCount);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String collectionId,  String name,  String artistName,  String url,  String? artworkUrl,  String? releaseDate,  String? genre,  int? trackCount)?  $default,) {final _that = this;
switch (_that) {
case _AppleMusicAlbumMatch() when $default != null:
return $default(_that.collectionId,_that.name,_that.artistName,_that.url,_that.artworkUrl,_that.releaseDate,_that.genre,_that.trackCount);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AppleMusicAlbumMatch implements AppleMusicAlbumMatch {
  const _AppleMusicAlbumMatch({required this.collectionId, required this.name, required this.artistName, required this.url, this.artworkUrl, this.releaseDate, this.genre, this.trackCount});
  factory _AppleMusicAlbumMatch.fromJson(Map<String, dynamic> json) => _$AppleMusicAlbumMatchFromJson(json);

@override final  String collectionId;
@override final  String name;
@override final  String artistName;
@override final  String url;
@override final  String? artworkUrl;
@override final  String? releaseDate;
@override final  String? genre;
@override final  int? trackCount;

/// Create a copy of AppleMusicAlbumMatch
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AppleMusicAlbumMatchCopyWith<_AppleMusicAlbumMatch> get copyWith => __$AppleMusicAlbumMatchCopyWithImpl<_AppleMusicAlbumMatch>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AppleMusicAlbumMatchToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AppleMusicAlbumMatch&&(identical(other.collectionId, collectionId) || other.collectionId == collectionId)&&(identical(other.name, name) || other.name == name)&&(identical(other.artistName, artistName) || other.artistName == artistName)&&(identical(other.url, url) || other.url == url)&&(identical(other.artworkUrl, artworkUrl) || other.artworkUrl == artworkUrl)&&(identical(other.releaseDate, releaseDate) || other.releaseDate == releaseDate)&&(identical(other.genre, genre) || other.genre == genre)&&(identical(other.trackCount, trackCount) || other.trackCount == trackCount));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,collectionId,name,artistName,url,artworkUrl,releaseDate,genre,trackCount);

@override
String toString() {
  return 'AppleMusicAlbumMatch(collectionId: $collectionId, name: $name, artistName: $artistName, url: $url, artworkUrl: $artworkUrl, releaseDate: $releaseDate, genre: $genre, trackCount: $trackCount)';
}


}

/// @nodoc
abstract mixin class _$AppleMusicAlbumMatchCopyWith<$Res> implements $AppleMusicAlbumMatchCopyWith<$Res> {
  factory _$AppleMusicAlbumMatchCopyWith(_AppleMusicAlbumMatch value, $Res Function(_AppleMusicAlbumMatch) _then) = __$AppleMusicAlbumMatchCopyWithImpl;
@override @useResult
$Res call({
 String collectionId, String name, String artistName, String url, String? artworkUrl, String? releaseDate, String? genre, int? trackCount
});




}
/// @nodoc
class __$AppleMusicAlbumMatchCopyWithImpl<$Res>
    implements _$AppleMusicAlbumMatchCopyWith<$Res> {
  __$AppleMusicAlbumMatchCopyWithImpl(this._self, this._then);

  final _AppleMusicAlbumMatch _self;
  final $Res Function(_AppleMusicAlbumMatch) _then;

/// Create a copy of AppleMusicAlbumMatch
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? collectionId = null,Object? name = null,Object? artistName = null,Object? url = null,Object? artworkUrl = freezed,Object? releaseDate = freezed,Object? genre = freezed,Object? trackCount = freezed,}) {
  return _then(_AppleMusicAlbumMatch(
collectionId: null == collectionId ? _self.collectionId : collectionId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,artistName: null == artistName ? _self.artistName : artistName // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,artworkUrl: freezed == artworkUrl ? _self.artworkUrl : artworkUrl // ignore: cast_nullable_to_non_nullable
as String?,releaseDate: freezed == releaseDate ? _self.releaseDate : releaseDate // ignore: cast_nullable_to_non_nullable
as String?,genre: freezed == genre ? _self.genre : genre // ignore: cast_nullable_to_non_nullable
as String?,trackCount: freezed == trackCount ? _self.trackCount : trackCount // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}


/// @nodoc
mixin _$AppleMusicAlbumInfo {

 String get collectionId; String get url; String? get notes;
/// Create a copy of AppleMusicAlbumInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppleMusicAlbumInfoCopyWith<AppleMusicAlbumInfo> get copyWith => _$AppleMusicAlbumInfoCopyWithImpl<AppleMusicAlbumInfo>(this as AppleMusicAlbumInfo, _$identity);

  /// Serializes this AppleMusicAlbumInfo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppleMusicAlbumInfo&&(identical(other.collectionId, collectionId) || other.collectionId == collectionId)&&(identical(other.url, url) || other.url == url)&&(identical(other.notes, notes) || other.notes == notes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,collectionId,url,notes);

@override
String toString() {
  return 'AppleMusicAlbumInfo(collectionId: $collectionId, url: $url, notes: $notes)';
}


}

/// @nodoc
abstract mixin class $AppleMusicAlbumInfoCopyWith<$Res>  {
  factory $AppleMusicAlbumInfoCopyWith(AppleMusicAlbumInfo value, $Res Function(AppleMusicAlbumInfo) _then) = _$AppleMusicAlbumInfoCopyWithImpl;
@useResult
$Res call({
 String collectionId, String url, String? notes
});




}
/// @nodoc
class _$AppleMusicAlbumInfoCopyWithImpl<$Res>
    implements $AppleMusicAlbumInfoCopyWith<$Res> {
  _$AppleMusicAlbumInfoCopyWithImpl(this._self, this._then);

  final AppleMusicAlbumInfo _self;
  final $Res Function(AppleMusicAlbumInfo) _then;

/// Create a copy of AppleMusicAlbumInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? collectionId = null,Object? url = null,Object? notes = freezed,}) {
  return _then(_self.copyWith(
collectionId: null == collectionId ? _self.collectionId : collectionId // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [AppleMusicAlbumInfo].
extension AppleMusicAlbumInfoPatterns on AppleMusicAlbumInfo {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AppleMusicAlbumInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AppleMusicAlbumInfo() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AppleMusicAlbumInfo value)  $default,){
final _that = this;
switch (_that) {
case _AppleMusicAlbumInfo():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AppleMusicAlbumInfo value)?  $default,){
final _that = this;
switch (_that) {
case _AppleMusicAlbumInfo() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String collectionId,  String url,  String? notes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AppleMusicAlbumInfo() when $default != null:
return $default(_that.collectionId,_that.url,_that.notes);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String collectionId,  String url,  String? notes)  $default,) {final _that = this;
switch (_that) {
case _AppleMusicAlbumInfo():
return $default(_that.collectionId,_that.url,_that.notes);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String collectionId,  String url,  String? notes)?  $default,) {final _that = this;
switch (_that) {
case _AppleMusicAlbumInfo() when $default != null:
return $default(_that.collectionId,_that.url,_that.notes);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AppleMusicAlbumInfo implements AppleMusicAlbumInfo {
  const _AppleMusicAlbumInfo({required this.collectionId, required this.url, this.notes});
  factory _AppleMusicAlbumInfo.fromJson(Map<String, dynamic> json) => _$AppleMusicAlbumInfoFromJson(json);

@override final  String collectionId;
@override final  String url;
@override final  String? notes;

/// Create a copy of AppleMusicAlbumInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AppleMusicAlbumInfoCopyWith<_AppleMusicAlbumInfo> get copyWith => __$AppleMusicAlbumInfoCopyWithImpl<_AppleMusicAlbumInfo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AppleMusicAlbumInfoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AppleMusicAlbumInfo&&(identical(other.collectionId, collectionId) || other.collectionId == collectionId)&&(identical(other.url, url) || other.url == url)&&(identical(other.notes, notes) || other.notes == notes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,collectionId,url,notes);

@override
String toString() {
  return 'AppleMusicAlbumInfo(collectionId: $collectionId, url: $url, notes: $notes)';
}


}

/// @nodoc
abstract mixin class _$AppleMusicAlbumInfoCopyWith<$Res> implements $AppleMusicAlbumInfoCopyWith<$Res> {
  factory _$AppleMusicAlbumInfoCopyWith(_AppleMusicAlbumInfo value, $Res Function(_AppleMusicAlbumInfo) _then) = __$AppleMusicAlbumInfoCopyWithImpl;
@override @useResult
$Res call({
 String collectionId, String url, String? notes
});




}
/// @nodoc
class __$AppleMusicAlbumInfoCopyWithImpl<$Res>
    implements _$AppleMusicAlbumInfoCopyWith<$Res> {
  __$AppleMusicAlbumInfoCopyWithImpl(this._self, this._then);

  final _AppleMusicAlbumInfo _self;
  final $Res Function(_AppleMusicAlbumInfo) _then;

/// Create a copy of AppleMusicAlbumInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? collectionId = null,Object? url = null,Object? notes = freezed,}) {
  return _then(_AppleMusicAlbumInfo(
collectionId: null == collectionId ? _self.collectionId : collectionId // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$AppleMusicTrack {

 String get trackName; String? get trackId; String? get artistName; int? get trackNumber; int? get discNumber; int? get durationMs; String? get url;
/// Create a copy of AppleMusicTrack
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppleMusicTrackCopyWith<AppleMusicTrack> get copyWith => _$AppleMusicTrackCopyWithImpl<AppleMusicTrack>(this as AppleMusicTrack, _$identity);

  /// Serializes this AppleMusicTrack to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppleMusicTrack&&(identical(other.trackName, trackName) || other.trackName == trackName)&&(identical(other.trackId, trackId) || other.trackId == trackId)&&(identical(other.artistName, artistName) || other.artistName == artistName)&&(identical(other.trackNumber, trackNumber) || other.trackNumber == trackNumber)&&(identical(other.discNumber, discNumber) || other.discNumber == discNumber)&&(identical(other.durationMs, durationMs) || other.durationMs == durationMs)&&(identical(other.url, url) || other.url == url));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,trackName,trackId,artistName,trackNumber,discNumber,durationMs,url);

@override
String toString() {
  return 'AppleMusicTrack(trackName: $trackName, trackId: $trackId, artistName: $artistName, trackNumber: $trackNumber, discNumber: $discNumber, durationMs: $durationMs, url: $url)';
}


}

/// @nodoc
abstract mixin class $AppleMusicTrackCopyWith<$Res>  {
  factory $AppleMusicTrackCopyWith(AppleMusicTrack value, $Res Function(AppleMusicTrack) _then) = _$AppleMusicTrackCopyWithImpl;
@useResult
$Res call({
 String trackName, String? trackId, String? artistName, int? trackNumber, int? discNumber, int? durationMs, String? url
});




}
/// @nodoc
class _$AppleMusicTrackCopyWithImpl<$Res>
    implements $AppleMusicTrackCopyWith<$Res> {
  _$AppleMusicTrackCopyWithImpl(this._self, this._then);

  final AppleMusicTrack _self;
  final $Res Function(AppleMusicTrack) _then;

/// Create a copy of AppleMusicTrack
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? trackName = null,Object? trackId = freezed,Object? artistName = freezed,Object? trackNumber = freezed,Object? discNumber = freezed,Object? durationMs = freezed,Object? url = freezed,}) {
  return _then(_self.copyWith(
trackName: null == trackName ? _self.trackName : trackName // ignore: cast_nullable_to_non_nullable
as String,trackId: freezed == trackId ? _self.trackId : trackId // ignore: cast_nullable_to_non_nullable
as String?,artistName: freezed == artistName ? _self.artistName : artistName // ignore: cast_nullable_to_non_nullable
as String?,trackNumber: freezed == trackNumber ? _self.trackNumber : trackNumber // ignore: cast_nullable_to_non_nullable
as int?,discNumber: freezed == discNumber ? _self.discNumber : discNumber // ignore: cast_nullable_to_non_nullable
as int?,durationMs: freezed == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as int?,url: freezed == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [AppleMusicTrack].
extension AppleMusicTrackPatterns on AppleMusicTrack {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AppleMusicTrack value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AppleMusicTrack() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AppleMusicTrack value)  $default,){
final _that = this;
switch (_that) {
case _AppleMusicTrack():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AppleMusicTrack value)?  $default,){
final _that = this;
switch (_that) {
case _AppleMusicTrack() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String trackName,  String? trackId,  String? artistName,  int? trackNumber,  int? discNumber,  int? durationMs,  String? url)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AppleMusicTrack() when $default != null:
return $default(_that.trackName,_that.trackId,_that.artistName,_that.trackNumber,_that.discNumber,_that.durationMs,_that.url);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String trackName,  String? trackId,  String? artistName,  int? trackNumber,  int? discNumber,  int? durationMs,  String? url)  $default,) {final _that = this;
switch (_that) {
case _AppleMusicTrack():
return $default(_that.trackName,_that.trackId,_that.artistName,_that.trackNumber,_that.discNumber,_that.durationMs,_that.url);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String trackName,  String? trackId,  String? artistName,  int? trackNumber,  int? discNumber,  int? durationMs,  String? url)?  $default,) {final _that = this;
switch (_that) {
case _AppleMusicTrack() when $default != null:
return $default(_that.trackName,_that.trackId,_that.artistName,_that.trackNumber,_that.discNumber,_that.durationMs,_that.url);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AppleMusicTrack implements AppleMusicTrack {
  const _AppleMusicTrack({required this.trackName, this.trackId, this.artistName, this.trackNumber, this.discNumber, this.durationMs, this.url});
  factory _AppleMusicTrack.fromJson(Map<String, dynamic> json) => _$AppleMusicTrackFromJson(json);

@override final  String trackName;
@override final  String? trackId;
@override final  String? artistName;
@override final  int? trackNumber;
@override final  int? discNumber;
@override final  int? durationMs;
@override final  String? url;

/// Create a copy of AppleMusicTrack
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AppleMusicTrackCopyWith<_AppleMusicTrack> get copyWith => __$AppleMusicTrackCopyWithImpl<_AppleMusicTrack>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AppleMusicTrackToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AppleMusicTrack&&(identical(other.trackName, trackName) || other.trackName == trackName)&&(identical(other.trackId, trackId) || other.trackId == trackId)&&(identical(other.artistName, artistName) || other.artistName == artistName)&&(identical(other.trackNumber, trackNumber) || other.trackNumber == trackNumber)&&(identical(other.discNumber, discNumber) || other.discNumber == discNumber)&&(identical(other.durationMs, durationMs) || other.durationMs == durationMs)&&(identical(other.url, url) || other.url == url));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,trackName,trackId,artistName,trackNumber,discNumber,durationMs,url);

@override
String toString() {
  return 'AppleMusicTrack(trackName: $trackName, trackId: $trackId, artistName: $artistName, trackNumber: $trackNumber, discNumber: $discNumber, durationMs: $durationMs, url: $url)';
}


}

/// @nodoc
abstract mixin class _$AppleMusicTrackCopyWith<$Res> implements $AppleMusicTrackCopyWith<$Res> {
  factory _$AppleMusicTrackCopyWith(_AppleMusicTrack value, $Res Function(_AppleMusicTrack) _then) = __$AppleMusicTrackCopyWithImpl;
@override @useResult
$Res call({
 String trackName, String? trackId, String? artistName, int? trackNumber, int? discNumber, int? durationMs, String? url
});




}
/// @nodoc
class __$AppleMusicTrackCopyWithImpl<$Res>
    implements _$AppleMusicTrackCopyWith<$Res> {
  __$AppleMusicTrackCopyWithImpl(this._self, this._then);

  final _AppleMusicTrack _self;
  final $Res Function(_AppleMusicTrack) _then;

/// Create a copy of AppleMusicTrack
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? trackName = null,Object? trackId = freezed,Object? artistName = freezed,Object? trackNumber = freezed,Object? discNumber = freezed,Object? durationMs = freezed,Object? url = freezed,}) {
  return _then(_AppleMusicTrack(
trackName: null == trackName ? _self.trackName : trackName // ignore: cast_nullable_to_non_nullable
as String,trackId: freezed == trackId ? _self.trackId : trackId // ignore: cast_nullable_to_non_nullable
as String?,artistName: freezed == artistName ? _self.artistName : artistName // ignore: cast_nullable_to_non_nullable
as String?,trackNumber: freezed == trackNumber ? _self.trackNumber : trackNumber // ignore: cast_nullable_to_non_nullable
as int?,discNumber: freezed == discNumber ? _self.discNumber : discNumber // ignore: cast_nullable_to_non_nullable
as int?,durationMs: freezed == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as int?,url: freezed == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
