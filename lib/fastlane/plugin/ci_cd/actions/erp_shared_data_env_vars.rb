require 'fastlane/action'
require 'fastlane_core/configuration/config_item'
require 'fastlane_core/ui/ui'
require 'fileutils'
require 'open-uri'

module Fastlane
  module Actions
    class ErpSharedDataEnvVarsAction < Action
      # rubocop:disable Require/MissingRequireStatement
      def self.run(params)
        gitlab_https_base_url = params[:gitlab_https_base_url]
        environments = params[:environments]
        gitlab_api_token = params[:gitlab_api_token]
        output_file = params[:output_file]
        url = "#{gitlab_https_base_url}/api/v4/projects/833/repository/files/app_configuration_environment%2Fdevelopment.env/raw?ref=main"

        env_vars = []

        headers = { "PRIVATE-TOKEN" => gitlab_api_token }
        content = OpenURI.open_uri(url, headers).read

        # Filter variables by given environments
        allowed_environments = ['TU', 'RU', 'PU', 'GEMATIK_DEV', 'GEMATIK_QS', 'GEMATIK_PROD']
        environments.split(',').map(&:strip).each do |environment|
          unless allowed_environments.include?(environment)
            UI.error("Allowed environments are: #{allowed_environments.join(', ')}")
            raise "Error: environment #{environment} not allowed"
          end

          content.each_line do |line|
            if line.include?(environment)
              env_vars.push(line)
            end
          end
        end

        # Write to output_file
        File.open(output_file, 'w') do |file|
          env_vars.each do |env_var|
            file.puts(env_var)
          end
        end

        UI.success("Collected environment variables for \"#{environments}\" and saved to #{output_file}")
      end
      # rubocop:enable Require/MissingRequireStatement

      def self.description
        "Collects environment variables from *.env files in the repository and outputs them to a file."
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(
            key: :gitlab_https_base_url,
            env_name: "GITLAB_HTTPS_BASE_URL",
            description: "Base URL for the GitLab API",
            optional: false
          ),
          FastlaneCore::ConfigItem.new(
            key: :environments,
            description: "An array of environment abbreviations, e.g. 'TU,RU,PU,GEMATIK_QS'",
            verify_block: proc do |value|
              UI.user_error!("No environment abbreviations for ErpSharedDataEnvVarsAction given, pass using `environments: 'TU,RU,PU,GEMATIK_QS'`") unless value && !value.empty?
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :gitlab_api_token,
            description: "API token for accessing the restricted repository in GitLab",
            verify_block: proc do |value|
              UI.user_error!("No API token value for ErpSharedDataEnvVarsAction given, pass using `gitlab_api_token: '...'`") unless value && !value.empty?
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :output_file,
            description: "The file to output the collected environment variables keys to",
            verify_block: proc do |value|
              UI.user_error!("No output file for PullEnvironmentVariblesIntoFileAction given, pass using `output_file: 'path/to/output.txt'`") unless value && !value.empty?
            end
          )
        ]
      end

      def self.authors
        ["Gerald Bartz"]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
