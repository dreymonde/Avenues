#if os(iOS) || os(OSX) || os(watchOS) || os(tvOS)
    import Foundation
#endif

public protocol StorageProtocol {
    
    associatedtype Key : Hashable
    associatedtype Value
    
    func value(for key: Key) -> Value?
    func set(_ value: Value?, for key: Key)
    
}

public struct Storage<Key : Hashable, Value> : StorageProtocol {
    
    public typealias Get = (Key) -> Value?
    public typealias Set = (Value?, Key) -> ()
    
    private let _get: Storage.Get
    private let _set: Storage.Set
    
    public init(get: @escaping Storage.Get,
                set: @escaping Storage.Set) {
        self._get = get
        self._set = set
    }
    
    public init<Storage : StorageProtocol>(_ storage: Storage)
            where Storage.Key == Key, Storage.Value == Value {
        self._get = storage.value(for:)
        self._set = storage.set
    }
        
    public func value(for key: Key) -> Value? {
        return _get(key)
    }
    
    public func set(_ value: Value?, for key: Key) {
        return _set(value, key)
    }
    
}

extension Storage {

    public static func dictionaryBased() -> Storage {
        var dictionary: [Key : Value] = [:]
        return Storage.synchronized(get: { dictionary[$0] },
                                          set: { dictionary[$1] = $0 })
    }
    
}

#if os(iOS) || os(OSX) || os(watchOS) || os(tvOS)

    extension Storage {
        
        public static func synchronized(get: @escaping Storage.Get,
                                        set: @escaping Storage.Set) -> Storage {
            let queue = DispatchQueue(label: "com.avenues.storage-dispatch-queue")
            let threadSafeGet: Storage.Get = { key in
                return queue.sync { return get(key) }
            }
            let threadSafeSet: Storage.Set = { value, key in
                queue.sync { set(value, key) }
            }
            return Storage(get: threadSafeGet,
                                 set: threadSafeSet)
        }
        
    }
    
    extension Storage where Value : AnyObject {
        
        public static func nsCache() -> Storage<IndexPath, Value> {
            let cache = NSCache<NSIndexPath, Value>()
            return Storage<IndexPath, Value>(get: { key in cache.object(forKey: key as NSIndexPath) },
                                                   set: { value, key in
                                                    if let value = value {
                                                        cache.setObject(value, forKey: key as NSIndexPath)
                                                    } else {
                                                        cache.removeObject(forKey: key as NSIndexPath)
                                                    }
            })
        }
        
    }

#endif
