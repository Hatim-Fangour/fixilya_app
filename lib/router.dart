// import 'package:fixilya_app/features/auth/presentation/screens/login_screen.dart'; // ✅ Add this import
// import 'package:fixilya_app/features/auth/presentation/screens/email_verification_screen.dart';
// import 'package:fixilya_app/features/auth/presentation/screens/user_type_selection_screen.dart';
// import 'package:fixilya_app/features/auth/presentation/screens/welcome_after_signup.dart';
// import 'package:flutter/material.dart';
// import 'package:fixilya_app/features/auth/presentation/screens/welcome_screen.dart';
// import 'package:fixilya_app/features/auth/presentation/screens/signup_screen.dart';
// import 'package:fixilya_app/features/profile/presentation/screens/handyman_profile_setup.dart';
// import 'package:fixilya_app/features/profile/presentation/screens/client_profile_setup.dart';
// import 'package:fixilya_app/features/profile/presentation/screens/client_profile_page.dart';
// import 'package:fixilya_app/features/profile/presentation/screens/handyman_profile_page.dart';
// import 'package:fixilya_app/views/widget_tree.dart';

// Route<dynamic> generateRoute(RouteSettings routeSettings) {
//   switch (routeSettings.name) {
//     case '/':
//       return MaterialPageRoute(builder: (_) => WelcomeScreen());

//     case '/welcome':
//       return MaterialPageRoute(builder: (_) => WelcomeScreen());

//     // ✅ Login Route
//     case '/login':
//       return MaterialPageRoute(builder: (_) => LoginScreen());

//     // User Type Selection
//     case '/user-type-selection':
//       return MaterialPageRoute(builder: (_) => UserTypeSelectionScreen());

//     case '/signup':
//       final args = routeSettings.arguments as Map<String, dynamic>?;
//       return MaterialPageRoute(
//         builder: (_) => SignUpScreen(userType: args?['userType'] ?? 'client'),
//       );

//     case '/email-verification':
//       final args = routeSettings.arguments as Map<String, dynamic>;

//       print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
//       print('🔀 ROUTER: email-verification');
//       print('Arguments: $args');
//       print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

//       return MaterialPageRoute(
//         builder: (_) {
//           print('🏗️ Building EmailVerificationScreen...');
//           return EmailVerificationScreen(
//             userType: args['userType'],
//             userName: args['userName'],
//             email: args['email'],
//             phone: args['phone'],
//             fullName: args['fullName'],
//           );
//         },
//       );

//     case '/welcome-after-signup':
//       final args = routeSettings.arguments as Map<String, dynamic>;
//       return MaterialPageRoute(
//         builder: (_) => WelcomeAfterSignup(
//           userType: args['userType'],
//           userName: args['userName'],
//         ),
//       );

//     case '/handyman-profile-setup':
//       return MaterialPageRoute(builder: (_) => HandymanProfileSetup());

//     case '/client-profile-setup':
//       return MaterialPageRoute(builder: (_) => ClientProfileSetup());

//     case '/home':
//     case '/widget-tree':
//       return MaterialPageRoute(builder: (_) => WidgetTree());

//     case '/client-profile':
//       return MaterialPageRoute(builder: (_) => ClientProfilePage());

//     case '/handyman-profile':
//       return MaterialPageRoute(builder: (_) => HandymanProfilePage());

//     default:
//       return MaterialPageRoute(
//         builder: (_) => Scaffold(
//           body: Center(
//             child: Text('No route defined for ${routeSettings.name}'),
//           ),
//         ),
//       );
//   }
// }
