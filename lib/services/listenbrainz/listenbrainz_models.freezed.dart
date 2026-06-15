// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'listenbrainz_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ListenBrainzSession {

 String get token; String get username;
/// Create a copy of ListenBrainzSession
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ListenBrainzSessionCopyWith<ListenBrainzSession> get copyWith => _$ListenBrainzSessionCopyWithImpl<ListenBrainzSession>(this as ListenBrainzSession, _$identity);

  /// Serializes this ListenBrainzSession to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ListenBrainzSession&&(identical(other.token, token) || other.token == token)&&(identical(other.username, username) || other.username == username));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,token,username);

@override
String toString() {
  return 'ListenBrainzSession(token: $token, username: $username)';
}


}

/// @nodoc
abstract mixin class $ListenBrainzSessionCopyWith<$Res>  {
  factory $ListenBrainzSessionCopyWith(ListenBrainzSession value, $Res Function(ListenBrainzSession) _then) = _$ListenBrainzSessionCopyWithImpl;
@useResult
$Res call({
 String token, String username
});




}
/// @nodoc
class _$ListenBrainzSessionCopyWithImpl<$Res>
    implements $ListenBrainzSessionCopyWith<$Res> {
  _$ListenBrainzSessionCopyWithImpl(this._self, this._then);

  final ListenBrainzSession _self;
  final $Res Function(ListenBrainzSession) _then;

/// Create a copy of ListenBrainzSession
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? token = null,Object? username = null,}) {
  return _then(_self.copyWith(
token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as String,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ListenBrainzSession].
extension ListenBrainzSessionPatterns on ListenBrainzSession {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ListenBrainzSession value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ListenBrainzSession() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ListenBrainzSession value)  $default,){
final _that = this;
switch (_that) {
case _ListenBrainzSession():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ListenBrainzSession value)?  $default,){
final _that = this;
switch (_that) {
case _ListenBrainzSession() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String token,  String username)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ListenBrainzSession() when $default != null:
return $default(_that.token,_that.username);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String token,  String username)  $default,) {final _that = this;
switch (_that) {
case _ListenBrainzSession():
return $default(_that.token,_that.username);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String token,  String username)?  $default,) {final _that = this;
switch (_that) {
case _ListenBrainzSession() when $default != null:
return $default(_that.token,_that.username);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ListenBrainzSession implements ListenBrainzSession {
  const _ListenBrainzSession({required this.token, required this.username});
  factory _ListenBrainzSession.fromJson(Map<String, dynamic> json) => _$ListenBrainzSessionFromJson(json);

@override final  String token;
@override final  String username;

/// Create a copy of ListenBrainzSession
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ListenBrainzSessionCopyWith<_ListenBrainzSession> get copyWith => __$ListenBrainzSessionCopyWithImpl<_ListenBrainzSession>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ListenBrainzSessionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ListenBrainzSession&&(identical(other.token, token) || other.token == token)&&(identical(other.username, username) || other.username == username));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,token,username);

@override
String toString() {
  return 'ListenBrainzSession(token: $token, username: $username)';
}


}

/// @nodoc
abstract mixin class _$ListenBrainzSessionCopyWith<$Res> implements $ListenBrainzSessionCopyWith<$Res> {
  factory _$ListenBrainzSessionCopyWith(_ListenBrainzSession value, $Res Function(_ListenBrainzSession) _then) = __$ListenBrainzSessionCopyWithImpl;
@override @useResult
$Res call({
 String token, String username
});




}
/// @nodoc
class __$ListenBrainzSessionCopyWithImpl<$Res>
    implements _$ListenBrainzSessionCopyWith<$Res> {
  __$ListenBrainzSessionCopyWithImpl(this._self, this._then);

  final _ListenBrainzSession _self;
  final $Res Function(_ListenBrainzSession) _then;

/// Create a copy of ListenBrainzSession
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? token = null,Object? username = null,}) {
  return _then(_ListenBrainzSession(
token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as String,username: null == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$ListenBrainzListenEntry {

 String get artistName; String get trackName; int get listenedAt; String? get releaseName; int? get durationSeconds;
/// Create a copy of ListenBrainzListenEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ListenBrainzListenEntryCopyWith<ListenBrainzListenEntry> get copyWith => _$ListenBrainzListenEntryCopyWithImpl<ListenBrainzListenEntry>(this as ListenBrainzListenEntry, _$identity);

  /// Serializes this ListenBrainzListenEntry to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ListenBrainzListenEntry&&(identical(other.artistName, artistName) || other.artistName == artistName)&&(identical(other.trackName, trackName) || other.trackName == trackName)&&(identical(other.listenedAt, listenedAt) || other.listenedAt == listenedAt)&&(identical(other.releaseName, releaseName) || other.releaseName == releaseName)&&(identical(other.durationSeconds, durationSeconds) || other.durationSeconds == durationSeconds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,artistName,trackName,listenedAt,releaseName,durationSeconds);

@override
String toString() {
  return 'ListenBrainzListenEntry(artistName: $artistName, trackName: $trackName, listenedAt: $listenedAt, releaseName: $releaseName, durationSeconds: $durationSeconds)';
}


}

/// @nodoc
abstract mixin class $ListenBrainzListenEntryCopyWith<$Res>  {
  factory $ListenBrainzListenEntryCopyWith(ListenBrainzListenEntry value, $Res Function(ListenBrainzListenEntry) _then) = _$ListenBrainzListenEntryCopyWithImpl;
@useResult
$Res call({
 String artistName, String trackName, int listenedAt, String? releaseName, int? durationSeconds
});




}
/// @nodoc
class _$ListenBrainzListenEntryCopyWithImpl<$Res>
    implements $ListenBrainzListenEntryCopyWith<$Res> {
  _$ListenBrainzListenEntryCopyWithImpl(this._self, this._then);

  final ListenBrainzListenEntry _self;
  final $Res Function(ListenBrainzListenEntry) _then;

/// Create a copy of ListenBrainzListenEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? artistName = null,Object? trackName = null,Object? listenedAt = null,Object? releaseName = freezed,Object? durationSeconds = freezed,}) {
  return _then(_self.copyWith(
artistName: null == artistName ? _self.artistName : artistName // ignore: cast_nullable_to_non_nullable
as String,trackName: null == trackName ? _self.trackName : trackName // ignore: cast_nullable_to_non_nullable
as String,listenedAt: null == listenedAt ? _self.listenedAt : listenedAt // ignore: cast_nullable_to_non_nullable
as int,releaseName: freezed == releaseName ? _self.releaseName : releaseName // ignore: cast_nullable_to_non_nullable
as String?,durationSeconds: freezed == durationSeconds ? _self.durationSeconds : durationSeconds // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [ListenBrainzListenEntry].
extension ListenBrainzListenEntryPatterns on ListenBrainzListenEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ListenBrainzListenEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ListenBrainzListenEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ListenBrainzListenEntry value)  $default,){
final _that = this;
switch (_that) {
case _ListenBrainzListenEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ListenBrainzListenEntry value)?  $default,){
final _that = this;
switch (_that) {
case _ListenBrainzListenEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String artistName,  String trackName,  int listenedAt,  String? releaseName,  int? durationSeconds)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ListenBrainzListenEntry() when $default != null:
return $default(_that.artistName,_that.trackName,_that.listenedAt,_that.releaseName,_that.durationSeconds);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String artistName,  String trackName,  int listenedAt,  String? releaseName,  int? durationSeconds)  $default,) {final _that = this;
switch (_that) {
case _ListenBrainzListenEntry():
return $default(_that.artistName,_that.trackName,_that.listenedAt,_that.releaseName,_that.durationSeconds);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String artistName,  String trackName,  int listenedAt,  String? releaseName,  int? durationSeconds)?  $default,) {final _that = this;
switch (_that) {
case _ListenBrainzListenEntry() when $default != null:
return $default(_that.artistName,_that.trackName,_that.listenedAt,_that.releaseName,_that.durationSeconds);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ListenBrainzListenEntry implements ListenBrainzListenEntry {
  const _ListenBrainzListenEntry({required this.artistName, required this.trackName, required this.listenedAt, this.releaseName, this.durationSeconds});
  factory _ListenBrainzListenEntry.fromJson(Map<String, dynamic> json) => _$ListenBrainzListenEntryFromJson(json);

@override final  String artistName;
@override final  String trackName;
@override final  int listenedAt;
@override final  String? releaseName;
@override final  int? durationSeconds;

/// Create a copy of ListenBrainzListenEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ListenBrainzListenEntryCopyWith<_ListenBrainzListenEntry> get copyWith => __$ListenBrainzListenEntryCopyWithImpl<_ListenBrainzListenEntry>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ListenBrainzListenEntryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ListenBrainzListenEntry&&(identical(other.artistName, artistName) || other.artistName == artistName)&&(identical(other.trackName, trackName) || other.trackName == trackName)&&(identical(other.listenedAt, listenedAt) || other.listenedAt == listenedAt)&&(identical(other.releaseName, releaseName) || other.releaseName == releaseName)&&(identical(other.durationSeconds, durationSeconds) || other.durationSeconds == durationSeconds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,artistName,trackName,listenedAt,releaseName,durationSeconds);

@override
String toString() {
  return 'ListenBrainzListenEntry(artistName: $artistName, trackName: $trackName, listenedAt: $listenedAt, releaseName: $releaseName, durationSeconds: $durationSeconds)';
}


}

/// @nodoc
abstract mixin class _$ListenBrainzListenEntryCopyWith<$Res> implements $ListenBrainzListenEntryCopyWith<$Res> {
  factory _$ListenBrainzListenEntryCopyWith(_ListenBrainzListenEntry value, $Res Function(_ListenBrainzListenEntry) _then) = __$ListenBrainzListenEntryCopyWithImpl;
@override @useResult
$Res call({
 String artistName, String trackName, int listenedAt, String? releaseName, int? durationSeconds
});




}
/// @nodoc
class __$ListenBrainzListenEntryCopyWithImpl<$Res>
    implements _$ListenBrainzListenEntryCopyWith<$Res> {
  __$ListenBrainzListenEntryCopyWithImpl(this._self, this._then);

  final _ListenBrainzListenEntry _self;
  final $Res Function(_ListenBrainzListenEntry) _then;

/// Create a copy of ListenBrainzListenEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? artistName = null,Object? trackName = null,Object? listenedAt = null,Object? releaseName = freezed,Object? durationSeconds = freezed,}) {
  return _then(_ListenBrainzListenEntry(
artistName: null == artistName ? _self.artistName : artistName // ignore: cast_nullable_to_non_nullable
as String,trackName: null == trackName ? _self.trackName : trackName // ignore: cast_nullable_to_non_nullable
as String,listenedAt: null == listenedAt ? _self.listenedAt : listenedAt // ignore: cast_nullable_to_non_nullable
as int,releaseName: freezed == releaseName ? _self.releaseName : releaseName // ignore: cast_nullable_to_non_nullable
as String?,durationSeconds: freezed == durationSeconds ? _self.durationSeconds : durationSeconds // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
