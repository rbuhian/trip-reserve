import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/vehicle_provider.dart';

class AddVehicleScreen extends ConsumerStatefulWidget {
  const AddVehicleScreen({super.key});

  @override
  ConsumerState<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends ConsumerState<AddVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _plateController = TextEditingController();
  final _descriptionController = TextEditingController();
  int _capacity = 4;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _plateController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final form = ref.read(vehicleFormProvider.notifier);
      form.setName(_nameController.text);
      form.setPlateNumber(_plateController.text);
      form.setCapacity(_capacity);
      form.setDescription(_descriptionController.text.isEmpty ? null : _descriptionController.text);

      final data = ref.read(vehicleFormProvider).toCreate();
      await ref.read(myVehiclesProvider.notifier).add(data);

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
        backgroundColor: colorScheme.surface,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Vehicle Image Placeholder
            _buildImageSection(colorScheme),

            const SizedBox(height: 28),

            // Vehicle Name
            _buildSectionLabel('Vehicle Name', colorScheme),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              decoration: _inputDecoration(
                hintText: 'e.g., Toyota Innova 2023',
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

            const SizedBox(height: 20),

            // Plate Number
            _buildSectionLabel('Plate Number', colorScheme),
            const SizedBox(height: 8),
            TextFormField(
              controller: _plateController,
              decoration: _inputDecoration(
                hintText: 'e.g., ABC 1234',
                colorScheme: colorScheme,
              ),
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\s]')),
              ],
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter plate number';
                }
                return null;
              },
            ),

            const SizedBox(height: 20),

            // Capacity
            _buildSectionLabel('Passenger Capacity', colorScheme),
            const SizedBox(height: 12),
            _buildCapacitySelector(colorScheme),

            const SizedBox(height: 20),

            // Description
            _buildSectionLabel('Description (Optional)', colorScheme),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              decoration: _inputDecoration(
                hintText: 'Additional details about your vehicle...',
                colorScheme: colorScheme,
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
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

  Widget _buildImageSection(ColorScheme colorScheme) {
    return GestureDetector(
      onTap: () {
        // TODO: Implement image picker
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image upload coming soon'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outlineVariant.withOpacity(0.5),
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add_photo_alternate_outlined,
                size: 32,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Add Vehicle Photo',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap to upload',
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label, ColorScheme colorScheme) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required ColorScheme colorScheme,
  }) {
    return InputDecoration(
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
