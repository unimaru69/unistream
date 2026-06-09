// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'epg_program.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$EpgProgram {

@JsonKey(fromJson: coerceString) String get title;@JsonKey(fromJson: coerceStringOrNull) String? get description;@JsonKey(fromJson: coerceStringOrNull) String? get start;@JsonKey(fromJson: coerceStringOrNull) String? get end;@JsonKey(name: 'start_timestamp', fromJson: coerceStringOrNull) String? get startTimestamp;@JsonKey(name: 'stop_timestamp', fromJson: coerceStringOrNull) String? get stopTimestamp;@JsonKey(name: 'start_utc', fromJson: coerceStringOrNull) String? get startUtc;@JsonKey(name: 'start_server_local', fromJson: coerceStringOrNull) String? get startServerLocal;@JsonKey(name: 'start_epoch') dynamic get startEpoch;
/// Create a copy of EpgProgram
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EpgProgramCopyWith<EpgProgram> get copyWith => _$EpgProgramCopyWithImpl<EpgProgram>(this as EpgProgram, _$identity);

  /// Serializes this EpgProgram to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EpgProgram&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.start, start) || other.start == start)&&(identical(other.end, end) || other.end == end)&&(identical(other.startTimestamp, startTimestamp) || other.startTimestamp == startTimestamp)&&(identical(other.stopTimestamp, stopTimestamp) || other.stopTimestamp == stopTimestamp)&&(identical(other.startUtc, startUtc) || other.startUtc == startUtc)&&(identical(other.startServerLocal, startServerLocal) || other.startServerLocal == startServerLocal)&&const DeepCollectionEquality().equals(other.startEpoch, startEpoch));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,title,description,start,end,startTimestamp,stopTimestamp,startUtc,startServerLocal,const DeepCollectionEquality().hash(startEpoch));

@override
String toString() {
  return 'EpgProgram(title: $title, description: $description, start: $start, end: $end, startTimestamp: $startTimestamp, stopTimestamp: $stopTimestamp, startUtc: $startUtc, startServerLocal: $startServerLocal, startEpoch: $startEpoch)';
}


}

/// @nodoc
abstract mixin class $EpgProgramCopyWith<$Res>  {
  factory $EpgProgramCopyWith(EpgProgram value, $Res Function(EpgProgram) _then) = _$EpgProgramCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: coerceString) String title,@JsonKey(fromJson: coerceStringOrNull) String? description,@JsonKey(fromJson: coerceStringOrNull) String? start,@JsonKey(fromJson: coerceStringOrNull) String? end,@JsonKey(name: 'start_timestamp', fromJson: coerceStringOrNull) String? startTimestamp,@JsonKey(name: 'stop_timestamp', fromJson: coerceStringOrNull) String? stopTimestamp,@JsonKey(name: 'start_utc', fromJson: coerceStringOrNull) String? startUtc,@JsonKey(name: 'start_server_local', fromJson: coerceStringOrNull) String? startServerLocal,@JsonKey(name: 'start_epoch') dynamic startEpoch
});




}
/// @nodoc
class _$EpgProgramCopyWithImpl<$Res>
    implements $EpgProgramCopyWith<$Res> {
  _$EpgProgramCopyWithImpl(this._self, this._then);

  final EpgProgram _self;
  final $Res Function(EpgProgram) _then;

/// Create a copy of EpgProgram
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? title = null,Object? description = freezed,Object? start = freezed,Object? end = freezed,Object? startTimestamp = freezed,Object? stopTimestamp = freezed,Object? startUtc = freezed,Object? startServerLocal = freezed,Object? startEpoch = freezed,}) {
  return _then(_self.copyWith(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,start: freezed == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as String?,end: freezed == end ? _self.end : end // ignore: cast_nullable_to_non_nullable
as String?,startTimestamp: freezed == startTimestamp ? _self.startTimestamp : startTimestamp // ignore: cast_nullable_to_non_nullable
as String?,stopTimestamp: freezed == stopTimestamp ? _self.stopTimestamp : stopTimestamp // ignore: cast_nullable_to_non_nullable
as String?,startUtc: freezed == startUtc ? _self.startUtc : startUtc // ignore: cast_nullable_to_non_nullable
as String?,startServerLocal: freezed == startServerLocal ? _self.startServerLocal : startServerLocal // ignore: cast_nullable_to_non_nullable
as String?,startEpoch: freezed == startEpoch ? _self.startEpoch : startEpoch // ignore: cast_nullable_to_non_nullable
as dynamic,
  ));
}

}


/// Adds pattern-matching-related methods to [EpgProgram].
extension EpgProgramPatterns on EpgProgram {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EpgProgram value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EpgProgram() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EpgProgram value)  $default,){
final _that = this;
switch (_that) {
case _EpgProgram():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EpgProgram value)?  $default,){
final _that = this;
switch (_that) {
case _EpgProgram() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: coerceString)  String title, @JsonKey(fromJson: coerceStringOrNull)  String? description, @JsonKey(fromJson: coerceStringOrNull)  String? start, @JsonKey(fromJson: coerceStringOrNull)  String? end, @JsonKey(name: 'start_timestamp', fromJson: coerceStringOrNull)  String? startTimestamp, @JsonKey(name: 'stop_timestamp', fromJson: coerceStringOrNull)  String? stopTimestamp, @JsonKey(name: 'start_utc', fromJson: coerceStringOrNull)  String? startUtc, @JsonKey(name: 'start_server_local', fromJson: coerceStringOrNull)  String? startServerLocal, @JsonKey(name: 'start_epoch')  dynamic startEpoch)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EpgProgram() when $default != null:
return $default(_that.title,_that.description,_that.start,_that.end,_that.startTimestamp,_that.stopTimestamp,_that.startUtc,_that.startServerLocal,_that.startEpoch);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: coerceString)  String title, @JsonKey(fromJson: coerceStringOrNull)  String? description, @JsonKey(fromJson: coerceStringOrNull)  String? start, @JsonKey(fromJson: coerceStringOrNull)  String? end, @JsonKey(name: 'start_timestamp', fromJson: coerceStringOrNull)  String? startTimestamp, @JsonKey(name: 'stop_timestamp', fromJson: coerceStringOrNull)  String? stopTimestamp, @JsonKey(name: 'start_utc', fromJson: coerceStringOrNull)  String? startUtc, @JsonKey(name: 'start_server_local', fromJson: coerceStringOrNull)  String? startServerLocal, @JsonKey(name: 'start_epoch')  dynamic startEpoch)  $default,) {final _that = this;
switch (_that) {
case _EpgProgram():
return $default(_that.title,_that.description,_that.start,_that.end,_that.startTimestamp,_that.stopTimestamp,_that.startUtc,_that.startServerLocal,_that.startEpoch);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: coerceString)  String title, @JsonKey(fromJson: coerceStringOrNull)  String? description, @JsonKey(fromJson: coerceStringOrNull)  String? start, @JsonKey(fromJson: coerceStringOrNull)  String? end, @JsonKey(name: 'start_timestamp', fromJson: coerceStringOrNull)  String? startTimestamp, @JsonKey(name: 'stop_timestamp', fromJson: coerceStringOrNull)  String? stopTimestamp, @JsonKey(name: 'start_utc', fromJson: coerceStringOrNull)  String? startUtc, @JsonKey(name: 'start_server_local', fromJson: coerceStringOrNull)  String? startServerLocal, @JsonKey(name: 'start_epoch')  dynamic startEpoch)?  $default,) {final _that = this;
switch (_that) {
case _EpgProgram() when $default != null:
return $default(_that.title,_that.description,_that.start,_that.end,_that.startTimestamp,_that.stopTimestamp,_that.startUtc,_that.startServerLocal,_that.startEpoch);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _EpgProgram implements EpgProgram {
  const _EpgProgram({@JsonKey(fromJson: coerceString) this.title = '', @JsonKey(fromJson: coerceStringOrNull) this.description, @JsonKey(fromJson: coerceStringOrNull) this.start, @JsonKey(fromJson: coerceStringOrNull) this.end, @JsonKey(name: 'start_timestamp', fromJson: coerceStringOrNull) this.startTimestamp, @JsonKey(name: 'stop_timestamp', fromJson: coerceStringOrNull) this.stopTimestamp, @JsonKey(name: 'start_utc', fromJson: coerceStringOrNull) this.startUtc, @JsonKey(name: 'start_server_local', fromJson: coerceStringOrNull) this.startServerLocal, @JsonKey(name: 'start_epoch') this.startEpoch});
  factory _EpgProgram.fromJson(Map<String, dynamic> json) => _$EpgProgramFromJson(json);

@override@JsonKey(fromJson: coerceString) final  String title;
@override@JsonKey(fromJson: coerceStringOrNull) final  String? description;
@override@JsonKey(fromJson: coerceStringOrNull) final  String? start;
@override@JsonKey(fromJson: coerceStringOrNull) final  String? end;
@override@JsonKey(name: 'start_timestamp', fromJson: coerceStringOrNull) final  String? startTimestamp;
@override@JsonKey(name: 'stop_timestamp', fromJson: coerceStringOrNull) final  String? stopTimestamp;
@override@JsonKey(name: 'start_utc', fromJson: coerceStringOrNull) final  String? startUtc;
@override@JsonKey(name: 'start_server_local', fromJson: coerceStringOrNull) final  String? startServerLocal;
@override@JsonKey(name: 'start_epoch') final  dynamic startEpoch;

/// Create a copy of EpgProgram
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EpgProgramCopyWith<_EpgProgram> get copyWith => __$EpgProgramCopyWithImpl<_EpgProgram>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EpgProgramToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _EpgProgram&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.start, start) || other.start == start)&&(identical(other.end, end) || other.end == end)&&(identical(other.startTimestamp, startTimestamp) || other.startTimestamp == startTimestamp)&&(identical(other.stopTimestamp, stopTimestamp) || other.stopTimestamp == stopTimestamp)&&(identical(other.startUtc, startUtc) || other.startUtc == startUtc)&&(identical(other.startServerLocal, startServerLocal) || other.startServerLocal == startServerLocal)&&const DeepCollectionEquality().equals(other.startEpoch, startEpoch));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,title,description,start,end,startTimestamp,stopTimestamp,startUtc,startServerLocal,const DeepCollectionEquality().hash(startEpoch));

@override
String toString() {
  return 'EpgProgram(title: $title, description: $description, start: $start, end: $end, startTimestamp: $startTimestamp, stopTimestamp: $stopTimestamp, startUtc: $startUtc, startServerLocal: $startServerLocal, startEpoch: $startEpoch)';
}


}

/// @nodoc
abstract mixin class _$EpgProgramCopyWith<$Res> implements $EpgProgramCopyWith<$Res> {
  factory _$EpgProgramCopyWith(_EpgProgram value, $Res Function(_EpgProgram) _then) = __$EpgProgramCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: coerceString) String title,@JsonKey(fromJson: coerceStringOrNull) String? description,@JsonKey(fromJson: coerceStringOrNull) String? start,@JsonKey(fromJson: coerceStringOrNull) String? end,@JsonKey(name: 'start_timestamp', fromJson: coerceStringOrNull) String? startTimestamp,@JsonKey(name: 'stop_timestamp', fromJson: coerceStringOrNull) String? stopTimestamp,@JsonKey(name: 'start_utc', fromJson: coerceStringOrNull) String? startUtc,@JsonKey(name: 'start_server_local', fromJson: coerceStringOrNull) String? startServerLocal,@JsonKey(name: 'start_epoch') dynamic startEpoch
});




}
/// @nodoc
class __$EpgProgramCopyWithImpl<$Res>
    implements _$EpgProgramCopyWith<$Res> {
  __$EpgProgramCopyWithImpl(this._self, this._then);

  final _EpgProgram _self;
  final $Res Function(_EpgProgram) _then;

/// Create a copy of EpgProgram
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? title = null,Object? description = freezed,Object? start = freezed,Object? end = freezed,Object? startTimestamp = freezed,Object? stopTimestamp = freezed,Object? startUtc = freezed,Object? startServerLocal = freezed,Object? startEpoch = freezed,}) {
  return _then(_EpgProgram(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,start: freezed == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as String?,end: freezed == end ? _self.end : end // ignore: cast_nullable_to_non_nullable
as String?,startTimestamp: freezed == startTimestamp ? _self.startTimestamp : startTimestamp // ignore: cast_nullable_to_non_nullable
as String?,stopTimestamp: freezed == stopTimestamp ? _self.stopTimestamp : stopTimestamp // ignore: cast_nullable_to_non_nullable
as String?,startUtc: freezed == startUtc ? _self.startUtc : startUtc // ignore: cast_nullable_to_non_nullable
as String?,startServerLocal: freezed == startServerLocal ? _self.startServerLocal : startServerLocal // ignore: cast_nullable_to_non_nullable
as String?,startEpoch: freezed == startEpoch ? _self.startEpoch : startEpoch // ignore: cast_nullable_to_non_nullable
as dynamic,
  ));
}


}

// dart format on
