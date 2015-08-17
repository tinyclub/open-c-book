
# Plugins

## Navigation

* [gitbook-plugin-anchor-navigation](https://github.com/yaneryou/gitbook-plugin-anchor-navigation)
    -   pdf 生成后，导航在页面底部
    -   展示的导航很漂亮
* [gitbook-plugin-maxiang](http://plugins.gitbook.com/plugin/maxiang)
    -   只默认支持两级(h2)
    -   不为 pdf 生成导航

* [gitbook-plugin-toc](http://plugins.gitbook.com/plugin/toc)
    -   需要修改 Markdown 文件，并且不支持中文，对于 pdf 可能会有一些用。可补充 maxiang（在anchor-navigation修复之前）

## Sidebar

* [tree](http://plugins.gitbook.com/plugin/tree)
    -   为侧边栏加树状结构
* [collapsible-menu](http://plugins.gitbook.com/plugin/collapsible-menu)
    -   可自动折叠边栏（不同与 tree 一起使用，效果不好）
* [toggle-chapters](http://plugins.gitbook.com/plugin/toggle-chapters)
    -   效果同上
* [gitbook-plugin-tocstyles](http://plugins.gitbook.com/plugin/tocstyles)
    -   可以设计更多侧边栏的花样，符合中文要求
* [gitbook-plugin-multipart](http://plugins.gitbook.com/plugin/multipart)
    -   在 Chapters 之上加 Part I/II

## Comments

* [disqus](http://plugins.gitbook.com/plugin/disqus)

## Code

* [gitbook-plugin-google_code_prettify](http://plugins.gitbook.com/plugin/google_code_prettify)

## Chinese

* [gitbook-plugin-betterchinese](http://plugins.gitbook.com/plugin/betterchinese)
    -   本地没有特别效果，需要到 gitbooks.io 上验证

## Introduction DIY

* [diy-introduction](http://plugins.gitbook.com/plugin/diy-introduction)
    -   未看到生效？

## Exercises

* [exercises](http://plugins.gitbook.com/plugin/exercises)
    -   可交互式的练习（很有意义），gitbook 2.0 因为 markdown 解析 `{%` 出错，导致无法使用。
    -   `sudo npm install gitbook -g gitbook@1.5.0`
    -   /usr/lib/node_modules/gitbook/bin/gitbook.js
    -   http://cowmanchiang.me/gitbook/gitbook/contents/plugin/exercises.html
