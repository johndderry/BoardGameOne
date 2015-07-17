library interpreter;

import 'bufferedhtmlio.dart';

part 'standardobjects.dart';

/**********************
 * CLASS TokenLexer   *
 **********************/

class TokenLexer {
  
  static const
    ERROR       = -3,
    WAITONINPUT = -2,
    ENDOFINPUT  = -1,
    NONE        = 0,
    NUMERIC     = 1,
    LEFTPAREN   = 2,
    RIGHTPAREN  = 3,
    LESSTHAN    = 4,
    GREATERTHAN = 5,
    LESSTHANOREQUAL    = 6,
    GREATERTHANOREQUAL = 7,
    EQUAL     = 8,
    NOTEQUAL  = 9,
    MULTIPLY  = 10,
    DIVIDE    = 11,
    ADD       = 12,
    SUBTRACT  = 13,
    AND       = 14,
    OR        = 15,
    NOT       = 16,
    PERIOD    = 17,
    COMMA     = 18,
    HELP      = 19,
    NAME      = 20,
    STRING    = 21,
    OBJECT    = 22;
  
  static final 
    period  = '.'.codeUnits[0],
    comma   = ','.codeUnits[0],
    space   = ' '.codeUnits[0],
    tab     = '\t'.codeUnits[0],
    newline = '\n'.codeUnits[0],
    helpchar    = '?'.codeUnits[0],
    leftparen   = '('.codeUnits[0],
    rightparen  = ')'.codeUnits[0],
    lessthan    = '<'.codeUnits[0],
    greaterthan = '>'.codeUnits[0],
    equals      = '='.codeUnits[0],
    multiply    = '*'.codeUnits[0],
    divide      = '/'.codeUnits[0],
    plus        = '+'.codeUnits[0],
    minus       = '-'.codeUnits[0],
    barquote    = '|'.codeUnits[0],
    singlequote = '\''.codeUnits[0],
    doublequote = '"'.codeUnits[0],
    substitute  = '\$'.codeUnits[0];
    
  static final List<int>
    terminators = '\t\n .,?()<>=*/+-\$|\'"'.codeUnits,
    and = 'and'.codeUnits,
    or  = 'or'.codeUnits,
    not = 'not'.codeUnits,
    numbers = '0123456789'.codeUnits;

    int _lastchar,  // previous character code
        scanchar,   // current character read from _source
        quotechar;
    num           value;              // value parsed in exprlexer
    String        name;
    CharBuffer    string;
    CharBuffer    _source;
 
    String get lastscanchar { 
      if( _lastchar < 0 ) return _lastchar.toString();
      return new String.fromCharCode( _lastchar );
    }
    
    List<String> getnames(int tok) {
      
      // accept a list of names seperated by commas from the input lines,
      // and return them in a list

      List<String> names = new List<String>();

      while( tok == NAME ) {
        names.add(name);
        tok = nexttoken();
        if( tok != COMMA ) break;
        tok = nexttoken();
      }
      
      if( tok == NAME )
        returnname();
      
      return names;      
    }
    
    void backup() {
      // backup one character if there is a character in scanchar
      if( scanchar > 0 ) _source.ungetchar(scanchar);
      scanchar = _lastchar;
      _lastchar = NONE;
    }
   
    void clearscan() {
      if( scanchar > 0 ) _source.ungetchar(scanchar);
      scanchar = NONE;      
    }
    
    void returnname() {
      backup();
      if( name != null )
        _source.insertchars( name.codeUnits );
    }
    
    int nexttoken() {
      // extract the next token from input.
      // scanchar may already have a character,
      //    and scanchar may be loaded with the next character
      //    when we leave
      
      StringBuffer buf;

      if( scanchar == NONE ) 
        // no scanchar present, read one 
        _lastchar = scanchar = _source.getchar();

      while( scanchar == space || scanchar == tab || scanchar == newline )
        _lastchar = scanchar = _source.getchar();
      if( scanchar < 0 ) return scanchar;
      //if( scanchar < 0 ) return ENDOFINPUT;

      if( scanchar == leftparen ) {
        scanchar = NONE;
        return LEFTPAREN;
      }
      if( scanchar == helpchar ) {
        scanchar = NONE;
        return HELP;
      }
      if( scanchar == period ) {
        scanchar = NONE;
        return PERIOD;
      }
      if( scanchar == comma ) {
        scanchar = NONE;
        return COMMA;
      }
      if( scanchar == rightparen ) { 
        scanchar = NONE;
        return RIGHTPAREN;
      }
      if( scanchar == multiply ) {
        scanchar = NONE;
        return MULTIPLY;
      }
      if( scanchar == divide ) { 
        scanchar = NONE;
        return DIVIDE;
      }
      if( scanchar == plus ) {
        scanchar = NONE;
        return ADD;
      }
      if( scanchar == minus ) {
        scanchar = NONE;
        return SUBTRACT;
      }
      if( scanchar == lessthan) {
        scanchar = _source.getchar();
        if( scanchar == equals ) {
          scanchar = NONE;
          return LESSTHANOREQUAL;
        }
        if( scanchar == greaterthan ) {
          scanchar = NONE;
          return NOTEQUAL;
        }
        _source.ungetchar(scanchar);
        scanchar = NONE;
        return LESSTHAN;
      }
      if( scanchar == greaterthan) {
        scanchar = _source.getchar();
        if( scanchar == equals ) {
          scanchar = NONE;
          return GREATERTHANOREQUAL;
        }
        _source.ungetchar(scanchar);
        scanchar = NONE;
        return GREATERTHAN;
      }
      if( scanchar == equals ) {
        scanchar = NONE;
        return EQUAL;
      }
      if( scanchar == and[0] ) {
        scanchar = _source.getchar();
        if( scanchar == and[1] ) {
          scanchar = _source.getchar();
          if( scanchar == and[2] ) {
            scanchar = NONE; 
            return AND;
          } else {
            // undo last two getchar()s
            _source.ungetchar(scanchar);
            _source.ungetchar(and[1]);
            scanchar = and[0];
          }
        }
        else {
          // undo last getchar
          _source.ungetchar(scanchar);
          scanchar = and[0];          
        }
      }
      if( scanchar == or[0] ) {
        scanchar = _source.getchar();
        if( scanchar == or[1] ) {
          scanchar = NONE;
          return OR;
        } else {
          // undo last getchar
          _source.ungetchar(scanchar);
          scanchar = or[0];                    
        }
      }
      if( scanchar == not[0] ) {
        scanchar = _source.getchar();
        if( scanchar == not[1] ) {
          scanchar = _source.getchar();
          if( scanchar == not[2] ) { 
            scanchar = NONE;
            return NOT;
          } else {
            // undo last two getchar()s
            _source.ungetchar(scanchar);
            _source.ungetchar(not[1]);
            scanchar = not[0];
          }
        }
        else {
          // undo last getchar
          _source.ungetchar(scanchar);
          scanchar = not[0];                    
        }
      }
      if( scanchar == substitute) {
        // fetch the name which follows, return as object name
        buf = new StringBuffer();
        scanchar = _source.getchar();
        while( scanchar > 0 && !terminators.contains(scanchar) ) {
          buf.writeCharCode(scanchar);
          scanchar = _source.getchar();
        }
        name = buf.toString();
        return OBJECT;
      }
      if( scanchar == singlequote || scanchar == doublequote || scanchar == barquote ) {
        quotechar = scanchar;
        string = new CharBuffer( null );
        scanchar = _source.getchar();
        while( scanchar > 0 && scanchar != quotechar ) { 
          string.add(scanchar);
          scanchar = _source.getchar();
        }
        scanchar = NONE;
        return STRING;
      }
      
      int n, pos = 0, radixpos = -1;
      if( (n = numbers.indexOf( scanchar )) >= 0 ) {
        value = n;
        scanchar = _source.getchar();
        while( scanchar == period || (n = numbers.indexOf( scanchar )) >= 0 ) {
          if( scanchar == period ) {
            if( radixpos < 0 ) radixpos = pos;
            else return ERROR;           
          } else {
            pos++;
            value = value * 10;
            value = value + n;
          }
          scanchar = _source.getchar();
        }
        if( radixpos >= 0) {
          double div = 1.0;
          int cnt = pos - radixpos;
          while( cnt-- > 0  ) div = div * 10.0; 
          value = value / div;
        }
        return NUMERIC;
      }
      
      // the token is assumed to be a token name
      buf = new StringBuffer();
      while( scanchar > 0 && !terminators.contains(scanchar) ) {
        buf.writeCharCode(scanchar);
        scanchar = _source.getchar();
      }
      name = buf.toString();
      return NAME;
    }

  TokenLexer( this._source ) {
    scanchar = _lastchar = NONE;
  }
  
}

/***********************************
 * CLASS ObjectData / ObjectEntry  *
 ***********************************/
class ObjectData {
  CharBuffer  buffer;
  num         value;
}

class ObjectEntry {
  
  static const
    INTERNAL = 0, TEXT = 1, VALUE = 2, OBJECT = 3;
  
  String      name, help;
  ObjectData  data;           // object's instance storage
  int         type = INTERNAL;    // object type
  
  // object's default methods
  var input, output, value;
  Map<String,ObjectEntry> dict;   // object's internal dictionary 
  ObjectEntry duplicate() {
    ObjectEntry o = new ObjectEntry(name, help, input, output, value);
    o.type = type;
    o.data = new ObjectData();
    o.data.value = data.value;
    o.data.buffer = data.buffer.duplicate();
    //o.data.buffer = data.buffer;
    return o;
  }
  
  ObjectEntry(this.name, this.help, this.input, this.output, this.value );
}

/**************************
 * CLASS ObjectDictionary *
 **************************/

class ObjectDictionary {
  
  static const MAXDICTDEPTH = 20;
  
  int         _currentdepth;             // current dictionary depth depth
  List<Map>   _dictmap;        // list of dictionary maps for each depth's
  Map<String,ObjectEntry> _predefined;  // predefined objects list;
  CharBuffer  _logbuf;
  
  bool verbose = false, strictmatch = true;
  
  // methods _countfrom, count, count_depth
  // return count of entries
  int get depth { return _currentdepth; }
  Map<String,ObjectEntry> get dictmap { return _dictmap[_currentdepth]; }
  void set dictmap(Map<String,ObjectEntry> m) { _dictmap[_currentdepth] = m; }
  
  int changedepth(int change) { 
    if( change > 0 ) {
      if( _currentdepth + change > MAXDICTDEPTH ) {
        _logbuf.webcon.writeln('ERROR: Max dictionary depth ${MAXDICTDEPTH} cannot be exceeded');
        return _currentdepth;
      }
      while( change-- > 0 ) {
        _dictmap.add(null);
        _currentdepth++;
      }
    }
    else if( change < 0 ) {
      if( _currentdepth + change  < 0 ) {
        _logbuf.webcon.writeln('ERROR: Dictionary depth cannot go below 0');
        return _currentdepth;
      }
      while( change++ < 0 ) {
        _dictmap.removeLast();
        _currentdepth--;
      }
    }
    
    return _currentdepth;
  }
  
  int count(int depth) {
    if( depth < 0 )
      return _dictmap[_currentdepth].length;
    if( depth >= _dictmap.length ) return 0;
    return _dictmap[depth].length;
  }
  
  String list(int depth) {

    if( depth >= _dictmap.length ) return '';
    
    Map<String,ObjectEntry> map = _dictmap[depth];
    if( map == null || map.length == 0 ) return '';
        
    StringBuffer buildstring = new StringBuffer();
    
    for( String name in map.keys ) {
    
      if( verbose ) buildstring.writeln('${name}:\n${map[name].help}');
      else          buildstring.write('${name} ');
    }
    return buildstring.toString();
  }
  
  ObjectEntry locate_from( Map<String,ObjectEntry> map, String searchname ) {
    if( verbose ) _logbuf.webcon.writeln('INFO: locate "${searchname}"');
    if( map == null || map.length == null ) return null;
    return map[searchname];
  }

  ObjectEntry locatecurrent( String searchname ) { 
      return locate_from( _dictmap[_currentdepth], searchname );
  }
    
  ObjectEntry locate( String searchname ) { 
    ObjectEntry check;
      for( int depth = _currentdepth; depth >= 0; depth-- )
        if( _dictmap[depth] != null && 
            (check = locate_from( _dictmap[depth], searchname )) != null )
          return check;
      return null;
    }

  int create( ObjectEntry entry ) {

    Map<String,ObjectEntry> map = _dictmap[_currentdepth];
    if( map == null )
      map = _dictmap[_currentdepth] = new Map<String,ObjectEntry>();
    map[entry.name] = entry;
    return 0;
  }
  
  void clear() {
    
    ObjectEntry e, f;
    int n = _currentdepth;
    // look for problem here    
    //_logbuf.webcon.writeln('in clear: curdep=${n.toString()} dicmaplen=${_dictmap.length}');
    while( n > 0 ) {
      _dictmap[n--] = null;
      _dictmap.removeLast();
    }
    _dictmap.add(null);
  }
  
  ObjectDictionary( this._logbuf, Map<String,ObjectEntry> predefined ) {
    
    _predefined = predefined;
    if( _predefined == null ) {
      _dictmap = new List<Map>();
      _dictmap.add(null);
      _currentdepth = 0;
    }
    else {
      _dictmap = new List<Map>();
      _dictmap.add(_predefined);
      _dictmap.add(null);
      _currentdepth = 1;
   }
  }
}

/**************************
 * CLASS MandyInterpreter *
 **************************/

class MandyInterpreter {

  static const
    VERBOSE_NONE = 0, VERBOSE_LOW = 1, VERBOSE_MED = 2, VERBOSE_HIGH = 3;
  
  // restart flag moved to CharBuffer instance
  // bool restart = false; // restart instruction flag;

  int completioncode, 
      interdepth = -1,   // interpreter nesting depth
      verbosity = 0;    // verbosity control
  
  WebConsole    source, console;
  CharBuffer    srcbuf, conbuf;
  CharBuffer    restartbuf;   // save read buffer for consoleevent()
  StandardObjects   stdobjs;
  ObjectDictionary  objects;
 
  int action( CharBuffer actionbuf ) {
    // interpret instructions contained in a character buffer if present
    if( actionbuf == null ) return 0;
    CharBuffer copybuf = actionbuf.duplicate();
    copybuf.allowinput = false;
    return interpret( copybuf );
  }
  
  int interpret( CharBuffer inputsource ) {

    TokenLexer  lexer = new TokenLexer( inputsource );
    bool        endofinput = false;
    int         result, token, termpos;
    
    completioncode = 0;
    
    if( inputsource.restart ) {
      // attempt instruction restart
      inputsource.restart = false;
      if( inputsource.lastlinevalid ) inputsource.refetch();
      if( verbosity > VERBOSE_MED ) {
        srcbuf.webcon.writeln('INFO: instruction restart at depth ${interdepth}');  
      }
    }
    else {      
      interdepth++;
      if( verbosity > VERBOSE_LOW && interdepth > 0 ) {
        srcbuf.webcon.writeln('INFO: depth increased to ${interdepth}');  
      }
    }
    
    while( !endofinput ) {
      
      token = lexer.nexttoken();
      if( token == TokenLexer.ENDOFINPUT ) {
        endofinput = true;
        completioncode = lexer.scanchar;
        continue;
      } else if( token == TokenLexer.WAITONINPUT ) {
        if( verbosity > VERBOSE_LOW ) 
          srcbuf.webcon.writeln('INFO: depth=${interdepth}; interpreter returned in WAIT state');
        inputsource.lastlinevalid = false;
        inputsource.restart = true;
        //restartbuf = srcbuf;
        restartbuf = inputsource;
        return token;
      }

      if( token != TokenLexer.NAME ) {
        srcbuf.webcon.writeln('WARNING: Expecting object name, found "${lexer.lastscanchar}');
        continue;
        }
      
      ObjectEntry obj = objects.locate(lexer.name);
      if( obj != null ) {
        
        if( verbosity > VERBOSE_NONE ) 
          srcbuf.webcon.writeln('INFO: depth=${interdepth}; interpret sees object "${lexer.name}"');

        if( obj.dict != null && lexer.scanchar == TokenLexer.period ) {
          // there's a dictionary and property/method, grab it
          lexer.nexttoken();
          int tok = lexer.nexttoken();
          if( tok != TokenLexer.NAME ) {
            srcbuf.webcon.writeln('WARNING: Expecting method name, found "${lexer.lastscanchar}');
            continue;            
          }
          ObjectEntry e = objects.locate_from( obj.dict, lexer.name);   
          if( e == null ) {
            srcbuf.webcon.writeln('ERROR: unrecognized method "${lexer.name}"');
            continue;
            }
          if( e.input != null ) {
            // use the input method.
            if( verbosity > VERBOSE_MED )
              srcbuf.webcon.writeln('INFO: "${obj.name}.${e.name}" recognized, calling input method');
            
            lexer.clearscan();
            objects.changedepth(1);
            objects.dictmap = obj.dict;
            result = e.input( inputsource, e.dict, e.data, e.help );
            objects.changedepth(-1);
          } else 
            srcbuf.webcon.writeln('ERROR: no input method for "${lexer.name}"');
        }
        else if( obj.input != null ) {
          // use the input method.
          if( verbosity > VERBOSE_MED )
            srcbuf.webcon.writeln('INFO: "${obj.name}" recognized, calling input method');
          
          lexer.clearscan();
          result = obj.input(inputsource, obj.dict, obj.data, obj.help );
          
          if( verbosity > VERBOSE_MED ) 
            srcbuf.webcon.writeln('INFO: object returned ${StandardObjects.ErrorMap[result]}');
          if( result == CharBuffer.WAIT ) {
            if( verbosity > VERBOSE_LOW ) 
              srcbuf.webcon.writeln('INFO: depth=${interdepth}; interpreter returned in WAIT state');
            inputsource.restart = true;
            //restartbuf = srcbuf;
            restartbuf = inputsource;
            return result;
          }
          if( result < 0 || result == StandardObjects.CONTROL_END ||
              (result != 0 && objects.depth > 0 ) ) {
            if( verbosity > VERBOSE_LOW ) 
              srcbuf.webcon.writeln('INFO: interpreter returned with ${StandardObjects.ErrorMap[result]}');
            interdepth--;
            return result;          
          }
        }

      } else srcbuf.webcon.writeln('WARNING: unrecognized object "${lexer.name}"');

    } // end of while not endofinput
    
    // normal return    
    interdepth--;
    if( verbosity > VERBOSE_LOW && interdepth > 0 ) {
      srcbuf.webcon.writeln('INFO: level moving down to ${interdepth}');  
    }
    return completioncode;  
  }

  void sourceevent() {
    /*
     * this doesn't work right. The first time it's called interdepth is raised 
     * from -1 to 0. But interpreter returns in WAITONINPUT state and level never
     * can return to -1. I can't set allowinput to false because the WebConsole
     * needs to read for input.
     */
    interpret( srcbuf );
    conbuf.deliver();
    srcbuf.deliver();
  }

  void consoleevent() {
    if( restartbuf != null && restartbuf.restart ) {
      interpret( restartbuf );
      conbuf.deliver();
      srcbuf.deliver();
    }
  }

  MandyInterpreter( doc, sourceclass, consoleclass ) {

    console   = new WebConsole( doc, consoleclass);
    conbuf    = new CharBuffer( console );
    console.inputeventhandler = consoleevent;

    if( sourceclass != null && sourceclass.length > 0 ) {
      // create a source buffer
      source    = new WebConsole( doc, sourceclass );
      srcbuf    = new CharBuffer( source );
      source.inputeventhandler = sourceevent;
    } else {
      // create a dummy so that errors have a place to display
      // by using the console webcon in allowinput = false mode
      srcbuf    = new CharBuffer( console );
      srcbuf.allowinput = false;
    }
    
    stdobjs   = new StandardObjects( conbuf, srcbuf );
    objects   = new ObjectDictionary( srcbuf, stdobjs.dictmap );
    stdobjs.referals = objects;
    stdobjs.interp = this;
  }
}

