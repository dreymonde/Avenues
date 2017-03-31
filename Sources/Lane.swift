public enum ProcessorResult<Value> {
    case success(Value)
    case failure(Error)
}

public enum ProcessingState {
    case undefined
    case none
    case running
    case completed
}

public typealias ProcessorCompletion<T> = (ProcessorResult<T>) -> ()

public protocol ProcessorProtocol {
    
    associatedtype Key : Hashable
    associatedtype Value
    
    func start(key: Key, completion: @escaping ProcessorCompletion<Value>)
    func cancel(key: Key)
    func processingState(key: Key) -> ProcessingState
    func cancelAll()
    
}

public extension ProcessorProtocol {
    
    func mapKey<OtherKey>(_ transform: @escaping (OtherKey) -> Key) -> Processor<OtherKey, Value> {
        let start: Processor<OtherKey, Value>.Start = { otherKey, completion in self.start(key: transform(otherKey), completion: completion) }
        let cancel: Processor<OtherKey, Value>.Cancel = { otherKey in self.cancel(key: transform(otherKey)) }
        let getStage: Processor<OtherKey, Value>.GetState = { otherKey in self.processingState(key: transform(otherKey)) }
        return Processor(start: start,
                       cancel: cancel,
                       getState: getStage,
                       cancelAll: cancelAll)
    }
    
    func mapKey<OtherKey>(_ transform: @escaping (OtherKey) -> Key?) -> Processor<OtherKey, Value> {
        func logCannot(otherKey: OtherKey) {
            avenues_print("Cannot convert \(otherKey) to \(Key.self)")
        }
        let start: Processor<OtherKey, Value>.Start = { otherKey, completion in
            if let key = transform(otherKey) {
                self.start(key: key, completion: completion)
            } else {
                logCannot(otherKey: otherKey)
            }
        }
        let cancel: Processor<OtherKey, Value>.Cancel = { otherKey in
            if let key = transform(otherKey) {
                self.cancel(key: key)
            } else {
                logCannot(otherKey: otherKey)
            }
        }
        let getStage: Processor<OtherKey, Value>.GetState = { otherKey in
            if let key = transform(otherKey) {
                return self.processingState(key: key)
            } else {
                logCannot(otherKey: otherKey)
                return .undefined
            }
        }
        return Processor(start: start,
                         cancel: cancel,
                         getState: getStage,
                         cancelAll: cancelAll)

    }
    
    func mapValue<OtherValue>(_ transform: @escaping (Value) throws -> OtherValue) -> Processor<Key, OtherValue> {
        let start: Processor<Key, OtherValue>.Start = { key, completion in
            self.start(key: key, completion: { (result) in
                switch result {
                case .success(let value):
                    do {
                        let otherValue = try transform(value)
                        completion(.success(otherValue))
                    } catch {
                        completion(.failure(error))
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            })
        }
        return Processor(start: start,
                         cancel: self.cancel(key:),
                         getState: self.processingState(key:),
                         cancelAll: self.cancelAll)
    }
    
}

public struct Processor<Key : Hashable, Value> : ProcessorProtocol {
    
    public typealias Start = (Key, @escaping ProcessorCompletion<Value>) -> ()
    public typealias Cancel = (Key) -> ()
    public typealias GetState = (Key) -> ProcessingState
    public typealias CancelAll = () -> ()
    
    let _start: Processor.Start
    let _cancel: Processor.Cancel
    let _getState: Processor.GetState
    let _cancelAll: Processor.CancelAll
    
    public init(start: @escaping Processor.Start,
                cancel: @escaping Processor.Cancel,
                getState: @escaping Processor.GetState,
                cancelAll: @escaping Processor.CancelAll) {
        self._start = start
        self._cancel = cancel
        self._getState = getState
        self._cancelAll = cancelAll
    }
    
    public init<ProcessorType : ProcessorProtocol>(_ processor: ProcessorType) where ProcessorType.Key == Key, ProcessorType.Value == Value {
        self._start = processor.start(key:completion:)
        self._cancel = processor.cancel(key:)
        self._getState = processor.processingState(key:)
        self._cancelAll = processor.cancelAll
    }
    
    public func start(key: Key, completion: @escaping (ProcessorResult<Value>) -> ()) {
        _start(key, completion)
    }
    
    public func cancel(key: Key) {
        _cancel(key)
    }
    
    public func processingState(key: Key) -> ProcessingState {
        return _getState(key)
    }
    
    public func cancelAll() {
        _cancelAll()
    }
    
}
