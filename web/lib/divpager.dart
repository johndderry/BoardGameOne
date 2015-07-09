/**************************
  *  BoardGameOne files   *
  *  (c) John Derry 2015  *
 **************************/
library divpager;

import 'dart:html';
import 'interpreter.dart';
import 'gameboard.dart';
import 'gameengine.dart';

class DivPager {
  
  bool isEditor, showingConsole, showingNarrative;

  ButtonElement     consoleClear;
  TextInputElement  consoleInput;
  GameEngine        engine;
  Possessions       possessions;
  MandyInterpreter  mandy;
  TitleElement      title;
  HeadingElement    gametitle;
  DivElement        mainDiv, boardDiv, mouseoverDiv, messagesDiv, 
                    possessionsDiv, consoleDiv;
  var               boardloadcallback;

  void enterNarrative(String narrative) {
        _placeNarrative(narrative, 'You have entered the ${narrative}.<br>');
  }
  
  void _keylistener(KeyboardEvent e) {
    int key;
    if( showingNarrative ) {
      showingNarrative = false;
      if( showingConsole ) _placeConsole();
      else _placeBoard();
      return;
    }
    if( (key = directionkeymap[e.keyCode]) != null )
      engine.movePOVplayer( key, false );
    else if( e.keyCode == 78 ) { // 'n'
      if( engine.narrativeName != null && engine.narrativeName.length > 0) 
        _placeNarrative(engine.narrativeName, null);
    }
  }

  void _handleError(Error e) {
    messagesDiv.text = 'narrative load failure: ${engine.narrativeName}';
  }
    
  void _load_narrative(String text) {
    mainDiv.appendHtml(text);
  }

  void _placeNarrative(String narrative, String pretext) {
    Node child;
    engine.paused = true;
    showingNarrative = true;  
    while( (child = mainDiv.lastChild) != null ) 
      child.remove();
    if( pretext != null )
      mainDiv.appendHtml(pretext);
    HttpRequest.getString('http://${HOSTNAME}/data/narratives/${narrative}')
      .then(_load_narrative).catchError(_handleError);
  }

  void _placeBoard() {
    Node child;
    while( (child = mainDiv.lastChild) != null ) 
      child.remove();
    mainDiv.append(boardDiv);
    mainDiv.append(mouseoverDiv);
    mainDiv.append(messagesDiv);
    mainDiv.append(possessionsDiv);
    showingConsole = false;
    engine.paused = false;
  }

  void _placeConsole() {
    Node child;
    engine.paused = true;
    while( (child = mainDiv.lastChild) != null ) 
      child.remove();
    mainDiv.appendText('Chat');
    mainDiv.append(consoleClear);
    mainDiv.append(consoleInput);
    mainDiv.append(consoleDiv);
    showingConsole = true;
  }

  void _boardloaded() {
    
    ObjectEntry titlestring, globalaction;
    List<Node>  childnodes;
    // update the page and heading title
    titlestring = engine.board.properties['title'];
    if( titlestring != null ) {
      childnodes = title.childNodes;
      childnodes[0].remove();
      title.appendText(titlestring.data.buffer.string); 
      gametitle.text = titlestring.data.buffer.string;
    }
    // set board into run mode
    if( isEditor )
      boardloadcallback();
    else {
      engine.setToRunning();
      engine.paused = false;
    }
  } 
    
  void loadMap( String map ) {
    engine.board.loadMap( map );
  }
  
  void swap() {
    if( showingConsole ) _placeBoard();
    else _placeConsole();
  }

  DivPager(this.mainDiv, String sourceclass, String consoleclass) {

    isEditor = showingConsole = showingNarrative = false;
    
    // locate or create necessary HTML elements
    boardDiv = new DivElement();
    mouseoverDiv = new DivElement();
    messagesDiv = new DivElement();
    possessionsDiv = new DivElement();
    consoleClear = new ButtonElement();
    consoleInput = new TextInputElement();
    consoleDiv = new DivElement();
    
    mouseoverDiv.id = 'mouseover';
    messagesDiv.id = 'messages';
    consoleClear.appendText("Clear");
    consoleClear.id = 'clear';
    consoleInput.size = 60;
    consoleClear.className = consoleInput.className = 
      consoleDiv.className = 'console';
    
    // have to place some console elements for new MandyInterpreter() to find them
    mainDiv.append(consoleClear);
    mainDiv.append(consoleInput);
    mainDiv.append(consoleDiv);
    
    mandy = new MandyInterpreter( document, sourceclass, consoleclass );
    engine = new GameEngine(mandy, boardDiv, mouseoverDiv, messagesDiv);
    possessions = new Possessions(possessionsDiv);

    //mandy.console.outputeventhandler = placeConsole;
    engine.pager = this;
    engine.possessions = possessions;
    engine.board.loadcallback = _boardloaded;
    possessions.interpreter = mandy;
    
    title = querySelector('title');
    gametitle = querySelector('#gametitle');
    
    if( title.text == 'Editor' ) 
      isEditor = true;
    else // autoload title if the title is not 'Play'
      if( title.text != 'Play' && title.text != 'Editor') {
        // use the game title as the board name
        engine.board.loadMap(title.text);
      }

    window.addEventListener("keyup", _keylistener );
    _placeBoard();
  }

}