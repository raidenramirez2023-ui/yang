import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yang_chow/utils/app_theme.dart';

/// Helper to provide distinct modern icons for food categories
class CategoryIconHelper {
  static IconData getIcon(String category) {
    final c = category.toLowerCase().trim();
    if (c.contains('dim sum') || c.contains('siomai') || c.contains('dumpling') || c.contains('steamed')) {
      return Icons.bakery_dining_rounded;
    }
    if (c.contains('rice') || c.contains('fried rice') || c.contains('yang chow')) {
      return Icons.rice_bowl_rounded;
    }
    if (c.contains('noodle') || c.contains('pancit') || c.contains('canton') || c.contains('bihon') || c.contains('mami')) {
      return Icons.ramen_dining_rounded;
    }
    if (c.contains('soup') || c.contains('hotpot') || c.contains('broth')) {
      return Icons.soup_kitchen_rounded;
    }
    if (c.contains('seafood') || c.contains('fish') || c.contains('shrimp') || c.contains('crab') || c.contains('squid')) {
      return Icons.set_meal_rounded;
    }
    if (c.contains('chicken') || c.contains('poultry') || c.contains('buttered')) {
      return Icons.egg_rounded;
    }
    if (c.contains('pork') || c.contains('beef') || c.contains('meat') || c.contains('lechon')) {
      return Icons.kebab_dining_rounded;
    }
    if (c.contains('vegetable') || c.contains('veggie') || c.contains('broccoli') || c.contains('salad')) {
      return Icons.eco_rounded;
    }
    if (c.contains('drink') || c.contains('beverage') || c.contains('juice') || c.contains('tea') || c.contains('coffee')) {
      return Icons.local_bar_rounded;
    }
    if (c.contains('dessert') || c.contains('sweet') || c.contains('cake') || c.contains('halo')) {
      return Icons.icecream_rounded;
    }
    if (c.contains('bundle') || c.contains('family') || c.contains('platter') || c.contains('feast')) {
      return Icons.dinner_dining_rounded;
    }
    return Icons.restaurant_menu_rounded;
  }
}

/// Shimmer loader effect widget for food loading states
class AppShimmer extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  const AppShimmer({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 12,
    this.margin,
  });

  @override
  State<AppShimmer> createState() => _AppShimmerState();
}

class _AppShimmerState extends State<AppShimmer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          margin: widget.margin,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(_animation.value - 1, 0),
              end: Alignment(_animation.value, 0),
              colors: const [
                Color(0xFFEDE6E2),
                Color(0xFFF7F2EE),
                Color(0xFFE4DCD6),
                Color(0xFFF7F2EE),
                Color(0xFFEDE6E2),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Food Item Skeleton Loader Card
class FoodItemSkeleton extends StatelessWidget {
  const FoodItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expanded(
            flex: 3,
            child: AppShimmer(
              width: double.infinity,
              height: double.infinity,
              borderRadius: 20,
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: const [
                  AppShimmer(width: 120, height: 16, borderRadius: 6),
                  AppShimmer(width: 80, height: 12, borderRadius: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      AppShimmer(width: 60, height: 16, borderRadius: 6),
                      AppShimmer(width: 32, height: 32, borderRadius: 16),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tactile Button Scale Feedback Micro-Interaction
class AnimatedTapScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleFactor;

  const AnimatedTapScale({
    super.key,
    required this.child,
    this.onTap,
    this.scaleFactor = 0.96,
  });

  @override
  State<AnimatedTapScale> createState() => _AnimatedTapScaleState();
}

class _AnimatedTapScaleState extends State<AnimatedTapScale> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? widget.scaleFactor : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

/// Empty State Illustration & Action Card
class EmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? buttonText;
  final VoidCallback? onButtonPressed;

  const EmptyStateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.buttonText,
    this.onButtonPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.warmGold.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 52,
                color: AppTheme.warmGold,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkGrey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.mediumGrey,
                height: 1.4,
              ),
            ),
            if (buttonText != null && onButtonPressed != null) ...[
              const SizedBox(height: 24),
              AnimatedTapScale(
                onTap: onButtonPressed,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.warmGold,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.warmGold.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.restaurant_menu_rounded, color: AppTheme.darkBrownText, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        buttonText!,
                        style: GoogleFonts.inter(
                          color: AppTheme.darkBrownText,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Order Status Stepper for Live Order Tracking
class OrderStatusStepper extends StatelessWidget {
  final String status;

  const OrderStatusStepper({
    super.key,
    required this.status,
  });

  int _getStepIndex(String statusStr) {
    final s = statusStr.toLowerCase();
    if (s.contains('cancel')) return -1;
    if (s.contains('deliver') || s.contains('complete') || s.contains('claimed') || s.contains('served')) return 3;
    if (s.contains('ready')) return 2;
    if (s.contains('prepar') || s.contains('cooking') || s.contains('kitchen')) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final currentStep = _getStepIndex(status);

    if (currentStep == -1) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.errorRed.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.errorRed.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.cancel_outlined, color: AppTheme.errorRed, size: 20),
            const SizedBox(width: 10),
            Text(
              'Order Cancelled',
              style: GoogleFonts.inter(
                color: AppTheme.errorRed,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    final steps = [
      {'label': 'Pending', 'icon': Icons.receipt_long_rounded},
      {'label': 'Preparing', 'icon': Icons.soup_kitchen_rounded},
      {'label': 'Ready', 'icon': Icons.takeout_dining_rounded},
      {'label': 'Completed', 'icon': Icons.check_circle_outline_rounded},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(steps.length, (index) {
              final isDone = index < currentStep;
              final isCurrent = index == currentStep;

              return Expanded(
                child: Row(
                  children: [
                    Container(
                      width: isCurrent ? 34 : 28,
                      height: isCurrent ? 34 : 28,
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? AppTheme.warmGold
                            : (isDone ? AppTheme.forestGreen : Colors.grey.shade300),
                        shape: BoxShape.circle,
                        boxShadow: isCurrent
                            ? [
                                BoxShadow(
                                  color: AppTheme.warmGold.withOpacity(0.4),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        isDone
                            ? Icons.check_rounded
                            : (steps[index]['icon'] as IconData),
                        size: isCurrent ? 18 : 14,
                        color: isCurrent
                            ? AppTheme.darkBrownText
                            : (isDone ? Colors.white : Colors.grey.shade600),
                      ),
                    ),
                    if (index < steps.length - 1)
                      Expanded(
                        child: Container(
                          height: 3,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: index < currentStep ? AppTheme.forestGreen : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(steps.length, (index) {
              final isCurrent = index == currentStep;
              final isDone = index < currentStep;
              return Expanded(
                child: Text(
                  steps[index]['label'] as String,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: isCurrent ? FontWeight.bold : (isDone ? FontWeight.w600 : FontWeight.normal),
                    color: isCurrent
                        ? AppTheme.darkGrey
                        : (isDone ? AppTheme.forestGreen : AppTheme.mediumGrey),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// Stock availability pill badge
class StockBadge extends StatelessWidget {
  final bool isAvailable;

  const StockBadge({
    super.key,
    required this.isAvailable,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isAvailable
            ? AppTheme.successGreen.withValues(alpha: 0.12)
            : AppTheme.errorRed.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isAvailable ? 'In Stock' : 'Out of Stock',
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isAvailable ? AppTheme.successGreen : AppTheme.errorRed,
        ),
      ),
    );
  }
}

/// Pulsing live status dot indicator
class LivePulseDot extends StatefulWidget {
  final Color color;
  final double size;

  const LivePulseDot({
    super.key,
    this.color = AppTheme.successGreen,
    this.size = 8,
  });

  @override
  State<LivePulseDot> createState() => _LivePulseDotState();
}

class _LivePulseDotState extends State<LivePulseDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: _animation.value),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: _animation.value * 0.6),
                blurRadius: widget.size,
                spreadRadius: 1,
              ),
            ],
          ),
        );
      },
    );
  }
}

