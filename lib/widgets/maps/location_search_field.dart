import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../models/booking.dart';
import '../../providers/location_provider.dart';
import '../../services/maps_service.dart';

/// A text field for searching and selecting locations
class LocationSearchField extends ConsumerStatefulWidget {
  /// Label text
  final String? label;

  /// Hint text
  final String? hint;

  /// Leading icon
  final IconData? prefixIcon;

  /// Color for the prefix icon
  final Color? prefixIconColor;

  /// Current selected location
  final LocationData? value;

  /// Callback when location is selected
  final ValueChanged<LocationData>? onLocationSelected;

  /// Whether to show "Use current location" option
  final bool showCurrentLocationOption;

  /// Whether to show clear button when value is set
  final bool showClearButton;

  /// Callback when cleared
  final VoidCallback? onClear;

  /// Read-only mode (just displays the address)
  final bool readOnly;

  const LocationSearchField({
    super.key,
    this.label,
    this.hint,
    this.prefixIcon = Icons.location_on_outlined,
    this.prefixIconColor,
    this.value,
    this.onLocationSelected,
    this.showCurrentLocationOption = true,
    this.showClearButton = true,
    this.onClear,
    this.readOnly = false,
  });

  @override
  ConsumerState<LocationSearchField> createState() => _LocationSearchFieldState();
}

class _LocationSearchFieldState extends ConsumerState<LocationSearchField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounceTimer;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.value != null) {
      _controller.text = widget.value!.address;
    }
  }

  @override
  void didUpdateWidget(LocationSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value?.address != oldWidget.value?.address) {
      _controller.text = widget.value?.address ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              widget.label!,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          readOnly: widget.readOnly,
          onChanged: widget.readOnly ? null : _onTextChanged,
          onTap: widget.readOnly ? null : _showLocationPicker,
          decoration: InputDecoration(
            hintText: widget.hint ?? 'Search location...',
            hintStyle: TextStyle(
              color: colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            prefixIcon: Icon(
              widget.prefixIcon,
              color: widget.prefixIconColor ?? colorScheme.onSurfaceVariant,
            ),
            suffixIcon: _buildSuffixIcon(colorScheme),
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: colorScheme.outlineVariant.withOpacity(0.5),
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
              borderSide: BorderSide(color: colorScheme.error),
            ),
            errorText: _error,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget? _buildSuffixIcon(ColorScheme colorScheme) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (widget.showClearButton && widget.value != null) {
      return IconButton(
        icon: Icon(
          Icons.clear,
          color: colorScheme.onSurfaceVariant,
        ),
        onPressed: () {
          _controller.clear();
          widget.onClear?.call();
        },
      );
    }

    return null;
  }

  void _onTextChanged(String value) {
    _debounceTimer?.cancel();

    if (value.isEmpty) {
      setState(() => _error = null);
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _searchAddress(value);
    });
  }

  Future<void> _searchAddress(String query) async {
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final mapsService = ref.read(mapsServiceProvider);
      final location = await mapsService.geocodeAddress(query);

      widget.onLocationSelected?.call(location);
      _controller.text = location.address;
      _focusNode.unfocus();
    } on MapsServiceException catch (e) {
      setState(() => _error = e.message);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showLocationPicker() async {
    if (widget.readOnly) return;

    final result = await showModalBottomSheet<LocationData>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _LocationPickerSheet(
        showCurrentLocationOption: widget.showCurrentLocationOption,
        initialQuery: _controller.text,
      ),
    );

    if (result != null) {
      _controller.text = result.address;
      widget.onLocationSelected?.call(result);
    }
  }
}

/// Bottom sheet for location selection
class _LocationPickerSheet extends ConsumerStatefulWidget {
  final bool showCurrentLocationOption;
  final String initialQuery;

  const _LocationPickerSheet({
    required this.showCurrentLocationOption,
    required this.initialQuery,
  });

  @override
  ConsumerState<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends ConsumerState<_LocationPickerSheet> {
  final _searchController = TextEditingController();
  Timer? _debounceTimer;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialQuery;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              'Select Location',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Search field
            TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: _onSearchChanged,
              onSubmitted: _searchAddress,
              decoration: InputDecoration(
                hintText: 'Search for a location...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: colorScheme.error),
                ),
              ),

            const SizedBox(height: 16),

            // Options
            Expanded(
              child: ListView(
                controller: scrollController,
                children: [
                  // Current location option
                  if (widget.showCurrentLocationOption) ...[
                    _buildCurrentLocationTile(context),
                    const SizedBox(height: 8),
                  ],

                  // Map picker option
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: colorScheme.primaryContainer,
                      child: Icon(
                        Icons.map,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    title: const Text('Pick on Map'),
                    subtitle: const Text('Select a point on the map'),
                    trailing: const Icon(Icons.chevron_right),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onTap: _openMapPicker,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentLocationTile(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currentLocation = ref.watch(currentLocationProvider);

    return currentLocation.when(
      data: (location) => ListTile(
        leading: CircleAvatar(
          backgroundColor: colorScheme.primaryContainer,
          child: Icon(
            Icons.my_location,
            color: colorScheme.onPrimaryContainer,
          ),
        ),
        title: const Text('Current Location'),
        subtitle: Text(
          location?.address ?? 'Getting location...',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        onTap: location != null
            ? () => Navigator.pop(context, location)
            : null,
      ),
      loading: () => ListTile(
        leading: CircleAvatar(
          backgroundColor: colorScheme.surfaceContainerHighest,
          child: const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        title: const Text('Current Location'),
        subtitle: const Text('Getting location...'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      error: (_, __) => ListTile(
        leading: CircleAvatar(
          backgroundColor: colorScheme.errorContainer,
          child: Icon(
            Icons.location_off,
            color: colorScheme.onErrorContainer,
          ),
        ),
        title: const Text('Current Location'),
        subtitle: const Text('Location unavailable'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        onTap: _requestLocationPermission,
      ),
    );
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    if (value.isEmpty) {
      setState(() => _error = null);
      return;
    }
  }

  Future<void> _searchAddress(String query) async {
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final mapsService = ref.read(mapsServiceProvider);
      final location = await mapsService.geocodeAddress(query);

      if (mounted) {
        Navigator.pop(context, location);
      }
    } on MapsServiceException catch (e) {
      setState(() => _error = e.message);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _openMapPicker() async {
    // TODO: Navigate to full map picker screen
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Map picker will be implemented')),
    );
  }

  Future<void> _requestLocationPermission() async {
    final locationService = ref.read(locationServiceProvider);
    final permission = await locationService.requestPermission();

    if (permission == LocationPermission.deniedForever) {
      await locationService.openAppSettings();
    }

    // Refresh the current location provider
    ref.invalidate(currentLocationProvider);
  }
}
