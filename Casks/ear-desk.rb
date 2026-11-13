cask "ear-desk" do
  version "1.8.1"
  sha256 "f55807cad12d864eb5159a7f8a29ec94f7e36fd3a9ecb4630f859b1ee4c8899b"

  url "https://github.com/balshaansingh29/Ear-Desk-macOS/releases/download/v#{version}/Ear-Desk-macOS-v#{version}.dmg"
  name "Ear-Desk"
  desc "Native menu bar companion for Nothing and CMF audio gear on macOS"
  homepage "https://github.com/balshaansingh29/Ear-Desk-macOS"

  auto_updates true
  depends_on macos: ">= :ventura"

  app "Ear-Desk.app"

  zap trash: [
    "~/Library/Preferences/app.eardesk.mac.plist",
    "~/Library/Application Support/Ear-Desk",
    "~/Library/Caches/app.eardesk.mac",
  ]
end
