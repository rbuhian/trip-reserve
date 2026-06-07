import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/enums.dart';
import '../../../models/pricing.dart';
import '../../../providers/booking_form_provider.dart';
import '../../../repositories/pricing_repository.dart';

/// Provider for available addons
final availableAddonsProvider = FutureProvider<List<PricingAddon>>((ref) async {
  final pricingRepo = ref.watch(pricingRepositoryProvider);
  return pricingRepo.getAvailableAddons();
});

/// Screen for selecting optional add-ons
class BookingAddonsScreen extends ConsumerWidget {
  const BookingAddonsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formState = ref.watch(bookingFormProvider);
    final addonsAsync = ref.watch(availableAddonsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add-ons'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: () => context.push('/book/confirm'),
            child: const Text('Skip'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Current selection summary
          _buildSelectionSummary(formState),

          // Add-ons list
          Expanded(
            child: addonsAsync.when(
              data: (addons) {
                if (addons.isEmpty) {
                  return _buildEmptyState();
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: addons.length,
                  itemBuilder: (context, index) {
                    final addon = addons[index];
                    final isSelected =
                        ref.read(bookingFormProvider.notifier).isAddonSelected(addon.id);
                    final selectedItem = formState.selectedAddons
                        .where((item) => item.addon.id == addon.id)
                        .firstOrNull;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _AddonCard(
                        addon: addon,
                        isSelected: isSelected,
                        quantity: selectedItem?.quantity ?? 1,
                        onToggle: () {
                          ref
                              .read(bookingFormProvider.notifier)
                              .toggleAddon(addon);
                        },
                        onQuantityChanged: (quantity) {
                          ref
                              .read(bookingFormProvider.notifier)
                              .updateAddonQuantity(addon.id, quantity);
                        },
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (error, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline,
                        size: 48, color: theme.colorScheme.error),
                    const SizedBox(height: 16),
                    Text('Error loading add-ons'),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => ref.invalidate(availableAddonsProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Continue button
          _buildBottomButton(context, formState),
        ],
      ),
    );
  }

  Widget _buildSelectionSummary(BookingFormState formState) {
    if (formState.selectedAddons.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 20, color: AppColors.textMedium),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Add optional services to enhance your trip',
                style: TextStyle(
                  color: AppColors.textMedium,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.1),
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 20, color: AppColors.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${formState.selectedAddons.length} add-on${formState.selectedAddons.length > 1 ? 's' : ''} selected',
              style: TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            '₱${formState.addonsTotal.toStringAsFixed(0)}',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_shopping_cart_outlined,
            size: 64,
            color: AppColors.textLight,
          ),
          const SizedBox(height: 16),
          Text(
            'No add-ons available',
            style: TextStyle(
              color: AppColors.textMedium,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton(BuildContext context, BookingFormState formState) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              context.push('/book/confirm');
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(
              formState.selectedAddons.isEmpty
                  ? 'Continue without add-ons'
                  : 'Continue',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddonCard extends StatelessWidget {
  final PricingAddon addon;
  final bool isSelected;
  final int quantity;
  final VoidCallback onToggle;
  final ValueChanged<int> onQuantityChanged;

  const _AddonCard({
    required this.addon,
    required this.isSelected,
    required this.quantity,
    required this.onToggle,
    required this.onQuantityChanged,
  });

  IconData _getAddonIcon() {
    final iconName = addon.icon?.toLowerCase() ?? '';
    switch (iconName) {
      case 'flight':
      case 'airplane':
        return Icons.flight;
      case 'child':
      case 'child_care':
        return Icons.child_care;
      case 'time':
      case 'waiting':
        return Icons.hourglass_empty;
      case 'luggage':
        return Icons.luggage;
      case 'wifi':
        return Icons.wifi;
      case 'water':
        return Icons.water_drop;
      default:
        return Icons.add_circle_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final showQuantitySelector =
        isSelected && addon.addonType != AddonType.flat;

    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              isSelected ? AppColors.primary.withOpacity(0.05) : AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withOpacity(0.1)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getAddonIcon(),
                    color: isSelected ? AppColors.primary : AppColors.textMedium,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        addon.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                        ),
                      ),
                      if (addon.description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          addon.description!,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textMedium,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Price
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      addon.priceLabel,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    if (isSelected && addon.addonType != AddonType.flat)
                      Text(
                        '= ₱${(addon.price * quantity).toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMedium,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                // Checkbox
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.border,
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
            // Quantity selector
            if (showQuantitySelector) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    addon.addonType == AddonType.perHour ? 'Hours:' : 'Quantity:',
                    style: TextStyle(
                      color: AppColors.textMedium,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 16),
                  _QuantitySelector(
                    value: quantity,
                    onChanged: onQuantityChanged,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuantitySelector extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _QuantitySelector({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: value > 1 ? () => onChanged(value - 1) : null,
          icon: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: value > 1 ? AppColors.surface : AppColors.disabled,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.remove,
              size: 18,
              color: value > 1 ? AppColors.primary : AppColors.white,
            ),
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 8),
        Container(
          width: 40,
          alignment: Alignment.center,
          child: Text(
            '$value',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: value < 10 ? () => onChanged(value + 1) : null,
          icon: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: value < 10 ? AppColors.primary : AppColors.disabled,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.add,
              size: 18,
              color: AppColors.white,
            ),
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }
}
