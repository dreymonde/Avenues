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
        return Cache(self)
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
    
    public init<Cache : CacheProtocol>(_ cache: Cache) where Cache.Key == Key, Cache.Value == Value {
        self.init(get: cache.value, set: cache.set)
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

extension Cache where Key : Hashable {
    
    public static func dictionaryBased() -> Cache<Key, Value> {
        var dictionary: [Key : Value] = [:]
        return Cache<Key, Value>(get: { dictionary[$0] },
                                 set: { dictionary[$1] = $0 })
    }
    
}

extension CacheProtocol {
    
    public func mapKeys<OtherKey>(to keyType: OtherKey.Type = OtherKey.self,
                                  _ transform: @escaping (OtherKey) -> Key) -> Cache<OtherKey, Value> {
        let get: (OtherKey) -> Value? = { otherKey in return self.value(forKey: transform(otherKey)) }
        let set: (Value, OtherKey) -> () = { value, otherKey in self.set(value, forKey: transform(otherKey)) }
        return Cache(get: get, set: set)
    }
    
    public func mapValues<OtherValue>(to valueType: OtherValue.Type = OtherValue.self,
                                      transformIn: @escaping (Value) -> OtherValue?,
                                      transformOut: @escaping (OtherValue) -> Value) -> Cache<Key, OtherValue> {
        return Cache<Key, OtherValue>(get: { (key) -> OtherValue? in
            return self.value(forKey: key).flatMap(transformIn)
        }, set: { (otherValue, key) in
            self.set(transformOut(otherValue), forKey: key)
        })
    }
        
}

#if os(iOS) || os(OSX) || os(watchOS) || os(tvOS)
    
    public final class NSCacheCache<Key : AnyObject, Value : AnyObject> : CacheProtocol where Key : Hashable {
        
        public var cache: NSCache<Key, Value>
        
        public init(cache: NSCache<Key, Value> = NSCache()) {
            self.cache = cache
        }
        
        public func value(forKey key: Key) -> Value? {
            return cache.object(forKey: key)
        }
        
        public func set(_ value: Value, forKey key: Key) {
            cache.setObject(value, forKey: key)
        }
        
        public func remove(valueAt key: Key) {
            cache.removeObject(forKey: key)
        }
        
        public func clear() {
            self.cache = NSCache()
        }
        
    }
    
    public func NSCacheCacheBoxedKey<Key : Hashable, Value : AnyObject>() -> Cache<Key, Value> {
        return NSCacheCache<NSCacheKeyBox<Key>, Value>().mapKeys(NSCacheKeyBox.init)
    }
    
    internal final class NSCacheKeyBox<Value : Hashable> : NSObject {
        
        internal let boxed: Value
        
        internal init(_ value: Value) {
            self.boxed = value
        }
        
        internal override func isEqual(_ object: Any?) -> Bool {
            guard let other = object as? NSCacheKeyBox<Value> else {
                return false
            }
            return self.boxed == other.boxed
        }
        
        internal override var hash: Int {
            return boxed.hashValue
        }
        
    }
    
#endif
