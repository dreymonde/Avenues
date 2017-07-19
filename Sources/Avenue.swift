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

public class ProtoAvenue<StoringKey : Hashable, ProcessingKey : Hashable, Value> {
    
    internal func didChangeState(forKey key: StoringKey) {
        // override
    }
    
    internal func didFail(with error: Error, key: StoringKey) {
        // override
    }
    
    public let storage: Storage<StoringKey, Value>
    public let processor: Processor<ProcessingKey, Value>
    
    fileprivate let callbackQueue: DispatchQueue?
    fileprivate let processingQueue = DispatchQueue(label: "AvenueQueue", qos: .userInitiated)
    
    public init(storage: Storage<StoringKey, Value>,
                processor: Processor<ProcessingKey, Value>,
                callbackMode: AvenueCallbackDispatchMode = .mainQueue) {
        self.storage = storage
        self.processor = processor
        self.callbackQueue = callbackMode.queue
    }
    
    deinit {
        avenues_print("Deinit \(self)")
    }
    
    public func item(at key: StoringKey) -> Value? {
        return storage.value(for: key)
    }
    
    public func cancelProcessing(of key: ProcessingKey) {
        avenues_print("Cancelling download at \(key)")
        processingQueue.async {
            self.processor.cancel(key: key)
        }
    }
    
    public func cancelAll() {
        self.processor.cancelAll()
    }
    
    internal func internal_prepareItem(for key: ProcessingKey,
                            storingTo storingKey: StoringKey,
                            force: Bool = false) {
        processingQueue.async {
            self._prepareItem(for: key, storingTo: storingKey, force: force)
        }
    }
    
    public func processingState(of key: ProcessingKey) -> ProcessingState {
        return processor.processingState(key: key)
    }
    
    fileprivate func _prepareItem(for key: ProcessingKey,
                                  storingTo storingKey: StoringKey,
                                  force: Bool) {
        guard storage.value(for: storingKey) == nil || force else {
            avenues_print("Item already exists for \(storingKey)")
            return
        }
        guard processor.processingState(key: key) != .running else {
            avenues_print("Processing is already in flight for \(key)")
            return
        }
        processor.start(key: key) { (result) in
            switch result {
            case .success(let value):
                avenues_print("Have an item at \(storingKey), storing")
                self.storage.set(value, for: storingKey)
                self.dispatchCallback {
                    self.didChangeState(forKey: storingKey)
                }
            case .failure(let error):
                avenues_print("Errored processing item at \(storingKey), cancelling processing. Error: \(error)")
                self.processor.cancel(key: key)
                self.dispatchCallback {
                    self.didFail(with: error, key: storingKey)
                }
            }
        }
    }
    
    private func dispatchCallback(callback: @escaping () -> ()) {
        if let queue = callbackQueue {
            queue.async { callback() }
        } else {
            callback()
        }
    }
    
}

public class CallbackBasedAvenue<StoringKey : Hashable, ProcessingKey : Hashable, Value> : ProtoAvenue<StoringKey, ProcessingKey, Value> {
    
    public var onStateChange: (StoringKey) -> () = { _ in avenues_print("No onStateChange") }
    public var onError: (Error, StoringKey) -> () = { _ in avenues_print("No onError") }
    
    internal final override func didChangeState(forKey key: StoringKey) {
        onStateChange(key)
    }
    
    internal final override func didFail(with error: Error, key: StoringKey) {
        onError(error, key)
    }
    
}

public final class Avenue<Key : Hashable, Value> : CallbackBasedAvenue<Key, Key, Value> {
    
    public func prepareItem(for key: Key, force: Bool = false) {
        internal_prepareItem(for: key, storingTo: key, force: force)
    }
    
}

public final class AsymmetricalAvenue<StoringKey : Hashable, ProcessingKey : Hashable, Value> : CallbackBasedAvenue<StoringKey, ProcessingKey, Value> {
    
    public func prepareItem(for key: ProcessingKey,
                            storingTo storingKey: StoringKey,
                            force: Bool = false) {
        internal_prepareItem(for: key, storingTo: storingKey, force: force)
    }
    
}

extension ProtoAvenue {
    
    internal func test_syncPrepareItem(for key: ProcessingKey,
                                       storingTo storingKey: StoringKey,
                                       force: Bool) {
        self._prepareItem(for: key, storingTo: storingKey, force: force)
    }
    
}
