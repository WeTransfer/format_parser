# format_parser

is a Ruby library for prying open video, image, document, and audio files.
It includes a number of parser modules that try to recover metadata useful for post-processing and layout while reading the absolute
minimum amount of data possible.

`format_parser` is inspired by [imagesize,](https://rubygems.org/gem/imagesize) [fastimage](https://github.com/sdsykes/fastimage)
and [dimensions,](https://github.com/sstephenson/dimensions) borrowing from them where appropriate.

## Basic usage

Pass an IO object that responds to `read` and `seek` to `FormatParser`.

```ruby
file_info = FormatParser.parse(File.open("myimage.jpg", "rb"))
file_info.file_nature           #=> :image
file_info.file_format           #=> :JPG
file_info.width_px              #=> 320
file_info.height_px             #=> 240
file_info.orientation           #=> :top_left
```
If nothing is detected, the result will be `nil`.

## Design rationale

We need to recover metadata from various file types, and we need to do so satisfying the following constraints:

* The data in those files can be malicious and/or incomplete, so we need to be failsafe
* The data will be fetched from a remote location, so we want to acquire it with as few HTTP requests as possible
  and with fetches being sufficiently small - the number of HTTP requests being of greater concern due to the
  fact that we rely on AWS, and data transfer is much cheaper than per-request fees.
* The data can be recognized ambiguously and match more than one format definition (like TIFF sections of camera RAW)
* The number of supported formats is only ever going to increase, not decrease
* The library is likely to be used in multiple consumer applications
* The information necessary is a small subset of the overall metadata available in the file

Therefore we adapt the following approaches:

* Modular parsers per file format, with some degree of code sharing between them (but not too much). Adding new formats
  should be low-friction, and testing these format parsers should be possible in isolation
* Modular and configurable IO stack that supports limiting reads/loops from the source entity.
  The IO stack is isolated from the parsers, meaning parsers do not need to care about things
  like fetches using `Range:` headers, GZIP compression and the like
* A caching system that allows us to ideally fetch once, and only once, and as little as possible - but still accomodate formats
  that have the important information at the end of the file or might need information from the middle of the file
* Minimal dependencies, and if dependencies are to be used they should be very stable and low-level
* Where possible, use small subsets of full-feature format parsers since we only care about a small subset of the data
* Avoid using C libraries which are likely to contain buffer overflows/underflows - we stay memory safe

## Fixture Sources

- MIT licensed fixture files from the FastImage and Dimensions projects
- fixture.aiff was created by one of the project maintainers and is MIT licensed
