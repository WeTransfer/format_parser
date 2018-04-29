# format_parser


is a Ruby library for prying open video, image, document, and audio files.
It includes a number of parser modules that try to recover metadata useful for post-processing and layout while reading the absolute
minimum amount of data possible.

`format_parser` is inspired by [imagesize,](https://rubygems.org/gem/imagesize) [fastimage](https://github.com/sdsykes/fastimage)
and [dimensions,](https://github.com/sstephenson/dimensions) borrowing from them where appropriate.

[![Gem Version](https://badge.fury.io/rb/format_parser.svg)](https://badge.fury.io/rb/format_parser) [![Build Status](https://travis-ci.org/WeTransfer/format_parser.svg?branch=master)](https://travis-ci.org/WeTransfer/format_parser)

## Currently supported filetypes:

* TIFF
* CR2
* PSD
* PNG
* MP3
* JPEG
* GIF
* PDF
* DPX
* AIFF
* WAV
* FLAC
* FDX
* MOV
* MP4
* M4A
* ZIP
* DOCX, PPTX, XLSX

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
array_of_results = FormatParser.parse(File.open("myimage.jpg", "rb"), results: :all)
```

You can also optimize the metadata extraction by providing hints to the gem:

```ruby
FormatParser.parse(File.open("myimage", "rb"), natures: [:video, :image], formats: [:jpg, :png, :mp4], results: :all)
```

Return values of all parsers have built-in JSON serialization

```ruby
img_info = FormatParser.parse(File.open("myimage.jpg", "rb"))
JSON.pretty_generate(img_info) #=> ...
```

## Creating your own parsers

See the [section on writing parsers in CONTRIBUTING.md](CONTRIBUTING.md#so-you-want-to-contribute-a-new-parser)

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

### JPEG
- `divergent_pixel_dimensions_exif.jpg` is used with permission from LiveKom GmbH
- `extended_reads.jpg` has kindly been made available by Raphaelle Pellerin for use exclusively with format_parser
- `too_many_APP1_markers_surrogate.jpg` was created by the project maintainers

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

### DPX
- DPX files were created by one of the project maintainers and may be used with the library for the purposes of testing

### MOOV
- bmff.mp4 is borrowed from the [bmff](https://github.com/zuku/bmff) project
- Test_Circular MOV files were created by one of the project maintainers and are MIT licensed

### CR2
- CR2 examples are downloaded from http://www.rawsamples.ch/ and are Creative Common Licensed.

### FLAC
- atc_fixture_vbr.flac is a converted version of the MP3 with the same name
- c_11k16btipcm.flac is a converted version of the WAV with the same name

### M4A
- fixture.m4a was created by one of the project maintainers and is MIT licensed

### TIFF
- `Shinbutsureijoushuincho.tiff` is obtained from Wikimedia Commons and is Creative Commons licensed
- `IMG_9266_*.tif` and all it's variations were created by the project maintainers

### ZIP
- The .zip fixture files have been created by the project maintainers

### .docx
- The .docx files were generated by the project maintainers

### .key
- The `keynote_recognized_as_jpeg.key` file was created by the project maintainers
