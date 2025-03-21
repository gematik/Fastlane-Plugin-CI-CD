require 'net/http'
require 'uri'
require 'openssl'
require 'fastlane'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?(:UI)

  module Helper
    class HtmlContentFetcher
      def fetch_html_content(url)
        # Basic URL validation
        unless url =~ /\A#{URI::DEFAULT_PARSER.make_regexp(['http', 'https'])}\z/
          UI.error("Invalid URL: #{url}")
          return ""
        end

        uri = URI.parse(url)
        http = Net::HTTP.new(uri.host, uri.port)

        # Configure HTTP connection
        configure_http_connection(http, uri)

        # Create and configure the request
        request = create_request(uri, url)

        # Send the request and handle the response
        send_request_and_handle_response(http, request, url)
      rescue StandardError => e
        UI.error("Error fetching content from #{url}: #{e.message}")
        ""
      end

      private

      def fetch_gitlab_api_token
        ENV['GITLAB_API_TOKEN'] || prompt(text: "GITLAB_API_TOKEN not set, please specify")
      end

      def configure_http_connection(http, uri)
        # Enable HTTPS if the URL uses HTTPS
        if uri.scheme == 'https'
          http.use_ssl = true
          http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        end

        # Set reasonable timeouts
        http.open_timeout = 10  # seconds
        http.read_timeout = 30  # seconds
      end

      def create_request(uri, url)
        request = Net::HTTP::Get.new(uri.request_uri)

        # Add the GitLab token if needed
        if url.include?('gitlab')
          request["PRIVATE-TOKEN"] = fetch_gitlab_api_token
        end

        # Add standard headers
        request["User-Agent"] = "Fastlane-AuditGenerator/1.0"
        request["Accept"] = "text/html,application/xhtml+xml"

        request
      end

      def send_request_and_handle_response(http, request, url)
        response = http.request(request)

        case response
        when Net::HTTPSuccess
          response.body
        when Net::HTTPRedirection
          UI.important("Redirected to #{response['location']}. Following...")
          fetch_html_content(response['location'], nil)  # Don't pass token on redirect for security
        else
          UI.error("Failed to fetch content from #{url}: #{response.code} #{response.message}")
          ""
        end
      end
    end
  end
end
