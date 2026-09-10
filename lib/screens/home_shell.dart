import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/hasanat_provider.dart';
import '../widgets/download_banner.dart';
import 'adhkar/adhkar_screen.dart';
import 'hasanat/hasanat_screen.dart';
import 'more/more_screen.dart';
import 'quran/quran_screen.dart';
import 'recitation/recitation_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;

  /// Selected tab index, shared with the tab screens so each one can run its
  /// first-visit coach-mark tutorial only when it is actually on screen.
  final ValueNotifier<int> _selectedTab = ValueNotifier<int>(0);

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      QuranScreen(selectedTab: _selectedTab, tabIndex: 0),
      RecitationScreen(selectedTab: _selectedTab, tabIndex: 1),
      HasanatScreen(selectedTab: _selectedTab, tabIndex: 2),
      AdhkarScreen(selectedTab: _selectedTab, tabIndex: 3),
      MoreScreen(selectedTab: _selectedTab, tabIndex: 4),
    ];
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _selectedTab.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshNewDay();
  }

  /// Re-resolves "today" so the counters roll over at midnight even if the
  /// app stayed open across midnight.
  void _refreshNewDay() {
    final hasanat = context.read<HasanatProvider>();
    if (hasanat.refreshClock()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✦ A new day — hasanat counts have reset.'),
        ),
      );
    }
  }

  void _selectTab(int i) {
    setState(() => _index = i);
    _selectedTab.value = i;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(index: _index, children: _screens),
          Positioned(
            top: 8,
            left: 16,
            right: 16,
            child: SafeArea(
              bottom: false,
              child: DownloadBanner(onTap: () {
                _selectTab(1);
              }),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          _selectTab(i);
          _refreshNewDay();
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Qur\'an',
          ),
          NavigationDestination(
            icon: Icon(Icons.headphones_outlined),
            selectedIcon: Icon(Icons.headphones),
            label: 'Recite',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome),
            label: 'Hasanat',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline),
            selectedIcon: Icon(Icons.favorite),
            label: 'Adhkar',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view),
            label: 'More',
          ),
        ],
      ),
    );
  }
}