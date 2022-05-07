%code requires {
  #include <memory>
  #include <cstring>
  #include <iostream>
  #include <map>
  #include <set>
  #include <stack>
  #include <vector>
  #include <algorithm>
  #include "assert.h"  
  #include "koopa.h"
  #include "AST.h"
}

%{
#include <iostream>
#include <memory>
#include <cstring>
#include <map>
#include <set>
#include <stack>
#include <vector>
#include <algorithm>
#include "assert.h"
#include "koopa.h"
#include "AST.h"

// 声明 lexer 函数和错误处理函数
int yylex();
void yyerror(std::unique_ptr<BaseAST> &ast, const char *s);
void parse_string(const char* str);
void global_alloc(koopa_raw_value_t value);
int calc_alloc_size(koopa_raw_type_t value);

using namespace std;

%}

// 定义 parser 函数和错误处理函数的附加参数
// 我们需要返回一个字符串作为 AST, 所以我们把附加参数定义成字符串的智能指针
// 解析完成后, 我们要手动修改这个参数, 把它设置成解析得到的字符串
%parse-param { std::unique_ptr<BaseAST> &ast }

// yylval 的定义, 我们把它定义成了一个联合体 (union)
// 因为 token 的值有的是字符串指针, 有的是整数
// 之前我们在 lexer 中用到的 str_val 和 int_val 就是在这里被定义的
// 至于为什么要用字符串指针而不直接用 string 或者 unique_ptr<string>?
// 请自行 STFW 在 union 里写一个带析构函数的类会出现什么情况
%union {
  std::string *str_val;
  int int_val;
  BaseAST *ast_val;
}

// lexer 返回的所有 token 种类的声明
// 注意 IDENT 和 INT_CONST 会返回 token 的值, 分别对应 str_val 和 int_val
%token INT RETURN CONST VOID LE GE EQ NE AND OR IF THEN ELSE WHILE CONTINUE BREAK 
%token <str_val> IDENT
%token <int_val> INT_CONST

// 非终结符的类型定义
%type <ast_val> CompUnits FunorVar FuncDef FuncRParams FuncFParams FuncFParam FuncType Block ArrayDef ArrayExp BlockItem MS UMS LVal Decl VarDecl VarDef InitVal ConstDecl ConstDef ConstInitVal ConstArrayInitVal ConstExp BType Stmt Exp ArrayInitVal LOrExp LAndExp EqExp RelExp UnaryExp PrimaryExp AddExp MulExp Number 
%type <str_val> UnaryOp

%%

// 开始符, CompUnit ::= FuncDef, 大括号后声明了解析完成后 parser 要做的事情
// 之前我们定义了 FuncDef 会返回一个 str_val, 也就是字符串指针
// 而 parser 一旦解析完 CompUnit, 就说明所有的 token 都被解析了, 即解析结束了
// 此时我们应该把 FuncDef 返回的结果收集起来, 作为 AST 传给调用 parser 的函数
// $1 指代规则里第一个符号的返回值, 也就是 FuncDef 的返回值
// 你可能会问, FuncType, IDENT 之类的结果已经是字符串指针了
// 为什么还要用 unique_ptr 接住它们, 然后再解引用, 把它们拼成另一个字符串指针呢
// 因为所有的字符串指针都是我们 new 出来的, new 出来的内存一定要 delete
// 否则会发生内存泄漏, 而unique_ptr 这种智能指针可以自动帮我们 delete
// 虽然此处你看不出用 unique_ptr 和手动 delete 的区别, 但当我们定义了 AST 之后
// 这种写法会省下很多内存管理的负担

/* 最顶层的解析 */
CompUnit
: CompUnits {
  auto comp_unit = make_unique<CompUnitAST>();
  comp_unit->compunits = unique_ptr<BaseAST>($1);
  ast = move(comp_unit);
}
;

CompUnits 
: FunorVar {
  auto ast = new CompUnitsAST();
  ast->compunits = NULL;
  ast->decl = NULL;
  ast->func_def = unique_ptr<BaseAST>($1);
  $$ = ast;
}
| ConstDecl {
  auto ast = new CompUnitsAST();
  ast->compunits = NULL;
  ast->decl = unique_ptr<BaseAST>($1);
  ast->func_def = NULL;
  $$ = ast;
}
| CompUnits FunorVar {
  auto ast = new CompUnitsAST();
  ast->compunits = unique_ptr<BaseAST>($1);
  ast->decl = NULL;
  ast->func_def = unique_ptr<BaseAST>($2);
  $$ = ast;
}
| CompUnits ConstDecl {
  auto ast = new CompUnitsAST();
  ast->compunits = unique_ptr<BaseAST>($1);
  ast->decl = unique_ptr<BaseAST>($2);
  ast->func_def = NULL;
  $$ = ast;
}
;

FunorVar
  : FuncType FuncDef {
    auto ast = new FunorVarAST();
    ast->func_type = unique_ptr<BaseAST>($1);
    ast->funcdef = unique_ptr<BaseAST>($2);
    ast->vardef = NULL;
    $$ = ast;
  }
  | FuncType VarDef ';' {
    auto ast = new FunorVarAST();
    ast->func_type = unique_ptr<BaseAST>($1);
    ast->vardef = unique_ptr<BaseAST>($2);
    ast->funcdef = NULL;
    $$ = ast;
  }
  ;

/* 两种Type*/
FuncType
: INT {
  auto ast = new FuncTypeAST();
  ast->type = *new string("int");
  $$ = ast;
}
| VOID {
  auto ast = new FuncTypeAST();
  ast->type = *new string("void");
  $$ = ast;
}
;

BType
: INT {
  auto ast = new BTypeAST();
    ast->type = *new string("int");
    $$ = ast;
}
;

/* 函数名 */
FuncDef
: IDENT '(' ')' Block {
  auto ast = new FuncDefAST();
  ast->ident = *unique_ptr<string>($1);
  ast->funcp = NULL;
  ast->block = unique_ptr<BaseAST>($4);
  $$ = ast;
}
| IDENT '(' FuncFParams ')' Block {
  auto ast = new FuncDefAST();
  ast->ident = *unique_ptr<string>($1);
  ast->funcp = unique_ptr<BaseAST>($3);
  ast->block = unique_ptr<BaseAST>($5);
  $$ = ast;
}
;

FuncFParams
: FuncFParam {
  auto ast = new FuncFParamsAST();
  ast->para = unique_ptr<BaseAST>($1);
  ast->paras = NULL;
  $$ = ast;
}
| FuncFParam ',' FuncFParams {
  auto ast = new FuncFParamsAST();
  ast->para = unique_ptr<BaseAST>($1);
  ast->paras = unique_ptr<BaseAST>($3);
  $$ = ast;
}
;

FuncFParam
: BType IDENT {
  auto ast = new FuncFParamAST();
  ast->isarray = 0;
  ast->ident = *unique_ptr<string>($2);
  $$ = ast;
  }
| BType IDENT '[' ']' {
  auto ast = new FuncFParamAST();
  ast->isarray = 1;
  ast->ident = *unique_ptr<string>($2);
  ast->arraydef = NULL;
  $$ = ast;
}
| BType IDENT '[' ']' ArrayDef {
  auto ast = new FuncFParamAST();
  ast->isarray = 1;
  ast->ident = *unique_ptr<string>($2);
  ast->arraydef = unique_ptr<BaseAST>($5);
  $$ = ast;
}
;

/* 基本块 */
Block
: '{' BlockItem '}' {
  auto ast = new BlockAST();
  ast->blockitem = unique_ptr<BaseAST>($2);
  $$ = ast;
}
;

BlockItem
: {
  auto ast = new BlockItemAST();
  ast->stmt = NULL;
  ast->decl = NULL;
  ast->blockitem = NULL;
  $$ = ast;
}
| Stmt BlockItem {
  auto ast = new BlockItemAST();
  ast->stmt = unique_ptr<BaseAST>($1);
  ast->decl = NULL;
  ast->blockitem = unique_ptr<BaseAST>($2);
  $$ = ast;
}
| Decl BlockItem{
  auto ast = new BlockItemAST();
  ast->decl = unique_ptr<BaseAST>($1);
  ast->stmt = NULL;
  ast->blockitem = unique_ptr<BaseAST>($2);
  $$ = ast;
}
;

/* 声明部分 */
Decl
: ConstDecl {
  auto ast = new DeclAST();
  ast->constdecl = unique_ptr<BaseAST>($1);
  ast->vardecl = NULL;
  $$ = ast;
}
| VarDecl {
  auto ast = new DeclAST();
  ast->vardecl = unique_ptr<BaseAST>($1);
  ast->constdecl = NULL;
  $$ = ast;
}
;

ConstDecl
: CONST BType ConstDef ';' {
  auto ast = new ConstDeclAST();
  ast->const_ = *new string("const");
  ast->btype = unique_ptr<BaseAST>($2);
  ast->constdef = unique_ptr<BaseAST>($3);
  $$ = ast;
}
;

ConstDef
  : IDENT '=' ConstInitVal {
    auto ast = new ConstDefAST();
    ast->ident = *unique_ptr<string>($1);
    ast->constinitval = unique_ptr<BaseAST>($3);
    ast->constdef = NULL;
    $$ = ast;
  }
  | IDENT ArrayDef '=' ConstInitVal {
    auto ast = new ConstDefAST();
    ast->ident = *unique_ptr<string>($1);
    ast->arraydef = unique_ptr<BaseAST>($2);
    ast->constinitval = unique_ptr<BaseAST>($4);
    ast->constdef = NULL;
    $$ = ast;
  }
  | IDENT '=' ConstInitVal ',' ConstDef {
    auto ast = new ConstDefAST();
    ast->ident = *unique_ptr<string>($1);
    ast->constinitval = unique_ptr<BaseAST>($3);
    ast->constdef = unique_ptr<BaseAST>($5);
    $$ = ast;
  }
  | IDENT ArrayDef '=' ConstInitVal ',' ConstDef {
    auto ast = new ConstDefAST();
    ast->ident = *unique_ptr<string>($1);
    ast->arraydef = unique_ptr<BaseAST>($2);
    ast->constinitval = unique_ptr<BaseAST>($4);
    ast->constdef = unique_ptr<BaseAST>($6);
    $$ = ast;
  }
  ;

ArrayDef
: '[' ConstExp ']'{
  auto ast = new ArrayDefAST();
  ast->constexp = unique_ptr<BaseAST>($2);
  $$ = ast;
}
| '[' ConstExp ']' ArrayDef {
  auto ast = new ArrayDefAST();
  ast->constexp = unique_ptr<BaseAST>($2);
  ast->arraydef = unique_ptr<BaseAST>($4);
  $$ = ast;
}

ConstInitVal
: ConstExp {
  auto ast = new ConstInitValAST();
  ast->constexp = unique_ptr<BaseAST>($1);
  $$ = ast;
}
| '{' '}' {
  auto ast = new ConstInitValAST();
  ast->constexp = NULL;
  $$ = ast;
}
| '{' ConstArrayInitVal '}' {  // ConstArrayInitVal 表示 ConstInitVal {"," ConstInitVal}
  auto ast = new ConstInitValAST();
  ast->constexp = NULL;
  ast->constarrayinitval = unique_ptr<BaseAST>($2);
  $$ = ast;
}
;

ConstArrayInitVal
: ConstInitVal {
  auto ast = new ConstArrayInitValAST();
  ast->constinitval = unique_ptr<BaseAST>($1);
  ast->constayyayinitval = NULL;
  $$ = ast;
}
| ConstInitVal ',' ConstArrayInitVal {
  auto ast = new ConstArrayInitValAST();
  ast->constinitval = unique_ptr<BaseAST>($1);
  ast->constayyayinitval = unique_ptr<BaseAST>($3);
  $$ = ast;
}
;

ConstExp
: Exp {
  auto ast = new ConstExpAST();
  ast->exp = unique_ptr<BaseAST>($1);
  $$ = ast;
}
;

VarDecl
: BType VarDef ';' {
  auto ast = new VarDeclAST();
  ast->btype = unique_ptr<BaseAST>($1);
  ast->vardef = unique_ptr<BaseAST>($2);
  $$ = ast;
}
;

VarDef
: IDENT {
  auto ast = new VarDefAST();
  ast->ident = *unique_ptr<string>($1);
  ast->vardef = NULL;
  $$ = ast;
}
| IDENT ArrayDef {
  auto ast = new VarDefAST();
  ast->ident = *unique_ptr<string>($1);
  ast->arraydef = unique_ptr<BaseAST>($2);
  ast->vardef = NULL;
  $$ = ast;
}
| IDENT '=' InitVal {
  auto ast = new VarDefAST();
  ast->ident = *unique_ptr<string>($1);
  ast->initval = unique_ptr<BaseAST>($3);
  ast->vardef = NULL;
  $$ = ast;
}
| IDENT ArrayDef '=' InitVal{
  auto ast = new VarDefAST();
  ast->ident = *unique_ptr<string>($1);
  ast->arraydef = unique_ptr<BaseAST>($2);
  ast->initval = unique_ptr<BaseAST>($4);
  ast->vardef = NULL;
  $$ = ast;
}
| IDENT ',' VarDef {
  auto ast = new VarDefAST();
  ast->ident = *unique_ptr<string>($1);
  ast->vardef = unique_ptr<BaseAST>($3);
  $$ = ast;
}
| IDENT ArrayDef ',' VarDef {
  auto ast = new VarDefAST();
  ast->ident = *unique_ptr<string>($1);
  ast->arraydef = unique_ptr<BaseAST>($2);
  ast->vardef = unique_ptr<BaseAST>($4);
  $$ = ast;
}
| IDENT '=' InitVal ',' VarDef {
  auto ast = new VarDefAST();
  ast->ident = *unique_ptr<string>($1);
  ast->initval = unique_ptr<BaseAST>($3);
  ast->vardef = unique_ptr<BaseAST>($5);
  $$ = ast;
}
| IDENT ArrayDef '=' InitVal ',' VarDef {
  auto ast = new VarDefAST();
  ast->ident = *unique_ptr<string>($1);
  ast->arraydef = unique_ptr<BaseAST>($2);
  ast->initval = unique_ptr<BaseAST>($4);
  ast->vardef = unique_ptr<BaseAST>($6);
  $$ = ast;
}
;

InitVal
: Exp {
  auto ast = new InitValAST();
  ast->exp = unique_ptr<BaseAST>($1);
  $$ = ast;
}
| '{' '}' {
  auto ast = new InitValAST();
  ast->zeroinit = 1;
  ast->exp = NULL;
  ast->arrayinitval = NULL;
  $$ = ast;
}
| '{' ArrayInitVal '}' {   // ArrayInitVal 表示 InitVal {"," InitVal}
  auto ast = new InitValAST();
  ast->exp = NULL;
  ast->arrayinitval = unique_ptr<BaseAST>($2);
  $$ = ast;
}
;

ArrayInitVal
: InitVal {
  auto ast = new ArrayInitValAST();
  ast->initval = unique_ptr<BaseAST>($1);
  ast->arrayinitval = NULL;
  $$ = ast;
}
| InitVal ',' ArrayInitVal {
  auto ast = new ArrayInitValAST();
  ast->initval = unique_ptr<BaseAST>($1);
  ast->arrayinitval = unique_ptr<BaseAST>($3);
  $$ = ast;
}
;

/* Statement */
// 改写文法的根据是将S分为 完全匹配 (MS) 和 不完全匹配 (UMS) 两类，并且在 UMS 中规定 else 右结合 
Stmt
: MS {
  auto ast = new StmtAST();
  ast->ms = unique_ptr<BaseAST>($1);
  $$ = ast; 
}
| UMS {
  auto ast = new StmtAST();
  ast->ums = unique_ptr<BaseAST>($1);
  $$ = ast; 
}
;

MS
: ';' {
  auto ast = new MSAST();
  ast->type = 0;
  $$ = ast;
}
| Exp ';' {
  auto ast = new MSAST();
  ast->type = 1;
  ast->exp = unique_ptr<BaseAST>($1);
  $$ = ast;
}
| RETURN ';' {
  auto ast = new MSAST();
  ast->type = 2;
  $$ = ast;
} 
| RETURN Exp ';' {
  auto ast = new MSAST();
  ast->type = 3;
  ast->exp = unique_ptr<BaseAST>($2);
  $$ = ast;
}
| LVal '=' Exp ';' {
  auto ast = new MSAST();
  ast->type = 4;
  ast->ms = unique_ptr<BaseAST>($1);
  ast->exp = unique_ptr<BaseAST>($3);
  $$ = ast; 
}
| Block {
  auto ast = new MSAST();
  ast->type = 5;
  ast->ms = unique_ptr<BaseAST>($1);
  $$ = ast; 
}
| IF '(' Exp ')' MS ELSE MS {
  auto ast = new MSAST();
  ast->type = 6;
  ast->exp = unique_ptr<BaseAST>($3);
  ast->ms = unique_ptr<BaseAST>($5);
  ast->ms2 = unique_ptr<BaseAST>($7);
  $$ = ast; 
}
| WHILE '(' Exp ')' MS {
  auto ast = new MSAST();
  ast->type = 7;
  ast->exp = unique_ptr<BaseAST>($3);
  ast->ms = unique_ptr<BaseAST>($5);
  $$ = ast; 
}
| BREAK ';' {
  auto ast = new MSAST();
  ast->type = 8;
  $$ = ast; 
}
| CONTINUE ';' {
  auto ast = new MSAST();
  ast->type = 9;
  $$ = ast; 
}
;

UMS
: WHILE '(' Exp ')' UMS {
  auto ast = new UMSAST();
  ast->exp = unique_ptr<BaseAST>($3);
  ast->ums = unique_ptr<BaseAST>($5);
  ast->ms = NULL;
  $$ = ast; 
}
| IF '(' Exp ')' Stmt {
  auto ast = new UMSAST();
  ast->exp = unique_ptr<BaseAST>($3);
  ast->ms = unique_ptr<BaseAST>($5);
  ast->ums = NULL;
  $$ = ast; 
}
| IF '(' Exp ')' MS ELSE UMS {
  auto ast = new UMSAST();
  ast->exp = unique_ptr<BaseAST>($3);
  ast->ms = unique_ptr<BaseAST>($5);
  ast->ums = unique_ptr<BaseAST>($7);
  $$ = ast; 
}
;

/* 表达式 */
Exp
: LOrExp {
  auto ast = new ExpAST();
  ast->lorexp = unique_ptr<BaseAST>($1);
  $$ = ast;
}
;

LOrExp
: LAndExp {
  auto ast = new LOrExpAST();
  ast->landexp = unique_ptr<BaseAST>($1);
  $$ = ast;
}
| LOrExp OR LAndExp {
  auto ast = new LOrExpAST();
  ast->lorexp = unique_ptr<BaseAST>($1);
  ast->landexp = unique_ptr<BaseAST>($3);
  $$ = ast;
}
;

LAndExp
: EqExp {
  auto ast = new LAndExpAST();
  ast->eqexp = unique_ptr<BaseAST>($1);
  $$ = ast;
}
| LAndExp AND EqExp {
  auto ast = new LAndExpAST();
  ast->landexp = unique_ptr<BaseAST>($1);
  ast->eqexp = unique_ptr<BaseAST>($3);
  $$ = ast;
}
;

EqExp
:RelExp {
  auto ast = new EqExpAST();
  ast->relexp = unique_ptr<BaseAST>($1);
  $$ = ast;
}
| EqExp EQ RelExp{
  auto ast = new EqExpAST();
  ast->eqexp = unique_ptr<BaseAST>($1);
  ast->op = *new string("==");
  ast->relexp = unique_ptr<BaseAST>($3);
  $$ = ast;
}
| EqExp NE RelExp{
  auto ast = new EqExpAST();
  ast->eqexp = unique_ptr<BaseAST>($1);
  ast->op = *new string("!=");
  ast->relexp = unique_ptr<BaseAST>($3);
  $$ = ast;
}
;

RelExp
: AddExp {
  auto ast = new RelExpAST();
  ast->addexp = unique_ptr<BaseAST>($1);
  $$ = ast;
}
| RelExp LE AddExp {
  auto ast = new RelExpAST();
  ast->relexp = unique_ptr<BaseAST>($1);
  ast->op = *new string("<=");
  ast->addexp = unique_ptr<BaseAST>($3);
  $$ = ast;
}
| RelExp GE AddExp {
  auto ast = new RelExpAST();
  ast->relexp = unique_ptr<BaseAST>($1);
  ast->op = *new string(">=");
  ast->addexp = unique_ptr<BaseAST>($3);
  $$ = ast;
}
| RelExp '<' AddExp {
  auto ast = new RelExpAST();
  ast->relexp = unique_ptr<BaseAST>($1);    
  ast->op = *new string("<");
  ast->addexp = unique_ptr<BaseAST>($3);
  $$ = ast;
}
| RelExp '>' AddExp {
  auto ast = new RelExpAST();
  ast->relexp = unique_ptr<BaseAST>($1);
  ast->op = *new string(">");
  ast->addexp = unique_ptr<BaseAST>($3);
  $$ = ast;
}
;

AddExp
: MulExp {
  auto ast = new AddAST();
  ast->op = *new string("");
  ast->mulexp = unique_ptr<BaseAST>($1);
  $$ = ast;
}
| AddExp '+' MulExp {
  auto ast = new AddAST();
  ast->addexp = unique_ptr<BaseAST>($1);
  ast->op = *new string("+");
  ast->mulexp = unique_ptr<BaseAST>($3);
  $$ = ast;
}
| AddExp '-' MulExp {
  auto ast = new AddAST();
  ast->addexp = unique_ptr<BaseAST>($1);
  ast->op = *new string("-");;
  ast->mulexp = unique_ptr<BaseAST>($3);
  $$ = ast;
}
;

MulExp
: UnaryExp {
  auto ast = new MulAST();
  ast->op = *new string("");;
  ast->unaryexp = unique_ptr<BaseAST>($1);
  $$ = ast;
}
| MulExp '*' UnaryExp {
  auto ast = new MulAST();
  ast->mulexp = unique_ptr<BaseAST>($1);
  ast->op = *new string("*");;
  ast->unaryexp = unique_ptr<BaseAST>($3);
  $$ = ast;
}
| MulExp '/' UnaryExp {
  auto ast = new MulAST();
  ast->mulexp = unique_ptr<BaseAST>($1);
  ast->op = *new string("/");;
  ast->unaryexp = unique_ptr<BaseAST>($3);
  $$ = ast;
  }
| MulExp '%' UnaryExp {
  auto ast = new MulAST();
  ast->mulexp = unique_ptr<BaseAST>($1);
  ast->op = *new string("%");;
  ast->unaryexp = unique_ptr<BaseAST>($3);
  $$ = ast;
}
;

UnaryExp
: PrimaryExp {
  auto ast = new UnaryExpAST();
  ast->type = 0;
  ast->op_ident = *new string("+");
  ast->unaryexp_paras = unique_ptr<BaseAST>($1);
  $$ = ast;
}
| UnaryOp UnaryExp {
  auto ast = new UnaryExpAST();
  ast->type = 1;
  ast->op_ident = *unique_ptr<string>($1);
  ast->unaryexp_paras = unique_ptr<BaseAST>($2);
  $$ = ast;
}
| IDENT '(' ')' {
  auto ast = new UnaryExpAST();
  ast->type = 2;
  ast->op_ident =  *unique_ptr<string>($1);
  ast->unaryexp_paras = NULL;
  $$ = ast;
}
| IDENT '(' FuncRParams ')' {
  auto ast = new UnaryExpAST();
  ast->type = 3;
  ast->op_ident =  *unique_ptr<string>($1);
  ast->unaryexp_paras = unique_ptr<BaseAST>($3);
  $$ = ast;
}
;

FuncRParams
: Exp {
  auto ast = new FuncRParamsAST();
  ast->exp =  unique_ptr<BaseAST>($1);
  ast->paras = NULL;
  $$ = ast;
}
| Exp ',' FuncRParams{
  auto ast = new FuncRParamsAST();
  ast->exp =  unique_ptr<BaseAST>($1);
  ast->paras = unique_ptr<BaseAST>($3);
  $$ = ast;
}
;

UnaryOp
: '+' {
  $$ = new string("+");
}
| '-' {
  $$ = new string("-");
}
| '!' {
  $$ = new string("!");
}
;
  
PrimaryExp
: '(' Exp ')' {
  auto ast = new PrimaryExpAST();
  ast->exp = unique_ptr<BaseAST>($2);
  ast->lval = NULL;
  ast->num = NULL;
  $$ = ast;
}
| Number{
  auto ast = new PrimaryExpAST();
  ast->num = unique_ptr<BaseAST>($1);
  ast->lval = NULL;
  ast->exp = NULL;
  $$ = ast;
}
| LVal {
  auto ast = new PrimaryExpAST();
  ast->exp = NULL;
  ast->num = NULL;
  ast->lval = unique_ptr<BaseAST>($1);
  $$ = ast;
}
;

LVal
: IDENT {
  auto ast = new LValAST();
  ast->ident = *unique_ptr<string>($1);
  ast->arrayexp = NULL;
  $$ = ast; 
}
| IDENT ArrayExp {    // ArrayExp 表示 一次或更多的"[" Exp "]"
  auto ast = new LValAST();
  ast->ident = *unique_ptr<string>($1);
  ast->arrayexp = unique_ptr<BaseAST>($2);
  $$ = ast; 
}
;

ArrayExp
: '[' Exp ']' {
  auto ast = new ArrayExpAST();
  ast->exp = unique_ptr<BaseAST>($2);
  ast->arrayexp = NULL;
  $$ = ast; 
}
| '[' Exp ']' ArrayExp {
  auto ast = new ArrayExpAST();
  ast->exp = unique_ptr<BaseAST>($2);
  ast->arrayexp = unique_ptr<BaseAST>($4);
  $$ = ast; 
}
;

Number
: INT_CONST {
  auto ast = new NumberAST();
  ast->number = $1;
  $$ = ast;
}
;


%%

// 定义错误处理函数, 其中第二个参数是错误信息
// parser 如果发生错误 (例如输入的程序出现了语法错误), 就会调用这个函数
void yyerror(std::unique_ptr<BaseAST> &ast, const char *s) {
  // From https://www.cnblogs.com/zhangleo/p/15963442.html
    extern int yylineno;    // defined and maintained in lex
    extern char *yytext;    // defined and maintained in lex
    int len = strlen(yytext);
    int i;
    char buf[512] = {0};
    for (i=0;i<len;++i)
    {
        sprintf(buf, "%s%c ", buf, yytext[i]);
    }
    fprintf(stderr, "%s\n", yytext);
    fprintf(stderr, "ERROR: %s at symbol '%s' on line %d\n", s, buf, yylineno);
}

void global_alloc(koopa_raw_value_t value)
{
  for (int i = 0; i < value->kind.data.aggregate.elems.len; ++i)
  {
    koopa_raw_value_t t = (koopa_raw_value_t)value->kind.data.aggregate.elems.buffer[i];
    if (t->kind.tag == KOOPA_RVT_INTEGER)
    {
      cout << "  .word " << t->kind.data.integer.value << endl;
    }
    else
    {
      global_alloc(t);
    }
  }
}

int calc_alloc_size(koopa_raw_type_t value)
{
  if (value->tag == 0)
    return 4;
  else
    return value->data.array.len * calc_alloc_size(value->data.array.base);
}

void parse_string(const char* str)
{
  map<koopa_raw_value_t, int> map;
  //解析字符串 str, 得到 Koopa IR 程序
  koopa_program_t program;
  koopa_error_code_t ret = koopa_parse_from_string(str, &program);
  assert(ret == KOOPA_EC_SUCCESS);  // 确保解析时没有出错
  // 创建一个 raw program builder, 用来构建 raw program
  koopa_raw_program_builder_t builder = koopa_new_raw_program_builder();
  // 将 Koopa IR 程序转换为 raw program
  koopa_raw_program_t raw = koopa_build_raw_program(builder, program);
  // 释放 Koopa IR 程序占用的内存
  koopa_delete_program(program);
  int local_label = 1;


  // 处理 raw program
  for (size_t i = 0; i < raw.values.len; ++i)
  {
    koopa_raw_value_t value = (koopa_raw_value_t) raw.values.buffer[i];
    cout << "  .data" << endl;
    cout << "  .globl " << value->name+1 << endl;
    cout<<value->name+1<<":"<<endl;
    
    if (value->kind.tag == KOOPA_RVT_GLOBAL_ALLOC)
    {
      //cout << value->kind.data.global_alloc.init->kind.tag<<endl;
      if (value->kind.data.global_alloc.init->kind.tag == KOOPA_RVT_AGGREGATE)
      {
        global_alloc(value->kind.data.global_alloc.init);
      }
      if (value->kind.data.global_alloc.init->kind.tag == KOOPA_RVT_ZERO_INIT)
      {
        
        cout << "  .zero " << calc_alloc_size(value->kind.data.global_alloc.init->ty)<< endl;
      }
      if (value->kind.data.global_alloc.init->kind.tag == KOOPA_RVT_INTEGER)
      {
        cout<<"  .word "<<value->kind.data.global_alloc.init->kind.data.integer.value<<endl;
      }
    }
    else
    {
      cout<<"ERROR"<<endl;
    }
    cout<<endl;
  }

  // 使用 for 循环遍历函数列表
  for (size_t i = 0; i < raw.funcs.len; ++i) {
    // 正常情况下, 列表中的元素就是函数, 我们只不过是在确认这个事实
    // 当然, 你也可以基于 raw slice 的 kind, 实现一个通用的处理函数
    assert(raw.funcs.kind == KOOPA_RSIK_FUNCTION);
    // 获取当前函数
    koopa_raw_function_t func = (koopa_raw_function_t) raw.funcs.buffer[i];
    // 进一步处理当前函数

    if (func->bbs.len == 0)
      continue;
    cout << endl << "  .text"<< endl;
    cout << "  .globl " << func->name+1 << endl; // name的第一个字符是@符号
    cout << func->name+1 << ":" << endl;

    int size = 0;  // stack size
    for (size_t j = 0; j < func->bbs.len; ++j) {
      koopa_raw_basic_block_t bb = (koopa_raw_basic_block_t)func->bbs.buffer[j];
      // 进一步处理当前基本块
      for (size_t k = 0; k < bb->insts.len; ++k){
        koopa_raw_value_t value = (koopa_raw_value_t)bb->insts.buffer[k];

        if (value->kind.tag == KOOPA_RVT_ALLOC){
          if (value->ty->tag == KOOPA_RTT_POINTER)
          {
            if (value->ty->data.pointer.base->tag == KOOPA_RTT_INT32)
            {
              size += 4;
            }
            else if (value->ty->data.pointer.base->tag == KOOPA_RTT_ARRAY)
            {
              int sz = calc_alloc_size(value->ty->data.pointer.base);
              size += sz;
            }
            else if (value->ty->data.pointer.base->tag == KOOPA_RTT_POINTER)
            {
              size += 4;
            }
          }    
        }
        else if (value->kind.tag == KOOPA_RVT_LOAD){
            size += 4;
        }
        else if (value->kind.tag == KOOPA_RVT_STORE){
        }
        else if (value->kind.tag == KOOPA_RVT_GET_PTR) {
          size += 4;
        }
        else if (value->kind.tag == KOOPA_RVT_GET_ELEM_PTR) {
          size += 4;
        }
        else if (value->kind.tag == KOOPA_RVT_BINARY){
          size += 4;
        }
        else if (value->kind.tag == KOOPA_RVT_BRANCH){
        }
        else if (value->kind.tag == KOOPA_RVT_JUMP){
        }
        else if (value->kind.tag == KOOPA_RVT_CALL){
          size += 4;
        }
        else if (value->kind.tag == KOOPA_RVT_RETURN){
        }
      }
    }

    size = (size + 31) >> 4 << 4;
    if (size >= -2048 && size <=2047)
    {
      cout << "  addi  sp, sp, -" << size <<endl;
      cout << "  sw    ra, " << size - 4 << "(sp)" << endl;
      cout << "  sw    s0, " << size - 8 << "(sp)" << endl;
    }
    else
    {
      cout << "  li    t0, " << size << endl;
      cout << "  sub   sp, sp, t0" << endl;
      cout << "  add   t1, sp, t0" << endl;
      cout << "  sw    ra, " << -4 << "(t1)" << endl;
      cout << "  sw    s0, " << -8 << "(t1)" << endl;
    }
    
    int allc = 0;

    for (size_t j = 0; j < func->bbs.len; ++j) {
      //cout<<"j = "<<j<<endl;
      assert(func->bbs.kind == KOOPA_RSIK_BASIC_BLOCK);
      koopa_raw_basic_block_t bb = (koopa_raw_basic_block_t)func->bbs.buffer[j];
      // 进一步处理当前基本块
      // ...
      cout << bb->name+1 << ":" << endl;
      for (size_t k = 0; k < bb->insts.len; ++k){
        //cout<<" k = "<<k<<endl;
        //cout<<"len = "<<bb->insts.len<<endl;
        int current = 0;
        koopa_raw_value_t value = (koopa_raw_value_t)bb->insts.buffer[k];
        
        //cout<<(value->kind.tag)<<endl;

        if (value->kind.tag == KOOPA_RVT_ALLOC){
          // cout<<"tag = "<<value->ty->tag<<endl;
          if (value->ty->tag == KOOPA_RTT_POINTER)
          {
            if (value->ty->data.pointer.base->tag == KOOPA_RTT_INT32)
            {
              map[value] = allc;
              allc = allc + 4;
            }
            else if (value->ty->data.pointer.base->tag == KOOPA_RTT_ARRAY)
            {
              int sz = calc_alloc_size(value->ty->data.pointer.base);
              map[value] = allc;
              allc += sz;
            }
            else if (value->ty->data.pointer.base->tag == KOOPA_RTT_POINTER)
            {
              map[value] = allc;
              allc = allc + 4;
            }
          }     
          // cout<<"AFTER ALLC: " << allc<<endl;
        }
        else if (value->kind.tag == KOOPA_RVT_LOAD){
          if (value->kind.data.load.src->kind.tag == KOOPA_RVT_GLOBAL_ALLOC){
            cout << "  la    t0, " << value->kind.data.load.src->name+1 << endl;
            cout << "  lw    t0, 0(t0)" << endl;
            if (allc >= -2048 && allc <=2047)
            {
              cout << "  sw    t0, " << allc << "(sp)" << endl;
            }
            else
            {
              cout << "  li    t1, " << allc << endl;
              cout << "  add   t1, t1, sp" << endl;
              cout << "  sw    t0, 0(t1)" << endl;
            }
            
            map[value] = allc;
            allc = allc + 4;
          }
          else if (value->kind.data.load.src->kind.tag == KOOPA_RVT_ALLOC)
          {
            if (map[value->kind.data.load.src] >= -2048 && map[value->kind.data.load.src] <=2047)
            {
              cout << "  lw    t0, " << map[value->kind.data.load.src] << "(sp)" << endl;
            }
            else
            {
              cout << "  li    t1, " << map[value->kind.data.load.src] << endl;
              cout << "  add   t1, t1, sp" << endl;
              cout << "  lw    t0, 0(t1)" << endl;
            }
            
            if (allc >= -2048 && allc <=2047)
            {
              cout << "  sw    t0, " << allc << "(sp)" << endl;
            }
            else
            {
              cout << "  li    t1, " << allc << endl;
              cout << "  add   t1, t1, sp" << endl;
              cout << "  sw    t0, 0(t1)" << endl;
            }
            map[value] = allc;
            allc = allc + 4;
          }
          else{
            if (map[value->kind.data.load.src] >= -2048 && map[value->kind.data.load.src] <=2047)
            {
              cout << "  lw    t0, " << map[value->kind.data.load.src] << "(sp)" << endl;
            }
            else
            {
              cout << "  li    t1, " << map[value->kind.data.load.src] << endl;
              cout << "  add   t1, t1, sp" << endl;
              cout << "  lw    t0, 0(t1)" << endl;
            }

            cout << "  lw    t0, 0(t0)" << endl;
            
            if (allc >= -2048 && allc <=2047)
            {
              cout << "  sw    t0, " << allc << "(sp)" << endl;
            }
            else
            {
              cout << "  li    t1, " << allc << endl;
              cout << "  add   t1, t1, sp" << endl;
              cout << "  sw    t0, 0(t1)" << endl;
            }

            map[value] = allc;
            allc = allc + 4;
          }
        }
        else if (value->kind.tag == KOOPA_RVT_STORE){

          // cout<<value->kind.data.store.value->kind.tag<<endl;
          if(value->kind.data.store.value->kind.tag == KOOPA_RVT_INTEGER){
            // cout<<value->kind.data.store.dest->kind.tag<<endl;
            if (value->kind.data.store.dest->kind.tag == KOOPA_RVT_GLOBAL_ALLOC)
            {
              cout << "  la    t0, " << value->kind.data.store.dest->name+1 << endl;
              cout << "  li    t1, " << value->kind.data.store.value->kind.data.integer.value << endl;
              cout << "  sw    t1, 0(t0)" << endl;
            }
            else if (value->kind.data.store.dest->kind.tag == KOOPA_RVT_ALLOC)
            {
              cout << "  li    t0, " << value->kind.data.store.value->kind.data.integer.value << endl;

              if (map[value->kind.data.store.dest] >= -2048 && map[value->kind.data.store.dest] <= 2047)
              {
                cout << "  sw    t0, " << map[value->kind.data.store.dest] << "(sp)" << endl;
              }
              else
              {
                cout << "  li    t1, " << map[value->kind.data.store.dest]<<endl;
                cout << "  add   t1, t1, sp" << endl;
                cout << "  sw    t0, 0(t1)" << endl;
              }              
            }
            else
            {
              cout << "  li    t0, " << value->kind.data.store.value->kind.data.integer.value << endl;

              if (map[value->kind.data.store.dest] >= -2048 && map[value->kind.data.store.dest] <= 2047)
              {
                cout << "  lw    t1, " << map[value->kind.data.store.dest] << "(sp)" << endl;
              }
              else
              {
                cout << "  li    t1, " << map[value->kind.data.store.dest]<<endl;
                cout << "  add   t1, t1, sp" << endl;
                cout << "  lw    t1, 0(t1)" << endl;
              }  
              cout << "  sw    t0, 0(t1)" << endl;              
            }
            
          }
          else if (value->kind.data.store.value->kind.tag == KOOPA_RVT_FUNC_ARG_REF) 
          {
            int id = value->kind.data.store.value->kind.data.block_arg_ref.index;
            if (id < 8)
            {
              if (map[value->kind.data.store.dest] >=-2048 && map[value->kind.data.store.dest] <=2047)
              {
                cout << "  sw    a" << id << ", " << map[value->kind.data.store.dest] << "(sp)" << endl;
              }
              else
              {
                cout << "  li    t1, " << map[value->kind.data.store.dest] <<endl;
                cout << "  add   t1, t1, sp" << endl;
                cout << "  sw    a" << id << ", 0(t1)" << endl;
              }
              
            }
            else
            {
              if (size + 4 * (id - 8) >= -2048 && size + 4 * (id - 8) <= 2047)
              {
                cout << "  lw    t0, " << size + 4 * (id - 8) << "(sp)"<< endl;
              }
              else
              {
                cout << "  li    t0, " << size + 4 * (id - 8);
                cout << "  add   t0, t0, sp" << endl;
                cout << "  lw    t0, 0(t0)" << endl;
              }

              if (map[value->kind.data.store.dest] >= -2048 && map[value->kind.data.store.dest] <= 2047)
              {
                cout << "  sw    t0, " << map[value->kind.data.store.dest] << "(sp)" << endl;
              }
              else
              {
                cout << "  li   t1, " << map[value->kind.data.store.dest];
                cout << "  add  t1, t1, sp" << endl;
                cout << "  sw   t0, 0(t1)" <<endl;
              }              
            }
          }
          else
          {
            if (value->kind.data.store.dest->kind.tag == KOOPA_RVT_GLOBAL_ALLOC)
            {
              cout << "  la    t0, " << value->kind.data.store.dest->name+1 << endl;
              if (map[value->kind.data.store.value] >= -2048 && map[value->kind.data.store.value] <= 2047)
              {
                cout << "  lw    t1, " << map[value->kind.data.store.value] << "(sp)" << endl;
              }
              else
              {
                cout << "  li    t1, " << map[value->kind.data.store.value] << endl;
                cout << "  add   t1, t1, sp" << endl;
                cout << "  lw    t1, 0(t1)" << endl;
              }
              cout << "  sw    t1, 0(t0)" << endl;
            }
            else if (value->kind.data.store.dest->kind.tag == KOOPA_RVT_ALLOC)
            {
              if (map[value->kind.data.store.value] >= -2048 && map[value->kind.data.store.value] <= 2047)
              {
                cout << "  lw    t1, " << map[value->kind.data.store.value] << "(sp)" << endl;
              }
              else
              {
                cout << "  li    t1, " << map[value->kind.data.store.value] << endl;
                cout << "  add   t1, t1, sp" << endl;
                cout << "  lw    t1, 0(t1)" << endl;
              }
              if (map[value->kind.data.store.dest] >= -2048 && map[value->kind.data.store.dest] <=2047)
              {
                cout << "  sw    t1, " << map[value->kind.data.store.dest] << "(sp)" << endl;
              }
              else
              {
                cout << "  li    t0, " << map[value->kind.data.store.dest] << endl;
                cout << "  add   t0, t0, sp" << endl;
                cout << "  sw    t1, 0(t0)" << endl;
              }
            }
            else
            {
              if (map[value->kind.data.store.value] >= -2048 && map[value->kind.data.store.value] <= 2047)
              {
                cout << "  lw    t0, " << map[value->kind.data.store.value] << "(sp)" << endl;
              }
              else
              {
                cout << "  li    t0, " << map[value->kind.data.store.value] << endl;
                cout << "  add   t0, t0, sp" << endl;
                cout << "  lw    t0, 0(t0)" << endl;
              }
              if (map[value->kind.data.store.dest] >= -2048 && map[value->kind.data.store.dest] <=2047)
              {
                cout << "  lw    t1, " << map[value->kind.data.store.dest] << "(sp)" << endl;
              }
              else
              {
                cout << "  li    t1, " << map[value->kind.data.store.dest] <<endl;
                cout << "  add   t1, t1, sp" << endl;
                cout << "  lw    t1, 0(t1)" << endl;
              }
              cout << "  sw    t0, 0(t1)" << endl;              
            }
          }
        }
        else if (value->kind.tag == KOOPA_RVT_GET_PTR) {

          koopa_raw_value_t src = value->kind.data.get_ptr.src;
          koopa_raw_value_t index = value->kind.data.get_ptr.index;


          int sz;

          // cout<< "tag = " << src->kind.tag<<endl;


          if (src->kind.tag == KOOPA_RVT_ALLOC)
          {
            if (map[src] <= 2047 && map[src] >= -2048)
              cout << "  addi  t0, sp, " << map[src] << endl;
            else
            {
              cout << "  li    t1, " << map[src] << endl;
              cout << "  add   t0, sp, t1" << endl;
            }
            sz = calc_alloc_size(src->ty->data.pointer.base->data.array.base);
          }
          else if(src->kind.tag == KOOPA_RVT_GLOBAL_ALLOC)
          {
            cout << "  la    t0, " << src->name+1 << endl;
            sz = calc_alloc_size(src->ty->data.pointer.base->data.array.base);
          }
          else if (src->kind.tag == KOOPA_RVT_LOAD)
          {
            if (map[src] <= 2047 && map[src] >= -2048)
              cout << "  addi  t0, sp, " << map[src] << endl;
            else
            {
              cout << "  li    t1, " << map[src] << endl;
              cout << "  add   t0, sp, t1" << endl;
            }
              cout << "  lw    t0, 0(t0)" << endl;
            sz = calc_alloc_size(src->kind.data.load.src->ty->data.pointer.base->data.pointer.base);
          }
          else
          {
            if (map[src] <= 2047 && map[src] >= -2048)
              cout << "  addi  t0, sp, " << map[src] << endl;
            else
            {
              cout << "  li    t1, " << map[src] << endl;
              cout << "  add   t0, sp, t1" << endl;
            }
              cout << "  lw    t0, 0(t0)" << endl;
            sz = calc_alloc_size(src->ty->data.pointer.base->data.array.base);

          }
          if (index->kind.tag == KOOPA_RVT_INTEGER)
          {
            int offset = index->kind.data.integer.value;
            cout << "  li    t1, " << offset << endl;
          }
          else
          {
            if (map[index] >= -2048 && map[index] <= 2047)
            {
              cout << "  lw    t1, " << map[index] << "(sp)" << endl;
            }
            else
            {
              cout << "  li    t1, " << map[index] << endl;
              cout << "  add   t1, t1, sp" << endl;
              cout << "  lw    t1, 0(t1)" << endl;
            }
          }
          cout << "  li    t2, " << sz << endl;
          cout << "  mul   t1, t1, t2" << endl;
          cout << "  add   t0, t0, t1" << endl;
          
          if (allc >= -2048 && allc <=2047)
          {
            cout << "  sw    t0, " << allc << "(sp)" << endl;
          }
          else
          {
            cout << "  li    t1, " << allc <<endl;
            cout << "  add   t1,t1,sp"<<endl;
            cout << "  sw    t0, 0(t1)" << endl;
          }
          
          map[value] = allc;
          allc += 4;
        }
        else if (value->kind.tag == KOOPA_RVT_GET_ELEM_PTR) {
          koopa_raw_value_t src = value->kind.data.get_elem_ptr.src;
          koopa_raw_value_t index = value->kind.data.get_elem_ptr.index;
          int sz = calc_alloc_size(src->ty->data.pointer.base->data.array.base);
          // cout<< "tag = " << index->kind.tag<<endl;
          if (src->kind.tag == KOOPA_RVT_ALLOC)
          {
            if (map[src] <= 2047 && map[src] >= -2048)
              cout<< "  addi   t0, sp, " << map[src] << endl;
            else
            {
              cout << "  li    t1, " << map[src] << endl;
              cout << "  add   t0, sp, t1" << endl;
            }
          }
          else if(src->kind.tag == KOOPA_RVT_GLOBAL_ALLOC)
          {
            cout << "  la    t0, " << src->name+1 << endl;
          }
          else
          {
            if (map[src] <= 2047 && map[src] >= -2048)
              cout << "  addi  t0, sp, " << map[src] << endl;
            else
            {
              cout << "  li    t1, " << map[src] << endl;
              cout << "  add   t0, sp, t1" << endl;
            }
              cout << "  lw  t0, 0(t0)" << endl;
            
          }
          if (index->kind.tag == KOOPA_RVT_INTEGER)
          {
            int offset = index->kind.data.integer.value;
            cout << "  li   t1, " << offset << endl;
          }
          else
          {
            if (map[index] >= -2048 && map[index] <= 2047)
            {
              cout << "  lw    t1, " << map[index] << "(sp)" << endl;
            }
            else
            {
              cout << "  li    t1, " << map[index] << endl;
              cout << "  add   t1, t1, sp" << endl;
              cout << "  lw    t1, 0(t1)" << endl;
            }
          }
          
          cout << "  li    t2, " << sz << endl;
          cout << "  mul   t1, t1, t2" << endl;
          cout << "  add   t0, t0, t1" << endl;
          
          if (allc >= -2048 && allc <= 2047)
          {
            cout << "  sw    t0, " << allc << "(sp)" << endl;
          }
          else
          {
            cout << "  li    t1, " << allc <<endl;
            cout << "  add   t1,t1,sp"<<endl;
            cout << "  sw    t0, 0(t1)" << endl;
          }

          map[value] = allc;
          allc += 4;
        }
        else if (value->kind.tag == KOOPA_RVT_BINARY){
          string rs1,rs2,rd;
          if(value->kind.data.binary.lhs->kind.tag == KOOPA_RVT_INTEGER){
            int lvalue = value->kind.data.binary.lhs->kind.data.integer.value;
            if (lvalue == 0){
              rs1 = "x0";
            }
            else
            {
              cout << "  li    " << "t" << current << ", " << lvalue << endl;
              rs1 = string("t") + to_string(current);
              current = current + 1;
            }
          }
          else {
            if (map[value->kind.data.binary.lhs] >= -2048 && map[value->kind.data.binary.lhs] <= 2047)
            {
              cout << "  lw    t" << current << ", " << map[value->kind.data.binary.lhs] <<"(sp)" << endl;
            }
            else
            {
              cout << "  li    t" << current << ", " << map[value->kind.data.binary.lhs] << endl;
              cout << "  add   t" << current << ", t" << current << ", sp" << endl;
              cout << "  lw    t" << current << ", 0(t" << current << ")" << endl; 
            }
            
            rs1 = string("t") + to_string(current);
            current = current + 1;
          }
          // cout<< "op = "<< value->kind.data.binary.op <<' '<<endl;
          if(value->kind.data.binary.rhs->kind.tag == KOOPA_RVT_INTEGER){
            int rvalue = value->kind.data.binary.rhs->kind.data.integer.value;
            if (rvalue == 0){
              rs2 = "x0";
            }
            else{
              cout << "  li    " << "t" << current << ", " << rvalue << endl;
              rs2 = string("t") + to_string(current);
              current = current + 1;
            }
          }
          else {
            if (map[value->kind.data.binary.rhs] >= -2048 && map[value->kind.data.binary.rhs] <= 2047)
            {
              cout << "  lw    t" << current << ", " << map[value->kind.data.binary.rhs] <<"(sp)" << endl;
            }
            else
            {
              cout << "  li    t" << current << ", " << map[value->kind.data.binary.rhs] << endl;
              cout << "  add   t" << current << ", t" << current << ", sp" << endl;
              cout << "  lw    t" << current << ", 0(t" << current << ")" << endl; 
            }
            rs2 = string("t") + to_string(current);
            current = current + 1;
          }    
        
          rd = string("t") + to_string(current);
          current = current + 1;
          // map[value] = rd;
          if (value->kind.data.binary.op == 0){
            // ne          
            cout<<"  xor   "<< rd<<", "<<rs1<<", "<<rs2<<endl;
            cout<<"  seqz  "<< rd<<", "<<rd<<endl;
            cout << "  li    " << rs1 << ", " << 1 << endl;
            cout<<"  sub   "<< rd<<", "<<rs1<<", "<< rd<<endl;
          }
          else if (value->kind.data.binary.op == 1){
            // eq          
            cout<<"  xor   "<< rd<<", "<<rs1<<", "<<rs2<<endl;
            cout<<"  seqz  "<< rd<<", "<<rd<<endl;
          }
          else if (value->kind.data.binary.op == 2){  // greater than
            cout<<"  sgt   "<< rd<<", "<<rs1<<", "<<rs2<<endl;
          }
          else if (value->kind.data.binary.op == 3){  // less than
            cout<<"  slt   "<< rd<<", "<<rs1<<", "<<rs2<<endl;
          }
          else if (value->kind.data.binary.op == 4){  // greater or equal than
            cout<<"  slt   "<< rd<<", "<<rs1<<", "<<rs2<<endl;
            cout<<"  seqz  "<< rd<<", "<<rd<<endl;
          }
          else if (value->kind.data.binary.op == 5){  // less or equal than
            cout<<"  sgt   "<< rd<<", "<<rs1<<", "<<rs2<<endl;
            cout<<"  seqz  "<< rd<<", "<<rd<<endl;
          }
          else if (value->kind.data.binary.op == 6){
            cout<<"  add   "<< rd<<", "<<rs1<<", "<<rs2<<endl;
          }
          else if (value->kind.data.binary.op == 7){
            cout<<"  sub   "<< rd<<", "<<rs1<<", "<<rs2<<endl;
          }
          else if (value->kind.data.binary.op == 8){
            cout<<"  mul   "<< rd<<", "<<rs1<<", "<<rs2<<endl;
          }
          else if (value->kind.data.binary.op == 9){
            cout<<"  div   "<< rd<<", "<<rs1<<", "<<rs2<<endl;
          }
          else if (value->kind.data.binary.op == 10){
            cout<<"  rem   "<< rd<<", "<<rs1<<", "<<rs2<<endl;
          }
          else if (value->kind.data.binary.op == 11){
            cout<<"  and   "<< rd<<", "<<rs1<<", "<<rs2<<endl;
          }
          else if (value->kind.data.binary.op == 12){
            cout<<"  or    "<< rd<<", "<<rs1<<", "<<rs2<<endl;
          }

          if (allc >= -2048 && allc <= 2047)
          {
            cout << "  sw    " << rd <<", " << allc << "(sp)" << endl;
          }
          else
          {
            cout << "  li    t" << current << ", " << allc << endl;
            cout << "  add   t" << current << ", t" << current << ", sp" << endl;
            cout << "  sw    " << rd << ", 0(t" << current << ")" << endl;
          }
          map[value] = allc;
          //cout<<long(value)<<endl;
          allc += 4;
        }
        else if (value->kind.tag == KOOPA_RVT_BRANCH){
          if (map[value->kind.data.branch.cond] >= -2048 && map[value->kind.data.branch.cond] <=2047)
          {
            cout << "  lw    t0, " << map[value->kind.data.branch.cond] << "(sp)" << endl;
          }
          else
          {
            cout << "  li    t0, " << map[value->kind.data.branch.cond] << endl;
            cout << "  add   t0, t0, sp" << endl;
            cout << "  lw    t0, 0(t0)" << endl;
          }
          
          //cout << "  bnez t0, " << value->kind.data.branch.true_bb->name+1 << endl;
          cout << "  beq   t0, x0, " << local_label << "f" << endl;
          cout << "  jal   x0, " << value->kind.data.branch.true_bb->name+1 << endl;
          cout << local_label++ << ":  jal   x0, " << value->kind.data.branch.false_bb->name+1 << endl;
        }
        else if (value->kind.tag == KOOPA_RVT_JUMP){
          // AUIPC和JALR配合可以跳转32位相对于PC的地址范围
          cout << "  jal  x0, " << value->kind.data.jump.target->name+1 << endl;
        }
        else if (value->kind.tag == KOOPA_RVT_CALL){
          int sbrk = 0;
          int p1 = value->kind.data.call.args.len > 8 ? 8:value->kind.data.call.args.len;
          for (int para = 0; para < p1; ++para)
          {
            if (map[(koopa_raw_value_t)value->kind.data.call.args.buffer[para]] >= -2048 && map[(koopa_raw_value_t)value->kind.data.call.args.buffer[para]] <=2047)
            {
              cout<< "  lw   a" << para << ", " << map[(koopa_raw_value_t)value->kind.data.call.args.buffer[para]] << "(sp)" << endl;
            }
            else
            {
              cout << "  li    t0," << map[(koopa_raw_value_t)value->kind.data.call.args.buffer[para]] << endl;
              cout << "  add   t0, t0, sp" << endl;
              cout << "  lw    a" << para << ", 0(t0)" << endl; 
            }
            
          }
          if (value->kind.data.call.args.len > 8)
          {
            sbrk = 4 * (value->kind.data.call.args.len - 8);
            cout<< "  addi  sp, sp, -" << sbrk << endl; 
          }
          if (sbrk)
          {
            for (int para = 8; para < value->kind.data.call.args.len; ++para)
            {
              if (map[(koopa_raw_value_t)value->kind.data.call.args.buffer[para]] >= -2048 && map[(koopa_raw_value_t)value->kind.data.call.args.buffer[para]] <=2047)
              {
                cout<< "  lw    t0, " << map[(koopa_raw_value_t)value->kind.data.call.args.buffer[para]] + sbrk << "(sp)" << endl;
              }
              else
              {
                cout << "  li    t0," << map[(koopa_raw_value_t)value->kind.data.call.args.buffer[para]] << endl;
                cout << "  add   t0, t0, sp" << endl;
                cout << "  lw    t0, " << sbrk << "(t0)" << endl; 
              }

              cout<< "  sw    t0, " << 4 * (para-8) << "(sp)" << endl; 
            }
          }
          cout << local_label << ":  auipc ra, %pcrel_hi(" << value->kind.data.call.callee->name+1 << ")" << endl;
          cout << "  jalr  ra, %pcrel_lo(" << local_label++ << "b) (ra)" << endl;

          // cout << "  call  " << value->kind.data.call.callee->name+1 << endl;
          if (sbrk){
            cout<< "  addi  sp, sp, " << sbrk << endl;
          }
          if (allc >=-2048 && allc <= 2047)
          {
            cout<< "  sw    a0, " << allc << "(sp)" << endl;
          }
          else
          {
            cout << "  li    t0, " << allc <<endl;
            cout << "  add  t0, t0, sp" << endl;
            cout << "  sw    a0, 0(t0)" << endl;
          }
          
          map[value] = allc;
          allc += 4;
        }
        else if (value->kind.tag == KOOPA_RVT_RETURN){
          // 示例程序中, 你得到的 value 一定是一条 return 指令
          // 于是我们可以按照处理 return 指令的方式处理这个 value
          // return 指令中, value 代表返回值
          //cout<<"ret"<<endl;
          koopa_raw_value_t ret_value = value->kind.data.ret.value;
          //cout<<"ret"<<endl;
          if (ret_value != NULL){
            if (ret_value->kind.tag == KOOPA_RVT_INTEGER){
              // 于是我们可以按照处理 integer 的方式处理 ret_value
              // integer 中, value 代表整数的数值
              int32_t int_val = ret_value->kind.data.integer.value;
              // 示例程序中, 这个数值一定是 0
              // assert(int_val == 0);
              cout << "   li    " << "a0 , " << int_val << endl;
            }
            else {
              //cout<<"  mv    a0, "<<map[ret_value]<<endl;
              if (map[ret_value] >= -2048 && map[ret_value] <=2047)
              {
                cout << "  lw    a0, "<< map[ret_value] << "(sp)" << endl;
              }
              else
              {
                cout << "  li    t0, " << map[ret_value] << endl;
                cout << "  add   t0, t0, sp" << endl;
                cout << "  lw    a0, 0(t0)" << endl;
              }
            }
          }
          
          if (size >= -2048 && size <= 2047)
          {
            cout << "  lw    ra, " << size - 4 << "(sp)" << endl;
            cout << "  lw    s0, " << size - 8 << "(sp)" << endl;
            cout << "  addi  sp, sp, " << size <<endl;
          }
          else
          {
            cout << "  li    t0, " << size << endl;
            cout << "  add   t1, t0, sp" << endl;
            cout << "  lw    ra, " << -4 << "(t1)" << endl;
            cout << "  lw    s0, " << -8 << "(t1)" << endl;
            cout << "  add  sp, sp, t0" << endl;
          }          
          cout << "  ret" << endl;
        }
      }
    }
  }

  // 处理完成, 释放 raw program builder 占用的内存
  // 注意, raw program 中所有的指针指向的内存均为 raw program builder 的内存
  // 所以不要在 raw program builder 处理完毕之前释放 builder
  koopa_delete_raw_program_builder(builder);
}



