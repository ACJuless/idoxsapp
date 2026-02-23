import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'scheduled_call_detail_page.dart';

class ScheduledCallsPage extends StatelessWidget {
  final DateTime selectedDate;
  ScheduledCallsPage({required this.selectedDate});

  String get dateKey =>
    '${selectedDate.year.toString().padLeft(4, '0')}-'
    '${selectedDate.month.toString().padLeft(2, '0')}-'
    '${selectedDate.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scheduled Calls'),
        backgroundColor: Colors.green.shade600,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('scheduled_calls')
            .doc(dateKey)
            .collection('items')
            .orderBy('time')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty)
            return Center(child: Text("No scheduled calls for this date"));
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, idx) {
              final data = docs[idx].data() as Map<String, dynamic>;
              return Card(
                elevation: 2,
                margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: ListTile(
                  title: Text(data['userName'] ?? '-'),
                  subtitle: Text('Time: ${data['time'] ?? 'N/A'}\nDetails: ${data['details'] ?? ''}'),
                  isThreeLine: true,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ScheduledCallDetailPage(
                          callData: data,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
