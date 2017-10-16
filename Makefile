all: install
	gitbook build

pdf: install
	gitbook pdf

install:
	gitbook install

read-pdf:
	evince book.pdf

read: read-html

read-html:
	chromium-browser _book/index.html

clean:
	@rm -rf _book

distclean: clean
	@rm book.pdf
