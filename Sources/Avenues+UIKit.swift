#if os(iOS) || os(tvOS)
    import UIKit
#elseif os(macOS)
    import AppKit
#endif


#if os(iOS) || os(tvOS)

//    public typealias UIImageAvenue = Avenue<IndexPath, UIImage>
    
    public func UIImageAvenue(indexPathToURL: @escaping (IndexPath) -> URL) -> Avenue<IndexPath, UIImage> {
        let sessionLane: Processor<IndexPath, UIImage> = URLSessionProcessor()
            .mapKey(indexPathToURL)
            .mapImage()
        let storage: Storage<IndexPath, UIImage> = NSCacheStorage<NSIndexPath, UIImage>()
            .mapKey({ $0 as NSIndexPath })
        return Avenue<IndexPath, UIImage>(storage: storage,
                                          processor: sessionLane,
                                          callbackMode: .mainQueue)
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
