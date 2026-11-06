+++
title = "SwiftUI: Cheatsheet"
weight = 1
[extra]
date = "2026-11-06"
author = "Arif Driessen"
+++

A growing collection of reference material I've picked up while learning SwiftUI
and iOS development.

This isn't a step-by-step tutorial or a comprehensive guide. It's more of a
personal reference; things I found useful to know, documented here for fast
reference.

## SwiftUI fundamentals

### Views

SwiftUI is a **declarative UI framework**. Instead of manually creating and
updating UI elements, you describe what the UI should look like for a given
state.

A view is typically a `struct` conforming to the `View` protocol:

```swift
struct ContentView: View {
    var body: some View {
        Text("Hello, world!")
    }
}
```

- `body` describes the view's content.
- `some View` is an opaque return type: the concrete type is determined by the
  implementation.
- Views are lightweight value types that SwiftUI can recreate frequently.
- SwiftUI evaluates `body` as needed when dependencies change. This doesn't
  necessarily mean the underlying UI is recreated.

### View composition

Complex interfaces are built by composing smaller views.

```swift
struct ProfileView: View {
    var body: some View {
        VStack(alignment: .leading) {
            Text("Arif")
                .font(.headline)

            Text("iOS Developer")
                .foregroundStyle(.secondary)
        }
    }
}
```

The `body` property uses `@ViewBuilder`, which allows multiple view expressions
and conditional content.

```swift
@ViewBuilder
var status: some View {
    if isLoading {
        ProgressView()
    } else {
        Text("Ready")
    }
}
```

**Gotcha:** `some View` doesn't mean that a function can return arbitrary
unrelated view types. `@ViewBuilder` handles conditional branches by
constructing a concrete composite view type.

### View identity

SwiftUI uses **view identity** to associate persistent state (`@State`) and
lifetime with views across updates.

- **Structural identity:** inferred from a view's type and position in the
  hierarchy.
- **Explicit identity:** supplied using stable identifiers (`ForEach`, `.id()`).
- Same identity → SwiftUI can preserve view-local state.
- Changed identity → SwiftUI can discard and reinitialize view-local state.

```swift
// Structural identity: independent state
VStack {
    CounterView() // A
    CounterView() // B
}
```

For dynamic collections, `ForEach` uses explicit identifiers to track elements
across insertions, deletions, and reordering.

```swift
// Requires `Item: Identifiable`
ForEach(items) { item in
    ItemRow(item: item)
}

// Alternative: explicit `Hashable` ID
ForEach(items, id: \.id) { item in
    ItemRow(item: item)
}
```

Use `.id()` to explicitly control a view's identity:

```swift
CounterView()
    .id(selectedUser.id) // Resets local state when ID changes
```

## State & data flow

| Mechanism      | Purpose                                                                                                |
| -------------- | ------------------------------------------------------------------------------------------------------ |
| `@State`       | Stores mutable data owned by a view, preserving it across view updates                                 |
| `@Binding`     | Lets a child view read and modify data owned by its parent                                             |
| `@Observable`  | Tracks changes to a model's properties (typicallly `class`es) so views using them update automatically |
| `@Bindable`    | Lets UI controls directly read and modify properties of an `@Observable` model                         |
| `@Environment` | Gives views access to shared values and dependencies without passing them through every parent         |

### `@State`

A view owns and modifies its own state.

```swift
struct CounterView: View {
    @State private var count = 0

    var body: some View {
        Button("Count: \(count)") {
            count += 1
        }
    }
}
```

- SwiftUI manages the storage for the state.
- The value persists across body reevaluations while the view retains its
  identity.
- Changes invalidate the relevant view dependencies.
- Prefer `private` since state should generally be managed by its owning view.

### `@Binding`

A child view modifies state owned by its parent.

```swift
struct ParentView: View {
    @State private var isEnabled = false

    var body: some View {
        ChildView(isEnabled: $isEnabled)
    }
}

struct ChildView: View {
    @Binding var isEnabled: Bool

    var body: some View {
        Toggle("Enabled", isEnabled: $isEnabled)
    }
}
```

- isEnabled reads or writes the underlying value.
- $isEnabled accesses its binding.
- Mutations propagate back to the original source of truth.
- Bindings are commonly used with controls like `Toggle`, `TextField`, and
  `Slider`.

### `@Observable`

A model's properties are tracked automatically, so views update when the
properties they read change.

```swift
@Observable
class Counter {
    var count = 0
}

struct CounterView: View {
    @State private var counter = Counter()

    var body: some View {
        Button("Count: \(counter.count)") {
            counter.count += 1
        }
    }
}
```

- Requires iOS 17+.
- Works with classes, and also supports observable structs.
- Supports fine-grained property observation.
- Use `@ObservationIgnored` to exclude stored properties from observation.

### `@Bindable`

A view creates bindings to properties of an observable model it receives.

```swift
@Observable
class User {
    var name = ""
}

struct UserEditor: View {
    @Bindable var user: User

    var body: some View {
        TextField("Name", text: $user.name)
    }
}
```

### `@Environment`

A dependency is injected into the view hierarchy and accessed by descendant
views without explicitly passing it through each view.

```swift
@Observable
class Settings {
    var username = "Arif"
}

// Inject at a parent
ContentView()
    .environment(Settings())

// Access in a descendant
struct ProfileView: View {
    @Environment(Settings.self) private var settings

    var body: some View {
        Text(settings.username)
    }
}
```

## Persistence

### `@AppStorage`

Use `@AppStorage` for simple values that should survive app restarts, such as
user preferences:

```swift
@AppStorage("showNotifications")
private var showNotifications = true
```

It uses Foundation's `UserDefaults` under the hood, while automatically updating
SwiftUI views when the stored value changes.

Unlike `@State`, the value persists across launches.

`@AppStoragae` couples the UI and storage layers. If separation of concerns is
needed, have the backing model write to `UserDefauts` directly.

### `@SceneStorage`

Use `@SceneStorage` for small amounts of state associated with a particular
window or scene:

```swift
@SceneStorage("selectedTab")
private var selectedTab = 0
```

SwiftUI may restore this value when the scene is recreated, making it useful for
things like selected tabs or navigation state.

Unlike `@AppStorage`, it is not intended for durable persistence. Restoration is
not guaranteed.

### SwiftData

For more complex persistent application data, Apple provides SwiftData,
essentially an ORM over an SQLite database that integrates with SwiftUI.

Define the schema using `@Model`:

```swift
import SwiftData

@Model
class Note {
    var title: String

    init(title: String) {
        self.title = title
    }
}
```

Configure persistence at the app level:

```swift
@main
struct NotesApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: Note.self)
    }
}
```

#### Reading data

Use `@Query` to fetch persisted models and automatically update SwiftUI when
query results change:

```swift
@Query(sort: \Note.title)
private var notes: [Note]
```

Queries can also be filtered using `#Predicate`.

#### Modifying data

Access the model context through the environment:

```swift
@Environment(\.modelContext)
private var context
```

Insert, update, and delete models:

```swift
// Insert
let note = Note(title: "Hello")
context.insert(note)

// Update
note.title = "Updated"

// Delete
context.delete(note)

// Explicitly save
try context.save()
```

SwiftData tracks changes to models and supports automatic saving, so explicit
saves aren't always necessary.

#### Separating persistence from UI

For simple applications, views can interact with `ModelContext` directly. As
applications grow, it's useful to separate domain operations from presentation
logic.

A practical approach is:

- **Views read data** using `@Query`, benefiting from automatic observation.
- **Stores handle domain mutations**, coordinating persistence, business rules,
  and associated side effects.
- **Views manage UI-specific state** using `@State`, `@AppStorage`, or
  `@SceneStorage` as appropriate.

For example, deleting a downloaded podcast may involve cancelling a relevant
task, removing database records, and deleting files. A `LibraryStore` can
coordinate these operations rather than leaving that responsibility to a view.

**Warning:** `@Query` returns mutable model objects. If your architecture
delegates domain mutations to stores, treat queried models as read-only in
views.

### FileManager

### `FileManager`

Use Foundation's `FileManager` to persist data directly in the file system.

For example, to save a `Data` value to the app's Documents directory:

```swift
import Foundation

let data = Data("Hello, world!".utf8)

let fileURL = URL.documentsDirectory
    .appendingPathComponent("hello.txt")

// Save:
try data.write(to: fileURL, options: .atomic)

// Load:
let savedData = try Data(contentsOf: fileURL)

// Convert back to a String:
let text = String(decoding: savedData, as: UTF8.self)
```

The Documents directory is part of the app's sandbox. Files stored there survive
app restarts and are normally included in device backups.

Other commonly used directories include:

- **Documents:** User-generated files and persistent application data.
- **Application Support:** Persistent files used internally by the app.
- **Caches:** Re-creatable data that the system may delete when storage is
  needed.
- **Temporary:** Short-lived files that the system may remove.

For internal application data that users do not need to access directly,
Application Support is generally more appropriate than Documents.

`FileManager` does not automatically update SwiftUI views when files change. You
must load the data into state, such as `@State` or an `@Observable` model, and
update that state when the underlying files change.

It is particularly useful for storing large files or binary data that would not
fit naturally into `UserDefaults` or a database.

## Layout

### Stacks

Stacks arrange views along an axis. `VStack`, `HStack`, `ZStack`.

Use `LazyVStack` and `LazyHStack` for lazy creation of content, typically inside
a `ScrollView`.

For collections, `List` and `Grid`/`LazyVGrid`/`LazyHGrid` provide additional
layout options.

### Safe areas

SwiftUI normally respects the "safe area", avoiding system UI such as the status
bar, Dynamic Island, and home indicator.

```swift
Color.blue
    .ignoresSafeArea()
```

Use `.ignoresSafeArea()` when content should extend into those regions.

For content that should remain positioned relative to the safe area, use
`.safeAreaInset(...)`:

```swift
ScrollView {
    // Content
}
.safeAreaInset(edge: .bottom) {
    Button("Continue") {}
        .padding()
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
}
```

## Navigation

| Mechanism             | Use case                                          |
| --------------------- | ------------------------------------------------- |
| `NavigationStack`     | Hierarchical push/pop navigation                  |
| `NavigationLink`      | User-initiated navigation to a destination        |
| `NavigationPath`      | Programmatic navigation with heterogeneous values |
| `.sheet`              | Temporary modal content                           |
| `.fullScreenCover`    | Full-screen modal flows                           |
| `.alert`              | Important messages and simple decisions           |
| `.confirmationDialog` | Choosing between actions                          |
| `TabView`             | Switching between top-level sections              |
| `NavigationSplitView` | Sidebar and detail navigation                     |

### NavigationStack

`NavigationStack` manages a stack of views, allowing users to navigate forward
and backward through a hierarchy.

```swift
NavigationStack {
    NavigationLink("View details") {
        DetailView()
    }
    .navigationTitle("Home")
}
```

### Value-based navigation

Instead of specifying a destination view directly, a `NavigationLink` can push a
value onto the navigation stack.

```swift
NavigationStack {
    List(items) { item in
        NavigationLink(value: item) {
            Text(item.name)
        }
    }
    .navigationDestination(for: Item.self) { item in
        ItemDetailView(item: item)
    }
}
```

- The navigation value must conform to `Hashable`.
- `.navigationDestination(for:)` maps a value type to a destination view.
- Different value types can have different destination registrations.
- Value-based navigation is useful when navigation needs to be controlled
  programmatically.

**Mental model:** A navigation stack can be represented as a sequence of values,
with SwiftUI mapping those values to views.

### Programmatic navigation

Bind a `NavigationStack` to a path to control navigation from code.

```swift
enum Route: Hashable {
    case profile
    case settings
}

struct ContentView: View {
    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            Button("Open settings") {
                path.append(.settings)
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .profile:
                    ProfileView()
                case .settings:
                    SettingsView()
                }
            }
        }
    }
}
```

Useful operations:

```swift
path.append(.profile)  // Push
path.removeLast()      // Pop one
path.removeAll()       // Pop to root
```

A typed array such as `[Route]` works well when all destinations can be
represented by one route type.

For heterogeneous navigation values, use `NavigationPath`:

```swift
@State private var path = NavigationPath()
```

`NavigationPath` can hold values of different `Hashable` types.

**Gotcha:** Only call `removeLast()` when the path is nonempty. Otherwise, it
will trap.

### Dismissing a destination

Use the environment's `dismiss` action to return to the previous screen.

```swift
struct DetailView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button("Go back") {
            dismiss()
        }
    }
}
```

`dismiss()` works for several presentation contexts, including:

- Popping a pushed navigation destination.
- Dismissing a sheet.
- Dismissing a full-screen cover.

### Sheets

Sheets present content modally, usually without replacing the underlying
navigation hierarchy.

```swift
struct ContentView: View {
    @State private var showingSettings = false

    var body: some View {
        Button("Settings") {
            showingSettings = true
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
}
```

- The Boolean binding controls whether the sheet is presented.
- Setting the binding to `false` dismisses the sheet.
- Sheets can also be dismissed using `@Environment(\.dismiss)`.
- A sheet can contain its own `NavigationStack`.

For example:

```swift
.sheet(isPresented: $showingSettings) {
    NavigationStack {
        SettingsView()
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showingSettings = false
                    }
                }
            }
    }
}
```

### Item-based sheets

Use `.sheet(item:)` when the presented content is an optional identifiable
value. This avoids keeping a separate Boolean and selected-item variable in sync

```swift
@State private var selectedItem: Item?

var body: some View {
    List(items) { item in
        Button(item.name) {
            selectedItem = item
        }
    }
    .sheet(item: $selectedItem) { item in
        ItemDetailView(item: item)
    }
}
```

- `Item` must conform to `Identifiable`.
- A non-`nil` value presents the sheet.
- Setting the selection to `nil` dismisses it.
- The selected item is passed to the sheet's content closure.

### Full-screen covers

Use `.fullScreenCover(...)` for modal content that occupies the entire screen.

```swift
@State private var showingOnboarding = false

var body: some View {
    Button("Start onboarding") {
        showingOnboarding = true
    }
    .fullScreenCover(isPresented: $showingOnboarding) {
        OnboardingView()
    }
}
```

Like sheets, full-screen covers support both Boolean and item-based
presentation.

Typical use cases include onboarding flows, immersive experiences, and custom
full-screen interfaces.

### Alerts

Use `.alert(...)` to present short messages or request simple user decisions.

```swift
@State private var showingAlert = false

var body: some View {
    Button("Delete") {
        showingAlert = true
    }
    .alert("Delete item?", isPresented: $showingAlert) {
        Button("Delete", role: .destructive) {
            deleteItem()
        }

        Button("Cancel", role: .cancel) {}
    } message: {
        Text("This action cannot be undone.")
    }
}
```

Button roles communicate intent:

- `.cancel` — Cancel the operation.
- `.destructive` — Indicate a destructive operation.

SwiftUI and the system determine the appropriate visual presentation.

### Confirmation dialogs

Use `.confirmationDialog(...)` when the user must choose between several
actions.

```swift
@State private var showingOptions = false

var body: some View {
    Button("More options") {
        showingOptions = true
    }
    .confirmationDialog(
        "Choose an action",
        isPresented: $showingOptions
    ) {
        Button("Share") {
            shareItem()
        }

        Button("Delete", role: .destructive) {
            deleteItem()
        }
    }
}
```

Unlike alerts, confirmation dialogs are designed around choosing an action
rather than displaying an important message.

### TabView

`TabView` provides navigation between top-level sections of an app.

```swift
TabView {
    Tab("Home", systemImage: "house") {
        HomeView()
    }

    Tab("Settings", systemImage: "gear") {
        SettingsView()
    }
}
```

Each tab can contain its own navigation stack:

```swift
TabView {
    Tab("Home", systemImage: "house") {
        NavigationStack {
            HomeView()
        }
    }

    Tab("Settings", systemImage: "gear") {
        NavigationStack {
            SettingsView()
        }
    }
}
```

This allows each section to maintain its own navigation hierarchy.

### NavigationSplitView

`NavigationSplitView` supports multi-column navigation, particularly useful on
iPad and macOS.

```swift
@State private var selectedItem: Item?

var body: some View {
    NavigationSplitView {
        List(items, selection: $selectedItem) { item in
            Text(item.name)
        }
    } detail: {
        if let selectedItem {
            ItemDetailView(item: selectedItem)
        } else {
            ContentUnavailableView(
                "Select an item",
                systemImage: "sidebar.left"
            )
        }
    }
}
```

SwiftUI adapts the layout to the available space, collapsing columns when
necessary.

### Deep linking

Deep linking allows external URLs to navigate to specific content within an app.

Use `.onOpenURL(...)` to handle incoming URLs:

```swift
.onOpenURL { url in
    guard url.scheme == "myapp" else { return }

    if url.host == "settings" {
        path = [.settings]
    }
}
```

For example:

```text
myapp://settings
```

The app must be configured to handle the URL scheme (or associated universal
links).

## Concurrency

SwiftUI provides the `.task` modifier for running asynchronous work associated
with a view's lifecycle:

```swift
struct ContentView: View {
    @State private var users: [User] = []

    var body: some View {
        List(users) { user in
            Text(user.name)
        }
        .task {
            users = await fetchUsers()
        }
    }
}
```

Unlike spawning an unstructured task with `Task {}`, SwiftUI manages the
lifetime of the task. It starts when the view appears and automatically requests
cancellation when the view disappears.

Cancellation is cooperative, however, so the asynchronous operation must respect
cancellation for it to stop early.

SwiftUI also provides `.task(id:)`, which cancels the previous task and starts a
new one when the given value changes:

```swift
@State private var query = ""
@State private var results: [Result] = []

var body: some View {
    VStack {
        TextField("Search", text: $query)

        List(results) { result in
            Text(result.name)
        }
    }
    .task(id: query) {
        results = await search(query)
    }
}
```

SwiftUI's `View` protocol is isolated to `@MainActor`, allowing view code to
access UI-related state safely. The `.task` modifier inherits this isolation,
although asynchronous operations can suspend without blocking the main thread.

### When to use `Task {}`

Unlike `.task {}`, which runs when a view appears, `Task {}` is useful for
starting asynchronous work in response to an event, such as a button press:

```swift id="t5mb91"
Button("Save") {
    Task {
        await saveChanges()
    }
}
```

This is necessary because SwiftUI's `Button` action takes a synchronous closure,
so you cannot directly use `await` inside it.

Unlike `.task {}`, the spawned task is not automatically cancelled when the view
disappears. If cancellation is needed, you must manage it yourself.

As a rule of thumb, use `.task {}` for work tied to a view's lifecycle, and
`Task {}` for work triggered by user interactions.

## App Extensions

Live Activity, Control Center
