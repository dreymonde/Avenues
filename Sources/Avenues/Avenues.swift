//
//  Avenues.swift
//  Avenues
//
//  Created by Oleg Dreyman on 2/12/18.
//  Copyright © 2018 Avenues. All rights reserved.
//

import Foundation

public final class Avenue<Key : Hashable, Value, Claimer : AnyObject & Hashable> {
    
    public let cache: Cache<Key, Value>
    public let processor: Processor<Key, Value>
    
    private let queue = DispatchQueue(label: "avenue-queue")
    
    private func onMain(task: @escaping () -> ()) {
        DispatchQueue.main.async(execute: task)
    }
    
    private func onBackground(task: @escaping () -> ()) {
        queue.async(execute: task)
    }
    
    public init(cache: Cache<Key, Value>,
                processor: Processor<Key, Value>) {
        self.cache = cache
        self.processor = processor
    }
    
    private var claims: [Claimer : (Key, (Value) -> ())] = [:] {
        didSet {
            assert(Thread.isMainThread)
        }
    }
    
    public func register(_ claimer: Claimer, for resourceKey: Key, setup: @escaping (Claimer, Value?) -> ()) {
        if let existing = cache.value(forKey: resourceKey) {
            setup(claimer, existing)
        } else {
            setup(claimer, nil)
            claims[claimer] = (resourceKey, { [weak claimer] value in
                if let reclaimer = claimer {
                    setup(reclaimer, value)
                }
            })
            onBackground {
                self.run(requestFor: resourceKey)
            }
        }
    }
    
    private func run(requestFor key: Key) {
        guard processor.processingState(key: key) != .running else {
            return
        }
        processor.start(key: key) { (result) in
            switch result {
            case .failure(let error):
                print(key, error)
            case .success(let value):
                self.resourceDidArrive(value, resourceKey: key)
            }
        }
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
            let relevant = self.claims.filter { (key, value) -> Bool in
                return value.0 == resourceKey
            }
            self.cache.set(resource, forKey: resourceKey)
            relevant.forEach { (_, value) in
                value.1(resource)
            }
        }
    }
    
}

