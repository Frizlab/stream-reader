// swift-tools-version:5.1
import PackageDescription



let package = Package(
	name: "SimpleStream",
	products: [
		.library(name: "SimpleStream", targets: ["SimpleStream"])
	],
	targets: [
		.target(name: "SimpleStream", dependencies: []),
		.testTarget(name: "SimpleStreamTests", dependencies: ["SimpleStream"])
	]
)
