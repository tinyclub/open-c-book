# Introduction #

As open source books, ebooks and pdf format should be created on fly, the following sections describe those solution in detail.

The solution below is based on [Pro Git][progit]; while it is little updated on format inside. 

# Making Pdf books #
PDF format is used to read/print in nice way like real book, [pandoc][pandoc] good at this and it is used instead to generate latex from markdown, and latex tool `xelatex` (is part of [TexLive][texlive] now) is used to convert pdf from latex.

Please check [ctax](http://www.ctan.org/) and [TexLive][texlive] for more background for latex, which is quite complicated and elegant if you have never touched before.

## Ubuntu Platform ##

Ubuntu Platform Oneiric (11.10) is used mainly due to pandoc. 

[pandoc][pandoc] can be installed directly from source, which version is 1.8.x. If you use Ubuntu 11.04, then it is just 1.5.x.

Though texlive 2011 can be installed separately, the default one texlive 2009 from Ubuntu repository is good enough so far. 

    $ sudo apt-get install ruby1.9.1
    $ sudo apt-get install pandoc
    $ sudo apt-get install texlive-xetex
    $ sudo apt-get install texlive-latex-recommended # main packages
    $ sudo apt-get install texlive-latex-extra # package titlesec
	
You need to install related fonts for Chinese, fortunately they exist in ubuntu source also.
    
    $ sudo apt-get install ttf-arphic-gbsn00lp ttf-arphic-ukai # from arphic 
    $ sudo apt-get install ttf-wqy-microhei ttf-wqy-zenhei     # from WenQuanYi

Install more

    $ sudo gem install debugger-linecache debugger-ruby_core_source ruby-debug-base19 ruby_core_source

Then it should work perfectly

    $ make 

Read the book

    $ make read

Convert html to markdown

    $ pandoc -f html -t markdown test.html -o test.markdown
    or
    $ tools/h2m test.html

Configure book

    $ vim config/basic.yml
    and
    $ vim config/main.yml

Modify the latex template

    $ vim latex/template.tex

Update version

    $ vim version

Release the book

    $ make release

Just remind you, some [extra pandoc markdown format](http://johnmacfarlane.net/pandoc/README.html) is used inside this book:

  * code syntax highlight (doesn't work in pdf, while it should work in html/epub which needed later)
  * footnote
    	
[pandoc]: http://johnmacfarlane.net/pandoc/    
[calibre]: http://calibre-ebook.com/
[progit]: http://github.com/progit/progit 
[texlive]: http://www.tug.org/texlive/
