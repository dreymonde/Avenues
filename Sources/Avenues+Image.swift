#if os(iOS) || os(tvOS) || os(watchOS)
    import UIKit
#elseif os(macOS)
    import AppKit
#endif


#if os(iOS) || os(tvOS)

//    public typealias UIImageAvenue = Avenue<IndexPath, UIImage>
    
    public func UIImageAvenue_Legacy() -> AsymmetricalAvenue<IndexPath, URL, UIImage> {
        let sessionLane: Processor<URL, UIImage> = URLSessionProcessor()
            .mapImage()
        let storage: Storage<IndexPath, UIImage> = NSCacheStorage<NSIndexPath, UIImage>()
            .mapKey({ $0 as NSIndexPath })
        return AsymmetricalAvenue<IndexPath, URL, UIImage>(storage: storage,
                                          processor: sessionLane,
                                          callbackMode: .mainQueue)
    }
    
    public protocol UIImageAvenueDelegate : class {
        
        func avenue(_ avenue: UIImageAvenue, didFetchImageWith url: URL)
        func avenue(_ avenue: UIImageAvenue, didFailToFetchImageWith url: URL, error: Error)
        
    }
    
    public final class UIImageAvenue : ProtoAvenue<URL, URL, UIImage> {
        
        public weak var delegate: UIImageAvenueDelegate?
        
        override final func didChangeState(forKey key: URL) {
            delegate?.avenue(self, didFetchImageWith: key)
        }
        
        override final func didFail(with error: Error, key: URL) {
            delegate?.avenue(self, didFailToFetchImageWith: key, error: error)
        }
        
        public init(urlSessionConfiguration: URLSessionConfiguration = .default) {
            let session = URLSession(configuration: urlSessionConfiguration)
            let sessionLane = URLSessionProcessor(session: session).mapImage()
            let storage: Storage<URL, UIImage> = NSCacheStorage<NSURL, UIImage>()
                .mapKey({ $0 as NSURL })
            super.init(storage: storage,
                       processor: sessionLane,
                       callbackMode: .mainQueue)
        }
    
    }
    
#endif

#if os(iOS) || os(tvOS) || os(watchOS)
    
    public extension ProcessorProtocol where Value == Data {
        
        func mapImage() -> Processor<Key, UIImage> {
            return mapValue(UIImage.fromData)
        }
        
    }

    public enum UIImageDataConversionError : Error {
        case cannotConvertFromData
    }
    
    extension UIImage {
        
        internal static func fromData(_ data: Data) throws -> UIImage {
            if let image = self.init(data: data) {
                return image
            } else {
                throw UIImageDataConversionError.cannotConvertFromData
            }
        }
        
    }


#endif

#if os(macOS)

    public extension ProcessorProtocol where Value == Data {
        
        func mapImage() -> Processor<Key, NSImage> {
            return mapValue(NSImage.fromData)
        }
        
    }
    
    public enum NSImageDataConversionError : Error {
        case cannotConvertFromData
    }
    
    extension NSImage {
        
        internal static func fromData(_ data: Data) throws -> NSImage {
            if let image = self.init(data: data) {
                return image
            } else {
                throw NSImageDataConversionError.cannotConvertFromData
            }
        }
        
    }

#endif
