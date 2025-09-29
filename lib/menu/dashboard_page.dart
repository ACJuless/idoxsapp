import 'package:flutter/material.dart';
import 'base_menu_page.dart';

class DashboardPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BaseMenuPage(
      title: 'Dashboard',
      icon: Icons.dashboard,
      description: 'Overview of your activities, statistics, and key metrics.',
      accentColor: Colors.purple.shade600,
      additionalContent: [
        ListTile(
          leading: Icon(Icons.analytics, color: Colors.purple.shade600),
          title: Text('Analytics'),
          subtitle: Text('View performance metrics'),
        ),
        ListTile(
          leading: Icon(Icons.insights, color: Colors.purple.shade600),
          title: Text('Insights'),
          subtitle: Text('Data-driven recommendations'),
        ),
      ],
    );
  }
}