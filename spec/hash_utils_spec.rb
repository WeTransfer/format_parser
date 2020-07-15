require 'spec_helper'

describe FormatParser::HashUtils do
  describe '.deep_transform_keys' do
    it 'transforms all the keys in a hash' do
      hash = { aa: 1, 'bb' => 2 }
      result = described_class.deep_transform_keys(hash, &:to_s)

      expect(result).to eq('aa' => 1, 'bb' => 2)
    end

    it 'transforms all the keys in a array of hashes' do
      array = [{ aa: 1, bb: 2 }, { cc: 3, dd: [{c: 2, d: 3}] }]
      result = described_class.deep_transform_keys(array, &:to_s)

      expect(result).to eq(
        [{'aa' => 1, 'bb' => 2}, {'cc' => 3, 'dd' => [{'c' => 2, 'd' => 3}]}]
      )
    end

    it 'transforms all the keys in a hash recursively' do
      hash = { aa: 1, bb: { cc: 22, dd: 3 } }
      result = described_class.deep_transform_keys(hash, &:to_s)

      expect(result).to eq('aa' => 1, 'bb' => { 'cc' => 22, 'dd' => 3})
    end

    it 'does nothing for an non array/hash object' do
      object = Object.new
      result = described_class.deep_transform_keys(object, &:to_s)

      expect(result).to eq(object)
    end

    it 'returns the last value if different keys are transformed into the same one' do
      hash = { aa: 0, 'bb' => 2, bb: 1 }
      result = described_class.deep_transform_keys(hash, &:to_s)

      expect(result).to eq('aa' => 0, 'bb' => 1)
    end
  end
end
