/**************************
  *  BoardGameOne files   *
  *  (c) John Derry 2015  *
 **************************/
import 'dart:html';
import '../lib/divpager.dart';

DivPager          pager;
ButtonElement     loadMap, swapMain;
TextInputElement  mapName;
DivElement        mainDiv;

void buttonpress(Event e) {
  String globalaction;
  
  if( e.currentTarget == loadMap ) 
    pager.loadMap(mapName.value);
    
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
  
  if( loadMap != null ) loadMap.onClick.listen(buttonpress);
  if( swapMain != null ) swapMain.onClick.listen(buttonpress);
}
