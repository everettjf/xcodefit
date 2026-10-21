cask "xcodefit" do
  version "1.0.0"
  sha256 "b05e95e2314703d7d551ff91b78e1d6a62a0f38c0449497c59dea853c0d5c182"

  url "https://github.com/everettjf/homebrew-tap/releases/download/xcodefit-v#{version}/XcodeFit-#{version}.zip?build=3"
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
