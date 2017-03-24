//
//  Avenues.swift
//  AvenuesProto
//
//  Created by Олег on 18.03.17.
//  Copyright © 2017 Heeveear Proto. All rights reserved.
//

import Foundation

internal func avenues_print(_ item: Any) {
    if Log.isEnabled {
        print(item)
    }
}

public enum Log {
    
    public static var isEnabled = false
    
}

public enum AvenueCallbackDispatchMode {
    case mainQueue
    case privateQueue
    
    internal var queue: DispatchQueue? {
        switch self {
        case .mainQueue:
            return .main
        case .privateQueue:
            return nil
        }
    }
}

public final class Avenue<Key : Hashable, Value> {
    
    public var onStateChange: (Key) -> ()
    public var onError: (Error, Key) -> ()
    
    fileprivate let storage: Storage<Key, Value>
    fileprivate let processor: Processor<Key, Value>
    
    fileprivate let callbackQueue: DispatchQueue?
    fileprivate let processingQueue = DispatchQueue(label: "AvenueQueue", qos: DispatchQoS.userInitiated)
    
    public init(storage: Storage<Key, Value>,
                processor: Processor<Key, Value>,
                callbackMode: AvenueCallbackDispatchMode = .mainQueue) {
        self.storage = storage
        self.processor = processor
        self.callbackQueue = callbackMode.queue
        self.onError = { _ in avenues_print("No onError") }
        self.onStateChange = { _ in avenues_print("No onStateChange") }
    }
    
    private func dispatchCallback(callback: @escaping () -> ()) {
        if let queue = callbackQueue {
            queue.async { callback() }
        } else {
            callback()
        }
    }
    
    deinit {
        avenues_print("Deinit \(self)")
    }
    
    public func item(at key: Key) -> Value? {
        return storage.value(for: key)
    }
    
    public func cancelProcessing(ofItemAt key: Key) {
        avenues_print("Cancelling download at \(key)")
        processingQueue.async {
            self.processor.cancel(key: key)
        }
    }
    
    public func cancelAll() {
        self.processor.cancelAll()
    }
    
    public func prepareItem(at key: Key) {
        processingQueue.async {
            self._prepareItem(at: key)
        }
    }
    
    public func processingState(ofItemAt key: Key) -> ProcessingState {
        return processor.processingState(key: key)
    }
    
    fileprivate func _prepareItem(at key: Key) {
        if storage.value(for: key) == nil {
            if processor.processingState(key: key) != .running {
                processor.start(key: key, completion: { (result) in
                    switch result {
                    case .success(let value):
                        avenues_print("Have an item at \(key), storing")
                        self.storage.set(value, for: key)
                        self.dispatchCallback {
                            self.onStateChange(key)
                        }
                    case .failure(let error):
                        avenues_print("Errored processing item at \(key), cancelling processing. Error: \(key)")
                        self.processor.cancel(key: key)
                        self.dispatchCallback {
                            self.onError(error, key)
                        }
                    }
                })
            } else {
                avenues_print("Processing is already in flight for \(key)")
            }
        } else {
            avenues_print("Item already exists for \(key)")
        }
    }
    
}
