## 0.7.0
* Configure READ limits centrally

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