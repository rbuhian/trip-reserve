import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/booking.dart';
import '../services/places_service.dart';

/// Provider for PlacesService
final placesServiceProvider = Provider<PlacesService>((ref) {
  return PlacesService();
});

/// State for place autocomplete search
class PlaceSearchState {
  final String query;
  final List<PlacePrediction> predictions;
  final bool isLoading;
  final String? error;

  const PlaceSearchState({
    this.query = '',
    this.predictions = const [],
    this.isLoading = false,
    this.error,
  });

  PlaceSearchState copyWith({
    String? query,
    List<PlacePrediction>? predictions,
    bool? isLoading,
    String? error,
  }) {
    return PlaceSearchState(
      query: query ?? this.query,
      predictions: predictions ?? this.predictions,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  bool get isEmpty => predictions.isEmpty && !isLoading && error == null;
  bool get hasResults => predictions.isNotEmpty;
}

/// StateNotifier for managing place search
class PlaceSearchNotifier extends StateNotifier<PlaceSearchState> {
  final PlacesService _placesService;
  Timer? _debounceTimer;

  PlaceSearchNotifier(this._placesService) : super(const PlaceSearchState());

  /// Search for places with debouncing
  void search(String query) {
    // Cancel previous timer
    _debounceTimer?.cancel();

    // Update query immediately
    state = state.copyWith(query: query, error: null);

    // Clear results if query is empty
    if (query.trim().isEmpty) {
      state = state.copyWith(predictions: [], isLoading: false);
      return;
    }

    // Show loading
    state = state.copyWith(isLoading: true);

    // Debounce the search
    _debounceTimer = Timer(const Duration(milliseconds: 400), () async {
      try {
        final predictions = await _placesService.searchPlaces(query);
        // Only update if query hasn't changed
        if (state.query == query) {
          state = state.copyWith(
            predictions: predictions,
            isLoading: false,
          );
        }
      } on PlacesServiceException catch (e) {
        if (state.query == query) {
          state = state.copyWith(
            isLoading: false,
            error: e.message,
            predictions: [],
          );
        }
      }
    });
  }

  /// Get place details and return LocationData
  Future<LocationData?> selectPlace(PlacePrediction prediction) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final location = await _placesService.getPlaceDetails(prediction.placeId);
      state = state.copyWith(
        isLoading: false,
        predictions: [],
        query: '',
      );
      return location;
    } on PlacesServiceException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message,
      );
      return null;
    }
  }

  /// Clear search state
  void clear() {
    _debounceTimer?.cancel();
    state = const PlaceSearchState();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

/// Provider for pickup location search
final pickupSearchProvider =
    StateNotifierProvider.autoDispose<PlaceSearchNotifier, PlaceSearchState>(
  (ref) {
    final placesService = ref.watch(placesServiceProvider);
    return PlaceSearchNotifier(placesService);
  },
);

/// Provider for dropoff location search
final dropoffSearchProvider =
    StateNotifierProvider.autoDispose<PlaceSearchNotifier, PlaceSearchState>(
  (ref) {
    final placesService = ref.watch(placesServiceProvider);
    return PlaceSearchNotifier(placesService);
  },
);
