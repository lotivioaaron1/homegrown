import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';

// ── Sport intro panel data ────────────────────────────────────────
// Drop your photos in at these paths. Until they exist, each panel
// falls back to a themed gradient + icon so nothing breaks.
class _SportPanelData {
  final String assetPath;
  final String eyebrow;
  final String headline;
  final String subtext;
  const _SportPanelData({
    required this.assetPath,
    required this.eyebrow,
    required this.headline,
    required this.subtext,
  });
}

const List<_SportPanelData> _sportPanels = [
  _SportPanelData(
    assetPath: 'assets/images/onboard_basketball.jpg',
    eyebrow:   'BASKETBALL',
    headline:  'Every Shot\nTells a Story',
    subtext:   'Track your stats, get scouted by coaches, and rise through '
        "Legazpi's basketball scene.",
  ),
  _SportPanelData(
    assetPath: 'assets/images/onboard_volleyball.jpg',
    eyebrow:   'VOLLEYBALL',
    headline:  'Rise Above\nThe Net',
    subtext:   'Find games, join local leagues, and build your athletic '
        'profile as a volleyball player.',
  ),
  _SportPanelData(
    assetPath: 'assets/images/onboard_badminton.jpg',
    eyebrow:   'BADMINTON',
    headline:  'Precision.\nSpeed. Grit.',
    subtext:   "Discover courts near you and connect with Legazpi's "
        'badminton community.',
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();

  // Three full-bleed sport intro panels, then the Features page.
  //
  // A "What sport do you play?" page used to follow Features. It saved the
  // answer to SharedPreferences and nothing ever read it, so registration
  // asked for the sport again anyway — and because this runs before the
  // role picker, it asked coaches and organizers a question meant for
  // athletes. The role-specific registration screens own the question now.
  static final int _sportPanelCount = _sportPanels.length; // 3
  static final int _totalPages = _sportPanelCount + 1; // 4

  int _currentPage = 0;

  bool get _onSportPanel => _currentPage < _sportPanelCount;

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  void _onContinue() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _onGetStarted();
    }
  }

  Future<void> _onGetStarted() async {
    final prefs = await SharedPreferences.getInstance();
    // splash_screen.dart reads this to send a returning user who has logged
    // out straight to /login instead of the first-run CTA. It reads the flag
    // but nothing used to write it, so every returning user was treated as
    // brand new.
    await prefs.setBool('onboarding_complete', true);
    Get.offAllNamed('/register');
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Sport panels render full-bleed (no safe-area padding/background),
      // so let the Stack inside each panel handle its own insets.
      backgroundColor: AppTheme.bg,
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _currentPage = i),
            children: [
              for (int i = 0; i < _sportPanelCount; i++)
                _SportPanel(
                  data: _sportPanels[i],
                  isLastSportPanel: i == _sportPanelCount - 1,
                  onAdvance: () => _goToPage(i + 1),
                ),
              const _FeaturesPage(),
            ],
          ),

          // Small progress dots over the sport panels themselves, matching
          // the reference's per-panel indicator. Hidden on the Features
          // page, which is the last page and carries the CTA instead.
          if (_onSportPanel)
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.of(context).padding.bottom + 12,
              child: _SportPanelDots(
                total: _sportPanelCount,
                current: _currentPage,
              ),
            ),

          // The CTA for the Features page. It used to sit under a dot
          // indicator and a Skip link, both of which only made sense while a
          // sport-selection page followed: Features is now the last page, so
          // the indicator would show a single dot and Skip could never
          // render (it was hidden on the last page).
          if (!_onSportPanel)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _onContinue,
                      child: const Text('Get Started'),
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

// ── Full-bleed sport intro panel (NEW) ────────────────────────────
class _SportPanel extends StatelessWidget {
  final _SportPanelData data;
  final bool isLastSportPanel;
  final VoidCallback onAdvance;

  const _SportPanel({
    required this.data,
    required this.isLastSportPanel,
    required this.onAdvance,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          data.assetPath,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1A1200), Color(0xFF0F0F1A)],
              ),
            ),
            child: Center(
              child: Icon(
                Icons.sports_basketball_outlined,
                size: size.width * 0.28,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
          ),
        ),
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.0, 0.45, 1.0],
              colors: [
                Colors.transparent,
                Color(0xCC0A0A12),
                Color(0xF20A0A12),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            size.width * 0.07,
            0,
            size.width * 0.07,
            bottomInset + 52, // leaves room for the dot row below it
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.eyebrow,
                style: TextStyle(
                  color: AppTheme.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                data.headline,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size.width * 0.088,
                  fontWeight: FontWeight.w900,
                  height: 1.12,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                data.subtext,
                style: const TextStyle(
                  color: Color(0xFFC7C7D6),
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 22),
              GestureDetector(
                onTap: onAdvance,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isLastSportPanel ? 'Get Started' : 'Swipe to start',
                        style: const TextStyle(
                          color: Color(0xFF0A0A12),
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isLastSportPanel
                            ? Icons.check_rounded
                            : Icons.arrow_forward_rounded,
                        size: 17,
                        color: const Color(0xFF0A0A12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SportPanelDots extends StatelessWidget {
  final int total;
  final int current;
  const _SportPanelDots({required this.total, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final bool active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 20 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.white.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// Everything below this line is your ORIGINAL code, unchanged.
// ══════════════════════════════════════════════════════════════════

class _FeaturesPage extends StatelessWidget {
  const _FeaturesPage();
  final List<_FeatureItem> _features = const [
    _FeatureItem(
      icon: Iconsax.chart_2,
      title: 'Performance Dashboard',
      description:
          'Track your game stats and see your growth with visual analytics.',
    ),
    _FeatureItem(
      icon: Iconsax.cup,
      title: 'Talent Discovery',
      description:
          'Get ranked by coaches through our Point-Based scoring system.',
    ),
    _FeatureItem(
      icon: Iconsax.location,
      title: 'Game Directory',
      description: 'Find games and venues near you with our Venue Locator.',
    ),
  ];
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'HOMEGROWN',
              style: TextStyle(
                color: AppTheme.accent,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Your Digital\nAthletic Identity',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                height: 1.2,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Track your performance, get discovered by coaches, and find games near you.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.sub,
                fontSize: 14,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 32),
            ..._features.map((f) => _FeatureCard(item: f)),
          ],
        ),
      ),
    );
  }
}

class _FeatureItem {
  final IconData icon;
  final String title;
  final String description;
  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });
}

class _FeatureCard extends StatelessWidget {
  final _FeatureItem item;
  const _FeatureCard({required this.item});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.accent.withValues(alpha: 0.22),
                  AppTheme.accent2.withValues(alpha: 0.10),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppTheme.accent.withValues(alpha: 0.25),
              ),
            ),
            child: Center(
              child: Icon(item.icon, size: 24, color: AppTheme.accent),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: TextStyle(
                    color: AppTheme.sub,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
