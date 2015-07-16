library NLPparser;

import 'dart:html';
import 'dart:convert';
import '../lib/bufferedhtmlio.dart';

part 'english_definition.dart';
part 'knowledge.dart';

bool verbose = false;

void showShift( WebConsole con, List<WordNode> sh ) {
    
  WordNode wn, w;;
  con.write('Shift:');
  for( wn in sh ) {
    con.write('[${wn.desc}');
    w = wn.next;
    while( w != null ) {
      con.write('/${w.desc}');
      w = w.next;        
    }
    con.write(']');
  }
  con.writeln('');
}

class Parser {
  String            line;
  WebConsole        console;
  englishParserDef  parserdef;
  List<WordNode>    shift;
  bool              endofinput = false;
  int               terminator;
  static const bool NL_ENDS_INPUT = true;
  
  Parser(this.console, this.parserdef);
  
  WordNode nextword() {
  
    int end, generic_end;
    bool haveWord, haveGeneric;
    WordNode node;
    String wordstring, trailer;
   
    int getLocInList( List<String>list, String str ) {
      String s; int n = 0;
      for( s in list ) {
       if( s == str ) return n;
       n++;
      }
      return -1;
    }
    
    WordNode parseGeneric(String def) {
      WordNode node = new WordNode("generic","",-1, -1, -1 , -1 );
      List<String> pair, assig = def.split(' ');
      String as; int indx;
      console.writeln('parsing generic "${wordstring}"');
      for( as in assig) {
        pair = as.split('=');
        if( pair.length == 2) {
          console.write('see "${pair[0]} ${pair[1]}"');
          switch( pair[0] ) {
            case "pos": indx = getLocInList( parserdef.posNames, pair[1]); 
              if( indx >= 0 )  node.pos = indx;
              break;
            case "plu": indx = getLocInList( parserdef.pluNames, pair[1]); 
              if( indx >= 0 )  node.plu = indx;
              break;
            case "tense": indx = getLocInList( parserdef.tenseNames, pair[1]); 
              if( indx >= 0 )  node.tense = indx;
              break;
           }
        }
      }
      return node;
    }
    
    bool lookforpunc(String pchar ) {
      int check = line.indexOf(pchar);
      if( check == 0 ) {
        line = line.substring(1);
        return true;
      }
      else  if( check > 0 ) {
        if( end < 0 || check < end ) {
          end = check;
        }
      }
      return false;
    }
    
    while( !haveWord && !haveGeneric ) {
      if( line == null || line.length == 0 ) {
        line = console.readline();
        if( line == null || ( NL_ENDS_INPUT && line.length == 0 ))
           return new WordNode.nonword(ENDOFINPUT, 'endofinput');
      }
      line = line.trimLeft();
      if( line.length == 0 ) continue;
      end = line.indexOf(' ');

      if( lookforpunc('.'))
         return new WordNode.nonword(PERIOD, 'period');
      if( lookforpunc(','))
        return new WordNode.nonword(COMMA, 'comma');
      if( lookforpunc(':'))
        return new WordNode.nonword(COLON, 'colon');
      if( lookforpunc(';'))
        return new WordNode.nonword(SEMICOLON, 'semicolon');
      if( lookforpunc('?'))
        return new WordNode.nonword(QUESTION, 'question');

      if( lookforpunc('(')) {
        // this is a generic word, used as wildcards
        haveGeneric = true;
        trailer = null;
        generic_end = line.indexOf(')');
        if(end < 0 ) {  // theres a trailer
          if( line.length > generic_end )  // theres a trailer
            trailer = line.substring(generic_end+1);
          
          wordstring = line.substring(0,generic_end);          
          line = null;
        } else {
          if( end - generic_end == 1 ) // theres a trailer
            trailer = line.substring(generic_end+1);
          wordstring = line.substring(0,generic_end);
          line = line.substring(end);
        }
      } else {
      
        if( end < 0 ) {
          wordstring = line;
          line = null;
        } else {
          wordstring = line.substring(0, end);
          line = line.substring(end);
        }
        // if we have found viable word, leave
        if( wordstring.length > 0 ) haveWord = true;
      }
    }
    
    // look up the word node by it's appearance
    if( haveWord ) {
      node = parserdef.wordMap[wordstring];
      if( node == null ) {
        console.writeln('word not recognized: "${wordstring}"');
        return new WordNode.nonword(UNKNOWN,'unknown');
      }
      node = node.dup;  // get of duplicate of word and linked list
      if( verbose ) console.writeln('saw "${wordstring}"');
      return node;
    }
    if( haveGeneric ) {
      node = parseGeneric(wordstring);
      if( node == null ) {
        console.writeln('generic not recognized: "${wordstring}"');
        return new WordNode.nonword(UNKNOWN,'unknown');
      }
      node.repeater = trailer;
      if( verbose ) {
        console.writeln('saw "${wordstring} "');
        if( trailer != null ) console.writeln('trailer "${trailer}"');
      }
      return node;      
    }
    return null;
  }
  
  WordNode sent(WordNode phrsA, WordNode conn, WordNode phrsB) {
    if( phrsA == null ) return phrsB;
    WordNode p = phrsA;
    while( p.next != null ) p = p.next;
    p.next = conn;
    conn.prev = p;
    conn.next = phrsB;
    phrsB.prev = conn;
    return phrsA;
  }
  
  WordNode intr(WordNode int, WordNode act, WordNode obj) {
    WordNode wn = new WordNode.nonword(-1,'interogative');
    wn.sub = int;
    wn.act = act;
    wn.obj = obj;
    if( int != null ) int.up = wn;
    if( act != null ) act.up = wn;
    if( obj != null ) obj.up = wn;
    return wn;
  }
  
  WordNode phrs(WordNode sub, WordNode act, WordNode obj) {
    WordNode wn = new WordNode.nonword(-1,'phrase');
    wn.sub = sub;
    wn.act = act;
    wn.obj = obj;
    if( sub != null ) sub.up = wn;
    if( act != null ) act.up = wn;
    if( obj != null ) obj.up = wn;
    return wn;
  }
  
  WordNode prephs(WordNode prep, WordNode mod, WordNode obj) {
    WordNode wn = new WordNode.nonword(-1,'prepphrase');
    wn.act = prep;
    wn.obj = obj;
    wn.obj.foremod = mod;
    prep.up = obj.up;
    return wn;
  }
  
  WordNode append(WordNode list, WordNode item) {
    if( list == null ) return item;
    WordNode p = list;
    while( p.next != null ) p = p.next;
    p.next = item;
    item.prev  = p;
    return list;
    
  }
  
  bool checkReduction( int precedence, List<WordNode> sh ) {
    if( verbose ) showShift( console, sh );
    RuleDef rule;
    bool submatch, rulematch = false;
    int shpos, chpos, pos, startpos;
    WordNode wn;
    List<int> chainpos; // track which chained word variation was matched
    for( rule in parserdef.rules ) {
      if( rule.prec == precedence ) {
        // check each rule against the tail of shifted word list
        startpos = sh.length - rule.terms.length;
        if( startpos < 0 ) continue; // shift is too short for this rule
        rulematch = true; pos = 0; chainpos = new List<int>();
        for( shpos = startpos; shpos < sh.length; shpos++, pos++) 
          if( (wn = sh[shpos]).nonw >= 0 ) {
            // word at shift pos is nonword, compare two nonwords
            if( wn.nonw != rule.terms[pos].nonw ) {
              rulematch = false;
              break;
            }
          } else {
            // for terminals, for each variation of word in chained list look for a rulematch
            chpos = 0;
            submatch = false;
            while( wn != null ) {   
              if( wn.pos == rule.terms[pos].pos ) {
                submatch = true;
                break;
              }
              wn = wn.next; chpos++;
            }
            if( submatch == false ) {
              rulematch = false;
              break;
            } else
              chainpos.add(chpos);  // record which possible chained word was used
          }      
        if( rulematch == true ) break;
      }
    }
    if( rulematch == true ) {
      WordNode word;
      if( verbose ) console.writeln(
      'reducing ${rule.terms.length} terms to \'${rule.name}\' by rule ${rule.ident}');
      List<WordNode> extract = sh.sublist(startpos);
      // remove any unused chained words 
      if( true ) {
        int i;
        chpos = 0; // we have to keep a seperate count of chainpos position    
        for( pos = 0; pos < extract.length; pos ++ )
          // only look at words, ignore nonword terms. To do this
          if( extract[pos].nonw < 0 ) {
            if( (i = chainpos[chpos++]) > 0 ) {
              wn = extract[pos];
              while( i-- > 0 )
                wn = wn.next;
              extract[pos] = wn;
            } else wn.next = null;
          }
        }
      sh.removeRange(startpos, sh.length);
      word = parserdef.doAction( rule.name, rule.ident, extract);
      if( word != null ) {
        word.nonw = rule.nonw; 
        sh.add( word );
      }
    }
    return rulematch;
  }

  WordNode parse( ) {

    WordNode node;
    shift = new List();
    
    while( (node = nextword()).nonw != ENDOFINPUT  && node.nonw != PERIOD && node.nonw != QUESTION) {
      if( node.nonw == COMMA || node.nonw == SEMICOLON ||
          node.pos == englishParserDef.pos_conjunction ) {
        // check for reduction of leftward precedence before shifting
        while( checkReduction( -1, shift ) ) checkReduction( 0, shift );
      }
      // check for reduction of no stated precedence after shifting
      shift.add(node);
      while( checkReduction( 0, shift ));
    }
    if( node.nonw == ENDOFINPUT ) endofinput = true;
    terminator = node.nonw;
    // reduce to the max extend
    while( checkReduction( -1, shift ) ) checkReduction( 0, shift );
    // then parse terminator found and reduce once more
    shift.add(node);
    while( checkReduction( 0, shift ));

    if( verbose ) 
      console.writeln('Parsing complete, shift is ${shift.length} nodes long');

    if( shift.length == 1 ) return shift[0];
    else return null;
  }
}
