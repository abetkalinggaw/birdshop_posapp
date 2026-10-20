import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

final productPhotoStoreProvider = Provider((ref) => ProductPhotoStore());

class ProductPhotoStore {
  final Future<Directory> Function() directory;
  ProductPhotoStore({Future<Directory> Function()? directory})
    : directory = directory ?? getApplicationSupportDirectory;

  Future<String> persist(String path) async {
    if (path.isEmpty || path.startsWith('http') || path.startsWith('assets/')) {
      return path;
    }
    final folder = Directory('${(await directory()).path}/product_photos');
    await folder.create(recursive: true);
    if (path.startsWith('${folder.path}/')) return path;
    // Keep saved photos: historical sale snapshots may still reference them.
    final target =
        '${folder.path}/${DateTime.now().microsecondsSinceEpoch}.jpg';
    return (await File(path).copy(target)).path;
  }
}
