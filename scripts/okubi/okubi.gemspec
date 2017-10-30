# coding: utf-8
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "okubi/version"

Gem::Specification.new do |spec|
  spec.name          = "okubi"
  spec.version       = Okubi::VERSION
  spec.authors       = ["The Frontside (frontside.io)"]
  spec.email         = ["joe@frontside.io"]

  spec.summary       = %q{Internal tool for deploying FOLIO Open Library Platform to Kubernetes/GKE}
  spec.description   = %q{Internal tool for deploying FOLIO Open Library Platform to Kubernetes/GKE}
  spec.homepage      = "https://www.github.com/thefrontside/folio-deployment/tree/master/scripts/okubi"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  # spec.files         = `git ls-files -z`.split("\x0").reject do |f|
  spec.files           = Dir["**/*"].reject do |f|
    File.directory?(f) || f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "bin"
  spec.executables   = spec.files.grep(%r{^bin/okubi}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.15"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency 'pry-byebug'

  spec.add_runtime_dependency 'require_all'
  spec.add_runtime_dependency 'kubeclient'
  spec.add_runtime_dependency 'clamp'
  spec.add_runtime_dependency 'tty-spinner'
  spec.add_runtime_dependency 'tty-command'
  spec.add_runtime_dependency 'tty-prompt'
  spec.add_runtime_dependency 'pastel'
  spec.add_runtime_dependency 'dotenv'
  spec.add_runtime_dependency 'psych'
  spec.add_runtime_dependency 'multi_json'
  spec.add_runtime_dependency 'hashugar'
  spec.add_runtime_dependency 'configatron'
  spec.add_runtime_dependency 'dnsimple'
  spec.add_runtime_dependency 'net-ping'
  spec.add_runtime_dependency 'ssl-test'
  spec.add_runtime_dependency 'tilt'
end
