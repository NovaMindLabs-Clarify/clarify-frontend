import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/localization.dart';
import '../core/theme/design_tokens.dart';
import 'clarify_toast.dart';

/// Личные сообщения — список диалогов + чат (SOCIAL_PLAN.md §2.3/4.3). Реалтайм
/// через тот же принцип, что уже работает для задач (TaskService.initRealtime) —
/// подписка на изменения таблицы `messages`.
class ConversationsListScreen extends StatefulWidget {
  final String currentLang;
  final double scale;
  final Widget Function({required Widget child, EdgeInsetsGeometry? margin, EdgeInsetsGeometry? padding, Color? customColor}) buildGlassContainer;
  final String? initialPartnerId;
  final String? initialPartnerName;

  const ConversationsListScreen({
    super.key,
    required this.currentLang,
    this.scale = 1.0,
    required this.buildGlassContainer,
    this.initialPartnerId,
    this.initialPartnerName,
  });

  @override
  State<ConversationsListScreen> createState() => _ConversationsListScreenState();
}

class _ConversationsListScreenState extends State<ConversationsListScreen> {
  List<Map<String, dynamic>>? _conversations;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _load();
    _channel = Supabase.instance.client.channel('messages_changes')
      ..onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'messages', callback: (_) => _load())
      ..subscribe();

    if (widget.initialPartnerId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openConversation(widget.initialPartnerId!, widget.initialPartnerName ?? ''));
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await Supabase.instance.client.rpc('list_conversations');
      if (mounted) setState(() => _conversations = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      if (mounted) setState(() => _conversations = []);
    }
  }

  void _openConversation(String partnerId, String partnerName) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ConversationScreen(currentLang: widget.currentLang, partnerId: partnerId, partnerName: partnerName),
    )).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    if (_conversations == null) return const Center(child: CircularProgressIndicator());
    if (_conversations!.isEmpty) {
      return Center(child: Text('Пока нет сообщений'.tr(widget.currentLang), style: TextStyle(color: t.text3, fontSize: 15)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _conversations!.length,
      itemBuilder: (context, index) {
        final c = _conversations![index];
        final unread = (c['unread_count'] as num?)?.toInt() ?? 0;
        final name = (c['full_name'] as String?)?.trim();
        final displayName = (name == null || name.isEmpty) ? 'Без имени'.tr(widget.currentLang) : name;

        return widget.buildGlassContainer(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            onTap: () => _openConversation(c['partner_id'] as String, displayName),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: CircleAvatar(
              radius: 20,
              backgroundColor: t.accentSoft,
              backgroundImage: c['avatar_url'] != null ? NetworkImage(c['avatar_url'] as String) : null,
              child: c['avatar_url'] == null ? Text(displayName[0].toUpperCase(), style: TextStyle(color: t.accent, fontWeight: FontWeight.bold)) : null,
            ),
            title: Text(displayName, style: TextStyle(color: t.text, fontWeight: FontWeight.w600)),
            subtitle: c['last_message'] != null
                ? Text(c['last_message'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.text3))
                : null,
            trailing: unread > 0
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: t.accent, borderRadius: BorderRadius.circular(ClarifyRadius.pill)),
                    child: Text('$unread', style: TextStyle(color: t.onAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                  )
                : null,
          ),
        );
      },
    );
  }
}

class ConversationScreen extends StatefulWidget {
  final String currentLang;
  final String partnerId;
  final String partnerName;

  const ConversationScreen({super.key, required this.currentLang, required this.partnerId, required this.partnerName});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>>? _messages;
  RealtimeChannel? _channel;
  bool _isSending = false;

  String get _myId => Supabase.instance.client.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _load();
    Supabase.instance.client.rpc('mark_conversation_read', params: {'partner_id': widget.partnerId}).catchError((_) => null);
    _channel = Supabase.instance.client.channel('conversation_${widget.partnerId}')
      ..onPostgresChanges(event: PostgresChangeEvent.insert, schema: 'public', table: 'messages', callback: (_) => _load())
      ..subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await Supabase.instance.client
          .from('messages')
          .select()
          .or('and(from_id.eq.$_myId,to_id.eq.${widget.partnerId}),and(from_id.eq.${widget.partnerId},to_id.eq.$_myId)')
          .order('created_at');
      if (mounted) {
        setState(() => _messages = List<Map<String, dynamic>>.from(data));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        });
      }
    } catch (e) {
      if (mounted) setState(() => _messages = []);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;
    setState(() => _isSending = true);
    _controller.clear();
    try {
      await Supabase.instance.client.from('messages').insert({'from_id': _myId, 'to_id': widget.partnerId, 'text': text});
      await _load();
    } catch (e) {
      if (mounted) ClarifyToast.show(context, 'Ошибка отправки: $e', variant: ClarifyToastVariant.danger);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        elevation: 0,
        foregroundColor: t.text,
        title: Text(widget.partnerName, style: TextStyle(fontFamily: 'Golos Text', fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages == null
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages!.length,
                    itemBuilder: (context, index) {
                      final m = _messages![index];
                      final isMine = m['from_id'] == _myId;
                      return Align(
                        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          constraints: const BoxConstraints(maxWidth: 320),
                          decoration: BoxDecoration(
                            color: isMine ? t.accent : t.surface2,
                            borderRadius: BorderRadius.circular(ClarifyRadius.lg),
                          ),
                          child: Text(m['text'] as String, style: TextStyle(color: isMine ? t.onAccent : t.text)),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: TextStyle(color: t.text),
                      decoration: InputDecoration(
                        hintText: 'Сообщение...'.tr(widget.currentLang),
                        hintStyle: TextStyle(color: t.text3),
                        filled: true,
                        fillColor: t.surface2,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(ClarifyRadius.pill), borderSide: BorderSide.none),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(LucideIcons.send, color: t.accent),
                    onPressed: _isSending ? null : _send,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
