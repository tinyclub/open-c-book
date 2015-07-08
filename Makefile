# Makefile for open source book

# Get configs
bookCfg := config/basic.yml
bookName := $(shell cat $(bookCfg) | grep name | cut -d':' -f2 | tr -d ' ')
bookLang := $(shell cat $(bookCfg) | grep lang: | cut -d':' -f2 | tr -d ' ')
bookCover:= $(shell cat $(bookCfg) | grep cover: | cut -d':' -f2 | tr -d ' ')
outDir   := pdf

short_fileName := $(bookName).$(bookLang).pdf

# tools
make_pdf := tools/makepdf

# Get release version
bookVersion := $(shell cat version)
long_fileName := $(bookName).$(bookLang).book.$(bookVersion).pdf

# pdf versions
bookInput  := $(outDir)/$(short_fileName)
bookOutput := $(outDir)/$(long_fileName)

# build targets
all: $(bookInput)
	gitbook build

$(bookInput): clean
	@$(make_pdf)
	gitbook pdf

read:
	evince $(bookInput)

release: $(bookInput)
	@echo -e -n "\n\tRelease Version $(bookVersion):"
	@cp $(bookInput) $(bookOutput) 2>&1 > /dev/null
	@echo -e "\t$(outDir)/${bookName}.${bookLang}.book.${bookVersion}.pdf"

clean:
	@rm -rf latex/zh/*

distclean: clean
	@rm -rf pdf/*
