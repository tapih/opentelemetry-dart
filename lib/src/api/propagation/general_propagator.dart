import 'package:opentelemetry/src/api/trace/trace_state.dart';

import '../trace/nonrecording_span.dart';
import '../../api/context/context.dart' as api;

import '../../../api.dart' as api;

/// [SubPropagator] is responsible for extracting and injecting a value of type [T] from a carrier.
abstract class SubPropagator<T> {
  T extract(dynamic carrier, api.TextMapGetter getter);

  void inject(dynamic carrier, api.TextMapSetter setter, T value);
}

/// [TraceIdPropagator] is responsible for extracting and injecting a [api.TraceId] from a carrier.
typedef TraceIdPropagator = SubPropagator<api.TraceId>;

/// [SpanIdPropagator] is responsible for extracting and injecting a [api.SpanId] from a carrier.
typedef SpanIdPropagator = SubPropagator<api.SpanId>;

/// [TraceFlagsPropagator] is responsible for extracting and injecting a [api.TraceFlags] from a carrier.
typedef TraceFlagsPropagator = SubPropagator<int>;

/// [TraceStatePropagator] is responsible for extracting and injecting a [api.TraceState] from a carrier.
typedef TraceStatePropagator = SubPropagator<api.TraceState>;

/// [GeneralPropagator] is a general purpose propagator that can be used to create a propagator for any format.
class GeneralPropagator<
    T extends TraceIdPropagator,
    S extends SpanIdPropagator,
    F extends TraceFlagsPropagator,
    A extends TraceStatePropagator> implements api.TextMapPropagator {
  final T traceIdPropagator;
  final S spanIdPropagator;
  final F traceFlagsPropagator;
  final A traceStatePropagator;

  GeneralPropagator(
    this.traceIdPropagator,
    this.spanIdPropagator,
    this.traceFlagsPropagator,
    this.traceStatePropagator,
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
            traceIdPropagator.extract(carrier, getter),
            spanIdPropagator.extract(carrier, getter),
            traceFlagsPropagator.extract(carrier, getter),
            traceStatePropagator.extract(carrier, getter),
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

    traceIdPropagator.inject(carrier, setter, spanContext.traceId);
    spanIdPropagator.inject(carrier, setter, spanContext.spanId);
    traceFlagsPropagator.inject(carrier, setter, spanContext.traceFlags);
    traceStatePropagator.inject(carrier, setter, spanContext.traceState);
  }
}


/// [NoopTraceStatePropagator] is a no-op implementation of [TraceStatePropagator].
class NoopTraceStatePropagator implements TraceStatePropagator {
  /// [extract] always returns an empty [api.TraceState].
  @override
  TraceState extract(dynamic carrier, api.TextMapGetter getter) {
    return TraceState.empty();
  }

  /// [inject] does nothing.
  @override
  void inject(dynamic carrier, api.TextMapSetter setter, void value) {}
}
