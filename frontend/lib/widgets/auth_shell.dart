import 'package:flutter/material.dart';

import 'mechassist_logo.dart';

/// En-tête bleu + logo + carte blanche arrondie (maquettes MechAssist).
class AuthShell extends StatelessWidget {
  const AuthShell({
    required this.title,
    required this.child,
    super.key,
    this.subtitle,
    this.showBack = false,
    this.showLogo = true,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final bool showBack;
  final bool showLogo;

  static const Color topBlue = Color(0xFF0F4C75);
  static const Color titleColor = Color(0xFF10324A);

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    const headerMinHeight = 248.0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: (headerMinHeight + topInset).clamp(248.0, 320.0),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Positioned.fill(child: ColoredBox(color: topBlue)),
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 48,
                          child: showBack
                              ? Align(
                                  alignment: Alignment.centerLeft,
                                  child: Material(
                                    color: Colors.white,
                                    shape: const CircleBorder(),
                                    elevation: 2,
                                    shadowColor: Colors.black26,
                                    child: InkWell(
                                      customBorder: const CircleBorder(),
                                      onTap: () => Navigator.maybePop(context),
                                      child: const SizedBox(
                                        width: 44,
                                        height: 44,
                                        child: Icon(
                                          Icons.chevron_left_rounded,
                                          color: topBlue,
                                          size: 30,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                        if (showLogo) ...[
                          const Spacer(flex: 2),
                          Center(
                            child: MechAssistLogoBadge(
                              size: MediaQuery.sizeOf(context).shortestSide < 360 ? 92 : 108,
                              elevation: 4,
                            ),
                          ),
                          const Spacer(flex: 3),
                        ] else ...[
                          const Spacer(),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, -28),
              child: Material(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                elevation: 12,
                shadowColor: Colors.black12,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 36),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                            height: 1.15,
                            color: titleColor,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            subtitle!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.35,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                        const SizedBox(height: 28),
                        child,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
