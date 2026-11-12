cask "xcodefit" do
  arch arm: "-arm64"

  version "1.0.9"
  sha256 arm:   "92a5922d1e5a91400aa00ed852dec40ebc299701c891db2aef3cd2fde65012fe",
         intel: "1d236b0ba8cead54d931df25e7572a34d3cdb50c957559a987a66a172fb66346"

  url "https://github.com/everettjf/homebrew-tap/releases/download/xcodefit-v#{version}/XcodeFit-#{version}#{arch}.zip"
  name "XcodeFit"
  desc "Give Xcode storage a checkup and clean with care"
  homepage "https://atomsprout.com/xcodefit/"

  livecheck do
    url :url
    regex(/^xcodefit-v(\d+(?:\.\d+)+)$/i)
    strategy :github_releases
  end

  depends_on macos: :sonoma

  app "XcodeFit.app"

  zap trash: [
    "~/Library/Preferences/com.xcodefit.app.plist",
    "~/Library/Saved Application State/com.xcodefit.app.savedState",
  ]
end
