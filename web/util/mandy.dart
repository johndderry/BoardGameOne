import 'dart:html';
import '../libr/interpreter.dart';
import '../libr/webfilesys.dart';
import '../libr/bufferedhtmlio.dart';
   
ButtonElement clearobjects, load, save, 
  clearconsole, clearsource, incrverb, decrverb;
TextInputElement  nameText, verbosity;
TextAreaElement   sourceText;
SelectElement     helpRoot, helpSelect;
WebFileSys        filesys;
MandyInterpreter  mandy;

WebConsole    helpconsole;
CharBuffer    conbuf;
HelpIndex     helproot, helpindex;

class HelpIndex{
  String name;
  Map<String,String> map;
  HelpIndex     next;
}

void addPDOption(SelectElement select, String name) {
  OptionElement option = new OptionElement();
  option.value = option.text = name;
  select.append(option);
}

void helpconsoleevent() {
  // fetch the input and then clear it out after looking up help
  String answer;
  conbuf.fetch();
  answer = StandardObjects.helpindex[conbuf.string.trimRight()];
  conbuf.webcon.clear();  // throws out last response
  conbuf.clear();         // throws out leftover input
  if( answer == null )
    conbuf.addAll('No help available<br>'.codeUnits);
  else   
    conbuf.addAll('${answer}<br>'.codeUnits);
  conbuf.deliver();
    
  }

void main() {
  
  clearobjects = querySelector('#clearobjects');
  load = querySelector('#load');
  save = querySelector('#save');
  clearconsole = querySelector('#clearconsole');
  clearsource = querySelector('#clearsource');
  incrverb = querySelector('#incrverb');
  decrverb = querySelector('#decrverb');
  helpRoot = querySelector("#helpRoot");
  helpSelect = querySelector("#helpSelect");

  clearobjects.onClick.listen(buttonpress);
  load.onClick.listen(buttonpress);
  save.onClick.listen(buttonpress);
  incrverb.onClick.listen(buttonpress);
  decrverb.onClick.listen(buttonpress);
  helpRoot.onClick.listen(buttonpress);    
  helpSelect.onClick.listen(buttonpress);    
  
  nameText = querySelector('#loadname');
  verbosity = querySelector('#verbosity');
  sourceText = querySelector('#sourcetext');
  helpSelect = querySelector('#helpSelect');
  helpRoot = querySelector('#helpRoot');
  TextAreaElement websyslog = querySelector('#websyslog');
  
  mandy     = new MandyInterpreter( document, '.source', '.console' ); 
  filesys   = new WebFileSys(websyslog);

  helpconsole = new WebConsole(document, '.helpdiv');
  helpconsole.echo = false;
  conbuf    = new CharBuffer( helpconsole );
  helpconsole.inputeventhandler = helpconsoleevent;

  helproot = helpindex = new HelpIndex();
  helpindex.name = 'script standard objects';
  helpindex.map = StandardObjects.helpindex; 
  addPDOption( helpRoot, helpindex.name );
  
  Iterator keys_iter = helproot.map.keys.iterator;
   while( keys_iter.moveNext() ) {
     addPDOption( helpSelect, keys_iter.current );
   }
}
  
void buttonpress(Event e) {
  
  String src;
  if( e.currentTarget == clearobjects ) 
    mandy.objects.clear();
  else if( e.currentTarget == load ) 
    filesys.loadtext('${nameText.value}.mdy', sourceText);
  else if( e.currentTarget == save )  
    filesys.savetext('${nameText.value}.mdy', sourceText);
  else if( e.currentTarget == incrverb ) {
    mandy.verbosity++;
    verbosity.value = mandy.verbosity.toString();
  }
  else if( e.currentTarget == decrverb ) {
    if( mandy.verbosity > 0 ) {
      mandy.verbosity--;
      verbosity.value = mandy.verbosity.toString();
    }
  }
  else if( e.currentTarget == helpRoot ) {
    // get the right helpindex in place
    List<OptionElement> opt = helpRoot.selectedOptions;
    int indx = opt[0].index;
    helpindex = helproot;
    while( indx-- > 0 && helpindex.next != null ) 
      helpindex = helpindex.next; 
    // reload the options for display
    Node e;
    // clear old list and any help first
    while( (e = helpSelect.firstChild) != null ) e.remove();
    helpconsole.clear();
    // load new list
    Iterator keys_iter = helpindex.map.keys.iterator;
    while( keys_iter.moveNext() ) {
      addPDOption( helpSelect, keys_iter.current );
    }
  }
  else if( e.currentTarget == helpSelect ) {
    List<OptionElement> opt = helpSelect.selectedOptions;
    String answ = helpindex.map[opt[0].innerHtml]; 
    helpconsole.clear();
    helpconsole.writeln(answ);
  }

}
