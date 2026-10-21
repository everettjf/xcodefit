cask "xcodefit" do
  arch arm: "-arm64", intel: ""

  version "1.0.7"
  sha256 arm: "b68752416246f90fc4ae85fabfa9a7fda31dd8627177272af2719b25f9475a2a",
         intel: "de4f6d30dbf52d09443165cc0e080c4aee26136d3b99991b56e784f71c4779ba"

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
