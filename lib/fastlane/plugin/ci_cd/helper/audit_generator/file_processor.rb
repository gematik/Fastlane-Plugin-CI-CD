require 'kramdown'

module Fastlane
  module Helper
    class FileProcessor
      attr_reader :specs

      def initialize
        @specs = {}
      end

      def process_requirement_notes(file)
        number = 0

        File.open(file) do |f|
          f.each_line do |line|
            number += 1
            parse_block([line], file, number, "intro")
          end
        end
      end

      def process_code_file(file)
        number = 0
        first_hit = 0
        block = []

        File.open(file) do |f|
          f.each_line do |line|
            number += 1

            if line =~ %r{///?}
              if block.empty?
                first_hit = number
              end
              block << line
            else
              unless block.empty?
                block << line
                parse_block(block, file, first_hit, "code")
                block = []
              end
            end
          end
        end
      end

      def parse_block(block, file, first_line_number, source)
        number = first_line_number

        trimming = block.first[/\A */].size
        trimmed_code = block.map do |line|
          line.sub(/^ {0,#{trimming}}/, '')
        end.join

        block.each do |line|
          # Format: [REQ:<SPEC>:<AFOS>:<SUBAFOS?>] <DESC>
          if (matches = line.match(/\[REQ:(?<SPEC>[^:]*):(?<AFOS>[^:^|\s]*)(?:(?::)(?<SUBAFOS>[^:^|\s]*))?(?:(?:\|)(?<NUMBEROFLINES>[^:\s]*))?\](?<DESC>.*)/))
            register(matches, file, number, trimmed_code, source, trimming)
          end
          number += 1
        end
      end

      # rubocop:disable Metrics/PerceivedComplexity
      def register(matches, file, line, code = "", source = "code", trimming = 0)
        spec = matches[:SPEC]
        afos = matches[:AFOS]

        afos.split(',').each do |afo_with_count|
          parts = afo_with_count.split('#')
          afo = parts[0]
          number = parts.count == 2 ? parts[1] : 0

          hit = {
          "file" => file,
          "line" => line,
          "code" => code,
          "#" => number,
          "source" => source
        }

          hit["part"] = matches[:SUBAFOS] if matches.names.include?("SUBAFOS")

          if matches.names.include?("DESC")
            hit["description"] = Kramdown::Document.new(matches[:DESC]).to_html
          end

          if matches.names.include?("NUMBEROFLINES")
            number_of_lines = matches[:NUMBEROFLINES].to_i
            if number_of_lines > 1
              hit["code"] += read_part_of_file(file, line + 1, number_of_lines - 1, trimming)
              hit["line_to"] = line + number_of_lines - 1
            end
          end

          @specs[spec] ||= {}
          @specs[spec][afo] ||= []
          @specs[spec][afo] << hit
        end
      end
      # rubocop:enable Metrics/PerceivedComplexity

      def read_part_of_file(filename, start_line, num_lines, trimming = 0)
        return "" unless File.exist?(filename)

        lines = []
        current_line = 1

        File.foreach(filename) do |line|
          if current_line >= start_line && current_line < start_line + num_lines
            lines << line.chomp
          elsif current_line >= start_line + num_lines
            break
          end
          current_line += 1
        end

        lines.empty? ? "" : lines.map { |line| line.sub(/^ {0,#{trimming}}/, '') }.join("\n")
      end
    end
  end
end
