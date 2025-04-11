require 'fastlane/action'
require 'fastlane_core/configuration/config_item'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?(:UI)

  module Actions
    class TeamsEntraIdAccessTokenAction < Action
      def self.run(params)
        scope = params[:scope]
        tenant_id = params[:tenant_id]
        grant_type = params[:grant_type]
        client_id = params[:client_id]
        client_secret = params[:client_secret]

        require 'net/http'
        require 'uri'

        uri = URI.parse("https://login.microsoftonline.com/#{tenant_id}/oauth2/v2.0/token")
        request = Net::HTTP::Post.new(uri)
        request.content_type = "application/x-www-form-urlencoded"

        request.set_form_data(
          "client_id" => client_id,
          "client_secret" => client_secret,
          "grant_type" => grant_type,
          "scope" => scope
        )

        req_options = {
          use_ssl: uri.scheme == "https"
        }

        response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
          http.request(request)
        end

        if response.code.to_i == 200
          UI.message("🍾 EntraID API request successful")
          json = JSON.parse(response.body)
          json["access_token"]

        else
          UI.message("⚠️ An error occurred")
          UI.message("Status code: #{response.code.to_i}")
          UI.message(response.body.to_s)
          UI.user_error!("⚠️ An error occurred")
        end
      end

      def self.description
        "Retrieves an access token from Microsoft Entra ID for Microsoft Teams."
      end

      def self.authors
        ["Gerald Bartz"]
      end

      def self.return_value
        "Returns the access token as a string."
      end

      def self.details
        "Use this action to obtain an access token from Microsoft Entra ID for Microsoft Teams using the client credentials flow."
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :scope,
                                       description: "The scope for the access token request",
                                       default_value: "https://service.flow.microsoft.com//.default",
                                       optional: false),
          FastlaneCore::ConfigItem.new(key: :tenant_id,
                                       env_name: "TEAMS_AUTH_TENANT_ID",
                                       description: "The tenant ID for the Microsoft Entra ID",
                                       optional: false),
          FastlaneCore::ConfigItem.new(key: :grant_type,
                                       description: "The grant type for the access token request",
                                       default_value: "client_credentials",
                                       optional: false),
          FastlaneCore::ConfigItem.new(key: :client_id,
                                       env_name: "TEAMS_AUTH_CLIENT_USR",
                                       description: "The client ID for the Microsoft Entra ID application",
                                       optional: false),
          FastlaneCore::ConfigItem.new(key: :client_secret,
                                       env_name: "TEAMS_AUTH_CLIENT_PSW",
                                       description: "The client secret for the Microsoft Entra ID application",
                                       optional: false)
        ]
      end

      def self.is_supported?(platform)
        [:ios, :mac].include?(platform)
      end
    end
  end
end
