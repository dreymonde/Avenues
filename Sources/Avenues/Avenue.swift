//
//  Avenues.swift
//  Avenues
//
//  Created by Oleg Dreyman on 2/12/18.
//  Copyright © 2018 Avenues. All rights reserved.
//

import Foundation

public enum ResourceState<Value> {
    case existing(Value)
    case justArrived(Value)
    case processing
    
    public var value: Value? {
        switch self {
        case .existing(let value):
            return value
        case .justArrived(let value):
            return value
        case .processing:
            return nil
        }
    }
}

public final class Avenue<Key : Hashable, Value> {
    
    public let cache: MemoryCache<Key, Value>
    public let scheduler: Scheduler<Key, Value>

    private var claims = Claims()
    private let queue = DispatchQueue(label: "avenue-dispatch-queue")
    
    public init(cache: MemoryCache<Key, Value>,
                scheduler: Scheduler<Key, Value>) {
        self.cache = cache
        self.scheduler = scheduler
        self.scheduler.didFinish.delegate(to: self) { (self, args) in
            self.processing(for: args.key, didFinishWith: args.result)
        }
    }
    
    public convenience init(cache: MemoryCache<Key, Value>,
                            processor: Processor<Key, Value>) {
        let scheduler = Scheduler(processor: processor)
        self.init(cache: cache, scheduler: scheduler)
    }
    
    public func manualRegister(claimer: AnyHashable,
                               for resourceKey: Key,
                               setup: @escaping (ResourceState<Value>) -> ()) {
        assert(Thread.isMainThread, "You can claim resources only on the main thread")
        let claim = Claim(key: resourceKey, setup: setup)
        claims[claimer] = claim
        self.run(requestFor: resourceKey) { (cachedValue) in
            if let cachedValue = cachedValue {
                setup(.existing(cachedValue))
            } else {
                setup(.processing)
            }
        }
    }
    
    public func register<Claimer : AnyObject & Hashable>(_ claimer: Claimer,
                                                         for resourceKey: Key,
                                                         setup: @escaping (Claimer, ResourceState<Value>) -> ()) {
        manualRegister(claimer: claimer, for: resourceKey) { [weak claimer] (value) in
            if let claimer = claimer {
                setup(claimer, value)
            }
        }
    }
    
    private func run(requestFor key: Key, existingValue block: (Value?) -> ()) {
        if let existing = cache.value(forKey: key) {
            block(existing)
            return
        }
        block(nil)
        onBackgroundQueue {
            self.scheduler.requestProcessing(key: key)
        }
    }
    
    public func forceLoad(key: Key) {
        run(requestFor: key, existingValue: { _ in })
    }
    
    public func preload(key: Key) {
        run(requestFor: key, existingValue: { _ in })
    }
    
    public func cancel(key: Key) {
        onBackgroundQueue {
            self.scheduler.cancelProcessing(key: key)
        }
    }
    
    public func cancelAll() {
        onBackgroundQueue {
            self.scheduler.cancelAll()
        }
    }
    
    private func processing(for key: Key, didFinishWith result: ProcessorResult<Value>) {
        switch result {
        case .failure(let error):
            print(key, error)
        case .success(let value):
            self.resourceDidArrive(value, resourceKey: key)
        }
    }
    
    private func resourceDidArrive(_ resource: Value, resourceKey: Key) {
        onMainQueue {
            let activeClaims = self.claims.claims(for: resourceKey)
            self.cache.set(resource, forKey: resourceKey)
            for (claim) in activeClaims {
                claim.setup(.justArrived(resource))
            }
        }
    }
    
}

extension Avenue {
    
    private func onMainQueue(task: @escaping () -> ()) {
        DispatchQueue.main.async(execute: task)
    }
    
    private func onBackgroundQueue(task: @escaping () -> ()) {
        queue.async(execute: task)
    }
    
}

extension Avenue {
    
    private struct Claims {
        
        private var claimsForClaimer: [AnyHashable : Claim] = [:]
        private var claimersForKey: [Key : Set<AnyHashable>] = [:]
        
        subscript(claimer: AnyHashable) -> Claim? {
            get {
                return claimsForClaimer[claimer]
            }
            set {
                if let oldClaim = claimsForClaimer[claimer] {
                    let oldKey = oldClaim.key
                    claimersForKey[oldKey]?.remove(claimer)
                }
                claimsForClaimer[claimer] = newValue
                if let newClaim = newValue {
                    claimersForKey[newClaim.key, default: []].insert(claimer)
                }
            }
        }
        
        func claims(for key: Key) -> [Claim] {
            return claimersForKey[key, default: []].compactMap({ claimer in claimsForClaimer[claimer] })
        }
        
    }
    
    private struct Claim {
        
        let key: Key
        let setup: (ResourceState<Value>) -> ()
        
    }
    
}
