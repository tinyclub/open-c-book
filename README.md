> 联系作者：笔者为一位[重度开源践行者](http://tinylab.org/hello-tinylab/#section-2)，可微信联系：lzufalcon<br>
> 本书来源：[开源书籍：C 语言编程透视](http://www.tinylab.org/open-c-book/) (by [泰晓科技](http://tinylab.org))<br>
> 报名参与：*Star/fork* [GitHub 仓库](https://github.com/tinyclub/open-c-book) 并发送 *Pull Request*<br>
> 关注我们：[扫描二维码](#follow) 关注 [@泰晓科技](http://weibo.com/tinylaborg) 微博和微信公众号<br>
> 赞助我们：[捐助我们](#donate), [更多原创开源书籍](#more)需要您的支持 ^o^ <br>

# C 语言编程透视

v 0.2

本书与[《深入淺出 Hello World》](http://blog.linux.org.tw/~jserv/archives/001844.html)有着类似的心路历程，旨在以实验的方式去探究类似 `Hello World` 这样的小程序在开发与执行过程中的微妙变化，一层层揭开 C 语言程序开发过程的神秘面纱，透视背后的秘密，不断享受醍醐灌顶的美妙。

## 介绍

- 项目首页：<http://www.tinylab.org/open-c-book>
- 代码仓库：<https://github.com/tinyclub/open-c-book>
- 在线阅读：<http://tinylab.gitbooks.io/cbook>

    更多背景和计划请参考：[前言](zh/preface/01-chapter1.markdown)。

### 安装

以 Debian/Ubuntu 为例：

    $ sudo apt-get install retext git nodejs npm
    $ sudo apt-get install calibre fonts-arphic-gbsn00lp
    $ sudo npm install gitbook-cli -g
    $ sudo rm /usr/local/bin/gitbook
    $ sudo sh -c 'echo "nodejs /usr/local/lib/node_modules/gitbook-cli/bin/gitbook.js \$@" > /usr/local/bin/gitbook'
    $ sudo chmod +x /usr/local/bin/gitbook
    $ gitbook install


### 下载

    $ git clone https://github.com/tinyclub/open-c-book.git
    $ cd open-c-book/

### 编译

    $ gitbook build  // 编译成网页
    $ gitbook pdf    // 编译成 pdf

### 纠错

欢迎大家指出不足，如有任何疑问，请邮件联系 wuzhangjin at gmail dot com 或者直接修复并提交 Pull Request。

### 版权

本书采用 ![CC BY NC ND 4.0](http://i.creativecommons.org/l/by-nc-nd/4.0/88x31.png) 协议发布，详细版权信息请参考 [CC BY NC ND 4.0](http://creativecommons.org/licenses/by-nc-nd/4.0/)。

<hr>

<span id="follow"></span>
### 关注我们

-   [新浪微博](http://weibo.com/tinylaborg)

   [<img src="pic/tinylab-sina.jpg" width="168px"/>](http://weibo.com/tinylaborg)

-   微信公众号

   <img src="pic/tinylab-weixin.jpg" width="168px"/>


<span id="donate"></span>
### 赞助我们

* 微信扫码赞助原创

    <img src="pic/tinylab-sponsor.jpg" width="168px"/>

* 访问 [泰晓开源小店](http://weidian.com/?userid=335178200) 支持心仪项目

    [<img src="pic/tinylab-shop.jpg" width="168px"/>](http://weidian.com/?userid=335178200)

<span id="more"></span>
### 更多原创开源书籍

* [Shell 编程范例](http://tinylab.gitbooks.io/shellbook/)
* [嵌入式 Linux 知识库(eLinux.org 中文版)](http://tinylab.gitbooks.io/elinux/)
* [Linux 内核文档(Linux Documentation/ 中文版)](http://tinylab.gitbooks.io/linux-doc/)
