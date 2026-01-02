import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:ui';
import '../../theme/app_theme.dart';
// import '../common/glass_container.dart'; // Removed unused

class AgeVerificationOverlay extends StatefulWidget {
  final Function(int year) onYearSelected;

  const AgeVerificationOverlay({
    super.key,
    required this.onYearSelected,
  });

  @override
  State<AgeVerificationOverlay> createState() => _AgeVerificationOverlayState();
}

class _AgeVerificationOverlayState extends State<AgeVerificationOverlay> {
  int? _selectedYear;
  final int currentYear = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    // Generate years (1900 to current)
    // Reverse order so current year is near top? Or typical scroll.
    // Let's do Current down to 1900
    final years =
        List.generate(currentYear - 1900 + 1, (index) => currentYear - index);

    return PopScope(
      canPop: false, // Blocking
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // 1. Full Screen Blur
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  color:
                      Colors.black.withOpacity(0.85), // Dark opaque background
                ),
              ),
            ),

            // 2. Content
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Select your year of birth",
                      textAlign: TextAlign.center,
                      style: AppTheme.header.copyWith(
                        fontSize: 24,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "This information helps us determine eligibility.",
                      textAlign: TextAlign.center,
                      style: AppTheme.text.copyWith(
                        color: Colors.white60,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Picker Container
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: CupertinoTheme(
                        data: const CupertinoThemeData(
                          brightness: Brightness.dark,
                          textTheme: CupertinoTextThemeData(
                            pickerTextStyle: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                            ),
                          ),
                        ),
                        child: CupertinoPicker(
                          itemExtent: 40,
                          scrollController: FixedExtentScrollController(
                            initialItem: years.indexOf(
                                2000), // Default to 2000 for convenience
                          ),
                          onSelectedItemChanged: (index) {
                            setState(() {
                              _selectedYear = years[index];
                            });
                          },
                          children: years
                              .map((y) => Center(child: Text(y.toString())))
                              .toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Continue Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _selectedYear != null
                            ? () => widget.onYearSelected(_selectedYear!)
                            : null, // Disabled until selected
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.neonBlue,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.white10,
                          disabledForegroundColor: Colors.white30,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          "Continue",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
