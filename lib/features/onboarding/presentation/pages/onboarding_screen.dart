import 'package:flutter/material.dart';
import 'package:petit/core/utils/platform_utils.dart';

/// The welcome screens: what Petit does, how to use it, and that files stay on
/// the device. Shown once on first launch, and again from Settings.
///
/// [onFinished] runs when the user reaches the end or skips.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _pageAnimation = Duration(milliseconds: 300);

  List<_WelcomePage> get _pages => [
        const _WelcomePage(
          icon: Icons.compress,
          title: 'Welcome to Petit',
          body: 'Make photos and videos much smaller, so they are quicker to '
              'send and take up less space, without losing what matters.',
        ),
        _WelcomePage(
          icon: Icons.tune,
          title: 'Pick, preview, compress',
          body: PlatformInfo.isDesktop
              ? 'Add files, or drop them anywhere in the window. Petit shows '
                  'how big each image will be before you compress, and '
                  'warns you about settings that will not help.'
              : 'Add files, or share them to Petit from your gallery. It '
                  'shows how big each image will be before you compress, and '
                  'warns you about settings that will not help.',
        ),
        const _WelcomePage(
          icon: Icons.lock_outline,
          title: 'Your files stay yours',
          body: 'Everything is compressed on this device and nothing is '
              'uploaded. Your originals are never changed. Choose your '
              'favourite settings once, in the Settings tab.',
        ),
      ];

  bool get _isLast => _page == _pages.length - 1;

  void _next() {
    if (_isLast) {
      widget.onFinished();
    } else {
      _controller.nextPage(duration: _pageAnimation, curve: Curves.easeOut);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = _pages;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                    // Keeps its space on the last page so nothing jumps.
                    child: Opacity(
                      opacity: _isLast ? 0 : 1,
                      child: TextButton(
                        onPressed: _isLast ? null : widget.onFinished,
                        child: const Text('Skip'),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _controller,
                    onPageChanged: (index) => setState(() => _page = index),
                    children: pages,
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < pages.length; i++)
                      AnimatedContainer(
                        duration: _pageAnimation,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: i == _page ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _page
                              ? scheme.primary
                              : scheme.outlineVariant,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _next,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(_isLast ? 'Get started' : 'Next'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 64, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(height: 40),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Text(
            body,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
