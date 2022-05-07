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




  // 处理完成, 释放 raw program builder 占用的内存
  // 注意, raw program 中所有的指针指向的内存均为 raw program builder 的内存
  // 所以不要在 raw program builder 处理完毕之前释放 builder
  koopa_delete_raw_program_builder(builder);
}



