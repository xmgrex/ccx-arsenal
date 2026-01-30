# Kotlin/Android Log Patterns

Copy-paste-ready logging patterns for Android/Kotlin debugging.

## Basic Logging

```kotlin
import android.util.Log

private const val TAG = "ClassName"

// Log levels
Log.v(TAG, "Verbose message")  // Most detailed
Log.d(TAG, "Debug message")    // Debug info
Log.i(TAG, "Info message")     // General info
Log.w(TAG, "Warning message")  // Warnings
Log.e(TAG, "Error message")    // Errors

// With variable values
Log.d(TAG, "[ClassName] methodName: variable=$variable")
Log.d(TAG, "[ClassName] condition: isValid=$isValid, value=$value")

// Method entry/exit
Log.d(TAG, "[ClassName] methodName: ENTER params=($param1, $param2)")
Log.d(TAG, "[ClassName] methodName: EXIT result=$result")
```

## Activity Lifecycle

```kotlin
override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    Log.d(TAG, "[${this::class.simpleName}] onCreate: savedInstanceState=${savedInstanceState != null}")
}

override fun onStart() {
    super.onStart()
    Log.d(TAG, "[${this::class.simpleName}] onStart")
}

override fun onResume() {
    super.onResume()
    Log.d(TAG, "[${this::class.simpleName}] onResume")
}

override fun onPause() {
    Log.d(TAG, "[${this::class.simpleName}] onPause")
    super.onPause()
}

override fun onStop() {
    Log.d(TAG, "[${this::class.simpleName}] onStop")
    super.onStop()
}

override fun onDestroy() {
    Log.d(TAG, "[${this::class.simpleName}] onDestroy")
    super.onDestroy()
}

override fun onSaveInstanceState(outState: Bundle) {
    Log.d(TAG, "[${this::class.simpleName}] onSaveInstanceState")
    super.onSaveInstanceState(outState)
}
```

## Fragment Lifecycle

```kotlin
override fun onAttach(context: Context) {
    super.onAttach(context)
    Log.d(TAG, "[${this::class.simpleName}] onAttach")
}

override fun onCreateView(
    inflater: LayoutInflater,
    container: ViewGroup?,
    savedInstanceState: Bundle?
): View? {
    Log.d(TAG, "[${this::class.simpleName}] onCreateView")
    return super.onCreateView(inflater, container, savedInstanceState)
}

override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
    super.onViewCreated(view, savedInstanceState)
    Log.d(TAG, "[${this::class.simpleName}] onViewCreated")
}

override fun onDestroyView() {
    Log.d(TAG, "[${this::class.simpleName}] onDestroyView")
    super.onDestroyView()
}

override fun onDetach() {
    Log.d(TAG, "[${this::class.simpleName}] onDetach")
    super.onDetach()
}
```

## Coroutine Operations

```kotlin
suspend fun fetchData() {
    Log.d(TAG, "[ClassName] fetchData: START on ${Thread.currentThread().name}")
    try {
        val result = withContext(Dispatchers.IO) {
            Log.d(TAG, "[ClassName] fetchData: IO operation on ${Thread.currentThread().name}")
            api.getData()
        }
        Log.d(TAG, "[ClassName] fetchData: SUCCESS count=${result.size}")
    } catch (e: Exception) {
        Log.e(TAG, "[ClassName] fetchData: ERROR", e)
    }
}

// With scope tracking
viewModelScope.launch {
    Log.d(TAG, "[ClassName] coroutine: LAUNCHED")
    try {
        // operation
    } finally {
        Log.d(TAG, "[ClassName] coroutine: COMPLETED")
    }
}
```

## Flow Handling

```kotlin
viewModelScope.launch {
    dataFlow
        .onStart { Log.d(TAG, "[ClassName] flow: STARTED") }
        .onEach { data -> Log.d(TAG, "[ClassName] flow: EMIT data=$data") }
        .onCompletion { cause ->
            Log.d(TAG, "[ClassName] flow: COMPLETED cause=$cause")
        }
        .catch { e -> Log.e(TAG, "[ClassName] flow: ERROR", e) }
        .collect { data ->
            Log.d(TAG, "[ClassName] flow: COLLECTED data=$data")
        }
}
```

## ViewModel

```kotlin
class MyViewModel : ViewModel() {
    init {
        Log.d(TAG, "[MyViewModel] init")
    }

    override fun onCleared() {
        Log.d(TAG, "[MyViewModel] onCleared")
        super.onCleared()
    }

    fun updateState(newValue: String) {
        Log.d(TAG, "[MyViewModel] updateState: from=${_state.value} to=$newValue")
        _state.value = newValue
    }
}
```

## LiveData

```kotlin
// Observing
viewModel.data.observe(viewLifecycleOwner) { value ->
    Log.d(TAG, "[ClassName] data observed: value=$value")
}

// Setting value
fun updateLiveData(newValue: String) {
    Log.d(TAG, "[ClassName] updateLiveData: from=${_liveData.value} to=$newValue")
    _liveData.value = newValue
}
```

## Click Handlers

```kotlin
button.setOnClickListener {
    Log.d(TAG, "[ClassName] button clicked")
    // handler code
}

// With view info
view.setOnClickListener { v ->
    Log.d(TAG, "[ClassName] clicked: viewId=${v.id}, tag=${v.tag}")
}
```

## RecyclerView Adapter

```kotlin
override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
    Log.d(TAG, "[Adapter] onCreateViewHolder: viewType=$viewType")
    return ViewHolder(/* ... */)
}

override fun onBindViewHolder(holder: ViewHolder, position: Int) {
    Log.d(TAG, "[Adapter] onBindViewHolder: position=$position, item=${items[position]}")
    holder.bind(items[position])
}

override fun getItemCount(): Int {
    Log.d(TAG, "[Adapter] getItemCount: count=${items.size}")
    return items.size
}
```

## Navigation

```kotlin
// Navigate
Log.d(TAG, "[ClassName] navigating to: destination")
findNavController().navigate(R.id.action_to_destination)

// With arguments
Log.d(TAG, "[ClassName] navigating to: destination with args=$args")
findNavController().navigate(
    R.id.action_to_destination,
    bundleOf("key" to value)
)

// Back
Log.d(TAG, "[ClassName] navigating back")
findNavController().popBackStack()
```

## API Calls (Retrofit)

```kotlin
suspend fun makeApiCall(request: Request): Response {
    Log.d(TAG, "[ApiClient] REQUEST: ${request.url}")
    Log.d(TAG, "[ApiClient] BODY: $request")

    val response = api.call(request)

    Log.d(TAG, "[ApiClient] RESPONSE: code=${response.code()}")
    Log.d(TAG, "[ApiClient] RESPONSE BODY: ${response.body()}")

    return response
}
```

## SharedPreferences

```kotlin
fun savePreference(key: String, value: String) {
    Log.d(TAG, "[Prefs] saving: key=$key, value=$value")
    prefs.edit().putString(key, value).apply()
}

fun getPreference(key: String): String? {
    val value = prefs.getString(key, null)
    Log.d(TAG, "[Prefs] getting: key=$key, value=$value")
    return value
}
```

## Conditional Branches

```kotlin
fun processItem(item: Item) {
    when {
        item.isValid -> {
            Log.d(TAG, "[ClassName] processItem: branch=VALID item=${item.id}")
            // valid path
        }
        item.isPending -> {
            Log.d(TAG, "[ClassName] processItem: branch=PENDING item=${item.id}")
            // pending path
        }
        else -> {
            Log.d(TAG, "[ClassName] processItem: branch=INVALID item=${item.id}")
            // invalid path
        }
    }
}
```

## Performance Timing

```kotlin
val startTime = System.currentTimeMillis()
// ... operation
val duration = System.currentTimeMillis() - startTime
Log.d(TAG, "[ClassName] operation took: ${duration}ms")

// Or using measureTimeMillis
val duration = measureTimeMillis {
    // operation
}
Log.d(TAG, "[ClassName] operation took: ${duration}ms")
```

## Timber (Alternative Logging Library)

```kotlin
// Setup in Application
class MyApp : Application() {
    override fun onCreate() {
        super.onCreate()
        if (BuildConfig.DEBUG) {
            Timber.plant(Timber.DebugTree())
        }
    }
}

// Usage (TAG is automatic)
Timber.d("[ClassName] methodName: variable=$variable")
Timber.e(exception, "[ClassName] error occurred")
```

## Notes

- Always use a TAG constant for filtering in Logcat
- Use `Log.isLoggable(TAG, Log.DEBUG)` for conditional logging
- Consider Timber for automatic tagging and release builds
- Be careful not to log sensitive data (passwords, tokens)
