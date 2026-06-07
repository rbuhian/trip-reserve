import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/enums.dart';
import '../../../providers/booking_form_provider.dart';

/// Screen for selecting vehicle category and providing trip details
class BookingVehicleScreen extends ConsumerStatefulWidget {
  const BookingVehicleScreen({super.key});

  @override
  ConsumerState<BookingVehicleScreen> createState() =>
      _BookingVehicleScreenState();
}

class _BookingVehicleScreenState extends ConsumerState<BookingVehicleScreen> {
  final _additionalInfoController = TextEditingController();
  final _bagsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final formState = ref.read(bookingFormProvider);
    _bagsController.text =
        formState.numBags > 0 ? formState.numBags.toString() : '';
    _additionalInfoController.text = formState.additionalInfo ?? '';
  }

  @override
  void dispose() {
    _additionalInfoController.dispose();
    _bagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(bookingFormProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Category'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // Trip summary
          _buildTripSummary(formState),

          // Category selection and details
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category selection header
                  Text(
                    'Vehicle Category',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choose the type of vehicle you need',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Category cards
                  ...VehicleCategory.values.map((category) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _CategoryCard(
                          category: category,
                          isSelected: formState.selectedCategory == category,
                          pricing: formState.categoryPricing,
                          onTap: () {
                            ref
                                .read(bookingFormProvider.notifier)
                                .setCategory(category);
                          },
                        ),
                      )),

                  const SizedBox(height: 24),

                  // Number of bags
                  Text(
                    'Number of Bags',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'How many bags will you bring?',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Decrement button
                      _CounterButton(
                        icon: Icons.remove,
                        onTap: () {
                          final current = formState.numBags;
                          if (current > 0) {
                            ref
                                .read(bookingFormProvider.notifier)
                                .setNumBags(current - 1);
                            _bagsController.text = (current - 1).toString();
                          }
                        },
                      ),
                      const SizedBox(width: 16),
                      // Number display
                      SizedBox(
                        width: 60,
                        child: TextField(
                          controller: _bagsController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(2),
                          ],
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onChanged: (value) {
                            final numBags = int.tryParse(value) ?? 0;
                            ref
                                .read(bookingFormProvider.notifier)
                                .setNumBags(numBags);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Increment button
                      _CounterButton(
                        icon: Icons.add,
                        onTap: () {
                          final current = formState.numBags;
                          if (current < 99) {
                            ref
                                .read(bookingFormProvider.notifier)
                                .setNumBags(current + 1);
                            _bagsController.text = (current + 1).toString();
                          }
                        },
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.luggage,
                        size: 24,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Additional info
                  Text(
                    'Additional Information',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Any special requests or notes for the driver (optional)',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _additionalInfoController,
                    maxLines: 3,
                    maxLength: 500,
                    decoration: InputDecoration(
                      hintText:
                          'E.g., Need help with luggage, traveling with pets, child seats needed...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (value) {
                      ref
                          .read(bookingFormProvider.notifier)
                          .setAdditionalInfo(value.isEmpty ? null : value);
                    },
                  ),

                  const SizedBox(height: 80), // Space for bottom button
                ],
              ),
            ),
          ),

          // Continue button
          _buildBottomButton(context, ref, formState),
        ],
      ),
    );
  }

  Widget _buildTripSummary(BookingFormState formState) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          // Date & Time
          Expanded(
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  formState.dateText,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 24,
            color: AppColors.divider,
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.access_time, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  formState.timeText,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 24,
            color: AppColors.divider,
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.straighten, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  formState.distanceText,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton(
      BuildContext context, WidgetRef ref, BookingFormState formState) {
    final isComplete = formState.isCategoryComplete;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(color: AppColors.divider),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Price summary
            if (formState.priceBreakdown != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Estimated Fare',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    formState.priceBreakdown!.totalText,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isComplete
                    ? () {
                        context.push('/book/addons');
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  disabledBackgroundColor: AppColors.disabled,
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final VehicleCategory category;
  final bool isSelected;
  final dynamic pricing; // CategoryPricing?
  final VoidCallback onTap;

  const _CategoryCard({
    required this.category,
    required this.isSelected,
    required this.pricing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.05)
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Category icon
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: _getCategoryColor(category).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getCategoryIcon(category),
                size: 32,
                color: _getCategoryColor(category),
              ),
            ),
            const SizedBox(width: 16),
            // Category info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.displayName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    category.description,
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (pricing != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'From ${pricing.baseRateText}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Selection indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : colorScheme.outlineVariant,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check,
                      size: 16,
                      color: AppColors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getCategoryIcon(VehicleCategory category) {
    switch (category) {
      case VehicleCategory.sedan:
        return Icons.directions_car;
      case VehicleCategory.mpvSuv:
        return Icons.airport_shuttle;
      case VehicleCategory.van:
        return Icons.directions_bus;
    }
  }

  Color _getCategoryColor(VehicleCategory category) {
    switch (category) {
      case VehicleCategory.sedan:
        return AppColors.primary;
      case VehicleCategory.mpvSuv:
        return AppColors.primaryLight;
      case VehicleCategory.van:
        return AppColors.success;
    }
  }
}

class _CounterButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CounterButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          child: Icon(icon, color: colorScheme.onSurface),
        ),
      ),
    );
  }
}
