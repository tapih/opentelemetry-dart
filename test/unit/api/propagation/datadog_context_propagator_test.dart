// Copyright 2021-2022 Workiva.
// Licensed under the Apache License, Version 2.0. Please see https://github.com/Workiva/opentelemetry-dart/blob/master/LICENSE for more information

@TestOn('vm')
import 'package:opentelemetry/api.dart' as api;
import 'package:opentelemetry/src/api/propagation/datadog_trace_context_propagator.dart';
import 'package:opentelemetry/src/api/trace/nonrecording_span.dart';
import 'package:test/test.dart';

const uint128MaxStr = '340282366920938463463374607431768211455';
final uint128MaxHexStr = 'f' * 32;

const uint64MaxStr = '18446744073709551615';
final uint64MaxHexStr = 'f' * 16;

const sampleTraceIdStr = '123456';
const sampleTraceIdHexStr = '1e240';

const sampleSpanIdStr = '7890';
const sampleSpanIdHexStr = '1ed2';

const traceIdKey = 'x-datadog-trace-id';
const spanIdKey = 'x-datadog-parent-id';
const samplingPriorityKey = 'x-datadog-sampling-priority';

class TestingInjector implements api.TextMapSetter<Map<String, String>> {
  @override
  void set(Map<String, String> carrier, String key, String value) {
    carrier[key] = value;
  }
}

class TestingExtractor implements api.TextMapGetter<Map<String, String>> {
  @override
  String? get(Map<String, String> carrier, String key) {
    return carrier[key];
  }

  @override
  Iterable<String> keys(Map<String, String> carrier) {
    return carrier.keys;
  }
}

void main() {
  group('DatadogTraceIdPropagator', () {
    final propagator = DatadogTraceIdPropagator();
    group('extract', () {
      final testCases = [
        {
          'name': 'should create id',
          'input': <String, String>{traceIdKey: sampleTraceIdStr},
          'isError': false,
          'expected': sampleTraceIdHexStr.padLeft(32, '0'),
        },
        {
          'name': 'should create id with max value with uint128',
          'input': <String, String>{traceIdKey: uint128MaxStr},
          'isError': false,
          'expected': uint128MaxHexStr,
        },
        {
          'name': 'should throw error if map is null',
          'input': <String, String>{},
          'isError': true,
          'expected': throwsException,
        },
        {
          'name': 'should throw error if value is empty',
          'input': <String, String>{traceIdKey: ''},
          'isError': true,
          'expected': throwsException,
        },
        {
          'name': 'should throw error with value larger than uint128\'s max',
          'input': <String, String>{traceIdKey: '${uint128MaxStr}1'},
          'isError': true,
          'expected': throwsFormatException,
        },
        {
          'name': 'should throw error with larger negative value',
          'input': <String, String>{traceIdKey: '-$sampleTraceIdStr'},
          'isError': true,
          'expected': throwsFormatException,
        },
        {
          'name': 'should throw error with non numeric string',
          'input': <String, String>{traceIdKey: 'abc'},
          'isError': true,
          'expected': throwsFormatException,
        },
      ];

      for (final testCase in testCases) {
        test(testCase['name'], () {
          if (testCase['isError']! as bool) {
            expect(
              () => propagator.extract(
                testCase['input']! as Map<String, String>,
                TestingExtractor(),
              ),
              testCase['expected'],
              reason:
                  '${testCase['name']}, but successful (Expected: ${testCase['expected']})',
            );
          } else {
            final actual = propagator
                .extract(
                  testCase['input']! as Map<String, String>,
                  TestingExtractor(),
                )
                .toString();
            final expected = testCase['expected'];
            expect(
              actual,
              expected,
              reason:
                  '${testCase['name']} (Expected: $expected, Actual: $actual)',
            );
          }
        });
      }
    });

    group('inject', () {
      test('should inject value', () {
        final testCarrier = <String, String>{};
        propagator.inject(
          testCarrier,
          TestingInjector(),
          api.TraceId.fromString(sampleTraceIdHexStr),
        );
        expect(testCarrier[traceIdKey], sampleTraceIdStr);
      });
    });
  });

  group('DatadogSpanIdPropagator', () {
    final propagator = DatadogSpanIdPropagator();
    group('extract', () {
      final testCases = [
        {
          'name': 'should create id',
          'input': <String, String>{spanIdKey: sampleSpanIdStr},
          'isError': false,
          'expected': sampleSpanIdHexStr.padLeft(16, '0'),
        },
        {
          'name': 'should create id with max value with uint64',
          'input': <String, String>{spanIdKey: uint64MaxStr},
          'isError': false,
          'expected': uint64MaxHexStr,
        },
        {
          'name': 'should throw error if map is null',
          'input': <String, String>{},
          'isError': true,
          'expected': throwsException,
        },
        {
          'name': 'should throw error if value is empty',
          'input': <String, String>{spanIdKey: ''},
          'isError': true,
          'expected': throwsException,
        },
        {
          'name': 'should throw error with value larger than uint64\'s max',
          'input': <String, String>{spanIdKey: '${uint64MaxStr}1'},
          'isError': true,
          'expected': throwsFormatException,
        },
        {
          'name': 'should throw error with larger negative value',
          'input': <String, String>{spanIdKey: '-$sampleSpanIdStr'},
          'isError': true,
          'expected': throwsFormatException,
        },
        {
          'name': 'should throw error with non numeric string',
          'input': <String, String>{spanIdKey: 'abc'},
          'isError': true,
          'expected': throwsFormatException,
        },
      ];

      for (final testCase in testCases) {
        test(testCase['name'], () {
          if (testCase['isError']! as bool) {
            expect(
              () => propagator.extract(
                testCase['input']! as Map<String, String>,
                TestingExtractor(),
              ),
              testCase['expected'],
              reason:
                  '${testCase['name']}, but successful (Expected: ${testCase['expected']})',
            );
          } else {
            final actual = propagator
                .extract(
                  testCase['input']! as Map<String, String>,
                  TestingExtractor(),
                )
                .toString();
            final expected = testCase['expected'];
            expect(
              actual,
              expected,
              reason:
                  '${testCase['name']} (Expected: $expected, Actual: $actual)',
            );
          }
        });
      }
    });

    group('inject', () {
      test('should inject value', () {
        final testCarrier = <String, String>{};
        propagator.inject(
          testCarrier,
          TestingInjector(),
          api.SpanId.fromString(sampleSpanIdHexStr),
        );
        expect(testCarrier[spanIdKey], sampleSpanIdStr);
      });
    });
  });

  group('DatadogSamplingPriorityPropagator', () {
    final propagator = DatadogSamplingPriorityPropagator();

    group('extract', () {
      final testCases = [
        {
          'name': 'should return sampled with sampling priority on',
          'input': <String, String>{samplingPriorityKey: '1'},
          'isError': false,
          'expected': api.TraceFlags.sampled,
        },
        {
          'name': 'should return sampled with sampling priority off',
          'input': <String, String>{samplingPriorityKey: '0'},
          'isError': false,
          'expected': api.TraceFlags.none,
        },
        {
          'name': 'should return none if carrier is empty',
          'input': <String, String>{},
          'isError': false,
          'expected': api.TraceFlags.none,
        },
        {
          'name': 'should return none if sampling priority is out of range',
          'input': <String, String>{samplingPriorityKey: '123'},
          'isError': false,
          'expected': api.TraceFlags.none,
        },
        {
          'name':
              'should return none if sampling priority is non numeric string',
          'input': <String, String>{samplingPriorityKey: 'a'},
          'isError': false,
          'expected': api.TraceFlags.none,
        },
      ];
      for (final testCase in testCases) {
        test(testCase['name'], () {
          if (testCase['isError']! as bool) {
            expect(
              () => propagator.extract(
                testCase['input']! as String,
                TestingExtractor(),
              ),
              testCase['expected'],
              reason:
                  '${testCase['name']}, but successful (Expected: ${testCase['expected']})',
            );
          } else {
            final actual = propagator.extract(
              testCase['input']! as Map<String, String>,
              TestingExtractor(),
            );
            final expected = testCase['expected'];
            expect(
              actual,
              expected,
              reason:
                  '${testCase['name']} (Expected: $expected, Actual: $actual)',
            );
          }
        });
      }

      group('inject', () {
        test('should inject value', () {
          final testCarrier = <String, String>{};
          propagator.inject(
            testCarrier,
            TestingInjector(),
            api.TraceFlags.sampled,
          );
          expect(testCarrier[samplingPriorityKey], '1');
        });
      });
    });
  });

  group('DatadogTraceContextPropagator', () {
    final testPropagator = DatadogTraceContextPropagator();

    group('extract', () {
      final current = api.Context.current;
      final testCases = [
        {
          'name': 'should return the extracted context',
          'input': <String, String>{
            traceIdKey: sampleTraceIdStr,
            spanIdKey: sampleSpanIdStr,
            samplingPriorityKey: '1',
          },
          'expected': api.SpanContext(
            api.TraceId.fromString(sampleTraceIdHexStr),
            api.SpanId.fromString(sampleSpanIdHexStr),
            api.TraceFlags.sampled,
            api.TraceState.empty(),
          ),
        },
        {
          'name':
              'should return the extracted context even if traceFlags is null',
          'input': <String, String>{
            traceIdKey: sampleTraceIdStr,
            spanIdKey: sampleSpanIdStr,
          },
          'expected': api.SpanContext(
            api.TraceId.fromString(sampleTraceIdHexStr),
            api.SpanId.fromString(sampleSpanIdHexStr),
            api.TraceFlags.none,
            api.TraceState.empty(),
          ),
        },
        {
          'name': 'should return the current context if traceId is null',
          'input': <String, String>{
            spanIdKey: sampleSpanIdStr,
          },
          'expected': current.spanContext,
        },
        {
          'name': 'should return the current context if spanId is null',
          'input': <String, String>{
            traceIdKey: sampleTraceIdStr,
          },
          'expected': current.spanContext,
        },
      ];

      for (final testCase in testCases) {
        test(testCase['name'], () {
          final result = testPropagator.extract(
            current,
            testCase['input'],
            TestingExtractor(),
          );
          // traceId
          {
            final actual = result.spanContext.traceId.toString();
            final expected =
                (testCase['expected']! as api.SpanContext).traceId.toString();
            expect(
              actual,
              equals(expected),
              reason: '${testCase['name']}: Expected $expected, got $actual',
            );
          }
          // spanId
          {
            final actual = result.spanContext.spanId.toString();
            final expected =
                (testCase['expected']! as api.SpanContext).spanId.toString();
            expect(
              actual,
              equals(expected),
              reason:
                  '${testCase['name']} (Expected: $expected, Actual: $actual)',
            );
          }
          // traceFlags
          {
            final actual = result.spanContext.traceFlags;
            final expected =
                (testCase['expected']! as api.SpanContext).traceFlags;
            expect(
              actual,
              equals(expected),
              reason:
                  '${testCase['name']} (Expected: $expected, Actual: $actual)',
            );
          }
        });
      }
    });

    group('inject', () {
      final testCases = [
        {
          'name': 'should inject values',
          'input': api.Context.current.withSpan(
            NonRecordingSpan(
              api.SpanContext(
                api.TraceId.fromString(sampleTraceIdHexStr),
                api.SpanId.fromString(sampleSpanIdHexStr),
                api.TraceFlags.none,
                api.TraceState.empty(),
              ),
            ),
          ),
          'expected': <String, String>{
            traceIdKey: sampleTraceIdStr,
            spanIdKey: sampleSpanIdStr,
            samplingPriorityKey: '0',
          },
        },
        {
          'name': 'should not inject values if span context is invalid',
          'input': api.Context.current.withSpan(
            NonRecordingSpan(
              api.SpanContext(
                api.TraceId.invalid(),
                api.SpanId.invalid(),
                api.TraceFlags.none,
                api.TraceState.empty(),
              ),
            ),
          ),
          'expected': <String, String>{},
        },
      ];

      for (final testCase in testCases) {
        test(testCase['name'], () {
          final actual = <String, String>{};
          testPropagator.inject(
            testCase['input']! as api.Context,
            actual,
            TestingInjector(),
          );
          final expected = testCase['expected'];
          expect(
            actual,
            equals(expected),
            reason:
                '${testCase['name']} (Expected: $expected, Actual: $actual)',
          );
        });
      }
    });
  });
}
