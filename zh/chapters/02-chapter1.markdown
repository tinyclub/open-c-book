# 把 Vim 打造成源代码编辑器

-    [前言](#toc_1212_1748_1)
-    [常规操作](#toc_1212_1748_2)
    -    [打开文件](#toc_1212_1748_3)
    -    [编辑文件](#toc_1212_1748_4)
    -    [保存文件](#toc_1212_1748_5)
    -    [退出/关闭](#toc_1212_1748_6)
-    [命令模式](#toc_1212_1748_7)
    -    [编码风格与 indent 命令](#toc_1212_1748_8)
    -    [用 Vim 命令养成良好编码风格](#toc_1212_1748_9)
-    [相关小技巧](#toc_1212_1748_10)
-    [后记](#toc_1212_1748_11)
-    [参考资料](#toc_1212_1748_12)


<span id="toc_1212_1748_1"></span>
## 前言

程序开发过程中，源代码的编辑主要是为了实现算法，结果则是一些可阅读的、便于检错的、可移植的文本文件。如何产生一份良好的源代码，这不仅需要一些良好的编辑工具，还需要开发人员养成良好的编程修养。

Linux 下有很多优秀的程序编辑工具，包括专业的文本编辑器和一些集成开发环境（IDE）提供的编辑工具，前者的代表作有 Vim 和 Emacs，后者的代表作则有 Eclipse，Kdevelop，Anjuta 等，这里主要介绍 Vim 的基本使用和配置。

<span id="toc_1212_1748_2"></span>
## 常规操作

通过 Vim 进行文本编辑的一般过程包括：文件的打开、编辑、保存、关闭/退出，而编辑则包括插入新内容、替换已有内容、查找内容，还包括复制、粘贴、删除等基本操作。

该过程如下图：

![Vim基本使用过程](pic/vim_basic_usage.jpg)

下面介绍几个主要操作：
   
<span id="toc_1212_1748_3"></span>
### 打开文件

在命令行下输入 `vim 文件名` 即可打开一个新文件并进入 Vim 的“编辑模式”。

编辑模式可以切换到命令模式（按下字符 `:`）和插入模式（按下字母 `a/A/i/I/o/O/s/S/c/C` 等或者 Insert 键）。

编辑模式下，Vim 会把键盘输入解释成 Vim 的编辑命令，以便实现诸如字符串查找(按下字母 `/`)、文本复制（按下字母 `yy`）、粘贴（按下字母 `pp`）、删除（按下字母 `d` 等）、替换（`s`）等各种操作。

当按下 `a/A/i/I/o/O/s/S/c/C` 等字符时，Vim 先执行这些字符对应命令的动作（比如移动光标到某个位置，删除某些字符），然后进入插入模式；进入插入模式后可以通过按下 ESC 键或者是 `CTRL+C` 返回到编辑模式。

在编辑模式下输入冒号 `:` 后可进入命令模式，通过它可以完成一些复杂的编辑功能，比如进行正则表达式匹配替换，执行 Shell 命令（按下 `!` 命令）等。

实际上，无论是插入模式还是命令模式都是编辑模式的一种。而编辑模式却并不止它们两个，还有字符串查找、删除、替换等。

需要提到的是，如果在编辑模式按下字母 `v/V` 或者是 `CTRL+V`，可以用光标选择一个区块，进而结合命令模式对这一个区块进行特定的操作。

<span id="toc_1212_1748_4"></span>
### 编辑文件

打开文件以后即可进入编辑模式，这时可以进行各种编辑操作，包括插入、复制、删除、替换字符。其中两种比较重要的模式经常被“独立”出来，即上面提到的插入模式和命令模式。
 
<span id="toc_1212_1748_5"></span>
### 保存文件

在退出之前需切换到命令模式，输入命令 `w` 以便保存各种编辑后的内容，如果想取消某种操作，可以用 `u` 命令。如果打开 Vim 编辑器时没有设定文件名，那么在按下 `w` 命令时会提示没有文件名，此时需要在 `w` 命令后加上需要保存的文件名。
 
<span id="toc_1212_1748_6"></span>
### 退出/关闭

保存好内容后就可退出，只需在命令模式下键入字符 `q`。如果对文件内容进行了编辑，却没有保存，那么 Vim 会提示，如果不想保存之前的编辑动作，那么可按下字符 `q` 并且在之后跟上一个感叹号`!`，这样会强制退出，不保存最近的内容变更。

<span id="toc_1212_1748_7"></span>
## 命令模式
 
这里需要着重提到的是 Vim 的命令模式，它是 Vim 扩展各种新功能的接口，用户可以通过它启用和撤销某个功能，开发人员则可通过它为用户提供新的功能。下面主要介绍通过命令模式这个接口定制 Vim 以便我们更好地进行源代码的编辑。

<span id="toc_1212_1748_8"></span>
### 编码风格与 indent 命令

先提一下编码风格。刚学习编程时，代码写得很“难看”（不方便阅读，不方便检错，看不出任何逻辑结构），常常导致心情不好，而且排错也很困难，所以逐渐意识到代码编写需要规范，即养成良好的编码风格，如果换成俗话，那就是代码的排版，让代码好看一些。虽说“编程的“（高雅一些则称开发人员）不一定懂艺术，不过这个应该不是“搞艺术的”（高雅一些应该是文艺工作人员）的特权，而是我们应该具备的专业素养。在 Linux 下，比较流行的“行业”风格有 KR 的编码风格、GNU 的编码风格、Linux 内核的编码风格（基于 KR 的，缩进是 8 个空格）等，它们都可以通过 `indent` 命令格式化，对应的选项分别是`-kr`，`-gnu`，`-kr -i8`。下面演示用 `indent` 命令把代码格式化成上面的三种风格。

这样糟糕的编码风格看着会让人想“哭”，太难阅读啦：

```
$ cat > test.c
/* test.c -- a test program for using indent */
#include<stdio.h>

int main(int argc, char *argv[])
{
 int i=0;
 if (i != 0) {i++; }
 else {i--; };
 for(i=0;i<5;i++)j++;
 printf("i=%d,j=%d\n",i,j);

 return 0;
}
```

格式化成 KR 风格，好看多了：

```
$ indent -kr test.c
$ cat test.c
/* test.c -- a test program for using indent */
#include<stdio.h>

int main(int argc, char *argv[])
{
    int i = 0;
    if (i != 0) {
        i++;
    } else {
        i--;
    };
    for (i = 0; i < 5; i++)
        j++;
    printf("i=%d,j=%d\n", i, j);
    return 0;
}
```

采用 GNU 风格，感觉不如 KR 的风格，处理 `if` 语句时增加了代码行，却并没明显改进效果：

```
$ indent -gnu test.c
$ cat test.c
/* test.c -- a test program for using indent */
#include<stdio.h>

int
main (int argc, char *argv[])
{
  int i = 0;
  if (i != 0)
    {
      i++;
    }
  else
    {
      i--;
    };
  for (i = 0; i < 5; i++)
    j++;
  printf ("i=%d,j=%d\n", i, j);
  return 0;
}
```

实际上 `indent` 命令有时候会不靠谱，也不建议“先污染再治理”，而是从一开始就坚持“可持续发展”的观念，在写代码时就逐步养成良好的风格。

需要提到地是，Linux 的编码风格描述文件为内核源码下的 [Documentation/CodingStyle](https://git.kernel.org/cgit/linux/kernel/git/torvalds/linux.git/plain/Documentation/CodingStyle)，而相应命令为 [scripts/Lindent](https://git.kernel.org/cgit/linux/kernel/git/torvalds/linux.git/plain/scripts/Lindent)。

<span id="toc_1212_1748_9"></span>
### 用 Vim 命令养成良好编码风格

从演示中可看出编码风格真地很重要，但是如何养成良好的编码风格呢？经常练习，遵守某个编码风格，一如既往。不过这还不够，如果没有一个好编辑器，习惯也很难养成。而 Vim 提供了很多辅助我们养成良好编码习惯的功能，这些都通过它的命令模式提供。现在分开介绍几个功能；

|Vim 命令         |   功效           |
|-----------------|------------------|
|`:syntax on`      | 语法加“靓”（亮） |
|`:syntax off`     | 语法不加“靓”（亮）|
|`:set cindent`    | C 语言自动缩进（可简写为`set cin`） |
|`:set sw=8`       | 自动缩进宽度（需要`set cin`才有用） |
|`:set ts=8`       | 设定 TAB 宽度 |
|`:set number`     | 显示行号      |
|`:set nonumber`   | 不显示行号    |
|`:setsm`          | 括号自动匹配  |

这几个命令对代码编写来说非常有用，可以考虑把它们全部写到 `~/.vimrc` 文件（Vim 启动时会去加载这个文件里头的内容）中，如：

```
$ cat ~/.vimrc
:set number
:set sw=8
:set ts=8
:set sm
:set cin
:syntax on
```

<span id="toc_1212_1748_10"></span>
## 相关小技巧

需要补充的几个技巧有；

-   对注释自动断行
    - 在编辑模式下，可通过 `gqap` 命令对注释自动断行（每行字符个数可通过命令模式下的 `set textwidth=个数` 设定）


-   跳到指定行
    - 命令模式下输入数字可以直接跳到指定行，也可在打开文件时用`vim +数字 文件名`实现相同的功能。


-   把 C 语言输出为 html
    - 命令模式下的`TOhtml`命令可把 C 语言输出为 html 文件，结合 `syntax on`，可产生比较好的网页把代码发布出去。


-   注释掉代码块
    - 先切换到可视模式（编辑模式下按字母 `v` 可切换过来），用光标选中一片代码，然后通过命令模式下的命令 `s#^#//#g` 把某这片代码注释掉，这非常方便调试某一片代码的功能。


-   切换到粘贴模式解决 Insert 模式自动缩进的问题
    - 命令模式下的 `set paste` 可解决复制本来已有缩进的代码的自动缩进问题，后可执行 `set nopaste` 恢复自动缩进。


-   使用 Vim 最新特性
    - 为了使用最新的 Vim 特性，可用 `set nocp` 取消与老版本的 Vi 的兼容。


-   全局替换某个变量名
    - 如发现变量命名不好，想在整个代码中修改，可在命令模式下用 `%s#old_variable#new_variable#g` 全局替换。替换的时注意变量名是其他变量一部分的情况。如果希望将变量"abc"全部替换成"xyz"又不希望把"abcd"错误替换成"xyzd",则可以在查找时指定边界:`%s#\<old_variable\>#new_variable#g`。


-   把缩进和 TAB 键都替换为空格
    - 可考虑设置 `expandtab`，即 `set et`，如果要把以前编写的代码中的缩进和 TAB 键都替换掉，可以用 `retab`。


-   关键字自动补全
    - 输入一部分字符后，按下 `CTRL+P` 或者 `CTRL+N` 即可。比如先输入 `prin`，然后按下 `CTRL+P/N` 就可以补全了。


-   在编辑模式下查看手册
    - 可把光标定位在某个函数，按下 `Shift+k` 就可以调出 `man`，很有用。


-   删除空行
    - 在命令模式下输入 `g/^$/d`，前面 `g` 命令是扩展到全局，中间是匹配空行，后面 `d` 命令是执行删除动作。用替换也可以实现，键入 `%s#^\n##g`，意思是把所有以换行开头的行全部替换为空。类似地，如果要把多个空行转换为一个可以输入 `g/^\n$/d` 或者 `%s#^\n$##g`。


-   创建与使用代码交叉引用
    - 注意利用一些有用的插件，比如 `ctags`, `cscope` 等，可以提高代码阅读、分析的效率。特别是开放的软件。


-   回到原位置
    - 在用 `ctags` 或 `cscope` 时，当找到某个标记后，又想回到原位置，可按下 `CTRL+T`。


这里特别提到 `cscope`，为了加速代码的阅读，还可以类似上面在 `~/.vimrc` 文件中通过 `map` 命令预定义一些快捷方式，例如：

```
if has("cscope")
          set csprg=/usr/bin/cscope
          set csto=0
          set cst
          set nocsverb
          " add any database in current directory
          if filereadable("cscope.out")
            cs add cscope.out
          " else add database pointed to by environment
          elseif $CSCOPE_DB != ""
            cs add $CSCOPE_DB
          endif
          set csverb
:map \ :cs find g <C-R>=expand("<cword>")<CR><CR>
:map s :cs find s <C-R>=expand("<cword>")<CR><CR>
:map t :cs find t <C-R>=expand("<cword>")<CR><CR>
:map c :cs find c <C-R>=expand("<cword>")<CR><CR>
:map C :cs find d <C-R>=expand("<cword>")<CR><CR>
:map f :cs find f <C-R>=expand("<cword>")<CR><CR>
endif
```

因为 `s,t,c,C,f` 这几个 Vim 的默认快捷键用得不太多，所以就把它们给作为快捷方式映射了，如果已经习惯它们作为其他的快捷方式就换别的字符吧。

**注** 上面很多技巧中用到了正则表达式，关于这部分请参考：[正则表达式 30 分钟入门教程](http://deerchao.net/tutorials/regex/regex.htm)。

更多的技巧可以看看后续资料。

<span id="toc_1212_1748_11"></span>
## 后记

实际上，在源代码编写时还有很多需要培养的“素质”，例如源文件的开头注释、函数的注释，变量的命名等。这方面建议看看参考资料里的编程修养、内核编码风格、网络上流传的《华为编程规范》，以及《[C Traps & Pitfalls](https://en.wikipedia.org/wiki/C_Traps_and_Pitfalls)》, 《[C-FAQ](http://c-faq.com/)》等。

<span id="toc_1212_1748_12"></span>
## 参考资料

-   Vim 官方教程，在命令行下键入 vimtutor 即可
-   vim 实用技术序列
    - [实用技巧](http://www.ibm.com/developerworks/cn/linux/l-tip-vim1/)
    - [常用插件](http://www.ibm.com/developerworks/cn/linux/l-tip-vim2/)
    - [定制 Vim](http://www.ibm.com/developerworks/cn/linux/l-tip-vim3/)
-   [Graphical vi-vim Cheat Sheet and Tutorial](http://www.viemu.com/a_vi_vim_graphical_cheat_sheet_tutorial.html)
-   [Documentation/CodingStyle](https://git.kernel.org/cgit/linux/kernel/git/torvalds/linux.git/plain/Documentation/CodingStyle)
-   [scripts/Lindent](https://git.kernel.org/cgit/linux/kernel/git/torvalds/linux.git/plain/scripts/Lindent)。
-   [正则表达式 30 分钟入门教程](http://deerchao.net/tutorials/regex/regex.htm)
-   [也谈 C 语言编程风格：完成从程序员到工程师的蜕变](http://www.tinylab.org/talk-about-c-language-programming-style/)
-   Vim 高级命令集锦
-   编程修养
-   C Traps & Pitfalls
-   C FAQ
