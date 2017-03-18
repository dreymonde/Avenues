//
//  Avenues.swift
//  AvenuesProto
//
//  Created by Олег on 18.03.17.
//  Copyright © 2017 Heeveear Proto. All rights reserved.
//

import Foundation

public final class Avenue<Key : Hashable, Value> {
    
    fileprivate let onStateChange: (Key) -> ()
    fileprivate let onError: (Error, Key) -> ()
    
    fileprivate let storage: AvenueStorage<Key, Value>
    fileprivate let lane: AvenueLane<Key, Value>
    
    fileprivate let processingQueue = DispatchQueue(label: "AvenueQueue")
    
    internal init(_storage: AvenueStorage<Key, Value>,
         lane: AvenueLane<Key, Value>,
         onError: @escaping (Error, Key) -> () = { _ in },
         onStateChange: @escaping (Key) -> ()) {
        self.storage = _storage
        self.lane = lane
        self.onError = onError
        self.onStateChange = onStateChange
    }
    
    public func item(at key: Key) -> Value? {
        return storage.value(for: key)
    }
    
    public func cancelPreparation(ofItemAt key: Key) {
        print("Cancelling download at \(key)")
        processingQueue.async {
            self.lane.cancel(key: key)
        }
    }
    
    public func prepareItem(at key: Key) {
        processingQueue.async {
            self._prepareItem(at: key)
        }
    }
    
    fileprivate func _prepareItem(at key: Key) {
        if !lane.isRunning(key: key) {
            guard storage.value(for: key) == nil else {
                return
            }
            lane.start(key: key, completion: { (result) in
                switch result {
                case .success(let value):
                    print("Have an image at \(key), storing")
                    self.storage.set(value, for: key)
                    self.onStateChange(key)
                case .failure(let error):
                    print("Errored downloading image at \(key), removing operation from dict. Error: \(key)")
                    self.lane.cancel(key: key)
                    self.onError(error, key)
                }
            })
        } else {
            print("Download for \(key) is already in-flight")
        }
    }
    
}

public extension Avenue {
    
    convenience init(storage: AvenueStorage<Key, Value>,
                     lane: AvenueLane<Key, Value>,
                     onError: @escaping (Error, Key) -> () = { _ in },
                     onStateChange: @escaping (Key) -> ()) {
        self.init(_storage: storage,
                  lane: lane,
                  onError: { error, key in DispatchQueue.main.async { onError(error, key) } },
                  onStateChange: { key in DispatchQueue.main.async { onStateChange(key) } })
    }
    
    static func notOnMainQueue(storage: AvenueStorage<Key, Value>,
                               lane: AvenueLane<Key, Value>,
                               onError: @escaping (Error, Key) -> () = { _ in },
                               onStateChange: @escaping (Key) -> ()) -> Avenue {
        return Avenue(_storage: storage,
                      lane: lane,
                      onError: onError,
                      onStateChange: onStateChange)
    }
    
}
