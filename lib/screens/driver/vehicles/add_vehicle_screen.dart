import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/document.dart';
import '../../../models/vehicle.dart';
import '../../../providers/vehicle_provider.dart';
import '../../../repositories/document_repository.dart';
import '../../../services/storage_service.dart';
import '../../../widgets/document_upload_card.dart';
import '../../../widgets/photo_upload_card.dart';

class AddVehicleScreen extends ConsumerStatefulWidget {
  const AddVehicleScreen({super.key});

  @override
  ConsumerState<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends ConsumerState<AddVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _plateController = TextEditingController();
  final _modelController = TextEditingController();
  final _colorController = TextEditingController();
  final _descriptionController = TextEditingController();
  int _capacity = 4;
  int? _year;
  bool _isSubmitting = false;

  // Photo management
  final Map<VehiclePhotoType, XFile?> _pendingPhotos = {};
  final Set<VehiclePhotoType> _uploadingPhotos = {};

  // Document management
  XFile? _pendingOr;
  XFile? _pendingCr;
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

  Future<void> _pickPhoto(VehiclePhotoType type) async {
    final file = await ImagePickerHelper.pickImage();
    if (file != null) {
      setState(() {
        _pendingPhotos[type] = file;
      });
    }
  }

  void _removePhoto(VehiclePhotoType type) {
    setState(() {
      _pendingPhotos.remove(type);
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final form = ref.read(vehicleFormProvider.notifier);
      form.setName(_nameController.text);
      form.setPlateNumber(_plateController.text);
      form.setCapacity(_capacity);
      form.setYear(_year);
      form.setModel(_modelController.text.isEmpty ? null : _modelController.text);
      form.setColor(_colorController.text.isEmpty ? null : _colorController.text);
      form.setDescription(_descriptionController.text.isEmpty ? null : _descriptionController.text);

      final data = ref.read(vehicleFormProvider).toCreate();
      final vehicle = await ref.read(myVehiclesProvider.notifier).add(data);

      // Upload photos
      final storageService = ref.read(storageServiceProvider);
      final documentRepo = ref.read(documentRepositoryProvider);

      for (final entry in _pendingPhotos.entries) {
        if (entry.value != null) {
          setState(() => _uploadingPhotos.add(entry.key));
          try {
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vehicle added successfully'),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Vehicle'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
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
              currentUrls: const {},
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
              pendingOr: _pendingOr,
              pendingCr: _pendingCr,
              isUploadingOr: _isUploadingOr,
              isUploadingCr: _isUploadingCr,
              onOrTap: () => _pickDocument(DocumentType.vehicleOr),
              onCrTap: () => _pickDocument(DocumentType.vehicleCr),
              onOrDelete: _pendingOr != null
                  ? () => _removeDocument(DocumentType.vehicleOr)
                  : null,
              onCrDelete: _pendingCr != null
                  ? () => _removeDocument(DocumentType.vehicleCr)
                  : null,
            ),

            const SizedBox(height: 32),

            // Submit Button
            FilledButton(
              onPressed: _isSubmitting ? null : _submit,
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
                      'Add Vehicle',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),

            const SizedBox(height: 20),
          ],
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
