import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
  bool isRecordingAudio = false;
  Timer? _pollingTimer;

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
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 2000), (_) async {
      if (!mounted) return;
      try {
        final targetId = widget.isGroup ? widget.target['id'] : (widget.target['_id'] ?? widget.target['id']);
        final list = await api.getChatHistory(targetId.toString(), isGroup: widget.isGroup);
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
      final targetId = widget.isGroup ? widget.target['id'] : (widget.target['_id'] ?? widget.target['id']);
      final list = await api.getChatHistory(targetId.toString(), isGroup: widget.isGroup);
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
    final targetId = widget.isGroup ? widget.target['id'] : (widget.target['_id'] ?? widget.target['id']);

    final res = await api.sendMessage(
      recipientId: widget.isGroup ? null : targetId.toString(),
      groupId: widget.isGroup ? targetId.toString() : null,
      content: text.isNotEmpty ? text : (type == 'IMAGE' ? '📷 Photo jointe' : '📎 Pièce jointe'),
      messageType: type,
      attachments: attachments,
    );

    if (res['success'] == true) {
      _loadMessages();
    }
  }

  void _startCall(String callType) async {
    final targetId = widget.isGroup ? widget.target['id'] : (widget.target['_id'] ?? widget.target['id']);

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
    final targetId = widget.isGroup ? widget.target['id'] : (widget.target['_id'] ?? widget.target['id']);
    if (action == 'LEAVE_GROUP') {
      final res = await api.leaveGroup(targetId.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['data']?['message'] ?? 'Vous avez quitté le groupe.')));
        Navigator.pop(context);
      }
    } else if (action == 'BLOCK') {
      final res = await api.blockUser(targetId.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['data']?['message'] ?? 'Statut du contact mis à jour.')));
      }
    } else if (action == 'ARCHIVE') {
      final res = await api.archiveConversation(targetId.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['data']?['message'] ?? 'Discussion archivée.')));
        Navigator.pop(context);
      }
    }
  }

  void _showAttachmentPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('Partager un document ou un média', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _attachmentOption(
                  icon: CupertinoIcons.photo_fill,
                  color: Colors.purple,
                  label: 'Photo / Cliché',
                  onTap: () async {
                    Navigator.pop(ctx);
                    final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['jpg', 'png', 'jpeg']);
                    if (file != null) {
                      _sendMessage(
                        content: '📷 Image transmise : ${file.name}',
                        type: 'IMAGE',
                        attachments: [
                          {'url': file.path ?? file.name, 'name': file.name, 'fileType': 'image/jpeg'}
                        ],
                      );
                    }
                  },
                ),
                _attachmentOption(
                  icon: CupertinoIcons.doc_fill,
                  color: Colors.red,
                  label: 'Document PDF',
                  onTap: () async {
                    Navigator.pop(ctx);
                    final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['pdf', 'doc', 'docx']);
                    if (file != null) {
                      _sendMessage(
                        content: '📄 Document joint : ${file.name}',
                        type: 'DOCUMENT',
                        attachments: [
                          {'url': file.path ?? file.name, 'name': file.name, 'fileType': 'application/pdf'}
                        ],
                      );
                    }
                  },
                ),
                _attachmentOption(
                  icon: CupertinoIcons.capsule_fill,
                  color: AppTheme.accent,
                  label: 'Ordonnance',
                  onTap: () {
                    Navigator.pop(ctx);
                    _sendMessage(
                      content: '💊 Prescriptions / Ordonnance médicale jointe pour validation.',
                      type: 'PRESCRIPTION',
                    );
                  },
                ),
                _attachmentOption(
                  icon: CupertinoIcons.lab_flask,
                  color: const Color(0xFF059669),
                  label: 'Résultat Labo',
                  onTap: () {
                    Navigator.pop(ctx);
                    _sendMessage(
                      content: '🧪 Résultats d\'analyse biologique du patient disponibles.',
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
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = api.currentUser?['id'] ?? api.currentUser?['_id'];
    final name = widget.target['name'] ??
        '${widget.target['firstName'] ?? ''} ${widget.target['lastName'] ?? ''}'.trim();
    final role = widget.target['role'] ?? (widget.isGroup ? 'Groupe' : 'Staff');
    final avatarUrl = widget.target['avatarUrl'];

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        elevation: 1,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.chevron_back, color: Color(0xFF0F172A)),
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
                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 15, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.isGroup ? role : 'En ligne',
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Appel Audio',
            icon: const Icon(CupertinoIcons.phone_fill, color: AppTheme.accent),
            onPressed: () => _startCall('AUDIO'),
          ),
          IconButton(
            tooltip: 'Appel Vidéo',
            icon: const Icon(CupertinoIcons.videocam_fill, color: AppTheme.accent),
            onPressed: () => _startCall('VIDEO'),
          ),
          PopupMenuButton<String>(
            icon: const Icon(CupertinoIcons.ellipsis_vertical, color: Color(0xFF0F172A)),
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              if (widget.isGroup)
                const PopupMenuItem(
                  value: 'LEAVE_GROUP',
                  child: Row(
                    children: [
                      Icon(CupertinoIcons.arrow_right_square, color: Colors.redAccent, size: 20),
                      SizedBox(width: 8),
                      Text('Quitter le groupe'),
                    ],
                  ),
                )
              else
                const PopupMenuItem(
                  value: 'BLOCK',
                  child: Row(
                    children: [
                      Icon(CupertinoIcons.slash_circle, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Text('Bloquer / Débloquer'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'ARCHIVE',
                child: Row(
                  children: [
                    Icon(CupertinoIcons.archivebox, color: Colors.grey, size: 20),
                    SizedBox(width: 8),
                    Text('Archiver la discussion'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          // Historique des messages
          Expanded(
            child: isLoading
                ? const Center(child: CupertinoActivityIndicator())
                : messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.chat_bubble, size: 54, color: Colors.grey.shade400),
                            const SizedBox(height: 10),
                            Text('Démarrer la discussion avec $name', style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        itemCount: messages.length,
                        itemBuilder: (context, idx) {
                          final msg = messages[idx];
                          final sender = msg['senderId'];
                          final senderIdStr = sender is Map ? (sender['_id'] ?? sender['id']) : sender;
                          final isMe = senderIdStr?.toString() == currentUserId?.toString();

                          final senderName = sender is Map
                              ? '${sender['firstName'] ?? ''} ${sender['lastName'] ?? ''}'.trim()
                              : 'Soignant';

                          return _buildMessageBubble(msg, isMe, senderName);
                        },
                      ),
          ),

          // Barre de saisie style Messenger/WhatsApp
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -1))],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(CupertinoIcons.plus_circle_fill, color: AppTheme.accent, size: 26),
                    onPressed: _showAttachmentPicker,
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: messageCtrl,
                        minLines: 1,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: 'Écrire un message...',
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppTheme.accent,
                    child: IconButton(
                      icon: const Icon(CupertinoIcons.arrow_up, color: Colors.white, size: 18),
                      onPressed: () => _sendMessage(),
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

  Widget _buildMessageBubble(dynamic msg, bool isMe, String senderName) {
    final content = msg['content'] ?? '';
    final type = msg['messageType'] ?? 'TEXT';
    final attachments = msg['attachments'] as List? ?? [];
    final dt = DateTime.tryParse(msg['createdAt']?.toString() ?? '')?.toLocal();
    final timeStr = dt != null ? '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}' : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe && widget.isGroup)
            Padding(
              padding: const EdgeInsets.only(left: 6, bottom: 2),
              child: Text(senderName, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
            ),
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isMe ? const Color(0xFF0284C7) : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMe ? 16 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 16),
              ),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type spécifique (Badge Ordonnance / Labo / Appel)
                if (type == 'CALL_OFFER')
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.white24 : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isMe ? Colors.white30 : const Color(0xFFBFDBFE)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.phone_in_talk, size: 18, color: isMe ? Colors.white : const Color(0xFF0284C7)),
                            const SizedBox(width: 6),
                            Text(
                              isMe ? 'Appel émis' : 'Appel entrant...',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isMe ? Colors.white : const Color(0xFF0369A1)),
                            ),
                          ],
                        ),
                        if (!isMe) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF16A34A),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  elevation: 0,
                                ),
                                icon: const Icon(Icons.call, size: 16),
                                label: const Text('Décrocher', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                onPressed: () {
                                  final isVideo = content.toLowerCase().contains('vidéo');
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CallOverlayScreen(
                                        contact: widget.target,
                                        callType: isVideo ? 'VIDEO' : 'AUDIO',
                                        isCaller: false,
                                        onEndCall: () => Navigator.pop(context),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                if (type == 'PRESCRIPTION')

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(color: isMe ? Colors.white24 : const Color(0xFFE0F2FE), borderRadius: BorderRadius.circular(6)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.medical_information, size: 14, color: isMe ? Colors.white : const Color(0xFF0369A1)),
                        const SizedBox(width: 4),
                        Text('Ordonnance Médicale', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isMe ? Colors.white : const Color(0xFF0369A1))),
                      ],
                    ),
                  ),

                if (type == 'RESULT')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(color: isMe ? Colors.white24 : const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(6)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.biotech, size: 14, color: isMe ? Colors.white : const Color(0xFF15803D)),
                        const SizedBox(width: 4),
                        Text('Résultat d\'Analyse', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isMe ? Colors.white : const Color(0xFF15803D))),
                      ],
                    ),
                  ),

                // Pièces jointes
                if (attachments.isNotEmpty) ...[
                  ...attachments.map((att) {
                    final url = att['url']?.toString() ?? '';
                    final isPdf = url.toLowerCase().endsWith('.pdf') || att['fileType'] == 'application/pdf';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isMe ? Colors.white12 : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(isPdf ? Icons.picture_as_pdf : Icons.image, color: isMe ? Colors.white : const Color(0xFF0284C7), size: 22),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              att['name'] ?? 'Fichier',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isMe ? Colors.white : const Color(0xFF0F172A)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],

                // Texte du message
                Text(
                  content,
                  style: TextStyle(
                    color: isMe ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      timeStr,
                      style: TextStyle(
                        fontSize: 10,
                        color: isMe ? Colors.white70 : const Color(0xFF94A3B8),
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      Icon(
                        msg['isRead'] == true ? Icons.done_all : Icons.done,
                        size: 13,
                        color: msg['isRead'] == true ? Colors.cyanAccent : Colors.white70,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
