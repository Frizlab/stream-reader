// swift-tools-version:5.1
import PackageDescription



let package = Package(
	name: "SimpleStream",
	products: [
		.library(name: "SimpleStream", targets: ["SimpleStream"])
	],
	dependencies: [
		.package(url: "https://github.com/apple/swift-system.git", from: "0.0.1")
	],
	targets: [
		.target(name: "SimpleStream", dependencies: [.product(name: "SystemPackage", package: "swift-system")]),
		.testTarget(name: "SimpleStreamTests", dependencies: ["SimpleStream"])
	]
)
