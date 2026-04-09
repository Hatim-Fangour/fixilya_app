import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class PaymentsPage extends StatefulWidget {
  const PaymentsPage({super.key});

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage>
    with SingleTickerProviderStateMixin {
  static const primaryColor = Color.fromRGBO(83, 110, 254, 1);
  static const secondaryColor = Color.fromRGBO(110, 133, 255, 1);
  static const accentColor = Color.fromRGBO(147, 167, 255, 1);

  late AnimationController _animationController;

  final List<Map<String, dynamic>> _paymentMethods = [
    {
      'id': '1',
      'type': 'Credit Card',
      'detail': '•••• 4242',
      'cardHolder': 'Hassan Alami',
      'expiry': '12/26',
      'icon': FontAwesomeIcons.creditCard,
      'isDefault': true,
    },
    {
      'id': '2',
      'type': 'Bank Account',
      'detail': 'BMCE •••• 1234',
      'cardHolder': 'Hassan Alami',
      'expiry': '',
      'icon': FontAwesomeIcons.buildingColumns,
      'isDefault': false,
    },
    {
      'id': '3',
      'type': 'Cash',
      'detail': 'Pay on delivery',
      'cardHolder': '',
      'expiry': '',
      'icon': FontAwesomeIcons.moneyBill,
      'isDefault': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _setDefaultPayment(String id) {
    setState(() {
      for (var method in _paymentMethods) {
        method['isDefault'] = method['id'] == id;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Text('Default payment method updated'),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _deletePaymentMethod(String id) {
    final method = _paymentMethods.firstWhere((m) => m['id'] == id);

    if (method['isDefault']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Text('Cannot delete default payment method'),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.delete_outline, color: Colors.red, size: 24),
            ),
            SizedBox(width: 12),
            Text('Delete Payment Method'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete ${method['type']}?',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[700])),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _paymentMethods.removeWhere((m) => m['id'] == id);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Payment method deleted'),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddPaymentMethodDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddPaymentMethodSheet(
        onAdd: (Map<String, dynamic> newMethod) {
          setState(() {
            _paymentMethods.add(newMethod);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Text('Payment method added successfully'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showPaymentMethodDetails(Map<String, dynamic> method) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
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
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [primaryColor, secondaryColor],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: FaIcon(
                          method['icon'],
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                    SizedBox(height: 24),
                    Center(
                      child: Text(
                        method['type'],
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    if (method['isDefault']) ...[
                      SizedBox(height: 8),
                      Center(
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Default Payment Method',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: primaryColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                    SizedBox(height: 32),
                    if (method['cardHolder'].isNotEmpty) ...[
                      _buildDetailRow('Card Holder', method['cardHolder']),
                      SizedBox(height: 16),
                    ],
                    _buildDetailRow('Account Number', method['detail']),
                    if (method['expiry'].isNotEmpty) ...[
                      SizedBox(height: 16),
                      _buildDetailRow('Expiry Date', method['expiry']),
                    ],
                    SizedBox(height: 32),
                    if (!method['isDefault'])
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _setDefaultPayment(method['id']);
                          },
                          icon: Icon(Icons.check_circle_outline),
                          label: Text('Set as Default'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    if (!method['isDefault']) SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _deletePaymentMethod(method['id']);
                        },
                        icon: Icon(Icons.delete_outline, color: Colors.red),
                        label: Text(
                          'Remove Payment Method',
                          style: TextStyle(color: Colors.red),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.red),
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
    return Row(
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
    );
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
                                FontAwesomeIcons.creditCard,
                                color: primaryColor,
                                size: 24,
                              ),
                            ),
                            SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Payment Methods',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  '${_paymentMethods.length} methods',
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
            child: FadeTransition(
              opacity: _animationController,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ..._paymentMethods
                        .map((method) => _buildPaymentMethodCard(method))
                        ,
                    SizedBox(height: 16),
                    _buildAddPaymentButton(),
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

  Widget _buildPaymentMethodCard(Map<String, dynamic> method) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: method['isDefault'] ? primaryColor : Colors.grey.shade200,
          width: method['isDefault'] ? 2 : 1,
        ),
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
          onTap: () => _showPaymentMethodDetails(method),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: FaIcon(method['icon'], color: primaryColor, size: 24),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            method['type'],
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (method['isDefault']) ...[
                            SizedBox(width: 8),
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
                                'Default',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        method['detail'],
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddPaymentButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [primaryColor, secondaryColor]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 15,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _showAddPaymentMethodDialog,
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, color: Colors.white, size: 24),
                SizedBox(width: 12),
                Text(
                  'Add Payment Method',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
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

// ============================================
// ADD PAYMENT METHOD SHEET
// ============================================

class _AddPaymentMethodSheet extends StatefulWidget {
  final Function(Map<String, dynamic>) onAdd;

  const _AddPaymentMethodSheet({required this.onAdd});

  @override
  State<_AddPaymentMethodSheet> createState() => _AddPaymentMethodSheetState();
}

class _AddPaymentMethodSheetState extends State<_AddPaymentMethodSheet> {
  static const primaryColor = Color.fromRGBO(83, 110, 254, 1);
  static const secondaryColor = Color.fromRGBO(110, 133, 255, 1);

  final _formKey = GlobalKey<FormState>();
  String _selectedType = 'Credit Card';
  final _cardNumberController = TextEditingController();
  final _cardHolderController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();

  final List<Map<String, dynamic>> _paymentTypes = [
    {'name': 'Credit Card', 'icon': FontAwesomeIcons.creditCard},
    {'name': 'Debit Card', 'icon': FontAwesomeIcons.creditCard},
    {'name': 'Bank Account', 'icon': FontAwesomeIcons.buildingColumns},
  ];

  @override
  void dispose() {
    _cardNumberController.dispose();
    _cardHolderController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  void _submitPaymentMethod() {
    if (_formKey.currentState!.validate()) {
      final newMethod = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'type': _selectedType,
        'detail':
            '•••• ${_cardNumberController.text.substring(_cardNumberController.text.length - 4)}',
        'cardHolder': _cardHolderController.text,
        'expiry': _expiryController.text,
        'icon': _paymentTypes.firstWhere(
          (t) => t['name'] == _selectedType,
        )['icon'],
        'isDefault': false,
      };

      widget.onAdd(newMethod);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
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
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryColor, secondaryColor],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.add, color: Colors.white, size: 24),
                ),
                SizedBox(width: 12),
                Text(
                  'Add Payment Method',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Payment Type Selection
                    Text(
                      'Payment Type',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 12),
                    ..._paymentTypes.map((type) {
                      final isSelected = _selectedType == type['name'];
                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedType = type['name']);
                        },
                        child: Container(
                          margin: EdgeInsets.only(bottom: 12),
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? primaryColor.withOpacity(0.1)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? primaryColor
                                  : Colors.grey.shade300,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              FaIcon(
                                type['icon'],
                                color: isSelected
                                    ? primaryColor
                                    : Colors.grey[600],
                                size: 20,
                              ),
                              SizedBox(width: 12),
                              Text(
                                type['name'],
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? primaryColor
                                      : Colors.black87,
                                ),
                              ),
                              Spacer(),
                              if (isSelected)
                                Icon(
                                  Icons.check_circle,
                                  color: primaryColor,
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      );
                    }),

                    SizedBox(height: 24),

                    // Card Number
                    TextFormField(
                      controller: _cardNumberController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Card Number',
                        prefixIcon: Icon(
                          Icons.credit_card,
                          color: primaryColor,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: primaryColor, width: 2),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter card number';
                        }
                        if (value.length < 16) {
                          return 'Card number must be 16 digits';
                        }
                        return null;
                      },
                    ),

                    SizedBox(height: 16),

                    // Card Holder
                    TextFormField(
                      controller: _cardHolderController,
                      decoration: InputDecoration(
                        labelText: 'Card Holder Name',
                        prefixIcon: Icon(Icons.person, color: primaryColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: primaryColor, width: 2),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter card holder name';
                        }
                        return null;
                      },
                    ),

                    SizedBox(height: 16),

                    // Expiry and CVV
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _expiryController,
                            keyboardType: TextInputType.datetime,
                            decoration: InputDecoration(
                              labelText: 'Expiry (MM/YY)',
                              prefixIcon: Icon(
                                Icons.calendar_today,
                                color: primaryColor,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: primaryColor,
                                  width: 2,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Required';
                              }
                              return null;
                            },
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _cvvController,
                            keyboardType: TextInputType.number,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: 'CVV',
                              prefixIcon: Icon(Icons.lock, color: primaryColor),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: primaryColor,
                                  width: 2,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Required';
                              }
                              if (value.length != 3) {
                                return 'Invalid CVV';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 32),

                    // Add Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _submitPaymentMethod,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Add Payment Method',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
