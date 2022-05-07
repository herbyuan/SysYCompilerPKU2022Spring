#include <cassert>
#include <cstdio>
#include <iostream>
#include <memory>
#include <cstring>
#include <map>
#include <set>
#include <stack>
#include <vector>
#include <algorithm>
#include <unistd.h>
#include "assert.h"  
#include "AST.h"

using namespace std;

// 声明 lexer 的输入, 以及 parser 函数
// 为什么不引用 sysy.tab.hpp 呢? 因为首先里面没有 yyin 的定义
// 其次, 因为这个文件不是我们自己写的, 而是被 Bison 生成出来的
// 你的代码编辑器/IDE 很可能找不到这个文件, 然后会给你报错 (虽然编译不会出错)
// 看起来会很烦人, 于是干脆采用这种看起来 dirty 但实际很有效的手段
extern FILE *yyin;
extern int yyparse(unique_ptr<BaseAST> &ast);
extern void parse_string(const char* str);

int main(int argc, const char *argv[]) {
  // 解析命令行参数. 测试脚本/评测平台要求你的编译器能接收如下参数:
  // compiler 模式 输入文件 -o 输出文件
  assert(argc == 5);
  assert(argc == 5);
  auto mode = argv[1];
  auto input = argv[2];
  auto output = argv[4];

  // 打开输入文件, 并且指定 lexer 在解析的时候读取这个文件
  yyin = fopen(input, "r");
  assert(yyin);
  // 调用 parser 函数, parser 函数会进一步调用 lexer 解析输入文件的
  // parse input file
  unique_ptr<BaseAST> ast;
  auto ret = yyparse(ast);
  assert(!ret);

  int old = dup(1);

  if (strcmp(mode, "-koopa") == 0)
  {
    // Dump Koopa IR
    freopen(output, "w", stdout);
    // cout<<"    fun @main(): i32 {"<<endl;
    // cout << "%entry_0:" << endl;
    // cout<< "  %1 = add 0, 0" << endl;
    // cout<< "  ret %1"<<endl;
    // cout<< "}" <<endl;
    ast->Dump();
    dup2(old, 1);
  }
  else
  {
    // Dump Koopa IR
    FILE *fp = freopen((string(output) + ".koopa").c_str(), "w", stdout);
    ast->Dump();
    fflush(fp);
    dup2(old, 1);
    // Koopa IR -> RISC-V
    FILE* koopaio = fopen((string(output) + ".koopa").c_str(), "r");
    char *str=(char *)malloc(1 << 30);
    memset(str, 0, 1 << 30);
    int len = fread(str, 1, 1 << 30, koopaio);
    str[len] = 0;
    // cout<<str<<endl;
    // parse_string(str);
    freopen(output, "w", stdout);
    parse_string(str);
    dup2(old, 1);
  }

  return 0;
}

// build/compiler -riscv hello.c -o hello.koopa
// build/compiler -koopa hello.c -o hello.koopa
