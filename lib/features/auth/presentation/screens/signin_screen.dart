// import 'package:fixilya_app/services/auth_service.dart';
// import 'package:flutter/material.dart';
// import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// class SignInScreen extends StatefulWidget {
//   const SignInScreen({Key? key}) : super(key: key);

//   @override
//   State<SignInScreen> createState() => _SignInScreenState();
// }

// class _SignInScreenState extends State<SignInScreen>
//     with TickerProviderStateMixin {
//   final _formKey = GlobalKey<FormState>();
//   final _authService = AuthService();

//   // Animation Controllers
//   late AnimationController _headerController;
//   late AnimationController _formController;
//   late Animation<double> _headerAnimation;
//   late Animation<double> _formAnimation;
//   late Animation<Offset> _slideAnimation;

//   // Controllers
//   final _emailController = TextEditingController();
//   final _passwordController = TextEditingController();

//   bool _rememberMe = false;
//   bool _isLoading = false;
//   bool _obscurePassword = true;

//   // Colors
//   static const primaryColor = Color.fromRGBO(83, 110, 254, 1);
//   static const secondaryColor = Color.fromRGBO(110, 133, 255, 1);
//   static const accentColor = Color.fromRGBO(147, 167, 255, 1);

//   @override
//   void initState() {
//     super.initState();

//     // Initialize animations
//     _headerController = AnimationController(
//       duration: Duration(milliseconds: 800),
//       vsync: this,
//     );

//     _formController = AnimationController(
//       duration: Duration(milliseconds: 1000),
//       vsync: this,
//     );

//     _headerAnimation = CurvedAnimation(
//       parent: _headerController,
//       curve: Curves.easeOut,
//     );

//     _formAnimation = CurvedAnimation(
//       parent: _formController,
//       curve: Curves.easeOut,
//     );

//     _slideAnimation = Tween<Offset>(
//       begin: Offset(0, 0.3),
//       end: Offset.zero,
//     ).animate(_formAnimation);

//     // Start animations
//     _headerController.forward();
//     Future.delayed(Duration(milliseconds: 200), () {
//       _formController.forward();
//     });
//   }

//   @override
//   void dispose() {
//     _headerController.dispose();
//     _formController.dispose();
//     _emailController.dispose();
//     _passwordController.dispose();
//     super.dispose();
//   }

//   Future<void> _handleSignIn() async {
//     if (!_formKey.currentState!.validate()) return;

//     setState(() => _isLoading = true);

//     try {
//       final result = await _authService.signInWithEmail(
//         email: _emailController.text.trim(),
//         password: _passwordController.text,
//       );

//       if (mounted) {
//         setState(() => _isLoading = false);
//       }

//       if (result['success']) {
//         if (mounted) {
//           Navigator.pushReplacementNamed(context, '/home');
//         }
//       } else {
//         _showErrorDialog(result['message']);
//       }
//     } catch (e) {
//       if (mounted) {
//         setState(() => _isLoading = false);
//       }
//       _showErrorDialog('An error occurred. Please try again.');
//     }
//   }

//   void _showErrorDialog(String message) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//         title: Row(
//           children: [
//             Container(
//               padding: EdgeInsets.all(8),
//               decoration: BoxDecoration(
//                 color: Colors.red.withOpacity(0.1),
//                 shape: BoxShape.circle,
//               ),
//               child: Icon(Icons.error_outline, color: Colors.red, size: 24),
//             ),
//             SizedBox(width: 12),
//             Text('Error', style: TextStyle(fontSize: 20)),
//           ],
//         ),
//         content: Text(message),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             style: TextButton.styleFrom(foregroundColor: primaryColor),
//             child: Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Container(
//         decoration: BoxDecoration(
//           gradient: LinearGradient(
//             begin: Alignment.topLeft,
//             end: Alignment.bottomRight,
//             colors: [primaryColor, secondaryColor, accentColor],
//           ),
//         ),
//         child: SafeArea(
//           child: Column(
//             children: [
//               _buildHeader(),
//               Expanded(child: _buildForm()),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildHeader() {
//     return FadeTransition(
//       opacity: _headerAnimation,
//       child: Padding(
//         padding: EdgeInsets.fromLTRB(20, 16, 20, 16),
//         child: Column(
//           children: [
//             SizedBox(height: 20),

//             // Animated Icon
//             TweenAnimationBuilder(
//               tween: Tween<double>(begin: 0, end: 1),
//               duration: Duration(milliseconds: 600),
//               builder: (context, double value, child) {
//                 return Transform.scale(
//                   scale: value,
//                   child: Container(
//                     padding: EdgeInsets.all(20),
//                     decoration: BoxDecoration(
//                       color: Colors.white,
//                       shape: BoxShape.circle,
//                       boxShadow: [
//                         BoxShadow(
//                           color: Colors.black.withOpacity(0.2),
//                           blurRadius: 20,
//                           offset: Offset(0, 10),
//                         ),
//                       ],
//                     ),
//                     child: FaIcon(
//                       FontAwesomeIcons.userCircle,
//                       color: primaryColor,
//                       size: 40,
//                     ),
//                   ),
//                 );
//               },
//             ),

//             SizedBox(height: 16),

//             Text(
//               'Welcome Back',
//               style: TextStyle(
//                 fontSize: 28,
//                 fontWeight: FontWeight.bold,
//                 color: Colors.white,
//                 letterSpacing: 0.5,
//               ),
//             ),

//             SizedBox(height: 6),

//             Text(
//               'Sign in to continue',
//               style: TextStyle(
//                 fontSize: 14,
//                 color: Colors.white.withOpacity(0.9),
//                 letterSpacing: 0.3,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildForm() {
//     return SlideTransition(
//       position: _slideAnimation,
//       child: FadeTransition(
//         opacity: _formAnimation,
//         child: Container(
//           decoration: BoxDecoration(
//             color: Colors.white,
//             borderRadius: BorderRadius.only(
//               topLeft: Radius.circular(30),
//               topRight: Radius.circular(30),
//             ),
//           ),
//           child: SafeArea(
//             top: false,
//             child: SingleChildScrollView(
//               padding: EdgeInsets.fromLTRB(20, 24, 20, 16),
//               child: Form(
//                 key: _formKey,
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       'Sign In',
//                       style: TextStyle(
//                         fontSize: 22,
//                         fontWeight: FontWeight.bold,
//                         color: Colors.black87,
//                       ),
//                     ),

//                     SizedBox(height: 20),

//                     _buildAnimatedTextField(
//                       label: 'Email',
//                       controller: _emailController,
//                       icon: Icons.email_outlined,
//                       keyboardType: TextInputType.emailAddress,
//                       delay: 100,
//                       validator: (value) {
//                         if (value == null || value.isEmpty) {
//                           return 'Please enter your email';
//                         }
//                         final emailRegex = RegExp(
//                           r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
//                         );
//                         if (!emailRegex.hasMatch(value)) {
//                           return 'Please enter a valid email';
//                         }
//                         return null;
//                       },
//                     ),

//                     SizedBox(height: 14),

//                     _buildAnimatedTextField(
//                       label: 'Password',
//                       controller: _passwordController,
//                       icon: Icons.lock_outline,
//                       obscureText: true,
//                       delay: 200,
//                       validator: (value) {
//                         if (value == null || value.isEmpty) {
//                           return 'Please enter your password';
//                         }
//                         return null;
//                       },
//                     ),

//                     SizedBox(height: 14),

//                     // Remember Me & Forgot Password Row
//                     TweenAnimationBuilder(
//                       tween: Tween<double>(begin: 0, end: 1),
//                       duration: Duration(milliseconds: 600),
//                       builder: (context, double value, child) {
//                         return Opacity(
//                           opacity: value,
//                           child: Row(
//                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                             children: [
//                               Row(
//                                 children: [
//                                   Transform.scale(
//                                     scale: 0.9,
//                                     child: Checkbox(
//                                       value: _rememberMe,
//                                       onChanged: (value) {
//                                         setState(() => _rememberMe = value!);
//                                       },
//                                       activeColor: primaryColor,
//                                       shape: RoundedRectangleBorder(
//                                         borderRadius: BorderRadius.circular(4),
//                                       ),
//                                     ),
//                                   ),
//                                   Text(
//                                     'Remember me',
//                                     style: TextStyle(
//                                       fontSize: 13,
//                                       color: Colors.black87,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                               TextButton(
//                                 onPressed: () {
//                                   // Handle forgot password
//                                   Navigator.pushNamed(
//                                     context,
//                                     '/forgot-password',
//                                   );
//                                 },
//                                 style: TextButton.styleFrom(
//                                   padding: EdgeInsets.symmetric(horizontal: 8),
//                                 ),
//                                 child: Text(
//                                   'Forgot Password?',
//                                   style: TextStyle(
//                                     fontSize: 13,
//                                     color: primaryColor,
//                                     fontWeight: FontWeight.w600,
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ),
//                         );
//                       },
//                     ),

//                     SizedBox(height: 20),

//                     // Sign In Button
//                     TweenAnimationBuilder(
//                       tween: Tween<double>(begin: 0, end: 1),
//                       duration: Duration(milliseconds: 800),
//                       builder: (context, double value, child) {
//                         return Transform.scale(
//                           scale: value,
//                           child: Container(
//                             width: double.infinity,
//                             height: 52,
//                             decoration: BoxDecoration(
//                               gradient: LinearGradient(
//                                 colors: [primaryColor, secondaryColor],
//                               ),
//                               borderRadius: BorderRadius.circular(16),
//                               boxShadow: [
//                                 BoxShadow(
//                                   color: primaryColor.withOpacity(0.3),
//                                   blurRadius: 20,
//                                   offset: Offset(0, 10),
//                                 ),
//                               ],
//                             ),
//                             child: ElevatedButton(
//                               onPressed: _isLoading ? null : _handleSignIn,
//                               style: ElevatedButton.styleFrom(
//                                 backgroundColor: Colors.transparent,
//                                 shadowColor: Colors.transparent,
//                                 shape: RoundedRectangleBorder(
//                                   borderRadius: BorderRadius.circular(16),
//                                 ),
//                               ),
//                               child: _isLoading
//                                   ? SizedBox(
//                                       width: 22,
//                                       height: 22,
//                                       child: CircularProgressIndicator(
//                                         color: Colors.white,
//                                         strokeWidth: 2.5,
//                                       ),
//                                     )
//                                   : Row(
//                                       mainAxisAlignment:
//                                           MainAxisAlignment.center,
//                                       children: [
//                                         Text(
//                                           'Sign In',
//                                           style: TextStyle(
//                                             fontSize: 17,
//                                             fontWeight: FontWeight.bold,
//                                             color: Colors.white,
//                                             letterSpacing: 0.5,
//                                           ),
//                                         ),
//                                         SizedBox(width: 8),
//                                         Icon(
//                                           Icons.arrow_forward_rounded,
//                                           color: Colors.white,
//                                           size: 20,
//                                         ),
//                                       ],
//                                     ),
//                             ),
//                           ),
//                         );
//                       },
//                     ),

//                     SizedBox(height: 20),

//                     // Divider with "Or sign in with"
//                     TweenAnimationBuilder(
//                       tween: Tween<double>(begin: 0, end: 1),
//                       duration: Duration(milliseconds: 600),
//                       builder: (context, double value, child) {
//                         return Opacity(
//                           opacity: value,
//                           child: Row(
//                             children: [
//                               Expanded(
//                                 child: Divider(
//                                   thickness: 0.7,
//                                   color: Colors.grey.withOpacity(0.5),
//                                 ),
//                               ),
//                               Padding(
//                                 padding: EdgeInsets.symmetric(horizontal: 12),
//                                 child: Text(
//                                   'Or sign in with',
//                                   style: TextStyle(
//                                     color: Colors.grey[600],
//                                     fontSize: 13,
//                                   ),
//                                 ),
//                               ),
//                               Expanded(
//                                 child: Divider(
//                                   thickness: 0.7,
//                                   color: Colors.grey.withOpacity(0.5),
//                                 ),
//                               ),
//                             ],
//                           ),
//                         );
//                       },
//                     ),

//                     SizedBox(height: 16),

//                     // Social Sign In Buttons
//                     TweenAnimationBuilder(
//                       tween: Tween<double>(begin: 0, end: 1),
//                       duration: Duration(milliseconds: 600),
//                       builder: (context, double value, child) {
//                         return Opacity(
//                           opacity: value,
//                           child: Row(
//                             mainAxisAlignment: MainAxisAlignment.center,
//                             children: [
//                               _buildSocialButton(
//                                 FontAwesomeIcons.google,
//                                 Colors.red,
//                               ),
//                               SizedBox(width: 16),
//                               _buildSocialButton(
//                                 FontAwesomeIcons.facebook,
//                                 Color(0xFF1877F2),
//                               ),
//                               SizedBox(width: 16),
//                               _buildSocialButton(
//                                 FontAwesomeIcons.apple,
//                                 Colors.black,
//                               ),
//                             ],
//                           ),
//                         );
//                       },
//                     ),

//                     SizedBox(height: 20),

//                     // Sign Up Link
//                     Center(
//                       child: TextButton(
//                         onPressed: () {
//                           Navigator.pushReplacementNamed(context, '/signup');
//                         },
//                         style: TextButton.styleFrom(
//                           padding: EdgeInsets.symmetric(vertical: 8),
//                         ),
//                         child: RichText(
//                           text: TextSpan(
//                             text: 'Don\'t have an account? ',
//                             style: TextStyle(
//                               color: Colors.grey[600],
//                               fontSize: 14,
//                             ),
//                             children: [
//                               TextSpan(
//                                 text: 'Sign Up',
//                                 style: TextStyle(
//                                   color: primaryColor,
//                                   fontWeight: FontWeight.bold,
//                                   fontSize: 14,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildSocialButton(IconData icon, Color color) {
//     return Container(
//       width: 50,
//       height: 50,
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: Colors.grey.shade300, width: 1),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.05),
//             blurRadius: 10,
//             offset: Offset(0, 4),
//           ),
//         ],
//       ),
//       child: IconButton(
//         icon: FaIcon(icon, color: color, size: 20),
//         onPressed: () {
//           // Handle social sign in
//         },
//       ),
//     );
//   }

//   Widget _buildAnimatedTextField({
//     required String label,
//     required IconData icon,
//     required TextEditingController controller,
//     required int delay,
//     bool obscureText = false,
//     TextInputType? keyboardType,
//     String? Function(String?)? validator,
//   }) {
//     return TweenAnimationBuilder(
//       tween: Tween<double>(begin: 0, end: 1),
//       duration: Duration(milliseconds: 600),
//       builder: (context, double value, child) {
//         return Opacity(
//           opacity: value,
//           child: Transform.translate(
//             offset: Offset(50 * (1 - value), 0),
//             child: TextFormField(
//               controller: controller,
//               obscureText: obscureText && _obscurePassword,
//               keyboardType: keyboardType,
//               validator: validator,
//               style: TextStyle(fontSize: 15),
//               decoration: InputDecoration(
//                 labelText: label,
//                 labelStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
//                 prefixIcon: Container(
//                   margin: EdgeInsets.all(10),
//                   padding: EdgeInsets.all(6),
//                   decoration: BoxDecoration(
//                     color: primaryColor.withOpacity(0.1),
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                   child: Icon(icon, color: primaryColor, size: 18),
//                 ),
//                 suffixIcon: obscureText
//                     ? IconButton(
//                         icon: Icon(
//                           _obscurePassword
//                               ? Icons.visibility_off_outlined
//                               : Icons.visibility_outlined,
//                           color: Colors.grey[600],
//                           size: 20,
//                         ),
//                         onPressed: () {
//                           setState(() => _obscurePassword = !_obscurePassword);
//                         },
//                       )
//                     : null,
//                 filled: true,
//                 fillColor: Colors.grey[50],
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(14),
//                   borderSide: BorderSide.none,
//                 ),
//                 enabledBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(14),
//                   borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
//                 ),
//                 focusedBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(14),
//                   borderSide: BorderSide(color: primaryColor, width: 2),
//                 ),
//                 errorBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(14),
//                   borderSide: BorderSide(color: Colors.red, width: 1),
//                 ),
//                 focusedErrorBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(14),
//                   borderSide: BorderSide(color: Colors.red, width: 2),
//                 ),
//                 contentPadding: EdgeInsets.symmetric(
//                   horizontal: 14,
//                   vertical: 14,
//                 ),
//                 isDense: true,
//               ),
//             ),sss
//           ),
//         );
//       },
//     );
//   }
// }
