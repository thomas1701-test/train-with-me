import UIKit

// MARK: - Cache

final class ImageCache {
    static let shared = ImageCache()

    private let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 100
        c.totalCostLimit = 50 * 1024 * 1024 // 50 MB
        return c
    }()

    func get(_ key: String) -> UIImage? { cache.object(forKey: key as NSString) }
    func set(_ image: UIImage, for key: String) { cache.setObject(image, forKey: key as NSString) }
    func remove(_ key: String) { cache.removeObject(forKey: key as NSString) }

    func load(fileName: String) async -> UIImage? {
        if let cached = get(fileName) { return cached }

        return await Task.detached(priority: .userInitiated) {
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(fileName)
            guard let image = UIImage(contentsOfFile: url.path) else { return nil }
            self.set(image, for: fileName)
            return image
        }.value
    }
}

// MARK: - CachedAsyncImage

import SwiftUI

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let fileName: String
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @State private var uiImage: UIImage? = nil

    init(
        fileName: String,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.fileName    = fileName
        self.content     = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let uiImage {
                content(Image(uiImage: uiImage))
            } else {
                placeholder()
            }
        }
        .task(id: fileName) {
            uiImage = await ImageCache.shared.load(fileName: fileName)
        }
    }
}//
//  ImageCache.swift
//  Train with Me
//
//  Created by Thomas on 09.05.26.
//

