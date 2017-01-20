# 打造史上最小可执行 ELF 文件（45 字节，可打印字符串）

-    [前言](#toc_3928_6176_1)
-    [可执行文件格式的选取](#toc_3928_6176_2)
-    [链接优化](#toc_3928_6176_3)
-    [可执行文件“减肥”实例（从6442到708字节）](#toc_3928_6176_4)
    -    [系统默认编译](#toc_3928_6176_5)
    -    [不采用默认编译](#toc_3928_6176_6)
    -    [删除对程序运行没有影响的节区](#toc_3928_6176_7)
    -    [删除可执行文件的节区表](#toc_3928_6176_8)
-    [用汇编语言来重写 Hello World（76字节）](#toc_3928_6176_9)
    -    [采用默认编译](#toc_3928_6176_10)
    -    [删除掉汇编代码中无关紧要内容](#toc_3928_6176_11)
    -    [不默认编译并删除掉无关节区和节区表](#toc_3928_6176_12)
    -    [用系统调用取代库函数](#toc_3928_6176_13)
    -    [把字符串作为参数输入](#toc_3928_6176_14)
    -    [寄存器赋值重用](#toc_3928_6176_15)
    -    [通过文件名传递参数](#toc_3928_6176_16)
    -    [删除非必要指令](#toc_3928_6176_17)
-    [合并代码段、程序头和文件头（52字节）](#toc_3928_6176_18)
    -    [把代码段移入文件头](#toc_3928_6176_19)
    -    [把程序头移入文件头](#toc_3928_6176_20)
    -    [在非连续的空间插入代码](#toc_3928_6176_21)
    -    [把程序头完全合入文件头](#toc_3928_6176_22)
-    [汇编语言极限精简之道（45字节）](#toc_3928_6176_23)
-    [小结](#toc_3928_6176_24)
-    [参考资料](#toc_3928_6176_25)


<span id="toc_3928_6176_1"></span>
## 前言

本文从减少可执行文件大小的角度分析了 `ELF` 文件，期间通过经典的 `Hello World` 实例逐步演示如何通过各种常用工具来分析 `ELF` 文件，并逐步精简代码。

为了能够尽量减少可执行文件的大小，我们必须了解可执行文件的格式，以及链接生成可执行文件时的后台细节（即最终到底有哪些内容被链接到了目标代码中）。通过选择合适的可执行文件格式并剔除对可执行文件的最终运行没有影响的内容，就可以实现目标代码的裁减。因此，通过探索减少可执行文件大小的方法，就相当于实践性地去探索了可执行文件的格式以及链接过程的细节。

当然，算法的优化和编程语言的选择可能对目标文件的大小有很大的影响，在本文最后我们会跟参考资料 [\[1\]][1] 的作者那样去探求一个打印 `Hello World` 的可执行文件能够小到什么样的地步。

<span id="toc_3928_6176_2"></span>
## 可执行文件格式的选取

可执行文件格式的选择要满足的一个基本条件是：目标系统支持该可执行文件格式，资料 [\[2\]][2] 分析和比较了 `UNIX` 平台下的三种可执行文件格式，这三种格式实际上代表着可执行文件的一个发展过程：

- a.out 文件格式非常紧凑，只包含了程序运行所必须的信息（文本、数据、 `BSS`），而且每个 `section` 的顺序是固定的。

- coff 文件格式虽然引入了一个节区表以支持更多节区信息，从而提高了可扩展性，但是这种文件格式的重定位在链接时就已经完成，因此不支持动态链接（不过扩展的 `coff` 支持）。

- elf 文件格式不仅动态链接，而且有很好的扩展性。它可以描述可重定位文件、可执行文件和可共享文件（动态链接库）三类文件。

下面来看看 `ELF` 文件的结构图：

```
文件头部(ELF Header)
程序头部表(Program Header Table)
节区1(Section1)
节区2(Section2)
节区3(Section3)
...
节区头部(Section Header Table)
```

无论是文件头部、程序头部表、节区头部表还是各个节区，都是通过特定的结构体 `(struct)描述的，这些结构在 `elf.h` 文件中定义。文件头部用于描述整个文件的类型、大小、运行平台、程序入口、程序头部表和节区头部表等信息。例如，我们可以通过文件头部查看该 `ELF` 文件的类型。

```
$ cat hello.c   #典型的hello, world程序
#include <stdio.h>

int main(void)
{
	printf("hello, world!\n");
	return 0;
}
$ gcc -c hello.c   #编译，产生可重定向的目标代码
$ readelf -h hello.o | grep Type   #通过readelf查看文件头部找出该类型
  Type:                              REL (Relocatable file)
$ gcc -o hello hello.o   #生成可执行文件
$ readelf -h hello | grep Type
  Type:                              EXEC (Executable file)
$ gcc -fpic -shared -Wl,-soname,libhello.so.0 -o libhello.so.0.0 hello.o  #生成共享库
$ readelf -h libhello.so.0.0 | grep Type
  Type:                              DYN (Shared object file)
```

那节区头部表（将简称节区表）和程序头部表有什么用呢？实际上前者只对可重定向文件有用，而后者只对可执行文件和可共享文件有用。

节区表是用来描述各节区的，包括各节区的名字、大小、类型、虚拟内存中的位置、相对文件头的位置等，这样所有节区都通过节区表给描述了，这样连接器就可以根据文件头部表和节区表的描述信息对各种输入的可重定位文件进行合适的链接，包括节区的合并与重组、符号的重定位（确认符号在虚拟内存中的地址）等，把各个可重定向输入文件链接成一个可执行文件（或者是可共享文件）。如果可执行文件中使用了动态连接库，那么将包含一些用于动态符号链接的节区。我们可以通过 `readelf -S` （或 `objdump -h`）查看节区表信息。

```
$ readelf -S hello  #可执行文件、可共享库、可重定位文件默认都生成有节区表
...
Section Headers:
  [Nr] Name              Type            Addr     Off    Size   ES Flg Lk Inf Al
  [ 0]                   NULL            00000000 000000 000000 00      0   0  0
  [ 1] .interp           PROGBITS        08048114 000114 000013 00   A  0   0  1
  [ 2] .note.ABI-tag     NOTE            08048128 000128 000020 00   A  0   0  4
  [ 3] .hash             HASH            08048148 000148 000028 04   A  5   0  4
...
    [ 7] .gnu.version      VERSYM          0804822a 00022a 00000a 02   A  5   0  2
...
  [11] .init             PROGBITS        08048274 000274 000030 00  AX  0   0  4
...
  [13] .text             PROGBITS        080482f0 0002f0 000148 00  AX  0   0 16
  [14] .fini             PROGBITS        08048438 000438 00001c 00  AX  0   0  4
...
```

三种类型文件的节区（各个常见节区的作用请参考资料 [\[11\]][11])可能不一样，但是有几个节区，例如 `.text`，`.data`，`.bss` 是必须的，特别是 `.text`，因为这个节区包含了代码。如果一个程序使用了动态链接库（引用了动态连接库中的某个函数），那么需要 `.interp` 节区以便告知系统使用什么动态连接器程序来进行动态符号链接，进行某些符号地址的重定位。通常，`.rel.text` 节区只有可重定向文件有，用于链接时对代码区进行重定向，而 `.hash`，`.plt`，`.got` 等节区则只有可执行文件（或可共享库）有，这些节区对程序的运行特别重要。还有一些节区，可能仅仅是用于注释，比如 `.comment`，这些对程序的运行似乎没有影响，是可有可无的，不过有些节区虽然对程序的运行没有用处，但是却可以用来辅助对程序进行调试或者对程序运行效率有影响。

虽然三类文件都必须包含某些节区，但是节区表对可重定位文件来说才是必须的，而程序的执行却不需要节区表，只需要程序头部表以便知道如何加载和执行文件。不过如果需要对可执行文件或者动态连接库进行调试，那么节区表却是必要的，否则调试器将不知道如何工作。下面来介绍程序头部表，它可通过 `readelf -l`（或 `objdump -p`）查看。

```
$ readelf -l hello.o #对于可重定向文件，gcc没有产生程序头部，因为它对可重定向文件没用

There are no program headers in this file.
$  readelf -l hello  #而可执行文件和可共享文件都有程序头部
...
Program Headers:
  Type           Offset   VirtAddr   PhysAddr   FileSiz MemSiz  Flg Align
  PHDR           0x000034 0x08048034 0x08048034 0x000e0 0x000e0 R E 0x4
  INTERP         0x000114 0x08048114 0x08048114 0x00013 0x00013 R   0x1
      [Requesting program interpreter: /lib/ld-linux.so.2]
  LOAD           0x000000 0x08048000 0x08048000 0x00470 0x00470 R E 0x1000
  LOAD           0x000470 0x08049470 0x08049470 0x0010c 0x00110 RW  0x1000
  DYNAMIC        0x000484 0x08049484 0x08049484 0x000d0 0x000d0 RW  0x4
  NOTE           0x000128 0x08048128 0x08048128 0x00020 0x00020 R   0x4
  GNU_STACK      0x000000 0x00000000 0x00000000 0x00000 0x00000 RW  0x4

 Section to Segment mapping:
  Segment Sections...
   00
   01     .interp
   02     .interp .note.ABI-tag .hash .gnu.hash .dynsym .dynstr .gnu.version .gnu.version_r .rel.dyn .rel.plt .init .plt .text .fini .rodata .eh_frame
   03     .ctors .dtors .jcr .dynamic .got .got.plt .data .bss
   04     .dynamic
   05     .note.ABI-tag
   06
$ readelf -l libhello.so.0.0  #节区和上面类似，这里省略
```

从上面可看出程序头部表描述了一些段（`Segment`），这些段对应着一个或者多个节区，上面的 `readelf -l` 很好地显示了各个段与节区的映射。这些段描述了段的名字、类型、大小、第一个字节在文件中的位置、将占用的虚拟内存大小、在虚拟内存中的位置等。这样系统程序解释器将知道如何把可执行文件加载到内存中以及进行动态链接等动作。

该可执行文件包含 7 个段，`PHDR` 指程序头部，`INTERP` 正好对应 `.interp` 节区，两个 `LOAD` 段包含程序的代码和数据部分，分别包含有 `.text` 和 `.data`，`.bss` 节区，`DYNAMIC` 段包含 `.daynamic`，这个节区可能包含动态连接库的搜索路径、可重定位表的地址等信息，它们用于动态连接器。 `NOTE` 和 `GNU_STACK` 段貌似作用不大，只是保存了一些辅助信息。因此，对于一个不使用动态连接库的程序来说，可能只包含 `LOAD` 段，如果一个程序没有数据，那么只有一个 `LOAD` 段就可以了。

总结一下，Linux 虽然支持很多种可执行文件格式，但是目前 `ELF` 较通用，所以选择 `ELF` 作为我们的讨论对象。通过上面对 `ELF` 文件分析发现一个可执行的文件可能包含一些对它的运行没用的信息，比如节区表、一些用于调试、注释的节区。如果能够删除这些信息就可以减少可执行文件的大小，而且不会影响可执行文件的正常运行。

<span id="toc_3928_6176_3"></span>
## 链接优化

从上面的讨论中已经接触了动态连接库。 `ELF` 中引入动态连接库后极大地方便了公共函数的共享，节约了磁盘和内存空间，因为不再需要把那些公共函数的代码链接到可执行文件，这将减少了可执行文件的大小。

与此同时，静态链接可能会引入一些对代码的运行可能并非必须的内容。你可以从[《GCC 编译的背后（第二部分：汇编和链接）》][100] 了解到 `GCC` 链接的细节。从那篇 Blog 中似乎可以得出这样的结论：仅仅从是否影响一个 C 语言程序运行的角度上说，`GCC` 默认链接到可执行文件的几个可重定位文件 （`crt1.o`，`rti.o`，`crtbegin.o`，`crtend.o`，`crtn.o`）并不是必须的，不过值得注意的是，如果没有链接那些文件但在程序末尾使用了 `return` 语句，`main` 函数将无法返回，因此需要替换为 `_exit` 调用；另外，既然程序在进入 `main` 之前有一个入口，那么 `main` 入口就不是必须的。因此，如果不采用默认链接也可以减少可执行文件的大小。

[100]: 02-chapter2.markdown

<span id="toc_3928_6176_4"></span>
## 可执行文件“减肥”实例（从6442到708字节）

这里主要是根据上面两点来介绍如何减少一个可执行文件的大小。以 `Hello World` 为例。

首先来看看默认编译产生的 `Hello World` 的可执行文件大小。

<span id="toc_3928_6176_5"></span>
### 系统默认编译

代码同上，下面是一组演示，

```
$ uname -r   #先查看内核版本和gcc版本，以便和你的结果比较
2.6.22-14-generic
$ gcc --version
gcc (GCC) 4.1.3 20070929 (prerelease) (Ubuntu 4.1.2-16ubuntu2)
...
$ gcc -o hello hello.c   #默认编译
$ wc -c hello   #产生一个大小为6442字节的可执行文件
6442 hello
```

<span id="toc_3928_6176_6"></span>
### 不采用默认编译

可以考虑编辑时就把 `return 0` 替换成 `_exit(0)` 并包含定义该函数的 `unistd.h` 头文件。下面是从[《GCC 编译的背后（第二部分：汇编和链接）》][100]总结出的 `Makefile` 文件。

[100]: 02-chapter2.markdown

```
#file: Makefile
#functin: for not linking a program as the gcc do by default
#author: falcon<zhangjinw@gmail.com>
#update: 2008-02-23

MAIN = hello
SOURCE =
OBJS = hello.o
TARGET = hello
CC = gcc-3.4 -m32
LD = ld -m elf_i386

CFLAGSs += -S
CFLAGSc += -c
LDFLAGS += -dynamic-linker /lib/ld-linux.so.2 -L /usr/lib/ -L /lib -lc
RM = rm -f
SEDc = sed -i -e '/\#include[ "<]*unistd.h[ ">]*/d;' \
	-i -e '1i \#include <unistd.h>' \
	-i -e 's/return 0;/_exit(0);/'
SEDs = sed -i -e 's/main/_start/g'

all: $(TARGET)

$(TARGET):
	@$(SEDc) $(MAIN).c
	@$(CC) $(CFLAGSs) $(MAIN).c
	@$(SEDs) $(MAIN).s
	@$(CC) $(CFLAGSc) $(MAIN).s $(SOURCE)
	@$(LD) $(LDFLAGS) -o $@ $(OBJS)
clean:
	@$(RM) $(MAIN).s $(OBJS) $(TARGET)
```

把上面的代码复制到一个Makefile文件中，并利用它来编译hello.c。

```
$ make   #编译
$ ./hello   #这个也是可以正常工作的
Hello World
$ wc -c hello   #但是大小减少了4382个字节，减少了将近 70%
2060 hello
$ echo "6442-2060" | bc
4382
$ echo "(6442-2060)/6442" | bc -l
.68022353306426575597
```

对于一个比较小的程序，能够减少将近 70% “没用的”代码。

<span id="toc_3928_6176_7"></span>
### 删除对程序运行没有影响的节区

使用上述 `Makefile` 来编译程序，不链接那些对程序运行没有多大影响的文件，实际上也相当于删除了一些“没用”的节区，可以通过下列演示看出这个实质。

```
$ make clean
$ make
$ readelf -l hello | grep "0[0-9]\ \ "
   00
   01     .interp
   02     .interp .hash .dynsym .dynstr .gnu.version .gnu.version_r .rel.plt .plt .text .rodata
   03     .dynamic .got.plt
   04     .dynamic
   05
$ make clean
$ gcc -o hello hello.c
$ readelf -l hello | grep "0[0-9]\ \ "
   00
   01     .interp
   02     .interp .note.ABI-tag .hash .gnu.hash .dynsym .dynstr .gnu.version .gnu.version_r
	  .rel.dyn .rel.plt .init .plt .text .fini .rodata .eh_frame
   03     .ctors .dtors .jcr .dynamic .got .got.plt .data .bss
   04     .dynamic
   05     .note.ABI-tag
   06
```

通过比较发现使用自定义的 `Makefile` 文件，少了这么多节区： `.bss .ctors .data .dtors .eh_frame .fini .gnu.hash .got .init .jcr .note.ABI-tag .rel.dyn` 。
再看看还有哪些节区可以删除呢？通过之前的分析发现有些节区是必须的，那 `.hash?.gnu.version?` 呢，通过 `strip -R`（或 `objcop -R`）删除这些节区试试。

```
$ wc -c hello   #查看大小，以便比较
2060
$ time ./hello    #我们比较一下一些节区对执行时间可能存在的影响
Hello World

real    0m0.001s
user    0m0.000s
sys     0m0.000s
$ strip -R .hash hello   #删除.hash节区
$ wc -c hello
1448 hello
$ echo "2060-1448" | bc   #减少了612字节
612
$ time ./hello           #发现执行时间长了一些（实际上也可能是进程调度的问题）
Hello World

real    0m0.006s
user    0m0.000s
sys     0m0.000s
$ strip -R .gnu.version hello   #删除.gnu.version还是可以工作
$ wc -c hello
1396 hello
$ echo "1448-1396" | bc      #又减少了52字节
52
$ time ./hello
Hello World

real    0m0.130s
user    0m0.004s
sys     0m0.000s
$ strip -R .gnu.version_r hello   #删除.gnu.version_r就不工作了
$ time ./hello
./hello: error while loading shared libraries: ./hello: unsupported version 0 of Verneed record
```

通过删除各个节区可以查看哪些节区对程序来说是必须的，不过有些节区虽然并不影响程序的运行却可能会影响程序的执行效率，这个可以上面的运行时间看出个大概。
通过删除两个“没用”的节区，我们又减少了 `52+612`，即 664 字节。

<span id="toc_3928_6176_8"></span>
### 删除可执行文件的节区表

用普通的工具没有办法删除节区表，但是参考资料[\[1\]][1]的作者已经写了这样一个工具。你可以从[这里](http://www.muppetlabs.com/~breadbox/software/elfkickers.html)下载到那个工具，它是该作者写的一序列工具 `ELFkickers` 中的一个。

下载并编译（**注**：1.0 之前的版本才支持 32 位和正常编译，新版本在代码中明确限定了数据结构为 `Elf64`）：

```
$ git clone https://github.com/BR903/ELFkickers
$ cd ELFkickers/sstrip/
$ git checkout f0622afa    # 检出 1.0 版
$ make
```

然后复制到 `/usr/bin` 下，下面用它来删除节区表。

```
$ sstrip hello      #删除ELF可执行文件的节区表
$ ./hello           #还是可以正常运行，说明节区表对可执行文件的运行没有任何影响
Hello World
$ wc -c hello       #大小只剩下708个字节了
708 hello
$ echo "1396-708" | bc  #又减少了688个字节。
688
```

通过删除节区表又把可执行文件减少了 688 字节。现在回头看看相对于 `gcc` 默认产生的可执行文件，通过删除一些节区和节区表到底减少了多少字节？减幅达到了多少？

```
$ echo "6442-708" | bc   #
5734
$ echo "(6442-708)/6442" | bc -l
.89009624340266997826
```

减少了 5734 多字节，减幅将近 `90%`，这说明：对于一个简短的 `hello.c` 程序而言，`gcc` 引入了将近 `90%` 的对程序运行没有影响的数据。虽然通过删除节区和节区表，使得最终的文件只有 708 字节，但是打印一个 `Hello World` 真的需要这么多字节么？事实上未必，因为：

- 打印一段 `Hello World` 字符串，我们无须调用 `printf`，也就无须包含动态连接库，因此 `.interp`，`.dynamic` 等节区又可以去掉。为什么？我们可以直接使用系统调用 `(sys_write)来打印字符串。
- 另外，我们无须把 `Hello World` 字符串存放到可执行文件中？而是让用户把它当作参数输入。

下面，继续进行可执行文件的“减肥”。

<span id="toc_3928_6176_9"></span>
## 用汇编语言来重写"Hello World"（76字节）

<span id="toc_3928_6176_10"></span>
### 采用默认编译

先来看看 `gcc` 默认产生的汇编代码情况。通过 `gcc` 的 `-S` 选项可得到汇编代码。

```
$ cat hello.c  #这个是使用_exit和printf函数的版本
#include <stdio.h>      /* printf */
#include <unistd.h>     /* _exit */

int main()
{
	printf("Hello World\n");
	_exit(0);
}
$ gcc -S hello.c    #生成汇编
$ cat hello.s       #这里是汇编代码
	.file   "hello.c"
	.section        .rodata
.LC0:
	.string "Hello World"
	.text
.globl main
	.type   main, @function
main:
	leal    4(%esp), %ecx
	andl    $-16, %esp
	pushl   -4(%ecx)
	pushl   %ebp
	movl    %esp, %ebp
	pushl   %ecx
	subl    $4, %esp
	movl    $.LC0, (%esp)
	call    puts
	movl    $0, (%esp)
	call    _exit
	.size   main, .-main
	.ident  "GCC: (GNU) 4.1.3 20070929 (prerelease) (Ubuntu 4.1.2-16ubuntu2)"
	.section        .note.GNU-stack,"",@progbits
$ gcc -o hello hello.s   #看看默认产生的代码大小
$ wc -c hello
6523 hello
```

<span id="toc_3928_6176_11"></span>
### 删除掉汇编代码中无关紧要内容

现在对汇编代码 `hello.s` 进行简单的处理得到，

```
.LC0:
	.string "Hello World"
	.text
.globl main
	.type   main, @function
main:
	leal    4(%esp), %ecx
	andl    $-16, %esp
	pushl   -4(%ecx)
	pushl   %ebp
	movl    %esp, %ebp
	pushl   %ecx
	subl    $4, %esp
	movl    $.LC0, (%esp)
	call    puts
	movl    $0, (%esp)
	call    _exit
```

再编译看看，

```
$ gcc -o hello.o hello.s
$ wc -c hello
6443 hello
$ echo "6523-6443" | bc   #仅仅减少了80个字节
80
```

<span id="toc_3928_6176_12"></span>
### 不默认编译并删除掉无关节区和节区表

如果不采用默认编译呢并且删除掉对程序运行没有影响的节区和节区表呢？

```
$ sed -i -e "s/main/_start/g" hello.s   #因为没有初始化，所以得直接进入代码，替换main为_start
$ as --32 -o  hello.o hello.s
$ ld -melf_i386 -o hello hello.o --dynamic-linker /lib/ld-linux.so.2 -L /usr/lib -lc
$ ./hello
hello world!
$ wc -c hello
1812 hello
$ echo "6443-1812" | bc -l   #和之前的实验类似，也减少了4k左右
4631
$ readelf -l hello | grep "\ [0-9][0-9]\ "
   00
   01     .interp
   02     .interp .hash .dynsym .dynstr .gnu.version .gnu.version_r .rel.plt .plt .text
   03     .dynamic .got.plt
   04     .dynamic
$ strip -R .hash hello
$ strip -R .gnu.version hello
$ wc -c hello
1200 hello
$ sstrip hello
$ wc -c hello  #这个结果比之前的708（在删除所有垃圾信息以后）个字节少了708-676，即32个字节
676 hello
$ ./hello
Hello World
```

容易发现这 32 字节可能跟节区 `.rodata` 有关系，因为刚才在链接完以后查看节区信息时，并没有 `.rodata` 节区。

<span id="toc_3928_6176_13"></span>
### 用系统调用取代库函数

前面提到，实际上还可以不用动态连接库中的 `printf` 函数，也不用直接调用 `_exit`，而是在汇编里头使用系统调用，这样就可以去掉和动态连接库关联的内容。如果想了解如何在汇编中使用系统调用，请参考资料 [\[9\]][9]。使用系统调用重写以后得到如下代码，

```
.LC0:
	.string "Hello World\xa\x0"
	.text
.global _start
_start:
	xorl   %eax, %eax
	movb   $4, %al                  #eax = 4, sys_write(fd, addr, len)
	xorl   %ebx, %ebx
	incl   %ebx                     #ebx = 1, standard output
	movl   $.LC0, %ecx              #ecx = $.LC0, the address of string
	xorl   %edx, %edx
	movb   $13, %dl                 #edx = 13, the length of .string
	int    $0x80
	xorl   %eax, %eax
	movl   %eax, %ebx               #ebx = 0
	incl   %eax                     #eax = 1, sys_exit
	int    $0x80
```

现在编译就不再需要动态链接器 `ld-linux.so` 了，也不再需要链接任何库。

```
$ as --32 -o hello.o hello.s
$ ld -melf_i386 -o hello hello.o
$ readelf -l hello

Elf file type is EXEC (Executable file)
Entry point 0x8048062
There are 1 program headers, starting at offset 52

Program Headers:
  Type           Offset   VirtAddr   PhysAddr   FileSiz MemSiz  Flg Align
  LOAD           0x000000 0x08048000 0x08048000 0x0007b 0x0007b R E 0x1000

 Section to Segment mapping:
  Segment Sections...
   00     .text
$ sstrip hello
$ ./hello           #完全可以正常工作
Hello World
$ wc -c hello
123 hello
$ echo "676-123" | bc   #相对于之前，已经只需要123个字节了，又减少了553个字节
553
```

可以看到效果很明显，只剩下一个 `LOAD` 段，它对应 `.text` 节区。

<span id="toc_3928_6176_14"></span>
### 把字符串作为参数输入

不过是否还有办法呢？把 `Hello World` 作为参数输入，而不是硬编码在文件中。所以如果处理参数的代码少于 `Hello World` 字符串的长度，那么就可以达到减少目标文件大小的目的。

先来看一个能够打印程序参数的汇编语言程序，它来自参考资料[\[9\]][9]。

```
.text
.globl _start

_start:
	popl    %ecx            # argc
vnext:
	popl    %ecx            # argv
	test    %ecx, %ecx      # 空指针表明结束
	jz      exit
	movl    %ecx, %ebx
	xorl    %edx, %edx
strlen:
	movb    (%ebx), %al
	inc     %edx
	inc     %ebx
	test    %al, %al
	jnz     strlen
	movb    $10, -1(%ebx)
	movl    $4, %eax        # 系统调用号(sys_write)
	movl    $1, %ebx        # 文件描述符(stdout)
	int     $0x80
	jmp     vnext
exit:
	movl    $1,%eax         # 系统调用号(sys_exit)
	xorl    %ebx, %ebx      # 退出代码
	int     $0x80
	ret
```

编译看看效果，

```
$ as --32 -o args.o args.s
$ ld -melf_i386 -o args args.o
$ ./args "Hello World"  #能够打印输入的字符串，不错
./args
Hello World
$ sstrip args
$ wc -c args           #处理以后只剩下130字节
130 args
```

可以看到，这个程序可以接收用户输入的参数并打印出来，不过得到的可执行文件为 130 字节，比之前的 123 个字节还多了 7 个字节，看看还有改进么？分析上面的代码后，发现，原来的代码有些地方可能进行优化，优化后得到如下代码。

```
.global _start
_start:
	popl %ecx        #弹出argc
vnext:
	popl %ecx        #弹出argv[0]的地址
	test %ecx, %ecx  #空指针表明结束
	jz exit
	movl %ecx, %ebx  #复制字符串地址到ebx寄存器
	xorl %edx, %edx  #把字符串长度清零
strlen:                         #求输入字符串的长度
	movb (%ebx), %al        #复制字符到al，以便判断是否为字符串结束符\0
	inc %edx                #edx存放每个当前字符串的长度
	inc %ebx                #ebx存放每个当前字符的地址
	test %al, %al           #判断字符串是否结束，即是否遇到\0
	jnz strlen
	movb $10, -1(%ebx)      #在字符串末尾插入一个换行符\0xa
	xorl %eax, %eax
	movb $4, %al            #eax = 4, sys_write(fd, addr, len)
	xorl %ebx, %ebx
	incl %ebx               #ebx = 1, standard output
	int $0x80
	jmp vnext
exit:
	xorl %eax, %eax
	movl %eax, %ebx                 #ebx = 0
	incl %eax               #eax = 1, sys_exit
	int $0x80
```

再测试（记得先重新汇编、链接并删除没用的节区和节区表）。

```
$ wc -c hello
124 hello
```

现在只有 124 个字节，不过还是比 123 个字节多一个，还有什么优化的办法么？

先来看看目前 `hello` 的功能，感觉不太符合要求，因为只需要打印 `Hello World`，所以不必处理所有的参数，仅仅需要接收并打印一个参数就可以。这样的话，把 `jmp vnext`（2 字节）这个循环去掉，然后在第一个 `pop %ecx` 语句之前加一个 `pop %ecx`（1 字节）语句就可以。

```
.global _start
_start:
	popl %ecx
	popl %ecx        #弹出argc[0]的地址
	popl %ecx        #弹出argv[1]的地址
	test %ecx, %ecx
	jz exit
	movl %ecx, %ebx
	xorl %edx, %edx
strlen:
	movb (%ebx), %al
	inc %edx
	inc %ebx
	test %al, %al
	jnz strlen
	movb $10, -1(%ebx)
	xorl %eax, %eax
	movb $4, %al
	xorl %ebx, %ebx
	incl %ebx
	int $0x80
exit:
	xorl %eax, %eax
	movl %eax, %ebx
	incl %eax
	int $0x80
```

现在刚好 123 字节，和原来那个代码大小一样，不过仔细分析，还是有减少代码的余地：因为在这个代码中，用了一段额外的代码计算字符串的长度，实际上如果仅仅需要打印 `Hello World`，那么字符串的长度是固定的，即 12 。所以这段代码可去掉，与此同时测试字符串是否为空也就没有必要（不过可能影响代码健壮性！），当然，为了能够在打印字符串后就换行，在串的末尾需要加一个回车（`$10`）并且设置字符串的长度为 `12+1`，即 13，

```
.global _start
_start:
	popl %ecx
	popl %ecx
	popl %ecx
	movb $10,12(%ecx) #在Hello World的结尾加一个换行符
	xorl %edx, %edx
	movb $13, %dl
	xorl %eax, %eax
	movb $4, %al
	xorl %ebx, %ebx
	incl %ebx
	int $0x80
	xorl %eax, %eax
	movl %eax, %ebx
	incl %eax
	int $0x80
```

再看看效果，

```
$ wc -c hello
111 hello
```

<span id="toc_3928_6176_15"></span>
### 寄存器赋值重用

现在只剩下 111 字节，比刚才少了 12 字节。貌似到了极限？还有措施么？

还有，仔细分析发现：系统调用 `sys_exit` 和 `sys_write` 都用到了 `eax` 和 `ebx` 寄存器，它们之间刚好有那么一点巧合：

- sys_exit 调用时，`eax` 需要设置为 1，`ebx` 需要设置为 0 。
- sys_write 调用时，`ebx` 刚好是 1 。

因此，如果在 `sys_exit` 调用之前，先把 `ebx` 复制到 `eax` 中，再对 `ebx` 减一，则可减少两个字节。

不过，因为标准输入、标准输出和标准错误都指向终端，如果往标准输入写入一些东西，它还是会输出到标准输出上，所以在上述代码中如果在 `sys_write` 之前 `ebx` 设置为 0，那么也可正常往屏幕上打印 `Hello World`，这样的话，`sys_exit` 调用前就没必要修改 `ebx`，而仅需把 `eax` 设置为 1，这样就可减少 3 个字节。

```
.global _start
_start:
	popl %ecx
	popl %ecx
	popl %ecx
	movb $10,12(%ecx)
	xorl %edx, %edx
	movb $13, %dl
	xorl %eax, %eax
	movb $4, %al
	xorl %ebx, %ebx
	int $0x80
	xorl %eax, %eax
	incl %eax
	int $0x80
```

看看效果，

```
$ wc -c hello
108 hello
```

现在看一下纯粹的指令还有多少？

```
$ readelf -h hello | grep Size
  Size of this header:               52 (bytes)
  Size of program headers:           32 (bytes)
  Size of section headers:           0 (bytes)
$  echo "108-52-32" | bc
24
```

<span id="toc_3928_6176_16"></span>
### 通过文件名传递参数

对于标准的 `main` 函数的两个参数，文件名实际上作为第二个参数（数组）的第一个元素传入，如果仅仅是为了打印一个字符串，那么可以打印文件名本身。例如，要打印 `Hello World`，可以把文件名命名为 `Hello World` 即可。

这样地话，代码中就可以删除掉一条 `popl` 指令，减少 1 个字节，变成 107 个字节。

```
.global _start
_start:
	popl %ecx
	popl %ecx
	movb $10,12(%ecx)
	xorl %edx, %edx
	movb $13, %dl
	xorl %eax, %eax
	movb $4, %al
	xorl %ebx, %ebx
	int $0x80
	xorl %eax, %eax
	incl %eax
	int $0x80
```

看看效果，

```
$ as --32 -o hello.o hello.s
$ ld -melf_i386 -o hello hello.o
$ sstrip hello
$ wc -c hello
107
$ mv hello "Hello World"
$ export PATH=./:$PATH
$ Hello\ World
Hello World
```

<span id="toc_3928_6176_17"></span>
### 删除非必要指令

在测试中发现，`edx`，`eax`，`ebx` 的高位即使不初始化，也常为 0，如果不考虑健壮性（仅这里实验用，实际使用中必须考虑健壮性），几条 `xorl` 指令可以移除掉。

另外，如果只是为了演示打印字符串，完全可以不用打印换行符，这样下来，代码可以综合优化成如下几条指令：

```
.global _start
_start:
	popl %ecx	# argc
	popl %ecx	# argv[0]
	movb $5, %dl	# 设置字符串长度
	movb $4, %al	# eax = 4, 设置系统调用号, sys_write(fd, addr, len) : ebx, ecx, edx
	int $0x80
	movb $1, %al
	int $0x80
```

看看效果：

```
$ as --32 -o hello.o hello.s
$ ld -melf_i386 -o hello hello.o
$ sstrip hello
$ wc -c hello
96
```

<span id="toc_3928_6176_18"></span>
## 合并代码段、程序头和文件头（52字节）

<span id="toc_3928_6176_19"></span>
### 把代码段移入文件头

纯粹的指令只有 `96-84=12` 个字节了，还有办法再减少目标文件的大小么？如果看了参考资料 [\[1\]][1]，看样子你又要蠢蠢欲动了：这 12 个字节是否可以插入到文件头部或程序头部？如果可以那是否意味着还可减少可执行文件的大小呢？现在来比较一下这三部分的十六进制内容。

```
$ hexdump -C hello -n 52     #文件头(52bytes)
00000000  7f 45 4c 46 01 01 01 00  00 00 00 00 00 00 00 00  |.ELF............|
00000010  02 00 03 00 01 00 00 00  54 80 04 08 34 00 00 00  |........T...4...|
00000020  00 00 00 00 00 00 00 00  34 00 20 00 01 00 00 00  |........4. .....|
00000030  00 00 00 00                                       |....|
00000034
$ hexdump -C hello -s 52 -n 32    #程序头(32bytes)
00000034  01 00 00 00 00 00 00 00  00 80 04 08 00 80 04 08  |................|
00000044  6c 00 00 00 6c 00 00 00  05 00 00 00 00 10 00 00  |l...l...........|
00000054
$ hexdump -C hello -s 84          #实际代码部分(12bytes)
00000054  59 59 b2 05 b0 04 cd 80  b0 01 cd 80              |YY..........|
00000060
```

从上面结果发现 `ELF` 文件头部和程序头部还有好些空洞（0），是否可以把指令字节分散放入到那些空洞里或者是直接覆盖掉那些系统并不关心的内容？抑或是把代码压缩以后放入可执行文件中，并在其中实现一个解压缩算法？还可以是通过一些代码覆盖率测试工具（`gcov`，`prof`）对你的代码进行优化？

在继续介绍之前，先来看一个 `dd` 工具，可以用来直接“编辑” `ELF` 文件，例如，

直接往指定位置写入 `0xff` ：

```
$ hexdump -C hello -n 16	# 写入前，elf文件前16个字节
00000000  7f 45 4c 46 01 01 01 00  00 00 00 00 00 00 00 00  |.ELF............|
00000010
$ echo -ne "\xff" | dd of=hello bs=1 count=1 seek=15 conv=notrunc	# 把最后一个字节0覆盖掉
1+0 records in
1+0 records out
1 byte (1 B) copied, 3.7349e-05 s, 26.8 kB/s
$ hexdump -C hello -n 16	# 写入后果然被覆盖
00000000  7f 45 4c 46 01 01 01 00  00 00 00 00 00 00 00 ff  |.ELF............|
00000010
```

- `seek=15` 表示指定写入位置为第 15 个（从第 0 个开始）
- `conv=notrunc` 选项表示要保留写入位置之后的内容，默认情况下会截断。
- `bs=1` 表示一次读/写 1 个
- `count=1` 表示总共写 1 次

覆盖多个连续的值：

把第 12，13，14，15 连续 4 个字节全部赋值为 `0xff` 。

```
$ echo -ne "\xff\xff\xff\xff" | dd of=hello bs=1 count=4 seek=12 conv=notrunc
$ hexdump -C hello -n 16
00000000  7f 45 4c 46 01 01 01 00  00 00 00 00 ff ff ff ff  |.ELF............|
00000010
```

下面，通过往文件头指定位置写入 `0xff` 确认哪些部分对于可执行文件的执行是否有影响？这里是逐步测试后发现依然能够执行的情况：

```
$ hexdump -C hello
00000000  7f 45 4c 46 ff ff ff ff  ff ff ff ff ff ff ff ff  |.ELF............|
00000010  02 00 03 00 ff ff ff ff  54 80 04 08 34 00 00 00  |........T...4...|
00000020  ff ff ff ff ff ff ff ff  34 00 20 00 01 00 ff ff  |........4. .....|
00000030  ff ff ff ff 01 00 00 00  00 00 00 00 00 80 04 08  |................|
00000040  00 80 04 08 60 00 00 00  60 00 00 00 05 00 00 00  |....`...`.......|
00000050  00 10 00 00 59 59 b2 05  b0 04 cd 80 b0 01 cd 80  |....YY..........|
00000060
```

可以发现，文件头部分，有 30 个字节即使被篡改后，该可执行文件依然可以正常执行。这意味着，这 30 字节是可以写入其他代码指令字节的。而我们的实际代码指令只剩下 12 个，完全可以直接移到前 12 个 `0xff` 的位置，即从第 4 个到第 15 个。

而代码部分的起始位置，通过 `readelf -h` 命令可以看到：

```
$ readelf -h hello | grep "Entry"
  Entry point address:               0x8048054
```

上面地址的最后两位 `0x54=84` 就是代码在文件中的偏移，也就是刚好从程序头之后开始的，也就是用文件头（52）+程序头（32）个字节开始的 12 字节覆盖到第 4 个字节开始的 12 字节内容即可。

上面的 `dd` 命令从 `echo` 命令获得输入，下面需要通过可执行文件本身获得输入，先把代码部分移过去：

```
$ dd if=hello of=hello bs=1 skip=84 count=12 seek=4 conv=notrunc
12+0 records in
12+0 records out
12 bytes (12 B) copied, 4.9552e-05 s, 242 kB/s
$ hexdump -C hello
00000000  7f 45 4c 46 59 59 b2 05  b0 04 cd 80 b0 01 cd 80  |.ELFYY..........|
00000010  02 00 03 00 01 00 00 00  54 80 04 08 34 00 00 00  |........T...4...|
00000020  00 00 00 00 00 00 00 00  34 00 20 00 01 00 00 00  |........4. .....|
00000030  00 00 00 00 01 00 00 00  00 00 00 00 00 80 04 08  |................|
00000040  00 80 04 08 60 00 00 00  60 00 00 00 05 00 00 00  |....`...`.......|
00000050  00 10 00 00 59 59 b2 05  b0 04 cd 80 b0 01 cd 80  |....YY..........|
00000060
```

接着把代码部分截掉：

```
$ dd if=hello of=hello bs=1 count=1 skip=84 seek=84
0+0 records in
0+0 records out
0 bytes (0 B) copied, 1.702e-05 s, 0.0 kB/s
$ hexdump -C hello
00000000  7f 45 4c 46 59 59 b2 05  b0 04 cd 80 b0 01 cd 80  |.ELFYY..........|
00000010  02 00 03 00 01 00 00 00  54 80 04 08 34 00 00 00  |........T...4...|
00000020  00 00 00 00 00 00 00 00  34 00 20 00 01 00 00 00  |........4. .....|
00000030  00 00 00 00 01 00 00 00  00 00 00 00 00 80 04 08  |................|
00000040  00 80 04 08 60 00 00 00  60 00 00 00 05 00 00 00  |....`...`.......|
00000050  00 10 00 00                                       |....|
00000054
```

这个时候还不能执行，因为代码在文件中的位置被移动了，相应地，文件头中的 `Entry point address`，即文件入口地址也需要被修改为 `0x8048004` 。

即需要把 `0x54` 所在的第 24 个字节修改为 `0x04` ：

```
$ echo -ne "\x04" | dd of=hello bs=1 count=1 seek=24 conv=notrunc
1+0 records in
1+0 records out
1 byte (1 B) copied, 3.7044e-05 s, 27.0 kB/s
$ hexdump -C hello
00000000  7f 45 4c 46 59 59 b2 05  b0 04 cd 80 b0 01 cd 80  |.ELFYY..........|
00000010  02 00 03 00 01 00 00 00  04 80 04 08 34 00 00 00  |............4...|
00000020  84 00 00 00 00 00 00 00  34 00 20 00 01 00 28 00  |........4. ...(.|
00000030  05 00 02 00 01 00 00 00  00 00 00 00 00 80 04 08  |................|
00000040  00 80 04 08 60 00 00 00  60 00 00 00 05 00 00 00  |....`...`.......|
00000050  00 10 00 00
```

修改后就可以执行了。

<span id="toc_3928_6176_20"></span>
### 把程序头移入文件头

程序头部分经过测试发现基本上都不能修改并且需要是连续的，程序头有 32 个字节，而文件头中连续的 `0xff` 可以被篡改的只有从第 46 个开始的 6 个了，另外，程序头刚好是 `01 00` 开头，而第 44，45 个刚好为 `01 00`，这样地话，这两个字节文件头可以跟程序头共享，这样地话，程序头就可以往文件头里头移动 8 个字节了。

```
$ dd if=hello of=hello bs=1 skip=52 seek=44 count=32 conv=notrunc
```

再把最后 8 个没用的字节删除掉，保留 `84-8=76` 个字节：

```
$ dd if=hello of=hello bs=1 skip=76 seek=76
$ hexdump -C hello
00000000  7f 45 4c 46 59 59 b2 05  b0 04 cd 80 b0 01 cd 80  |.ELFYY..........|
00000010  02 00 03 00 01 00 00 00  04 80 04 08 34 00 00 00  |............4...|
00000020  84 00 00 00 00 00 00 00  34 00 20 00 01 00 00 00  |........4. .....|
00000030  00 00 00 00 00 80 04 08  00 80 04 08 60 00 00 00  |............`...|
00000040  60 00 00 00 05 00 00 00  00 10 00 00              |`...........|
0000004c
```

另外，还需要把文件头中程序头的位置信息改为 44，即第 28 个字节，原来是 `0x34`，即 52 的位置。

```
$ echo "obase=16;ibase=10;44" | bc	# 先把44转换是16进制的0x2C
2C
$ echo -ne "\x2C" | dd of=hello bs=1 count=1 seek=28 conv=notrunc	# 修改文件头
1+0 records in
1+0 records out
1 byte (1 B) copied, 3.871e-05 s, 25.8 kB/s
$ hexdump -C hello
00000000  7f 45 4c 46 59 59 b2 05  b0 04 cd 80 b0 01 cd 80  |.ELFYY..........|
00000010  02 00 03 00 01 00 00 00  04 80 04 08 2c 00 00 00  |............,...|
00000020  84 00 00 00 00 00 00 00  34 00 20 00 01 00 00 00  |........4. .....|
00000030  00 00 00 00 00 80 04 08  00 80 04 08 60 00 00 00  |............`...|
00000040  60 00 00 00 05 00 00 00  00 10 00 00              |`...........|
0000004c
```

修改后即可执行了，目前只剩下 76 个字节：

```
$ wc -c hello
76
```

<span id="toc_3928_6176_21"></span>
### 在非连续的空间插入代码

另外，还有 12 个字节可以放代码，见 `0xff` 的地方：

```
$ hexdump -C hello
00000000  7f 45 4c 46 59 59 b2 05  b0 04 cd 80 b0 01 cd 80  |.ELFYY..........|
00000010  02 00 03 00 ff ff ff ff  04 80 04 08 2c 00 00 00  |............,...|
00000020  ff ff ff ff ff ff ff ff  34 00 20 00 01 00 00 00  |........4. .....|
00000030  00 00 00 00 00 80 04 08  00 80 04 08 60 00 00 00  |............`...|
00000040  60 00 00 00 05 00 00 00  00 10 00 00              |`...........|
0000004c
```

不过因为空间不是连续的，需要用到跳转指令作为跳板利用不同的空间。

例如，如果要利用后面的 `0xff` 的空间，可以把第 14，15 位置的 `cd 80` 指令替换为一条跳转指令，比如跳转到第 20 个字节的位置，从跳转指令之后的 16 到 20 刚好 4 个字节。

然后可以参考 [X86 指令编码表][15]（也可以写成汇编生成可执行文件后用 `hexdump` 查看），可以把 `jmp` 指令编码为： `0xeb 0x04` 。

```
$ echo -ne "\xeb\x04" | dd of=hello bs=1 count=2 seek=14 conv=notrunc
```

然后把原来位置的 `cd 80` 移动到第 20 个字节开始的位置：

```
$ echo -ne "\xcd\x80" | dd of=hello bs=1 count=2 seek=20 conv=notrunc
```

依然可以执行，类似地可以利用更多非连续的空间。

<span id="toc_3928_6176_22"></span>
### 把程序头完全合入文件头

在阅读参考资料 [\[1\]][1]后，发现有更多深层次的探讨，通过分析 Linux 系统对 `ELF` 文件头部和程序头部的解析，可以更进一步合并程序头和文件头。

该资料能够把最简的 `ELF` 文件（简单返回一个数值）压缩到 45 个字节，真地是非常极端的努力，思路可以充分借鉴。在充分理解原文的基础上，我们进行更细致地梳理。

首先对 `ELF` 文件头部和程序头部做更彻底的理解，并具体到每一个字节的含义以及在 Linux 系统下的实际解析情况。

先来看看 `readelf -a` 的结果：

```
$ as --32 -o hello.o hello.s
$ ld -melf_i386 -o hello hello.o
$ sstrip hello
$ readelf -a hello
ELF Header:
  Magic:   7f 45 4c 46 01 01 01 00 00 00 00 00 00 00 00 00
  Class:                             ELF32
  Data:                              2's complement, little endian
  Version:                           1 (current)
  OS/ABI:                            UNIX - System V
  ABI Version:                       0
  Type:                              EXEC (Executable file)
  Machine:                           Intel 80386
  Version:                           0x1
  Entry point address:               0x8048054
  Start of program headers:          52 (bytes into file)
  Start of section headers:          0 (bytes into file)
  Flags:                             0x0
  Size of this header:               52 (bytes)
  Size of program headers:           32 (bytes)
  Number of program headers:         1
  Size of section headers:           0 (bytes)
  Number of section headers:         0
  Section header string table index: 0

There are no sections in this file.

There are no sections to group in this file.

Program Headers:
  Type           Offset   VirtAddr   PhysAddr   FileSiz MemSiz  Flg Align
  LOAD           0x000000 0x08048000 0x08048000 0x00060 0x00060 R E 0x1000
```

然后结合 `/usr/include/linux/elf.h` 分别做详细注解。

首先是 52 字节的 `Elf` 文件头的结构体 `elf32_hdr`：


  变量类型     |  变量名           | 字节  | 说明                   | 类型
 --------------|-------------------|-------|------------------------|-------
  unsigned char|e_ident[EI_NIDENT] |16     | .ELF 前四个标识文件类型| 必须
  Elf32_Half   |e_type             |2      | 指定为可执行文件 | 必须
  Elf32_Half   |e_machine          |2      | 指示目标机类型，例如：Intel 386 | 必须
  Elf32_Word   |e_version          |4      | 当前只有一个版本存在，被忽略了 | ~~可篡改~~
  Elf32_Addr   |e_entry            |4      | 代码入口=加载地址(p_vaddr+.text偏移) | **可调整**
  Elf32_Off    |e_phoff            |4      | 程序头 Phdr 的偏移地址，用于加载代码| 必须
  Elf32_Off    |e_shoff            |4      | 所有节区相关信息对文件执行无效 | ~~可篡改~~
  Elf32_Word   |e_flags            |4      | Intel 架构未使用 | ~~可篡改~~
  Elf32_Half   |e_ehsize           |2      | 文件头大小，Linux 没做校验 | ~~可篡改~~
  Elf32_Half   |e_phentsize        |2      | 程序头入口大小，新内核有用 | 必须
  Elf32_Half   |e_phnum            |2      | 程序头入口个数 | 必须
  Elf32_Half   |e_shentsize        |2      | 所有节区相关信息对文件执行无效 | ~~可篡改~~
  Elf32_Half   |e_shnum            |2      | 所有节区相关信息对文件执行无效 | ~~可篡改~~
  Elf32_Half   |e_shstrndx         |2      | 所有节区相关信息对文件执行无效 | ~~可篡改~~

其次是 32 字节的程序头（Phdr）的结构体 `elf32_phdr`：

  变量类型     |  变量名  | 字节  | 说明           | 类型
 --------------|----------|-------|----------------|-------
  Elf32_Word   |p_type    |4      | 标记为可加载段 | 必须
  Elf32_Off    |p_offset  |4      | 相对程序头的偏移地址| 必须
  Elf32_Addr   |p_vaddr   |4      | 加载地址, 0x0~0x80000000，页对齐 | **可调整**
  Elf32_Addr   |p_paddr   |4      | 物理地址，暂时没用 | ~~可篡改~~
  Elf32_Word   |p_filesz  |4      | 加载的文件大小，>=real size | **可调整**
  Elf32_Word   |p_memsz   |4      | 加载所需内存大小，>= p_filesz | **可调整**
  Elf32_Word   |p_flags   |4      | 权限:read(4),exec(1), 其中一个暗指另外一个|**可调整**
  Elf32_Word   |p_align   |4      | PIC(共享库需要)，对执行文件无效 | ~~可篡改~~

接着，咱们把 Elf 中的文件头和程序头部分**可调整**和~~可篡改~~的字节（52 + 32 = 84个）全部用特别的字体标记出来。

```
$ hexdump -C hello -n 84
```


> 00000000  7f 45 4c 46 ~~01 01 01 00  00 00 00 00 00 00 00 00~~

> 00000010  02 00 03 00 ~~01 00 00 00~~ **54 80 04 08 34** 00 00 00

> 00000020  ~~84 00 00 00 00 00 00 00~~  34 00 20 00 01 00 ~~28 00~~

> 00000030  ~~05 00 02 00~~|01 00 00 00  00 00 00 00 **00 80 04 08**

> 00000040  ~~00 80 04 08~~ **60 00 00 00  60 00 00 00 05 00 00 00**

> 00000050  ~~00 10 00 00~~

> 00000054

上述 `|` 线之前为文件头，之后为程序头，之前的 `000000xx` 为偏移地址。

如果要把程序头彻底合并进文件头。从上述信息综合来看，文件头有 4 处必须保留，结合资料 [\[1\]][1]，经过对比发现，如果把第 4 行开始的程序头往上平移 3 行，也就是：


> 00000000  ========= ~~01 01 01 00  00 00 00 00 00 00 00 00~~

> 00000010  02 00 03 00 ~~01 00 00 00~~ **54 80 04 08 34** 00 00 00

> 00000020  ~~84 00 00 00~~

> 00000030  ========= 01 00 00 00  00 00 00 00 **00 80 04 08**

> 00000040  ~~00 80 04 08~~ **60 00 00 00  60 00 00 00 05 00 00 00**

> 00000050  ~~00 10 00 00~~

> 00000054

把可直接合并的先合并进去，效果如下：

（文件头）

> 00000000  ========= 01 00 00 00  00 00 00 00 **00 80 04 08** (^^ p_vaddr)

> 00000010  02 00 03 00 ~~60 00 00 00~~ **54 80 04 08 34** 00 00 00

> 00000020  =================== ^^ e_entry ^^ e_phoff

（程序头）

> 00000030  ========= 01 00 00 00  00 00 00 00 **00 80 04 08** (^^ p_vaddr)

> 00000040  02 00 03 00 **60 00 00 00  60 00 00 00 05 00 00 00**

> 00000050  =========  ^^ p_filesz   ^^ p_memsz  ^^p_flags

> 00000054

接着需要设法处理好可调整的 6 处，可以逐个解决，从易到难。

* 首先，合并 `e_phoff` 与 `p_flags`

在合并程序头以后，程序头的偏移地址需要修改为 4，即文件的第 4 个字节开始，也就是说 `e_phoff` 需要修改为 04。

而恰好，`p_flags` 的 `read(4)` 和 `exec(1)` 可以只选其一，所以，只保留 `read(4)` 即可，刚好也为 04。

合并后效果如下：

（文件头）

> 00000000  ========= 01 00 00 00  00 00 00 00 **00 80 04 08** (^^ p_vaddr)

> 00000010  02 00 03 00 ~~60 00 00 00~~ **54 80 04 08** 04 00 00 00

> 00000020  =================== ^^ e_entry

（程序头）

> 00000030  ========= 01 00 00 00  00 00 00 00 **00 80 04 08** (^^ p_vaddr)

> 00000040  02 00 03 00 **60 00 00 00  60 00 00 00** 04 00 00 00

> 00000050  =========  ^^ p_filesz   ^^ p_memsz

> 00000054

* 接下来，合并 `e_entry`，`p_filesz`, `p_memsz`  和 `p_vaddr`

从早前的分析情况来看，这 4 个变量基本都依赖 `p_vaddr`，也就是程序的加载地址，大体的依赖关系如下：

```
e_entry = p_vaddr + text offset = p_vaddr + 84 = p_vaddr + 0x54

p_memsz = e_entry

p_memsz >= p_filesz，可以简单取 p_filesz = p_memsz

p_vaddr = page alignment
```

所以，首先需要确定 `p_vaddr`，通过测试，发现`p_vaddr` 最低必须有 64k，也就是 0x00010000，对应到 `hexdump` 的 `little endian` 导出结果，则为 `00 00 01 00`。

需要注意的是，为了尽量少了分配内存，我们选择了一个最小的`p_vaddr`，如果申请的内存太大，系统将无法分配。

接着，计算出另外 3 个变量：

```
e_entry = 0x00010000 + 0x54 = 0x00010054 即 54 00 01 00
p_memsz = 54 00 01 00
p_filesz = 54 00 01 00
```

完全合并后，修改如下：

（文件头）

> 00000000  =========   01 00 00 00  00 00 00 00  00 00 01 00

> 00000010  02 00 03 00 54 00 01 00  54 00 01 00  04 00 00 00

> 00000020  ========

好了，直接把内容烧入：

```
$ echo -ne "\x01\x00\x00\x00\x00\x00\x00\x00" \
	   "\x00\x00\x01\x00\x02\x00\x03\x00" \
	   "\x54\x00\x01\x00\x54\x00\x01\x00\x04" |\
	   tr -d ' ' |\
    dd of=hello bs=1 count=25 seek=4 conv=notrunc
```

截掉代码（52 + 32 + 12 = 96）之后的所有内容，查看效果如下：

```
$ dd if=hello of=hello bs=1 count=1 skip=96 seek=96
$ hexdump -C hello -n 96
00000000  7f 45 4c 46 01 00 00 00  00 00 00 00 00 00 01 00  |.ELF............|
00000010  02 00 03 00 54 00 01 00  54 00 01 00 04 00 00 00  |....T...T.......|
00000020  84 00 00 00 00 00 00 00  34 00 20 00 01 00 28 00  |........4. ...(.|
00000030  05 00 02 00 01 00 00 00  00 00 00 00 00 80 04 08  |................|
00000040  00 80 04 08 60 00 00 00  60 00 00 00 05 00 00 00  |....`...`.......|
00000050  00 10 00 00 59 59 b2 05  b0 04 cd 80 b0 01 cd 80  |....YY..........|
00000060
```

最后的工作是查看文件头中剩下的~~可篡改~~的内容，并把**代码部分**合并进去，程序头已经合入，不再显示。

> 00000000  7f 45 4c 46 01 00 00 00  00 00 00 00 00 00 01 00

> 00000010  02 00 03 00 54 00 01 00  54 00 01 00 04 00 00 00

> 00000020  ~~84 00 00 00 00 00 00 00~~  34 00 20 00 01 00 ~~28 00~~

> 00000030  ~~05 00 02 00~~

> 00000040

> 00000050  ============= **59 59 b2 05  b0 04 cd 80 b0 01 cd 80**

> 00000060

我们的指令有 12 字节，~~可篡改~~的部分有 14 个字节，理论上一定放得下，不过因为把程序头搬进去以后，这 14 个字节并不是连续，刚好可以用上我们之前的跳转指令处理办法来解决。

并且，加入 2 个字节的跳转指令，刚好是 14 个字节，恰好把代码也完全包含进了文件头。

在预留好**跳转指令**位置的前提下，我们把代码部分先合并进去：

> 00000000  7f 45 4c 46 01 00 00 00  00 00 00 00 00 00 01 00

> 00000010  02 00 03 00 54 00 01 00  54 00 01 00 04 00 00 00

> 00000020  **59 59 b2 05  b0 04** ~~00 00~~  34 00 20 00 01 00 **cd 80**

> 00000030  **b0 01 cd 80**


接下来设计跳转指令，跳转指令需要从所在位置跳到第一个 **cd 80** 所在的位置，相距 6 个字节，根据 `jmp` 短跳转的编码规范，可以设计为 `0xeb 0x06`，填完后效果如下：


> 00000000  7f 45 4c 46 01 00 00 00  00 00 00 00 00 00 01 00

> 00000010  02 00 03 00 54 00 01 00  54 00 01 00 04 00 00 00

> 00000020  **59 59 b2 05  b0 04 eb 06** 34 00 20 00 01 00 **cd 80**

> 00000030  **b0 01 cd 80**

用 `dd` 命令写入，分两段写入：

```
$ echo -ne "\x59\x59\xb2\x05\xb0\x04\xeb\x06" | \
    dd of=hello bs=1 count=8 seek=32 conv=notrunc

$ echo -ne "\xcd\x80\xb0\x01\xcd\x80" | \
    dd of=hello bs=1 count=6 seek=46 conv=notrunc
```

代码合入以后，需要修改文件头中的代码的偏移地址，即 `e_entry`，也就是要把原来的偏移 84 (0x54) 修改为现在的偏移，即 0x20。

```
$ echo -ne "\x20" | dd of=hello bs=1 count=1 seek=24 conv=notrunc
```

修改完以后恰好把合并进的程序头 `p_memsz`，也就是分配给文件的内存改小了，`p_filesz`也得相应改小。

```
$ echo -ne "\x20" | dd of=hello bs=1 count=1 seek=20 conv=notrunc
```

程序头和代码都已经合入，最后，把 52 字节之后的内容全部删掉：

```
$ dd if=hello of=hello bs=1 count=1 skip=52 seek=52
$ hexdump -C hello
00000000  7f 45 4c 46 01 00 00 00  00 00 00 00 00 00 01 00  |.ELF............|
00000010  02 00 03 00 20 00 01 00  20 00 01 00 04 00 00 00  |....T...T.......|
00000020  59 59 b2 05 b0 04 eb 06  34 00 20 00 01 00 cd 80  |YY......4. .....|
00000030  b0 01 cd 80
$ export PATH=./:$PATH
$ hello
hello
```

**代码**和~~程序头~~部分合并进文件头的汇总情况：

> 00000000  7f 45 4c 46 ~~01 00 00 00  00 00 00 00 00 00 01 00~~

> 00000010  ~~02 00 03 00 20 00 01 00  20 00 01 00 04 00 00 00~~

> 00000020  **~~59 59 b2 05~~ b0 04 eb 06**  34 00 20 00 01 00 **cd 80**

> 00000030  **b0 01 cd 80**


最后，我们的成绩是：

```
$ wc -c hello
52
```

史上最小的可打印 `Hello World`（注：要完全打印得把代码中的5该为13，并且把文件名该为该字符串） 的 `Elf` 文件是 52 个字节。打破了资料 [\[1\]][1] 作者创造的纪录：

```
$ cd ELFkickers/tiny/
$ wc -c hello
59 hello
```
需要特别提到的是，该作者创造的最小可执行 Elf 是 45 个字节。

但是由于那个程序只能返回一个数值，代码更简短，刚好可以直接嵌入到文件头中间，而文件末尾的 7 个 `0` 字节由于 Linux 加载时会自动填充，所以可以删掉，所以最终的文件大小是 52 - 7 即 45 个字节。

其大体可实现如下：

```
.global _start
_start:
	mov $42, %bl   # 设置返回值为 42
	xor %eax, %eax # eax = 0
	inc %eax       # eax = eax+1, 设置系统调用号, sys_exit()
	int $0x80
```

保存为 ret.s，编译和执行效果如下：

```
$ as --32 -o ret.o ret.s
$ ld -melf_i386 -o ret ret.o
$ ./ret
42
```

代码字节数可这么查看：

```
$ ld -melf_i386 --oformat=binary -o ret.bin ret.o
$ hexdump -C ret.bin
0000000  b3 2a 31 c0 40 cd 80
0000007
```

这里只有 7 条指令，刚好可以嵌入，而最后的 6 个字节因为~~可篡改~~为 0，并且内核可自动填充 0，所以干脆可以连续删掉最后 7 个字节的 0：

> 00000000  7f 45 4c 46 01 00 00 00  00 00 00 00 00 00 01 00

> 00000010  02 00 03 00 54 00 01 00  54 00 01 00 04 00 00 00

> 00000020  **b3 2a 31 c0 40 cd 80** 00 34 00 20 00 01 00 00 00

> 00000030  00 00 00 00

可以直接用已经合并好程序头的 `hello` 来做实验，这里一并截掉最后的 7 个 0 字节：

```
$ cp hello ret
$ echo -ne "\xb3\x2a\x31\xc0\x40\xcd\x80" |\
    dd of=ret bs=1 count=8 seek=32 conv=notrunc
$ dd if=ret of=hello bs=1 count=1 skip=45 seek=45
$ hexdump -C hello
00000000  7f 45 4c 46 01 00 00 00  00 00 00 00 00 00 01 00  |.ELF............|
00000010  02 00 03 00 20 00 01 00  20 00 01 00 04 00 00 00  |.... ... .......|
00000020  b3 2a 31 c0 40 cd 80 06  34 00 20 00 01           |.*1.@...4. ..|
0000002d
$ wc -c ret
45 ret
$ ./ret
$ echo $?
42
```

如果想快速构建该 `Elf` 文件，可以直接使用下述 Shell 代码：

```
#!/bin/bash
#
# generate_ret_elf.sh -- Generate a 45 bytes Elf file
#
# $ bash generate_ret_elf.sh
# $ chmod a+x ret.elf
# $ ./ret.elf
# $ echo $?
# 42
#

ret="\x7f\x45\x4c\x46\x01\x00\x00\x00"
ret=${ret}"\x00\x00\x00\x00\x00\x00\x01\x00"
ret=${ret}"\x02\x00\x03\x00\x20\x00\x01\x00"
ret=${ret}"\x20\x00\x01\x00\x04\x00\x00\x00"
ret=${ret}"\xb3\x2a\x31\xc0\x40\xcd\x80\x06"
ret=${ret}"\x34\x00\x20\x00\x01"

echo -ne $ret > ret.elf
```

又或者是直接参照资料 [\[1\]][1] 的 `tiny.asm` 就行了，其代码如下：

```
; ret.asm

  BITS 32

	        org     0x00010000

	        db      0x7F, "ELF"             ; e_ident
	        dd      1                                       ; p_type
	        dd      0                                       ; p_offset
	        dd      $$                                      ; p_vaddr
	        dw      2                       ; e_type        ; p_paddr
	        dw      3                       ; e_machine
	        dd      _start                  ; e_version     ; p_filesz
	        dd      _start                  ; e_entry       ; p_memsz
	        dd      4                       ; e_phoff       ; p_flags
  _start:
	        mov     bl, 42                  ; e_shoff       ; p_align
	        xor     eax, eax
	        inc     eax                     ; e_flags
	        int     0x80
	        db      0
	        dw      0x34                    ; e_ehsize
	        dw      0x20                    ; e_phentsize
	        db      1                       ; e_phnum
	                                        ; e_shentsize
	                                        ; e_shnum
	                                        ; e_shstrndx

  filesize      equ     $ - $$
```

编译和运行效果如下：

```
$ nasm -f bin -o ret ret.asm
$ chmod +x ret
$ ./ret ; echo $?
42
$ wc -c ret
45 ret
```

下面也给一下本文精简后的 `hello` 的 `nasm` 版本：

```
; hello.asm

  BITS 32

	        org     0x00010000

	        db      0x7F, "ELF"             ; e_ident
	        dd      1                                       ; p_type
	        dd      0                                       ; p_offset
	        dd      $$                                      ; p_vaddr
	        dw      2                       ; e_type        ; p_paddr
	        dw      3                       ; e_machine
	        dd      _start                  ; e_version     ; p_filesz
	        dd      _start                  ; e_entry       ; p_memsz
	        dd      4                       ; e_phoff       ; p_flags
  _start:
	        pop     ecx     ; argc          ; e_shoff       ; p_align
	        pop     ecx     ; argv[0]
	        mov     dl, 5   ; str len       ; e_flags
	        mov     al, 4   ; sys_write(fd, addr, len) : ebx, ecx, edx
	        jmp     _next   ; jump to next part of the code
	        dw      0x34                      ; e_ehsize
	        dw      0x20                      ; e_phentsize
	        dw      1                         ; e_phnum
  _next:        int     0x80    ; syscall         ; e_shentsize
	        mov     al, 1   ; eax=1,sys_exit  ; e_shnum
	        int     0x80    ; syscall         ; e_shstrndx

  filesize      equ     $ - $$
```

编译和用法如下：

```
$ nasm -f bin -o hello hello.asm
$ chmod a+x hello
$ export PATH=./:$PATH
$ hello
hello
$ wc -c hello
52
```

经过一番努力，`AT&T` 的完整 binary 版本如下：

```
# hello.s
#
# as --32 -o hello.o hello.s
# ld -melf_i386 --oformat=binary -o hello hello.o
#

	.file "hello.s"
	.global _start, _load
	.equ   LOAD_ADDR, 0x00010000   # Page aligned load addr, here 64k
	.equ   E_ENTRY, LOAD_ADDR + (_start - _load)
	.equ   P_MEM_SZ, E_ENTRY
	.equ   P_FILE_SZ, P_MEM_SZ

_load:
	.byte  0x7F
	.ascii "ELF"                  # e_ident, Magic Number
	.long  1                                      # p_type, loadable seg
	.long  0                                      # p_offset
	.long  LOAD_ADDR                              # p_vaddr
	.word  2                      # e_type, exec  # p_paddr
	.word  3                      # e_machine, Intel 386 target
	.long  P_FILE_SZ              # e_version     # p_filesz
	.long  E_ENTRY                # e_entry       # p_memsz
	.long  4                      # e_phoff       # p_flags, read(exec)
	.text
_start:
	popl   %ecx    # argc         # e_shoff       # p_align
	popl   %ecx    # argv[0]
	mov    $5, %dl # str len      # e_flags
	mov    $4, %al # sys_write(fd, addr, len) : ebx, ecx, edx
	jmp    next    # jump to next part of the code
	.word  0x34                   # e_ehsize = 52
	.word  0x20                   # e_phentsize = 32
	.word  1                      # e_phnum = 1
	.text
_next:  int    $0x80   # syscall        # e_shentsize
	mov    $1, %al # eax=1,sys_exit # e_shnum
	int    $0x80   # syscall        # e_shstrndx
```

编译和运行效果如下：

```
$ as --32 -o hello.o hello.s
$ ld -melf_i386 --oformat=binary -o hello hello.o
$ export PATH=./:$PATH
$ hello
hello
$ wc -c hello
52 hello
```

**注**：编译时务必要加 `--oformat=binary` 参数，以便直接基于源文件构建一个二进制的 `Elf` 文件，否则会被 `ld` 默认编译，自动填充其他内容。

<span id="toc_3928_6176_23"></span>
## 汇编语言极限精简之道（45字节）

经过上述努力，我们已经完全把程序头和代码都融入了 52 字节的 `Elf` 文件头，还可以再进一步吗？

基于资料一，如果再要努力，只能设法把 `Elf` 末尾的 7 个 0 字节删除，但是由于代码已经把 `Elf` 末尾的 7 字节 0 字符都填满了，所以要想在这一块努力，只能继续压缩代码。

继续研究下代码先：

```
.global _start
_start:
	popl %ecx	# argc
	popl %ecx	# argv[0]
	movb $5, %dl	# 设置字符串长度
	movb $4, %al	# eax = 4, 设置系统调用号, sys_write(fd, addr, len) : ebx, ecx, edx
	int $0x80
	movb $1, %al
	int $0x80
```

查看对应的编码：

```
$ as --32 -o hello.o hello.s
$ ld -melf_i386 -o hello hello.o --oformat=binary
$ hexdump -C hello
00000000  59 59 b2 05 b0 04 cd 80  b0 01 cd 80              |YY..........|
0000000c
```

每条指令对应的编码映射如下：

  指令         |  编码     | 说明
  -------------|-----------|-----------
  popl %ecx    |  59  	   | argc
  popl %ecx    |  59	   | argv[0]
  movb $5, %dl |  b2 05	   | 设置字符串长度
  movb $4, %al |  b0 04	   | eax = 4, 设置系统调用号, sys_write(fd, addr, len) : ebx, ecx, edx
  int $0x80    |  cd 80    | 触发系统调用
  movb $1, %al |  b0 01    | eax = 1, sys_exit
  int $0x80    |  cd 80    | 触发系统调用

可以观察到：

* `popl` 的指令编码最简洁。
* `int $0x80` 重复了两次，而且每条都占用了 2 字节
* `movb` 每条都占用了 2 字节
* `eax` 有两次赋值，每次占用了 2 字节
* `popl %ecx` 取出的 argc 并未使用

根据之前通过参数传递字符串的想法，咱们是否可以考虑通过参数来设置变量呢？

理论上，传入多个参数，通过 `pop` 弹出来赋予 `eax`, `ecx` 即可，但是实际上，由于从参数栈里头 `pop` 出来的参数是参数的地址，并不是参数本身，所以该方法行不通。

不过由于第一个参数取出的是数字，并且是参数个数，而且目前的那条 `popl %ecx` 取出的 `argc` 并没有使用，那么刚好可以用来设置 `eax`，替换后如下：

```
.global _start
_start:
	popl %eax    # eax = 4, 设置系统调用号, sys_write(fd, addr, len) : ebx, ecx, edx
	popl %ecx    # argv[0], 字符串
	movb $5, %dl # 设置字符串长度
	int $0x80
	movb $1, %al # eax = 1, sys_exit
	int $0x80
```

这里需要传入 4 个参数，即让栈弹出的第一个值，也就是参数个数赋予 `eax`，也就是：`hello 5 4 1`。

难道我们只能把该代码优化到 10 个字节？

巧合地是，当偶然改成这样的情况下，该代码还能正常返回。

```
.global _start
_start:
	popl %eax	# eax = 4, 设置系统调用号, sys_write(fd, addr, len) : ebx, ecx, edx
	popl %ecx	# argv[0], 字符串
	movb $5, %dl	# 设置字符串长度
	int $0x80
	loop _start     # 触发系统退出
```

**注**：上面我们使用了 `loop` 指令而不是 `jmp` 指令，因为 `jmp _start` 产生的代码更长，而 `loop _start` 指令只有两个字节。

这里相当于删除了 `movb $1, %al`，最后我们获得了 8 个字节。但是这里为什么能够工作呢？

经过分析 `arch/x86/ia32/ia32entry.S`，我们发现当系统调用号无效时（超过系统调用入口个数），内核为了健壮考虑，必须要处理这类异常，并通过 `ia32_badsys` 让系统调用正常返回。

这个可以这样验证：

```
.global _start
_start:
	popl %eax    # argc, eax = 4, 设置系统调用号, sys_write(fd, addr, len) : ebx, ecx, edx
	popl %ecx    # argv[0], 文件名
	mov $5, %dl  # argv[1]，字符串长度
	int $0x80
	mov $0xffffffda, %eax  # 设置一个非法调用号用于退出
	int $0x80
```

那最后的结果是，我们产生了一个可以正常打印字符串，大小只有 45 字节的 `Elf` 文件，最终的结果如下：

```
# hello.s
#
# $ as --32 -o hello.o hello.s
# $ ld -melf_i386 --oformat=binary -o hello hello.o
# $ export PATH=./:$PATH
# $ hello 0 0 0
# hello
#

	.file "hello.s"
	.global _start, _load
	.equ   LOAD_ADDR, 0x00010000   # Page aligned load addr, here 64k
	.equ   E_ENTRY, LOAD_ADDR + (_start - _load)
	.equ   P_MEM_SZ, E_ENTRY
	.equ   P_FILE_SZ, P_MEM_SZ

_load:
	.byte  0x7F
	.ascii "ELF"              # e_ident, Magic Number
	.long  1                                      # p_type, loadable seg
	.long  0                                      # p_offset
	.long  LOAD_ADDR                              # p_vaddr
	.word  2                  # e_type, exec  # p_paddr
	.word  3                  # e_machine, Intel 386 target
	.long  P_FILE_SZ          # e_version     # p_filesz
	.long  E_ENTRY            # e_entry       # p_memsz
	.long  4                  # e_phoff       # p_flags, read(exec)
	.text
_start:
	popl   %eax    # argc     # e_shoff       # p_align
	               # 4 args, eax = 4, sys_write(fd, addr, len) : ebx, ecx, edx
	               # set 2nd eax = random addr to trigger bad syscall for exit
	popl   %ecx    # argv[0]
	mov    $5, %dl # str len  # e_flags
	int    $0x80
	loop   _start  # loop to popup a random addr as a bad syscall number
	.word  0x34               # e_ehsize = 52
	.word  0x20               # e_phentsize = 32
	.byte  1                  # e_phnum = 1, remove trailing 7 bytes with 0 value
	                          # e_shentsize
	                          # e_shnum
	                          # e_shstrndx
```

效果如下：

```
$ as --32 -o hello.o hello.s
$ ld -melf_i386 -o hello hello.o --oformat=binary
$ export PATH=./:$PATH
$ hello 0 0 0
hello
$ wc -c hello
45 hello
```

到这里，我们获得了史上最小的可以打印字符串的 `Elf` 文件，是的，只有 45 个字节。

<span id="toc_3928_6176_24"></span>
## 小结

到这里，关于可执行文件的讨论暂且结束，最后来一段小小的总结，那就是我们设法去减少可执行文件大小的意义？

实际上，通过这样一个讨论深入到了很多技术的细节，包括可执行文件的格式、目标代码链接的过程、 Linux 下汇编语言开发等。与此同时，可执行文件大小的减少本身对嵌入式系统非常有用，如果删除那些对程序运行没有影响的节区和节区表将减少目标系统的大小，适应嵌入式系统资源受限的需求。除此之外，动态连接库中的很多函数可能不会被使用到，因此也可以通过某种方式剔除 [\[8\]][8]，[\[10\]][10] 。

或许，你还会发现更多有趣的意义，欢迎给我发送邮件，一起讨论。

<span id="toc_3928_6176_25"></span>
## 参考资料

- [A Whirlwind Tutorial on Creating Really Teensy ELF Executables for Linux][1]
- [UNIX/LINUX 平台可执行文件格式分析][2]
- [C/C++ 程序编译步骤详解][3]
- [The Linux GCC HOW TO][4]
- [ELF: From The Programmer's Perspective][5]
- [Understanding ELF using readelf and objdump][6]
- [Dissecting shared libraries][7]
- [嵌入式 Linux 小型化技术][8]
- [Linux 汇编语言开发指南][9]
- [Library Optimizer][10]
- ELF file format and ABI：[\[1\]][11]，[\[2\]][12]，[\[3\]][13]，[\[4\]][14]
- [i386 指令编码表][15]

 [1]: http://www.muppetlabs.com/~breadbox/software/tiny/teensy.html
 [2]: http://blog.chinaunix.net/u/19881/showart_215242.html
 [3]: http://www.xxlinux.com/linux/article/development/soft/20070424/8267.html
 [4]: http://www.faqs.org/docs/Linux-HOWTO/GCC-HOWTO.html
 [5]: http://linux.jinr.ru/usoft/WWW/www_debian.org/Documentation/elf/elf.html
 [6]: http://www.linuxforums.org/misc/understanding_elf_using_readelf_and_objdump.html
 [7]: http://www.ibm.com/developerworks/linux/library/l-shlibs.html
 [8]: http://www.gexin.com.cn/UploadFile/document2008119102415.pdf
 [9]: http://www.ibm.com/developerworks/cn/linux/l-assembly/index.html
 [10]: http://sourceforge.net/projects/libraryopt
 [11]: http://refspecs.linuxbase.org/elf/elf.pdf
 [12]: http://www.muppetlabs.com/~breadbox/software/ELF.txt
 [13]: http://162.105.203.48/web/gaikuang/submission/TN05.ELF.Format.Summary.pdf
 [14]: http://www.xfocus.net/articles/200105/174.html
 [15]: http://sparksandflames.com/files/x86InstructionChart.html
