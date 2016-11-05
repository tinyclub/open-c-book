# 前言

-    [背景](#toc_1235_30984_1)
-    [现状](#toc_1235_30984_2)
-    [计划](#toc_1235_30984_3)


<span id="toc_1235_30984_1"></span>
## 背景

笔者 2007 年开始系统地学习 Shell 编程，并在[兰大开源社区](http://oss.lzu.edu.cn)写了序列文章。

在编写[《Shell 编程范例》](http://tinylab.gitbooks.io/shellbook)文章的[《进程操作》](http://tinylab.gitbooks.io/shellbook/content/zh/chapters/01-chapter7.html)一章时，为了全面了解进程的来龙去脉，对程序开发过程的细节、ELF 格式的分析、进程的内存映像等进行了全面地梳理，后来搞得“雪球越滚越大”，甚至脱离了 Shell 编程关注的内容。所以想了个小办法，“大事化小，小事化了”，把涉及到的内容进行了分解，进而演化成另外一个完整的序列。

2008 年 3 月 1 日，当初步完成整个序列时，做了如下的小结：

> 到今天，关于"Linux 下 C 语言开发过程"的一个简单视图总算粗略地完成了，从寒假之前的一段时间到现在过了将近一个月左右吧。写这个主题的目的源自“Shell 编程范例之进程操作”，当写到这一章时，突然对进程的由来、本身和去向感到“迷惑不解”。所以想着好好花些时间来弄清楚它们，现在发现，这个由来就是这里的程序开发过程，进程来自一个普通的文本文件，在这里是 C 语言程序，C 语言程序经过编辑、预处理、编译、汇编、链接、执行而成为一个进程；而进程本身呢？当一个可执行文件被执行以后，有了 exec 调用，被程序解释器映射到了内存中，有了它的内存映像；而进程的去向呢？通过不断地执行指令和内存映像的变化，进程完成着各项任务，等任务完成以后就可以退出了（exit）。
>
> 这样一份视图实际上是在寒假之前绘好的，可以从下图中看到它；不过到现在才明白背后的很多细节。这些细节就是这个序列的每个篇章，可以对照“视图”来阅读它们。

![C语言程序开发过程视图](pic/c_dev_procedure.jpg)

<span id="toc_1235_30984_2"></span>
## 现状

目前整个序列大部分都已经以 Blog 的形式写完，大体结构目下：

-   [《把 VIM 打造成源代码编辑器》][1]
    -   源代码编辑过程：用 VIM 编辑代码的一些技巧
    -   更新时间：2008-2-22


-   [《GCC 编译的背后》][2]
    -   编译过程：预处理、编译、汇编、链接
    -   第一部分：《预处理和编译》（更新时间：2008-2-22）
    -   第二部分：《汇编和链接》（更新时间：2008-2-22）


-   [《程序执行的那一刹那 》][3]
    -   执行过程：当从命令行输入一个命令之后
    -   更新时间：2008-2-15


-   [《进程的内存映像》][4] 
    -   进程加载过程：程序在内存里是个什么样子？
    -   第一部分（讨论“缓冲区溢出和注入”问题）（更新时间：2008-2-13）
    -   第二部分（讨论进程的内存分布情况）（更新时间：2008-6-1）


-   [《进程和进程的基本操作》][5]
    -   进程操作：描述进程相关概念和基本操作
    -   更新时间：2008-2-21


-   [《动态符号链接的细节》][6]
    -   动态链接过程：函数 puts/printf 的地址在哪里？
    -   更新时间：2008-2-26


-   [《打造史上最小可执行ELF文件》][7]
    -   ELF 详解：从”减肥”的角度一层一层剖开 ELF 文件，最终获得一个可打印 Hello World 的 **45** 字节 ELF 可执行文件
    -   更新时间：2008-2-23


-   [《代码测试、调试与优化小结》][8]
    -   程序开发过后：内存溢出了吗？有缓冲区溢出？代码覆盖率如何测试呢？怎么调试汇编代码？有哪些代码优化技巧和方法呢？
    -   更新时间：2008-2-29

[1]: http://www.tinylab.org/make-vim-source-code-editor/
[2]: http://www.tinylab.org/behind-the-gcc-compiler/
[3]: http://www.tinylab.org/program-execution-the-moment/
[4]: http://www.tinylab.org/process-memory-image/ 
[5]: http://www.tinylab.org/process-and-basic-operation/
[6]: http://www.tinylab.org/details-of-a-dynamic-symlink/
[7]: http://www.tinylab.org/as-an-executable-file-to-slim-down/
[8]: http://www.tinylab.org/testing-debugging-and-optimization-of-code-summary/

<span id="toc_1235_30984_3"></span>
## 计划

考虑到整个 Linux 世界的蓬勃发展，Linux 和 C 语言的应用环境越来越多，相关使用群体会不断增加，所以最近计划把该序列重新整理，以自由书籍的方式不断更新，以便惠及更多的读者。

打算重新规划、增补整个序列，并以开源项目的方式持续维护，并通过 [泰晓科技|TinyLab.org](http://tinylab.org) 平台接受读者的反馈，直到正式发行出版。

自由书籍将会维护在 [泰晓科技](http://tinylab.org) 的[项目仓库](https://github.com/tinyclub/open-c-book)中。项目相关信息如下：

-   项目首页：<http://www.tinylab.org/open-c-book/>
-   代码仓库：[https://github.com/tinyclub/open-c-book.git](https://github.com/tinyclub/open-c-book)

欢迎大家指出本书初稿中的不足，甚至参与到相关章节的写作、校订和完善中来。

如果有时间和兴趣，欢迎参与。可以通过 [泰晓科技](http://www.tinylab.org/about/) 联系我们，或者直接关注微博[@泰晓科技](http://weibo.com/tinylaborg)并私信我们。
