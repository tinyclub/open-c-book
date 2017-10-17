all: serve

html:
	gitbook build

pdf:
	gitbook pdf

serve:
	gitbook serve > .gitbook-serve.log 2>&1 &

view:
	chromium-browser http://localhost:4000 >/dev/null 2>&1 &

read: view

read-pdf:
	chromium-browser book*.pdf >/dev/null 2>&1 &

read-html:
	chromium-browser _book/index.html >/dev/null 2>&1 &

clean:
	@rm -rf _book

distclean: clean
	@rm book*.pdf
