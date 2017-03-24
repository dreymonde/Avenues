#if os(iOS) || os(watchOS) || os(tvOS)
    import UIKit
    import Foundation
#elseif os(macOS)
    import AppKit
    import Foundation
#endif

#if os(iOS) || os(watchOS) || os(tvOS) || os(macOS)
    
    public enum URLSessionProcessorError : Error {
        case responseIsNotHTTP(URLResponse?)
        case noData
    }
    
    public class URLSessionProcessor : ProcessorProtocol {
        
        public typealias Key = URL
        public typealias Value = Data
        
        fileprivate let validateResponse: (HTTPURLResponse) throws -> ()
        public let session: URLSession
        
        fileprivate(set) var running: Synchronized<[URL : URLSessionTask]> = Synchronized([:])
        public var runningTasks: [URL : URLSessionTask] {
            return running.get()
        }
        
        public init(session: URLSession = URLSession(configuration: .default),
                    validateResponse: @escaping (HTTPURLResponse) throws -> () = { _ in }) {
            self.session = session
            self.validateResponse = validateResponse
        }
        
        deinit {
            avenues_print("Deinit \(self)")
        }
        
        public func start(key url: URL, completion: @escaping (ProcessorResult<Value>) -> ()) {
            let task = session.dataTask(with: url) { [weak self] (data, response, error) in
                self?.didFinishTask(data: data, response: response, error: error, completion: completion)
            }
            running.set({ (dict: inout [URL : URLSessionTask]) in dict[url] = task })
            task.resume()
        }
        
        public func cancel(key: Key) {
            running.set { (dict: inout [URL : URLSessionTask]) in
                dict[key]?.cancel()
                dict[key] = nil
            }
        }
        
        public func processingState(key: Key) -> ProcessingState {
            if let task = running.get()[key] {
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
                                       completion: @escaping (ProcessorResult<Value>) -> ()) {
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
