import 'dart:io';
/*
 * This utility routine for generating word variations
 * REMNANT
 */
main() {

  while(true) {
    
    String line, line2;
    line = stdin.readLineSync();
    if( line == null || line.length == 1 ) break;
    line = line.replaceFirst('\n', '');
    if( line[line.length-1] == 'e' )
      line2 = line.substring(0,line.length-1);
    else
      line2 = line;
    
    stdout.write('''\n
${line}\t\t${line.toUpperCase()}(pos=noun;plu=singular)
${line}\t\t${line.toUpperCase()}(pos=verb;plu=plural;tense=present)
${line2}ed\t\t${line.toUpperCase()}(pos=verb;tense=past)
${line2}ing\t${line.toUpperCase()}(pos=verb;tense=future)
${line}s\t\t${line.toUpperCase()}(pos=noun;plu=plural)
${line}s\t\t${line.toUpperCase()}(pos=verb;plu=singular;tense=present)
''');
    
  }
}