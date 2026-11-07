import 'package:uuid/uuid.dart';

class PostUploadSpec {
  static String objectPath(String userId, String uuid) => '$userId/$uuid.jpg';
  static String newObjectPath(String userId, {Uuid? uuidGen}) =>
      objectPath(userId, (uuidGen ?? const Uuid()).v4());
  static bool isValidObjectPath(String userId, String path) {
    final re = RegExp(
        '^${RegExp.escape(userId)}/[0-9a-fA-F-]{36}\\.jpg\$');
    return re.hasMatch(path);
  }
}

class PostRollbackPlan {
  final String? postId;
  final List<String> uploadedPaths;
  const PostRollbackPlan({this.postId, this.uploadedPaths = const []});
  bool get hasWork => postId != null || uploadedPaths.isNotEmpty;
}
