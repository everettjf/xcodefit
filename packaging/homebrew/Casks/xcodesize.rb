cask "xcodesize" do
  version "1.0.0"
  sha256 "e05f52c9cde9400cbfb70489c30b3e3b7d59de4623cb41cf373ef0fd9b90a95b"

  url "https://github.com/everettjf/homebrew-tap/releases/download/xcodesize-v#{version}/XcodeSize-#{version}.zip"
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
