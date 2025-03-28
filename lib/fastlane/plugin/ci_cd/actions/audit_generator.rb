# lib/fastlane/actions/audit_generator_action.rb
require 'fastlane/action'
require 'fastlane_core/configuration/config_item'
require 'json'
require 'erb'
require_relative '../helper/audit_generator/audit_data_loader'
require_relative '../helper/audit_generator/file_processor'
require_relative '../helper/audit_generator/spec_fetcher'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?(:UI)

  module Actions
    class AuditGeneratorAction < Action
      def self.run(params)
        UI.message("The audit_generator plugin is working!")

        # Load data and initialize processors
        data_loader = Fastlane::Helper::AuditDataLoader.new(params[:audit_afos_json])
        file_processor = Fastlane::Helper::FileProcessor.new
        spec_fetcher = Fastlane::Helper::SpecFetcher.new(data_loader.audit_afos_json)

        # Process requirement notes if provided
        if params[:requirement_notes_glob]
          UI.message("Processing requirement notes from: #{params[:requirement_notes_glob]}")
          Dir.glob(params[:requirement_notes_glob]).each do |file|
            file_processor.process_requirement_notes(file)
          end
        end

        # Process code files
        source_files = []
        params[:source_file_globs].each do |glob|
          UI.message("Adding source files from glob: #{glob}")
          source_files.concat(Dir.glob(glob))
        end

        source_files.each do |file|
          file_processor.process_code_file(file)
        end

        # Get specs and prepare data for templates
        original_texts = spec_fetcher.fetch_specs
        audit_data = prepare_audit_data(data_loader.audit_afos, file_processor.specs, original_texts)

        # Generate output files
        generate_output_files(params, audit_data)
      end

      def self.prepare_audit_data(required_afos, specs, original_texts)
        original_afos = {}
        missing_afos = required_afos.dup

        # Process specs and collect data
        specs.each do |spec, afos|
          afos.each do |afo, entries|
            missing_afos = missing_afos.difference([afo])
            next unless original_texts[spec]

            original_afos[afo] = original_texts[spec].at_css("##{afo.sub('.', '')}").to_s.split("\n").map do |line|
              line.sub(/^ */, '')
            end.join("\n")
          end
        end

        # Sort specs for better readability
        sorted_specs = sort_specs(specs)

        {
          "required_afos" => required_afos,
          "original_afos" => original_afos,
          "specs" => specs,
          "sorted_specs" => sorted_specs,
          "missing_afos" => missing_afos
        }
      end

      def self.sort_specs(specs)
        specs.transform_values do |afos|
          afos
            .transform_values do |hits|
              hits.sort_by { |hit| hit["#"].to_i }
            end
            .sort_by do |value|
              value.to_s.scan(/\d+|\D+/).map do |match|
                next match if match.to_i.zero?

                match.rjust(3, '0')
              end.join
            end
            .to_h
        end.sort_by { |k, v| k }
      end

      def self.generate_output_files(params, audit_data)
        sh("mkdir -p #{params[:output_directory]}")

        params[:erb_templates].each do |erb_template|
          erb_out_path = File.join(params[:output_directory], File.basename(erb_template, '.erb'))
          erb = ERB.new(File.read(erb_template))
          UI.message("Writing AFOs to #{erb_out_path}")
          File.write(erb_out_path, erb.result_with_hash(audit_data))
        end
      end

      def self.description
        "This action generates an audit report from source files and requirement notes and writes it to any provided template."
      end

      def self.authors
        ["Martin Fiebig"]
      end

      def self.return_value
        # If your method provides a return value, you can describe here what it does
      end

      def self.details
        "You can use this action to generate an audit report for your project"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(
            key: :audit_afos_json,
            description: "Path to a json file containing the list of afos to audit as well as the urls to the specs. Example: { \"audit_afos\": [\"AFO1\", \"AFO2\"], \"specs\": { \"spec1\": \"https://url.to/spec1\" } }",
            optional: true,
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :output_directory,
            description: "Path to the output file",
            optional: false,
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :erb_templates,
            description: "Array of paths to ERB template files",
            optional: true,
            type: Array,
            verify_block: proc do |value|
              UI.user_error!("erb_templates cannot be empty") if value.empty?
              # test that files exist
              value.each do |file|
                UI.user_error!("ERB template file #{file} does not exist") unless File.exist?(file)
              end
            end
          ),
          FastlaneCore::ConfigItem.new(
            key: :requirement_notes_glob,
            description: "Glob pattern for requirement notes files",
            optional: true,
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :source_file_globs,
            description: "Array of glob patterns for source files to process",
            optional: false,
            type: Array
          )
        ]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
