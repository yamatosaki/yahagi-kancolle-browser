import 'battle_models.dart';

const List<int> _halfSunkNumber = <int>[0, 1, 1, 2, 2, 3, 4, 4, 5, 6, 7, 7, 8];

BattleRank estimateBattleRank({
  required List<BattleShipSnapshot> friendShips,
  required List<BattleShipSnapshot> enemyShips,
}) {
  if (friendShips.isEmpty || enemyShips.isEmpty) {
    return BattleRank.unknown;
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
  if (2 * enemy.damageRate > 5 * ours.damageRate) {
    return BattleRank.b;
  }
  if (10 * enemy.damageRate > 9 * ours.damageRate) {
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
  int damageRate,
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
    damageRate: totalHp <= 0 ? 0 : (lostHp / totalHp * 100).floor(),
    flagshipSunk: flagship.currentHp <= 0,
    flagshipCritical: flagship.currentHp * 4 <= flagship.maxHp,
  );
}
