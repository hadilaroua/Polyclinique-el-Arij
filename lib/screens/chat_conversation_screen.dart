import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';
import '../widgets/avatar_widget.dart';
import 'call_overlay_screen.dart';

class ChatConversationScreen extends StatefulWidget {
  final Map<String, dynamic> target;
  final bool isGroup;

  const ChatConversationScreen({
    super.key,
    required this.target,
    this.isGroup = false,
  });

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  final api = ApiService();
  final messageCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  List<dynamic> messages = [];
  bool isLoading = true;
  Timer? _pollingTimer;
  Map<String, dynamic>? _replyingToMessage;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _startSync();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _scrollCtrl.dispose();
    messageCtrl.dispose();
    super.dispose();
  }

  void _startSync() {
    _pollingTimer?.cancel();
    _pollingTimer =
        Timer.periodic(const Duration(milliseconds: 2000), (_) async {
      if (!mounted) return;
      try {
        final targetId = widget.isGroup
            ? widget.target['id']
            : (widget.target['_id'] ?? widget.target['id']);
        final list = await api.getChatHistory(targetId.toString(),
            isGroup: widget.isGroup);
        if (!mounted) return;
        if (list.length != messages.length) {
          setState(() {
            messages = list;
          });
          _scrollToBottom();
        }
      } catch (_) {}
    });
  }

  Future<void> _loadMessages() async {
    setState(() => isLoading = true);
    try {
      final targetId = widget.isGroup
          ? widget.target['id']
          : (widget.target['_id'] ?? widget.target['id']);
      final list = await api.getChatHistory(targetId.toString(),
          isGroup: widget.isGroup);
      if (mounted) {
        setState(() {
          messages = list;
          isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage({
    String? content,
    String type = 'TEXT',
    List<Map<String, dynamic>>? attachments,
  }) async {
    final text = content ?? messageCtrl.text.trim();
    if (text.isEmpty && (attachments == null || attachments.isEmpty)) return;

    messageCtrl.clear();
    final targetId = widget.isGroup
        ? widget.target['id']
        : (widget.target['_id'] ?? widget.target['id']);

    String finalContent = text;
    if (_replyingToMessage != null && text.isNotEmpty) {
      final replySender = _replyingToMessage!['senderId'];
      final replyName = replySender is Map
          ? '${replySender['firstName'] ?? ''} ${replySender['lastName'] ?? ''}'.trim()
          : 'Soignant';
      final replySnippet = _replyingToMessage!['content']?.toString() ?? '';
      finalContent = '↪️ [Réponse à $replyName: "$replySnippet"]\n$text';
    }

    setState(() => _replyingToMessage = null);

    final res = await api.sendMessage(
      recipientId: widget.isGroup ? null : targetId.toString(),
      groupId: widget.isGroup ? targetId.toString() : null,
      content: finalContent.isNotEmpty
          ? finalContent
          : (type == 'IMAGE' ? '📷 Photo jointe' : '📎 Pièce jointe'),
      messageType: type,
      attachments: attachments,
    );

    if (res['success'] == true) {
      _loadMessages();
    }
  }

  void _startCall(String callType) async {
    final targetId = widget.isGroup
        ? widget.target['id']
        : (widget.target['_id'] ?? widget.target['id']);

    await api.sendCallSignal(
      targetUserId: targetId.toString(),
      callType: callType,
      action: 'OFFER',
    );

    await _sendMessage(
      content: '📞 Appel ${callType == "VIDEO" ? "Vidéo" : "Audio"} en cours...',
      type: 'CALL_OFFER',
    );

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallOverlayScreen(
          contact: widget.target,
          callType: callType,
          isCaller: true,
          onEndCall: () {
            api.sendCallSignal(
              targetUserId: targetId.toString(),
              callType: callType,
              action: 'HANGUP',
            );
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  void _handleMenuAction(String action) async {
    final targetId = widget.isGroup
        ? widget.target['id']
        : (widget.target['_id'] ?? widget.target['id']);
    if (action == 'LEAVE_GROUP') {
      final res = await api.leaveGroup(targetId.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                res['data']?['message'] ?? 'Vous avez quitté le groupe.')));
        Navigator.pop(context);
      }
    } else if (action == 'BLOCK') {
      final res = await api.blockUser(targetId.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                res['data']?['message'] ?? 'Statut du contact mis à jour.')));
      }
    } else if (action == 'ARCHIVE') {
      final res = await api.archiveConversation(targetId.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                res['data']?['message'] ?? 'Discussion archivée.')));
        Navigator.pop(context);
      }
    }
  }

  void _showAttachmentPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 20),
            Text(
              'Partager un fichier médical',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: AppTheme.textColor(context),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _attachmentOption(
                  icon: Icons.photo_outlined,
                  color: const Color(0xFF8B5CF6),
                  label: 'Photo',
                  onTap: () async {
                    Navigator.pop(ctx);
                    final file = await FilePicker.pickFile(
                        type: FileType.custom,
                        allowedExtensions: ['jpg', 'png', 'jpeg']);
                    if (file != null) {
                      _sendMessage(
                        content: '📷 Image : ${file.name}',
                        type: 'IMAGE',
                        attachments: [
                          {
                            'url': file.path ?? file.name,
                            'name': file.name,
                            'fileType': 'image/jpeg'
                          }
                        ],
                      );
                    }
                  },
                ),
                _attachmentOption(
                  icon: Icons.picture_as_pdf_outlined,
                  color: const Color(0xFFEF4444),
                  label: 'PDF',
                  onTap: () async {
                    Navigator.pop(ctx);
                    final file = await FilePicker.pickFile(
                        type: FileType.custom,
                        allowedExtensions: ['pdf', 'doc', 'docx']);
                    if (file != null) {
                      _sendMessage(
                        content: '📄 Document : ${file.name}',
                        type: 'DOCUMENT',
                        attachments: [
                          {
                            'url': file.path ?? file.name,
                            'name': file.name,
                            'fileType': 'application/pdf'
                          }
                        ],
                      );
                    }
                  },
                ),
                _attachmentOption(
                  icon: Icons.medication_outlined,
                  color: const Color(0xFF10B981),
                  label: 'Ordonnance',
                  onTap: () {
                    Navigator.pop(ctx);
                    _sendMessage(
                      content: '💊 Ordonnance médicale transmise.',
                      type: 'PRESCRIPTION',
                    );
                  },
                ),
                _attachmentOption(
                  icon: Icons.science_outlined,
                  color: const Color(0xFF0284C7),
                  label: 'Résultat labo',
                  onTap: () {
                    Navigator.pop(ctx);
                    _sendMessage(
                      content:
                          '🧪 Résultats d\'analyse disponibles.',
                      type: 'RESULT',
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _attachmentOption({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textColor(context))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = api.currentUser?['id'] ?? api.currentUser?['_id'];
    final target = widget.target;
    final name =
        target['name'] ??
        '${target['firstName'] ?? ''} ${target['lastName'] ?? ''}'.trim();
    final role = target['role'] ?? (widget.isGroup ? 'Groupe' : 'Staff');
    final avatarUrl = target['avatarUrl'];
    final roleLabel = AppTheme.getRoleLabel(role);
    final roleColor = AppTheme.getRoleColor(role);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor(context),
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceColor(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: AppTheme.textColor(context), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            AvatarWidget(
              avatarUrl: avatarUrl,
              name: name.isNotEmpty ? name : 'Discussion',
              role: role,
              radius: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isNotEmpty ? name : 'Messagerie',
                    style: TextStyle(
                      color: AppTheme.textColor(context),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: AppTheme.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        widget.isGroup ? 'Groupe • $roleLabel' : roleLabel,
                        style: TextStyle(
                          color: widget.isGroup
                              ? AppTheme.subtextColor(context)
                              : roleColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Audio call
          Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: AppTheme.elevatedSurface(context),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.borderColor(context)),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(Icons.phone_outlined,
                  size: 18, color: AppTheme.textColor(context)),
              onPressed: () => _startCall('AUDIO'),
            ),
          ),
          // Video call
          Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: AppTheme.elevatedSurface(context),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.borderColor(context)),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(Icons.videocam_outlined,
                  size: 18, color: AppTheme.textColor(context)),
              onPressed: () => _startCall('VIDEO'),
            ),
          ),
          // More
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded,
                color: AppTheme.textColor(context), size: 20),
            onSelected: _handleMenuAction,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            itemBuilder: (context) => [
              if (widget.isGroup)
                const PopupMenuItem(
                  value: 'LEAVE_GROUP',
                  child: Row(
                    children: [
                      Icon(Icons.exit_to_app_rounded,
                          color: Colors.redAccent, size: 18),
                      SizedBox(width: 10),
                      Text('Quitter le groupe'),
                    ],
                  ),
                )
              else
                const PopupMenuItem(
                  value: 'BLOCK',
                  child: Row(
                    children: [
                      Icon(Icons.block_rounded, color: Colors.orange, size: 18),
                      SizedBox(width: 10),
                      Text('Bloquer'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'ARCHIVE',
                child: Row(
                  children: [
                    Icon(Icons.archive_outlined, color: Colors.grey, size: 18),
                    SizedBox(width: 10),
                    Text('Archiver'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
              height: 1,
              thickness: 1,
              color: AppTheme.borderColor(context)),
        ),
      ),
      body: Column(
        children: [
          // ── Messages ─────────────────────────────────────────────────
          Expanded(
            child: isLoading
                ? const Center(child: CupertinoActivityIndicator())
                : messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppTheme.elevatedSurface(context),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.chat_bubble_outline_rounded,
                                  size: 36,
                                  color: AppTheme.subtextColor(context)),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Démarrer la discussion',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: AppTheme.textColor(context),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Envoyez votre premier message à $name',
                              style: TextStyle(
                                  color: AppTheme.subtextColor(context),
                                  fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        itemCount: messages.length,
                        itemBuilder: (context, idx) {
                          final msg = messages[idx];
                          final sender = msg['senderId'];
                          final senderIdStr = sender is Map
                              ? (sender['_id'] ?? sender['id'])
                              : sender;
                          final isMe = senderIdStr?.toString() ==
                              currentUserId?.toString();

                          final senderName = sender is Map
                              ? '${sender['firstName'] ?? ''} ${sender['lastName'] ?? ''}'
                                  .trim()
                              : 'Soignant';

                          // Date separator
                          bool showDate = false;
                          if (idx == 0) {
                            showDate = true;
                          } else {
                            final prevMsg = messages[idx - 1];
                            final prevDt = DateTime.tryParse(
                                prevMsg['createdAt']?.toString() ?? '');
                            final currDt = DateTime.tryParse(
                                msg['createdAt']?.toString() ?? '');
                            if (prevDt != null && currDt != null) {
                              if (prevDt.day != currDt.day) showDate = true;
                            }
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (showDate)
                                _buildDateSeparator(msg['createdAt']),
                              _buildMessageBubble(msg, isMe, senderName),
                            ],
                          );
                        },
                      ),
          ),

          // ── Replying Preview Banner ──────────────────────────────────
          if (_replyingToMessage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.isDarkMode(context)
                    ? AppTheme.darkElevated
                    : const Color(0xFFEFF6FF),
                border: Border(
                  top: BorderSide(color: AppTheme.borderColor(context)),
                  left: const BorderSide(color: AppTheme.secondaryBondi, width: 4),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(CupertinoIcons.arrowshape_turn_up_left_fill,
                                size: 12, color: AppTheme.secondaryBondi),
                            const SizedBox(width: 5),
                            Text(
                              'Réponse au message',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.secondaryBondi,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _replyingToMessage!['content']?.toString() ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.subtextColor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    color: AppTheme.subtextColor(context),
                    onPressed: () => setState(() => _replyingToMessage = null),
                  ),
                ],
              ),
            ),

          // ── Input bar ─────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor(context),
              border: Border(
                  top: BorderSide(
                      color: AppTheme.borderColor(context), width: 1)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  // Attachment button
                  GestureDetector(
                    onTap: _showAttachmentPicker,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppTheme.elevatedSurface(context),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.attach_file_rounded,
                          size: 20, color: AppTheme.subtextColor(context)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Text field
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.elevatedSurface(context),
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: AppTheme.borderColor(context)),
                      ),
                      child: TextField(
                        controller: messageCtrl,
                        minLines: 1,
                        maxLines: 4,
                        style: TextStyle(
                            color: AppTheme.textColor(context), fontSize: 15),
                        decoration: InputDecoration(
                          hintText: _replyingToMessage != null
                              ? 'Votre réponse...'
                              : 'Écrire un message...',
                          hintStyle: TextStyle(
                              color: AppTheme.subtextColor(context),
                              fontSize: 14),
                          border: InputBorder.none,
                          filled: false,
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Send button
                  GestureDetector(
                    onTap: () => _sendMessage(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryBondi,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.secondaryBondi.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.arrow_upward_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSeparator(dynamic createdAt) {
    final dt =
        DateTime.tryParse(createdAt?.toString() ?? '')?.toLocal();
    if (dt == null) return const SizedBox.shrink();

    final now = DateTime.now();
    String label;
    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
      label = "Aujourd'hui";
    } else if (dt.day == now.day - 1) {
      label = 'Hier';
    } else {
      label =
          '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.elevatedSurface(context),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.subtextColor(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(
      dynamic msg, bool isMe, String senderName) {
    final content = msg['content'] ?? '';
    final type = msg['messageType'] ?? 'TEXT';
    final attachments = msg['attachments'] as List? ?? [];
    final dt =
        DateTime.tryParse(msg['createdAt']?.toString() ?? '')?.toLocal();
    final timeStr = dt != null
        ? '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
        : '';

    final isDark = AppTheme.isDarkMode(context);
    final meBubbleColor = AppTheme.secondaryBondi;
    final otherBubbleColor = isDark ? AppTheme.darkCard : Colors.white;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onDoubleTap: () => _showMessageActionSheet(msg, isMe, senderName),
        onLongPress: () => _showMessageActionSheet(msg, isMe, senderName),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isMe && widget.isGroup)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 3),
                  child: Text(
                    senderName,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.subtextColor(context)),
                  ),
                ),
              Container(
                constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.78),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isMe ? meBubbleColor : otherBubbleColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isMe ? 18 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 18),
                  ),
                  border: isMe
                      ? null
                      : Border.all(
                          color: isDark ? AppTheme.darkBorder : AppTheme.border,
                          width: 1,
                        ),
                  boxShadow: isMe
                      ? [
                          BoxShadow(
                            color: meBubbleColor.withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          )
                        ],
                ),
                child: Column(
                  crossAxisAlignment:
                      isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    // Special type badges (Calls, Prescriptions, Results)
                    if (type == 'CALL_OFFER')
                      _callBadge(context, isMe, content)
                    else ...[
                      if (type == 'PRESCRIPTION')
                        _typeBadge(
                          context,
                          isMe,
                          icon: Icons.medication_rounded,
                          label: 'Ordonnance Médicale',
                          color: const Color(0xFF0284C7),
                        ),

                      if (type == 'RESULT')
                        _typeBadge(
                          context,
                          isMe,
                          icon: Icons.science_rounded,
                          label: 'Résultat d\'Analyse',
                          color: const Color(0xFF15803D),
                        ),

                      // Attachments
                      if (attachments.isNotEmpty)
                        ...attachments.map((att) => _attachmentTile(context, att, isMe)),

                      // Text content
                      Text(
                        content,
                        style: TextStyle(
                          color: isMe ? Colors.white : AppTheme.textColor(context),
                          fontSize: 14.5,
                          height: 1.4,
                        ),
                      ),
                    ],

                    const SizedBox(height: 4),

                    // Time + read status
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          timeStr,
                          style: TextStyle(
                            fontSize: 10,
                            color: isMe
                                ? Colors.white.withValues(alpha: 0.75)
                                : AppTheme.subtextColor(context),
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          Icon(
                            msg['isRead'] == true
                                ? Icons.done_all_rounded
                                : Icons.done_rounded,
                            size: 13,
                            color: msg['isRead'] == true
                                ? Colors.cyanAccent.withValues(alpha: 0.95)
                                : Colors.white.withValues(alpha: 0.7),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMessageActionSheet(dynamic msg, bool isMe, String senderName) {
    final content = msg['content']?.toString() ?? '';
    final isDark = AppTheme.isDarkMode(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: AppTheme.subtextColor(context).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Emoji reaction bar (Messenger style)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkElevated : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: ['❤️', '👍', '👏', '😂', '😮', '🙏'].map((emoji) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        _sendMessage(content: emoji, type: 'TEXT');
                      },
                      child: Text(emoji, style: const TextStyle(fontSize: 24)),
                    );
                  }).toList(),
                ),
              ),
              // Actions list
              ListTile(
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryBondi.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(CupertinoIcons.arrowshape_turn_up_left_fill,
                      color: AppTheme.secondaryBondi, size: 18),
                ),
                title: const Text('Répondre',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _replyingToMessage = msg);
                },
              ),
              ListTile(
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(CupertinoIcons.arrowshape_turn_up_right_fill,
                      color: Color(0xFF8B5CF6), size: 18),
                ),
                title: const Text('Transférer',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showForwardMessageModal(content);
                },
              ),
              ListTile(
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(CupertinoIcons.doc_on_doc_fill,
                      color: Colors.blueGrey, size: 18),
                ),
                title: const Text('Copier le texte',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                onTap: () {
                  Navigator.pop(ctx);
                  Clipboard.setData(ClipboardData(text: content));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Message copié dans le presse-papier'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppTheme.vitalEmergency.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(CupertinoIcons.trash_fill,
                      color: AppTheme.vitalEmergency, size: 18),
                ),
                title: const Text('Supprimer pour moi',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: AppTheme.vitalEmergency)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    messages.removeWhere((m) =>
                        m == msg || (m['_id'] != null && m['_id'] == msg['_id']));
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Message supprimé'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showForwardMessageModal(String textToForward) async {
    final staffData = await api.getConversations();
    if (!mounted) return;
    final staff = staffData['staffList'] as List? ?? [];
    final currentUserId = api.currentUser?['id'] ?? api.currentUser?['_id'];
    final isDark = AppTheme.isDarkMode(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.subtextColor(context).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Transférer le message',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textColor(context),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkElevated : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderColor(context)),
              ),
              child: Text(
                '"$textToForward"',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: AppTheme.textColor(context),
                ),
              ),
            ),
            const Text(
              'Choisir un destinataire',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: staff.length,
                itemBuilder: (context, i) {
                  final s = staff[i];
                  final sid = (s['_id'] ?? s['id'])?.toString();
                  if (sid == currentUserId?.toString()) return const SizedBox.shrink();
                  final name =
                      '${s['firstName'] ?? ''} ${s['lastName'] ?? ''}'.trim();
                  final role = s['role'] ?? 'STAFF';

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: AvatarWidget(name: name, role: role, radius: 18),
                    title: Text(name.isNotEmpty ? name : 'Personnel',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(AppTheme.getRoleLabel(role),
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.getRoleColor(role))),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryBondi,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text('Envoyer',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await api.sendMessage(
                        recipientId: sid,
                        content: '↪️ [Transféré] $textToForward',
                        messageType: 'TEXT',
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Message transféré à $name')),
                      );
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

  Widget _callBadge(BuildContext context, bool isMe, String content) {
    final isVideo = content.toLowerCase().contains('vidéo') ||
        content.toLowerCase().contains('video');
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isMe
            ? Colors.white.withValues(alpha: 0.18)
            : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMe
              ? Colors.white.withValues(alpha: 0.3)
              : const Color(0xFFBFDBFE),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: isMe
                  ? Colors.white.withValues(alpha: 0.25)
                  : AppTheme.secondaryBondi.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isVideo
                  ? CupertinoIcons.videocam_fill
                  : (isMe
                      ? CupertinoIcons.phone_fill_arrow_up_right
                      : CupertinoIcons.phone_fill_arrow_down_left),
              size: 16,
              color: isMe ? Colors.white : AppTheme.secondaryBondi,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isVideo ? 'Appel Vidéo' : 'Appel Audio',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isMe ? Colors.white : AppTheme.textColor(context),
                ),
              ),
              const SizedBox(height: 1),
              Text(
                isMe ? 'Appel émis' : 'Appel entrant',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isMe
                      ? Colors.white.withValues(alpha: 0.8)
                      : AppTheme.secondaryBondi,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _typeBadge(
    BuildContext context,
    bool isMe, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: isMe ? Colors.white.withValues(alpha: 0.15) : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: isMe ? Colors.white : color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isMe ? Colors.white : color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _attachmentTile(
      BuildContext context, dynamic att, bool isMe) {
    final url = att['url']?.toString() ?? '';
    final isPdf = url.toLowerCase().endsWith('.pdf') ||
        att['fileType'] == 'application/pdf';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isMe
            ? Colors.white.withValues(alpha: 0.15)
            : AppTheme.elevatedSurface(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
            color: isMe ? Colors.white : const Color(0xFF0284C7),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              att['name'] ?? 'Fichier',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isMe ? Colors.white : AppTheme.textColor(context),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
