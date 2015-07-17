/**************************
  *  BoardGameOne files   *
  *  (c) John Derry 2015  *
 **************************/
import 'dart:html';
import '../libr/gameengine.dart';

DivPager          pager;
ButtonElement     loadMap, swapMain;
TextInputElement  mapName, imageSize;
DivElement        mainDiv;

void buttonpress(Event e) {
  String globalaction;
  
  if( e.currentTarget == loadMap ) {
    pager.engine.board.imageSize = int.parse(imageSize.value);
    pager.loadMap(mapName.value);
  }
  else if( e.currentTarget == swapMain ) 
    pager.swap();
}

void main() {
  // locate or create necessary HTML elements
  mainDiv = querySelector('#mainArea');  
  pager = new DivPager( mainDiv, null, '.console' );
  
  // these might not be available on all boards 
  mapName = querySelector("#mapName");
  loadMap = querySelector("#loadMap");
  swapMain = querySelector('#swapMain');
  imageSize = querySelector("#imageSize");
  
  if( loadMap != null ) loadMap.onClick.listen(buttonpress);
  if( swapMain != null ) swapMain.onClick.listen(buttonpress);

  pager.engine.board.imageSize = int.parse(imageSize.value);
}
