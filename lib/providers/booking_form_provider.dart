import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/booking.dart';
import '../models/pricing.dart';
import '../models/vehicle.dart';
import '../repositories/booking_repository.dart';
import '../repositories/pricing_repository.dart';
import '../repositories/vehicle_repository.dart';
import 'location_provider.dart';

/// Booking form state for multi-step booking flow
class BookingFormState {
  // Step 1: Location (from LocationSelectionState)
  final LocationData? pickup;
  final LocationData? dropoff;
  final double? distanceKm;
  final int? durationMinutes;

  // Step 2: Date & Time
  final DateTime? scheduledDate;
  final String? pickupTime; // Format: "HH:mm"

  // Step 3: Vehicle
  final Vehicle? selectedVehicle;

  // Step 4: Add-ons
  final List<SelectedAddonItem> selectedAddons;

  // Pricing
  final PriceBreakdown? priceBreakdown;
  final PricingConfig? pricingConfig;

  // Form state
  final bool isLoading;
  final String? error;
  final int currentStep;

  const BookingFormState({
    this.pickup,
    this.dropoff,
    this.distanceKm,
    this.durationMinutes,
    this.scheduledDate,
    this.pickupTime,
    this.selectedVehicle,
    this.selectedAddons = const [],
    this.priceBreakdown,
    this.pricingConfig,
    this.isLoading = false,
    this.error,
    this.currentStep = 0,
  });

  /// Check if location step is complete
  bool get isLocationComplete =>
      pickup != null && dropoff != null && distanceKm != null;

  /// Check if date/time step is complete
  bool get isDateTimeComplete => scheduledDate != null && pickupTime != null;

  /// Check if vehicle step is complete
  bool get isVehicleComplete => selectedVehicle != null;

  /// Check if all required fields are complete
  bool get isComplete =>
      isLocationComplete && isDateTimeComplete && isVehicleComplete;

  /// Get total add-ons fee
  double get addonsTotal =>
      selectedAddons.fold(0, (sum, item) => sum + item.totalPrice);

  /// Formatted distance text
  String get distanceText =>
      distanceKm != null ? '${distanceKm!.toStringAsFixed(1)} km' : '-';

  /// Formatted duration text
  String get durationText {
    if (durationMinutes == null) return '-';
    if (durationMinutes! < 60) return '$durationMinutes min';
    final hours = durationMinutes! ~/ 60;
    final mins = durationMinutes! % 60;
    return mins > 0 ? '${hours}h ${mins}min' : '${hours}h';
  }

  /// Formatted date text
  String get dateText {
    if (scheduledDate == null) return '-';
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[scheduledDate!.month - 1]} ${scheduledDate!.day}, ${scheduledDate!.year}';
  }

  /// Formatted time text
  String get timeText {
    if (pickupTime == null) return '-';
    final parts = pickupTime!.split(':');
    final hour = int.parse(parts[0]);
    final minute = parts[1];
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  BookingFormState copyWith({
    LocationData? pickup,
    LocationData? dropoff,
    double? distanceKm,
    int? durationMinutes,
    DateTime? scheduledDate,
    String? pickupTime,
    Vehicle? selectedVehicle,
    List<SelectedAddonItem>? selectedAddons,
    PriceBreakdown? priceBreakdown,
    PricingConfig? pricingConfig,
    bool? isLoading,
    String? error,
    int? currentStep,
    bool clearError = false,
    bool clearVehicle = false,
  }) {
    return BookingFormState(
      pickup: pickup ?? this.pickup,
      dropoff: dropoff ?? this.dropoff,
      distanceKm: distanceKm ?? this.distanceKm,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      pickupTime: pickupTime ?? this.pickupTime,
      selectedVehicle: clearVehicle ? null : (selectedVehicle ?? this.selectedVehicle),
      selectedAddons: selectedAddons ?? this.selectedAddons,
      priceBreakdown: priceBreakdown ?? this.priceBreakdown,
      pricingConfig: pricingConfig ?? this.pricingConfig,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      currentStep: currentStep ?? this.currentStep,
    );
  }
}

/// Selected add-on with quantity
class SelectedAddonItem {
  final PricingAddon addon;
  final int quantity;

  const SelectedAddonItem({
    required this.addon,
    this.quantity = 1,
  });

  double get totalPrice => addon.price * quantity;

  SelectedAddonItem copyWith({int? quantity}) {
    return SelectedAddonItem(
      addon: addon,
      quantity: quantity ?? this.quantity,
    );
  }
}

/// Provider for booking form state
final bookingFormProvider =
    StateNotifierProvider<BookingFormNotifier, BookingFormState>((ref) {
  return BookingFormNotifier(ref);
});

/// Notifier for booking form state
class BookingFormNotifier extends StateNotifier<BookingFormState> {
  final Ref _ref;

  BookingFormNotifier(this._ref) : super(const BookingFormState());

  /// Initialize form with location data from LocationSelectionState
  void initializeFromLocation() {
    final locationState = _ref.read(locationSelectionProvider);
    if (locationState.pickup != null && locationState.dropoff != null) {
      final distanceKm = locationState.distanceKm;
      // Estimate duration: assume ~30 km/h average speed in city traffic
      final durationMinutes = distanceKm != null ? (distanceKm / 30 * 60).round() : null;

      state = state.copyWith(
        pickup: LocationData(
          address: locationState.pickup!.address,
          lat: locationState.pickup!.lat,
          lng: locationState.pickup!.lng,
        ),
        dropoff: LocationData(
          address: locationState.dropoff!.address,
          lat: locationState.dropoff!.lat,
          lng: locationState.dropoff!.lng,
        ),
        distanceKm: distanceKm,
        durationMinutes: durationMinutes,
        currentStep: 1,
        clearError: true,
      );
      _loadPricingConfig();
    }
  }

  /// Load pricing configuration
  Future<void> _loadPricingConfig() async {
    try {
      final pricingRepo = _ref.read(pricingRepositoryProvider);
      final config = await pricingRepo.getActivePricingConfig();
      if (config != null) {
        state = state.copyWith(pricingConfig: config);
        _updatePriceBreakdown();
      }
    } catch (e) {
      state = state.copyWith(error: 'Failed to load pricing: $e');
    }
  }

  /// Set scheduled date
  /// Clears selected vehicle since availability may have changed
  void setDate(DateTime date) {
    state = state.copyWith(
      scheduledDate: date,
      clearError: true,
      clearVehicle: true, // Clear vehicle when date changes
    );
    _updatePriceBreakdown();
  }

  /// Set pickup time
  /// Clears selected vehicle since availability may have changed
  void setTime(String time) {
    state = state.copyWith(
      pickupTime: time,
      clearError: true,
      clearVehicle: true, // Clear vehicle when time changes
    );
  }

  /// Set selected vehicle
  void setVehicle(Vehicle vehicle) {
    state = state.copyWith(
      selectedVehicle: vehicle,
      clearError: true,
    );
  }

  /// Clear selected vehicle
  void clearVehicle() {
    state = state.copyWith(clearVehicle: true);
  }

  /// Add an addon
  void addAddon(PricingAddon addon, {int quantity = 1}) {
    final existing = state.selectedAddons
        .indexWhere((item) => item.addon.id == addon.id);

    List<SelectedAddonItem> newAddons;
    if (existing >= 0) {
      // Update quantity
      newAddons = [...state.selectedAddons];
      newAddons[existing] = newAddons[existing].copyWith(
        quantity: newAddons[existing].quantity + quantity,
      );
    } else {
      // Add new
      newAddons = [
        ...state.selectedAddons,
        SelectedAddonItem(addon: addon, quantity: quantity),
      ];
    }

    state = state.copyWith(selectedAddons: newAddons);
    _updatePriceBreakdown();
  }

  /// Remove an addon
  void removeAddon(String addonId) {
    final newAddons = state.selectedAddons
        .where((item) => item.addon.id != addonId)
        .toList();
    state = state.copyWith(selectedAddons: newAddons);
    _updatePriceBreakdown();
  }

  /// Update addon quantity
  void updateAddonQuantity(String addonId, int quantity) {
    if (quantity <= 0) {
      removeAddon(addonId);
      return;
    }

    final newAddons = state.selectedAddons.map((item) {
      if (item.addon.id == addonId) {
        return item.copyWith(quantity: quantity);
      }
      return item;
    }).toList();

    state = state.copyWith(selectedAddons: newAddons);
    _updatePriceBreakdown();
  }

  /// Toggle addon (add/remove)
  void toggleAddon(PricingAddon addon) {
    final exists = state.selectedAddons.any((item) => item.addon.id == addon.id);
    if (exists) {
      removeAddon(addon.id);
    } else {
      addAddon(addon);
    }
  }

  /// Check if addon is selected
  bool isAddonSelected(String addonId) {
    return state.selectedAddons.any((item) => item.addon.id == addonId);
  }

  /// Update price breakdown
  void _updatePriceBreakdown() {
    if (state.pricingConfig == null || state.distanceKm == null) return;

    final config = state.pricingConfig!;
    final baseFare = config.baseRate;
    final distanceFee = config.calculateDistanceFee(state.distanceKm!);

    final addonLineItems = state.selectedAddons.map((item) {
      return AddonLineItem(
        name: item.addon.name,
        quantity: item.quantity,
        unitPrice: item.addon.price,
        totalPrice: item.totalPrice,
      );
    }).toList();

    final addonsTotal = state.addonsTotal;
    final subtotal = baseFare + distanceFee;
    final total = subtotal + addonsTotal;
    final finalTotal = total < config.minimumFare ? config.minimumFare : total;

    state = state.copyWith(
      priceBreakdown: PriceBreakdown(
        baseFare: baseFare,
        distanceFee: distanceFee,
        distanceKm: state.distanceKm!,
        addons: addonLineItems,
        subtotal: subtotal,
        totalAmount: finalTotal,
      ),
    );
  }

  /// Set current step
  void setStep(int step) {
    state = state.copyWith(currentStep: step);
  }

  /// Go to next step
  void nextStep() {
    state = state.copyWith(currentStep: state.currentStep + 1);
  }

  /// Go to previous step
  void previousStep() {
    if (state.currentStep > 0) {
      state = state.copyWith(currentStep: state.currentStep - 1);
    }
  }

  /// Submit booking
  Future<Booking?> submitBooking() async {
    if (!state.isComplete) {
      state = state.copyWith(error: 'Please complete all required fields');
      return null;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final bookingRepo = _ref.read(bookingRepositoryProvider);

      final bookingData = BookingCreate(
        pickupAddress: state.pickup!.address,
        pickupLat: state.pickup!.lat,
        pickupLng: state.pickup!.lng,
        dropoffAddress: state.dropoff!.address,
        dropoffLat: state.dropoff!.lat,
        dropoffLng: state.dropoff!.lng,
        distanceKm: state.distanceKm!,
        durationMinutes: state.durationMinutes ?? 0,
        scheduledDate: state.scheduledDate!,
        pickupTime: state.pickupTime!,
        vehicleId: state.selectedVehicle!.id,
        baseFare: state.priceBreakdown?.baseFare ?? 0,
        distanceFee: state.priceBreakdown?.distanceFee ?? 0,
        addonsFee: state.addonsTotal,
        totalAmount: state.priceBreakdown?.totalAmount ?? 0,
      );

      // Create addon data
      final addons = state.selectedAddons.map((item) {
        return BookingAddonCreate(
          addonId: item.addon.id,
          quantity: item.quantity,
          unitPrice: item.addon.price,
          totalPrice: item.totalPrice,
        );
      }).toList();

      final booking = await bookingRepo.create(
        bookingData,
        addons: addons.isNotEmpty ? addons : null,
      );

      state = state.copyWith(isLoading: false);
      return booking;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to create booking: $e',
      );
      return null;
    }
  }

  /// Reset form
  void reset() {
    state = const BookingFormState();
    // Also clear location selection
    _ref.read(locationSelectionProvider.notifier).clearAll();
  }
}

/// Provider for available addons
final availableAddonsProvider = FutureProvider<List<PricingAddon>>((ref) async {
  final pricingRepo = ref.watch(pricingRepositoryProvider);
  return pricingRepo.getAvailableAddons();
});

/// Provider for available vehicles (for customer booking)
final bookingVehiclesProvider = FutureProvider<List<Vehicle>>((ref) async {
  final vehicleRepo = ref.watch(vehicleRepositoryProvider);
  return vehicleRepo.getAvailableVehicles();
});

/// Provider for vehicles available for the selected date/time
/// Returns null if date/time not selected, otherwise returns available vehicles
final availableVehiclesForBookingProvider = FutureProvider<List<Vehicle>?>((ref) async {
  final formState = ref.watch(bookingFormProvider);

  // Return null if date/time not selected yet
  if (formState.scheduledDate == null || formState.pickupTime == null) {
    return null;
  }

  final vehicleRepo = ref.watch(vehicleRepositoryProvider);
  return vehicleRepo.getAvailableVehiclesForDateTime(
    date: formState.scheduledDate!,
    pickupTime: formState.pickupTime!,
    estimatedDurationMinutes: formState.durationMinutes ?? 120,
  );
});
