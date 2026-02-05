// Core Constants - App Strings
// All application text strings for easy localization

class AppStrings {
  // Private constructor to prevent instantiation
  AppStrings._();

  // ==================== App Info ====================
  static const String appName = 'Fixilya';
  static const String appTagline = 'Your Trusted Handyman Service';
  static const String appDescription =
      'Find skilled professionals for all your home repair needs';

  // ==================== Authentication ====================
  static const String signIn = 'Sign In';
  static const String signUp = 'Sign Up';
  static const String createAccount = 'Create Account';
  static const String login = 'Login';
  static const String logout = 'Logout';
  static const String forgotPassword = 'Forgot Password?';
  static const String resetPassword = 'Reset Password';
  static const String verifyEmail = 'Verify Your Email';
  static const String emailVerification = 'Email Verification';
  static const String sendVerification = 'Send Verification Email';
  static const String alreadyHaveAccount = 'Already have an account?';
  static const String dontHaveAccount = "Don't have an account?";
  static const String rememberMe = 'Remember Me';
  static const String continueWithGoogle = 'Continue with Google';
  static const String continueWithFacebook = 'Continue with Facebook';
  static const String continueWithApple = 'Continue with Apple';
  static const String orContinueWith = 'Or continue with';

  // ==================== User Types ====================
  static const String selectUserType = 'Select User Type';
  static const String iAmClient = "I'm a Client";
  static const String iAmHandyman = "I'm a Handyman";
  static const String client = 'Client';
  static const String handyman = 'Handyman';
  static const String clientDescription = 'Looking for professional services';
  static const String handymanDescription = 'Offering professional services';

  // ==================== Form Fields ====================
  static const String fullName = 'Full Name';
  static const String email = 'Email';
  static const String emailAddress = 'Email Address';
  static const String password = 'Password';
  static const String confirmPassword = 'Confirm Password';
  static const String phone = 'Phone Number';
  static const String phoneNumber = 'Phone Number';
  static const String city = 'City';
  static const String address = 'Address';
  static const String bio = 'Bio';
  static const String description = 'Description';
  static const String category = 'Category';
  static const String service = 'Service';
  static const String experience = 'Experience';
  static const String yearsOfExperience = 'Years of Experience';
  static const String hourlyRate = 'Hourly Rate';
  static const String skills = 'Skills';
  static const String location = 'Location';

  // ==================== Validation ====================
  static const String required = 'This field is required';
  static const String invalidEmail = 'Please enter a valid email';
  static const String invalidPassword =
      'Password must be at least 6 characters';
  static const String passwordMismatch = 'Passwords do not match';
  static const String invalidPhone = 'Please enter a valid phone number';

  // ==================== Profile ====================
  static const String profile = 'Profile';
  static const String editProfile = 'Edit Profile';
  static const String myProfile = 'My Profile';
  static const String personalInfo = 'Personal Information';
  static const String personalInformation = 'Personal Information';
  static const String professionalInfo = 'Professional Information';
  static const String professionalDetails = 'Professional Details';
  static const String contactInfo = 'Contact Information';
  static const String contactInformation = 'Contact Information';
  static const String aboutMe = 'About Me';
  static const String aboutProfessional = 'About Professional';
  static const String professionalBio = 'Professional Bio';
  static const String profileStrength = 'Profile Strength';
  static const String completeProfile =
      'Complete your profile to get more clients';
  static const String verified = 'Verified';
  static const String verifiedPro = 'Verified Pro';
  static const String verifiedProfessional = 'Verified Professional';

  // ==================== Home/Search ====================
  static const String home = 'Home';
  static const String search = 'Search';
  static const String searchHandymen = 'Search for handymen...';
  static const String searchServices = 'Search services';
  static const String findProfessionals = 'Find Professionals';
  static const String popularServices = 'Popular Services';
  static const String nearYou = 'Near You';
  static const String topRated = 'Top Rated';
  static const String filter = 'Filter';
  static const String sortBy = 'Sort By';
  static const String results = 'Results';

  // ==================== Booking ====================
  static const String book = 'Book';
  static const String bookNow = 'Book Now';
  static const String booking = 'Booking';
  static const String bookAppointment = 'Book Appointment';
  static const String confirmBooking = 'Confirm Booking';
  static const String myBookings = 'My Bookings';
  static const String bookingHistory = 'Booking History';
  static const String upcomingBookings = 'Upcoming Bookings';
  static const String pastBookings = 'Past Bookings';
  static const String bookingDetails = 'Booking Details';
  static const String selectDate = 'Select Date';
  static const String selectTime = 'Select Time';
  static const String preferredDate = 'Preferred Date';
  static const String preferredTime = 'Preferred Time';
  static const String describeJob = 'Describe your job';
  static const String jobDescription = 'Job Description';

  // ==================== Reviews ====================
  static const String reviews = 'Reviews';
  static const String review = 'Review';
  static const String rating = 'Rating';
  static const String writeReview = 'Write a Review';
  static const String customerReviews = 'Customer Reviews';
  static const String clientReviews = 'Client Reviews';
  static const String seeAllReviews = 'See All Reviews';
  static const String viewAllReviews = 'View All Reviews';
  static const String rateService = 'Rate this service';
  static const String leaveReview = 'Leave a review';

  // ==================== Skills & Services ====================
  static const String skillsAndPricing = 'Skills & Pricing';
  static const String servicesOffered = 'Services Offered';
  static const String professionalServices = 'Professional Services';
  static const String addSkill = 'Add Skill';
  static const String addService = 'Add Service';
  static const String editSkill = 'Edit Skill';
  static const String skillName = 'Skill Name';
  static const String serviceName = 'Service Name';
  static const String price = 'Price';
  static const String pricePerHour = 'Price per hour';

  // ==================== Portfolio ====================
  static const String portfolio = 'Portfolio';
  static const String previousWork = 'Previous Work';
  static const String portfolioGallery = 'Portfolio Gallery';
  static const String addWork = 'Add Work';
  static const String addToPortfolio = 'Add to Portfolio';
  static const String projectTitle = 'Project Title';
  static const String clientName = 'Client Name';

  // ==================== Stats ====================
  static const String jobsDone = 'Jobs Done';
  static const String jobsCompleted = 'Jobs Completed';
  static const String completedJobs = 'Completed Jobs';
  static const String yearsExp = 'Years Exp';
  static const String exp = 'Exp';

  // ==================== Availability ====================
  static const String availability = 'Availability';
  static const String availabilityStatus = 'Availability Status';
  static const String available = 'Available';
  static const String unavailable = 'Unavailable';
  static const String acceptingBookings = 'Accepting new bookings';
  static const String notAcceptingBookings = 'Not accepting bookings';

  // ==================== Actions ====================
  static const String save = 'Save';
  static const String cancel = 'Cancel';
  static const String confirm = 'Confirm';
  static const String delete = 'Delete';
  static const String remove = 'Remove';
  static const String edit = 'Edit';
  static const String update = 'Update';
  static const String submit = 'Submit';
  static const String send = 'Send';
  static const String continue_ = 'Continue';
  static const String next = 'Next';
  static const String back = 'Back';
  static const String done = 'Done';
  static const String close = 'Close';
  static const String ok = 'OK';
  static const String yes = 'Yes';
  static const String no = 'No';
  static const String apply = 'Apply';
  static const String clear = 'Clear';
  static const String reset = 'Reset';
  static const String resend = 'Resend';
  static const String refresh = 'Refresh';
  static const String retry = 'Retry';

  // ==================== Navigation ====================
  static const String settings = 'Settings';
  static const String notifications = 'Notifications';
  static const String messages = 'Messages';
  static const String chat = 'Chat';
  static const String help = 'Help';
  static const String about = 'About';
  static const String termsAndConditions = 'Terms & Conditions';
  static const String privacyPolicy = 'Privacy Policy';
  static const String contactUs = 'Contact Us';
  static const String support = 'Support';

  // ==================== Messages ====================
  static const String success = 'Success';
  static const String error = 'Error';
  static const String warning = 'Warning';
  static const String info = 'Info';
  static const String loading = 'Loading...';
  static const String pleaseWait = 'Please wait...';
  static const String settingUp = 'Setting up your profile...';
  static const String processing = 'Processing...';
  static const String sending = 'Sending...';
  static const String saving = 'Saving...';
  static const String updating = 'Updating...';
  static const String noData = 'No data available';
  static const String noResults = 'No results found';
  static const String noInternet = 'No internet connection';
  static const String sessionExpired = 'Session expired. Please sign in again.';
  static const String profileUpdated = 'Profile updated successfully!';
  static const String bookingSuccess = 'Booking request sent successfully!';
  static const String emailSent = 'Verification email sent!';

  // ==================== Placeholders ====================
  static const String enterYourName = 'Enter your name';
  static const String enterYourEmail = 'Enter your email';
  static const String enterYourPassword = 'Enter your password';
  static const String enterYourPhone = 'Enter your phone number';
  static const String selectYourCity = 'Select your city';
  static const String describeYourself = 'Describe yourself';
  static const String tellUsAboutYou = 'Tell us about yourself';

  // ==================== Email Verification ====================
  static const String checkYourEmail = 'Check your email';
  static const String verificationEmailSent =
      'We\'ve sent a verification link to your email';
  static const String clickVerificationLink =
      'Click the verification link in your email';
  static const String returnAndConfirm = 'Return here and confirm';
  static const String iVerifiedMyEmail = 'I\'ve Verified My Email';
  static const String resendVerificationEmail = 'Resend verification email';
  static const String emailNotVerified =
      'Email not verified yet. Please check your inbox.';

  // ==================== Logout ====================
  static const String logoutConfirmation = 'Are you sure you want to logout?';
  static const String logoutFromAccount = 'Logout from Account';

  // ==================== Call Actions ====================
  static const String call = 'Call';
  static const String message = 'Message';
  static const String share = 'Share';

  // ==================== Units ====================
  static const String dhPerHour = 'DH/hour';
  static const String perHour = '/hour';
  static const String dh = 'DH';

  // ==================== Days ====================
  static const String today = 'Today';
  static const String yesterday = 'Yesterday';
  static const String daysAgo = 'days ago';
  static const String weeksAgo = 'weeks ago';
  static const String monthsAgo = 'months ago';
}
