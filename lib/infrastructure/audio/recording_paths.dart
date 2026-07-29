import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Where a Record-mode take gets written (design doc §9). One flat folder
/// under app documents; filenames carry the skill id and a timestamp so
/// takes never collide and stay identifiable without a database lookup.
Future<String> newRecordingFilePath({required String skillId}) async {
  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory(p.join(docs.path, 'recordings'));
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  return p.join(dir.path, '${skillId}_$timestamp.wav');
}
