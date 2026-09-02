// test/profile_photo_picker_test.dart
//
// Covers ProfilePhotoPicker, the avatar control shared by all three
// registration flows. It is purely presentational — the parent owns the
// ImagePicker call and the Storage upload — so it tests without Firebase.

import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homegrown/widgets/profile_photo_picker.dart';

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(body: child),
    );

/// Smallest valid PNG, so FileImage has something real to decode.
const _onePixelPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk'
    'YPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

void main() {
  testWidgets('prompts for a photo when none is picked', (tester) async {
    await tester.pumpWidget(
        _host(ProfilePhotoPicker(image: null, onTap: () {})));

    expect(find.text('Upload Photo'), findsOneWidget);
    expect(find.text('PNG or JPG, max 5MB'), findsOneWidget);
    expect(find.byIcon(Icons.add_a_photo_outlined), findsOneWidget);
  });

  testWidgets('taps hand off to the parent, which owns the picker',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(
        _host(ProfilePhotoPicker(image: null, onTap: () => taps++)));

    await tester.tap(find.byIcon(Icons.add_a_photo_outlined));
    expect(taps, 1);
  });

  testWidgets('swaps the prompt for a preview once a photo is picked',
      (tester) async {
    final file = File('${Directory.systemTemp.createTempSync().path}/a.png')
      ..writeAsBytesSync(base64Decode(_onePixelPng));
    addTearDown(() => file.parent.deleteSync(recursive: true));

    await tester.pumpWidget(
        _host(ProfilePhotoPicker(image: file, onTap: () {})));

    expect(find.text('Upload Photo'), findsNothing);
    expect(find.byIcon(Icons.add_a_photo_outlined), findsNothing);
    // The edit badge stays put, so the photo is still replaceable.
    expect(find.byIcon(Icons.edit_rounded), findsOneWidget);
  });
}
