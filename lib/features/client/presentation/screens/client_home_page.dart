import 'package:fixilya_app/core/config/global_variables.dart';
import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:fixilya_app/core/constants/app_routes.dart';
import 'package:fixilya_app/features/handyman/presentation/widgets/handyman_card.dart';
import 'package:fixilya_app/services/handyman_data_service.dart';
import 'package:fixilya_app/features/handyman/presentation/screens/bookings_service.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ClientHomePage extends StatefulWidget {
  const ClientHomePage({super.key});

  @override
  State<ClientHomePage> createState() => _ClientHomePageState();
}

class _ClientHomePageState extends State<ClientHomePage> {
  final HandymanDataService _handymanService = HandymanDataService();
  final BookingsService _bookingsService = BookingsService();

  List<Map<String, dynamic>> _allHandymen = [];
  bool _isLoading = true; // ✅ Add loading state

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadHandymen();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ✅ FAKE DATA - Will be merged with real data
  // final List<Map<String, dynamic>> _fakeHandymen = [
  //   {
  //     'id': 'fake_1', // ✅ Add unique ID
  //     'name': 'Siham',
  //     'skills': ['Cleaning'], // ✅ Changed to match Firebase structure
  //     'city': 'Nador',
  //     'rating': 0,
  //     'reviews': 0,
  //     'category': 'Cleaning', // ✅ Add 'category' for easier filtering
  //     'phone': '+212682483044',
  //     'hourlyRate': 150,
  //     'profilePicture': '',
  //     'approved': true, // ✅ Changed 'verified' to 'approved'
  //     'experience': '8 years',
  //     'completedJobs': 0,
  //     'isAvailable': true,
  //     'verified': true, // ✅ Add availability
  //     'workImages': [],
  //     'bio':
  //         'Experienced cleaner with 8 years of expertise in residential and commercial cleaning. Committed to delivering top-notch service and customer satisfaction. Available for regular cleaning, deep cleaning, and move-in/move-out cleaning services.',
  //   },
  //   {
  //     'id': 'fake_2',
  //     'name': 'Khaled EL OMRANI',
  //     'skills': ['Electricity'],
  //     'city': 'Nador',
  //     'rating': 4.9,
  //     'reviews': 89,
  //     'category': 'Electricity', // ✅ Add 'category' for easier filtering
  //     'phone': '+212777991513',
  //     'hourlyRate': 180,
  //     'profilePicture': '',
  //     'approved': true,
  //     'experience': '12 years',
  //     'completedJobs': 12,
  //     'isAvailable': true,
  //     'verified': true,
  //     'workImages': [],
  //     'bio':
  //         'Experienced cleaner with 8 years of expertise in residential and commercial cleaning. Committed to delivering top-notch service and customer satisfaction. Available for regular cleaning, deep cleaning, and move-in/move-out cleaning services.',
  //   },
  //   {
  //     'id': 'fake_3',
  //     'name': 'Kamal',
  //     'skills': ['Electricity'],
  //     'city': 'Nador',
  //     'rating': 4.7,
  //     'reviews': 156,
  //     'category': 'Electricity', // ✅ Add 'category' for easier filtering
  //     'phone': '+212601918727',
  //     'hourlyRate': 140,
  //     'profilePicture': '',
  //     'approved': true,
  //     'experience': '6 years',
  //     'completedJobs': 198,
  //     'isAvailable': true,
  //     'verified': true,
  //     'workImages': [],
  //     'bio':
  //         'Experienced cleaner with 8 years of expertise in residential and commercial cleaning. Committed to delivering top-notch service and customer satisfaction. Available for regular cleaning, deep cleaning, and move-in/move-out cleaning services.',
  //   },
  //   {
  //     'id': 'fake_4',
  //     'name': 'Mohamed ASSILA',
  //     'skills': ['Electricity'],
  //     'city': 'Nador',
  //     'rating': 4.6,
  //     'reviews': 93,
  //     'category': 'Electricity', // ✅ Add 'category' for easier filtering
  //     'phone': '+212606826196',
  //     'hourlyRate': 120,
  //     'profilePicture': '',
  //     'approved': true,
  //     'experience': '5 years',
  //     'completedJobs': 167,
  //     'isAvailable': true,
  //     'verified': true,
  //     'workImages': [],
  //     'bio':
  //         'Experienced cleaner with 8 years of expertise in residential and commercial cleaning. Committed to delivering top-notch service and customer satisfaction. Available for regular cleaning, deep cleaning, and move-in/move-out cleaning services.',
  //   },
  //   {
  //     'id': 'fake_5',
  //     'name': 'Waeil WARIACHI',
  //     'skills': ['Appliance Repair'],
  //     'city': 'Nador',
  //     'rating': 4.9,
  //     'reviews': 201,
  //     'category': 'Appliance Repair', // ✅ Add 'category' for easier filtering
  //     'phone': '+212623417072',
  //     'hourlyRate': 200,
  //     'profilePicture': '',
  //     'approved': true,
  //     'experience': '10 years',
  //     'completedJobs': 421,
  //     'isAvailable': true,
  //     'verified': true,
  //     'workImages': [],
  //     'bio':
  //         'Experienced cleaner with 8 years of expertise in residential and commercial cleaning. Committed to delivering top-notch service and customer satisfaction. Available for regular cleaning, deep cleaning, and move-in/move-out cleaning services.',
  //   },
  //   {
  //     'id': 'fake_6',
  //     'name': 'Mohamed IKKEN',
  //     'skills': ['Facade coverings'],
  //     'city': 'Nador',
  //     'rating': 4.5,
  //     'reviews': 74,
  //     'category': 'Facade Coverings', // ✅ Add 'category' for easier filtering
  //     'phone': '+212695581770',
  //     'hourlyRate': 110,
  //     'profilePicture': '',
  //     'approved': true,
  //     'experience': '4 years',
  //     'completedJobs': 134,
  //     'isAvailable': true,
  //     'verified': true,
  //     'workImages': [],
  //     'bio':
  //         'Experienced cleaner with 8 years of expertise in residential and commercial cleaning. Committed to delivering top-notch service and customer satisfaction. Available for regular cleaning, deep cleaning, and move-in/move-out cleaning services.',
  //   },
  //   {
  //     'id': 'fake_7',
  //     'name': 'Soufian KOLIGHA',
  //     'skills': ['Painting'],
  //     'city': 'Nador',
  //     'rating': 4.5,
  //     'reviews': 74,
  //     'category': 'Painting', // ✅ Add 'category' for easier filtering
  //     'phone': '+212644659405',
  //     'hourlyRate': 110,
  //     'profilePicture': '',
  //     'approved': true,
  //     'experience': '4 years',
  //     'completedJobs': 134,
  //     'isAvailable': true,
  //     'verified': true,
  //     'workImages': [],
  //     'bio':
  //         'Experienced cleaner with 8 years of expertise in residential and commercial cleaning. Committed to delivering top-notch service and customer satisfaction. Available for regular cleaning, deep cleaning, and move-in/move-out cleaning services.',
  //   },
  //   {
  //     'id': 'fake_8',
  //     'name': 'Abdelhak KOLIGHA',
  //     'skills': ['Painting'],
  //     'city': 'Nador',
  //     'rating': 4.5,
  //     'reviews': 74,
  //     'category': 'Painting', // ✅ Add 'category' for easier filtering
  //     'phone': '+212642691733',
  //     'hourlyRate': 110,
  //     'profilePicture': '',
  //     'approved': true,
  //     'experience': '4 years',
  //     'completedJobs': 134,
  //     'isAvailable': true,
  //     'verified': true,
  //     'workImages': [],
  //     'bio':
  //         'Experienced cleaner with 8 years of expertise in residential and commercial cleaning. Committed to delivering top-notch service and customer satisfaction. Available for regular cleaning, deep cleaning, and move-in/move-out cleaning services.',
  //   },
  //   {
  //     'id': 'fake_9',
  //     'name': 'Abdelwahed',
  //     'skills': ['Welding'],
  //     'city': 'Nador',
  //     'rating': 4.5,
  //     'reviews': 74,
  //     'category': 'Welding', // ✅ Add 'category' for easier filtering
  //     'phone': '+212757438410',
  //     'hourlyRate': 110,
  //     'profilePicture': '',
  //     'approved': true,
  //     'experience': '4 years',
  //     'completedJobs': 134,
  //     'isAvailable': true,
  //     'verified': true,
  //     'workImages': [],
  //     'bio':
  //         'Experienced cleaner with 8 years of expertise in residential and commercial cleaning. Committed to delivering top-notch service and customer satisfaction. Available for regular cleaning, deep cleaning, and move-in/move-out cleaning services.',
  //   },
  //   {
  //     'id': 'fake_10',
  //     'name': 'Youssef',
  //     'skills': ['Concrete'],
  //     'city': 'Nador',
  //     'rating': 4.5,
  //     'reviews': 74,
  //     'category': 'Concrete', // ✅ Add 'category' for easier filtering
  //     'phone': '+212605153771',
  //     'hourlyRate': 110,
  //     'profilePicture': '',
  //     'approved': true,
  //     'experience': '4 years',
  //     'completedJobs': 134,
  //     'isAvailable': true,
  //     'verified': true,
  //     'workImages': [],
  //     'bio':
  //         'Experienced cleaner with 8 years of expertise in residential and commercial cleaning. Committed to delivering top-notch service and customer satisfaction. Available for regular cleaning, deep cleaning, and move-in/move-out cleaning services.',
  //   },
  //   {
  //     'id': 'fake_11',
  //     'name': 'Kroom',
  //     'skills': ['Aluminum'],
  //     'city': 'Nador',
  //     'rating': 4.5,
  //     'reviews': 74,
  //     'category': 'Aluminum', // ✅ Add 'category' for easier filtering
  //     'phone': '+212694645584',
  //     'hourlyRate': 110,
  //     'profilePicture': '',
  //     'approved': true,
  //     'experience': '4 years',
  //     'completedJobs': 134,
  //     'isAvailable': true,
  //     'verified': true,
  //     'workImages': [],
  //     'bio':
  //         'Experienced cleaner with 8 years of expertise in residential and commercial cleaning. Committed to delivering top-notch service and customer satisfaction. Available for regular cleaning, deep cleaning, and move-in/move-out cleaning services.',
  //   },
  //   {
  //     'id': 'fake_12',
  //     'name': 'Zouhir',
  //     'skills': ['Zellige', 'Masonry'],
  //     'city': 'Nador',
  //     'rating': 4.5,
  //     'reviews': 74,
  //     'category': 'Zellige', // ✅ Add 'category' for easier filtering
  //     'phone': '+212699449970',
  //     'hourlyRate': 110,
  //     'profilePicture': '',
  //     'approved': true,
  //     'experience': '4 years',
  //     'completedJobs': 134,
  //     'isAvailable': true,
  //     'verified': true,
  //     'workImages': [],
  //     'bio':
  //         'Experienced cleaner with 8 years of expertise in residential and commercial cleaning. Committed to delivering top-notch service and customer satisfaction. Available for regular cleaning, deep cleaning, and move-in/move-out cleaning services.',
  //   },
  //   {
  //     'id': 'fake_13',
  //     'name': 'Youssef',
  //     'skills': ['Zellige', 'Masonry'],
  //     'city': 'Nador',
  //     'rating': 4.5,
  //     'reviews': 74,
  //     'category': 'Zellige', // ✅ Add 'category' for easier filtering
  //     'phone': '+212699449970',
  //     'hourlyRate': 110,
  //     'profilePicture': '',
  //     'approved': true,
  //     'experience': '4 years',
  //     'completedJobs': 134,
  //     'isAvailable': true,
  //     'verified': true,
  //     'workImages': [],
  //     'bio':
  //         'Experienced cleaner with 8 years of expertise in residential and commercial cleaning. Committed to delivering top-notch service and customer satisfaction. Available for regular cleaning, deep cleaning, and move-in/move-out cleaning services.',
  //   },
  //   {
  //     'id': 'fake_14',
  //     'name': 'Soufian',
  //     'skills': ['Plumbing'],
  //     'city': 'Nador',
  //     'rating': 4.5,
  //     'reviews': 74,
  //     'category': 'Plumbing', // ✅ Add 'category' for easier filtering
  //     'phone': '+212658603906',
  //     'hourlyRate': 110,
  //     'profilePicture': '',
  //     'approved': true,
  //     'experience': '4 years',
  //     'completedJobs': 134,
  //     'isAvailable': true,
  //     'verified': true,
  //     'workImages': [],
  //     'bio':
  //         'Experienced cleaner with 8 years of expertise in residential and commercial cleaning. Committed to delivering top-notch service and customer satisfaction. Available for regular cleaning, deep cleaning, and move-in/move-out cleaning services.',
  //   },
  //   {
  //     'id': 'fake_15',
  //     'name': 'Mosa',
  //     'skills': ['Carpentry'],
  //     'city': 'Nador',
  //     'rating': 4.5,
  //     'reviews': 74,
  //     'category': 'Carpentry', // ✅ Add category for easier filtering
  //     'phone': '+212634882102',
  //     'hourlyRate': 110,
  //     'profilePicture': '',
  //     'approved': true,
  //     'experience': '4 years',
  //     'completedJobs': 134,
  //     'isAvailable': true,
  //     'verified': true,
  //     'workImages': [],
  //     'bio':
  //         'Experienced cleaner with 8 years of expertise in residential and commercial cleaning. Committed to delivering top-notch service and customer satisfaction. Available for regular cleaning, deep cleaning, and move-in/move-out cleaning services.',
  //   },
  // ];

  Future<void> _loadHandymen() async {
    setState(() => _isLoading = true); // ✅ Set loading true

    try {
      final realHandymen = await _handymanService.getAllHandymen();
      print('✅ Fetched ${realHandymen} real handymen from Firebase');
      print('\n\n\n');
      print(
        '✅ Fetched ${GlobalVariables.fakeHandymen[0]} fake handymen from Firebase',
      );
      print('\n\n\n');
      print(realHandymen);
      if (mounted) {
        setState(() {
          _allHandymen = [
            ...GlobalVariables.fakeHandymen, // Fake data
            ...realHandymen, // Real Firebase data
          ];
          _isLoading = false; // ✅ Set loading false
        });

        print(
          '✅ Loaded ${GlobalVariables.fakeHandymen.length} fake + ${realHandymen.length} real = ${_allHandymen.length} total handymen',
        );

        print('✅ Loaded ${_allHandymen.length} handymen');
      }
    } catch (e) {
      print('❌ Error loading handymen: $e');

      if (mounted) {
        setState(() => _isLoading = false); // ✅ Set loading false on error
      }
    }
  }

  List<Map<String, dynamic>> get filteredJobs {
    return _allHandymen.where((job) {
      final cityMatch =
          GlobalVariables.selectedCity == 'All Cities' ||
          job['city'] == GlobalVariables.selectedCity;

      bool categoryMatch = GlobalVariables.selectedCategory == 'All Services';
      if (!categoryMatch && job['skills'] is List) {
        final skills = job['skills'] as List;
        categoryMatch = skills.contains(GlobalVariables.selectedCategory);
      }

      bool searchMatch = _searchQuery.isEmpty;
      if (!searchMatch) {
        final name = job['name'].toString().toLowerCase();
        final query = _searchQuery.toLowerCase();
        searchMatch = name.contains(query);
      }

      return cityMatch && categoryMatch && searchMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor(context),
      body: SafeArea(
        child: Column(
          children: [
            // Header with gradient
            Container(
              decoration: BoxDecoration(
                gradient: AppColors.subtleHeaderGradientThemed(context),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  // Top bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Find Handyman',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                              color: AppColors.white,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Book professional services',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            padding: EdgeInsets.all(8),
                            constraints: BoxConstraints(),
                            icon: StreamBuilder<int>(
                              stream: _bookingsService
                                  .streamUnreadNotificationsCount(),
                              builder: (context, snapshot) {
                                final unreadCount = snapshot.data ?? 0;

                                return Stack(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceColor(
                                          context,
                                        ).withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.notifications_outlined,
                                        color: AppColors.white,
                                        size: 24,
                                      ),
                                    ),
                                    if (unreadCount > 0)
                                      Positioned(
                                        right: 0,
                                        top: 0,
                                        child: Container(
                                          padding: EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          constraints: BoxConstraints(
                                            minWidth: 16,
                                            minHeight: 16,
                                          ),
                                          child: Text(
                                            unreadCount > 99
                                                ? '99+'
                                                : '$unreadCount',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                            onPressed: () {
                              AppRoutes.toClientNotifications();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),

                  SizedBox(height: 12),

                  // Search Bar
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.cardColor(context),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        // ✅ Add onChanged
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search for services...',
                        hintStyle: TextStyle(fontSize: 14),
                        prefixIcon: Icon(
                          Icons.search,
                          color: AppColors.primaryColor,
                          size: 20,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear,
                                  color: AppColors.grey600,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _searchController.clear();
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Filters Section
            Container(
              // color: AppColors.surfaceColor(context),
              padding: EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filters',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.textPrimaryColor(context),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            GlobalVariables.selectedCity = 'All Cities';
                            GlobalVariables.selectedCategory = 'All Services';
                          });
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          minimumSize: Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Clear All',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 8),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'City',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                                color: AppColors.textSecondaryColor(context),
                              ),
                            ),
                            SizedBox(height: 6),
                            Container(
                              height: 40,
                              padding: EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: AppColors.cardColor(context),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.borderColor(context),
                                ),
                              ),
                              child: DropdownButton<String>(
                                value: GlobalVariables.selectedCity,
                                isExpanded: true,
                                underline: SizedBox(),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textPrimaryColor(context),
                                ),
                                icon: FaIcon(
                                  FontAwesomeIcons.chevronDown,
                                  size: 12,
                                  color: AppColors.grey600,
                                ),
                                items: GlobalVariables.cities.map((
                                  String city,
                                ) {
                                  return DropdownMenuItem<String>(
                                    value: city,
                                    child: Text(city),
                                  );
                                }).toList(),
                                onChanged: (String? newValue) {
                                  setState(() {
                                    GlobalVariables.selectedCity = newValue!;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(width: 10),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Service',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                                color: AppColors.textSecondaryColor(context),
                              ),
                            ),
                            SizedBox(height: 6),
                            Container(
                              height: 40,
                              padding: EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: AppColors.cardColor(context),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.borderColor(context),
                                ),
                              ),
                              child: DropdownButton<String>(
                                value: GlobalVariables.selectedCategory,
                                isExpanded: true,
                                underline: SizedBox(),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textPrimaryColor(context),
                                ),
                                icon: FaIcon(
                                  FontAwesomeIcons.chevronDown,
                                  size: 12,
                                  color: AppColors.grey600,
                                ),
                                items: GlobalVariables.availableSkills.map((
                                  Map<String, dynamic> category,
                                ) {
                                  return DropdownMenuItem<String>(
                                    value: category['name'],
                                    child: Row(
                                      children: [
                                        FaIcon(
                                          category['icon'],
                                          size: 12,
                                          color: AppColors.primaryColor,
                                        ),
                                        SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            category['name'],
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (String? newValue) {
                                  setState(() {
                                    GlobalVariables.selectedCategory =
                                        newValue!;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Divider(
              height: 1,
              thickness: 1,
              color: AppColors.dividerColor(context),
            ),

            // Results Count
            Container(
              // color: AppColors.surfaceColor(context),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 16,
                        color: AppColors.primaryColor,
                      ),
                      SizedBox(width: 6),
                      Text(
                        _isLoading
                            ? 'Loading...'
                            : '${filteredJobs.length} Available',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.textPrimaryColor(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ✅ Jobs List with Skeleton Loading
            Expanded(
              child: _isLoading
                  ? _buildSkeletonLoading() // ✅ Show skeleton while loading
                  : filteredJobs.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FaIcon(
                            FontAwesomeIcons.magnifyingGlass,
                            size: 48,
                            color: AppColors.grey400,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'No handymen found',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.grey600,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Try adjusting your filters',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.grey500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
                      itemCount: filteredJobs.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: HandymanCard(job: filteredJobs[index]),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ SKELETON LOADING WIDGET
  Widget _buildSkeletonLoading() {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: 5, // Show 5 skeleton cards
      itemBuilder: (context, index) {
        return Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: _buildSkeletonCard(),
        );
      },
    );
  }

  Widget _buildSkeletonCard() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceColor(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar skeleton
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: AppColors.inputBorderColor(context),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          SizedBox(width: 12),
          // Details skeleton
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name skeleton
                Container(
                  width: double.infinity,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.inputBorderColor(context),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                SizedBox(height: 8),
                // Category skeleton
                Container(
                  width: 100,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppColors.inputBorderColor(context),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                SizedBox(height: 8),
                // Rating skeleton
                Row(
                  children: [
                    Container(
                      width: 80,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.inputBorderColor(context),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    SizedBox(width: 12),
                    Container(
                      width: 60,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppColors.inputBorderColor(context),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
