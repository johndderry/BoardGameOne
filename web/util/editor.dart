/**************************
  *  BoardGameOne files   *
  *  (c) John Derry 2015  *
 **************************/
//
//	EDITOR base code
//	main(): pick up all selector references
//    then create a DivPager and ToolBox objects - these do the work
//
import 'dart:html';
import '../libr/gameengine.dart';

DivPager      pager;
ToolBox       tools;

ButtonElement     loadMap, saveMap, useLocal, useWeb, loadScr, saveScr,
                  addRow, addCol, createNew, swapMain, run, singlestep, step, stop;
TextInputElement  mapName, scratchName, rowsNum, colsNum, imageSize, boardSize;

void main() {
  
  pager   = new DivPager(querySelector("#mainPagingArea"), '.source', '.console');
  tools   = new ToolBox(pager.engine, querySelector("#select"), pager.messagesDiv );
  pager.engine.board.boardclass = 'editboard';
  pager.boardloadcallback = tools.loadOptions;
  
  loadMap = querySelector("#loadMap");
  saveMap = querySelector("#saveMap");
  loadScr = querySelector("#loadScratch");
  saveScr = querySelector("#saveScratch");
  useLocal = querySelector("#useLocal");
  useWeb = querySelector("#useWeb");
  addRow = querySelector("#addRow");
  addCol = querySelector("#addCol");
  createNew = querySelector("#create");
  swapMain = querySelector("#swapMain");
  run = querySelector("#run");
  singlestep = querySelector("#singlestep");
  step = querySelector("#step");
  stop = querySelector("#stop");
  mapName = querySelector("#mapName");
  scratchName = querySelector("#scratchName");
  rowsNum = querySelector("#rows");
  colsNum = querySelector("#cols");
  imageSize = querySelector("#imageSize");
  boardSize = querySelector("#boardSize");
  
  loadMap.onClick.listen(buttonpress);
  saveMap.onClick.listen(buttonpress);
  loadScr.onClick.listen(buttonpress);
  saveScr.onClick.listen(buttonpress);
  useLocal.onClick.listen(buttonpress);
  useWeb.onClick.listen(buttonpress);
  addRow.onClick.listen(buttonpress);
  addCol.onClick.listen(buttonpress);
  createNew.onClick.listen(buttonpress);
  swapMain.onClick.listen(buttonpress);
  run.onClick.listen(buttonpress);
  singlestep.onClick.listen(buttonpress);
  step.onClick.listen(buttonpress);
  stop.onClick.listen(buttonpress);
  //imageSize.onClick.listen(buttonpress);
}

void buttonpress(Event e) {
  
  // just update this everytime
  pager.engine.board.imageSize = int.parse(imageSize.value);

  if( e.currentTarget == loadMap )
    pager.engine.board.loadMap(mapName.value);
  else if( e.currentTarget == saveMap )
    pager.engine.board.saveMap(mapName.value);
  else if( e.currentTarget == loadScr )
    pager.engine.board.loadScratch(scratchName.value);
  else if( e.currentTarget == saveScr )
    pager.engine.board.saveScratch(scratchName.value);
  else if( e.currentTarget == useLocal ) 
    pager.engine.useLocal(querySelector("#map"));
  else if( e.currentTarget == useWeb ) 
    pager.engine.useWeb(querySelector("#map"));
  else if( e.currentTarget == swapMain ) 
    pager.swap();
  else if( e.currentTarget == run ) {
    pager.engine.board.boardclass = 'runboard';
    pager.engine.singlestep = false;
    pager.engine.setToRunning();
    pager.engine.paused = false;
  }
  else if( e.currentTarget == singlestep ){
    pager.engine.board.boardclass = 'runboard';
    pager.engine.singlestep = true;
    pager.engine.setToRunning();
    pager.engine.paused = false;
  }
  else if( e.currentTarget == step ){
    if( pager.engine.running ) pager.engine.slicecallback(null);
  }
  else if( e.currentTarget == stop ){
    pager.engine.stopRunning();
    pager.engine.board.boardclass = 'editboard';
  }
  else if( e.currentTarget == addRow )
    pager.engine.board.adjust(1,0);
  else if( e.currentTarget == addCol )
    pager.engine.board.adjust(0,1);
  //else if( e.currentTarget == imageSize )
  //  pager.engine.board.imageSize = int.parse(imageSize.value);
  else if( e.currentTarget == createNew ) {
    tools.reset();  // clear any player / item selection options
    pager.engine.board.create(rowsNum.value, colsNum.value);
    mapName.value = "";
  }
}


