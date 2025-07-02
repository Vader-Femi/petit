import 'package:share_handler/share_handler.dart';

class SharedMediaDetails {
  final SharedMediaType type;
  final List<SharedAttachment>? sharedAttachment;

  SharedMediaDetails({
    required this.type,
    required this.sharedAttachment,
  });
}

enum SharedMediaType {
  image,
  video
}
