import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/photo_picker_dialog.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback? onProfileUpdated;
  final VoidCallback onLogout;

  const ProfileScreen({
    super.key,
    this.onProfileUpdated,
    required this.onLogout,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final api = ApiService();
  bool isUpdating = false;

  void _changePhoto() {
    PhotoPickerDialog.show(
      context,
      currentAvatarUrl: api.currentUser?['avatarUrl'],
      onPhotoSelected: (newUrl) async {
        setState(() => isUpdating = true);
        final res = await api.updateProfile(avatarUrl: newUrl);
        setState(() => isUpdating = false);

        if (!mounted) return;
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppTheme.success,
              content: Text('Photo de profil synchronisée avec succès !'),
            ),
          );
          widget.onProfileUpdated?.call();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.danger,
              content: Text(res['message'] ?? 'Erreur lors de la mise à jour'),
            ),
          );
        }
      },
    );
  }

  void _editPhone() {
    final phoneCtrl = TextEditingController(text: api.currentUser?['phone'] ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modifier le téléphone'),
        content: TextField(
          controller: phoneCtrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Numéro de téléphone',
            prefixIcon: Icon(Icons.phone),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => isUpdating = true);
              await api.updateProfile(phone: phoneCtrl.text.trim());
              setState(() => isUpdating = false);
              widget.onProfileUpdated?.call();
            },
            child: const Text('Enregistrer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = api.currentUser;
    final profile = api.currentProfile;
    final role = user?['role'] ?? 'STAFF';

    final firstName = user?['firstName'] ?? '';
    final lastName = user?['lastName'] ?? '';
    final fullName = '$firstName $lastName'.trim();
    final email = user?['email'] ?? '—';
    final phone = user?['phone'] ?? 'Non renseigné';
    final cin = user?['cin'] ?? '—';
    final avatarUrl = user?['avatarUrl'];
    final roleColor = AppTheme.getRoleColor(role);

    // Extraction des détails spécifiques
    String licenseNumber = '—';
    String serviceOrSpecialty = '—';
    String shiftOrRoom = '—';

    if (profile != null) {
      licenseNumber = profile['licenseNumber'] ?? profile['registryId'] ?? '—';
      serviceOrSpecialty = profile['specialty'] ??
          profile['technicalSpecialty'] ??
          profile['department'] ??
          profile['service'] ??
          '—';
      shiftOrRoom = profile['shift'] ?? profile['officeRoom'] ?? '—';
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Mon Profil Professionnel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              setState(() => isUpdating = true);
              await api.fetchProfile();
              setState(() => isUpdating = false);
            },
          ),
        ],
      ),
      body: isUpdating
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Carte En-tête Avatar & Rôle
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        AvatarWidget(
                          avatarUrl: avatarUrl,
                          name: fullName,
                          role: role,
                          radius: 46,
                          isEditable: true,
                          onTap: _changePhoto,
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: _changePhoto,
                          icon: const Icon(Icons.photo_camera, size: 16),
                          label: const Text(
                            'Modifier la photo',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          fullName.isNotEmpty ? fullName : 'Collaborateur Arij',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textMain,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: roleColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            AppTheme.getRoleLabel(role),
                            style: TextStyle(
                              color: roleColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Section Données d'accréditation clinique
                  _sectionCard(
                    title: 'Accréditation & Exercice',
                    icon: Icons.verified_user_outlined,
                    children: [
                      _infoRow(label: 'Numéro CIN', value: cin, isCode: true),
                      if (licenseNumber != '—')
                        _infoRow(label: 'N° Ordre / Registre', value: licenseNumber, isCode: true),
                      _infoRow(label: 'Spécialité / Service', value: serviceOrSpecialty),
                      if (shiftOrRoom != '—')
                        _infoRow(label: 'Affectation / Shift', value: shiftOrRoom),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Section Coordonnées & Connexion
                  _sectionCard(
                    title: 'Coordonnées professionnelles',
                    icon: Icons.contact_phone_outlined,
                    children: [
                      _infoRow(label: 'Email de connexion', value: email),
                      _infoRow(
                        label: 'Téléphone de contact',
                        value: phone,
                        action: IconButton(
                          icon: const Icon(Icons.edit, size: 16, color: AppTheme.primary),
                          onPressed: _editPhone,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ),
                      _infoRow(label: 'Établissement', value: 'Polyclinique Arij, Djerba'),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Bouton Déconnexion
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.danger,
                        side: const BorderSide(color: Color(0xFFFECACA)),
                        backgroundColor: const Color(0xFFFEF2F2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: widget.onLogout,
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text(
                        'Se déconnecter',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMain,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow({
    required String label,
    required String value,
    bool isCode = false,
    Widget? action,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isCode)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      value,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppTheme.textMain,
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: Text(
                      value,
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppTheme.textMain,
                      ),
                    ),
                  ),
                if (action != null) ...[
                  const SizedBox(width: 8),
                  action,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
