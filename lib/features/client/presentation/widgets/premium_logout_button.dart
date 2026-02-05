// import 'package:fixilya_app/core/constants/app_colors.dart';
// import 'package:fixilya_app/features/auth/presentation/screens/login_screen.dart';
// import 'package:flutter/material.dart';
// import 'dart:ui';

// class PremiumLogoutButton extends StatelessWidget {
//   const PremiumLogoutButton({super.key});

//   void _showUltraLuxuryLogoutDialog() {
//     showGeneralDialog(
//       context: context,
//       barrierDismissible: true,
//       barrierLabel: 'Logout',
//       barrierColor: Colors.black.withValues(alpha: 0.75),
//       transitionDuration: Duration(milliseconds: 500),
//       pageBuilder: (context, animation1, animation2) {
//         return Container();
//       },
//       transitionBuilder: (context, animation, secondaryAnimation, child) {
//         return SlideTransition(
//           position: Tween<Offset>(begin: Offset(0, 0.3), end: Offset.zero)
//               .animate(
//                 CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
//               ),
//           child: ScaleTransition(
//             scale: Tween<double>(begin: 0.85, end: 1.0).animate(
//               CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
//             ),
//             child: FadeTransition(
//               opacity: animation,
//               child: Center(
//                 child: Container(
//                   margin: EdgeInsets.symmetric(horizontal: 24),
//                   child: ClipRRect(
//                     borderRadius: BorderRadius.circular(32),
//                     child: BackdropFilter(
//                       filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
//                       child: Container(
//                         decoration: BoxDecoration(
//                           color: Colors.white.withValues(alpha: 0.95),
//                           borderRadius: BorderRadius.circular(32),
//                           border: Border.all(
//                             color: Colors.white.withValues(alpha: 0.5),
//                             width: 2,
//                           ),
//                           boxShadow: [
//                             BoxShadow(
//                               color: Colors.black.withValues(alpha: 0.3),
//                               blurRadius: 60,
//                               spreadRadius: 10,
//                               offset: Offset(0, 30),
//                             ),
//                           ],
//                         ),
//                         child: Material(
//                           color: Colors.transparent,
//                           child: Padding(
//                             padding: EdgeInsets.all(32),
//                             child: Column(
//                               mainAxisSize: MainAxisSize.min,
//                               children: [
//                                 // Animated Gradient Circle
//                                 TweenAnimationBuilder(
//                                   tween: Tween<double>(begin: 0, end: 1),
//                                   duration: Duration(milliseconds: 800),
//                                   curve: Curves.elasticOut,
//                                   builder: (context, double value, child) {
//                                     return Transform.scale(
//                                       scale: value,
//                                       child: Container(
//                                         width: 100,
//                                         height: 100,
//                                         decoration: BoxDecoration(
//                                           gradient: LinearGradient(
//                                             begin: Alignment.topLeft,
//                                             end: Alignment.bottomRight,
//                                             colors: [
//                                               Color(0xFFFF6B6B),
//                                               Color(0xFFEE5A6F),
//                                               Color(0xFFC06C84),
//                                             ],
//                                           ),
//                                           shape: BoxShape.circle,
//                                           boxShadow: [
//                                             BoxShadow(
//                                               color: Colors.red.withValues(
//                                                 alpha: 0.5,
//                                               ),
//                                               blurRadius: 30,
//                                               offset: Offset(0, 15),
//                                             ),
//                                           ],
//                                         ),
//                                         child: Stack(
//                                           alignment: Alignment.center,
//                                           children: [
//                                             // Pulsing effect
//                                             TweenAnimationBuilder(
//                                               tween: Tween<double>(
//                                                 begin: 1,
//                                                 end: 1.2,
//                                               ),
//                                               duration: Duration(seconds: 1),
//                                               builder:
//                                                   (
//                                                     context,
//                                                     double scale,
//                                                     child,
//                                                   ) {
//                                                     return Transform.scale(
//                                                       scale: scale,
//                                                       child: Container(
//                                                         width: 100,
//                                                         height: 100,
//                                                         decoration:
//                                                             BoxDecoration(
//                                                               shape: BoxShape
//                                                                   .circle,
//                                                               border: Border.all(
//                                                                 color: Colors
//                                                                     .red
//                                                                     .withValues(
//                                                                       alpha:
//                                                                           0.3,
//                                                                     ),
//                                                                 width: 2,
//                                                               ),
//                                                             ),
//                                                       ),
//                                                     );
//                                                   },
//                                               onEnd: () {
//                                                 // Repeat animation
//                                               },
//                                             ),
//                                             Icon(
//                                               Icons.power_settings_new_rounded,
//                                               color: Colors.white,
//                                               size: 48,
//                                             ),
//                                           ],
//                                         ),
//                                       ),
//                                     );
//                                   },
//                                 ),

//                                 SizedBox(height: 28),

//                                 // Title with gradient
//                                 ShaderMask(
//                                   shaderCallback: (bounds) => LinearGradient(
//                                     colors: [
//                                       Color(0xFFFF6B6B),
//                                       Color(0xFFC06C84),
//                                     ],
//                                   ).createShader(bounds),
//                                   child: Text(
//                                     'Logout Account',
//                                     style: TextStyle(
//                                       fontSize: 28,
//                                       fontWeight: FontWeight.w900,
//                                       color: Colors.white,
//                                       letterSpacing: 0.5,
//                                     ),
//                                   ),
//                                 ),

//                                 SizedBox(height: 14),

//                                 // Subtitle
//                                 Text(
//                                   'You\'re about to end this session',
//                                   textAlign: TextAlign.center,
//                                   style: TextStyle(
//                                     fontSize: 15,
//                                     color: Colors.grey[600],
//                                     fontWeight: FontWeight.w500,
//                                     letterSpacing: 0.3,
//                                   ),
//                                 ),

//                                 SizedBox(height: 8),

//                                 // Description
//                                 Container(
//                                   padding: EdgeInsets.symmetric(
//                                     horizontal: 20,
//                                     vertical: 12,
//                                   ),
//                                   decoration: BoxDecoration(
//                                     color: Colors.grey[100],
//                                     borderRadius: BorderRadius.circular(16),
//                                   ),
//                                   child: Text(
//                                     'Are you sure you want to logout from your account?',
//                                     textAlign: TextAlign.center,
//                                     style: TextStyle(
//                                       fontSize: 14,
//                                       color: Colors.grey[700],
//                                       height: 1.4,
//                                     ),
//                                   ),
//                                 ),

//                                 SizedBox(height: 32),

//                                 // Premium Buttons
//                                 Row(
//                                   children: [
//                                     // Stay Button
//                                     Expanded(
//                                       child: Container(
//                                         height: 56,
//                                         decoration: BoxDecoration(
//                                           gradient: LinearGradient(
//                                             colors: [
//                                               AppColors.primaryColor.withValues(
//                                                 alpha: 0.1,
//                                               ),
//                                               AppColors.secondaryColor
//                                                   .withValues(alpha: 0.05),
//                                             ],
//                                           ),
//                                           borderRadius: BorderRadius.circular(
//                                             18,
//                                           ),
//                                           border: Border.all(
//                                             color: AppColors.primaryColor
//                                                 .withValues(alpha: 0.3),
//                                             width: 2,
//                                           ),
//                                         ),
//                                         child: Material(
//                                           color: AppColors.transparent,
//                                           child: InkWell(
//                                             borderRadius: BorderRadius.circular(
//                                               18,
//                                             ),
//                                             onTap: () => Navigator.pop(context),
//                                             child: Center(
//                                               child: Row(
//                                                 mainAxisAlignment:
//                                                     MainAxisAlignment.center,
//                                                 children: [
//                                                   Icon(
//                                                     Icons.close_rounded,
//                                                     color:
//                                                         AppColors.primaryColor,
//                                                     size: 22,
//                                                   ),
//                                                   SizedBox(width: 8),
//                                                   Text(
//                                                     'Stay',
//                                                     style: TextStyle(
//                                                       fontSize: 16,
//                                                       fontWeight:
//                                                           FontWeight.bold,
//                                                       color: AppColors
//                                                           .primaryColor,
//                                                       letterSpacing: 0.5,
//                                                     ),
//                                                   ),
//                                                 ],
//                                               ),
//                                             ),
//                                           ),
//                                         ),
//                                       ),
//                                     ),

//                                     SizedBox(width: 14),

//                                     // Logout Button
//                                     Expanded(
//                                       flex: 2,
//                                       child: Container(
//                                         height: 56,
//                                         decoration: BoxDecoration(
//                                           gradient: LinearGradient(
//                                             begin: Alignment.topLeft,
//                                             end: Alignment.bottomRight,
//                                             colors:
//                                                 AppColors.logoutButtonGradient,
//                                           ),
//                                           borderRadius: BorderRadius.circular(
//                                             18,
//                                           ),
//                                           boxShadow: [
//                                             BoxShadow(
//                                               color: Color(
//                                                 0xFFFF6B6B,
//                                               ).withValues(alpha: 0.5),
//                                               blurRadius: 20,
//                                               offset: Offset(0, 10),
//                                             ),
//                                           ],
//                                         ),
//                                         child: Material(
//                                           color: AppColors.transparent,
//                                           child: InkWell(
//                                             borderRadius: BorderRadius.circular(
//                                               18,
//                                             ),
//                                             onTap: () {
//                                               Navigator.pop(context);
//                                               Navigator.pushNamedAndRemoveUntil(
//                                                 context,
//                                                 LoginScreen.routeName,
//                                                 (route) => false,
//                                               );
//                                             },
//                                             child: Center(
//                                               child: Row(
//                                                 mainAxisAlignment:
//                                                     MainAxisAlignment.center,
//                                                 children: [
//                                                   Icon(
//                                                     Icons.logout_rounded,
//                                                     color: AppColors.white,
//                                                     size: 22,
//                                                   ),
//                                                   SizedBox(width: 10),
//                                                   Text(
//                                                     'Logout Now',
//                                                     style: TextStyle(
//                                                       fontSize: 17,
//                                                       fontWeight:
//                                                           FontWeight.w900,
//                                                       color: AppColors.white,
//                                                       letterSpacing: 0.8,
//                                                     ),
//                                                   ),
//                                                 ],
//                                               ),
//                                             ),
//                                           ),
//                                         ),
//                                       ),
//                                     ),
//                                   ],
//                                 ),

//                                 SizedBox(height: 20),

//                                 // Info Badge
//                                 Container(
//                                   padding: EdgeInsets.symmetric(
//                                     horizontal: 16,
//                                     vertical: 10,
//                                   ),
//                                   decoration: BoxDecoration(
//                                     gradient: LinearGradient(
//                                       colors: [
//                                         AppColors.blue50,
//                                         AppColors.indigo50,
//                                       ],
//                                     ),
//                                     borderRadius: BorderRadius.circular(14),
//                                     border: Border.all(
//                                       color: AppColors.blue200,
//                                       width: 1.5,
//                                     ),
//                                   ),
//                                   child: Row(
//                                     mainAxisSize: MainAxisSize.min,
//                                     children: [
//                                       Container(
//                                         padding: EdgeInsets.all(6),
//                                         decoration: BoxDecoration(
//                                           color: Colors.blue.shade100,
//                                           shape: BoxShape.circle,
//                                         ),
//                                         child: Icon(
//                                           Icons.lock_outline,
//                                           color: Colors.blue.shade700,
//                                           size: 16,
//                                         ),
//                                       ),
//                                       SizedBox(width: 10),
//                                       Text(
//                                         'Your data is safe & secure',
//                                         style: TextStyle(
//                                           fontSize: 12,
//                                           color: Colors.blue.shade900,
//                                           fontWeight: FontWeight.w600,
//                                           letterSpacing: 0.3,
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         );
//       },
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: Colors.red.shade200, width: 1.5),
//       ),
//       child: Material(
//         color: Colors.transparent,
//         child: InkWell(
//           onTap: () =>
//               _showUltraLuxuryLogoutDialog(), // Use ultra luxury dialog
//           borderRadius: BorderRadius.circular(16),
//           child: Padding(
//             padding: EdgeInsets.symmetric(vertical: 16),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Icon(Icons.logout, color: Colors.red, size: 20),
//                 SizedBox(width: 10),
//                 Text(
//                   'Logout from Account',
//                   style: TextStyle(
//                     color: Colors.red,
//                     fontSize: 16,
//                     fontWeight: FontWeight.bold,
//                     letterSpacing: 0.3,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
