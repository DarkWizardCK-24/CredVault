import 'package:cred_vault/models/platform_catalog.dart';
import 'package:cred_vault/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// A service's brand icon on a softly tinted rounded square.
class PlatformAvatar extends StatelessWidget {
  final String platform;
  final double size;

  const PlatformAvatar({super.key, required this.platform, this.size = 52});

  @override
  Widget build(BuildContext context) {
    final info = PlatformCatalog.of(platform);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.3),
        color: info.color.withValues(alpha: 0.14),
        border: Border.all(color: info.color.withValues(alpha: 0.35)),
      ),
      child: Center(
        child: FaIcon(info.icon, color: info.color, size: size * 0.44),
      ),
    );
  }
}

/// Bottom sheet with a searchable grid of services. Returns the chosen name.
Future<String?> showPlatformPicker(BuildContext context, {String? selected}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _PlatformPicker(selected: selected),
  );
}

class _PlatformPicker extends StatefulWidget {
  final String? selected;

  const _PlatformPicker({this.selected});

  @override
  State<_PlatformPicker> createState() => _PlatformPickerState();
}

class _PlatformPickerState extends State<_PlatformPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final platforms = PlatformCatalog.all
        .where((p) => q.isEmpty || p.name.toLowerCase().contains(q))
        .toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, controller) => Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Choose a service',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Search services',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: platforms.isEmpty
                ? const Center(
                    child: Text(
                      'No match - pick "Other" to name it yourself',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  )
                : GridView.builder(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          mainAxisExtent: 104,
                        ),
                    itemCount: platforms.length,
                    itemBuilder: (context, i) {
                      final p = platforms[i];
                      final isSelected = p.name == widget.selected;
                      return InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => Navigator.pop(context, p.name),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            color: isSelected
                                ? AppTheme.gold.withValues(alpha: 0.12)
                                : AppTheme.surfaceHigh.withValues(alpha: 0.6),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.gold
                                  : AppTheme.border,
                              width: isSelected ? 1.6 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              PlatformAvatar(platform: p.name, size: 44),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                child: Text(
                                  p.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
