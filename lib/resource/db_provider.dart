// resource/db_provider.dart
import 'package:flutter/foundation.dart' show kIsWeb;

// Import the INTERFACE
import 'db_provider_interface.dart';
import 'db_provider_io.dart';
import 'db_provider_web.dart';

// Conditional Export: Exports either DBProviderIO or DBProviderWeb *as* DBProviderImpl
// This makes the concrete class name consistent regardless of platform.
export 'db_provider_io.dart' if (dart.library.html) 'db_provider_web.dart' show DBProviderWeb hide DBProviderIO;
export 'db_provider_io.dart' if (dart.library.io) 'db_provider_io.dart' show DBProviderIO hide DBProviderWeb;

// Factory function to create the correct implementation
DbProviderInterface createDbProvider() {
  if (kIsWeb) {
    return DBProviderWeb(); // Directly call the web constructor
  } else {
    return DBProviderIO(); // Directly call the IO constructor
  }
}

// Global instance of the correct implementation, typed as the interface
final DbProviderInterface dbProvider = createDbProvider();