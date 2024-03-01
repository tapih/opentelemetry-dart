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
            traceStateCommand.extract(carrier, getter),
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
    traceStateCommand.inject(carrier, setter, spanContext.traceState);
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
