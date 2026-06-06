import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/booking.dart';

/// Service for Google Places API operations
class PlacesService {
  static const _placesBaseUrl = 'https://maps.googleapis.com/maps/api/place';

  /// Get place details (coordinates) from a place ID
  Future<LocationData> getPlaceDetails(String placeId) async {
    final url = Uri.parse(
      '$_placesBaseUrl/details/json'
      '?place_id=$placeId'
      '&fields=geometry,formatted_address,name'
      '&key=${AppConfig.googleMapsApiKey}',
    );

    try {
      final response = await http.get(url);

      if (response.statusCode != 200) {
        throw PlacesServiceException(
          'Failed to fetch place details',
          code: PlacesErrorCode.networkError,
        );
      }

      final data = json.decode(response.body);

      if (data['status'] != 'OK') {
        throw PlacesServiceException(
          data['error_message'] ?? 'Failed to get place details',
          code: _mapStatusToErrorCode(data['status']),
        );
      }

      final result = data['result'];
      final location = result['geometry']['location'];
      final address = result['formatted_address'] ?? result['name'] ?? '';

      return LocationData(
        address: address,
        lat: location['lat'].toDouble(),
        lng: location['lng'].toDouble(),
      );
    } catch (e) {
      if (e is PlacesServiceException) rethrow;
      throw PlacesServiceException(
        'Failed to fetch place details: $e',
        code: PlacesErrorCode.unknown,
      );
    }
  }

  /// Search for places (autocomplete)
  Future<List<PlacePrediction>> searchPlaces(String query) async {
    if (query.trim().isEmpty) return [];

    final url = Uri.parse(
      '$_placesBaseUrl/autocomplete/json'
      '?input=${Uri.encodeComponent(query)}'
      '&components=country:ph'
      '&key=${AppConfig.googleMapsApiKey}',
    );

    try {
      final response = await http.get(url);

      if (response.statusCode != 200) {
        throw PlacesServiceException(
          'Failed to search places',
          code: PlacesErrorCode.networkError,
        );
      }

      final data = json.decode(response.body);

      if (data['status'] != 'OK' && data['status'] != 'ZERO_RESULTS') {
        throw PlacesServiceException(
          data['error_message'] ?? 'Failed to search places',
          code: _mapStatusToErrorCode(data['status']),
        );
      }

      final predictions = data['predictions'] as List<dynamic>;
      return predictions
          .map((p) => PlacePrediction(
                placeId: p['place_id'],
                description: p['description'],
                mainText: p['structured_formatting']?['main_text'] ?? '',
                secondaryText:
                    p['structured_formatting']?['secondary_text'] ?? '',
              ))
          .toList();
    } catch (e) {
      if (e is PlacesServiceException) rethrow;
      throw PlacesServiceException(
        'Failed to search places: $e',
        code: PlacesErrorCode.unknown,
      );
    }
  }

  PlacesErrorCode _mapStatusToErrorCode(String status) {
    switch (status) {
      case 'ZERO_RESULTS':
        return PlacesErrorCode.noResults;
      case 'OVER_QUERY_LIMIT':
        return PlacesErrorCode.quotaExceeded;
      case 'REQUEST_DENIED':
        return PlacesErrorCode.requestDenied;
      case 'INVALID_REQUEST':
        return PlacesErrorCode.invalidRequest;
      default:
        return PlacesErrorCode.unknown;
    }
  }
}

/// Place prediction from autocomplete
class PlacePrediction {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;

  const PlacePrediction({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });
}

/// Error codes for places service
enum PlacesErrorCode {
  noResults,
  quotaExceeded,
  requestDenied,
  invalidRequest,
  networkError,
  unknown,
}

/// Custom exception for places errors
class PlacesServiceException implements Exception {
  final String message;
  final PlacesErrorCode code;

  PlacesServiceException(this.message, {required this.code});

  @override
  String toString() => message;
}
