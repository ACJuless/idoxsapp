import 'package:flutter/material.dart';
import 'base_menu_page.dart';

class ItineraryPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BaseMenuPage(
      title: 'Itinerary',
      icon: Icons.schedule,
      description: 'Manage your schedules, appointments, and daily tasks efficiently.',
      accentColor: Colors.green.shade600,
      additionalContent: [
        ListTile(
          leading: Icon(Icons.event, color: Colors.green.shade600),
          title: Text('Upcoming Events'),
          subtitle: Text('View and manage your calendar'),
        ),
        ListTile(
          leading: Icon(Icons.task, color: Colors.green.shade600),
          title: Text('Task Management'),
          subtitle: Text('Track your daily activities'),
        ),
      ],
    );
  }
}