require "download_strategy"
require "utils/github"

# Downloads a release asset from a private GitHub repository.
# Credentials come from HOMEBREW_GITHUB_API_TOKEN, the `gh` CLI login, or the
# macOS keychain (in that order).
class GitHubPrivateReleaseDownloadStrategy < CurlDownloadStrategy
  def initialize(url, name, version, **meta)
    super
    match = url.match(%r{^https://github\.com/([^/]+)/([^/]+)/releases/download/([^/]+)/(.+)$})
    raise CurlDownloadStrategyError.new(url, "not a GitHub release URL") if match.nil?

    @owner, @repo, @tag, @filename = match.captures
  end

  private

  def _fetch(url:, resolved_url:, timeout:)
    token = GitHub::API.credentials
    if token.blank?
      message = "no GitHub credentials: set HOMEBREW_GITHUB_API_TOKEN or run `gh auth login`"
      raise CurlDownloadStrategyError.new(url, message)
    end

    curl_download asset_url,
                  "--header", "Accept: application/octet-stream",
                  "--header", "Authorization: Bearer #{token}",
                  to: temporary_path, timeout: timeout
  end

  def asset_url
    release = GitHub::API.open_rest("https://api.github.com/repos/#{@owner}/#{@repo}/releases/tags/#{@tag}")
    asset = release["assets"].find { |a| a["name"] == @filename }
    raise CurlDownloadStrategyError.new(url, "#{@filename} not in release #{@tag}") if asset.nil?

    asset["url"]
  end
end

class DevVm < Formula
  desc "Isolated Lima dev VM for macOS with rootless Docker and GitHub SSH"
  homepage "https://github.com/robsonpeixoto/dev-vm"
  version "0.2.0"

  depends_on "gh"
  depends_on "lima"

  on_macos do
    on_arm do
      url "https://github.com/robsonpeixoto/dev-vm/releases/download/v#{version}/dev-vm_#{version}_darwin_arm64.tar.gz",
          using: GitHubPrivateReleaseDownloadStrategy
      sha256 "2031e67e74339709194a22c85708dbd49dadc13784dedfb6e100fbfd4aeef748"
    end
    on_intel do
      url "https://github.com/robsonpeixoto/dev-vm/releases/download/v#{version}/dev-vm_#{version}_darwin_amd64.tar.gz",
          using: GitHubPrivateReleaseDownloadStrategy
      sha256 "33ae04e28962c9a7fa43b2604aa4e64242ee3fefd8bd6b253a4bd873b005385c"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/robsonpeixoto/dev-vm/releases/download/v#{version}/dev-vm_#{version}_linux_arm64.tar.gz",
          using: GitHubPrivateReleaseDownloadStrategy
      sha256 "339baca3a221cd1d425847cedf6af5b38f475c1db2e9d68898fc11be01a6ff39"
    end
    on_intel do
      url "https://github.com/robsonpeixoto/dev-vm/releases/download/v#{version}/dev-vm_#{version}_linux_amd64.tar.gz",
          using: GitHubPrivateReleaseDownloadStrategy
      sha256 "bc1f411d5dcedbbc675698ebd212ff750f59c289ce9e2b3992b8f345345d2ead"
    end
  end

  def install
    bin.install "dev-vm"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/dev-vm version")
  end
end
