**[配套视频已上线](https://www.cctalk.com/m/group/88089283)**：55 节视频，80+ 份实验素材，独立代码仓库
<br/>
<a href="https://www.cctalk.com/m/group/88089283" target="_blank"><img src="pic/elf-horizontal.jpg" style="max-height:250px; max-width:100%">
</a>
<br/>

# 程序执行的一刹那

-    [什么是命令行接口](#toc_16100_6031_1)
-    [/bin/bash 是什么时候启动的](#toc_16100_6031_2)
    -    [/bin/login](#toc_16100_6031_3)
    -    [/bin/getty](#toc_16100_6031_4)
    -    [/sbin/init](#toc_16100_6031_5)
    -    [命令启动过程追本溯源](#toc_16100_6031_6)
    -    [谁启动了 /sbin/init](#toc_16100_6031_7)
-    [/bin/bash 如何处理用户键入的命令](#toc_16100_6031_8)
    -    [预备知识](#toc_16100_6031_9)
    -    [哪种命令先被执行](#toc_16100_6031_10)
    -    [这些特殊字符是如何解析的：`|, >, <, &`](#toc_16100_6031_11)
    -    [/bin/bash 用什么魔法让一个普通程序变成了进程](#toc_16100_6031_12)
-    [参考资料](#toc_16100_6031_13)


当我们在 Linux 下的命令行输入一个命令之后，这背后发生了什么？

<span id="toc_16100_6031_1"></span>
## 什么是命令行接口

用户使用计算机有两种常见的方式，一种是图形化的接口（GUI），另外一种则是命令行接口（CLI）。对于图形化的接口，用户点击某个图标就可启动后台的某个程序；对于命令行的接口，用户键入某个程序的名字就可启动某个程序。这两者的基本过程是类似的，都需要查找程序文件在磁盘上的位置，加载到内存并通过不同的解释器进行解析和运行。下面以命令行为例来介绍程序执行一刹那发生的一些事情。

首先来介绍什么是命令行？命令行就是 `Command Line`，很直观的概念就是系统启动后的那个黑屏幕：有一个提示符，并有光标在闪烁的那样一个终端，一般情况下可以用 `CTRL+ALT+F1-6` 切换到不同的终端；在 GUI 界面下也会有一些伪终端，看上去和系统启动时的那个终端没有什么区别，也会有一个提示符，并有一个光标在闪烁。就提示符和响应用户的键盘输入而言，它们两者在功能上是一样的，实际上它们就是同一个东西，用下面的命令就可以把它们打印出来。

```
$ echo $SHELL # 打印当前SHELL，当前运行的命令行接口程序
/bin/bash
$ echo $$     # 该程序对应进程ID，$$是个特殊的环境变量，它存放了当前进程ID
1481
$ ps -C bash   # 通过PS命令查看
  PID TTY          TIME CMD
 1481 pts/0    00:00:00 bash
```

从上面的操作结果可以看出，当前命令行接口实际上是一个程序，那就是 `/bin/bash`，它是一个实实在在的程序，它打印提示符，接受用户输入的命令，分析命令序列并执行然后返回结果。不过 `/bin/bash` 仅仅是当前使用的命令行程序之一，还有很多具有类似功能的程序，比如 `/bin/ash`, `/bin/dash` 等。不过这里主要来讨论 `bash`，讨论它自己是怎么启动的，它怎么样处理用户输入的命令等后台细节？

<span id="toc_16100_6031_2"></span>
## /bin/bash 是什么时候启动的

<span id="toc_16100_6031_3"></span>
### /bin/login

先通过 `CTRL+ALT+F1` 切换到一个普通终端下面，一般情况下看到的是 "XXX login: " 提示输入用户名，接着是提示输入密码，然后呢？就直接登录到了我们的命令行接口。实际上正是你输入正确的密码后，那个程序才把 `/bin/bash` 给启动了。那是什么东西提示 "XXX login:" 的呢？正是 `/bin/login` 程序，那 `/bin/login` 程序怎么知道要启动 `/bin/bash`，而不是其他的 `/bin/dash` 呢？

`/bin/login` 程序实际上会检查我们的 `/etc/passwd` 文件，在这个文件里头包含了用户名、密码和该用户的登录 Shell。密码和用户名匹配用户的登录，而登录 Shell 则作为用户登录后的命令行程序。看看 `/etc/passwd` 中典型的这么一行：

```
$ cat /etc/passwd | grep falcon
falcon:x:1000:1000:falcon,,,:/home/falcon:/bin/bash
```

这个是我用的帐号的相关信息哦，看到最后一行没？`/bin/bash`，这正是我登录用的命令行解释程序。至于密码呢，看到那个 **`x`** 没？这个 `x` 说明我的密码被保存在另外一个文件里头 `/etc/shadow`，而且密码是经过加密的。至于这两个文件的更多细节，看手册吧。

我们怎么知道刚好是 `/bin/login` 打印了 "XXX login" 呢？现在回顾一下很早以前学习的那个 `strace` 命令。我们可以用 `strace` 命令来跟踪 `/bin/login` 程序的执行。

跟上面一样，切换到一个普通终端，并切换到 Root 用户，用下面的命令：

```
$ strace -f -o strace.out /bin/login
```

退出以后就可以打开 `strace.out` 文件，看看到底执行了哪些文件，读取了哪些文件。从中可以看到正是 `/bin/login` 程序用 `execve` 调用了 `/bin/bash` 命令。通过后面的演示，可以发现 `/bin/login` 只是在子进程里头用 `execve` 调用了 `/bin/bash`，因为在启动 `/bin/bash` 后，可以看到 `/bin/login` 并没有退出。

<span id="toc_16100_6031_4"></span>
### /bin/getty

那 `/bin/login` 又是怎么起来的呢？

下面再来看一个演示。先在一个可以登陆的终端下执行下面的命令。

```
$ getty 38400 tty8 linux
```

`getty` 命令停留在那里，貌似等待用户的什么操作，现在切回到第 8 个终端，是不是看到有 "XXX login:" 的提示了。输入用户名并登录，之后退出，回到第一个终端，发现 `getty` 命令已经退出。

类似地，也可以用 `strace` 命令来跟踪 `getty` 的执行过程。在第一个终端下切换到 Root 用户。执行如下命令：

```
$ strace -f -o strace.out getty 38400 tty8 linux
```

同样在 `strace.out` 命令中可以找到该命令的相关启动细节。比如，可以看到正是 `getty` 程序用 `execve` 系统调用执行了 `/bin/login` 程序。这个地方，`getty` 是在自己的主进程里头直接执行了 `/bin/login`，这样 `/bin/login` 将把 `getty` 的进程空间替换掉。

<span id="toc_16100_6031_5"></span>
### /sbin/init

这里涉及到一个非常重要的东西：`/sbin/init`，通过 `man init` 命令可以查看到该命令的作用，它可是“万物之王”（init  is  the  parent of all processes on the system）哦。它是 Linux 系统默认启动的第一个程序，负责进行 Linux 系统的一些初始化工作，而这些初始化工作的配置则是通过 `/etc/inittab` 来做的。那么来看看 `/etc/inittab` 的一个简单的例子吧，可以通过 `man inittab` 查看相关帮助。

需要注意的是，在较新版本的 Ubuntu 和 Fedora 等发行版中，一些新的 `init` 程序，比如 `upstart` 和 `systemd` 被开发出来用于取代 `System V init`，它们可能放弃了对 `/etc/inittab` 的使用，例如 `upstart` 会读取 `/etc/init/` 下的配置，比如 `/etc/init/tty1.conf`，但是，基本的配置思路还是类似 `/etc/inittab`，对于 `upstart` 的 `init` 配置，这里不做介绍，请通过 `man 5 init` 查看帮助。

配置文件 `/etc/inittab` 的语法非常简单，就是下面一行的重复，

```
id:runlevels:action:process
```

-   `id` 就是一个唯一的编号，不用管它，一个名字而言，无关紧要。

-   `runlevels` 是运行级别，这个还是比较重要的，理解运行级别的概念很有必要，它可以有如下的取值：

        0 is halt.
        1 is single-user.
        2-5 are multi-user.
        6 is reboot.

    不过，真正在配置文件里头用的是 `1-5` 了，而 `0` 和 `6` 非常特别，除了用它作为 `init` 命令的参数关机和重启外，似乎没有哪个“傻瓜”把它写在系统的配置文件里头，让系统启动以后就关机或者重启。`1` 代表单用户，而 `2-5` 则代表多用户。对于 `2-5` 可能有不同的解释，比如在 Slackware 12.0 上，`2,3,5` 被用来作为多用户模式，但是默认不启动 X windows （GUI接口），而 `4` 则作为启动 X windows 的运行级别。

-   `action` 是动作，它也有很多选择，我们关心几个常用的
    
-   `initdefault`：用来指定系统启动后进入的运行级别，通常在 `/etc/inittab` 的第一条配置，如：

        id:3:initdefault:

    这个说明默认运行级别是 3，即多用户模式，但是不启动 X window 的那种。

-   `sysinit`：指定那些在系统启动时将被执行的程序，例如：

        si:S:sysinit:/etc/rc.d/rc.S

    在 `man inittab` 中提到，对于 `sysinit`，`boot` 等动作，`runlevels` 选项是不用管的，所以可以很容易解读这条配置：它的意思是系统启动时将默认执行 `/etc/rc.d/rc.S` 文件，在这个文件里可直接或者间接地执行想让系统启动时执行的任何程序，完成系统的初始化。

-   `wait`：当进入某个特别的运行级别时，指定的程序将被执行一次，`init` 将等到它执行完成，例如：

        rc:2345:wait:/etc/rc.d/rc.M

    这个说明无论是进入运行级别 2，3，4，5 中哪一个，`/etc/rc.d/rc.M` 将被执行一次，并且有 `init` 等待它执行完成。

-   `ctrlaltdel`，当 `init` 程序接收到 `SIGINT` 信号时，某个指定的程序将被执行，我们通常通过按下 `CTRL+ALT+DEL`，这个默认情况下将给 `init` 发送一个 `SIGINT` 信号。

    如果我们想在按下这几个键时，系统重启，那么可以在 `/etc/inittab` 中写入：

        ca::ctrlaltdel:/sbin/shutdown -t5 -r now

-   `respawn`：这个指定的进程将被重启，任何时候当它退出时。这意味着没有办法结束它，除非 `init` 自己结束了。例如：

        c1:1235:respawn:/sbin/agetty 38400 tty1 linux

    这一行的意思非常简单，就是系统运行在级别 1，2，3，5 时，将默认执行 `/sbin/agetty` 程序（这个类似于上面提到的 `getty` 程序），这个程序非常有意思，就是无论什么时候它退出，`init` 将再次启动它。这个有几个比较有意思的问题：

* 在 Slackware 12.0 下，当默认运行级别为 4 时，只有第 6 个终端可以用。原因是什么呢？因为类似上面的配置，因为那里只有 `1235`，而没有 `4`，这意味着当系统运行在第 `4` 级别时，其他终端下的 `/sbin/agetty` 没有启动。所以，如果想让其他终端都可以用，把 `1235` 修改为 `12345` 即可。
* 另外一个有趣的问题就是：正是 `init` 程序在读取这个配置行以后启动了 `/sbin/agetty`，这就是 `/sbin/agetty` 的秘密。
* 还有一个问题：无论退出哪个终端，那个 "XXX login:" 总是会被打印，原因是 `respawn` 动作有趣的性质，因为它告诉 `init`，无论 `/sbin/agetty` 什么时候退出，重新把它启动起来，那跟 "XXX login:" 有什么关系呢？从前面的内容，我们发现正是 `/sbin/getty` （同 `agetty`）启动了 `/bin/login`，而 `/bin/login` 又启动了 `/bin/bash`，即我们的命令行程序。

<span id="toc_16100_6031_6"></span>
### 命令启动过程追本溯源

而 `init` 程序作为“万物之王”，它是所有进程的“父”（也可能是祖父……）进程，那意味着其他进程最多只能是它的儿子进程。而这个子进程是怎么创建的，`fork` 调用，而不是之前提到的 `execve` 调用。前者创建一个子进程，后者则会覆盖当前进程。因为我们发现 `/sbin/getty` 运行时，`init` 并没有退出，因此可以判断是 `fork` 调用创建一个子进程后，才通过 `execve` 执行了 `/sbin/getty`。

因此，可以总结出这么一个调用过程：

```
     fork     execve         execve         fork           execve
init --> init --> /sbin/getty --> /bin/login --> /bin/login --> /bin/bash
```

这里的 `execve` 调用以后，后者将直接替换前者，因此当键入 `exit` 退出 `/bin/bash` 以后，也就相当于 `/sbin/getty` 都已经结束了，因此最前面的 `init` 程序判断 `/sbin/getty` 退出了，又会创建一个子进程把 `/sbin/getty` 启动，进而又启动了 `/bin/login`，又看到了那个 "XXX login:"。

通过 `ps` 和 `pstree` 命令看看实际情况是不是这样，前者打印出进程的信息，后者则打印出调用关系。

```
$ ps -ef | egrep "/sbin/init|/sbin/getty|bash|/bin/login"
root         1     0  0 21:43 ?        00:00:01 /sbin/init
root      3957     1  0 21:43 tty4     00:00:00 /sbin/getty 38400 tty4
root      3958     1  0 21:43 tty5     00:00:00 /sbin/getty 38400 tty5
root      3963     1  0 21:43 tty3     00:00:00 /sbin/getty 38400 tty3
root      3965     1  0 21:43 tty6     00:00:00 /sbin/getty 38400 tty6
root      7023     1  0 22:48 tty1     00:00:00 /sbin/getty 38400 tty1
root      7081     1  0 22:51 tty2     00:00:00 /bin/login --
falcon    7092  7081  0 22:52 tty2     00:00:00 -bash
```

上面的结果已经过滤了一些不相干的数据。从上面的结果可以看到，除了 `tty2` 被替换成 `/bin/login` 外，其他终端都运行着 `/sbin/getty`，说明终端 2 上的进程是 `/bin/login`，它已经把 `/sbin/getty` 替换掉，另外，我们看到 `-bash` 进程的父进程是 `7081` 刚好是 `/bin/login` 程序，这说明 `/bin/login` 启动了 `-bash`，但是它并没有替换掉 `/bin/login`，而是成为了 `/bin/login` 的子进程，这说明 `/bin/login` 通过 `fork` 创建了一个子进程并通过 `execve` 执行了 `-bash`（后者通过 `strace`跟踪到）。而 `init` 呢，其进程 ID 是 1，是 `/sbin/getty` 和 `/bin/login` 的父进程，说明 `init` 启动或者间接启动了它们。下面通过 `pstree` 来查看调用树，可以更清晰地看出上述关系。

```
$ pstree | egrep "init|getty|\-bash|login"
init-+-5*[getty]
     |-login---bash
     |-xfce4-terminal-+-bash-+-grep
```

结果显示 `init` 是 5 个 `getty` 程序，`login` 程序和 `xfce4-terminal` 的父进程，而后两者则是 `bash` 的父进程，另外我们执行的 `grep` 命令则在 `bash` 上运行，是 `bash` 的子进程，这个将是我们后面关心的问题。

从上面的结果发现，`init` 作为所有进程的父进程，它的父进程 ID 饶有兴趣的是 0，它是怎么被启动的呢？谁才是真正的“造物主”？

<span id="toc_16100_6031_7"></span>
### 谁启动了 /sbin/init

如果用过 `Lilo` 或者 `Grub` 这些操作系统引导程序，可能会用到 Linux 内核的一个启动参数 `init`，当忘记密码时，可能会把这个参数设置成 `/bin/bash`，让系统直接进入命令行，而无须输入帐号和密码，这样就可以方便地把登录密码修改掉。

这个 `init` 参数是个什么东西呢？通过 `man bootparam` 会发现它的秘密，`init` 参数正好指定了内核启动后要启动的第一个程序，而如果没有指定该参数，内核将依次查找 `/sbin/init`，`/etc/init`，`/bin/init`，`/bin/sh`，如果找不到这几个文件中的任何一个，内核就要恐慌（panic）了，并挂（hang）在那里一动不动了（注：如果 `panic=timeout` 被传递给内核并且 `timeout` 大于 0，那么就不会挂住而是重启）。

因此 `/sbin/init` 就是 Linux 内核启动的。而 Linux 内核呢？是通过 `Lilo` 或者 `Grub` 等引导程序启动的，`Lilo` 和 `Grub` 都有相应的配置文件，一般对应 `/etc/lilo.conf` 和 `/boot/grub/menu.lst`，通过这些配置文件可以指定内核映像文件、系统根目录所在分区、启动选项标签等信息，从而能够让它们顺利把内核启动起来。

那 `Lilo` 和 `Grub` 本身又是怎么被运行起来的呢？有了解 MBR 不？MBR 就是主引导扇区，一般情况下这里存放着 `Lilo` 和 `Grub` 的代码，而谁知道正好是这里存放了它们呢？BIOS，如果你用光盘安装过操作系统的话，那么应该修改过 `BIOS` 的默认启动设置，通过设置可以让系统从光盘、硬盘、U 盘甚至软盘启动。正是这里的设置让 BIOS 知道了 MBR 处的代码需要被执行。

那 BIOS 又是什么时候被起来的呢？处理器加电后有一个默认的起始地址，一上电就执行到了这里，再之前就是开机键按键后的上电时序。

更多系统启动的细节，看看 `man boot-scripts` 吧。

到这里，`/bin/bash` 的神秘面纱就被揭开了，它只是系统启动后运行的一个程序而已，只不过这个程序可以响应用户的请求，那它到底是如何响应用户请求的呢？

<span id="toc_16100_6031_8"></span>
## /bin/bash 如何处理用户键入的命令

<span id="toc_16100_6031_9"></span>
### 预备知识

在执行磁盘上某个程序时，通常不会指定这个程序文件的绝对路径，比如要执行 `echo` 命令时，一般不会输入 `/bin/echo`，而仅仅是输入 `echo`。那为什么这样 `bash` 也能够找到 `/bin/echo` 呢？原因是 Linux 操作系统支持这样一种策略：Shell 的一个环境变量 `PATH` 里头存放了程序的一些路径，当 Shell 执行程序时有可能去这些目录下查找。`which` 作为 Shell（这里特指 `bash`）的一个内置命令，如果用户输入的命令是磁盘上的某个程序，它会返回这个文件的全路径。

有三个东西和终端的关系很大，那就是标准输入、标准输出和标准错误，它们是三个文件描述符，一般对应描述符 0，1，2。在 C 语言程序里，我们可以把它们当作文件描述符一样进行操作。在命令行下，则可以使用重定向字符`>，<`等对它们进行操作。对于标准输出和标准错误，都默认输出到终端，对于标准输入，也同样默认从终端输入。

<span id="toc_16100_6031_10"></span>
### 哪种命令先被执行

在 C 语言里头要写一段输入字符串的命令很简单，调用 `scanf` 或者 `fgets` 就可以。这个在 `bash` 里头应该是类似的。但是它获取用户的命令以后，如何分析命令，如何响应不同的命令呢？

首先来看看 `bash` 下所谓的命令，用最常见的 `test` 来作测试。

- 字符串被解析成命令

    随便键入一个字符串 `test1`， `bash` 发出响应，告知找不到这个程序：

        $ test1
        bash: test1: command not found

- 内置命令

    而当键入 `test` 时，看不到任何输出，唯一响应是，新命令提示符被打印了：

        $ test
        $

    查看 `test` 这个命令的类型，即查看 `test` 将被如何解释， `type` 告诉我们 `test` 是一个内置命令，如果没有理解错， `test` 应该是利用诸如 `case "test": do something;break;` 这样的机制实现的，具体如何实现可以查看 `bash` 源代码。

        $ type test
        test is a shell builtin

- 外部命令

    这里通过 `which` 查到 `/usr/bin` 下有一个 `test` 命令文件，在键入 `test` 时，到底哪一个被执行了呢？

        $ which test
        /usr/bin/test

    执行这个呢？也没什么反应，到底谁先被执行了？

        $ /usr/bin/test

    从上述演示中发现一个问题？如果输入一个命令，这个命令要么就不存在，要么可能同时是 Shell 的内置命令、也有可能是磁盘上环境变量 `PATH` 所指定的目录下的某个程序文件。

    考虑到 `test` 内置命令和 `/usr/bin/test` 命令的响应结果一样，我们无法知道哪一个先被执行了，怎么办呢？把 `/usr/bin/test` 替换成一个我们自己的命令，并让它打印一些信息(比如 `hello, world!` )，这样我们就知道到底谁被执行了。写完程序，编译好，命名为 `test` 放到 `/usr/bin` 下（记得备份原来那个）。开始测试：

    键入 `test` ，还是没有效果：

        $ test
        $

    而键入绝对路径呢，则打印了 `hello, world!` 诶，那默认情况下肯定是内置命令先被执行了：

        $ /usr/bin/test
        hello, world!

    由上述实验结果可见，内置命令比磁盘文件中的程序优先被 `bash` 执行。原因应该是内置命令避免了不必要的 `fork/execve` 调用，对于采用类似算法实现的功能，内置命令理论上有更高运行效率。

    下面看看更多有趣的内容，键盘键入的命令还有可能是什么呢？因为 `bash` 支持别名（`alias`）和函数（`function`），所以还有可能是别名和函数，另外，如果 `PATH` 环境变量指定的不同目录下有相同名字的程序文件，那到底哪个被优先找到呢？

    下面再作一些实验，

- 别名

    把 `test` 命名为 `ls -l` 的别名，再执行 `test` ，竟然执行了 `ls -l` ，说明别名（`alias`）比内置命令（`builtin`）更优先：

        $ alias test="ls -l"
        $ test
        total 9488
        drwxr-xr-x 12 falcon falcon    4096 2008-02-21 23:43 bash-3.2
        -rw-r--r--  1 falcon falcon 2529838 2008-02-21 23:30 bash-3.2.tar.gz

- 函数

    定义一个名叫 `test` 的函数，执行一下，发现，还是执行了 `ls -l` ，说明 `function` 没有 `alias` 优先级高：

        $ function test { echo "hi, I'm a function"; }
        $ test
        total 9488
        drwxr-xr-x 12 falcon falcon    4096 2008-02-21 23:43 bash-3.2
        -rw-r--r--  1 falcon falcon 2529838 2008-02-21 23:30 bash-3.2.tar.gz

    把别名给去掉（`unalias`），现在执行的是函数，说明函数的优先级比内置命令也要高：

        $ unalias test
        $ test
        hi, I'm a function

    如果在命令之前跟上 `builtin` ，那么将直接执行内置命令：

        $ builtin test

    要去掉某个函数的定义，这样就可以：

        $ unset test

通过这个实验我们得到一个命令的别名（`alias`）、函数（`function`），内置命令（`builtin`）和程序（`program`）的执行优先次序：

        先    alias --> function --> builtin --> program   后

实际上， `type` 命令会告诉我们这些细节， `type -a` 会按照 `bash` 解析的顺序依次打印该命令的类型，而 `type -t` 则会给出第一个将被解析的命令的类型，之所以要做上面的实验，是为了让大家加印象。

```
$ type -a test
test is a shell builtin
test is /usr/bin/test
$ alias test="ls -l"
$ function test { echo "I'm a function"; }
$ type -a test
test is aliased to `ls -l'
test is a function
test ()
{
    echo "I'm a function"
}
test is a shell builtin
test is /usr/bin/test
$ type -t test
alias
```

下面再看看 `PATH` 指定的多个目录下有同名程序的情况。再写一个程序，打印 `hi, world!`，以示和 `hello, world!` 的区别，放到 `PATH` 指定的另外一个目录 `/bin` 下，为了保证测试的说服力，再写一个放到另外一个叫 `/usr/local/sbin` 的目录下。

先看看 `PATH` 环境变量，确保它有 `/usr/bin`，`/bin` 和 `/usr/local/sbin` 这几个目录，然后通过 `type -P`（`-P` 参数强制到 `PATH` 下查找，而不管是别名还是内置命令等，可以通过 `help type` 查看该参数的含义）查看，到底哪个先被执行。

```
$ echo $PATH
/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games
$ type -P test
/usr/local/sbin/test
```

如上可以看到 `/usr/local/sbin` 下的先被找到。

把 `/usr/local/sbin/test` 下的给删除掉，现在 `/usr/bin` 下的先被找到：

```
$ rm /usr/local/sbin/test
$ type -P test
/usr/bin/test
```

`type -a` 也显示类似的结果：

```
$ type -a test
test is aliased to `ls -l'
test is a function
test ()
{
    echo "I'm a function"
}
test is a shell builtin
test is /usr/bin/test
test is /bin/test
```

因此，可以找出这么一个规律： Shell 从 `PATH` 列出的路径中依次查找用户输入的命令。考虑到程序的优先级最低，如果想优先执行磁盘上的程序文件 `test` 呢？那么就可以用 `test -P` 找出这个文件并执行就可以了。

补充：对于 Shell 的内置命令，可以通过 `help command` 的方式获得帮助，对于程序文件，可以查看用户手册（当然，这个需要安装，一般叫做 `xxx-doc`）， `man command` 。

<span id="toc_16100_6031_11"></span>
### 这些特殊字符是如何解析的：`|, >, <, &`

在命令行上，除了输入各种命令以及一些参数外，比如上面 `type` 命令的各种参数 `-a`，`-P` 等，对于这些参数，是传递给程序本身的，非常好处理，比如 `if` ， `else` 条件分支或者 `switch`，`case` 都可以处理。当然，在 `bash` 里头可能使用专门的参数处理函数 `getopt` 和 `getopt_long` 来处理它们。

而 `|` ， `>` ， `<` ， `&` 等字符，则比较特别， Shell 是怎么处理它们的呢？它们也被传递给程序本身吗？可我们的程序内部一般都不处理这些字符的，所以应该是 Shell 程序自己解析了它们。

先来看看这几个字符在命令行的常见用法，


`<` 字符表示：把 `test.c` 文件重定向为标准输入，作为 `cat` 命令输入，而 `cat` 默认输出到标准输出：

```
$ cat < ./test.c
#include <stdio.h>

int main(void)
{
        printf("hi, myself!\n");
        return 0;
}
```

`>` 表示把标准输出重定向为文件 `test_new.c` ，结果内容输出到 `test_new.c` ：

```
$ cat < ./test.c > test_new.c
```

对于 `>` ， `<` ， `>>` ， `<<` ， `<>` 我们都称之为重定向（`redirect`）， Shell 到底是怎么进行所谓的“重定向”的呢？

这主要归功于 `dup/fcntl` 等函数，它们可以实现：复制文件描述符，让多个文件描述符共享同一个文件表项。比如，当把文件 `test.c` 重定向为标准输入时。假设之前用以打开 `test.c` 的文件描述符是 5 ，现在就把 5 复制为了 0 ，这样当 `cat` 试图从标准输入读出内容时，也就访问了文件描述符 5 指向的文件表项，接着读出了文件内容。输出重定向与此类似。其他的重定向，诸如 `>>` ， `<<` ， `<>` 等虽然和 `>` ， `<` 的具体实现功能不太一样，但本质是一样的，都是文件描述符的复制，只不过可能对文件操作有一些附加的限制，比如 `>>` 在输出时追加到文件末尾，而 `>` 则会从头开始写入文件，前者意味着文件的大小会增长，而后者则意味文件被重写。

那么 `|` 呢？ `|` 被形象地称为“管道”，实际上它就是通过 C 语言里头的无名管道来实现的。先看一个例子，

```
$ cat < ./test.c  | grep hi
        printf("hi, myself!\n");
```

在这个例子中， `cat` 读出了 `test.c` 文件中的内容，并输出到标准输出上，但是实际上输出的内容却只有一行，原因是这个标准输出被“接到”了 `grep` 命令的标准输入上，而 `grep` 命令只打印了包含 “hi” 字符串的一行。

这是怎么被“接”上的。 `cat` 和 `grep` 作为两个单独的命令，它们本身没有办法把两者的输入和输出“接”起来。这正是 Shell 自己的“杰作”，它通过 C 语言里头的 `pipe` 函数创建了一个管道（一个包含两个文件描述符的整形数组，一个描述符用于写入数据，一个描述符用于读入数据），并且通过 `dup/fcntl` 把 `cat` 的输出复制到了管道的输入，而把管道的输出则复制到了 `grep` 的输入。这真是一个奇妙的想法。

那 `&` 呢？当你在程序的最后跟上这个奇妙的字符以后就可以接着做其他事情了，看看效果：

```
$ sleep 50 & #让程序在后台运行
[1] 8261
```

提示符被打印出来，可以输入东西，让程序到前台运行，无法输入东西了，按下 `CTRL+Z` ，再让程序到后台运行：

```
$ fg %1
sleep 50

[1]+  Stopped                 sleep 50
```

实际上 `&` 正是 `Shell ` 支持作业控制的表征，通过作业控制，用户在命令行上可以同时作几个事情（把当前不做的放到后台，用 `&` 或者 `CTRL+Z` 或者 `bg`）并且可以自由地选择当前需要执行哪一个（用 `fg` 调到前台）。这在实现时应该涉及到很多东西，包括终端会话（`session`）、终端信号、前台进程、后台进程等。而在命令的后面加上 `&` 后，该命令将被作为后台进程执行，后台进程是什么呢？这类进程无法接收用户发送给终端的信号（如 `SIGHUP` ，`SIGQUIT` ，`SIGINT`），无法响应键盘输入（被前台进程占用着），不过可以通过 `fg` 切换到前台而享受作为前台进程具有的特权。

因此，当一个命令被加上 `&` 执行后，Shell 必须让它具有后台进程的特征，让它无法响应键盘的输入，无法响应终端的信号（意味忽略这些信号），并且比较重要的是新的命令提示符得打印出来，并且让命令行接口可以继续执行其他命令，这些就是 Shell 对 `&` 的执行动作。

还有什么神秘的呢？你也可以写自己的 Shell 了，并且可以让内核启动后就执行它 `l` ，在 `lilo` 或者 `grub` 的启动参数上设置 `init=/path/to/your/own/shell/program` 就可以。当然，也可以把它作为自己的登录 Shell ，只需要放到 `/etc/passwd` 文件中相应用户名所在行的最后就可以。不过貌似到现在还没介绍 Shell 是怎么执行程序，是怎样让程序变成进程的，所以继续。

<span id="toc_16100_6031_12"></span>
### /bin/bash 用什么魔法让一个普通程序变成了进程

当我们从键盘键入一串命令，Shell 奇妙地响应了，对于内置命令和函数，Shell 自身就可以解析了（通过 `switch` ，`case` 之类的 C 语言语句）。但是，如果这个命令是磁盘上的一个文件呢。它找到该文件以后，怎么执行它的呢？

还是用 `strace` 来跟踪一个命令的执行过程看看。

```
$ strace -f -o strace.log /usr/bin/test
hello, world!
$ cat strace.log | sed -ne "1p"   #我们对第一行很感兴趣
8445  execve("/usr/bin/test", ["/usr/bin/test"], [/* 33 vars */]) = 0
```

从跟踪到的结果的第一行可以看到 `bash` 通过 `execve` 调用了 `/usr/bin/test` ，并且给它传了 33 个参数。这 33 个 `vars` 是什么呢？看看 `declare -x` 的结果（这个结果只有 32 个，原因是 `vars` 的最后一个变量需要是一个结束标志，即 `NULL`）。

```
$ declare -x | wc -l   #declare -x声明的环境变量将被导出到子进程中
32
$ export TEST="just a test"   #为了认证declare -x和之前的vars的个数的关系，再加一个
$ declare -x | wc -l
33
$ strace -f -o strace.log /usr/bin/test   #再次跟踪，看看这个关系
hello, world!
$ cat strace.log | sed -ne "1p"
8523  execve("/usr/bin/test", ["/usr/bin/test"], [/* 34 vars */]) = 0
```

通过这个演示发现，当前 Shell 的环境变量中被设置为 `export` 的变量被复制到了新的程序里头。不过虽然我们认为 Shell 执行新程序时是在一个新的进程里头执行的，但是 `strace` 并没有跟踪到诸如 `fork` 的系统调用（可能是 `strace` 自己设计的时候并没有跟踪 `fork` ，或者是在 `fork` 之后才跟踪）。但是有一个事实我们不得不承认：当前 Shell 并没有被新程序的进程替换，所以说 Shell 肯定是先调用 `fork` （也有可能是 `vfork`）创建了一个子进程，然后再调用 `execve` 执行新程序的。如果你还不相信，那么直接通过 `exec` 执行新程序看看，这个可是直接把当前 Shell 的进程替换掉的。

```
exec /usr/bin/test
```

该可以看到当前 Shell “哗”（听不到，突然没了而已）的一下就没有了。

下面来模拟一下 Shell 执行普通程序。 `multiprocess` 相当于当前 Shell ，而 `/usr/bin/test` 则相当于通过命令行传递给 Shell 的一个程序。这里是代码：

```
/* multiprocess.c */
#include <stdio.h>
#include <sys/types.h>
#include <unistd.h>     /* sleep, fork, _exit */

int main()
{
	int child;
	int status;

	if( (child = fork()) == 0) {    /* child */
		printf("child: my pid is %d\n", getpid());
		printf("child: my parent's pid is %d\n", getppid());
		execlp("/usr/bin/test","/usr/bin/test",(char *)NULL);;
	} else if(child < 0){   	/* error */
        	printf("create child process error!\n");
        	_exit(0);
	}                                               	/* parent */
	printf("parent: my pid is %d\n", getpid());
	if ( wait(&status) == child ) {
		printf("parent: wait for my child exit successfully!\n");
	}
}
```

运行看看，

```
$ make multiprocess
$ ./multiprocess
child: my pid is 2251
child: my parent's pid is 2250
hello, world!
parent: my pid is 2250
parent: wait for my child exit successfully!
```

从执行结果可以看出，`/usr/bin/test` 在 `multiprocess` 的子进程中运行并不干扰父进程，因为父进程一直等到了 `/usr/bin/test` 执行完成。

再回头看看代码，你会发现 `execlp` 并没有传递任何环境变量信息给 `/usr/bin/test` ，到底是怎么把环境变量传送过去的呢？通过 `man exec` 我们可以看到一组 `exec` 的调用，在里头并没有发现 `execve` ，但是通过 `man execve` 可以看到该系统调用。实际上 `exec` 的那一组调用都只是 `libc` 库提供的，而 `execve` 才是真正的系统调用，也就是说无论使用 `exec` 调用中的哪一个，最终调用的都是 `execve` ，如果使用 `execlp` ，那么 `execlp` 将通过一定的处理把参数转换为 `execve` 的参数。因此，虽然我们没有传递任何环境变量给 `execlp` ，但是默认情况下，`execlp` 把父进程的环境变量复制给了子进程，而这个动作是在 `execlp` 函数内部完成的。

现在，总结一下 `execve` ，它有有三个参数，

 `- ` 第一个是程序本身的绝对路径，对于刚才使用的 `execlp` ，我们没有指定路径，这意味着它会设法到 `PATH` 环境变量指定的路径下去寻找程序的全路径。
 `- ` 第二个参数是一个将传递给被它执行的程序的参数数组指针。正是这个参数把我们从命令行上输入的那些参数，诸如 `grep` 命令的 `-v` 等传递给了新程序，可以通过 `main` 函数的第二个参数 `char ` * `argv[]` 获得这些内容。
 `- ` 第三个参数是一个将传递给被它执行的程序的环境变量，这些环境变量也可以通过 `main` 函数的第三个变量获取，只要定义一个 `char ` * `env[]` 就可以了，只是通常不直接用它罢了，而是通过另外的方式，通过 `extern char ` ** `environ` 全局变量（环境变量表的指针）或者 `getenv` 函数来获取某个环境变量的值。

当然，实际上，当程序被 `execve` 执行后，它被加载到了内存里，包括程序的各种指令、数据以及传递给它的各种参数、环境变量等都被存放在系统分配给该程序的内存空间中。

我们可以通过 `/proc/<pid>/maps` 把一个程序对应的进程的内存映象看个大概。

```
$ cat /proc/self/maps   #查看cat程序自身加载后对应进程的内存映像
08048000-0804c000 r-xp 00000000 03:01 273716     /bin/cat
0804c000-0804d000 rw-p 00003000 03:01 273716     /bin/cat
0804d000-0806e000 rw-p 0804d000 00:00 0          [heap]
b7c46000-b7e46000 r--p 00000000 03:01 87528      /usr/lib/locale/locale-archive
b7e46000-b7e47000 rw-p b7e46000 00:00 0
b7e47000-b7f83000 r-xp 00000000 03:01 466875     /lib/libc-2.5.so
b7f83000-b7f84000 r--p 0013c000 03:01 466875     /lib/libc-2.5.so
b7f84000-b7f86000 rw-p 0013d000 03:01 466875     /lib/libc-2.5.so
b7f86000-b7f8a000 rw-p b7f86000 00:00 0
b7fa1000-b7fbc000 r-xp 00000000 03:01 402817     /lib/ld-2.5.so
b7fbc000-b7fbe000 rw-p 0001b000 03:01 402817     /lib/ld-2.5.so
bfcdf000-bfcf4000 rw-p bfcdf000 00:00 0          [stack]
ffffe000-fffff000 r-xp 00000000 00:00 0          [vdso]
```

关于程序加载和进程内存映像的更多细节请参考[《C 语言程序缓冲区注入分析》][100]。

[100]: 02-chapter5.markdown

到这里，关于命令行的秘密都被“曝光”了，可以开始写自己的命令行解释程序了。

关于进程的相关操作请参考[《进程与进程的基本操作》][101]。

[101]: 02-chapter7.markdown

补充：上面没有讨论到一个比较重要的内容，那就是即使 `execve` 找到了某个可执行文件，如果该文件属主没有运行该程序的权限，那么也没有办法运行程序。可通过 `ls -l` 查看程序的权限，通过 `chmod` 添加或者去掉可执行权限。

文件属主具有可执行权限时才可以执行某个程序：

```
$ whoami
falcon
$ ls -l hello  #查看用户权限(第一个x表示属主对该程序具有可执行权限
-rwxr-xr-x 1 falcon users 6383 2000-01-23 07:59 hello*
$ ./hello
Hello World
$ chmod -x hello  #去掉属主的可执行权限
$ ls -l hello
-rw-r--r-- 1 falcon users 6383 2000-01-23 07:59 hello
$ ./hello
-bash: ./hello: Permission denied
```

<span id="toc_16100_6031_13"></span>
## 参考资料

- Linux 启动过程：`man boot-scripts`
- Linux 内核启动参数：`man bootparam`
- `man 5 passwd`
- `man shadow`
- 《UNIX 环境高级编程》，进程关系一章

<hr>

**关注作者公众号**：
<br/>
<img src='../../pic/tinylab-wechat.jpg' width='110px'/>
<br/>
