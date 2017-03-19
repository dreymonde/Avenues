public enum FetcherResult<Value> {
    case success(Value)
    case failure(Error)
}

public typealias FetcherCompletion<T> = (FetcherResult<T>) -> ()

public protocol FetcherProtocol {
    
    associatedtype Key : Hashable
    associatedtype Value
    
    func start(key: Key, completion: @escaping FetcherCompletion<Value>)
    func cancel(key: Key)
    func isRunning(key: Key) -> Bool
    
}

public struct Fetcher<Key : Hashable, Value> : FetcherProtocol {
    
    public typealias Start = (Key, @escaping FetcherCompletion<Value>) -> ()
    public typealias Cancel = (Key) -> ()
    public typealias IsRunning = (Key) -> Bool
    
    let _start: Fetcher.Start
    let _cancel: Fetcher.Cancel
    let _isRunning: Fetcher.IsRunning
    
    public init(start: @escaping Fetcher.Start,
                cancel: @escaping Fetcher.Cancel,
                isRunning: @escaping Fetcher.IsRunning) {
        self._start = start
        self._cancel = cancel
        self._isRunning = isRunning
    }
    
    public init<FetcherType : FetcherProtocol>(_ fetcher: FetcherType) where FetcherType.Key == Key, FetcherType.Value == Value {
        self._start = fetcher.start
        self._cancel = fetcher.cancel
        self._isRunning = fetcher.isRunning
    }
    
    public func start(key: Key, completion: @escaping (FetcherResult<Value>) -> ()) {
        _start(key, completion)
    }
    
    public func cancel(key: Key) {
        _cancel(key)
    }
    
    public func isRunning(key: Key) -> Bool {
        return _isRunning(key)
    }
    
}
