/**************************
  *  BoardGameOne files   *
  *  (c) John Derry 2015  *
 **************************/
/*
 *  Dart implemention of Mandy interpreter, console I/O
 *  using dart:io library
 */

library bufferedhtmlio;
import 'dart:collection';
import 'dart:html';

/*
 * Everybody reads this from here
 */

const HOSTNAME = "127.0.0.1:8080";

/* 
 */

class WebConsole {
            
  ButtonElement     _accept, _clear;
  TextInputElement  _inputline;
  TextAreaElement   _inputarea;
  var               _text;
  String            _input;
  bool              inputready = false, echo = true;

  var               outputeventhandler, inputeventhandler;

  void _accepttext(Event e) {
    String textarea;
    if( _inputarea == null || _inputarea.value.length == 0 ) return;
    _input = '${_input}${_inputarea.value}\n';
    textarea = _inputarea.value.replaceAll('\n', '<br>');
    if( echo ) 
      _text.innerHtml = '${_text.innerHtml}${textarea}';
    //_inputarea.value = '';
    inputready = true;
    if( inputeventhandler != null) inputeventhandler();
  }
 
  void _cleartext(Event e) {
    _text.innerHtml = '';    
  }
  
  void _listeninput(KeyboardEvent e) {
    if( e.keyCode == '\r'.codeUnits[0] ) 
      _acceptInput();
  }
    
  void _acceptInput() {
    if( _inputline.value.length == 0 ) return;
    if( echo ) 
      _text.innerHtml = '${_text.innerHtml}${_inputline.value}<br>';
    _input = '${_input}${_inputline.value}';
    _inputline.value = '';
    inputready = true;
    if( inputeventhandler != null) inputeventhandler();
  }

  /* begin public methods */
  
  WebConsole clear() {
    
    _text.innerHtml = '';
    return this;
  }

  String gettext() {
    return _text.innerHtml;
  }
  
  String readline() {
    String retstring;
    int nlpos = _input.indexOf('\n');
    if( nlpos < 0 || nlpos == _input.length -1  ) {
      // no newline or single newline at the end of input
      inputready = false;
      retstring = _input;
      _input = '';
      return retstring;
    }
    // grab the first line as input
    retstring = _input.substring(0, nlpos + 1);
    _input = _input.substring( nlpos + 1 );
    return retstring;
  }

  WebConsole write(String s) {
    
    _text.innerHtml = '${_text.innerHtml}<b>${s}</b>';
    if( outputeventhandler != null) outputeventhandler();
    return this;
  }

  WebConsole writeln(String s) {
    
    _text.innerHtml = '${_text.innerHtml}<b>${s}</b><br>';
    if( outputeventhandler != null) outputeventhandler();
    return this;
  }

  WebConsole( HtmlDocument doc, String htmlclass ) {
    
    var list = querySelectorAll(htmlclass);
    for( Element elem in list ) {
      switch( elem.nodeName ) {
        case 'INPUT':   _inputline = elem;
          _inputline.onKeyUp.listen(_listeninput);
          break;
        case 'TEXTAREA':  _inputarea = elem; break;
        case 'P': 
        case 'DIV':     _text = elem; break;
        case 'BUTTON':
          if( elem.id == 'clear' ) {
            _clear = elem;
            _clear.onClick.listen(_cleartext);
          }
          else {
            _accept = elem;
            _accept.onClick.listen(_accepttext);
          }
          break;      
      }      
    }

    _input = '';
  }
}

class CharBuffer extends ListBase<int> {
  
  static const WARNING = 10, EOF = -1, WAIT = -2, ERROR  = -3;
  static final int newline = '\n'.codeUnits[0];
  
  WebConsole  webcon;
  bool        allowinput = true, allowoutput = true;
  bool        restart = false, lastlinevalid = true;
  bool        echo = true;
  int         currentpos = 0;
  String      _lastline;
  
  List<int> innerList = new List<int>();
  
  int get length => innerList.length;
  
  void set length(int len) {
    innerList.length = len;
  }

  void operator[]=(int index, int value) {
      innerList[index] = value;
    }

  int operator [](int index) => innerList[index];

  /* input based functions */
  
  int fetch() {
    
    // fetch one line of input and transfer to buffer
    
    if( webcon == null || !allowinput ) return EOF;
    if( webcon.inputready == false ) return WAIT;

    _lastline = webcon.readline();
    lastlinevalid = true;
    
    innerList.clear();
    innerList.addAll(_lastline.codeUnits);
    innerList.add(newline);
    currentpos = 0;
    return innerList.length;
  }

  void refetch() {    
    innerList.clear();
    innerList.addAll(_lastline.codeUnits);
    innerList.add(newline);
    currentpos = 0;    
  }
  
  int fetchuntil(String term) {
    
    // fetch mutiple lines from specified source
    // until terminator string is located
    
    if( webcon == null || !allowinput ) return EOF;
    if( webcon.inputready == false ) return WAIT;

    String line;
    while( webcon.inputready && !(line = webcon.readline()).contains(term, 0) ) {
    
      List<int> codeunits = line.codeUnits;
      innerList.addAll(codeunits);
      innerList.add(newline);
    }
    return innerList.length;
  }

  int getchar() {

    int r;
    if( innerList.length == 0 ) {
      if( (r = fetch()) <= 0 ) return r;
    }
    if( currentpos >= innerList.length ) return ERROR;
    return innerList.removeAt( currentpos );
  }

  void ungetchar(int c) {
    innerList.insert( currentpos, c );
  }
  
  /*
   * output based functions
   */

  void deliver() {
    
    if( webcon == null || !allowoutput || length == 0 ) return;

    int i = 0;
    StringBuffer sbuf = new StringBuffer();
   
    while( i < innerList.length ) sbuf.writeCharCode(innerList[i++]);
    //webcon.writeln( sbuf.toString() );
    webcon.write( sbuf.toString() );
    innerList.clear();
    currentpos = 0;
  }

  void insertchars( List<int> chars ) {
    
    innerList.insertAll(currentpos, chars);  
  }
  
  void insertAll(int index, Iterable<int> iterable) => innerList.insertAll(index, iterable);
  
  void add(int value) => innerList.add(value);
  
  void addAll(Iterable<int> all) => innerList.addAll(all);
  
  CharBuffer duplicate() {
    // return a duplicate copy of self
    CharBuffer ret = new CharBuffer( this.webcon );
    ret.addAll( innerList );
    ret.allowinput = allowinput;
    ret.allowoutput = allowoutput;
    return ret;
  }
  
  String get string {
    StringBuffer buf = new StringBuffer();
    for( int c in innerList ) 
      buf.writeCharCode(c);
    return buf.toString();
  }
  
  CharBuffer( this.webcon );
}
