import 'package:flutter/material.dart';

class ScheduledCallDetailPage extends StatelessWidget {
  final Map<String, dynamic> callData;
  ScheduledCallDetailPage({required this.callData});

  @override
  Widget build(BuildContext context) {
    final patientName = callData["userName"] ?? 'Patient';
    final address = callData["address"] ?? 'Address not set';
    final specialty = callData["specialty"] ?? 'Specialty not set';
    final List<String> tabs = [
      "Pre Call", "Location", "Tools", "Signature", "Post-Call", "CoDs"
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(patientName),
          backgroundColor: Colors.green.shade600,
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(106),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                      left: 18, right: 18, top: 5, bottom: 2),
                  child: Text(
                    address,
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 18, right: 18, bottom: 6),
                  child: Text(
                    specialty,
                    style: TextStyle(
                        fontSize: 15, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                TabBar(
                  isScrollable: true,
                  tabs: tabs.map((t) => Tab(child: Text(t))).toList(),
                  indicatorColor: Colors.white,
                  labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
          ),
        ),
        body: TabBarView(
          children: tabs.map((name) {
            return Center(
              child: Text(
                "$name Section",
                style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
