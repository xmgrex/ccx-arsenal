# JavaScript/TypeScript Log Patterns

Copy-paste-ready logging patterns for JavaScript/TypeScript debugging.

## Basic Console Logging

```javascript
// Simple value logging
console.log('[ClassName] methodName:', variable);

// Multiple values (object shorthand)
console.log('[ClassName] methodName:', { a, b, c });

// Conditional logging
console.log('[ClassName] condition check:', { isValid, value });

// Method entry/exit
console.log('[ClassName] methodName: ENTER', { param1, param2 });
console.log('[ClassName] methodName: EXIT', { result });

// With string interpolation
console.log(`[ClassName] methodName: variable=${variable}`);
```

## Console Log Levels

```javascript
console.log('General information');     // Standard log
console.info('Informational message');  // Info level
console.warn('Warning message');        // Warning level
console.error('Error message');         // Error level
console.debug('Debug details');         // Debug level (may be hidden by default)
```

## Grouped Logging

```javascript
console.group('[ClassName] methodName');
console.log('input:', params);
console.log('processing...');
console.log('output:', result);
console.groupEnd();

// Collapsed by default
console.groupCollapsed('[ClassName] details');
console.log('detailed info 1');
console.log('detailed info 2');
console.groupEnd();
```

## Async Operations

```javascript
async function fetchData() {
  console.log('[ClassName] fetchData: START');
  try {
    const result = await api.getData();
    console.log('[ClassName] fetchData: SUCCESS', { count: result.length });
    return result;
  } catch (error) {
    console.error('[ClassName] fetchData: ERROR', error);
    throw error;
  }
}

// Promise chain
fetchData()
  .then(result => {
    console.log('[ClassName] then: received', { result });
  })
  .catch(error => {
    console.error('[ClassName] catch: error', { error });
  })
  .finally(() => {
    console.log('[ClassName] finally: cleanup');
  });
```

## React Component Lifecycle

```javascript
// Functional component with hooks
function MyComponent({ prop }) {
  console.log('[MyComponent] render:', { prop });

  useEffect(() => {
    console.log('[MyComponent] mounted');
    return () => {
      console.log('[MyComponent] unmounted');
    };
  }, []);

  useEffect(() => {
    console.log('[MyComponent] prop changed:', { prop });
  }, [prop]);

  return <div>...</div>;
}

// Class component
class MyComponent extends React.Component {
  componentDidMount() {
    console.log('[MyComponent] componentDidMount');
  }

  componentDidUpdate(prevProps, prevState) {
    console.log('[MyComponent] componentDidUpdate:', {
      prevProps,
      currentProps: this.props,
      prevState,
      currentState: this.state,
    });
  }

  componentWillUnmount() {
    console.log('[MyComponent] componentWillUnmount');
  }

  render() {
    console.log('[MyComponent] render');
    return <div>...</div>;
  }
}
```

## State Management

### useState

```javascript
const [state, setState] = useState(initialValue);

const updateState = (newValue) => {
  console.log('[Component] updateState: from=', state, 'to=', newValue);
  setState(newValue);
};
```

### useReducer

```javascript
const loggerReducer = (reducer) => (state, action) => {
  console.group(`[Reducer] ${action.type}`);
  console.log('Previous State:', state);
  console.log('Action:', action);
  const nextState = reducer(state, action);
  console.log('Next State:', nextState);
  console.groupEnd();
  return nextState;
};

const [state, dispatch] = useReducer(loggerReducer(reducer), initialState);
```

### Redux

```javascript
// Middleware logger
const loggerMiddleware = (store) => (next) => (action) => {
  console.group(`[Redux] ${action.type}`);
  console.log('dispatching:', action);
  console.log('prev state:', store.getState());
  const result = next(action);
  console.log('next state:', store.getState());
  console.groupEnd();
  return result;
};
```

### Zustand

```javascript
const useStore = create((set, get) => ({
  value: 0,
  setValue: (newValue) => {
    console.log('[Store] setValue:', { from: get().value, to: newValue });
    set({ value: newValue });
  },
}));
```

## Event Handlers

```javascript
// Click handler
const handleClick = (event) => {
  console.log('[Component] click:', {
    target: event.target,
    position: { x: event.clientX, y: event.clientY },
  });
};

// Form submit
const handleSubmit = (event) => {
  event.preventDefault();
  const formData = new FormData(event.target);
  console.log('[Form] submit:', Object.fromEntries(formData));
};

// Input change
const handleChange = (event) => {
  console.log('[Input] change:', {
    name: event.target.name,
    value: event.target.value,
  });
};
```

## API Requests (fetch)

```javascript
async function apiCall(url, options = {}) {
  console.log('[API] REQUEST:', { url, options });

  const response = await fetch(url, options);
  const data = await response.json();

  console.log('[API] RESPONSE:', {
    status: response.status,
    ok: response.ok,
    data,
  });

  return data;
}
```

## API Requests (Axios)

```javascript
// Interceptors
axios.interceptors.request.use((config) => {
  console.log('[Axios] REQUEST:', {
    method: config.method,
    url: config.url,
    data: config.data,
  });
  return config;
});

axios.interceptors.response.use(
  (response) => {
    console.log('[Axios] RESPONSE:', {
      status: response.status,
      data: response.data,
    });
    return response;
  },
  (error) => {
    console.error('[Axios] ERROR:', {
      status: error.response?.status,
      data: error.response?.data,
    });
    return Promise.reject(error);
  }
);
```

## Router (React Router)

```javascript
// Custom hook for route logging
function useRouteLogger() {
  const location = useLocation();

  useEffect(() => {
    console.log('[Router] navigation:', {
      pathname: location.pathname,
      search: location.search,
      state: location.state,
    });
  }, [location]);
}

// Navigation
const navigate = useNavigate();
const goToDetail = (id) => {
  console.log('[Component] navigating to:', `/detail/${id}`);
  navigate(`/detail/${id}`);
};
```

## LocalStorage/SessionStorage

```javascript
const storage = {
  set(key, value) {
    console.log('[Storage] set:', { key, value });
    localStorage.setItem(key, JSON.stringify(value));
  },
  get(key) {
    const value = JSON.parse(localStorage.getItem(key));
    console.log('[Storage] get:', { key, value });
    return value;
  },
  remove(key) {
    console.log('[Storage] remove:', { key });
    localStorage.removeItem(key);
  },
};
```

## Conditional Branches

```javascript
function processItem(item) {
  if (item.isValid) {
    console.log('[ClassName] processItem: branch=VALID', { itemId: item.id });
    // valid path
  } else if (item.isPending) {
    console.log('[ClassName] processItem: branch=PENDING', { itemId: item.id });
    // pending path
  } else {
    console.log('[ClassName] processItem: branch=INVALID', { itemId: item.id });
    // invalid path
  }
}

// Switch statement
switch (status) {
  case 'loading':
    console.log('[ClassName] status: branch=LOADING');
    break;
  case 'success':
    console.log('[ClassName] status: branch=SUCCESS');
    break;
  case 'error':
    console.log('[ClassName] status: branch=ERROR');
    break;
  default:
    console.log('[ClassName] status: branch=UNKNOWN', { status });
}
```

## Loop Iterations

```javascript
items.forEach((item, index) => {
  console.log(`[ClassName] processing: ${index + 1}/${items.length}`, { item });
});

// For...of with index
for (const [index, item] of items.entries()) {
  console.log(`[ClassName] iteration: ${index + 1}/${items.length}`, { item });
}

// Array methods
const results = items
  .filter((item) => {
    const pass = item.isValid;
    console.log('[ClassName] filter:', { itemId: item.id, pass });
    return pass;
  })
  .map((item) => {
    console.log('[ClassName] map:', { itemId: item.id });
    return transform(item);
  });
```

## Performance Timing

```javascript
// console.time
console.time('[ClassName] operationName');
// ... operation
console.timeEnd('[ClassName] operationName');

// Manual timing
const start = performance.now();
// ... operation
const duration = performance.now() - start;
console.log(`[ClassName] operation took: ${duration.toFixed(2)}ms`);

// Performance marks
performance.mark('start-operation');
// ... operation
performance.mark('end-operation');
performance.measure('operation', 'start-operation', 'end-operation');
const measure = performance.getEntriesByName('operation')[0];
console.log(`[ClassName] operation took: ${measure.duration.toFixed(2)}ms`);
```

## Table Output

```javascript
// Display array of objects as table
console.table(items);

// With specific columns
console.table(items, ['id', 'name', 'status']);
```

## Object Inspection

```javascript
// Expandable tree view
console.dir(complexObject);

// With depth
console.dir(complexObject, { depth: null }); // Node.js
```

## Notes

- Use browser DevTools filters to show/hide specific log levels
- `console.log` is synchronous and can impact performance in tight loops
- Consider using a logging library (winston, pino, loglevel) for production
- Use conditional logging for production:
  ```javascript
  const DEBUG = process.env.NODE_ENV !== 'production';
  DEBUG && console.log('debug info');
  ```
- Chrome DevTools supports CSS styling in console:
  ```javascript
  console.log('%c[Important]%c message', 'color: red; font-weight: bold', '');
  ```
