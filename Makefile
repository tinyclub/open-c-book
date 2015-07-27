all:
	gitbook build
	gitbook pdf

read:
	evince book.pdf

clean:
	@rm -rf _book

distclean: clean
	@rm book.pdf
