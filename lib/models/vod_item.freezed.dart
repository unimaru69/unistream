// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'vod_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$VodItem {

@JsonKey(name: 'stream_id') dynamic get streamId;@JsonKey(fromJson: coerceString) String get name;@JsonKey(name: 'stream_icon', fromJson: coerceStringOrNull) String? get streamIcon;@JsonKey(fromJson: coerceStringOrNull) String? get cover;@JsonKey(name: 'container_extension', fromJson: coerceString) String get containerExtension;@JsonKey(name: 'category_id', fromJson: coerceStringOrNull) String? get categoryId;@JsonKey(name: 'category_name', fromJson: coerceStringOrNull) String? get categoryName;@JsonKey(fromJson: coerceStringOrNull) String? get rating;@JsonKey(name: 'stream_type', fromJson: coerceStringOrNull) String? get streamType;@JsonKey(fromJson: coerceStringOrNull) String? get plot;@JsonKey(fromJson: coerceStringOrNull) String? get description;@JsonKey(fromJson: coerceStringOrNull) String? get added;@JsonKey(name: 'last_modified', fromJson: coerceStringOrNull) String? get lastModified;
/// Create a copy of VodItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VodItemCopyWith<VodItem> get copyWith => _$VodItemCopyWithImpl<VodItem>(this as VodItem, _$identity);

  /// Serializes this VodItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VodItem&&const DeepCollectionEquality().equals(other.streamId, streamId)&&(identical(other.name, name) || other.name == name)&&(identical(other.streamIcon, streamIcon) || other.streamIcon == streamIcon)&&(identical(other.cover, cover) || other.cover == cover)&&(identical(other.containerExtension, containerExtension) || other.containerExtension == containerExtension)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.categoryName, categoryName) || other.categoryName == categoryName)&&(identical(other.rating, rating) || other.rating == rating)&&(identical(other.streamType, streamType) || other.streamType == streamType)&&(identical(other.plot, plot) || other.plot == plot)&&(identical(other.description, description) || other.description == description)&&(identical(other.added, added) || other.added == added)&&(identical(other.lastModified, lastModified) || other.lastModified == lastModified));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(streamId),name,streamIcon,cover,containerExtension,categoryId,categoryName,rating,streamType,plot,description,added,lastModified);

@override
String toString() {
  return 'VodItem(streamId: $streamId, name: $name, streamIcon: $streamIcon, cover: $cover, containerExtension: $containerExtension, categoryId: $categoryId, categoryName: $categoryName, rating: $rating, streamType: $streamType, plot: $plot, description: $description, added: $added, lastModified: $lastModified)';
}


}

/// @nodoc
abstract mixin class $VodItemCopyWith<$Res>  {
  factory $VodItemCopyWith(VodItem value, $Res Function(VodItem) _then) = _$VodItemCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'stream_id') dynamic streamId,@JsonKey(fromJson: coerceString) String name,@JsonKey(name: 'stream_icon', fromJson: coerceStringOrNull) String? streamIcon,@JsonKey(fromJson: coerceStringOrNull) String? cover,@JsonKey(name: 'container_extension', fromJson: coerceString) String containerExtension,@JsonKey(name: 'category_id', fromJson: coerceStringOrNull) String? categoryId,@JsonKey(name: 'category_name', fromJson: coerceStringOrNull) String? categoryName,@JsonKey(fromJson: coerceStringOrNull) String? rating,@JsonKey(name: 'stream_type', fromJson: coerceStringOrNull) String? streamType,@JsonKey(fromJson: coerceStringOrNull) String? plot,@JsonKey(fromJson: coerceStringOrNull) String? description,@JsonKey(fromJson: coerceStringOrNull) String? added,@JsonKey(name: 'last_modified', fromJson: coerceStringOrNull) String? lastModified
});




}
/// @nodoc
class _$VodItemCopyWithImpl<$Res>
    implements $VodItemCopyWith<$Res> {
  _$VodItemCopyWithImpl(this._self, this._then);

  final VodItem _self;
  final $Res Function(VodItem) _then;

/// Create a copy of VodItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? streamId = freezed,Object? name = null,Object? streamIcon = freezed,Object? cover = freezed,Object? containerExtension = null,Object? categoryId = freezed,Object? categoryName = freezed,Object? rating = freezed,Object? streamType = freezed,Object? plot = freezed,Object? description = freezed,Object? added = freezed,Object? lastModified = freezed,}) {
  return _then(_self.copyWith(
streamId: freezed == streamId ? _self.streamId : streamId // ignore: cast_nullable_to_non_nullable
as dynamic,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,streamIcon: freezed == streamIcon ? _self.streamIcon : streamIcon // ignore: cast_nullable_to_non_nullable
as String?,cover: freezed == cover ? _self.cover : cover // ignore: cast_nullable_to_non_nullable
as String?,containerExtension: null == containerExtension ? _self.containerExtension : containerExtension // ignore: cast_nullable_to_non_nullable
as String,categoryId: freezed == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String?,categoryName: freezed == categoryName ? _self.categoryName : categoryName // ignore: cast_nullable_to_non_nullable
as String?,rating: freezed == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as String?,streamType: freezed == streamType ? _self.streamType : streamType // ignore: cast_nullable_to_non_nullable
as String?,plot: freezed == plot ? _self.plot : plot // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,added: freezed == added ? _self.added : added // ignore: cast_nullable_to_non_nullable
as String?,lastModified: freezed == lastModified ? _self.lastModified : lastModified // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [VodItem].
extension VodItemPatterns on VodItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VodItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VodItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VodItem value)  $default,){
final _that = this;
switch (_that) {
case _VodItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VodItem value)?  $default,){
final _that = this;
switch (_that) {
case _VodItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'stream_id')  dynamic streamId, @JsonKey(fromJson: coerceString)  String name, @JsonKey(name: 'stream_icon', fromJson: coerceStringOrNull)  String? streamIcon, @JsonKey(fromJson: coerceStringOrNull)  String? cover, @JsonKey(name: 'container_extension', fromJson: coerceString)  String containerExtension, @JsonKey(name: 'category_id', fromJson: coerceStringOrNull)  String? categoryId, @JsonKey(name: 'category_name', fromJson: coerceStringOrNull)  String? categoryName, @JsonKey(fromJson: coerceStringOrNull)  String? rating, @JsonKey(name: 'stream_type', fromJson: coerceStringOrNull)  String? streamType, @JsonKey(fromJson: coerceStringOrNull)  String? plot, @JsonKey(fromJson: coerceStringOrNull)  String? description, @JsonKey(fromJson: coerceStringOrNull)  String? added, @JsonKey(name: 'last_modified', fromJson: coerceStringOrNull)  String? lastModified)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VodItem() when $default != null:
return $default(_that.streamId,_that.name,_that.streamIcon,_that.cover,_that.containerExtension,_that.categoryId,_that.categoryName,_that.rating,_that.streamType,_that.plot,_that.description,_that.added,_that.lastModified);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'stream_id')  dynamic streamId, @JsonKey(fromJson: coerceString)  String name, @JsonKey(name: 'stream_icon', fromJson: coerceStringOrNull)  String? streamIcon, @JsonKey(fromJson: coerceStringOrNull)  String? cover, @JsonKey(name: 'container_extension', fromJson: coerceString)  String containerExtension, @JsonKey(name: 'category_id', fromJson: coerceStringOrNull)  String? categoryId, @JsonKey(name: 'category_name', fromJson: coerceStringOrNull)  String? categoryName, @JsonKey(fromJson: coerceStringOrNull)  String? rating, @JsonKey(name: 'stream_type', fromJson: coerceStringOrNull)  String? streamType, @JsonKey(fromJson: coerceStringOrNull)  String? plot, @JsonKey(fromJson: coerceStringOrNull)  String? description, @JsonKey(fromJson: coerceStringOrNull)  String? added, @JsonKey(name: 'last_modified', fromJson: coerceStringOrNull)  String? lastModified)  $default,) {final _that = this;
switch (_that) {
case _VodItem():
return $default(_that.streamId,_that.name,_that.streamIcon,_that.cover,_that.containerExtension,_that.categoryId,_that.categoryName,_that.rating,_that.streamType,_that.plot,_that.description,_that.added,_that.lastModified);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'stream_id')  dynamic streamId, @JsonKey(fromJson: coerceString)  String name, @JsonKey(name: 'stream_icon', fromJson: coerceStringOrNull)  String? streamIcon, @JsonKey(fromJson: coerceStringOrNull)  String? cover, @JsonKey(name: 'container_extension', fromJson: coerceString)  String containerExtension, @JsonKey(name: 'category_id', fromJson: coerceStringOrNull)  String? categoryId, @JsonKey(name: 'category_name', fromJson: coerceStringOrNull)  String? categoryName, @JsonKey(fromJson: coerceStringOrNull)  String? rating, @JsonKey(name: 'stream_type', fromJson: coerceStringOrNull)  String? streamType, @JsonKey(fromJson: coerceStringOrNull)  String? plot, @JsonKey(fromJson: coerceStringOrNull)  String? description, @JsonKey(fromJson: coerceStringOrNull)  String? added, @JsonKey(name: 'last_modified', fromJson: coerceStringOrNull)  String? lastModified)?  $default,) {final _that = this;
switch (_that) {
case _VodItem() when $default != null:
return $default(_that.streamId,_that.name,_that.streamIcon,_that.cover,_that.containerExtension,_that.categoryId,_that.categoryName,_that.rating,_that.streamType,_that.plot,_that.description,_that.added,_that.lastModified);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VodItem implements VodItem {
  const _VodItem({@JsonKey(name: 'stream_id') required this.streamId, @JsonKey(fromJson: coerceString) this.name = '', @JsonKey(name: 'stream_icon', fromJson: coerceStringOrNull) this.streamIcon, @JsonKey(fromJson: coerceStringOrNull) this.cover, @JsonKey(name: 'container_extension', fromJson: coerceString) this.containerExtension = 'mp4', @JsonKey(name: 'category_id', fromJson: coerceStringOrNull) this.categoryId, @JsonKey(name: 'category_name', fromJson: coerceStringOrNull) this.categoryName, @JsonKey(fromJson: coerceStringOrNull) this.rating, @JsonKey(name: 'stream_type', fromJson: coerceStringOrNull) this.streamType, @JsonKey(fromJson: coerceStringOrNull) this.plot, @JsonKey(fromJson: coerceStringOrNull) this.description, @JsonKey(fromJson: coerceStringOrNull) this.added, @JsonKey(name: 'last_modified', fromJson: coerceStringOrNull) this.lastModified});
  factory _VodItem.fromJson(Map<String, dynamic> json) => _$VodItemFromJson(json);

@override@JsonKey(name: 'stream_id') final  dynamic streamId;
@override@JsonKey(fromJson: coerceString) final  String name;
@override@JsonKey(name: 'stream_icon', fromJson: coerceStringOrNull) final  String? streamIcon;
@override@JsonKey(fromJson: coerceStringOrNull) final  String? cover;
@override@JsonKey(name: 'container_extension', fromJson: coerceString) final  String containerExtension;
@override@JsonKey(name: 'category_id', fromJson: coerceStringOrNull) final  String? categoryId;
@override@JsonKey(name: 'category_name', fromJson: coerceStringOrNull) final  String? categoryName;
@override@JsonKey(fromJson: coerceStringOrNull) final  String? rating;
@override@JsonKey(name: 'stream_type', fromJson: coerceStringOrNull) final  String? streamType;
@override@JsonKey(fromJson: coerceStringOrNull) final  String? plot;
@override@JsonKey(fromJson: coerceStringOrNull) final  String? description;
@override@JsonKey(fromJson: coerceStringOrNull) final  String? added;
@override@JsonKey(name: 'last_modified', fromJson: coerceStringOrNull) final  String? lastModified;

/// Create a copy of VodItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VodItemCopyWith<_VodItem> get copyWith => __$VodItemCopyWithImpl<_VodItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VodItemToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VodItem&&const DeepCollectionEquality().equals(other.streamId, streamId)&&(identical(other.name, name) || other.name == name)&&(identical(other.streamIcon, streamIcon) || other.streamIcon == streamIcon)&&(identical(other.cover, cover) || other.cover == cover)&&(identical(other.containerExtension, containerExtension) || other.containerExtension == containerExtension)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.categoryName, categoryName) || other.categoryName == categoryName)&&(identical(other.rating, rating) || other.rating == rating)&&(identical(other.streamType, streamType) || other.streamType == streamType)&&(identical(other.plot, plot) || other.plot == plot)&&(identical(other.description, description) || other.description == description)&&(identical(other.added, added) || other.added == added)&&(identical(other.lastModified, lastModified) || other.lastModified == lastModified));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(streamId),name,streamIcon,cover,containerExtension,categoryId,categoryName,rating,streamType,plot,description,added,lastModified);

@override
String toString() {
  return 'VodItem(streamId: $streamId, name: $name, streamIcon: $streamIcon, cover: $cover, containerExtension: $containerExtension, categoryId: $categoryId, categoryName: $categoryName, rating: $rating, streamType: $streamType, plot: $plot, description: $description, added: $added, lastModified: $lastModified)';
}


}

/// @nodoc
abstract mixin class _$VodItemCopyWith<$Res> implements $VodItemCopyWith<$Res> {
  factory _$VodItemCopyWith(_VodItem value, $Res Function(_VodItem) _then) = __$VodItemCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'stream_id') dynamic streamId,@JsonKey(fromJson: coerceString) String name,@JsonKey(name: 'stream_icon', fromJson: coerceStringOrNull) String? streamIcon,@JsonKey(fromJson: coerceStringOrNull) String? cover,@JsonKey(name: 'container_extension', fromJson: coerceString) String containerExtension,@JsonKey(name: 'category_id', fromJson: coerceStringOrNull) String? categoryId,@JsonKey(name: 'category_name', fromJson: coerceStringOrNull) String? categoryName,@JsonKey(fromJson: coerceStringOrNull) String? rating,@JsonKey(name: 'stream_type', fromJson: coerceStringOrNull) String? streamType,@JsonKey(fromJson: coerceStringOrNull) String? plot,@JsonKey(fromJson: coerceStringOrNull) String? description,@JsonKey(fromJson: coerceStringOrNull) String? added,@JsonKey(name: 'last_modified', fromJson: coerceStringOrNull) String? lastModified
});




}
/// @nodoc
class __$VodItemCopyWithImpl<$Res>
    implements _$VodItemCopyWith<$Res> {
  __$VodItemCopyWithImpl(this._self, this._then);

  final _VodItem _self;
  final $Res Function(_VodItem) _then;

/// Create a copy of VodItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? streamId = freezed,Object? name = null,Object? streamIcon = freezed,Object? cover = freezed,Object? containerExtension = null,Object? categoryId = freezed,Object? categoryName = freezed,Object? rating = freezed,Object? streamType = freezed,Object? plot = freezed,Object? description = freezed,Object? added = freezed,Object? lastModified = freezed,}) {
  return _then(_VodItem(
streamId: freezed == streamId ? _self.streamId : streamId // ignore: cast_nullable_to_non_nullable
as dynamic,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,streamIcon: freezed == streamIcon ? _self.streamIcon : streamIcon // ignore: cast_nullable_to_non_nullable
as String?,cover: freezed == cover ? _self.cover : cover // ignore: cast_nullable_to_non_nullable
as String?,containerExtension: null == containerExtension ? _self.containerExtension : containerExtension // ignore: cast_nullable_to_non_nullable
as String,categoryId: freezed == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String?,categoryName: freezed == categoryName ? _self.categoryName : categoryName // ignore: cast_nullable_to_non_nullable
as String?,rating: freezed == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as String?,streamType: freezed == streamType ? _self.streamType : streamType // ignore: cast_nullable_to_non_nullable
as String?,plot: freezed == plot ? _self.plot : plot // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,added: freezed == added ? _self.added : added // ignore: cast_nullable_to_non_nullable
as String?,lastModified: freezed == lastModified ? _self.lastModified : lastModified // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
