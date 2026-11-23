cask "pastu" do
  version "0.4.0"
  sha256 "0fd22589668b3f688972a314f003a48aadb6800bae50537c03723d48b9f97055"

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
