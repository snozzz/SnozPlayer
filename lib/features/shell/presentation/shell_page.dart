import 'package:flutter/material.dart';

import '../../../app/theme/app_palette.dart';
import '../../home/presentation/home_page.dart';
import '../../library/presentation/library_page.dart';
import '../../profile/presentation/profile_page.dart';

class ShellPage extends StatefulWidget {
  const ShellPage({super.key});

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  int _currentIndex = 0;

  static const _pages = [HomePage(), LibraryPage(), ProfilePage()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: NavigationBar(
            selectedIndex: _currentIndex,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_rounded),
                selectedIcon: Icon(Icons.home_filled),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.video_library_outlined),
                selectedIcon: Icon(Icons.video_library_rounded),
                label: 'Library',
              ),
              NavigationDestination(
                icon: Icon(Icons.favorite_border_rounded),
                selectedIcon: Icon(
                  Icons.favorite_rounded,
                  color: AppPalette.berry,
                ),
                label: 'Cozy',
              ),
            ],
            onDestinationSelected: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
          ),
        ),
      ),
    );
  }
}
