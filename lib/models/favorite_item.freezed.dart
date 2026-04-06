// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'favorite_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$FavoriteItem {

 String get key; String get name; String get cover; String get mode;@JsonKey(name: 'stream_id') String? get streamId;@JsonKey(name: 'series_id') String? get seriesId;@JsonKey(name: 'category_id') String? get categoryId;@JsonKey(name: 'container_extension') String? get containerExtension;@JsonKey(name: 'stream_icon') String? get streamIcon; String? get rating;
/// Create a copy of FavoriteItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FavoriteItemCopyWith<FavoriteItem> get copyWith => _$FavoriteItemCopyWithImpl<FavoriteItem>(this as FavoriteItem, _$identity);

  /// Serializes this FavoriteItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FavoriteItem&&(identical(other.key, key) || other.key == key)&&(identical(other.name, name) || other.name == name)&&(identical(other.cover, cover) || other.cover == cover)&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.streamId, streamId) || other.streamId == streamId)&&(identical(other.seriesId, seriesId) || other.seriesId == seriesId)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.containerExtension, containerExtension) || other.containerExtension == containerExtension)&&(identical(other.streamIcon, streamIcon) || other.streamIcon == streamIcon)&&(identical(other.rating, rating) || other.rating == rating));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,key,name,cover,mode,streamId,seriesId,categoryId,containerExtension,streamIcon,rating);

@override
String toString() {
  return 'FavoriteItem(key: $key, name: $name, cover: $cover, mode: $mode, streamId: $streamId, seriesId: $seriesId, categoryId: $categoryId, containerExtension: $containerExtension, streamIcon: $streamIcon, rating: $rating)';
}


}

/// @nodoc
abstract mixin class $FavoriteItemCopyWith<$Res>  {
  factory $FavoriteItemCopyWith(FavoriteItem value, $Res Function(FavoriteItem) _then) = _$FavoriteItemCopyWithImpl;
@useResult
$Res call({
 String key, String name, String cover, String mode,@JsonKey(name: 'stream_id') String? streamId,@JsonKey(name: 'series_id') String? seriesId,@JsonKey(name: 'category_id') String? categoryId,@JsonKey(name: 'container_extension') String? containerExtension,@JsonKey(name: 'stream_icon') String? streamIcon, String? rating
});




}
/// @nodoc
class _$FavoriteItemCopyWithImpl<$Res>
    implements $FavoriteItemCopyWith<$Res> {
  _$FavoriteItemCopyWithImpl(this._self, this._then);

  final FavoriteItem _self;
  final $Res Function(FavoriteItem) _then;

/// Create a copy of FavoriteItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? key = null,Object? name = null,Object? cover = null,Object? mode = null,Object? streamId = freezed,Object? seriesId = freezed,Object? categoryId = freezed,Object? containerExtension = freezed,Object? streamIcon = freezed,Object? rating = freezed,}) {
  return _then(_self.copyWith(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,cover: null == cover ? _self.cover : cover // ignore: cast_nullable_to_non_nullable
as String,mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as String,streamId: freezed == streamId ? _self.streamId : streamId // ignore: cast_nullable_to_non_nullable
as String?,seriesId: freezed == seriesId ? _self.seriesId : seriesId // ignore: cast_nullable_to_non_nullable
as String?,categoryId: freezed == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String?,containerExtension: freezed == containerExtension ? _self.containerExtension : containerExtension // ignore: cast_nullable_to_non_nullable
as String?,streamIcon: freezed == streamIcon ? _self.streamIcon : streamIcon // ignore: cast_nullable_to_non_nullable
as String?,rating: freezed == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [FavoriteItem].
extension FavoriteItemPatterns on FavoriteItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FavoriteItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FavoriteItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FavoriteItem value)  $default,){
final _that = this;
switch (_that) {
case _FavoriteItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FavoriteItem value)?  $default,){
final _that = this;
switch (_that) {
case _FavoriteItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String key,  String name,  String cover,  String mode, @JsonKey(name: 'stream_id')  String? streamId, @JsonKey(name: 'series_id')  String? seriesId, @JsonKey(name: 'category_id')  String? categoryId, @JsonKey(name: 'container_extension')  String? containerExtension, @JsonKey(name: 'stream_icon')  String? streamIcon,  String? rating)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FavoriteItem() when $default != null:
return $default(_that.key,_that.name,_that.cover,_that.mode,_that.streamId,_that.seriesId,_that.categoryId,_that.containerExtension,_that.streamIcon,_that.rating);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String key,  String name,  String cover,  String mode, @JsonKey(name: 'stream_id')  String? streamId, @JsonKey(name: 'series_id')  String? seriesId, @JsonKey(name: 'category_id')  String? categoryId, @JsonKey(name: 'container_extension')  String? containerExtension, @JsonKey(name: 'stream_icon')  String? streamIcon,  String? rating)  $default,) {final _that = this;
switch (_that) {
case _FavoriteItem():
return $default(_that.key,_that.name,_that.cover,_that.mode,_that.streamId,_that.seriesId,_that.categoryId,_that.containerExtension,_that.streamIcon,_that.rating);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String key,  String name,  String cover,  String mode, @JsonKey(name: 'stream_id')  String? streamId, @JsonKey(name: 'series_id')  String? seriesId, @JsonKey(name: 'category_id')  String? categoryId, @JsonKey(name: 'container_extension')  String? containerExtension, @JsonKey(name: 'stream_icon')  String? streamIcon,  String? rating)?  $default,) {final _that = this;
switch (_that) {
case _FavoriteItem() when $default != null:
return $default(_that.key,_that.name,_that.cover,_that.mode,_that.streamId,_that.seriesId,_that.categoryId,_that.containerExtension,_that.streamIcon,_that.rating);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FavoriteItem implements FavoriteItem {
  const _FavoriteItem({required this.key, this.name = '', this.cover = '', this.mode = '', @JsonKey(name: 'stream_id') this.streamId, @JsonKey(name: 'series_id') this.seriesId, @JsonKey(name: 'category_id') this.categoryId, @JsonKey(name: 'container_extension') this.containerExtension, @JsonKey(name: 'stream_icon') this.streamIcon, this.rating});
  factory _FavoriteItem.fromJson(Map<String, dynamic> json) => _$FavoriteItemFromJson(json);

@override final  String key;
@override@JsonKey() final  String name;
@override@JsonKey() final  String cover;
@override@JsonKey() final  String mode;
@override@JsonKey(name: 'stream_id') final  String? streamId;
@override@JsonKey(name: 'series_id') final  String? seriesId;
@override@JsonKey(name: 'category_id') final  String? categoryId;
@override@JsonKey(name: 'container_extension') final  String? containerExtension;
@override@JsonKey(name: 'stream_icon') final  String? streamIcon;
@override final  String? rating;

/// Create a copy of FavoriteItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FavoriteItemCopyWith<_FavoriteItem> get copyWith => __$FavoriteItemCopyWithImpl<_FavoriteItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FavoriteItemToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FavoriteItem&&(identical(other.key, key) || other.key == key)&&(identical(other.name, name) || other.name == name)&&(identical(other.cover, cover) || other.cover == cover)&&(identical(other.mode, mode) || other.mode == mode)&&(identical(other.streamId, streamId) || other.streamId == streamId)&&(identical(other.seriesId, seriesId) || other.seriesId == seriesId)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.containerExtension, containerExtension) || other.containerExtension == containerExtension)&&(identical(other.streamIcon, streamIcon) || other.streamIcon == streamIcon)&&(identical(other.rating, rating) || other.rating == rating));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,key,name,cover,mode,streamId,seriesId,categoryId,containerExtension,streamIcon,rating);

@override
String toString() {
  return 'FavoriteItem(key: $key, name: $name, cover: $cover, mode: $mode, streamId: $streamId, seriesId: $seriesId, categoryId: $categoryId, containerExtension: $containerExtension, streamIcon: $streamIcon, rating: $rating)';
}


}

/// @nodoc
abstract mixin class _$FavoriteItemCopyWith<$Res> implements $FavoriteItemCopyWith<$Res> {
  factory _$FavoriteItemCopyWith(_FavoriteItem value, $Res Function(_FavoriteItem) _then) = __$FavoriteItemCopyWithImpl;
@override @useResult
$Res call({
 String key, String name, String cover, String mode,@JsonKey(name: 'stream_id') String? streamId,@JsonKey(name: 'series_id') String? seriesId,@JsonKey(name: 'category_id') String? categoryId,@JsonKey(name: 'container_extension') String? containerExtension,@JsonKey(name: 'stream_icon') String? streamIcon, String? rating
});




}
/// @nodoc
class __$FavoriteItemCopyWithImpl<$Res>
    implements _$FavoriteItemCopyWith<$Res> {
  __$FavoriteItemCopyWithImpl(this._self, this._then);

  final _FavoriteItem _self;
  final $Res Function(_FavoriteItem) _then;

/// Create a copy of FavoriteItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? key = null,Object? name = null,Object? cover = null,Object? mode = null,Object? streamId = freezed,Object? seriesId = freezed,Object? categoryId = freezed,Object? containerExtension = freezed,Object? streamIcon = freezed,Object? rating = freezed,}) {
  return _then(_FavoriteItem(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,cover: null == cover ? _self.cover : cover // ignore: cast_nullable_to_non_nullable
as String,mode: null == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as String,streamId: freezed == streamId ? _self.streamId : streamId // ignore: cast_nullable_to_non_nullable
as String?,seriesId: freezed == seriesId ? _self.seriesId : seriesId // ignore: cast_nullable_to_non_nullable
as String?,categoryId: freezed == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String?,containerExtension: freezed == containerExtension ? _self.containerExtension : containerExtension // ignore: cast_nullable_to_non_nullable
as String?,streamIcon: freezed == streamIcon ? _self.streamIcon : streamIcon // ignore: cast_nullable_to_non_nullable
as String?,rating: freezed == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
