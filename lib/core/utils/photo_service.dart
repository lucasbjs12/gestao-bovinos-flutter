import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class PhotoService {
  static final _picker = ImagePicker();

  static Future<File?> pickFromCamera() => _pick(ImageSource.camera);
  static Future<File?> pickFromGallery() => _pick(ImageSource.gallery);

  static Future<File?> _pick(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1080,
      maxHeight: 1080,
      imageQuality: 90,
    );
    return picked != null ? File(picked.path) : null;
  }

  /// Comprime [source] e salva em `<appDocs>/<uid>/photos/<timestamp>.jpg`.
  /// Retorna o caminho absoluto do arquivo salvo.
  static Future<String> saveCompressed(File source, String uid) async {
    final dir = await getApplicationDocumentsDirectory();
    final photosDir = Directory('${dir.path}/$uid/photos');
    if (!await photosDir.exists()) await photosDir.create(recursive: true);

    final dest = '${photosDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';

    final result = await FlutterImageCompress.compressAndGetFile(
      source.absolute.path,
      dest,
      quality: 75,
      minWidth: 800,
      minHeight: 800,
    );

    return result?.path ?? source.path;
  }

  /// Deleta o arquivo se for um path local (não URL).
  static void deleteIfLocal(String? path) {
    if (path == null || path.startsWith('http')) return;
    final file = File(path);
    if (file.existsSync()) file.deleteSync();
  }
}
