import 'package:flutter/material.dart';
import 'base_menu_page.dart';

class DoctorPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BaseMenuPage(
      title: 'Doctor',
      icon: Icons.local_hospital,
      description: 'Medical appointments, health records, and healthcare management.',
      accentColor: Colors.red.shade600,
      additionalContent: [
        ListTile(
          leading: Icon(Icons.medical_services, color: Colors.red.shade600),
          title: Text('Appointments'),
          subtitle: Text('Schedule and manage medical visits'),
        ),
        ListTile(
          leading: Icon(Icons.health_and_safety, color: Colors.red.shade600),
          title: Text('Health Records'),
          subtitle: Text('Access your medical history'),
        ),
      ],
    );
  }
}