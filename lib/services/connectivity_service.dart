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

  /// True when the device has a Wi-Fi or mobile connection but no route to the
  /// internet — a captive portal, or a router that is up with no upstream. The
  /// offline screen gives different advice for the two cases, since "check your
  /// Wi-Fi" is unhelpful advice to someone whose Wi-Fi is plainly connected.
  final RxBool hasNetworkButNoInternet = false.obs;

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
    if (results.contains(ConnectivityResult.none)) {
      // No adapter at all, so there is no network to blame the outage on.
      hasNetworkButNoInternet.value = false;
      return false;
    }
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      final online =
          result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      hasNetworkButNoInternet.value = !online;
      return online;
    } catch (_) {
      // The adapter reported a connection but the lookup failed or timed out.
      hasNetworkButNoInternet.value = true;
      return false;
    }
  }

  void _showReconnectedSnackbar() {
    Get.snackbar(
      '✅ Back Online',
      'Internet connection restored.',
      snackPosition:   SnackPosition.BOTTOM,
      // Was a hardcoded 0xFF0D2E20, which stayed a dark green block on the
      // light background. successSurface/successText are that same dark hex
      // plus a light-mode counterpart.
      backgroundColor: AppTheme.successSurface,
      colorText:       AppTheme.successText,
      icon: Icon(Icons.wifi_rounded,
          color: AppTheme.successText, size: 20),
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
        // Same story as above: 0xFF2A1A1A is now errorSurface's dark value.
        backgroundColor: AppTheme.errorSurface,
        colorText:       AppTheme.errorText,
        icon: Icon(Icons.wifi_off_rounded,
            color: AppTheme.errorText, size: 20),
        margin:          const EdgeInsets.all(16),
        borderRadius:    12,
        duration:        const Duration(seconds: 2),
      );
    }
  }
}