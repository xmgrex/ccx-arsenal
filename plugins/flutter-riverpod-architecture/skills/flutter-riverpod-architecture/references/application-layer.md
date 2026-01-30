# Application Layer Rules

## Layer Purpose

Handle business logic, state management, and Provider definitions.

## ALLOWED

- Riverpod providers and state management
- Business logic and domain orchestration
- Repository consumption and dependency injection
- `flutter_riverpod` package

## FORBIDDEN

- `package:flutter/` imports (except flutter_riverpod)
- UI classes (`BuildContext`, `Navigator`, `showDialog`, `ScaffoldMessenger`)
- Widget classes

## Provider Types

### Repository Providers (Singleton)

```dart
@Riverpod(keepAlive: true)
SomeRepository someRepository(Ref ref) {
  return SomeRepository(
    firestore: ref.watch(firebaseFirestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
    isWeb: kIsWeb,  // Platform check HERE, not in data layer
  );
}
```

### Stream Providers (Auto-dispose)

```dart
@riverpod
Stream<List<Project>> projects(Ref ref) {
  return ref.watch(projectRepositoryProvider).watchProjects();
}
// NOTE: ref.invalidate() NOT NEEDED for StreamProviders
```

### Future Providers (Auto-dispose)

```dart
@riverpod
Future<Project> projectDetail(Ref ref, String projectId) async {
  return ref.watch(projectRepositoryProvider).getProject(projectId);
}
// NOTE: ref.invalidate() REQUIRED after write operations
```

## AsyncNotifier Pattern (REQUIRED)

```dart
@riverpod
class SomeNotifier extends _$SomeNotifier {
  @override
  Future<void> build() async => null;

  Future<void> someAction({required params}) async {
    // 1. Prevent disposal during async operation
    final link = ref.keepAlive();

    // 2. Set loading state
    state = const AsyncValue.loading();

    // 3. Execute with automatic error handling
    state = await AsyncValue.guard(() async {
      final repo = ref.read(someRepositoryProvider);
      await repo.performAction(params);
    });

    // 4. Release keepAlive
    link.close();
  }
}
```

## State Management

### RECOMMENDED: AsyncValue<T>

```dart
// Let Riverpod handle loading/error automatically
@riverpod
class ProjectForm extends _$ProjectForm {
  @override
  Future<Project> build() async => Project.empty();

  Future<void> submit() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return await ref.read(projectRepositoryProvider).create(state.value!);
    });
  }
}
```

### AVOID: Custom XXXState classes

```dart
// ANTI-PATTERN: Don't manually manage loading/error
@freezed
class ProjectFormState with _$ProjectFormState {
  const factory ProjectFormState({
    @Default(false) bool isLoading,  // AsyncValue handles this
    String? errorMessage,             // AsyncValue handles this
  }) = _ProjectFormState;
}
```

## Controller Creation Criteria

### CREATE Controller when:

- Multiple repositories need coordination
- Complex business rules apply
- Transaction management required
- Side effects need chaining

### DON'T CREATE Controller when:

- Simple CRUD to a single repository
- No additional business logic
- Would be a pass-through

**Principle**: YAGNI - Don't create until needed

## Provider Invalidation Rules

| Provider Type | After Write Operation |
|---------------|-----------------------|
| StreamProvider | No invalidation needed (auto-updates) |
| FutureProvider | `ref.invalidate()` required |
| StateProvider | Manual state update |

```dart
// After creating a project
await repository.createProject(project);
ref.invalidate(projectDetailProvider(projectId)); // Required for FutureProvider
// StreamProvider watching projects list updates automatically
```

## Custom Lint Rules (Recommended)

- `forbid_application_flutter_import`: Application layer cannot import Flutter UI classes
