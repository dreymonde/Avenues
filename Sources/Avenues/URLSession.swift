
import Foundation

#if os(iOS) || os(watchOS) || os(tvOS) || os(macOS)
    
    public enum URLSessionProcessorError : Error {
        case responseIsNotHTTP(URLResponse?)
        case noData
    }
    
    public class URLSessionProcessor : ProcessorProtocol {
                
        public let validateResponse: (HTTPURLResponse) throws -> ()
        public let session: URLSession
        
        fileprivate(set) var running: Synchronized<[URL : URLSessionTask]> = Synchronized([:])
        public var runningTasks: [URL : URLSessionTask] {
            return running.read()
        }
        
        public init(session: URLSession, validateResponse: @escaping (HTTPURLResponse) throws -> () = { _ in }) {
            self.session = session
            self.validateResponse = validateResponse
        }
        
        public init(sessionConfiguration: URLSessionConfiguration,
                    validateResponse: @escaping (HTTPURLResponse) throws -> () = { _ in }) {
            self.session = URLSession(configuration: sessionConfiguration)
            self.validateResponse = validateResponse
        }
        
        public convenience init() {
            self.init(sessionConfiguration: .default)
        }
        
        deinit {
            print("Deinit \(self)")
        }
        
        public func start(key url: URL, completion: @escaping (ProcessorResult<Data>) -> ()) {
            let task = session.dataTask(with: url) { [weak self] (data, response, error) in
                self?.didFinishTask(data: data, response: response, error: error, completion: completion)
            }
            running.write(with: { $0[url] = task })
            task.resume()
        }
        
        public func cancel(key: URL) {
            running.write(with: {
                $0[key]?.cancel()
                $0[key] = nil
            })
        }
        
        public func processingState(key: URL) -> ProcessingState {
            if let task = running.read()[key] {
                switch task.state {
                case .running, .canceling:
                    return .running
                case .completed:
                    return .completed
                case .suspended:
                    return .none
                }
            }
            return .none
        }
        
        public func cancelAll() {
            session.invalidateAndCancel()
        }
        
        fileprivate func didFinishTask(data: Data?,
                                       response: URLResponse?,
                                       error: Error?,
                                       completion: @escaping (ProcessorResult<Data>) -> ()) {
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(URLSessionProcessorError.responseIsNotHTTP(response)))
                return
            }
            do {
                try self.validateResponse(httpResponse)
                guard let data = data else {
                    throw URLSessionProcessorError.noData
                }
                completion(.success(data))
            } catch {
                completion(.failure(error))
            }
        }
        
    }
    
#endif

