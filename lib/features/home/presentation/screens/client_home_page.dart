import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:fixilya_app/features/handyman/presentation/widgets/handyman_card.dart';
import 'package:fixilya_app/services/handyman_data_service.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ClientHomePage extends StatefulWidget {
  const ClientHomePage({super.key});

  @override
  State<ClientHomePage> createState() => _ClientHomePageState();
}

class _ClientHomePageState extends State<ClientHomePage> {
  // ✅ Service for fetching real data
  final HandymanDataService _handymanService = HandymanDataService();

  // ✅ State for real data
  List<Map<String, dynamic>> _allHandymen = [];

  bool _isLoading = true;
  String _searchQuery = '';

  // Filter states
  String selectedCity = 'All Cities';
  String selectedCategory = 'All Services';

  // Sample data (replace with your actual data later)
  final List<String> cities = [
    'All Cities',
    'Casablanca',
    'Rabat',
    'Fes',
    'Marrakech',
    'Tangier',
    'Agadir',
  ];

  final List<Map<String, dynamic>> categories = [
    {'name': 'All Services', 'icon': FontAwesomeIcons.briefcase},
    {'name': 'Electricity', 'icon': FontAwesomeIcons.bolt},
    {'name': 'Carpentry', 'icon': FontAwesomeIcons.hammer},
    {'name': 'Plumbing', 'icon': FontAwesomeIcons.wrench},
    {'name': 'Painting', 'icon': FontAwesomeIcons.paintRoller},
    {'name': 'Cleaning', 'icon': FontAwesomeIcons.broom},
    {'name': 'AC Repair', 'icon': FontAwesomeIcons.wind},
    {'name': 'General Maintenance', 'icon': FontAwesomeIcons.screwdriverWrench},
  ];

  // Sample handyman jobs (replace with API data later)
  final List<Map<String, dynamic>> handymanJobs = [
    {
      'name': 'Ahmed El Fassi',
      'category': 'Electricity',
      'city': 'Casablanca',
      'rating': 4.8,
      'reviews': 127,
      'phone': '+212 6 12 34 56 78',
      'hourlyRate': 150,
      'image': 'https://i.pravatar.cc/150?img=12',
      'verified': true,
      'experience': '8 years',
      'completedJobs': 245,
    },
    {
      'name': 'Youssef Bennani',
      'category': 'Carpentry',
      'city': 'Rabat',
      'rating': 4.9,
      'reviews': 89,
      'phone': '+212 6 98 76 54 32',
      'hourlyRate': 180,
      'image': 'https://i.pravatar.cc/150?img=13',
      'verified': true,
      'experience': '12 years',
      'completedJobs': 312,
    },
    {
      'name': 'Hamza Idrissi',
      'category': 'Plumbing',
      'city': 'Fes',
      'rating': 4.7,
      'reviews': 156,
      'phone': '+212 6 11 22 33 44',
      'hourlyRate': 140,
      'image': 'https://i.pravatar.cc/150?img=14',
      'verified': true,
      'experience': '6 years',
      'completedJobs': 198,
    },
    {
      'name': 'Omar Alaoui',
      'category': 'Painting',
      'city': 'Marrakech',
      'rating': 4.6,
      'reviews': 93,
      'phone': '+212 6 55 66 77 88',
      'hourlyRate': 120,
      'image': 'https://i.pravatar.cc/150?img=15',
      'verified': false,
      'experience': '5 years',
      'completedJobs': 167,
    },
    {
      'name': 'Karim Tazi',
      'category': 'AC Repair',
      'city': 'Tangier',
      'rating': 4.9,
      'reviews': 201,
      'phone': '+212 6 99 88 77 66',
      'hourlyRate': 200,
      'image': 'https://i.pravatar.cc/150?img=16',
      'verified': true,
      'experience': '10 years',
      'completedJobs': 421,
    },
    {
      'name': 'Said Berrada',
      'category': 'General Maintenance',
      'city': 'Casablanca',
      'rating': 4.5,
      'reviews': 74,
      'phone': '+212 6 44 33 22 11',
      'hourlyRate': 110,
      'image': 'https://i.pravatar.cc/150?img=17',
      'verified': true,
      'experience': '4 years',
      'completedJobs': 134,
    },
  ];

  // Filter jobs based on selection
  // List<Map<String, dynamic>> get filteredJobs {
  //   return handymanJobs.where((job) {
  //     final cityMatch =
  //         selectedCity == 'All Cities' || job['city'] == selectedCity;
  //     final categoryMatch =
  //         selectedCategory == 'All Services' ||
  //         job['category'] == selectedCategory;
  //     return cityMatch && categoryMatch;
  //   }).toList();
  // }

  @override
  void initState() {
    super.initState();
    _loadHandymen();
  }

  // ✅ Load handymen from Firebase
  Future<void> _loadHandymen() async {
    setState(() => _isLoading = true);

    try {
      final handymen = await _handymanService.getAllHandymen();

      if (mounted) {
        setState(() {
          _allHandymen = handymen;
          _isLoading = false;
        });

        print('✅ Loaded ${_allHandymen.length} handymen');
      }
    } catch (e) {
      print('❌ Error loading handymen: $e');

      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ✅ Filter jobs based on selection
  List<Map<String, dynamic>> get filteredJobs {
    return _allHandymen.where((job) {
      // City filter
      final cityMatch =
          selectedCity == 'All Cities' || job['city'] == selectedCity;

      // Category filter (check if skill list contains selected category)
      bool categoryMatch = selectedCategory == 'All Services';
      if (!categoryMatch && job['skills'] is List) {
        final skills = job['skills'] as List;
        categoryMatch = skills.contains(selectedCategory);
      }

      // Search filter
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
      backgroundColor: AppColors.grey50,
      body: SafeArea(
        child: Column(
          children: [
            // Header with gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primaryColor, AppColors.secondaryColor],
                ),
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
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: IconButton(
                              icon: FaIcon(
                                FontAwesomeIcons.bell,
                                color: AppColors.white,
                                size: 18,
                              ),
                              onPressed: () {},
                              padding: EdgeInsets.all(8),
                              constraints: BoxConstraints(),
                            ),
                          ),
                          SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: IconButton(
                              icon: FaIcon(
                                FontAwesomeIcons.user,
                                color: AppColors.white,
                                size: 18,
                              ),
                              onPressed: () {},
                              padding: EdgeInsets.all(8),
                              constraints: BoxConstraints(),
                            ),
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
                      color: AppColors.white,
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
                      decoration: InputDecoration(
                        hintText: 'Search for services...',
                        hintStyle: TextStyle(fontSize: 14),
                        prefixIcon: Icon(
                          Icons.search,
                          color: AppColors.primaryColor,
                          size: 20,
                        ),
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
              color: AppColors.white,
              padding: EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Column(
                children: [
                  // Filter header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filters',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.black,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            selectedCity = 'All Cities';
                            selectedCategory = 'All Services';
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

                  // City & Service Type Filters
                  Row(
                    children: [
                      // City Filter
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'City',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                                color: AppColors.grey700,
                              ),
                            ),
                            SizedBox(height: 6),
                            Container(
                              height: 40,
                              padding: EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: AppColors.grey50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.grey200),
                              ),
                              child: DropdownButton<String>(
                                value: selectedCity,
                                isExpanded: true,
                                underline: SizedBox(),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.black,
                                ),
                                icon: FaIcon(
                                  FontAwesomeIcons.chevronDown,
                                  size: 12,
                                  color: AppColors.grey600,
                                ),
                                items: cities.map((String city) {
                                  return DropdownMenuItem<String>(
                                    value: city,
                                    child: Text(city),
                                  );
                                }).toList(),
                                onChanged: (String? newValue) {
                                  setState(() {
                                    selectedCity = newValue!;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(width: 10),

                      // Service Type Filter
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Service',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                                color: AppColors.grey700,
                              ),
                            ),
                            SizedBox(height: 6),
                            Container(
                              height: 40,
                              padding: EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: AppColors.grey50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.grey200),
                              ),
                              child: DropdownButton<String>(
                                value: selectedCategory,
                                isExpanded: true,
                                underline: SizedBox(),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.black,
                                ),
                                icon: FaIcon(
                                  FontAwesomeIcons.chevronDown,
                                  size: 12,
                                  color: AppColors.grey600,
                                ),
                                items: categories.map((
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
                                    selectedCategory = newValue!;
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

            // Divider
            Divider(height: 1, thickness: 1, color: AppColors.grey200),

            // Results Count
            Container(
              color: AppColors.white,
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
                        '${filteredJobs.length} Available',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.black,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Jobs List
            Expanded(
              child: filteredJobs.isEmpty
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
}
