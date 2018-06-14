module FormatParser
  module ActiveStorage
    class Railtie < Rails::Railtie
      # Move the responsibility of images analysis to format_parser:
      # Since ActiveStorage is using Minimagick (for shelling out mogrify and convert)
      # It is better to do it in-process since it's less expensive than shelling out
      # Also FormatParser is better in some cases like CR2 vs TIFFs
      if defined?(ActiveStorage::Analyzer::ImageAnalyzer)
        initializer 'active_storage.analyze_image' do
          ActiveStorage::Analyzer::ImageAnalyzer.class_eval do
            def metadata
              read_image do |image|
                # The step of swapping height & width if image is rotated
                # is already done in parsers
                { width: image.width_px, height: image.height_px }
              end
            end

            private

            def read_image
              download_blob_to_tempfile do |file|
                yield FormatParser.parse_file_at(file.path, natures: [:image])
              end
            end
          end
        end
      end
    end
  end
end
