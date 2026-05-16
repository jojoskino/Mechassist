import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../theme/feu_theme.dart';
import 'mechassist_logo.dart';

/// Feuille / écran de signalement de panne (maquette).
class CreateRequestSheet extends StatefulWidget {
  const CreateRequestSheet({
    super.key,
    required this.mechanicName,
    this.pickupLabel,
    this.recentAddresses = const [],
    this.scrollController,
    this.onRefreshLocation,
    this.initialDescription,
    this.showAddressFields = false,
  });

  final String mechanicName;
  final String? pickupLabel;
  final List<String> recentAddresses;
  final ScrollController? scrollController;
  final Future<String?> Function()? onRefreshLocation;
  final String? initialDescription;
  final bool showAddressFields;

  static Future<CreateRequestResult?> show(
    BuildContext context, {
    required String mechanicName,
    String pickupLabel = 'Ma position actuelle',
    List<String> recentAddresses = const [],
    Future<String?> Function()? onRefreshLocation,
    String? initialDescription,
    bool fullScreen = true,
  }) {
    if (fullScreen) {
      return Navigator.push<CreateRequestResult>(
        context,
        MaterialPageRoute(
          builder: (_) => CreateRequestSheet(
            mechanicName: mechanicName,
            pickupLabel: pickupLabel,
            recentAddresses: recentAddresses,
            onRefreshLocation: onRefreshLocation,
            initialDescription: initialDescription,
            showAddressFields: true,
          ),
        ),
      );
    }
    final topInset = MediaQuery.paddingOf(context).top;
    return showModalBottomSheet<CreateRequestResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(top: topInset + 48),
          child: DraggableScrollableSheet(
            expand: true,
            initialChildSize: 0.58,
            minChildSize: 0.35,
            maxChildSize: 0.92,
            snap: true,
            snapSizes: const [0.35, 0.58, 0.75, 0.92],
            snapAnimationDuration: const Duration(milliseconds: 280),
            builder: (_, scrollController) => CreateRequestSheet(
              mechanicName: mechanicName,
              pickupLabel: pickupLabel,
              recentAddresses: recentAddresses,
              scrollController: scrollController,
              onRefreshLocation: onRefreshLocation,
              initialDescription: initialDescription,
              showAddressFields: true,
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
    required this.urgency,
    this.address,
    this.photo,
  });

  final String vehicleType;
  final String description;
  final String urgency;
  final String? address;
  final XFile? photo;

  String get urgencyLabel {
    switch (urgency) {
      case 'critique':
        return 'Critique';
      case 'moyenne':
        return 'Moyenne';
      default:
        return 'Légère';
    }
  }

  String descriptionForApi() {
    final prefix = 'Urgence : $urgencyLabel.';
    final body = description.trim();
    return body.isEmpty ? prefix : '$prefix $body';
  }
}

class _CreateRequestSheetState extends State<CreateRequestSheet> {
  final _descCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  String _vehicleType = 'voiture';
  String _urgency = 'moyenne';
  late String? _pickupLabel;
  bool _refreshingLocation = false;
  XFile? _photo;
  final _picker = ImagePicker();

  static const _maxDesc = 500;

  @override
  void initState() {
    super.initState();
    _pickupLabel = widget.pickupLabel;
    if (widget.initialDescription != null && widget.initialDescription!.isNotEmpty) {
      _descCtrl.text = widget.initialDescription!;
    }
    _descCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  TextStyle get _sectionLabel => GoogleFonts.poppins(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: Colors.grey.shade600,
      );

  Future<void> _refreshPickup() async {
    if (widget.onRefreshLocation == null) return;
    setState(() => _refreshingLocation = true);
    final label = await widget.onRefreshLocation!();
    if (!mounted) return;
    setState(() {
      _refreshingLocation = false;
      if (label != null && label.isNotEmpty) _pickupLabel = label;
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
        urgency: _urgency,
        address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        photo: _photo,
      ),
    );
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final x = await _picker.pickImage(
      source: source,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 85,
    );
    if (x != null) setState(() => _photo = x);
  }

  List<Widget> _formChildren(BuildContext context, {required bool showTopBar}) {
    return [
      if (showTopBar) _topBar(context),
      Text(
        'Signalement de panne',
        style: GoogleFonts.poppins(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: FeuTheme.charcoal,
          height: 1.2,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        'Décrivez votre problème pour recevoir l\'aide d\'un expert certifié.',
        style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade700, height: 1.4),
      ),
      if (widget.mechanicName.isNotEmpty) ...[
        const SizedBox(height: 12),
        _mechanicChip(),
      ],
      const SizedBox(height: 22),
      Text('TYPE DE VÉHICULE', style: _sectionLabel),
      const SizedBox(height: 10),
      _vehicleCards(),
      const SizedBox(height: 22),
      Text('DEGRÉ D\'URGENCE', style: _sectionLabel),
      const SizedBox(height: 10),
      _urgencyRow(),
      const SizedBox(height: 22),
      Text('DESCRIPTION DE LA PANNE', style: _sectionLabel),
      const SizedBox(height: 10),
      _descriptionField(),
      if (widget.showAddressFields && widget.onRefreshLocation != null) ...[
        const SizedBox(height: 18),
        Text('LOCALISATION', style: _sectionLabel),
        const SizedBox(height: 8),
        _locationRow(),
        if (widget.recentAddresses.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.recentAddresses.map((a) {
              return ActionChip(
                label: Text(a, style: GoogleFonts.poppins(fontSize: 12)),
                onPressed: () {
                  _addressCtrl.text = a;
                  setState(() {});
                },
              );
            }).toList(),
          ),
        ],
      ],
      const SizedBox(height: 22),
      Text('PHOTOS (OPTIONNEL)', style: _sectionLabel),
      const SizedBox(height: 10),
      _photoRow(),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: _submit,
        style: FilledButton.styleFrom(
          backgroundColor: FeuTheme.deepBlue,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text('Envoyer la demande', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
      ),
      SizedBox(height: MediaQuery.paddingOf(context).bottom + 8),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isModal = widget.scrollController != null;
    final children = _formChildren(context, showTopBar: !isModal);

    Widget scrollable(ScrollController? controller, double minHeight) {
      return ListView(
        controller: controller,
        physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      );
    }

    if (isModal) {
      return Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              children: [
                const SizedBox(height: 10),
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
                Expanded(
                  child: scrollable(widget.scrollController, math.max(400, constraints.maxHeight - 24)),
                ),
              ],
            );
          },
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(child: scrollable(null, 0)),
    );
  }

  Widget _topBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: FeuTheme.deepBlue, size: 20),
          ),
          const MechAssistLogoChip(size: 32),
          const SizedBox(width: 8),
          Text(
            'MechAssist',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 18, color: FeuTheme.deepBlue),
          ),
        ],
      ),
    );
  }

  Widget _mechanicChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: FeuTheme.pageGrey,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FeuTheme.deepBlue.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          const Icon(Icons.build_circle_outlined, color: FeuTheme.deepBlue, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Pour ${widget.mechanicName}',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: FeuTheme.deepBlue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _vehicleCards() {
    return Row(
      children: [
        Expanded(child: _vehicleCard('voiture', 'Voiture', Icons.directions_car_filled_rounded)),
        const SizedBox(width: 12),
        Expanded(child: _vehicleCard('moto', 'Moto', Icons.two_wheeler_rounded)),
      ],
    );
  }

  Widget _vehicleCard(String id, String label, IconData icon) {
    final selected = _vehicleType == id;
    return InkWell(
      onTap: () => setState(() => _vehicleType = id),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? FeuTheme.deepBlue : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: FeuTheme.deepBlue.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Icon(icon, size: 36, color: selected ? FeuTheme.deepBlue : Colors.grey.shade500),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: selected ? FeuTheme.deepBlue : FeuTheme.charcoal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _urgencyRow() {
    return Row(
      children: [
        Expanded(child: _urgencyPill('legere', 'Légère', Icons.schedule_rounded, FeuTheme.urgencyLightBg, FeuTheme.urgencyLightFg)),
        const SizedBox(width: 8),
        Expanded(child: _urgencyPill('moyenne', 'Moyenne', Icons.warning_amber_rounded, FeuTheme.urgencyMediumBg, FeuTheme.urgencyMediumFg)),
        const SizedBox(width: 8),
        Expanded(child: _urgencyPill('critique', 'Critique', Icons.bolt_rounded, FeuTheme.urgencyCriticalBg, FeuTheme.urgencyCriticalFg)),
      ],
    );
  }

  Widget _urgencyPill(String id, String label, IconData icon, Color bg, Color fg) {
    final selected = _urgency == id;
    return InkWell(
      onTap: () => setState(() => _urgency = id),
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: selected ? fg : Colors.transparent, width: 2),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: fg),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w700, color: fg),
            ),
          ],
        ),
      ),
    );
  }

  Widget _descriptionField() {
    final len = _descCtrl.text.length;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _descCtrl,
            maxLines: 5,
            maxLength: _maxDesc,
            buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
            style: GoogleFonts.poppins(fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Ex: Ma voiture ne démarre plus, il y a un bruit métallique…',
              hintStyle: GoogleFonts.poppins(color: Colors.grey.shade500, fontSize: 14),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12, bottom: 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                '$len/$_maxDesc',
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade500),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _locationRow() {
    return Row(
      children: [
        Expanded(
          child: Text(
            _pickupLabel ?? 'Ma position',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
        if (_refreshingLocation)
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2, color: FeuTheme.deepBlue),
          )
        else
          IconButton(
            onPressed: _refreshPickup,
            icon: const Icon(Icons.my_location_rounded, color: FeuTheme.deepBlue),
          ),
      ],
    );
  }

  Widget _photoRow() {
    return Row(
      children: [
        _photoSlot(
          dashed: true,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_a_photo_outlined, color: FeuTheme.deepBlue.withValues(alpha: 0.7)),
              const SizedBox(height: 4),
              Text('Ajouter', style: GoogleFonts.poppins(fontSize: 12, color: FeuTheme.deepBlue)),
            ],
          ),
          onTap: () => _showPhotoSource(),
        ),
        if (_photo != null) ...[
          const SizedBox(width: 10),
          _photoSlot(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: FutureBuilder<Uint8List>(
                    future: _photo!.readAsBytes(),
                    builder: (context, snap) {
                      if (!snap.hasData) {
                        return const ColoredBox(
                          color: Color(0xFFE8ECEF),
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        );
                      }
                      return Image.memory(
                        snap.data!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      );
                    },
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () => setState(() => _photo = null),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  void _showPhotoSource() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text('Galerie', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                _pickPhoto(ImageSource.gallery);
              },
            ),
            if (!kIsWeb)
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: Text('Appareil photo', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickPhoto(ImageSource.camera);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _photoSlot({required Widget child, bool dashed = false, VoidCallback? onTap}) {
    return Expanded(
      child: AspectRatio(
        aspectRatio: 1,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: dashed
                    ? Border.all(color: Colors.grey.shade400, width: 1.5, strokeAlign: BorderSide.strokeAlignInside)
                    : null,
                color: dashed ? null : const Color(0xFFF0F2F5),
              ),
              child: dashed
                  ? CustomPaint(
                      painter: _DashedBorderPainter(),
                      child: child,
                    )
                  : ClipRRect(borderRadius: BorderRadius.circular(14), child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(14));
    final paint = Paint()
      ..color = Colors.grey.shade400
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    const dash = 6.0;
    final path = Path()..addRRect(r);
    for (final metric in path.computeMetrics()) {
      var dist = 0.0;
      while (dist < metric.length) {
        final len = (dist + dash < metric.length) ? dash : metric.length - dist;
        canvas.drawPath(metric.extractPath(dist, dist + len), paint);
        dist += dash * 2;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
