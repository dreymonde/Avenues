//
//  Avenues.swift
//  Avenues
//
//  Created by Oleg Dreyman on 2/12/18.
//  Copyright © 2018 Avenues. All rights reserved.
//

import Foundation

public final class Avenue<Key : Hashable, Value> {
    
    public let cache: MemoryCache<Key, Value>
    public let processor: Processor<Key, Value>
    
    private var claims: [AnyHashable : Claim] = [:]
    
    private let queue = DispatchQueue(label: "avenue-queue")
    
    public init(cache: MemoryCache<Key, Value>,
                processor: Processor<Key, Value>) {
        self.cache = cache
        self.processor = processor
    }
    
    private func register(_ claimer: AnyHashable,
                          for resourceKey: Key,
                          setup: @escaping (Value?) -> ()) {
        if let existing = cache.value(forKey: resourceKey) {
            setup(existing)
        } else {
            setup(nil)
            let claim = Claim(key: resourceKey, setup: setup)
            claims[claimer] = claim
            self.run(requestFor: resourceKey)
        }
    }
    
    public func register<Claimer : AnyObject & Hashable>(_ claimer: Claimer,
                                                         for resourceKey: Key,
                                                         setup: @escaping (Claimer, Value?) -> ()) {
        register(claimer, for: resourceKey) { [weak claimer] (value) in
            if let claimer = claimer {
                setup(claimer, value)
            }
        }
    }
    
    private func run(requestFor key: Key) {
        onBackground {
            guard self.processor.processingState(key: key) != .running else {
                return
            }
            self.processor.start(key: key) { (result) in
                switch result {
                case .failure(let error):
                    print(key, error)
                case .success(let value):
                    self.resourceDidArrive(value, resourceKey: key)
                }
            }
        }
    }
    
    public func preload(key: Key) {
        run(requestFor: key)
    }
    
    public func cancel(key: Key) {
        onBackground {
            self.processor.cancel(key: key)
        }
    }
    
    public func cancelAll() {
        onBackground {
            self.processor.cancelAll()
        }
    }
    
    private func resourceDidArrive(_ resource: Value, resourceKey: Key) {
        onMain {
            let activeClaims = self.claims.filter({ (_, claim) -> Bool in
                return claim.key == resourceKey
            })
            self.cache.set(resource, forKey: resourceKey)
            for (_, claim) in activeClaims {
                claim.setup(resource)
            }
        }
    }
    
}

extension Avenue {
    
    private func onMain(task: @escaping () -> ()) {
        DispatchQueue.main.async(execute: task)
    }
    
    private func onBackground(task: @escaping () -> ()) {
        queue.async(execute: task)
    }

}

extension Avenue {
    
    private struct Claim {
        
        let key: Key
        let setup: (Value) -> ()
        
    }
    
}
