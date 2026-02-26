import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';
import '../menu/doctor_menu/add_doctor_page.dart' show specialtyOptions;
import 'doctors_by_specialty_page.dart';

class AllSpecialtiesPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final orientation = MediaQuery.of(context).orientation;
    final bool isPortrait = orientation == Orientation.portrait;

    // Responsive numbers (tighter in portrait)
    final int perRow = isPortrait ? 3 : 6;
    final double iconRadius = isPortrait ? 44 : 34;   // BIG ICON in portrait
    final double iconSize = isPortrait ? 44 : 34;
    final double labelHeight = isPortrait ? 26 : 20;
    final double mainAxisSpacing = isPortrait ? 4 : 20;  // Much closer in portrait!
    final double crossAxisSpacing = isPortrait ? 4 : 18;
    final double gridPadding = isPortrait ? 2 : 12;

    return Scaffold(
      appBar: AppBar(
        title: Text('Find your Doctor'),
        backgroundColor: Color.fromRGBO(82, 41, 205, 1),
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            tooltip: 'Search Specialties',
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: GridView.builder(
          padding: EdgeInsets.symmetric(horizontal: gridPadding, vertical: mainAxisSpacing),
          itemCount: specialtyOptions.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: perRow,
            mainAxisSpacing: mainAxisSpacing,
            crossAxisSpacing: crossAxisSpacing,
            childAspectRatio: isPortrait ? 0.82 : 0.95,
          ),
          itemBuilder: (context, index) => _SpecialtyCell(
            specialty: specialtyOptions[index],
            iconRadius: iconRadius,
            iconSize: iconSize,
            labelHeight: labelHeight,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DoctorsBySpecialtyPage(specialty: specialtyOptions[index]),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SpecialtyCell extends StatelessWidget {
  final String specialty;
  final double iconRadius;
  final double iconSize;
  final double labelHeight;
  final VoidCallback onTap;

  const _SpecialtyCell({
    required this.specialty,
    required this.iconRadius,
    required this.iconSize,
    required this.labelHeight,
    required this.onTap,
  });

  IconData _getIconForSpecialty(String specialty) {
    switch (specialty) {
      case "Cardiology":
        return Icons.favorite;
      case "Neurology":
        return Icons.psychology;
      case "Orthopedic Surgery":
      case "Orthopedic Doctor":
      case "Orthopedics":
        return Icons.accessibility_new;
      case "Pathology":
        return Icons.biotech;
      default:
        return Icons.local_hospital;
    }
  }

  bool get needsMarquee => specialty.length > 16;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(iconRadius),
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: iconRadius,
            backgroundColor: Color(0xFFbaa9eb),
            child: Icon(
              _getIconForSpecialty(specialty),
              color: Color.fromRGBO(82, 41, 205, 1),
              size: iconSize,
            ),
          ),
          SizedBox(height: 6),
          SizedBox(
            height: labelHeight,
            child: needsMarquee
                ? Marquee(
                    text: specialty,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: Color.fromRGBO(82, 41, 205, 1),
                    ),
                    scrollAxis: Axis.horizontal,
                    blankSpace: 18.0,
                    velocity: 12.0,
                    fadingEdgeStartFraction: 0.14,
                    fadingEdgeEndFraction: 0.14,
                    pauseAfterRound: Duration(seconds: 1),
                    accelerationDuration: Duration(milliseconds: 900),
                    accelerationCurve: Curves.linear,
                    decelerationDuration: Duration(milliseconds: 800),
                    decelerationCurve: Curves.easeOut,
                  )
                : Text(
                    specialty,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: Color.fromRGBO(82, 41, 205, 1),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
          ),
        ],
      ),
    );
  }
}
