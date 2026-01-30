# UI Patterns & Widget Composition Rules

## CRITICAL: Widget Classes NOT Functions

### FORBIDDEN - Widget Functions (Methods)

```dart
// NEVER DO THIS
Widget _buildHeader() {
  return Text('Header');
}

Widget _buildContent() {
  return Column(children: [...]);
}

@override
Widget build(BuildContext context) {
  return Column(
    children: [
      _buildHeader(),    // BAD
      _buildContent(),   // BAD
    ],
  );
}
```

### REQUIRED - Widget Classes

```dart
// ALWAYS DO THIS
class HeaderWidget extends StatelessWidget {
  const HeaderWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text('Header');
  }
}

class ContentWidget extends StatelessWidget {
  const ContentWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(children: [...]);
  }
}
```

### Why Widget Classes are Superior

1. **Performance**: `const` constructors enable Flutter's optimization
2. **Hot Reload Stability**: Widget classes work perfectly with hot reload
3. **Maintainability**: Clear component boundaries
4. **Team Collaboration**: Consistent structure

## ConsumerWidget Pattern

### Screen (Container)

```dart
class ProjectScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectAsync = ref.watch(projectProvider(projectId));
    return projectAsync.when(
      data: (data) => ProjectContent(project: data),
      error: (error, stack) => ErrorDisplayWidget(error: error),
      loading: () => const LoadingIndicator(),
    );
  }
}
```

### Section Widget - Fine-grained Observation

```dart
class CategorySection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // REQUIRED: Use select() for performance
    final category = ref.watch(
      formProvider.select((state) => state.value?.category)
    );
    return CategorySelector(
      value: category,
      onChanged: (v) => ref.read(formProvider.notifier).updateCategory(v),
    );
  }
}
```

## Anti-Patterns to AVOID

### Double State (setState + Provider)

```dart
// FORBIDDEN
class _MyWidgetState extends ConsumerState<MyWidget> {
  String _localTitle = '';  // Duplicate state!

  @override
  Widget build(BuildContext context) {
    final title = ref.watch(titleProvider);  // Provider state
    // ...
  }
}
```

### Watch Entire Object

```dart
// BAD - Rebuilds on ANY field change
final project = ref.watch(projectProvider);
return Text(project.title);

// GOOD - Rebuilds only when title changes
final title = ref.watch(projectProvider.select((p) => p.title));
return Text(title);
```

### API Calls in Widgets

```dart
// FORBIDDEN - Direct API call in widget
@override
void initState() {
  FirebaseFirestore.instance.collection('projects').get().then(...);
}

// REQUIRED - API calls in Providers
final projectsAsync = ref.watch(projectsProvider);
```

## AsyncValue Handling

### Standard Pattern

```dart
return asyncValue.when(
  data: (data) => DataWidget(data: data),
  loading: () => const LoadingWidget(),
  error: (error, stack) => ErrorWidget(error: error),
);
```

### With Previous Data (Skeleton Loading)

```dart
return asyncValue.when(
  data: (data) => DataWidget(data: data),
  loading: () => asyncValue.hasValue
      ? DataWidget(data: asyncValue.value!) // Show stale data
      : const LoadingWidget(),              // Show skeleton
  error: (error, stack) => ErrorWidget(error: error),
);
```

### Skip Loading on Refresh

```dart
return asyncValue.when(
  skipLoadingOnRefresh: true,
  data: (data) => DataWidget(data: data),
  loading: () => const LoadingWidget(),
  error: (error, stack) => ErrorWidget(error: error),
);
```

## Best Practices Checklist

Before submitting presentation code, verify:

1. [ ] No widget-returning methods (`_buildXxx()`)
2. [ ] All reusable UI extracted to Widget classes
3. [ ] `const` constructors where possible
4. [ ] `ref.watch().select()` for fine-grained observation
5. [ ] No `setState` when Provider handles state
6. [ ] No direct API/Firebase calls in widgets
7. [ ] Using `when()` for AsyncValue handling

## Widget Naming Conventions

| Type | Naming Pattern | Example |
|------|----------------|---------|
| Screen | `{Feature}Screen` | `ProjectListScreen` |
| Page content | `{Feature}Content` | `ProjectContent` |
| Reusable section | `{Purpose}Section` | `CategorySection` |
| Simple display | `{Data}Widget` | `ProjectCard` |
| Form | `{Feature}Form` | `ProjectForm` |
