lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "configruous/version"

Gem::Specification.new do |spec|
  spec.name          = "configruous"
  spec.version       = Configruous::VERSION
  spec.authors       = ["Randy D. Wallace Jr."]
  spec.email         = ["randy@edatasource.com"]

  spec.summary       = %q{Convert yaml or property files to SSM Parameters}
  #spec.description   = %q{TODO: Write a longer description or delete this line.}
  spec.homepage      = "https://configruo.us/"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end

  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "aws-sdk-ssm"
  spec.add_dependency "inifile"
  spec.add_dependency "hashdiff"

  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.5"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "factory_bot"
  spec.add_development_dependency "coveralls"
end
