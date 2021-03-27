// swift-tools-version:5.1
import PackageDescription



let package = Package(
	name: "stream-reader",
	products: [
		.library(name: "StreamReader", targets: ["StreamReader"])
	],
	dependencies: [
		.package(url: "https://github.com/apple/swift-system.git", from: "0.0.1")
	],
	targets: [
		.target(name: "StreamReader", dependencies: [.product(name: "SystemPackage", package: "swift-system")]),
		.testTarget(name: "StreamReaderTests", dependencies: ["StreamReader"])
	]
)
