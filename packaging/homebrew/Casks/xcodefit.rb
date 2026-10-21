cask "xcodefit" do
  version "1.0.2"
  sha256 "41bd2f2d3abff14451f0bb3a63bf1e85351f557b8345bae02dc5a2ee8b5920a7"

  url "https://github.com/everettjf/homebrew-tap/releases/download/xcodefit-v#{version}/XcodeFit-#{version}.zip"
  name "XcodeFit"
  desc "Give Xcode storage a checkup and clean with care"
  homepage "https://xnu.app/xcodefit/"

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
