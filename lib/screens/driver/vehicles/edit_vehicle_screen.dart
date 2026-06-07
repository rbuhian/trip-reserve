import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/document.dart';
import '../../../models/vehicle.dart';
import '../../../providers/vehicle_provider.dart';
import '../../../repositories/document_repository.dart';
import '../../../services/storage_service.dart';
import '../../../widgets/document_upload_card.dart';
import '../../../widgets/photo_upload_card.dart';

/// Provider for vehicle photos
final vehiclePhotosProvider = FutureProvider.family<List<VehiclePhoto>, String>((ref, vehicleId) async {
  final repo = ref.watch(documentRepositoryProvider);
  return repo.getVehiclePhotos(vehicleId);
});

/// Provider for vehicle documents (OR/CR)
final vehicleDocumentsProvider = FutureProvider.family<List<Document>, String>((ref, vehicleId) async {
  final repo = ref.watch(documentRepositoryProvider);
  return repo.getVehicleDocuments(vehicleId);
});

class EditVehicleScreen extends ConsumerStatefulWidget {
  final String vehicleId;

  const EditVehicleScreen({super.key, required this.vehicleId});

  @override
  ConsumerState<EditVehicleScreen> createState() => _EditVehicleScreenState();
}

class _EditVehicleScreenState extends ConsumerState<EditVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _plateController = TextEditingController();
  final _modelController = TextEditingController();
  final _colorController = TextEditingController();
  final _descriptionController = TextEditingController();
  int _capacity = 4;
  int? _year;
  bool _isSubmitting = false;
  bool _initialized = false;

  // Photo management
  final Map<VehiclePhotoType, XFile?> _pendingPhotos = {};
  final Map<VehiclePhotoType, String?> _existingPhotoUrls = {};
  final Set<VehiclePhotoType> _uploadingPhotos = {};
  final Set<VehiclePhotoType> _deletedPhotos = {};

  // Document management
  XFile? _pendingOr;
  XFile? _pendingCr;
  Document? _existingOr;
  Document? _existingCr;
  bool _isUploadingOr = false;
  bool _isUploadingCr = false;

  @override
  void dispose() {
    _nameController.dispose();
    _plateController.dispose();
    _modelController.dispose();
    _colorController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _initializeForm(Vehicle vehicle, List<VehiclePhoto> photos, List<Document> documents) {
    if (_initialized) return;
    _initialized = true;

    _nameController.text = vehicle.name;
    _plateController.text = vehicle.plateNumber;
    _modelController.text = vehicle.model ?? '';
    _colorController.text = vehicle.color ?? '';
    _descriptionController.text = vehicle.description ?? '';
    _capacity = vehicle.capacity;
    _year = vehicle.year;

    // Load existing photos
    for (final photo in photos) {
      _existingPhotoUrls[photo.photoType] = photo.url;
    }

    // Load existing documents
    for (final doc in documents) {
      if (doc.documentType == DocumentType.vehicleOr) {
        _existingOr = doc;
      } else if (doc.documentType == DocumentType.vehicleCr) {
        _existingCr = doc;
      }
    }
  }

  Future<void> _pickPhoto(VehiclePhotoType type) async {
    final file = await ImagePickerHelper.pickImage();
    if (file != null) {
      setState(() {
        _pendingPhotos[type] = file;
        _deletedPhotos.remove(type);
      });
    }
  }

  void _removePhoto(VehiclePhotoType type) {
    setState(() {
      if (_pendingPhotos.containsKey(type)) {
        _pendingPhotos.remove(type);
      } else if (_existingPhotoUrls.containsKey(type)) {
        _deletedPhotos.add(type);
      }
    });
  }

  Future<void> _pickDocument(DocumentType type) async {
    final file = await ImagePickerHelper.pickDocument();
    if (file != null) {
      setState(() {
        if (type == DocumentType.vehicleOr) {
          _pendingOr = file;
        } else {
          _pendingCr = file;
        }
      });
    }
  }

  void _removeDocument(DocumentType type) {
    setState(() {
      if (type == DocumentType.vehicleOr) {
        _pendingOr = null;
      } else {
        _pendingCr = null;
      }
    });
  }

  Future<void> _viewDocument(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open document: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deleteExistingDocument(Document doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document?'),
        content: Text('Are you sure you want to delete this ${doc.documentType.displayName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final storageService = ref.read(storageServiceProvider);
      final documentRepo = ref.read(documentRepositoryProvider);

      await storageService.deleteDocument(doc.storagePath);
      await documentRepo.deleteDocument(doc.id);

      setState(() {
        if (doc.documentType == DocumentType.vehicleOr) {
          _existingOr = null;
        } else {
          _existingCr = null;
        }
      });

      ref.invalidate(vehicleDocumentsProvider(widget.vehicleId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document deleted'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _submit(Vehicle vehicle) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      // Update vehicle info
      final update = VehicleUpdate(
        name: _nameController.text.trim(),
        plateNumber: _plateController.text.trim().toUpperCase(),
        capacity: _capacity,
        year: _year,
        model: _modelController.text.isEmpty ? null : _modelController.text.trim(),
        color: _colorController.text.isEmpty ? null : _colorController.text.trim(),
        description: _descriptionController.text.isEmpty
            ? null
            : _descriptionController.text.trim(),
      );

      await ref.read(myVehiclesProvider.notifier).updateVehicle(vehicle.id, update);

      final storageService = ref.read(storageServiceProvider);
      final documentRepo = ref.read(documentRepositoryProvider);

      // Delete removed photos
      for (final type in _deletedPhotos) {
        final photos = ref.read(vehiclePhotosProvider(widget.vehicleId)).valueOrNull ?? [];
        final photo = photos.where((p) => p.photoType == type).firstOrNull;
        if (photo != null) {
          await storageService.deleteVehiclePhoto(photo.storagePath);
          await documentRepo.deleteVehiclePhoto(photo.id);
        }
      }

      // Upload new photos
      for (final entry in _pendingPhotos.entries) {
        if (entry.value != null) {
          setState(() => _uploadingPhotos.add(entry.key));
          try {
            // Delete existing photo first if any
            final photos = ref.read(vehiclePhotosProvider(widget.vehicleId)).valueOrNull ?? [];
            final existingPhoto = photos.where((p) => p.photoType == entry.key).firstOrNull;
            if (existingPhoto != null) {
              await storageService.deleteVehiclePhoto(existingPhoto.storagePath);
              await documentRepo.deleteVehiclePhoto(existingPhoto.id);
            }

            final result = await storageService.uploadVehiclePhoto(
              vehicleId: vehicle.id,
              photoType: entry.key,
              file: entry.value!,
            );
            await documentRepo.addVehiclePhoto(
              vehicleId: vehicle.id,
              photoType: entry.key,
              storagePath: result.storagePath,
              url: result.url,
            );
          } finally {
            setState(() => _uploadingPhotos.remove(entry.key));
          }
        }
      }

      // Upload OR document
      if (_pendingOr != null) {
        setState(() => _isUploadingOr = true);
        try {
          // Delete existing if any
          if (_existingOr != null) {
            await storageService.deleteDocument(_existingOr!.storagePath);
            await documentRepo.deleteDocument(_existingOr!.id);
          }

          final result = await storageService.uploadDocument(
            userId: vehicle.driverId,
            documentType: DocumentType.vehicleOr,
            file: _pendingOr!,
            vehicleId: vehicle.id,
          );
          await documentRepo.uploadDocument(DocumentUpload(
            documentType: DocumentType.vehicleOr,
            vehicleId: vehicle.id,
            storagePath: result.storagePath,
            url: result.url,
            fileName: result.fileName,
            fileSize: result.fileSize,
            mimeType: result.mimeType,
          ));
        } finally {
          setState(() => _isUploadingOr = false);
        }
      }

      // Upload CR document
      if (_pendingCr != null) {
        setState(() => _isUploadingCr = true);
        try {
          // Delete existing if any
          if (_existingCr != null) {
            await storageService.deleteDocument(_existingCr!.storagePath);
            await documentRepo.deleteDocument(_existingCr!.id);
          }

          final result = await storageService.uploadDocument(
            userId: vehicle.driverId,
            documentType: DocumentType.vehicleCr,
            file: _pendingCr!,
            vehicleId: vehicle.id,
          );
          await documentRepo.uploadDocument(DocumentUpload(
            documentType: DocumentType.vehicleCr,
            vehicleId: vehicle.id,
            storagePath: result.storagePath,
            url: result.url,
            fileName: result.fileName,
            fileSize: result.fileSize,
            mimeType: result.mimeType,
          ));
        } finally {
          setState(() => _isUploadingCr = false);
        }
      }

      // Refresh providers
      ref.invalidate(vehiclePhotosProvider(widget.vehicleId));
      ref.invalidate(vehicleDocumentsProvider(widget.vehicleId));
      ref.invalidate(vehicleByIdProvider(widget.vehicleId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vehicle updated successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _confirmDelete(Vehicle vehicle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Vehicle?'),
        content: Text(
          'Are you sure you want to delete "${vehicle.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await ref.read(myVehiclesProvider.notifier).delete(vehicle.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vehicle deleted'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          context.go('/driver/vehicles');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _toggleActive(Vehicle vehicle) async {
    try {
      if (vehicle.isActive) {
        await ref.read(myVehiclesProvider.notifier).deactivate(vehicle.id);
      } else {
        await ref.read(myVehiclesProvider.notifier).reactivate(vehicle.id);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              vehicle.isActive ? 'Vehicle deactivated' : 'Vehicle activated',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final vehicleAsync = ref.watch(vehicleByIdProvider(widget.vehicleId));
    final photosAsync = ref.watch(vehiclePhotosProvider(widget.vehicleId));
    final documentsAsync = ref.watch(vehicleDocumentsProvider(widget.vehicleId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Vehicle'),
        actions: [
          vehicleAsync.whenOrNull(
            data: (vehicle) => vehicle != null
                ? PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (action) {
                      if (action == 'toggle') {
                        _toggleActive(vehicle);
                      } else if (action == 'delete') {
                        _confirmDelete(vehicle);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'toggle',
                        child: Row(
                          children: [
                            Icon(
                              vehicle.isActive
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(vehicle.isActive ? 'Deactivate' : 'Activate'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: colorScheme.error,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Delete',
                              style: TextStyle(color: colorScheme.error),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : null,
          ) ?? const SizedBox(),
        ],
      ),
      body: vehicleAsync.when(
        data: (vehicle) {
          if (vehicle == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  const Text('Vehicle not found'),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => context.go('/driver/vehicles'),
                    child: const Text('Go back'),
                  ),
                ],
              ),
            );
          }

          // Wait for photos and documents to load
          final photos = photosAsync.valueOrNull ?? [];
          final documents = documentsAsync.valueOrNull ?? [];

          _initializeForm(vehicle, photos, documents);

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Status indicator
                if (!vehicle.isActive)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: colorScheme.error.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 20,
                          color: colorScheme.error,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'This vehicle is currently inactive',
                            style: TextStyle(
                              color: colorScheme.error,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Vehicle Photos Section
                _buildSectionLabel('Vehicle Photos', colorScheme),
                const SizedBox(height: 8),
                Text(
                  'Upload photos of your vehicle from different angles',
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                VehiclePhotoGrid(
                  currentUrls: Map.fromEntries(
                    _existingPhotoUrls.entries
                        .where((e) => !_deletedPhotos.contains(e.key))
                        .where((e) => !_pendingPhotos.containsKey(e.key)),
                  ),
                  pendingFiles: _pendingPhotos,
                  uploadingTypes: _uploadingPhotos,
                  onPhotoTap: _pickPhoto,
                  onPhotoDelete: _removePhoto,
                ),

                const SizedBox(height: 28),

                // Basic Info Section
                _buildSectionLabel('Vehicle Information', colorScheme),
                const SizedBox(height: 12),

                // Vehicle Name
                TextFormField(
                  controller: _nameController,
                  decoration: _inputDecoration(
                    labelText: 'Vehicle Name *',
                    hintText: 'e.g., Toyota Innova',
                    colorScheme: colorScheme,
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter vehicle name';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Year and Model row
                Row(
                  children: [
                    // Year
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _year,
                        decoration: _inputDecoration(
                          labelText: 'Year',
                          hintText: 'Select',
                          colorScheme: colorScheme,
                        ),
                        items: List.generate(
                          DateTime.now().year - 1989,
                          (i) => DateTime.now().year - i,
                        ).map((year) {
                          return DropdownMenuItem(
                            value: year,
                            child: Text(year.toString()),
                          );
                        }).toList(),
                        onChanged: (value) => setState(() => _year = value),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Model
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _modelController,
                        decoration: _inputDecoration(
                          labelText: 'Model',
                          hintText: 'e.g., Innova, Fortuner',
                          colorScheme: colorScheme,
                        ),
                        textCapitalization: TextCapitalization.words,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Plate Number and Color row
                Row(
                  children: [
                    // Plate Number
                    Expanded(
                      child: TextFormField(
                        controller: _plateController,
                        decoration: _inputDecoration(
                          labelText: 'Plate Number *',
                          hintText: 'ABC 1234',
                          colorScheme: colorScheme,
                        ),
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\s]')),
                        ],
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Required';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Color
                    Expanded(
                      child: TextFormField(
                        controller: _colorController,
                        decoration: _inputDecoration(
                          labelText: 'Color',
                          hintText: 'e.g., White',
                          colorScheme: colorScheme,
                        ),
                        textCapitalization: TextCapitalization.words,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Capacity
                _buildSectionLabel('Passenger Capacity', colorScheme),
                const SizedBox(height: 12),
                _buildCapacitySelector(colorScheme),

                const SizedBox(height: 20),

                // Description
                TextFormField(
                  controller: _descriptionController,
                  decoration: _inputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'Additional details about your vehicle...',
                    colorScheme: colorScheme,
                  ),
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                ),

                const SizedBox(height: 28),

                // Documents Section
                _buildSectionLabel('Vehicle Documents', colorScheme),
                const SizedBox(height: 8),
                Text(
                  'Upload your vehicle OR and CR for verification',
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                VehicleDocumentsList(
                  orDocument: _existingOr,
                  crDocument: _existingCr,
                  pendingOr: _pendingOr,
                  pendingCr: _pendingCr,
                  isUploadingOr: _isUploadingOr,
                  isUploadingCr: _isUploadingCr,
                  onOrTap: () => _pickDocument(DocumentType.vehicleOr),
                  onCrTap: () => _pickDocument(DocumentType.vehicleCr),
                  onOrDelete: _pendingOr != null
                      ? () => _removeDocument(DocumentType.vehicleOr)
                      : (_existingOr != null ? () => _deleteExistingDocument(_existingOr!) : null),
                  onCrDelete: _pendingCr != null
                      ? () => _removeDocument(DocumentType.vehicleCr)
                      : (_existingCr != null ? () => _deleteExistingDocument(_existingCr!) : null),
                  onOrView: _existingOr != null ? () => _viewDocument(_existingOr!.url) : null,
                  onCrView: _existingCr != null ? () => _viewDocument(_existingCr!.url) : null,
                ),

                const SizedBox(height: 32),

                // Submit Button
                FilledButton(
                  onPressed: _isSubmitting ? null : () => _submit(vehicle),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.white,
                          ),
                        )
                      : const Text(
                          'Save Changes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: colorScheme.error),
              const SizedBox(height: 16),
              Text('Error: ${error.toString()}'),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => ref.invalidate(vehicleByIdProvider(widget.vehicleId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label, ColorScheme colorScheme) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
    );
  }

  InputDecoration _inputDecoration({
    String? labelText,
    required String hintText,
    required ColorScheme colorScheme,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      hintStyle: TextStyle(
        color: colorScheme.onSurfaceVariant.withOpacity(0.7),
      ),
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: colorScheme.outlineVariant.withOpacity(0.3),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: colorScheme.primary,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: colorScheme.error,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: colorScheme.error,
          width: 1.5,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
    );
  }

  Widget _buildCapacitySelector(ColorScheme colorScheme) {
    final capacities = [2, 4, 6, 7, 10, 12, 15];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: capacities.map((cap) {
        final isSelected = _capacity == cap;
        return GestureDetector(
          onTap: () => setState(() => _capacity = cap),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? colorScheme.primary.withOpacity(0.1)
                  : colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.outlineVariant.withOpacity(0.3),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.person,
                  size: 16,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  '$cap',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
