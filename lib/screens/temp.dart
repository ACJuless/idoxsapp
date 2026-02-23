// @override
// Widget build(BuildContext context) {
//   FutureBuilder<List<String>>(
//     future: scanMarketingTools(),
//     builder: (context, toolSnapshot) {
//       if (toolSnapshot.connectionState != ConnectionState.done) {
//         return Center(child: CircularProgressIndicator());
//       }
//       if (toolSnapshot.hasError || !toolSnapshot.hasData) {
//         return Center(child: Text("Could not load tool assets."));
//       }

//       final toolNames = toolSnapshot.data!;
//       final todayStr =
//         "${DateTime.now().year.toString().padLeft(4, '0')}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}";

//       return FutureBuilder<QuerySnapshot>(
//         future: FirebaseFirestore.instance.collection('doctors').get(),
//         builder: (context, doctorSnapshot) {
//           if (!doctorSnapshot.hasData) return Center(child: CircularProgressIndicator());
//           final doctorDocs = doctorSnapshot.data!.docs;

//           // Filter only doctors with a scheduledVisit today
//           return FutureBuilder<List<DocumentSnapshot>>(
//             future: () async {
//               List<DocumentSnapshot> filtered = [];
//               for (var doc in doctorDocs) {
//                 final scheduled = await FirebaseFirestore.instance
//                     .collection('doctors')
//                     .doc(doc.id)
//                     .collection('scheduledVisits')
//                     .where('scheduledDate', isEqualTo: todayStr)
//                     .limit(1)
//                     .get();
//                 if (scheduled.docs.isNotEmpty) filtered.add(doc);
//               }
//               return filtered;
//             }(),
//             builder: (context, filteredSnapshot) {
//               if (!filteredSnapshot.hasData) return Center(child: CircularProgressIndicator());
//               final filteredDocs = filteredSnapshot.data!;
//               if (filteredDocs.isEmpty)
//                 return Center(child: Text("No scheduled doctors today."));

//               return SizedBox(
//                 height: 280,
//                 child: SingleChildScrollView(
//                   scrollDirection: Axis.horizontal,
//                   child: Row(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: filteredDocs.map((doc) {
//                       final stateKey = doc.id;
//                       doctorChecklistStates[stateKey] ??= {
//                         for (final tool in toolNames) tool: false,
//                       };

//                       final isAllChecked = doctorChecklistStates[stateKey]!.values.every((v) => v);

//                       return Stack(
//                         children: [
//                           Container(
//                             width: 220,
//                             constraints: const BoxConstraints(minHeight: 120, maxHeight: 240),
//                             margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
//                             padding: const EdgeInsets.all(12),
//                             decoration: BoxDecoration(
//                               color: Colors.white,
//                               borderRadius: BorderRadius.circular(18),
//                               border: Border.all(
//                                 color: isAllChecked ? Colors.green : Colors.white,
//                                 width: 2,
//                               ),
//                               boxShadow: [
//                                 BoxShadow(
//                                   color: Colors.black12,
//                                   blurRadius: 6,
//                                   offset: Offset(2, 3),
//                                 ),
//                               ],
//                             ),
//                             child: Column(
//                               crossAxisAlignment: CrossAxisAlignment.start,
//                               children: [
//                                 Text(
//                                   "${doc['lastName'] ?? ''}, ${doc['firstName'] ?? ''}".trim(),
//                                   style: const TextStyle(
//                                     fontSize: 18,
//                                     fontWeight: FontWeight.bold,
//                                     color: Colors.black87,
//                                   ),
//                                   maxLines: 2,
//                                   overflow: TextOverflow.ellipsis,
//                                 ),
//                                 const SizedBox(height: 10),
//                                 Expanded(
//                                   child: Scrollbar(
//                                     child: SingleChildScrollView(
//                                       child: Column(
//                                         crossAxisAlignment: CrossAxisAlignment.start,
//                                         children: toolNames.map((tool) => Row(
//                                           children: [
//                                             StatefulBuilder(
//                                               builder: (context, setItemState) => Checkbox(
//                                                 value: doctorChecklistStates[stateKey]![tool]!,
//                                                 onChanged: (checked) {
//                                                   setItemState(() {
//                                                     doctorChecklistStates[stateKey]![tool] = checked!;
//                                                   });
//                                                 },
//                                                 materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
//                                                 visualDensity: VisualDensity.compact,
//                                               ),
//                                             ),
//                                             Flexible(
//                                               child: Text(
//                                                 tool,
//                                                 style: const TextStyle(fontSize: 14),
//                                                 overflow: TextOverflow.ellipsis,
//                                               ),
//                                             ),
//                                           ],
//                                         )).toList(),
//                                       ),
//                                     ),
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                           if (isAllChecked)
//                             Positioned(
//                               top: 6,
//                               right: 12,
//                               child: Icon(
//                                 Icons.check_circle,
//                                 color: Colors.green,
//                                 size: 24,
//                               ),
//                             ),
//                         ],
//                       );
//                     }).toList(),
//                   ),
//                 ),
//               );
//             },
//           );
//         },
//       );
//     },
//   );

// }
