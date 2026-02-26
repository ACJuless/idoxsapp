// The skeleton for the pages in the drawer

import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

class BaseMenuPage extends StatelessWidget {
  final String title;
  final IconData icon;
  final String description;
  final List<Widget>? additionalContent;
  final Color? accentColor;

  const BaseMenuPage({
    Key? key,
    required this.title,
    required this.icon,
    required this.description,
    this.additionalContent,
    this.accentColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color pageAccentColor = accentColor ?? AppColors.primary;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: pageAccentColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              pageAccentColor.withOpacity(0.1),
              AppColors.background,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(AppSizes.paddingL),
            child: Column(
              children: [
                // Header Card
                Card(
                  elevation: 8,
                  shadowColor: pageAccentColor.withOpacity(0.3),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(AppSizes.paddingXL),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppSizes.radiusL),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          pageAccentColor,
                          pageAccentColor.withOpacity(0.8),
                        ],
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            icon,
                            size: AppSizes.iconXL,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: AppSizes.paddingM),
                        Text(
                          title,
                          style: AppTextStyles.heading2.copyWith(
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: AppSizes.paddingS),
                        Text(
                          description,
                          style: AppTextStyles.body1.copyWith(
                            color: Colors.white.withOpacity(0.9),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: AppSizes.paddingXL),

                // Content Section
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(AppSizes.paddingL),
                      child: Column(
                        children: [
                          // Text(
                          //   'Coming Soon',
                          //   style: AppTextStyles.heading3,
                          // ),
                          // SizedBox(height: AppSizes.paddingM),
                          // Text(
                          //   'This feature is currently under development. We\'re working hard to bring you the best experience.',
                          //   style: AppTextStyles.body2,
                          //   textAlign: TextAlign.center,
                          // ),
                          // SizedBox(height: AppSizes.paddingL),
                          
                          // Additional content if provided
                          if (additionalContent != null) ...additionalContent!,
                          
                          // Spacer(),
                          
                          // Action Button
                          // SizedBox(
                          //   width: double.infinity,
                          //   child: ElevatedButton.icon(
                          //     onPressed: () {
                          //       ScaffoldMessenger.of(context).showSnackBar(
                          //         SnackBar(
                          //           content: Text('$title feature coming soon!'),
                          //           backgroundColor: pageAccentColor,
                          //           behavior: SnackBarBehavior.floating,
                          //           shape: RoundedRectangleBorder(
                          //             borderRadius: BorderRadius.circular(AppSizes.radiusM),
                          //           ),
                          //         ),
                          //       );
                          //     },
                          //     icon: Icon(Icons.notifications),
                          //     label: Text('Notify When Available'),
                          //     style: ElevatedButton.styleFrom(
                          //       backgroundColor: pageAccentColor,
                          //       padding: EdgeInsets.symmetric(vertical: AppSizes.paddingM),
                          //     ),
                          //   ),
                          // ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}