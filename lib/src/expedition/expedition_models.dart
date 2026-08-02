enum ExpeditionConditionKind {
  flagshipLevel,
  shipCount,
  composition,
  flagshipType,
  levelSum,
  resupply,
  morale,
  drumCount,
  drumCarrierCount,
  firepower,
  antiAir,
  antiSub,
  lineOfSight,
  greatSuccessRate,
  allSparkled,
  higherLevelFlagship,
  daihatsuFill,
}

class ExpeditionConditionResult {
  const ExpeditionConditionResult({
    required this.kind,
    required this.label,
    required this.actual,
    required this.passed,
    this.auxiliary = false,
  });

  final ExpeditionConditionKind kind;
  final String label;
  final String actual;
  final bool passed;
  final bool auxiliary;
}

class ExpeditionEvaluation {
  const ExpeditionEvaluation({
    required this.hasRule,
    required this.normalConditions,
    required this.greatSuccessConditions,
    required this.greatSuccessRate,
    required this.greatSuccessTarget,
    required this.daihatsuFill,
  });

  final bool hasRule;
  final List<ExpeditionConditionResult> normalConditions;
  final List<ExpeditionConditionResult> greatSuccessConditions;
  final double greatSuccessRate;
  final int greatSuccessTarget;
  final ExpeditionConditionResult daihatsuFill;

  bool get normalPassed =>
      hasRule && normalConditions.every((condition) => condition.passed);

  bool get greatSuccessPassed =>
      normalPassed &&
      greatSuccessConditions.every((condition) => condition.passed) &&
      greatSuccessRate >= greatSuccessTarget;
}

class ExpeditionIncome {
  const ExpeditionIncome({
    this.fuel = 0,
    this.ammunition = 0,
    this.steel = 0,
    this.bauxite = 0,
    this.items = const [],
  });

  final int fuel;
  final int ammunition;
  final int steel;
  final int bauxite;
  final List<ExpeditionRewardItem> items;

  List<int> get values => <int>[fuel, ammunition, steel, bauxite];
}

enum ExpeditionRewardKind {
  normal,
  greatSuccess,
}

class ExpeditionRewardItem {
  const ExpeditionRewardItem({
    required this.id,
    required this.count,
    required this.kind,
  });

  final int id;
  final int count;
  final ExpeditionRewardKind kind;
}
