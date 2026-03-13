/// Conditional import stub for creating the tracking service.
/// On web: returns WebTrackingService
/// On desktop: returns UdpService
library;

import 'tracking_service.dart';

// This file is the "default" (non-web) implementation.
// The web version is in tracking_factory_web.dart.
// Conditional import in main.dart picks the right one.

import 'udp_service.dart';

TrackingService createTrackingService() => UdpService();
