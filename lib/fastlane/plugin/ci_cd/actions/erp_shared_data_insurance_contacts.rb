require 'fastlane/action'
require 'fastlane_core/configuration/config_item'
require 'open-uri'
require 'fileutils'
require 'fastlane_core/ui/ui'

require 'csv'
require 'json'

module Fastlane
  module Actions
    class ErpSharedDataInsuranceContactsAction < Action
      # rubocop:disable Require/MissingRequireStatement
      def self.run(params)
        gitlab_https_base_url = params[:gitlab_https_base_url]
        gitlab_api_token = params[:gitlab_api_token]
        replace_file_path = params[:replace_file_path]
        transform_to_json_format = params[:transform_to_json_format]
        # The file is stored in project 833, path input/health_insurance_contacts.csv
        csv_url = "#{gitlab_https_base_url}/api/v4/projects/833/repository/files/input%2Fhealth_insurance_contacts.csv/raw?ref=main"

        begin
          # Download the CSV file
          UI.message("Downloading CSV file from #{csv_url} ...")
          headers = { "PRIVATE-TOKEN" => gitlab_api_token }
          csv_content = OpenURI.open_uri(csv_url, headers).read

          # Write to a temporary file
          Dir.mktmpdir do |tmpdir|
            input_csv_file_path = File.join(tmpdir, "health_insurance_contacts.csv")
            File.write(input_csv_file_path, csv_content)

            if transform_to_json_format
              UI.message("Transforming CSV to JSON...")
              transformed_file_path = File.join(tmpdir, "health_insurance_contacts.json")
              csv_data = CSV.read(input_csv_file_path, headers: true, col_sep: ';', skip_blanks: true)
              # Replace nil values with empty strings
              json_array = csv_data.map { |row| row.to_h.transform_values { |v| v.nil? ? "" : v } }
              File.write(transformed_file_path, JSON.pretty_generate(json_array))
              new_contents = File.read(transformed_file_path)
            else
              UI.message("No transformation CSV to JSON performed")
              new_contents = File.read(input_csv_file_path)
            end

            File.open(replace_file_path, "w") { |file| file.puts(new_contents) }
            UI.message("File replaced successfully: #{replace_file_path}")
          end
        rescue StandardError => e
          UI.error("An error occurred: #{e.message}")
          raise "Failed to process the CSV file: #{e.message}"
        end
      end
      # rubocop:enable Require/MissingRequireStatement

      def self.description
        "Handle data from ERP Shared Data Repository"
      end

      def self.authors
        ["sigabrtz"]
      end

      def self.return_value
        # If your method provides a return value, you can describe here what it does
      end

      def self.details
        # Optional:
        "Handle data from ERP Shared Data Repository"
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
              UI.user_error!("No API token value for ErpSharedDataInsuranceContactsAction given, pass using `gitlab_api_token: '...'`") unless value && !value.empty?
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :replace_file_path,
            description: "(Local) path of the file to be replaced",
            optional: false
          ),
          FastlaneCore::ConfigItem.new(
            key: :transform_to_json_format,
            description: "Perform transformation to JSON format? true/false (default: true)",
            default_value: false,
            type: Boolean,
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
