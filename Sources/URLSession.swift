#if os(iOS) || os(watchOS) || os(tvOS)
    import UIKit
    import Foundation
#elseif os(macOS)
    import AppKit
    import Foundation
#endif

#if os(iOS) || os(watchOS) || os(tvOS) || os(macOS)
    
    public protocol DataConvertible {
        
        static func fromData(_ data: Data) throws -> Self
        
    }
    
    extension Data : DataConvertible {
        
        public static func fromData(_ data: Data) throws -> Data {
            return data
        }
        
    }
    
    public enum URLSessionFetcherError : Error {
        case responseIsNotHTTP(URLResponse?)
        case noData
    }
    
    public class URLSessionFetcher : FetcherProtocol {
        
        public typealias Key = URL
        public typealias Value = Data
        
        fileprivate let validateResponse: (HTTPURLResponse) throws -> ()
        public let session: URLSession
        
        fileprivate(set) var running: Synchronized<[URL : URLSessionTask]> = Synchronized([:])
        public var runningTasks: [URL : URLSessionTask] {
            return running.get()
        }
        
        public init(session: URLSession = .shared,
                    validateResponse: @escaping (HTTPURLResponse) throws -> () = { _ in }) {
            self.session = session
            self.validateResponse = validateResponse
        }
        
        deinit {
            avenues_print("Deinit \(self)")
        }
        
        public func start(key url: URL, completion: @escaping (FetcherResult<Value>) -> ()) {
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
        
        public func fetchingState(key: Key) -> FetchingState {
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
        
        fileprivate func didFinishTask(data: Data?,
                                       response: URLResponse?,
                                       error: Error?,
                                       completion: @escaping (FetcherResult<Value>) -> ()) {
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(URLSessionFetcherError.responseIsNotHTTP(response)))
                return
            }
            do {
                try self.validateResponse(httpResponse)
                guard let data = data else {
                    throw URLSessionFetcherError.noData
                }
                completion(.success(data))
            } catch {
                completion(.failure(error))
            }
        }
        
        public func mapValue<Convertible : DataConvertible>() -> Fetcher<URL, Convertible> {
            return mapValue(Convertible.fromData)
        }
        
    }
        
#endif

#if os(iOS) || os(watchOS) || os(tvOS)
    
    public enum UIImageDataConversionError : Error {
        case cannotConvertFromData
    }
    
    extension UIImage : DataConvertible {
        
        public static func fromData(_ data: Data) throws -> Self {
            if let image = self.init(data: data) {
                return image
            } else {
                throw UIImageDataConversionError.cannotConvertFromData
            }
        }
        
    }
    
#endif

