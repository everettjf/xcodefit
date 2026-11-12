cask "xcodefit" do
  arch arm: "-arm64", intel: ""

  version "1.0.8"
  sha256 arm: "93175e0a69fa8c94c38baf192efacbfbf2fafcce2ec6c7464621e389981533ba",
         intel: "21ef163c13c1616016a55e930db1a03232d53f9dae59d5528852d197fead001c"

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
