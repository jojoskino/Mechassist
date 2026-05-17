import 'package:flutter/material.dart';
import '../theme/app_fonts.dart';

import '../theme/feu_theme.dart';

/// Feuille de notation mécanicien (maquette avis).
class RateMechanicSheet extends StatefulWidget {
  const RateMechanicSheet({
    super.key,
    required this.mechanicName,
    this.subtitle,
  });

  final String mechanicName;
  final String? subtitle;

  static Future<({int stars, String comment, Set<String> tags})?> show(
    BuildContext context, {
    required String mechanicName,
    String? subtitle,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: RateMechanicSheet(mechanicName: mechanicName, subtitle: subtitle),
      ),
    );
  }

  @override
  State<RateMechanicSheet> createState() => _RateMechanicSheetState();
}

class _RateMechanicSheetState extends State<RateMechanicSheet> {
  var _stars = 4;
  final _commentCtrl = TextEditingController();
  final _tags = <String>{'Professionnel'};

  static const _tagOptions = ['Rapide', 'Professionnel', 'Prix juste'];

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: FeuTheme.charcoal.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.mechanicName,
                textAlign: TextAlign.center,
                style: AppFonts.style(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              if (widget.subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  widget.subtitle!,
                  textAlign: TextAlign.center,
                  style: AppFonts.style(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
              const SizedBox(height: 20),
              Text('VOTRE NOTE', style: _label),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  final v = i + 1;
                  return IconButton(
                    onPressed: () => setState(() => _stars = v),
                    icon: Icon(
                      v <= _stars ? Icons.star_rounded : Icons.star_border_rounded,
                      color: Colors.amber.shade700,
                      size: 36,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              Text('POINTS FORTS', style: _label),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _tagOptions.map((t) {
                  final selected = _tags.contains(t);
                  return FilterChip(
                    label: Text(t, style: AppFonts.style(fontWeight: FontWeight.w600)),
                    selected: selected,
                    onSelected: (v) {
                      setState(() {
                        if (v) {
                          _tags.add(t);
                        } else {
                          _tags.remove(t);
                        }
                      });
                    },
                    selectedColor: FeuTheme.deepBlue,
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(color: selected ? Colors.white : FeuTheme.deepBlue),
                    side: BorderSide(color: FeuTheme.deepBlue.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Text('VOTRE AVIS', style: _label),
              const SizedBox(height: 8),
              TextField(
                controller: _commentCtrl,
                minLines: 3,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Racontez-nous votre expérience…',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(
                    context,
                    (
                      stars: _stars,
                      comment: _commentCtrl.text.trim(),
                      tags: Set<String>.from(_tags),
                    ),
                  );
                },
                icon: const Icon(Icons.send_rounded),
                label: Text('Soumettre', style: AppFonts.style(fontWeight: FontWeight.w700, fontSize: 16)),
                style: FilledButton.styleFrom(
                  backgroundColor: FeuTheme.deepBlue,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle get _label => AppFonts.style(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: Colors.grey.shade600,
      );
}
