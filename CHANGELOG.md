## Unreleased
* Add support for the Ogg format

## 0.13.2
* Handle BMP files with pixel array offsets larger than 54

## 0.13.1
* Avoid ZIP checks in the JPEG parser which are no longer necessary

## 0.13.0
* Replace the homegrown ID3 parser with [id3tag](https://github.com/krists/id3tag) - this introduces id3tag
  as a dependency in addition to `exifr`, but the gains are substantial.

## 0.12.4
* Ensure JPEG recognition only runs when the JPEG SOI marker is detected **at the start** of file. Previously
  the JPEG parser would scan for the marker, sometimes finding it (appropriately) in places like... MP3 album
  artwork inside ID3 tags. Or Keynote documents. Or whatnot - lots of things have JPEG thumbnails embedded.

## 0.12.3
* Make sure all strings going to the JSON representations of parse results are encoded as UTF-8 or escaped

## 0.12.2
* Make sure the `VERSION` constant is available in the loaded gem. Previously the constant would be made
  available by Bundler when developing the library - since it loads the `.gemspec` which, in turn, requires the
  version.rb file, but when used as a gem the version.rb file would not end up being loaded.

## 0.12.1
* Reinstate support for Ruby 2.2.0
* Fix support for JRuby 9.0

## 0.12.0
* Relay upstream status from `RemoteIO` in the `status_code` attribute (returns an `Integer`)

## 0.11.0
* Add `Image#display_width_px` and `Image#display_height_px` for EXIF/aspect corrected display dimensions, and provide
  those values from a few parsers already. Also make full EXIF data available for JPEG/TIFF in `intrinsics[:exif]`
* Adds `limits_config` option to `FormatParser.parse()` for tweaking buffers and read limits externally

## 0.10.0
* Adds the `format_parser_inspect` binary for parsing a file from the commandline
  and returning results in JSON
* Adds the `FormatParser.parse_at(path)` convenience method

## 0.9.4
* Fix a TIFF parsing regression introduced in 0.3.1 that led to all TIFFs being incorrectly parsed

## 0.9.3
* Fix a JPEG parsing regression introduced in 0.9.1

## 0.9.2 (yanked)
* Make sure MP3 parser returns `nil` when encountering infinite duration
* Do not read JPEG APP1 markers that contain no EXIF data
* Explicitly replace `Float::INFINITY` values in `AttributesJSON` with `nil` as per JSON convention
* Make sure the cached pages in `Care` are explicitly deleted after each `parse` call (should help GC)
* Raise the pagefaults restriction to 16 to cope with "too many useless markers in JPEGs" scenario once more

## 0.9.1 (yanked)
* Perf: Make JPEG parser bail out earlier if no marker is found while scanning through 1024 bytes of data

## 0.9.0
* Add a parser for the BMP image file format

## 0.8.0
* Add `Measurometer` for applying instrumentation around FormatParser operaions. See documentation for usage.

## 0.7.0
* Configure read limits / pagefault limits centrally so that those limits make sense together

## 0.6.0
* Double the cache page size once more
* We no longer need exifr/jpeg
* Fix EXIF parsing in JPEG files
* Reject Keynote documents in JPEG parser

## 0.5.2
* Do not raise EXIFR errors for keynote files
* Correct broken comment for the audio nature

## 0.5.1
* Raise the cache page size during detection
* Fix ZIP entry filename parsing

## 0.5.0
* Add FLAC parser
* Add parse_atom_children_and_data_fields support
* Add basic detection of Office files
* Optimize EOCD signature lookup

## 0.4.0
* Adds a basic PDF parser
* Make sure root: and to_json without arguments work
* ZIP file format support

## 0.3.5
* Fix the bug with EXIF dimensions being used instead of pixel dimensions

## 0.3.4
* Pagefault limit
* Add seek modes required by exifr

## 0.3.3
* Implement a sane to_json as well

## 0.3.2
* Add default as_json
* Test on 2.5.0

## 0.3.1
* Remove post install warning
* Moved aiff_parser_spec.rb to spec/parsers
* CR2 file support
* Add require 'set' to format_parser.rb
* Use register_parser for natures/fmts

## 0.3.0
* Reverse API changes to support :first as default and add opts to parse_http
* Implement and comply with rubocop
* JPEG parser and Care fixes
* Add format and count options to parse_http
* Return first result as default
* Use hashes for MOOV atom default fields

## 0.2.0
* Implement parser DSL

## 0.1.7
* Fix read(0) on Care::IOWrapper, introduce top-level tests

## 0.1.6
* Fix mp3 parsing bug
* Add MOOV parser

## 0.1.5
* Add FDX parser
* Remove dry-structs
* New interface updates

## 0.1.4
* Add WAV parser

## 0.1.3
* Add MP3 parser
* Add FileInformation#intrinsics
* Disallow negative Care offsets

## 0.1.2
* Introduce a restrictive IO subset wrapper
* Switch rewind for seek in exif parser
* Prep for OSS release
* Add fuzz spec
* Improve orientation parsing
* Optimisation for PNG and invalid input protection on JPEG

## 0.1.1
* Add AIFF parser

## 0.1.0
* Add parsers for PNG, JPG, TIFF, PSD
* Add GIF parser
* Add DPX parser
