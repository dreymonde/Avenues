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
    
    public enum URLSessionAvenueLaneError : Error {
        case responseIsNotHTTP(URLResponse?)
        case noData
    }
    
    public class URLSessionAvenueLane<Key : Hashable, Value> : AvenueLaneProtocol {
        
        fileprivate let transformValue: (Data) throws -> Value
        fileprivate let getURL: (Key) -> URL?
        fileprivate let validateResponse: (HTTPURLResponse) throws -> ()
        public let session: URLSession
        
        public fileprivate(set) var running: Synchronized<[Key : URLSessionTask]> = Synchronized([:])
        
        public init(session: URLSession = .shared,
                    getURL: @escaping (Key) -> URL?,
                    validateResponse: @escaping (HTTPURLResponse) throws -> () = { _ in },
                    transform: @escaping (Data) throws -> Value) {
            self.session = session
            self.getURL = getURL
            self.validateResponse = validateResponse
            self.transformValue = transform
        }
        
        public func start(key: Key, completion: @escaping (AvenueLaneResult<Value>) -> ()) {
            guard let url = getURL(key) else {
                return
            }
            let task = session.dataTask(with: url) { [weak self] (data, response, error) in
                self?.didFinishTask(data: data, response: response, error: error, completion: completion)
            }
            running.set({ (dict: inout [Key : URLSessionTask]) in dict[key] = task })
            task.resume()
        }
        
        public func cancel(key: Key) {
            running.set { (dict: inout [Key : URLSessionTask]) in
                dict[key]?.cancel()
                dict[key] = nil
            }
        }
        
        public func isRunning(key: Key) -> Bool {
            return running.get()[key] != nil
        }
        
        fileprivate func didFinishTask(data: Data?,
                                       response: URLResponse?,
                                       error: Error?,
                                       completion: @escaping (AvenueLaneResult<Value>) -> ()) {
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(URLSessionAvenueLaneError.responseIsNotHTTP(response)))
                return
            }
            do {
                try self.validateResponse(httpResponse)
                guard let data = data else {
                    throw URLSessionAvenueLaneError.noData
                }
                let value = try self.transformValue(data)
                completion(.success(value))
            } catch {
                completion(.failure(error))
            }
        }
        
    }
    
    public extension URLSessionAvenueLane where Value : DataConvertible {
        
        convenience init(session: URLSession = .shared,
                         getURL: @escaping (Key) -> URL?,
                         validateResponse: @escaping (HTTPURLResponse) throws -> () = { _ in }) {
            self.init(session: session,
                      getURL: getURL,
                      validateResponse: validateResponse,
                      transform: Value.fromData)
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

