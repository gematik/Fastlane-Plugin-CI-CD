require 'fastlane/action'
require 'fastlane_core/configuration/config_item'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?(:UI)

  module Actions
    class TeamsSendAdaptiveCardAction < Action
      def self.run(params)
        require 'json'

        adaptive_card = params[:adaptive_card]
        url = params[:url]
        webhook_url = params[:webhook_url]

        scope = params[:scope]
        tenant_id = params[:tenant_id]
        grant_type = params[:grant_type]
        client_id = params[:client_id]
        client_secret = params[:client_secret]

        access_token = other_action.teams_entra_id_access_token(
          scope:,
          tenant_id:,
          grant_type:,
          client_id:,
          client_secret:
        )
        destination = other_action.teams_channel_or_chat_destination(url:)

        payload = {
          "type" => "message",
          "attachments" => [
            {
              "destination" => destination,
              "contentType" => "application/vnd.microsoft.card.adaptive",
              "content" => adaptive_card
            }
          ]
        }.to_json

        UI.message("Will send payload: #{payload}")

        # Post to channel/chat
        uri = URI.parse(webhook_url.to_s)
        request = Net::HTTP::Post.new(uri)
        request.content_type = "application/json"
        request["Authorization"] = "Bearer #{access_token}"
        request.body = payload.to_s

        req_options = {
          use_ssl: uri.scheme == "https"
        }

        response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
          http.request(request)
        end

        if response.code.to_i == 202
          UI.message("🍾 Send to channel/chat request successful")
          UI.message("Status code: #{response.code.to_i}")
          UI.message(response.body.to_s)
          true
        else
          UI.message("⚠️ An error occurred")
          UI.message("Status code: #{response.code.to_i}")
          UI.message(response.body.to_s)
          UI.user_error!("⚠️ An error occurred")
          false
        end
      end

      def self.description
        "Sends a request to a Microsoft Teams channel or chat. adaptive_card must be a JSON string."
      end

      def self.authors
        ["Gerald Bartz"]
      end

      def self.return_value
        ""
      end

      def self.details
        "Use this action to send a request to a Microsoft Teams channel or chat. adaptive_card must be a JSON string."
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :adaptive_card,
                                       description: "The adaptive card (a json that contains an element \"type\": \"AdaptiveCard\") to send to the channel/chat",
                                       optional: false),
          FastlaneCore::ConfigItem.new(key: :url,
                                       description: "URL of the channel (or chat)",
                                       optional: false),
          FastlaneCore::ConfigItem.new(key: :webhook_url,
                                       env_name: "TEAMS_WORKFLOW_WEBHOOK",
                                       description: "The workflow webhook URL for posting into gematik Teams channel/chat",
                                       optional: false),
          # For Entra ID access token:
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
