$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'simplecov'

# SimpleCov.minimum_coverage 95
SimpleCov.start
# This module is only used to check the environment is currently a testing env
module SpecHelper
end

require 'fastlane' # to import the Action super class
require 'fastlane/plugin/ci_cd' # import the actual plugin
require 'rspec'

Fastlane.load_actions # load other actions (in case your plugin calls other actions or shared values)

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"
  config.expect_with(:rspec) do |c|
    c.syntax = :expect
  end
end
