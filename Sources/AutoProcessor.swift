public protocol AutoProcessorProtocol {
    
    associatedtype Key : Hashable
    associatedtype Value
    
    func start(key: Key, completion: @escaping ProcessorCompletion<Value>)
    func cancel(key: Key) -> Bool
    func cancelAll()
    
}

public extension AutoProcessorProtocol {
    
    func processor() -> Processor<Key, Value> {
        return Processor(AutoProcessor(self))
    }
    
}

public final class AutoProcessor<Proc : AutoProcessorProtocol> : ProcessorProtocol {
    
    public typealias Key = Proc.Key
    public typealias Value = Proc.Value
    
    private let proc: Proc
    
    public init(_ autoProcessor: Proc) {
        self.proc = autoProcessor
    }
    
    private var tasks: Synchronized<[Key : ProcessingState]> = .init([:])
    
    public func start(key: Proc.Key, completion: @escaping (ProcessorResult<Proc.Value>) -> ()) {
        tasks.set({ (dict : inout [Key : ProcessingState]) in dict[key] = .running })
        proc.start(key: key) { [weak self] (result) in
            self?.tasks.set({ (dict : inout [Key : ProcessingState]) in dict[key] = .completed })
            completion(result)
        }
    }
    
    public func processingState(key: Proc.Key) -> ProcessingState {
        return tasks.get()[key] ?? .none
    }
    
    public func cancel(key: Proc.Key) {
        if proc.cancel(key: key) {
            tasks.set({ (dict : inout [Key : ProcessingState]) in dict[key] = nil })
        }
    }
    
    public func cancelAll() {
        proc.cancelAll()
    }
    
}
