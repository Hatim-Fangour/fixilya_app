import 'package:fixilya_app/core/constants/app_colors.dart';
import 'package:fixilya_app/core/constants/app_icons.dart';
import 'package:fixilya_app/data/notifiers.dart';
import 'package:flutter/material.dart';

class NavBarWidget extends StatefulWidget {
  final String userType; // ✅ Add user type parameter

  const NavBarWidget({
    super.key,
    required this.userType, // ✅ Required parameter
  });

  @override
  State<NavBarWidget> createState() => _NavBarWidgetState();
}

class _NavBarWidgetState extends State<NavBarWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  // Colors
  static const primaryColor = Color.fromRGBO(83, 110, 254, 1);
  static const secondaryColor = Color.fromRGBO(110, 133, 255, 1);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // ✅ Dynamic nav items based on user type
  List<Map<String, dynamic>> get _navItems {
    if (widget.userType == 'client') {
      return [
        {'icon': SocialIcons.home, 'label': 'Home', 'index': 0},
        {'icon': SocialIcons.profile, 'label': 'Profile', 'index': 1},
      ];
    } else {
      // Handyman
      return [
        {'icon': SocialIcons.home, 'label': 'Home', 'index': 0},
        {'icon': SocialIcons.profile, 'label': 'Profile', 'index': 1},
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: selectedPageNotifier,
      builder: (BuildContext context, dynamic selectedPage, Widget? child) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceColor(context),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowColor(context),
                blurRadius: 20,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Container(
              height: 65,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: _navItems
                    .map(
                      (item) => _buildNavItem(
                        icon: item['icon'],
                        label: item['label'],
                        index: item['index'],
                        isSelected: selectedPage == item['index'],
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    required bool isSelected,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          selectedPageNotifier.value = index;
          _animationController.forward(from: 0);
        },
        child: AnimatedContainer(
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(colors: [primaryColor, secondaryColor])
                : null,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.3),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: isSelected ? 1.1 : 1.0,
                duration: Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: Icon(
                  icon,
                  size: 18,
                  color: isSelected ? Colors.white : Colors.grey[600],
                ),
              ),
              if (isSelected) ...[
                SizedBox(width: 8),
                AnimatedOpacity(
                  opacity: isSelected ? 1.0 : 0.0,
                  duration: Duration(milliseconds: 300),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
