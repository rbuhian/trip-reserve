import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/pricing.dart';
import '../providers/supabase_provider.dart';

/// Provider for PricingRepository
final pricingRepositoryProvider = Provider<PricingRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return PricingRepository(client);
});

/// Repository for pricing configuration and add-ons
class PricingRepository {
  final SupabaseClient _client;

  PricingRepository(this._client);

  SupabaseQueryBuilder get _configTable => _client.from('pricing_config');
  SupabaseQueryBuilder get _addonsTable => _client.from('pricing_addons');

  /// Get the active pricing configuration
  Future<PricingConfig?> getActivePricingConfig() async {
    final response = await _configTable
        .select()
        .eq('is_active', true)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    return response != null ? PricingConfig.fromJson(response) : null;
  }

  /// Get all available (active) add-ons
  Future<List<PricingAddon>> getAvailableAddons() async {
    final response = await _addonsTable
        .select()
        .eq('is_active', true)
        .order('display_order');

    return (response as List)
        .map((json) => PricingAddon.fromJson(json))
        .toList();
  }

  /// Get a specific add-on by ID
  Future<PricingAddon?> getAddonById(String id) async {
    final response = await _addonsTable
        .select()
        .eq('id', id)
        .maybeSingle();

    return response != null ? PricingAddon.fromJson(response) : null;
  }

  /// Calculate fare for a booking
  Future<PriceBreakdown> calculateFare({
    required double distanceKm,
    List<SelectedAddon> selectedAddons = const [],
  }) async {
    final config = await getActivePricingConfig();
    if (config == null) {
      throw Exception('No active pricing configuration found');
    }

    final baseFare = config.baseRate;
    final distanceFee = config.calculateDistanceFee(distanceKm);

    // Calculate addons total
    double addonsTotal = 0;
    final addonLineItems = <AddonLineItem>[];

    for (final selected in selectedAddons) {
      final addon = await getAddonById(selected.addonId);
      if (addon != null) {
        final addonTotal = addon.calculatePrice(selected.quantity);
        addonsTotal += addonTotal;
        addonLineItems.add(AddonLineItem(
          name: addon.name,
          quantity: selected.quantity,
          unitPrice: addon.price,
          totalPrice: addonTotal,
        ));
      }
    }

    final subtotal = baseFare + distanceFee;
    final total = subtotal + addonsTotal;

    // Apply minimum fare
    final finalTotal = total < config.minimumFare ? config.minimumFare : total;

    return PriceBreakdown(
      baseFare: baseFare,
      distanceFee: distanceFee,
      distanceKm: distanceKm,
      addons: addonLineItems,
      subtotal: subtotal,
      totalAmount: finalTotal,
    );
  }
}

/// Selected addon with quantity
class SelectedAddon {
  final String addonId;
  final int quantity;

  const SelectedAddon({
    required this.addonId,
    this.quantity = 1,
  });
}

/// Price breakdown for display
class PriceBreakdown {
  final double baseFare;
  final double distanceFee;
  final double distanceKm;
  final List<AddonLineItem> addons;
  final double subtotal;
  final double totalAmount;

  const PriceBreakdown({
    required this.baseFare,
    required this.distanceFee,
    required this.distanceKm,
    required this.addons,
    required this.subtotal,
    required this.totalAmount,
  });

  double get addonsTotal => addons.fold(0, (sum, item) => sum + item.totalPrice);

  String get baseFareText => '₱${baseFare.toStringAsFixed(0)}';
  String get distanceFeeText => '₱${distanceFee.toStringAsFixed(0)}';
  String get addonsTotalText => '₱${addonsTotal.toStringAsFixed(0)}';
  String get subtotalText => '₱${subtotal.toStringAsFixed(0)}';
  String get totalText => '₱${totalAmount.toStringAsFixed(0)}';
}

/// Line item for addon in breakdown
class AddonLineItem {
  final String name;
  final int quantity;
  final double unitPrice;
  final double totalPrice;

  const AddonLineItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  String get quantityText => quantity > 1 ? 'x$quantity' : '';
  String get priceText => '₱${totalPrice.toStringAsFixed(0)}';
}

// ============================================================
// ADMIN PRICING REPOSITORY
// ============================================================

/// Provider for AdminPricingRepository
final adminPricingRepositoryProvider = Provider<AdminPricingRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return AdminPricingRepository(client);
});

/// Repository for admin pricing management
class AdminPricingRepository {
  final SupabaseClient _client;

  AdminPricingRepository(this._client);

  SupabaseQueryBuilder get _configTable => _client.from('pricing_config');
  SupabaseQueryBuilder get _addonsTable => _client.from('pricing_addons');

  // ============================================================
  // PRICING CONFIG METHODS
  // ============================================================

  /// Get all pricing configurations
  Future<List<PricingConfig>> getAllPricingConfigs() async {
    final response = await _configTable
        .select()
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => PricingConfig.fromJson(json))
        .toList();
  }

  /// Get the active pricing configuration
  Future<PricingConfig?> getActivePricingConfig() async {
    final response = await _configTable
        .select()
        .eq('is_active', true)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    return response != null ? PricingConfig.fromJson(response) : null;
  }

  /// Create new pricing configuration
  Future<PricingConfig> createPricingConfig({
    required double baseRate,
    required double perKmRate,
    required double minimumFare,
    required int cancellationHours,
    required double cancellationFeePercent,
    bool isActive = true,
  }) async {
    // If this is set as active, deactivate all others first
    if (isActive) {
      await _configTable.update({'is_active': false}).eq('is_active', true);
    }

    final response = await _configTable
        .insert({
          'base_rate': baseRate,
          'per_km_rate': perKmRate,
          'minimum_fare': minimumFare,
          'cancellation_hours': cancellationHours,
          'cancellation_fee_percent': cancellationFeePercent,
          'is_active': isActive,
        })
        .select()
        .single();

    return PricingConfig.fromJson(response);
  }

  /// Update pricing configuration
  Future<PricingConfig> updatePricingConfig(
    String id, {
    double? baseRate,
    double? perKmRate,
    double? minimumFare,
    int? cancellationHours,
    double? cancellationFeePercent,
    bool? isActive,
  }) async {
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (baseRate != null) updates['base_rate'] = baseRate;
    if (perKmRate != null) updates['per_km_rate'] = perKmRate;
    if (minimumFare != null) updates['minimum_fare'] = minimumFare;
    if (cancellationHours != null) updates['cancellation_hours'] = cancellationHours;
    if (cancellationFeePercent != null) updates['cancellation_fee_percent'] = cancellationFeePercent;
    if (isActive != null) {
      // If setting as active, deactivate all others first
      if (isActive) {
        await _configTable.update({'is_active': false}).eq('is_active', true);
      }
      updates['is_active'] = isActive;
    }

    final response = await _configTable
        .update(updates)
        .eq('id', id)
        .select()
        .single();

    return PricingConfig.fromJson(response);
  }

  /// Delete pricing configuration
  Future<void> deletePricingConfig(String id) async {
    await _configTable.delete().eq('id', id);
  }

  // ============================================================
  // PRICING ADDONS METHODS
  // ============================================================

  /// Get all add-ons (including inactive)
  Future<List<PricingAddon>> getAllAddons() async {
    final response = await _addonsTable
        .select()
        .order('display_order');

    return (response as List)
        .map((json) => PricingAddon.fromJson(json))
        .toList();
  }

  /// Get add-on by ID
  Future<PricingAddon?> getAddonById(String id) async {
    final response = await _addonsTable
        .select()
        .eq('id', id)
        .maybeSingle();

    return response != null ? PricingAddon.fromJson(response) : null;
  }

  /// Create new add-on
  Future<PricingAddon> createAddon({
    required String name,
    String? description,
    required String addonType,
    required double price,
    String? icon,
    int displayOrder = 0,
    bool isActive = true,
  }) async {
    final response = await _addonsTable
        .insert({
          'name': name,
          'description': description,
          'addon_type': addonType,
          'price': price,
          'icon': icon,
          'display_order': displayOrder,
          'is_active': isActive,
        })
        .select()
        .single();

    return PricingAddon.fromJson(response);
  }

  /// Update add-on
  Future<PricingAddon> updateAddon(
    String id, {
    String? name,
    String? description,
    String? addonType,
    double? price,
    String? icon,
    int? displayOrder,
    bool? isActive,
  }) async {
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (name != null) updates['name'] = name;
    if (description != null) updates['description'] = description;
    if (addonType != null) updates['addon_type'] = addonType;
    if (price != null) updates['price'] = price;
    if (icon != null) updates['icon'] = icon;
    if (displayOrder != null) updates['display_order'] = displayOrder;
    if (isActive != null) updates['is_active'] = isActive;

    final response = await _addonsTable
        .update(updates)
        .eq('id', id)
        .select()
        .single();

    return PricingAddon.fromJson(response);
  }

  /// Delete add-on
  Future<void> deleteAddon(String id) async {
    await _addonsTable.delete().eq('id', id);
  }

  /// Reorder add-ons
  Future<void> reorderAddons(List<String> addonIds) async {
    for (int i = 0; i < addonIds.length; i++) {
      await _addonsTable
          .update({'display_order': i})
          .eq('id', addonIds[i]);
    }
  }
}
