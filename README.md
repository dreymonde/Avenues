# Avenues

**Avenues** is a new approach to the old and famous problem -- asynchronous loading of a resource, the most common example of which is populating an image from a remote location. The main advantage of **Avenues** is that it makes the whole process much more transparent and controllable.

In contrast to other libraries which solves the same problem, **Avenues** doesn't sacrifice "right" for "neat". Instead, **Avenues** is highly customizable, unopiniated about your business-logic, and very transparent. You can use it as a simple out-of-the-box solution, or you can get your hands dirty and customize it to fully fit your needs.

After all, **Avenues** is a really small, component-based project, so if you need even more controllable solution -- build one yourself! Our source code is there to help.

## Features
- Asynchronous loading/processing of items.
- Generic approach -- **Avenues** can be used not just for images.
- `NSCache`-based memory caching.
- Designed to work with `UITableView`/`UICollectionView` in an elegant, idiomatic way.
- Highly customizable -- you can provide your own storage and fetching mechanisms.
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
    var avenue: Avenue<IndexPath, UIImage>!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.avenue = UIImageAvenue(indexPathToURL: { [unowned self] in self.entries[$0.row].imageURL })
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
        cell.textLabel?.text = entry.text
        let image: UIImage? = avenue.item(at: indexPath)
        cell.imageView?.image = image
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: <#identifier#>, for: indexPath)
        configureCell(cell, forRowAt: indexPath)
        avenue.prepareItem(at: indexPath)
        return cell
    }
    
}

```

`UIImageAvenue` is a helper function that provides default `NSCache`-based storage and `URLSession`-based downloader. You can achieve the same behavior using this code:

```swift
let cache = NSCache<NSIndexPath, UIImage>()
let storage: Storage<IndexPath, UIImage> = NSCacheStorage(cache: cache)
    .mapKey({ indexPath in indexPath as NSIndexPath })
let session = URLSession(configuration: .default)
let downloader: Processor<IndexPath, UIImage> = URLSessionProcessor(session: session)
    .mapKey({ [unowned self] in self.entries[$0.row].imageURL })
    .mapImage()
self.avenue = Avenue(storage: storage,
                     processor: downloader,
                     callbackMode: .mainQueue)
```

**Avenues** provides `URLSessionProcessor` and `NSCacheStorage` + `Storage.dictionaryBased` out of the box.

### Writing your own processor
**Avenues** is not limited for networking. Any situation that requires asynchronous job will benefit from it. **Avenues** provides basic `URLSessionProcessor`, but you can write your own -- for networking or for anything else. Let's imagine that we want to write a processor that does some heavy background job and then produces a `UIImage` object. Here is one way to do it:

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
let drawer: Processor<IndexPath, UIImage> = ChartDrawer().mapKey({ [unowned self] in self.charts[$0.row] })
self.avenue = Avenue(storage: storage,
                     processor: drawer,
                     callbackMode: .mainQueue)

```

### Using Avenues with `UITableViewDataSourcePrefetching`

```swift
tableView.prefetchDataSource = self
```

Then:

```swift
extension AvenueTableViewController : UITableViewDataSourcePrefetching {
    
    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        for indexPath in indexPaths {
            avenue.prepareItem(at: indexPath)
        }
    }

    func tableView(_ tableView: UITableView, cancelPrefetchingForRowsAt indexPaths: [IndexPath]) {
        for indexPath in indexPaths {
            avenue.cancelProcessing(ofItemAt: indexPath)
        }
    }
    
}
```

Works the same way with `UICollectionView`.