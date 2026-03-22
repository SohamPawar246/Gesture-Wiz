import 'package:flutter_test/flutter_test.dart';
import 'package:fpv_magic/systems/performance_monitor.dart';

void main() {
  group('PerformanceMonitor', () {
    late PerformanceMonitor monitor;

    setUp(() {
      monitor = PerformanceMonitor.instance;
      monitor.reset();
    });

    group('FPS tracking', () {
      test('should start with default 60 FPS', () {
        expect(monitor.currentFps, 60.0);
      });

      test('should calculate FPS from delta time', () {
        // Simulate 30 FPS (0.0333 seconds per frame)
        for (int i = 0; i < 60; i++) {
          monitor.recordFrame(0.0333);
        }

        expect(monitor.currentFps, closeTo(30.0, 1.0));
      });

      test('should calculate FPS from 60 FPS delta', () {
        // Simulate 60 FPS (0.01667 seconds per frame)
        for (int i = 0; i < 60; i++) {
          monitor.recordFrame(0.01667);
        }

        expect(monitor.currentFps, closeTo(60.0, 2.0));
      });

      test('should track average frame time', () {
        // 30 FPS = 33.33ms per frame
        for (int i = 0; i < 60; i++) {
          monitor.recordFrame(0.0333);
        }

        expect(monitor.avgFrameTime, closeTo(33.3, 1.0));
      });

      test('should ignore zero or negative delta', () {
        monitor.recordFrame(0.0);
        monitor.recordFrame(-0.1);

        expect(monitor.currentFps, 60.0); // Should remain at default
      });

      test('should track min and max FPS', () {
        //  Simulate varying FPS with full sample window
        for (int i = 0; i < 20; i++) {
          monitor.recordFrame(0.01667); // 60 FPS
        }
        for (int i = 0; i < 20; i++) {
          monitor.recordFrame(0.03); // 33 FPS
        }
        for (int i = 0; i < 20; i++) {
          monitor.recordFrame(0.02); // 50 FPS
        }

        expect(monitor.minFps, lessThan(monitor.maxFps));
      });
    });

    group('performance status', () {
      test('should report excellent status at 60 FPS', () {
        for (int i = 0; i < 60; i++) {
          monitor.recordFrame(0.01667); // 60 FPS
        }

        expect(monitor.status, PerformanceStatus.excellent);
      });

      test('should report good status at 50 FPS', () {
        for (int i = 0; i < 60; i++) {
          monitor.recordFrame(0.02); // 50 FPS
        }

        expect(monitor.status, PerformanceStatus.good);
      });

      test('should report warning status at 40 FPS', () {
        for (int i = 0; i < 60; i++) {
          monitor.recordFrame(0.025); // 40 FPS
        }

        expect(monitor.status, PerformanceStatus.warning);
      });

      test('should report critical status at 25 FPS', () {
        for (int i = 0; i < 60; i++) {
          monitor.recordFrame(0.04); // 25 FPS
        }

        expect(monitor.status, PerformanceStatus.critical);
      });

      test('isPerformanceDegraded should return true below 45 FPS', () {
        for (int i = 0; i < 60; i++) {
          monitor.recordFrame(0.025); // 40 FPS
        }

        expect(monitor.isPerformanceDegraded, isTrue);
      });

      test('isPerformanceDegraded should return false at 60 FPS', () {
        for (int i = 0; i < 60; i++) {
          monitor.recordFrame(0.01667); // 60 FPS
        }

        expect(monitor.isPerformanceDegraded, isFalse);
      });
    });

    group('quality recommendations', () {
      test('should recommend high quality at 60 FPS', () {
        for (int i = 0; i < 60; i++) {
          monitor.recordFrame(0.01667);
        }

        expect(monitor.getRecommendedQuality(), QualityLevel.high);
      });

      test('should recommend medium quality at 50 FPS', () {
        for (int i = 0; i < 60; i++) {
          monitor.recordFrame(0.02);
        }

        expect(monitor.getRecommendedQuality(), QualityLevel.medium);
      });

      test('should recommend low quality at 35 FPS', () {
        for (int i = 0; i < 60; i++) {
          monitor.recordFrame(0.0286);
        }

        expect(monitor.getRecommendedQuality(), QualityLevel.low);
      });

      test('should recommend minimal quality at 20 FPS', () {
        for (int i = 0; i < 60; i++) {
          monitor.recordFrame(0.05);
        }

        expect(monitor.getRecommendedQuality(), QualityLevel.minimal);
      });
    });

    group('entity tracking', () {
      test('should track enemy count', () {
        monitor.updateEntityCounts(enemies: 10, projectiles: 5, particles: 50);

        expect(monitor.enemyCount, 10);
      });

      test('should track projectile count', () {
        monitor.updateEntityCounts(enemies: 5, projectiles: 20, particles: 30);

        expect(monitor.projectileCount, 20);
      });

      test('should track particle count', () {
        monitor.updateEntityCounts(enemies: 3, projectiles: 7, particles: 100);

        expect(monitor.particleCount, 100);
      });

      test('should calculate total entities', () {
        monitor.updateEntityCounts(enemies: 10, projectiles: 15, particles: 75);

        expect(monitor.totalEntities, 100);
      });
    });

    group('reset', () {
      test('should reset all FPS stats to defaults', () {
        // Change stats
        for (int i = 0; i < 60; i++) {
          monitor.recordFrame(0.03); // 33 FPS
        }
        monitor.updateEntityCounts(
          enemies: 50,
          projectiles: 30,
          particles: 200,
        );

        // Reset
        monitor.reset();

        expect(monitor.currentFps, 60.0);
        expect(monitor.avgFrameTime, 16.67);
        expect(monitor.enemyCount, 0);
        expect(monitor.projectileCount, 0);
        expect(monitor.particleCount, 0);
      });
    });

    group('getSummary', () {
      test('should return formatted summary string', () {
        monitor.recordFrame(0.01667); // 60 FPS
        monitor.updateEntityCounts(enemies: 5, projectiles: 10, particles: 50);

        final summary = monitor.getSummary();

        expect(summary, contains('FPS'));
        expect(summary, contains('Frame'));
        expect(summary, contains('Entities'));
        expect(summary, contains('65')); // total entities
      });
    });
  });
}
