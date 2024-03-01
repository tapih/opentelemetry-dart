// Copyright 2021-2022 Workiva.
// Licensed under the Apache License, Version 2.0. Please see https://github.com/Workiva/opentelemetry-dart/blob/master/LICENSE for more information

import 'package:logging/logging.dart';
import 'package:opentelemetry/api.dart' as api;
import 'package:opentelemetry/src/experimental_api.dart' as api;

class Counter<T extends num> implements api.Counter<T> {
  final _logger = Logger('opentelemetry.sdk.metrics.counter');

  @override
  void add(T value, {List<api.Attribute>? attributes, api.Context? context}) {
    if (value < 0) {
      _logger.warning('Counter can only record non-negative values. '
          'Received $value. Dropping the measurement.');
          return;
    }
    _record(value, attributes: attributes, context: context);
  }

  void _record(T value, {List<api.Attribute>? attributes, api.Context? context}) {

  }
}
