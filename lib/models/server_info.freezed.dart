// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'server_info.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$UserInfo {

 dynamic get auth;
/// Create a copy of UserInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserInfoCopyWith<UserInfo> get copyWith => _$UserInfoCopyWithImpl<UserInfo>(this as UserInfo, _$identity);

  /// Serializes this UserInfo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserInfo&&const DeepCollectionEquality().equals(other.auth, auth));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(auth));

@override
String toString() {
  return 'UserInfo(auth: $auth)';
}


}

/// @nodoc
abstract mixin class $UserInfoCopyWith<$Res>  {
  factory $UserInfoCopyWith(UserInfo value, $Res Function(UserInfo) _then) = _$UserInfoCopyWithImpl;
@useResult
$Res call({
 dynamic auth
});




}
/// @nodoc
class _$UserInfoCopyWithImpl<$Res>
    implements $UserInfoCopyWith<$Res> {
  _$UserInfoCopyWithImpl(this._self, this._then);

  final UserInfo _self;
  final $Res Function(UserInfo) _then;

/// Create a copy of UserInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? auth = freezed,}) {
  return _then(_self.copyWith(
auth: freezed == auth ? _self.auth : auth // ignore: cast_nullable_to_non_nullable
as dynamic,
  ));
}

}


/// Adds pattern-matching-related methods to [UserInfo].
extension UserInfoPatterns on UserInfo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UserInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UserInfo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UserInfo value)  $default,){
final _that = this;
switch (_that) {
case _UserInfo():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UserInfo value)?  $default,){
final _that = this;
switch (_that) {
case _UserInfo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( dynamic auth)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UserInfo() when $default != null:
return $default(_that.auth);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( dynamic auth)  $default,) {final _that = this;
switch (_that) {
case _UserInfo():
return $default(_that.auth);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( dynamic auth)?  $default,) {final _that = this;
switch (_that) {
case _UserInfo() when $default != null:
return $default(_that.auth);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UserInfo implements UserInfo {
  const _UserInfo({this.auth = 0});
  factory _UserInfo.fromJson(Map<String, dynamic> json) => _$UserInfoFromJson(json);

@override@JsonKey() final  dynamic auth;

/// Create a copy of UserInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserInfoCopyWith<_UserInfo> get copyWith => __$UserInfoCopyWithImpl<_UserInfo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UserInfoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UserInfo&&const DeepCollectionEquality().equals(other.auth, auth));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(auth));

@override
String toString() {
  return 'UserInfo(auth: $auth)';
}


}

/// @nodoc
abstract mixin class _$UserInfoCopyWith<$Res> implements $UserInfoCopyWith<$Res> {
  factory _$UserInfoCopyWith(_UserInfo value, $Res Function(_UserInfo) _then) = __$UserInfoCopyWithImpl;
@override @useResult
$Res call({
 dynamic auth
});




}
/// @nodoc
class __$UserInfoCopyWithImpl<$Res>
    implements _$UserInfoCopyWith<$Res> {
  __$UserInfoCopyWithImpl(this._self, this._then);

  final _UserInfo _self;
  final $Res Function(_UserInfo) _then;

/// Create a copy of UserInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? auth = freezed,}) {
  return _then(_UserInfo(
auth: freezed == auth ? _self.auth : auth // ignore: cast_nullable_to_non_nullable
as dynamic,
  ));
}


}


/// @nodoc
mixin _$ServerDetails {

@JsonKey(name: 'time_now') String? get timeNow;@JsonKey(name: 'timestamp_now') dynamic get timestampNow;
/// Create a copy of ServerDetails
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ServerDetailsCopyWith<ServerDetails> get copyWith => _$ServerDetailsCopyWithImpl<ServerDetails>(this as ServerDetails, _$identity);

  /// Serializes this ServerDetails to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ServerDetails&&(identical(other.timeNow, timeNow) || other.timeNow == timeNow)&&const DeepCollectionEquality().equals(other.timestampNow, timestampNow));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,timeNow,const DeepCollectionEquality().hash(timestampNow));

@override
String toString() {
  return 'ServerDetails(timeNow: $timeNow, timestampNow: $timestampNow)';
}


}

/// @nodoc
abstract mixin class $ServerDetailsCopyWith<$Res>  {
  factory $ServerDetailsCopyWith(ServerDetails value, $Res Function(ServerDetails) _then) = _$ServerDetailsCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'time_now') String? timeNow,@JsonKey(name: 'timestamp_now') dynamic timestampNow
});




}
/// @nodoc
class _$ServerDetailsCopyWithImpl<$Res>
    implements $ServerDetailsCopyWith<$Res> {
  _$ServerDetailsCopyWithImpl(this._self, this._then);

  final ServerDetails _self;
  final $Res Function(ServerDetails) _then;

/// Create a copy of ServerDetails
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? timeNow = freezed,Object? timestampNow = freezed,}) {
  return _then(_self.copyWith(
timeNow: freezed == timeNow ? _self.timeNow : timeNow // ignore: cast_nullable_to_non_nullable
as String?,timestampNow: freezed == timestampNow ? _self.timestampNow : timestampNow // ignore: cast_nullable_to_non_nullable
as dynamic,
  ));
}

}


/// Adds pattern-matching-related methods to [ServerDetails].
extension ServerDetailsPatterns on ServerDetails {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ServerDetails value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ServerDetails() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ServerDetails value)  $default,){
final _that = this;
switch (_that) {
case _ServerDetails():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ServerDetails value)?  $default,){
final _that = this;
switch (_that) {
case _ServerDetails() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'time_now')  String? timeNow, @JsonKey(name: 'timestamp_now')  dynamic timestampNow)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ServerDetails() when $default != null:
return $default(_that.timeNow,_that.timestampNow);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'time_now')  String? timeNow, @JsonKey(name: 'timestamp_now')  dynamic timestampNow)  $default,) {final _that = this;
switch (_that) {
case _ServerDetails():
return $default(_that.timeNow,_that.timestampNow);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'time_now')  String? timeNow, @JsonKey(name: 'timestamp_now')  dynamic timestampNow)?  $default,) {final _that = this;
switch (_that) {
case _ServerDetails() when $default != null:
return $default(_that.timeNow,_that.timestampNow);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ServerDetails implements ServerDetails {
  const _ServerDetails({@JsonKey(name: 'time_now') this.timeNow, @JsonKey(name: 'timestamp_now') this.timestampNow});
  factory _ServerDetails.fromJson(Map<String, dynamic> json) => _$ServerDetailsFromJson(json);

@override@JsonKey(name: 'time_now') final  String? timeNow;
@override@JsonKey(name: 'timestamp_now') final  dynamic timestampNow;

/// Create a copy of ServerDetails
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ServerDetailsCopyWith<_ServerDetails> get copyWith => __$ServerDetailsCopyWithImpl<_ServerDetails>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ServerDetailsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ServerDetails&&(identical(other.timeNow, timeNow) || other.timeNow == timeNow)&&const DeepCollectionEquality().equals(other.timestampNow, timestampNow));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,timeNow,const DeepCollectionEquality().hash(timestampNow));

@override
String toString() {
  return 'ServerDetails(timeNow: $timeNow, timestampNow: $timestampNow)';
}


}

/// @nodoc
abstract mixin class _$ServerDetailsCopyWith<$Res> implements $ServerDetailsCopyWith<$Res> {
  factory _$ServerDetailsCopyWith(_ServerDetails value, $Res Function(_ServerDetails) _then) = __$ServerDetailsCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'time_now') String? timeNow,@JsonKey(name: 'timestamp_now') dynamic timestampNow
});




}
/// @nodoc
class __$ServerDetailsCopyWithImpl<$Res>
    implements _$ServerDetailsCopyWith<$Res> {
  __$ServerDetailsCopyWithImpl(this._self, this._then);

  final _ServerDetails _self;
  final $Res Function(_ServerDetails) _then;

/// Create a copy of ServerDetails
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? timeNow = freezed,Object? timestampNow = freezed,}) {
  return _then(_ServerDetails(
timeNow: freezed == timeNow ? _self.timeNow : timeNow // ignore: cast_nullable_to_non_nullable
as String?,timestampNow: freezed == timestampNow ? _self.timestampNow : timestampNow // ignore: cast_nullable_to_non_nullable
as dynamic,
  ));
}


}


/// @nodoc
mixin _$ServerInfo {

@JsonKey(name: 'user_info') UserInfo? get userInfo;@JsonKey(name: 'server_info') ServerDetails? get serverInfo;
/// Create a copy of ServerInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ServerInfoCopyWith<ServerInfo> get copyWith => _$ServerInfoCopyWithImpl<ServerInfo>(this as ServerInfo, _$identity);

  /// Serializes this ServerInfo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ServerInfo&&(identical(other.userInfo, userInfo) || other.userInfo == userInfo)&&(identical(other.serverInfo, serverInfo) || other.serverInfo == serverInfo));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,userInfo,serverInfo);

@override
String toString() {
  return 'ServerInfo(userInfo: $userInfo, serverInfo: $serverInfo)';
}


}

/// @nodoc
abstract mixin class $ServerInfoCopyWith<$Res>  {
  factory $ServerInfoCopyWith(ServerInfo value, $Res Function(ServerInfo) _then) = _$ServerInfoCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'user_info') UserInfo? userInfo,@JsonKey(name: 'server_info') ServerDetails? serverInfo
});


$UserInfoCopyWith<$Res>? get userInfo;$ServerDetailsCopyWith<$Res>? get serverInfo;

}
/// @nodoc
class _$ServerInfoCopyWithImpl<$Res>
    implements $ServerInfoCopyWith<$Res> {
  _$ServerInfoCopyWithImpl(this._self, this._then);

  final ServerInfo _self;
  final $Res Function(ServerInfo) _then;

/// Create a copy of ServerInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? userInfo = freezed,Object? serverInfo = freezed,}) {
  return _then(_self.copyWith(
userInfo: freezed == userInfo ? _self.userInfo : userInfo // ignore: cast_nullable_to_non_nullable
as UserInfo?,serverInfo: freezed == serverInfo ? _self.serverInfo : serverInfo // ignore: cast_nullable_to_non_nullable
as ServerDetails?,
  ));
}
/// Create a copy of ServerInfo
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserInfoCopyWith<$Res>? get userInfo {
    if (_self.userInfo == null) {
    return null;
  }

  return $UserInfoCopyWith<$Res>(_self.userInfo!, (value) {
    return _then(_self.copyWith(userInfo: value));
  });
}/// Create a copy of ServerInfo
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ServerDetailsCopyWith<$Res>? get serverInfo {
    if (_self.serverInfo == null) {
    return null;
  }

  return $ServerDetailsCopyWith<$Res>(_self.serverInfo!, (value) {
    return _then(_self.copyWith(serverInfo: value));
  });
}
}


/// Adds pattern-matching-related methods to [ServerInfo].
extension ServerInfoPatterns on ServerInfo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ServerInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ServerInfo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ServerInfo value)  $default,){
final _that = this;
switch (_that) {
case _ServerInfo():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ServerInfo value)?  $default,){
final _that = this;
switch (_that) {
case _ServerInfo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'user_info')  UserInfo? userInfo, @JsonKey(name: 'server_info')  ServerDetails? serverInfo)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ServerInfo() when $default != null:
return $default(_that.userInfo,_that.serverInfo);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'user_info')  UserInfo? userInfo, @JsonKey(name: 'server_info')  ServerDetails? serverInfo)  $default,) {final _that = this;
switch (_that) {
case _ServerInfo():
return $default(_that.userInfo,_that.serverInfo);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'user_info')  UserInfo? userInfo, @JsonKey(name: 'server_info')  ServerDetails? serverInfo)?  $default,) {final _that = this;
switch (_that) {
case _ServerInfo() when $default != null:
return $default(_that.userInfo,_that.serverInfo);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ServerInfo implements ServerInfo {
  const _ServerInfo({@JsonKey(name: 'user_info') this.userInfo, @JsonKey(name: 'server_info') this.serverInfo});
  factory _ServerInfo.fromJson(Map<String, dynamic> json) => _$ServerInfoFromJson(json);

@override@JsonKey(name: 'user_info') final  UserInfo? userInfo;
@override@JsonKey(name: 'server_info') final  ServerDetails? serverInfo;

/// Create a copy of ServerInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ServerInfoCopyWith<_ServerInfo> get copyWith => __$ServerInfoCopyWithImpl<_ServerInfo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ServerInfoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ServerInfo&&(identical(other.userInfo, userInfo) || other.userInfo == userInfo)&&(identical(other.serverInfo, serverInfo) || other.serverInfo == serverInfo));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,userInfo,serverInfo);

@override
String toString() {
  return 'ServerInfo(userInfo: $userInfo, serverInfo: $serverInfo)';
}


}

/// @nodoc
abstract mixin class _$ServerInfoCopyWith<$Res> implements $ServerInfoCopyWith<$Res> {
  factory _$ServerInfoCopyWith(_ServerInfo value, $Res Function(_ServerInfo) _then) = __$ServerInfoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'user_info') UserInfo? userInfo,@JsonKey(name: 'server_info') ServerDetails? serverInfo
});


@override $UserInfoCopyWith<$Res>? get userInfo;@override $ServerDetailsCopyWith<$Res>? get serverInfo;

}
/// @nodoc
class __$ServerInfoCopyWithImpl<$Res>
    implements _$ServerInfoCopyWith<$Res> {
  __$ServerInfoCopyWithImpl(this._self, this._then);

  final _ServerInfo _self;
  final $Res Function(_ServerInfo) _then;

/// Create a copy of ServerInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? userInfo = freezed,Object? serverInfo = freezed,}) {
  return _then(_ServerInfo(
userInfo: freezed == userInfo ? _self.userInfo : userInfo // ignore: cast_nullable_to_non_nullable
as UserInfo?,serverInfo: freezed == serverInfo ? _self.serverInfo : serverInfo // ignore: cast_nullable_to_non_nullable
as ServerDetails?,
  ));
}

/// Create a copy of ServerInfo
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserInfoCopyWith<$Res>? get userInfo {
    if (_self.userInfo == null) {
    return null;
  }

  return $UserInfoCopyWith<$Res>(_self.userInfo!, (value) {
    return _then(_self.copyWith(userInfo: value));
  });
}/// Create a copy of ServerInfo
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ServerDetailsCopyWith<$Res>? get serverInfo {
    if (_self.serverInfo == null) {
    return null;
  }

  return $ServerDetailsCopyWith<$Res>(_self.serverInfo!, (value) {
    return _then(_self.copyWith(serverInfo: value));
  });
}
}

// dart format on
