import Foundation


public struct Synchronized<Value> {
    
    fileprivate let access: DispatchQueue
    fileprivate var _value: Value
    
    public var value: Value {
        get {
            return get()
        }
        set {
            set(newValue)
        }
    }
    
    public init(_ value: Value, queue: DispatchQueue) {
        self._value = value
        self.access = queue
    }
    
    public init(_ value: Value) {
        let queue = DispatchQueue(label: "com.avenues.synchronized-\(Value.self)")
        self.init(value, queue: queue)
    }
    
    public func get() -> Value {
        return access.sync { return _value }
    }
    
    public mutating func set(_ value: Value) {
        access.sync {
            self._value = value
        }
    }
    
    public mutating func set(_ change: (inout Value) -> ()) {
        access.sync {
            change(&_value)
        }
    }

}
