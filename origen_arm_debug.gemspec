# coding: utf-8
config = File.expand_path('../config', __FILE__)
require "#{config}/version"

Gem::Specification.new do |spec|
  spec.name          = 'origen_arm_debug'
  spec.version       = OrigenARMDebug::VERSION
  spec.authors       = ["Ronnie Lajaunie"]
  spec.email         = ["ronnie.lajaunie@nxp.com"]
  spec.summary       = "Provides an Origen API to perform register read and write operations via the ARM_DEBUG protocol."
  spec.homepage      = "http://origen-sdk.org/origen_arm_debug"
  spec.license       = 'MIT'

#  spec.required_ruby_version     = '>= 1.9.3'
#  spec.required_rubygems_version = '>= 1.8.11'

  # Only the files that are hit by these wildcards will be included in the
  # packaged gem, the default should hit everything in most cases but this will
  # need to be added to if you have any custom directories
  spec.files         = Dir["lib/**/*.rb", "templates/**/*", "config/**/*.rb",
                           "bin/*", "lib/tasks/**/*.rake", "pattern/**/*.rb",
                           "program/**/*.rb"
                          ]
  spec.executables   = []
  spec.require_paths = ["lib"]

  # Add any gems that your plugin needs to run within a host application
  spec.add_runtime_dependency 'origen', '~>0.7', '>= 0.7.36'
  spec.add_runtime_dependency 'origen_jtag', '~>0.17', '>= 0.17.0'
  spec.add_runtime_dependency 'origen_swd', '~>1', '>= 1.1.0'
end
