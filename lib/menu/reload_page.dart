import 'package:flutter/material.dart';
import 'base_menu_page.dart';

class ReloadPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BaseMenuPage(
      title: 'Reload',
      icon: Icons.refresh,
      description: 'Refresh data, sync content, and update application information.',
      accentColor: Colors.orange.shade600,
      additionalContent: [
        ListTile(
          leading: Icon(Icons.sync, color: Colors.orange.shade600),
          title: Text('Data Sync'),
          subtitle: Text('Synchronize with cloud services'),
        ),
        ListTile(
          leading: Icon(Icons.update, color: Colors.orange.shade600),
          title: Text('App Updates'),
          subtitle: Text('Check for latest version'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: ElevatedButton(
            onPressed: () {
              // TODO: Add reload logic here
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
            ),
            child: Text('Reload'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: ElevatedButton(
            onPressed: () {
              // TODO: Add send updates logic here
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
            ),
            child: Text('Send Updates'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: ElevatedButton(
            onPressed: () {
              // TODO: Add reload notes logic here
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
            ),
            child: Text('Reload Notes'),
          ),
        ),
      ],
    );
  }
}