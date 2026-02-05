/// Shared Widget - Custom App Bar
/// Reusable app bar component with gradient and customization
///
/// Features:
/// - Gradient background
/// - Custom title and actions
/// - Optional leading widget
/// - Elevation control
/// - Search functionality
/// - Flexible styling

import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;
  final double elevation;
  final bool showBackButton;
  final VoidCallback? onBackPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool useGradient;
  final PreferredSizeWidget? bottom;
  final double toolbarHeight;

  const CustomAppBar({
    Key? key,
    this.title,
    this.titleWidget,
    this.actions,
    this.leading,
    this.centerTitle = true,
    this.elevation = 0,
    this.showBackButton = true,
    this.onBackPressed,
    this.backgroundColor,
    this.foregroundColor,
    this.useGradient = true,
    this.bottom,
    this.toolbarHeight = kToolbarHeight,
  }) : super(key: key);

  @override
  Size get preferredSize =>
      Size.fromHeight(toolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget? leadingWidget = leading;
    if (leadingWidget == null && showBackButton && Navigator.canPop(context)) {
      leadingWidget = IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new,
          color: foregroundColor ?? Colors.white,
        ),
        onPressed: onBackPressed ?? () => Navigator.pop(context),
      );
    }

    final appBar = AppBar(
      title:
          titleWidget ??
          (title != null
              ? Text(
                  title!,
                  style: TextStyle(
                    color: foregroundColor ?? Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                )
              : null),
      leading: leadingWidget,
      actions: actions,
      centerTitle: centerTitle,
      elevation: elevation,
      backgroundColor: Colors.transparent,
      foregroundColor: foregroundColor ?? Colors.white,
      bottom: bottom,
      toolbarHeight: toolbarHeight,
    );

    if (useGradient) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              backgroundColor ?? const Color(0xFF536EFE),
              const Color(0xFF7C4DFF),
            ],
          ),
        ),
        child: appBar,
      );
    }

    return Container(
      color: backgroundColor ?? theme.primaryColor,
      child: appBar,
    );
  }
}

/// Search App Bar variant
class SearchAppBar extends StatelessWidget implements PreferredSizeWidget {
  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSearch;
  final VoidCallback? onClear;
  final bool autofocus;

  const SearchAppBar({
    Key? key,
    this.controller,
    this.hintText = 'Search...',
    this.onChanged,
    this.onSearch,
    this.onClear,
    this.autofocus = false,
  }) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Theme.of(context).primaryColor,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      title: TextField(
        controller: controller,
        autofocus: autofocus,
        onChanged: onChanged,
        onSubmitted: (_) => onSearch?.call(),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
          border: InputBorder.none,
          suffixIcon: controller?.text.isNotEmpty ?? false
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white),
                  onPressed: () {
                    controller?.clear();
                    onClear?.call();
                  },
                )
              : null,
        ),
      ),
      actions: [
        if (onSearch != null)
          IconButton(icon: const Icon(Icons.search), onPressed: onSearch),
      ],
    );
  }
}
