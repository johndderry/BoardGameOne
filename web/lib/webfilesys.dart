/**************************
  *  BoardGameOne files   *
  *  (c) John Derry 2015  *
 **************************/
library webfilesys;
import 'dart:html';

class WebFileSys {
 
  FileSystem filesystem;
  var logarea, transferarea, transferdata;
 
  void _requestFileSystemCallback(FileSystem fs) {
    filesystem = fs;
  }

  Entry _onCreateFile(FileEntry e) {
    return e;
  }

  Entry _deleteIt(FileEntry e) {
    e.remove();
    return e;
    }

  // data read
  void _onDataLoadEnd(Blob result) {
    transferdata.code = result.slice(0,0,'binary');
    transferdata.names = result.slice(1,1,'binary');
  }

  File _dataFileRead(File f){
    FileReader reader = new FileReader();
    reader.onLoadEnd.listen((ProgressEvent event) => _onDataLoadEnd(reader.result));
    reader.readAsArrayBuffer(f);
    return f;
  }

  Entry _onDataGetLoad(FileEntry e) {
    e.file().then(_dataFileRead)
      .catchError(_handleError);
    return e;
  }

  // text read
  void _onTextLoadEnd(String result) {
    transferarea.value = result;
  }

  File _textFileRead(File f){
    FileReader reader = new FileReader();
    reader.onLoadEnd.listen((ProgressEvent event) => _onTextLoadEnd(reader.result));
    reader.readAsText(f);
    return f;
  }

  Entry _onTextGetLoad(FileEntry e) {
    e.file().then(_textFileRead)
      .catchError(_handleError);
    return e;
  }

  // data write
  FileWriter _dataFileWrite(FileWriter fw) {
    // Create a new text Blob and write it to fw.
    Blob blob = new Blob([transferdata.data, transferdata.names], 'binary');
    fw.write(blob);
    return fw;
  }

  Entry _onDataGetSave(FileEntry e) {
    e.createWriter().then(_dataFileWrite)
      .catchError(_handleError);
    return e;
  }

  // text write
  FileWriter _textFileWrite(FileWriter fw) {
    // Create a new text Blob and write it to fw.
    Blob blob = new Blob([transferarea.value], 'text/plain');
    fw.write(blob);
    return fw;
  }

  Entry _onTextGetSave(FileEntry e) {
    e.createWriter().then(_textFileWrite)
      .catchError(_handleError);
    return e;
  }

  void _ignoreError(FileError e) { }
  
  void _handleError(FileError e) {
    var msg;
    switch (e.code) {
      case FileError.QUOTA_EXCEEDED_ERR:
        msg = 'QUOTA_EXCEEDED_ERR';
        break;
      case FileError.NOT_FOUND_ERR:
        msg = 'NOT_FOUND_ERR';
        break;
      case FileError.SECURITY_ERR:
        msg = 'SECURITY_ERR';
        break;
      case FileError.INVALID_MODIFICATION_ERR:
        msg = 'INVALID_MODIFICATION_ERR';
        break;
      case FileError.INVALID_STATE_ERR:
        msg = 'INVALID_STATE_ERR';
        break;
      default:
        msg = 'Unknown Error';
        break;
    }
    logarea = "Error: $msg";
  }

  void loadtext(String filename, var area ) {
    transferarea = area;
    filesystem.root.getFile(filename).then(_onTextGetLoad)
      .catchError(_handleError);
  }
  
  void savetext( String filename, var area) {
    transferarea = area;
    //filesystem.root.getFile(filename).then(_deleteIt)
    //  .catchError(_ignoreError);    
    filesystem.root.createFile(filename).then(_onCreateFile)
      .catchError(_handleError);
    filesystem.root.getFile(filename).then(_onTextGetSave)
      .catchError(_handleError);    
  }
  
  WebFileSys(this.logarea) {  
    window.requestFileSystem(1024 * 1024, persistent: false)
     .then(_requestFileSystemCallback, onError: _handleError);
   
  }
  
}