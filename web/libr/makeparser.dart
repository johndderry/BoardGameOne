/**************************
  *  BoardGameOne files   *
  *  (c) John Derry 2015  *
 **************************/
library makeparser;
import 'dart:io';

part 'ruleparser.dart';
part 'wordparser.dart';

const libraryheader = '''/*** generated by makeparser.dart ***/\npart of NLPparser;\n
const ENDOFINPUT = 0, UNKNOWN = 1, PERIOD = 2, COMMA = 3, COLON = 4, SEMICOLON = 5, QUESTION = 6;
class WordNode {\n  String name, desc, repeater; int nonw, pos, meaning, plu, tense;
  WordNode up, next, prev, sub, act, obj, foremod, backmod;
  WordNode get dup { 
    WordNode n,m,r = new WordNode(name,desc,pos,meaning,plu,tense); 
    n = next; m = r; while( n != null ) { 
      m.next = new WordNode(n.name,n.desc,n.pos,n.meaning,n.plu,n.tense); m = m.next; n = n.next;
    }
    return r;
  }
  WordNode(this.name, this.desc, this.pos, this.meaning, this.plu, this.tense)
    { repeater=null; nonw = -1; }
  WordNode.nonword(this.nonw, this.desc);\n}
class RuleDef {\n  String name; int nonw, prec, ident;\n  List<WordNode> terms;\n  var action;
  RuleDef(this.name, this.ident, this.nonw, this.prec){ terms = new List(); }\n}
'''; 

/*
 * This console dart program creates the parser definition
 * 
 * It takes the parser_name as single argument. From that,
 * it reads the definition from the input files 'parser_name.words' and
 * 'parser_name.rules' and creates parser_name_definition.dart in path './parser'.
 * That file is part of the library NLPparser defined in parser/parser.dart
 * 
 * Already present in the direct
 */
void main(List<String> args) {
  
  String source;
  IOSink ioSink;
  File wordfile, rulefile, dartfile;
  bool parsewords, parserules;
 
  wordfile = new File('parser/${args[0]}.words');
  rulefile = new File('parser/${args[0]}.rules');
  dartfile = new File('parser/${args[0]}_definition.dart');

  ioSink = dartfile.openWrite();
  // write out some header stuff
  ioSink.writeln( libraryheader );
  ioSink.writeln('class ${args[0]}ParserDef {\n  Parser parser;');
  
  if( wordfile.existsSync() ) {
    source = wordfile.readAsStringSync();
    if( !( parsewords = parsesourcewords( source )) )
      stderr.writeln('failure to parse words');
    else {
      displaywords();
      gen_word_code( ioSink );
    }
  }
  
  if( rulefile.existsSync() ) {
    source = rulefile.readAsStringSync();
    if( !( parserules = parsesourcerules( source )) )
      stderr.writeln('failure to parse rules');
    else { 
      displayrules();
      gen_rule_code( ioSink );
    }
  }
  
  ioSink.writeln('  // end of ${args[0]}ParserDef\n}');
  ioSink.close();
}

