import 'package:flutter/material.dart';
import 'package:fast_food_app/models.dart';

// A class to hold the temporary state of a menu item's customization.
class CustomizationState {
  Map<String, List<Option>> selectedOptions;
  Set<String> ingredientsToRemove;
  int quantity;

  CustomizationState({
    required this.selectedOptions,
    required this.ingredientsToRemove,
    required this.quantity,
  });

  // Create a deep copy to avoid reference issues.
  CustomizationState copy() {
    return CustomizationState(
      selectedOptions: Map<String, List<Option>>.from(
        selectedOptions.map(
          (key, value) => MapEntry(key, List<Option>.from(value)),
        ),
      ),
      ingredientsToRemove: Set<String>.from(ingredientsToRemove),
      quantity: quantity,
    );
  }
}

class MenuCustomizationProvider with ChangeNotifier {
  final Map<String, CustomizationState> _customizations = {};

  // Get the saved customization for a given menu item ID.
  CustomizationState? getCustomization(String menuItemId) {
    return _customizations[menuItemId]?.copy();
  }

  // Update or create a customization for a given menu item ID.
  void updateCustomization(String menuItemId, CustomizationState state) {
    _customizations[menuItemId] = state;
    // We don't call notifyListeners() because we don't want to trigger UI rebuilds
    // across the app for this. The MenuCustomizationPage will manage its own state
    // and just use this provider as a data store.
  }

  // Clear the customization for a menu item, typically after adding it to the cart.
  void clearCustomization(String menuItemId) {
    if (_customizations.containsKey(menuItemId)) {
      _customizations.remove(menuItemId);
    }
  }
}
