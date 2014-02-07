# 为可执行文件“减肥”

## 前言

本文从减少可执行文件大小的角度分析了ELF文件，期间通过经典的"Hello World"实例逐步演示如何通过各种常用工具来分析ELF文件，并逐步精简代码。

为了能够尽量减少可执行文件的大小，我们必须了解可执行文件的格式，以及链接生成可执行文件时的后台细节（即最终到底有哪些内容被链接到了目标代码中）。通过选择合适的可执行文件格式并剔除对可执行文件的最终运行没有影响的内容，就可以实现目标代码的裁减。因此，通过探索减少可执行文件大小的方法，就相当于实践性地去探索了可执行文件的格式以及链接过程的细节。

当然，算法的优化和编程语言的选择可能对目标文件的大小有很大的影响，在本文最后我们会跟参考资料[1][1]的作者那样去探求一个打印“Hello World”的可执行文件能够小到什么样的地步。

## 可执行文件格式的选取

可执行文件格式的选择要满足的一个基本条件是：目标系统支持该可执行文件格式，资料[2][2]分析和比较了UNIX平台下的三种可执行文件格式，这三种格式实际上代表着可执行文件的一个发展过程：

- a.out文件格式非常紧凑，只包含了程序运行所必须的信息（文本、数据、BSS），而且每个 section的顺序是固定的。

- coff文件格式虽然引入了一个节区表以支持更多节区信息，从而提高了可扩展性，但是这种文件格式的重定位在链接时就已经完成，因此不支持动态链接（不过扩展的coff支持）。

- elf文件格式不仅动态链接，而且有很好的扩展性。它可以描述可重定位文件、可执行文件和可共享文件（动态链接库）三类文件。

下面来看看ELF文件的结构图：

```
文件头部(ELF Header)
程序头部表(Program Header Table)
节区1(Section1)
节区2(Section2)
节区3(Section3)
...
节区头部(Section Header Table)
```

无论是文件头部、程序头部表、节区头部表还是各个节区，都是通过特定的结构体(struct)描述的，这些结构在elf.h文件中定义。文件头部用于描述整个文件的类型、大小、运行平台、程序入口、程序头部表和节区头部表等信息。例如，我们可以通过文件头部查看该ELF文件的类型。

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
$ gcc -fpic -shared -W1,-soname,libhello.so.0 -o libhello.so.0.0 hello.o  #生成共享库
$ readelf -h libhello.so.0.0 | grep Type
  Type:                              DYN (Shared object file)
```

那节区头部表（将简称节区表）和程序头部表有什么用呢？实际上前者只对可重定向文件有用，而后者只对可执行文件和可共享文件有用。

节区表是用来描述各节区的，包括各节区的名字、大小、类型、虚拟内存中的位置、相对文件头的位置等，这样所有节区都通过节区表给描述了，这样连接器就可以根据文件头部表和节区表的描述信息对各种输入的可重定位文件进行合适的链接，包括节区的合并与重组、符号的重定位（确认符号在虚拟内存中的地址）等，把各个可重定向输入文件链接成一个可执行文件（或者是可共享文件）。如果可执行文件中使用了动态连接库，那么将包含一些用于动态符号链接的节区。我们可以通过readelf -S（或objdump -h）查看节区表信息。

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

三种类型文件的节区(各个常见节区的作用请参考资料[11][11])可能不一样，但是有几个节区，例如.text, .data, .bss是必须的，特别是.text，因为这个节区包含了代码。如果一个程序使用了动态链接库（引用了动态连接库中的某个函数），那么需要.interp节区以便告知系统使用什么动态连接器程序来进行动态符号链接，进行某些符号地址的重定位。通常，.rel.text节区只有可重定向文件有，用于链接时对代码区进行重定向，而.hash,.plt,.got等节区则只有可执行文件（或可共享库）有，这些节区对程序的运行特别重要。还有一些节区，可能仅仅是用于注释，比如.comment，这些对程序的运行似乎没有影响，是可有可无的，不过有些节区虽然对程序的运行没有用处，但是却可以用来辅助对程序进行调试或者对程序运行效率有影响。

虽然三类文件都必须包含某些节区，但是节区表对可重定位文件来说才是必须的，而程序的执行却不需要节区表，只需要程序头部表以便知道如何加载和执行文件。不过如果需要对可执行文件或者动态连接库进行调试，那么节区表却是必要的，否则调试器将不知道如何工作。下面来介绍程序头部表，它可通过readelf -l(或objdump -p)查看。

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

从上面可看出程序头部表描述了一些段（Segment），这些段对应着一个或者多个节区，上面的readelf -l很好地显示了各个段与节区的映射。这些段描述了段的名字、类型、大小、第一个字节在文件中的位置、将占用的虚拟内存大小、在虚拟内存中的位置等。这样系统程序解释器将知道如何把可执行文件加载到内存中以及进行动态链接等动作。

该可执行文件包含7个段，PHDR指程序头部，INTERP正好对应.interp节区，两个LOAD段包含程序的代码和数据部分，分别包含有.text和.data，.bss节区，DYNAMIC段包含.daynamic，这个节区可能包含动态连接库的搜索路径、可重定位表的地址等信息，它们用于动态连接器。NOTE和GNU_STACK段貌似作用不大，只是保存了一些辅助信息。因此，对于一个不使用动态连接库的程序来说，可能只包含LOAD段，如果一个程序没有数据，那么只有一个LOAD段就可以了。

总结一下，Linux虽然支持很多种可执行文件格式，但是目前ELF较通用，所以选择ELF作为我们的讨论对象。通过上面对ELF文件分析发现一个可执行的文件可能包含一些对它的运行没用的信息，比如节区表、一些用于调试、注释的节区。如果能够删除这些信息就可以减少可执行文件的大小，而且不会影响可执行文件的正常运行。

## 链接优化

从上面的讨论中已经接触了动态连接库。ELF中引入动态连接库后极大地方便了公共函数的共享，节约了磁盘和内存空间，因为不再需要把那些公共函数的代码链接到可执行文件，这将减少了可执行文件的大小。

与此同时，静态链接可能会引入一些对代码的运行可能并非必须的内容。你可以从《GCC编译的背后(第二部分：汇编和链接)》 了解到GCC链接的细节。从那篇Blog中似乎可以得出这样的结论：仅仅从是否影响一个C语言程序运行的角度上说，GCC默认链接到可执行文件的几个可重定位文件(crt1.o,rti.o,crtbegin.o,crtend.o,crtn.o)并不是必须的，不过值得注意的是，如果没有链接那些文件但在程序末尾使用了return语句，main函数将无法返回，因此需要替换为_exit调用；另外，既然程序在进入main之前有一个入口，那么main入口就不是必须的。因此，如果不采用默认链接也可以减少可执行文件的大小。

## 可执行文件“减肥”实例

这里主要是根据上面两点来介绍如何减少一个可执行文件的大小。以"Hello World"为例。

首先来看看默认编译产生的Hello World的可执行文件大小。

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

### 不采用默认编译

可以考虑编辑时就把return 0替换成_exit(0)并包含定义该函数的unistd.h头文件。下面是从GCC编译的背后(第二部分：汇编和链接)》总结出的Makefile文件。

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
$ wc -c hello   #但是大小减少了4382个字节，减少了将近70%
2060 hello
$ echo "6442-2060" | bc
4382
$ echo "(6442-2060)/6442" | bc -l
.68022353306426575597
```

对于一个比较小的程序，能够减少将近70%“没用的”代码。至于一个大一点的程序（这个代码是资料[1][1]的作者写的一个小工具，我们后面会使用它）再看看效果。

```
$ gcc -o sstrip sstrip.c   #默认编译的情况
$ wc -c sstrip
10912 sstrip
$ sed -i -e "s/hello/sstrip/g" Makefile  #把Makefile中的hello替换成sstrip
$ make clean      #清除默认编译的sstrip
$ make            #用我们的Makefile编译
$ wc -c sstrip
6589 sstrip
$ echo "10912-6589" | bc -l   #再比较大小，减少的代码还是4323个字节，减幅40%
4323
$ echo "(10912-6589)/10912" | bc -l
.39616935483870967741
```

通过这两个简单的实验，我们发现，能够减少掉4000个字节左右，相当于4k左右。

### 删除对程序运行没有影响的节区

使用上述Makefile来编译程序，不链接那些对程序运行没有多大影响的文件，实际上也相当于删除了一些“没用”的节区，可以通过下列演示看出这个实质。

```
$ sed -i -e "s/sstrip/hello/g" Makefile  #先看看用Makefile编译的结果，替换回hello
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

通过比较发现使用自定义的Makefile文件，少了这么多节区：.bss .ctors .data .dtors .eh_frame .fini .gnu.hash .got .init .jcr .note.ABI-tag .rel.dyn。
再看看还有哪些节区可以删除呢？通过之前的分析发现有些节区是必须的，那.hash?.gnu.version?呢，通过strip -R(或objcop -R)删除这些节区试试。

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
通过删除两个“没用”的节区，我们又减少了52+612，即664字节。

### 删除可执行文件的节区表

用普通的工具没有办法删除节区表，但是参考资料[1][1]的作者已经写了这样一个工具。你可以从这里http://www.muppetlabs.com/~breadbox/software/elfkickers.html下载到那个工具，即我们上面作为一个演示例子的sstrip，它是该作者写的一序列工具ELFkickers中的一个。下载以后，编译，并复制到/usr/bin下，下面用它来删除节区表。

```
$ sstrip hello      #删除ELF可执行文件的节区表
$ ./hello           #还是可以正常运行，说明节区表对可执行文件的运行没有任何影响
Hello World
$ wc -c hello       #大小只剩下708个字节了
708 hello
$ echo "1396-708" | bc  #又减少了688个字节。
688
```

通过删除节区表又把可执行文件减少了688字节。现在回头看看相对于gcc默认产生的可执行文件，通过删除一些节区和节区表到底减少了多少字节？减幅达到了多少？

```
$ echo "6442-708" | bc   #
5734
$ echo "(6442-708)/6442" | bc -l
.89009624340266997826
```

减少了5734多字节，减幅将近90%，这说明：对于一个简短的hello.c程序而言，gcc引入了将近90%的对程序运行没有影响的数据。虽然通过删除节区和节区表，使得最终的文件只有708字节，但是打印一个"Hello World"真的需要这么多字节么？
事实上未必，因为：

- 打印一段Hello World字符串，我们无须调用printf，也就无须包含动态连接库，因此.interp，.dynamic等节区又可以去掉。为什么？我们可以直接使用系统调用(sys_write)来打印字符串。
- 另外，我们无须把Hello World字符串存放到可执行文件中？而是让用户把它当作参数输入。

下面，继续进行可执行文件的“减肥”。

## 用汇编语言来重写"Hello World"

### 采用默认编译

先来看看gcc默认产生的汇编代码情况。通过gcc的-S选项可得到汇编代码。

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

### 删除掉汇编代码中无关紧要内容

现在对汇编代码(hello.s)进行简单的处理得到，

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

### 不默认编译并删除掉无关节区和节区表

如果不采用默认编译呢并且删除掉对程序运行没有影响的节区和节区表呢？

```
$ sed -i -e "s/main/_start/g" hello.s   #因为没有初始化，所以得直接进入代码，替换main为_start
$ as -o  hello.o hello.s
$ ld -o hello hello.o --dynamic-linker /lib/ld-linux.so.2 -L /usr/lib -lc
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

容易发现这32字节可能跟节区.rodata有关系，因为刚才在链接完以后查看节区信息时，并没有.rodata节区。

### 用系统调用取代库函数

前面提到，实际上还可以不用动态连接库中的printf函数，也不用直接调用_exit，而是在汇编里头使用系统调用，这样就可以去掉和动态连接库关联的内容。（如果想了解如何在汇编中使用系统调用，请参考资料[9][9]）。使用系统调用重写以后得到如下代码，

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

现在编译就不再需要动态链接器ld-linux.so了，也不再需要链接任何库。

```
$ as -o hello.o hello.s
$ ld -o hello hello.o
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

可以看到效果很明显，只剩下一个LOAD段，它对应.text节区。

### 把字符串作为参数输入

不过是否还有办法呢？把Hello World作为参数输入，而不是硬编码在文件中。所以如果处理参数的代码少于Hello World字符串的长度，那么就可以达到减少目标文件大小的目的。

先来看一个能够打印程序参数的汇编语言程序，它来自参考资料[9][9]。

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
$ as -o args.o args.s
$ ld -o args args.o
$ ./args "Hello World"  #能够打印输入的字符串，不错
./args
Hello World
$ sstrip args
$ wc -c args           #处理以后只剩下130字节
130 args
```

可以看到，这个程序可以接收用户输入的参数并打印出来，不过得到的可执行文件为130字节，比之前的123个字节还多了7个字节，看看还有改进么？分析上面的代码后，发现，原来的代码有些地方可能进行优化，优化后得到如下代码。

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

现在只有124个字节，不过还是比123个字节多一个，还有什么优化的办法么？
先来看看目前hello的功能，感觉不太符合要求，因为只需要打印Hello World，所以不必处理所有的参数，仅仅需要接收并打印一个参数就可以。这样的话，把jmp vnext(2字节)这个循环去掉，然后在第一个pop %ecx语句之前加一个pop %ecx(1字节)语句就可以。

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

现在刚好123字节，和原来那个代码大小一样，不过仔细分析，还是有减少代码的余地：因为在这个代码中，用了一段额外的代码计算字符串的长度，实际上如果仅仅需要打印Hello World，那么字符串的长度是固定的，即12。所以这段代码可去掉，与此同时测试字符串是否为空也就没有必要（不过可能影响代码健壮性！），当然，为了能够在打印字符串后就换行，在串的末尾需要加一个回车（`$10`）并且设置字符串的长度为12+1，即13，

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

### 寄存器赋值重用

现在只剩下111字节，比刚才少了12字节。貌似到了极限？还有措施么？

还有，仔细分析发现：系统调用sys\_exit和sys\_write都用到了eax和ebx寄存器，它们之间刚好有那么一点巧合：

- sys_exit调用时，eax需要设置为1，ebx需要设置为0。
- sys_write调用时，ebx刚好是1。

因此，如果在sys\_exit调用之前，先把ebx复制到eax中，再对ebx减一，则可减少两个字节。

不过，因为标准输入、标准输出和标准错误都指向终端，如果往标准输入写入一些东西，它还是会输出到标准输出上，所以在上述代码中如果在sys\_write之前ebx设置为0，那么也可正常往屏幕上打印Hell World，这样的话，sys\_exit调用前就没必要修改ebx，而仅需把eax设置为1，这样就可减少3个字节。

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

### 把代码移入文件头或程序头中

纯粹的指令只有24个字节了，还有办法再减少目标文件的大小么？如果看了参考资料[1][1]，看样子你又要蠢蠢欲动了：这24个字节是否可以插入到文件头部或程序头部？如果可以那是否意味着还可减少可执行文件的大小呢？现在来比较一下这三部分的十六进制内容。

```
$  hexdump -C hello -n 52     #文件头(52bytes)
00000000  7f 45 4c 46 01 01 01 00  00 00 00 00 00 00 00 00  |.ELF............|
00000010  02 00 03 00 01 00 00 00  54 80 04 08 34 00 00 00  |........T...4...|
00000020  00 00 00 00 00 00 00 00  34 00 20 00 01 00 00 00  |........4. .....|
00000030  00 00 00 00                                       |....|
00000034
$ hexdump -C hello -s 52 -n 32    #程序头(32bytes)
00000034  01 00 00 00 00 00 00 00  00 80 04 08 00 80 04 08  |................|
00000044  6c 00 00 00 6c 00 00 00  05 00 00 00 00 10 00 00  |l...l...........|
00000054
$ hexdump -C hello -s 84          #实际代码部分(24bytes)
00000054  59 59 59 c6 41 0c 0a 31  d2 b2 0d 31 c0 b0 04 31  |YYY.A..1...1...1|
00000064  db cd 80 31 c0 40 cd 80                           |...1.@..|
0000006c
```

从上面结果发现ELF文件头部和程序头部还有好些空洞(0)，是否可以通过引入跳转指令把24个字节分散放入到那些空洞里或者是直接覆盖掉那些系统并不关心的内容？抑或是把代码压缩以后放入可执行文件中，并在其中实现一个解压缩算法？还可以是通过一些代码覆盖率测试工具(gcov,prof)对你的代码进行优化？这个作为我们共同的练习吧！

由于时间关系，这里不再进一步讨论，如果想进一步研究，请阅读参考资料[1][1]，它更深层次地讨论了ELF文件，特别是Linux系统对ELF文件头部和程序头部的解析。

## 小结

到这里，关于可执行文件的讨论暂且结束，最后来一段小小的总结，那就是我们设法去减少可执行文件大小的意义？

实际上，通过这样一个讨论深入到了很多技术的细节，包括可执行文件的格式、目标代码链接的过程、Linux下汇编语言开发等。与此同时，可执行文件大小的减少本身对嵌入式系统非常有用，如果删除那些对程序运行没有影响的节区和节区表将减少目标系统的大小，适应嵌入式系统资源受限的需求。除此之外，动态连接库中的很多函数可能不会被使用到，因此也可以通过某种方式剔除[8][8][10][10]。

或许，你还会发现更多有趣的意义，欢迎给我发送邮件，一起讨论。

## 参考资料

- [A Whirlwind Tutorial on Creating Really Teensy ELF Executables for Linux][1]
- [UNIX/LINUX 平台可执行文件格式分析][2]
- [C/C++程序编译步骤详解][3]
- [The Linux GCC HOW TO][4]
- [ELF: From The Programmer's Perspective][5]
- [Understanding ELF using readelf and objdump][6]
- [Dissecting shared libraries][7]
- [嵌入式Linux小型化技术][8]
- [Linux汇编语言开发指南][9]
- [Library Optimizer][10]
- ELF file format and ABI：[1][11]，[2][12]，[3][13]，[4][14]

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
 [11]: http://www.x86.org/ftp/manuals/tools/elf.pdf
 [12]: http://www.muppetlabs.com/~breadbox/software/ELF.txt
 [13]: http://162.105.203.48/web/gaikuang/submission/TN05.ELF.Format.Summary.pdf
 [14]: http://www.xfocus.net/articles/200105/174.html
