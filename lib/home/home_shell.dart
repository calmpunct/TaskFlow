import 'package:flutter/material.dart';
import 'package:taskflow/pages/calendar_page.dart';
import 'package:taskflow/pages/countdown_page.dart';
import 'package:taskflow/pages/focus_page.dart';
import 'package:taskflow/pages/task_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;
  bool _isTaskDrawerOpen = false;

  late final List<Widget> _pages = [
    TaskPage(
      onDrawerChanged: (isOpen) {
        if (_isTaskDrawerOpen == isOpen) {
          return;
        }
        setState(() {
          _isTaskDrawerOpen = isOpen;
        });
      },
    ),
    const FocusPage(),
    const CalendarPage(),
    const CountdownPage(),
  ];

  static const List<_TabItem> _tabs = <_TabItem>[
    _TabItem(label: '任务', icon: Icons.checklist_rounded),
    _TabItem(label: '专注', icon: Icons.timer_rounded),
    _TabItem(label: '日历', icon: Icons.calendar_month_rounded),
    _TabItem(label: '倒数日', icon: Icons.flag_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: _isTaskDrawerOpen
          ? null
          : BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              items: _tabs
                  .map(
                    (tab) => BottomNavigationBarItem(
                      icon: Icon(tab.icon),
                      label: tab.label,
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _TabItem {
  const _TabItem({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

