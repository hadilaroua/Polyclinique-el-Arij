import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/theme.dart';

class GoogleCalendarSyncModal extends StatefulWidget {
  const GoogleCalendarSyncModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const GoogleCalendarSyncModal(),
    );
  }

  @override
  State<GoogleCalendarSyncModal> createState() => _GoogleCalendarSyncModalState();
}

class _GoogleCalendarSyncModalState extends State<GoogleCalendarSyncModal> {
  final _api = ApiService();
  bool _loading = true;
  bool _isConnected = false;
  String _email = 'doctor.trabelsi@elarij-clinic.tn';
  final _emailCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getGoogleCalendarStatus();
      if (mounted) {
        setState(() {
          _isConnected = res['isConnected'] == true;
          _email = res['accountEmail'] ?? 'doctor.trabelsi@elarij-clinic.tn';
          _emailCtrl.text = _email;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isConnected = true;
          _email = 'doctor.trabelsi@elarij-clinic.tn';
          _emailCtrl.text = _email;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleConnection() async {
    setState(() => _loading = true);
    if (_isConnected) {
      await _api.disconnectGoogleCalendar();
      if (mounted) {
        setState(() {
          _isConnected = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google Calendar déconnecté')),
        );
      }
    } else {
      final emailToUse = _emailCtrl.text.trim().isNotEmpty ? _emailCtrl.text.trim() : 'doctor.trabelsi@elarij-clinic.tn';
      await _api.connectGoogleCalendar(emailToUse);
      if (mounted) {
        setState(() {
          _isConnected = true;
          _email = emailToUse;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Synchronisation Google Calendar activée avec succès'),
            backgroundColor: AppTheme.evergreen,
          ),
        );
      }
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkBackground : AppTheme.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: AppTheme.dustGrey.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(CupertinoIcons.arrow_2_circlepath_circle_fill, color: Colors.blue, size: 24),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Synchronisation Google Calendar',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : AppTheme.evergreen,
                    ),
                  ),
                  const Text(
                    'Service externe de synchronisation',
                    style: TextStyle(fontSize: 12, color: AppTheme.dustGrey),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _isConnected ? AppTheme.evergreen.withOpacity(0.4) : AppTheme.dustGrey.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _isConnected ? AppTheme.evergreen : AppTheme.alertRed,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isConnected ? 'Google Calendar connecté' : 'Google Calendar non connecté',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: isDark ? Colors.white : AppTheme.textMain,
                          ),
                        ),
                        if (_isConnected)
                          Text(
                            _email,
                            style: const TextStyle(fontSize: 12, color: AppTheme.dustGrey),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    _isConnected ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.xmark_circle_fill,
                    color: _isConnected ? AppTheme.evergreen : AppTheme.dustGrey,
                  ),
                ],
              ),
            ),

            if (!_isConnected) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Compte Google',
                  hintText: 'ex: doctor.trabelsi@gmail.com',
                  prefixIcon: const Icon(CupertinoIcons.mail, color: AppTheme.evergreen),
                  filled: true,
                  fillColor: isDark ? AppTheme.darkSurface : Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: CupertinoButton(
                color: _isConnected ? AppTheme.alertRed : AppTheme.evergreen,
                borderRadius: BorderRadius.circular(16),
                onPressed: _toggleConnection,
                child: Text(
                  _isConnected ? 'Déconnecter Google Calendar' : 'Connecter Google Calendar',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 15),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
