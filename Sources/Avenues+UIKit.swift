#if os(iOS) || os(tvOS)
    import UIKit

//    public typealias UIImageAvenue = Avenue<IndexPath, UIImage>
    
    public func UIImageAvenue(indexPathToURL: @escaping (IndexPath) -> URL,
                              onError: @escaping (Error, IndexPath) -> () = { _ in },
                              onStateChange: @escaping (IndexPath) -> ()) -> Avenue<IndexPath, UIImage> {
        let sessionLane = URLSessionFetcher<IndexPath, UIImage>(getURL: indexPathToURL)
        let storage = AvenueStorage<IndexPath, UIImage>.nsCache()
        return Avenue<IndexPath, UIImage>.ui(storage: storage,
                                             lane: sessionLane,
                                             onError: onError,
                                             onStateChange: onStateChange)
    }
    
#endif