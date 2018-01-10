module FormatParser
  class ParseConfig < Dry::Struct
    module Types
      include Dry::Types.module
    end
    attribute :natures, Types::Strict::Array.member(Symbol)
    attribute :formats, Types::Strict::Array.member(Symbol)
    attribute :limit,   Types::Strict::Int
  end
end
