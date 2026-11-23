cask "pastu" do
  version "0.2.0"
  sha256 "3182a1448a16226727dd9c10bd8c11afbc33ca3dea031b8f63b99593accaf5dd"

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
