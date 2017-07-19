#if os(iOS) || os(tvOS) || os(watchOS)
    import UIKit
#elseif os(macOS)
    import AppKit
#endif


#if os(iOS) || os(tvOS)

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
        
        public let nscache: NSCache<NSURL, UIImage>
        
        public init(processor: Processor<URL, UIImage>) {
            let cache = NSCache<NSURL, UIImage>()
            self.nscache = cache
            let storage: Storage<URL, UIImage> = NSCacheStorage<NSURL, UIImage>(cache: cache)
                .mapKey({ $0 as NSURL })
            super.init(storage: storage,
                       processor: processor,
                       callbackMode: .mainQueue)
        }
        
        public convenience init(urlSessionConfiguration: URLSessionConfiguration = .default) {
            let session = URLSession(configuration: urlSessionConfiguration)
            let sessionLane = URLSessionProcessor(session: session).mapImage()
            self.init(processor: sessionLane)
        }
        
        public func prepareImage(for url: URL, force: Bool = false) {
            internal_prepareItem(for: url, storingTo: url, force: force)
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
