cask "pastu" do
  version "0.5.0"
  sha256 "70bc3c4f384551df6c912f6ba6dbe4c36383c327827aa9cc73bb464a8c1c4f50"

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
