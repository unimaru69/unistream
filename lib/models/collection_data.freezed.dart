// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'collection_data.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CollectionData {

 String get id; String get name; List<FavoriteItem> get items; String? get mode;
/// Create a copy of CollectionData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CollectionDataCopyWith<CollectionData> get copyWith => _$CollectionDataCopyWithImpl<CollectionData>(this as CollectionData, _$identity);

  /// Serializes this CollectionData to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CollectionData&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&const DeepCollectionEquality().equals(other.items, items)&&(identical(other.mode, mode) || other.mode == mode));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,const DeepCollectionEquality().hash(items),mode);

@override
String toString() {
  return 'CollectionData(id: $id, name: $name, items: $items, mode: $mode)';
}


}

/// @nodoc
abstract mixin class $CollectionDataCopyWith<$Res>  {
  factory $CollectionDataCopyWith(CollectionData value, $Res Function(CollectionData) _then) = _$CollectionDataCopyWithImpl;
@useResult
$Res call({
 String id, String name, List<FavoriteItem> items, String? mode
});




}
/// @nodoc
class _$CollectionDataCopyWithImpl<$Res>
    implements $CollectionDataCopyWith<$Res> {
  _$CollectionDataCopyWithImpl(this._self, this._then);

  final CollectionData _self;
  final $Res Function(CollectionData) _then;

/// Create a copy of CollectionData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? items = null,Object? mode = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<FavoriteItem>,mode: freezed == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [CollectionData].
extension CollectionDataPatterns on CollectionData {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CollectionData value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CollectionData() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CollectionData value)  $default,){
final _that = this;
switch (_that) {
case _CollectionData():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CollectionData value)?  $default,){
final _that = this;
switch (_that) {
case _CollectionData() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  List<FavoriteItem> items,  String? mode)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CollectionData() when $default != null:
return $default(_that.id,_that.name,_that.items,_that.mode);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  List<FavoriteItem> items,  String? mode)  $default,) {final _that = this;
switch (_that) {
case _CollectionData():
return $default(_that.id,_that.name,_that.items,_that.mode);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  List<FavoriteItem> items,  String? mode)?  $default,) {final _that = this;
switch (_that) {
case _CollectionData() when $default != null:
return $default(_that.id,_that.name,_that.items,_that.mode);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CollectionData implements CollectionData {
  const _CollectionData({required this.id, required this.name, final  List<FavoriteItem> items = const [], this.mode}): _items = items;
  factory _CollectionData.fromJson(Map<String, dynamic> json) => _$CollectionDataFromJson(json);

@override final  String id;
@override final  String name;
 final  List<FavoriteItem> _items;
@override@JsonKey() List<FavoriteItem> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

@override final  String? mode;

/// Create a copy of CollectionData
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CollectionDataCopyWith<_CollectionData> get copyWith => __$CollectionDataCopyWithImpl<_CollectionData>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CollectionDataToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CollectionData&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&const DeepCollectionEquality().equals(other._items, _items)&&(identical(other.mode, mode) || other.mode == mode));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,const DeepCollectionEquality().hash(_items),mode);

@override
String toString() {
  return 'CollectionData(id: $id, name: $name, items: $items, mode: $mode)';
}


}

/// @nodoc
abstract mixin class _$CollectionDataCopyWith<$Res> implements $CollectionDataCopyWith<$Res> {
  factory _$CollectionDataCopyWith(_CollectionData value, $Res Function(_CollectionData) _then) = __$CollectionDataCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, List<FavoriteItem> items, String? mode
});




}
/// @nodoc
class __$CollectionDataCopyWithImpl<$Res>
    implements _$CollectionDataCopyWith<$Res> {
  __$CollectionDataCopyWithImpl(this._self, this._then);

  final _CollectionData _self;
  final $Res Function(_CollectionData) _then;

/// Create a copy of CollectionData
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? items = null,Object? mode = freezed,}) {
  return _then(_CollectionData(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<FavoriteItem>,mode: freezed == mode ? _self.mode : mode // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
