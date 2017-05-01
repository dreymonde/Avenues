# Avenues

[![Swift][swift-badge]][swift-url]
[![Platform][platform-badge]][platform-url]

**Avenues** is a new approach to the old and famous problem – asynchronous loading of a resource, the most common example of which is populating an image from a remote location. The main advantage of **Avenues** is that it makes the whole process much more transparent and controllable.

In contrast to other libraries which solves the same problem, **Avenues** doesn't sacrifice "right" for "neat". Instead, **Avenues** is highly customizable, unopiniated about your business-logic, and very transparent. You can use it as a simple out-of-the-box solution, or you can get your hands dirty and customize it to fully fit your needs.

After all, **Avenues** is a really small, component-based project, so if you need even more controllable solution – build one yourself! Our source code is there to help.

## Features
- Asynchronous loading/processing of items.
- Generic approach – **Avenues** can be used not just for images.
- `NSCache`-based memory caching.
- Designed to work with `UITableView`/`UICollectionView` in an elegant, idiomatic way.
- Highly customizable – you can provide your own storage and fetching mechanisms.
- Not firing multiple requests for the same item.
- Clear and transparent design with *no magic at all*.

## Usage
### The simplest

```swift
import UIKit
import Avenues

struct Entry {
    let text: String
    let imageURL: URL?
}

class ExampleTableViewController: UITableViewController {
    
    var entries: [Entry] = []
    let avenue = UIImageAvenue()

    override func viewDidLoad() {
        super.viewDidLoad()
        avenue.onStateChange = { [weak self] indexPath in
            if let cell = self?.tableView.cellForRow(at: indexPath) {
                self?.configureCell(cell, forRowAt: indexPath)
            }
        }
        avenue.onError = { error, indexPath in
            print("Failed to download image at \(indexPath). Error: \(error)")
        }
    }
    
    deinit {
        avenue.cancelAll()
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return entries.count
    }
    
    func configureCell(_ cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let entry = entries[indexPath.row]
        if let imageURL = entry.imageURL {
            avenue.prepareItem(for: imageURL, storingTo: indexPath)
        }
        cell.textLabel?.text = entry.text
        cell.imageView?.image = avenue.item(at: indexPath)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "reuseIdentifier", for: indexPath)
        configureCell(cell, forRowAt: indexPath)
        return cell
    }
    
}

```

`UIImageAvenue` is a helper function that creates a basic instance of type `Avenue<IndexPath, URL, UIImage>` with `NSCache`-based storage and `URLSession`-based downloader. You can achieve the same behavior using this code:

```swift
let cache = NSCache<NSIndexPath, UIImage>()
let storage: Storage<IndexPath, UIImage> = NSCacheStorage(cache: cache)
    .mapKey({ indexPath in indexPath as NSIndexPath })
let session = URLSession(configuration: .default)
let downloader: Processor<URL, UIImage> = URLSessionProcessor(session: session)
    .mapImage()
let avenue = Avenue(storage: storage,
                    processor: downloader,
                    callbackMode: .mainQueue)
```

**Avenues** provides `URLSessionProcessor`, `NSCacheStorage` and `Storage.dictionaryBased` out of the box.

### Writing your own processor
**Avenues** is not limited for networking. Any situation that requires asynchronous job will benefit from it. **Avenues** provides basic `URLSessionProcessor`, but you can write your own – for networking or for anything else. Let's imagine that we want to write a processor that does some heavy background job and then produces a `UIImage` object. Here is one way to do it:

```swift
final class ChartDrawer : ProcessorProtocol {
    
    typealias Key = ChartData
    typealias Value = UIImage
    
    private enum State {
        case drawing
        case done
    }
    
    private var jobs: [ChartData : State] = [:]
    private let jobsSyncQueue = DispatchQueue(label: "JobsSyncQueue")
    
    private func produceImage(from data: ChartData) -> UIImage {
        /// ... some heavy job
        return UIImage()
    }
    
    func start(key data: ChartData, completion: @escaping (ProcessorResult<UIImage>) -> ()) {
        jobsSyncQueue.sync {
            jobs[data] = .drawing
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let image = self.produceImage(from: data)
            self.jobsSyncQueue.sync {
                self.jobs[data] = .done
            }
            completion(.success(image))
        }
    }
    
    func processingState(key: ChartData) -> ProcessingState {
        return jobsSyncQueue.sync {
            if let job = jobs[key] {
                switch job {
                case .drawing:
                    return .running
                case .done:
                    return .completed
                }
            }
            return .none
        }
    }
    
    func cancel(key: ChartData) {
        // not supported
    }
    
    func cancelAll() {
        // not supported
    }
    
}
```

And here's how to create our regular `Avenue<IndexPath, UIImage>` from it:

```swift
let storage = Storage<IndexPath, UIImage>.dictionaryBased()
let drawer = Processor(ChartDrawer())
let avenue = Avenue(storage: storage,
                    processor: drawer,
                    callbackMode: .mainQueue)
```

You may have noticed that there are a lot of tricky state handling going on in `ChartDrawer`, like having this `jobs` dictionary (which should be thread-safe). If you don't want to deal with all that stuff, you can simply conform to `AutoProcessorProtocol` instead of `ProcessorProtocol`:

```swift
final class AutoChartDrawer : AutoProcessorProtocol {
    
    typealias Key = ChartData
    typealias Value = UIImage
    
    func produceImage(from data: ChartData) -> UIImage {
        /// ... some heavy job
        return UIImage()
    }
    
    func start(key data: ChartData, completion: @escaping (ProcessorResult<UIImage>) -> ()) {
        DispatchQueue.global(qos: .userInitiated).async {
            let image = self.produceImage(from: data)
            completion(.success(image))
        }
    }
    
    func cancel(key: ChartData) -> Bool {
        // not supported
        return false
    }
    
    func cancelAll() {
        // not supported
    }
    
}
```

And then create your avenue like this:

```swift
let storage = Storage<IndexPath, UIImage>.dictionaryBased()
let drawer = AutoChartDrawer().processor()
let avenue = Avenue(storage: storage,
                    processor: drawer,
                    callbackMode: .mainQueue)

```

`AutoProcessor` will handle all that state management for you.

### Using Avenues with `UITableViewDataSourcePrefetching`

```swift
tableView.prefetchDataSource = self
```

Then:

```swift
extension ExampleTableViewController : UITableViewDataSourcePrefetching {
    
    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        for indexPath in indexPaths {
            if let imageURL = entries[indexPath.row].imageURL {
                avenue.prepareItem(for: imageURL, storingTo: indexPath)
            }
        }
    }
    
    func tableView(_ tableView: UITableView, cancelPrefetchingForRowsAt indexPaths: [IndexPath]) {
        for indexPath in indexPaths {
            if let imageURL = entries[indexPath.row].imageURL {
                avenue.cancelProcessing(of: imageURL)
            }
        }
    }
    
}
```

Works the same way with `UICollectionView`.

### Caching fetched items on disk
**Avenues** doesn't support disk caching out of the box. If you want that , you should use **Avenues** in combination with [Shallows][shallows-github-url], which is a dedicated caching solution. For more info on that, check out the [Avenues+Shallows][avenues-shallows-github-url] repo.

## Installation
**Avenues** is available through [Carthage][carthage-url]. To install, just write into your Cartfile:

```ruby
github "dreymonde/Avenues" ~> 0.1.0
```

[carthage-url]: https://github.com/Carthage/Carthage
[swift-badge]: https://img.shields.io/badge/Swift-3.0-orange.svg?style=flat
[swift-url]: https://swift.org
[platform-badge]: https://img.shields.io/badge/platform-iOS%20%7C%20macOS%20%7C%20watchOS%20%7C%20tvOS-lightgrey.svg
[platform-url]: https://developer.apple.com/swift/
[shallows-github-url]: https://github.com/dreymonde/Shallows
[avenues-shallows-github-url]: https://github.com/dreymonde/Avenues-Shallows
