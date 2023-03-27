require 'spec_helper'

describe FormatParser::ISOBaseMediaFileFormat::Box do
  describe '.new' do
    context 'when no fields/children' do
      subject { described_class.new('foo', 0, 0) }

      it 'sets them as empty hash/array' do
        expect(subject.fields).to eq({})
        expect(subject.children).to eq([])
      end
    end

    context 'when fields/children' do
      let(:fields) { { foo: 1, bar: 'bar' } }
      let(:children) { [described_class.new('bar', 0, 0)] }

      subject { described_class.new('foo', 0, 0, fields, children) }

      it 'sets them correctly' do
        expect(subject.fields).to eq(fields)
        expect(subject.children).to eq(children)
      end
    end
  end

  describe '#all_children' do
    context 'when no types given' do
      subject do
        described_class.new('root', 0, 0, nil, [
          described_class.new('foo', 0, 0),
          described_class.new('bar', 0, 0)
        ])
      end

      it 'returns empty array' do
        expect(subject.all_children).to eq([])
      end
    end

    context 'when no children' do
      subject { described_class.new('root', 0, 0) }

      it 'returns empty array' do
        expect(subject.all_children('foo')).to eq([])
      end
    end

    context 'when no children of given type(s)' do
      subject do
        described_class.new('root', 0, 0, nil, [
          described_class.new('foo', 0, 0),
          described_class.new('bar', 0, 0, nil, [
            described_class.new('baz', 0, 0)
          ])
        ])
      end

      it 'returns empty array' do
        expect(subject.all_children('baz')).to eq([])
      end
    end

    context 'when multiple children of given type(s)' do
      let(:child_1) { described_class.new('foo', 0, 0) }
      let(:child_2) do
        described_class.new('foo', 0, 0, nil, [
          described_class.new('qux', 0, 0)
        ])
      end
      let(:child_3) { described_class.new('bar', 0, 0) }

      subject do
        described_class.new('root', 0, 0, nil, [
          child_1,
          child_2,
          child_3,
          described_class.new('baz', 0, 0)
        ])
      end

      it 'returns all matching direct children' do
        expect(subject.all_children('foo', 'bar', 'qux')).to match_array([child_1, child_2, child_3])
      end
    end
  end

  describe '#child?' do
    context 'when no children' do
      subject { described_class.new('root', 0, 0) }

      it 'returns false' do
        expect(subject.child?('foo')).to eq(false)
      end
    end

    context 'when no children of given type' do
      subject do
        described_class.new('root', 0, 0, nil, [
          described_class.new('foo', 0, 0),
          described_class.new('bar', 0, 0, nil, [
            described_class.new('baz', 0, 0)
          ])
        ])
      end

      it 'returns false' do
        expect(subject.child?('baz')).to eq(false)
      end
    end

    context 'when child of given type' do
      subject do
        described_class.new('root', 0, 0, nil, [
          described_class.new('foo', 0, 0),
          described_class.new('bar', 0, 0),
        ])
      end

      it 'returns true' do
        expect(subject.child?('foo')).to eq(true)
      end
    end
  end

  describe '#first_child' do
    context 'when no types given' do
      subject do
        described_class.new('root', 0, 0, nil, [
          described_class.new('foo', 0, 0),
          described_class.new('bar', 0, 0)
        ])
      end

      it 'returns nil' do
        expect(subject.first_child).to eq(nil)
      end
    end

    context 'when no children' do
      subject { described_class.new('root', 0, 0) }

      it 'returns nil' do
        expect(subject.first_child('foo')).to eq(nil)
      end
    end

    context 'when no children of given type(s)' do
      subject do
        described_class.new('root', 0, 0, nil, [
          described_class.new('foo', 0, 0),
          described_class.new('bar', 0, 0, nil, [
            described_class.new('baz', 0, 0)
          ])
        ])
      end

      it 'returns nil' do
        expect(subject.first_child('baz')).to eq(nil)
      end
    end

    context 'when multiple children of given type(s)' do
      let(:child) { described_class.new('bar', 0, 0) }

      subject do
        described_class.new('root', 0, 0, nil, [
          described_class.new('foo', 0, 0, nil, [
            described_class.new('qux', 0, 0)
          ]),
          child,
          described_class.new('bar', 0, 0),
          described_class.new('baz', 0, 0)
        ])
      end

      it 'returns first matching direct child' do
        expect(subject.first_child('qux', 'baz', 'bar')).to eq(child)
      end
    end
  end

  describe '#all_descendents' do
    context 'when no types given' do
      subject do
        described_class.new('root', 0, 0, nil, [
          described_class.new('foo', 0, 0),
          described_class.new('bar', 0, 0)
        ])
      end

      it 'returns empty array' do
        expect(subject.all_descendents).to eq([])
      end
    end

    context 'when no children' do
      subject { described_class.new('root', 0, 0) }

      it 'returns empty array' do
        expect(subject.all_descendents('root', 'foo')).to eq([])
      end
    end

    context 'when no descendents of given type(s)' do
      subject do
        described_class.new('root', 0, 0, nil, [
          described_class.new('foo', 0, 0),
          described_class.new('bar', 0, 0, nil, [
            described_class.new('baz', 0, 0)
          ])
        ])
      end

      it 'returns empty array' do
        expect(subject.all_descendents('root', 'qux')).to eq([])
      end
    end

    context 'when multiple descendents of given type(s)' do
      let(:descendent_1) { described_class.new('bar', 0, 0) }
      let(:descendent_2) { described_class.new('baz', 10, 10, nil, [descendent_3]) }
      let(:descendent_3) { described_class.new('bar', 20, 20) }

      subject do
        described_class.new('root', 0, 0, nil, [
          described_class.new('foo', 0, 0, nil, [
            descendent_1
          ]),
          descendent_2,
          described_class.new('qux', 40, 40)
        ])
      end

      it 'returns all matching descendents' do
        expect(subject.all_descendents('bar', 'baz')).to match_array([descendent_1, descendent_2, descendent_3])
      end
    end
  end

  describe '#all_descendents_by_path' do
    context 'when no children' do
      subject { described_class.new('root', 0, 0) }

      it 'returns empty array' do
        expect(subject.all_descendents_by_path(['foo'])).to eq([])
      end
    end

    context 'when no path' do
      subject do
        described_class.new('root', 0, 0, nil, [
          described_class.new('foo', 0, 0, nil, [
            described_class.new('bar', 0, 0)
          ])
        ])
      end

      it 'returns empty array' do
        expect(subject.all_descendents_by_path([])).to eq([])
      end
    end

    context 'when no descendents at given path' do
      subject do
        described_class.new('root', 0, 0, nil, [
          described_class.new('foo', 0, 0, nil, [
            described_class.new('bar', 0, 0)
          ])
        ])
      end

      it 'returns empty array' do
        expect(subject.all_descendents_by_path(%w[foo baz])).to eq([])
      end
    end

    context 'when multiple descendents at given path' do
      let(:descendent_1) { described_class.new('bar', 0, 0) }
      let(:descendent_2) { described_class.new('bar', 0, 0) }

      subject do
        described_class.new('root', 0, 0, nil, [
          described_class.new('foo', 0, 0, nil, [
            descendent_1,
            described_class.new('baz', 0, 0, nil, [
              described_class.new('bar', 0, 0)
            ]),
            descendent_2,
          ])
        ])
      end

      it 'returns all matching descendents' do
        expect(subject.all_descendents_by_path(%w[foo bar])).to match_array([descendent_1, descendent_2])
      end
    end
  end

  describe '#first_descendent' do
    context 'when no children' do
      subject { described_class.new('root', 0, 0) }

      it 'returns nil' do
        expect(subject.first_descendent('root', 'foo')).to eq(nil)
      end
    end

    context 'when no descendents of given type(s)' do
      subject do
        described_class.new('root', 0, 0, nil, [
          described_class.new('foo', 0, 0),
          described_class.new('bar', 0, 0, nil, [
            described_class.new('baz', 0, 0)
          ])
        ])
      end

      it 'returns nil' do
        expect(subject.first_descendent('root', 'qux')).to eq(nil)
      end
    end

    context 'when multiple descendents of given type(s)' do
      let(:descendent) { described_class.new('bar', 0, 0) }

      subject do
        described_class.new('root', 0, 0, nil, [
          described_class.new('foo', 0, 0, nil, [
            descendent
          ]),
          described_class.new('bar', 0, 0),
        ])
      end

      it 'returns first matching descendent' do
        expect(subject.first_descendent('bar')).to be(descendent)
      end
    end
  end

  describe '#first_descendent_by_path' do
    context 'when no children' do
      subject { described_class.new('root', 0, 0) }

      it 'returns nil' do
        expect(subject.first_descendent_by_path(['foo'])).to eq(nil)
      end
    end

    context 'when no path' do
      subject do
        described_class.new('root', 0, 0, nil, [
          described_class.new('foo', 0, 0, nil, [
            described_class.new('bar', 0, 0)
          ])
        ])
      end

      it 'returns nil' do
        expect(subject.first_descendent_by_path([])).to eq(nil)
      end
    end

    context 'when no descendents at given path' do
      subject do
        described_class.new('root', 0, 0, nil, [
          described_class.new('foo', 0, 0, nil, [
            described_class.new('bar', 0, 0)
          ])
        ])
      end

      it 'returns nil' do
        expect(subject.first_descendent_by_path(%w[foo baz])).to eq(nil)
      end
    end

    context 'when multiple descendents at given path' do
      let(:descendent) { described_class.new('bar', 0, 0) }

      subject do
        described_class.new('root', 0, 0, nil, [
          described_class.new('foo', 0, 0, nil, [
            described_class.new('baz', 0, 0, nil, [
              described_class.new('bar', 0, 0)
            ]),
            descendent,
            described_class.new('bar', 0, 0),
          ])
        ])
      end

      it 'returns first matching descendent' do
        expect(subject.first_descendent_by_path(%w[foo bar])).to eq(descendent)
      end
    end
  end
end
