import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:fixilya_app/features/booking/presentation/controllers/booking_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Booking creation screen.
///
/// Allows a client to create a new booking by selecting a service type,
/// date/time, providing a location, description, and viewing an estimated cost.
class BookingScreen extends StatefulWidget {
  /// The handyman being booked (required for creating the booking).
  final String handymanId;
  final String handymanName;
  final double hourlyRate;

  const BookingScreen({
    super.key,
    required this.handymanId,
    required this.handymanName,
    required this.hourlyRate,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _locationController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedService = 'Plumbing';
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 10, minute: 0);
  int _estimatedDuration = 60;
  bool _isSubmitting = false;

  static const List<String> _serviceTypes = [
    'Plumbing',
    'Electrical Work',
    'Carpentry',
    'Painting',
    'Cleaning',
    'AC Repair',
    'Gardening',
    'Appliance Repair',
    'General Maintenance',
  ];

  static const List<int> _durationOptions = [30, 60, 90, 120, 180, 240];

  double get _estimatedCost =>
      widget.hourlyRate * (_estimatedDuration / 60);

  @override
  void dispose() {
    _locationController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _submitBooking() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final controller = Get.find<BookingController>();
    final timeStr =
        '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';

    final success = await controller.createBooking(
      handymanId: widget.handymanId,
      serviceType: _selectedService,
      serviceDescription: _descriptionController.text.trim().isNotEmpty
          ? _descriptionController.text.trim()
          : null,
      scheduledDate: _selectedDate,
      scheduledTime: timeStr,
      location: _locationController.text.trim(),
      address: _addressController.text.trim().isNotEmpty
          ? _addressController.text.trim()
          : null,
      hourlyRate: widget.hourlyRate,
      estimatedDuration: _estimatedDuration,
      clientNotes: _descriptionController.text.trim().isNotEmpty
          ? _descriptionController.text.trim()
          : null,
    );

    setState(() => _isSubmitting = false);

    if (success && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor(context),
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.textPrimaryColor(context),
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Book Service',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: AppColors.textPrimaryColor(context),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Handyman info header
            _buildHandymanHeader(),
            const SizedBox(height: 20),

            // Service type
            _buildSectionLabel('Service Type'),
            const SizedBox(height: 8),
            _buildServiceDropdown(),
            const SizedBox(height: 16),

            // Date and time
            _buildSectionLabel('Date & Time'),
            const SizedBox(height: 8),
            _buildDateTimePickers(),
            const SizedBox(height: 16),

            // Duration
            _buildSectionLabel('Estimated Duration'),
            const SizedBox(height: 8),
            _buildDurationDropdown(),
            const SizedBox(height: 16),

            // Location
            _buildSectionLabel('Location'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _locationController,
              hint: 'City or area (e.g., Casablanca)',
              icon: Icons.location_on_outlined,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Location is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _addressController,
              hint: 'Full address (optional)',
              icon: Icons.home_outlined,
            ),
            const SizedBox(height: 16),

            // Description
            _buildSectionLabel('Description (optional)'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _descriptionController,
              hint: 'Describe the work you need done...',
              icon: Icons.description_outlined,
              maxLines: 4,
            ),
            const SizedBox(height: 24),

            // Estimated cost card
            _buildEstimatedCostCard(),
            const SizedBox(height: 24),

            // Submit button
            _buildSubmitButton(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHandymanHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.subtleGradientThemed(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor(context)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primaryColor.withValues(alpha: 0.2),
            child: Text(
              widget.handymanName.isNotEmpty
                  ? widget.handymanName[0].toUpperCase()
                  : 'H',
              style: const TextStyle(
                color: AppColors.primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.handymanName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.textPrimaryColor(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.hourlyRate.toStringAsFixed(0)} DH/hr',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondaryColor(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 15,
        color: AppColors.textPrimaryColor(context),
      ),
    );
  }

  Widget _buildServiceDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.inputFillColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.inputBorderColor(context)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedService,
          isExpanded: true,
          dropdownColor: AppColors.cardColor(context),
          style: TextStyle(
            color: AppColors.textPrimaryColor(context),
            fontSize: 15,
          ),
          items: _serviceTypes
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (val) {
            if (val != null) setState(() => _selectedService = val);
          },
        ),
      ),
    );
  }

  Widget _buildDateTimePickers() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.inputFillColor(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.inputBorderColor(context)),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today,
                      size: 18, color: AppColors.primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                    style: TextStyle(
                      color: AppColors.textPrimaryColor(context),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: _pickTime,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.inputFillColor(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.inputBorderColor(context)),
              ),
              child: Row(
                children: [
                  Icon(Icons.access_time,
                      size: 18, color: AppColors.primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    _selectedTime.format(context),
                    style: TextStyle(
                      color: AppColors.textPrimaryColor(context),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDurationDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.inputFillColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.inputBorderColor(context)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _estimatedDuration,
          isExpanded: true,
          dropdownColor: AppColors.cardColor(context),
          style: TextStyle(
            color: AppColors.textPrimaryColor(context),
            fontSize: 15,
          ),
          items: _durationOptions.map((d) {
            final hours = d ~/ 60;
            final mins = d % 60;
            String label;
            if (hours > 0 && mins > 0) {
              label = '${hours}h ${mins}min';
            } else if (hours > 0) {
              label = '${hours}h';
            } else {
              label = '${mins}min';
            }
            return DropdownMenuItem(value: d, child: Text(label));
          }).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _estimatedDuration = val);
          },
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      style: TextStyle(
        color: AppColors.textPrimaryColor(context),
        fontSize: 15,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textHintColor(context)),
        prefixIcon: maxLines == 1
            ? Icon(icon, color: AppColors.primaryColor, size: 20)
            : null,
        filled: true,
        fillColor: AppColors.inputFillColor(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.inputBorderColor(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.inputBorderColor(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  Widget _buildEstimatedCostCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor(context)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLightColor(context),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Hourly Rate',
                style: TextStyle(
                  color: AppColors.textSecondaryColor(context),
                  fontSize: 14,
                ),
              ),
              Text(
                '${widget.hourlyRate.toStringAsFixed(0)} DH',
                style: TextStyle(
                  color: AppColors.textPrimaryColor(context),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Duration',
                style: TextStyle(
                  color: AppColors.textSecondaryColor(context),
                  fontSize: 14,
                ),
              ),
              Text(
                '$_estimatedDuration min',
                style: TextStyle(
                  color: AppColors.textPrimaryColor(context),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Estimated Total',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.textPrimaryColor(context),
                ),
              ),
              Text(
                '${_estimatedCost.toStringAsFixed(0)} DH',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppColors.primaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitBooking,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Confirm Booking',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
