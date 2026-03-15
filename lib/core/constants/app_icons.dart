// lib/core/constants/app_icons.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// General-purpose app icons used across the application.
class AppIcons {
  AppIcons._();

  // Navigation
  static const home = Icons.home_outlined;
  static const homeFilled = Icons.home;
  static const search = Icons.search;
  static const bookings = Icons.calendar_today_outlined;
  static const bookingsFilled = Icons.calendar_today;
  static const messages = Icons.chat_bubble_outline;
  static const messagesFilled = Icons.chat_bubble;
  static const profile = Icons.person_outline;
  static const profileFilled = Icons.person;
  static const notifications = Icons.notifications_outlined;
  static const notificationsFilled = Icons.notifications;
  static const settings = Icons.settings_outlined;

  // Actions
  static const add = Icons.add;
  static const edit = Icons.edit_outlined;
  static const delete = Icons.delete_outline;
  static const close = Icons.close;
  static const back = Icons.arrow_back;
  static const forward = Icons.arrow_forward;
  static const share = Icons.share_outlined;
  static const favorite = Icons.favorite_border;
  static const favoriteFilled = Icons.favorite;
  static const filter = Icons.filter_list;
  static const sort = Icons.sort;
  static const refresh = Icons.refresh;
  static const camera = Icons.camera_alt_outlined;
  static const gallery = Icons.photo_library_outlined;
  static const call = Icons.call_outlined;
  static const location = Icons.location_on_outlined;
  static const star = Icons.star;
  static const starBorder = Icons.star_border;
  static const check = Icons.check;
  static const error = Icons.error_outline;
  static const info = Icons.info_outline;
  static const warning = Icons.warning_amber;
  static const copy = Icons.copy;
  static const visibility = Icons.visibility_outlined;
  static const visibilityOff = Icons.visibility_off_outlined;
  static const darkMode = Icons.dark_mode_outlined;
  static const lightMode = Icons.light_mode_outlined;
  static const language = Icons.language;
  static const logout = Icons.logout;
  static const help = Icons.help_outline;
  static const about = Icons.info_outline;
  static const privacy = Icons.privacy_tip_outlined;
  static const terms = Icons.description_outlined;
}

class SocialIcons {
  SocialIcons._();

  // Navigation
  static final home = FontAwesomeIcons.house;
  static final profile = FontAwesomeIcons.user;

  // Social Media Platforms
  static final facebook = FontAwesomeIcons.facebook;
  static final twitter = FontAwesomeIcons.twitter;
  static final instagram = FontAwesomeIcons.instagram;
  static final linkedin = FontAwesomeIcons.linkedin;
  static final youtube = FontAwesomeIcons.youtube;
  static final tiktok = FontAwesomeIcons.tiktok;

  // Messaging
  static final whatsapp = FontAwesomeIcons.whatsapp;
  static final telegram = FontAwesomeIcons.telegram;
  static final messenger = FontAwesomeIcons.facebookMessenger;

  // Tech Companies
  static final google = FontAwesomeIcons.google;
  static final apple = FontAwesomeIcons.apple;
  static final microsoft = FontAwesomeIcons.microsoft;
  static final android = FontAwesomeIcons.android;

  // Development
  static final github = FontAwesomeIcons.github;
  static final gitlab = FontAwesomeIcons.gitlab;
  static final stackoverflow = FontAwesomeIcons.stackOverflow;

  // Payment
  static final paypal = FontAwesomeIcons.paypal;
  static final stripe = FontAwesomeIcons.stripe;

  // Others
  static final spotify = FontAwesomeIcons.spotify;
  static final discord = FontAwesomeIcons.discord;
  static final reddit = FontAwesomeIcons.reddit;
  static final twitch = FontAwesomeIcons.twitch;
}

class SocialColors {
  static final facebook = Color(0xFF1877F2);
  static final twitter = Color(0xFF1DA1F2);
  static final instagram = Color(0xFFE4405F);
  static final linkedin = Color(0xFF0A66C2);
  static final youtube = Color(0xFFFF0000);
  static final whatsapp = Color(0xFF25D366);
  static final google = Color(0xFFDB4437);
  static final apple = Color(0xFF000000);
  static final github = Color(0xFF181717);
}
