import 'package:flutter/material.dart';

import '../data/IntroPage.dart';

class IntroCarouselDialog extends StatefulWidget {
  const IntroCarouselDialog({super.key});

  @override
  State<IntroCarouselDialog> createState() => IntroCarouselDialogState();
}

class IntroCarouselDialogState extends State<IntroCarouselDialog> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<IntroPage> pages = [
    IntroPage(
      imageAsset: Icons.photo_size_select_small,
      title: 'Welcome to Petit',
      description: 'This app makes your images smaller in size so they take up less space and send faster — without losing quality.',
    ),
    IntroPage(
      imageAsset: Icons.image,
      title: 'Supports Many Formats',
      description: 'It works with different types of images like JPG, PNG, HEIF, and HEIC.',
    ),
    IntroPage(
      imageAsset: Icons.compress,
      title: 'Simple to Use',
      description: 'Just choose your pictures, pick the quality you want, tap “Compress,” and your smaller images will be saved automatically.',
    ),
  ];

  void _nextPage() {
    if (_currentPage < pages.length - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 250,
              width: 300,
              child: PageView.builder(
                controller: _pageController,
                itemCount: pages.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) => pages[index],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                pages.length,
                    (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 14,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.circular(8),
                    color: _currentPage == index
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.primaryContainer,
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _nextPage,
                child: Text(_currentPage == pages.length - 1 ? "GOT IT" : "NEXT"),
              ),
            )
          ],
        ),
      ),
    );
  }
}
