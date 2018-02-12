//
//  Avenues+Images.swift
//  Avenues
//
//  Created by Олег on 12.02.2018.
//  Copyright © 2018 Avenues. All rights reserved.
//

#if os(iOS) || os(tvOS)
    import UIKit
#elseif os(watchOS)
    import WatchKit
#elseif os(macOS)
    import AppKit
#endif


#if os(iOS) || os(tvOS)
    
    public func UIImageAvenue() -> Avenue<URL, UIImage> {        
        let sessionLane = URLSessionProcessor(sessionConfiguration: .default)
            .mapImage()
        let memoryCache: MemoryCache<URL, UIImage> = NSCacheCache<NSURL, UIImage>()
            .mapKeys({ $0 as NSURL })
        return Avenue(cache: memoryCache, processor: sessionLane)
    }
    
#endif

#if os(iOS) || os(tvOS) || os(watchOS)
    
    public extension ProcessorProtocol where Value == Data {
        
        func mapImage() -> Processor<Key, UIImage> {
            return mapValues(UIImage.fromData)
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

#if os(iOS) || os(tvOS)
    
    extension Avenue where Value == UIImage {
        
        public func register(_ imageView: UIImageView, for resourceKey: Key) {
            self.register(imageView, for: resourceKey, setup: { (view, image) in
                view.image = image
            })
        }
        
    }
    
#endif

#if os(watchOS)
    
    extension Avenue where Value == UIImage {
        
        public func register(_ interfaceImage: WKInterfaceImage, for resourceKey: Key) {
            self.register(interfaceImage, for: resourceKey, setup: { (interface, image) in
                interface.setImage(image)
            })
        }
        
    }

#endif

#if os(macOS)
    
    extension Avenue where Value == NSImage {
        
        public func register(_ imageView: NSImageView, for resourceKey: Key) {
            self.register(imageView, for: resourceKey, setup: { (view, image) in
                view.image = image
            })
        }
        
    }
    
    public extension ProcessorProtocol where Value == Data {
        
        func mapImage() -> Processor<Key, NSImage> {
            return mapValues(NSImage.fromData)
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

