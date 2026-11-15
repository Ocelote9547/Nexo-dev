import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Tamaño máximo permitido para una fotografía (5 MB).
const int maxPhotoSizeBytes = 5 * 1024 * 1024;

/// Manages private media files (photos, thumbnails, temp files).
class MediaService {
  final Directory? baseDirectory;
  MediaService({this.baseDirectory});

  Future<Directory> get _base async {
    if (baseDirectory != null) {
      final media = Directory(p.join(baseDirectory!.path, 'media'));
      if (!await media.exists()) await media.create(recursive: true);
      return media;
    }
    final dir = await getApplicationDocumentsDirectory();
    final media = Directory(p.join(dir.path, 'media'));
    if (!await media.exists()) await media.create(recursive: true);
    return media;
  }

  Future<Directory> contactDir(String contactId) async {
    if (contactId.isEmpty ||
        contactId.contains('..') ||
        contactId.contains('/') ||
        contactId.contains('\\')) {
      throw ArgumentError('Identificador de contacto no válido');
    }
    final base = await _base;
    final d = Directory(p.join(base.path, 'contacts', contactId));
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  Future<String> saveBytes(String contactId, String filename, List<int> bytes) async {
    // Validar tamaño máximo de la fotografía
    if (bytes.length > maxPhotoSizeBytes) {
      throw ArgumentError(
        'Fotografía demasiado grande: $bytes.length bytes (máximo $maxPhotoSizeBytes bytes)',
      );
    }
    // Validar que sea una imagen válida si es una foto
    if (filename.toLowerCase().endsWith('.jpg') ||
        filename.toLowerCase().endsWith('.jpeg') ||
        filename.toLowerCase().endsWith('.png')) {
      try {
        final decoded = img.decodeImage(Uint8List.fromList(bytes));
        if (decoded == null) {
          throw ArgumentError('Datos de imagen inválidos o no reconocidos');
        }
      } catch (e) {
        if (e is ArgumentError) rethrow;
        throw ArgumentError('Datos de imagen inválidos: $e');
      }
    }
    final dir = await contactDir(contactId);
    final file = File(p.join(dir.path, filename));
    await file.writeAsBytes(bytes, flush: true);
    return p.relative(file.path, from: (await _base).path);
  }

  Future<File?> resolve(String relativePath) async {
    if (relativePath.contains('..') || p.isAbsolute(relativePath)) {
      throw ArgumentError('Ruta no permitida');
    }
    final base = await _base;
    final normalized = p.normalize(relativePath);
    final fullPath = p.join(base.path, normalized);
    if (!p.isWithin(base.path, fullPath)) {
      throw ArgumentError('Ruta fuera del directorio privado');
    }
    final file = File(fullPath);
    if (await file.exists()) return file;
    return null;
  }

  Future<void> deleteContactFiles(String contactId) async {
    if (contactId.isEmpty ||
        contactId.contains('..') ||
        contactId.contains('/') ||
        contactId.contains('\\')) {
      throw ArgumentError('Identificador de contacto no válido');
    }
    final base = await _base;
    final d = Directory(p.join(base.path, 'contacts', contactId));
    if (await d.exists()) await d.delete(recursive: true);
  }

  String sha256Of(List<int> bytes) => sha256.convert(bytes).toString();

  Future<String> savePhoto(String contactId, List<int> bytes) async {
    final rel = await saveBytes(contactId, 'photo.jpg', bytes);
    try {
      final decoded = img.decodeImage(Uint8List.fromList(bytes));
      if (decoded != null) {
        final thumb = img.copyResize(decoded, width: 256);
        final thumbBytes = img.encodeJpg(thumb, quality: 85);
        await saveBytes(contactId, 'thumb.jpg', List<int>.from(thumbBytes));
      }
    } catch (_) {}
    return rel;
  }

  Future<File?> thumbnailFile(String contactId) async {
    return resolve('contacts/$contactId/thumb.jpg');
  }

  Future<void> replacePhoto(String contactId, List<int> bytes) async {
    await deleteContactFiles(contactId);
    await savePhoto(contactId, bytes);
  }

  Future<Directory> tempDir() async {
    final base = await _base;
    final d = Directory(p.join(base.path, 'temp'));
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }
}
