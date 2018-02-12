import Foundation

internal struct Synchronized<Value> {
    
    fileprivate let access: DispatchQueue
    fileprivate var _value: Value
        
    internal init(_ value: Value, queue: DispatchQueue) {
        self._value = value
        self.access = queue
    }
    
    internal init(_ value: Value) {
        let queue = DispatchQueue(label: "com.avenues.synchronized-\(Value.self)")
        self.init(value, queue: queue)
    }
    
    internal func read() -> Value {
        return access.sync { return _value }
    }
    
    internal mutating func write(_ value: Value) {
        access.sync {
            self._value = value
        }
    }
    
    internal mutating func write(with change: (inout Value) -> ()) {
        access.sync {
            change(&_value)
        }
    }

}
