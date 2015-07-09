/**************************
  *  BoardGameOne files   *
  *  (c) John Derry 2015  *
 **************************/
library standardobjects;

import 'bufferedhtmlio.dart';
import 'interpreter.dart';

class ExprStackElem {
  static int
    OPERATOR  = 1,
    UNARY     = 2,
    VALUE     = 3,
    STRING    = 4;
  int type;
  int operator, precedence;
  num value;
  String string;
  
  ExprStackElem(this.type, {int operator:0 , int precedence:-1, num value:0, String string:null} ) {
    this.operator = operator;
    this.precedence = precedence;
    this.value = value;
    this.string = string;
  }
}

class StandardObjects {
  
  static const 
    EOF = -1, WAIT = -2, ERROR  = -3,
    CONTROL_END = 1, CONTROL_ELSE = 2;
  static final Map<int,String> ErrorMap = 
    {ERROR:'Error',WAIT:'Wait',EOF:'Eof',0:'None',CONTROL_END:'ControlEnd',CONTROL_ELSE:'ControlElse'};
  static const
    PARENPREC = 0,
    ANDORPREC = 1,
    COMPAREPREC = 2,
    ADDSUBTPREC = 3,
    MULTDIVPREC = 4,
    UNARYPREC   = 5;
  
  static final Map additional_help = {
    'general':  general_help,
    'quoting':  quoting_help,
    'naming':   naming_help,
    'expression': expression_help,
    'methods':  methods_help
  };
  
  CharBuffer  _conbuf, _srcbuf;
  MandyInterpreter  interp;
  ObjectDictionary  referals;
  
  Map<String,ObjectEntry> dictmap = new Map<String,ObjectEntry>();
  
  /*****************************
   * Support Routines
   *****************************/
  
  bool reduce( List <ExprStackElem> stack, int prec ) {
    // check for a stack reduction possible.
    // if there are at least three items on the stack,
    // compare passed precedence with stack operator precedence.
    // if the passed precedence is equal or lower, perform the reduction
    // and reduce the value/operator/value on top to a value 
    
    ExprStackElem elem, op;
    bool performed = false;
    
    while( stack.length >= 3 && prec <= stack[stack.length-2].precedence ) {
      // make a reduction
      performed = true;
      elem = stack.removeLast();
      op = stack.removeLast();
      switch( op.operator ) {
        case TokenLexer.ADD: stack[stack.length-1].value = 
            stack[stack.length-1].value + elem.value;
        break;
        case TokenLexer.SUBTRACT: stack[stack.length-1].value = 
            stack[stack.length-1].value - elem.value;
        break;
        case TokenLexer.MULTIPLY: stack[stack.length-1].value = 
            stack[stack.length-1].value * elem.value;
        break;
        case TokenLexer.DIVIDE: stack[stack.length-1].value = 
            stack[stack.length-1].value / elem.value;
        break;
        case TokenLexer.AND: 
          if( stack[stack.length-1].value > 0 && elem.value > 0 )
            stack[stack.length-1].value = 1;
          else stack[stack.length-1].value = 0;
        break;
        case TokenLexer.OR:
          if( stack[stack.length-1].value > 0 || elem.value > 0 )
            stack[stack.length-1].value = 1;
          else stack[stack.length-1].value = 0;
        break;
        case TokenLexer.LESSTHAN:
          if( stack[stack.length-1].value < elem.value )
            stack[stack.length-1].value = 1;
          else stack[stack.length-1].value = 0;
        break;
        case TokenLexer.LESSTHANOREQUAL:
          if( stack[stack.length-1].value <= elem.value )
            stack[stack.length-1].value = 1;
          else stack[stack.length-1].value = 0;
        break;
        case TokenLexer.GREATERTHAN:
          if( stack[stack.length-1].value > elem.value )
            stack[stack.length-1].value = 1;
          else stack[stack.length-1].value = 0;
        break;
        case TokenLexer.LESSTHANOREQUAL:
          if( stack[stack.length-1].value <= elem.value )
            stack[stack.length-1].value = 1;
          else stack[stack.length-1].value = 0;
        break;
        case TokenLexer.EQUAL:
          if( stack[stack.length-1].value == elem.value )
            stack[stack.length-1].value = 1;
          else stack[stack.length-1].value = 0;
        break;
        case TokenLexer.NOTEQUAL:
          if( stack[stack.length-1].value != elem.value )
            stack[stack.length-1].value = 1;
          else stack[stack.length-1].value = 0;
        break;
        
      }
    }
    
    return performed;
  }
  
  num expression( TokenLexer lexer ) {
    // parse an expression up to closing paren or newline and return value  
    // create a new tokenlexer object for this source
    
    List<ExprStackElem> stack = new List<ExprStackElem>();
    int token, depth = 0;

    token = lexer.nexttoken();
    while( token != TokenLexer.ENDOFINPUT && token != TokenLexer.NAME ) {
      
      switch( token ) {
        case TokenLexer.OBJECT:
          ObjectEntry obj;
          num value;
          if((obj = referals.locate(lexer.name)) != null) {
            
            if( obj.dict != null && lexer.scanchar == TokenLexer.period ) {
              // there's a dictionary and property/method, grab it
              token = lexer.nexttoken();
              token = lexer.nexttoken();
              if( token != TokenLexer.NAME ) {
                _srcbuf.webcon.writeln('WARNING: Expecting method name, found "${lexer.lastscanchar}');
                continue;            
              }
              ObjectEntry e = referals.locate_from( obj.dict, lexer.name);   
              if( e == null ) {
                _srcbuf.webcon.writeln('ERROR: unrecognized method "${lexer.name}"');
                continue;
                }
              if( e.value != null ) {
                // use the input method.
                if( interp.verbosity > MandyInterpreter.VERBOSE_MED )
                  _srcbuf.webcon.writeln('INFO: "${obj.name}.${e.name}" recognized, calling value method');
                
                lexer.clearscan();
                referals.changedepth(1);
                referals.dictmap = obj.dict;
                value = e.value( e.dict, e.data );
                referals.changedepth(-1);
              } else 
                _srcbuf.webcon.writeln('ERROR: no value method for "${lexer.name}"');
            } else             
            if( obj.value != null ) {
              value = obj.value( obj.dict, obj.data );
              stack.add(new ExprStackElem(ExprStackElem.VALUE, value: value));   
            }
          } else {
            _srcbuf.webcon.writeln('ERROR: can\'t locate object "${lexer.name}"');      
            return -2;
          }         
          break;
        case TokenLexer.NUMERIC:
          stack.add(new ExprStackElem(ExprStackElem.VALUE, value: lexer.value));
          break;
        case TokenLexer.LEFTPAREN:
          stack.add(new ExprStackElem(ExprStackElem.OPERATOR, operator:TokenLexer.LEFTPAREN, precedence:PARENPREC));
          break;
        case TokenLexer.RIGHTPAREN:
          // check for stack reduction first
          reduce(stack, PARENPREC );
          if( stack.length == 0 )
            // empty expression, return 0
            return 0;
          if( stack.length == 1 ) {
            if( stack[0].type == ExprStackElem.OPERATOR ) {
              _srcbuf.webcon.writeln('syntax error at "${lexer.lastscanchar}": missing value');
              return 0;
              }
            else {
              // this is the closing paren, return stack value
              return stack[0].value;
            }
          }
          // stack.length >= 2
          // make sure there is left paren at the right position
          ExprStackElem elem =  stack[stack.length-2];
          if( elem.type == ExprStackElem.OPERATOR && elem.operator == TokenLexer.LEFTPAREN ) {
            // remove paren from stack and shift value left 
            var v = stack.removeLast();
            stack[stack.length-1] = v;
          } else {
            _srcbuf.webcon.writeln('syntax error at "${lexer.lastscanchar}":not a value between ()');
            return 0;
          }
          break;
        case TokenLexer.LESSTHAN:
          reduce(stack, COMPAREPREC );
          stack.add(new ExprStackElem(ExprStackElem.OPERATOR, operator:TokenLexer.LESSTHAN, precedence:COMPAREPREC));
          break;
        case TokenLexer.GREATERTHAN:
          reduce(stack, COMPAREPREC );
          stack.add(new ExprStackElem(ExprStackElem.OPERATOR, operator:TokenLexer.GREATERTHAN, precedence:COMPAREPREC));
          break;
        case TokenLexer.LESSTHANOREQUAL: 
          reduce(stack, COMPAREPREC );
          stack.add(new ExprStackElem(ExprStackElem.OPERATOR, operator:TokenLexer.LESSTHANOREQUAL, precedence:COMPAREPREC));
          break;
        case TokenLexer.GREATERTHANOREQUAL:
          reduce(stack, COMPAREPREC );
          stack.add(new ExprStackElem(ExprStackElem.OPERATOR, operator:TokenLexer.GREATERTHANOREQUAL, precedence:COMPAREPREC));
          break;
        case TokenLexer.EQUAL:
          reduce(stack, COMPAREPREC );
          stack.add(new ExprStackElem(ExprStackElem.OPERATOR, operator:TokenLexer.EQUAL, precedence:COMPAREPREC));
          break;
        case TokenLexer.NOTEQUAL:
          reduce(stack, COMPAREPREC );
          stack.add(new ExprStackElem(ExprStackElem.OPERATOR, operator:TokenLexer.NOTEQUAL, precedence:COMPAREPREC));
          break;
        case TokenLexer.MULTIPLY:
          reduce(stack, MULTDIVPREC );
          stack.add(new ExprStackElem(ExprStackElem.OPERATOR, operator:TokenLexer.MULTIPLY, precedence:MULTDIVPREC));
          break;
        case TokenLexer.DIVIDE:
          reduce(stack, MULTDIVPREC );
          stack.add(new ExprStackElem(ExprStackElem.OPERATOR, operator:TokenLexer.DIVIDE, precedence:MULTDIVPREC));
          break;
        case TokenLexer.ADD:
          reduce(stack, ADDSUBTPREC );
          stack.add(new ExprStackElem(ExprStackElem.OPERATOR, operator:TokenLexer.ADD, precedence:ADDSUBTPREC));
          break;
        case TokenLexer.SUBTRACT:
          if( stack.length > 0 || stack[stack.length-1].type == ExprStackElem.OPERATOR ) {
            // unary operator
            stack.add(new ExprStackElem(ExprStackElem.UNARY, operator:TokenLexer.SUBTRACT, precedence:UNARYPREC));
            break;
          } // else binary operator
          reduce(stack, ADDSUBTPREC );
          stack.add(new ExprStackElem(ExprStackElem.OPERATOR, operator:TokenLexer.SUBTRACT, precedence:ADDSUBTPREC));
          break;
        case TokenLexer.AND:
          reduce(stack, ANDORPREC );
          stack.add(new ExprStackElem(ExprStackElem.OPERATOR, operator:TokenLexer.AND, precedence:ANDORPREC));
          break;
        case TokenLexer.OR:     
          reduce(stack, ANDORPREC );
          stack.add(new ExprStackElem(ExprStackElem.OPERATOR, operator:TokenLexer.OR, precedence:ANDORPREC));
          break;
        case TokenLexer.NOT:
          if( stack.length > 0 || stack[stack.length-1].type == ExprStackElem.OPERATOR ) {
            // unary operator
            stack.add(new ExprStackElem(ExprStackElem.UNARY, operator:TokenLexer.NOT, precedence:UNARYPREC));
            break;
          }
          _srcbuf.webcon.writeln('syntax error at "${lexer.lastscanchar}":NOT not a unary operator');
          break;
        
      }
      token = lexer.nexttoken();
    }
    
    // if we ended with a name, return it
    if( token == TokenLexer.NAME )
      lexer.returnname();
    
    // ended with a name or eof. Look for legitimate value
    reduce( stack, PARENPREC );
    if( stack.length == 1 ) {
      if( stack[0].type == ExprStackElem.OPERATOR ) {
        _srcbuf.webcon.writeln('syntax error at "${lexer.lastscanchar}": missing value');
        return 0;
        }
      else {
        // this is the closing paren, return stack value
        return stack[0].value;
      }
    }
    // any stack elements left is an error
    else if( stack.length != 0 ) 
      _srcbuf.webcon.writeln('expression syntax error at "${lexer.lastscanchar}"');

    return 0;
    }
        
  int expandbuffer( CharBuffer buffer, int scanpos ) {
    //
    // expand the buffer for any substitutions and expressions
    //
    int retcode, c, spos, searchlen, searchlen2;
    String searchname;
    ObjectEntry obj, e;
    
    retcode = 0;
    while( scanpos < buffer.length ) {
      
      // move scanpos foward until substitution character or left paren
      while( scanpos < buffer.length && 
          (c = buffer[scanpos]) != TokenLexer.substitute && c != TokenLexer.leftparen) scanpos++;
      
      if( scanpos >= buffer.length ) continue;
      
      if( c == TokenLexer.substitute ) {
        
        spos = scanpos + 1;
        searchlen = 0;
        // locate end of substitution string
        while( spos + searchlen < buffer.length && 
            !TokenLexer.terminators.contains(buffer[spos+searchlen]))
          searchlen++;
        
        if( searchlen > 0 ) {
          Iterable range = buffer.getRange(spos, spos+searchlen);
          searchname = new String.fromCharCodes(range);
          if((obj = referals.locate(searchname)) != null) {
            
            if( obj.dict != null && spos + searchlen < buffer.length &&
                buffer[spos+searchlen] == TokenLexer.period ) {
              // there's a dictionary and property/method, grab it
              searchlen2 = 0; spos = spos + searchlen + 1;
              while( spos + searchlen2 < buffer.length && 
                  !TokenLexer.terminators.contains(buffer[spos+searchlen2]))
                searchlen2++;
              range = buffer.getRange(spos, spos+searchlen2);
              searchname = new String.fromCharCodes(range);
              ObjectEntry e = referals.locate_from( obj.dict, searchname );   
              if( e == null ) {
                _srcbuf.webcon.writeln('ERROR: unrecognized method "${searchname}"');
                continue;
                }
              if( e.output != null ) {
                // use the output method.
                if( interp.verbosity > MandyInterpreter.VERBOSE_MED )
                  _srcbuf.webcon.writeln('INFO: object.method "${obj.name}.${e.name}" expanded');
                buffer.removeRange(scanpos, spos+searchlen2);
                referals.changedepth(1);
                referals.dictmap = obj.dict;
                retcode = e.output( e.dict, e.data, buffer, scanpos );
                referals.changedepth(-1);
                if( retcode == CharBuffer.WAIT ) return retcode;
              } else 
                _srcbuf.webcon.writeln('ERROR: no input method for "${e.name}"');
            } else if( obj.output != null ) {
              buffer.removeRange(scanpos, spos+searchlen);
              
              if( interp.verbosity > MandyInterpreter.VERBOSE_MED )
                _srcbuf.webcon.writeln('INFO: object "${obj.name} expanded');
              
              if( (retcode = obj.output(obj.dict, obj.data, buffer, scanpos )) == CharBuffer.WAIT )
                return retcode;
            }
          }
        } else _srcbuf.webcon.writeln('ERROR: Can\'t expand: ${searchname}');
        
      } else if( c == TokenLexer.leftparen ) {
        
        TokenLexer lexer = new TokenLexer( buffer );
        buffer.currentpos = scanpos;
        buffer.getchar();     // throw out left paren
        num value = expression( lexer );
        buffer.insertchars( value.toString().codeUnits );
        buffer.currentpos = 0;
      }
    
    }
    
    return retcode;
  }
  
  /************************************************************
   * PREDEFINED SIMPLE OBJECTS                                *
   * accept, echo, help, list, call, break, verbose, compare  *
   ************************************************************/

  /*
   * Here are the predefined object methods. 
   *
   * The simplist Objects have only two basic methods: input and output.
   *
   * The input method is called *_input() and
   * accepts source buffer and the instance data object,
   * and returns an integer error:
   *   = -3 : fatal error
   *   = -2 : input wait condition
   *   = -1 : EOF on input
   *   = 0  : NO error
   *   > 0  : informational or warning
   *
   * The output has two forms *_output() and *_value()
   * _output accepts the ObjectEntry object, instance data object, a 
   *   CharBuffer buffer object, an insert index, and returns a CharBuffer object.
   * _value  accepts ObjectEntry object and instance data object, 
   *   and returns a numeric value.
   */
  
  /*
   * accept
   */

  static const String accept_help = '''
The Accept object is used to accept a line of input from the player.
It is generally invoking inside a routine and the result is assigned to
a Text object.\
In an assignment it's refered to as \$accept, and will cause Mandy to wait
for a line of input text.
''';
  
  int accept_input(CharBuffer source, Map<String,ObjectEntry> dictmap, ObjectData data, String help ) {

    int tok;
    ObjectEntry e;
    
    // create a lexer for method's use and look for help
    TokenLexer lexer = new TokenLexer( source );

    if( (tok = lexer.nexttoken()) == TokenLexer.HELP ) {
      _conbuf.addAll(help.codeUnits);
      _conbuf.deliver();
    }    

    else if( tok == TokenLexer.OBJECT || tok == TokenLexer.NAME ) {
     
      if( (e = referals.locate(lexer.name)) == null ) {
        _srcbuf.webcon.writeln('ERROR: unknown object: "${lexer.name}"');
        return ERROR;
      } else if( e.type != ObjectEntry.TEXT ) { 
        _srcbuf.webcon.writeln('ERROR: object "${lexer.name}" not a text object');
        return ERROR;
      } else {
        int char;
        CharBuffer buffer = new CharBuffer( null );
        while( (char = _conbuf.getchar()) > 0 && char != TokenLexer.newline )
          buffer.add( char );
        if( char == CharBuffer.WAIT ) return char;
        if( buffer.length > 0 )
          e.data.buffer = buffer;
      }
    }        

    return 0;  
  }

  int accept_output(ObjectEntry e, ObjectData data, CharBuffer buffer, int pos ) {
    
    int char;
    while( (char = _conbuf.getchar()) > 0 && char != TokenLexer.newline )
      buffer.insert( pos++, char );
    if( char == CharBuffer.WAIT ) return char;
    return 0;
  }
  
  /*
   * echo
   */
  
  static const String echo_help = '''
The Echo object is used to display text and values to the player.
It will echo the next token on the input line, substituting any
object references for the contents of the object. Object references
are the name of the object preceded by the dollar sign (\$).
Text can be quoted with single (') or double (") quotes.
See help on 'quoting' for more information on quoting in Mandy.
''';  
  
  int echo_input(CharBuffer source, Map<String,ObjectEntry> dictmap, ObjectData data, String help ) {

    num value;
    int tok, retval = 0;
    
    // create a lexer for method's use and look for help
    TokenLexer lexer = new TokenLexer( source );

    if( (tok = lexer.nexttoken()) == TokenLexer.HELP ) 
      _conbuf.addAll(help.codeUnits);  
    
    else if( tok == TokenLexer.STRING ) {
      // token is a quoted string
      if( lexer.quotechar == TokenLexer.doublequote ) 
        if( expandbuffer( lexer.string, 0 ) == CharBuffer.WAIT ) 
          return CharBuffer.WAIT;
      _conbuf.addAll( lexer.string );
    }
    
    else if( tok == TokenLexer.LEFTPAREN ) {
      // token is a numeric expression
      value = expression( lexer );
      _conbuf.addAll( value.toString().codeUnits );
    }
    
    else if( tok == TokenLexer.OBJECT ) {
      ObjectEntry obj;
      if((obj = referals.locate(lexer.name)) == null) {
        _srcbuf.webcon.writeln('ERROR: can\'t locate object "${lexer.name}"');      
        return ERROR;
      }
      if( obj.dict != null && lexer.scanchar == TokenLexer.period ) {
        // there's a dictionary and property/method, grab it
        lexer.nexttoken();
        int tok = lexer.nexttoken();
        if( tok != TokenLexer.NAME ) {
          _srcbuf.webcon.writeln('ERROR: Expecting method name, found "${lexer.lastscanchar}');
          return ERROR;            
        }
        ObjectEntry e = referals.locate_from( obj.dict, lexer.name);   
        if( e == null ) {
          _srcbuf.webcon.writeln('ERROR: unrecognized method "${lexer.name}"');
          return ERROR;
          }
        if( e.output != null ) {
          // use the output method.
          if( interp.verbosity > MandyInterpreter.VERBOSE_MED )
            _srcbuf.webcon.writeln('INFO: "${obj.name}.${e.name}" recognized, calling output method');
          
          CharBuffer buffer = new CharBuffer( null );
          referals.changedepth(1);
          referals.dictmap = obj.dict;
          retval = e.output( e.dict, e.data, buffer, 0 );
          referals.changedepth(-1);
          _conbuf.addAll( buffer.innerList );
        } else 
          _srcbuf.webcon.writeln('ERROR: no input method for "${lexer.name}"');
      }
      else if( obj.output != null ) {
        if( interp.verbosity > MandyInterpreter.VERBOSE_MED )
          _srcbuf.webcon.writeln('INFO: "${obj.name} recognized, calling output method');
        
        CharBuffer buffer = new CharBuffer( null );
        if( (retval = obj.output(obj.dict, obj.data, buffer, 0 )) == CharBuffer.WAIT )
          return retval;
        _conbuf.addAll( buffer.innerList );

      } else {
        _srcbuf.webcon.writeln('ERROR: no output method for "${lexer.name}"');                
        return ERROR;
      }
    } 
    else if( tok == TokenLexer.NAME ) 
      switch( lexer.name ) {
        case 'clear': _conbuf.webcon.clear(); break;
        case 'newline': _conbuf.addAll('<br>'.codeUnits); break;
        default:
          _srcbuf.webcon.writeln('WARNING: command for echo expected, found "${lexer.name}"');      
    }
      //_conbuf.addAll( lexer.name.codeUnits );
    else {
      _srcbuf.webcon.writeln('ERROR: expecting something to echo, found "${lexer.lastscanchar}"');      
      return ERROR;
    }
    
    _conbuf.deliver();
    return 0;  
  }

 /*
  * help
  */
  
  static const String help_help = '''
The Help object will offer help on the next list of tokens which follow.
These can be object names, like 'help', or an additional topic if available.
Help offerered for objects is the same as using ? with the object itself.
Besides objects, Help offers help on topics: quoting, expressions, naming,
methods, predefined, as well as 'all'.
''';

  int help_input(CharBuffer source, Map<String,ObjectEntry> dictmap, ObjectData data, String help ) {
   
    int     tok;
    String  addhelp;
    ObjectEntry oe;
    List<String> names;
    
    // create a lexer for method's use and look for help
    TokenLexer lexer = new TokenLexer( source );

    if( (tok = lexer.nexttoken()) == TokenLexer.HELP ) 
      _conbuf.addAll(help.codeUnits);
    
    else if( (names = lexer.getnames(tok)) != null ){
      // _srcbuf.webcon.write('looking for help on: ');
      // try to get help on each name token on the source line
      for( var n in names ) {
        //_srcbuf.webcon.write('${lexer.name} ');
        if( referals != null && (oe = referals.locate(n)) != null )
          _conbuf.addAll(oe.help.codeUnits);
        else if( (addhelp = additional_help[n]) != null )
          _conbuf.addAll(addhelp.codeUnits);        
      }
    }
    
    _conbuf.deliver();
    return 0;
  }

/*
 * list
 */
  
  static const String list_help = '''
The list object will provide a list of objects in the dictionarie(s).
Used alone it will show objects from all dictionary levels. Levels
increase when Routine-created objects are called with the Call object.
When a numeric expression is provided, only dictionaries from that level
or greater are shown. Level 0 contains all language objects, and level 1
and greater contain all created objects.
''';
  
  int list_input(CharBuffer source, Map<String,ObjectEntry> dictmap, ObjectData data, String help ) {

    int     tok, startlevel;
    String  out;
    
    // create a lexer for method's use and look for help
    TokenLexer lexer = new TokenLexer( source );

    if( (tok = lexer.nexttoken()) == TokenLexer.HELP ) {
      _conbuf.addAll(help.codeUnits);
      _conbuf.deliver();
      return 0;
    }
    if( tok == TokenLexer.LEFTPAREN )
      startlevel = expression( lexer );
    else if( tok == TokenLexer.NUMERIC )
      startlevel = lexer.value;
    
    
    if( startlevel == null ) {
      _srcbuf.webcon.writeln('ERROR: bad level expression  at "${lexer.lastscanchar}"');
      return ERROR;
    }
    
    for( var i = startlevel; i >= 0; i-- ) {
      _conbuf.addAll(i.toString().codeUnits);
      _conbuf.addAll(': '.codeUnits); 
      out = referals.list(i);
      if( out != null ) _conbuf.addAll(out.codeUnits);
      _conbuf.addAll('<br>'.codeUnits);
    }
    _conbuf.deliver();
    
    return 0;  
  }

  int list_output(Map<String,ObjectEntry> dictmap, ObjectData data, CharBuffer buffer, int pos ) {
    String list = referals.list(referals.depth);
    buffer.insertAll(pos, list.codeUnits );
    return 0;
  }
  
  num list_value(Map<String,ObjectEntry> dictmap, ObjectData data ) {
    return referals.count(-1);
  }
  
  /*
   * call
   */
  
  static const String call_help = '''
The Call object is used to invoke a stored routine.
Following the Call object should be the name of an object
which has been previously created with the Routine object.
''';

  int call_input(CharBuffer source, Map<String,ObjectEntry> dictmap, ObjectData data, String help ) {

    int tok;
    ObjectEntry obj;
    CharBuffer  buffer;
    
    // create a lexer for method's use and look for help
    TokenLexer lexer = new TokenLexer( source );

    if( (tok = lexer.nexttoken()) == TokenLexer.HELP ) {
      _conbuf.addAll(help.codeUnits);
      _conbuf.deliver();
    }
    else if( tok != TokenLexer.NAME ) {
      _srcbuf.webcon.writeln('ERROR: Expecting object name, found "${lexer.lastscanchar}');
      return ERROR;
      }
    else if( (obj = referals.locate(lexer.name)) == null ) {
      source.webcon.writeln('ERROR: unknown object ${lexer.name}');
      return ERROR;
      }
    else {
      if( obj.dict != null && lexer.scanchar == TokenLexer.period ) {
        // there's a dictionary and property/method, grab it
        lexer.nexttoken();
        int tok = lexer.nexttoken();
        if( tok != TokenLexer.NAME ) {
          _srcbuf.webcon.writeln('ERROR: Expecting method name, found "${lexer.lastscanchar}');
          return ERROR;            
        }
        ObjectEntry e = referals.locate_from( obj.dict, lexer.name);   
        if( e == null ) {
          _srcbuf.webcon.writeln('ERROR: unrecognized method "${lexer.name}"');
          return ERROR;
          }
        if( e.type == ObjectEntry.TEXT ) {

          if( interp.verbosity > MandyInterpreter.VERBOSE_LOW ) 
            source.webcon.writeln('INFO: call ${lexer.name}'); 

          buffer = new CharBuffer( source.webcon );
          buffer.allowinput = false;        
          e.output( e.dict, e.data, buffer, 0 );
          
          referals.changedepth(1);
          referals.dictmap = obj.dict;
          // still call the routine in it's local depth
          referals.changedepth(1);
          interp.interpret( buffer );
          referals.changedepth(-2);
        } else {
          source.webcon.writeln('ERROR: method ${lexer.name} is not a routine'); 
          return ERROR;
        }
      } else if( obj.type == ObjectEntry.TEXT ) {

        if( interp.verbosity > MandyInterpreter.VERBOSE_LOW ) 
          source.webcon.writeln('INFO: call ${lexer.name}'); 

        buffer = new CharBuffer( source.webcon );
        buffer.allowinput = false;        
        obj.output( obj.dict, obj.data, buffer, 0 );
        
        referals.changedepth(1);
        interp.interpret( buffer );
        referals.changedepth(-1);
      } else {
        source.webcon.writeln('WARNING: call argument ${lexer.name} is not a routine');
        return ERROR;
        }
    } 
    
    return 0;  
  }
  
  /*
   * verbose
   */
  
  static const String verbose_help = '''
The Verbose object is used to control the level of verbosity, which is
the level information that Mandy provides as it interprets instructions.
The Verbose object acts just like a object created by Value and takes
the same methods: =, + and -.
The value of verbosity can be numeric from 0 to 4.
''';
  
  int verbose_input(CharBuffer source, Map<String,ObjectEntry> dictmap, ObjectData data, String help ) {

    num value = null;
    int tok;
    
    // create a lexer for method's use and look for help
    TokenLexer lexer = new TokenLexer( source );

    if( (tok = lexer.nexttoken()) == TokenLexer.HELP ) {
      _conbuf.addAll(help.codeUnits);
      _conbuf.deliver();
      return 0;
    }  
    
    if( tok == TokenLexer.EQUAL ) {
      
      tok = lexer.nexttoken();
      if( tok == TokenLexer.NUMERIC ) {
        value = lexer.value;
      } else if( tok == TokenLexer.LEFTPAREN ) {
        // token is a numeric expression
        value = expression( lexer );
      }
    }

    else {
      _srcbuf.webcon.writeln('Expecting "=" but found "${lexer.lastscanchar}"');
      return ERROR;
    }
      
    if( value != null )
      interp.verbosity = value;
    else {
      _srcbuf.webcon.writeln('Expecting verbose value but found "${lexer.lastscanchar}"');
      return ERROR;
    }
    
    return 0;  
  }

  int verbose_output(Map<String,ObjectEntry> dictmap, ObjectData data, CharBuffer buffer, int pos ) {
    buffer.insertAll( pos, interp.verbosity.toString().codeUnits );
    return 0;
  }
  
  int verbose_value(Map<String,ObjectEntry> dictmap, ObjectData data ) {
    return interp.verbosity;
  }
  /*
   * break
   */
  
  static const String break_help = '''
The Break object is used to interupt interpretation of the current stream
and enter an interactive Mandy state. Whatever follows on the input line
is passed to the interpreter and interpeted before any other input.
To return to the previous interupted state use the End object.
''';  
  
  int break_input(CharBuffer source, Map<String,ObjectEntry> dictmap, ObjectData data, String help ) {

    int tok, returncode;
    
    // create a lexer for method's use and look for help
    TokenLexer lexer = new TokenLexer( source );

    if( (tok = lexer.nexttoken()) == TokenLexer.HELP ) {
      _conbuf.addAll(help.codeUnits);
      _conbuf.deliver();
    }    
    else if( tok == TokenLexer.NAME )
      lexer.returnname();

    if( interp != null ) {
      _srcbuf.webcon.writeln('breaking to mandy interpreter');
      returncode = interp.interpret( source );
      if( returncode != CharBuffer.WAIT )
        _srcbuf.webcon.writeln('break returning from interpreter with code ${returncode}');
      return returncode;
      }
    
    return 0;
   }

  /*
   * compare
   */
    
  static const String compare_help = '''
  The compare object will compare two objects and return the relationship as a value.
  When the two objects are text objects, compare will perform alphabetic sorting. 
  Compare is first used with the two objects supplied on the input line as arguments.
  Then compare is referenced in an exression or in a value object assignment. The value 
  of compare will be -1, 0, or 1 depending on whether the first object is alphabetically 
  less than, the same as, or greater than the second object.
  ''';
    
  int compare_input(CharBuffer source, Map<String,ObjectEntry> dictmap, ObjectData data, String help ) {

    int         tok;
    CharBuffer  arg1, arg2;
    
    // create a lexer for method's use and look for help
    TokenLexer lexer = new TokenLexer( source );

    if( (tok = lexer.nexttoken()) == TokenLexer.HELP ) {
      _conbuf.addAll(help.codeUnits);
      _conbuf.deliver();
      return 0;
    }      
    else if( tok == TokenLexer.STRING ) {
      // token is a quoted string
      if( lexer.quotechar == TokenLexer.doublequote ) 
        if( expandbuffer( lexer.string, 0 ) == CharBuffer.WAIT ) 
          return CharBuffer.WAIT;
      arg1 = lexer.string;
    }      
    else if( tok == TokenLexer.OBJECT ) {
      ObjectEntry obj;
      if((obj = referals.locate(lexer.name)) == null) {
        _srcbuf.webcon.writeln('ERROR: can\'t locate object "${lexer.name}"');      
         return ERROR;
      }
      if( obj.dict != null && lexer.scanchar == TokenLexer.period ) {
        // there's a dictionary and property/method, grab it
        lexer.nexttoken();
        int tok = lexer.nexttoken();
        if( tok != TokenLexer.NAME ) {
          _srcbuf.webcon.writeln('ERROR: Expecting method name, found "${lexer.lastscanchar}');
          return ERROR;            
        }
        ObjectEntry e = referals.locate_from( obj.dict, lexer.name);   
        if( e == null ) {
          _srcbuf.webcon.writeln('ERROR: unrecognized method "${lexer.name}"');
          return ERROR;
          }
        if( e.type == ObjectEntry.TEXT ) {
          arg1 = e.data.buffer;
        } else {
          source.webcon.writeln('ERROR: method ${lexer.name} is not a routine'); 
          return ERROR;
        }
      }
      else if( obj.type == ObjectEntry.TEXT )
        arg1 = obj.data.buffer;
      else {
         _srcbuf.webcon.writeln('ERROR: object "${lexer.name}" has wrong type');                
         return ERROR;
      }
    }
    else {
      _srcbuf.webcon.writeln('ERROR: expecting string or object, found "${lexer.lastscanchar}"');                
      return ERROR;
    }
    
    tok = lexer.nexttoken();   
    if( tok == TokenLexer.STRING ) {
      // token is a quoted string
      if( lexer.quotechar == TokenLexer.doublequote ) 
        if( expandbuffer( lexer.string, 0 ) == CharBuffer.WAIT ) 
          return CharBuffer.WAIT;
      arg2 = lexer.string;
      }      
    else if( tok == TokenLexer.OBJECT ) {
      ObjectEntry obj;
      if((obj = referals.locate(lexer.name)) == null) {
        _srcbuf.webcon.writeln('ERROR: can\'t locate object "${lexer.name}"');      
        return ERROR;
      } else if( obj.type != ObjectEntry.TEXT ) {
        _srcbuf.webcon.writeln('ERROR: object "${lexer.name}" has wrong type');                
        return ERROR;
      }
      arg2 = obj.data.buffer;
    }
    else {
      _srcbuf.webcon.writeln('ERROR: expecting string or object, found "${lexer.lastscanchar}"');                
      return ERROR;
    }
    data.value = compare_charbuffer( arg1, arg2 );   
    return 0;  
  }

  
  num compare_value(Map<String,ObjectEntry> dictmap, ObjectData data ) {
    return data.value;
  }
  
  num compare_charbuffer( CharBuffer arg1, CharBuffer arg2 ) {
    int pos = 0;
    while( true ) {
      if( pos == arg1.length && pos == arg2.length ) return 0;
      if( pos == arg1.length ) return -1;
      if( pos == arg2.length ) return 1;
      if( arg1[pos] < arg2[pos]) return -1;
      if( arg1[pos] > arg2[pos]) return 1;
      pos ++;
    }
  }
  
/*****************************************************
 * CREATOR OBJECTS - these create other objects
 * text, value, routine, object 
 *****************************************************/
  
  /* 
   * first are the methods for the objects they create 
   *
   * textobj
   */
  
  static const String textobj_help = '''
An object created with the Text object can store and manipulate text.
These methods are available for text objects:
\t= new_text_to_assign
\t+ new_text_to_append
\t@ accept_text_until_end
The new_text can be quoted with single (') or double(") quotes,
and substitution for object references are expanded for = and +.
See help on 'quoting' for more information on quoting in Mandy.
Accept_text_until_end accepts unexpanded text from multiple lines
until an End object is seen.
''';
  
  int textobj_input(CharBuffer source, Map<String,ObjectEntry> dictmap, ObjectData data, String help ) {

    int tok, tok2;
    num value;
    ObjectEntry obj, e;
    CharBuffer  buffer = null;
    
    // create a lexer for method's use and look for help
    TokenLexer lexer = new TokenLexer( source );

    if( (tok = lexer.nexttoken()) == TokenLexer.HELP ) {
      _conbuf.addAll(help.codeUnits);
      _conbuf.deliver();
      return 0;
    }    

    if( tok == TokenLexer.EQUAL || tok == TokenLexer.ADD ) {
      
      tok2 = lexer.nexttoken();
      if( tok2 == TokenLexer.STRING ) {
        // token is a quoted string
        if( lexer.quotechar == TokenLexer.doublequote )
          if( expandbuffer( lexer.string, 0 ) == CharBuffer.WAIT )
            return CharBuffer.WAIT;
          buffer = lexer.string;
        
      } else if( tok2 == TokenLexer.OBJECT ) {
        if((obj = referals.locate(lexer.name)) == null) {
          _srcbuf.webcon.writeln('ERROR: can\'t locate object "${lexer.name}"');      
          return ERROR;
        }
        if( obj.dict != null && lexer.scanchar == TokenLexer.period ) {
          // there's a dictionary and property/method, grab it
          lexer.nexttoken();
          tok = lexer.nexttoken();
          if( tok != TokenLexer.NAME ) {
            _srcbuf.webcon.writeln('ERROR: Expecting method name, found "${lexer.lastscanchar}');
            return ERROR;            
          }
          ObjectEntry e = referals.locate_from( obj.dict, lexer.name);   
          if( e == null ) {
            _srcbuf.webcon.writeln('ERROR: unrecognized method "${lexer.name}"');
            return ERROR;
            }
          if( e.output != null ) {
            // use the output method.
            if( interp.verbosity > MandyInterpreter.VERBOSE_MED )
              _srcbuf.webcon.writeln('INFO: "${obj.name}.${e.name}" recognized, calling output method');
            
            buffer = new CharBuffer( null );
            referals.changedepth(1);
            referals.dictmap = obj.dict;
            e.output( e.dict, e.data, buffer, 0 );
            referals.changedepth(-1);
          } else 
            _srcbuf.webcon.writeln('ERROR: no input method for "${lexer.name}"');
        }
        else if( obj.output != null ) {
          buffer = new CharBuffer( null );
          if( obj.output(obj.dict, obj.data, buffer, 0 ) == CharBuffer.WAIT )
            return CharBuffer.WAIT;
        }
        else if( e.value != null ) {
          value = e.value( e.dict, e.data );
          buffer.addAll( value.toString().codeUnits );               
        }
      } else {
        _srcbuf.webcon.writeln('Expecting quoted string or object, something else');
        return ERROR;
      }

      if( buffer != null )
        if( tok == TokenLexer.EQUAL )
          data.buffer = buffer;
        else // append for + 
          if( data.buffer == null ) data.buffer = buffer;
          else data.buffer.addAll(buffer);
    }

    else {
      _srcbuf.webcon.writeln('Expecting "=" or "+" after text object, found "${lexer.lastscanchar}"');
      return ERROR;
    }
    
    return 0;  
  }

  int textobj_output(Map<String,ObjectEntry> dictmap, ObjectData data, CharBuffer buffer, int pos ) {
    
    if( data.buffer == null ) return 0;
    
    buffer.insertAll( pos, data.buffer );
    return 0;
  }
  
  num textobj_value(Map<String,ObjectEntry> dictmap, ObjectData data ) {

    if( data.buffer == null ) return 0;
    TokenLexer lexer = new TokenLexer(data.buffer);
    return expression( lexer );
  }

  /*
   * valueobj
   */
  
  static const String valueobj_help = '''
An object created with the Value object can store and manipulate values.
These methods are available for value objects:
\t= new_value_expression_to_assign
\t+ new_value_expression_to_add
\t- new_value_expression_to_subtract
For help with expressions, see help on 'expressions'
''';  

  int valueobj_input(CharBuffer source, Map<String,ObjectEntry> dictmap, ObjectData data, String help ) {
    int tok, tok2;
    ObjectEntry e;
    num value = null;
    
    // create a lexer for method's use and look for help
    TokenLexer lexer = new TokenLexer( source );

    if( (tok = lexer.nexttoken()) == TokenLexer.HELP ) {
      _conbuf.addAll(help.codeUnits);
      _conbuf.deliver();
    }    
    else if( tok == TokenLexer.EQUAL ) {
      tok2 = lexer.nexttoken();
      if( tok2 == TokenLexer.NUMERIC ) {
        value = lexer.value;
      } 
      else if( tok2 == TokenLexer.OBJECT ) {
        ObjectEntry obj;
        if((obj = referals.locate(lexer.name)) == null) {
          _srcbuf.webcon.writeln('ERROR: can\'t locate object "${lexer.name}"');      
          return ERROR;
        }
        if( obj.dict != null && lexer.scanchar == TokenLexer.period ) {
          // there's a dictionary and property/method, grab it
          lexer.nexttoken();
          tok = lexer.nexttoken();
          if( tok != TokenLexer.NAME ) {
            _srcbuf.webcon.writeln('ERROR: Expecting method name, found "${lexer.lastscanchar}');
            return ERROR;            
          }
          ObjectEntry e = referals.locate_from( obj.dict, lexer.name);   
          if( e == null ) {
            _srcbuf.webcon.writeln('ERROR: unrecognized method "${lexer.name}"');
            return ERROR;
            }
          if( e.value != null ) {
            value = e.value( e.dict, e.data );
          } else {
            _srcbuf.webcon.writeln('ERROR: object "${lexer.name}" has no value');      
            return ERROR;
          }
        }
        else  if( obj.value != null ) {
            value = obj.value( obj.dict, obj.data );
        } else {
          _srcbuf.webcon.writeln('ERROR: object "${lexer.name}" has no value');      
          return ERROR;
        }

      } else if( tok2 == TokenLexer.LEFTPAREN ) {
        // token is a numeric expression
        value = expression( lexer );
      }
      if( value != null )
        data.value = value;
    }
    else {
      _srcbuf.webcon.writeln('Expecting "=" after value object, found "${lexer.lastscanchar}"');
      return ERROR;
    }
    return 0;  
  }

  int valueobj_output(Map<String,ObjectEntry> dictmap, ObjectData data, CharBuffer buffer, int pos ) {
    if( data.value == null ) return 0;
    
    buffer.insertAll( pos, data.value.toString().codeUnits );
    return 0;
  }
  
  num valueobj_value(Map<String,ObjectEntry> dictmap, ObjectData data ) {
    if( data.value == null ) return 0;
    
    return data.value;

  }
  
  /*
   * objectobj
   */
  
  static const String objectobj_help = '''
An object created with the Object object can act like any other
objects in Mandy. They will be recognized as an object on the input line
both at the beginning as an object, or as a text reference with \$object_name.
Recognized on the input line it can be used to expand it's prototype.
As text reference it will list all methods and properties it contains.
Additional methods can be accessed with '.method' notation.
See additional help on 'methods'.
''';

  int objectobj_input(CharBuffer source, Map<String,ObjectEntry> dictmap, ObjectData data, String help ) {
 
    CharBuffer buf, buffer;
    int ret, tok;
    // create a lexer for method's use and look for help
    TokenLexer lexer = new TokenLexer( source );

    if( (tok = lexer.nexttoken()) == TokenLexer.HELP ) {
      _conbuf.addAll(help.codeUnits);
      _conbuf.deliver();
      return 0;
    }
    // extract the text to use to expand the prototype
    if( tok == TokenLexer.STRING ) {
      // token is a quoted string
      if( lexer.quotechar == TokenLexer.doublequote ) 
        if( expandbuffer( lexer.string, 0 ) == CharBuffer.WAIT ) 
          return CharBuffer.WAIT;
      buf = lexer.string;
    } 
    else if( tok == TokenLexer.OBJECT ) {
      ObjectEntry obj;
      if((obj = referals.locate(lexer.name)) != null) {
        if( obj.type == ObjectEntry.TEXT )
          buf = obj.data.buffer;
        else {
          _srcbuf.webcon.writeln('ERROR: wrong object type for prototype: "${lexer.name}"');
          return ERROR;
          }
      } else {
        _srcbuf.webcon.writeln('ERROR: unrecognized object "${lexer.name}"');
        return ERROR;
      }
    } else {
      _srcbuf.webcon.writeln('ERROR: expecting prototype, found "${lexer.lastscanchar}"');
      return ERROR;
    }
    
    // process the input for prototype definition
    if( buf != null ) {
      if( interp.verbosity > MandyInterpreter.VERBOSE_LOW )
        _srcbuf.webcon.writeln('INFO: evaluating prototype "${buf.string}"');

      buffer = new CharBuffer( source.webcon );
      buffer.allowinput = false;
      buffer.addAll(buf);
      
      referals.changedepth(1);
      referals.dictmap = dictmap;
      ret = interp.interpret( buffer );
      if( interp.verbosity > MandyInterpreter.VERBOSE_LOW )
        _srcbuf.webcon.writeln('INFO: prototype evaluation returned ${ret.toString()}');
      referals.changedepth(-1);
      if( ret != EOF ) return ret;
    }
    return 0;
  }

  int objectobj_output(Map<String,ObjectEntry> dictmap, ObjectData data, CharBuffer buffer, int pos ) {

    if( dictmap == null ) return 0;
    
    StringBuffer buf = new StringBuffer();    
    for( String name in dictmap.keys) {
      buf.write(name);
      buf.write(' ');
    }
    
    buffer.insertAll(pos, buf.toString().codeUnits );
    return 0;
  }
    
  /*
   * NEXT ARE THE actual creator objects themselves
   *
   *  text  
   */
  
  static const String text_help = '''
The Text object is used to create new objects which can hold text
or Mandy routines, which are a set Mandy instructions which are
invoked later. Following the Text object should be the name which the new object will take.
See help on 'naming' for more information on object naming in Mandy.
''';
  
  int text_input(CharBuffer source, Map<String,ObjectEntry> dictmap, ObjectData data, String help ) {

    int tok;
    ObjectEntry e;
    List<String> names;
    
    // create a lexer for method's use and look for help
    TokenLexer lexer = new TokenLexer( source );

    if( (tok = lexer.nexttoken()) == TokenLexer.HELP ) {
      _conbuf.addAll(help.codeUnits);
      _conbuf.deliver();
    }
    
    else if( (names = lexer.getnames(tok)) != null ) {    
      if( interp.verbosity > MandyInterpreter.VERBOSE_MED )
        _srcbuf.webcon.write('INFO: creating text objects: ');
      for( var name in names ) {
        
        if( interp.verbosity > MandyInterpreter.VERBOSE_MED )
          _srcbuf.webcon.write('${name} ');
        
        // look for dup object - at current level only, allow for shadowing
        if( referals.locatecurrent(name) != null ) {
          _srcbuf.webcon.writeln('warning: can\'t create dup object "${name}"');
        } else {
          
          e = new ObjectEntry(name, textobj_help, textobj_input, textobj_output, textobj_value );
          e.type = ObjectEntry.TEXT;
          e.data = new ObjectData();
          
          referals.create( e );
        }
      }        
      if( interp.verbosity > MandyInterpreter.VERBOSE_MED ) _srcbuf.webcon.writeln(null);
    }
    
    else {
      _srcbuf.webcon.writeln('ERROR: expecting list of names to create, found "${lexer.lastscanchar}"');
      return ERROR;
    }
    
    return 0;  
  }

  /*
   * value
   */
  
  static const String value_help = '''
The Value object is used to create new objects which can hold values.
Following the Value object should be the name which the new object will take.
See help on 'naming' for more information on object naming in Mandy.
''';
  
  int value_input(CharBuffer source, Map<String,ObjectEntry> dictmap, ObjectData data, String help ) {

    int tok;
    ObjectEntry e;
    List<String> names;
    
    // create a lexer for method's use and look for help
    TokenLexer lexer = new TokenLexer( source );

    if( (tok = lexer.nexttoken()) == TokenLexer.HELP ) {
      _conbuf.addAll(help.codeUnits);
      _conbuf.deliver();
    }    
    
    else if( (names = lexer.getnames(tok)) != null ) {    
      if( interp.verbosity > MandyInterpreter.VERBOSE_MED )
      _srcbuf.webcon.write('creating value objects: ');
      for( var name in names ) {
        
        if( interp.verbosity > MandyInterpreter.VERBOSE_MED )
           _srcbuf.webcon.write('${lexer.name} ');
        
        // look for dup object - at current level only, allow for shadowing
        if( referals.locatecurrent(name) != null ) {
          _srcbuf.webcon.writeln('warning: can\'t create dup object "${name}"');
        } else {
          
          e = new ObjectEntry(name, valueobj_help, valueobj_input, valueobj_output, valueobj_value );
          e.type = ObjectEntry.VALUE;
          e.data = new ObjectData();
          
          referals.create( e );
        }
      }        
      if( interp.verbosity > MandyInterpreter.VERBOSE_MED ) _srcbuf.webcon.writeln(null);
    }
    
    else {
      _srcbuf.webcon.writeln('ERROR: expecting list of names to create, found "${lexer.lastscanchar}"');
      return ERROR;
    }
    
    return 0;  
  }

  /*
   * object
   */
  
  static const String object_help = '''
The Object object is used to create new objects from user-supplied
prototypes. Following the Object object should be a list of names
which the new objects will take.
''';
  
  int object_input(CharBuffer source, Map<String,ObjectEntry> dictmap, ObjectData data, String help ) {

    int eret, tok;
    CharBuffer buffer;
    List<String> names;
    String objectname, objectproto;
    ObjectEntry e, f;
    
    // create a lexer for method's use and look for help
    TokenLexer lexer = new TokenLexer( source );

    if( (tok = lexer.nexttoken()) == TokenLexer.HELP ) {
      _conbuf.addAll(help.codeUnits);
      _conbuf.deliver();
    }    
    
    else if( (names = lexer.getnames(tok)) != null ) {    
      if( interp.verbosity > MandyInterpreter.VERBOSE_MED )
        _srcbuf.webcon.write('creating object objects: ');
      for( objectname in names ) {

        if( interp.verbosity > MandyInterpreter.VERBOSE_MED )
          _srcbuf.webcon.write('${objectname} ');
        
        // look for dup object - at current level only, allow for shadowing
        if( referals.locatecurrent(objectname) != null ) {
          _srcbuf.webcon.writeln('WARNING: can\'t create duplicate object "${objectname}"');
          continue;
        }
        
        // create the object object
        f = new ObjectEntry(objectname, objectobj_help, objectobj_input, objectobj_output, null );
        f.type = ObjectEntry.OBJECT;
        // create a empty dictionary
        f.dict = new Map<String,ObjectEntry>();
        referals.create( f );
      }
      if( interp.verbosity > MandyInterpreter.VERBOSE_MED ) _srcbuf.webcon.writeln(null);
    }
    
    else {
      _srcbuf.webcon.writeln('ERROR: expecting list of names to create, found "${lexer.lastscanchar}"');
      return ERROR;
    }

    return 0;  
  }

  /*
   * dup
   */
  
  static const String dup_help = '''
The dup object is used to duplicate an existing object, making an\
exact copy with a new name. Text and value objects will retain their data,\
and for objects all properties and methods are duplicated as well as\
any property data associated.\
Following the dup object should be the name of the object to \
duplicate, and following that is the name that the new object will take.\
''';
  
  int dup_input(CharBuffer source, Map<String,ObjectEntry> dictmap, ObjectData data, String help ) {

    int tok;
    String objectname, objectdup;
    ObjectEntry e, f;
    
    // create a lexer for method's use and look for help
    TokenLexer lexer = new TokenLexer( source );

    if( (tok = lexer.nexttoken()) == TokenLexer.HELP ) {
      _conbuf.addAll(help.codeUnits);
      _conbuf.deliver();
      return 0;
    }    
    if( tok != TokenLexer.NAME ) {
      _srcbuf.webcon.writeln('ERROR: expecting object name, found ${lexer.lastscanchar}');
      lexer.backup();
      return ERROR;      
    }
    objectname = lexer.name;
    // look for dup object - at current level only, allow for shadowing
    if( referals.locatecurrent(objectname) != null ) {
      _srcbuf.webcon.writeln('can\'t create object with dup name "${objectname}"');
      return ERROR;      
    }    
    if( (tok = lexer.nexttoken()) != TokenLexer.NAME ) {
      _srcbuf.webcon.writeln('ERROR: expecting object to duplicate, found ${lexer.lastscanchar}');
      lexer.backup();
      return ERROR;      
    }    
    objectdup = lexer.name;
    e = referals.locate(objectdup);
    if( e == null ) {
      _srcbuf.webcon.writeln('ERROR: unknown object "${objectdup}"');
      return ERROR;
    }
    if( interp.verbosity > MandyInterpreter.VERBOSE_MED )
      _srcbuf.webcon.writeln('Duplicating "${objectdup}" to "${objectname}"');
    // now create the duplicate
    f = new ObjectEntry(objectname, e.help, e.input, e.output, e.value );
    f.type = e.type;
    f.data = e.data;
    f.dict = e.dict;
      
    referals.create( f );
    return 0;  
  }

    /****************************************
   * CONTROL OBJECTS
   * end, else, for, if, while
   ****************************************/
  
  /*
   * These are flow-control objects which end blocks of instructions.
   * Generally they return value greater that zero 
   * to flag the interpreter to stop reading and return
   *
   * end
   */
  
  static const String end_help = '''
The End object is used to end a block of instructions which\
have been started by the use of a For, While, If or Routine object.\
It can be also used to end the Mandy interpreter itself.\
''';
  
  int end_input(CharBuffer source, Map<String,ObjectEntry> dictmap, ObjectData data, String help ) {

    int tok;
    
    // create a lexer for method's use and look for help
    TokenLexer lexer = new TokenLexer( source );

    if( (tok = lexer.nexttoken()) == TokenLexer.HELP ) {
      _conbuf.addAll(help.codeUnits);
      _conbuf.deliver();
    }    
    else if( tok == TokenLexer.NAME )
      lexer.returnname();
    
    if( interp.verbosity > MandyInterpreter.VERBOSE_LOW ) {
      _conbuf.addAll('(end encountered)'.codeUnits); 
      _conbuf.deliver();
    }

    return CONTROL_END;  
  }

  /*
   * else
   */
  
  static const String else_help = '''
The Else object is used to end the block of instructions executed when true,\
and begin the block of instructions executed when false.\
''';

  int else_input(CharBuffer source, Map<String,ObjectEntry> dictmap, ObjectData data, String help ) {

    int tok;
    
    // create a lexer for method's use and look for help
    TokenLexer lexer = new TokenLexer( source );

    if( (tok = lexer.nexttoken()) == TokenLexer.HELP ) {
      _conbuf.addAll(help.codeUnits);
      _conbuf.deliver();
    }    
    else if( tok == TokenLexer.NAME )
      lexer.returnname();

    if( interp.verbosity > MandyInterpreter.VERBOSE_LOW ) {
      _conbuf.addAll('(end encountered)'.codeUnits); 
      _conbuf.deliver();
    }

    return CONTROL_ELSE;  
  }

  /*
   * These are control statements which set up the control structions 
   *
   * if
   */
  
  static const String if_help = '''
The If object is used to conditionally execute a set of instructions.\
Following the If object is an expression which will be evaluated for truth.\
If true, all the input lines following the If object will be executed until\
either an Else or End object is encountered. If false, all the input lines\
will be ignored until an Else object is encountered, and the lines following\
the Else until an End object will be executed. If no Else is encountered,\
all lines will be ignored until the End.\
''';

  int skipblock(TokenLexer lexer, bool stopOnElse ) {
    int tok;
    while( (tok = lexer.nexttoken()) != TokenLexer.ENDOFINPUT && tok != TokenLexer.ERROR )
      if( tok == TokenLexer.NAME ) {
        if( lexer.name.compareTo('if') == 0 ) tok = skipblock( lexer, false );
        else {
          if( lexer.name.compareTo('end') == 0 ) break;
          if( stopOnElse && lexer.name.compareTo('else') == 0 ) break;
        }
      }
    return tok;
  }
  
  int if_input(CharBuffer source, Map<String,ObjectEntry> dictmap, ObjectData data, String help ) {

    int result, tok;
    num value = null;
    
    // create a lexer for method's use and look for help
    TokenLexer lexer = new TokenLexer( source );

    // evaluate the input following if as an expression
    if( (value = expression( lexer )) == null ) {
      _srcbuf.webcon.writeln('ERROR: if object does not evaluate to an expression');
      return ERROR;
      };

    if( value == 0.0 ) {
      if( interp.verbosity > MandyInterpreter.VERBOSE_LOW ) 
        _conbuf.addAll('(if evaluated false)'.codeUnits); 
      
      // skip over next part of input until else or end
      tok = skipblock(lexer, true);
      if( tok != TokenLexer.NAME ) {
        _srcbuf.webcon.writeln('WARNING: expecting "end" or "else"');
        return 1;
      }
      if( lexer.name.compareTo('end') == 0 ) return 0;
      if( lexer.name.compareTo('else') != 0 ) {
        _srcbuf.webcon.writeln('WARNING: expecting "end" or "else"');
        return 2;
      }

      // continue to processing else part until the end encountered
      result = interp.interpret(source);
      if( result != CONTROL_END ) {
        _srcbuf.webcon.writeln('WARNING: expecting "end"');
        return 3;
      }
      
    } else {
      
      if( interp.verbosity > MandyInterpreter.VERBOSE_LOW ) 
        _conbuf.addAll('(if evaluated true)'.codeUnits); 
      
      // continue to processing until the end or else encountered
      result = interp.interpret(source);
      if( result == CONTROL_END ) {
        // normal completion with end
        if( interp.verbosity > MandyInterpreter.VERBOSE_LOW ) 
           _conbuf.addAll('(if completed)'.codeUnits); 
      } else {
         if( result != CONTROL_ELSE ) {
            _srcbuf.webcon.writeln('WARNING: expecting "else"');
            return 1;
         }         
         // skip over else part until end
         while( (tok = lexer.nexttoken()) != TokenLexer.ENDOFINPUT && tok != TokenLexer.ERROR )
           if( tok == TokenLexer.NAME ) {
             if( lexer.name.compareTo('end') == 0 )
               break;
           }
         if( tok != TokenLexer.NAME ) {
           _srcbuf.webcon.writeln('WARNING: expecting "end"');
           return 2;
         }
         if( lexer.name.compareTo('end') == 0 ) return 0;
         else {
           _srcbuf.webcon.writeln('WARNING: expecting "end"');
           return 3;
         }
       }
     }
    
    if( interp.verbosity > MandyInterpreter.VERBOSE_LOW ) {
      _conbuf.addAll('(if completed)'.codeUnits); 
      _conbuf.deliver();
    }
    
    return 0;  
  }

  /*
   * while
   */
  
  static const String while_help = '''
The While object is used to repeatedly execute a set of instructions\
while a certain condition is true. The condition is evaluated before\
each execution of the set, and when events occuring within the instructions\
change the condition in then that will be reflected in the evaluation\
and the loop can end.\
Immediately following the While object is an expression which will be\
evaluated for truth. If true, all instructions on the lines following will\
be executed, until an End object is encountered. At that point, the\
expression will be re-evaluated and if still true, the instructions\
will be executed again. This will continue until the condition\
is finally evaluated false.\
''';
  
  int while_input(CharBuffer source, Map<String,ObjectEntry> dictmap, ObjectData data, String help ) {

    CharBuffer condbuf, execbuf;
    List<int>  condlist, execlist;
    TokenLexer condlexer, execlexer;
    num value;
    
    // move the condition part following the while into a new buffer
    // this assumes the conditional part is already in source buffer
    condbuf = new CharBuffer( null );
    condlist = source.innerList;
    condlexer = new TokenLexer(condbuf);
    
    // now read all lines until end into another buffer      
    execbuf = new CharBuffer(source.webcon);
    execbuf.fetchuntil('end' );
    execlist = execbuf.innerList;
    execlexer = new TokenLexer(execbuf);
    
    while( true ) {
      // perform while block while condition is true
      // evaluate condition
      condbuf.innerList = new List<int>();
      condbuf.innerList.addAll( condlist );
      condlexer.scanchar = 0;   // clear this or else it senses EOF
      value = expression( condlexer );  
      
      if( value == 0.0 ) {
        // condition is false, leave
        if( interp.verbosity > MandyInterpreter.VERBOSE_LOW ) {
          _conbuf.addAll('(while completed)'.codeUnits); 
          _conbuf.deliver();
        }
        break;        
      }
      
      if( interp.verbosity > MandyInterpreter.VERBOSE_LOW ) {
        _conbuf.addAll('(while executed)'.codeUnits); 
        _conbuf.deliver();
      }

      // execute the code in execbuf
      execbuf.innerList = new List<int>();
      execbuf.innerList.addAll( execlist );
      interp.interpret( execbuf );
      
    }

    return 0;  
  }

  /**********************************
   * ADDITIONAL HELP TEXT
   **********************************/
  
  static const String general_help = '''
Mandy is a very simple but powerfull object-oriented language.n\
Mandy could be called Object Control Language because it borrows
ideas from Tcl/Tk, yet the syntax is more like Basic.n\
The first thing on the input line is the name of an object to invoke.
Following that are instructions to that object, if required.
There are a small number of predefined objects, and some of those
are able to create additional objects. Basically that's it.n\
Two other things to start: list will give you a list of existing objects,
and follow an object name with a question mark (?) to ask for object help.
''';
  
  static const String quoting_help = '''
Whenever text is entered as input to an object, it may be quoted in order
to include spaces and tab characters which would normally end the text.
In addition to that, use of quoting controls whether object references
(which are the name of the object prefaced by the dollar sign) are to be
expanded to represent their contents or not. The basic rules are:
\ttext without any quoting receieves expansion of objects
\ttext quoted with single quotes (') DOES NOT receive expansion 
\ttext quoted with double quotes (\") receives expansion of objects
''';
  
  static const String naming_help = '''
CREATING:
  The names of new objects that you create can be simple or they can refer
to a heirarchy of objects that you create. The first rule of naming is that
names can contain characters, numbers, and most punctuation characters that
are not used by OCL objects. Characters reserved for OCL object use are:
\t\$\t?\t!\t=\t-\t+\t'\t\"n\
To create heirarchy when naming objects, use the foward-slash (/)
to indicate increasing depth of heirarchy. Example:
\tfoo/bar\t indicates bar is subordinate to foo, and
\tfoo/bar/zoo\tindicates bar is subordinate to foo, and zoo subordinate to bar.
USING:
  When refering to objects by names, whether it's the standard objects or
ones you create, it's only necessary to use enough characters to uniquely
identify the object. Care should be taken when using this feature in scripts.
''';
  
  static const String expression_help = '''
Expressions are entered in their natural form using parenthesis to indicate
grouping. Operators allowed in expressions are:
\t+\t-\t*\t/\t^\t<\t>\t=\t<>
\tor\tand\tnot
''';
  
  static const String methods_help = '''
Methods are a means of accessing properties and stored routines of an
object. They are tailored to meet the needs of each object.
You create your own methods when you use Object to read a prototype
and that prototype contains routines.
There are also automatic methods available to access the value and text
properties of any object which has them. That includes ones which you create
with Object as well as the GUI objects, which keep GUI configuration in
properties.n\
To indicate a method, append the method name to the object with a period.
This works when invoking the object for input at the beginning of the line,
or using it with expansion by prefacing it with the dollar sign '\$'.
See help on "quoting".
'''; 
   
  /*
   * end of standard object definitions  
   */
  
  ObjectEntry textobject(String name) {
     
     ObjectEntry entry;
     entry = new ObjectEntry(name, textobj_help, textobj_input, textobj_output, textobj_value);
     entry.data = new ObjectData();
     entry.type = ObjectEntry.TEXT;
     return entry;
   }
   
  ObjectEntry valueobject(String name) {
     
     ObjectEntry entry;
     entry = new ObjectEntry(name, valueobj_help, valueobj_input, valueobj_output, valueobj_value);
     entry.data = new ObjectData();
     entry.type = ObjectEntry.VALUE;
     return entry;
   }
   
  ObjectEntry objectobject(String name) {
    
    ObjectEntry entry;
    entry = new ObjectEntry(name, objectobj_help, objectobj_input, objectobj_output, null);
    entry.type = ObjectEntry.OBJECT;
    return entry;
  }
  
  StandardObjects( this._conbuf, this._srcbuf ) {
    dictmap['accept'] = new ObjectEntry("accept", accept_help, accept_input, accept_output, null);
    dictmap['break'] = new ObjectEntry("break", break_help, break_input, null, null);
    dictmap['call'] = new ObjectEntry("call", call_help, call_input, null, null);
    dictmap['dup'] = new ObjectEntry("dup", dup_help, dup_input, null, null);
    dictmap['echo'] = new ObjectEntry("echo", echo_help, echo_input, null, null);
    dictmap['else'] = new ObjectEntry("else", else_help, else_input, null, null);
    dictmap['end'] = new ObjectEntry("end", end_help, end_input, null, null);
    dictmap['help'] = new ObjectEntry("help", help_help, help_input, null, null);
    dictmap['if'] = new ObjectEntry("if", if_help, if_input, null, null);
    dictmap['list'] = new ObjectEntry("list", list_help, list_input, list_output, list_value);
    dictmap['object'] = new ObjectEntry("object", object_help, object_input, null, null);
    dictmap['text'] = new ObjectEntry("text", text_help, text_input, null, null);
    dictmap['value'] = new ObjectEntry("value", value_help, value_input, null , null);
    dictmap['verbose'] = new ObjectEntry("verbose", verbose_help, verbose_input, verbose_output, verbose_value);
    dictmap['while'] = new ObjectEntry("while", while_help, while_input, null, null);

    ObjectEntry obj = new ObjectEntry("compare", compare_help, compare_input, null, compare_value);
    obj.data = new ObjectData();
    dictmap['compare'] = obj;

  }
  
}