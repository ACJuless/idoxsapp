// lib/menu/dashboard_page.dart
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
    );
  }
}

// lib/menu/outbox_page.dart
class OutboxPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BaseMenuPage(
      title: 'Outbox',
      icon: Icons.outbox,
      description: 'Manage outgoing documents, signatures, and pending items.',
      accentColor: Colors.brown.shade600,
    );
  }
}

// lib/menu/map_page.dart
class MapPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BaseMenuPage(
      title: 'Map/GPS',
      icon: Icons.map,
      description: 'Location services, GPS tracking, and geographical features.',
      accentColor: Colors.teal.shade600,
    );
  }
}

// lib/menu/marketing_page.dart
class MarketingPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BaseMenuPage(
      title: 'Marketing Tools',
      icon: Icons.campaign,
      description: 'Promotional materials, campaigns, and marketing resources.',
      accentColor: Colors.indigo.shade600,
    );
  }
}

// lib/menu/forms_page.dart
class FormsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BaseMenuPage(
      title: 'Electronic Forms',
      icon: Icons.description,
      description: 'Digital forms, templates, and document management.',
      accentColor: Colors.cyan.shade600,
    );
  }
}

// lib/menu/sales_page.dart
class SalesPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BaseMenuPage(
      title: 'Sales',
      icon: Icons.trending_up,
      description: 'Sales tracking, analytics, and performance metrics.',
      accentColor: Colors.pink.shade600,
    );
  }
}