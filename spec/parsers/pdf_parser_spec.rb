require 'spec_helper'

describe FormatParser::PDFParser do
  shared_examples :behave_like_pdf do |hash|
    let(:parsed_pdf) {
      subject.call(
        File.open(fixtures_dir + '/' + hash.fetch(:file), 'rb')
      )
    }

    it 'acts as a pdf' do
      expect(parsed_pdf).not_to be_nil
      expect(parsed_pdf.nature).to eq(:document)
      expect(parsed_pdf.format).to eq(:pdf)
    end

    it 'has a correct page count' do
      expect(parsed_pdf.page_count).to eq(hash.fetch(:page_count))
    end
  end

  describe 'parses a PDF file' do
    describe 'a single page file' do
      include_examples :behave_like_pdf, file: '1_page.pdf', page_count: 1
    end

    describe 'a multi page pdf file' do
      include_examples :behave_like_pdf, file: '2_pages.pdf', page_count: 2
    end
  end
end
