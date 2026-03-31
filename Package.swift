// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DeskerHK",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "DeskerHK", targets: ["DeskerHK"]),
    ],
    dependencies: [
        .package(url: "https://github.com/supabase/supabase-swift", from: "2.0.0"),
    ],
    targets: [
        .target(
            name: "DeskerHK",
            dependencies: [.product(name: "Supabase", package: "supabase-swift")],
            path: ".",
            exclude: ["Package.swift", "App", ".git"],
            sources: ["Models", "Repositories", "Resources", "Services", "ViewModels", "Views"]
        ),
    ]
)
