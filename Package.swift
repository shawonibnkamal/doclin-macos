// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "Doclin", platforms: [.macOS(.v13)], products: [.executable(name: "Doclin", targets: ["Doclin"])], targets: [.target(name: "DoclinCore"), .executableTarget(name: "Doclin", dependencies: ["DoclinCore"]), .executableTarget(name: "DoclinChecks", dependencies: ["DoclinCore"], path: "Tests/DoclinCoreTests")])
