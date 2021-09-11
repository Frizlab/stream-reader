// swift-tools-version:5.2
import PackageDescription



let package = Package(
	name: "stream-reader",
	products: [
		.library(name: "StreamReader", targets: ["StreamReader"])
	],
	dependencies: [
		.package(url: "https://github.com/apple/swift-system.git", from: "1.0.0")
	],
	targets: [
		.target(name: "StreamReader", dependencies: [.product(name: "SystemPackage", package: "swift-system")]),
		.testTarget(name: "StreamReaderTests", dependencies: ["StreamReader"])
	]
)
