import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminAnalyticsPage extends StatefulWidget {
  const AdminAnalyticsPage({super.key});

  @override
  State<AdminAnalyticsPage> createState() => _AdminAnalyticsPageState();
}

class _AdminAnalyticsPageState extends State<AdminAnalyticsPage> {
  // Luxury Colors
  static const Color primaryGold = Color(0xFFD4AF37);
  static const Color deepNavy = Color(0xFF0A1929);
  static const Color charcoal = Color(0xFF1A2332);
  static const Color softWhite = Color(0xFFFAFAFA);
  static const Color accentRed = Color(0xFFE63946);
  static const Color accentGreen = Color(0xFF06D6A0);
  static const Color accentBlue = Color(0xFF118AB2);
  static const Color accentPurple = Color(0xFF8338EC);
  static const Color accentOrange = Color(0xFFFFB703);

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  String _selectedPeriod = '7days'; // 7days, 30days, 90days, all

  // Data
  List<FlSpot> _revenueData = [];
  List<FlSpot> _handymenData = [];
  List<FlSpot> _bookingsData = [];
  Map<String, int> _bookingsByStatus = {};
  Map<String, int> _topCities = {};

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);

    try {
      await Future.wait([
        _loadRevenueChart(),
        _loadUserGrowthChart(),
        _loadBookingsChart(),
        _loadBookingsByStatus(),
        _loadTopCities(),
      ]);
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading analytics: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _loadRevenueChart() async {
    try {
      final days = _getDaysForPeriod();
      final now = DateTime.now();
      final startDate = now.subtract(Duration(days: days));

      final bookings = await _firestore
          .collection('bookings')
          .where('status', isEqualTo: 'completed')
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
          )
          .orderBy('createdAt')
          .get();

      // Group by day
      Map<int, double> dailyRevenue = {};

      for (var doc in bookings.docs) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        final amount = (data['amount'] ?? data['totalAmount'] ?? 0).toDouble();

        if (createdAt != null) {
          final dayIndex = createdAt.difference(startDate).inDays;
          dailyRevenue[dayIndex] = (dailyRevenue[dayIndex] ?? 0) + amount;
        }
      }

      setState(() {
        _revenueData =
            dailyRevenue.entries
                .map((e) => FlSpot(e.key.toDouble(), e.value))
                .toList()
              ..sort((a, b) => a.x.compareTo(b.x));
      });
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading revenue chart: $e');
    }
  }

  Future<void> _loadUserGrowthChart() async {
    try {
      final days = _getDaysForPeriod();
      final now = DateTime.now();
      final startDate = now.subtract(Duration(days: days));

      final handymen = await _firestore
          .collection('handymen')
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
          )
          .orderBy('createdAt')
          .get();

      // Group by day
      Map<int, int> dailyHandymen = {};

      for (var doc in handymen.docs) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

        if (createdAt != null) {
          final dayIndex = createdAt.difference(startDate).inDays;
          dailyHandymen[dayIndex] = (dailyHandymen[dayIndex] ?? 0) + 1;
        }
      }

      // Convert to cumulative
      int cumulative = 0;
      List<FlSpot> spots = [];
      for (int i = 0; i <= days; i++) {
        cumulative += dailyHandymen[i] ?? 0;
        spots.add(FlSpot(i.toDouble(), cumulative.toDouble()));
      }

      setState(() {
        _handymenData = spots;
      });
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading user growth chart: $e');
    }
  }

  Future<void> _loadBookingsChart() async {
    try {
      final days = _getDaysForPeriod();
      final now = DateTime.now();
      final startDate = now.subtract(Duration(days: days));

      final bookings = await _firestore
          .collection('bookings')
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
          )
          .orderBy('createdAt')
          .get();

      // Group by day
      Map<int, int> dailyBookings = {};

      for (var doc in bookings.docs) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

        if (createdAt != null) {
          final dayIndex = createdAt.difference(startDate).inDays;
          dailyBookings[dayIndex] = (dailyBookings[dayIndex] ?? 0) + 1;
        }
      }

      setState(() {
        _bookingsData =
            dailyBookings.entries
                .map((e) => FlSpot(e.key.toDouble(), e.value.toDouble()))
                .toList()
              ..sort((a, b) => a.x.compareTo(b.x));
      });
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading bookings chart: $e');
    }
  }

  Future<void> _loadBookingsByStatus() async {
    try {
      // Cap at 2000 to avoid loading the entire collection for analytics.
      // For accurate totals at scale, use Firestore aggregation queries.
      final bookings = await _firestore.collection('bookings').limit(2000).get();

      Map<String, int> statusCount = {};

      for (var doc in bookings.docs) {
        final status = doc.data()['status'] ?? 'unknown';
        statusCount[status] = (statusCount[status] ?? 0) + 1;
      }

      setState(() {
        _bookingsByStatus = statusCount;
      });
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading bookings by status: $e');
    }
  }

  Future<void> _loadTopCities() async {
    try {
      final handymen = await _firestore.collection('handymen').limit(2000).get();

      Map<String, int> cityCount = {};

      for (var doc in handymen.docs) {
        final city = doc.data()['city'] ?? 'Unknown';
        cityCount[city] = (cityCount[city] ?? 0) + 1;
      }

      // Sort and take top 5
      final sorted = cityCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      setState(() {
        _topCities = Map.fromEntries(sorted.take(5));
      });
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading top cities: $e');
    }
  }

  int _getDaysForPeriod() {
    switch (_selectedPeriod) {
      case '7days':
        return 7;
      case '30days':
        return 30;
      case '90days':
        return 90;
      default:
        return 365;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: deepNavy,
      appBar: _buildAppBar(),
      body: _isLoading ? _buildLoading() : _buildContent(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: charcoal,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: softWhite),
        onPressed: () => Get.back(),
      ),
      title: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primaryGold.withOpacity(0.2),
                  primaryGold.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.analytics, color: primaryGold, size: 20),
          ),
          SizedBox(width: 12),
          Text(
            'Analytics',
            style: TextStyle(
              color: softWhite,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(primaryGold),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPeriodSelector(),
          SizedBox(height: 24),
          _buildRevenueChart(),
          SizedBox(height: 20),
          _buildUserGrowthChart(),
          SizedBox(height: 20),
          _buildBookingsChart(),
          SizedBox(height: 20),
          _buildBookingsStatusPieChart(),
          SizedBox(height: 20),
          _buildTopCitiesChart(),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildPeriodChip('7 Days', '7days'),
          SizedBox(width: 12),
          _buildPeriodChip('30 Days', '30days'),
          SizedBox(width: 12),
          _buildPeriodChip('90 Days', '90days'),
          SizedBox(width: 12),
          _buildPeriodChip('All Time', 'all'),
        ],
      ),
    );
  }

  Widget _buildPeriodChip(String label, String value) {
    final isSelected = _selectedPeriod == value;

    return InkWell(
      onTap: () {
        setState(() => _selectedPeriod = value);
        _loadAnalytics();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(colors: [primaryGold, Color(0xFFFFD700)])
              : null,
          color: isSelected ? null : charcoal,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : primaryGold.withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? deepNavy : softWhite,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildRevenueChart() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [charcoal, deepNavy]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryGold.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.attach_money, color: primaryGold, size: 24),
              SizedBox(width: 12),
              Text(
                'Revenue Trend',
                style: TextStyle(
                  color: softWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: _revenueData.isEmpty
                ? Center(
                    child: Text(
                      'No data',
                      style: TextStyle(color: softWhite.withOpacity(0.5)),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 1,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: softWhite.withOpacity(0.1),
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                '${value.toInt()}d',
                                style: TextStyle(
                                  color: softWhite.withOpacity(0.5),
                                  fontSize: 10,
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                '\$${value.toInt()}',
                                style: TextStyle(
                                  color: softWhite.withOpacity(0.5),
                                  fontSize: 10,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: _revenueData,
                          isCurved: true,
                          gradient: LinearGradient(
                            colors: [primaryGold, Color(0xFFFFD700)],
                          ),
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                primaryGold.withOpacity(0.3),
                                primaryGold.withOpacity(0.0),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserGrowthChart() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [charcoal, deepNavy]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentBlue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up, color: accentBlue, size: 24),
              SizedBox(width: 12),
              Text(
                'Handymen Growth',
                style: TextStyle(
                  color: softWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: _handymenData.isEmpty
                ? Center(
                    child: Text(
                      'No data',
                      style: TextStyle(color: softWhite.withOpacity(0.5)),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: softWhite.withOpacity(0.1),
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                '${value.toInt()}d',
                                style: TextStyle(
                                  color: softWhite.withOpacity(0.5),
                                  fontSize: 10,
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                '${value.toInt()}',
                                style: TextStyle(
                                  color: softWhite.withOpacity(0.5),
                                  fontSize: 10,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: _handymenData,
                          isCurved: true,
                          gradient: LinearGradient(
                            colors: [accentBlue, accentBlue.withOpacity(0.7)],
                          ),
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                accentBlue.withOpacity(0.3),
                                accentBlue.withOpacity(0.0),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingsChart() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [charcoal, deepNavy]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentGreen.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.work_history, color: accentGreen, size: 24),
              SizedBox(width: 12),
              Text(
                'Bookings Trend',
                style: TextStyle(
                  color: softWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: _bookingsData.isEmpty
                ? Center(
                    child: Text(
                      'No data',
                      style: TextStyle(color: softWhite.withOpacity(0.5)),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: softWhite.withOpacity(0.1),
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                '${value.toInt()}d',
                                style: TextStyle(
                                  color: softWhite.withOpacity(0.5),
                                  fontSize: 10,
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                '${value.toInt()}',
                                style: TextStyle(
                                  color: softWhite.withOpacity(0.5),
                                  fontSize: 10,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: _bookingsData,
                          isCurved: true,
                          gradient: LinearGradient(
                            colors: [accentGreen, accentGreen.withOpacity(0.7)],
                          ),
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                accentGreen.withOpacity(0.3),
                                accentGreen.withOpacity(0.0),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingsStatusPieChart() {
    if (_bookingsByStatus.isEmpty) {
      return SizedBox.shrink();
    }

    final colors = [
      accentGreen,
      accentBlue,
      accentOrange,
      accentRed,
      accentPurple,
    ];
    int colorIndex = 0;

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [charcoal, deepNavy]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentPurple.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pie_chart, color: accentPurple, size: 24),
              SizedBox(width: 12),
              Text(
                'Bookings by Status',
                style: TextStyle(
                  color: softWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: _bookingsByStatus.entries.map((entry) {
                        final color = colors[colorIndex % colors.length];
                        colorIndex++;

                        return PieChartSectionData(
                          value: entry.value.toDouble(),
                          title: '${entry.value}',
                          color: color,
                          radius: 50,
                          titleStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _bookingsByStatus.entries.map((entry) {
                      colorIndex = 0;
                      final entryColorIndex = _bookingsByStatus.keys
                          .toList()
                          .indexOf(entry.key);
                      final color = colors[entryColorIndex % colors.length];

                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                entry.key,
                                style: TextStyle(
                                  color: softWhite.withOpacity(0.7),
                                  fontSize: 11,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopCitiesChart() {
    if (_topCities.isEmpty) {
      return SizedBox.shrink();
    }

    final maxValue = _topCities.values.reduce((a, b) => a > b ? a : b);

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [charcoal, deepNavy]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentOrange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_city, color: accentOrange, size: 24),
              SizedBox(width: 12),
              Text(
                'Top Cities',
                style: TextStyle(
                  color: softWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          ..._topCities.entries.map((entry) {
            final percentage = (entry.value / maxValue);

            return Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.key,
                        style: TextStyle(
                          color: softWhite,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${entry.value}',
                        style: TextStyle(
                          color: accentOrange,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percentage,
                      backgroundColor: softWhite.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(accentOrange),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
