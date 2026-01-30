# Dart/Flutter Log Patterns

Copy-paste-ready logging patterns for Flutter/Dart debugging.

## Basic Debug Output

```dart
// Simple value logging
debugPrint('[ClassName] methodName: variable=$variable');

// Multiple values
debugPrint('[ClassName] methodName: a=$a, b=$b, c=$c');

// Conditional/state logging
debugPrint('[ClassName] condition check: isValid=$isValid, value=$value');

// Method entry/exit
debugPrint('[ClassName] methodName: ENTER params=($param1, $param2)');
debugPrint('[ClassName] methodName: EXIT result=$result');
```

## Widget Lifecycle

```dart
@override
void initState() {
  super.initState();
  debugPrint('[${widget.runtimeType}] initState');
}

@override
void didChangeDependencies() {
  super.didChangeDependencies();
  debugPrint('[${widget.runtimeType}] didChangeDependencies');
}

@override
void didUpdateWidget(covariant OldWidget oldWidget) {
  super.didUpdateWidget(oldWidget);
  debugPrint('[${widget.runtimeType}] didUpdateWidget');
}

@override
void dispose() {
  debugPrint('[${widget.runtimeType}] dispose');
  super.dispose();
}
```

## Build Tracking

```dart
@override
Widget build(BuildContext context) {
  debugPrint('[${widget.runtimeType}] build: key=${widget.key}');
  return Container(
    // ...
  );
}

// With state info
@override
Widget build(BuildContext context) {
  debugPrint('[${widget.runtimeType}] build: isLoading=$isLoading, itemCount=${items.length}');
  return // ...
}
```

## Async Operations

```dart
Future<void> fetchData() async {
  debugPrint('[ClassName] fetchData: START');
  try {
    final result = await api.getData();
    debugPrint('[ClassName] fetchData: SUCCESS count=${result.length}');
  } catch (e, stackTrace) {
    debugPrint('[ClassName] fetchData: ERROR $e');
    debugPrint('[ClassName] fetchData: STACK $stackTrace');
  }
}
```

## Stream Handling

```dart
stream.listen(
  (data) {
    debugPrint('[ClassName] stream: DATA received=$data');
  },
  onError: (error) {
    debugPrint('[ClassName] stream: ERROR $error');
  },
  onDone: () {
    debugPrint('[ClassName] stream: DONE');
  },
);
```

## State Management

### setState

```dart
void updateCounter() {
  debugPrint('[ClassName] updateCounter: BEFORE counter=$counter');
  setState(() {
    counter++;
  });
  debugPrint('[ClassName] updateCounter: AFTER counter=$counter');
}
```

### Provider/Riverpod

```dart
// Provider notifyListeners
void updateState(String newValue) {
  debugPrint('[ClassName] updateState: from=$_value to=$newValue');
  _value = newValue;
  notifyListeners();
}

// Riverpod state change
ref.listen<MyState>(myProvider, (previous, next) {
  debugPrint('[ClassName] state changed: $previous -> $next');
});
```

### BLoC

```dart
// Event handling
on<MyEvent>((event, emit) {
  debugPrint('[MyBloc] event received: $event');
  debugPrint('[MyBloc] current state: $state');
  emit(newState);
  debugPrint('[MyBloc] new state: $newState');
});
```

## Gesture Handling

```dart
GestureDetector(
  onTap: () {
    debugPrint('[MyWidget] onTap triggered');
    // ... handler code
  },
  onTapDown: (details) {
    debugPrint('[MyWidget] onTapDown: position=${details.globalPosition}');
  },
  onPanStart: (details) {
    debugPrint('[MyWidget] onPanStart: position=${details.globalPosition}');
  },
  onPanUpdate: (details) {
    debugPrint('[MyWidget] onPanUpdate: delta=${details.delta}');
  },
  onPanEnd: (details) {
    debugPrint('[MyWidget] onPanEnd: velocity=${details.velocity}');
  },
)
```

## Navigation

```dart
// Push
debugPrint('[ClassName] navigating to: /details');
Navigator.pushNamed(context, '/details', arguments: {'id': id});

// Pop
debugPrint('[ClassName] popping with result: $result');
Navigator.pop(context, result);

// Route observer
class DebugRouteObserver extends RouteObserver<PageRoute<dynamic>> {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    debugPrint('[Router] PUSH: ${previousRoute?.settings.name} -> ${route.settings.name}');
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    debugPrint('[Router] POP: ${route.settings.name} -> ${previousRoute?.settings.name}');
    super.didPop(route, previousRoute);
  }
}
```

## API Calls

```dart
Future<Response> makeApiCall(String endpoint, Map<String, dynamic> body) async {
  debugPrint('[ApiClient] REQUEST: $endpoint');
  debugPrint('[ApiClient] BODY: ${jsonEncode(body)}');

  final response = await http.post(Uri.parse(endpoint), body: body);

  debugPrint('[ApiClient] RESPONSE: status=${response.statusCode}');
  debugPrint('[ApiClient] RESPONSE BODY: ${response.body}');

  return response;
}
```

## Conditional Branches

```dart
void processItem(Item item) {
  if (item.isValid) {
    debugPrint('[ClassName] processItem: branch=VALID item=${item.id}');
    // valid path
  } else if (item.isPending) {
    debugPrint('[ClassName] processItem: branch=PENDING item=${item.id}');
    // pending path
  } else {
    debugPrint('[ClassName] processItem: branch=INVALID item=${item.id}');
    // invalid path
  }
}
```

## Loop Iterations

```dart
for (var i = 0; i < items.length; i++) {
  debugPrint('[ClassName] processing: iteration=${i + 1}/${items.length} item=${items[i].id}');
  // process item
}

// For each with index
items.asMap().forEach((index, item) {
  debugPrint('[ClassName] forEach: ${index + 1}/${items.length} item=${item.id}');
});
```

## Performance Timing

```dart
final stopwatch = Stopwatch()..start();
// ... operation
stopwatch.stop();
debugPrint('[ClassName] operation took: ${stopwatch.elapsedMilliseconds}ms');
```

## Notes

- `debugPrint` is throttled and safe for large output (unlike `print`)
- Use `kDebugMode` check to conditionally include logging:
  ```dart
  if (kDebugMode) {
    debugPrint('[ClassName] debug info');
  }
  ```
- For production logging, consider using `logger` package
