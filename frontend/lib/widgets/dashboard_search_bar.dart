import 'package:flutter/material.dart';

import '../theme/feu_theme.dart';

/// Barre de recherche avec filtrage en direct (sans bouton « Rechercher »).
class DashboardSearchBar extends StatefulWidget {
  const DashboardSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hintText = 'Filtrer…',
    this.loading = false,
  });

  final TextEditingController controller;
  final VoidCallback onChanged;
  final String hintText;
  final bool loading;

  @override
  State<DashboardSearchBar> createState() => _DashboardSearchBarState();
}

class _DashboardSearchBarState extends State<DashboardSearchBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  void _clear() {
    widget.controller.clear();
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: widget.controller,
              textInputAction: TextInputAction.search,
              onChanged: (_) => widget.onChanged(),
              onSubmitted: (_) => widget.onChanged(),
              decoration: InputDecoration(
                hintText: widget.hintText,
                isDense: true,
                prefixIcon: Icon(Icons.search_rounded, color: FeuTheme.deepBlue.withValues(alpha: 0.85)),
                suffixIcon: widget.controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 20),
                        onPressed: _clear,
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: FeuTheme.ember.withValues(alpha: 0.25)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: FeuTheme.ember.withValues(alpha: 0.18)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: FeuTheme.ember, width: 1.6),
                ),
              ),
            ),
            if (widget.loading)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(minHeight: 2, color: FeuTheme.ember),
              ),
          ],
        ),
      ),
    );
  }
}
