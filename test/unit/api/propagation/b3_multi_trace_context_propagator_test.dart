// Copyright 2021-2022 Workiva.
// Licensed under the Apache License, Version 2.0. Please see https://github.com/Workiva/opentelemetry-dart/blob/master/LICENSE for more information

@TestOn('vm')
import 'package:mockito/mockito.dart';
import 'package:opentelemetry/api.dart' as api;
import 'package:opentelemetry/src/api/propagation/b3_multi_trace_context_propagator.dart';
import 'package:opentelemetry/src/api/trace/nonrecording_span.dart';
import 'package:test/test.dart';

const valid16 = '0123456789abcdef';
const valid32 = '$valid16$valid16';

const traceIdKey = 'x-b3-traceid';
const spanIdKey = 'x-b3-spanid';
const sampledKey = 'x-b3-sampled';
const debugKey = 'x-b3-flags';

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
  group('B3MultiTraceIdCommand', () {
    final command = B3MultiTraceIdCommand();
    group('extract', () {
      final testCases = [
        {
          'name': 'should create id if 32 valid chars are given',
          'input': <String, String>{traceIdKey: valid32},
          'isError': false,
          'expected': valid32,
        },
        {
          'name': 'should create id if 16 valid chars are given',
          'input': <String, String>{
            traceIdKey: valid16,
          },
          'isError': false,
          'expected': '${'0' * 16}$valid16',
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
          'name': 'should throw error if 31 valid chars are given',
          'input': <String, String>{traceIdKey: valid32.substring(0, 31)},
          'isError': true,
          'expected': throwsFormatException,
        },
        {
          'name': 'should throw error if 33 valid chars are given',
          'input': <String, String>{traceIdKey: '${valid32}0'},
          'isError': true,
          'expected': throwsFormatException,
        },
        {
          'name': 'should throw error if some chars are invalid',
          'input': <String, String>{
            traceIdKey: '${valid32.substring(0, 29)}xyz'
          },
          'isError': true,
          'expected': throwsFormatException,
        },
        {
          'name': 'should throw error if value is invalid',
          'input': <String, String>{
            traceIdKey: api.TraceId.invalid().toString()
          },
          'isError': true,
          'expected': throwsException,
        },
      ];

      for (final testCase in testCases) {
        test(testCase['name'], () {
          if (testCase['isError']! as bool) {
            expect(
              () => command.extract(
                testCase['input']! as Map<String, String>,
                TestingExtractor(),
              ),
              testCase['expected'],
              reason:
                  '${testCase['name']}, but successful (Expected: ${testCase['expected']})',
            );
          } else {
            final actual = command
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
        command.inject(
          testCarrier,
          TestingInjector(),
          api.TraceId.fromString(valid32),
        );
        expect(testCarrier[traceIdKey], valid32);
      });
    });
  });

  group('B3MultiSpanIdCommand', () {
    final command = B3MultiSpanIdCommand();
    group('extract', () {
      final testCases = [
        {
          'name': 'should create id if 16 valid chars are given',
          'input': <String, String>{spanIdKey: valid16},
          'isError': false,
          'expected': valid16,
        },
        {
          'name': 'should throw error if carrier is null',
          'input': <String, String>{},
          'isError': true,
          'expected': throwsException,
        },
        {
          'name': 'should throw error if value is empty',
          'input': <String, String>{spanIdKey: ''},
          'isError': true,
          'expected': throwsFormatException,
        },
        {
          'name': 'should throw error if 15 valid chars are given',
          'input': <String, String>{spanIdKey: valid16.substring(0, 15)},
          'isError': true,
          'expected': throwsFormatException,
        },
        {
          'name': 'should throw error if 17 valid chars are given',
          'input': <String, String>{spanIdKey: '${valid16}0'},
          'isError': true,
          'expected': throwsFormatException,
        },
        {
          'name': 'should throw error if some chars are invalid',
          'input': <String, String>{
            spanIdKey: '${valid16.substring(0, 13)}xyz'
          },
          'isError': true,
          'expected': throwsFormatException,
        },
        {
          'name': 'should throw error if value is invalid',
          'input': <String, String>{spanIdKey: api.SpanId.invalid().toString()},
          'isError': true,
          'expected': throwsException,
        },
      ];

      for (final testCase in testCases) {
        test(testCase['name'], () {
          if (testCase['isError']! as bool) {
            expect(
              () => command.extract(
                testCase['input']! as Map<String, String>,
                TestingExtractor(),
              ),
              testCase['expected'],
              reason:
                  '${testCase['name']}, but successful (Expected: ${testCase['expected']})',
            );
          } else {
            final actual = command
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
        command.inject(
          testCarrier,
          TestingInjector(),
          api.SpanId.fromString(valid16),
        );
        expect(testCarrier[spanIdKey], valid16);
      });
    });
  });

  group('B3MultiTraceFlagsCommand', () {
    final command = B3MultiTraceFlagsCommand();
    group('extract', () {
      final testCases = [
        {
          'name': 'should return sampled with debug on',
          'input': <String, String>{debugKey: '1'},
          'isError': false,
          'expected': api.TraceFlags.sampled,
        },
        {
          'name': 'should return sampled with sampled on',
          'input': <String, String>{sampledKey: '1'},
          'isError': false,
          'expected': api.TraceFlags.sampled,
        },
        {
          'name': 'should return none with sampled off and debug off',
          'input': <String, String>{
            sampledKey: '0',
            debugKey: '0',
          },
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
          'name': 'should return none with non numeric string',
          'input': <String, String>{
            sampledKey: 'a',
            debugKey: 'b',
          },
          'isError': false,
          'expected': api.TraceFlags.none,
        },
      ];
      for (final testCase in testCases) {
        test(testCase['name'], () {
          if (testCase['isError']! as bool) {
            expect(
              () => command.extract(
                testCase['input']! as String,
                TestingExtractor(),
              ),
              testCase['expected'],
              reason:
                  '${testCase['name']}, but successful (Expected: ${testCase['expected']})',
            );
          } else {
            final actual = command.extract(
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
    });

    group('inject', () {
      final testCases = [
        {
          'name': 'should inject sampled on',
          'input': api.TraceFlags.sampled,
          'expected': <String, String>{
            sampledKey: '1',
          },
        },
        {
          'name': 'should inject sampled off',
          'input': api.TraceFlags.none,
          'expected': <String, String>{
            sampledKey: '0',
          },
        },
      ];
      for (final testCase in testCases) {
        test(testCase['name'], () {
          final testCarrier = <String, String>{};
          command.inject(
            testCarrier,
            TestingInjector(),
            testCase['input']! as int,
          );
          expect(testCarrier, equals(testCase['expected']));
        });
      }
    });
  });

  group('B3MultiTraceContextPropagator', () {
    final testPropagator = B3MultiTraceContextPropagator();

    group('extract', () {
      final current = api.Context.current;
      final testCases = [
        {
          'name': 'should return the extracted context',
          'input': <String, String>{
            traceIdKey: valid32,
            spanIdKey: valid16,
            sampledKey: '1',
          },
          'expected': api.SpanContext(
            api.TraceId.fromString(valid32),
            api.SpanId.fromString(valid16),
            api.TraceFlags.sampled,
            api.TraceState.empty(),
          ),
        },
        {
          'name':
              'should return the extracted context even if traceFlags is null',
          'input': <String, String>{
            traceIdKey: valid32,
            spanIdKey: valid16,
          },
          'expected': api.SpanContext(
            api.TraceId.fromString(valid32),
            api.SpanId.fromString(valid16),
            api.TraceFlags.none,
            api.TraceState.empty(),
          ),
        },
        {
          'name': 'should return the current context if traceId is null',
          'input': <String, String>{
            spanIdKey: valid16,
          },
          'expected': current.spanContext,
        },
        {
          'name': 'should return the current context if spanId is null',
          'input': <String, String>{
            traceIdKey: valid32,
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
                api.TraceId.fromString(valid32),
                api.SpanId.fromString(valid16),
                api.TraceFlags.none,
                api.TraceState.empty(),
              ),
            ),
          ),
          'expected': <String, String>{
            traceIdKey: valid32,
            spanIdKey: valid16,
            sampledKey: '0',
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
