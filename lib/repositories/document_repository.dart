import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/document.dart';
import '../models/vehicle.dart';
import '../providers/supabase_provider.dart';

/// Repository for document management
class DocumentRepository {
  final SupabaseClient _client;

  DocumentRepository(this._client);

  String get _userId => _client.auth.currentUser!.id;

  // ============================================
  // VEHICLE PHOTOS
  // ============================================

  /// Get all photos for a vehicle
  Future<List<VehiclePhoto>> getVehiclePhotos(String vehicleId) async {
    final response = await _client
        .from('vehicle_photos')
        .select()
        .eq('vehicle_id', vehicleId)
        .order('photo_type');

    return (response as List)
        .map((json) => VehiclePhoto.fromJson(json))
        .toList();
  }

  /// Add a vehicle photo
  Future<VehiclePhoto> addVehiclePhoto({
    required String vehicleId,
    required VehiclePhotoType photoType,
    required String storagePath,
    required String url,
  }) async {
    // Delete existing photo of this type first
    await _client
        .from('vehicle_photos')
        .delete()
        .eq('vehicle_id', vehicleId)
        .eq('photo_type', photoType.value);

    final response = await _client
        .from('vehicle_photos')
        .insert({
          'vehicle_id': vehicleId,
          'photo_type': photoType.value,
          'storage_path': storagePath,
          'url': url,
        })
        .select()
        .single();

    return VehiclePhoto.fromJson(response);
  }

  /// Delete a vehicle photo
  Future<void> deleteVehiclePhoto(String photoId) async {
    await _client.from('vehicle_photos').delete().eq('id', photoId);
  }

  /// Delete all photos for a vehicle
  Future<void> deleteAllVehiclePhotos(String vehicleId) async {
    await _client.from('vehicle_photos').delete().eq('vehicle_id', vehicleId);
  }

  // ============================================
  // USER DOCUMENTS
  // ============================================

  /// Get all documents for the current user
  Future<List<Document>> getMyDocuments() async {
    final response = await _client
        .from('documents')
        .select()
        .eq('user_id', _userId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => Document.fromJson(json))
        .toList();
  }

  /// Get documents for a specific vehicle
  Future<List<Document>> getVehicleDocuments(String vehicleId) async {
    final response = await _client
        .from('documents')
        .select()
        .eq('vehicle_id', vehicleId)
        .order('document_type');

    return (response as List)
        .map((json) => Document.fromJson(json))
        .toList();
  }

  /// Get driver's license document
  Future<Document?> getDriversLicense() async {
    final response = await _client
        .from('documents')
        .select()
        .eq('user_id', _userId)
        .eq('document_type', DocumentType.driversLicense.value)
        .neq('status', DocumentStatus.rejected.name)
        .maybeSingle();

    return response != null ? Document.fromJson(response) : null;
  }

  /// Get vehicle OR document
  Future<Document?> getVehicleOr(String vehicleId) async {
    final response = await _client
        .from('documents')
        .select()
        .eq('vehicle_id', vehicleId)
        .eq('document_type', DocumentType.vehicleOr.value)
        .neq('status', DocumentStatus.rejected.name)
        .maybeSingle();

    return response != null ? Document.fromJson(response) : null;
  }

  /// Get vehicle CR document
  Future<Document?> getVehicleCr(String vehicleId) async {
    final response = await _client
        .from('documents')
        .select()
        .eq('vehicle_id', vehicleId)
        .eq('document_type', DocumentType.vehicleCr.value)
        .neq('status', DocumentStatus.rejected.name)
        .maybeSingle();

    return response != null ? Document.fromJson(response) : null;
  }

  /// Upload a document
  Future<Document> uploadDocument(DocumentUpload data) async {
    // Delete existing document of this type first (if not rejected)
    if (data.documentType.isVehicleDocument && data.vehicleId != null) {
      await _client
          .from('documents')
          .delete()
          .eq('vehicle_id', data.vehicleId!)
          .eq('document_type', data.documentType.value)
          .neq('status', DocumentStatus.rejected.name);
    } else {
      await _client
          .from('documents')
          .delete()
          .eq('user_id', _userId)
          .eq('document_type', data.documentType.value)
          .isFilter('vehicle_id', null)
          .neq('status', DocumentStatus.rejected.name);
    }

    final response = await _client
        .from('documents')
        .insert({
          'user_id': _userId,
          'vehicle_id': data.vehicleId,
          'document_type': data.documentType.value,
          'status': DocumentStatus.pending.name,
          'storage_path': data.storagePath,
          'url': data.url,
          'file_name': data.fileName,
          'file_size': data.fileSize,
          'mime_type': data.mimeType,
          'document_number': data.documentNumber,
          'expiry_date': data.expiryDate?.toIso8601String(),
        })
        .select()
        .single();

    return Document.fromJson(response);
  }

  /// Delete a document
  Future<void> deleteDocument(String documentId) async {
    await _client.from('documents').delete().eq('id', documentId);
  }

  // ============================================
  // ADMIN FUNCTIONS
  // ============================================

  /// Get all pending documents (admin)
  Future<List<Document>> getPendingDocuments() async {
    final response = await _client
        .from('documents')
        .select()
        .eq('status', DocumentStatus.pending.name)
        .order('created_at');

    return (response as List)
        .map((json) => Document.fromJson(json))
        .toList();
  }

  /// Approve a document (admin)
  Future<Document> approveDocument(String documentId) async {
    final response = await _client
        .from('documents')
        .update({
          'status': DocumentStatus.approved.name,
          'reviewed_by': _userId,
          'reviewed_at': DateTime.now().toIso8601String(),
        })
        .eq('id', documentId)
        .select()
        .single();

    return Document.fromJson(response);
  }

  /// Reject a document (admin)
  Future<Document> rejectDocument(String documentId, String reason) async {
    final response = await _client
        .from('documents')
        .update({
          'status': DocumentStatus.rejected.name,
          'reviewed_by': _userId,
          'reviewed_at': DateTime.now().toIso8601String(),
          'rejection_reason': reason,
        })
        .eq('id', documentId)
        .select()
        .single();

    return Document.fromJson(response);
  }
}

/// Provider for DocumentRepository
final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return DocumentRepository(client);
});
