enum ExpeditionRequirementType {
  flagshipLevel,
  shipCount,
  composition,
  flagshipType,
  levelSum,
  morale,
  drumCount,
  drumCarrierCount,
  firepower,
  antiAir,
  antiSub,
  lineOfSight,
}

class ExpeditionRequirement {
  const ExpeditionRequirement(
    this.type,
    this.value, [
    this.compositions = const [],
  ]);
  final ExpeditionRequirementType type;
  final int value;
  final List<Map<String, int>> compositions;
}

class ExpeditionRule {
  const ExpeditionRule(this.id, this.requirements);
  final int id;
  final List<ExpeditionRequirement> requirements;
}

ExpeditionRequirement _r(ExpeditionRequirementType type, int value) =>
    ExpeditionRequirement(type, value);
ExpeditionRequirement _c(Map<String, int> value) =>
    ExpeditionRequirement(ExpeditionRequirementType.composition, 0, [value]);
ExpeditionRequirement _ac(List<Map<String, int>> value) =>
    ExpeditionRequirement(ExpeditionRequirementType.composition, 0, value);
List<ExpeditionRequirement> _base(int flagshipLevel, int ships) => [
  _r(ExpeditionRequirementType.flagshipLevel, flagshipLevel),
  _r(ExpeditionRequirementType.shipCount, ships),
];

final Map<int, ExpeditionRule> expeditionRules = <int, ExpeditionRule>{
  1: ExpeditionRule(1, [
    ..._base(1, 2),
    _r(ExpeditionRequirementType.morale, 28),
  ]),
  2: ExpeditionRule(2, [
    ..._base(2, 4),
    _r(ExpeditionRequirementType.morale, 13),
  ]),
  3: ExpeditionRule(3, [
    ..._base(3, 3),
    _r(ExpeditionRequirementType.morale, 22),
  ]),
  4: ExpeditionRule(4, [..._base(3, 3), _escort]),
  5: ExpeditionRule(5, [..._base(3, 4), _escort]),
  6: ExpeditionRule(6, [
    ..._base(4, 4),
    _r(ExpeditionRequirementType.morale, 1),
  ]),
  7: ExpeditionRule(7, _base(5, 6)),
  8: ExpeditionRule(8, _base(6, 6)),
  9: ExpeditionRule(9, [..._base(3, 4), _escort]),
  10: ExpeditionRule(10, [
    ..._base(3, 3),
    _c({'CL': 2}),
  ]),
  11: ExpeditionRule(11, [
    ..._base(6, 4),
    _c({'DDorDE': 2}),
  ]),
  12: ExpeditionRule(12, [
    ..._base(4, 4),
    _c({'DDorDE': 2}),
  ]),
  13: ExpeditionRule(13, [
    ..._base(5, 6),
    _c({'CL': 1, 'DD': 4}),
  ]),
  14: ExpeditionRule(14, [
    ..._base(6, 6),
    _c({'CL': 1, 'DD': 3}),
  ]),
  15: ExpeditionRule(15, [
    ..._base(9, 6),
    _c({'CVLike': 2, 'DD': 2}),
  ]),
  16: ExpeditionRule(16, [
    ..._base(11, 6),
    _c({'CL': 1, 'DD': 2}),
  ]),
  17: ExpeditionRule(17, [
    ..._base(20, 6),
    _c({'CL': 1, 'DD': 3}),
  ]),
  18: ExpeditionRule(18, [
    ..._base(15, 6),
    _c({'CVLike': 3, 'DD': 2}),
  ]),
  19: ExpeditionRule(19, [
    ..._base(20, 6),
    _c({'BBV': 2, 'DD': 2}),
  ]),
  20: ExpeditionRule(20, [
    ..._base(1, 2),
    _c({'SSLike': 1, 'CL': 1}),
  ]),
  21: ExpeditionRule(21, [
    ..._base(15, 5),
    _r(ExpeditionRequirementType.levelSum, 30),
    _c({'CL': 1, 'DD': 4}),
    _r(ExpeditionRequirementType.drumCarrierCount, 3),
  ]),
  22: ExpeditionRule(22, [
    ..._base(30, 6),
    _r(ExpeditionRequirementType.levelSum, 45),
    _c({'CA': 1, 'CL': 1, 'DD': 2}),
  ]),
  23: ExpeditionRule(23, [
    ..._base(50, 6),
    _r(ExpeditionRequirementType.levelSum, 200),
    _c({'BBV': 2, 'DD': 2}),
  ]),
  24: ExpeditionRule(24, [
    ..._base(50, 6),
    _r(ExpeditionRequirementType.levelSum, 200),
    _c({'CL': 1, 'DDorDE': 4}),
    _r(ExpeditionRequirementType.flagshipType, 3),
  ]),
  25: ExpeditionRule(25, [
    ..._base(25, 4),
    _c({'CA': 2, 'DD': 2}),
  ]),
  26: ExpeditionRule(26, [
    ..._base(30, 4),
    _c({'CVLike': 1, 'CL': 1, 'DD': 2}),
  ]),
  27: ExpeditionRule(27, [
    ..._base(1, 2),
    _c({'SSLike': 2}),
  ]),
  28: ExpeditionRule(28, [
    ..._base(30, 3),
    _c({'SSLike': 3}),
  ]),
  29: ExpeditionRule(29, [
    ..._base(50, 3),
    _c({'SSLike': 3}),
  ]),
  30: ExpeditionRule(30, [
    ..._base(55, 4),
    _c({'SSLike': 4}),
  ]),
  31: ExpeditionRule(31, [
    ..._base(60, 4),
    _r(ExpeditionRequirementType.levelSum, 200),
    _c({'SSLike': 4}),
  ]),
  32: ExpeditionRule(32, [
    ..._base(5, 3),
    _c({'CT': 1, 'DD': 2}),
    _r(ExpeditionRequirementType.flagshipType, 21),
  ]),
  33: ExpeditionRule(33, [
    ..._base(1, 2),
    _c({'DD': 2}),
  ]),
  34: ExpeditionRule(34, [
    ..._base(1, 2),
    _c({'DD': 2}),
  ]),
  35: ExpeditionRule(35, [
    ..._base(40, 6),
    _c({'CVLike': 2, 'CA': 1, 'DD': 1}),
  ]),
  36: ExpeditionRule(36, [
    ..._base(30, 6),
    _c({'AV': 2, 'CL': 1, 'DD': 1}),
  ]),
  37: ExpeditionRule(37, [
    ..._base(50, 6),
    _r(ExpeditionRequirementType.levelSum, 200),
    _c({'CL': 1, 'DD': 5}),
    _r(ExpeditionRequirementType.drumCarrierCount, 3),
    _r(ExpeditionRequirementType.drumCount, 4),
  ]),
  38: ExpeditionRule(38, [
    ..._base(65, 6),
    _r(ExpeditionRequirementType.levelSum, 240),
    _c({'DD': 5}),
    _r(ExpeditionRequirementType.drumCarrierCount, 4),
    _r(ExpeditionRequirementType.drumCount, 8),
  ]),
  39: ExpeditionRule(39, [
    ..._base(3, 5),
    _r(ExpeditionRequirementType.levelSum, 180),
    _c({'AS': 1, 'SSLike': 4}),
  ]),
  40: ExpeditionRule(40, [
    ..._base(25, 6),
    _r(ExpeditionRequirementType.levelSum, 150),
    _c({'CL': 1, 'AV': 2, 'DD': 2}),
    _r(ExpeditionRequirementType.flagshipType, 3),
  ]),
  41: ExpeditionRule(41, [
    ..._base(30, 3),
    _r(ExpeditionRequirementType.levelSum, 100),
    _c({'DDorDE': 3}),
    _stats(60, 80, 210, 0),
  ]),
  42: ExpeditionRule(42, [
    ..._base(45, 4),
    _r(ExpeditionRequirementType.levelSum, 200),
    _escort,
  ]),
  43: ExpeditionRule(43, [
    ..._base(55, 6),
    _r(ExpeditionRequirementType.levelSum, 300),
    _r(ExpeditionRequirementType.flagshipType, 7),
    _ac([
      {'CVE': 1, 'DD': 2},
      {'CVE': 1, 'DE': 2},
      {'CVL': 1, 'CL': 1, 'DD': 4},
      {'CVL': 1, 'CL': 1, 'DE': 2},
      {'CVL': 1, 'DD': 1, 'DE': 3},
      {'CVL': 1, 'CT': 1, 'DE': 2},
      {'CVL': 1, 'CVE': 1, 'DD': 2},
      {'CVL': 1, 'CVE': 1, 'DE': 2},
    ]),
    _stats(500, 280, 280, 170),
  ]),
  44: ExpeditionRule(44, [
    ..._base(35, 6),
    _r(ExpeditionRequirementType.levelSum, 210),
    _c({'CVLike': 2, 'AV': 1, 'CL': 1, 'DDorDE': 2}),
    _r(ExpeditionRequirementType.drumCarrierCount, 3),
    _r(ExpeditionRequirementType.drumCount, 6),
    _stats(0, 200, 200, 150),
  ]),
  45: ExpeditionRule(45, [
    ..._base(50, 5),
    _r(ExpeditionRequirementType.levelSum, 240),
    _r(ExpeditionRequirementType.flagshipType, 7),
    _c({'CVL': 1, 'DDorDE': 4}),
    _stats(0, 240, 300, 180),
  ]),
  46: ExpeditionRule(46, [
    ..._base(60, 5),
    _r(ExpeditionRequirementType.levelSum, 300),
    _c({'CA': 2, 'CL': 1, 'DD': 2}),
    _stats(350, 250, 220, 190),
  ]),
  100: ExpeditionRule(100, [
    ..._base(5, 4),
    _r(ExpeditionRequirementType.levelSum, 10),
    _c({'DDorDE': 3}),
  ]),
  101: ExpeditionRule(101, [
    ..._base(20, 4),
    _c({'DDorDE': 4}),
    _stats(50, 70, 180, 0),
  ]),
  102: ExpeditionRule(102, [
    ..._base(35, 5),
    _r(ExpeditionRequirementType.levelSum, 185),
    _ac([
      {'CL': 1, 'DDorDE': 3},
      {'CL': 1, 'DE': 2},
      {'DD': 1, 'DE': 3},
      {'CT': 1, 'DE': 2},
      {'CVE': 1, 'DD': 2},
      {'CVE': 1, 'DE': 2},
    ]),
    _stats(0, 0, 280, 60),
  ]),
  103: ExpeditionRule(103, [
    ..._base(40, 5),
    _r(ExpeditionRequirementType.levelSum, 200),
    _ac([
      {'CL': 1, 'DD': 2},
      {'CL': 1, 'DE': 2},
      {'DD': 1, 'DE': 3},
      {'CT': 1, 'DE': 2},
      {'CVE': 1, 'DD': 2},
      {'CVE': 1, 'DE': 2},
    ]),
    _stats(300, 200, 200, 120),
  ]),
  104: ExpeditionRule(104, [
    ..._base(45, 5),
    _r(ExpeditionRequirementType.levelSum, 230),
    _ac([
      {'CL': 1, 'DD': 3},
      {'CL': 1, 'DE': 2},
      {'DD': 1, 'DE': 3},
      {'CT': 1, 'DE': 2},
      {'CVE': 1, 'DD': 2},
      {'CVE': 1, 'DE': 2},
    ]),
    _stats(280, 220, 240, 150),
  ]),
  105: ExpeditionRule(105, [
    ..._base(55, 6),
    _r(ExpeditionRequirementType.levelSum, 290),
    _ac([
      {'CL': 1, 'DD': 3},
      {'CL': 1, 'DE': 2},
      {'DD': 1, 'DE': 3},
      {'CT': 1, 'DE': 2},
      {'CVE': 1, 'DD': 2},
      {'CVE': 1, 'DE': 2},
    ]),
    _stats(330, 300, 270, 180),
  ]),
  110: ExpeditionRule(110, [
    ..._base(40, 6),
    _r(ExpeditionRequirementType.levelSum, 150),
    _c({'AV': 1, 'CL': 1, 'DDorDE': 2}),
    _stats(0, 200, 200, 140),
  ]),
  111: ExpeditionRule(111, [
    ..._base(45, 6),
    _r(ExpeditionRequirementType.levelSum, 220),
    _c({'CA': 1, 'CL': 1, 'DD': 3}),
    _stats(360, 160, 160, 140),
  ]),
  112: ExpeditionRule(112, [
    ..._base(50, 6),
    _r(ExpeditionRequirementType.levelSum, 250),
    _c({'AV': 1, 'CL': 1, 'DD': 4}),
    _stats(400, 220, 220, 190),
  ]),
  113: ExpeditionRule(113, [
    ..._base(55, 6),
    _r(ExpeditionRequirementType.levelSum, 300),
    _c({'CA': 2, 'CL': 1, 'DD': 2, 'SSLike': 1}),
    _stats(500, 280, 280, 170),
  ]),
  114: ExpeditionRule(114, [
    ..._base(60, 6),
    _r(ExpeditionRequirementType.levelSum, 330),
    _c({'AV': 1, 'CL': 1, 'DD': 2}),
    _stats(510, 400, 285, 385),
  ]),
  115: ExpeditionRule(115, [
    ..._base(75, 6),
    _r(ExpeditionRequirementType.levelSum, 400),
    _c({'CL': 1, 'DD': 5}),
    _stats(410, 390, 410, 340),
    _r(ExpeditionRequirementType.flagshipType, 3),
  ]),
  131: ExpeditionRule(131, [
    ..._base(50, 5),
    _r(ExpeditionRequirementType.levelSum, 200),
    _r(ExpeditionRequirementType.flagshipType, 16),
    _c({'AV': 1, 'DD': 3}),
    _stats(0, 240, 240, 300),
  ]),
  132: ExpeditionRule(132, [
    ..._base(55, 5),
    _r(ExpeditionRequirementType.levelSum, 270),
    _r(ExpeditionRequirementType.flagshipType, 20),
    _c({'AS': 1, 'SSLike': 3}),
    _stats(60, 80, 50, 0),
  ]),
  133: ExpeditionRule(133, [
    ..._base(65, 5),
    _r(ExpeditionRequirementType.levelSum, 350),
    _r(ExpeditionRequirementType.flagshipType, 20),
    _c({'AS': 1, 'SSLike': 3}),
    _stats(115, 90, 70, 95),
  ]),
  141: ExpeditionRule(141, [
    ..._base(55, 6),
    _r(ExpeditionRequirementType.levelSum, 290),
    _c({'CA': 1, 'CL': 1, 'DD': 3}),
    _r(ExpeditionRequirementType.flagshipType, 5),
    _stats(450, 350, 330, 250),
  ]),
  142: ExpeditionRule(142, [
    ..._base(70, 5),
    _r(ExpeditionRequirementType.levelSum, 320),
    _c({'DD': 5}),
    _stats(280, 240, 200, 160),
    _r(ExpeditionRequirementType.drumCarrierCount, 3),
    _r(ExpeditionRequirementType.drumCount, 4),
  ]),
};

final ExpeditionRequirement _escort = _ac([
  {'CL': 1, 'DDorDE': 2},
  {'DD': 1, 'DE': 3},
  {'CT': 1, 'DE': 2},
  {'CVE': 1, 'DE': 2},
  {'CVE': 1, 'DD': 2},
]);
ExpeditionRequirement _stats(int fp, int aa, int asw, int los) =>
    ExpeditionRequirement(ExpeditionRequirementType.firepower, fp, [
      <String, int>{'aa': aa, 'asw': asw, 'los': los},
    ]);
