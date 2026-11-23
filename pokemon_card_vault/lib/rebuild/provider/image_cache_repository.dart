import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'image_cache_file_system.dart';

/// Image index only. Never opens collection, cart, auth or scanner storage.
/// Uses the same filesystem for downloads, eviction and startup reconciliation.
class ImageCacheRepository extends CacheInfoRepository {
  ImageCacheRepository({
    required String databaseName,
    required this.fileSystem,
    required this.maxBytes,
    required this.maxObjects,
    required this.maxAge,
  }) : _index = Platform.isAndroid || Platform.isIOS || Platform.isMacOS
            ? CacheObjectProvider(databaseName: databaseName)
            : JsonCacheInfoRepository(databaseName: databaseName);

  final CacheInfoRepository _index;
  final ImageCacheFileSystem fileSystem;
  final int maxBytes;
  final int maxObjects;
  final Duration maxAge;
  VoidCallback? onEvicted;
  Future<bool>? _opening;
  Future<void>? _maintenance;
  Timer? _timer;
  bool _closed = false;

  @override
  Future<bool> open() => _opening ??= _openAndReconcile();

  Future<bool> _openAndReconcile() async {
    final opened = await _index.open();
    try {
      // CacheStore waits for open() before reading/writing its index. Do this
      // only at startup so an in-flight download is never mistaken for an orphan.
      final referenced = (await _index.getAllObjects())
          .map((object) => object.relativePath)
          .toSet();
      for (final file in await fileSystem.managedFiles()) {
        if (!referenced.contains(file.uri.pathSegments.last)) {
          await file.delete();
        }
      }
      await _trim();
    } on FileSystemException catch (error) {
      debugPrint(
          'Image cache reconciliation skipped: ${error.osError?.errorCode}');
    }
    return opened;
  }

  @override
  Future<dynamic> updateOrInsert(CacheObject cacheObject) async {
    final result = await _index.updateOrInsert(cacheObject);
    // Includes completed downloads and cache hits (LRU touches). Coalesce work;
    // temporary download files may exceed the budget until this pass completes.
    if (!_closed && _timer == null) {
      _timer = Timer(const Duration(seconds: 10), () {
        _timer = null;
        _maintenance ??= _runMaintenance();
      });
    }
    return result;
  }

  Future<void> _runMaintenance() async {
    try {
      await _trim();
    } catch (_) {
      // Optional image cache maintenance must not break loading a card.
      debugPrint('Image cache maintenance deferred.');
    } finally {
      _maintenance = null;
    }
  }

  Future<void> _trim() async {
    final toRemove = await getObjectsOverCapacity(maxObjects);
    await deleteAll(toRemove.map((object) => object.id!).toList());
  }

  @override
  Future<List<CacheObject>> getObjectsOverCapacity(int capacity) async {
    final objects = await _index.getAllObjects();
    objects.sort((a, b) => (a.touched ?? DateTime.fromMillisecondsSinceEpoch(0))
        .compareTo(b.touched ?? DateTime.fromMillisecondsSinceEpoch(0)));
    final sizes = <int, int>{};
    var bytes = 0;
    for (final object in objects) {
      if (!ImageCacheFileSystem.isManagedName(object.relativePath)) continue;
      final file = await fileSystem.createFile(object.relativePath);
      var length = object.length ?? 0;
      try {
        final type = await FileSystemEntity.type(file.path, followLinks: false);
        if (type == FileSystemEntityType.notFound) {
          length = 0;
        } else if (type == FileSystemEntityType.file) {
          length = await file.length();
        } else {
          continue;
        }
      } on FileSystemException {
        // A concurrent replacement/removal can race this scan. Retain the
        // recorded size; deletion rechecks the current file and retries safely.
      }
      sizes[object.id!] = length;
      bytes += length;
    }
    final expiredBefore = DateTime.now().subtract(maxAge);
    var count = objects.length;
    final remove = <CacheObject>[];
    for (final object in objects) {
      final length = sizes[object.id];
      if (length == null) continue;
      final expired = object.touched?.isBefore(expiredBefore) ?? true;
      if (length == 0 || expired || bytes > maxBytes || count > capacity) {
        remove.add(object);
        bytes -= length;
        count--;
      }
    }
    return remove;
  }

  @override
  Future<int> delete(int id) => deleteAll([id]);

  @override
  Future<int> deleteAll(Iterable<int> ids) async {
    final requested = ids.toSet();
    if (requested.isEmpty) return 0;
    final removable = <int>[];
    for (final object in await _index.getAllObjects()) {
      if (!requested.contains(object.id) ||
          !ImageCacheFileSystem.isManagedName(object.relativePath)) {
        continue;
      }
      try {
        final file = await fileSystem.createFile(object.relativePath);
        // Never follow or remove links, directories or arbitrary index paths.
        final type = await FileSystemEntity.type(file.path, followLinks: false);
        if (type == FileSystemEntityType.file) {
          await file.delete();
        } else if (type != FileSystemEntityType.notFound) {
          continue;
        }
        removable.add(object.id!);
      } on FileSystemException {
        // Keep the index entry on failure so the next pass can retry the file.
      }
    }
    if (removable.isEmpty) return 0;
    final deleted = await _index.deleteAll(removable);
    if (deleted > 0) onEvicted?.call();
    return deleted;
  }

  @override
  Future<bool> close() async {
    _closed = true;
    _timer?.cancel();
    await _maintenance;
    return _index.close();
  }

  @override
  Future<bool> exists() => _index.exists();

  @override
  Future<void> deleteDataFile() => _index.deleteDataFile();

  @override
  Future<CacheObject?> get(String key) => _index.get(key);

  @override
  Future<List<CacheObject>> getAllObjects() => _index.getAllObjects();

  @override
  Future<List<CacheObject>> getOldObjects(Duration maxAge) =>
      _index.getOldObjects(maxAge);

  @override
  Future<CacheObject> insert(CacheObject cacheObject,
          {bool setTouchedToNow = true}) =>
      _index.insert(cacheObject, setTouchedToNow: setTouchedToNow);

  @override
  Future<int> update(CacheObject cacheObject, {bool setTouchedToNow = true}) =>
      _index.update(cacheObject, setTouchedToNow: setTouchedToNow);
}
