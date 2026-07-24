import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme.dart';
import '../../core/api_client.dart';
import '../../main.dart';
import 'package:provider/provider.dart';

class ChatScreen extends StatefulWidget {
  final int partnerId;
  final String partnerName;
  const ChatScreen({super.key, required this.partnerId, required this.partnerName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final resp = await ApiClient.instance.getConversation(widget.partnerId);
      if (resp['success'] == true && mounted) {
        setState(() {
          _messages = List<Map<String, dynamic>>.from(resp['data']['messages']);
          _loading = false;
        });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _msgCtrl.clear();
    try {
      await ApiClient.instance.sendMessage(widget.partnerId, text);
      await _load();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final myId = context.read<AuthProvider>().user?.id;

    return Scaffold(
      backgroundColor: FarmColors.offWhite,
      appBar: AppBar(
        backgroundColor: FarmColors.darkGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        leading: const BackButton(color: Colors.white),
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white.withOpacity(0.2),
              radius: 18,
              child: Text(
                widget.partnerName.substring(0, 1).toUpperCase(),
                style: FarmTextStyles.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.partnerName,
                    style: FarmTextStyles.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
                Text('Private Message',
                    style: FarmTextStyles.bodySmall.copyWith(color: Colors.white60, fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: FarmColors.primaryGreen))
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline,
                                size: 64, color: FarmColors.textSecondary.withOpacity(0.3)),
                            const SizedBox(height: 12),
                            Text('No messages yet. Say hello!',
                                style: FarmTextStyles.bodyMedium.copyWith(color: FarmColors.textSecondary)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: _messages.length,
                        itemBuilder: (context, i) {
                          final m = _messages[i];
                          final isMe = (m['sender_id'] as int?) == myId;
                          return _Bubble(msg: m, isMe: isMe)
                              .animate()
                              .fadeIn(duration: 200.ms)
                              .slideY(begin: 0.05);
                        },
                      ),
          ),
          _InputBar(
            controller: _msgCtrl,
            sending: _sending,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final Map<String, dynamic> msg;
  final bool isMe;
  const _Bubble({required this.msg, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: FarmColors.mintFaint,
              child: Text(
                (msg['sender_name'] as String? ?? 'U').substring(0, 1).toUpperCase(),
                style: FarmTextStyles.bodySmall.copyWith(
                    color: FarmColors.primaryGreen, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: isMe ? FarmColors.cardGradient : null,
                color: isMe ? null : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                border: isMe ? null : Border.all(color: FarmColors.borderLight),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
                ],
              ),
              child: Text(
                msg['content'] ?? '',
                style: FarmTextStyles.bodySmall.copyWith(
                    color: isMe ? Colors.white : FarmColors.textPrimary),
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  const _InputBar({required this.controller, required this.sending, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
          left: 12, right: 12, top: 10, bottom: MediaQuery.of(context).padding.bottom + 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: FarmColors.borderLight)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: controller,
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: FarmTextStyles.bodySmall.copyWith(color: FarmColors.textSecondary),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: FarmColors.borderLight)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: FarmColors.borderLight)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: FarmColors.primaryGreen)),
                filled: true,
                fillColor: FarmColors.offWhite,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: sending ? null : onSend,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: FarmColors.cardGradient,
                borderRadius: BorderRadius.circular(22),
              ),
              child: sending
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
