import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fixilya_app/core/config/app_config.dart';
import 'package:fixilya_app/core/config/global_variables.dart';
import 'package:flutter/foundation.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Manages app-wide configuration (cities & skills) via the backend API.
/// The backend uses the Firebase Admin SDK, so Firestore security rules
/// do not apply — admin writes always succeed regardless of client rules.
class AppConfigService {
  static final AppConfigService _instance = AppConfigService._internal();
  factory AppConfigService() => _instance;
  AppConfigService._internal();

  // ── Icon registry ──────────────────────────────────────────────────────────
  static final Map<String, dynamic> iconMap = {
    'briefcase':    FontAwesomeIcons.briefcase,
    'faucet':       FontAwesomeIcons.faucet,
    'bolt':         FontAwesomeIcons.bolt,
    'hammer':       FontAwesomeIcons.hammer,
    'paintRoller':  FontAwesomeIcons.paintRoller,
    'cubesStacked': FontAwesomeIcons.cubesStacked,
    'building':     FontAwesomeIcons.building,
    'broom':        FontAwesomeIcons.broom,
    'seedling':     FontAwesomeIcons.seedling,
    'wrench':       FontAwesomeIcons.wrench,
    'cubes':        FontAwesomeIcons.cubes,
    'home':         FontAwesomeIcons.house,
    'thLarge':      FontAwesomeIcons.tableList,
    'snowflake':    FontAwesomeIcons.snowflake,
    'plug':         FontAwesomeIcons.plug,
    'house':        FontAwesomeIcons.house,
    'star':         FontAwesomeIcons.star,
    'tools':        FontAwesomeIcons.screwdriverWrench,
    'fire':         FontAwesomeIcons.fire,
    'leaf':         FontAwesomeIcons.leaf,
  };

  static String iconNameFor(dynamic icon) {
    return iconMap.entries
        .firstWhere(
          (e) => e.value == icon,
          orElse: () => MapEntry('wrench', FontAwesomeIcons.wrench),
        )
        .key;
  }

  // ── Dio instance with Firebase token ───────────────────────────────────────

  Future<Dio> _dio() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    final dio = Dio(BaseOptions(
      baseUrl: '${AppConfig.userServiceUrl}/users/config',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    ));
    return dio;
  }

  // ── Cities ─────────────────────────────────────────────────────────────────

  Future<List<String>> getCities() async {
    try {
      final dio = await _dio();
      final res = await dio.get('/cities');
      final items = (res.data['data'] as List?)?.cast<String>() ?? [];
      if (items.isNotEmpty) return items;
    } catch (e) {
      if (kDebugMode) debugPrint('AppConfigService.getCities: $e');
    }
    return GlobalVariables.cities.skip(1).toList();
  }

  Future<void> addCity(String city) async {
    final dio = await _dio();
    await dio.post('/cities', data: {'name': city.trim()});
  }

  Future<void> deleteCity(String city) async {
    final dio = await _dio();
    await dio.delete('/cities/${Uri.encodeComponent(city)}');
  }

  // ── Skills ─────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getSkills() async {
    try {
      final dio = await _dio();
      final res = await dio.get('/skills');
      final items = (res.data['data'] as List?) ?? [];
      if (items.isNotEmpty) {
        return items.map((raw) {
          final name = raw['name'] as String? ?? '';
          final iconName = raw['icon'] as String? ?? 'wrench';
          return {
            'name': name,
            'icon': iconMap[iconName] ?? FontAwesomeIcons.wrench,
            'iconName': iconName,
          };
        }).toList();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('AppConfigService.getSkills: $e');
    }
    return GlobalVariables.availableSkills.skip(1).map((s) {
      final iconName = iconNameFor(s['icon']);
      return {'name': s['name'] as String, 'icon': s['icon'], 'iconName': iconName};
    }).toList();
  }

  /// Returns `false` if a skill with the same name already exists (409).
  Future<bool> addSkill(String name, String iconName) async {
    try {
      final dio = await _dio();
      await dio.post('/skills', data: {'name': name.trim(), 'icon': iconName});
      return true;
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) return false; // duplicate
      rethrow;
    }
  }

  Future<void> deleteSkill(String name) async {
    final dio = await _dio();
    await dio.delete('/skills/${Uri.encodeComponent(name)}');
  }

  // ── Seed ───────────────────────────────────────────────────────────────────

  /// Seeds Firestore defaults via the backend if the collections are empty.
  Future<void> seedIfEmpty() async {
    try {
      final dio = await _dio();

      // Check cities
      final citiesRes = await dio.get('/cities');
      final cities = (citiesRes.data['data'] as List?) ?? [];
      if (cities.isEmpty) {
        for (final city in GlobalVariables.cities.skip(1)) {
          await dio.post('/cities', data: {'name': city});
        }
        if (kDebugMode) debugPrint('AppConfigService: seeded cities');
      }

      // Check skills
      final skillsRes = await dio.get('/skills');
      final skills = (skillsRes.data['data'] as List?) ?? [];
      if (skills.isEmpty) {
        for (final s in GlobalVariables.availableSkills.skip(1)) {
          await dio.post('/skills', data: {
            'name': s['name'] as String,
            'icon': iconNameFor(s['icon']),
          });
        }
        if (kDebugMode) debugPrint('AppConfigService: seeded skills');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('AppConfigService.seedIfEmpty: $e');
    }
  }
}
