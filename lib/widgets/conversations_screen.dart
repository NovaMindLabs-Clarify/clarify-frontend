import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/localization.dart';
import '../core/theme/design_tokens.dart';
import 'chat_message_widgets.dart';
import 'clarify_bottom_sheet.dart';
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
  final _scrollController = ScrollController();
  List<Map<String, dynamic>>? _messages;
  RealtimeChannel? _channel;
  Map<String, dynamic>? _replyingTo;
  Map<String, dynamic>? _editingMessage;
  String? _partnerAvatarUrl;

  String get _myId => Supabase.instance.client.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _load();
    _loadPartnerAvatar();
    Supabase.instance.client.rpc('mark_conversation_read', params: {'partner_id': widget.partnerId}).catchError((_) => null);
    _channel = Supabase.instance.client.channel('conversation_${widget.partnerId}')
      ..onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'messages', callback: (_) => _load())
      ..subscribe();
  }

  Future<void> _loadPartnerAvatar() async {
    try {
      final data = await Supabase.instance.client.from('profiles').select('avatar_url').eq('user_id', widget.partnerId).maybeSingle();
      if (mounted && data != null) setState(() => _partnerAvatarUrl = data['avatar_url'] as String?);
    } catch (_) {
      // Аватарки может не быть или профиль ещё не создан — иконка-заглушка не хуже.
    }
  }

  void _showPartnerCard() {
    final t = context.tokens;
    showClarifyBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: t.accentSoft,
              backgroundImage: _partnerAvatarUrl != null ? NetworkImage(_partnerAvatarUrl!) : null,
              child: _partnerAvatarUrl == null
                  ? Text(widget.partnerName.isNotEmpty ? widget.partnerName[0].toUpperCase() : '?', style: TextStyle(fontSize: 28, color: t.accent, fontWeight: FontWeight.bold))
                  : null,
            ),
            const SizedBox(height: 12),
            Text(widget.partnerName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: t.text)),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await Supabase.instance.client
          .from('messages')
          .select()
          .or('and(from_id.eq.$_myId,to_id.eq.${widget.partnerId}),and(from_id.eq.${widget.partnerId},to_id.eq.$_myId)')
          .order('created_at', ascending: true);
      if (mounted) {
        setState(() => _messages = List<Map<String, dynamic>>.from(data));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        });
      }
    } on PostgrestException {
      if (mounted) setState(() => _messages = []);
    }
  }

  Future<void> _submit(String text) async {
    if (_editingMessage != null) {
      await _editMessage((_editingMessage!['id'] as num).toInt(), text);
    } else {
      await _sendMessage(text);
    }
  }

  Future<void> _sendMessage(String text) async {
    try {
      await Supabase.instance.client.from('messages').insert({
        'from_id': _myId,
        'to_id': widget.partnerId,
        'text': text,
        if (_replyingTo != null) 'reply_to_id': _replyingTo!['id'],
      });
      if (mounted) setState(() => _replyingTo = null);
      await _load();
    } on PostgrestException catch (e) {
      if (mounted) ClarifyToast.show(context, 'Ошибка отправки: ${e.message}', variant: ClarifyToastVariant.danger);
    }
  }

  Future<void> _editMessage(int id, String text) async {
    try {
      await Supabase.instance.client.rpc('edit_message', params: {'message_id': id, 'new_text': text});
      if (mounted) setState(() => _editingMessage = null);
      await _load();
    } on PostgrestException catch (e) {
      if (mounted) ClarifyToast.show(context, 'Ошибка редактирования: ${e.message}', variant: ClarifyToastVariant.danger);
    }
  }

  Future<void> _deleteMessage(int id) async {
    try {
      await Supabase.instance.client.rpc('delete_message', params: {'message_id': id});
      await _load();
    } on PostgrestException catch (e) {
      if (mounted) ClarifyToast.show(context, 'Ошибка удаления: ${e.message}', variant: ClarifyToastVariant.danger);
    }
  }

  Future<void> _togglePin(int id) async {
    try {
      await Supabase.instance.client.rpc('toggle_pin_message', params: {'message_id': id});
      await _load();
    } on PostgrestException catch (e) {
      if (mounted) ClarifyToast.show(context, 'Ошибка: ${e.message}', variant: ClarifyToastVariant.danger);
    }
  }

  void _openActions(Map<String, dynamic> m) {
    final isMine = m['from_id'] == _myId;
    final id = (m['id'] as num).toInt();
    showMessageActions(
      context: context,
      isMobile: true,
      isMine: isMine,
      isPinned: m['pinned'] as bool? ?? false,
      currentLang: widget.currentLang,
      onReply: () => setState(() {
        _replyingTo = m;
        _editingMessage = null;
      }),
      onForward: () => forwardMessage(
        context: context,
        isMobile: true,
        currentLang: widget.currentLang,
        text: m['text'] as String,
        forwardedFromName: isMine ? 'Вы'.tr(widget.currentLang) : widget.partnerName,
      ),
      onTogglePin: () => _togglePin(id),
      onEdit: isMine
          ? () => setState(() {
                _editingMessage = m;
                _replyingTo = null;
              })
          : null,
      onDelete: isMine ? () => _deleteMessage(id) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final byId = _messages == null ? <dynamic, Map<String, dynamic>>{} : {for (final m in _messages!) m['id']: m};
    final pinnedList = _messages?.where((m) => m['pinned'] == true).toList() ?? const [];
    final pinnedMessage = pinnedList.isEmpty ? null : pinnedList.first;

    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        elevation: 0,
        foregroundColor: t.text,
        title: Text(widget.partnerName, style: TextStyle(fontFamily: 'Golos Text', fontWeight: FontWeight.w700)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: _showPartnerCard,
              child: CircleAvatar(
                radius: 18,
                backgroundColor: t.accentSoft,
                backgroundImage: _partnerAvatarUrl != null ? NetworkImage(_partnerAvatarUrl!) : null,
                child: _partnerAvatarUrl == null
                    ? Text(widget.partnerName.isNotEmpty ? widget.partnerName[0].toUpperCase() : '?', style: TextStyle(color: t.accent, fontWeight: FontWeight.bold))
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (pinnedMessage != null)
            PinnedMessageBar(
              currentLang: widget.currentLang,
              text: pinnedMessage['text'] as String,
              onUnpin: () => _togglePin((pinnedMessage['id'] as num).toInt()),
            ),
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
                      final replyTo = byId[m['reply_to_id']];
                      return ChatMessageBubble(
                        currentLang: widget.currentLang,
                        message: m,
                        isMine: isMine,
                        showReadTicks: true,
                        replyToMessage: replyTo,
                        replyToSenderLabel: replyTo == null ? '' : (replyTo['from_id'] == _myId ? 'Вы'.tr(widget.currentLang) : widget.partnerName),
                        onOpenActions: () => _openActions(m),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: ChatComposer(
              currentLang: widget.currentLang,
              onSubmit: _submit,
              replyPreviewLabel: _replyingTo == null ? null : (_replyingTo!['from_id'] == _myId ? 'Вы'.tr(widget.currentLang) : widget.partnerName),
              replyPreviewText: _replyingTo == null ? null : _replyingTo!['text'] as String,
              onCancelReply: () => setState(() => _replyingTo = null),
              isEditing: _editingMessage != null,
              editingInitialText: _editingMessage?['text'] as String?,
              onCancelEdit: () => setState(() => _editingMessage = null),
            ),
          ),
        ],
      ),
    );
  }
}
