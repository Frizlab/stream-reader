// swift-tools-version:5.2
import PackageDescription


let package = Package(
	name: "stream-reader",
	products: [
		.library(name: "StreamReader", targets: ["StreamReader"])
	],
	dependencies: {
		var ret = [Package.Dependency]()
#if !canImport(System)
		ret.append(.package(url: "https://github.com/apple/swift-system.git", from: "1.0.0"))
#endif
		return ret
	}(),
	targets: [
		.target(name: "StreamReader", dependencies: {
			var ret = [Target.Dependency]()
#if !canImport(System)
			ret.append(.product(name: "SystemPackage", package: "swift-system"))
#endif
			return ret
		}()),
		.testTarget(name: "StreamReaderTests", dependencies: ["StreamReader"])
	]
)
