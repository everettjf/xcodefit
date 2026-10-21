cask "xcodefit" do
  arch arm: "-arm64", intel: ""

  version "1.0.5"
  sha256 arm: "40090b7cbb8662533d75f60d612a4c55f13c6f4aece96002e353effb31a73c9e",
         intel: "4f2cbf83ae0d1332c1e2b846a12fd6536bcae4f490c608ec5c339f5438609095"

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
