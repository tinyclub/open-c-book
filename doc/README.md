

# C语言编程透视 

- Author: Wu Zhangjin <wuzhangjin@gmail.com>
- Date  : Sun Jan 19 22:05:51 CST 2014

## Introduction

2007年开始系统地学习Shell编程，并在[兰大开源社区](http://oss.lzu.edu.cn)写了序列文章。

在编写Shell序列文章的[《进程操作》](http://www.tinylab.org/shell-programming-paradigm-of-process-operations/)一章时，为了全面了解进程的来龙去脉，对程序开发过程的细节、ELF格式的分析、进程的内存映像等进行了全面地梳理，后来搞得“雪球越滚越大”，甚至脱离了Shell编程关注的内容。所以想了个小办法，“大事化小，小事化了”，把涉及到的内容进行了分解，进而演化成另外一个完整的序列。

类似于[《Shell编程序列》](http://www.tinylab.org/shell-programming-paradigm-series-index-review/)，相关文章也在网路上有较多的转载，说明确实有一定的读者，为了更完整地呈现给读者，这里计划重新全面地整理。

《Shell编程序列》已经作为自由书籍发布：

- Project Homepage: <http://www.tinylab.org/project/pleac-shell/>
- Project Repository: [https://gitlab.com/tinylab/pleac-shell.git](https://gitlab.com/tinylab/pleac-shell)

## Outline

-   《把VIM打造成源代码编辑器》（源代码编辑过程：用VIM编辑代码的一些技巧）（更新时间：2008-2-22）
-   《GCC编译的背后》（编译过程：预处理、编译、汇编、链接）
    - 第一部分：《预处理和编译》（更新时间：2008-2-22）
    - 第二部分：《汇编和链接》（更新时间：2008-2-22）
-   《程序执行的那一刹那 》（执行过程：当我们从命令行输入一个命令之后）（更新时间：2008-2-15）
-   《进程的内存映像》 （进程加载过程：程序在内存里是个什么样子）
    - 第一部分（讨论“缓冲区溢出和注入”问题）（更新时间：2008-2-13）
    - 第二部分（讨论进程的内存分别情况）（更新时间：2008-6-1）
-   《动态符号链接的细节》（动态链接过程：函数puts/printf的地址在哪里）（更新时间：2008-2-26）
-   《代码测试、调试与优化小结》（程序开发过后：内存溢出了吗？有缓冲区溢出？代码覆盖率如何测试呢？怎么调试汇编代码？有哪些代码优化技巧和方法呢？）（更新时间：2008-2-29）
-   《为可执行文件“减肥”》（从”减肥”的角度一层一层剖开ELF文件）（更新时间：2008-2-23）
-   《进程和进程的基本操作》（描述进程相关概念和基本操作）（更新时间：2008-2-21）

## Schedule

争取在一个礼拜左右整理完初稿，两个礼拜内整理完成后正式对外发布Review版本，一个月内正式发布0.1版本。

争取在1.0版本时完成该书的大部分目标，并争取出版社的支持，进行出版。

## References

- [《Shell编程序列》](http://www.tinylab.org/shell-programming-paradigm-series-index-review/)
