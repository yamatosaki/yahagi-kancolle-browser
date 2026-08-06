import 'battle_models.dart';

const List<int> _halfSunkNumber = <int>[0, 1, 1, 2, 2, 3, 4, 4, 5, 6, 7, 7, 8];

BattleRank estimateBattleRank({
  required List<BattleShipSnapshot> friendShips,
  required List<BattleShipSnapshot> enemyShips,
  bool airRaid = false,
}) {
  if (friendShips.isEmpty || (!airRaid && enemyShips.isEmpty)) {
    return BattleRank.unknown;
  }
  if (airRaid) {
    final initialHp = friendShips.fold<int>(
      0,
      (sum, ship) => sum + ship.initialHp,
    );
    final currentHp = friendShips.fold<int>(
      0,
      (sum, ship) => sum + ship.currentHp.clamp(0, ship.initialHp),
    );
    if (initialHp <= 0) {
      return BattleRank.unknown;
    }
    final damageRate = (initialHp - currentHp) / initialHp * 100;
    if (damageRate <= 0) return BattleRank.ss;
    if (damageRate < 10) return BattleRank.a;
    if (damageRate < 20) return BattleRank.b;
    if (damageRate < 50) return BattleRank.c;
    if (damageRate < 80) return BattleRank.d;
    return BattleRank.e;
  }
  final ours = _status(friendShips);
  final enemy = _status(enemyShips);

  if (ours.sunk == 0) {
    if (enemy.sunk == enemy.count) {
      return ours.lostHp <= 0 ? BattleRank.ss : BattleRank.s;
    }
    final threshold = enemy.count < _halfSunkNumber.length
        ? _halfSunkNumber[enemy.count]
        : (enemy.count * 2 / 3).ceil();
    if (enemy.count > 1 && enemy.sunk >= threshold) {
      return BattleRank.a;
    }
  }
  if (enemy.flagshipSunk && ours.sunk < enemy.sunk) {
    return BattleRank.b;
  }
  if (ours.count == 1 && ours.flagshipCritical) {
    return BattleRank.d;
  }
  if (2 * enemy.lostHp * ours.totalHp > 5 * ours.lostHp * enemy.totalHp) {
    return BattleRank.b;
  }
  final enemyDamageAtLeastFriend =
      enemy.lostHp * ours.totalHp >= ours.lostHp * enemy.totalHp;
  final enemyDamageAtLeastHalf = 2 * enemy.lostHp >= enemy.totalHp;
  if (enemy.lostHp > 0 &&
      (enemyDamageAtLeastFriend || enemyDamageAtLeastHalf)) {
    return BattleRank.c;
  }
  if (ours.sunk > 0 && ours.count - ours.sunk == 1) {
    return BattleRank.e;
  }
  return BattleRank.d;
}

({
  int count,
  int sunk,
  int lostHp,
  int totalHp,
  bool flagshipSunk,
  bool flagshipCritical,
})
_status(List<BattleShipSnapshot> ships) {
  var totalHp = 0;
  var lostHp = 0;
  var sunk = 0;
  for (final ship in ships) {
    final hp = ship.currentHp.clamp(0, ship.maxHp);
    totalHp += ship.initialHp;
    lostHp += ship.initialHp - hp;
    if (hp <= 0) {
      sunk += 1;
    }
  }
  final flagship = ships.first;
  return (
    count: ships.length,
    sunk: sunk,
    lostHp: lostHp,
    totalHp: totalHp,
    flagshipSunk: flagship.currentHp <= 0,
    flagshipCritical: flagship.currentHp * 4 <= flagship.maxHp,
  );
}
