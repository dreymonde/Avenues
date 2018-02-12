//
//  Cache.swift
//  Avenues
//
//  Created by Олег on 12.02.2018.
//  Copyright © 2018 Avenues. All rights reserved.
//

import Foundation

public protocol CacheProtocol {
    
    associatedtype Key
    associatedtype Value
    
    func value(forKey key: Key) -> Value?
    func set(_ value: Value, forKey key: Key)
    
}

extension CacheProtocol {
    
    public func asCache() -> Cache<Key, Value> {
        return Cache(get: value(forKey:), set: set(_:forKey:))
    }
    
}

public struct Cache<Key, Value> : CacheProtocol {
    
    private let _get: (Key) -> Value?
    private let _set: (Value, Key) -> ()
    
    public init(get: @escaping (Key) -> Value?,
                set: @escaping (Value, Key) -> ()) {
        self._get = get
        self._set = set
    }
    
    private func assertMainQueue() {
        assert(Thread.isMainThread)
    }
    
    public func value(forKey key: Key) -> Value? {
        assertMainQueue()
        return _get(key)
    }
    
    public func set(_ value: Value, forKey key: Key) {
        assertMainQueue()
        _set(value, key)
    }
    
}

public final class MemoryCache<Key : Hashable, Value> : CacheProtocol {
    
    private var dict: [Key : Value]
    
    public init(_ dict: [Key : Value] = [:]) {
        self.dict = dict
    }
    
    public func value(forKey key: Key) -> Value? {
        return dict[key]
    }
    
    public func set(_ value: Value, forKey key: Key) {
        dict[key] = value
    }
    
}

