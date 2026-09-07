// lib/widgets/profile_photo_picker.dart

import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// The circular "tap to add your avatar" control on step 3 of every
/// registration flow. Shared rather than duplicated per screen — the same
/// precedent as barangay_picker_sheet.dart, which all three register
/// screens also use.
///
/// Purely presentational: the parent owns the picked [File] and the
/// ImagePicker call, since only the parent knows when to upload it.
class ProfilePhotoPicker extends StatelessWidget {
  /// The locally picked file, shown as a preview. Null renders the
  /// empty "Upload Photo" placeholder.
  final File? image;
  final VoidCallback onTap;

  const ProfilePhotoPicker({super.key, required this.image, required this.onTap});

  @override
  Widget build(BuildContext context) => Center(
    child: GestureDetector(
      onTap: onTap,
      child: Stack(children: [
        Container(
          width: 110, height: 110,
          decoration: BoxDecoration(
            color: AppTheme.card, shape: BoxShape.circle,
            border: Border.all(color: AppTheme.border, width: 2),
            image: image != null
                ? DecorationImage(image: FileImage(image!),
                    fit: BoxFit.cover) : null),
          // The two labels wrap inside a circle only ~106px wide, and wrap
          // harder still once the OS text scale is turned up — enough to
          // push the column past the fixed height and paint overflow
          // stripes. scaleDown shrinks the placeholder to fit instead;
          // at default text size nothing is scaled and it looks unchanged.
          child: image == null ? FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.add_a_photo_outlined,
                    color: AppTheme.muted, size: 28),
                const SizedBox(height: 6),
                Text('Upload Photo', style: TextStyle(
                    color: AppTheme.muted, fontSize: 11)),
                Text('PNG or JPG, max 5MB', style: TextStyle(
                    color: AppTheme.muted.withValues(alpha: 0.6),
                    fontSize: 10)),
              ]),
            ),
          ) : null),
        Positioned(bottom: 4, right: 4,
          child: Container(width: 28, height: 28,
            decoration: BoxDecoration(color: AppTheme.accent,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.bg, width: 2)),
            child: const Icon(Icons.edit_rounded,
                color: AppTheme.buttonFg, size: 14))),
      ]),
    ),
  );
}
