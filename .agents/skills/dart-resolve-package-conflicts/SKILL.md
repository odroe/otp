---
name: dart-resolve-package-conflicts
description: Workflow for fixing package version conflicts. Use this when `pub get` fails due to incompatible package versions.
metadata:
  model: models/gemini-3.1-pro-preview
  last_modified: Fri, 24 Apr 2026 15:11:14 GMT
---
# Managing Dart Dependencies

## Contents
- [Core Concepts](#core-concepts)
- [Version Constraints](#version-constraints)
- [Workflow: Auditing Dependencies](#workflow-auditing-dependencies)
- [Workflow: Upgrading Dependencies](#workflow-upgrading-dependencies)
- [Workflow: Resolving Version Conflicts](#workflow-resolving-version-conflicts)
- [Examples](#examples)

## Core Concepts

The commands below use the Dart CLI for pure Dart projects. For Flutter projects, including this repository's root workspace, use `flutter pub` in place of `dart pub`, `flutter analyze` in place of `dart analyze`, and `flutter test` in place of `dart test`.

Dart enforces a strict single-version rule for dependencies: a project and all its transitive dependencies must resolve to a single, shared version of any given package. This prevents runtime type mismatches but introduces the risk of "version lock."

To mitigate version lock, Dart relies on version constraints rather than pinned versions in the `pubspec.yaml`. The `pubspec.lock` file maintains the exact resolved versions for reproducible builds.

Understand the output columns of `dart pub outdated`:
*   **Current:** The version currently recorded in `pubspec.lock`.
*   **Upgradable:** The latest version allowed by the constraints in `pubspec.yaml`. `dart pub upgrade` resolves to this.
*   **Resolvable:** The absolute latest version that can be resolved when factoring in all other dependencies in the project.
*   **Latest:** The latest published version of the package (excluding prereleases).

## Version Constraints

*   **Use Caret Syntax:** Always use caret syntax (e.g., `^1.2.3`) for dependencies in `pubspec.yaml`. This allows `pub` to select newer, compatible versions during resolution: below the next major version for versions at or above 1.0, or below the next minor version for pre-1.0 versions (for example, `^0.1.2` means `>=0.1.2 <0.2.0`).
*   **Tighten Dev Dependencies:** Set the lower bound of `dev_dependencies` to the exact version currently used. This reduces resolution complexity and prevents older, incompatible dev tools from being selected.
*   **Enforce Lockfiles in CI:** Use `dart pub get --enforce-lockfile` in CI/CD pipelines to ensure the exact versions tested locally are used in production.

## Workflow: Auditing Dependencies

Run this workflow periodically to identify stale packages that may impact stability or performance.

**Task Progress:**
- [ ] Run `dart pub outdated`.
- [ ] Review the **Upgradable** column to identify packages that can be updated without modifying `pubspec.yaml`.
- [ ] Review the **Resolvable** column to identify packages that require constraint modifications in `pubspec.yaml` to update.
- [ ] Identify any packages marked as retracted or discontinued.

## Workflow: Upgrading Dependencies

Use conditional logic based on the audit results to upgrade dependencies.

**Task Progress:**
- [ ] **If updating to "Upgradable" versions:**
  - [ ] Run `dart pub upgrade`.
  - [ ] Run `dart pub upgrade --tighten` to automatically update the lower bounds in `pubspec.yaml` to match the newly resolved versions.
- [ ] **If updating to "Resolvable" versions (Major updates):**
  - [ ] Manually edit `pubspec.yaml` to bump the version constraint to match the "Resolvable" column (e.g., change `^0.11.0` to `^0.12.1`).
  - [ ] Run `dart pub upgrade` to resolve the new constraints and update `pubspec.lock`.
- [ ] **Feedback Loop:**
  - [ ] Run `dart analyze` -> review errors -> fix breaking API changes.
  - [ ] Run `dart test` -> review failures -> fix regressions.

## Workflow: Resolving Version Conflicts

When `pub` cannot satisfy all version constraints, use the solver output to identify the responsible direct dependency or SDK constraint and adjust it in `pubspec.yaml`. Deleting lockfile entries cannot resolve incompatible constraints. If the conflict comes from a transitive dependency, select a compatible version of the direct dependency that introduces it.

For a retracted version with a compatible replacement, update only the affected package; the surgical lockfile workflow below preserves unrelated locked versions where possible.

**NEVER** delete the entire `pubspec.lock` file and run `dart pub get`. This causes uncontrolled upgrades across the entire dependency graph.

**Task Progress:**
- [ ] Open `pubspec.lock`.
- [ ] Locate the specific YAML block for the retracted package after verifying that a compatible replacement exists.
- [ ] Delete ONLY that package's entry from the lockfile.
- [ ] Run `dart pub get` to resolve a compatible, non-retracted replacement; review the lockfile diff for any required transitive changes.
- [ ] **Feedback Loop:**
  - [ ] Run `dart pub deps` -> verify the dependency graph resolves correctly.
  - [ ] If resolution fails, use the solver output to adjust the responsible direct dependency or SDK constraint in `pubspec.yaml`, and retry.

## Examples

### Tightening Constraints
When `dart pub outdated` shows a package is resolvable to a higher minor/patch version, use the `--tighten` flag to update the `pubspec.yaml` automatically.

**Input (`pubspec.yaml`):**
```yaml
dependencies:
  http: ^0.13.0
```

**Command:**
```bash
dart pub upgrade --tighten http
```

**Output (`pubspec.yaml`):**
```yaml
dependencies:
  http: ^0.13.5
```

### Surgical Lockfile Removal
If `package_a` is retracted and the constraints allow a replacement, remove only its block from `pubspec.lock`.

**Before (`pubspec.lock`):**
```yaml
packages:
  package_a:
    dependency: "direct main"
    description:
      name: package_a
      url: "https://pub.dev"
    source: hosted
    version: "1.0.0" # Retracted version
  package_b:
    dependency: "direct main"
    # ...
```

**Action:** Delete the `package_a` block entirely. Leave `package_b` untouched. Run `dart pub get`.
