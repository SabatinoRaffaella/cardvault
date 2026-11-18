import 'dart:io';
import 'cache_directory_provider.dart';

/// Lettura/scrittura del file JSON; le regole di scadenza restano nel cache layer.
class CacheFileProvider {
  CacheFileProvider(
      {CacheDirectoryProvider? directories,
      this.fileName = 'marketplace-home-v1.json'})
      : assert(!fileName.contains('/') && !fileName.contains('\\')),
        _directories = directories ?? CacheDirectoryProvider();
  final CacheDirectoryProvider _directories;
  final String fileName;

  Future<File> _file() async {
    final directory = await _directories.directory('metadata');
    if (!RegExp(r'^[a-z0-9-]+\.json$').hasMatch(fileName)) {
      throw ArgumentError.value(fileName);
    }
    return File('${directory.path}/$fileName');
  }

  Future<String?> read() async {
    final file = await _file();
    return await file.exists() ? file.readAsString() : null;
  }

  Future<void> write(String contents) async {
    final file = await _file();
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(contents, flush: true);
    await temporary.rename(file.path);
  }
}
