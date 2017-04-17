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

public final class Avenue<StoringKey : Hashable, ProcessingKey : Hashable, Value> {
    
    public var onStateChange: (StoringKey) -> ()
    public var onError: (Error, StoringKey) -> ()
    
    fileprivate let storage: Storage<StoringKey, Value>
    fileprivate let processor: Processor<ProcessingKey, Value>
    
    fileprivate let callbackQueue: DispatchQueue?
    fileprivate let processingQueue = DispatchQueue(label: "AvenueQueue", qos: DispatchQoS.userInitiated)
    
    public init(storage: Storage<StoringKey, Value>,
                processor: Processor<ProcessingKey, Value>,
                callbackMode: AvenueCallbackDispatchMode = .mainQueue) {
        self.storage = storage
        self.processor = processor
        self.callbackQueue = callbackMode.queue
        self.onError = { _ in avenues_print("No onError") }
        self.onStateChange = { _ in avenues_print("No onStateChange") }
    }
    
    deinit {
        avenues_print("Deinit \(self)")
    }
    
    public func item(at key: StoringKey) -> Value? {
        return storage.value(for: key)
    }
    
    public func cancelProcessing(ofItemAt key: ProcessingKey) {
        avenues_print("Cancelling download at \(key)")
        processingQueue.async {
            self.processor.cancel(key: key)
        }
    }
    
    public func cancelAll() {
        self.processor.cancelAll()
    }
    
    public func prepareItem(at key: ProcessingKey,
                            storingTo storingKey: StoringKey,
                            force: Bool = false) {
        processingQueue.async {
            self._prepareItem(at: key, storingTo: storingKey, force: force)
        }
    }
    
    internal func test_syncPrepareItem(at key: ProcessingKey,
                                       storingTo storingKey: StoringKey,
                                       force: Bool) {
        self._prepareItem(at: key, storingTo: storingKey, force: force)
    }
    
    public func processingState(ofItemAt key: ProcessingKey) -> ProcessingState {
        return processor.processingState(key: key)
    }
    
    fileprivate func _prepareItem(at key: ProcessingKey,
                                  storingTo storingKey: StoringKey,
                                  force: Bool) {
        guard storage.value(for: storingKey) == nil || force else {
            avenues_print("Item already exists for \(key)")
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
                    self.onStateChange(storingKey)
                }
            case .failure(let error):
                avenues_print("Errored processing item at \(storingKey), cancelling processing. Error: \(error)")
                self.processor.cancel(key: key)
                self.dispatchCallback {
                    self.onError(error, storingKey)
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

extension Avenue where StoringKey == ProcessingKey {
    
    public func prepareItem(at key: StoringKey, force: Bool = false) {
        prepareItem(at: key, storingTo: key, force: force)
    }
    
}

public typealias SymmetricalAvenue<Key : Hashable, Value> = Avenue<Key, Key, Value>
