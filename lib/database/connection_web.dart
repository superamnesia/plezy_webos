/// Web database connection implementation using Drift's WASM support.
library;

import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

QueryExecutor openDatabaseConnection() {
  return LazyDatabase(() async {
    final result = await WasmDatabase.open(
      databaseName: 'plezy_db',
      sqlite3Uri: Uri.parse('sqlite3.wasm'),
      driftWorkerUri: Uri.parse('drift_worker.dart.js'),
    );

    if (result.missingFeatures.isNotEmpty) {
      // Log missing features but continue - basic functionality still works
      // ignore: avoid_print
      print('Drift WASM missing features: ${result.missingFeatures}');
    }

    return result.resolvedExecutor;
  });
}
