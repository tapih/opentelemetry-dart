// Copyright 2021-2022 Workiva.
// Licensed under the Apache License, Version 2.0. Please see https://github.com/Workiva/opentelemetry-dart/blob/master/LICENSE for more information

import 'package:opentelemetry/src/api/trace/trace_flags.dart';
import 'package:opentelemetry/src/api/trace/trace_state.dart';

import '../trace/nonrecording_span.dart';
import '../../api/context/context.dart' as api;

import '../../../api.dart' as api;

/// [PropagationCommand] is responsible for extracting and injecting a value of type [T] from a carrier.
abstract class PropagationCommand<T> {
  T extract(dynamic carrier, api.TextMapGetter getter);

  void inject(dynamic carrier, api.TextMapSetter setter, T value);
}

/// [TraceIdPropagationCommand] is responsible for extracting and injecting a [api.TraceId] from a carrier.
typedef TraceIdPropagationCommand = PropagationCommand<api.TraceId>;

/// [SpanIdPropagationCommand] is responsible for extracting and injecting a [api.SpanId] from a carrier.
typedef SpanIdPropagationCommand = PropagationCommand<api.SpanId>;

/// [TraceFlagsPropagationCommand] is responsible for extracting and injecting a [api.TraceFlags] from a carrier.
typedef TraceFlagsPropagationCommand = PropagationCommand<int>;

/// [TraceStatePropagationCommand] is responsible for extracting and injecting a [api.TraceState] from a carrier.
typedef TraceStatePropagationCommand = PropagationCommand<api.TraceState>;

/// [B3MultiTraceContextPropagator] propagates span context using the B3 multi-header HTTP format.
/// See https://github.com/openzipkin/b3-propagation for details.
class B3MultiTraceContextPropagator extends GeneralPropagator {
  B3MultiTraceContextPropagator()
      : super(
          B3MultiTraceIdCommand(),
          B3MultiSpanIdCommand(),
          B3MultiTraceFlagsCommand(),
          NoopTraceStatePropagationCommand(),
        );
}

/// [GeneralPropagator] is a general purpose propagator that can be used to create a propagator for any format.
class GeneralPropagator<
    T extends TraceIdPropagationCommand,
    S extends SpanIdPropagationCommand,
    F extends TraceFlagsPropagationCommand,
    A extends TraceStatePropagationCommand> implements api.TextMapPropagator {
  final T traceIdCommand;
  final S spanIdCommand;
  final F traceFlagsCommand;
  final A traceStateCommand;

  GeneralPropagator(
    this.traceIdCommand,
    this.spanIdCommand,
    this.traceFlagsCommand,
    this.traceStateCommand,
  );

  @override
  api.Context extract(
    api.Context context,
    dynamic carrier,
    api.TextMapGetter getter,
  ) {
    try {
      return context.withSpan(
        NonRecordingSpan(
          api.SpanContext.remote(
            traceIdCommand.extract(carrier, getter),
            spanIdCommand.extract(carrier, getter),
            traceFlagsCommand.extract(carrier, getter),
            api.TraceState.empty(),
          ),
        ),
      );
    } catch (_) {
      return context;
    }
  }

  @override
  void inject(api.Context context, dynamic carrier, api.TextMapSetter setter) {
    final spanContext = context.spanContext;
    if (!spanContext.isValid) {
      return;
    }

    traceIdCommand.inject(carrier, setter, spanContext.traceId);
    spanIdCommand.inject(carrier, setter, spanContext.spanId);
    traceFlagsCommand.inject(carrier, setter, spanContext.traceFlags);
  }
}

class B3MultiTraceIdCommand implements TraceIdPropagationCommand {
  static const key = 'x-b3-traceid';

  /// [extract] constructs a [api.TraceId] from a carrier.
  /// The X-B3-TraceId header is encoded as 32 or 16 lower-hex characters.
  /// See https://github.com/openzipkin/b3-propagation?tab=readme-ov-file#traceid-1 for details.
  @override
  api.TraceId extract(dynamic carrier, api.TextMapGetter getter) {
    final idStr = getter.get(carrier, key);
    if (idStr == null) {
      throw Exception('$key not found in carrier');
    }
    if (!RegExp(r'^([0-9a-f]{32}|[0-9a-f]{16})$').hasMatch(idStr)) {
      throw FormatException(
          'TraceId must be a 16 or 32 lower-hex characters string', idStr);
    }

    final id = api.TraceId.fromString(idStr);
    if (id.toString() == api.TraceId.invalid().toString()) {
      throw Exception('TraceId is invalid (${id.toString()}');
    }
    return id;
  }

  /// [inject] sets the value of the [api.TraceId] in the carrier.
  @override
  void inject(dynamic carrier, api.TextMapSetter setter, api.TraceId value) {
    setter.set(carrier, key, value.toString());
  }
}

class B3MultiSpanIdCommand implements SpanIdPropagationCommand {
  static const key = 'x-b3-spanid';

  /// [extract] constructs a [api.SpanId] from a carrier.
  // The X-B3-SpanId header is encoded as 16 lower-hex characters.
  // See https://github.com/openzipkin/b3-propagation?tab=readme-ov-file#spanid-1 for details.
  @override
  api.SpanId extract(dynamic carrier, api.TextMapGetter getter) {
    final idStr = getter.get(carrier, key);
    if (idStr == null) {
      throw Exception('$key not found in carrier');
    }
    if (!RegExp(r'^[0-9a-f]{16}$').hasMatch(idStr)) {
      throw FormatException(
          'SpanId must be a 16 lower-hex characters string', idStr);
    }

    final id = api.SpanId.fromString(idStr);
    if (id.toString() == api.SpanId.invalid().toString()) {
      throw Exception('TraceId is invalid (${id.toString()}');
    }
    return id;
  }

  /// [inject] sets the value of the [api.SpanId] in the carrier.
  @override
  void inject(dynamic carrier, api.TextMapSetter setter, api.SpanId value) {
    setter.set(carrier, key, value.toString());
  }
}

class B3MultiTraceFlagsCommand implements TraceFlagsPropagationCommand {
  static const sampledKey = 'x-b3-sampled';
  static const debugKey = 'x-b3-flags';

  static const _debugOn = '1';
  static const _sampledOn = '1';
  static const _sampledOff = '0';

  /// [extract] constructs a [api.TraceFlags] from a carrier.
  @override
  int extract(dynamic carrier, api.TextMapGetter getter) {
    // An accept sampling decision is encoded as X-B3-Sampled: 1 and a deny as X-B3-Sampled: 0.
    // See https://github.com/openzipkin/b3-propagation?tab=readme-ov-file#sampling-state-1 for details.
    // It also says that "Absent means defer the decision to the receiver of this header", but
    // OpenTelemetry does not support this behavior.
    final sampled = getter.get(carrier, sampledKey);
    // Debug is encoded as X-B3-Flags: 1. Absent or any other value can be ignored.
    // See https://github.com/openzipkin/b3-propagation?tab=readme-ov-file#debug-flag-1 for details.
    // It also says that "Debug implies an accept decision, so don't also send the X-B3-Sampled header.",
    // but we accept both settings in the same request.
    final debug = getter.get(carrier, debugKey);

    if (debug == _debugOn || sampled == _sampledOn) {
      return TraceFlags.sampled;
    }
    return TraceFlags.none;
  }

  /// [inject] sets the value of the [api.TraceFlags] in the carrier.
  @override
  void inject(dynamic carrier, api.TextMapSetter setter, int value) {
    if ((value & TraceFlags.sampled) != 0) {
      setter.set(carrier, sampledKey, _sampledOn);
      return;
    }
    setter.set(carrier, sampledKey, _sampledOff);
  }
}

/// [NoopTraceStatePropagationCommand] is a no-op implementation of [TraceStatePropagationCommand].
class NoopTraceStatePropagationCommand implements TraceStatePropagationCommand {
  /// [extract] always returns an empty [api.TraceState].
  @override
  TraceState extract(dynamic carrier, api.TextMapGetter getter) {
    return TraceState.empty();
  }

  /// [inject] does nothing.
  @override
  void inject(dynamic carrier, api.TextMapSetter setter, void value) {}
}
