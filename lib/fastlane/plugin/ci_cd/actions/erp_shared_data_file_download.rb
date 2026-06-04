require 'fastlane/action'
require 'fastlane_core/configuration/config_item'
require 'fastlane_core/ui/ui'
require 'open-uri'
require 'fileutils'
require 'cgi'

module Fastlane
  module Actions
    class ErpSharedDataFileDownloadAction < Action
      # rubocop:disable Require/MissingRequireStatement
      def self.run(params)
        gitlab_https_base_url = params[:gitlab_https_base_url]
        gitlab_api_token = params[:gitlab_api_token]
        remote_file_path = params[:remote_file_path]
        output_file = params[:output_file]
        ref = params[:ref]

        encoded_path = CGI.escape(remote_file_path)
        url = "#{gitlab_https_base_url}/api/v4/projects/833/repository/files/#{encoded_path}/raw?ref=#{ref}"

        begin
          UI.message("Downloading file from #{url} ...")
          headers = { "PRIVATE-TOKEN" => gitlab_api_token }

          FileUtils.mkdir_p(File.dirname(output_file))

          # Stream download to support binary files without corrupting them.
          File.open(output_file, 'wb') do |out_file|
            OpenURI.open_uri(url, 'rb', headers) do |remote|
              IO.copy_stream(remote, out_file)
            end
          end

          UI.success("Downloaded \"#{remote_file_path}\" to #{output_file}")
        rescue StandardError => e
          UI.error("An error occurred: #{e.message}")
          raise "Failed to download the file: #{e.message}"
        end
      end
      # rubocop:enable Require/MissingRequireStatement

      def self.description
        "Downloads a (binary) file from the ERP Shared Data Repository into a local path."
      end

      def self.authors
        ["Gerald Bartz"]
      end

      def self.details
        "Looks up a file under the given path in the ERP Shared Data GitLab repository (project 833) and downloads/copies it (binary-safe) into the specified path of the calling repository."
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
            key: :gitlab_api_token,
            description: "API token for accessing the restricted repository in GitLab",
            verify_block: proc do |value|
              UI.user_error!("No API token value for ErpSharedDataFileDownloadAction given, pass using `gitlab_api_token: '...'`") unless value && !value.empty?
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :remote_file_path,
            description: "Path of the file inside the ERP Shared Data Repository (e.g. 'input/health_insurance_contacts.csv')",
            verify_block: proc do |value|
              UI.user_error!("No remote_file_path for ErpSharedDataFileDownloadAction given, pass using `remote_file_path: 'path/in/repo/file.bin'`") unless value && !value.empty?
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :output_file,
            description: "Local path (in the calling repository) where the downloaded file should be saved",
            verify_block: proc do |value|
              UI.user_error!("No output_file for ErpSharedDataFileDownloadAction given, pass using `output_file: 'path/to/output.bin'`") unless value && !value.empty?
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :ref,
            description: "Git branch, tag or commit to download the file from (default: 'main')",
            default_value: "main",
            optional: true
          )
        ]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
