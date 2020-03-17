#!/usr/bin/env ruby
# encoding: UTF-8

Encoding.default_external = Encoding::UTF_8

require "optparse"
require "tmpdir"

begin
  require "bibtex"
  require "pdfinfo"
rescue LoadError => err
  $stderr.puts
  $stderr.puts "ERROR: The following ruby gems are required: bibtex-ruby pdfinfo"
  $stderr.puts "Please try running the following command:"
  $stderr.puts
  $stderr.puts "gem install bibtex pdfinfo"
  $stderr.puts
  $stderr.puts "Original error message:"
  $stderr.puts err.to_s
  exit 1
end

# get command line options
options = {}
begin
  parser = OptionParser.new do |opts|
    opts.banner = "Usage: #{opts.program_name} [options]"

    opts.separator ""
    opts.separator "Available options:"
    opts.on("-b", "--bibtex FILE", "Obtain publication data from FILE") { |v| options[:bibfile] = v }
    opts.on("-c", "--copyright NAME", "Copyright is held by NAME instead of publisher") { |v| options[:copyright] = v }
    opts.on("-i", "--input FILE", "Read original PDF from FILE") { |v| options[:infile] = v }
    opts.on("-k", "--key KEY", "Use bibtex entry KEY") { |v| options[:bibkey] = v }
    opts.on("-o", "--output FILE", "Write annotated PDF to FILE") { |v| options[:outfile] = v }

    opts.separator ""
    opts.separator "Generic options:"
    opts.on_tail("-h", "--help", "Show this message and exit") do
      puts opts
      exit 0
    end
  end
  parser.parse!
rescue OptionParser::InvalidOption => e
  $stderr.puts "ERROR: #{e.message}"
  $stderr.puts
  $stderr.puts parser
  exit 1
end

if (options[:bibfile].nil? || options[:infile].nil? || options[:bibkey].nil? || options[:outfile].nil?)
  $stderr.puts "ERROR: Missing arguments"
  $stderr.puts
  $stderr.puts parser
  exit 1
end

bibfile = File.expand_path(options[:bibfile])
bibkey = options[:bibkey]
infile = File.expand_path(options[:infile])
outfile = File.expand_path(options[:outfile])

unless File.exist?(bibfile)
  $stderr.puts("ERROR: Bibtex file not found")
  exit 1
end

unless File.exist?(infile)
  $stderr.puts("ERROR: Input file not found")
  exit 1
end

begin
  bib = BibTeX.open(bibfile)
rescue BibTeX::ParseError => err
  $stderr.puts "ERROR: Could not parse the bibtex library"
  $stderr.puts
  $stderr.puts err
  exit 1
end

if bib[bibkey].nil?
  $stderr.puts("ERROR: Key not found in bibtex file")
  exit 1
end

bibentry = bib[bibkey]
bibentry.replace

# For now we only know how to annotate certain types of entries
case bibentry.type.to_s
when "inbook" then pubname = bibentry.title
when "article" then pubname = bibentry.journal
when "inproceedings" then pubname = bibentry.booktitle
when "incollection" then pubname = bibentry.booktitle
else begin
  $stderr.puts("ERROR: Publication type not supported")
  exit 1
end
end

if options[:copyright].nil?
  if (!bibentry.has_field?("publisher") || bibentry.fields[:publisher].empty?)
    $stderr.puts("ERROR: Bibtex entry contains no publisher. Specify copyright holder.")
    exit 1
  end

  # Workaround for some publishers with deviating copyright holder
  case bibentry.publisher.to_s
  when "IEEE Computer Society" then copyright = "IEEE"
  else copyright = bibentry.publisher
  end
else
  copyright = options[:copyright]
end

pdfinfo = Pdfinfo.new(infile).pages[0]

Dir.mktmpdir { |tmpdir|
  File.open(File.join(tmpdir, bibentry.key + ".tex"), "w") do |output|
    File.open(File.join(__dir__, "/overlay.tex"), "r") do |input|
      while line = input.gets
        output.puts line.gsub(/%%[A-Z]*%%/,
                              "%%WIDTH%%" => pdfinfo.width,
                              "%%HEIGHT%%" => pdfinfo.height,
                              "%%FILENAME%%" => bibentry.key + "-orig",
                              "%%YEAR%%" => bibentry.year,
                              "%%DOI%%" => (bibentry.has_field?("doi") ? bibentry.doi.gsub("_", '\_') : ""),
                              "%%PUBNAME%%" => pubname.gsub(". ", '.\ '),
                              "%%COPYRIGHT%%" => copyright.gsub(". ", '.\ '))
      end
    end
  end

  FileUtils.cp(infile, File.join(tmpdir, bibentry.key + "-orig.pdf"))
  Dir.chdir(tmpdir) do
    system ("latexmk -pdf " + bibentry.key)
  end

  outdir = File.dirname(outfile)
  FileUtils.mkdir_p outdir
  FileUtils.cp(File.join(tmpdir, bibentry.key + ".pdf"), outfile)
}
