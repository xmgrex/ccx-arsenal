# Data Layer Rules

## Layer Purpose

Handle external data sources (Firebase, HTTP, etc.) as a Pure Dart layer.

## ALLOWED

- Pure Dart implementation
- External SDKs (Firebase, HTTP clients, etc.)
- Pure Dart domain models and value objects

## FORBIDDEN

- `package:flutter/` imports
- `@riverpod` annotations or Riverpod dependencies
- UI classes (`BuildContext`, `Navigator`, `showDialog`, etc.)
- `kIsWeb` and other platform-dependent constants

## Constructor Pattern

```dart
// REQUIRED: const constructor + required dependencies
const SomeRepository({
  required FirebaseFirestore firestore,
  required FirebaseAuth auth,
  required bool isWeb,  // Platform check injected from application layer
}) : _firestore = firestore,
     _auth = auth,
     _isWeb = isWeb;
```

## Dependency Injection

### BAD - Direct platform dependency

```dart
class AuthRepository {
  Future<UserCredential?> signInWithGoogle() {
    if (kIsWeb) { // FORBIDDEN: Flutter dependency
      return _auth.signInWithPopup(GoogleAuthProvider());
    }
  }
}
```

### GOOD - Injected dependency

```dart
class AuthRepository {
  const AuthRepository({
    required FirebaseAuth firebaseAuth,
    required bool isWeb,  // Injected from application layer
  });

  Future<UserCredential?> signInWithGoogle() {
    if (_isWeb) {  // Uses injected value
      return _auth.signInWithPopup(GoogleAuthProvider());
    }
  }
}
```

## Repository Pattern

```dart
class ProjectRepository {
  const ProjectRepository({
    required FirebaseFirestore firestore,
  }) : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('projects');

  /// Watch all projects as a stream
  Stream<List<Project>> watchProjects() {
    return _collection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Project.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  /// Get a single project by ID
  Future<Project> getProject(String id) async {
    final doc = await _collection.doc(id).get();
    if (!doc.exists) {
      throw Exception('Project not found: $id');
    }
    return Project.fromJson({...doc.data()!, 'id': doc.id});
  }

  /// Create a new project
  Future<String> createProject(Project project) async {
    final doc = await _collection.add(project.toJson());
    return doc.id;
  }

  /// Update an existing project
  Future<void> updateProject(Project project) async {
    await _collection.doc(project.id).update(project.toJson());
  }

  /// Delete a project
  Future<void> deleteProject(String id) async {
    await _collection.doc(id).delete();
  }
}
```

## Verification

```bash
# Check for forbidden imports (must return empty)
grep -r "package:flutter" lib/features/*/data/
grep -r "riverpod" lib/features/*/data/
grep -r "kIsWeb" lib/features/*/data/
```

## Custom Lint Rules (Recommended)

- `forbid_data_upper_imports`: Data layer cannot import presentation/application/Flutter
- `avoid_provider_in_data_layer`: Data layer cannot use Riverpod
