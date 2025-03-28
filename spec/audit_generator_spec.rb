require 'spec_helper'
require 'fastlane'
require 'fastlane/action'
require 'fastlane/plugin/ci_cd/actions/audit_generator'
require 'fileutils'

describe Fastlane::Actions::AuditGeneratorAction do
  let(:test_output_dir) { 'spec/fixtures/output' }
  let(:test_erb_template) { 'spec/fixtures/templates/test_template.erb' }
  let(:test_audit_afos_json) { 'spec/fixtures/audit_afos.json' }
  let(:test_requirement_notes) { 'spec/fixtures/requirement-notes.md' }
  let(:test_swift_file) { 'spec/fixtures/TestFile.swift' }

  before do
    # Create test directories and files
    FileUtils.mkdir_p(test_output_dir)
    FileUtils.mkdir_p(File.dirname(test_erb_template))

    # Create a simple ERB template for testing
    File.write(test_erb_template, <<~ERB)
      # Requirements Report
      <% specs.each do |spec, afos| %>
        ## <%= spec %>
        <% afos.each do |afo, hits| %>
          ### <%= afo %>
          <%= hits.length %> implementation(s)
        <% end %>
      <% end %>

      Missing AFOs: <%= missing_afos.join(', ') %>
    ERB

    # Create a test audit_afos.json file
    File.write(test_audit_afos_json, <<~JSON)
      {
        "audit_afos": ["A_1", "A_2", "A_3"],
        "specs": {
          "SPEC1": "https://example.com/spec1",
          "SPEC2": "https://example.com/spec2"
        }
      }
    JSON

    # Create a test requirement notes file
    File.write(test_requirement_notes, <<~MD)
      # Requirements

      [REQ:SPEC1:A_1] This is requirement A_1
    MD

    # Create a test Swift file with requirements
    File.write(test_swift_file, <<~SWIFT)
      import Foundation

      // [REQ:SPEC1:A_2] This is requirement A_2
      class TestClass {
          func testMethod() {
              // Implementation
          }
      }
    SWIFT

    # Stub the HTML content fetcher
    allow_any_instance_of(Fastlane::Helper::HtmlContentFetcher).to receive(:fetch_html_content).and_return(<<~HTML)
      <html>
        <body>
          <div id="A1">Requirement A_1 details</div>
          <div id="A2">Requirement A_2 details</div>
          <div id="A3">Requirement A_3 details</div>
        </body>
      </html>
    HTML

    # Stub UI messages to keep test output clean
    allow(Fastlane::UI).to receive(:message)
    allow(Fastlane::UI).to receive(:important)
    allow(Fastlane::UI).to receive(:error)
  end

  after do
    # Clean up test files
    FileUtils.rm_rf('spec/fixtures')
  end

  describe '#run' do
    it 'generates output files based on templates' do
      # Run the action
      described_class.run(
        audit_afos_json: test_audit_afos_json,
        output_directory: test_output_dir,
        erb_templates: [test_erb_template],
        requirement_notes_glob: test_requirement_notes,
        source_file_globs: [test_swift_file]
      )

      # Check that the output file was created
      output_file = File.join(test_output_dir, 'test_template')
      expect(File.exist?(output_file)).to be true

      # Check the content of the output file
      content = File.read(output_file)
      expect(content).to include('# Requirements Report')
      expect(content).to include('## SPEC1')
      expect(content).to include('### A_1')
      expect(content).to include('### A_2')
      expect(content).to include('Missing AFOs: A_3')
    end

    it 'handles missing requirement notes gracefully' do
      # Run the action without requirement notes
      described_class.run(
        audit_afos_json: test_audit_afos_json,
        output_directory: test_output_dir,
        erb_templates: [test_erb_template],
        requirement_notes_glob: nil,
        source_file_globs: [test_swift_file]
      )

      # Check that the output file was created
      output_file = File.join(test_output_dir, 'test_template')
      expect(File.exist?(output_file)).to be true

      # Check the content of the output file - should only have A_2 from the Swift file
      content = File.read(output_file)
      expect(content).to include('### A_2')
      expect(content).not_to include('### A_1')
    end

    it 'reports missing AFOs correctly' do
      # Run the action with only one requirement implemented
      File.write(test_swift_file, <<~SWIFT)
        import Foundation

        // [REQ:SPEC1:A_2] This is requirement A_2
        class TestClass {}
      SWIFT

      File.write(test_requirement_notes, '')

      described_class.run(
        audit_afos_json: test_audit_afos_json,
        output_directory: test_output_dir,
        erb_templates: [test_erb_template],
        requirement_notes_glob: test_requirement_notes,
        source_file_globs: [test_swift_file]
      )

      # Check that missing AFOs are reported correctly
      output_file = File.join(test_output_dir, 'test_template')
      content = File.read(output_file)
      expect(content).to include('Missing AFOs: A_1, A_3')
    end
  end

  describe '.description' do
    it 'returns a description' do
      expect(described_class.description).to be_a(String)
      expect(described_class.description).not_to be_empty
    end
  end

  describe '.authors' do
    it 'returns the authors' do
      expect(described_class.authors).to be_a(Array)
      expect(described_class.authors).not_to be_empty
    end
  end

  describe '.available_options' do
    it 'returns the available options' do
      options = described_class.available_options
      expect(options).to be_a(Array)
      expect(options.length).to be >= 3

      # Check that required options are present
      option_keys = options.map(&:key)
      expect(option_keys).to include(:audit_afos_json)
      expect(option_keys).to include(:output_directory)
      expect(option_keys).to include(:erb_templates)
      expect(option_keys).to include(:requirement_notes_glob)
      expect(option_keys).to include(:source_file_globs)
    end
  end

  describe '.is_supported?' do
    it 'returns true for any platform' do
      expect(described_class.is_supported?(:ios)).to be true
      expect(described_class.is_supported?(:android)).to be true
    end
  end
end
