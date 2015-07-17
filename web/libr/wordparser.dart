part of makeparser;

const wordinsertcode = '''\n  Map<String,WordNode> wordMap = new Map();
  Map<int,List<WordNode>> meaningMap = new Map();
  void createWD(String text,String desc,int meaning,int pos,int plu,int tense) {
    WordNode w, v; List<WordNode> l;
    if((w = wordMap[text]) == null) wordMap[text] = v = new WordNode(text,desc,pos,meaning,plu,tense);
    else {
      while(w.next != null) w = w.next;
      w.next = v = new WordNode(text,desc,pos,meaning,plu,tense);
    }
    if((l = meaningMap[meaning]) == null ) {
      l = new List();
      l.add( v ); meaningMap[meaning] = l;
    } else 
      l.add( v );
  }
  void createwords() {''';

class Word {
  String text, meaning;
  String pos, plu, tense;
  void display() {
    stdout.write('Text=${text} Meaning=${meaning} ');
    if( pos != null ) stdout.write('pos=${pos} ');
    if( plu != null ) stdout.write('plu=${plu} ');
    if( tense != null ) stdout.write('tense=${tense} ');
    stdout.writeln();
  }
}

List<Word>      wordlist;
Map<String,int> meaningMap, posMap, tenseMap, pluMap;

void gen_word_code( IOSink ios ) {
  // generate static constant statements as well as descriptive lists
  // for representing word parts
  // first create maps for these parts by reading thru word lists
  int imeaning=0, ipos=0, itense=0, iplu=0; 
  StringBuffer cbuf, lbuf;
  meaningMap = new Map(); posMap = new Map(); tenseMap = new Map(); pluMap = new Map();
  for( Word w in wordlist ) {
    if( meaningMap[w.meaning] == null ) meaningMap[w.meaning] = imeaning++; 
    if( w.pos != null && posMap[w.pos] == null ) posMap[w.pos] = ipos++; 
    if( w.plu != null && pluMap[w.plu] == null ) pluMap[w.plu] = iplu++; 
    if( w.tense != null && tenseMap[w.tense] == null ) tenseMap[w.tense] = itense++; 
  }
  // now generate statements in output file
  Iterable<String> names; Iterable<int> values; int i;
  /*
   *  MEANING
   */
  cbuf = new StringBuffer(); lbuf = new StringBuffer();
  cbuf.write('  static const ');
  lbuf.write('  List<String> meaningNames = [');  
  names = meaningMap.keys; values = meaningMap.values;
  for( i = 0; i < names.length-1; i++ ) {
    cbuf.write('meaning_${names.elementAt(i)}=${values.elementAt(i)}, ');
    lbuf.write('\'${names.elementAt(i)}\', ');
  }
  if( names.length > 0 ) {
    cbuf.write('meaning_${names.elementAt(i)}=${values.elementAt(i)};');
    lbuf.write('\'${names.elementAt(i)}\'];');
    ios.writeln(cbuf.toString());
    ios.writeln(lbuf.toString());
  }
  /*
   *  PartOfSpeach
   */
  cbuf = new StringBuffer(); lbuf = new StringBuffer();
  cbuf.write('  static const ');
  lbuf.write('  List<String> posNames = [');  
  names = posMap.keys; values = posMap.values;
  for( i = 0; i < names.length-1; i++ ) {
    cbuf.write('pos_${names.elementAt(i)}=${values.elementAt(i)}, ');
    lbuf.write('\'${names.elementAt(i)}\', ');
  }
  if( names.length > 0 ) {
    cbuf.write('pos_${names.elementAt(i)}=${values.elementAt(i)};');
    lbuf.write('\'${names.elementAt(i)}\'];');
    ios.writeln(cbuf.toString());
    ios.writeln(lbuf.toString());
  }
  /*
   * PLURALITY
   */
  cbuf = new StringBuffer(); lbuf = new StringBuffer();
  cbuf.write('  static const ');
  lbuf.write('  List<String> pluNames = [');  
  names = pluMap.keys; values = pluMap.values;
  for( i = 0; i < names.length-1; i++ ) {
    cbuf.write('plu_${names.elementAt(i)}=${values.elementAt(i)}, ');
    lbuf.write('\'${names.elementAt(i)}\', ');
  }
  if( names.length > 0 ) {
    cbuf.write('plu_${names.elementAt(i)}=${values.elementAt(i)};');
    lbuf.write('\'${names.elementAt(i)}\'];');
    ios.writeln(cbuf.toString());
    ios.writeln(lbuf.toString());
  }
  /*
   * TENSE
   */
  cbuf = new StringBuffer(); lbuf = new StringBuffer();
  cbuf.write('  static const ');
  lbuf.write('  List<String> tenseNames = [');  
  names = tenseMap.keys; values = tenseMap.values;
  for( i = 0; i < names.length-1; i++ ) {
    cbuf.write('tense_${names.elementAt(i)}=${values.elementAt(i)}, ');
    lbuf.write('\'${names.elementAt(i)}\', ');
  }
  if( names.length > 0 ) {
    cbuf.write('tense_${names.elementAt(i)}=${values.elementAt(i)};');
    lbuf.write('\'${names.elementAt(i)}\'];');
    ios.writeln(cbuf.toString());
    ios.writeln(lbuf.toString());
  }
  /*
   *  create instance creation code for words in list  
   */
  ios.writeln(wordinsertcode);
  for( Word w in wordlist ) {
    imeaning = meaningMap[w.meaning];
    if( w.pos == null ) ipos = -1;
    else ipos = posMap[w.pos];
    if( w.plu == null ) iplu = -1;
    else iplu = pluMap[w.plu];
    if( w.tense == null ) itense = -1;
    else itense = tenseMap[w.tense];
    ios.writeln('    createWD(\'${w.text}\',\'${w.pos}\',${imeaning},${ipos},${iplu},${itense});');
  }
  ios.writeln('  }');
}

void displaywords() {
  for(Word word in wordlist ) {
    stdout.write('Word ${word.text}: ');
    word.display();
  }
}

Word parseProps( String properties) {
  String p;
  Word word = new Word();
  for( p in properties.split(';') ) {
    List<String> keyval = p.split('=');
    switch(keyval[0]) {
      case 'pos': word.pos = keyval[1]; break;
      case 'tense': word.tense = keyval[1]; break;
      case 'plu': word.plu = keyval[1]; break;
    }
  }
  return word;
}

bool parsesourcewords( String words ) {

  void parseWord( String word ) {
   
    Word newword; String text; int i,j;
    i = word.indexOf(' ');
    if( i < 0 ) i = word.indexOf('\t');
    if( i < 0 ) {
      stderr.writeln('error parsing "${word}"');
      return;
    }
    //newword = new Word();
    text = word.substring(0,i);
    word = word.substring(i+1);
    word = word.trimLeft();
    i = word.indexOf('(');
    j = word.indexOf(')');
    if( i < 0 || j < 0 ) {
      stderr.writeln('error parsing ${word}');
      return;
    }
    newword = parseProps( word.substring(i+1,j) );
    newword.text = text;
    newword.meaning = word.substring(0,i);
    
    wordlist.add(newword);    
  }
  
  wordlist = new List<Word>();
  List<String> wordtext = words.split('\n');
  wordtext.forEach(parseWord);
  if( wordlist.length > 0 ) return true;
  else return false;
}