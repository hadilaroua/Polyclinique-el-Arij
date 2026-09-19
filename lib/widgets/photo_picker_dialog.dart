import 'package:flutter/material.dart';
import '../utils/theme.dart';
import 'avatar_widget.dart';

class PhotoPickerDialog extends StatefulWidget {
  final String? currentAvatarUrl;
  final Function(String) onPhotoSelected;

  const PhotoPickerDialog({
    super.key,
    this.currentAvatarUrl,
    required this.onPhotoSelected,
  });

  static void show(
    BuildContext context, {
    String? currentAvatarUrl,
    required Function(String) onPhotoSelected,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PhotoPickerDialog(
        currentAvatarUrl: currentAvatarUrl,
        onPhotoSelected: onPhotoSelected,
      ),
    );
  }

  @override
  State<PhotoPickerDialog> createState() => _PhotoPickerDialogState();
}

class _PhotoPickerDialogState extends State<PhotoPickerDialog> {
  late String selectedUrl;
  final customUrlController = TextEditingController();

  final List<Map<String, String>> presets = [
    {
      'label': 'Dr. Homme 1',
      'url': 'https://images.unsplash.com/photo-1622253692010-333f2da6031d?w=300',
    },
    {
      'label': 'Dr. Femme 1',
      'url': 'https://images.unsplash.com/photo-1594824813587-5788e0b1c099?w=300',
    },
    {
      'label': 'Dr. Homme 2',
      'url': 'https://images.unsplash.com/photo-1612349317150-e413f6a5b16d?w=300',
    },
    {
      'label': 'Infirmière',
      'url': 'https://images.unsplash.com/photo-1579684385127-1ef15d508118?w=300',
    },
    {
      'label': 'Sage-femme',
      'url': 'https://images.unsplash.com/photo-1559839734-2b71ea197ec2?w=300',
    },
    {
      'label': 'Technicien',
      'url': 'https://images.unsplash.com/photo-1537368910025-700350fe46c7?w=300',
    },
  ];

  @override
  void initState() {
    super.initState();
    selectedUrl = widget.currentAvatarUrl ?? presets.first['url']!;
    customUrlController.text = widget.currentAvatarUrl ?? '';
  }

  @override
  void dispose() {
    customUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Choisir une photo de profil',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textMain,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Visible par la direction médicale et vos collègues',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 18),

            // Grand aperçu circulaire
            AvatarWidget(
              avatarUrl: selectedUrl,
              name: 'Dr Arij',
              radius: 44,
            ),
            const SizedBox(height: 20),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Avatars cliniques prédéfinis',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMain,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Grille de presets
            SizedBox(
              height: 85,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: presets.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, idx) {
                  final p = presets[idx];
                  final isSelected = selectedUrl == p['url'];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedUrl = p['url']!;
                        customUrlController.text = p['url']!;
                      });
                    },
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? AppTheme.primary : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                          child: AvatarWidget(
                            avatarUrl: p['url'],
                            radius: 26,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          p['label']!,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? AppTheme.primary : AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 14),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Ou saisir une URL de photo personnalisée',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMain,
                ),
              ),
            ),
            const SizedBox(height: 8),

            TextField(
              controller: customUrlController,
              decoration: InputDecoration(
                hintText: 'https://...',
                prefixIcon: const Icon(Icons.link, size: 18),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.check_circle, color: AppTheme.primary),
                  onPressed: () {
                    if (customUrlController.text.trim().isNotEmpty) {
                      setState(() {
                        selectedUrl = customUrlController.text.trim();
                      });
                    }
                  },
                ),
              ),
              onChanged: (val) {
                if (val.trim().isNotEmpty) {
                  setState(() {
                    selectedUrl = val.trim();
                  });
                }
              },
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  widget.onPhotoSelected(selectedUrl);
                  Navigator.pop(context);
                },
                child: const Text(
                  'Confirmer la photo',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
