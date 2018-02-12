# format_parser


is a Ruby library for prying open video, image, document, and audio files.
It includes a number of parser modules that try to recover metadata useful for post-processing and layout while reading the absolute
minimum amount of data possible.

`format_parser` is inspired by [imagesize,](https://rubygems.org/gem/imagesize) [fastimage](https://github.com/sdsykes/fastimage)
and [dimensions,](https://github.com/sstephenson/dimensions) borrowing from them where appropriate.

[![Gem Version](https://badge.fury.io/rb/format_parser.svg)](https://badge.fury.io/rb/format_parser) [![Build Status](https://travis-ci.org/WeTransfer/format_parser.svg?branch=master)](https://travis-ci.org/WeTransfer/format_parser)

## Currently supported filetypes:

`TIFF, CR2, PSD, PNG, MP3, JPEG, GIF, DPX, AIFF, WAV, FDX, MOV, MP4`

...with [more](https://github.com/WeTransfer/format_parser/issues?q=is%3Aissue+is%3Aopen+label%3Aformats) on the way!

## Basic usage

Pass an IO object that responds to `read` and `seek` to `FormatParser` and the first confirmed match will be returned.

```ruby
match = FormatParser.parse(File.open("myimage.jpg", "rb"))
match.nature        #=> :image
match.format        #=> :jpg
match.width_px      #=> 320
match.height_px     #=> 240
match.orientation   #=> :top_left
```

If you would rather receive all potential results from the gem, call the gem as follows:

```ruby
FormatParser.parse(File.open("myimage.jpg", "rb"), results: :all)
```

You can also optimize the metadata extraction by providing hints to the gem:

```ruby
FormatParser.parse(File.open("myimage", "rb"), natures: [:video, :image], formats: [:jpg, :png, :mp4], results: :all)
```

## Creating your own parsers

In order to create new parsers, you have to write a method or a  Proc that accepts an IO and performs the
parsing, and then returns the metadata for the file (if it could recover any) or `nil` if it couldn't. All files pass
through all parsers by default, so if you are dealing with a file that is not "your" format - return `nil` from
your method or `break` your Proc as early as possible. A blank `return` works fine too.

The IO will at the minimum support the subset of the IO API defined in `IOConstraint`

Strictly, a parser should be one of the two things:

1) An object that can be `call()`-ed itself, with an argument that conforms to `IOConstraint`
2) An object that responds to `new` and returns something that can be `call()`-ed with the same convention.

The second opton is useful for parsers that are stateful and non-reentrant. FormatParser is made to be used in
threaded environments, and if you use instance variables you need your parser to be isolated from it's siblings in
other threads - therefore you can pass a Class on registration to have your parser instantiated for each `call()`,
anew.

Your parser has to be registered using `FormatParser.register_parser` with the information on the formats
and file natures it provides.

Down below you can find a basic parser implementation:

```ruby
MyParser = ->(io) {
  # ... do some parsing with `io`
  magic_bytes = io.read(4)
  break if magic_bytes != 'XBMP'
  # ... more parsing code
  # ...and return the FileInformation::Image object with the metadata.
  FormatParser::Image.new(
    width_px: parsed_width,
    height_px: parsed_height,
  )
}

# Register the parser with the module, so that it will be applied to any
# document given to `FormatParser.parse()`. The supported natures are currently
#      - :audio
#      - :document
#      - :image
#      - :video
FormatParser.register_parser MyParser, natures: :image, formats: :bmp
```

If you are using a class, this is the skeleton to use:

```ruby
class MyParser
  def call(io)
    # ... do some parsing with `io`
    magic_bytes = io.read(4)
    return unless magic_bytes != 'XBMP'
    # ... more parsing code
    # ...and return the FileInformation::Image object with the metadata.
    FormatParser::Image.new(
      width_px: parsed_width,
      height_px: parsed_height,
    )
  end

  FormatParser.register_parser self, natures: :image, formats: :bmp
end
```

## Design rationale

We need to recover metadata from various file types, and we need to do so satisfying the following constraints:

* The data in those files can be malicious and/or incomplete, so we need to be failsafe
* The data will be fetched from a remote location (S3), so we want to obtain it with as few HTTP requests as possible
* ...and with the amount of data fetched being small - the number of HTTP requests being of greater concern
* The data can be recognized ambiguously and match more than one format definition (like TIFF sections of camera RAW)
* The information necessary is a small subset of the overall metadata available in the file.
* The number of supported formats is only ever going to increase, not decrease
* The library is likely to be used in multiple consumer applications
* The library is likely to be used in multithreading environments

## Deliberate design choices

Therefore we adapt the following approaches:

* Modular parsers per file format, with some degree of code sharing between them (but not too much). Adding new formats
  should be low-friction, and testing these format parsers should be possible in isolation
* Modular and configurable IO stack that supports limiting reads/loops from the source entity.
  The IO stack is isolated from the parsers, meaning parsers do not need to care about things
  like fetches using `Range:` headers, GZIP compression and the like
* A caching system that allows us to ideally fetch once, and only once, and as little as possible - but still accomodate formats
  that have the important information at the end of the file or might need information from the middle of the file
* Minimal dependencies, and if dependencies are to be used they should be very stable and low-level
* Where possible, use small subsets of full-feature format parsers since we only care about a small subset of the data.
* When a choice arises between using a dependency or writing a small parser, write the small parser since less code
  is easier to verify and test, and we likely don't care about all the metadata anyway
* Avoid using C libraries which are likely to contain buffer overflows/underflows - we stay memory safe

## Fixture Sources

Unless specified otherwise in this section the fixture files are MIT licensed and from the FastImage and Dimensions projects.

### AIFF
- fixture.aiff was created by one of the project maintainers and is MIT licensed

### WAV
- c_11k16bitpcm.wav and c_8kmp316.wav are from [Wikipedia WAV](https://en.wikipedia.org/wiki/WAV#Comparison_of_coding_schemes), retrieved January 7, 2018
- c_39064__alienbomb__atmo-truck.wav is from [freesound](https://freesound.org/people/alienbomb/sounds/39064/) and is CC0 licensed
- c_M1F1-Alaw-AFsp.wav and d_6_Channel_ID.wav are from a [McGill Engineering site](http://www-mmsp.ece.mcgill.ca/Documents/AudioFormats/WAVE/Samples.html)

### MP3
- Cassy.mp3 has been produced by WeTransfer and may be used with the library for the purposes of testing

### FDX
- fixture.fdx was created by one of the project maintainers and is MIT licensed

### MOOV
- bmff.mp4 is borrowed from the [bmff](https://github.com/zuku/bmff) project
- Test_Circular MOV files were created by one of the project maintainers and are MIT licensed
