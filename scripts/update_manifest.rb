#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "fileutils"
require "open-uri"

DEFAULT_MANIFEST_PATH = "bucket/tg.json"
REPO = "pzoln/tg"
WINDOWS_TARGETS = {
  "64bit" => "x86_64-pc-windows-msvc.tar.gz",
  "arm64" => "aarch64-pc-windows-msvc.tar.gz",
}.freeze

def prompt_version
  $stdout.print("Release version (e.g. 0.1.0-beta.3): ")
  $stdin.gets&.strip.to_s
end

def normalize_version(value)
  value.to_s.strip.sub(/\Atg-v/, "")
end

def fetch_checksums(tag)
  sums_url = "https://github.com/#{REPO}/releases/download/#{tag}/#{tag}-SHA256SUMS.txt"
  [URI.open(sums_url).read, sums_url]
rescue OpenURI::HTTPError => error
  abort("Failed to download #{sums_url}: #{error.message}")
rescue SocketError, SystemCallError => error
  abort("Failed to reach #{sums_url}: #{error.message}")
end

def checksum_for(contents, archive)
  contents.each_line do |line|
    checksum, file = line.strip.split(/\s+/, 2)
    next unless checksum && file

    return checksum if file.sub(/\A\*/, "") == archive
  end

  nil
end

def release_filename(tag, suffix)
  "#{tag}-#{suffix}"
end

def release_url(tag, filename)
  "https://github.com/#{REPO}/releases/download/#{tag}/#{filename}"
end

def release_entry(tag, suffix, checksum)
  filename = release_filename(tag, suffix)

  {
    "url" => release_url(tag, filename),
    "hash" => checksum,
    "extract_dir" => File.basename(filename, ".tar.gz"),
  }
end

def autoupdate_entry(suffix)
  filename = release_filename("tg-v$version", suffix)
  escaped_suffix = Regexp.escape(suffix)

  {
    "url" => release_url("tg-v$version", filename),
    "extract_dir" => File.basename(filename, ".tar.gz"),
    "hash" => {
      "url" => release_url("tg-v$version", "tg-v$version-SHA256SUMS.txt"),
      "find" => "^([a-fA-F0-9]{64})\\s+tg-v$version-#{escaped_suffix}$",
    },
  }
end

def build_architecture(tag, checksums_text, sums_url)
  architecture = {}

  WINDOWS_TARGETS.each do |arch, suffix|
    checksum = checksum_for(checksums_text, release_filename(tag, suffix))
    next unless checksum

    architecture[arch] = release_entry(tag, suffix, checksum)
  end

  abort("Missing Windows checksum entries in #{sums_url}") if architecture.empty?
  architecture
end

def build_autoupdate
  WINDOWS_TARGETS.each_with_object({}) do |(arch, suffix), architecture|
    architecture[arch] = autoupdate_entry(suffix)
  end
end

def build_manifest(version, architecture)
  {
    "version" => version,
    "description" => "Text diagram editor for the terminal",
    "homepage" => "https://github.com/#{REPO}",
    "license" => "Apache-2.0",
    "architecture" => architecture,
    "bin" => "tg.exe",
    "checkver" => {
      "url" => "https://api.github.com/repos/#{REPO}/releases?per_page=1",
      "jsonpath" => "$[0].tag_name",
      "regex" => "^tg-v(.+)$",
    },
    "autoupdate" => {
      "architecture" => build_autoupdate,
    },
  }
end

version = normalize_version(ARGV[0].nil? ? prompt_version : ARGV[0])
abort("Release version is required.") if version.empty?

manifest_path = ARGV.fetch(1, DEFAULT_MANIFEST_PATH)
tag = "tg-v#{version}"
checksums_text, sums_url = fetch_checksums(tag)
architecture = build_architecture(tag, checksums_text, sums_url)
manifest = build_manifest(version, architecture)

FileUtils.mkdir_p(File.dirname(manifest_path))
File.write(manifest_path, "#{JSON.pretty_generate(manifest)}\n")
puts "Updated #{manifest_path} for #{tag}"
