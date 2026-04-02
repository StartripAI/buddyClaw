import AppKit
import Foundation

let expectedSpecies: [String] = [
    "axolotl", "blob", "cactus", "capybara", "cat", "chonk",
    "dragon", "duck", "ghost", "goose", "mushroom", "octopus",
    "owl", "penguin", "rabbit", "robot", "snail", "turtle",
]

let frameWidth = 256
let frameHeight = 256
let baselineTolerance = 32
let minimumOpaquePixels = 128

struct StyleValidationTarget {
    let label: String
    let root: URL
    let required: Bool
}

func projectRoot() -> URL {
    let arguments = CommandLine.arguments
    if let rootIndex = arguments.firstIndex(of: "--project-root"), arguments.indices.contains(rootIndex + 1) {
        return URL(fileURLWithPath: arguments[rootIndex + 1], isDirectory: true)
    }
    return URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
}

func alphaValue(
    at offset: Int,
    alphaInfo: CGImageAlphaInfo,
    bytes: UnsafePointer<UInt8>,
    bytesPerPixel: Int
) -> UInt8 {
    switch alphaInfo {
    case .premultipliedLast, .last, .noneSkipLast:
        return bytes[offset + min(3, bytesPerPixel - 1)]
    case .premultipliedFirst, .first, .noneSkipFirst, .alphaOnly:
        return bytes[offset]
    case .none:
        return 255
    @unknown default:
        return bytes[offset + min(3, bytesPerPixel - 1)]
    }
}

func frameMetrics(in cgImage: CGImage, frameIndex: Int) -> (opaquePixels: Int, baseline: Int?) {
    guard let data = cgImage.dataProvider?.data,
          let bytes = CFDataGetBytePtr(data) else {
        return (0, nil)
    }

    let bytesPerRow = cgImage.bytesPerRow
    let bytesPerPixel = max(1, cgImage.bitsPerPixel / 8)
    let startX = frameIndex * frameWidth
    var opaquePixels = 0
    var baseline: Int?

    for y in 0..<frameHeight {
        for x in 0..<frameWidth {
            let offset = y * bytesPerRow + (startX + x) * bytesPerPixel
            let alpha = alphaValue(
                at: offset,
                alphaInfo: cgImage.alphaInfo,
                bytes: bytes,
                bytesPerPixel: bytesPerPixel
            )
            if alpha > 8 {
                opaquePixels += 1
                baseline = max(baseline ?? y, y)
            }
        }
    }

    return (opaquePixels, baseline)
}

func validateSprite(named species: String, in root: URL) -> [String] {
    let url = root.appendingPathComponent("\(species).png")
    guard let image = NSImage(contentsOf: url),
          let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        return ["missing or unreadable PNG"]
    }

    var issues: [String] = []
    if cgImage.width != frameWidth * 4 || cgImage.height != frameHeight {
        issues.append("expected 1024x256, got \(cgImage.width)x\(cgImage.height)")
    }

    switch cgImage.alphaInfo {
    case .none:
        issues.append("missing alpha channel")
    default:
        break
    }

    var baselines: [Int] = []
    for frameIndex in 0..<4 {
        let metrics = frameMetrics(in: cgImage, frameIndex: frameIndex)
        if metrics.opaquePixels < minimumOpaquePixels {
            issues.append("frame \(frameIndex + 1) has only \(metrics.opaquePixels) opaque pixels")
        }
        if let baseline = metrics.baseline {
            baselines.append(baseline)
        } else {
            issues.append("frame \(frameIndex + 1) has no opaque content")
        }
    }

    if let minBaseline = baselines.min(),
       let maxBaseline = baselines.max(),
       maxBaseline - minBaseline > baselineTolerance {
        issues.append("baseline drift \(maxBaseline - minBaseline)px exceeds \(baselineTolerance)px")
    }

    return issues
}

func validateDirectory(_ target: StyleValidationTarget) -> Bool {
    let fileManager = FileManager.default
    guard let runtimeFiles = try? fileManager.contentsOfDirectory(at: target.root, includingPropertiesForKeys: nil) else {
        if target.required {
            fputs("error: could not read \(target.label) directory at \(target.root.path)\n", stderr)
            return false
        }
        print("SKIP \(target.label): directory missing at \(target.root.path)")
        return true
    }

    let actualPNGs = Set(
        runtimeFiles
            .filter { $0.pathExtension.lowercased() == "png" }
            .map { $0.deletingPathExtension().lastPathComponent }
    )

    if actualPNGs.isEmpty {
        if target.required {
            fputs("error: \(target.label) contains no PNG assets.\n", stderr)
            return false
        }
        print("SKIP \(target.label): no PNG assets present")
        return true
    }

    let expectedPNGs = Set(expectedSpecies)
    if actualPNGs != expectedPNGs {
        let missing = expectedPNGs.subtracting(actualPNGs).sorted()
        let extras = actualPNGs.subtracting(expectedPNGs).sorted()
        if missing.isEmpty == false {
            print("missing \(target.label) sprites: \(missing.joined(separator: ", "))")
        }
        if extras.isEmpty == false {
            print("unexpected \(target.label) sprites: \(extras.joined(separator: ", "))")
        }
        return false
    }

    var failed = false
    for species in expectedSpecies {
        let issues = validateSprite(named: species, in: target.root)
        if issues.isEmpty {
            print("PASS \(target.label) \(species)")
        } else {
            failed = true
            print("FAIL \(target.label) \(species): \(issues.joined(separator: " | "))")
        }
    }

    if failed {
        return false
    }

    print("Validated \(expectedSpecies.count) \(target.label) sprites in \(target.root.path)")
    return true
}

let root = projectRoot()
let pixelRoot = root.appendingPathComponent("Sources/DesktopBuddy/Resources/PixelSprites", isDirectory: true)
let clawRoot = root.appendingPathComponent("Sources/DesktopBuddy/Resources/ClawSprites", isDirectory: true)

let pixelOK = validateDirectory(StyleValidationTarget(label: "Pixel", root: pixelRoot, required: true))
let clawOK = validateDirectory(StyleValidationTarget(label: "Claw", root: clawRoot, required: false))

print("ASCII style uses code rendering and does not require PNG validation.")

if pixelOK && clawOK {
    exit(0)
}

exit(1)
