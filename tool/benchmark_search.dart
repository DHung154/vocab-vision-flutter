import 'dart:convert';
import 'dart:io';

import 'package:giao_dien/catalog_data.dart';
import 'package:giao_dien/core/text/search_normalizer.dart';
import 'package:giao_dien/core/text/catalog_search_index.dart';

void main(List<String> args) {
  final words = [for (var i = 0; i < 10; i++) ...catalogWords];
  const samples = [
    'ban tinh',
    'pencil',
    'do dung hoc tap',
    'fruit',
    'school',
    'clock',
    'animal',
    'bút',
    'chair',
    'not-present',
  ];
  final queries = [for (var i = 0; i < 10; i++) ...samples];
  // Warm the VM before reporting a timed workload.
  for (var i = 0; i < 3; i++) {
    for (final word in catalogWords) {
      normalizeSearchText(
        '${word.english} ${word.vietnamese} ${word.id} ${word.topic}',
      );
    }
  }
  final stopwatch = Stopwatch()..start();
  final indexed = args.contains('--indexed');
  final index = indexed ? CatalogSearchIndex(words) : null;
  final indexBuildUs = stopwatch.elapsedMicroseconds;
  var matches = 0;
  for (final input in queries) {
    if (index != null) {
      matches += index.search(input).length;
      continue;
    }
    final query = normalizeSearchText(input);
    for (final word in words) {
      final haystack = normalizeSearchText(
        '${word.english} ${word.vietnamese} ${word.id} ${word.topic}',
      );
      if (haystack.contains(query)) matches++;
    }
  }
  stopwatch.stop();
  final result = {
    'entries': words.length,
    'queries': queries.length,
    'matches': matches,
    'elapsed_us': stopwatch.elapsedMicroseconds,
    'mode': indexed
        ? 'indexed search including index creation'
        : 'normalization on every search',
    if (indexed) 'index_build_us': indexBuildUs,
  };
  final output =
      args.where((arg) => !arg.startsWith('--')).firstOrNull ??
      'build/qa-performance/${indexed ? 'indexed' : 'normalized'}-search.json';
  File(output).parent.createSync(recursive: true);
  File(
    output,
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(result));
  stdout.writeln(jsonEncode(result));
}
