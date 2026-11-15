cask "xcodefit" do
  arch arm: "-arm64"

  version "1.0.10"
  sha256 arm:   "a953785e38e5ca0f90a0396bb4b04d58f99290ce129fa5e92b56335bc152bd7f",
         intel: "75d635aaead9f6409302b2d54b2b9797317ef3e6f6463bbe6b8959169e6b029c"

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
