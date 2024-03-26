// Copyright 2021-2022 Workiva.
// Licensed under the Apache License, Version 2.0. Please see https://github.com/Workiva/opentelemetry-dart/blob/master/LICENSE for more information

import 'package:opentelemetry/src/api/trace/trace_flags.dart';
import 'package:opentelemetry/src/api/propagation/general_propagator.dart';

import '../../../api.dart' as api;

/// [DatadogTraceContextPropagator] is responsible for extracting and injecting trace context into carriers.
/// See https://docs.datadoghq.com/tracing/other_telemetry/connect_logs_and_traces/opentelemetry?tab=python
/// and https://docs.datadoghq.com/tracing/guide/send_traces_to_agent_by_api/?tab=shell#model for details.
class DatadogTraceContextPropagator extends GeneralPropagator<
    DatadogTraceIdPropagator,
    DatadogSpanIdPropagator,
    DatadogSamplingPriorityPropagator,
    NoopTraceStatePropagator> {
  DatadogTraceContextPropagator()
      : super(
          DatadogTraceIdPropagator(),
          DatadogSpanIdPropagator(),
          DatadogSamplingPriorityPropagator(),
          NoopTraceStatePropagator(),
        );
}

/// [DatadogTraceIdPropagator] is a [TraceIdPropagator] that extracts and injects
/// [api.TraceId].
class DatadogTraceIdPropagator implements TraceIdPropagator {
  static const key = 'x-datadog-trace-id';

  static final _max = BigInt.parse('f' * 32, radix: 16);

  /// [extract] constructs a [api.TraceId] from a carrier.
  /// The trace_id is The unique integer (64-bit unsigned or 128-bit unsigned) ID of the trace
  /// containing this span.
  /// https://docs.datadoghq.com/tracing/guide/send_traces_to_agent_by_api/?tab=shell#model
  ///
  /// OpenTelemetry TraceId and SpanId properties differ from Datadog conventions. Therefore it’s
  /// necessary to translate TraceId and SpanId from their OpenTelemetry formats (a 128bit unsigned
  /// int and 64bit unsigned int represented as a 32-hex-character and
  /// 16-hex-character lowercase string, respectively) into their Datadog Formats(a 64bit unsigned int).
  /// https://docs.datadoghq.com/tracing/other_telemetry/connect_logs_and_traces/opentelemetry?tab=python
  ///
  /// These documents seem to contradict each other, but this method assumes that the trace_id is 64
  /// bits or 128 bits.
  @override
  api.TraceId extract(dynamic carrier, api.TextMapGetter getter) {
    final idStr = getter.get(carrier, key);
    if (idStr == null) {
      throw Exception('$key not found in carrier');
    }
    final value = BigInt.parse(idStr);
    if (value.isNegative || value > _max) {
      throw FormatException(
          'TraceId must be less than a 128-bit unsigned integer', idStr);
    }
    return api.TraceId.fromString(value.toRadixString(16));
  }

  /// [inject] sets the value of the [api.TraceId] in the carrier.
  @override
  void inject(dynamic carrier, api.TextMapSetter setter, api.TraceId value) {
    setter.set(carrier, key, int.parse(value.toString(), radix: 16).toString());
  }
}

/// [DatadogSpanIdPropagator] is a [SpanIdPropagator] that extracts and injects
/// [api.SpanId].
class DatadogSpanIdPropagator implements SpanIdPropagator {
  static const key = 'x-datadog-parent-id';

  static final _max = BigInt.parse('f' * 16, radix: 16);

  /// [extract] constructs a [api.SpanId] from a carrier.
  // OpenTelemetry TraceId and SpanId properties differ from Datadog conventions. Therefore it’s
  // necessary to translate TraceId and SpanId from their OpenTelemetry formats (a 128bit unsigned
  // int and 64bit unsigned int represented as a 32-hex-character and
  // 16-hex-character lowercase string, respectively) into their Datadog Formats(a 64bit unsigned int).
  // https://docs.datadoghq.com/tracing/other_telemetry/connect_logs_and_traces/opentelemetry?tab=python
  @override
  api.SpanId extract(dynamic carrier, api.TextMapGetter getter) {
    final idStr = getter.get(carrier, key);
    if (idStr == null) {
      throw Exception('$key not found in carrier');
    }
    final value = BigInt.parse(idStr);
    if (value.isNegative || value > _max) {
      throw FormatException(
          'SpanId must be less than a 64-bit unsigned integer', idStr);
    }
    return api.SpanId.fromString(value.toRadixString(16));
  }

  /// [inject] sets the value of the [api.SpanId] in the carrier.
  @override
  void inject(dynamic carrier, api.TextMapSetter setter, api.SpanId value) {
    final idHexStr = value.toString();
    final idStr = int.parse(
      idHexStr.length > 16 ? idHexStr.substring(16, 32) : idHexStr,
      radix: 16,
    ).toString();
    setter.set(carrier, key, idStr);
  }
}

/// [DatadogSamplingPriorityPropagator] is a [TraceFlagsPropagator] that extracts
/// and injects [api.TraceFlags].
class DatadogSamplingPriorityPropagator
    implements TraceFlagsPropagator {
  static const key = 'x-datadog-sampling-priority';

  static const _sampledOn = '1';
  static const _sampledOff = '0';

  /// [extract] constructs a [api.TraceFlags] from a carrier.
  @override
  int extract(dynamic carrier, api.TextMapGetter getter) {
    final priority = getter.get(carrier, key);
    return priority == _sampledOn ? TraceFlags.sampled : TraceFlags.none;
  }

  /// [inject] sets the value of the [api.TraceFlags] in the carrier.
  @override
  void inject(dynamic carrier, api.TextMapSetter setter, int value) {
    setter.set(
      carrier,
      key,
      value == TraceFlags.sampled ? _sampledOn : _sampledOff,
    );
  }
}
