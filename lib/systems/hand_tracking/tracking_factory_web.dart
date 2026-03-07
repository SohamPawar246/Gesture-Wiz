/// Web implementation of the tracking factory.
/// Returns WebTrackingService (uses MediaPipe JS bridge).

import 'tracking_service.dart';
import 'web_tracking_service.dart';

TrackingService createTrackingService() => WebTrackingService();
