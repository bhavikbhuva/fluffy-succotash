// PestRaksh: a service's packages grouped into plans (Admin → Services →
// Package plans), as the website's utils/packagePlans.ts. The API sends
// `package_plans` on the service ({size_heading, plans: [{key, name,
// description}]}, in display order) and `plan_key` / `size_label` on each
// package. Such a service is shown in two steps: choose a plan, then a size.
import 'package:customer/utils/json_parsers.dart';

class PackagePlanInfo {
  PackagePlanInfo.fromJson(Map<String, dynamic> json)
    : key = parseString(json['key']) ?? '',
      name = (parseString(json['name']) ?? '').trim(),
      description = (parseString(json['description']) ?? '').trim();

  final String key;
  final String name;
  final String description;
}

class PackagePlansConfig {
  PackagePlansConfig.fromJson(Map<String, dynamic> json)
    : sizeHeading = (parseString(json['size_heading']) ?? '').trim(),
      plans = [
        for (final p
            in (json['plans'] is List ? json['plans'] as List : const []))
          if (p is Map<String, dynamic>) PackagePlanInfo.fromJson(p),
      ];

  /// "Home size", "Floor area", …
  final String sizeHeading;
  final List<PackagePlanInfo> plans;

  static PackagePlansConfig? tryParse(dynamic raw) =>
      raw is Map<String, dynamic> ? PackagePlansConfig.fromJson(raw) : null;
}

/// One plan with its packages, in the server's order.
class PackagePlan<T> {
  PackagePlan(this.info) : variants = [];

  final PackagePlanInfo info;
  final List<T> variants;

  String get key => info.key;
  String get name => info.name;
  String get description => info.description;
}

class PackagePlanGroups<T> {
  PackagePlanGroups(this.sizeHeading, this.plans);

  final String sizeHeading;
  final List<PackagePlan<T>> plans;

  /// The plan of [selected], or the first plan.
  PackagePlan<T> planOf(T? selected, String Function(T) planKey) {
    if (selected != null) {
      final key = planKey(selected);
      for (final p in plans) {
        if (p.key == key) return p;
      }
    }
    return plans.first;
  }
}

/// Groups [variants] by plan, or null to show the plain list: no plans, or any
/// package without a known plan or a size. Hiding a package because its plan
/// is missing would be worse than a long list (as on the website).
PackagePlanGroups<T>? groupPackagePlans<T>(
  PackagePlansConfig? config,
  List<T>? variants, {
  required String Function(T) planKey,
  required String Function(T) sizeLabel,
}) {
  final list = variants ?? const [];
  if (config == null || config.plans.isEmpty || list.isEmpty) return null;
  final plans = [
    for (final p in config.plans)
      if (p.key.isNotEmpty && p.name.isNotEmpty) PackagePlan<T>(p),
  ];
  final byKey = {for (final p in plans) p.key: p};
  for (final v in list) {
    final plan = byKey[planKey(v)];
    if (plan == null || sizeLabel(v).trim().isEmpty) return null;
    plan.variants.add(v);
  }
  final used = [
    for (final p in plans)
      if (p.variants.isNotEmpty) p,
  ];
  return used.isEmpty ? null : PackagePlanGroups<T>(config.sizeHeading, used);
}

/// Switching plan keeps the size the customer had (2 BHK stays 2 BHK) where
/// the new plan has it; otherwise its first size.
T samePackageSizeIn<T>(
  PackagePlan<T> plan,
  T? selected,
  String Function(T) sizeLabel,
) {
  if (selected != null) {
    final want = sizeLabel(selected).trim().toLowerCase();
    for (final v in plan.variants) {
      if (sizeLabel(v).trim().toLowerCase() == want) return v;
    }
  }
  return plan.variants.first;
}
