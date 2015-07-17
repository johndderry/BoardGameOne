/**************************
  *  BoardGameOne files   *
  *  (c) John Derry 2015  *
 **************************/
part of NLPparser;

/*
 * class SENTNODE is used as a structure
 */

class SentNode {
  int meaning, pos, plu, tense, length;
  SentNode next, child;
  SentNode(this.meaning,this.pos,this.plu,this.tense);
  bool compare( SentNode n ) {
    if( n.pos == pos && (meaning < 0 || n.meaning == meaning )) return true;
    return false;
  }
}

SentNode convert( WordNode node ) {
  
  SentNode top, last, lastchild, sn;
  WordNode wn = node;
  while( wn != null ) {
    if( wn.meaning != null )
      sn = new SentNode(wn.meaning+1,wn.pos+1,wn.plu+1,wn.tense+1);
    else
      sn = new SentNode(0,0,0,0);
    if( top == null ) last = top = sn;
    else {
      last.next = sn;
      last = sn;
    }
    lastchild = null;
    if( wn.foremod != null ) 
      lastchild = last.child = convert( wn.foremod );
    if( wn.backmod != null ) {
      sn = convert( wn.backmod );
      if( lastchild == null )
        lastchild = last.child = sn;
      else
        lastchild.next = sn;
      lastchild = sn;
    } 
    if( wn.sub != null ) {
      sn = convert( wn.sub );
      if( lastchild == null )
        lastchild = last.child = sn;
      else
        lastchild.next = sn;
      lastchild = sn;
    } 
    if( wn.act != null ) {
      sn = convert( wn.act );
      if( lastchild == null )
        lastchild = last.child = sn;
      else
        lastchild.next = sn;
      lastchild = sn;
    } 
    if( wn.obj != null ) {
      sn = convert( wn.obj );
      if( lastchild == null )
        lastchild = last.child = sn;
      else
        lastchild.next = sn;
      lastchild = sn;
    } 
    wn = wn.next;      
  }
  return top;
}

/*
 * class PACKSENT
 * holds a packed sentence and/or a tree struct of SentNode
 * can be converted back and forth on demand     
 */

class PackSent {
  SentNode root;
  List<int> data;
  
  void encode( StringBuffer buf ) {
    buf.write( JSON.encode( data ) );
  }
  
  void decode( String str ) {
    data = JSON.decode( str );
  }
  
  static bool compare( SentNode sample, SentNode node ) {
    // for each node of sample list, look for a match from real nodes
    // and do the same for any children
    bool matchfound;
    SentNode sn = sample, nd;
    while( sn != null ) {
      // ignore the interogative
      if( sn.pos == englishParserDef.pos_interogative + 1 ) {
        sn = sn.next;
        continue;
      }
      // for each sample element look for a match anywhere in the list
      nd = node;
      matchfound = false;
      while( !matchfound && nd != null ) {      
        if( sn.compare( nd ) ) {
          matchfound = true;
          if( sn.child != null ) {
            if( nd.child == null ) matchfound = false;
            if( !compare( sn.child, nd.child )) matchfound = false;
          }
        }
        nd = nd.next;
      }
      if( !matchfound ) return false;
      sn = sn.next;
    }
    return true;
  }

  static bool traverse( SentNode sample, SentNode node ) {
  
     // called recursively to compare all nodes at this level
    //  with sample
     while( node != null ) {
       if( compare( sample, node )) return true;
       // now check for any children match
       if( node.child != null ) {
         if( traverse( sample, node.child )) return true;
       }
       node = node.next;
     }
     return false;      
  }
  
  bool match( SentNode test ) {
    // to match we look for every occurance of a parent node
    // then see if there are the required children.
    // do this recursively for each node
    if( root == null ) expand();
    // work thru the internal tree and use each node 
    // as the starting point to compare with test
    return traverse( test, root );    
  }
  
  bool expand() {
    if( data == null ) return false;
    int pos = 0;
    
    SentNode expandnode() {
      int levelstartpos = pos, startpos, dat, overlen;
      SentNode sn, first, last;
      overlen = data[pos+1] >> 1;
      while( pos - levelstartpos < overlen ) {
        startpos = pos;
        dat = data[pos++];
        sn = new SentNode(dat>>6, dat&7, (dat>>3)&1, (dat>>4)&3);
        sn.length = data[pos++] >> 1;
        if( first == null ) first = sn;
        else last.next = sn;
        last = sn;
        if( pos - startpos < sn.length ) {
          int i = (data[pos+1]) & 1;
          if( i > 0 ) 
            sn.child = expandnode();
        }
      }
      return first;
    }
    
    root = expandnode();
    return true;
  }
  
  bool compact() {
    if( root == null ) return false;

    // determine linear lengths of each node
    int nodelength( SentNode node ) {
      int rlen = 0, len = 0;
      SentNode sn = node;
      while( sn != null ) {
        if( sn.child != null ) {
          sn.child.length = nodelength( sn.child );
          len += sn.child.length;
        }
        // for each node at this level add two to this level
        // and set the length=2 for node even though this may be updated
        // if it is a child node
        len += 2;
        sn.length = len;
        rlen += len;
        len = 0;
        sn = sn.next;
      }
      return rlen;
    }
    root.length = nodelength( root );

    // now flatten tree into data
    void nodeflatten( SentNode node ) {
      SentNode sn = node;
      bool first = true; 
      while( sn != null ) {
        data.add( sn.meaning << 6 | sn.tense << 4 | sn.plu << 3 | sn.pos );
        if( first ) {
          data.add( (sn.length << 1) | 1 );
          first = false;          
        } else 
          data.add( sn.length << 1 );
        if( sn.child != null ) nodeflatten( sn.child );
        sn = sn.next;
      }
    }
    data = new List();
    nodeflatten( root );
    root = null;
    return true;
  }
}

bool comparesentroot( WebConsole console, SentNode n1, SentNode n2, int depth ) {

  while( n1 != null && n2 != null ) {
    if( n1.meaning!= n2.meaning ) {
      console.writeln('CONVERSION ERROR in Sentence ROOT: meaning differs at depth ${depth}, ${n1.meaning}<>${n2.meaning}');
      return false;
    }
    if( n1.pos!= n2.pos ) {
      console.writeln('CONVERSION ERROR in Sentence ROOT: pos differs at depth ${depth}, ${n1.pos}<>${n2.pos}');
      return false;
    }
    if( n1.plu!= n2.plu ) {
      console.writeln('CONVERSION ERROR in Sentence ROOT: plu differs at depth ${depth}, ${n1.plu}<>${n2.plu}');
      return false;
    }
    if( n1.tense!= n2.tense ) {
      console.writeln('CONVERSION ERROR in Sentence ROOT: tense differs at depth ${depth}, ${n1.tense}<>${n2.tense}');
      return false;
    }
  
    if( n1.child != null && n2.child == null ) {
      console.writeln('CONVERSION ERROR in Sentence ROOT: child vrs no-child at depth ${depth}');
      return false;
    }
    if( n1.child == null && n2.child != null ) {
      console.writeln('CONVERSION ERROR in Sentence ROOT: no-child vrs child at depth ${depth}');
      return false;
    }
    if( n1.child != null && n1.child != null )
      if( comparesentroot( console, n1.child, n2.child, depth+1 ) == false ) return false;
    
    if( n1.next != null && n2.next == null ) {
      console.writeln('CONVERSION ERROR in Sentence ROOT: next vrs no-next at depth ${depth}');
      return false;
    }
    if( n1.next == null && n2.next != null ) {
      console.writeln('CONVERSION ERROR in Sentence ROOT: no-next vrs next at depth ${depth}');
      return false;
    }
    n1 = n1.next; n2 = n2.next;
 }
  
  return true;
}

bool comparesentdata( WebConsole console, List<int> s1, List<int> s2 ) {

  if( s1.length != s2.length ) {
    if( console != null )
      console.writeln('CONVERSION ERROR in Sentence DATA: differs in length, ${s1.length}<>${s2.length}');
    return false;
  }
  int indx = s1.length -1;
  while( indx >= 0 ) {
    if( s1[indx] != s2[indx] ) {
      if( console != null )
        console.writeln('CONVERSION ERROR in Sentence DATA: value differs at index ${indx}, ${s1[indx]}<>${s2[indx]}');
      return false;
    }
    indx--;
  }
  return true;
}

/*
 * class KNOWBASE
 * holds a knowledge base, which is basically a list of PackSent
 */

class KnowBase {
  
  WebConsole console;
  englishParserDef parserDef;
  List<PackSent> sentdata = new List();
  bool verbose = false, verify = false;
  
  KnowBase( this.console, this.parserDef );
  
  void _handleError(Error e) {
    console.writeln('map load failure: ${e.toString()}');
  }

  void _read_data(String jstr) {
    
    if( verbose ) console.write('read ${jstr} from knowledge, ');
    List<List<int>> sentences = JSON.decode(jstr);
    List<int> sent;
    int count = 0;
    sentdata = new List();
    for( sent in sentences ) {
      PackSent ps = new PackSent();
      ps.data = sent;
      sentdata.add(ps);
      count++;
    }
    if( verbose ) console.writeln('Generated ${count} sentences.');
  }
  
  bool read(String path) {
    if( verbose ) console.writeln('reading knowledge from "$path"');
    
    HttpRequest.getString('http://${HOSTNAME}/knowledge/${path}.json')
      .then(_read_data).catchError(_handleError);

    return true;
  }
  
  bool write(String path) {
    if( sentdata.length == 0 ) return false;
    
    if( verbose ) console.writeln('writing knowledge to "$path"');
    
    HttpRequest req = new HttpRequest();
    req.onReadyStateChange.listen((ProgressEvent e) {
      if (req.readyState == HttpRequest.DONE &&
          (req.status == 200 || req.status == 0))
        console.writeln('knowledge post success');
      else 
        console.writeln('knowledge post failure: ${e.toString()}');
    });

    // open up the http channel and send an JSON encoded _cellMap using map name
    req.open('POST', 'http://${HOSTNAME}/knowledge/${path}.json', async:false);

    StringBuffer data = new StringBuffer('[');
    PackSent sent; int cnt = 0;
    if( sentdata.length > 1 )
      while( cnt < sentdata.length-1 ) {
        sentdata[cnt].encode( data ); 
        data.write(','); cnt++;        
      }
    sentdata[cnt].encode( data );
    
    data.write(']');
    req.send( data.toString() );
    return true;
  }
  
  int merge( KnowBase merge ) {
      
    int cnt, currentlen = sentdata.length;
    PackSent sent, test;
    bool dup;
    // work thru new sentences, looking for duplicate before appending
    for( sent in merge.sentdata ) {
      cnt = 0;
      dup = false;
      for( test in sentdata ) {
        if( cnt++ >= currentlen ) continue;                 // only compare to original list
        if( comparesentdata( null, sent.data, test.data )) {
          dup = true;
          break;  // duplicate, dont add
        }
      }
      sentdata.add( sent );
    }
    
    return this.sentdata.length;
  }
  
  List<PackSent> query(WordNode qnode) {
    // return a list of selected sentences made from the query in qnode
    List<PackSent> coll = new List();
    PackSent sent;
    SentNode sn = convert( qnode );
    for( sent in sentdata ) {
      if( sent.match( sn )) coll.add(sent);
    }
    return coll;
  }
  
  void makesentence( StringBuffer sentence, SentNode sn, String parentname ) {

    String          thisname;
    List<WordNode>  list;
    WordNode        wn;
    bool            found = false;
    
    while( sn != null ) {
      thisname = null;
      if( sn.meaning > 0 ) {
        // have parentname and we are a preposition, output parentname before proceeding
        if( parentname != null && sn.pos-1 == englishParserDef.pos_preposition ) {
          sentence.writeln('${parentname} ');
          parentname == null;
        }
        list = parserDef.meaningMap[sn.meaning -1];
        for( wn in list ) 
          if( wn.pos == sn.pos-1 && wn.plu == sn.plu-1 && wn.tense == sn.tense-1) {
            thisname = wn.name;
            found = true;
            break;
          }
        if( !found ) 
          console.writeln('no match: meaning=${sn.meaning-1} pos=${sn.pos-1} plu=${sn.plu-1} tense=${sn.tense-1}');
        else
          // if we are a verb, output it immediately
          if( wn.pos == englishParserDef.pos_verb ) {
            sentence.write('${thisname} ');
            thisname = null;
          }
        }
      if( sn.child != null ) {
        if( parentname != null ) {
          // if we have child and parentname, write this name out first
          if( thisname != null ) sentence.write('${thisname} ');
          makesentence( sentence, sn.child, parentname );
        }
        else // if no parentname, call child with us as parentname
          makesentence( sentence, sn.child, thisname );
      }
      else 
        if( thisname != null ) sentence.write('${thisname} ');
      sn = sn.next;
    }
    // if we still have parent name string, then we haven't seen a preposition
    // so output it now
    if( parentname != null )
      sentence.write('${parentname} ');
  }

  bool learn( WordNode wordnode ) {
    List savelist; SentNode saveroot;
    PackSent sent = new PackSent();
    saveroot = sent.root = convert( wordnode );
    sent.compact();
    if( verify ) {
      savelist = sent.data;
      sent.expand();
      if( comparesentroot( console, saveroot, sent.root, 0 ) == false ) return false;
      sent.compact();
      if( comparesentdata( console, savelist, sent.data ) == false ) return false;
    }
    PackSent test;
    bool dup = false;
    for( test in sentdata ) {
      if( comparesentdata( null, sent.data, test.data )) {
        dup = true;
        break;
      }
    }
    if( dup ) return false;
    sentdata.add( sent );
    return true;
  }
  
  SentNode getsent( int indx ) {
    if( indx >= sentdata.length ) return null;
    SentNode sn;
    PackSent ps = sentdata[indx];
    ps.expand();
    sn = ps.root;
    ps.root = null;
    return sn;
  }
  
  String show() {
    PackSent sent;
    StringBuffer sentence = new StringBuffer();
    for( sent in sentdata ) {
      sent.expand();
      makesentence( sentence, sent.root, null);
      sentence.writeln('.');
    }
    return sentence.toString();
  }
  
}
