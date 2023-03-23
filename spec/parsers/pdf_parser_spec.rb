require 'spec_helper'

describe FormatParser::PDFParser do

  def parse_pdf (pdf_filename)
    subject.call(
      File.open(
        Pathname.new(fixtures_dir).join('PDF').join(pdf_filename),
        'rb'
      )
    )
  end

  shared_examples :behave_like_pdf do |params|
    it "#{params[:file]} acts as a pdf" do
      parsed_pdf = parse_pdf params[:file]
      expect(parsed_pdf).not_to be_nil
      expect(parsed_pdf.nature).to eq(:document)
      expect(parsed_pdf.format).to eq(:pdf)
      expect(parsed_pdf.content_type).to eq('application/pdf')
    end
  end

  describe 'parses a PDF file' do
    describe 'a single page file' do
      include_examples :behave_like_pdf, file: '1_page.pdf'
    end

    describe 'various PDF versions' do
      include_examples :behave_like_pdf, file: 'Lorem Ipsum PDF 1.6.pdf'
      include_examples :behave_like_pdf, file: 'Lorem Ipsum PDF-A-1b.pdf'
      include_examples :behave_like_pdf, file: 'Lorem Ipsum PDF-A-2b.pdf'
      include_examples :behave_like_pdf, file: 'Lorem Ipsum PDF-A-3b.pdf'
      include_examples :behave_like_pdf, file: 'Lorem Ipsum PDF-UA.pdf'
      include_examples :behave_like_pdf, file: 'Lorem Ipsum Hybrid - ODF embedded.pdf'
      include_examples :behave_like_pdf, file: 'Simple PDF 2.0 file.pdf'
    end

    describe 'complex PDF 2.0 files' do
      include_examples :behave_like_pdf, file: 'PDF 2.0 image with BPC.pdf'
      include_examples :behave_like_pdf, file: 'PDF 2.0 UTF-8 string and annotation.pdf'
      include_examples :behave_like_pdf, file: 'PDF 2.0 via incremental save.pdf'
      include_examples :behave_like_pdf, file: 'PDF 2.0 with page level output intent.pdf'
      include_examples :behave_like_pdf, file: 'pdf20-utf8-test.pdf'
    end
  end

  describe 'broken PDF files should not parse' do
    it 'PDF with missing version header' do
      parsed_pdf = parse_pdf 'not_a.pdf'
      expect(parsed_pdf).to be_nil
    end

    it 'PDF 2.0 with offset start' do
      parsed_pdf = parse_pdf 'PDF 2.0 with offset start.pdf'
      expect(parsed_pdf).to be_nil
    end

    it 'exceeds the PDF read limit' do
      parsed_pdf = parse_pdf 'exceed_PDF_read_limit.pdf'
      expect(parsed_pdf).to be_nil
    end

  end
end


