// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'account_info.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AccountInfo {

 String get id; String get email;@JsonKey(name: 'trial_started_at') DateTime get trialStartedAt;@JsonKey(name: 'subscription_tier') String get subscriptionTier;@JsonKey(name: 'subscription_expires_at') DateTime? get subscriptionExpiresAt;@JsonKey(name: 'cross_platform_license') bool get crossPlatformLicense;@JsonKey(name: 'created_at') DateTime? get createdAt;
/// Create a copy of AccountInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AccountInfoCopyWith<AccountInfo> get copyWith => _$AccountInfoCopyWithImpl<AccountInfo>(this as AccountInfo, _$identity);

  /// Serializes this AccountInfo to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AccountInfo&&(identical(other.id, id) || other.id == id)&&(identical(other.email, email) || other.email == email)&&(identical(other.trialStartedAt, trialStartedAt) || other.trialStartedAt == trialStartedAt)&&(identical(other.subscriptionTier, subscriptionTier) || other.subscriptionTier == subscriptionTier)&&(identical(other.subscriptionExpiresAt, subscriptionExpiresAt) || other.subscriptionExpiresAt == subscriptionExpiresAt)&&(identical(other.crossPlatformLicense, crossPlatformLicense) || other.crossPlatformLicense == crossPlatformLicense)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,email,trialStartedAt,subscriptionTier,subscriptionExpiresAt,crossPlatformLicense,createdAt);

@override
String toString() {
  return 'AccountInfo(id: $id, email: $email, trialStartedAt: $trialStartedAt, subscriptionTier: $subscriptionTier, subscriptionExpiresAt: $subscriptionExpiresAt, crossPlatformLicense: $crossPlatformLicense, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $AccountInfoCopyWith<$Res>  {
  factory $AccountInfoCopyWith(AccountInfo value, $Res Function(AccountInfo) _then) = _$AccountInfoCopyWithImpl;
@useResult
$Res call({
 String id, String email,@JsonKey(name: 'trial_started_at') DateTime trialStartedAt,@JsonKey(name: 'subscription_tier') String subscriptionTier,@JsonKey(name: 'subscription_expires_at') DateTime? subscriptionExpiresAt,@JsonKey(name: 'cross_platform_license') bool crossPlatformLicense,@JsonKey(name: 'created_at') DateTime? createdAt
});




}
/// @nodoc
class _$AccountInfoCopyWithImpl<$Res>
    implements $AccountInfoCopyWith<$Res> {
  _$AccountInfoCopyWithImpl(this._self, this._then);

  final AccountInfo _self;
  final $Res Function(AccountInfo) _then;

/// Create a copy of AccountInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? email = null,Object? trialStartedAt = null,Object? subscriptionTier = null,Object? subscriptionExpiresAt = freezed,Object? crossPlatformLicense = null,Object? createdAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,trialStartedAt: null == trialStartedAt ? _self.trialStartedAt : trialStartedAt // ignore: cast_nullable_to_non_nullable
as DateTime,subscriptionTier: null == subscriptionTier ? _self.subscriptionTier : subscriptionTier // ignore: cast_nullable_to_non_nullable
as String,subscriptionExpiresAt: freezed == subscriptionExpiresAt ? _self.subscriptionExpiresAt : subscriptionExpiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,crossPlatformLicense: null == crossPlatformLicense ? _self.crossPlatformLicense : crossPlatformLicense // ignore: cast_nullable_to_non_nullable
as bool,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [AccountInfo].
extension AccountInfoPatterns on AccountInfo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AccountInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AccountInfo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AccountInfo value)  $default,){
final _that = this;
switch (_that) {
case _AccountInfo():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AccountInfo value)?  $default,){
final _that = this;
switch (_that) {
case _AccountInfo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String email, @JsonKey(name: 'trial_started_at')  DateTime trialStartedAt, @JsonKey(name: 'subscription_tier')  String subscriptionTier, @JsonKey(name: 'subscription_expires_at')  DateTime? subscriptionExpiresAt, @JsonKey(name: 'cross_platform_license')  bool crossPlatformLicense, @JsonKey(name: 'created_at')  DateTime? createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AccountInfo() when $default != null:
return $default(_that.id,_that.email,_that.trialStartedAt,_that.subscriptionTier,_that.subscriptionExpiresAt,_that.crossPlatformLicense,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String email, @JsonKey(name: 'trial_started_at')  DateTime trialStartedAt, @JsonKey(name: 'subscription_tier')  String subscriptionTier, @JsonKey(name: 'subscription_expires_at')  DateTime? subscriptionExpiresAt, @JsonKey(name: 'cross_platform_license')  bool crossPlatformLicense, @JsonKey(name: 'created_at')  DateTime? createdAt)  $default,) {final _that = this;
switch (_that) {
case _AccountInfo():
return $default(_that.id,_that.email,_that.trialStartedAt,_that.subscriptionTier,_that.subscriptionExpiresAt,_that.crossPlatformLicense,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String email, @JsonKey(name: 'trial_started_at')  DateTime trialStartedAt, @JsonKey(name: 'subscription_tier')  String subscriptionTier, @JsonKey(name: 'subscription_expires_at')  DateTime? subscriptionExpiresAt, @JsonKey(name: 'cross_platform_license')  bool crossPlatformLicense, @JsonKey(name: 'created_at')  DateTime? createdAt)?  $default,) {final _that = this;
switch (_that) {
case _AccountInfo() when $default != null:
return $default(_that.id,_that.email,_that.trialStartedAt,_that.subscriptionTier,_that.subscriptionExpiresAt,_that.crossPlatformLicense,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AccountInfo extends AccountInfo {
  const _AccountInfo({required this.id, this.email = '', @JsonKey(name: 'trial_started_at') required this.trialStartedAt, @JsonKey(name: 'subscription_tier') this.subscriptionTier = 'trial', @JsonKey(name: 'subscription_expires_at') this.subscriptionExpiresAt, @JsonKey(name: 'cross_platform_license') this.crossPlatformLicense = false, @JsonKey(name: 'created_at') this.createdAt}): super._();
  factory _AccountInfo.fromJson(Map<String, dynamic> json) => _$AccountInfoFromJson(json);

@override final  String id;
@override@JsonKey() final  String email;
@override@JsonKey(name: 'trial_started_at') final  DateTime trialStartedAt;
@override@JsonKey(name: 'subscription_tier') final  String subscriptionTier;
@override@JsonKey(name: 'subscription_expires_at') final  DateTime? subscriptionExpiresAt;
@override@JsonKey(name: 'cross_platform_license') final  bool crossPlatformLicense;
@override@JsonKey(name: 'created_at') final  DateTime? createdAt;

/// Create a copy of AccountInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AccountInfoCopyWith<_AccountInfo> get copyWith => __$AccountInfoCopyWithImpl<_AccountInfo>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AccountInfoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AccountInfo&&(identical(other.id, id) || other.id == id)&&(identical(other.email, email) || other.email == email)&&(identical(other.trialStartedAt, trialStartedAt) || other.trialStartedAt == trialStartedAt)&&(identical(other.subscriptionTier, subscriptionTier) || other.subscriptionTier == subscriptionTier)&&(identical(other.subscriptionExpiresAt, subscriptionExpiresAt) || other.subscriptionExpiresAt == subscriptionExpiresAt)&&(identical(other.crossPlatformLicense, crossPlatformLicense) || other.crossPlatformLicense == crossPlatformLicense)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,email,trialStartedAt,subscriptionTier,subscriptionExpiresAt,crossPlatformLicense,createdAt);

@override
String toString() {
  return 'AccountInfo(id: $id, email: $email, trialStartedAt: $trialStartedAt, subscriptionTier: $subscriptionTier, subscriptionExpiresAt: $subscriptionExpiresAt, crossPlatformLicense: $crossPlatformLicense, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$AccountInfoCopyWith<$Res> implements $AccountInfoCopyWith<$Res> {
  factory _$AccountInfoCopyWith(_AccountInfo value, $Res Function(_AccountInfo) _then) = __$AccountInfoCopyWithImpl;
@override @useResult
$Res call({
 String id, String email,@JsonKey(name: 'trial_started_at') DateTime trialStartedAt,@JsonKey(name: 'subscription_tier') String subscriptionTier,@JsonKey(name: 'subscription_expires_at') DateTime? subscriptionExpiresAt,@JsonKey(name: 'cross_platform_license') bool crossPlatformLicense,@JsonKey(name: 'created_at') DateTime? createdAt
});




}
/// @nodoc
class __$AccountInfoCopyWithImpl<$Res>
    implements _$AccountInfoCopyWith<$Res> {
  __$AccountInfoCopyWithImpl(this._self, this._then);

  final _AccountInfo _self;
  final $Res Function(_AccountInfo) _then;

/// Create a copy of AccountInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? email = null,Object? trialStartedAt = null,Object? subscriptionTier = null,Object? subscriptionExpiresAt = freezed,Object? crossPlatformLicense = null,Object? createdAt = freezed,}) {
  return _then(_AccountInfo(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,trialStartedAt: null == trialStartedAt ? _self.trialStartedAt : trialStartedAt // ignore: cast_nullable_to_non_nullable
as DateTime,subscriptionTier: null == subscriptionTier ? _self.subscriptionTier : subscriptionTier // ignore: cast_nullable_to_non_nullable
as String,subscriptionExpiresAt: freezed == subscriptionExpiresAt ? _self.subscriptionExpiresAt : subscriptionExpiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,crossPlatformLicense: null == crossPlatformLicense ? _self.crossPlatformLicense : crossPlatformLicense // ignore: cast_nullable_to_non_nullable
as bool,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
