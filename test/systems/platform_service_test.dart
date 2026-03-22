import 'package:flutter_test/flutter_test.dart';
import 'package:fpv_magic/systems/platform_service.dart';

void main() {
  group('PlatformService', () {
    late PlatformService platform;

    setUp(() {
      platform = PlatformService.instance;
    });

    test('should be a singleton', () {
      final instance1 = PlatformService.instance;
      final instance2 = PlatformService.instance;

      expect(identical(instance1, instance2), isTrue);
    });

    group('platform detection', () {
      test('should return a valid platform type', () {
        expect(platform.platformType, isA<PlatformType>());
      });

      test('should return a valid platform category', () {
        expect(platform.category, isA<PlatformCategory>());
      });

      test('platform category should match platform type', () {
        final type = platform.platformType;
        final category = platform.category;

        if (type == PlatformType.android || type == PlatformType.ios) {
          expect(category, PlatformCategory.mobile);
        } else if (type == PlatformType.web) {
          expect(category, PlatformCategory.web);
        } else if (type == PlatformType.windows ||
            type == PlatformType.macos ||
            type == PlatformType.linux) {
          expect(category, PlatformCategory.desktop);
        }
      });
    });

    group('platform capabilities', () {
      test('isMobile should match mobile category', () {
        expect(platform.isMobile, platform.category == PlatformCategory.mobile);
      });

      test('isDesktop should match desktop category', () {
        expect(
          platform.isDesktop,
          platform.category == PlatformCategory.desktop,
        );
      });

      test('isWeb should match web platform', () {
        expect(platform.isWeb, platform.platformType == PlatformType.web);
      });

      test('supportsHandTracking should be true for desktop/web', () {
        if (platform.isDesktop || platform.isWeb) {
          expect(platform.supportsHandTracking, isTrue);
        } else {
          expect(platform.supportsHandTracking, isFalse);
        }
      });

      test('prefersTouchInput should be true for mobile', () {
        if (platform.isMobile) {
          expect(platform.prefersTouchInput, isTrue);
        } else {
          expect(platform.prefersTouchInput, isFalse);
        }
      });

      test('supportsHighQuality should be true for desktop', () {
        if (platform.isDesktop) {
          expect(platform.supportsHighQuality, isTrue);
        } else {
          expect(platform.supportsHighQuality, isFalse);
        }
      });
    });

    group('performance recommendations', () {
      test('recommendedParticleLimit should be reasonable', () {
        final limit = platform.recommendedParticleLimit;

        expect(limit, greaterThan(0));
        expect(limit, lessThanOrEqualTo(1000));

        // Mobile should have lower limit
        if (platform.isMobile) {
          expect(limit, lessThanOrEqualTo(150));
        }

        // Desktop should have higher limit
        if (platform.isDesktop) {
          expect(limit, greaterThanOrEqualTo(300));
        }
      });

      test('recommendedTargetFps should be 60', () {
        expect(platform.recommendedTargetFps, 60.0);
      });
    });

    group('display information', () {
      test('displayName should not be empty', () {
        expect(platform.displayName.isNotEmpty, isTrue);
      });

      test('displayName should match platform type', () {
        final name = platform.displayName;
        final type = platform.platformType;

        if (type == PlatformType.android) expect(name, 'Android');
        if (type == PlatformType.ios) expect(name, 'iOS');
        if (type == PlatformType.web) expect(name, 'Web');
        if (type == PlatformType.windows) expect(name, 'Windows');
        if (type == PlatformType.macos) expect(name, 'macOS');
        if (type == PlatformType.linux) expect(name, 'Linux');
      });

      test('inputHint should be relevant to platform', () {
        final hint = platform.inputHint;

        expect(hint.isNotEmpty, isTrue);

        if (platform.prefersTouchInput) {
          expect(hint.toLowerCase(), contains('tap'));
        }

        if (platform.supportsHandTracking) {
          expect(
            hint.toLowerCase(),
            anyOf(contains('hand'), contains('mouse')),
          );
        }
      });
    });
  });

  group('PlatformType', () {
    test('should have all expected types', () {
      expect(PlatformType.values, contains(PlatformType.android));
      expect(PlatformType.values, contains(PlatformType.ios));
      expect(PlatformType.values, contains(PlatformType.web));
      expect(PlatformType.values, contains(PlatformType.windows));
      expect(PlatformType.values, contains(PlatformType.macos));
      expect(PlatformType.values, contains(PlatformType.linux));
      expect(PlatformType.values, contains(PlatformType.unknown));
    });
  });

  group('PlatformCategory', () {
    test('should have all expected categories', () {
      expect(PlatformCategory.values, contains(PlatformCategory.mobile));
      expect(PlatformCategory.values, contains(PlatformCategory.desktop));
      expect(PlatformCategory.values, contains(PlatformCategory.web));
      expect(PlatformCategory.values, contains(PlatformCategory.unknown));
    });
  });
}
