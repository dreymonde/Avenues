#if os(iOS) || os(OSX) || os(watchOS) || os(tvOS)
    import Foundation
#endif

public protocol StorageProtocol {
    
    associatedtype Key : Hashable
    associatedtype Value
    
    func value(for key: Key) -> Value?
    func set(_ value: Value, for key: Key)
    func remove(valueAt key: Key)
    
}

public struct Storage<Key : Hashable, Value> : StorageProtocol {
    
    public typealias Get = (Key) -> Value?
    public typealias Set = (Value, Key) -> ()
    public typealias Remove = (Key) -> ()
    
    private let _get: Storage.Get
    private let _set: Storage.Set
    private let _remove: Storage.Remove
    
    public init(get: @escaping Storage.Get,
                set: @escaping Storage.Set,
                remove: @escaping Storage.Remove) {
        self._get = get
        self._set = set
        self._remove = remove
    }
    
    public init(get: @escaping Storage.Get,
                set: @escaping (Value?, Key) -> ()) {
        self._get = get
        self._set = { value, key in set(value, key) }
        self._remove = { key in set(nil, key) }
    }
    
    public init<Storage : StorageProtocol>(_ storage: Storage) where Storage.Key == Key, Storage.Value == Value {
        self._get = storage.value(for:)
        self._set = storage.set(_:for:)
        self._remove = storage.remove(valueAt:)
    }
    
    public func value(for key: Key) -> Value? {
        return _get(key)
    }
    
    public func set(_ value: Value, for key: Key) {
        return _set(value, key)
    }
    
    public func remove(valueAt key: Key) {
        _remove(key)
    }
    
}

extension Storage {

    public static func dictionaryBased() -> Storage {
        var dictionary: [Key : Value] = [:]
        return Storage(get: { dictionary[$0] },
                       set: { dictionary[$1] = $0 }).synchronized()
    }
    
}

public extension StorageProtocol {
    
    func mapKey<OtherKey>(_ transform: @escaping (OtherKey) -> Key) -> Storage<OtherKey, Value> {
        let get: Storage<OtherKey, Value>.Get = { otherKey in return self.value(for: transform(otherKey)) }
        let set: Storage<OtherKey, Value>.Set = { value, otherKey in self.set(value, for: transform(otherKey)) }
        let remove: Storage<OtherKey, Value>.Remove = { otherKey in self.remove(valueAt: transform(otherKey)) }
        return Storage(get: get, set: set, remove: remove)
    }
    
    func mapValue<OtherValue>(inTransform: @escaping (Value) -> OtherValue, outTransform: @escaping (OtherValue) -> Value) -> Storage<Key, OtherValue> {
        let get: Storage<Key, OtherValue>.Get = { key in return self.value(for: key).map(inTransform) }
        let set: Storage<Key, OtherValue>.Set = { otherValue, key in self.set(outTransform(otherValue), for: key) }
        return Storage(get: get, set: set, remove: self.remove)
    }
    
}

#if os(iOS) || os(OSX) || os(watchOS) || os(tvOS)
    
    public class NSCacheStorage<Key : AnyObject, Value : AnyObject> : StorageProtocol where Key : Hashable {
        
        public let cache: NSCache<Key, Value>
        
        init(cache: NSCache<Key, Value> = NSCache()) {
            self.cache = cache
        }
        
        public func value(for key: Key) -> Value? {
            return cache.object(forKey: key)
        }
        
        public func set(_ value: Value, for key: Key) {
            cache.setObject(value, forKey: key)
        }
        
        public func remove(valueAt key: Key) {
            cache.removeObject(forKey: key)
        }
        
    }

    extension Storage {
        
        public func synchronized() -> Storage {
            let queue = DispatchQueue(label: "com.avenues.storage-dispatch-queue")
            let threadSafeGet: Storage.Get = { key in
                return queue.sync { return self.value(for: key) }
            }
            let threadSafeSet: Storage.Set = { value, key in
                queue.sync { self.set(value, for: key) }
            }
            let threadSafeRemove: Storage.Remove = { key in
                queue.sync { self.remove(valueAt: key) }
            }
            return Storage(get: threadSafeGet,
                           set: threadSafeSet,
                           remove: threadSafeRemove)
        }
        
    }
    
#endif
