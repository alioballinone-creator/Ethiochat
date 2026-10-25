import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class EthioCacheManager {
  static const key = 'ethiochatCacheKey';
  static CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 200,
      repo: JsonCacheInfoRepository(databaseName: key),
      fileService: HttpFileService(),
    ),
  );
}
