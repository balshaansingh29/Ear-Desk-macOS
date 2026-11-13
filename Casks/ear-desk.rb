cask "ear-desk" do
  version "1.8.0"
  sha256 "7e1b8bc5e35ca22252e0661e8361eb82c5ab1c1b31cef04c7855279bb390ffde"

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
