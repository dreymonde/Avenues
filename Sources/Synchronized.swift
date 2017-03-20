import Foundation

internal struct Synchronized<Value> {
    
    fileprivate let access: DispatchQueue
    fileprivate var _value: Value
    
    @available(*, deprecated, message: "Don't use it in production code, use `get` and `set` instead")
    internal var value: Value {
        get {
            return get()
        }
        set {
            set(newValue)
        }
    }
    
    internal init(_ value: Value, queue: DispatchQueue) {
        self._value = value
        self.access = queue
    }
    
    internal init(_ value: Value) {
        let queue = DispatchQueue(label: "com.avenues.synchronized-\(Value.self)")
        self.init(value, queue: queue)
    }
    
    internal func get() -> Value {
        return access.sync { return _value }
    }
    
    internal mutating func set(_ value: Value) {
        access.sync {
            self._value = value
        }
    }
    
    internal mutating func set(_ change: (inout Value) -> ()) {
        access.sync {
            change(&_value)
        }
    }

}
