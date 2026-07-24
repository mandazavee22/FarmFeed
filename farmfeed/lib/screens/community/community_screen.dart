import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme.dart';
import '../../core/api_client.dart';
import '../../main.dart';
import 'chat_screen.dart';
import 'new_topic_sheet.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: FarmColors.offWhite,
        body: Column(
          children: [
            // Styled Tab Bar Container (sits under common header)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: const BoxDecoration(
                gradient: FarmColors.primaryGradient,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: FarmColors.accentLime,
                indicatorWeight: 4,
                indicatorSize: TabBarIndicatorSize.label,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                labelStyle: FarmTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700),
                unselectedLabelStyle: FarmTextStyles.bodySmall,
                tabs: const [
                  Tab(child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [Icon(Icons.public, size: 18), SizedBox(width: 8), Text('Forum')],
                  )),
                  Tab(child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [Icon(Icons.inbox_outlined, size: 18), SizedBox(width: 8), Text('Inbox')],
                  )),
                ],
              ),
            ),
            
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  _ForumTab(),
                  _InboxTab(),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: AnimatedBuilder(
          animation: _tabController,
          builder: (context, _) {
            if (_tabController.index == 0) {
              return FloatingActionButton.extended(
                heroTag: 'community_forum_fab',
                backgroundColor: FarmColors.primaryGreen,
                icon: const Icon(Icons.add, color: Colors.white),
                label: Text('New Topic',
                    style: FarmTextStyles.bodySmall.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const NewTopicSheet(),
                ).then((_) => setState(() {})),
              );
            }
            return FloatingActionButton.extended(
              heroTag: 'community_inbox_fab',
              backgroundColor: FarmColors.primaryGreen,
              icon: const Icon(Icons.person_search, color: Colors.white),
              label: Text('Find User',
                  style: FarmTextStyles.bodySmall.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
              onPressed: () => _showFindUserSheet(context),
            );
          },
        ),
      ),
    );
  }

  void _showFindUserSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _FindUserSheet(),
    );
  }
}

// ── Forum Tab ─────────────────────────────────────────────────────────────────

class _ForumTab extends StatefulWidget {
  const _ForumTab();

  @override
  State<_ForumTab> createState() => _ForumTabState();
}

class _ForumTabState extends State<_ForumTab>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _topics = [];
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final resp = await ApiClient.instance.getForumTopics();
      if (resp['success'] == true && mounted) {
        setState(() {
          _topics = List<Map<String, dynamic>>.from(resp['data']['topics']);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: FarmColors.primaryGreen));
    }
    if (_topics.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.forum_outlined, size: 64, color: FarmColors.textSecondary.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text('No topics yet. Start the conversation!',
                style: FarmTextStyles.bodyMedium.copyWith(color: FarmColors.textSecondary)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: FarmColors.primaryGreen,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _topics.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final t = _topics[i];
          return _TopicCard(topic: t, onRefresh: _load)
              .animate()
              .fadeIn(delay: Duration(milliseconds: 50 * i))
              .slideY(begin: 0.08);
        },
      ),
    );
  }
}

class _TopicCard extends StatefulWidget {
  final Map<String, dynamic> topic;
  final VoidCallback onRefresh;
  const _TopicCard({required this.topic, required this.onRefresh});

  @override
  State<_TopicCard> createState() => _TopicCardState();
}

class _TopicCardState extends State<_TopicCard> {
  bool _expanded = false;
  List<Map<String, dynamic>> _posts = [];
  bool _loadingPosts = false;
  final _replyCtrl = TextEditingController();

  Color _categoryColor(String? cat) {
    switch (cat) {
      case 'Tips': return FarmColors.accentLime;
      case 'Deals': return const Color(0xFFF59E0B);
      case 'Alerts': return Colors.redAccent;
      default: return FarmColors.primaryGreen;
    }
  }

  Future<void> _loadPosts() async {
    setState(() => _loadingPosts = true);
    try {
      final resp = await ApiClient.instance.getForumTopic(widget.topic['id'] as int);
      if (resp['success'] == true && mounted) {
        setState(() {
          _posts = List<Map<String, dynamic>>.from(resp['data']['topic']['posts'] ?? []);
          _loadingPosts = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingPosts = false);
    }
  }

  Future<void> _sendReply() async {
    final text = _replyCtrl.text.trim();
    if (text.isEmpty) return;
    try {
      await ApiClient.instance.replyToTopic(widget.topic['id'] as int, text);
      _replyCtrl.clear();
      await _loadPosts();
      widget.onRefresh();
    } catch (_) {}
  }

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.topic;
    final cat = t['category'] as String? ?? 'General';
    final catColor = _categoryColor(cat);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FarmColors.borderLight),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              setState(() => _expanded = !_expanded);
              if (_expanded && _posts.isEmpty) _loadPosts();
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: catColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(cat,
                            style: FarmTextStyles.bodySmall.copyWith(
                                color: catColor, fontWeight: FontWeight.w700, fontSize: 10)),
                      ),
                      const Spacer(),
                      Text('${t['reply_count'] ?? 0} replies',
                          style: FarmTextStyles.bodySmall.copyWith(
                              color: FarmColors.textSecondary, fontSize: 11)),
                      const SizedBox(width: 6),
                      Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                          color: FarmColors.textSecondary, size: 18),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(t['title'] ?? '',
                      style: FarmTextStyles.titleMedium.copyWith(color: FarmColors.darkGreen)),
                  const SizedBox(height: 4),
                  Text(t['content'] ?? '',
                      style: FarmTextStyles.bodySmall.copyWith(color: FarmColors.textSecondary),
                      maxLines: _expanded ? null : 2,
                      overflow: _expanded ? null : TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.person_outline, size: 13, color: FarmColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(t['author_name'] ?? '',
                          style: FarmTextStyles.bodySmall.copyWith(
                              fontSize: 11, color: FarmColors.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            if (_loadingPosts)
              const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(color: FarmColors.primaryGreen),
              )
            else ...[
              ..._posts.map((p) => _PostTile(post: p)),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _replyCtrl,
                        decoration: InputDecoration(
                          hintText: 'Write a reply...',
                          hintStyle: FarmTextStyles.bodySmall.copyWith(color: FarmColors.textSecondary),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: FarmColors.borderLight),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: FarmColors.borderLight),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: FarmColors.primaryGreen),
                          ),
                          filled: true,
                          fillColor: FarmColors.offWhite,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _sendReply,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: FarmColors.cardGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _PostTile extends StatelessWidget {
  final Map<String, dynamic> post;
  const _PostTile({required this.post});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: FarmColors.mintFaint,
            child: Text(
              (post['author_name'] as String? ?? 'U').substring(0, 1).toUpperCase(),
              style: FarmTextStyles.bodySmall.copyWith(
                  color: FarmColors.primaryGreen, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: FarmColors.offWhite,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(post['author_name'] ?? '',
                      style: FarmTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.w700, color: FarmColors.darkGreen, fontSize: 11)),
                  const SizedBox(height: 3),
                  Text(post['content'] ?? '',
                      style: FarmTextStyles.bodySmall.copyWith(color: FarmColors.textSecondary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Inbox Tab ─────────────────────────────────────────────────────────────────

class _InboxTab extends StatefulWidget {
  const _InboxTab();

  @override
  State<_InboxTab> createState() => _InboxTabState();
}

class _InboxTabState extends State<_InboxTab>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _threads = [];
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final resp = await ApiClient.instance.getInbox();
      if (resp['success'] == true && mounted) {
        setState(() {
          _threads = List<Map<String, dynamic>>.from(resp['data']['threads']);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: FarmColors.primaryGreen));
    }
    if (_threads.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: FarmColors.textSecondary.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text('No messages yet.',
                style: FarmTextStyles.bodyMedium.copyWith(color: FarmColors.textSecondary)),
            const SizedBox(height: 8),
            Text('Tap "Find User" to start a private conversation.',
                style: FarmTextStyles.bodySmall.copyWith(color: FarmColors.textSecondary),
                textAlign: TextAlign.center),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: FarmColors.primaryGreen,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _threads.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final t = _threads[i];
          final unread = !(t['is_read'] as bool? ?? true);
          return GestureDetector(
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(
                    builder: (_) => ChatScreen(
                        partnerId: t['partner_id'] as int,
                        partnerName: t['partner_name'] as String)))
                .then((_) => _load()),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: unread ? FarmColors.primaryGreen.withOpacity(0.3) : FarmColors.borderLight),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: FarmColors.mintFaint,
                    child: Text(
                      (t['partner_name'] as String? ?? 'U').substring(0, 1).toUpperCase(),
                      style: FarmTextStyles.titleMedium.copyWith(color: FarmColors.primaryGreen),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(t['partner_name'] ?? '',
                                style: FarmTextStyles.bodyMedium.copyWith(
                                    fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                                    color: FarmColors.darkGreen)),
                            if (unread) ...[
                              const SizedBox(width: 6),
                              Container(
                                width: 8, height: 8,
                                decoration: const BoxDecoration(
                                    color: FarmColors.primaryGreen, shape: BoxShape.circle),
                              ),
                            ]
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(t['last_message'] ?? '',
                            style: FarmTextStyles.bodySmall.copyWith(
                                color: FarmColors.textSecondary,
                                fontWeight: unread ? FontWeight.w600 : FontWeight.normal),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: FarmColors.textSecondary, size: 20),
                ],
              ),
            ).animate().fadeIn(delay: Duration(milliseconds: 50 * i)).slideX(begin: 0.05),
          );
        },
      ),
    );
  }
}

// ── Find User Sheet ───────────────────────────────────────────────────────────

class _FindUserSheet extends StatefulWidget {
  const _FindUserSheet();

  @override
  State<_FindUserSheet> createState() => _FindUserSheetState();
}

class _FindUserSheetState extends State<_FindUserSheet> {
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(() {
      final q = _searchCtrl.text.toLowerCase();
      setState(() {
        _filtered = _users.where((u) => (u['name'] as String).toLowerCase().contains(q)).toList();
      });
    });
  }

  Future<void> _load() async {
    try {
      final resp = await ApiClient.instance.getCommunityUsers();
      if (resp['success'] == true && mounted) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(resp['data']['users']);
          _filtered = _users;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(
              color: FarmColors.borderLight, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text('Find Someone to Message',
                style: FarmTextStyles.titleMedium.copyWith(color: FarmColors.darkGreen)),
            const SizedBox(height: 14),
            TextFormField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by name...',
                prefixIcon: const Icon(Icons.search, color: FarmColors.textSecondary),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: FarmColors.offWhite,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: FarmColors.primaryGreen))
                  : ListView.separated(
                      controller: ctrl,
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final u = _filtered[i];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: FarmColors.mintFaint,
                            child: Text(
                              (u['name'] as String).substring(0, 1).toUpperCase(),
                              style: FarmTextStyles.bodyMedium.copyWith(color: FarmColors.primaryGreen),
                            ),
                          ),
                          title: Text(u['name'] ?? '', style: FarmTextStyles.bodyMedium),
                          subtitle: Text(u['role'] == 'farmer' ? 'Farmer' : 'Supplier',
                              style: FarmTextStyles.bodySmall.copyWith(color: FarmColors.primaryGreen)),
                          trailing: const Icon(Icons.message_outlined, color: FarmColors.primaryGreen),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                    partnerId: u['id'] as int,
                                    partnerName: u['name'] as String)));
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
