// lib/widgets/no_internet_overlay.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/connectivity_service.dart';
import '../theme/app_theme.dart';

class NoInternetOverlay extends StatelessWidget {
  final Widget child;

  const NoInternetOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isConnected =
          ConnectivityService.to.isConnected.value;

      return Stack(children: [
        // ── Main app content ─────────────────
        child,

        // ── No internet overlay ───────────────
        if (!isConnected)
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: Container(
                color: AppTheme.bg,
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Animated icon
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 400),
                        curve:    Curves.elasticOut,
                        builder:  (_, v, child) =>
                            Transform.scale(scale: v, child: child),
                        child: Container(
                          width: 110, height: 110,
                          decoration: BoxDecoration(
                            color: AppTheme.card,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppTheme.border, width: 2),
                          ),
                          child: const Center(
                            child: Text('📡',
                                style: TextStyle(fontSize: 48))),
                        ),
                      ),

                      const SizedBox(height: 32),

                      Text('No Internet Connection',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color:         AppTheme.textPrimary,
                          fontSize:      22,
                          fontWeight:    FontWeight.w900,
                          letterSpacing: -0.3)),

                      const SizedBox(height: 10),

                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 40),
                        child: Text(
                          'Homegrown requires an internet connection '
                          'to load events, stats and rankings.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color:  AppTheme.sub,
                            fontSize: 14,
                            height: 1.6)),
                      ),

                      const SizedBox(height: 32),

                      // Pulsing waiting indicator
                      _PulsingDots(),

                      const SizedBox(height: 20),

                      Text('Waiting for connection...',
                        style: TextStyle(
                          color:    AppTheme.muted,
                          fontSize: 13)),

                      const SizedBox(height: 40),

                      // Tips
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: AppTheme.border)),
                          child: const Column(children: [
                            _TipRow(icon: Icons.wifi_rounded,
                                text: 'Check your Wi-Fi connection'),
                            SizedBox(height: 10),
                            _TipRow(
                                icon: Icons.signal_cellular_alt_rounded,
                                text: 'Check your mobile data'),
                            SizedBox(height: 10),
                            _TipRow(icon: Icons.airplane_ticket_rounded,
                                text:
                                    'Make sure Airplane mode is off'),
                          ]),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Retry button
                      GestureDetector(
                        onTap: () =>
                            ConnectivityService.to.retryConnection(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppTheme.accentSurface,
                            borderRadius: BorderRadius.circular(14),
                            border:
                                Border.all(color: AppTheme.accent)),
                          child: Row(mainAxisSize: MainAxisSize.min,
                            children: [
                            Icon(Icons.refresh_rounded,
                                color: AppTheme.accentText, size: 20),
                            const SizedBox(width: 8),
                            Text('Try Again', style: TextStyle(
                              color:      AppTheme.accentText,
                              fontSize:   14,
                              fontWeight: FontWeight.w700)),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ]);
    });
  }
}

// ─────────────────────────────────────────────
// Pulsing dots animation
// ─────────────────────────────────────────────

class _PulsingDots extends StatefulWidget {
  @override
  State<_PulsingDots> createState() => _PulsingDotsState();
}

class _PulsingDotsState extends State<_PulsingDots>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>>   _anims;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) =>
        AnimationController(
          vsync:    this,
          duration: const Duration(milliseconds: 600))
          ..repeat(reverse: true));

    _anims = List.generate(3, (i) =>
        CurvedAnimation(
            parent: _controllers[i], curve: Curves.easeInOut));

    // Stagger the dots
    Future.delayed(const Duration(milliseconds: 150),
        () => _controllers[1].forward());
    Future.delayed(const Duration(milliseconds: 300),
        () => _controllers[2].forward());
  }

  @override
  void dispose() {
    for (final c in _controllers) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) =>
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: AnimatedBuilder(
            animation: _anims[i],
            builder: (_, __) => Container(
              width:  10,
              height: 10,
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(
                    alpha: 0.3 + (_anims[i].value * 0.7)),
                shape: BoxShape.circle)),
          ),
        )));
  }
}

// ─────────────────────────────────────────────
// Tip row widget
// ─────────────────────────────────────────────

class _TipRow extends StatelessWidget {
  final IconData icon;
  final String   text;

  const _TipRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
          color:        AppTheme.cardNested,
          borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: AppTheme.muted, size: 16)),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: TextStyle(
        color:    AppTheme.sub,
        fontSize: 12))),
    ]);
  }
}