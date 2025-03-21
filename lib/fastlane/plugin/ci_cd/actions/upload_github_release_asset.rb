require 'fastlane/action'
require 'fastlane_core/globals'
require 'fastlane_core/configuration/config_item'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?(:UI)

  module Actions
    class UploadGithubReleaseAssetAction < Action
      # rubocop:disable Metrics/PerceivedComplexity
      def self.run(params)
        require 'json'
        require 'uri'
        require 'net/http'

        owner = "gematik"
        github_project_name = params[:github_project_name].sub(/\.git$/, '')
        tag = params[:tag]
        asset_file = params[:asset_file]
        asset_name = params[:asset_name] || File.basename(asset_file)
        github_api_token = params[:github_api_token]

        UI.user_error!("TAG is not set!") if tag.empty?
        UI.user_error!("ASSET_FILE is not set!") if asset_file.empty?
        UI.user_error!("ASSET_FILE does not exist: #{asset_file}") unless File.exist?(asset_file)

        UI.message("Automatic ASSET_NAME: #{asset_name}") if params[:asset_name].nil?

        # Get release ID
        uri = URI("https://api.github.com/repos/#{owner}/#{github_project_name}/releases")
        req = Net::HTTP::Get.new(uri)
        req['Accept'] = 'application/vnd.github+json'
        req['Authorization'] = "Bearer #{github_api_token}"
        req['X-GitHub-Api-Version'] = '2022-11-28'

        res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(req) }
        json_result = JSON.parse(res.body)

        release_id = json_result.find { |release| release['tag_name'] == tag }&.dig('id')
        UI.user_error!("Could not find GitHub release for #{tag}!") unless release_id

        UI.message("RELEASE_ID: #{release_id} for TAG: #{tag}")

        # Upload asset
        uri = URI("https://uploads.github.com/repos/#{owner}/#{github_project_name}/releases/#{release_id}/assets?name=#{asset_name}")
        req = Net::HTTP::Post.new(uri)
        req['Accept'] = 'application/vnd.github+json'
        req['Authorization'] = "Bearer #{github_api_token}"
        req['X-GitHub-Api-Version'] = '2022-11-28'
        req['Content-Type'] = 'application/octet-stream'
        req.body = File.read(asset_file)

        UI.message("Now uploading asset: #{asset_file} to release: #{tag} with name: #{asset_name} ... please wait")
        res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(req) }

        if res.code == '201'
          UI.success("Upload OK!")
        else
          UI.user_error!("Upload failed! Response: #{res.body}")
        end
      end
      # rubocop:enable Metrics/PerceivedComplexity

      def self.description
        "Uploads an asset to a GitHub release"
      end

      def self.authors
        ["Gerald Bartz"]
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :github_project_name,
                                       env_name: "GITHUB_PROJECT_NAME",
                                       description: "GitHub project name (.git suffix is optional). E.g. \"OpenSSL-Swift\"",
                                       optional: false),
          FastlaneCore::ConfigItem.new(key: :tag,
                                       env_name: "TAG",
                                       description: "GitHub Release tag to upload the asset to",
                                       optional: false),
          FastlaneCore::ConfigItem.new(key: :asset_file,
                                       env_name: "ASSET_FILE",
                                       description: "(Local path to the asset file",
                                       optional: false),
          FastlaneCore::ConfigItem.new(key: :asset_name,
                                       env_name: "ASSET_NAME",
                                       description: "Name of the asset when uploaded (defaults to the asset's filename)",
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :github_api_token,
                                       env_name: "GITHUB_API_TOKEN",
                                       description: "GitHub access token (needs the necessary write permission). Hint: Could be of form \"ghp_...\"",
                                       optional: false,
                                       verify_block: proc do |value|
                                                       UI.user_error!("GitHub access token cannot be empty") if value.to_s.empty?
                                                     end)
        ]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
