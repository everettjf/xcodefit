cask "xcodefit" do
  arch arm: "-arm64", intel: ""

  version "1.0.3"
  sha256 arm: "31a56ed57fe10cc386eb49f4d0160ea2f757e4e1e4c17f9c685458a3572a01b7",
         intel: "af970cd6a90a96d3d50627bbbb2b5be35e345c3c18bdbbb6be7de3c3ac806812"

  url "https://github.com/everettjf/homebrew-tap/releases/download/xcodefit-v#{version}/XcodeFit-#{version}#{arch}.zip"
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
