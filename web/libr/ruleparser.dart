part of makeparser;

const ruleinsertcode = '''  List<RuleDef> rules = new List();\n  createrules() {\n    RuleDef def;''';

class RuleAttr {
  int nonw, prec;
  RuleAttr(this.nonw, this.prec);
}

class Rule {
  String          name;
  RuleAttr        attr;
  int             ident;
  List<String>    items;
  String          action;
  Rule(namestring, this.ident) {
    name = namestring.trim();
    items = new List<String>();
  }
  void display() {
    stdout.write('Name=${name} Items: ');
    for( String s in items) stdout.write('${s} ');
    if( action != null )  stdout.writeln(' Action=${action}');
    else                  stdout.writeln();
  }
}

int                   nextruleid, nextnonwpos;
List<Rule>            rulelist;
Map<String,RuleAttr>  nonwords;

void displayrules() {
  for(Rule rule in rulelist ) {
    stdout.write('Rule ${rule.ident}: ');
    rule.display();
  }
}

String makesubs( String str ) {
  
  str = str.replaceFirst('\$\$', 'retnode');
  str = str.replaceAll('\$1', 'shift[0]');
  str = str.replaceAll('\$2', 'shift[1]');
  str = str.replaceAll('\$3', 'shift[2]');
  // now look for nonword name substitution
  int i, j;
  RuleAttr nonsub;
  i = str.indexOf('\$');
  if( i < 0 || i + 1 >= str.length ) return str;
  j = str.indexOf('\$', i+1 );
  if( j < 0 ) return str;
  String non;
  non = str.substring(i+1,j);
  nonsub = nonwords[non];
  if( nonsub == null ) return str;  
  str = str.replaceAll('\$${non}\$', '${nonsub.nonw}');
  return str;    
}

void gen_rule_code(IOSink ios) {
  // generate constants and names list for non-terminals
  StringBuffer cbuf, lbuf;
  Iterable names, values;
  int i;
  cbuf = new StringBuffer(); lbuf = new StringBuffer();
  cbuf.write('  static const ');
  lbuf.write('  List<String> nonwNames = [');  
  names = nonwords.keys; values = nonwords.values;
  for( i = 0; i < names.length-1; i++ ) {
    cbuf.write('pos_${names.elementAt(i)}=${values.elementAt(i).nonw}, ');
    lbuf.write('\'${names.elementAt(i)}\', ');
  }
  if( names.length > 0 ) {
    cbuf.write('pos_${names.elementAt(i)}=${values.elementAt(i).nonw};');
    lbuf.write('\'${names.elementAt(i)}\'];');
    ios.writeln(cbuf.toString());
    ios.writeln(lbuf.toString());
  }
  
  ios.writeln(ruleinsertcode);
  Rule rule; RuleAttr ra;
  Word word; int pos;
  for( rule in rulelist) {
    ios.writeln('    def = new RuleDef(\'${rule.name}\',${rule.ident},${rule.attr.nonw},${rule.attr.prec});');
    for( String s in rule.items)
      if( s.startsWith('(') ) {
        // create a WordNode for rule term
        word = parseProps(s.substring(1,s.length-1));
        int ipos, iplu, itense;
        if( word.pos != null ) ipos = posMap[word.pos];
        else ipos = -1;
        if( word.plu != null ) iplu = pluMap[word.plu];
        else iplu = -1;
        if( word.pos != null ) itense = tenseMap[word.tense];
        else itense = -1;
        ios.writeln('    def.terms.add(new WordNode(null,null,${ipos},-1,${iplu},${itense}));');
      } else {
        // look up the non-terminal
        if( (ra = nonwords[s]) == null )
          stderr.writeln('ERROR: unknown non-terminal "${s}" in rule ${rule.ident}');
        else ios.writeln('    def.terms.add(new WordNode.nonword(${ra.nonw},null));');
      }
    ios.writeln('    rules.add(def);');
  }
  ios.writeln('''  }\n  WordNode doAction(String desc,int ident,List<WordNode> shift) {
    WordNode retnode;\n    switch(ident) {''');
  for( rule in rulelist )
    if( rule.action != null ) {
      ios.writeln('      case ${rule.ident}: ${makesubs(rule.action)} break;');
    }  
  ios.writeln('      default: return null;\n    }\n    if( retnode != null && desc != null ) retnode.desc = desc;\n    return retnode;\n  }');
}

bool parsesourcerules( String rules ) {

  Rule buildrule;
  int linenum = 1;

  void parseRule(String r) {
    if( r.length == 0 ) { linenum++; return; }
    if( r.indexOf(':') < 0 ) {
      int prec = 0;
      // process a nonword attribute 
      List<String> l = r.split('=');
      switch(l[1].trim()) {
        case 'left': prec = -1; break;
        case 'right': prec = 1; break;
      }
      RuleAttr ra;
      String name = l[0].trim();
      if( (ra = nonwords[name]) == null ) {
        ra = new RuleAttr(nextnonwpos++, prec);
        nonwords[name]= ra;
      }
      linenum++; return;
    }
    // process a nonword rule
    List<String>  l = r.split(':');
    assert( l != null );
    if( l.length < 2 ) {
      stderr.writeln('Line ${linenum}: No rule found "${r}"');
      linenum++; return;
    }    
    buildrule = new Rule(l[0], nextruleid);
    List<String> subact = l[1].split('{');
    List<String> subs = subact[0].split(' ');
    String s, t;
    for( s in subs ) {
      t = s.trim();
      if( t.length == 0 ) continue;
      buildrule.items.add(t);
    }
    int n;
    if( subact.length > 1) {
      n = subact[1].indexOf('}');
      buildrule.action = subact[1].substring(0,n).trim();
    }
    // get nonword pos if rule name exists or assign new one
    RuleAttr ra;
    if( (ra = nonwords[buildrule.name]) == null ) {
      ra = new RuleAttr(nextnonwpos++, 0);
      nonwords[buildrule.name]= ra;
    }
    buildrule.attr = ra;
    if( buildrule.items.length > 0) {
      rulelist.add( buildrule );
      nextruleid++;
    }
    linenum++;
  }
 
  rulelist = new List();
  nextruleid = 0;
  // create a map to resolve nonword references in the rule terms
  nonwords = new Map();
  // create the builtin nonwords
  nonwords['ENDOFINPUT']= new RuleAttr(0,0);
  nonwords['UNKNOWN']   = new RuleAttr(1,0);
  nonwords['PERIOD']    = new RuleAttr(2,0);
  nonwords['COMMA']     = new RuleAttr(3,0);
  nonwords['COLON']     = new RuleAttr(4,0);
  nonwords['SEMICOLON'] = new RuleAttr(5,0);
  nonwords['QUESTION']  = new RuleAttr(6,0);
  nextnonwpos = 7;
  // parse the rules and attr defs
  List<String> ruletext = rules.split('\n');
  ruletext.forEach(parseRule);
  if( rulelist.length > 0 ) 
    return true;
  return false;
}