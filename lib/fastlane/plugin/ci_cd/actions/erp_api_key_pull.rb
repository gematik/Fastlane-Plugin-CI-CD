require 'fastlane/action'
require 'fastlane_core/configuration/config_item'
require 'fastlane_core/ui/ui'

require 'csv'
require 'fileutils'
require 'open-uri'

module Fastlane
  module Actions
    class ErpApiKeyPullAction < Action
      # rubocop:disable Require/MissingRequireStatement
      def self.run(params)
        gitlab_https_base_url = params[:gitlab_https_base_url]
        version = params[:version]
        fd_environments = params[:fd_environments]
        output_file = params[:output_file]
        gitlab_api_token = params[:gitlab_api_token]

        api_keys = []
        api_keys.push("# Version dependent API keys for version #{version}")

        # FD, GitLab project ID: 961
        fd_environments.split(',').map(&:strip).each do |environment|
          api_key = run_for_environment(gitlab_https_base_url, version, environment, 961, gitlab_api_token)
          api_key_line = "ERP_IBM_#{environment}_X_API_KEY=\"#{api_key}\""
          api_keys.push(api_key_line)
          if environment.include?("RU")
            api_key_line = "ERP_IBM_#{environment}_DEV_X_API_KEY=\"#{api_key}\""
            api_keys.push(api_key_line)
          end
        end

        File.open(output_file, 'w') do |file|
          api_keys.each do |api_key|
            file.puts(api_key)
          end
        end

        UI.success("Collected API keys for version #{version} and saved to #{output_file}")
      end
      # rubocop:enable Require/MissingRequireStatement

      def self.run_for_environment(gitlab_https_base_url, version, environment, project_id, gitlab_api_token)
        url = "#{gitlab_https_base_url}/api/v4/projects/#{project_id}/repository/files/#{environment}.csv/raw?ref=main"

        headers = { "PRIVATE-TOKEN" => gitlab_api_token }
        csv_content = OpenURI.open_uri(url, headers).read

        # Step 2 & 3: Read the CSV and find the rows
        api_key = ''
        CSV.parse(csv_content, headers: true) do |row|
          if row['Bemerkung'] && row['Bemerkung'].include?(version)
            api_key = row['API Key']
          end

          break if api_key != '' # Stop searching key was found
        end

        # Check if both API key was found
        if api_key.empty?
          raise "Error: Couldn't find the API key for the specified version \"#{version}\"."
        end

        # Step 4: Return
        api_key
      end

      def self.description
        "Collects API keys from CSV files in the repository for a given version and outputs them to a single file."
      end

      # rubocop:disable Metrics/PerceivedComplexity
      def self.available_options
        [
          FastlaneCore::ConfigItem.new(
            key: :gitlab_https_base_url,
            env_name: "GITLAB_HTTPS_BASE_URL",
            description: "Base URL for the GitLab API",
            optional: false
          ),
          FastlaneCore::ConfigItem.new(
            key: :version,
            description: "A version substring to look for in the Bemerkung column, e.g. 'iOS 1.0.0' or 'Huawei 1.23.0'",
            verify_block: proc do |value|
              UI.user_error!("No version for GetApiKeysAction given, pass using `version: 'iOS 1.0.0'`") unless value && !value.empty?
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :fd_environments,
            description: "An array of environment abbreviations, e.g. 'TU,RU,PU'",
            verify_block: proc do |value|
              UI.user_error!("No fd_environments for GetApiKeysAction given, pass using `fd_environments: 'TU,RU,PU'`") unless value && !value.empty?
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :gitlab_api_token,
            description: "API token for accessing the restricted repository in GitLab",
            verify_block: proc do |value|
              UI.user_error!("No API token value for GetApiKeysAction given, pass using `gitlab_api_token: '...'`") unless value && !value.empty?
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :output_file,
            description: "The file to output the collected API keys to",
            verify_block: proc do |value|
              UI.user_error!("No output file for GetApiKeysAction given, pass using `output_file: 'path/to/output.txt'`") unless value && !value.empty?
            end
          )
        ]
      end
      # rubocop:enable Metrics/PerceivedComplexity

      def self.authors
        ["Gerald Bartz"]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
