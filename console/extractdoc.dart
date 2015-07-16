import 'dart:io';

/* Simple Server for game1
 * Browse to it using http://localhost:8080  
 * 
 * Provides CORS headers, so can be accessed from any other page
 */

final STANDARDOBJECTS = "lib/standardobjects.dart";  
final GAMEOBJECTS = "lib/gameengine.dart";
final DESIGNHELP = "lib/designhelp.dart";

StringBuffer output = new StringBuffer();

void main() {
  output.write('<!DOCTYPE html>\n\n<html><head><title>Board Game One Help</title></head>\n');
  output.write('<body>\n<h1>Game Board One Help</h1>');  
  readFile(DESIGNHELP);
}


void readFile(String path) {
  var file = new File(path);
  file.readAsLines().then((List<String> lines) {

    // figure out what do do next
    if( path == DESIGNHELP ) {
      extractdoc( lines, false );
      //output.write('<h2>Script Interpret</h2>\n');
      readFile(STANDARDOBJECTS);
    }
    if( path == STANDARDOBJECTS ) {
      extractdoc( lines, true );
      readFile(GAMEOBJECTS);
    }
    else if( path == GAMEOBJECTS ) {
      extractdoc( lines, true );
      writeFile( 'BoardGameOne.html', output.toString());
    }

  });
}

void writeFile(String path, String buffer) {
  var file = new File(path);
  file.writeAsString(buffer);
}

int gethelp(String ident, List<String> lines, int linestart, bool useidentheader, int pos ) {
  int linecnt = 0;
  String ln;
  if( useidentheader ) {
    //if( pos > 1 ) output.write('<P STYLE="margin-top: 0.17in; page-break-after: avoid"><FONT FACE="Albany, sans-serif"><FONT SIZE=4>$ident</FONT></FONT></P>');

    if( pos > 1 ) output.write('<h3>$ident</h3>\n');
    else          output.write('<h2>$ident</h2>\n');
  }
  while( (ln = lines.elementAt(linestart+linecnt)).contains("''';") == false ) {
    output.write(ln); output.write('\n'); linecnt++;
  }
  return linecnt;
}

void extractdoc( List<String> lines, bool useidentheader ) {
  
  const String static_const_string = "static const String ";
  const String const_string        = "const String";
  
  String extractName(String ident) {
    int loc;
    // the last _ always begins the _help, ignore it
    if( (loc=ident.lastIndexOf('_')) > 1) {
      ident = ident.substring(0,loc);
    }
    // any more are replaced by spaces
    return ident.replaceAll('_', ' ');
  }
  
  int pos;
  String ln;
  int skip = 0, lcount = 0;
  for( ln in lines ) {
    if( skip > 0 ) {
      skip--; lcount++;
      continue;
    }
    //print("saw ${ln}\n");
    ;
    if( (pos = ln.indexOf(static_const_string)) >= 0 ) {
      //print("at ${pos.toString()} saw ${ln}\n");
      int pos2 = ln.indexOf(' ', pos + 20);
      assert( pos2 > 0 );
      String ident = ln.substring( pos+20, pos+pos2-2 );
      ident = extractName(ident);
      print("saw '${static_const_string}' @${pos} ident=${ident} processing; ");

      skip = gethelp(ident, lines, lcount+1, useidentheader, pos);
      print("skipping ${skip.toString()}\n");
      
    } else if((pos = ln.indexOf(const_string)) >= 0) {
       //print("at ${pos.toString()} saw ${ln}\n");
       int pos2 = ln.indexOf(' ', pos + 13);
       assert( pos2 > 0 );
       String ident = ln.substring( pos+13, pos+pos2-2 );
       ident = extractName(ident);
       print("saw '${const_string}' @${pos} ident=${ident} processing; ");

       skip = gethelp(ident, lines, lcount+1, useidentheader, pos);
       print("skipping ${skip.toString()}\n");
         
      } 

    lcount++;
  }
}