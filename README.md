# format_parser


is a Ruby library for prying open video, image, document, and audio files.
It includes a number of parser modules that try to recover metadata useful for post-processing and layout while reading the absolute
minimum amount of data possible.

`format_parser` is inspired by [imagesize,](https://rubygems.org/gem/imagesize) [fastimage](https://github.com/sdsykes/fastimage)
and [dimensions,](https://github.com/sstephenson/dimensions) borrowing from them where appropriate.

[![Gem Version](https://badge.fury.io/rb/format_parser.svg)](https://badge.fury.io/rb/format_parser) [![Build Status](https://travis-ci.org/WeTransfer/format_parser.svg?branch=master)](https://travis-ci.org/WeTransfer/format_parser)

## Currently supported filetypes:

`TIFF, PSD, PNG, MP3, JPEG, GIF, DPX, AIFF, WAV, FDX, MOV, MP4`

...with more on the way!

## Basic usage

Pass an IO object that responds to `read` and `seek` to `FormatParser` and an array of matches will be returned.

```ruby
matches = FormatParser.parse(File.open("myimage.jpg", "rb"))
matches.first.nature        #=> :image
matches.first.format        #=> :jpg
matches.first.width_px      #=> 320
matches.first.height_px     #=> 240
matches.first.orientation   #=> :top_left
```

If you would rather receive only one result, call the gem as follows:

```ruby
FormatParser.parse(File.open("myimage.jpg", "rb"), returns: :one)
```

You can also optimize the metadata extraction by providing hints to the gem:

```ruby
FormatParser.parse(File.open("myimage", "rb"), natures: [:video, :image], formats: [:jpg, :png, :mp4])
```

## Creating your own parsers

In order to create new parsers, these have to meet two requirements:

1) Instances of the new parser class needs to respond to a `call` method which takes one IO object as an argument and returns some metadata information about its corresponding file or nil otherwise.
2) Instances of the new parser class needs to respond `natures` and `formats` accessor methods, both returning an array of symbols. A simple DSL is provided to avoid writing those accessors.
3) The class needs to register itself as a parser.


Down below you can find a basic parser implementation:

```ruby
class BasicParser
  include FormatParser::DSL # Adds formats and natures methods to the class, which define
                            # accessor for all the instances.
  
  formats :foo, :baz # Indicates which formats it can read.
  natures :bar       # Indicates which type of file from a human perspective it can read:
                     #      - :audio
                     #      - :document
                     #      - :image
                     #      - :video
  def call(file)
    # Returns a DTO object with including some metadata.
  end

  FormatParser.register_parser_constructor self # Register this parser.
```

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
