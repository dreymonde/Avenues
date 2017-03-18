public enum AvenueLaneResult<Value> {
    case success(Value)
    case failure(Error)
}

public typealias AvenueLaneCompletion<T> = (AvenueLaneResult<T>) -> ()

public protocol AvenueLaneProtocol {
    
    associatedtype Key : Hashable
    associatedtype Value
    
    func start(key: Key, completion: @escaping AvenueLaneCompletion<Value>)
    func cancel(key: Key)
    func isRunning(key: Key) -> Bool
    
}

public struct AvenueLane<Key : Hashable, Value> : AvenueLaneProtocol {
    
    public typealias Start = (Key, @escaping AvenueLaneCompletion<Value>) -> ()
    public typealias Cancel = (Key) -> ()
    public typealias IsRunning = (Key) -> Bool
    
    let _start: AvenueLane.Start
    let _cancel: AvenueLane.Cancel
    let _isRunning: AvenueLane.IsRunning
    
    public init(start: @escaping AvenueLane.Start,
                cancel: @escaping AvenueLane.Cancel,
                isRunning: @escaping AvenueLane.IsRunning) {
        self._start = start
        self._cancel = cancel
        self._isRunning = isRunning
    }
    
    public init<Lane : AvenueLaneProtocol>(_ lane: Lane) where Lane.Key == Key, Lane.Value == Value {
        self._start = lane.start
        self._cancel = lane.cancel
        self._isRunning = lane.isRunning
    }
    
    public func start(key: Key, completion: @escaping (AvenueLaneResult<Value>) -> ()) {
        _start(key, completion)
    }
    
    public func cancel(key: Key) {
        _cancel(key)
    }
    
    public func isRunning(key: Key) -> Bool {
        return _isRunning(key)
    }
    
}
