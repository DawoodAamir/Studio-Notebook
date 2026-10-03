// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "NotebookCore", platforms: [.macOS("27.0"), .iOS("27.0")],
  products: [.library(name: "NotebookCore", targets: ["NotebookCore"])],
  targets: [
    .target(name: "NotebookCore", path: "Sources/Core"),
    .testTarget(name: "NotebookCoreTests", dependencies: ["NotebookCore"], path: "Tests/Core"),
  ])
