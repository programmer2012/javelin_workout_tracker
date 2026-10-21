import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// An image chosen by the user, with the content type Storage needs.
class PickedImage {
  final Uint8List bytes;
  final String contentType;

  const PickedImage({required this.bytes, required this.contentType});
}

/// Returns the picked image, or `null` if the user cancelled.
Future<PickedImage?> pickImage(ImageSource source) async {
  final picker = ImagePicker();
  final file = await picker.pickImage(source: source);
  if (file == null) return null;

  final bytes = await file.readAsBytes();
  return PickedImage(
    bytes: bytes,
    // The picker does not report a mime type on every platform, so fall back
    // to the file header. An upload with no content type lands in Storage as
    // application/octet-stream, which the storage rules reject and which
    // makes the file download instead of rendering.
    contentType: file.mimeType ?? sniffImageType(bytes),
  );
}

/// Identifies an image from its magic bytes.
///
/// Falls back to JPEG: the source is an image picker, so an unrecognised
/// header is far more likely to be a format not listed here than something
/// that is not an image at all.
String sniffImageType(Uint8List bytes) {
  bool startsWith(List<int> magic, {int offset = 0}) {
    if (bytes.length < offset + magic.length) return false;
    for (var i = 0; i < magic.length; i++) {
      if (bytes[offset + i] != magic[i]) return false;
    }
    return true;
  }

  if (startsWith([0xFF, 0xD8, 0xFF])) return 'image/jpeg';
  if (startsWith([0x89, 0x50, 0x4E, 0x47])) return 'image/png';
  if (startsWith([0x47, 0x49, 0x46])) return 'image/gif';
  if (startsWith([0x42, 0x4D])) return 'image/bmp';

  // RIFF....WEBP
  if (startsWith([0x52, 0x49, 0x46, 0x46]) &&
      startsWith([0x57, 0x45, 0x42, 0x50], offset: 8)) {
    return 'image/webp';
  }

  // ....ftyp — the container iPhone photos arrive in.
  if (startsWith([0x66, 0x74, 0x79, 0x70], offset: 4)) return 'image/heic';

  return 'image/jpeg';
}
