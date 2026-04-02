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
            exclude: [
                "Package.swift", "App", ".git", "Resources/Assets.xcassets",
                "README.md", "project.yml",
                "SUPPLEMENTAL_SCHEMA.sql", "SUPABASE_SCHEMA.sql", "FRESH_START.sql",
                "SUPABASE_EXPLORE_DESKS_RLS.sql", "SUPABASE_DELETE_ACCOUNT_RPC.sql", "QUICK_FIX_AUTH_TRIGGER.sql",
            ],
            sources: ["Models", "Repositories", "Resources", "Services", "ViewModels", "Views"]
        ),
    ]
)
