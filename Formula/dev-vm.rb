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
  version "0.5.1"

  depends_on "gh"
  depends_on "lima"

  on_macos do
    on_arm do
      url "https://github.com/robsonpeixoto/dev-vm/releases/download/v#{version}/dev-vm_#{version}_darwin_arm64.tar.gz",
          using: GitHubPrivateReleaseDownloadStrategy
      sha256 "2c372648c3f1af875460e93c2c5a5b7ca290b8d99f638a4bd78961a50a44dea0"
    end
    on_intel do
      url "https://github.com/robsonpeixoto/dev-vm/releases/download/v#{version}/dev-vm_#{version}_darwin_amd64.tar.gz",
          using: GitHubPrivateReleaseDownloadStrategy
      sha256 "dd7f0d86f31c80b17f6bdf8f6a79f5c23dc32920fab9067e685388581d8f8e0c"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/robsonpeixoto/dev-vm/releases/download/v#{version}/dev-vm_#{version}_linux_arm64.tar.gz",
          using: GitHubPrivateReleaseDownloadStrategy
      sha256 "33a9f04b3a6496a894cb633c1e89770eebe1e5f7f6e23d646c061a875a8abd78"
    end
    on_intel do
      url "https://github.com/robsonpeixoto/dev-vm/releases/download/v#{version}/dev-vm_#{version}_linux_amd64.tar.gz",
          using: GitHubPrivateReleaseDownloadStrategy
      sha256 "e038c690ad2414cdae902297887808da6b025bb0d6cc0ae2b4ecd1a35383a63c"
    end
  end

  def install
    bin.install "dev-vm"
    bash_completion.install "completions/dev-vm.bash" => "dev-vm"
    zsh_completion.install "completions/dev-vm.zsh" => "_dev-vm"
    fish_completion.install "completions/dev-vm.fish"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/dev-vm version")
    assert_match "complete -F _dev_vm dev-vm", shell_output("#{bin}/dev-vm completion bash")
  end
end
