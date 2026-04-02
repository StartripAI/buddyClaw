import AppKit
import Foundation

public struct VerifiedSpriteCatalog {
    public static let expectedSpecies: [Species] = Species.allCases

    private static let spriteDirectories: [ArtStyle: [String]] = [
        .pixel: [
            "PixelSprites",
            "Resources/PixelSprites",
            // Development fallback while the repo finishes migrating.
            "RuntimeSprites",
            "Resources/RuntimeSprites",
        ],
        .claw: [
            "ClawSprites",
            "Resources/ClawSprites",
        ],
        .ascii: [],
    ]

    private let bundle: Bundle
    private let verifiedByStyle: [ArtStyle: Set<Species>]

    public init() {
        self.init(bundle: .module)
    }

    public init(bundle: Bundle) {
        self.bundle = bundle
        var verified: [ArtStyle: Set<Species>] = [.ascii: Set(Self.expectedSpecies)]

        for style in [ArtStyle.pixel, .claw] {
            verified[style] = Set(Self.expectedSpecies.filter { species in
                Self.loadValidatedSpriteURL(for: species, style: style, from: bundle) != nil
            })
        }

        self.verifiedByStyle = verified
    }

    public var availableStyles: [ArtStyle] {
        ArtStyle.allCases
    }

    // Identity uses the formal pixel release set as the canonical species pool.
    public var availableSpecies: [Species] {
        availableSpecies(for: .pixel)
    }

    public var defaultSpecies: Species {
        if isAvailable(style: .pixel, species: .cat) {
            return .cat
        }
        return availableSpecies.first ?? .cat
    }

    public func availableSpecies(for style: ArtStyle) -> [Species] {
        Self.expectedSpecies.filter { isAvailable(style: style, species: $0) }
    }

    public func spriteURL(for species: Species) -> URL? {
        spriteURL(for: species, style: .pixel)
    }

    public func spriteURL(for species: Species, style: ArtStyle) -> URL? {
        Self.loadValidatedSpriteURL(for: species, style: style, from: bundle)
    }

    public func isVerified(_ species: Species) -> Bool {
        isAvailable(style: .pixel, species: species)
    }

    public func isAvailable(style: ArtStyle, species: Species) -> Bool {
        if style == .ascii {
            return true
        }
        return verifiedByStyle[style]?.contains(species) == true
    }

    public func resolvedStyle(preferred: ArtStyle, species: Species) -> ArtStyle {
        if isAvailable(style: preferred, species: species) {
            return preferred
        }
        if isAvailable(style: .pixel, species: species) {
            return .pixel
        }
        if isAvailable(style: .claw, species: species) {
            return .claw
        }
        return .ascii
    }

    private static func loadValidatedSpriteURL(for species: Species, style: ArtStyle, from bundle: Bundle) -> URL? {
        guard style != .ascii else { return nil }

        for subdirectory in spriteDirectories[style] ?? [] {
            guard let url = bundle.url(forResource: species.rawValue, withExtension: "png", subdirectory: subdirectory),
                  let image = NSImage(contentsOf: url),
                  let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
                  cgImage.width == 1024,
                  cgImage.height == 256,
                  framesAreNonEmpty(in: cgImage) else {
                continue
            }
            return url
        }
        return nil
    }

    private static func framesAreNonEmpty(in cgImage: CGImage) -> Bool {
        guard let data = cgImage.dataProvider?.data else { return false }
        let ptr = CFDataGetBytePtr(data)!
        let bytesPerRow = cgImage.bytesPerRow
        let bytesPerPixel = max(1, cgImage.bitsPerPixel / 8)
        let frameWidth = cgImage.width / 4

        for frameIndex in 0..<4 {
            let startX = frameIndex * frameWidth
            var foundOpaquePixel = false

            for y in 0..<cgImage.height {
                for x in 0..<frameWidth {
                    let offset = y * bytesPerRow + (startX + x) * bytesPerPixel
                    let alpha = alphaValue(at: offset, alphaInfo: cgImage.alphaInfo, ptr: ptr, bytesPerPixel: bytesPerPixel)
                    if alpha > 8 {
                        foundOpaquePixel = true
                        break
                    }
                }
                if foundOpaquePixel { break }
            }

            if !foundOpaquePixel {
                return false
            }
        }

        return true
    }

    private static func alphaValue(
        at offset: Int,
        alphaInfo: CGImageAlphaInfo,
        ptr: UnsafePointer<UInt8>,
        bytesPerPixel: Int
    ) -> UInt8 {
        switch alphaInfo {
        case .premultipliedLast, .last, .noneSkipLast:
            return ptr[offset + min(3, bytesPerPixel - 1)]
        case .premultipliedFirst, .first, .noneSkipFirst, .alphaOnly:
            return ptr[offset]
        case .none:
            return 255
        @unknown default:
            return ptr[offset + min(3, bytesPerPixel - 1)]
        }
    }
}
