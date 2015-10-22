# Introduction

gitbook is supported, please [install gitbook](http://www.tinylab.org/docker-quick-start-docker-gitbook-writing-a-book/) and simply build it as followiing:

## Installation

    $ sudo aptitude install -y retext git nodejs npm
    $ sudo ln -fs /usr/bin/nodejs /usr/bin/node
    $ sudo aptitude install -y calibre fonts-arphic-gbsn00lp
    $ npm config set registry https://registry.npm.taobao.org
    $ sudo npm install gitbook-cli -g

## Compile

    $ gitbook build
    $ gitbook pdf
