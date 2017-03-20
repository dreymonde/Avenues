public enum FetcherResult<Value> {
    case success(Value)
    case failure(Error)
}

public enum FetchingState {
    case none
    case running
    case completed
}

public typealias FetcherCompletion<T> = (FetcherResult<T>) -> ()

public protocol FetcherProtocol {
    
    associatedtype Key : Hashable
    associatedtype Value
    
    func start(key: Key, completion: @escaping FetcherCompletion<Value>)
    func cancel(key: Key)
    func fetchingState(key: Key) -> FetchingState
    
}

public extension FetcherProtocol {
    
    func mapKey<OtherKey>(_ transform: @escaping (OtherKey) -> Key) -> Fetcher<OtherKey, Value> {
        let start: Fetcher<OtherKey, Value>.Start = { otherKey, completion in self.start(key: transform(otherKey), completion: completion) }
        let cancel: Fetcher<OtherKey, Value>.Cancel = { otherKey in self.cancel(key: transform(otherKey)) }
        let getStage: Fetcher<OtherKey, Value>.GetState = { otherKey in self.fetchingState(key: transform(otherKey)) }
        return Fetcher(start: start,
                       cancel: cancel,
                       getState: getStage)
    }
    
    func mapValue<OtherValue>(_ transform: @escaping (Value) throws -> OtherValue) -> Fetcher<Key, OtherValue> {
        let start: Fetcher<Key, OtherValue>.Start = { key, completion in
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
        return Fetcher(start: start,
                       cancel: self.cancel(key:),
                       getState: self.fetchingState(key:))
    }
    
}

public struct Fetcher<Key : Hashable, Value> : FetcherProtocol {
    
    public typealias Start = (Key, @escaping FetcherCompletion<Value>) -> ()
    public typealias Cancel = (Key) -> ()
    public typealias GetState = (Key) -> FetchingState
    
    let _start: Fetcher.Start
    let _cancel: Fetcher.Cancel
    let _getState: Fetcher.GetState
    
    public init(start: @escaping Fetcher.Start,
                cancel: @escaping Fetcher.Cancel,
                getState: @escaping Fetcher.GetState) {
        self._start = start
        self._cancel = cancel
        self._getState = getState
    }
    
    public init<FetcherType : FetcherProtocol>(_ fetcher: FetcherType) where FetcherType.Key == Key, FetcherType.Value == Value {
        self._start = fetcher.start(key:completion:)
        self._cancel = fetcher.cancel(key:)
        self._getState = fetcher.fetchingState(key:)
    }
    
    public func start(key: Key, completion: @escaping (FetcherResult<Value>) -> ()) {
        _start(key, completion)
    }
    
    public func cancel(key: Key) {
        _cancel(key)
    }
    
    public func fetchingState(key: Key) -> FetchingState {
        return _getState(key)
    }
    
}
