import 'package:flutter_test/flutter_test.dart';
import 'package:fpv_magic/models/difficulty.dart';

void main() {
  group('Difficulty', () {
    group('displayName', () {
      test('easy should display "EASY"', () {
        expect(Difficulty.easy.displayName, 'EASY');
      });

      test('normal should display "NORMAL"', () {
        expect(Difficulty.normal.displayName, 'NORMAL');
      });

      test('hard should display "HARD"', () {
        expect(Difficulty.hard.displayName, 'HARD');
      });
    });

    group('description', () {
      test('each difficulty should have a description', () {
        for (final d in Difficulty.values) {
          expect(d.description, isNotEmpty);
        }
      });
    });

    group('fromString', () {
      test('should parse "easy"', () {
        expect(Difficulty.fromString('easy'), Difficulty.easy);
      });

      test('should parse "normal"', () {
        expect(Difficulty.fromString('normal'), Difficulty.normal);
      });

      test('should parse "hard"', () {
        expect(Difficulty.fromString('hard'), Difficulty.hard);
      });

      test('should default to normal for null', () {
        expect(Difficulty.fromString(null), Difficulty.normal);
      });

      test('should default to normal for unknown string', () {
        expect(Difficulty.fromString('invalid'), Difficulty.normal);
        expect(Difficulty.fromString(''), Difficulty.normal);
      });
    });

    group('enemyDamageMultiplier', () {
      test('easy should be less than 1', () {
        expect(Difficulty.easy.enemyDamageMultiplier, lessThan(1.0));
      });

      test('normal should be exactly 1', () {
        expect(Difficulty.normal.enemyDamageMultiplier, 1.0);
      });

      test('hard should be greater than 1', () {
        expect(Difficulty.hard.enemyDamageMultiplier, greaterThan(1.0));
      });
    });

    group('enemyHealthMultiplier', () {
      test('easy should be less than 1', () {
        expect(Difficulty.easy.enemyHealthMultiplier, lessThan(1.0));
      });

      test('normal should be exactly 1', () {
        expect(Difficulty.normal.enemyHealthMultiplier, 1.0);
      });

      test('hard should be greater than 1', () {
        expect(Difficulty.hard.enemyHealthMultiplier, greaterThan(1.0));
      });
    });

    group('enemySpeedMultiplier', () {
      test('easy should be less than 1', () {
        expect(Difficulty.easy.enemySpeedMultiplier, lessThan(1.0));
      });

      test('normal should be exactly 1', () {
        expect(Difficulty.normal.enemySpeedMultiplier, 1.0);
      });

      test('hard should be greater than 1', () {
        expect(Difficulty.hard.enemySpeedMultiplier, greaterThan(1.0));
      });
    });

    group('spawnIntervalMultiplier', () {
      test('easy should slow spawns (greater than 1)', () {
        expect(Difficulty.easy.spawnIntervalMultiplier, greaterThan(1.0));
      });

      test('normal should be exactly 1', () {
        expect(Difficulty.normal.spawnIntervalMultiplier, 1.0);
      });

      test('hard should speed up spawns (less than 1)', () {
        expect(Difficulty.hard.spawnIntervalMultiplier, lessThan(1.0));
      });
    });

    group('manaRegenMultiplier', () {
      test('easy should boost mana regen', () {
        expect(Difficulty.easy.manaRegenMultiplier, greaterThan(1.0));
      });

      test('normal should be exactly 1', () {
        expect(Difficulty.normal.manaRegenMultiplier, 1.0);
      });

      test('hard should reduce mana regen', () {
        expect(Difficulty.hard.manaRegenMultiplier, lessThan(1.0));
      });
    });

    group('playerDamageMultiplier', () {
      test('easy should boost player damage', () {
        expect(Difficulty.easy.playerDamageMultiplier, greaterThan(1.0));
      });

      test('normal should be exactly 1', () {
        expect(Difficulty.normal.playerDamageMultiplier, 1.0);
      });

      test('hard should reduce player damage', () {
        expect(Difficulty.hard.playerDamageMultiplier, lessThan(1.0));
      });
    });

    group('surveillanceGainMultiplier', () {
      test('easy should reduce surveillance gain', () {
        expect(Difficulty.easy.surveillanceGainMultiplier, lessThan(1.0));
      });

      test('normal should be exactly 1', () {
        expect(Difficulty.normal.surveillanceGainMultiplier, 1.0);
      });

      test('hard should increase surveillance gain', () {
        expect(Difficulty.hard.surveillanceGainMultiplier, greaterThan(1.0));
      });
    });

    group('scoreMultiplier', () {
      test('easy should reduce score', () {
        expect(Difficulty.easy.scoreMultiplier, lessThan(1.0));
      });

      test('normal should be exactly 1', () {
        expect(Difficulty.normal.scoreMultiplier, 1.0);
      });

      test('hard should increase score as reward', () {
        expect(Difficulty.hard.scoreMultiplier, greaterThan(1.0));
      });
    });

    group('difficulty ordering', () {
      test('enemy challenge should increase: easy < normal < hard', () {
        expect(
          Difficulty.easy.enemyDamageMultiplier,
          lessThan(Difficulty.normal.enemyDamageMultiplier),
        );
        expect(
          Difficulty.normal.enemyDamageMultiplier,
          lessThan(Difficulty.hard.enemyDamageMultiplier),
        );
      });

      test('player advantage should decrease: easy > normal > hard', () {
        expect(
          Difficulty.easy.playerDamageMultiplier,
          greaterThan(Difficulty.normal.playerDamageMultiplier),
        );
        expect(
          Difficulty.normal.playerDamageMultiplier,
          greaterThan(Difficulty.hard.playerDamageMultiplier),
        );
      });
    });
  });
}
