cask "xcodefit" do
  arch arm: "-arm64", intel: ""

  version "1.0.4"
  sha256 arm: "29651de1e019ff8f42dd867e10ef7c0603c00556a1365b1a95bd254ba4c6573f",
         intel: "63c9d065f31dfe8bfa89d076daa4cd7ec348957c9b4d0eca659b4b21eb4433ba"

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
