import 'package:flutter/foundation.dart';
import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class InvoicesPage extends StatefulWidget {
  const InvoicesPage({super.key});

  @override
  State<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends State<InvoicesPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  // Premium Colors
  static const primaryColor = Color.fromRGBO(83, 110, 254, 1);
  static const secondaryColor = Color.fromRGBO(110, 133, 255, 1);
  static const accentColor = Color.fromRGBO(147, 167, 255, 1);

  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Paid', 'Pending', 'Overdue'];

  List<Map<String, dynamic>> _invoices = [];
  bool _isLoading = true;

  // final List<Map<String, dynamic>> _invoices = [
  //   {
  //     'id': 'INV-001',
  //     'handyman': 'Ahmed El Fassi',
  //     'service': 'Electrical Work',
  //     'date': 'Jan 15, 2026',
  //     'amount': 450.0,
  //     'status': 'Paid',
  //     'paymentMethod': 'Credit Card',
  //     'dueDate': 'Jan 15, 2026',
  //   },
  //   {
  //     'id': 'INV-002',
  //     'handyman': 'Youssef Bennani',
  //     'service': 'Carpentry',
  //     'date': 'Jan 10, 2026',
  //     'amount': 720.0,
  //     'status': 'Paid',
  //     'paymentMethod': 'Cash',
  //     'dueDate': 'Jan 10, 2026',
  //   },
  //   {
  //     'id': 'INV-003',
  //     'handyman': 'Hamza Idrissi',
  //     'service': 'Plumbing',
  //     'date': 'Jan 20, 2026',
  //     'amount': 280.0,
  //     'status': 'Pending',
  //     'paymentMethod': 'Pending',
  //     'dueDate': 'Jan 25, 2026',
  //   },
  //   {
  //     'id': 'INV-004',
  //     'handyman': 'Mohammed Berrada',
  //     'service': 'Painting',
  //     'date': 'Dec 28, 2025',
  //     'amount': 1200.0,
  //     'status': 'Paid',
  //     'paymentMethod': 'Bank Transfer',
  //     'dueDate': 'Dec 28, 2025',
  //   },
  // ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _animationController.forward();
    _loadInvoices();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Paid':
        return Colors.green;
      case 'Pending':
        return Colors.orange;
      case 'Overdue':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  List<Map<String, dynamic>> get _filteredInvoices {
    if (_selectedFilter == 'All') return _invoices;
    return _invoices.where((inv) => inv['status'] == _selectedFilter).toList();
  }

  double get _totalAmount {
    return _filteredInvoices.fold(0.0, (sum, inv) => sum + inv['amount']);
  }

  double get _paidAmount {
    return _invoices
        .where((inv) => inv['status'] == 'Paid')
        .fold(0.0, (sum, inv) => sum + inv['amount']);
  }

  double get _pendingAmount {
    return _invoices
        .where((inv) => inv['status'] == 'Pending')
        .fold(0.0, (sum, inv) => sum + inv['amount']);
  }

  Future<void> _loadInvoices() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (kDebugMode) debugPrint('❌ No user logged in');
        setState(() => _isLoading = false);
        return;
      }

      // Fetch completed bookings for this client
      final bookingsSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('clientId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'completed')
          .orderBy('completedAt', descending: true)
          .get();

      List<Map<String, dynamic>> invoices = [];

      for (var doc in bookingsSnapshot.docs) {
        final data = doc.data();

        // Calculate status based on payment status or due date
        String status = 'Paid'; // Default for completed bookings

        // If you have payment tracking, use it:
        if (data['paymentStatus'] != null) {
          status = data['paymentStatus'];
        } else if (data['isPaid'] == false) {
          status = 'Pending';
        }

        invoices.add({
          'id': doc.id,
          'handyman': data['handymanName'] ?? 'Unknown',
          'service': data['service'] ?? 'Service',
          'date': _formatDate(data['completedAt']),
          'amount': (data['amount'] ?? 0).toDouble(),
          'status': status,
          'paymentMethod': data['paymentMethod'] ?? 'Cash',
          'dueDate': _formatDate(data['scheduledDate']),
          'bookingId': doc.id,
          'rawData': data,
        });
      }

      if (mounted) {
        setState(() {
          _invoices = invoices;
          _isLoading = false;
        });
      }

      if (kDebugMode) debugPrint('✅ Loaded ${_invoices.length} invoices');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error loading invoices: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ✅ ADD THIS HELPER METHOD
  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Recent';

    try {
      DateTime date;
      if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else if (timestamp is DateTime) {
        date = timestamp;
      } else {
        return 'Recent';
      }

      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];

      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (e) {
      return 'Recent';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // Premium App Bar
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            elevation: 0,
            backgroundColor: primaryColor,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: AppColors.subtleHeaderGradientThemed(context),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 60, 16, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: FaIcon(
                                FontAwesomeIcons.fileInvoice,
                                color: primaryColor,
                                size: 24,
                              ),
                            ),
                            SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Invoices',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  '${_filteredInvoices.length} total',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: _isLoading
                ? _buildLoadingState() // ✅ Show loading
                : FadeTransition(
                    opacity: _animationController,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Summary Cards
                          Row(
                            children: [
                              Expanded(
                                child: _buildSummaryCard(
                                  'Total',
                                  '${_totalAmount.toStringAsFixed(0)} DH',
                                  Colors.blue,
                                  FontAwesomeIcons.chartLine,
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: _buildSummaryCard(
                                  'Paid',
                                  '${_paidAmount.toStringAsFixed(0)} DH',
                                  Colors.green,
                                  FontAwesomeIcons.checkCircle,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildSummaryCard(
                                  'Pending',
                                  '${_pendingAmount.toStringAsFixed(0)} DH',
                                  Colors.orange,
                                  FontAwesomeIcons.clock,
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: _buildSummaryCard(
                                  'Invoices',
                                  '${_invoices.length}',
                                  primaryColor,
                                  FontAwesomeIcons.receipt,
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: 24),

                          // Filter Chips
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: _filters.map((filter) {
                                final isSelected = _selectedFilter == filter;
                                return Padding(
                                  padding: EdgeInsets.only(right: 8),
                                  child: FilterChip(
                                    label: Text(filter),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      setState(() => _selectedFilter = filter);
                                    },
                                    backgroundColor: Colors.white,
                                    selectedColor: primaryColor.withOpacity(
                                      0.2,
                                    ),
                                    labelStyle: TextStyle(
                                      color: isSelected
                                          ? primaryColor
                                          : Colors.grey[700],
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                    side: BorderSide(
                                      color: isSelected
                                          ? primaryColor
                                          : Colors.grey.shade300,
                                      width: isSelected ? 2 : 1,
                                    ),
                                    showCheckmark: false,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),

                          SizedBox(height: 20),

                          // Invoices List
                          ..._filteredInvoices
                              .map((invoice) => _buildInvoiceCard(invoice))
                              ,

                          SizedBox(height: 20),

                          if (_filteredInvoices.isEmpty)
                            _buildEmptyState()
                          else
                            // Invoices List
                            ..._filteredInvoices
                                .map((invoice) => _buildInvoiceCard(invoice))
                                ,

                          SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return SizedBox(
      height: 400,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
            ),
            SizedBox(height: 20),
            Text(
              'Loading invoices...',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SizedBox(
      height: 400,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: FaIcon(
                FontAwesomeIcons.fileInvoice,
                size: 48,
                color: primaryColor,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'No invoices yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Complete bookings to see invoices',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: FaIcon(icon, color: color, size: 18),
          ),
          SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceCard(Map<String, dynamic> invoice) {
    final status = invoice['status'];
    final statusColor = _getStatusColor(status);

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showInvoiceDetails(invoice),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  invoice['id'],
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),
                              ),
                              SizedBox(width: 8),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Text(
                            invoice['handyman'],
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            invoice['service'],
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${invoice['amount'].toStringAsFixed(0)} DH',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          invoice['date'],
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Divider(height: 1, color: Colors.grey.shade200),
                SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.payment, size: 16, color: Colors.grey),
                    SizedBox(width: 6),
                    Text(
                      invoice['paymentMethod'],
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                    Spacer(),
                    Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                    SizedBox(width: 6),
                    Text(
                      'Due: ${invoice['dueDate']}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showInvoiceDetails(Map<String, dynamic> invoice) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        child: Column(
          children: [
            SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [primaryColor, secondaryColor],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: FaIcon(
                          FontAwesomeIcons.fileInvoice,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    Center(
                      child: Text(
                        invoice['id'],
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    SizedBox(height: 8),
                    Center(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(
                            invoice['status'],
                          ).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          invoice['status'],
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _getStatusColor(invoice['status']),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 32),
                    _buildDetailRow('Handyman', invoice['handyman']),
                    _buildDetailRow('Service', invoice['service']),
                    _buildDetailRow('Date', invoice['date']),
                    _buildDetailRow('Due Date', invoice['dueDate']),
                    _buildDetailRow('Payment Method', invoice['paymentMethod']),
                    SizedBox(height: 24),
                    Divider(),
                    SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Amount',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          '${invoice['amount'].toStringAsFixed(0)} DH',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 32),
                    if (invoice['status'] == 'Pending')
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Payment processed successfully!',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            'Pay Now',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: Icon(Icons.download),
                        label: Text('Download PDF'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryColor,
                          side: BorderSide(color: primaryColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
