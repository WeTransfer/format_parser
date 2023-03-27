require 'matrix'
require 'spec_helper'

describe FormatParser::ISOBaseMediaFileFormat::Utils do
  include FormatParser::ISOBaseMediaFileFormat::Utils
  Box = FormatParser::ISOBaseMediaFileFormat::Box

  describe '.dimensions' do
    context 'when no moov box' do
      let(:box_tree) { [Box.new('ftyp', 0, 16)] }

      it 'returns nil' do
        expect(dimensions(box_tree)).to eq(nil)
      end
    end

    context 'when no video trak boxes' do
      let(:box_tree) do
        [
          Box.new('moov', 0, 0, nil, [
            Box.new('trak', 0, 0),
            Box.new('trak', 0, 0, nil, [
              Box.new('hdlr', 0, 0, { handler_type: 'soun' }),
            ]),
            Box.new('trak', 0, 0, nil, [
              Box.new('hdlr', 0, 0, { component_type: 'mhlr', component_subtype: 'soun' }),
            ])
          ])
        ]
      end

      it 'returns nil' do
        expect(dimensions(box_tree)).to eq(nil)
      end
    end

    context 'when no video tkhd boxes' do
      let(:box_tree) do
        [
          Box.new('moov', 0, 0, nil, [
            Box.new('trak', 0, 0, nil, [
              Box.new('hdlr', 0, 0, { handler_type: 'soun' }),
              Box.new('tkhd', 0, 0),
            ]),
            Box.new('trak', 0, 0, nil, [
              Box.new('hdlr', 0, 0, { handler_type: 'vide' }),
            ]),
            Box.new('trak', 0, 0, nil, [
              Box.new('hdlr', 0, 0, { component_type: 'mhlr', component_subtype: 'vide' }),
            ])
          ])
        ]
      end

      it 'returns nil' do
        expect(dimensions(box_tree)).to eq(nil)
      end
    end

    context 'when dimensions missing' do
      let(:box_tree) do
        [
          Box.new('moov', 0, 0, nil, [
            Box.new('trak', 0, 0, nil, [
              Box.new('hdlr', 0, 0, { handler_type: 'vide' }),
              Box.new('tkhd', 0, 0, { height: 100 })
            ]),
          ])
        ]
      end

      it 'returns nil' do
        expect(dimensions(box_tree)).to eq(nil)
      end
    end

    context 'when movie matrix missing' do
      let(:box_tree) do
        [
          Box.new('moov', 0, 0, nil, [
            Box.new('trak', 0, 0, nil, [
              Box.new('hdlr', 0, 0, { handler_type: 'vide' }),
              Box.new('tkhd', 0, 0, {
                height: 100,
                width: 200,
                matrix: Matrix[[2, 0, 0], [0, 2, 0], [0, 0, 2]]
              })
            ]),
          ])
        ]
      end

      it 'defaults to identity matrix' do
        expect(dimensions(box_tree)).to eq([400, 200])
      end
    end

    context 'when track matrix missing' do
      let(:box_tree) do
        [
          Box.new('moov', 0, 0, nil, [
            Box.new('mvhd', 0, 0, { matrix: Matrix[[2, 0, 0], [0, 2, 0], [0, 0, 2]] }),
            Box.new('trak', 0, 0, nil, [
              Box.new('hdlr', 0, 0, { handler_type: 'vide' }),
              Box.new('tkhd', 0, 0, { height: 100, width: 200 })
            ]),
          ])
        ]
      end

      it 'defaults to identity matrix' do
        expect(dimensions(box_tree)).to eq([400, 200])
      end
    end

    context 'when multiple tracks' do
      let(:box_tree) do
        [
          Box.new('moov', 0, 0, nil, [
            Box.new('mvhd', 0, 0, { matrix: Matrix[[2, 0, 0], [0, 2, 0], [0, 0, 2]] }),
            Box.new('trak', 0, 0, nil, [
              Box.new('hdlr', 0, 0, { handler_type: 'vide' }),
              Box.new('tkhd', 0, 0, {
                height: 1000,
              })
            ]),
            Box.new('trak', 0, 0, nil, [
              Box.new('hdlr', 0, 0, { handler_type: 'vide' }),
              Box.new('tkhd', 0, 0, {
                height: 200,
                width: 100,
                matrix: Matrix[[0, 3, 0], [3, 0, 0], [0, 0, 3]]
              })
            ]),
            Box.new('trak', 0, 0, nil, [
              Box.new('hdlr', 0, 0, { component_type: 'mhlr', component_subtype: 'vide' }),
              Box.new('tkhd', 0, 0, {
                height: 200,
                width: 100,
                matrix: Matrix[[2, 0, 0], [0, 2, 0], [0, 0, 2]]
              })
            ]),
          ])
        ]
      end

      it 'correctly calculates dimensions' do
        expect(dimensions(box_tree)).to eq([1200, 800])
      end
    end
  end

  describe '.duration' do
    context 'when no moov box' do
      let(:box_tree) { [Box.new('ftyp', 0, 16)] }

      it 'returns nil' do
        expect(duration(box_tree)).to eq(nil)
      end
    end

    context 'when no mvhd box' do
      let(:box_tree) { [Box.new('moov', 0, 0)] }

      it 'returns nil' do
        expect(duration(box_tree)).to eq(nil)
      end
    end

    context 'when no duration' do
      let(:box_tree) do
        [
          Box.new('moov', 0, 0, nil, [
            Box.new('mvhd', 0, 0, { timescale: 1 })
          ])
        ]
      end

      it 'returns nil' do
        expect(duration(box_tree)).to eq(nil)
      end
    end

    context 'when no timescale' do
      let(:box_tree) do
        [
          Box.new('moov', 0, 0, nil, [
            Box.new('mvhd', 0, 0, { duration: 1 })
          ])
        ]
      end

      it 'returns nil' do
        expect(duration(box_tree)).to eq(nil)
      end
    end

    context 'when timescale and duration' do
      let(:box_tree) do
        [
          Box.new('moov', 0, 0, nil, [
            Box.new('mvhd', 0, 0, { duration: 10, timescale: 2 })
          ])
        ]
      end

      it 'correctly calculates duration' do
        expect(duration(box_tree)).to eq(5)
      end
    end
  end

  describe '.frame_rate' do
    context 'when no moov box' do
      let(:box_tree) { [Box.new('ftyp', 0, 16)] }

      it 'returns nil' do
        expect(frame_rate(box_tree)).to eq(nil)
      end
    end

    context 'when no video trak boxes' do
      let(:box_tree) do
        [
          Box.new('moov', 0, 0, nil, [
            Box.new('trak', 0, 0),
            Box.new('trak', 0, 0, nil, [
              Box.new('hdlr', 0, 0, { handler_type: 'soun' }), # Audio - should be ignored
              Box.new('mdia', 0, 0, nil, [
                Box.new('mdhd', 0, 0, { timescale: 30 }),
                Box.new('minf', 0, 0, nil, [
                  Box.new('stbl', 0, 0, nil, [
                    Box.new('stts', 0, 0, {
                      entry_count: 1,
                      entries: [
                        {
                          sample_count: 10,
                          sample_delta: 1
                        }
                      ]
                    })
                  ])
                ])
              ])
            ]),
          ])
        ]
      end

      it 'returns nil' do
        expect(frame_rate(box_tree)).to eq(nil)
      end
    end

    context 'when no mdhd box' do
      let(:box_tree) do
        [
          Box.new('moov', 0, 0, nil, [
            Box.new('trak', 0, 0, nil, [
              Box.new('hdlr', 0, 0, { handler_type: 'vide' }),
              Box.new('mdia', 0, 0, nil, [
                Box.new('minf', 0, 0, nil, [
                  Box.new('stbl', 0, 0, nil, [
                    Box.new('stts', 0, 0, {
                      entry_count: 1,
                      entries: [
                        {
                          sample_count: 10,
                          sample_delta: 1
                        }
                      ]
                    })
                  ])
                ])
              ])
            ]),
          ])
        ]
      end

      it 'returns nil' do
        expect(frame_rate(box_tree)).to eq(nil)
      end
    end

    context 'when no stts box' do
      let(:box_tree) do
        [
          Box.new('moov', 0, 0, nil, [
            Box.new('trak', 0, 0, nil, [
              Box.new('hdlr', 0, 0, { handler_type: 'vide' }),
              Box.new('mdia', 0, 0, nil, [
                Box.new('mdhd', 0, 0, { timescale: 30 }),
                Box.new('minf', 0, 0, nil, [
                  Box.new('stbl', 0, 0)
                ])
              ])
            ]),
          ])
        ]
      end

      it 'returns nil' do
        expect(frame_rate(box_tree)).to eq(nil)
      end
    end

    context 'when multiple entries' do
      let(:box_tree) do
        [
          Box.new('moov', 0, 0, nil, [
            Box.new('trak', 0, 0),
            Box.new('trak', 0, 0, nil, [
              Box.new('hdlr', 0, 0, { handler_type: 'soun' }), # Audio - should be ignored
              Box.new('mdia', 0, 0, nil, [
                Box.new('mdhd', 0, 0, { timescale: 30 }),
                Box.new('minf', 0, 0, nil, [
                  Box.new('stbl', 0, 0, nil, [
                    Box.new('stts', 0, 0, {
                      entry_count: 1,
                      entries: [
                        {
                          sample_count: 10,
                          sample_delta: 1
                        }
                      ]
                    })
                  ])
                ])
              ])
            ]),
            Box.new('trak', 0, 0, nil, [
              Box.new('hdlr', 0, 0, { handler_type: 'vide' }),
              Box.new('mdia', 0, 0, nil, [
                Box.new('mdhd', 0, 0, { timescale: 30 }),
                Box.new('minf', 0, 0, nil, [
                  Box.new('stbl', 0, 0)
                ])
              ])
            ]),
            Box.new('trak', 0, 0, nil, [
              Box.new('hdlr', 0, 0, { handler_type: 'vide' }),
              Box.new('mdia', 0, 0, nil, [
                Box.new('minf', 0, 0, nil, [
                  Box.new('stbl', 0, 0, nil, [
                    Box.new('stts', 0, 0, {
                      entry_count: 1,
                      entries: [
                        {
                          sample_count: 10,
                          sample_delta: 1
                        }
                      ]
                    })
                  ])
                ])
              ])
            ]),
            Box.new('trak', 0, 0, nil, [
              Box.new('hdlr', 0, 0, { handler_type: 'vide' }),
              Box.new('mdia', 0, 0, nil, [
                Box.new('mdhd', 0, 0, { timescale: 60 }),
                Box.new('minf', 0, 0, nil, [
                  Box.new('stbl', 0, 0, nil, [
                    Box.new('stts', 0, 0, {
                      entry_count: 2,
                      entries: [
                        {
                          sample_count: 10,
                          sample_delta: 2
                        },
                        {
                          sample_count: 10,
                          sample_delta: 1
                        }
                      ]
                    })
                  ])
                ])
              ])
            ]),
            Box.new('trak', 0, 0, nil, [
              Box.new('hdlr', 0, 0, { handler_type: 'vide' }),
              Box.new('mdia', 0, 0, nil, [
                Box.new('mdhd', 0, 0, { timescale: 120 }),
                Box.new('minf', 0, 0, nil, [
                  Box.new('stbl', 0, 0, nil, [
                    Box.new('stts', 0, 0, {
                      entry_count: 1,
                      entries: [
                        {
                          sample_count: 10,
                          sample_delta: 3
                        }
                      ]
                    })
                  ])
                ])
              ])
            ]),
          ])
        ]
      end

      it 'correctly calculates frame rate' do
        expect(frame_rate(box_tree)).to eq(30)
      end
    end

    describe '.video_codecs' do
      context 'when no moov box' do
        let(:box_tree) { [Box.new('ftyp', 0, 16)] }

        it 'returns empty array' do
          expect(video_codecs(box_tree)).to eq([])
        end
      end

      context 'when no video trak boxes' do
        let(:box_tree) do
          [
            Box.new('moov', 0, 0, nil, [
              Box.new('trak', 0, 0),
              Box.new('trak', 0, 0, nil, [
                Box.new('hdlr', 0, 0, { handler_type: 'soun' }),
                Box.new('mdia', 0, 0, nil, [
                  Box.new('minf', 0, 0, nil, [
                    Box.new('stbl', 0, 0, nil, [
                      Box.new('stsd', 0, 0, nil, [
                        Box.new('flac', 0, 0) # Audio codec - should be ignored
                      ])
                    ])
                  ])
                ])
              ]),
              Box.new('trak', 0, 0, nil, [
                Box.new('hdlr', 0, 0, { component_type: 'mhlr', component_subtype: 'soun' }),
                Box.new('mdia', 0, 0, nil, [
                  Box.new('minf', 0, 0, nil, [
                    Box.new('stbl', 0, 0, nil, [
                      Box.new('stsd', 0, 0, nil, [
                        Box.new('flac', 0, 0) # Audio codec - should be ignored
                      ])
                    ])
                  ])
                ])
              ])
            ])
          ]
        end

        it 'returns empty array' do
          expect(video_codecs(box_tree)).to eq([])
        end
      end

      context 'when no stsd boxes' do
        let(:box_tree) do
          [
            Box.new('moov', 0, 0, nil, [
              Box.new('trak', 0, 0, nil, [
                Box.new('hdlr', 0, 0, { handler_type: 'soun' }),
                Box.new('mdia', 0, 0, nil, [
                  Box.new('minf', 0, 0, nil, [
                    Box.new('stbl', 0, 0, nil, [
                      Box.new('stsd', 0, 0, nil, [
                        Box.new('flac', 0, 0) # Audio codec - should be ignored
                      ])
                    ])
                  ])
                ])
              ]),
              Box.new('trak', 0, 0, nil, [
                Box.new('hdlr', 0, 0, { handler_type: 'vide' })
              ]),
              Box.new('trak', 0, 0, nil, [
                Box.new('hdlr', 0, 0, { handler_type: 'vide' }),
                Box.new('mdia', 0, 0)
              ]),
              Box.new('trak', 0, 0, nil, [
                Box.new('hdlr', 0, 0, { handler_type: 'vide' }),
                Box.new('mdia', 0, 0, nil, [
                  Box.new('minf', 0, 0)
                ])
              ]),
              Box.new('trak', 0, 0, nil, [
                Box.new('hdlr', 0, 0, { handler_type: 'vide' }),
                Box.new('mdia', 0, 0, nil, [
                  Box.new('minf', 0, 0, nil, [
                    Box.new('stbl', 0, 0)
                  ])
                ])
              ]),
              Box.new('trak', 0, 0, nil, [
                Box.new('hdlr', 0, 0, { component_type: 'mhlr', component_subtype: 'vide' }),
                Box.new('mdia', 0, 0, nil, [
                  Box.new('minf', 0, 0, nil, [
                    Box.new('stbl', 0, 0)
                  ])
                ])
              ]),
            ])
          ]
        end

        it 'returns empty array' do
          expect(video_codecs(box_tree)).to eq([])
        end
      end

      context 'when no codecs' do
        let(:box_tree) do
          [
            Box.new('moov', 0, 0, nil, [
              Box.new('trak', 0, 0, nil, [
                Box.new('hdlr', 0, 0, { handler_type: 'soun' }),
                Box.new('mdia', 0, 0, nil, [
                  Box.new('minf', 0, 0, nil, [
                    Box.new('stbl', 0, 0, nil, [
                      Box.new('stsd', 0, 0, nil, [
                        Box.new('flac', 0, 0) # Audio codec - should be ignored
                      ])
                    ])
                  ])
                ])
              ]),
              Box.new('trak', 0, 0, nil, [
                Box.new('hdlr', 0, 0, { handler_type: 'vide' }),
                Box.new('mdia', 0, 0, nil, [
                  Box.new('minf', 0, 0, nil, [
                    Box.new('stbl', 0, 0, nil, [
                      Box.new('stsd', 0, 0)
                    ])
                  ])
                ])
              ]),
              Box.new('trak', 0, 0, nil, [
                Box.new('hdlr', 0, 0, { component_type: 'mhlr', component_subtype: 'vide' }),
                Box.new('mdia', 0, 0, nil, [
                  Box.new('minf', 0, 0, nil, [
                    Box.new('stbl', 0, 0, nil, [
                      Box.new('stsd', 0, 0)
                    ])
                  ])
                ])
              ]),
            ])
          ]
        end

        it 'returns empty array' do
          expect(video_codecs(box_tree)).to eq([])
        end
      end

      context 'when multiple codecs' do
        let(:box_tree) do
          [
            Box.new('moov', 0, 0, nil, [
              Box.new('trak', 0, 0, nil, [
                Box.new('hdlr', 0, 0, { handler_type: 'soun' }),
                Box.new('mdia', 0, 0, nil, [
                  Box.new('minf', 0, 0, nil, [
                    Box.new('stbl', 0, 0, nil, [
                      Box.new('stsd', 0, 0, nil, [
                        Box.new('flac', 0, 0) # Audio codec - should be ignored
                      ])
                    ])
                  ])
                ])
              ]),
              Box.new('trak', 0, 0, nil, [
                Box.new('hdlr', 0, 0, { handler_type: 'vide' }),
                Box.new('mdia', 0, 0, nil, [
                  Box.new('minf', 0, 0, nil, [
                    Box.new('stbl', 0, 0, nil, [
                      Box.new('stsd', 0, 0, nil, [
                        Box.new('avc1', 0, 0),
                        Box.new('raw ', 0, 0)
                      ])
                    ])
                  ])
                ])
              ]),
              Box.new('trak', 0, 0, nil, [
                Box.new('hdlr', 0, 0, { component_type: 'mhlr', component_subtype: 'vide' }),
                Box.new('mdia', 0, 0, nil, [
                  Box.new('minf', 0, 0, nil, [
                    Box.new('stbl', 0, 0, nil, [
                      Box.new('stsd', 0, 0, nil, [
                        Box.new('avc1', 0, 0),
                      ]),
                      Box.new('stsd', 0, 0, nil, [
                        Box.new('rpza', 0, 0),
                      ])
                    ])
                  ])
                ])
              ]),
              Box.new('trak', 0, 0, nil, [
                Box.new('hdlr', 0, 0, { handler_type: 'vide' }),
                Box.new('mdia', 0, 0, nil, [
                  Box.new('minf', 0, 0, nil, [
                    Box.new('stbl', 0, 0, nil, [
                      Box.new('stsd', 0, 0, nil, [
                        Box.new('avc1', 0, 0),
                      ])
                    ])
                  ])
                ]),
                Box.new('mdia', 0, 0, nil, [
                  Box.new('minf', 0, 0, nil, [
                    Box.new('stbl', 0, 0, nil, [
                      Box.new('stsd', 0, 0, nil, [
                        Box.new('avc1', 0, 0),
                        Box.new('mp4v', 0, 0)
                      ])
                    ])
                  ])
                ])
              ]),
            ])
          ]
        end

        it 'returns all distinct codecs' do
          expect(video_codecs(box_tree)).to match_array(['avc1', 'mp4v', 'raw ', 'rpza'])
        end
      end
    end
  end
end
