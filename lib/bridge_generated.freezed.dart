// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target

part of 'bridge_generated.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more informations: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

/// @nodoc
class _$ReplyTearOff {
  const _$ReplyTearOff();

  GetModelReply getModelReply(Project field0) {
    return GetModelReply(
      field0,
    );
  }
}

/// @nodoc
const $Reply = _$ReplyTearOff();

/// @nodoc
mixin _$Reply {
  Project get field0 => throw _privateConstructorUsedError;

  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(Project field0) getModelReply,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult Function(Project field0)? getModelReply,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(Project field0)? getModelReply,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(GetModelReply value) getModelReply,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult Function(GetModelReply value)? getModelReply,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(GetModelReply value)? getModelReply,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $ReplyCopyWith<Reply> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ReplyCopyWith<$Res> {
  factory $ReplyCopyWith(Reply value, $Res Function(Reply) then) =
      _$ReplyCopyWithImpl<$Res>;
  $Res call({Project field0});
}

/// @nodoc
class _$ReplyCopyWithImpl<$Res> implements $ReplyCopyWith<$Res> {
  _$ReplyCopyWithImpl(this._value, this._then);

  final Reply _value;
  // ignore: unused_field
  final $Res Function(Reply) _then;

  @override
  $Res call({
    Object? field0 = freezed,
  }) {
    return _then(_value.copyWith(
      field0: field0 == freezed
          ? _value.field0
          : field0 // ignore: cast_nullable_to_non_nullable
              as Project,
    ));
  }
}

/// @nodoc
abstract class $GetModelReplyCopyWith<$Res> implements $ReplyCopyWith<$Res> {
  factory $GetModelReplyCopyWith(
          GetModelReply value, $Res Function(GetModelReply) then) =
      _$GetModelReplyCopyWithImpl<$Res>;
  @override
  $Res call({Project field0});
}

/// @nodoc
class _$GetModelReplyCopyWithImpl<$Res> extends _$ReplyCopyWithImpl<$Res>
    implements $GetModelReplyCopyWith<$Res> {
  _$GetModelReplyCopyWithImpl(
      GetModelReply _value, $Res Function(GetModelReply) _then)
      : super(_value, (v) => _then(v as GetModelReply));

  @override
  GetModelReply get _value => super._value as GetModelReply;

  @override
  $Res call({
    Object? field0 = freezed,
  }) {
    return _then(GetModelReply(
      field0 == freezed
          ? _value.field0
          : field0 // ignore: cast_nullable_to_non_nullable
              as Project,
    ));
  }
}

/// @nodoc

class _$GetModelReply implements GetModelReply {
  const _$GetModelReply(this.field0);

  @override
  final Project field0;

  @override
  String toString() {
    return 'Reply.getModelReply(field0: $field0)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is GetModelReply &&
            const DeepCollectionEquality().equals(other.field0, field0));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, const DeepCollectionEquality().hash(field0));

  @JsonKey(ignore: true)
  @override
  $GetModelReplyCopyWith<GetModelReply> get copyWith =>
      _$GetModelReplyCopyWithImpl<GetModelReply>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(Project field0) getModelReply,
  }) {
    return getModelReply(field0);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult Function(Project field0)? getModelReply,
  }) {
    return getModelReply?.call(field0);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(Project field0)? getModelReply,
    required TResult orElse(),
  }) {
    if (getModelReply != null) {
      return getModelReply(field0);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(GetModelReply value) getModelReply,
  }) {
    return getModelReply(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult Function(GetModelReply value)? getModelReply,
  }) {
    return getModelReply?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(GetModelReply value)? getModelReply,
    required TResult orElse(),
  }) {
    if (getModelReply != null) {
      return getModelReply(this);
    }
    return orElse();
  }
}

abstract class GetModelReply implements Reply {
  const factory GetModelReply(Project field0) = _$GetModelReply;

  @override
  Project get field0;
  @override
  @JsonKey(ignore: true)
  $GetModelReplyCopyWith<GetModelReply> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
class _$RequestTearOff {
  const _$RequestTearOff();

  Init init() {
    return const Init();
  }

  Exit exit() {
    return const Exit();
  }

  GetModel getModel() {
    return const GetModel();
  }

  LoadModel loadModel(Project field0) {
    return LoadModel(
      field0,
    );
  }
}

/// @nodoc
const $Request = _$RequestTearOff();

/// @nodoc
mixin _$Request {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() init,
    required TResult Function() exit,
    required TResult Function() getModel,
    required TResult Function(Project field0) loadModel,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult Function()? init,
    TResult Function()? exit,
    TResult Function()? getModel,
    TResult Function(Project field0)? loadModel,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? init,
    TResult Function()? exit,
    TResult Function()? getModel,
    TResult Function(Project field0)? loadModel,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(Init value) init,
    required TResult Function(Exit value) exit,
    required TResult Function(GetModel value) getModel,
    required TResult Function(LoadModel value) loadModel,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult Function(Init value)? init,
    TResult Function(Exit value)? exit,
    TResult Function(GetModel value)? getModel,
    TResult Function(LoadModel value)? loadModel,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(Init value)? init,
    TResult Function(Exit value)? exit,
    TResult Function(GetModel value)? getModel,
    TResult Function(LoadModel value)? loadModel,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $RequestCopyWith<$Res> {
  factory $RequestCopyWith(Request value, $Res Function(Request) then) =
      _$RequestCopyWithImpl<$Res>;
}

/// @nodoc
class _$RequestCopyWithImpl<$Res> implements $RequestCopyWith<$Res> {
  _$RequestCopyWithImpl(this._value, this._then);

  final Request _value;
  // ignore: unused_field
  final $Res Function(Request) _then;
}

/// @nodoc
abstract class $InitCopyWith<$Res> {
  factory $InitCopyWith(Init value, $Res Function(Init) then) =
      _$InitCopyWithImpl<$Res>;
}

/// @nodoc
class _$InitCopyWithImpl<$Res> extends _$RequestCopyWithImpl<$Res>
    implements $InitCopyWith<$Res> {
  _$InitCopyWithImpl(Init _value, $Res Function(Init) _then)
      : super(_value, (v) => _then(v as Init));

  @override
  Init get _value => super._value as Init;
}

/// @nodoc

class _$Init implements Init {
  const _$Init();

  @override
  String toString() {
    return 'Request.init()';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is Init);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() init,
    required TResult Function() exit,
    required TResult Function() getModel,
    required TResult Function(Project field0) loadModel,
  }) {
    return init();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult Function()? init,
    TResult Function()? exit,
    TResult Function()? getModel,
    TResult Function(Project field0)? loadModel,
  }) {
    return init?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? init,
    TResult Function()? exit,
    TResult Function()? getModel,
    TResult Function(Project field0)? loadModel,
    required TResult orElse(),
  }) {
    if (init != null) {
      return init();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(Init value) init,
    required TResult Function(Exit value) exit,
    required TResult Function(GetModel value) getModel,
    required TResult Function(LoadModel value) loadModel,
  }) {
    return init(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult Function(Init value)? init,
    TResult Function(Exit value)? exit,
    TResult Function(GetModel value)? getModel,
    TResult Function(LoadModel value)? loadModel,
  }) {
    return init?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(Init value)? init,
    TResult Function(Exit value)? exit,
    TResult Function(GetModel value)? getModel,
    TResult Function(LoadModel value)? loadModel,
    required TResult orElse(),
  }) {
    if (init != null) {
      return init(this);
    }
    return orElse();
  }
}

abstract class Init implements Request {
  const factory Init() = _$Init;
}

/// @nodoc
abstract class $ExitCopyWith<$Res> {
  factory $ExitCopyWith(Exit value, $Res Function(Exit) then) =
      _$ExitCopyWithImpl<$Res>;
}

/// @nodoc
class _$ExitCopyWithImpl<$Res> extends _$RequestCopyWithImpl<$Res>
    implements $ExitCopyWith<$Res> {
  _$ExitCopyWithImpl(Exit _value, $Res Function(Exit) _then)
      : super(_value, (v) => _then(v as Exit));

  @override
  Exit get _value => super._value as Exit;
}

/// @nodoc

class _$Exit implements Exit {
  const _$Exit();

  @override
  String toString() {
    return 'Request.exit()';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is Exit);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() init,
    required TResult Function() exit,
    required TResult Function() getModel,
    required TResult Function(Project field0) loadModel,
  }) {
    return exit();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult Function()? init,
    TResult Function()? exit,
    TResult Function()? getModel,
    TResult Function(Project field0)? loadModel,
  }) {
    return exit?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? init,
    TResult Function()? exit,
    TResult Function()? getModel,
    TResult Function(Project field0)? loadModel,
    required TResult orElse(),
  }) {
    if (exit != null) {
      return exit();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(Init value) init,
    required TResult Function(Exit value) exit,
    required TResult Function(GetModel value) getModel,
    required TResult Function(LoadModel value) loadModel,
  }) {
    return exit(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult Function(Init value)? init,
    TResult Function(Exit value)? exit,
    TResult Function(GetModel value)? getModel,
    TResult Function(LoadModel value)? loadModel,
  }) {
    return exit?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(Init value)? init,
    TResult Function(Exit value)? exit,
    TResult Function(GetModel value)? getModel,
    TResult Function(LoadModel value)? loadModel,
    required TResult orElse(),
  }) {
    if (exit != null) {
      return exit(this);
    }
    return orElse();
  }
}

abstract class Exit implements Request {
  const factory Exit() = _$Exit;
}

/// @nodoc
abstract class $GetModelCopyWith<$Res> {
  factory $GetModelCopyWith(GetModel value, $Res Function(GetModel) then) =
      _$GetModelCopyWithImpl<$Res>;
}

/// @nodoc
class _$GetModelCopyWithImpl<$Res> extends _$RequestCopyWithImpl<$Res>
    implements $GetModelCopyWith<$Res> {
  _$GetModelCopyWithImpl(GetModel _value, $Res Function(GetModel) _then)
      : super(_value, (v) => _then(v as GetModel));

  @override
  GetModel get _value => super._value as GetModel;
}

/// @nodoc

class _$GetModel implements GetModel {
  const _$GetModel();

  @override
  String toString() {
    return 'Request.getModel()';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is GetModel);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() init,
    required TResult Function() exit,
    required TResult Function() getModel,
    required TResult Function(Project field0) loadModel,
  }) {
    return getModel();
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult Function()? init,
    TResult Function()? exit,
    TResult Function()? getModel,
    TResult Function(Project field0)? loadModel,
  }) {
    return getModel?.call();
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? init,
    TResult Function()? exit,
    TResult Function()? getModel,
    TResult Function(Project field0)? loadModel,
    required TResult orElse(),
  }) {
    if (getModel != null) {
      return getModel();
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(Init value) init,
    required TResult Function(Exit value) exit,
    required TResult Function(GetModel value) getModel,
    required TResult Function(LoadModel value) loadModel,
  }) {
    return getModel(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult Function(Init value)? init,
    TResult Function(Exit value)? exit,
    TResult Function(GetModel value)? getModel,
    TResult Function(LoadModel value)? loadModel,
  }) {
    return getModel?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(Init value)? init,
    TResult Function(Exit value)? exit,
    TResult Function(GetModel value)? getModel,
    TResult Function(LoadModel value)? loadModel,
    required TResult orElse(),
  }) {
    if (getModel != null) {
      return getModel(this);
    }
    return orElse();
  }
}

abstract class GetModel implements Request {
  const factory GetModel() = _$GetModel;
}

/// @nodoc
abstract class $LoadModelCopyWith<$Res> {
  factory $LoadModelCopyWith(LoadModel value, $Res Function(LoadModel) then) =
      _$LoadModelCopyWithImpl<$Res>;
  $Res call({Project field0});
}

/// @nodoc
class _$LoadModelCopyWithImpl<$Res> extends _$RequestCopyWithImpl<$Res>
    implements $LoadModelCopyWith<$Res> {
  _$LoadModelCopyWithImpl(LoadModel _value, $Res Function(LoadModel) _then)
      : super(_value, (v) => _then(v as LoadModel));

  @override
  LoadModel get _value => super._value as LoadModel;

  @override
  $Res call({
    Object? field0 = freezed,
  }) {
    return _then(LoadModel(
      field0 == freezed
          ? _value.field0
          : field0 // ignore: cast_nullable_to_non_nullable
              as Project,
    ));
  }
}

/// @nodoc

class _$LoadModel implements LoadModel {
  const _$LoadModel(this.field0);

  @override
  final Project field0;

  @override
  String toString() {
    return 'Request.loadModel(field0: $field0)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is LoadModel &&
            const DeepCollectionEquality().equals(other.field0, field0));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, const DeepCollectionEquality().hash(field0));

  @JsonKey(ignore: true)
  @override
  $LoadModelCopyWith<LoadModel> get copyWith =>
      _$LoadModelCopyWithImpl<LoadModel>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() init,
    required TResult Function() exit,
    required TResult Function() getModel,
    required TResult Function(Project field0) loadModel,
  }) {
    return loadModel(field0);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult Function()? init,
    TResult Function()? exit,
    TResult Function()? getModel,
    TResult Function(Project field0)? loadModel,
  }) {
    return loadModel?.call(field0);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? init,
    TResult Function()? exit,
    TResult Function()? getModel,
    TResult Function(Project field0)? loadModel,
    required TResult orElse(),
  }) {
    if (loadModel != null) {
      return loadModel(field0);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(Init value) init,
    required TResult Function(Exit value) exit,
    required TResult Function(GetModel value) getModel,
    required TResult Function(LoadModel value) loadModel,
  }) {
    return loadModel(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult Function(Init value)? init,
    TResult Function(Exit value)? exit,
    TResult Function(GetModel value)? getModel,
    TResult Function(LoadModel value)? loadModel,
  }) {
    return loadModel?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(Init value)? init,
    TResult Function(Exit value)? exit,
    TResult Function(GetModel value)? getModel,
    TResult Function(LoadModel value)? loadModel,
    required TResult orElse(),
  }) {
    if (loadModel != null) {
      return loadModel(this);
    }
    return orElse();
  }
}

abstract class LoadModel implements Request {
  const factory LoadModel(Project field0) = _$LoadModel;

  Project get field0;
  @JsonKey(ignore: true)
  $LoadModelCopyWith<LoadModel> get copyWith =>
      throw _privateConstructorUsedError;
}
