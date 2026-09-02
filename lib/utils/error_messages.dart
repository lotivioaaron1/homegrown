// lib/utils/error_messages.dart

import 'dart:async';
import 'dart:io';

// FirebaseException and FirebaseAuthException both come through firebase_auth.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Turns any thrown object into a sentence worth showing a user.
///
/// Screens used to pass `e.toString()` straight into a snackbar, which put
/// strings like `[cloud_firestore/permission-denied] Missing or insufficient
/// permissions.` in front of athletes and coaches. That text names internals,
/// gives no next step, and reads as a broken app rather than a rule.
///
/// The raw error is still written to the debug console, and Crashlytics
/// captures uncaught ones, so nothing is lost for diagnosis.
String friendlyError(Object? error, {String? fallback}) {
  final generic = fallback ?? 'Something went wrong. Please try again.';

  if (error == null) return generic;

  // Services that already build their own user-facing copy pass it through
  // unchanged rather than being flattened to the generic message.
  final message = _messageFromKnownException(error);
  if (message != null) return message;

  if (error is FirebaseAuthException) {
    return _authMessage(error.code) ?? generic;
  }

  if (error is FirebaseException) {
    return _firebaseMessage(error.code) ?? generic;
  }

  if (error is SocketException || error is HttpException) {
    return 'Network error. Check your connection and try again.';
  }

  if (error is TimeoutException) {
    return 'That took too long. Check your connection and try again.';
  }

  if (error is FormatException) {
    return "We couldn't read the response from the server. Please try again.";
  }

  debugPrint('friendlyError: unmapped ${error.runtimeType} -> $error');
  return generic;
}

/// The app's own exception types carry copy written for users already
/// (PlacesException, BarangayException). Matching on the message rather than
/// the type keeps this file from importing every service.
String? _messageFromKnownException(Object error) {
  final name = error.runtimeType.toString();
  if (name == 'PlacesException' ||
      name == 'BarangayException' ||
      name == 'GeocodingException' ||
      name == 'DirectionsException' ||
      name == 'StorageException') {
    final text = error.toString();
    // Strip the "TypeName: " prefix these add in toString().
    final colon = text.indexOf(': ');
    return colon >= 0 ? text.substring(colon + 2) : text;
  }
  return null;
}

String? _authMessage(String code) {
  switch (code) {
    case 'user-not-found':
      return 'No account found with this email.';
    case 'wrong-password':
      return 'Incorrect password. Please try again.';
    case 'invalid-email':
      return 'Please enter a valid email address.';
    case 'email-already-in-use':
      return 'An account already exists with this email.';
    case 'weak-password':
      return 'Password is too weak. Use at least 8 characters.';
    case 'user-disabled':
      return 'This account has been disabled.';
    case 'too-many-requests':
      return 'Too many attempts. Please try again later.';
    case 'network-request-failed':
      return 'Network error. Check your connection.';
    case 'invalid-credential':
      return 'Invalid credentials. Please try again.';
    case 'account-exists-with-different-credential':
      return 'An account already exists with a different sign-in method.';
    case 'requires-recent-login':
      return 'Please sign in again to confirm this change.';
    default:
      return null;
  }
}

String? _firebaseMessage(String code) {
  switch (code) {
    // Firestore and Storage both use these.
    case 'permission-denied':
    case 'unauthorized':
      return "You don't have permission to do that.";
    case 'unavailable':
      return 'Service is temporarily unavailable. Please try again shortly.';
    case 'deadline-exceeded':
      return 'That took too long. Check your connection and try again.';
    case 'not-found':
    case 'object-not-found':
      return "We couldn't find that item. It may have been removed.";
    case 'already-exists':
      return 'That already exists.';
    case 'resource-exhausted':
    case 'quota-exceeded':
      return 'Service is busy right now. Please try again shortly.';
    case 'cancelled':
    case 'canceled':
      return 'That was cancelled before it finished.';
    case 'failed-precondition':
      return "That couldn't be completed right now. Please try again.";
    case 'unauthenticated':
      return 'Please sign in again to continue.';
    case 'retry-limit-exceeded':
      return 'Upload timed out. Check your connection and try again.';
    default:
      return null;
  }
}
