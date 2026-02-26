import 'package:flutter/material.dart';
import 'base_menu_page.dart';

class OutboxPage extends StatefulWidget {
  @override
  _OutboxPageState createState() => _OutboxPageState();
}

class _OutboxPageState extends State<OutboxPage> {
  final List<Map<String, String>> _companies = [
    {
      "name": "ASD FARM",
      "visitDate": "2025-09-30 15:37:53",
      "planDate": "2025-09-30"
    },
    {
      "name": "FGHH",
      "visitDate": "2025-09-30 15:38:30",
      "planDate": "2025-11-09"
    },
    {
      "name": "PAUL CHENG LEE",
      "visitDate": "2025-04-04 14:26:27",
      "planDate": "2025-04-04"
    },
    {
      "name": "MAYBELLINE CHUA",
      "visitDate": "2025-04-04 15:39:29",
      "planDate": "2025-04-07"
    },
    {
      "name": "ELEN CHUA",
      "visitDate": "2025-04-04 15:39:46",
      "planDate": "2025-04-03"
    },
    {
      "name": "AMREIVAX CORPORATION",
      "visitDate": "2024-10-23 10:31:26",
      "planDate": "2024-10-23"
    },
    {
      "name": "BOARD OF TRUSTEES OF VETERANS OF WORLD WAR II (OUT PATIENT DEPARTMENT)",
      "visitDate": "2024-10-23 10:31:32",
      "planDate": "2024-10-23"
    },
    {
      "name": "PERRY ALGAM",
      "visitDate": "2024-10-11 16:28:49",
      "planDate": "2024-10-11"
    },
    {
      "name": "CIRILO CABANG",
      "visitDate": "2024-10-11 16:29:15",
      "planDate": "2024-10-11"
    },
    {
      "name": "MARVIN CARPUZ",
      "visitDate": "2024-10-11 16:29:23",
      "planDate": "2024-10-11"
    },
    {
      "name": "JENNIFER CORPUZ",
      "visitDate": "2024-10-11 16:29:28",
      "planDate": "2024-10-11"
    },
    {
      "name": "HELEN BUENVENIDA",
      "visitDate": "2024-07-15 14:54:54",
      "planDate": "2024-07-08"
    },
    {
      "name": "SUPAN FREDERICK",
      "visitDate": "2023-05-08 10:24:02",
      "planDate": "2023-05-05"
    },
  ];

  Map<String, List<Map<String, String>>> _groupCompaniesByDate() {
    Map<String, List<Map<String, String>>> grouped = {};

    for (var company in _companies) {
      DateTime visitDate = DateTime.parse(company["visitDate"]!);
      String dateKey = "${visitDate.year}-${visitDate.month.toString().padLeft(2, '0')}";

      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(company);
    }

    return grouped;
  }

  String _formatMonthYear(String dateKey) {
    List<String> parts = dateKey.split('-');
    int year = int.parse(parts[0]);
    int month = int.parse(parts[1]);

    List<String> months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    return "${months[month - 1]} $year";
  }

  @override
  Widget build(BuildContext context) {
    final groupedCompanies = _groupCompaniesByDate();
    final sortedKeys = groupedCompanies.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // Descending order

    return BaseMenuPage(
      title: 'Outbox',
      icon: Icons.outbox,
      description: 'Manage outgoing documents, signatures, and pending items.',
      accentColor: Colors.brown.shade600,
      additionalContent: [
        // ListTile(
        //   leading: Icon(Icons.send, color: Colors.brown.shade600),
        //   title: Text('Pending Documents'),
        //   subtitle: Text('Items waiting to be sent'),
        // ),
        // ListTile(
        //   leading: Icon(Icons.history, color: Colors.brown.shade600),
        //   title: Text('Send History'),
        //   subtitle: Text('Track sent documents'),
        // ),
        Expanded(
          child: ListView.builder(
            itemCount: sortedKeys.length,
            itemBuilder: (context, index) {
              String dateKey = sortedKeys[index];
              List<Map<String, String>> companiesForDate = groupedCompanies[dateKey]!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section Header
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    margin: EdgeInsets.only(top: index == 0 ? 8 : 16, bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.brown.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "${_formatMonthYear(dateKey)} (${companiesForDate.length})",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.brown.shade800,
                      ),
                    ),
                  ),
                  // Companies for this date
                  ...companiesForDate.map((company) => Card(
                        margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: ListTile(
                          leading: Icon(Icons.business, color: Colors.brown.shade600),
                          title: Text(
                            company["name"]!,
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Visit Date: ${company["visitDate"]!}"),
                              Text("Plan Date: ${company["planDate"]!}"),
                            ],
                          ),
                        ),
                      )),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
