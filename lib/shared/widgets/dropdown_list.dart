import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:flutter/material.dart';

// Controller class
class GenericDropdownController<T> extends ChangeNotifier {
  T? _value;
  String? _errorText;
  bool _isValid = true;

  GenericDropdownController({T? initialValue}) : _value = initialValue;

  T? get value => _value;
  String? get errorText => _errorText;
  bool get isValid => _isValid;

  /// Check if no value is selected
  bool get isEmpty => _value == null;

  /// Check if a value is selected
  bool get isNotEmpty => _value != null;

  void setValue(T? newValue) {
    if (_value != newValue) {
      _value = newValue;
      _errorText = null;
      _isValid = true;
      notifyListeners();
    }
  }

  void setError(String error) {
    _errorText = error;
    _isValid = false;
    notifyListeners();
  }

  void clearError() {
    _errorText = null;
    _isValid = true;
    notifyListeners();
  }

  void clear() {
    _value = null;
    _errorText = null;
    _isValid = true;
    notifyListeners();
  }

  /// Reset to initial value if provided
  void reset({T? newInitialValue}) {
    _value = newInitialValue;
    _errorText = null;
    _isValid = true;
    notifyListeners();
  }

}

// Widget class
class GenericDropdown<T> extends StatefulWidget {
  final List<T> items;
  final T? value;
  final String label;
  final String hint;
  final String Function(T) itemLabel;
  final void Function(T?)? onChanged;
  final String? Function(T?)? validator;
  final bool enabled;
  final GenericDropdownController<T>? controller;
  final FocusNode? focusNode;
  final bool autovalidate;
  final IconData? prefixIcon;
  final Color? primaryColor;
  final Color? secondaryColor;
  final bool showLabelInPreview;
  final bool isEditing;

  const GenericDropdown({
    super.key,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    required this.label,
    required this.hint,
    this.value,
    this.validator,
    this.enabled = true,
    this.controller,
    this.focusNode,
    this.autovalidate = false,
    this.prefixIcon,
    this.primaryColor,
    this.secondaryColor,
    this.showLabelInPreview = true,
    this.isEditing = true,
  });

  @override
  State<GenericDropdown<T>> createState() => _GenericDropdownState<T>();
}

class _GenericDropdownState<T> extends State<GenericDropdown<T>> {
  T? _currentValue;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _currentValue = _getSafeValue(widget.value ?? widget.controller?.value);
    _focusNode = widget.focusNode ?? FocusNode();

    // Listen to controller changes
    widget.controller?.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant GenericDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Remove old listener
    oldWidget.controller?.removeListener(_onControllerChanged);

    // Add new listener
    widget.controller?.addListener(_onControllerChanged);

    // Update value if widget value changed
    if (widget.value != oldWidget.value && widget.value != _currentValue) {
      setState(() {
        _currentValue = _getSafeValue(widget.value);
      });
      widget.controller?.setValue(_currentValue);
    }
  }

  void _onControllerChanged() {
    final safeValue = _getSafeValue(widget.controller?.value);
    if (safeValue != _currentValue) {
      setState(() {
        _currentValue = safeValue;
      });
    }
  }

  // ✅ NEW: Validate that value exists in items
  T? _getSafeValue(T? value) {
    if (value == null) return null;

    // Check if value exists in items list
    if (widget.items.contains(value)) {
      return value;
    }

    // Value doesn't exist in items, return null
    print(
      '⚠️ Dropdown value "$value" not found in items list. Setting to null.',
    );
    return null;
  }

  void _handleOnChanged(T? newValue) {
    setState(() {
      _currentValue = newValue;
    });

    // Update controller if provided
    widget.controller?.setValue(newValue);

    // Call external onChanged
    if (widget.onChanged != null) {
      widget.onChanged!(newValue);
    }
  }

  String? _handleValidator(T? value) {
    if (widget.validator != null) {
      final error = widget.validator!(value);
      if (error != null) {
        widget.controller?.setError(error);
      } else {
        widget.controller?.clearError();
      }
      return error;
    }
    return null;
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onControllerChanged);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Ensure value is safe before building
    final safeValue = _getSafeValue(_currentValue);

    // Get theme safely in build method
    final theme = Theme.of(context);
    final effectivePrimaryColor = widget.primaryColor ?? theme.primaryColor;
    final effectiveSecondaryColor =
        widget.secondaryColor ?? theme.colorScheme.secondary;

    if (!widget.isEditing) {
      // Preview mode (non-editing)
      return Row(
        children: [
          if (widget.prefixIcon != null)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryColor.withValues(alpha: 0.1),
                    AppColors.secondaryColor.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                widget.prefixIcon,
                color: AppColors.primaryColor,
                size: 20,
              ),
            ),
          if (widget.prefixIcon != null) const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.showLabelInPreview)
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryColor(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                if (widget.showLabelInPreview) const SizedBox(height: 4),
                Text(
                  safeValue != null ? widget.itemLabel(safeValue) : widget.hint,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: safeValue != null
                        ? AppColors.textPrimaryColor(context)
                        : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Editing mode
    return Row(
      children: [
        if (widget.prefixIcon != null)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryColor.withValues(alpha: 0.1),
                  AppColors.secondaryColor.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              widget.prefixIcon,
              color: AppColors.primaryColor,
              size: 20,
            ),
          ),
        if (widget.prefixIcon != null) const SizedBox(width: 14),
        Expanded(
          child: DropdownButtonFormField<T>(
            initialValue: safeValue, // ✅ Use validated value
            focusNode: _focusNode,
            autovalidateMode: widget.autovalidate
                ? AutovalidateMode.onUserInteraction
                : AutovalidateMode.disabled,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textPrimaryColor(context),
            ),
            decoration: InputDecoration(
              labelText: widget.label,
              labelStyle: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondaryColor(context),
              ),
              hintText: widget.hint,
              hintStyle: TextStyle(fontSize: 14, color: Colors.grey[400]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primaryColor, width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 1),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              isDense: true,
              filled: !widget.enabled,
              fillColor: !widget.enabled
                  ? AppColors.textPrimaryColor(context)
                  : AppColors.textPrimaryColor(context),
              errorText: widget.controller?.errorText,
              errorStyle: const TextStyle(fontSize: 12, height: 1),
              errorMaxLines: 2,
            ),
            items: widget.items
                .map(
                  (item) => DropdownMenuItem<T>(
                    value: item,
                    child: Text(
                      widget.itemLabel(item),
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimaryColor(context),
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: widget.enabled ? _handleOnChanged : null,
            validator: _handleValidator,
            isExpanded: true,
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.primaryColor,
            ),
            dropdownColor: AppColors.surfaceColor(context),
            menuMaxHeight: 300,
            borderRadius: BorderRadius.circular(12),
            elevation: 4,
            selectedItemBuilder: (BuildContext context) {
              return widget.items.map<Widget>((T item) {
                return Text(
                  widget.itemLabel(item),
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimaryColor(context),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ],
    );
  }
}
