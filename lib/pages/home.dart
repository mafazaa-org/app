import 'package:flutter/material.dart';
import 'package:app/constants/colors.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const TextStyle poetryStyle = TextStyle(
      fontFamily: 'Cairo',
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: AppColors.brightOne,
      height: 1.6,
    );

    return Scaffold(
      body: Stack(
        children: [
          // 1. Rich Radial/Linear Gradient Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.darkOne,
                  AppColors.darkTwo,
                ],
              ),
            ),
          ),

          // 2. Ambient Glow Effects
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 120,
                    spreadRadius: 40,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.secondary.withValues(alpha: 0.35),
                    blurRadius: 100,
                    spreadRadius: 30,
                  ),
                ],
              ),
            ),
          ),

          // 3. Logo Watermark on the Right/Bottom Side (partially out of screen crossing right and bottom boundaries)
          Positioned(
            right: -175,
            bottom: -100,
            child: Opacity(
              opacity: 0.12,
              child: Image.asset(
                'assets/images/2مفازا.png',
                width: 450,
                fit: BoxFit.contain,
              ),
            ),
          ),



          // 5. Main Content Area
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 60),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(height: 10),

                            // Top Brand Logo with "إعادة إحياء أمة"
                            Image.asset(
                              'assets/images/32مفازا.png',
                              height: 120,
                              fit: BoxFit.contain,
                            ),

                            const Spacer(flex: 2),

                           

                            const Spacer(flex: 3),

                            // Interactive Start Button
                            Container(
                              width: double.infinity,
                              height: 60,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(30),
                                gradient: const LinearGradient(
                                  colors: [
                                    AppColors.accent,
                                    AppColors.primary,
                                  ],
                                  begin: Alignment.centerRight,
                                  end: Alignment.centerLeft,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.accent.withValues(alpha: 0.3),
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'جاري الانتقال إلى قائمة الدروس...',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.darkOne,
                                        ),
                                        textAlign: TextAlign.right,
                                      ),
                                      backgroundColor: AppColors.accent,
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'ابدأ رحلة الدروس',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.brightOne,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Simple geometric pattern painter for Islamic feel
class IslamicPatternPainter extends CustomPainter {
  const IslamicPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (double i = 0; i < size.width; i += 60) {
      for (double j = 0; j < size.height; j += 60) {
        canvas.drawCircle(Offset(i, j), 4, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}