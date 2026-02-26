import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../menu/doctor_menu/doctor_detail_page.dart'; // Use correct path

class DoctorsBySpecialtyPage extends StatelessWidget {
  final String specialty;

  const DoctorsBySpecialtyPage({Key? key, required this.specialty}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$specialty Doctors'),
        backgroundColor: Colors.red.shade600,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('doctors')
            .where('specialty', isEqualTo: specialty)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(child: Text('No doctors found for $specialty.'));
          }
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doctor = docs[index].data() as Map<String, dynamic>;
              final docId = docs[index].id;
              return Card(
                margin: EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                child: ListTile(
                  leading: Icon(Icons.person, color: Colors.red.shade400),
                  title: Text('${doctor['lastName'] ?? ''}, ${doctor['firstName'] ?? ''}'),
                  subtitle: Text(doctor['specialty'] ?? ''),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DoctorDetailPage(
                          doctor: doctor,
                          doc_id: docId,
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
