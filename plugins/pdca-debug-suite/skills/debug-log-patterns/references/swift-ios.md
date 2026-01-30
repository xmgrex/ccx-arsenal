# Swift/iOS Log Patterns

Copy-paste-ready logging patterns for iOS/Swift debugging.

## Basic Print Logging

```swift
// Simple value logging
print("[ClassName] methodName: variable=\(variable)")

// Multiple values
print("[ClassName] methodName: a=\(a), b=\(b), c=\(c)")

// Conditional logging
print("[ClassName] condition check: isValid=\(isValid), value=\(value)")

// Method entry/exit
print("[ClassName] methodName: ENTER params=(\(param1), \(param2))")
print("[ClassName] methodName: EXIT result=\(result)")

// With optional handling
print("[ClassName] methodName: optionalValue=\(optionalValue ?? "nil")")
```

## UIViewController Lifecycle

```swift
override func viewDidLoad() {
    super.viewDidLoad()
    print("[\(type(of: self))] viewDidLoad")
}

override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    print("[\(type(of: self))] viewWillAppear: animated=\(animated)")
}

override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    print("[\(type(of: self))] viewDidAppear")
}

override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    print("[\(type(of: self))] viewWillDisappear")
}

override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    print("[\(type(of: self))] viewDidDisappear")
}

deinit {
    print("[\(type(of: self))] deinit")
}
```

## SwiftUI View Lifecycle

```swift
struct MyView: View {
    var body: some View {
        let _ = print("[MyView] body computed")

        VStack {
            // content
        }
        .onAppear {
            print("[MyView] onAppear")
        }
        .onDisappear {
            print("[MyView] onDisappear")
        }
        .onChange(of: someValue) { oldValue, newValue in
            print("[MyView] onChange: \(oldValue) -> \(newValue)")
        }
        .task {
            print("[MyView] task started")
        }
    }
}
```

## Async/Await Operations

```swift
func fetchData() async {
    print("[ClassName] fetchData: START")
    do {
        let result = try await api.getData()
        print("[ClassName] fetchData: SUCCESS count=\(result.count)")
    } catch {
        print("[ClassName] fetchData: ERROR \(error)")
    }
}

// With Task
Task {
    print("[ClassName] task: STARTED")
    await performOperation()
    print("[ClassName] task: COMPLETED")
}
```

## Combine

```swift
publisher
    .handleEvents(
        receiveSubscription: { _ in
            print("[ClassName] publisher: SUBSCRIBED")
        },
        receiveOutput: { value in
            print("[ClassName] publisher: OUTPUT \(value)")
        },
        receiveCompletion: { completion in
            print("[ClassName] publisher: COMPLETION \(completion)")
        },
        receiveCancel: {
            print("[ClassName] publisher: CANCELLED")
        }
    )
    .sink { value in
        print("[ClassName] sink: received \(value)")
    }
    .store(in: &cancellables)
```

## ObservableObject (SwiftUI)

```swift
class MyViewModel: ObservableObject {
    @Published var state: String = "" {
        didSet {
            print("[MyViewModel] state changed: \(oldValue) -> \(state)")
        }
    }

    init() {
        print("[MyViewModel] init")
    }

    deinit {
        print("[MyViewModel] deinit")
    }

    func updateState(_ newValue: String) {
        print("[MyViewModel] updateState: from=\(state) to=\(newValue)")
        state = newValue
    }
}
```

## Button Actions

```swift
// UIKit
button.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)

@objc func buttonTapped() {
    print("[ClassName] button tapped")
}

// SwiftUI
Button("Tap me") {
    print("[MyView] button tapped")
}
```

## TableView/CollectionView

```swift
// UITableViewDataSource
func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    print("[ClassName] numberOfRowsInSection: section=\(section), count=\(items.count)")
    return items.count
}

func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    print("[ClassName] cellForRowAt: indexPath=\(indexPath)")
    let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
    return cell
}

// UITableViewDelegate
func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    print("[ClassName] didSelectRowAt: indexPath=\(indexPath), item=\(items[indexPath.row])")
}
```

## Navigation

```swift
// UIKit
func navigateToDetail(item: Item) {
    print("[ClassName] navigating to: DetailViewController with item=\(item.id)")
    let vc = DetailViewController()
    navigationController?.pushViewController(vc, animated: true)
}

// SwiftUI
NavigationLink(destination: DetailView(item: item)) {
    Text("Go to detail")
}
.simultaneousGesture(TapGesture().onEnded {
    print("[MyView] navigating to: DetailView with item=\(item.id)")
})
```

## Network Requests (URLSession)

```swift
func makeRequest(url: URL) async throws -> Data {
    print("[Network] REQUEST: \(url)")

    let (data, response) = try await URLSession.shared.data(from: url)

    if let httpResponse = response as? HTTPURLResponse {
        print("[Network] RESPONSE: status=\(httpResponse.statusCode)")
    }
    print("[Network] RESPONSE: bytes=\(data.count)")

    return data
}
```

## UserDefaults

```swift
func savePreference(key: String, value: String) {
    print("[Prefs] saving: key=\(key), value=\(value)")
    UserDefaults.standard.set(value, forKey: key)
}

func getPreference(key: String) -> String? {
    let value = UserDefaults.standard.string(forKey: key)
    print("[Prefs] getting: key=\(key), value=\(value ?? "nil")")
    return value
}
```

## os_log (Production-Safe Logging)

```swift
import os.log

// Create a logger
let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ClassName")

// Usage
logger.debug("methodName: variable=\(variable)")
logger.info("methodName: important event")
logger.warning("methodName: unexpected condition")
logger.error("methodName: error occurred - \(error.localizedDescription)")

// With privacy for sensitive data
logger.info("user logged in: userId=\(userId, privacy: .private)")
```

## Conditional Branches

```swift
func processItem(_ item: Item) {
    switch item.status {
    case .valid:
        print("[ClassName] processItem: branch=VALID item=\(item.id)")
        // valid path
    case .pending:
        print("[ClassName] processItem: branch=PENDING item=\(item.id)")
        // pending path
    case .invalid:
        print("[ClassName] processItem: branch=INVALID item=\(item.id)")
        // invalid path
    }
}

// Guard statement
func processOptional(_ value: String?) {
    guard let unwrapped = value else {
        print("[ClassName] processOptional: branch=NIL, early return")
        return
    }
    print("[ClassName] processOptional: branch=VALUE, processing \(unwrapped)")
}
```

## Loop Iterations

```swift
for (index, item) in items.enumerated() {
    print("[ClassName] processing: iteration=\(index + 1)/\(items.count) item=\(item.id)")
}

// ForEach in SwiftUI
ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
    let _ = print("[MyView] rendering: \(index + 1)/\(items.count)")
    ItemRow(item: item)
}
```

## Performance Timing

```swift
let startTime = CFAbsoluteTimeGetCurrent()
// ... operation
let duration = CFAbsoluteTimeGetCurrent() - startTime
print("[ClassName] operation took: \(duration * 1000)ms")

// Using signpost for Instruments
import os.signpost

let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "Performance")
let signpostID = OSSignpostID(log: log)

os_signpost(.begin, log: log, name: "Operation", signpostID: signpostID)
// ... operation
os_signpost(.end, log: log, name: "Operation", signpostID: signpostID)
```

## Notes

- `print()` is removed in release builds when using `-D SWIFT_DISABLE_PRINT`
- Use `os.log` for production logging with privacy controls
- Use `#file`, `#function`, `#line` for automatic context:
  ```swift
  print("[\(#file):\(#line)] \(#function)")
  ```
- Consider using `dump()` for complex object inspection
