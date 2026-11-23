cask "pastu" do
  version "0.3.0"
  sha256 "550c3f85161651e1bf1546505c9293eceda730da25a2e678e1c39111bce218f0"

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
