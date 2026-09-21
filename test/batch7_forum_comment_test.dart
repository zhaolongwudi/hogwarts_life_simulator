/// Batch 7 · Issue #11：论坛评论只 +1 数字无文本 → 写真实评论实体。
///
/// 覆盖：
///  - ForumComment 数据完整性：toJson/fromJson 往返一致；
///  - ForumPost.commentList 持久化：toJson/fromJson 往返一致 + 旧档缺省回退空列表；
///  - addForumPostComment：文本落成实体、计数同步、空文本被拒、非法 id 静默；
///  - 存档兼容：旧档（无 comment_list 字段）读档后 commentList 为空、comments 计数保留。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hogwarts_life_simulator/models/player.dart';
import 'package:hogwarts_life_simulator/providers/game_provider.dart';
import 'helpers/test_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ForumComment 数据完整性', () {
    test('toJson/fromJson 往返一致', () {
      final c = ForumComment(
        id: 'fc_1',
        author: '哈利',
        content: '说得好！',
        timeLabel: '1991年9月3日 傍晚',
      );
      final json = c.toJson();
      expect(json['id'], 'fc_1');
      expect(json['author'], '哈利');
      expect(json['content'], '说得好！');
      expect(json['time_label'], '1991年9月3日 傍晚');

      final c2 = ForumComment.fromJson(json);
      expect(c2.id, 'fc_1');
      expect(c2.author, '哈利');
      expect(c2.content, '说得好！');
      expect(c2.timeLabel, '1991年9月3日 傍晚');
    });

    test('缺字段时回退到默认值', () {
      final c = ForumComment.fromJson(const {});
      expect(c.id, '');
      expect(c.author, '匿名巫师');
      expect(c.content, '');
      expect(c.timeLabel, '');
    });
  });

  group('ForumPost.commentList 持久化', () {
    test('toJson/fromJson 往返一致', () {
      final post = ForumPost(
        id: 'fp_1',
        category: '校园八卦',
        content: '今天发生了一件事',
        author: '哈利',
        timeLabel: '1991年9月3日 傍晚',
        commentList: [
          ForumComment(
            id: 'fc_1',
            author: '罗恩',
            content: '真的吗？',
            timeLabel: '1991年9月3日 傍晚',
          ),
          ForumComment(
            id: 'fc_2',
            author: '赫敏',
            content: '我也看到了',
            timeLabel: '1991年9月4日 早晨',
          ),
        ],
      );
      final json = post.toJson();
      final commentListJson = json['comment_list'] as List<dynamic>;
      expect(commentListJson.length, 2);

      final post2 = ForumPost.fromJson(json);
      expect(post2.commentList.length, 2);
      expect(post2.commentList[0].author, '罗恩');
      expect(post2.commentList[0].content, '真的吗？');
      expect(post2.commentList[1].author, '赫敏');
      expect(post2.commentList[1].content, '我也看到了');
    });

    test('旧档缺 comment_list 字段时回退到空列表', () {
      final json = <String, dynamic>{
        'id': 'fp_old',
        'category': '校园八卦',
        'content': '旧帖',
        'author': '匿名巫师',
        'time_label': '1991年9月1日',
        'likes': 3,
        'comments': 5, // 旧档可能已有计数
        'liked': false,
      };
      final post = ForumPost.fromJson(json);
      expect(post.commentList, isEmpty);
      expect(post.comments, 5); // 旧计数保留
    });

    test('comment_list 为 null 时回退到空列表', () {
      final json = <String, dynamic>{
        'id': 'fp_null',
        'category': '校园八卦',
        'content': '测试',
        'author': '匿名巫师',
        'time_label': '',
        'comment_list': null,
      };
      final post = ForumPost.fromJson(json);
      expect(post.commentList, isEmpty);
    });
  });

  group('addForumPostComment 行为', () {
    test('文本落成实体 + 计数同步', () async {
      final gp = await makeGame(offlineQuickMode: true);
      final p = gp.player!;
      final postId = gp.addForumPost(
        category: '校园八卦',
        content: '测试帖',
      )!;
      expect(postId, isNotEmpty);

      gp.addForumPostComment(postId, text: '第一条回复');
      gp.addForumPostComment(postId, text: '第二条回复');

      final post = p.forumPosts.firstWhere((e) => e.id == postId);
      expect(post.commentList.length, 2);
      expect(post.comments, 2);
      expect(post.commentList[0].content, '第一条回复');
      expect(post.commentList[1].content, '第二条回复');
      expect(post.commentList[0].author, p.name);
    });

    test('空文本被拒（不增加实体也不增加计数）', () async {
      final gp = await makeGame(offlineQuickMode: true);
      final postId = gp.addForumPost(
        category: '校园八卦',
        content: '测试帖',
      )!;

      gp.addForumPostComment(postId, text: '   ');
      gp.addForumPostComment(postId, text: '');

      final post = gp.player!.forumPosts.firstWhere((e) => e.id == postId);
      expect(post.commentList, isEmpty);
      expect(post.comments, 0);
    });

    test('非法 id 静默返回（不抛异常）', () async {
      final gp = await makeGame(offlineQuickMode: true);
      // 不应抛异常
      gp.addForumPostComment('nonexistent_id', text: '测试');
    });

    test('文本被 trim 后存储', () async {
      final gp = await makeGame(offlineQuickMode: true);
      final postId = gp.addForumPost(
        category: '校园八卦',
        content: '测试帖',
      )!;

      gp.addForumPostComment(postId, text: '  带空格的回复  ');

      final post = gp.player!.forumPosts.firstWhere((e) => e.id == postId);
      expect(post.commentList[0].content, '带空格的回复');
    });
  });

  group('存档兼容', () {
    test('旧档（无 comment_list）读档后 commentList 为空、comments 计数保留', () {
      // 模拟旧档：只有 comments 计数，没有 comment_list
      final oldJson = <String, dynamic>{
        'id': 'fp_legacy',
        'category': '校园八卦',
        'content': '旧帖内容',
        'author': '旧玩家',
        'time_label': '1991年9月1日',
        'likes': 2,
        'comments': 7,
        'liked': true,
      };
      final post = ForumPost.fromJson(oldJson);
      expect(post.commentList, isEmpty);
      expect(post.comments, 7);
      expect(post.liked, isTrue);
    });
  });
}