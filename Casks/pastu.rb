cask "pastu" do
  version "0.5.1"
  sha256 "23fa4d960421445be5fd97a3d459511a63e23c01f862c84f8b08f030616eb39d"

  url "https://github.com/keremeersoy/pastu/releases/download/v#{version}/Pastu-#{version}.zip"
  name "Pastu"
  desc "Local-first, privacy-focused clipboard manager"
  homepage "https://github.com/keremeersoy/pastu"

  depends_on arch: :arm64
  depends_on macos: :sequoia

  app "Pastu.app"

  zap trash: [
    "~/Library/Application Support/Pastu",
    "~/Library/Preferences/io.github.keremeersoy.Pastu.plist",
  ]

  caveats <<~EOS
    Pastu is not notarized yet. On first launch, allow it in
    System Settings > Privacy & Security > Open Anyway.
    Pasting needs the Accessibility permission.
  EOS
end
