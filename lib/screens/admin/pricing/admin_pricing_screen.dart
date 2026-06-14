import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/enums.dart';
import '../../../models/pricing.dart';
import '../../../repositories/pricing_repository.dart';

/// Provider for active pricing config
final activePricingConfigProvider = FutureProvider<PricingConfig?>((ref) async {
  final repo = ref.watch(adminPricingRepositoryProvider);
  return repo.getActivePricingConfig();
});

/// Provider for all add-ons
final allAddonsProvider = FutureProvider<List<PricingAddon>>((ref) async {
  final repo = ref.watch(adminPricingRepositoryProvider);
  return repo.getAllAddons();
});

/// Provider for all category pricing
final allCategoryPricingProvider = FutureProvider<List<CategoryPricing>>((ref) async {
  final repo = ref.watch(adminPricingRepositoryProvider);
  return repo.getAllCategoryPricing();
});

class AdminPricingScreen extends ConsumerWidget {
  const AdminPricingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final config = ref.watch(activePricingConfigProvider);
    final addons = ref.watch(allAddonsProvider);
    final categoryPricing = ref.watch(allCategoryPricingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pricing Configuration'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: AppColors.white,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(activePricingConfigProvider);
          ref.invalidate(allAddonsProvider);
          ref.invalidate(allCategoryPricingProvider);
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Base Rates Section
              _buildSectionHeader(context, 'Base Rates', Icons.payments_outlined),
              const SizedBox(height: 12),
              config.when(
                data: (cfg) => cfg != null
                    ? _PricingConfigCard(
                        config: cfg,
                        onEdit: () => _showEditPricingDialog(context, ref, cfg),
                      )
                    : _buildNoPricingConfig(context, ref),
                loading: () => const _LoadingCard(),
                error: (_, __) => _buildErrorCard(
                  context,
                  'Failed to load pricing',
                  () => ref.invalidate(activePricingConfigProvider),
                ),
              ),

              const SizedBox(height: 28),

              // Category Pricing Section
              _buildSectionHeader(context, 'Category Pricing', Icons.directions_car_outlined),
              const SizedBox(height: 8),
              Text(
                'Set different rates for each vehicle category',
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              categoryPricing.when(
                data: (pricingList) => Column(
                  children: VehicleCategory.values.map((category) {
                    final pricing = pricingList
                        .cast<CategoryPricing?>()
                        .firstWhere(
                          (p) => p?.category == category,
                          orElse: () => null,
                        );
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _CategoryPricingCard(
                        category: category,
                        pricing: pricing,
                        onEdit: () => _showCategoryPricingDialog(context, ref, category, pricing),
                      ),
                    );
                  }).toList(),
                ),
                loading: () => const _LoadingCard(),
                error: (_, __) => _buildErrorCard(
                  context,
                  'Failed to load category pricing',
                  () => ref.invalidate(allCategoryPricingProvider),
                ),
              ),

              const SizedBox(height: 28),

              // Add-ons Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionHeader(context, 'Add-on Services', Icons.add_circle_outline),
                  TextButton.icon(
                    onPressed: () => _showAddAddonDialog(context, ref),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add New'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              addons.when(
                data: (addonList) => addonList.isEmpty
                    ? _buildNoAddons(context, ref)
                    : Column(
                        children: addonList.map((addon) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _AddonCard(
                            addon: addon,
                            onEdit: () => _showEditAddonDialog(context, ref, addon),
                            onToggle: () => _toggleAddonStatus(context, ref, addon),
                            onDelete: () => _deleteAddon(context, ref, addon),
                          ),
                        )).toList(),
                      ),
                loading: () => const _LoadingCard(),
                error: (_, __) => _buildErrorCard(
                  context,
                  'Failed to load add-ons',
                  () => ref.invalidate(allAddonsProvider),
                ),
              ),

              const SizedBox(height: 28),

              // Fare Calculator Preview
              _buildSectionHeader(context, 'Fare Calculator Preview', Icons.calculate_outlined),
              const SizedBox(height: 12),
              const _FareCalculatorPreview(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildNoPricingConfig(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.settings_outlined,
            size: 48,
            color: colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'No pricing configuration',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Set up base rates to enable bookings',
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _showCreatePricingDialog(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Create Pricing'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoAddons(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.add_circle_outline,
            size: 48,
            color: colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'No add-ons configured',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add optional services for customers',
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context, String message, VoidCallback onRetry) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, size: 32, color: colorScheme.error),
          const SizedBox(height: 8),
          Text(message),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }

  void _showCreatePricingDialog(BuildContext context, WidgetRef ref) {
    _showPricingDialog(context, ref, null);
  }

  void _showEditPricingDialog(BuildContext context, WidgetRef ref, PricingConfig config) {
    _showPricingDialog(context, ref, config);
  }

  void _showPricingDialog(BuildContext context, WidgetRef ref, PricingConfig? config) {
    showDialog(
      context: context,
      builder: (context) => _PricingConfigDialog(
        config: config,
        onSave: (baseRate, perKmRate, minimumFare, cancellationHours, cancellationFeePercent) async {
          final repo = ref.read(adminPricingRepositoryProvider);
          if (config == null) {
            await repo.createPricingConfig(
              baseRate: baseRate,
              perKmRate: perKmRate,
              minimumFare: minimumFare,
              cancellationHours: cancellationHours,
              cancellationFeePercent: cancellationFeePercent,
            );
          } else {
            await repo.updatePricingConfig(
              config.id,
              baseRate: baseRate,
              perKmRate: perKmRate,
              minimumFare: minimumFare,
              cancellationHours: cancellationHours,
              cancellationFeePercent: cancellationFeePercent,
            );
          }
          ref.invalidate(activePricingConfigProvider);
        },
      ),
    );
  }

  void _showAddAddonDialog(BuildContext context, WidgetRef ref) {
    _showAddonDialog(context, ref, null);
  }

  void _showEditAddonDialog(BuildContext context, WidgetRef ref, PricingAddon addon) {
    _showAddonDialog(context, ref, addon);
  }

  void _showAddonDialog(BuildContext context, WidgetRef ref, PricingAddon? addon) {
    showDialog(
      context: context,
      builder: (context) => _AddonDialog(
        addon: addon,
        onSave: (name, description, addonType, price, icon) async {
          final repo = ref.read(adminPricingRepositoryProvider);
          if (addon == null) {
            await repo.createAddon(
              name: name,
              description: description,
              addonType: addonType,
              price: price,
              icon: icon,
            );
          } else {
            await repo.updateAddon(
              addon.id,
              name: name,
              description: description,
              addonType: addonType,
              price: price,
              icon: icon,
            );
          }
          ref.invalidate(allAddonsProvider);
        },
      ),
    );
  }

  Future<void> _toggleAddonStatus(BuildContext context, WidgetRef ref, PricingAddon addon) async {
    final repo = ref.read(adminPricingRepositoryProvider);
    await repo.updateAddon(addon.id, isActive: !addon.isActive);
    ref.invalidate(allAddonsProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${addon.name} ${addon.isActive ? 'disabled' : 'enabled'}'),
        ),
      );
    }
  }

  Future<void> _deleteAddon(BuildContext context, WidgetRef ref, PricingAddon addon) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Add-on'),
        content: Text('Are you sure you want to delete "${addon.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final repo = ref.read(adminPricingRepositoryProvider);
      await repo.deleteAddon(addon.id);
      ref.invalidate(allAddonsProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${addon.name} deleted')),
        );
      }
    }
  }

  void _showCategoryPricingDialog(
    BuildContext context,
    WidgetRef ref,
    VehicleCategory category,
    CategoryPricing? pricing,
  ) {
    showDialog(
      context: context,
      builder: (context) => _CategoryPricingDialog(
        category: category,
        pricing: pricing,
        onSave: (baseRate, perKmRate, minimumFare) async {
          final repo = ref.read(adminPricingRepositoryProvider);
          await repo.updateCategoryPricing(
            category,
            baseRate: baseRate,
            perKmRate: perKmRate,
            minimumFare: minimumFare,
          );
          ref.invalidate(allCategoryPricingProvider);
        },
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _PricingConfigCard extends StatelessWidget {
  final PricingConfig config;
  final VoidCallback onEdit;

  const _PricingConfigCard({
    required this.config,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Current Rates',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                style: IconButton.styleFrom(
                  backgroundColor: colorScheme.primary.withOpacity(0.1),
                  foregroundColor: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildRateRow(context, 'Base Rate', '₱${config.baseRate.toStringAsFixed(0)}'),
          const Divider(height: 24),
          _buildRateRow(context, 'Per Kilometer', '₱${config.perKmRate.toStringAsFixed(0)}/km'),
          const Divider(height: 24),
          _buildRateRow(context, 'Minimum Fare', '₱${config.minimumFare.toStringAsFixed(0)}'),
          const Divider(height: 24),
          _buildRateRow(context, 'Cancellation Window', '${config.cancellationHours} hours'),
          const Divider(height: 24),
          _buildRateRow(context, 'Cancellation Fee', '${config.cancellationFeePercent.toStringAsFixed(0)}%'),
        ],
      ),
    );
  }

  Widget _buildRateRow(BuildContext context, String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            color: colorScheme.primary,
          ),
        ),
      ],
    );
  }
}

class _CategoryPricingCard extends StatelessWidget {
  final VehicleCategory category;
  final CategoryPricing? pricing;
  final VoidCallback onEdit;

  const _CategoryPricingCard({
    required this.category,
    required this.pricing,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getCategoryColor(category).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getCategoryIcon(category),
              color: _getCategoryColor(category),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      category.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    if (pricing != null && !pricing!.isActive) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.onSurfaceVariant.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'DISABLED',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                if (pricing != null) ...[
                  Text(
                    'Base: ${pricing!.baseRateText} • ${pricing!.perKmRateText} • Min: ${pricing!.minimumFareText}',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ] else ...[
                  Text(
                    'Not configured - using default rates',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.primary.withOpacity(0.1),
              foregroundColor: colorScheme.primary,
            ),
          ),
        ],
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
        return Icons.bus_alert;
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

class _AddonCard extends StatelessWidget {
  final PricingAddon addon;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _AddonCard({
    required this.addon,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Opacity(
      opacity: addon.isActive ? 1.0 : 0.6,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getAddonIcon(addon.icon),
                color: colorScheme.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        addon.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      if (!addon.isActive) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: colorScheme.onSurfaceVariant.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'DISABLED',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (addon.description != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      addon.description!,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    addon.priceLabel,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    onEdit();
                    break;
                  case 'toggle':
                    onToggle();
                    break;
                  case 'delete':
                    onDelete();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'toggle',
                  child: Row(
                    children: [
                      Icon(addon.isActive ? Icons.visibility_off : Icons.visibility, size: 18),
                      const SizedBox(width: 8),
                      Text(addon.isActive ? 'Disable' : 'Enable'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                      const SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: AppColors.error)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getAddonIcon(String? icon) {
    switch (icon) {
      case 'flight':
        return Icons.flight;
      case 'child_care':
        return Icons.child_care;
      case 'schedule':
        return Icons.schedule;
      case 'luggage':
        return Icons.luggage;
      case 'wifi':
        return Icons.wifi;
      case 'ac':
        return Icons.ac_unit;
      default:
        return Icons.add_circle_outline;
    }
  }
}

class _PricingConfigDialog extends StatefulWidget {
  final PricingConfig? config;
  final Future<void> Function(double baseRate, double perKmRate, double minimumFare,
      int cancellationHours, double cancellationFeePercent) onSave;

  const _PricingConfigDialog({
    this.config,
    required this.onSave,
  });

  @override
  State<_PricingConfigDialog> createState() => _PricingConfigDialogState();
}

class _PricingConfigDialogState extends State<_PricingConfigDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _baseRateController;
  late TextEditingController _perKmRateController;
  late TextEditingController _minimumFareController;
  late TextEditingController _cancellationHoursController;
  late TextEditingController _cancellationFeeController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _baseRateController = TextEditingController(
      text: widget.config?.baseRate.toStringAsFixed(0) ?? '500',
    );
    _perKmRateController = TextEditingController(
      text: widget.config?.perKmRate.toStringAsFixed(0) ?? '20',
    );
    _minimumFareController = TextEditingController(
      text: widget.config?.minimumFare.toStringAsFixed(0) ?? '300',
    );
    _cancellationHoursController = TextEditingController(
      text: widget.config?.cancellationHours.toString() ?? '24',
    );
    _cancellationFeeController = TextEditingController(
      text: widget.config?.cancellationFeePercent.toStringAsFixed(0) ?? '50',
    );
  }

  @override
  void dispose() {
    _baseRateController.dispose();
    _perKmRateController.dispose();
    _minimumFareController.dispose();
    _cancellationHoursController.dispose();
    _cancellationFeeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      await widget.onSave(
        double.parse(_baseRateController.text),
        double.parse(_perKmRateController.text),
        double.parse(_minimumFareController.text),
        int.parse(_cancellationHoursController.text),
        double.parse(_cancellationFeeController.text),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.config == null ? 'Create Pricing' : 'Edit Pricing'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _baseRateController,
                decoration: const InputDecoration(
                  labelText: 'Base Rate (₱)',
                  prefixText: '₱ ',
                ),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _perKmRateController,
                decoration: const InputDecoration(
                  labelText: 'Per Kilometer Rate (₱)',
                  prefixText: '₱ ',
                  suffixText: '/km',
                ),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _minimumFareController,
                decoration: const InputDecoration(
                  labelText: 'Minimum Fare (₱)',
                  prefixText: '₱ ',
                ),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _cancellationHoursController,
                decoration: const InputDecoration(
                  labelText: 'Cancellation Window',
                  suffixText: 'hours',
                ),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _cancellationFeeController,
                decoration: const InputDecoration(
                  labelText: 'Cancellation Fee',
                  suffixText: '%',
                ),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

class _AddonDialog extends StatefulWidget {
  final PricingAddon? addon;
  final Future<void> Function(String name, String? description, String addonType,
      double price, String? icon) onSave;

  const _AddonDialog({
    this.addon,
    required this.onSave,
  });

  @override
  State<_AddonDialog> createState() => _AddonDialogState();
}

class _AddonDialogState extends State<_AddonDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  String _addonType = 'flat';
  String? _icon;
  bool _isSaving = false;

  static const _icons = [
    ('flight', Icons.flight, 'Airport'),
    ('child_care', Icons.child_care, 'Child'),
    ('schedule', Icons.schedule, 'Waiting'),
    ('luggage', Icons.luggage, 'Luggage'),
    ('wifi', Icons.wifi, 'WiFi'),
    ('ac', Icons.ac_unit, 'A/C'),
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.addon?.name ?? '');
    _descriptionController = TextEditingController(text: widget.addon?.description ?? '');
    _priceController = TextEditingController(
      text: widget.addon?.price.toStringAsFixed(0) ?? '',
    );
    _addonType = widget.addon?.addonType.value ?? 'flat';
    _icon = widget.addon?.icon;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      await widget.onSave(
        _nameController.text.trim(),
        _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        _addonType,
        double.parse(_priceController.text),
        _icon,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(widget.addon == null ? 'Add Add-on' : 'Edit Add-on'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description (optional)'),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _addonType,
                decoration: const InputDecoration(labelText: 'Pricing Type'),
                items: const [
                  DropdownMenuItem(value: 'flat', child: Text('Flat Fee')),
                  DropdownMenuItem(value: 'per_hour', child: Text('Per Hour')),
                  DropdownMenuItem(value: 'per_unit', child: Text('Per Unit')),
                ],
                onChanged: (v) => setState(() => _addonType = v!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                decoration: InputDecoration(
                  labelText: 'Price (₱)',
                  prefixText: '₱ ',
                  suffixText: _addonType == 'per_hour' ? '/hr' : _addonType == 'per_unit' ? '/unit' : null,
                ),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              Text(
                'Icon',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _icons.map((iconData) {
                  final isSelected = _icon == iconData.$1;
                  return GestureDetector(
                    onTap: () => setState(() => _icon = iconData.$1),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorScheme.primary
                            : colorScheme.surfaceContainerHighest.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        iconData.$2,
                        size: 20,
                        color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

class _CategoryPricingDialog extends StatefulWidget {
  final VehicleCategory category;
  final CategoryPricing? pricing;
  final Future<void> Function(double baseRate, double perKmRate, double minimumFare) onSave;

  const _CategoryPricingDialog({
    required this.category,
    this.pricing,
    required this.onSave,
  });

  @override
  State<_CategoryPricingDialog> createState() => _CategoryPricingDialogState();
}

class _CategoryPricingDialogState extends State<_CategoryPricingDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _baseRateController;
  late TextEditingController _perKmRateController;
  late TextEditingController _minimumFareController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _baseRateController = TextEditingController(
      text: widget.pricing?.baseRate.toStringAsFixed(0) ?? _getDefaultBaseRate(),
    );
    _perKmRateController = TextEditingController(
      text: widget.pricing?.perKmRate.toStringAsFixed(0) ?? _getDefaultPerKmRate(),
    );
    _minimumFareController = TextEditingController(
      text: widget.pricing?.minimumFare.toStringAsFixed(0) ?? _getDefaultMinimumFare(),
    );
  }

  String _getDefaultBaseRate() {
    switch (widget.category) {
      case VehicleCategory.sedan:
        return '500';
      case VehicleCategory.mpvSuv:
        return '700';
      case VehicleCategory.van:
        return '1000';
    }
  }

  String _getDefaultPerKmRate() {
    switch (widget.category) {
      case VehicleCategory.sedan:
        return '20';
      case VehicleCategory.mpvSuv:
        return '25';
      case VehicleCategory.van:
        return '30';
    }
  }

  String _getDefaultMinimumFare() {
    switch (widget.category) {
      case VehicleCategory.sedan:
        return '300';
      case VehicleCategory.mpvSuv:
        return '400';
      case VehicleCategory.van:
        return '500';
    }
  }

  @override
  void dispose() {
    _baseRateController.dispose();
    _perKmRateController.dispose();
    _minimumFareController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      await widget.onSave(
        double.parse(_baseRateController.text),
        double.parse(_perKmRateController.text),
        double.parse(_minimumFareController.text),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.category.displayName} Pricing'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _baseRateController,
                decoration: const InputDecoration(
                  labelText: 'Base Rate (₱)',
                  prefixText: '₱ ',
                ),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _perKmRateController,
                decoration: const InputDecoration(
                  labelText: 'Per Kilometer Rate (₱)',
                  prefixText: '₱ ',
                  suffixText: '/km',
                ),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _minimumFareController,
                decoration: const InputDecoration(
                  labelText: 'Minimum Fare (₱)',
                  prefixText: '₱ ',
                ),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

class _FareCalculatorPreview extends ConsumerStatefulWidget {
  const _FareCalculatorPreview();

  @override
  ConsumerState<_FareCalculatorPreview> createState() => _FareCalculatorPreviewState();
}

class _FareCalculatorPreviewState extends ConsumerState<_FareCalculatorPreview> {
  double _distance = 10.0;
  VehicleCategory _selectedCategory = VehicleCategory.sedan;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final config = ref.watch(activePricingConfigProvider);
    final categoryPricing = ref.watch(allCategoryPricingProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: categoryPricing.when(
        data: (pricingList) {
          // Find pricing for selected category, or use fallback
          final pricing = pricingList
              .cast<CategoryPricing?>()
              .firstWhere(
                (p) => p?.category == _selectedCategory,
                orElse: () => null,
              );

          // Use category pricing or fallback to global config
          return config.when(
            data: (cfg) {
              final baseFare = pricing?.baseRate ?? cfg?.baseRate ?? 500;
              final perKmRate = pricing?.perKmRate ?? cfg?.perKmRate ?? 20;
              final minimumFare = pricing?.minimumFare ?? cfg?.minimumFare ?? 300;

              final distanceFee = perKmRate * _distance;
              final total = baseFare + distanceFee;
              final finalTotal = total < minimumFare ? minimumFare : total;

              return Column(
                children: [
                  // Category selector
                  Row(
                    children: [
                      Text(
                        'Category:',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SegmentedButton<VehicleCategory>(
                          segments: VehicleCategory.values.map((cat) => ButtonSegment(
                            value: cat,
                            label: Text(
                              cat.displayName,
                              style: const TextStyle(fontSize: 11),
                            ),
                          )).toList(),
                          selected: {_selectedCategory},
                          onSelectionChanged: (selected) {
                            setState(() => _selectedCategory = selected.first);
                          },
                          showSelectedIcon: false,
                          style: ButtonStyle(
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Distance slider
                  Row(
                    children: [
                      Text(
                        'Distance:',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                      Expanded(
                        child: Slider(
                          value: _distance,
                          min: 1,
                          max: 100,
                          divisions: 99,
                          label: '${_distance.toStringAsFixed(0)} km',
                          onChanged: (v) => setState(() => _distance = v),
                        ),
                      ),
                      Text(
                        '${_distance.toStringAsFixed(0)} km',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),

                  const Divider(height: 24),

                  // Breakdown
                  _buildBreakdownRow(context, 'Base Fare (${_selectedCategory.displayName})', '₱${baseFare.toStringAsFixed(0)}'),
                  const SizedBox(height: 8),
                  _buildBreakdownRow(
                    context,
                    'Distance (${_distance.toStringAsFixed(0)} km × ₱${perKmRate.toStringAsFixed(0)})',
                    '₱${distanceFee.toStringAsFixed(0)}',
                  ),
                  if (total < minimumFare) ...[
                    const SizedBox(height: 8),
                    _buildBreakdownRow(
                      context,
                      'Minimum fare applied',
                      '₱${minimumFare.toStringAsFixed(0)}',
                      isNote: true,
                    ),
                  ],

                  const Divider(height: 24),

                  // Total
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Estimated Total',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        '₱${finalTotal.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 22,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Center(child: Text('Error loading config')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Error loading category pricing')),
      ),
    );
  }

  Widget _buildBreakdownRow(BuildContext context, String label, String value, {bool isNote = false}) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isNote ? AppColors.warning : colorScheme.onSurfaceVariant,
            fontStyle: isNote ? FontStyle.italic : FontStyle.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: isNote ? AppColors.warning : colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
