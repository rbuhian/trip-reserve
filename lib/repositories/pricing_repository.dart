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
