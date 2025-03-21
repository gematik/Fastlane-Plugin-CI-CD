require 'nokogiri'
require_relative 'html_content_fetcher'

module Fastlane
  module Helper
    class SpecFetcher
      def initialize(audit_afos_json)
        @audit_afos_json = audit_afos_json
        @html_fetcher = Fastlane::Helper::HtmlContentFetcher.new
      end

      def fetch_specs
        spec_urls = @audit_afos_json['specs']
        fetch_spec_htmls(spec_urls)
      end

      private

      def fetch_spec_htmls(spec_urls)
        spec_urls.each_with_object({}) do |(spec, url), spec_htmls|
          html_content = @html_fetcher.fetch_html_content(url)
          spec_htmls[spec] = Nokogiri::HTML(html_content)
        end
      end
    end
  end
end
