import 'package:flutter/material.dart';

class CountdownPage extends StatelessWidget {
  const CountdownPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('倒数日'),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.flag_rounded, size: 56),
            const SizedBox(height: 12),
            Text('倒数日 页面', style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      ),
    );
  }
}

