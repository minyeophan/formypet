import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_v2_tokens.dart';
import '../../services/community_service.dart';
import '../../widgets/app_header.dart';
import 'community_routes.dart';
import 'post_card.dart';

class CommunitySearchScreen extends StatefulWidget {
  const CommunitySearchScreen({super.key});

  @override
  State<CommunitySearchScreen> createState() => _CommunitySearchScreenState();
}

class _CommunitySearchScreenState extends State<CommunitySearchScreen> {
  final _controller = TextEditingController();
  final _service = CommunityService();
  List<dynamic> _posts = const [];
  bool _loading = false;
  String? _error;
  bool _searched = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final keyword = _controller.text.trim();
    if (keyword.length < 2 || keyword.length > 20) {
      setState(() => _error = '검색어는 2~20자로 입력해 주세요.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _searched = true;
    });
    try {
      final result = await _service.getFeed(keyword: keyword, limit: 50);
      if (mounted) setState(() => _posts = result.items);
    } catch (_) {
      if (mounted) setState(() => _error = '검색 결과를 불러오지 못했어요.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppV2Tokens.background,
      appBar: AppHeader(
        title: '커뮤니티 검색',
        showBackButton: true,
        centerTitle: true,
        onBack: () => context.pop(),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: TextField(
              key: const Key('community-search-field'),
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: '게시글을 검색해 보세요',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  tooltip: '검색어 지우기',
                  onPressed: _controller.clear,
                  icon: const Icon(Icons.close_rounded),
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Text(_error!));
    }
    if (_searched && _posts.isEmpty) {
      return const Center(child: Text('검색 결과가 없어요.'));
    }
    if (!_searched) {
      return const Center(child: Text('궁금한 내용을 검색해 보세요.'));
    }
    return ListView.builder(
      itemCount: _posts.length,
      itemBuilder: (context, index) {
        final post = _posts[index];
        return PostCard(
          post: post,
          onLike: () async {},
          onOpen: () => context.push(communityPostPath(post.id, 'search')),
        );
      },
    );
  }
}
