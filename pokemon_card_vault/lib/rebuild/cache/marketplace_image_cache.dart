import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../provider/image_cache_file_system.dart';
import '../provider/image_cache_repository.dart';

/// Una sola istanza per app. Scarica i file richiesti dai widget visibili.
abstract final class MarketplaceImageCache {
  static const key = 'rebuild-marketplace-images-v1';
  static const maxConcurrentDownloads = 2;
  static const maxBytes = 64 * 1000 * 1000;
  static const maxObjects = 240;
  static const maxAge = Duration(days: 30);
  static final instance = _create();

  static CacheManager _create() {
    final files = ImageCacheFileSystem();
    final repository = ImageCacheRepository(
        databaseName: key,
        fileSystem: files,
        maxBytes: maxBytes,
        maxObjects: maxObjects,
        maxAge: maxAge);
    final manager = CacheManager(Config(key,
        stalePeriod: maxAge,
        maxNrOfCacheObjects: maxObjects,
        repo: repository,
        fileService: HttpFileService()
          ..concurrentFetches = maxConcurrentDownloads,
        fileSystem: files));
    repository.onEvicted = manager.store.emptyMemoryCache;
    return manager;
  }
}
