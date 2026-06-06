import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../models/booking.dart';
import '../providers/places_provider.dart';
import '../services/places_service.dart';

/// Location type for styling
enum LocationType { pickup, dropoff }

/// A text field with Google Places autocomplete
class PlaceAutocompleteField extends ConsumerStatefulWidget {
  /// The location type (pickup or dropoff)
  final LocationType locationType;

  /// Callback when a location is selected
  final ValueChanged<LocationData>? onLocationSelected;

  /// Initial value to display
  final LocationData? initialValue;

  /// Hint text
  final String? hintText;

  /// Whether the field is enabled
  final bool enabled;

  /// Callback when use current location is tapped
  final VoidCallback? onUseCurrentLocation;

  /// Callback when pick from map is tapped
  final VoidCallback? onPickFromMap;

  const PlaceAutocompleteField({
    super.key,
    required this.locationType,
    this.onLocationSelected,
    this.initialValue,
    this.hintText,
    this.enabled = true,
    this.onUseCurrentLocation,
    this.onPickFromMap,
  });

  @override
  ConsumerState<PlaceAutocompleteField> createState() =>
      _PlaceAutocompleteFieldState();
}

class _PlaceAutocompleteFieldState
    extends ConsumerState<PlaceAutocompleteField> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOverlayVisible = false;

  AutoDisposeStateNotifierProvider<PlaceSearchNotifier, PlaceSearchState>
      get _provider => widget.locationType == LocationType.pickup
          ? pickupSearchProvider
          : dropoffSearchProvider;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue?.address);
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(PlaceAutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue) {
      _controller.text = widget.initialValue?.address ?? '';
    }
  }

  @override
  void dispose() {
    _removeOverlay();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      _showOverlay();
    } else {
      // Delay hiding to allow tap on predictions
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!_focusNode.hasFocus) {
          _removeOverlay();
        }
      });
    }
  }

  void _showOverlay() {
    if (_isOverlayVisible) return;

    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    _isOverlayVisible = true;
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _isOverlayVisible = false;
  }

  OverlayEntry _createOverlayEntry() {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    return OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 4),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: Consumer(
              builder: (context, ref, child) {
                final state = ref.watch(_provider);
                return _buildPredictionsList(state);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPredictionsList(PlaceSearchState state) {
    // Show loading
    if (state.isLoading && state.predictions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    // Show error
    if (state.error != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Text(
          state.error!,
          style: TextStyle(color: AppColors.error),
        ),
      );
    }

    // Show quick actions when no search yet
    if (state.query.isEmpty) {
      return _buildQuickActions();
    }

    // No results
    if (state.predictions.isEmpty && !state.isLoading) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No places found',
          style: TextStyle(color: AppColors.textMedium),
        ),
      );
    }

    // Show predictions
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 250),
      child: ListView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: state.predictions.length,
        itemBuilder: (context, index) {
          final prediction = state.predictions[index];
          return _buildPredictionTile(prediction);
        },
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.onUseCurrentLocation != null)
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.my_location, color: AppColors.primary, size: 20),
            ),
            title: const Text('Use current location'),
            onTap: () {
              _removeOverlay();
              _focusNode.unfocus();
              widget.onUseCurrentLocation?.call();
            },
          ),
        if (widget.onPickFromMap != null)
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.map, color: AppColors.accent, size: 20),
            ),
            title: const Text('Pick from map'),
            onTap: () {
              _removeOverlay();
              _focusNode.unfocus();
              widget.onPickFromMap?.call();
            },
          ),
      ],
    );
  }

  Widget _buildPredictionTile(PlacePrediction prediction) {
    return ListTile(
      leading: Icon(
        Icons.location_on_outlined,
        color: AppColors.textMedium,
      ),
      title: Text(
        prediction.mainText,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        prediction.secondaryText,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          color: AppColors.textMedium,
        ),
      ),
      onTap: () => _onPredictionSelected(prediction),
    );
  }

  Future<void> _onPredictionSelected(PlacePrediction prediction) async {
    _removeOverlay();
    _focusNode.unfocus();

    // Update text immediately
    _controller.text = prediction.description;

    // Fetch location details
    final location =
        await ref.read(_provider.notifier).selectPlace(prediction);

    if (location != null) {
      widget.onLocationSelected?.call(location);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPickup = widget.locationType == LocationType.pickup;

    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        enabled: widget.enabled,
        decoration: InputDecoration(
          hintText: widget.hintText ??
              (isPickup ? 'Enter pickup location' : 'Enter destination'),
          prefixIcon: Icon(
            isPickup ? Icons.trip_origin : Icons.location_on,
            color: isPickup ? AppColors.markerPickup : AppColors.markerDropoff,
          ),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () {
                    _controller.clear();
                    ref.read(_provider.notifier).clear();
                    widget.onLocationSelected?.call(const LocationData(
                      address: '',
                      lat: 0,
                      lng: 0,
                    ));
                  },
                )
              : null,
          filled: true,
          fillColor: theme.colorScheme.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.primary, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        onChanged: (value) {
          ref.read(_provider.notifier).search(value);
          // Refresh overlay
          _overlayEntry?.markNeedsBuild();
        },
      ),
    );
  }
}
