import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('关于本软件'),
              subtitle: const Text('了解 TaskFlow 的版本与说明'),
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: 'Taskflow',
                  applicationVersion: '1.0.1',
                  applicationLegalese: 'Taskflow - 一个任务清单与纪念日管理应用',
                  children: const [
                    SizedBox(height: 8),
                    Text('感谢使用 TaskFlow。'),
                    SizedBox(height: 6),
                    Text('作者：calmpunct'),
                    Text('官方QQ群：1091415887'),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
