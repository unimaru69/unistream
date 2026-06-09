// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'channel.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Channel {

@JsonKey(name: 'stream_id') dynamic get streamId;@JsonKey(fromJson: coerceString) String get name;@JsonKey(name: 'stream_icon', fromJson: coerceStringOrNull) String? get streamIcon;@JsonKey(fromJson: coerceStringOrNull) String? get cover;@JsonKey(name: 'category_id', fromJson: coerceStringOrNull) String? get categoryId;@JsonKey(name: 'category_name', fromJson: coerceStringOrNull) String? get categoryName;@JsonKey(name: 'num') dynamic get num;@JsonKey(name: 'tv_archive') dynamic get tvArchive;@JsonKey(name: 'tv_archive_duration') dynamic get tvArchiveDuration;@JsonKey(fromJson: coerceStringOrNull) String? get added;@JsonKey(name: 'last_modified', fromJson: coerceStringOrNull) String? get lastModified;
/// Create a copy of Channel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChannelCopyWith<Channel> get copyWith => _$ChannelCopyWithImpl<Channel>(this as Channel, _$identity);

  /// Serializes this Channel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Channel&&const DeepCollectionEquality().equals(other.streamId, streamId)&&(identical(other.name, name) || other.name == name)&&(identical(other.streamIcon, streamIcon) || other.streamIcon == streamIcon)&&(identical(other.cover, cover) || other.cover == cover)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.categoryName, categoryName) || other.categoryName == categoryName)&&const DeepCollectionEquality().equals(other.num, num)&&const DeepCollectionEquality().equals(other.tvArchive, tvArchive)&&const DeepCollectionEquality().equals(other.tvArchiveDuration, tvArchiveDuration)&&(identical(other.added, added) || other.added == added)&&(identical(other.lastModified, lastModified) || other.lastModified == lastModified));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(streamId),name,streamIcon,cover,categoryId,categoryName,const DeepCollectionEquality().hash(num),const DeepCollectionEquality().hash(tvArchive),const DeepCollectionEquality().hash(tvArchiveDuration),added,lastModified);

@override
String toString() {
  return 'Channel(streamId: $streamId, name: $name, streamIcon: $streamIcon, cover: $cover, categoryId: $categoryId, categoryName: $categoryName, num: $num, tvArchive: $tvArchive, tvArchiveDuration: $tvArchiveDuration, added: $added, lastModified: $lastModified)';
}


}

/// @nodoc
abstract mixin class $ChannelCopyWith<$Res>  {
  factory $ChannelCopyWith(Channel value, $Res Function(Channel) _then) = _$ChannelCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'stream_id') dynamic streamId,@JsonKey(fromJson: coerceString) String name,@JsonKey(name: 'stream_icon', fromJson: coerceStringOrNull) String? streamIcon,@JsonKey(fromJson: coerceStringOrNull) String? cover,@JsonKey(name: 'category_id', fromJson: coerceStringOrNull) String? categoryId,@JsonKey(name: 'category_name', fromJson: coerceStringOrNull) String? categoryName,@JsonKey(name: 'num') dynamic num,@JsonKey(name: 'tv_archive') dynamic tvArchive,@JsonKey(name: 'tv_archive_duration') dynamic tvArchiveDuration,@JsonKey(fromJson: coerceStringOrNull) String? added,@JsonKey(name: 'last_modified', fromJson: coerceStringOrNull) String? lastModified
});




}
/// @nodoc
class _$ChannelCopyWithImpl<$Res>
    implements $ChannelCopyWith<$Res> {
  _$ChannelCopyWithImpl(this._self, this._then);

  final Channel _self;
  final $Res Function(Channel) _then;

/// Create a copy of Channel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? streamId = freezed,Object? name = null,Object? streamIcon = freezed,Object? cover = freezed,Object? categoryId = freezed,Object? categoryName = freezed,Object? num = freezed,Object? tvArchive = freezed,Object? tvArchiveDuration = freezed,Object? added = freezed,Object? lastModified = freezed,}) {
  return _then(_self.copyWith(
streamId: freezed == streamId ? _self.streamId : streamId // ignore: cast_nullable_to_non_nullable
as dynamic,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,streamIcon: freezed == streamIcon ? _self.streamIcon : streamIcon // ignore: cast_nullable_to_non_nullable
as String?,cover: freezed == cover ? _self.cover : cover // ignore: cast_nullable_to_non_nullable
as String?,categoryId: freezed == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String?,categoryName: freezed == categoryName ? _self.categoryName : categoryName // ignore: cast_nullable_to_non_nullable
as String?,num: freezed == num ? _self.num : num // ignore: cast_nullable_to_non_nullable
as dynamic,tvArchive: freezed == tvArchive ? _self.tvArchive : tvArchive // ignore: cast_nullable_to_non_nullable
as dynamic,tvArchiveDuration: freezed == tvArchiveDuration ? _self.tvArchiveDuration : tvArchiveDuration // ignore: cast_nullable_to_non_nullable
as dynamic,added: freezed == added ? _self.added : added // ignore: cast_nullable_to_non_nullable
as String?,lastModified: freezed == lastModified ? _self.lastModified : lastModified // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Channel].
extension ChannelPatterns on Channel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Channel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Channel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Channel value)  $default,){
final _that = this;
switch (_that) {
case _Channel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Channel value)?  $default,){
final _that = this;
switch (_that) {
case _Channel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'stream_id')  dynamic streamId, @JsonKey(fromJson: coerceString)  String name, @JsonKey(name: 'stream_icon', fromJson: coerceStringOrNull)  String? streamIcon, @JsonKey(fromJson: coerceStringOrNull)  String? cover, @JsonKey(name: 'category_id', fromJson: coerceStringOrNull)  String? categoryId, @JsonKey(name: 'category_name', fromJson: coerceStringOrNull)  String? categoryName, @JsonKey(name: 'num')  dynamic num, @JsonKey(name: 'tv_archive')  dynamic tvArchive, @JsonKey(name: 'tv_archive_duration')  dynamic tvArchiveDuration, @JsonKey(fromJson: coerceStringOrNull)  String? added, @JsonKey(name: 'last_modified', fromJson: coerceStringOrNull)  String? lastModified)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Channel() when $default != null:
return $default(_that.streamId,_that.name,_that.streamIcon,_that.cover,_that.categoryId,_that.categoryName,_that.num,_that.tvArchive,_that.tvArchiveDuration,_that.added,_that.lastModified);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'stream_id')  dynamic streamId, @JsonKey(fromJson: coerceString)  String name, @JsonKey(name: 'stream_icon', fromJson: coerceStringOrNull)  String? streamIcon, @JsonKey(fromJson: coerceStringOrNull)  String? cover, @JsonKey(name: 'category_id', fromJson: coerceStringOrNull)  String? categoryId, @JsonKey(name: 'category_name', fromJson: coerceStringOrNull)  String? categoryName, @JsonKey(name: 'num')  dynamic num, @JsonKey(name: 'tv_archive')  dynamic tvArchive, @JsonKey(name: 'tv_archive_duration')  dynamic tvArchiveDuration, @JsonKey(fromJson: coerceStringOrNull)  String? added, @JsonKey(name: 'last_modified', fromJson: coerceStringOrNull)  String? lastModified)  $default,) {final _that = this;
switch (_that) {
case _Channel():
return $default(_that.streamId,_that.name,_that.streamIcon,_that.cover,_that.categoryId,_that.categoryName,_that.num,_that.tvArchive,_that.tvArchiveDuration,_that.added,_that.lastModified);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'stream_id')  dynamic streamId, @JsonKey(fromJson: coerceString)  String name, @JsonKey(name: 'stream_icon', fromJson: coerceStringOrNull)  String? streamIcon, @JsonKey(fromJson: coerceStringOrNull)  String? cover, @JsonKey(name: 'category_id', fromJson: coerceStringOrNull)  String? categoryId, @JsonKey(name: 'category_name', fromJson: coerceStringOrNull)  String? categoryName, @JsonKey(name: 'num')  dynamic num, @JsonKey(name: 'tv_archive')  dynamic tvArchive, @JsonKey(name: 'tv_archive_duration')  dynamic tvArchiveDuration, @JsonKey(fromJson: coerceStringOrNull)  String? added, @JsonKey(name: 'last_modified', fromJson: coerceStringOrNull)  String? lastModified)?  $default,) {final _that = this;
switch (_that) {
case _Channel() when $default != null:
return $default(_that.streamId,_that.name,_that.streamIcon,_that.cover,_that.categoryId,_that.categoryName,_that.num,_that.tvArchive,_that.tvArchiveDuration,_that.added,_that.lastModified);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Channel implements Channel {
  const _Channel({@JsonKey(name: 'stream_id') required this.streamId, @JsonKey(fromJson: coerceString) this.name = '', @JsonKey(name: 'stream_icon', fromJson: coerceStringOrNull) this.streamIcon, @JsonKey(fromJson: coerceStringOrNull) this.cover, @JsonKey(name: 'category_id', fromJson: coerceStringOrNull) this.categoryId, @JsonKey(name: 'category_name', fromJson: coerceStringOrNull) this.categoryName, @JsonKey(name: 'num') this.num, @JsonKey(name: 'tv_archive') this.tvArchive = 0, @JsonKey(name: 'tv_archive_duration') this.tvArchiveDuration = '0', @JsonKey(fromJson: coerceStringOrNull) this.added, @JsonKey(name: 'last_modified', fromJson: coerceStringOrNull) this.lastModified});
  factory _Channel.fromJson(Map<String, dynamic> json) => _$ChannelFromJson(json);

@override@JsonKey(name: 'stream_id') final  dynamic streamId;
@override@JsonKey(fromJson: coerceString) final  String name;
@override@JsonKey(name: 'stream_icon', fromJson: coerceStringOrNull) final  String? streamIcon;
@override@JsonKey(fromJson: coerceStringOrNull) final  String? cover;
@override@JsonKey(name: 'category_id', fromJson: coerceStringOrNull) final  String? categoryId;
@override@JsonKey(name: 'category_name', fromJson: coerceStringOrNull) final  String? categoryName;
@override@JsonKey(name: 'num') final  dynamic num;
@override@JsonKey(name: 'tv_archive') final  dynamic tvArchive;
@override@JsonKey(name: 'tv_archive_duration') final  dynamic tvArchiveDuration;
@override@JsonKey(fromJson: coerceStringOrNull) final  String? added;
@override@JsonKey(name: 'last_modified', fromJson: coerceStringOrNull) final  String? lastModified;

/// Create a copy of Channel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChannelCopyWith<_Channel> get copyWith => __$ChannelCopyWithImpl<_Channel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ChannelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Channel&&const DeepCollectionEquality().equals(other.streamId, streamId)&&(identical(other.name, name) || other.name == name)&&(identical(other.streamIcon, streamIcon) || other.streamIcon == streamIcon)&&(identical(other.cover, cover) || other.cover == cover)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.categoryName, categoryName) || other.categoryName == categoryName)&&const DeepCollectionEquality().equals(other.num, num)&&const DeepCollectionEquality().equals(other.tvArchive, tvArchive)&&const DeepCollectionEquality().equals(other.tvArchiveDuration, tvArchiveDuration)&&(identical(other.added, added) || other.added == added)&&(identical(other.lastModified, lastModified) || other.lastModified == lastModified));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(streamId),name,streamIcon,cover,categoryId,categoryName,const DeepCollectionEquality().hash(num),const DeepCollectionEquality().hash(tvArchive),const DeepCollectionEquality().hash(tvArchiveDuration),added,lastModified);

@override
String toString() {
  return 'Channel(streamId: $streamId, name: $name, streamIcon: $streamIcon, cover: $cover, categoryId: $categoryId, categoryName: $categoryName, num: $num, tvArchive: $tvArchive, tvArchiveDuration: $tvArchiveDuration, added: $added, lastModified: $lastModified)';
}


}

/// @nodoc
abstract mixin class _$ChannelCopyWith<$Res> implements $ChannelCopyWith<$Res> {
  factory _$ChannelCopyWith(_Channel value, $Res Function(_Channel) _then) = __$ChannelCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'stream_id') dynamic streamId,@JsonKey(fromJson: coerceString) String name,@JsonKey(name: 'stream_icon', fromJson: coerceStringOrNull) String? streamIcon,@JsonKey(fromJson: coerceStringOrNull) String? cover,@JsonKey(name: 'category_id', fromJson: coerceStringOrNull) String? categoryId,@JsonKey(name: 'category_name', fromJson: coerceStringOrNull) String? categoryName,@JsonKey(name: 'num') dynamic num,@JsonKey(name: 'tv_archive') dynamic tvArchive,@JsonKey(name: 'tv_archive_duration') dynamic tvArchiveDuration,@JsonKey(fromJson: coerceStringOrNull) String? added,@JsonKey(name: 'last_modified', fromJson: coerceStringOrNull) String? lastModified
});




}
/// @nodoc
class __$ChannelCopyWithImpl<$Res>
    implements _$ChannelCopyWith<$Res> {
  __$ChannelCopyWithImpl(this._self, this._then);

  final _Channel _self;
  final $Res Function(_Channel) _then;

/// Create a copy of Channel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? streamId = freezed,Object? name = null,Object? streamIcon = freezed,Object? cover = freezed,Object? categoryId = freezed,Object? categoryName = freezed,Object? num = freezed,Object? tvArchive = freezed,Object? tvArchiveDuration = freezed,Object? added = freezed,Object? lastModified = freezed,}) {
  return _then(_Channel(
streamId: freezed == streamId ? _self.streamId : streamId // ignore: cast_nullable_to_non_nullable
as dynamic,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,streamIcon: freezed == streamIcon ? _self.streamIcon : streamIcon // ignore: cast_nullable_to_non_nullable
as String?,cover: freezed == cover ? _self.cover : cover // ignore: cast_nullable_to_non_nullable
as String?,categoryId: freezed == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String?,categoryName: freezed == categoryName ? _self.categoryName : categoryName // ignore: cast_nullable_to_non_nullable
as String?,num: freezed == num ? _self.num : num // ignore: cast_nullable_to_non_nullable
as dynamic,tvArchive: freezed == tvArchive ? _self.tvArchive : tvArchive // ignore: cast_nullable_to_non_nullable
as dynamic,tvArchiveDuration: freezed == tvArchiveDuration ? _self.tvArchiveDuration : tvArchiveDuration // ignore: cast_nullable_to_non_nullable
as dynamic,added: freezed == added ? _self.added : added // ignore: cast_nullable_to_non_nullable
as String?,lastModified: freezed == lastModified ? _self.lastModified : lastModified // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
