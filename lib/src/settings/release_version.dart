bool isNewerRelease(String candidateTag, {required String currentTag}) {
  final candidate = _SemanticVersion.tryParse(candidateTag);
  final current = _SemanticVersion.tryParse(currentTag);
  return candidate != null &&
      current != null &&
      candidate.compareTo(current) > 0;
}

bool isValidReleaseTag(String tag) => _SemanticVersion.tryParse(tag) != null;

String normalizedReleaseVersion(String tag) {
  final trimmed = tag.trim();
  return trimmed.startsWith('v') ? trimmed.substring(1) : trimmed;
}

/// A compact label only; release checks and data compatibility keep the raw version.
String displayReleaseVersion(String value) {
  final version = _SemanticVersion.tryParse(value);
  if (version == null) return value;
  final core =
      '${version.major}.${version.minor}'
      '${version.patch == 0 ? '' : '.${version.patch}'}';
  final preRelease = version.preRelease;
  if (preRelease == null) return core;
  if (preRelease.length == 2 &&
      preRelease.first == 'beta' &&
      _SemanticVersion._numericIdentifier.hasMatch(preRelease.last)) {
    return '$core Beta${BigInt.parse(preRelease.last)}';
  }
  return '$core-${preRelease.join('.')}';
}

final class _SemanticVersion implements Comparable<_SemanticVersion> {
  const _SemanticVersion(this.major, this.minor, this.patch, this.preRelease);

  final int major;
  final int minor;
  final int patch;
  final List<String>? preRelease;

  static final RegExp _pattern = RegExp(
    r'^v?(\d+)\.(\d+)(?:\.(\d+))?(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$',
  );
  static final RegExp _compactBeta = RegExp(r'^beta(\d+)$');
  static final RegExp _numericIdentifier = RegExp(r'^\d+$');

  static _SemanticVersion? tryParse(String value) {
    final match = _pattern.firstMatch(value.trim());
    if (match == null) {
      return null;
    }
    final major = int.tryParse(match.group(1)!);
    final minor = int.tryParse(match.group(2)!);
    final patch = int.tryParse(match.group(3) ?? '0');
    if (major == null || minor == null || patch == null) return null;
    final preRelease = match.group(4)?.split('.');
    final compactBeta = preRelease == null
        ? null
        : _compactBeta.firstMatch(preRelease.first);
    return _SemanticVersion(
      major,
      minor,
      patch,
      compactBeta == null
          ? preRelease
          : ['beta', compactBeta.group(1)!, ...preRelease!.skip(1)],
    );
  }

  @override
  int compareTo(_SemanticVersion other) {
    for (final comparison in <int>[
      major.compareTo(other.major),
      minor.compareTo(other.minor),
      patch.compareTo(other.patch),
    ]) {
      if (comparison != 0) {
        return comparison;
      }
    }
    final left = preRelease;
    final right = other.preRelease;
    if (left == null || right == null) {
      if (left == null && right == null) {
        return 0;
      }
      return left == null ? 1 : -1;
    }
    final sharedLength = left.length < right.length
        ? left.length
        : right.length;
    for (var index = 0; index < sharedLength; index++) {
      final comparison = _compareIdentifier(left[index], right[index]);
      if (comparison != 0) {
        return comparison;
      }
    }
    return left.length.compareTo(right.length);
  }

  static int _compareIdentifier(String left, String right) {
    final leftNumber = _numericIdentifier.hasMatch(left)
        ? BigInt.parse(left)
        : null;
    final rightNumber = _numericIdentifier.hasMatch(right)
        ? BigInt.parse(right)
        : null;
    if (leftNumber != null && rightNumber != null) {
      return leftNumber.compareTo(rightNumber);
    }
    if (leftNumber != null) {
      return -1;
    }
    if (rightNumber != null) {
      return 1;
    }
    return left.compareTo(right);
  }
}
