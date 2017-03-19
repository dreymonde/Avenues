#if os(iOS) || os(OSX) || os(watchOS) || os(tvOS)
    import Foundation
#endif

public protocol AvenueStorageProtocol {
    
    associatedtype Key : Hashable
    associatedtype Value
    
    func value(for key: Key) -> Value?
    func set(_ value: Value?, for key: Key)
    
}

public struct AvenueStorage<Key : Hashable, Value> : AvenueStorageProtocol {
    
    public typealias Get = (Key) -> Value?
    public typealias Set = (Value?, Key) -> ()
    
    private let _get: AvenueStorage.Get
    private let _set: AvenueStorage.Set
    
    public init(get: @escaping AvenueStorage.Get,
                set: @escaping AvenueStorage.Set) {
        self._get = get
        self._set = set
    }
    
    public init<Storage : AvenueStorageProtocol>(_ storage: Storage)
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

extension AvenueStorage {

    public static func dictionaryBased() -> AvenueStorage {
        var dictionary: [Key : Value] = [:]
        return AvenueStorage.synchronized(get: { dictionary[$0] },
                                          set: { dictionary[$1] = $0 })
    }
    
}

#if os(iOS) || os(OSX) || os(watchOS) || os(tvOS)

    extension AvenueStorage {
        
        public static func synchronized(get: @escaping AvenueStorage.Get,
                                        set: @escaping AvenueStorage.Set) -> AvenueStorage {
            let queue = DispatchQueue(label: "com.avenues.storage-dispatch-queue")
            let threadSafeGet: AvenueStorage.Get = { key in
                return queue.sync { return get(key) }
            }
            let threadSafeSet: AvenueStorage.Set = { value, key in
                queue.sync { set(value, key) }
            }
            return AvenueStorage(get: threadSafeGet,
                                 set: threadSafeSet)
        }
        
    }
    
    extension AvenueStorage where Value : AnyObject {
        
        public static func nsCache() -> AvenueStorage<IndexPath, Value> {
            let cache = NSCache<NSIndexPath, Value>()
            return AvenueStorage<IndexPath, Value>(get: { key in cache.object(forKey: key as NSIndexPath) },
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
