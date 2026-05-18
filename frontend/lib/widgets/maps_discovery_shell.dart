import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../theme/app_fonts.dart';
import '../theme/feu_theme.dart';

/// Écran type Google Maps : carte plein écran, barre de recherche, puces, FAB, bottom sheet.
class MapsDiscoveryShell extends StatefulWidget {
  const MapsDiscoveryShell({
    super.key,
    required this.map,
    required this.sheetTitle,
    required this.buildSheetBody,
    this.searchController,
    this.searchHint = 'Rechercher…',
    this.onSearch,
    this.filterChips = const [],
    this.onFilterTap,
    this.filtersActive = false,
    this.sheetSubtitle,
    this.subtitleAccent = false,
    this.onRecenter,
    this.topBanner,
    this.onSheetRefresh,
    this.initialSheetFraction = 0.38,
    this.minSheetFraction = 0.22,
    this.maxSheetFraction = 0.88,
    this.primaryFabIcon = Icons.search_rounded,
    this.onPrimaryFab,
    this.loading = false,
    this.sheetHeaderExtra,
    this.searchHintGps = false,
    this.onMenuTap,
    this.bottomInset = 72,
  });

  final Widget map;
  final String sheetTitle;
  final String? sheetSubtitle;
  final List<Widget> Function() buildSheetBody;
  final TextEditingController? searchController;
  final String searchHint;
  final VoidCallback? onSearch;
  final List<Widget> filterChips;
  final VoidCallback? onFilterTap;
  final bool filtersActive;
  final VoidCallback? onRecenter;
  final Widget? topBanner;
  final Future<void> Function()? onSheetRefresh;
  final bool subtitleAccent;
  final double initialSheetFraction;
  final double minSheetFraction;
  final double maxSheetFraction;
  final IconData primaryFabIcon;
  final VoidCallback? onPrimaryFab;
  final bool loading;
  final Widget? sheetHeaderExtra;
  final bool searchHintGps;
  final VoidCallback? onMenuTap;
  /// Espace sous le contenu (barre de navigation basse).
  final double bottomInset;

  @override
  State<MapsDiscoveryShell> createState() => _MapsDiscoveryShellState();
}

class _MapsDiscoveryShellState extends State<MapsDiscoveryShell> {
  final DraggableScrollableController _sheetController = DraggableScrollableController();
  double _sheetFraction = 0.38;

  List<double> get _snapSizes {
    final mid = (widget.initialSheetFraction + widget.maxSheetFraction) / 2;
    return [
      widget.minSheetFraction,
      widget.initialSheetFraction,
      mid,
      widget.maxSheetFraction,
    ];
  }

  @override
  void initState() {
    super.initState();
    _sheetFraction = widget.initialSheetFraction;
    _sheetController.addListener(_onSheetMoved);
  }

  @override
  void didUpdateWidget(MapsDiscoveryShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSheetFraction != widget.initialSheetFraction &&
        _sheetController.isAttached) {
      _animateSheetTo(widget.initialSheetFraction);
    }
  }

  @override
  void dispose() {
    _sheetController.removeListener(_onSheetMoved);
    _sheetController.dispose();
    super.dispose();
  }

  void _onSheetMoved() {
    if (!_sheetController.isAttached) return;
    final next = _sheetController.size;
    if ((next - _sheetFraction).abs() > 0.008) {
      setState(() => _sheetFraction = next);
    }
  }

  Future<void> _animateSheetTo(double size) async {
    if (!_sheetController.isAttached) return;
    await _sheetController.animateTo(
      size.clamp(widget.minSheetFraction, widget.maxSheetFraction),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  /// Passe au palier suivant (comme un bottom sheet Google Maps).
  Future<void> _cycleSheetUp() async {
    if (!_sheetController.isAttached) return;
    final current = _sheetController.size;
    final snaps = _snapSizes;
    for (final target in snaps) {
      if (target > current + 0.04) {
        await _animateSheetTo(target);
        return;
      }
    }
    await _animateSheetTo(widget.maxSheetFraction);
  }

  void _onHeaderDragUpdate(DragUpdateDetails details) {
    if (!_sheetController.isAttached) return;
    final h = MediaQuery.sizeOf(context).height;
    if (h <= 0) return;
    final next = _sheetController.size - details.delta.dy / h;
    _sheetController.jumpTo(
      next.clamp(widget.minSheetFraction, widget.maxSheetFraction),
    );
  }

  void _snapToNearest() {
    if (!_sheetController.isAttached) return;
    final current = _sheetController.size;
    var best = _snapSizes.first;
    var bestDist = (best - current).abs();
    for (final s in _snapSizes) {
      final d = (s - current).abs();
      if (d < bestDist) {
        bestDist = d;
        best = s;
      }
    }
    _animateSheetTo(best);
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    final sheetBottom = MediaQuery.sizeOf(context).height * _sheetFraction + 72;

    return Stack(
      children: [
        // PERF: RepaintBoundary — la carte ne repaint pas avec le sheet.
        Positioned.fill(child: RepaintBoundary(child: widget.map)),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: topPad + 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (widget.onMenuTap != null)
                      IconButton(
                        onPressed: widget.onMenuTap,
                        tooltip: 'Menu',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                        icon: const Icon(Icons.menu_rounded, color: FeuTheme.deepBlue, size: 26),
                      ),
                    if (widget.onMenuTap != null) const SizedBox(width: 6),
                    Expanded(
                      child: _MapsSearchBar(
                        controller: widget.searchController,
                        hint: widget.searchHint,
                        onSubmitted: widget.onSearch,
                        onChanged: widget.onSearch,
                        showGpsIcon: widget.searchHintGps,
                        onFilterTap: widget.onFilterTap,
                        filtersActive: widget.filtersActive,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.filterChips.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      itemCount: widget.filterChips.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => widget.filterChips[i],
                    ),
                  ),
                ),
              if (widget.topBanner != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
                  child: widget.topBanner!,
                ),
            ],
          ),
        ),
        Positioned(
          right: 14,
          bottom: sheetBottom,
          child: Column(
            children: [
              if (widget.onRecenter != null)
                _MapFab(
                  icon: Icons.my_location_rounded,
                  tooltip: 'Ma position',
                  onPressed: widget.onRecenter!,
                ),
              const SizedBox(height: 10),
              if (widget.onPrimaryFab != null)
                _MapFab(
                  icon: widget.primaryFabIcon,
                  tooltip: 'Actualiser',
                  filled: true,
                  onPressed: widget.onPrimaryFab!,
                ),
            ],
          ),
        ),
        DraggableScrollableSheet(
          controller: _sheetController,
          expand: true,
          initialChildSize: widget.initialSheetFraction,
          minChildSize: widget.minSheetFraction,
          maxChildSize: widget.maxSheetFraction,
          snap: true,
          snapSizes: _snapSizes,
          snapAnimationDuration: const Duration(milliseconds: 280),
          builder: (context, scrollController) {
            final body = widget.buildSheetBody();
            return Material(
              elevation: 20,
              shadowColor: FeuTheme.charcoal.withValues(alpha: 0.22),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              color: Colors.white,
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _SheetDragHeader(
                    onDragTap: _cycleSheetUp,
                    onVerticalDragUpdate: _onHeaderDragUpdate,
                    onVerticalDragEnd: (_) => _snapToNearest(),
                    title: widget.sheetTitle,
                    subtitle: widget.sheetSubtitle,
                    subtitleAccent: widget.subtitleAccent,
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: widget.onSheetRefresh ?? () async {},
                      color: FeuTheme.deepBlue,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return ListView(
                            controller: scrollController,
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: ClampingScrollPhysics(),
                            ),
                            padding: EdgeInsets.fromLTRB(12, 4, 12, widget.bottomInset),
                            children: [
                              if (widget.sheetHeaderExtra != null) ...[
                                widget.sheetHeaderExtra!,
                                const SizedBox(height: 8),
                              ],
                              ...body,
                              SizedBox(height: math.max(48, constraints.maxHeight - 48)),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Poignée + titre : zone tactile pour tirer le panneau vers le haut.
class _SheetDragHeader extends StatelessWidget {
  const _SheetDragHeader({
    required this.onDragTap,
    required this.onVerticalDragUpdate,
    required this.onVerticalDragEnd,
    required this.title,
    this.subtitle,
    this.subtitleAccent = false,
  });

  final VoidCallback onDragTap;
  final GestureDragUpdateCallback onVerticalDragUpdate;
  final GestureDragEndCallback onVerticalDragEnd;
  final String title;
  final String? subtitle;
  final bool subtitleAccent;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onDragTap,
      onVerticalDragUpdate: onVerticalDragUpdate,
      onVerticalDragEnd: onVerticalDragEnd,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: FeuTheme.charcoal.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 16, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppFonts.style(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: FeuTheme.charcoal,
                          letterSpacing: -0.3,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              if (subtitleAccent) ...[
                                Icon(Icons.circle, size: 8, color: Colors.green.shade600),
                                const SizedBox(width: 6),
                              ],
                              Expanded(
                                child: Text(
                                  subtitle!,
                                  style: AppFonts.style(
                                    fontSize: 13.5,
                                    fontWeight: subtitleAccent ? FontWeight.w600 : FontWeight.w400,
                                    color: subtitleAccent
                                        ? const Color(0xFF2E7D32)
                                        : Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Icon(Icons.keyboard_arrow_up_rounded, color: FeuTheme.deepBlue.withValues(alpha: 0.7), size: 28),
                    Text(
                      'Tirer',
                      style: AppFonts.style(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1, color: FeuTheme.charcoal.withValues(alpha: 0.08)),
        ],
      ),
    );
  }
}

class _MapsSearchBar extends StatelessWidget {
  const _MapsSearchBar({
    this.controller,
    required this.hint,
    this.onSubmitted,
    this.onChanged,
    this.showGpsIcon = false,
    this.onFilterTap,
    this.filtersActive = false,
  });

  final TextEditingController? controller;
  final String hint;
  final VoidCallback? onSubmitted;
  final VoidCallback? onChanged;
  final bool showGpsIcon;
  final VoidCallback? onFilterTap;
  final bool filtersActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FeuTheme.charcoal.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: FeuTheme.charcoal.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  textInputAction: TextInputAction.search,
                  onChanged: onChanged == null ? null : (_) => onChanged!(),
                  onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
                  style: AppFonts.style(fontSize: 15, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: AppFonts.style(color: Colors.grey.shade500, fontSize: 15),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: FeuTheme.deepBlue.withValues(alpha: 0.65),
                      size: 22,
                    ),
                    suffixIcon: showGpsIcon
                        ? Icon(Icons.near_me_rounded, color: FeuTheme.deepBlue.withValues(alpha: 0.5), size: 20)
                        : null,
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              if (onFilterTap != null)
                IconButton(
                  onPressed: onFilterTap,
                  tooltip: 'Filtres',
                  icon: Icon(
                    Icons.tune_rounded,
                    color: filtersActive ? FeuTheme.ember : FeuTheme.deepBlue.withValues(alpha: 0.7),
                    size: 22,
                  ),
                ),
              const SizedBox(width: 4),
            ],
          ),
    );
  }
}

class _MapFab extends StatelessWidget {
  const _MapFab({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.filled = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      shadowColor: FeuTheme.charcoal.withValues(alpha: 0.2),
      color: filled ? FeuTheme.deepBlue : Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(icon, color: filled ? Colors.white : FeuTheme.deepBlue, size: 24),
          ),
        ),
      ),
    );
  }
}

/// Puce filtre horizontale (style Google Maps).
class MapsFilterChip extends StatelessWidget {
  const MapsFilterChip({
    super.key,
    required this.label,
    this.selected = false,
    this.icon,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? FeuTheme.deepBlue.withValues(alpha: 0.12) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? FeuTheme.deepBlue : FeuTheme.charcoal.withValues(alpha: 0.12),
            ),
            boxShadow: [
              BoxShadow(
                color: FeuTheme.charcoal.withValues(alpha: 0.08),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: selected ? FeuTheme.deepBlue : FeuTheme.charcoal),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: AppFonts.style(
                  fontSize: 13.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? FeuTheme.deepBlue : FeuTheme.charcoal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
