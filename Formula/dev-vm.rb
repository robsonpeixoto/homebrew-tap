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
  version "0.9.0"

  depends_on "gh"
  depends_on "lima"

  on_macos do
    on_arm do
      url "https://github.com/robsonpeixoto/dev-vm/releases/download/v#{version}/dev-vm_#{version}_darwin_arm64.tar.gz",
          using: GitHubPrivateReleaseDownloadStrategy
      sha256 "291983b1a6f74dc01e4f854dbc4eb72bd6400057c380cdab8be584b5ae3c8441"
    end
    on_intel do
      url "https://github.com/robsonpeixoto/dev-vm/releases/download/v#{version}/dev-vm_#{version}_darwin_amd64.tar.gz",
          using: GitHubPrivateReleaseDownloadStrategy
      sha256 "3bdc27995bd7092843e9f460612e8d7b5615bc240847c9bbbc05a89aee286fc7"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/robsonpeixoto/dev-vm/releases/download/v#{version}/dev-vm_#{version}_linux_arm64.tar.gz",
          using: GitHubPrivateReleaseDownloadStrategy
      sha256 "3878d548df8a73de876b73950e2b344f21ccf813a2bc11ebfddf0a4801c4b858"
    end
    on_intel do
      url "https://github.com/robsonpeixoto/dev-vm/releases/download/v#{version}/dev-vm_#{version}_linux_amd64.tar.gz",
          using: GitHubPrivateReleaseDownloadStrategy
      sha256 "c417b8554e2daafc79a8afd57ef1c638d32a625ac7ef392b49eb5c17c830e742"
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
