// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'episode.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Episode {

 dynamic get id;@JsonKey(fromJson: coerceStringOrNull) String? get title;@JsonKey(name: 'container_extension', fromJson: coerceString) String get containerExtension;@JsonKey(name: 'episode_num') dynamic get episodeNum;
/// Create a copy of Episode
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EpisodeCopyWith<Episode> get copyWith => _$EpisodeCopyWithImpl<Episode>(this as Episode, _$identity);

  /// Serializes this Episode to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Episode&&const DeepCollectionEquality().equals(other.id, id)&&(identical(other.title, title) || other.title == title)&&(identical(other.containerExtension, containerExtension) || other.containerExtension == containerExtension)&&const DeepCollectionEquality().equals(other.episodeNum, episodeNum));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(id),title,containerExtension,const DeepCollectionEquality().hash(episodeNum));

@override
String toString() {
  return 'Episode(id: $id, title: $title, containerExtension: $containerExtension, episodeNum: $episodeNum)';
}


}

/// @nodoc
abstract mixin class $EpisodeCopyWith<$Res>  {
  factory $EpisodeCopyWith(Episode value, $Res Function(Episode) _then) = _$EpisodeCopyWithImpl;
@useResult
$Res call({
 dynamic id,@JsonKey(fromJson: coerceStringOrNull) String? title,@JsonKey(name: 'container_extension', fromJson: coerceString) String containerExtension,@JsonKey(name: 'episode_num') dynamic episodeNum
});




}
/// @nodoc
class _$EpisodeCopyWithImpl<$Res>
    implements $EpisodeCopyWith<$Res> {
  _$EpisodeCopyWithImpl(this._self, this._then);

  final Episode _self;
  final $Res Function(Episode) _then;

/// Create a copy of Episode
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? title = freezed,Object? containerExtension = null,Object? episodeNum = freezed,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as dynamic,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,containerExtension: null == containerExtension ? _self.containerExtension : containerExtension // ignore: cast_nullable_to_non_nullable
as String,episodeNum: freezed == episodeNum ? _self.episodeNum : episodeNum // ignore: cast_nullable_to_non_nullable
as dynamic,
  ));
}

}


/// Adds pattern-matching-related methods to [Episode].
extension EpisodePatterns on Episode {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Episode value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Episode() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Episode value)  $default,){
final _that = this;
switch (_that) {
case _Episode():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Episode value)?  $default,){
final _that = this;
switch (_that) {
case _Episode() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( dynamic id, @JsonKey(fromJson: coerceStringOrNull)  String? title, @JsonKey(name: 'container_extension', fromJson: coerceString)  String containerExtension, @JsonKey(name: 'episode_num')  dynamic episodeNum)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Episode() when $default != null:
return $default(_that.id,_that.title,_that.containerExtension,_that.episodeNum);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( dynamic id, @JsonKey(fromJson: coerceStringOrNull)  String? title, @JsonKey(name: 'container_extension', fromJson: coerceString)  String containerExtension, @JsonKey(name: 'episode_num')  dynamic episodeNum)  $default,) {final _that = this;
switch (_that) {
case _Episode():
return $default(_that.id,_that.title,_that.containerExtension,_that.episodeNum);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( dynamic id, @JsonKey(fromJson: coerceStringOrNull)  String? title, @JsonKey(name: 'container_extension', fromJson: coerceString)  String containerExtension, @JsonKey(name: 'episode_num')  dynamic episodeNum)?  $default,) {final _that = this;
switch (_that) {
case _Episode() when $default != null:
return $default(_that.id,_that.title,_that.containerExtension,_that.episodeNum);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Episode implements Episode {
  const _Episode({required this.id, @JsonKey(fromJson: coerceStringOrNull) this.title, @JsonKey(name: 'container_extension', fromJson: coerceString) this.containerExtension = 'mp4', @JsonKey(name: 'episode_num') this.episodeNum});
  factory _Episode.fromJson(Map<String, dynamic> json) => _$EpisodeFromJson(json);

@override final  dynamic id;
@override@JsonKey(fromJson: coerceStringOrNull) final  String? title;
@override@JsonKey(name: 'container_extension', fromJson: coerceString) final  String containerExtension;
@override@JsonKey(name: 'episode_num') final  dynamic episodeNum;

/// Create a copy of Episode
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EpisodeCopyWith<_Episode> get copyWith => __$EpisodeCopyWithImpl<_Episode>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EpisodeToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Episode&&const DeepCollectionEquality().equals(other.id, id)&&(identical(other.title, title) || other.title == title)&&(identical(other.containerExtension, containerExtension) || other.containerExtension == containerExtension)&&const DeepCollectionEquality().equals(other.episodeNum, episodeNum));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(id),title,containerExtension,const DeepCollectionEquality().hash(episodeNum));

@override
String toString() {
  return 'Episode(id: $id, title: $title, containerExtension: $containerExtension, episodeNum: $episodeNum)';
}


}

/// @nodoc
abstract mixin class _$EpisodeCopyWith<$Res> implements $EpisodeCopyWith<$Res> {
  factory _$EpisodeCopyWith(_Episode value, $Res Function(_Episode) _then) = __$EpisodeCopyWithImpl;
@override @useResult
$Res call({
 dynamic id,@JsonKey(fromJson: coerceStringOrNull) String? title,@JsonKey(name: 'container_extension', fromJson: coerceString) String containerExtension,@JsonKey(name: 'episode_num') dynamic episodeNum
});




}
/// @nodoc
class __$EpisodeCopyWithImpl<$Res>
    implements _$EpisodeCopyWith<$Res> {
  __$EpisodeCopyWithImpl(this._self, this._then);

  final _Episode _self;
  final $Res Function(_Episode) _then;

/// Create a copy of Episode
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? title = freezed,Object? containerExtension = null,Object? episodeNum = freezed,}) {
  return _then(_Episode(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as dynamic,title: freezed == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String?,containerExtension: null == containerExtension ? _self.containerExtension : containerExtension // ignore: cast_nullable_to_non_nullable
as String,episodeNum: freezed == episodeNum ? _self.episodeNum : episodeNum // ignore: cast_nullable_to_non_nullable
as dynamic,
  ));
}


}

// dart format on
