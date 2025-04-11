require 'fastlane/action'
require 'fastlane_core/configuration/config_item'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?(:UI)

  module Actions
    class TeamsChannelOrChatDestinationAction < Action
      def self.run(params)
        url = params[:url]
        channel_id = self.parse_and_decode_channel_id(url)
        group_id = self.parse_group_id(url)
        chat_id = self.parse_and_decode_chat_id(url)

        message_card_destination = {}

        if channel_id && group_id
          message_card_destination = {
            "destinationType" => "channel",
            "channel" => {
              "channelId" => channel_id,
              "groupId" => group_id
            }
          }
        elsif chat_id
          message_card_destination = {
            "destinationType" => "groupChat",
            "groupChat" => {
              "chatId" => chat_id
            }
          }
        else
          UI.user_error!("⚠️ URL could not be parsed (channel ID, group ID, or chat ID not found)")
        end

        message_card_destination
      end

      def self.parse_and_decode_channel_id(url)
        require 'uri'
        match = url.match(%r{/channel/([^/]+)})
        if match
          channel_id = match[1]
          URI.decode_www_form_component(channel_id)
        end
      end

      def self.parse_group_id(url)
        require 'uri'
        match = url.match(/groupId=([^&]+)/)
        match ? match[1] : nil
      end

      def self.parse_and_decode_chat_id(url)
        require 'uri'
        match = url.match(%r{/message/([^/]+)})
        if match
          chat_id = match[1]
          URI.decode_www_form_component(chat_id)
        end
      end

      def self.description
        "Parses the URL to extract channel or chat destination information for Microsoft Teams."
      end

      def self.authors
        ["Gerald Bartz"]
      end

      def self.return_value
        "Returns a hash with the destination information."
      end

      def self.details
        "This action parses a Microsoft Teams URL to extract channel or chat IDs and returns the destination information as a hash(!)."
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :url,
                                       description: "The URL of the Microsoft Teams channel or chat",
                                       optional: false)
        ]
      end

      def self.is_supported?(platform)
        [:ios, :mac].include?(platform)
      end
    end
  end
end
