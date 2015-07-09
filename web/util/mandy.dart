/**************************
  *  BoardGameOne files   *
  *  (c) John Derry 2015  *
 **************************/
import 'dart:html';
import '../lib/interpreter.dart';
import '../lib/webfilesys.dart';
   
ButtonElement clearobjects, load, save, 
  clearconsole, clearsource, incrverb, decrverb;
TextInputElement  nameText, verbosity;
TextAreaElement   sourceText;
WebFileSys        filesys;
MandyInterpreter  mandy;

void main() {
  
  clearobjects = querySelector('#clearobjects');
  load = querySelector('#load');
  save = querySelector('#save');
  clearconsole = querySelector('#clearconsole');
  clearsource = querySelector('#clearsource');
  incrverb = querySelector('#incrverb');
  decrverb = querySelector('#decrverb');
  
  clearobjects.onClick.listen(buttonpress);
  load.onClick.listen(buttonpress);
  save.onClick.listen(buttonpress);
  incrverb.onClick.listen(buttonpress);
  decrverb.onClick.listen(buttonpress);
  
  nameText = querySelector('#loadname');
  verbosity = querySelector('#verbosity');
  sourceText = querySelector('#sourcetext');
  TextAreaElement websyslog = querySelector('#websyslog');
  
  mandy     = new MandyInterpreter( document, '.source', '.console' ); 
  filesys   = new WebFileSys(websyslog);
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
  
}
