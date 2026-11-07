import 'package:flutter_test/flutter_test.dart';
import 'package:ethio_chat/features/feed/presentation/post_upload_utils.dart';

void main() {
  test('object path format is <uid>/<uuid>.jpg', () {
    const uid = 'user-123';
    const uuid = '11111111-2222-3333-4444-555555555555';
    expect(PostUploadSpec.objectPath(uid, uuid),
        'user-123/11111111-2222-3333-4444-555555555555.jpg');
  });

  test('newObjectPath produces valid path for uid', () {
    const uid = 'abc';
    final path = PostUploadSpec.newObjectPath(uid);
    expect(PostUploadSpec.isValidObjectPath(uid, path), isTrue);
    expect(path.endsWith('.jpg'), isTrue);
    expect(path.startsWith('abc/'), isTrue);
  });

  test('rollback plan reports work when post or uploads exist', () {
    expect(const PostRollbackPlan().hasWork, isFalse);
    expect(const PostRollbackPlan(postId: 'p1').hasWork, isTrue);
    expect(const PostRollbackPlan(uploadedPaths: ['a/b.jpg']).hasWork, isTrue);
  });
}
