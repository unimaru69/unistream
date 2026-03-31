// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'series_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SeriesItem {

@JsonKey(name: 'series_id') dynamic get seriesId; String get name; String? get cover;@JsonKey(name: 'stream_icon') String? get streamIcon;@JsonKey(name: 'category_id') String? get categoryId;@JsonKey(name: 'category_name') String? get categoryName;@JsonKey(name: 'num_seasons') String? get numSeasons; String? get rating; String? get plot; String? get description; String? get added;@JsonKey(name: 'last_modified') String? get lastModified;
/// Create a copy of SeriesItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SeriesItemCopyWith<SeriesItem> get copyWith => _$SeriesItemCopyWithImpl<SeriesItem>(this as SeriesItem, _$identity);

  /// Serializes this SeriesItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SeriesItem&&const DeepCollectionEquality().equals(other.seriesId, seriesId)&&(identical(other.name, name) || other.name == name)&&(identical(other.cover, cover) || other.cover == cover)&&(identical(other.streamIcon, streamIcon) || other.streamIcon == streamIcon)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.categoryName, categoryName) || other.categoryName == categoryName)&&(identical(other.numSeasons, numSeasons) || other.numSeasons == numSeasons)&&(identical(other.rating, rating) || other.rating == rating)&&(identical(other.plot, plot) || other.plot == plot)&&(identical(other.description, description) || other.description == description)&&(identical(other.added, added) || other.added == added)&&(identical(other.lastModified, lastModified) || other.lastModified == lastModified));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(seriesId),name,cover,streamIcon,categoryId,categoryName,numSeasons,rating,plot,description,added,lastModified);

@override
String toString() {
  return 'SeriesItem(seriesId: $seriesId, name: $name, cover: $cover, streamIcon: $streamIcon, categoryId: $categoryId, categoryName: $categoryName, numSeasons: $numSeasons, rating: $rating, plot: $plot, description: $description, added: $added, lastModified: $lastModified)';
}


}

/// @nodoc
abstract mixin class $SeriesItemCopyWith<$Res>  {
  factory $SeriesItemCopyWith(SeriesItem value, $Res Function(SeriesItem) _then) = _$SeriesItemCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'series_id') dynamic seriesId, String name, String? cover,@JsonKey(name: 'stream_icon') String? streamIcon,@JsonKey(name: 'category_id') String? categoryId,@JsonKey(name: 'category_name') String? categoryName,@JsonKey(name: 'num_seasons') String? numSeasons, String? rating, String? plot, String? description, String? added,@JsonKey(name: 'last_modified') String? lastModified
});




}
/// @nodoc
class _$SeriesItemCopyWithImpl<$Res>
    implements $SeriesItemCopyWith<$Res> {
  _$SeriesItemCopyWithImpl(this._self, this._then);

  final SeriesItem _self;
  final $Res Function(SeriesItem) _then;

/// Create a copy of SeriesItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? seriesId = freezed,Object? name = null,Object? cover = freezed,Object? streamIcon = freezed,Object? categoryId = freezed,Object? categoryName = freezed,Object? numSeasons = freezed,Object? rating = freezed,Object? plot = freezed,Object? description = freezed,Object? added = freezed,Object? lastModified = freezed,}) {
  return _then(_self.copyWith(
seriesId: freezed == seriesId ? _self.seriesId : seriesId // ignore: cast_nullable_to_non_nullable
as dynamic,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,cover: freezed == cover ? _self.cover : cover // ignore: cast_nullable_to_non_nullable
as String?,streamIcon: freezed == streamIcon ? _self.streamIcon : streamIcon // ignore: cast_nullable_to_non_nullable
as String?,categoryId: freezed == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String?,categoryName: freezed == categoryName ? _self.categoryName : categoryName // ignore: cast_nullable_to_non_nullable
as String?,numSeasons: freezed == numSeasons ? _self.numSeasons : numSeasons // ignore: cast_nullable_to_non_nullable
as String?,rating: freezed == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as String?,plot: freezed == plot ? _self.plot : plot // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,added: freezed == added ? _self.added : added // ignore: cast_nullable_to_non_nullable
as String?,lastModified: freezed == lastModified ? _self.lastModified : lastModified // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [SeriesItem].
extension SeriesItemPatterns on SeriesItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SeriesItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SeriesItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SeriesItem value)  $default,){
final _that = this;
switch (_that) {
case _SeriesItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SeriesItem value)?  $default,){
final _that = this;
switch (_that) {
case _SeriesItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'series_id')  dynamic seriesId,  String name,  String? cover, @JsonKey(name: 'stream_icon')  String? streamIcon, @JsonKey(name: 'category_id')  String? categoryId, @JsonKey(name: 'category_name')  String? categoryName, @JsonKey(name: 'num_seasons')  String? numSeasons,  String? rating,  String? plot,  String? description,  String? added, @JsonKey(name: 'last_modified')  String? lastModified)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SeriesItem() when $default != null:
return $default(_that.seriesId,_that.name,_that.cover,_that.streamIcon,_that.categoryId,_that.categoryName,_that.numSeasons,_that.rating,_that.plot,_that.description,_that.added,_that.lastModified);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'series_id')  dynamic seriesId,  String name,  String? cover, @JsonKey(name: 'stream_icon')  String? streamIcon, @JsonKey(name: 'category_id')  String? categoryId, @JsonKey(name: 'category_name')  String? categoryName, @JsonKey(name: 'num_seasons')  String? numSeasons,  String? rating,  String? plot,  String? description,  String? added, @JsonKey(name: 'last_modified')  String? lastModified)  $default,) {final _that = this;
switch (_that) {
case _SeriesItem():
return $default(_that.seriesId,_that.name,_that.cover,_that.streamIcon,_that.categoryId,_that.categoryName,_that.numSeasons,_that.rating,_that.plot,_that.description,_that.added,_that.lastModified);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'series_id')  dynamic seriesId,  String name,  String? cover, @JsonKey(name: 'stream_icon')  String? streamIcon, @JsonKey(name: 'category_id')  String? categoryId, @JsonKey(name: 'category_name')  String? categoryName, @JsonKey(name: 'num_seasons')  String? numSeasons,  String? rating,  String? plot,  String? description,  String? added, @JsonKey(name: 'last_modified')  String? lastModified)?  $default,) {final _that = this;
switch (_that) {
case _SeriesItem() when $default != null:
return $default(_that.seriesId,_that.name,_that.cover,_that.streamIcon,_that.categoryId,_that.categoryName,_that.numSeasons,_that.rating,_that.plot,_that.description,_that.added,_that.lastModified);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SeriesItem implements SeriesItem {
  const _SeriesItem({@JsonKey(name: 'series_id') required this.seriesId, this.name = '', this.cover, @JsonKey(name: 'stream_icon') this.streamIcon, @JsonKey(name: 'category_id') this.categoryId, @JsonKey(name: 'category_name') this.categoryName, @JsonKey(name: 'num_seasons') this.numSeasons, this.rating, this.plot, this.description, this.added, @JsonKey(name: 'last_modified') this.lastModified});
  factory _SeriesItem.fromJson(Map<String, dynamic> json) => _$SeriesItemFromJson(json);

@override@JsonKey(name: 'series_id') final  dynamic seriesId;
@override@JsonKey() final  String name;
@override final  String? cover;
@override@JsonKey(name: 'stream_icon') final  String? streamIcon;
@override@JsonKey(name: 'category_id') final  String? categoryId;
@override@JsonKey(name: 'category_name') final  String? categoryName;
@override@JsonKey(name: 'num_seasons') final  String? numSeasons;
@override final  String? rating;
@override final  String? plot;
@override final  String? description;
@override final  String? added;
@override@JsonKey(name: 'last_modified') final  String? lastModified;

/// Create a copy of SeriesItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SeriesItemCopyWith<_SeriesItem> get copyWith => __$SeriesItemCopyWithImpl<_SeriesItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SeriesItemToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SeriesItem&&const DeepCollectionEquality().equals(other.seriesId, seriesId)&&(identical(other.name, name) || other.name == name)&&(identical(other.cover, cover) || other.cover == cover)&&(identical(other.streamIcon, streamIcon) || other.streamIcon == streamIcon)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.categoryName, categoryName) || other.categoryName == categoryName)&&(identical(other.numSeasons, numSeasons) || other.numSeasons == numSeasons)&&(identical(other.rating, rating) || other.rating == rating)&&(identical(other.plot, plot) || other.plot == plot)&&(identical(other.description, description) || other.description == description)&&(identical(other.added, added) || other.added == added)&&(identical(other.lastModified, lastModified) || other.lastModified == lastModified));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(seriesId),name,cover,streamIcon,categoryId,categoryName,numSeasons,rating,plot,description,added,lastModified);

@override
String toString() {
  return 'SeriesItem(seriesId: $seriesId, name: $name, cover: $cover, streamIcon: $streamIcon, categoryId: $categoryId, categoryName: $categoryName, numSeasons: $numSeasons, rating: $rating, plot: $plot, description: $description, added: $added, lastModified: $lastModified)';
}


}

/// @nodoc
abstract mixin class _$SeriesItemCopyWith<$Res> implements $SeriesItemCopyWith<$Res> {
  factory _$SeriesItemCopyWith(_SeriesItem value, $Res Function(_SeriesItem) _then) = __$SeriesItemCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'series_id') dynamic seriesId, String name, String? cover,@JsonKey(name: 'stream_icon') String? streamIcon,@JsonKey(name: 'category_id') String? categoryId,@JsonKey(name: 'category_name') String? categoryName,@JsonKey(name: 'num_seasons') String? numSeasons, String? rating, String? plot, String? description, String? added,@JsonKey(name: 'last_modified') String? lastModified
});




}
/// @nodoc
class __$SeriesItemCopyWithImpl<$Res>
    implements _$SeriesItemCopyWith<$Res> {
  __$SeriesItemCopyWithImpl(this._self, this._then);

  final _SeriesItem _self;
  final $Res Function(_SeriesItem) _then;

/// Create a copy of SeriesItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? seriesId = freezed,Object? name = null,Object? cover = freezed,Object? streamIcon = freezed,Object? categoryId = freezed,Object? categoryName = freezed,Object? numSeasons = freezed,Object? rating = freezed,Object? plot = freezed,Object? description = freezed,Object? added = freezed,Object? lastModified = freezed,}) {
  return _then(_SeriesItem(
seriesId: freezed == seriesId ? _self.seriesId : seriesId // ignore: cast_nullable_to_non_nullable
as dynamic,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,cover: freezed == cover ? _self.cover : cover // ignore: cast_nullable_to_non_nullable
as String?,streamIcon: freezed == streamIcon ? _self.streamIcon : streamIcon // ignore: cast_nullable_to_non_nullable
as String?,categoryId: freezed == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as String?,categoryName: freezed == categoryName ? _self.categoryName : categoryName // ignore: cast_nullable_to_non_nullable
as String?,numSeasons: freezed == numSeasons ? _self.numSeasons : numSeasons // ignore: cast_nullable_to_non_nullable
as String?,rating: freezed == rating ? _self.rating : rating // ignore: cast_nullable_to_non_nullable
as String?,plot: freezed == plot ? _self.plot : plot // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,added: freezed == added ? _self.added : added // ignore: cast_nullable_to_non_nullable
as String?,lastModified: freezed == lastModified ? _self.lastModified : lastModified // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
