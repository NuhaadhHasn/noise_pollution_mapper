/// Shared app state to prevent duplicate operations across screens
class SharedAppState {
  // Track if location dialog already shown APP-WIDE (prevent duplicate dialogs)
  static bool locationDialogShown = false;
  
  // Reset flag (call when app restarts)
  static void reset() {
    locationDialogShown = false;
  }
}
