import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/feu_theme.dart';

/// Feuille de demande style application de mobilité (carte + panneau glissable).
class CreateRequestSheet extends StatefulWidget {
  const CreateRequestSheet({
    super.key,
    required this.mechanicName,
    required this.pickupLabel,
    this.recentAddresses = const [],
    this.scrollController,
    this.onRefreshLocation,
  });

  final String mechanicName;
  final String pickupLabel;
  final List<String> recentAddresses;
  final ScrollController? scrollController;
  final Future<String?> Function()? onRefreshLocation;

  static Future<CreateRequestResult?> show(
    BuildContext context, {
    required String mechanicName,
    String pickupLabel = 'Ma position actuelle',
    List<String> recentAddresses = const [],
    Future<String?> Function()? onRefreshLocation,
  }) {
    final topInset = MediaQuery.paddingOf(context).top;
    return showModalBottomSheet<CreateRequestResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(top: topInset + 48),
          child: DraggableScrollableSheet(
            initialChildSize: 0.58,
            minChildSize: 0.42,
            maxChildSize: 0.92,
            expand: false,
            builder: (_, scrollController) => CreateRequestSheet(
              mechanicName: mechanicName,
              pickupLabel: pickupLabel,
              recentAddresses: recentAddresses,
              scrollController: scrollController,
              onRefreshLocation: onRefreshLocation,
            ),
          ),
        );
      },
    );
  }

  @override
  State<CreateRequestSheet> createState() => _CreateRequestSheetState();
}

class CreateRequestResult {
  CreateRequestResult({
    required this.vehicleType,
    required this.description,
    this.address,
    this.photo,
  });

  final String vehicleType;
  final String description;
  final String? address;
  final XFile? photo;
}

class _CreateRequestSheetState extends State<CreateRequestSheet> {
  final _descCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  String _vehicleType = 'voiture';
  late String _pickupLabel;
  bool _refreshingLocation = false;
  XFile? _photo;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _pickupLabel = widget.pickupLabel;
  }

  static const _vehicleOptions = <(String, String)>[
    ('voiture', 'Voiture'),
    ('moto', 'Moto'),
    ('autre', 'Autre'),
  ];

  TextStyle get _titleStyle => GoogleFonts.poppins(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: FeuTheme.charcoal,
      );

  TextStyle get _hintStyle => GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600);

  @override
  void dispose() {
    _descCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  void _applyRecent(String addr) {
    _addressCtrl.text = addr;
    setState(() {});
  }

  Future<void> _refreshPickup() async {
    if (widget.onRefreshLocation == null) return;
    setState(() => _refreshingLocation = true);
    final label = await widget.onRefreshLocation!();
    if (!mounted) return;
    setState(() {
      _refreshingLocation = false;
      if (label != null && label.isNotEmpty) {
        _pickupLabel = label;
      }
    });
  }

  void _submit() {
    final desc = _descCtrl.text.trim();
    if (desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Décris la panne pour envoyer la demande.', style: GoogleFonts.poppins())),
      );
      return;
    }
    Navigator.pop(
      context,
      CreateRequestResult(
        vehicleType: _vehicleType,
        description: desc,
        address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        photo: _photo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scroll = widget.scrollController;
    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: FeuTheme.charcoal.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
              children: [
                _vehicleSegment(),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        'Précise ton intervention',
                        style: _titleStyle.copyWith(fontSize: 18),
                      ),
                    ),
                    _orderForChip(),
                  ],
                ),
                const SizedBox(height: 14),
                _addressCard(),
                if (widget.recentAddresses.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(
                    'Repères récents',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.recentAddresses.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final label = widget.recentAddresses[i];
                        return ActionChip(
                          label: Text(
                            label,
                            style: GoogleFonts.poppins(fontSize: 12.5),
                            overflow: TextOverflow.ellipsis,
                          ),
                          avatar: Icon(Icons.history_rounded, size: 16, color: FeuTheme.deepBlue.withValues(alpha: 0.7)),
                          backgroundColor: const Color(0xFFF3F5F8),
                          side: BorderSide(color: FeuTheme.charcoal.withValues(alpha: 0.08)),
                          onPressed: () => _applyRecent(label),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  'Photo (optionnel)',
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _photoChip(Icons.photo_library_outlined, 'Galerie', ImageSource.gallery),
                    if (!kIsWeb)
                      _photoChip(Icons.photo_camera_outlined, 'Appareil', ImageSource.camera),
                    if (_photo != null)
                      TextButton(
                        onPressed: () => setState(() => _photo = null),
                        child: Text('Retirer', style: GoogleFonts.poppins(color: FeuTheme.ember)),
                      ),
                  ],
                ),
                if (_photo != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _photo!.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade700),
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
              child: FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: FeuTheme.deepBlue,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                ),
                child: Text(
                  'Envoyer la demande',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _vehicleSegment() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2F5),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          for (final opt in _vehicleOptions)
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _vehicleType = opt.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: _vehicleType == opt.$1 ? FeuTheme.charcoal : Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    opt.$2,
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: _vehicleType == opt.$1 ? Colors.white : FeuTheme.charcoal.withValues(alpha: 0.75),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _orderForChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5F8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FeuTheme.charcoal.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: FeuTheme.ember.withValues(alpha: 0.2),
            child: const Icon(Icons.build_circle_rounded, size: 16, color: FeuTheme.deepBlue),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              widget.mechanicName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: FeuTheme.deepBlue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _addressCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: FeuTheme.charcoal.withValues(alpha: 0.07)),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 28,
              child: Column(
                children: [
                  Icon(Icons.trip_origin_rounded, size: 20, color: Colors.green.shade600),
                  Expanded(
                    child: CustomPaint(
                      painter: _DashedLinePainter(color: Colors.grey.shade400),
                      size: const Size(2, double.infinity),
                    ),
                  ),
                  Icon(Icons.place_rounded, size: 22, color: FeuTheme.ember),
                  const SizedBox(height: 36),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _pickupLabel,
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: FeuTheme.charcoal,
                          ),
                        ),
                      ),
                      if (_refreshingLocation)
                        const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: FeuTheme.ember),
                        )
                      else
                        IconButton(
                          onPressed: widget.onRefreshLocation == null ? null : _refreshPickup,
                          icon: const Icon(Icons.my_location_rounded),
                          color: FeuTheme.deepBlue,
                          tooltip: 'Actualiser ma position',
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _addressCtrl,
                    style: GoogleFonts.poppins(fontSize: 15),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Repère ou adresse (optionnel)',
                      hintStyle: _hintStyle,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      suffixIcon: Icon(Icons.add_circle_outline_rounded, color: FeuTheme.deepBlue.withValues(alpha: 0.55)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descCtrl,
                    minLines: 2,
                    maxLines: 4,
                    style: GoogleFonts.poppins(fontSize: 15),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Décris la panne',
                      hintStyle: _hintStyle,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoChip(IconData icon, String label, ImageSource source) {
    return OutlinedButton.icon(
      onPressed: () async {
        final x = await _picker.pickImage(
          source: source,
          maxWidth: 2048,
          maxHeight: 2048,
          imageQuality: 85,
        );
        if (x != null) setState(() => _photo = x);
      },
      icon: Icon(icon, size: 18),
      label: Text(label, style: GoogleFonts.poppins(fontSize: 13)),
      style: OutlinedButton.styleFrom(
        foregroundColor: FeuTheme.deepBlue,
        side: BorderSide(color: FeuTheme.deepBlue.withValues(alpha: 0.3)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  _DashedLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    const dash = 4.0;
    const gap = 4.0;
    var y = 0.0;
    while (y < size.height) {
      canvas.drawLine(Offset(size.width / 2, y), Offset(size.width / 2, y + dash), paint);
      y += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
