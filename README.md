# pdf-annotate
Mark PDF files as author copies using an automatically generated overlay

## Requirements

The following ruby gems need to be installed:
* bibtex
* pdfinfo

Furthermore, you need:
* a working LaTeX installation
* latexmk
* pdfinfo

## Usage

```
Usage: annotate.rb [options]

Available options:
    -b, --bibtex FILE                Obtain publication data from FILE
    -c, --copyright NAME             Copyright is held by NAME instead of publisher
    -i, --input FILE                 Read original PDF from FILE
    -k, --key KEY                    Use bibtex entry KEY
    -o, --output FILE                Write annotated PDF to FILE

Generic options:
    -h, --help                       Show this message and exit

```

The following arguments are mandatory:
* `--bibtex FILE`
Path to BibTeX file that contains an entry for the document to process
* `--input FILE`
Path to input PDF file
* `--key KEY`
BibTeX key for the document to process
* `--output FILE`
Path to output PDF file

The copyright holder is normally determined by the publisher field of the BibTeX entry. It can be overwritten using
`--copyright NAME`.
