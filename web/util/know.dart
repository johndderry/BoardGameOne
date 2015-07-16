import 'dart:html';
import '../lib/bufferedhtmlio.dart';
import '../parser/parser.dart';

WebConsole    queryCon, additionCon;
Parser        addParser, queryParser;
englishParserDef english;
KnowBase      base, additions;
List<PackSent> queryList;

ButtonElement showB, showBS, loadB, saveB, updateB, deleteB;
CheckboxInputElement verboseCB;
TextInputElement  addcountText, basecountText, querycountText, KnowName, deleteposText; 

void dumpnode( WordNode node, List<WordNode> sh ) {
  
  int margin = -1;
  
  void list( String head, WordNode node ) {
    margin++;  
    StringBuffer marg = new StringBuffer();
    WordNode n = node;
    for( int i = 0; i < margin; i++ ) marg.write('__');
    //stdout.writeln('\n${marg.toString()}${head}:');
    additionCon.write('${marg.toString()}${head}: ');
    //marg.write('  ');
    bool first = true;
    while( n != null ) {
      //stdout.write('${marg.toString()}${n.desc}:');
      if( first ) 
        if( n.nonw != null && n.nonw >= 0 )
          additionCon.write('nonw=${english.nonwNames[n.nonw]};<br>${marg.toString()}');
        else 
          additionCon.write('<br>${marg.toString()}');
      else
        if( n.nonw != null && n.nonw >= 0 )
          additionCon.write('${marg.toString()}nonw=${english.nonwNames[n.nonw]};${marg.toString()}');
        else  
          additionCon.write(marg.toString());
      if( n.meaning != null && n.meaning >= 0 ) additionCon.write('meaning=${english.meaningNames[n.meaning]};');
      if( n.pos != null && n.pos >= 0 ) additionCon.write('pos=${english.posNames[n.pos]};');
      if( n.plu != null && n.plu >= 0 ) additionCon.write('plu=${english.pluNames[n.plu]};');
      if( n.tense != null && n.tense >= 0 ) additionCon.write('tense=${english.tenseNames[n.tense]};');
      additionCon.writeln('');
      if( n.foremod != null ) list('ForeMOD', n.foremod);
      if( n.backmod != null ) list('BackMOD', n.backmod);
      if( n.sub != null ) list('Subject', n.sub);
      if( n.act != null ) list('Action', n.act);
      if( n.obj != null ) list('Object', n.obj);
      if( n.repeater != null ) additionCon.write('rep:${n.repeater}');
      first = false;
      n = n.next;
    }
    margin--;
  }
  
  //additionCon.write('<div style="margin-left:40px">');
  if( node == null ) {
    additionCon.writeln('parse returned null');
    showShift( additionCon, sh );
  }
  else list('Sentence', node);  
  additionCon.write('</div>');
}

void showbase() {
  additionCon.writeln('<br>All Base:');
  additionCon.writeln( base.show() );
}

void showother() {
  additionCon.writeln('<br>Additions/Queries:');
  additionCon.writeln( additions.show() );
}

void mergeadditions() {
  additionCon.write('<br>Merging additions. ');
  int mergecnt = base.merge( additions );
  additionCon.writeln('Base new count = ${mergecnt}');
  updatecount();
}

void updatecount() {
  
  addcountText.value = additions.sentdata.length.toString();
  basecountText.value = base.sentdata.length.toString();
  if( queryList != null )
    querycountText.value = queryList.length.toString();
}

void button_event(Event e) {
  if( e.currentTarget == showB ) 
    showother();
  if( e.currentTarget == showBS ) 
    showbase();
  else if( e.currentTarget == updateB ) 
    mergeadditions();
  else if( e.currentTarget == loadB ) 
    base.read( KnowName.value );
  else if( e.currentTarget == saveB ) 
    base.write( KnowName.value );       
  else if( e.currentTarget == deleteB ) {
    int indx =  int.parse(deleteposText.value);
    if( indx < queryList.length ) {
      if( base.sentdata.remove( queryList[indx])) 
        updatecount();
    }
  }
}

void onQuery() {
  
  WordNode wn;
  PackSent psent;
  StringBuffer buf;
  
  queryParser.endofinput = false;
  while( queryParser.endofinput == false ) {
    wn = queryParser.parse();
    if( verboseCB.checked ) {
      base.verbose = true;
      dumpnode( wn, queryParser.shift );
    }
    else base.verbose = false;
    if( wn == null ) {
      queryCon.writeln("Sorry, I don't understand that.");
      continue;
    }
    queryList = base.query(wn);
    if( queryList == null || queryList.length == 0 ) {
      queryCon.writeln("I don't know.");
      continue;      
    }
    if( wn.nonw == 0 ) continue;
    queryCon.writeln("Yes, I know. ");

    buf = new StringBuffer();
    for( psent in queryList ) {
      //buf.write('<ul>');
      base.makesentence(buf, psent.root, "");
      //buf.write('</ul>');
    }      
    /* queryCon.writeln( '<ol>${buf.toString()}</ol>' ); */
    queryCon.writeln( '${buf.toString()}' );     
  }
}

void onAddition() {
  
  WordNode wn;
  addParser.endofinput = false;
  while( addParser.endofinput == false ) {
    wn = addParser.parse();
    if( verboseCB.checked ) dumpnode( wn, addParser.shift );
    if( wn == null ) {
      additionCon.writeln("Sorry, I don't understand that.");
      continue;
    }
    if( wn.nonw == 0 ) continue;
    if( additions.learn( wn )) updatecount();
  }
}

void main() {
  
  showB = querySelector('#show');
  showBS = querySelector('#showbase');
  loadB = querySelector('#load');
  saveB = querySelector('#save');
  deleteB = querySelector('#delete');
  updateB = querySelector('#update');
  KnowName = querySelector('#knowledgename');
  verboseCB = querySelector('#verbose');
  addcountText = querySelector('#addcount');
  querycountText = querySelector('#querycount');
  basecountText = querySelector('#basecount');
  deleteposText = querySelector('#deletepos');
  
  queryCon = new WebConsole( document, '.query');
  additionCon = new WebConsole( document, '.additions');
  
  english = new englishParserDef();  
  queryParser = new Parser(queryCon, english);
  addParser = new Parser(additionCon, english);

  // base uses the same reporting console as additions
  base = new KnowBase(additionCon, english);
  additions = new KnowBase(additionCon, english);

  queryCon.inputeventhandler = onQuery;
  additionCon.inputeventhandler = onAddition;
 
  english.parser = addParser;  // this could be problematic
  english.createwords();
  english.createrules();
 
  showB.onClick.listen(button_event);    
  showBS.onClick.listen(button_event);    
  loadB.onClick.listen(button_event);    
  saveB.onClick.listen(button_event);  
  deleteB.onClick.listen(button_event);  
  updateB.onClick.listen(button_event);  
  verboseCB.onClick.listen(button_event);
}