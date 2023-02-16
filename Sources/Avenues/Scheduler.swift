//
//  Scheduler.swift
//  NewAvenue
//
//  Created by Олег on 04.03.2018.
//  Copyright © 2018 Heeveear Proto. All rights reserved.
//

import Foundation

public final class Scheduler<Key : Hashable, Value> {
    
    public let processor: Processor<Key, Value>
    
    public init(processor: Processor<Key, Value>) {
        self.processor = processor
        self.runningTasks = Synchronized(CountedSet())
    }
    
    public var didFinish = Avenues.AvenuesDelegated<(key: Key, result: ProcessorResult<Value>), Void>()
    
    private var runningTasks: Synchronized<CountedSet<Key>>
    
    public func requestProcessing(key: Key) {
        let shouldStart: Bool = runningTasks.transaction { (running) in
            if running.contains(key) {
                running.add(key)
                return false
            }
            running.add(key)
            return true
        }
        if shouldStart {
            processor.start(key: key, completion: { (result) in
                self.request(for: key, didFinishWith: result)
            })
        }
    }
    
    private func request(for key: Key,
                         didFinishWith result: ProcessorResult<Value>) {
        let shouldComplete: Bool = self.runningTasks.transaction(with: { running in
            if running.contains(key) {
                running.clear(key)
                return true
            }
            return false
        })
        if shouldComplete {
            self.didFinish.call((key: key, result: result))
        }
        
    }
    
    public func cancelProcessing(key: Key) {
        let shouldCancel: Bool = runningTasks.transaction(with: { (running) in
            running.remove(key)
            if !running.contains(key) {
                return true
            } else {
                return false
            }
        })
        if shouldCancel {
            processor.cancel(key: key)
        }
    }
    
    public func cancelAll() {
        runningTasks.transaction(with: { (running) in
            running = CountedSet()
        })
        processor.cancelAll()
    }
    
}

public struct AvenuesDelegated<Input, Output> {
    
    private(set) var callback: ((Input) -> Output?)?
    
    public init() { }
    
    public mutating func delegate<Target : AnyObject>(to target: Target,
                                                      with callback: @escaping (Target, Input) -> Output) {
        self.callback = { [weak target] input in
            guard let target = target else {
                return nil
            }
            return callback(target, input)
        }
    }
    
    public func call(_ input: Input) -> Output? {
        return self.callback?(input)
    }
    
    public var isDelegateSet: Bool {
        return callback != nil
    }
    
}

extension AvenuesDelegated {
    
    public mutating func stronglyDelegate<Target : AnyObject>(to target: Target,
                                                              with callback: @escaping (Target, Input) -> Output) {
        self.callback = { input in
            return callback(target, input)
        }
    }
    
    public mutating func manuallyDelegate(with callback: @escaping (Input) -> Output) {
        self.callback = callback
    }
    
    public mutating func removeDelegate() {
        self.callback = nil
    }
    
}

extension AvenuesDelegated where Output == Void {
    
    public func call(_ input: Input) {
        self.callback?(input)
    }
    
}

internal struct CountedSet<Element : Hashable> {
    
    private var storage: [Element : UInt] = [:]
    
    init() { }
    
    init<C : Collection>(_ collection: C) where C.Element == Element {
        for element in collection {
            self.add(element)
        }
    }
    
    func contains(_ element: Element) -> Bool {
        return count(for: element) > 0
    }
    
    func count(for key: Element) -> UInt {
        return storage[key, default: 0]
    }
    
    mutating func add(_ element: Element) {
        storage[element, default: 0] += 1
    }
    
    mutating func remove(_ element: Element) {
        if let currentCount = storage[element] {
            if currentCount > 1 {
                storage[element] = currentCount - 1
            } else {
                storage.removeValue(forKey: element)
            }
        }
    }
    
    mutating func clear(_ element: Element) {
        storage.removeValue(forKey: element)
    }
    
}
