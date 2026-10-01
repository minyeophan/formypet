import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/my_community_activity.dart';
import 'package:frontend/models/post.dart';
import 'package:frontend/screens/my/my_comment_activity_row.dart';

void main() {
  for (final width in [320.0, 390.0]) {
    testWidgets(
      'long comment card at $width opens comment from both comment and title',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var commentOpens = 0;
        final title = List.filled(12, '긴 게시글 제목').join(' ');
        final comment = List.filled(15, '내가 작성한 긴 댓글').join(' ');
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(20),
                child: MyCommentActivityRow(
                  activity: MyCommunityActivity(
                    post: Post(
                      id: '1',
                      userId: '2',
                      authorNickname: '집사',
                      title: title,
                      content: '원문 본문은 카드에 표시하지 않음',
                      category: 'FREE',
                      likesCount: 1,
                      liked: false,
                      commentsCount: 2,
                      imageUrls: const [],
                      createdAt: '2026-09-01',
                    ),
                    activityAt: '2026-09-02',
                    commentId: '3',
                    commentContent: comment,
                  ),
                  onOpenComment: () => commentOpens++,
                ),
              ),
            ),
          ),
        );
        expect(tester.widget<Text>(find.text(title)).maxLines, 1);
        expect(tester.widget<Text>(find.text(comment)).maxLines, 2);
        expect(find.text('원문 본문은 카드에 표시하지 않음'), findsNothing);
        await tester.tap(find.text(title));
        expect(commentOpens, 1);
        await tester.tap(find.text(comment));
        expect(commentOpens, 2);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
