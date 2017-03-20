//
//  Avenues.swift
//  AvenuesProto
//
//  Created by Олег on 18.03.17.
//  Copyright © 2017 Heeveear Proto. All rights reserved.
//

import Foundation

internal func avenues_print(_ items: Any...) {
    if Log.isEnabled {
        print(items)
    }
}

public enum Log {
    
    public static var isEnabled = false
    
}

public final class Avenue<Key : Hashable, Value> {
    
    fileprivate let onStateChange: (Key) -> ()
    fileprivate let onError: (Error, Key) -> ()
    
    fileprivate let storage: Storage<Key, Value>
    fileprivate let fetcher: Fetcher<Key, Value>
    
    fileprivate let processingQueue = DispatchQueue(label: "AvenueQueue", qos: DispatchQoS.userInitiated)
    
    fileprivate init(storage: Storage<Key, Value>,
         fetcher: Fetcher<Key, Value>,
         onError: @escaping (Error, Key) -> () = { _ in },
         onStateChange: @escaping (Key) -> ()) {
        self.storage = storage
        self.fetcher = fetcher
        self.onError = onError
        self.onStateChange = onStateChange
    }
    
    deinit {
        avenues_print("Deinit \(self)")
    }
    
    public func item(at key: Key) -> Value? {
        return storage.value(for: key)
    }
    
    public func cancelFetch(ofItemAt key: Key) {
        avenues_print("Cancelling download at \(key)")
        processingQueue.async {
            self.fetcher.cancel(key: key)
        }
    }
    
    public func prepareItem(at key: Key) {
        processingQueue.async {
            self._prepareItem(at: key)
        }
    }
    
    fileprivate func _prepareItem(at key: Key) {
        if storage.value(for: key) == nil {
            if !fetcher.isInFlight(key: key) {
                fetcher.start(key: key, completion: { (result) in
                    switch result {
                    case .success(let value):
                        avenues_print("Have an image at \(key), storing")
                        self.storage.set(value, for: key)
                        self.onStateChange(key)
                    case .failure(let error):
                        avenues_print("Errored downloading image at \(key), removing operation from dict. Error: \(key)")
                        self.fetcher.cancel(key: key)
                        self.onError(error, key)
                    }
                })
            } else {
                avenues_print("Fetching is already in flight for \(key)")
            }
        } else {
            avenues_print("Value already exists for \(key)")
        }
    }
    
}

public extension Avenue {
    
    static func ui<StorageType : StorageProtocol, FetcherType : FetcherProtocol>(storage: StorageType,
                   fetcher: FetcherType,
                   onError: @escaping (Error, Key) -> () = { _ in },
                   onStateChange: @escaping (Key) -> ()) -> Avenue where StorageType.Key == Key, StorageType.Value == Value, FetcherType.Key == Key, FetcherType.Value == Value {
        return Avenue(storage: Storage(storage),
                      fetcher: Fetcher(fetcher),
                      onError: { error, key in DispatchQueue.main.async { onError(error, key) } },
                      onStateChange: { key in DispatchQueue.main.async { onStateChange(key) } })
    }
    
    static func notOnMainQueue<StorageType : StorageProtocol, FetcherType : FetcherProtocol>(storage: StorageType,
                               fetcher: FetcherType,
                               onError: @escaping (Error, Key) -> () = { _ in },
                               onStateChange: @escaping (Key) -> ()) -> Avenue where StorageType.Key == Key, StorageType.Value == Value, FetcherType.Key == Key, FetcherType.Value == Value {
        return Avenue(storage: Storage(storage),
                      fetcher: Fetcher(fetcher),
                      onError: onError,
                      onStateChange: onStateChange)
    }
    
}
