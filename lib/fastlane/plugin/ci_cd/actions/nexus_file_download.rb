module Fastlane
  module Actions
    class NexusFileDownloadAction < Action
      def self.run(params)
        require 'uri'
        require 'net/http'
        
        artefact_path = params[:artefact_path]
        target_file_path = params[:target_file_path]
        repository = params[:repository]
        nexus_username = params[:nexus_username]
        nexus_password = params[:nexus_password]
        nexus_url = params[:nexus_url]
        
        uri = URI("#{nexus_url}repository/#{repository}/#{artefact_path}")
        
        # Get directory from file path
        target_directory = File.dirname(target_file_path)
        FileUtils.mkdir_p(target_directory) unless File.directory?(target_directory)
        
        UI.message("Downloading artefact from #{uri} to #{target_file_path}")
        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
          request = Net::HTTP::Get.new(uri)
          request.basic_auth(nexus_username, nexus_password)
          
          response = http.request(request)
          
          case response
          when Net::HTTPSuccess
            File.open(target_file_path, 'w+') do |file|
              file.write(response.body)
            end
            UI.success("Successfully downloaded artefact to #{target_file_path}")
          else
            UI.user_error!("Nexus Download failed with #{response.code}")
          end
        end
      end
      
      def self.description
        "Downloads an artefact from Nexus repository"
      end
      
      def self.authors
        ["Gerald Bartz"]
      end
      
      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :artefact_path,
                                       env_name: "NEXUS_ARTEFACT_PATH",
                                       description: "Path to the artefact in Nexus repository. E.g. \"de/gematik/OpenSSL-Swift/4.3.2/OpenSSL_6_f647ffd.xcframework.zip\"",
                                       optional: false,
                                       verify_block: proc do |value|
                                         UI.user_error!("artefact_path cannot be nil") if value.nil?
                                         UI.user_error!("artefact_path cannot be empty") if value.to_s.strip.empty?
                                       end),
          FastlaneCore::ConfigItem.new(key: :target_file_path,
                                       env_name: "NEXUS_TARGET_FILE_PATH",
                                       description: "Local directory where the artefact will be saved",
                                       optional: false,
                                       verify_block: proc do |value|
                                         UI.user_error!("target_file_path cannot be nil") if value.nil?
                                         UI.user_error!("target_file_path cannot be empty") if value.to_s.strip.empty?
                                       end),
          FastlaneCore::ConfigItem.new(key: :repository,
                                       env_name: "NEXUS_REPOSITORY",
                                       description: "Nexus repository name. E.g. \"Apps\" or \"TestData\"",
                                       optional: true,
                                       default_value: "Apps"),
          FastlaneCore::ConfigItem.new(key: :nexus_username,
                                       env_name: "NEXUS_CREDENTIALS_USR",
                                       description: "Username for Nexus (must have read priviliges)",
                                       optional: false),
          FastlaneCore::ConfigItem.new(key: :nexus_password,
                                       env_name: "NEXUS_CREDENTIALS_PSW",
                                       description: "Password for Nexus",
                                       optional: false),
          FastlaneCore::ConfigItem.new(key: :nexus_url,
                                       env_name: "NEXUS_URL",
                                       description: "URL of the Nexus repository",
                                       optional: false,
                                       default_value: "https://nexus.prod.ccs.gematik.solutions/",
                                       verify_block: proc do |value|
                                         UI.user_error!("nexus_url cannot be empty") if value.to_s.strip.empty?
                                       end)
        ]
      end
      
      def self.is_supported?(platform)
        true
      end
    end
  end
end