cask "xcodesize" do
  version "1.0.0"
  sha256 "2a08970e3e80fc77ec20d4b28754fe45e7e4b8c683e8b98da3e6cded242a164e"

  url "https://github.com/everettjf/homebrew-tap/releases/download/xcodesize-v#{version}/XcodeSize-#{version}.zip?build=2"
  name "XcodeSize"
  desc "Inspect and clean Xcode storage"
  homepage "https://github.com/everettjf/homebrew-tap#xcodesize"

  livecheck do
    url :url
    regex(/^xcodesize-v(\d+(?:\.\d+)+)$/i)
    strategy :github_releases
  end

  depends_on macos: :sonoma

  app "XcodeSize.app"

  zap trash: [
    "~/Library/Preferences/com.xcodesize.app.plist",
    "~/Library/Saved Application State/com.xcodesize.app.savedState",
  ]
end
