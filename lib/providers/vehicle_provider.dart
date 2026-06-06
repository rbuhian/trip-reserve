import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/vehicle.dart';
import '../repositories/vehicle_repository.dart';

/// Provider for driver's vehicles list
final myVehiclesProvider = AsyncNotifierProvider<MyVehiclesNotifier, List<Vehicle>>(
  MyVehiclesNotifier.new,
);

class MyVehiclesNotifier extends AsyncNotifier<List<Vehicle>> {
  @override
  FutureOr<List<Vehicle>> build() async {
    final repository = ref.watch(vehicleRepositoryProvider);
    return repository.getMyVehicles();
  }

  /// Refresh the vehicles list
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(vehicleRepositoryProvider);
      return repository.getMyVehicles();
    });
  }

  /// Add a new vehicle
  Future<Vehicle> add(VehicleCreate data) async {
    final repository = ref.read(vehicleRepositoryProvider);
    final vehicle = await repository.create(data);

    // Update local state
    state = AsyncData([vehicle, ...state.valueOrNull ?? []]);

    return vehicle;
  }

  /// Update a vehicle
  Future<Vehicle> updateVehicle(String id, VehicleUpdate data) async {
    final repository = ref.read(vehicleRepositoryProvider);
    final updated = await repository.update(id, data);

    // Update local state
    state = AsyncData(
      state.valueOrNull
              ?.map((v) => v.id == id ? updated : v)
              .toList() ??
          [],
    );

    return updated;
  }

  /// Deactivate a vehicle
  Future<void> deactivate(String id) async {
    final repository = ref.read(vehicleRepositoryProvider);
    await repository.deactivate(id);

    // Update local state
    state = AsyncData(
      state.valueOrNull
              ?.map((v) => v.id == id ? v.copyWith(isActive: false) : v)
              .toList() ??
          [],
    );
  }

  /// Reactivate a vehicle
  Future<void> reactivate(String id) async {
    final repository = ref.read(vehicleRepositoryProvider);
    await repository.reactivate(id);

    // Update local state
    state = AsyncData(
      state.valueOrNull
              ?.map((v) => v.id == id ? v.copyWith(isActive: true) : v)
              .toList() ??
          [],
    );
  }

  /// Delete a vehicle
  Future<void> delete(String id) async {
    final repository = ref.read(vehicleRepositoryProvider);
    await repository.delete(id);

    // Update local state
    state = AsyncData(
      state.valueOrNull?.where((v) => v.id != id).toList() ?? [],
    );
  }
}

/// Provider for active vehicles only
final myActiveVehiclesProvider = Provider<List<Vehicle>>((ref) {
  final vehicles = ref.watch(myVehiclesProvider);
  return vehicles.valueOrNull?.where((v) => v.isActive).toList() ?? [];
});

/// Provider for a single vehicle by ID
final vehicleByIdProvider = FutureProvider.family<Vehicle?, String>((ref, id) async {
  final repository = ref.watch(vehicleRepositoryProvider);
  return repository.getById(id);
});

/// Provider for available vehicles (for customer booking)
final availableVehiclesProvider = FutureProvider<List<Vehicle>>((ref) async {
  final repository = ref.watch(vehicleRepositoryProvider);
  return repository.getAvailableVehicles();
});

/// Provider for vehicle form state
final vehicleFormProvider = StateNotifierProvider<VehicleFormNotifier, VehicleFormState>(
  (ref) => VehicleFormNotifier(),
);

class VehicleFormState {
  final String name;
  final String plateNumber;
  final int capacity;
  final String? imageUrl;
  final String? description;
  final bool isLoading;
  final String? error;

  const VehicleFormState({
    this.name = '',
    this.plateNumber = '',
    this.capacity = 4,
    this.imageUrl,
    this.description,
    this.isLoading = false,
    this.error,
  });

  VehicleFormState copyWith({
    String? name,
    String? plateNumber,
    int? capacity,
    String? imageUrl,
    String? description,
    bool? isLoading,
    String? error,
  }) {
    return VehicleFormState(
      name: name ?? this.name,
      plateNumber: plateNumber ?? this.plateNumber,
      capacity: capacity ?? this.capacity,
      imageUrl: imageUrl ?? this.imageUrl,
      description: description ?? this.description,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  bool get isValid =>
      name.trim().isNotEmpty &&
      plateNumber.trim().isNotEmpty &&
      capacity > 0;

  VehicleCreate toCreate() => VehicleCreate(
        name: name.trim(),
        plateNumber: plateNumber.trim().toUpperCase(),
        capacity: capacity,
        imageUrl: imageUrl,
        description: description?.trim(),
      );

  VehicleUpdate toUpdate() => VehicleUpdate(
        name: name.trim(),
        plateNumber: plateNumber.trim().toUpperCase(),
        capacity: capacity,
        imageUrl: imageUrl,
        description: description?.trim(),
      );
}

class VehicleFormNotifier extends StateNotifier<VehicleFormState> {
  VehicleFormNotifier() : super(const VehicleFormState());

  void setName(String value) => state = state.copyWith(name: value);
  void setPlateNumber(String value) => state = state.copyWith(plateNumber: value);
  void setCapacity(int value) => state = state.copyWith(capacity: value);
  void setImageUrl(String? value) => state = state.copyWith(imageUrl: value);
  void setDescription(String? value) => state = state.copyWith(description: value);
  void setLoading(bool value) => state = state.copyWith(isLoading: value);
  void setError(String? value) => state = state.copyWith(error: value);

  void reset() => state = const VehicleFormState();

  void loadFromVehicle(Vehicle vehicle) {
    state = VehicleFormState(
      name: vehicle.name,
      plateNumber: vehicle.plateNumber,
      capacity: vehicle.capacity,
      imageUrl: vehicle.imageUrl,
      description: vehicle.description,
    );
  }
}
