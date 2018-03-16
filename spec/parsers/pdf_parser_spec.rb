require 'spec_helper'

describe FormatParser::PDFParser do
  let(:parsed_pdf) {
    subject.call(
      File.open(
        Pathname.new(fixtures_dir).join('PDF').join(pdf_file),
        'rb'
      )
    )
  }

  shared_examples :behave_like_pdf do |hash|
    let(:pdf_file) { hash.fetch(:file) }

    it 'acts as a pdf' do
      expect(parsed_pdf).not_to be_nil
      expect(parsed_pdf.nature).to eq(:document)
      expect(parsed_pdf.format).to eq(:pdf)
    end

    it 'has a correct page count' do
      expect(parsed_pdf.page_count).to eq(hash.fetch(:page_count))
    end
  end

  describe 'a PDF file with a missing version header' do
    let(:pdf_file) { 'not_a.pdf' }

    it 'does not parse succesfully' do
      expect(parsed_pdf).to be_nil
    end
  end

  describe 'a PDF file with a correct header but no valid content' do
    let(:pdf_file) { 'broken.pdf' }

    pending 'does not parse succesfully'
  end

  describe 'exceeding the PDF read limit' do
    let(:pdf_file) { 'read_limit.pdf' }

    pending 'does not parse succesfully'
  end

  describe 'a PDF file with a missing COUNT_HEADER' do
    let(:pdf_file) { 'missing_page_count.pdf' }

    it 'does not return a page count' do
      expect(parsed_pdf.page_count).to eq(nil)
    end
  end

  describe 'parses a PDF file' do
    describe 'a single page file' do
      include_examples :behave_like_pdf, file: '1_page.pdf', page_count: 1
    end

    describe 'a multi page pdf file' do
      include_examples :behave_like_pdf, file: '2_pages.pdf', page_count: 2
    end

    describe 'a multi page pdf file with content' do
      include_examples :behave_like_pdf, file: '10_pages.pdf', page_count: 10
    end
  end
end
