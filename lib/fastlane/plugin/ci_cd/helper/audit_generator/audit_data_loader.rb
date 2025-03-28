require 'fastlane'
require 'json'

module Fastlane
  module Helper
    class AuditDataLoader
      attr_reader :audit_afos_json, :audit_afos

      def initialize(file_path)
        @audit_afos_json = load_audit_afos_json(file_path)
        @audit_afos = @audit_afos_json['audit_afos']
      end

      private

      def load_audit_afos_json(file_path)
        JSON.parse(File.read(file_path))
      end
    end
  end
end
