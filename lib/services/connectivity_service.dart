// lib/services/connectivity_service.dart

import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';
import '../theme/app_theme.dart';
import 'package:flutter/material.dart';

class ConnectivityService extends GetxService {
  static ConnectivityService get to => Get.find();

  final RxBool isConnected = true.obs;

  StreamSubscription? _subscription;
  bool _wasOffline = false;

  @override
  void onInit() {
    super.onInit();
    _checkInitial();
    _listenToChanges();
  }

  @override
  void onClose() {
    _subscription?.cancel();
    super.onClose();
  }

  // ── Initial check ─────────────────────────

  Future<void> _checkInitial() async {
    final result = await Connectivity().checkConnectivity();
    final online = await _hasActualInternet(result);
    isConnected.value = online;
    if (!online) _wasOffline = true;
  }

  // ── Listen to changes ─────────────────────

  void _listenToChanges() {
    _subscription = Connectivity()
        .onConnectivityChanged
        .listen((results) async {
      final online = await _hasActualInternet(results);

      if (!online && isConnected.value) {
        // Just went offline
        isConnected.value = false;
        _wasOffline = true;
      } else if (online && !isConnected.value) {
        // Just came back online
        isConnected.value = true;
        if (_wasOffline) {
          _wasOffline = false;
          _showReconnectedSnackbar();
        }
      }
    });
  }

  // ── Real internet check ───────────────────
  // connectivity_plus only checks network adapter,
  // not actual internet. We do a real lookup too.

  Future<bool> _hasActualInternet(
      List<ConnectivityResult> results) async {
    if (results.contains(ConnectivityResult.none)) return false;
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void _showReconnectedSnackbar() {
    Get.snackbar(
      '✅ Back Online',
      'Internet connection restored.',
      snackPosition:   SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFF0D2E20),
      colorText:       AppTheme.success,
      icon: const Icon(Icons.wifi_rounded,
          color: AppTheme.success, size: 20),
      margin:       const EdgeInsets.all(16),
      borderRadius: 12,
      duration:     const Duration(seconds: 2),
    );
  }

  // ── Manual retry ──────────────────────────

  Future<void> retryConnection() async {
    final result = await Connectivity().checkConnectivity();
    final online = await _hasActualInternet(result);
    isConnected.value = online;
    if (!online) {
      Get.snackbar(
        'Still Offline',
        'Please check your connection and try again.',
        snackPosition:   SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF2A1A1A),
        colorText:       const Color(0xFFFF5C5C),
        margin:          const EdgeInsets.all(16),
        borderRadius:    12,
        duration:        const Duration(seconds: 2),
      );
    }
  }
}