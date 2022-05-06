#pragma once

static int debug = 0;
static int now = 0;    // 临时变量编号



typedef struct
{
  int type;
  // 函数： 3-返回int 2-无返回值
  //
  //
  //
  //
  //
  int value;
  // 函数： 参数的个数
  std::string str;
  // 函数名 变量名 常量名
} Symbol;
typedef std::map<std::string, Symbol> Symbolmap;

typedef struct func_symbol
{
  int depth;
  int blockend;
  // int IFcount;
  // int whilecount;
  // int othercount;
  std::stack<int> loopstack;
  std::vector<Symbolmap> smap;
  std::set<std::string> nameset;
  func_symbol()
  {
    depth = 0;
    blockend = 0;
    // IFcount = 0;
    // whilecount = 0;
    // othercount = 0;
  }
} funcsymbol;

typedef struct
{
  Symbolmap globalsymbol;
  std::map<std::string, std::unique_ptr<func_symbol>> funcsymbolmap;
} Symboltable;

static Symboltable symbt;
static func_symbol * currentsymbt = NULL;
static std::string globalstr;




class BaseAST
{
public:
  virtual ~BaseAST() = default;

  virtual std::string Dump() const = 0;
};

/* 最顶层的解析 */
class CompUnitAST : public BaseAST
{
public:
  std::unique_ptr<BaseAST> compunits;
  std::string Dump() const override
  {
    if (debug) std::cout << "CompUnitAST:" << std::endl;
    // 库函数
    std::cout << "decl @getint(): i32" << std::endl;
    std::cout << "decl @getch(): i32" << std::endl;
    std::cout << "decl @getarray(*i32): i32" << std::endl;
    std::cout << "decl @putint(i32)" << std::endl;
    std::cout << "decl @putch(i32)" << std::endl;
    std::cout << "decl @putarray(i32, *i32)" << std::endl;
    std::cout << "decl @starttime()" << std::endl;
    std::cout << "decl @stoptime()" << std::endl;

    symbt.globalsymbol["getint"] = {3, 0, "getint"};
    symbt.globalsymbol["getch"] = {3, 0, "getch"};
    symbt.globalsymbol["getarray"] = {3, 1, "getarray"};
    symbt.globalsymbol["putint"] = {2, 1, "putint"};
    symbt.globalsymbol["putch"] = {2, 1, "putch"};
    symbt.globalsymbol["putarray"] = {2, 2, "putarray"};
    symbt.globalsymbol["starttime"] = {2, 0, "starttime"};
    symbt.globalsymbol["stoptime"] = {2, 0, "stoptime"};

    return compunits->Dump();
  }
};

class CompUnitsAST : public BaseAST
{
public:
  // 用智能指针管理对象
  std::unique_ptr<BaseAST> compunits;
  std::unique_ptr<BaseAST> func_def;
  std::unique_ptr<BaseAST> decl;
  std::string Dump() const override
  {
    if (debug) std::cout << "CompUnitsAST:" << std::endl;
    if (compunits)
    {
      compunits->Dump();
    }
    if (func_def)
    {
      func_def->Dump();
    }
    if (decl)
    {
      decl->Dump();
    }
    std::string str;
    return str;
  }
};


/* 两种Type*/
class FuncTypeAST : public BaseAST
{
public:
  std::string type;
  std::string Dump() const override
  {
    if (debug) std::cout << "FuncTypeAST" << std::endl;
    if (type == "int")
      std::cout << ": i32 ";
    else
      std::cout << " ";
    std::string str;
    return str;
  }
  int Calc() override
  {
    if (type == "int")
      return 1;
    else
      return 0;
  }
};

class BTypeAST: public BaseAST
{
public:
  std::string type;
  std::string Dump() const override
  {
    std::cout << type << std::endl;
    return type;
  }
};

/* 函数名 */
class FuncDefAST : public BaseAST
{
public:
  int func_type;
  std::string ident;
  std::unique_ptr<BaseAST> funcp;
  std::unique_ptr<BaseAST> block;
  std::string Dump() const override
  {
    if (debug) std::cout << "FuncDefAST:" << std::endl;
    std::cout << "fun " << "@" << ident << "(";
    // 取得函数的参数以及类型
    if (funcp)
      funcp->Dump();
    std::cout << ")";
    // 如果有返回值
    if (func_type == 1)
      std::cout << ": i32";
    std::cout << " {" << std::endl;
    std::cout << "%entry_" << entrycount++ << ":" << std::endl;
    symbt.funcsymbolmap[ident] = std::make_unique<func_symbol>();
    currentsymbt = symbt.funcsymbolmap[ident].get();
    Symbolmap m;
    currentsymbt->smap.push_back(m);
    currentsymbt->blockend = 0;
    if (funcp)
    {
      if (func_type == 1)
        symbt.globalsymbol[ident] = {3, funcp->allocpara(), ident + "_00"};
      else
        symbt.globalsymbol[ident] = {2, funcp->allocpara(), ident + "_00"};
    }
    else
    {
      if (func_type == 1)
        symbt.globalsymbol[ident] = {3, 0, ident + "_00"};
      else
        symbt.globalsymbol[ident] = {2, 0, ident + "_00"};
    }
    block->Dump();
    // 没有指定返回值
    if (currentsymbt->blockend == 0)
    {
      std::cout << "  ret" << std::endl;
      currentsymbt->blockend = 1;
    }
    std::cout << "}" << std::endl;
    std::cout << std::endl;
    currentsymbt->smap.pop_back();
    currentsymbt = NULL;
    std::string str;
    return str;
  }
};




/* 基本块 */
class BlockAST : public BaseAST
{
public:
  std::unique_ptr<BaseAST> blockitem;
  std::string Dump() const override
  {
    if (debug) std::cout << "BlockAST" << std::endl;
    currentsymbt->depth++;
    Symbolmap m;
    currentsymbt->smap.push_back(m);
    std::string str = blockitem->Dump();
    currentsymbt->smap.pop_back();
    currentsymbt->depth--;
    return str;
  }
};

class BlockItemAST : public BaseAST
{
public:
  std::unique_ptr<BaseAST> stmt;
  std::unique_ptr<BaseAST> decl;
  std::unique_ptr<BaseAST> blockitem;
  std::string Dump() const override
  {
    if (debug) std::cout << "BlockItemAST:" << std::endl;
    if (stmt || decl)
    {
      if (currentsymbt->blockend == 1)
      {
        currentsymbt->blockend = 0;
        std::cout << "%other_" << othercount++ << ":" << std::endl;
      }
    }
    if (stmt != NULL)
      stmt->Dump();
    if (decl != NULL)
      decl->Dump();
    if (blockitem != NULL)
      blockitem->Dump();
    std::string str;
    return str;
  }
};

/* 声明部分 */
class DeclAST : public BaseAST {
public:
    std::unique_ptr<BaseAST> constdecl;
    std::unique_ptr<BaseAST> vardecl;
    std::string Dump() const override {
      if (debug) std::cout << "DECL" << std::endl;
      if (vardecl != NULL)
        return vardecl->Dump();
      else
        return constdecl->Dump();
    }
};

class ConstExpAST:public BaseAST{
public:
    std::unique_ptr<BaseAST> exp;
    std::string Dump() const override{
      if (debug) std::cout << "ConstExpAST:" << std::endl;
      std::string str = exp->Dump();
      return str;
    }
    int Calc() override{
      return exp->Calc();
    }
};

class ConstArrayInitValAST:public BaseAST{
public:
    std::unique_ptr<BaseAST> constinitval;
    std::unique_ptr<BaseAST> constayyayinitval;
    std::string Dump() const override{
      std::string str;
      return str;
    }
    void fillinit(std::vector<int> dim, int * a, int depth) override {      
      constinitval->fillinit(dim,a,depth);
      if (constayyayinitval)
      {
        constayyayinitval->fillinit(dim,a,depth);
      }
    }
    void fillinit(std::vector<int> dim, std::string ident, int depth) override {
      constinitval->fillinit(dim,ident,depth);
      if (constayyayinitval)
      {
        constayyayinitval->fillinit(dim,ident,depth);
      }      
    }
};

class ConstInitValAST:public BaseAST{
public:
    std::unique_ptr<BaseAST> constexp;
    std::unique_ptr<BaseAST> constarrayinitval;
    std::string Dump() const override{
      if (constexp)
        return constexp->Dump();
      std::string str;
      return str;
    }
    int Calc() override{
      if (constexp)
        return constexp->Calc();
      return 0;
    }
    std::string ArrCalc() override{
      std::string str;
      if (constarrayinitval)
      {
        str =  constarrayinitval->ArrCalc();
      }
      return str;
    }
    void fillinit(std::vector<int> dim, int * a, int depth) override {
      if (constexp)
      {
        a[curr++] = constexp->Calc();
        return;
      }
      int sz = 1;
      for (int i = depth; i < dim.size(); ++i)
      {
        sz = sz * dim[i];
      }
      int sz1 = 1;
      int temp = curr;
      for (int i = dim.size() - 1; i >= 0 ; i--)
      {
        if (temp % dim[i] == 0){
          sz1 *= dim[i];
          temp = temp/dim[i];
        }
        else
          break;
      }
      if (sz > sz1)
        sz = sz1;
      // std::cout<<"sz = "<<sz<<std::endl;
      if (constarrayinitval == NULL)
      {        
        curr += sz;
        return;
      }
      if (constarrayinitval)
      {
        constarrayinitval->fillinit(dim, a, depth + 1);
        curr = (curr + sz - 1) / sz * sz;
      }
    }

    void fillinit(std::vector<int> dim, std::string ident, int depth) override {
      if (constexp)
      {
        std::string dst = BaseAST::fetch(dim, ident, curr, dim.size() - 1);
        curr++;
        std::cout << "  store " << constexp->Calc() << ", " << dst << std::endl;
        return;
      }
      int sz = 1;
      for (int i = depth; i < dim.size(); ++i)
      {
        sz = sz * dim[i];
      }
      int temp = curr;
      int sz1 = 1;
      for (int i = dim.size() - 1; i >= 0 ; i--)
      {
        if (temp % dim[i] == 0){
          sz1 *= dim[i];
          temp = temp/dim[i];
        }
        else
          break;
      }
      if (sz > sz1)
        sz = sz1;
      if (constarrayinitval == NULL)
      {
        for (int i = 0; i < sz; ++i)
        {
          std::string dst = BaseAST::fetch(dim, ident, curr, dim.size() - 1);
          curr++;
          std::cout << "  store " << "0" << ", " << dst << std::endl;
        }
        return;
      }
      if (constarrayinitval)
      {
        constarrayinitval->fillinit(dim, ident, depth + 1);
        int repeat = (curr + sz - 1) / sz * sz - curr;
        for (int i = 0; i < repeat; ++i)
        {
          std::string dst = BaseAST::fetch(dim, ident, curr, dim.size() - 1);
          curr++;
          std::cout << "  store " << "0" << ", " << dst << std::endl;
        }
      }
    }
};

class ArrayDefAST:public BaseAST {
public:
    std::unique_ptr<BaseAST> constexp;
    std::unique_ptr<BaseAST> arraydef;
    std::string Dump() const override{
      std::string str = constexp->Dump();
      if (arraydef)
        str += arraydef->Dump();
      return str;
    }
    std::string ArrCalc() override{
      std::string str;
      if (arraydef)
      {
        str = std::to_string(constexp->Calc()) + ", " + arraydef->ArrCalc();
        globalstr = std::string("[") + globalstr + ", " + std::to_string(constexp->Calc()) + "]";
      }
      else
      {
        str = std::to_string(constexp->Calc());
        globalstr = std::string("[i32, ") + std::to_string(constexp->Calc()) + "]";
      }
      return str;
    }
};

class ConstDefAST:public BaseAST{
public:
    std::string ident;
    std::unique_ptr<BaseAST> arraydef;
    std::unique_ptr<BaseAST> constinitval;
    std::unique_ptr<BaseAST> constdef;
    std::string Dump() const override{
      if (debug) std::cout << "ConstDefAST" << std::endl;
      if (currentsymbt == NULL)   //global
      {
        if (arraydef == NULL)   //var
        {
          symbt.globalsymbol[ident] = {1, constinitval->Calc(), ident + "_00"};
        }
        else      // array
        {
          std::string arrdim = arraydef->ArrCalc();          
          char * spl = std::strtok((char*)arrdim.c_str(),",");
          std::vector<int> dim;
          while(spl)
          {
            dim.push_back(atoi(spl));
            spl = strtok(NULL, ",");
          }
          symbt.globalsymbol[ident] = {3, (int)dim.size(), ident + "_00"};
          std::cout << "global @" << ident + "_00" << " = alloc " << globalstr << ", ";
          int k = 1;
          for (int i = 0; i < dim.size(); ++i)
          {
            k = k * dim[i];
          }

          int * a = new int[k];
          memset(a, 0, sizeof(int) * k);
          curr = 0;
          constinitval->fillinit(dim, a, 0);
          curr = 0;
          constinitval->DumpArray(dim, a, 0);
          std::cout << std::endl;


        }

      }
      else     //local
      {
        if (arraydef == NULL)   //var
        {
          currentsymbt->smap[currentsymbt->depth][ident] = {1, constinitval->Calc(), ident + std::string("_") + std::to_string(currentsymbt->depth)};
        }
        else     // array
        {
          std::string arrdim = arraydef->ArrCalc();
          
          char * spl = std::strtok((char*)arrdim.c_str(),",");
          std::vector<int> dim;
          while(spl)
          {
            dim.push_back(atoi(spl));
            spl = strtok(NULL, ",");
          }
          currentsymbt->smap[currentsymbt->depth][ident] = {3, (int)dim.size(), ident + std::string("_") + std::to_string(currentsymbt->depth)};
          std::cout<<"  @" << ident << "_" << currentsymbt->depth << " = alloc " << globalstr << std::endl;
          // currentsymbt->nameset.insert(ident + std::string("_") + std::to_string(currentsymbt->depth));
          curr = 0;
          constinitval->fillinit(dim, std::string("@") + ident + "_" + std::to_string(currentsymbt->depth), 0);        
        }
      }
      if (constdef)
        constdef->Dump();
      std::string str;
      return str;
    }
};

class ConstDeclAST:public BaseAST{
public:
    std::string const_;
    std::unique_ptr<BaseAST> btype;
    std::unique_ptr<BaseAST> constdef;
    std::string Dump() const override{
      if (debug)
        std::cout << "ConstDeclAST" << std::endl;
      return constdef->Dump();
    }
};

class ArrayInitValAST: public BaseAST{
public:
    std::unique_ptr<BaseAST> initval;
    std::unique_ptr<BaseAST> arrayinitval;
    std::string Dump() const override{
      std::string str;
      if (initval)
        str = initval->Dump();
      if (arrayinitval)
        str = str + "," + arrayinitval->Dump();
      return str;
    }
    std::string ArrCalc() override {
      std::string str;
      str = std::to_string(initval->Calc());
      if (arrayinitval)
      {
        str = str + "," + arrayinitval->ArrCalc();
      }
      return str;
    }
    void fillinit(std::vector<int> dim, int * a, int depth) override {      
      initval->fillinit(dim,a,depth);
      if (arrayinitval)
      {
        arrayinitval->fillinit(dim,a,depth);
      }
    }
    void fillinit(std::vector<int> dim, std::string ident, int depth) override {
      initval->fillinit(dim,ident,depth);
      if (arrayinitval)
      {
        arrayinitval->fillinit(dim,ident,depth);
      }      
    }
};

class InitValAST:public BaseAST{
public:
    int zeroinit;
    std::unique_ptr<BaseAST> exp;
    std::unique_ptr<BaseAST> arrayinitval;
    std::string Dump() const override{
      std::string str;
      if (exp)
        str = exp->Dump();
      if (arrayinitval)
        str = arrayinitval->Dump();
      return str;
    }
    int Calc() override{
      if (exp)
        return exp->Calc();
      return 0;
    }
    std::string ArrCalc() override {
      std::string str;
      if (arrayinitval)
      {
        str = arrayinitval->ArrCalc();
      }
      return str;
    }
    void fillinit(std::vector<int> dim, int * a, int depth) override {
      if (exp)
      {
        a[curr++] = exp->Calc();
        return;
      }
      int sz = 1;
      for (int i = depth; i < dim.size(); ++i)
      {
        sz = sz * dim[i];
      }
      int temp = curr;
      int sz1 = 1;
      for (int i = dim.size() - 1; i >= 0 ; i--)
      {
        if (temp % dim[i] == 0){
          sz1 *= dim[i];
          temp = temp/dim[i];
        }
        else
          break;
      }
      if (sz > sz1)
        sz = sz1;
      if (arrayinitval == NULL)
      {        
        curr += sz;
        return;
      }
      if (arrayinitval)
      {
        arrayinitval->fillinit(dim, a, depth + 1);
        curr = (curr + sz - 1) / sz * sz;
      }
    }
    void fillinit(std::vector<int> dim, std::string ident, int depth) override {
      if (exp)
      {
        std::string src = exp->Dump();
        std::string dst = BaseAST::fetch(dim, ident, curr, dim.size() - 1);
        curr++;
        std::cout << "  store " << src << ", " << dst << std::endl;
        return;
      }
      int sz = 1;
      for (int i = depth; i < dim.size(); ++i)
      {
        sz = sz * dim[i];
      }
      int temp = curr;
      int sz1 = 1;
      for (int i = dim.size() - 1; i >= 0 ; i--)
      {
        if (temp % dim[i] == 0){
          sz1 *= dim[i];
          temp = temp/dim[i];
        }
        else
          break;
      }
      if (sz > sz1)
        sz = sz1;
      if (arrayinitval == NULL)
      {
        for (int i = 0; i < sz; ++i)
        {
          std::string dst = BaseAST::fetch(dim, ident, curr, dim.size() - 1);
          curr++;
          std::cout << "  store " << "0" << ", " << dst << std::endl;
        }
        return;
      }
      if (arrayinitval)
      {
        arrayinitval->fillinit(dim, ident, depth + 1);
        int repeat = (curr + sz - 1) / sz * sz - curr;
        for (int i = 0; i < repeat; ++i)
        {
          std::string dst = BaseAST::fetch(dim, ident, curr, dim.size() - 1);
          curr++;
          std::cout << "  store " << "0" << ", " << dst << std::endl;
        }
      }
    }
};

class VarDefAST:public BaseAST{
public:
    std::string ident;
    std::unique_ptr<BaseAST> arraydef;
    std::unique_ptr<BaseAST> initval;
    std::unique_ptr<BaseAST> vardef;
    std::string Dump() const override{
      if (debug) std::cout << "VarDefAST:" << std::endl;
      if (currentsymbt == NULL)  //global var
      {
        if (arraydef == NULL)    // var
        {
          if (initval == NULL)
          {
            symbt.globalsymbol[ident] = {0, 0, ident + "_00"};
            std::cout << "global @" << ident + "_00" << " = alloc i32, zeroinit" << std::endl;
          }
          else
          {
            int init = initval->Calc();
            symbt.globalsymbol[ident] = {0, init, ident + "_00"};
            std::cout << "global @" << ident + "_00" << " = alloc i32, " << init << std::endl;
          }
        }
        else   // array 
        {
          if (initval == NULL || ((InitValAST *)initval.get())->zeroinit == 1)
          {
            std::string arrdim = arraydef->ArrCalc();
            char * spl = std::strtok((char*)arrdim.c_str(),",");
            std::vector<int> dim;
            while(spl)
            {
              dim.push_back(atoi(spl));
              spl = strtok(NULL, ",");
            }
            symbt.globalsymbol[ident] = {2, (int)dim.size(), ident + "_00"};
            std::cout << "global @" << ident + "_00" << " = alloc " << globalstr << ", zeroinit" << std::endl;
          }
          else
          {
            std::string arrdim = arraydef->ArrCalc();
            char * spl = std::strtok((char*)arrdim.c_str(),",");
            std::vector<int> dim;
            while(spl)
            {
              dim.push_back(atoi(spl));
              spl = strtok(NULL, ",");
            }
            symbt.globalsymbol[ident] = {2, (int)dim.size(), ident + "_00"};
            std::cout << "global @" << ident + "_00" << " = alloc " << globalstr << ", ";
            
            
            int k = 1;
            for (int i = 0; i < dim.size(); ++i)
            {
              k = k * dim[i];
            }
            int * a = new int[k];
            memset(a, 0, sizeof(int) * k);
            curr = 0;
            initval->fillinit(dim, a, 0);
            curr = 0;
            initval->DumpArray(dim, a, 0);
            std::cout << std::endl;
          }
        }
        
      }
      else     // local 
      {
        if (arraydef == NULL)   // var
        {
          if (initval == NULL){
            if (currentsymbt->nameset.count(ident + std::string("_") + std::to_string(currentsymbt->depth)) == 0)
            {
              currentsymbt->nameset.insert(ident + std::string("_") + std::to_string(currentsymbt->depth));
              std::cout<<"  @" << ident << "_" << currentsymbt->depth << " = alloc i32"<< std::endl;
            }
            currentsymbt->smap[currentsymbt->depth][ident] = {0, 0, ident + std::string("_") + std::to_string(currentsymbt->depth)};
            std::cout<<"  store 0, @" << ident << "_" << currentsymbt->depth << std::endl;
          }
          else{
            if (currentsymbt->nameset.count(ident + std::string("_") + std::to_string(currentsymbt->depth)) == 0)
            {
              currentsymbt->nameset.insert(ident + std::string("_") + std::to_string(currentsymbt->depth));
              std::cout<<"  @" << ident << "_" << currentsymbt->depth << " = alloc i32" << std::endl;
            }
            currentsymbt->smap[currentsymbt->depth][ident] = {0, 0, ident + std::string("_") + std::to_string(currentsymbt->depth)};
            initval->Dump();
            std::cout<<"  store %" << now << ", @" << ident << "_" << currentsymbt->depth << std::endl;
          }
        }
        else     //array
        {
          if (initval == NULL)
          {
            if (currentsymbt->nameset.count(ident + std::string("_") + std::to_string(currentsymbt->depth)) == 0)
            {
              currentsymbt->nameset.insert(ident + std::string("_") + std::to_string(currentsymbt->depth));
              std::string arrdim = arraydef->ArrCalc();
              std::cout<<"  @" << ident << "_" << currentsymbt->depth << " = alloc " << globalstr << std::endl;
            }
            std::string arrdim = arraydef->ArrCalc();
            char * spl = std::strtok((char*)arrdim.c_str(),",");
            std::vector<int> dim;
            while(spl)
            {
              dim.push_back(atoi(spl));
              spl = strtok(NULL, ",");
            }
            currentsymbt->smap[currentsymbt->depth][ident] = {2, (int)dim.size(), ident + std::string("_") + std::to_string(currentsymbt->depth)};
          }
          else
          {
            if (currentsymbt->nameset.count(ident + std::string("_") + std::to_string(currentsymbt->depth)) == 0)
            {
              currentsymbt->nameset.insert(ident + std::string("_") + std::to_string(currentsymbt->depth));
              std::string arrdim = arraydef->ArrCalc();
              std::cout<<"  @" << ident << "_" << currentsymbt->depth << " = alloc " << globalstr << std::endl;
              
              char * spl = std::strtok((char*)arrdim.c_str(),",");
              std::vector<int> dim;
              while(spl)
              {
                dim.push_back(atoi(spl));
                spl = strtok(NULL, ",");
              }
              curr = 0;
              initval->fillinit(dim, std::string("@") + ident + "_" + std::to_string(currentsymbt->depth), 0);
              currentsymbt->smap[currentsymbt->depth][ident] = {2, (int)dim.size(), ident + std::string("_") + std::to_string(currentsymbt->depth)};
            }
            else
            {
              std::string arrdim = arraydef->ArrCalc();
              char * spl = std::strtok((char*)arrdim.c_str(),",");
              std::vector<int> dim;
              while(spl)
              {
                dim.push_back(atoi(spl));
                spl = strtok(NULL, ",");
              }
              currentsymbt->smap[currentsymbt->depth][ident] = {2, (int)dim.size(), ident + std::string("_") + std::to_string(currentsymbt->depth)};
            }         
          }
        }        
      }
      if (vardef != NULL)
        vardef->Dump();
      std::string str;
      return str;
    }
};

class VarDeclAST:public BaseAST{
public:
    std::unique_ptr<BaseAST> btype;
    std::unique_ptr<BaseAST> vardef;
    std::string Dump() const override{
      return vardef->Dump();
    }
};

/* Statement */
class StmtAST : public BaseAST
{
public:
  std::unique_ptr<BaseAST> ms;
  std::unique_ptr<BaseAST> ums;
  std::string Dump() const override
  {
    if (ms)
      return ms->Dump();
    else
      return ums->Dump();
  }
};

class MSAST: public BaseAST
{
public:
  int type;
  std::unique_ptr<BaseAST> exp;
  std::unique_ptr<BaseAST> ms;
  std::unique_ptr<BaseAST> ms2;

  std::string Dump() const override
  {
    if (debug) std::cout << "MSAST" << std::endl;
    if (type == 0)    //  ';'   do nothing
    {
      if (currentsymbt->blockend == 0)
      {
        std::cout << "  %" << now + 1 << " = add 0, 0" << std::endl;
        now++;
      }
    }
    if (type == 1)     // Exp ';'
    {
      return exp->Dump();
    }
    else if (type == 2)      //  RETURN ';'
    {
      std::cout << "  ret" << std::endl;
      currentsymbt->blockend = 1;
    }
    else if (type == 3)      // RETURN Exp ';'
    {
      std::string str = exp->Dump();
      std::cout << "  ret " << str << std::endl;
      currentsymbt->blockend = 1;
      return str;
    }
    else if (type == 4)      // LVal '=' Exp ';'
    {
      std::string s0 = exp->Dump();
      ms->assign(s0);
      std::string str;
      return str;
    }
    else if (type == 5)     // Block
    {
      return ms->Dump();
    }
    else if (type == 6)      // IF '(' Exp ')' MS ELSE MS
    {
      int ifcount = IFcount++;
      std::string s0 = exp->Dump();
      std::cout << "  br " << s0 << ", %" << "then_" << ifcount << ", %" << "else_" << ifcount << std::endl;

      std::cout << "%" << "then_" << ifcount << ":" << std::endl;
      currentsymbt->blockend = 0;
      ms->Dump();

      if (currentsymbt->blockend == 0)
      {
        currentsymbt->blockend = 1;
        std::cout << "  jump " << "%" << "end_" << ifcount << std::endl;
      }

      std::cout << "%" << "else_" << ifcount << ":" << std::endl;
      currentsymbt->blockend = 0;
      ms2->Dump();

      if (currentsymbt->blockend == 0)
      {
        currentsymbt->blockend = 1;
        std::cout << "  jump " << "%" << "end_" << ifcount << std::endl;
      }

      std::cout << "%" << "end_" << ifcount << ":" << std::endl;
      currentsymbt->blockend = 0;
    }

    else if (type == 7)      // WHILE '(' Exp ')' MS
    {
      int W = whilecount++;
      currentsymbt->loopstack.push(W);
      std::cout << "  jump %while_entry_" << W << std::endl;
      std::cout << "%while_entry_" << W << ":" << std::endl;
      currentsymbt->blockend = 0;
      std::string s0 = exp->Dump();

      std::cout << "  br " << s0 << ", %while_body_" << W << ", %while_end_" << W << std::endl;

      std::cout << "%while_body_" << W << ":" << std::endl;
      currentsymbt->blockend = 0;

      ms->Dump();

      if (currentsymbt->blockend == 0)
        std::cout << "  jump %while_entry_" << W << std::endl;

      std::cout << "%while_end_" << W << ":" << std::endl;
      currentsymbt->blockend = 0;
      currentsymbt->loopstack.pop();
    }

    else if (type == 8)    // BREAK
    {
      if (currentsymbt->blockend == 0)
      {
        currentsymbt->blockend = 1;
        std::cout << "  jump %while_end_" << currentsymbt->loopstack.top() << std::endl;
      }
    }

    else if (type == 9)    // CONTINUE
    {
      if (currentsymbt->blockend == 0)
      {
        currentsymbt->blockend = 1;
        std::cout << "  jump %while_entry_" << currentsymbt->loopstack.top() << std::endl;
      }
    }

    std::string str;
    return str;
  }
};

class UMSAST: public BaseAST
{
public:
  std::unique_ptr<BaseAST> exp;
  std::unique_ptr<BaseAST> ms;
  std::unique_ptr<BaseAST> ums;

  std::string Dump() const override
  {
    if (ms == NULL)        // WHILE '(' Exp ')' UMS
    {
      int W = whilecount++;
      currentsymbt->loopstack.push(W);

      std::cout << "  jump %while_entry_" << W << std::endl;
      std::cout << "%while_entry_" << W << ":" << std::endl;
      currentsymbt->blockend = 0;
      std::string s0 = exp->Dump();

      std::cout << "  br " << s0 << ", %while_body_" << W << ", %while_end_" << W << std::endl;
      std::cout << "%while_body_" << W << ":" << std::endl;
      currentsymbt->blockend = 0;
      ums->Dump();

      if (currentsymbt->blockend == 0)
        std::cout << "  jump %while_entry_" << W << std::endl;

      std::cout << "%while_end_" << W << ":" << std::endl;
      currentsymbt->blockend = 0;
      currentsymbt->loopstack.pop();
    }

    else if (ums == NULL)      // IF '(' Exp ')' Stmt
    {
      int ifcount = IFcount++;
      std::string s0 = exp->Dump();
      std::cout << "  br " << s0 << ", %" << "then_" << ifcount << ", %" << "end_" << ifcount << std::endl;

      std::cout << "%" << "then_" << ifcount << ":" << std::endl;
      currentsymbt->blockend = 0;
      ms->Dump();

      if (currentsymbt->blockend == 0)
      {
        currentsymbt->blockend = 1;
        std::cout << "  jump " << "%" << "end_" << ifcount << std::endl;
      }

      std::cout << "%" << "end_" << ifcount << ":" << std::endl;
      currentsymbt->blockend = 0;
    }
    else        // IF '(' Exp ')' MS ELSE UMS
    {
      int ifcount = IFcount++;
      std::string s0 = exp->Dump();
      std::cout << "  br " << s0 << ", %" << "then_" << ifcount << ", %" << "else_" << ifcount << std::endl;

      std::cout << "%" << "then_" << ifcount << ":" << std::endl;
      currentsymbt->blockend = 0;
      ms->Dump();

      if (currentsymbt->blockend == 0)
      {
        currentsymbt->blockend = 1;
        std::cout << "  jump " << "%" << "end_" << ifcount << std::endl;
      }

      std::cout << "%" << "else_" << ifcount << ":" << std::endl;
      currentsymbt->blockend = 0;
      ums->Dump();

      if (currentsymbt->blockend == 0)
      {
        currentsymbt->blockend = 1;
        std::cout << "  jump " << "%" << "end_" << ifcount << std::endl;
      }

      std::cout << "%" << "end_" << ifcount << ":" << std::endl;
      currentsymbt->blockend = 0;
    }
    std::string str;
    return str;
  }
};

/* 表达式 */

class NumberAST: public BaseAST
{
public:
  int number;
  std::string Dump() const override
  {
    if (debug) std::cout << "NumberExpAST" << std::endl;
    std::cout << "  %" << ++now;
    std::cout << " = add 0, " << number << std::endl;
    std::string s0 = "%" + std::to_string(now);
    return s0;
  }
  int Calc() override
  {
    return number;
  }
};

class PrimaryExpAST: public BaseAST
{
public:
  std::unique_ptr<BaseAST> num;
  std::unique_ptr<BaseAST> exp;
  std::unique_ptr<BaseAST> lval;
  std::string Dump() const override
  {
    if (debug) std::cout << "PrimaryExpAST" << std::endl;
    if (num)
      return num->Dump();
    else if (exp)
      return exp->Dump();
    else
      return lval->Dump();
  }
  std::string pDump() override
  {
    if (debug)
      std::cout << "PrimaryExpAST" << std::endl;
    if (num)
      return num->Dump();
    else if (exp)
      return exp->Dump();
    else
      return lval->pDump();

  }
  int Calc() override
  {
    if (num)
      return num->Calc();
    else if(exp)
      return exp->Calc();
    else
      return lval->Calc();
  }
};

class UnaryExpAST: public BaseAST
{
public:
  int type;
  std::string op_ident;
  std::unique_ptr<BaseAST> unaryexp_paras;
  std::string Dump() const override
  {
    if (debug) std::cout << "UnaryExpAST" << std::endl;
    if (type == 0)
    {
      return unaryexp_paras->Dump();
    }
    else if (type == 1)
    {
      unaryexp_paras->Dump();
      if (op_ident == "!")
      {
        std::cout << "  %" << now + 1;
        std::cout << " = eq %" << now++ << ", 0" << std::endl;
      }
      else if (op_ident[0] == "-")
      {
        std::cout << "  %" << now + 1;
        std::cout << " = sub 0, %" << now++ << std::endl;
      }
    }
    else if (type == 2)
    {
      if (symbt.globalsymbol[op_ident].type == 3)
      {
        std::cout << "  %" << now + 1 << " = call @" << op_ident << "()" << std::endl;
        now++;
      }
      else
      {
        std::cout << "  call @" << op_ident << "()" << std::endl;
      }
    }
    else if (type == 3)
    {
      std::string s0 = unaryexp_paras->Dump();
      if (symbt.globalsymbol[op_ident].type == 3)
      {
        std::cout << "  %" << now + 1 << " = call @" << op_ident << "(" << s0 << ")" << std::endl;
        now++;
      }
      else
      {
        std::cout << "  call @" << op_ident << "(" << s0 << ")" << std::endl;
      }
    }
    std::string s1 = "%" + std::to_string(now);
    return s1;
  }

  std::string pDump() override
  {
    if (debug)
      std::cout << "UnaryExpAST" << std::endl;
    if (type == 0)
    {
      return unaryexp_paras->pDump();
    }
    else if (type == 1)
    {
      unaryexp_paras->pDump();
      if (op_ident[0] == '!')
      {
        std::cout << "  %" << now + 1;
        std::cout << " = eq %" << now++ << ", 0" << std::endl;
      }
      else if (op_ident[0] == '-')
      {
        std::cout << "  %" << now + 1;
        std::cout << " = sub 0, %" << now++ << std::endl;
      }
    }
    else if (type == 2)
    {
      if (symbt.globalsymbol[op_ident].type == 3)
      {
        std::cout << "  %" << now + 1 << " = call @" << op_ident << "()" << std::endl;
        now++;
      }
      else
      {
        std::cout << "  call @" << op_ident << "()" << std::endl;
      }
    }
    else if (type == 3)
    {
      std::string s0 = unaryexp_paras->pDump();
      if (symbt.globalsymbol[op_ident].type == 3)
      {
        std::cout << "  %" << now + 1 << " = call @" << op_ident << "(" << s0 << ")" << std::endl;
        now++;
      }
      else
      {
        std::cout << "  call @" << op_ident << "(" << s0 << ")" << std::endl;
      }
    }
    std::string s1 = "%" + std::to_string(now);
    return s1;
  }

  int Calc() override
  {
    if (type == 0 || type == 1)
    {
      if (op_ident == "!")
        return !(unaryexp_paras->Calc());
      else if (op_ident == "-")
        return -(unaryexp_paras->Calc());
      else
        return unaryexp_paras->Calc();
    }
    else
    {
      return -1;
    }
  }
};

class MulAST: public BaseAST
{
public:
  std::unique_ptr<BaseAST> mulexp;
  std::string op;
  std::unique_ptr<BaseAST> unaryexp;
  std::string Dump() const override
  {
    if (debug) std::cout << "MulAST" << std::endl;
    if (op == "")
    {
      return unaryexp->Dump();
    }
    if (op == "*")
    {
      std::string l = mulexp->Dump();
      std::string r = unaryexp->Dump();
      std::cout << "  %" << now + 1 << " = mul " << l << ", " << r << std::endl;
      now++;
    }
    else if (op == "/")
    {
      std::string l = mulexp->Dump();
      std::string r = unaryexp->Dump();
      std::cout << "  %" << now + 1 << " = div " << l << ", " << r << std::endl;
      now++;
    }
    else if (op == "%")
    {
      std::string l = mulexp->Dump();
      std::string r = unaryexp->Dump();
      std::cout << "  %" << now + 1 << " = mod " << l << ", " << r << std::endl;
      now++;
    }
    std::string s0 = "%" + std::to_string(now);
    return s0;
  }

  std::string pDump() const override
  {
    if (debug) std::cout << "MulAST" << std::endl;
    if (op == "")
    {
      return unaryexp->pDump();
    }
    if (op == "*")
    {
      std::string l = mulexp->pDump();
      std::string r = unaryexp->pDump();
      std::cout << "  %" << now + 1 << " = mul " << l << ", " << r << std::endl;
      now++;
    }
    else if (op == "/")
    {
      std::string l = mulexp->pDump();
      std::string r = unaryexp->pDump();
      std::cout << "  %" << now + 1 << " = div " << l << ", " << r << std::endl;
      now++;
    }
    else if (op == "%")
    {
      std::string l = mulexp->pDump();
      std::string r = unaryexp->pDump();
      std::cout << "  %" << now + 1 << " = mod " << l << ", " << r << std::endl;
      now++;
    }
    std::string s0 = "%" + std::to_string(now);
    return s0;
  }

  int Calc() override
  {
    if (op == "*")
      return (mulexp->Calc() * unaryexp->Calc());
    else if (op == "/")
      return (mulexp->Calc() / unaryexp->Calc());
    else if (op == "%")
      return (mulexp->Calc() % unaryexp->Calc());
    return unaryexp->Calc();
  }
};

class AddAST: public BaseAST
{
public:
  std::unique_ptr<BaseAST> addexp;
  std::string op;
  std::unique_ptr<BaseAST> mulexp;
  std::string Dump() const override
  {
    if (debug) std::cout << "AddAST" << std::endl;
    if (op == "")
      return mulexp->Dump();
    else if (op == "+")
    {
      std::string l = addexp->Dump();
      std::string r = mulexp->Dump();
      std::cout << "  %" << now + 1 << " = add " << l << ", " << r << std::endl;
      now++;
    }
    else if (op == "-")
    {
      std::string l = addexp->Dump();
      std::string r = mulexp->Dump();
      std::cout << "  %" << now + 1 << " = sub " << l << ", " << r << std::endl;
      now++;
    }
    std::string s0 = "%" + std::to_string(now);
    return s0;
  }

  std::string pDump() const override
  {
    if (debug) std::cout << "AddAST" << std::endl;
    if (op == "")
      return mulexp->pDump();
    else if (op == "+")
    {
      std::string l = addexp->pDump();
      std::string r = mulexp->pDump();
      std::cout << "  %" << now + 1 << " = add " << l << ", " << r << std::endl;
      now++;
    }
    else if (op == "-")
    {
      std::string l = addexp->pDump();
      std::string r = mulexp->pDump();
      std::cout << "  %" << now + 1 << " = sub " << l << ", " << r << std::endl;
      now++;
    }
    std::string s0 = "%" + std::to_string(now);
    return s0;
  }

  int Calc() override
  {
    if(op != "")
    {
      if (op == "+")
        return (addexp->Calc() + mulexp->Calc());
      else if (op == "-")
        return (addexp->Calc() - mulexp->Calc());
    }
    return mulexp->Calc();
  }
};

class RelExpAST: public BaseAST
{
public:
  std::unique_ptr<BaseAST> relexp;
  std::unique_ptr<BaseAST> addexp;
  std::string op;
  std::string Dump() const override
  {
    if (debug)
      std::cout << "RelExpAST" << std::endl;
    if(relexp != NULL)
    {
      std::string l = relexp->Dump();
      std::string r = addexp->Dump();
      if (op == "<=")
        std::cout << "  %" << now + 1 << " = le " << l << ", " << r << std::endl;
      else if (op == ">=")
        std::cout << "  %" << now + 1 << " = ge " << l << ", " << r << std::endl;
      else if (op == "<")
        std::cout << "  %" << now + 1 << " = lt " << l << ", " << r << std::endl;
      else  // (op == ">")
        std::cout << "  %" << now + 1 << " = gt " << l << ", " << r << std::endl;
      now++;
      std::string s0 = "%" + std::to_string(now);
      return s0;
    }
    else
    {
      return addexp->Dump();
    }
  }

  std::string pDump() override
  {
    if (debug)
      std::cout << "RelExpAST" << std::endl;
    if(relexp != NULL)
    {
      std::string l = relexp->pDump();
      std::string r = addexp->pDump();
      if (op == "<=")
        std::cout << "  %" << now + 1 << " = le " << l << ", " << r << std::endl;
      else if (op == ">=")
        std::cout << "  %" << now + 1 << " = ge " << l << ", " << r << std::endl;
      else if (op == "<")
        std::cout << "  %" << now + 1 << " = lt " << l << ", " << r << std::endl;
      else  // (op == ">")
        std::cout << "  %" << now + 1 << " = gt " << l << ", " << r << std::endl;
      now++;
      std::string s0 = "%" + std::to_string(now);
      return s0;
    }
    else
    {
      return addexp->pDump();
    }
  }

  int Calc() override
  {
    if(relexp != NULL)
    {
      if (op == "<=")
        return (relexp->Calc() <= addexp->Calc());
      else if (op == ">=")
        return (relexp->Calc() >= addexp->Calc());
      else if (op == "<")
        return (relexp->Calc() < addexp->Calc());
      else if (op == ">")
        return (relexp->Calc() > addexp->Calc());
    }
    return addexp->Calc();
  }
};

class EqExpAST: public BaseAST
{
public:
  std::unique_ptr<BaseAST> eqexp;
  std::unique_ptr<BaseAST> relexp;
  std::string op;
  std::string Dump() const override
  {
    if (debug)
      std::cout << "EqExpAST" << std::endl;
    if(eqexp != NULL)
    {
      std::string l = eqexp->Dump();
      std::string r = relexp->Dump();
      if (op == "==")
        std::cout << "  %" << now + 1 << " = eq " << l << ", " << r << std::endl;
      else
        std::cout << "  %" << now + 1 << " = ne " << l << ", " << r << std::endl;
      now++;
      std::string s0 = "%" + std::to_string(now);
      return s0;
    }
    else
    {
      return relexp->Dump();
    }
  }

  std::string pDump() override
  {
    if (debug)
      std::cout << "EqExpAST" << std::endl;
    if(eqexp != NULL)
    {
      std::string l = eqexp->pDump();
      std::string r = relexp->pDump();
      if (op == "==")
        std::cout << "  %" << now + 1 << " = eq " << l << ", " << r << std::endl;
      else
        std::cout << "  %" << now + 1 << " = ne " << l << ", " << r << std::endl;
      now++;
      std::string s0 = "%" + std::to_string(now);
      return s0;
    }
    else
    {
      return relexp->pDump();
    }
  }
  int Calc() override
  {
    if(eqexp != NULL)
    {
      if (op == "==")
        return (eqexp->Calc() == relexp->Calc());
      else
        return (eqexp->Calc() != relexp->Calc());
    }
    else
    {
      return relexp->Calc();
    }
  }
};

class LAndExpAST: public BaseAST
{
public:
  std::unique_ptr<BaseAST> eqexp;
  std::unique_ptr<BaseAST> landexp;
  std::string Dump() const override
  {
    if (debug) std::cout << "LAndExpAST" << std::endl;
    if(landexp != NULL)
    {
      // LAndExp "&&" EqExp;
      int ifcount = IFcount++;
      std::string l = landexp->Dump();
      std::cout << "  @int" << ifcount << " = alloc i32" << std::endl;
      std::cout << "  br " << l << ", %" << "then_" << ifcount << ", %" << "else_" << ifcount << std::endl;

      std::cout << "%" << "then_" << ifcount << ":" << std::endl;
      currentsymbt->blockend = 0;
      std::string r = eqexp->Dump();
      std::cout << "  %" << now + 1 << " = ne " << r << ", 0" << std::endl;
      now++;
      std::cout << "  store %" << now << ", @int" << ifcount << std::endl;

      std::cout << "  jump %end_" << ifcount << std::endl;

      std::cout << "%" << "else_" << ifcount << ":" << std::endl;
      currentsymbt->blockend = 0;
      std::cout << "  %" << now + 1 << " = ne " << l << ", 0" << std::endl;
      now++;
      std::cout << "  store %" << now << ", @int" << ifcount << std::endl;

      std::cout << "  jump %end_" << ifcount << std::endl;

      std::cout << "%" << "end_" << ifcount << ":" << std::endl;
      currentsymbt->blockend = 0;
      std::cout << "  %" << ++now << " = load @int" << ifcount << std::endl;
      std::string s0 = "%" + std::to_string(now);
      return s0;
    }
    else
    {
      return eqexp->Dump();
    }
  }

  std::string pDump() override
  {
    if (debug)
      std::cout << "LAndExpAST" << std::endl;
    if(landexp != NULL)
    {
      // LAndExp "&&" EqExp;
      int ifcount = IFcount++;
      std::string l = landexp->pDump();
      std::cout << "  @int" << ifcount << " = alloc i32" << std::endl;

      std::cout << "  br " << l << ", %" << "then_" << ifcount << ", %" << "else_" << ifcount << std::endl;

      std::cout << "%" << "then_" << ifcount << ":" << std::endl;
      currentsymbt->blockend = 0;
      std::string r = eqexp->pDump();
      std::cout << "  %" << now + 1 << " = ne " << r << ", 0" << std::endl;
      now++;
      std::cout << "  store %" << now << ", @int" << ifcount << std::endl;

      std::cout << "  jump %end_" << ifcount << std::endl;

      std::cout << "%" << "else_" << ifcount << ":" << std::endl;
      currentsymbt->blockend = 0;
      std::cout << "  %" << now + 1 << " = ne " << l << ", 0" << std::endl;
      now++;
      std::cout << "  store %" << now << ", @int" << ifcount << std::endl;

      std::cout << "  jump %end_" << ifcount << std::endl;

      std::cout << "%" << "end_" << ifcount << ":" << std::endl;
      currentsymbt->blockend = 0;
      std::cout << "  %" << ++now << " = load @int" << ifcount << std::endl;
      std::string s0 = "%" + std::to_string(now);
      return s0;
    }
    else
    {
      return eqexp->pDump();
    }
  }
  int Calc() override
  {
    if(landexp != NULL)
      return (landexp->Calc() and eqexp->Calc());
    else
      return eqexp->Calc();
  }
};

class LOrExpAST: public BaseAST
{
public:
  std::unique_ptr<BaseAST> lorexp;
  std::unique_ptr<BaseAST> landexp;
  std::string Dump() const override
  {
    if (debug)
      std::cout << "LOrExpAST" << std::endl;
    if(lorexp != NULL)
    {
      int ifcount = IFcount++;
      // LOrExp "||" LAndExp;

      std::string l = lorexp->Dump();
      std::cout << "  @int" << ifcount << " = alloc i32" << std::endl;
      std::cout << "  br " << l << ", %" << "then_" << ifcount << ", %" << "else_" << ifcount << std::endl;

      std::cout << "%" << "then_" << ifcount << ":" << std::endl;
      currentsymbt->blockend = 0;
      std::cout << "  %" << ++now << " = ne " << l << ", 0" << std::endl;
      std::cout << "  store %" << now << ", @int" << ifcount << std::endl;

      std::cout << "  jump %end_" << ifcount << std::endl;

      std::cout << "%" << "else_" << ifcount << ":" << std::endl;
      currentsymbt->blockend = 0;
      std::string r = landexp->Dump();
      std::cout << "  %" << now + 1 << " = ne " << r << ", 0" << std::endl;
      now++;
      std::cout << "  store %" << now << ", @int" << ifcount << std::endl;

      std::cout << "  jump %end_" << ifcount << std::endl;

      std::cout << "%" << "end_" << ifcount << ":" << std::endl;
      currentsymbt->blockend = 0;
      std::cout << "  %" << ++now << " = load @int" << ifcount << std::endl;
      std::string s1 = "%" + std::to_string(now);
      return s1;
    }
    else
    {
      return landexp->Dump();
    }
  }

  std::string pDump() override
  {
    if (debug)
      std::cout << "LOrExpAST" << std::endl;
    if(lorexp != NULL)
    {
      int ifcount = IFcount++;
      // LOrExp "||" LAndExp;
      std::string l = lorexp->pDump();
      std::cout << "  @int" << ifcount << " = alloc i32" << std::endl;
      std::cout << "  br " << l << ", %" << "then_" << ifcount << ", %" << "else_" << ifcount << std::endl;

      std::cout << "%" << "then_" << ifcount << ":" << std::endl;
      currentsymbt->blockend = 0;
      std::cout << "  %" << ++now << " = ne " << l << ", 0" << std::endl;
      std::cout << "  store %" << now << ", @int" << ifcount << std::endl;

      std::cout << "  jump %end_" << ifcount << std::endl;

      std::cout << "%" << "else_" << ifcount << ":" << std::endl;
      currentsymbt->blockend = 0;
      std::string r = landexp->pDump();
      std::cout << "  %" << now + 1 << " = ne " << r << ", 0" << std::endl;
      now++;
      std::cout << "  store %" << now << ", @int" << ifcount << std::endl;

      std::cout << "  jump %end_" << ifcount << std::endl;

      std::cout << "%" << "end_" << ifcount << ":" << std::endl;
      currentsymbt->blockend = 0;
      std::cout << "  %" << ++now << " = load @int" << ifcount << std::endl;
      std::string s1 = "%" + std::to_string(now);
      return s1;
    }
    else
    {
      return landexp->pDump();
    }
  }

  int Calc() override
  {
    if(lorexp != NULL)
      return (lorexp->Calc() or landexp->Calc());
    else
      return landexp->Calc();
  }
};

class ExpAST: public BaseAST
{
public:
  std::unique_ptr<BaseAST> lorexp;
  std::string Dump() const override
  {
    return lorexp->Dump();
  }
  std::string pDump() override
  {
    return lorexp->pDump();
  }
  int Calc() override
  {
    return lorexp->Calc();
  }
};







