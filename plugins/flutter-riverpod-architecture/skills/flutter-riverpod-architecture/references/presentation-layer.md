# Presentation Layer Rules

## Layer Purpose

Handle UI components, widgets, screens, and route guards.

## ALLOWED

- Full Flutter framework access
- UI state management (presentation layer notifiers)
- User interactions
- go_router integration
- Design system tokens

## FORBIDDEN - Direct Data Layer Access

```dart
// FORBIDDEN - Direct Data layer access
import 'package:myapp/features/*/data/*_repository.dart';

// FORBIDDEN - Calling Repository directly
final repository = ProjectRepository(...);
await repository.createProject(...);
```

Presentation layer accesses data ONLY through Application layer Providers.

## Screen with ConsumerWidget

```dart
class ProjectListScreen extends ConsumerWidget {
  const ProjectListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Projects')),
      body: projectsAsync.when(
        data: (projects) => ListView.builder(
          itemCount: projects.length,
          itemBuilder: (context, index) => ProjectCard(
            project: projects[index],
            onTap: () => ProjectDetailRoute(
              projectId: projects[index].id,
            ).push(context),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }
}
```

## Type-Safe Routing (go_router)

```dart
// lib/app/route/routes.dart
@TypedGoRoute<ProjectListRoute>(
  path: '/projects',
  routes: [
    TypedGoRoute<ProjectDetailRoute>(path: ':projectId'),
  ],
)
class ProjectListRoute extends GoRouteData {
  const ProjectListRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return const ProjectListScreen();
  }
}

class ProjectDetailRoute extends GoRouteData {
  const ProjectDetailRoute({required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return ProjectDetailScreen(projectId: projectId);
  }
}

// Usage
ProjectDetailRoute(projectId: 'abc123').push(context);
```

## UI State Notifier (Presentation Layer Provider)

```dart
// presentation/providers/project_form_notifier.dart
@riverpod
class ProjectFormNotifier extends _$ProjectFormNotifier {
  @override
  ProjectFormState build() => const ProjectFormState();

  void updateTitle(String title) {
    state = state.copyWith(title: title);
  }

  Future<void> submit() async {
    state = state.copyWith(isSubmitting: true);
    try {
      final controller = ref.read(projectControllerProvider);
      await controller.createProject(
        title: state.title,
        description: state.description,
      );
      state = state.copyWith(isSubmitting: false, isSuccess: true);
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
    }
  }
}
```

## select() Optimization

```dart
// BAD - Watches entire object (unnecessary rebuilds)
final user = ref.watch(userProvider);
Text(user.name);

// GOOD - Watches only needed field
final userName = ref.watch(userProvider.select((u) => u.name));
Text(userName);
```

## Layer Compliance Checklist

Before submitting presentation code, verify:

1. [ ] Not importing Data layer (`*_repository.dart`) directly
2. [ ] Accessing data through Application layer Providers
3. [ ] Using go_router type-safe routing
4. [ ] Using `select()` to watch only needed data

## Verification

```bash
# Check for forbidden data layer imports (must return empty)
grep -r "features/.*/data/.*_repository" lib/features/*/presentation/
```

## Related References

- `ui-patterns.md` - Widget class patterns, ConsumerWidget usage
