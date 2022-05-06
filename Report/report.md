# 2021Spring编译原理lab报告

## 序言

2022年春季学期的编译原理修改了Lab的内容，改为由助教自行新开发的[项目](https://pku-minic.github.io/online-doc/#/)。Lab的最终目的是实现一个可以将 SysY 语言(C 语言的子集)编译到 RISC-V 汇编的编译器。具体的实现可以分成两个阶段，首先是将 SysY 语言翻译到 Koopa 的中间表示代码，然后从中间代码构建最终的 RISC-V 汇编。

### 环境配置

首先需要配置相关的环境。

Lab 的运行环境以及需要的工具链已经打包成了镜像，可以运行在 Docker 中。拉取镜像使用以下命令：

```
docker pull maxxing/compiler-dev
```

然后就遇到了第一个问题——下载速度非常慢。可以尝试修改源，在 Docker 的设置—— Docker Engine 中将对话框代码替换为如下代码：


```
{
  "builder": {
    "gc": {
      "defaultKeepStorage": "20GB",
      "enabled": true
    }
  },
  "experimental": false,
  "features": {
    "buildkit": true
  },
  "registry-mirrors": [
    "https://hub-mirror.c.163.com",
    "https://mirror.baidubce.com"
  ]
}
```

然后就可以欢乐下载体验镜像文件了。但是重启之后会遇到 Docker 崩溃的问题，显示 Failed to restart。网上的分析是端口有冲突，暂时的解决方法是命令行中输入
> netsh winsock reset

但是重启之后问题依然出现。长期的解决方案是下载 nolsp.exe ，命令行中执行
> noLsp.exe C:\windows\system32\wsl.exe

编码的方案是在宿主系统中编写和维护项目，然后把项目目录挂载到 docker 中运行。docker 运行之后并不需要保存过程文件，所以可以直接删除来维护一个干净的调试环境。假设本地文件夹的位置是 `D:\compiler` ，想要挂载到 `/root/compiler` 位置，使用以下命令：
> docker run -it --rm -v C:\Users\herby\testproject:/root/compiler maxxing/compiler-dev bash

注意 windows 中的目录格式和 Linux 中是不同的，所以挂载时前后的目录斜杠方向相反。

然后在相应的文件夹中放入项目模板，并且在 `git` 中设置自己对应的项目地址。基本的编码环境就设置好了。

## Lv1 & Lv2

这部分需要构建一个词法分析和语法分析的框架，前两个lv没有功能的实现，所以只要能够解析代码并且扔掉注释就好了。

`sysy.l`文件用于进行词法分析，其中定义了每一个最基本的token。词法分析把字节流转换为token流。如果是保留字符，返回相应标识符；如果是数字，识别进制然后转换出对应的数最为返回值；其他的名称作为标识符返回字符串。为了让保留字不被作为标识符返回，需要把他们的定义写在标识符的正则表达式之前。`sysy.l`文件基本上已经给出了，只需要补充段注释的正则表达式。段注释由斜杠和星号包裹，且为最短匹配原则，与正则表达式默认的最长匹配不一致，所以需要规定在中间不能出现`*/`。也就是说中间可以是没有出现`*`，或者`*`之后不能紧跟着`/`。满足这样形式的字符可以出现多次，所以最终的实现为：
```
BlockComment  "/*"([^\*]|(\*)*[^\*/])*(\*)*"*/"
```

`sysy.y`定义了语法分析的规则，来得到AST。推导的开始符号是`CompUnit`，根据ENBF的规则，需要给出相应的推导规则以及对应的行为。输出中间表示的动作是在解析完整个代码之后才进行的，所以在此处只要把相应的结构关系定义好就行，具体的行为在结构体的对应函数中实现。但是此处的推导规则和ENBF有一些区别，比如此处不能直接定义出现0次或1次，也不能直接定义出现多次。在`sysy.y`文件的开头需要给出非终结符的类型定义，每次在之后的推导中定义一个新的非终结符号，就要在此处添加声明。此处的推导规则都在文档里给出了，直接使用就好。

新建一个文件`AST.h`用于存放所有`AST`的结构。所有的AST都是一个基类`BaseAST`的派生类，并在派生类中定义相关的关联结构。这样做的好处是所有的类都可以使用基类的指针来管理，也可以用相同的函数根据派生类实现不同的功能。在`sysy.y`进行语法分析的过程中会构建好这些AST的互相关系（也就是填充好对应的内容和指针），最后返回给调用语法分析函数的是一个`CompUnit`的指针。对此指针调用输出函数可以根据自定的规则遍历整棵树并输出中间形式。

参考在线文档，定义`Dump`函数用于输出。为了方便调试，可以在每个函数的开始设置如果是调试模式就输出对应AST的名称，这样可以看清推导的具体过程。在这个阶段并不需要输出有意义的IR，所以这部分可以先放一放。

中间代码（Koopa IR）到最终汇编的生成过程其实就是再次解析代码并生成另一种代码的过程。但是应当注意到前后两个过程的区别——从`SysY`到`Koopa IR`是前端的工作，主要是解析高级的代码结构并生成更低级的语言，但是并不和具体的底层实现相关；而后端负责IR到具体平台的实现，所以要考虑诸如寄存器分配之类的基础问题。

可喜可贺的是，将文本形式的 IR 转换为内存形式的库是已经提供的，所以在最终代码生成的过程中我们只要考虑根据相应的，而不用去像之前一样分析语法词法。当然如果没有这个库的话，中间形式的 IR 直接生成内存形式会比文本形式方便得多。

一个完整中间形式的代码会被解析成一个`koopa_raw_program_t`，通过对应不同精细度的列表拆分到函数、基本块和具体指令。由于 IR 中没有复杂的指令，所有的指令都是可以线性转换成相应汇编的，所以只要顺序遍历这个结构，对相应的模块作相应的输出即可。

`koopa_raw_program_t`中有一个全局值的部分和函数的部分，遍历时先获得总长度然后拿指针逐个遍历。此处只有函数的列表且只有一个元素。函数中分成数个基本块，基本块分成具体的语句。虽然此处的基本块只有一个，语句类型也只有返回，但是为了之后方便，还是最好构建出整个完整的解析模式：
```C++
  koopa_raw_program_t raw = koopa_build_raw_program(builder, program);

  // 处理 raw program
  for (size_t i = 0; i < raw.values.len; ++i)  // 处理全局变量和常量分配
  {
    if (value->kind.tag == KOOPA_RVT_GLOBAL_ALLOC)  // 类型只能是全局分配
    {

    }
    else cout<<"ERROR"<<endl;
  }
  for (size_t i = 0; i < raw.funcs.len; ++i)  // 使用 for 循环遍历函数列表
  {
    assert(raw.funcs.kind == KOOPA_RSIK_FUNCTION);
    // 获取当前函数
    koopa_raw_function_t func = (koopa_raw_function_t) raw.funcs.buffer[i];

    for (size_t j = 0; j < func->bbs.len; ++j) 
    {
      koopa_raw_basic_block_t bb = (koopa_raw_basic_block_t)func->bbs.buffer[j];
      // 进一步处理当前基本块
      for (size_t k = 0; k < bb->insts.len; ++k)
      {
        koopa_raw_value_t value = (koopa_raw_value_t)bb->insts.buffer[k];
        if (value->kind.tag == KOOPA_RVT_ALLOC){  
        }
        else if (value->kind.tag == KOOPA_RVT_LOAD){
        }
        else if (value->kind.tag == KOOPA_RVT_STORE){
        }
        else if (value->kind.tag == KOOPA_RVT_GET_PTR) {
        }
        else if (value->kind.tag == KOOPA_RVT_GET_ELEM_PTR) {
        }
        else if (value->kind.tag == KOOPA_RVT_BINARY){
        }
        else if (value->kind.tag == KOOPA_RVT_BRANCH){
        }
        else if (value->kind.tag == KOOPA_RVT_JUMP){
        }
        else if (value->kind.tag == KOOPA_RVT_CALL){
        }
        else if (value->kind.tag == KOOPA_RVT_RETURN){
        }
      }
    }
  }
  // 释放 Koopa IR 程序占用的内存
  koopa_delete_program(program);
  // 处理完成, 释放 raw program builder 占用的内存
  // 注意, raw program 中所有的指针指向的内存均为 raw program builder 的内存
  // 所以不要在 raw program builder 处理完毕之前释放 builder
  koopa_delete_raw_program_builder(builder);
```


## Lv3

这一章要实现实现一个能够处理表达式 (一元/二元) 的编译器。

### IR 生成

IR 的工作主要可以分为两部分：`EBNF`对应语法解析规则的修改和输出规则的定义。 在推导规则中不能出现部分结构的或形式，所以遇到`|`时需要将整个结构展开写一次。对于多种推导规则的情况，可以在`AST`中设置一个变量标明是第几种推导得出的结果，以节约事后判断的烦恼。运算的优先级是根据推导顺序定义的，并且推导的结果靠前的部分是与推导的头相同，靠后的部分是下一级运算，这样保证了运算是从左到右进行的。此处的计算规则都很明了，也不存在歧义，所以直接按照语法规范构建即可。在`Dump`函数中，注意运算的规则，应当先算前面部分再算后半部分，也就是先调用前面部分的`Dump`，再调用后半部分的`Dump`。

一元运算在生成中间表示时可以看作与常数进行二元运算。复杂的算术运算经过语法分析已经知道了计算的顺序，调用子一级的运算之后将前后两个结果进行二元运算。这样所有的运算都可以拆成二元运算的复合。然后使所有中间变量变成单赋值的——方法是设定一个全局变量记录使用到的个数，逐个增加编码。注意在每次使用中间变量之后要给全局变量增加1。

为了方便之后的编码，可以把`Dump`函数的返回值设置为`string`，记录保存这部分计算最终结果的临时变量名称，这样在后期加入例如函数多个参数调用的时候方便记录所有的参数。返回一个由被调用函数构建的字符串是很危险的，因为调用过程结束之后对应的结构都被摧毁了。但是以`string`座位返回之时编译器会构造出一个临时对象，保证这种危险的调用其实是没有问题的。

### RISC-V 生成

这里的`value->kind.tag`不一定是`KOOPA_RVT_RETURN`了，可能是一个二元运算，也可能是一个整数。此处所有的计算可以都放在寄存器中，所以此时对寄存器的分配和中间变量的分配规则非常相近。唯一的困难在于并不是每一条二元运算都可以直接对应到`RISC-V`汇编，所以有一些命令需要翻译成多条汇编命令来达到同样的效果。

aaa




## Lv4 & Lv5
这部分内容需要实现变量和常量的定义、赋值和使用，并且应当在适当的位置使用适当的变量/常量。

需要在`EBNF`中添加对应的推导规则。此时遇到了`Bison`不能直接支持的形式——一个部分重复出现若干次。比如这个例子：

> ConstDecl     ::= "const" BType ConstDef {"," ConstDef} ";"

我的解决方案是把重复的部分看作一个对自己的递归调用的推导规则。比如此处相当于有若干个`ConstDef`的组合，所以把这个语句拆分成两句：

> ConstDecl     ::= "const" BType ConstDef ";"
> ConstDef      ::= B | B "," ConstDef

这里`B`表示原先`ConstDef`的推导规则。也就是说，现在的可重复部分比原来多了一些规则，就是在推导出之前形式的后面再加上一个新的自己。

常量数值在编译时会直接替换为定义的数，所以只要保存在编译器执行的过程当中，需要的时候找到对应的数据替换上。变量是程序可以读取和修改的，所以在最终的程序中有对应的空间储存变量的值。所以在声明过程中遇到常量时，应存储到一个对应关系中，遇到变量`x`时，应当使用`@x = alloc i32`申请一个空间并放好初始化的值。调用这些符号时，应当找到对应作用域的符号来使用。

为了明确一个符号的作用域，在使用时找到对应的符号，要建立一个符号表。符号表的层次关系是由一组组`{}`(也就是`Block`)定义的，每个`{}`包括了新的一组符号作用域，其内部的符号优先于外层的符号被使用。如果没有则逐层向外寻找声明过的符号。对此，设计符号表也随着`{}`的出现和结束变动。考虑一个符号表的栈，遇到新的`Block`时，向栈中压入一个符号表，在`Block`中声明的变量和常量就放到栈顶的符号表中。当`Block`结束时，将栈顶的符号表删除，这样所有的局部符号都不存在了，不会影响接下来的程序。使用一个符号时，从栈顶向栈底遍历符号表找到第一个匹配的条目。对符号表的栈操作可以放在`Block`对应`AST`的`Dump`函数中。

为了方便，符号表保存所有声明的变量和常量。对于变量，应该存储其对应的名称和存放位置，但是在此时还拿不到具体放在哪个位置，由具名符号(例如上文中的`@x`)替代，其保存对应的内存位置。所以为了引用到正确的位置，每个具名符号应当是不一样的，考虑到栈的每一层最多只有一个同名的符号，可用栈的高度作为后缀来表示这个具名符号。综上，变量应当存储的就是`ident`和`ident_[depth]`。对于常量，只要记住对应的值并且能对应正确，所以存储的是`ident`和对应的值。为了区分到底是什么类型，可以增加一个`type`到对应`entry`中。所以最终的`entry`可以是这样的：
```c++  
typedef struct
{
  int type;
  int value;
  std::string str;
} Symbol;
```

考虑到之后会有多个函数，可以为每个函数建立符号表，以及全局的符号表，最终的构建如下：
```c++
typedef std::map<std::string, Symbol> Symbolmap;

typedef struct func_symbol
{
  int depth;
  std::vector<Symbolmap> smap;
  std::set<std::string> nameset;
  func_symbol()
  {
    depth = 0;
  }
} funcsymbol;

typedef struct
{
  Symbolmap globalsymbol;     // 全局的符号表
  std::map<std::string, std::unique_ptr<func_symbol>> funcsymbolmap;   // 映射到各个函数的符号表
} Symboltable;
static Symboltable symbt;
```







