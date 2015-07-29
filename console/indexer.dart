/**************************
  *  BoardGameOne files   *
  *  (c) John Derry 2015  *
 **************************/
import 'dart:io';
import 'dart:convert';
/*
 * Create an index of all directories in ./images and place in ./data/images.json
 * then get a directory of .png files in each directory and place in ./data/DIRNAME.json
 */

main() {

  List<String> dirindexlist, imageindexlist;

  IOSink ioSink;
  Directory dir;
  FileSystemEntity item;
  List<FileSystemEntity> dirlist;

  dirindexlist = new List();
  
  dir = new Directory( 'images' );
  dirlist = dir.listSync();
  
  File indexfile = new File('data/images.json');

  print('reading ./images for: ');
  for( item in dirlist ) {
    dirindexlist.add(item.path);
    print(item.path);  
  }
  
  ioSink = indexfile.openWrite(); 
  ioSink.write(JSON.encode( dirindexlist ));
  ioSink.close();
  
  String imagedir;
  for( imagedir in dirindexlist ) {

    print('\nreading directory of ${imagedir}');

    imageindexlist = new List();
    indexfile = new File('data/${imagedir}.json');
    
    dir = new Directory( imagedir );
    dirlist = dir.listSync();

    for( item in dirlist) 
      if( item.path.contains('.png')) {   
        imageindexlist.add( item.path.substring(item.path.indexOf('/')+1,item.path.indexOf('.')) );
        print('adding ${item.path}');
      }

    imageindexlist.sort();
 
    // save the data to the file
    ioSink = indexfile.openWrite(); 
    ioSink.write(JSON.encode( imageindexlist ));
    ioSink.close();    
  }
}

