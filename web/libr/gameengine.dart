/**************************
  *  BoardGameOne files   *
  *  (c) John Derry 2015  *
 **************************/
library boardgameone;

import 'dart:html';
import 'dart:async';
import 'dart:convert';
import 'bufferedhtmlio.dart';
import 'interpreter.dart';
import '../parser/parser.dart';

part 'divpager.dart';
part 'gameboard.dart';
part 'designtools.dart';
part 'designhelp.dart';
part 'behavior.dart';

/**********************
 * class GAMEENGINE   *
 **********************/
class GameEngine {

  static const defaultSlice = 500;
  
  bool          running, paused, singlestep, uselocal;  
  DivPager      pager;          // pager who created board
  GameBoard     board;          // currently operating gameboard
  GPlayer       povPlayer;      // player who's POV we are using and control we have
  String        narrativeName;  // name for narrative lookup
  CharBuffer    runlibrary;     // library routines to load before running

  // division elements passed to us
  Element         _boardelement, _mouseover, _messages; 
  GPlayer         _slicePlayer;   // player who has the timer slice
  List<GPlayer>   _activePlayers; // all active players
  List<GameBoard> _chainStack;    // stack for chaining game boards
  BoardSquare     _actionSquare;  // square receiveing action
  Timer           _sliceTimer;    // player slice timer

  WebConsole        queryConsole; // query console is created in divpager
  englishParserDef  english;      // same here; but we need them to activate players

  TextAreaElement         maparea;      // text area for local load/save of maps
  MandyInterpreter        interpreter;
  Possessions             possessions;

  GameEngine( this.interpreter, this._boardelement, this._mouseover, this._messages ) {
    board = new GameBoard( this, _boardelement, _mouseover, _messages );
    board.properties = GameBoard.genproperties(this, DEFAULT_GAME_CMAP, false);
    _chainStack = new List<GameBoard>();
    uselocal = singlestep = paused = running = false;
  }
  //
  // get some info about players using serialized names
  //
  KnowBase playerKnow(String name) {
    GPlayer player;
    for( player in _activePlayers ) 
       if( player.serialname == name ) return player.knowledge;
    return null;
    }
  
  String Players(int vicinity) {
    /*
     * Return a list of active players using serialized names
     * 
     * vicinity >=0 is distance, == -1 means all players
     * however only distance=0 is implemented
     */
    GPlayer player; StringBuffer buf;
    if( _activePlayers == null ) return '';
    buf = new StringBuffer();
    if( vicinity < 0 ) {
      for( player in _activePlayers ) 
         buf.write('<option>${player.name}</option>');
      return buf.toString();
      }
    BoardSquare bs = povPlayer.location;
    if( bs.above != null && bs.above.resident != null )
      buf.write('<option>${bs.above.resident.serialname}</option>');
    if( bs.below != null && bs.below.resident != null )
      buf.write('<option>${bs.below.resident.serialname}</option>');
    if( bs.left != null && bs.left.resident != null )
      buf.write('<option>${bs.left.resident.serialname}</option>');
    if( bs.right != null && bs.right.resident != null )
      buf.write('<option>${bs.right.resident.serialname}</option>');
    
    return buf.toString();
  
  }
  //
  // control whether maps are saved locally or not
  //
  void useLocal(Element mapdiv) {
    // use a local text area to load and save maps - for working remotely to www server
    if( uselocal ) return;
    maparea = new TextAreaElement();
    mapdiv.append(maparea);
    uselocal = true;
  }
  
  void useWeb(Element mapdiv) {
    // use the Put function of the local web server to load and save maps - default  
    if( !uselocal ) return;
    maparea.remove();
    maparea = null;
    uselocal = false;
  }
  
  /*
   * the follow methods are used during play and maybe during editing
   */
  Element     _content_message;
  List<Item>  _content_items;
  BoardSquare _content_square;
  
  void showcontents(BoardSquare square, List<Item> items) {
    _messages.text = 'There are items in front of you; click one to aquire';
    _content_items = items;
    _content_square = square;
    Item it; 
    // create table to load available images
    TableElement table = new TableElement();
    // _table.attributes['border'] = '1';
    TableRowElement row = table.addRow();
    for( it in items ) {
      if( it.imagename != null ) {
        Element cell = row.addCell();
        cell.id = it.name;
        cell.style.padding = '4px';
        cell.append( new ImageElement(src:'http://${HOSTNAME}/images/${it.imagename}.png'));
        cell.onClick.listen(_contents_click);
        cell.onMouseOver.listen(_contents_mouseover);
      }
    _messages.append(table);
    _content_message = new DivElement();
    _messages.append(_content_message);
    }
  }

  void _contents_mouseover( Event e ) {
    String desc;
    TableCellElement target = e.currentTarget;
    Item it = _content_items[target.cellIndex];
    if( it.description != null )
      if( board.descMap != null && (desc = board.descMap[it.description]) != null )
        _content_message.text = 'Item ${it.name}: ${desc}';
      else
        _content_message.text = 'Item ${it.name}: ${it.description}';
    else
      _content_message.text = 'Item ${it.name}';
    narrativeName = it.description;
  }

  void _contents_click( Event e ) {
    TableCellElement target = e.currentTarget;
    Item it = _content_items[target.cellIndex];
    // remove item from square's contents list
    _content_items.removeAt(target.cellIndex);
    // if list length now zero, remove list else refresh contents list
    if( _content_items.length == 0 ) {
      _content_square.contents = null;
      _messages.text = '';
    }
    else
      showcontents( _content_square, _content_items );
    if( povPlayer.possessions == null ) povPlayer.possessions = new List<Item>();
    povPlayer.possessions.add( it );
    possessions.show( povPlayer );
  }

  void stopRunning() {
    if( _sliceTimer != null ) _sliceTimer.cancel();
    running = false;
    _sliceTimer = null;
    _activePlayers = null;
    // clear the board of possesions
    possessions.clear();
    // unwind any chain stack
    while( _chainStack.length > 0 ) {
      board.remove();   // hide current board - will be destroyed by system
      board = _chainStack.removeLast();
     }
     board.restore();
  }

  void _createnewtimer(num interval) {
    if( singlestep ) return;
    if( _sliceTimer != null ) _sliceTimer.cancel();
    Duration dur = new Duration(milliseconds: interval);
    _sliceTimer = new Timer.periodic(dur, slicecallback);
  }
  
  void _placeboardresident(BoardSquare sqr) {
    // do all basic initialization for the player here
    // see if the player indicates 'point' direction
    ObjectEntry pe; String point;
    if( (pe=sqr.resident.properties['point']) != null) {
      point = pe.data.buffer.string;
      switch( point ) {
        case 'left': sqr.resident.direction = LEFT; break;
        case 'right': sqr.resident.direction = RIGHT; break;
        case 'up': sqr.resident.direction = ABOVE; break;
        case 'down': sqr.resident.direction = BELOW; break;
      }
    } else
      // set default direction
      sqr.resident.direction = RIGHT;
    // located a player: set location data and load the image element
    sqr.resident.location = sqr;
    if( sqr.resident.imagename != null ) {
      if( pe == null ) 
        sqr.resident.image = new ImageElement(src:'http://${HOSTNAME}/images/${sqr.resident.imagename}.png');
      else 
        sqr.resident.image = new ImageElement(src:'http://${HOSTNAME}/images/${sqr.resident.imagename}-${point}.png');
    }
    sqr.resident.image.height = sqr.resident.image.width = board.imageSize;
    // copy the player instance to _active players 
    _activePlayers.add(sqr.resident);
    // look for an initialization action
    ObjectEntry obj;
    if( (obj = sqr.resident.properties['initaction']) != null) {
      _slicePlayer = sqr.resident;
      interpreter.objects.changedepth(1);
      interpreter.objects.dictmap = sqr.resident.properties;
      // run the action in the base level as init
      interpreter.action( obj.data.buffer );
      // and put that back for use
      sqr.resident.properties = interpreter.objects.dictmap;
      interpreter.objects.changedepth(-1);      
    }
    // look for bevavior initialization
    if( (obj = sqr.resident.properties['behavior']) != null) {
      String pers = obj.data.buffer.string;
      switch(pers) {
        case 'vehicle': 
          sqr.resident.behavior = new VehBeh(this, sqr.resident, sqr.properties); break; 
        case 'pedestrian': 
          sqr.resident.behavior = new PedBeh(this, sqr.resident, sqr.properties); break; 
      }
      //if( sqr.resident.behavior != null ) sqr.resident.behavior.init();
    }
    // look for a knowledge base
    if( (obj = sqr.resident.properties['knowledge']) != null) {
      String know = obj.data.buffer.string;
      sqr.resident.knowledge = new KnowBase(queryConsole, english);
      sqr.resident.knowledge.read(know);  
      // we have no way of knowing if there was anything read!
    }
    // official enter the player into the board square so they show
    sqr.enter(sqr.resident);
    // look for POV player
    if( checkproperty( sqr.resident, 'POV', 'true')) {
      //_messages.text = 'POV player ${sqr.resident.name} located';
      povPlayer = sqr.resident;
      povPlayer.POV = true;
    } else
      sqr.resident.POV = false;   
  }
  
  void setToRunning() {
    // prep the game for running and set into run mode
    ObjectEntry obj, globalaction;
    // clear interpret objects then load board properties into 
    // interpreter so properties BECOME the level 1 objects 
    interpreter.objects.clear();
    interpreter.objects.dictmap = board.properties;
    // create other gameengine objects
    load_engine_objects();
    // clear activeplayer list, POV
    BoardSquare bs;
    Iterable<BoardSquare> squares = board.bsMap.values;
    _activePlayers = new List<GPlayer>();
    povPlayer = null;
    // look through board squares for any players to place
    // first reset the serial counters
    GPlayer.serialnum = Item.serialnum = 0;
    for( bs in squares )
      if( bs.resident != null ) _placeboardresident(bs);   
    // clear any selected cells from editing
    board.clearselected(); 
    // set game to running but still in pause
    running = true; paused = true;
    // create the periodic timer
    _createnewtimer( 500 );
    // execute global library and actions
    if( runlibrary != null ) 
      interpreter.action( runlibrary ); 
    if( (globalaction = board.properties['action']) != null) 
      interpreter.action( globalaction.data.buffer ); 
  }
  
  void slicecallback(Timer t)  {
    // go thru active player list and look for player action other than POV
    if( paused ) return;
    List playerList = _activePlayers.toList();
    GPlayer player; ObjectEntry obj;
    for( player in playerList ) {
      if( player.POV ) continue;
      if( player.sliceInit > 0 ) {
        if( player.sliceCount-- > 0 ) continue;
        player.sliceCount = player.sliceInit;
        // count is zero - reset count, run once
      }
      _slicePlayer = player;
      if( (obj = player.properties['action']) != null) {
        interpreter.objects.changedepth(1);
        interpreter.objects.dictmap = player.properties;
        // run the action in it's own level still
        interpreter.objects.changedepth(1);
        interpreter.action( obj.data.buffer );
        interpreter.objects.changedepth(-2);
      }
      if( player.behavior != null) player.behavior.slice();        
    }
    _slicePlayer = null;
  }
  
  void doSquareAction(GPlayer player, String actionprop) {
    // handle the square's action property if present
    // get the location from the player location property
    BoardSquare square = player.location;
    if( square.properties[actionprop] == null ) return;
    // fill in the resident field if present
    ObjectEntry obj;
    if( (obj = square.properties['resident']) != null ) {
      obj.data.buffer = new CharBuffer(null);
      obj.data.buffer.addAll(square.resident.name.codeUnits);
    }
    _actionSquare = square;   // note square in action
    // first depth increase is like an object 
    interpreter.objects.changedepth(1); 
    interpreter.objects.dictmap = square.properties;
    // also create an object 'player' to access resident player properties
    obj = interpreter.stdobjs.objectobject('player');
    obj.dict = player.properties;
    interpreter.objects.create(obj);
    // run the action in it's own level still
    interpreter.objects.changedepth(1);
    interpreter.action( square.properties[actionprop].data.buffer );
    interpreter.objects.changedepth(-2);
    _actionSquare = null;     // clear square in action
  }
  
  bool checkproperty( var obj, String prop, String value ) {
    // check to see if property exists and is set to a certain value
    ObjectEntry e = obj.properties[prop];
    if( e == null ) return false;
    if( e.data.buffer.string == value ) return true;
    return false;
  }
  
  bool doKeyFunc( int code ) {
    return false;
  }
  
  bool movePOVplayer( int direction, bool shift ) {
    return move( direction, shift, null, povPlayer );  
  }
  
  void changeorientation( GPlayer player, int dir ) {
    String point;
    switch( dir ) {
      case LEFT: point = 'left'; break;
      case RIGHT: point = 'right'; break;
      case ABOVE: point = 'up'; break;
      case BELOW: point = 'down'; break;
    }
    player.image = new ImageElement(src:'http://${HOSTNAME}/images/${player.imagename}-${point}.png');
    player.image.height = player.image.width = board.imageSize;
  }
  
  bool move(int direction, bool shift, String classname, GPlayer player ) {
    // move a player on board based on direction supplied if game is running
    if( !running || player == null ) return false;
    bool changeorient = false;
    // look for relative direction first
    switch (direction) {
      case FORWARD: direction = player.direction; break;
      case BACKWARD: 
        switch(player.direction) {
          case LEFT: direction = RIGHT; break;
          case RIGHT: direction = LEFT; break;
          case ABOVE: direction = BELOW; break;
          case BELOW: direction = ABOVE; break;
        } break;
      case LEFTWARD: 
        switch(player.direction) {
          case LEFT: direction = BELOW; break;
          case RIGHT: direction = ABOVE; break;
          case ABOVE: direction = LEFT; break;
          case BELOW: direction = RIGHT; break;
        } break;
      case RIGHTWARD: 
        switch(player.direction) {
          case LEFT: direction = ABOVE; break;
          case RIGHT: direction = BELOW; break;
          case ABOVE: direction = RIGHT; break;
          case BELOW: direction = LEFT; break;
        } break;
    }
    // check for class name to check
    if( classname != null && classname != 'none' ) {
      switch (direction) {
        case BELOW:
        if( player.location.below == null || player.location.below.classname != classname ) return false; break;
        case ABOVE:
        if( player.location.above == null || player.location.above.classname != classname ) return false; break;
        case LEFT:
        if( player.location.left == null || player.location.left.classname != classname ) return false; break;
        case RIGHT:
        if( player.location.right == null || player.location.right.classname != classname ) return false; break;
      }
    }
    if( !shift && direction != player.direction ) {
      player.direction = direction;
      if( player.properties['point'] != null ) changeorient = true;
    }
    switch (direction) {
      case BELOW:
        if (player.location.below != null && player.location.below.resident == null &&
            !checkproperty(player.location.below,'locked','true')) {
          doSquareAction(player, 'leaveaction');
          player.location.leave();
          player.location = player.location.below;
          if( changeorient ) changeorientation( player, direction );
          player.location.enter(player);
          doSquareAction(player, 'enteraction');
          return true;
        }
        break;
      case ABOVE:
        if (player.location.above != null && player.location.above.resident == null &&
            !checkproperty(player.location.above,'locked','true')) {
          doSquareAction(player, 'leaveaction');
          player.location.leave();
          player.location = player.location.above;
          if( changeorient ) changeorientation( player, direction );
          player.location.enter(player);
          doSquareAction(player, 'enteraction');
          return true;
        }
        break;
      case LEFT:
        if (player.location.left != null && player.location.left.resident == null &&
            !checkproperty(player.location.left,'locked','true')) {
          doSquareAction(player, 'leaveaction');
          player.location.leave();
          player.location = player.location.left;
          if( changeorient ) changeorientation( player, direction );
          player.location.enter(player);
          doSquareAction(player, 'enteraction');
          return true;
        }
        break;
      case RIGHT:
        if (player.location.right != null && player.location.right.resident == null &&
            !checkproperty(player.location.right,'locked','true')) {
          doSquareAction(player, 'leaveaction');
          player.location.leave();
          player.location = player.location.right;
          if( changeorient ) changeorientation( player, direction );
          player.location.enter(player);
          doSquareAction(player, 'enteraction');
          return true;
        }
        break;
    }
    return false;
  }

  int lookAround(int direction, int changedir, String classname) {
    BoardSquare sqr; int lookdir = direction;

    while( true ) {      
      switch( lookdir ) {
        case ABOVE: sqr = _slicePlayer.location.above;  break;
        case BELOW: sqr = _slicePlayer.location.below;  break;
        case LEFT:  sqr = _slicePlayer.location.left;  break;
        case RIGHT: sqr = _slicePlayer.location.right;  break;
      }
      if( sqr == null || sqr.classname != classname ) {
        // look for another square adjacent
        if( changedir == LEFTWARD ){
          switch(lookdir) {
             case ABOVE: lookdir = LEFT;  break;
             case BELOW: lookdir = RIGHT;  break;
             case LEFT:  lookdir = BELOW;  break;
             case RIGHT: lookdir = ABOVE;  break;
          }
        }
        else if( changedir == RIGHTWARD ){
          switch(lookdir) {
             case ABOVE: lookdir = RIGHT;  break;
             case BELOW: lookdir = LEFT;  break;
             case LEFT:  lookdir = ABOVE;  break;
             case RIGHT: lookdir = BELOW;  break;
          }
        }
        else { 
          //source.webcon.writeln('ERROR: leftward or rightward, found ${dirstring}');
          return -1;
        }
        if( lookdir == direction )
          /* once around, stuck */ 
          return -1;
        //
      }
      else return lookdir;
    }
  }

  bool attemptPass( int direction, String passstring, String classname) {
    //look for passing available
    BoardSquare psqr, psqr2; 
    int dir;
    if( passstring == 'left') {
      // update player direction
      //_slicePlayer.direction = direction;
      switch( direction) {
        case ABOVE: dir = LEFT; psqr = _slicePlayer.location.left;  break;
        case BELOW: dir = RIGHT; psqr = _slicePlayer.location.right;  break;
        case LEFT:  dir = BELOW; psqr = _slicePlayer.location.below;  break;
        case RIGHT: dir = ABOVE; psqr = _slicePlayer.location.above;  break;
      }
      if( psqr == null || psqr.resident != null || psqr.description != classname ) 
        return false;
      switch( direction) {
        case ABOVE: psqr2 = psqr.above;  break;
        case BELOW: psqr2 = psqr.below;  break;
        case LEFT:  psqr2 = psqr.left;  break;
        case RIGHT: psqr2 = psqr.right;  break;
      }
      if( psqr == null || psqr.resident != null || psqr.description != classname ) 
        return false;
      // go
      if( move( dir, true, null, _slicePlayer ) &&       
          move( direction, false, null, _slicePlayer )) return true;       
    }
    else if( passstring == 'right') {
      // update player direction
      //_slicePlayer.direction = direction;
      switch( direction) {
        case ABOVE: dir = RIGHT; psqr = _slicePlayer.location.right;  break;
        case BELOW: dir = LEFT; psqr = _slicePlayer.location.left;  break;
        case LEFT:  dir = ABOVE; psqr = _slicePlayer.location.above;  break;
        case RIGHT: dir = BELOW; psqr = _slicePlayer.location.below;  break;
      }
      if( psqr == null || psqr.resident != null || psqr.description != classname ) 
        return false;
      switch( direction) {
        case ABOVE: psqr2 = psqr.above;  break;
        case BELOW: psqr2 = psqr.below;  break;
        case LEFT:  psqr2 = psqr.left;  break;
        case RIGHT: psqr2 = psqr.right;  break;
      }
      if( psqr == null || psqr.resident != null || psqr.description != classname ) 
        return false;
      // go
      if( move( dir, true, null, _slicePlayer ) &&       
          move( direction, false, null, _slicePlayer )) return true;
    }
    return false;
  }

  GPlayer locateplayer( String ident ) {
     // attemp to locate an active player object by square's ident property
     GPlayer p;
     ObjectEntry obj;
     for( int i=0; i<_activePlayers.length; i++ ) {      
       p = _activePlayers.elementAt(i);
       if( (obj = p.properties['ident']) != null && obj.data.buffer.string == ident )
         return p;
     }
     return null;
   }
   
  BoardSquare locatesquare( String ident ) {
     // attemp to locate a boardsquare object by square's ident property
     Iterable<BoardSquare> bslist = board.bsMap.values;
     BoardSquare bs;
     ObjectEntry obj;
     for( int i=0; i<bslist.length; i++ ) {      
       bs = bslist.elementAt(i);
       if( (obj = bs.properties['ident']) != null && obj.data.buffer.string == ident )
         return bs;
     }
     return null;
   }
   
  String checkproximity( String playername, num distance, BoardSquare loc ) {
    
    GPlayer p, player; String name;
    int xtest, ytest;
    if( playername == 'POV') player = povPlayer;
    else {
      for( p in _activePlayers ) 
        if( playername == player.name ) {
          player = p;
          break;
        }
    }
    if( player == null ) return 'none';
    // this is only linear check on x/y, not triangulation 
    xtest = player.location.x - loc.x;
    if( xtest < 0 ) xtest = -xtest;
    if( xtest > distance ) return 'none';
    
    ytest = player.location.y - loc.y;
    if( ytest < 0 ) ytest = -ytest;
    if( ytest > distance ) return 'none';
    
    if( xtest > ytest )
      if( player.location.x < loc.x ) return 'above';
      else return 'below';
    else
      if( player.location.y < loc.y ) return 'left';
      else return 'right';
  }

  _chainboardloaded() {
    // get the chained board into a runnable state
    // look through board squares for new players to activate and entry point
    BoardSquare bs, enterbs;
    Iterable<BoardSquare> squares = board.bsMap.values;
    for( bs in squares ) 
      if( bs.resident != null ) {
        // set default direction
        bs.resident.direction = RIGHT;
        // located a player: set location data and load the image element
        bs.resident.location = bs;
        if( bs.resident.imagename != null ) {
          bs.resident.image = new ImageElement(src:'http://${HOSTNAME}/images/${bs.resident.imagename}.png');
          bs.resident.image.height = bs.resident.image.width = board.imageSize;        }
        // copy the player instance to _active players 
        _activePlayers.add(bs.resident);
        // call square.enter to make them show up
        bs.enter(bs.resident);
      } else if( checkproperty(bs, 'ENTRANCE', 'true'))
        enterbs = bs;
    
    if( enterbs != null ) {
      povPlayer.location = enterbs;
      enterbs.enter(povPlayer);
    }
    // update the title on game screen
	pager.updateTitle();
    // unpause the game
    paused = false;
  }

  /*
   * predefined GameEngine objects
   * 
   * Player: this is special object which when used will create another object
   * which can be used to access the properties of a givin player 
   * identified by 'POV' or ident
   */
static const String Game_Objects_help = '''
These are script objects which are associated with game board and
are only available while the game is in run mode.
''';

  static const String player_help = '''
<p><i>player</i> new_object_name player_identifier</p>
Player is used to create an object with the modifiable properties of an active player.
The first argument is the name of the object to create, and the second the identifier of the
player whose properties you wish to access, or "POV". Reading the value of the Player object
will return the success of the last usage of Player.
''';

  int player_input(CharBuffer source, Map<String,ObjectEntry> dictmap, ObjectData data, String help ) {

    int tok;
    String objectname, squareident;
    ObjectEntry obj;
    GPlayer  player;
    data.value = 0;
    
    // create a lexer for method's use
    TokenLexer lexer = new TokenLexer( source );

    if( (tok = lexer.nexttoken()) == TokenLexer.HELP ) {
      source.addAll(help.codeUnits);
      source.deliver();
      return 0;
    }    
    if( tok != TokenLexer.NAME ) {
      source.webcon.writeln('ERROR: expecting object name, found ${lexer.lastscanchar}');
      lexer.backup();
      return CharBuffer.ERROR;      
    }
    objectname = lexer.name;
    // look for dup object - at current level only, allow for shadowing
    if( interpreter.objects.locatecurrent(objectname) != null ) {
      source.webcon.writeln('can\'t create object with dup name "${objectname}"');
      return CharBuffer.ERROR;      
    }
    // look for player ident
    if( (tok = lexer.nexttoken()) != TokenLexer.NAME ) {
      source.webcon.writeln('ERROR: expecting player ident, found ${lexer.lastscanchar}');
      lexer.backup();
      data.value = 0;
      return CharBuffer.ERROR;      
    }  
    if( _actionSquare != null ) 
      switch( lexer.name ){
        case 'POV':   player = povPlayer; break;
        case 'left':  if( _actionSquare.left != null ) 
          player = _actionSquare.left.resident; break;
        case 'right': if( _actionSquare.right != null ) 
          player = _actionSquare.right.resident;  break;
        case 'above':    if( _actionSquare.above != null ) 
          player = _actionSquare.above.resident;  break;
        case 'below':  if( _actionSquare.below != null ) 
          player = _actionSquare.below.resident;  break;
        case 'this':  player = _actionSquare.resident; break;
        default:      player = locateplayer( lexer.name ); break;
      }      
    else if( lexer.name == 'POV')
      player = povPlayer;
    else  
      player = locateplayer( lexer.name );
    
    if( player == null ) {
      source.webcon.writeln('WARNING: can\'t locate player with ident "${lexer.name}"');
      return CharBuffer.WARNING;      
    }
        
    obj = interpreter.stdobjs.objectobject( objectname );
    obj.dict = player.properties;
    interpreter.objects.create(obj);

    data.value = 1;
    return 0;  
  }

  num player_value(Map<String,ObjectEntry> dictmap, ObjectData data ) {    
    return data.value;
  }
  
  /*
   * Square: this is special object which when used will create another object
   * which can be used to access the properties of a givin square identified by ident
   */
  static const String square_help = '''
<p><i>square</i> new_object_name square_identifier<br>
value_object = <i>&#36;square</i><br>
text_object = <i>&#36;square</i></p>
Square is used to create an object with the modifiable properties of a board square.
The first argument is the name of the object to create, and the second the identifier of the
square whose properties you wish to access. Reading the value of the Square object will
return the success of the last Square usage. Reading the output of the Square object will
return the name of the resident, if any, occupying the square or else will return 'none'.
''';

  int square_input(CharBuffer source, Map<String,ObjectEntry> dictmap, ObjectData data, String help ) {

    int tok;
    String objectname, squareident;
    ObjectEntry obj;
    BoardSquare  sqr;    
    data.value = 0;
    
    // create a lexer for method's use
    TokenLexer lexer = new TokenLexer( source );

    if( (tok = lexer.nexttoken()) == TokenLexer.HELP ) {
      source.addAll(help.codeUnits);
      source.deliver();
      return 0;
    }    
    if( tok != TokenLexer.NAME ) {
      source.webcon.writeln('ERROR: expecting object name, found ${lexer.lastscanchar}');
      lexer.backup();
      return CharBuffer.ERROR;      
    }
    objectname = lexer.name;
    // look for dup object - at current level only, allow for shadowing
    if( interpreter.objects.locatecurrent(objectname) != null ) {
      source.webcon.writeln('can\'t create object with dup name "${objectname}"');
      return CharBuffer.ERROR;      
    }
    // look for square ident
    if( (tok = lexer.nexttoken()) != TokenLexer.NAME ) {
      source.webcon.writeln('ERROR: expecting square ident, found ${lexer.lastscanchar}');
      lexer.backup();
      return CharBuffer.ERROR;      
    }  
    if( _slicePlayer != null ) 
      // if a slice player, we can use relative square location
      switch( lexer.name ){
        case 'leftward':
          switch(_slicePlayer.direction) {
            case ABOVE: sqr = _slicePlayer.location.left;  break;
            case BELOW: sqr = _slicePlayer.location.right;  break;
            case LEFT:  sqr = _slicePlayer.location.below;  break;
            case RIGHT: sqr = _slicePlayer.location.above;  break;
          }
          break;
        case 'rightward':
          switch(_slicePlayer.direction) {
            case ABOVE: sqr = _slicePlayer.location.right;  break;
            case BELOW: sqr = _slicePlayer.location.left;  break;
            case LEFT:  sqr = _slicePlayer.location.above;  break;
            case RIGHT: sqr = _slicePlayer.location.below;  break;
          }
          break;
        case 'forward':
          switch(_slicePlayer.direction) {
            case ABOVE: sqr = _slicePlayer.location.above;  break;
            case BELOW: sqr = _slicePlayer.location.below;  break;
            case LEFT:  sqr = _slicePlayer.location.left;  break;
            case RIGHT: sqr = _slicePlayer.location.right;  break;
          }
          break;
        case 'backward':
          switch(_slicePlayer.direction) {
            case ABOVE: sqr = _slicePlayer.location.below;  break;
            case BELOW: sqr = _slicePlayer.location.above;  break;
            case LEFT:  sqr = _slicePlayer.location.right;  break;
            case RIGHT: sqr = _slicePlayer.location.left;  break;
          }
          break;
        case 'left':  sqr = _slicePlayer.location.left;   break;
        case 'right': sqr = _slicePlayer.location.right;  break;
        case 'above': sqr = _slicePlayer.location.above;  break;
        case 'below': sqr = _slicePlayer.location.below;  break;
        case 'this':  sqr = _slicePlayer.location;        break;
        default:      sqr = locatesquare( lexer.name );   break;
      }      
    else
      sqr = locatesquare( lexer.name );
    
    if( sqr == null ) {
      source.webcon.writeln('WARNING: can\'t locate square with ident "${lexer.name}"');
      return CharBuffer.WARNING;      
    }
        
    obj = interpreter.stdobjs.objectobject( objectname );
    obj.dict = sqr.properties;
    interpreter.objects.create(obj);
    data.buffer = new CharBuffer(null);
    if( sqr.resident != null ) 
      data.buffer.addAll(sqr.resident.name.codeUnits);
    else
      data.buffer.addAll('none'.codeUnits);

    return 0;  
  }

  int square_output(Map<String,ObjectEntry> dictmap, ObjectData data, CharBuffer buffer, int pos ) {
    buffer.insertAll(pos, data.buffer);
    return 0;
  }
  
  num square_value(Map<String,ObjectEntry> dictmap, ObjectData data ) {    
    return data.value;
  }
  
   /*
   * Warp: this object will transport self or other beings to a specific location 
   */
  static const String warp_help = '''
<p><i>warp</i> player_identifier location_identifier</p>
Warp is used to instantly transport a player to a specific location on the board 
and is usually called by an action property within a square. 
First argument is a player name reference, or POV, and the second argument 
is the location identifier of the location to warp to.
''';

  int warp_input(CharBuffer source, Map<String,ObjectEntry> dictmap, ObjectData data, String help ) {

    int         tok;
    BoardSquare sqr;
    String      being;
    ObjectEntry obj;
    
    // create a lexer for method's use
    TokenLexer lexer = new TokenLexer( source );

    if( (tok = lexer.nexttoken()) == TokenLexer.HELP ) {
      source.addAll(help.codeUnits);
      source.deliver();
      return 0;
    }    
    if( tok != TokenLexer.NAME ) {
      source.webcon.writeln('ERROR: expecting player identifier, found ${lexer.lastscanchar}');
      lexer.backup();
      return CharBuffer.ERROR;      
    }    
    being = lexer.name;
    if( (tok = lexer.nexttoken()) != TokenLexer.NAME ) {
      source.webcon.writeln('ERROR: expecting location identifier, found ${lexer.lastscanchar}');
      lexer.backup();
      return CharBuffer.ERROR;      
    }    
    sqr = locatesquare( lexer.name );
    if( sqr == null ) {
      source.webcon.writeln('WARNING: can\'t locate square with ident "${lexer.name}"');
      return CharBuffer.ERROR;      
    }

    if( being == 'POV' ) {      
      povPlayer.location.leave();
      povPlayer.location = sqr;
      povPlayer.location.enter(povPlayer);
    } 
    else if( being == 'self' ) {
      if( _slicePlayer == null ) return 0;
      _slicePlayer.location.leave();
      _slicePlayer.location = sqr;
      _slicePlayer.location.enter(_slicePlayer);
    }
    else if( being == 'resident' ) {
      if( _actionSquare == null ) return 0;
      GPlayer p = _actionSquare.resident;
      if( p == null ) return 0 ;
      _actionSquare.leave();
      p.location = sqr;
      p.location.enter(p);
    }
    return 0;
  }
  
  /*
   * Move: this object is used to move the player with the timer slice around  
   */
  static const String move_help = '''
<p><i>move</i> classname direction</p>
Move is used to move a player who is not the POV player one square in any direction.
The first argument is the class to stay in, and the second is the direction: 
left, right, above, below, leftward, rightward, forward, backward, shiftleft, shiftright. 
Reading the value of move object will return the success of the last move attempted.
'''; 

  int move_input(CharBuffer source, Map<String,ObjectEntry> dictmap, ObjectData data, String help ) {

    ObjectEntry obj;
    int tok, direction;
    String classname, dirstring;
    bool shift = false;
    data.value = 0;

    // create a lexer for method's use
    TokenLexer lexer = new TokenLexer( source );
    if( (tok = lexer.nexttoken()) == TokenLexer.HELP ) {
      source.addAll(help.codeUnits);
      source.deliver();
      return 0;
    }    
    // make sure there is a _slicePlayer reference
    if( _slicePlayer == null ) {
      source.webcon.writeln('ERROR: no slice player available. Must be called from player object');
      return CharBuffer.ERROR;
    }
    // first is class spec
    if( tok == TokenLexer.NAME )
      classname = lexer.name;
    else if( tok == TokenLexer.OBJECT ) {
      if((obj = interpreter.objects.locate(lexer.name)) != null) {
        if( obj.type == ObjectEntry.TEXT || 
            ( obj.type == ObjectEntry.INTERNAL && obj.data != null && obj.data.buffer != null ))
          classname = obj.data.buffer.string;
        else {
          source.webcon.writeln('ERROR: bad object for class: "${lexer.name}"');
          return CharBuffer.ERROR;
        }
      }
    } else {
      source.webcon.writeln('ERROR: expecting class identifier, found ${lexer.lastscanchar}');
      lexer.backup();
      return CharBuffer.ERROR;      
    }   
    // then is the direction 
    tok = lexer.nexttoken();
    if( tok == TokenLexer.NAME )
      dirstring = lexer.name;
    else if( tok == TokenLexer.OBJECT ) {
      ObjectEntry obj;
      if((obj = interpreter.objects.locate(lexer.name)) != null) {
        if( obj.type == ObjectEntry.TEXT || 
            ( obj.type == ObjectEntry.INTERNAL && obj.data != null && obj.data.buffer != null ))
          dirstring = obj.data.buffer.string;
        else {
          source.webcon.writeln('ERROR: bad object for direction: "${lexer.name}"');
          return CharBuffer.ERROR;
        }
      }
    } else {
      source.webcon.writeln('ERROR: expecting direction identifier, found ${lexer.lastscanchar}');
      lexer.backup();
      return CharBuffer.ERROR;      
    }    
    
    if( dirstring == 'none' ) {
      source.webcon.writeln('WARNING: can\'t move towards "none"');
      return 1;
    }    
    else if( dirstring == 'shiftleft' ) {
      shift = true; direction = LEFTWARD;
    }
    else if( dirstring == 'shiftright' ) {
      shift = true; direction = RIGHTWARD;
    }
    else if( dirstring == 'left' )     direction = LEFT;
    else if( dirstring == 'right' )    direction = RIGHT;
    else if( dirstring == 'above' )    direction = ABOVE;
    else if( dirstring == 'below' )    direction = BELOW;
    else if( dirstring == 'forward' )  direction = FORWARD;
    else if( dirstring == 'backward' ) direction = BACKWARD;
    else if( dirstring == 'leftward' ) direction = LEFTWARD;
    else if( dirstring == 'rightward' )direction = RIGHTWARD;
    else {
      source.webcon.writeln('ERROR: expecting location, found "${dirstring}"');
      return CharBuffer.ERROR;
    }
    
    // perform the move
    if( move( direction, shift, classname, _slicePlayer ) ) data.value = 1;    
    return 0;
  }
  
  num move_value(Map<String,ObjectEntry> dictmap, ObjectData data ) {    
    return data.value;
  }
  
  /*
   * Merge this object is used to merge the player with the timer slice left or right  
   */
   static const String merge_help = '''
<p><i>merge</i> class_description passing_direction</p>
Merge left or right within a class. Merge doesn't change the player's direction,
it's the same as passing. 
Reading the value of merge object will return the success of the last merge attempted.
'''; 

  int merge_input(CharBuffer source, Map<String,ObjectEntry> dictmap, ObjectData data, String help ) {

    int tok, direction;
    ObjectEntry obj;
    String classname, passstring;
    data.value = 0;

    // create a lexer for method's use
    TokenLexer lexer = new TokenLexer( source );
    if( (tok = lexer.nexttoken()) == TokenLexer.HELP ) {
      source.addAll(help.codeUnits);
      source.deliver();
      return 0;
    }    
    // make sure there is a _slicePlayer reference
    if( _slicePlayer == null ) {
      source.webcon.writeln('ERROR: no slice player available. Must be called from player object');
      return CharBuffer.ERROR;
    }
    // first is class spec
    if( tok == TokenLexer.NAME )
      classname = lexer.name;
    else if( tok == TokenLexer.OBJECT ) {
      //ObjectEntry obj;
      if((obj = interpreter.objects.locate(lexer.name)) != null) {
        if( obj.type == ObjectEntry.TEXT || 
            ( obj.type == ObjectEntry.INTERNAL && obj.data != null && obj.data.buffer != null ))
          classname = obj.data.buffer.string;
        else {
          source.webcon.writeln('ERROR: bad object for class: "${lexer.name}"');
          return CharBuffer.ERROR;
        }
      }
    } else {
      source.webcon.writeln('ERROR: expecting class identifier, found ${lexer.lastscanchar}');
      lexer.backup();
      return CharBuffer.ERROR;      
    }   
    // then the pass direction
    tok = lexer.nexttoken();
    if( tok == TokenLexer.NAME )
      passstring = lexer.name;
    else if( tok == TokenLexer.OBJECT ) {
      //ObjectEntry obj;
      if((obj = interpreter.objects.locate(lexer.name)) != null) {
        if( obj.type == ObjectEntry.TEXT || 
            ( obj.type == ObjectEntry.INTERNAL && obj.data != null && obj.data.buffer != null ))
          passstring = obj.data.buffer.string;
        else {
          source.webcon.writeln('ERROR: bad object for direction: "${lexer.name}"');
          return CharBuffer.ERROR;
        }
      }
    } else {
      source.webcon.writeln('ERROR: expecting direction identifier, found ${lexer.lastscanchar}');
      lexer.backup();
      return CharBuffer.ERROR;      
    }
    
    if( attemptPass( _slicePlayer.direction, passstring, classname ))
      data.value = 1;
    return 0;
  }   
   
  num merge_value(Map<String,ObjectEntry> dictmap, ObjectData data ) {    
    return data.value;
  }
     
  /*
   * Forward: this object is used to move the player with the timer slice forward  
   */
  static const String forward_help = '''
  <p><i>forward</i> class_description turning_direction passing_direction</p>
  Forward is an advanced form of move. It takes three arguments: 
  the class of the area to stay in, and the suggested turning direction 
  if forward is not possible (leftward, rightward), and the passing direction(left,right).
  Reading the value of move object will the success of the last move 
  attempted(0=no move,1=foward,2=turn,3=pass)
  '''; 
  int forward_input(CharBuffer source, Map<String,ObjectEntry> dictmap, ObjectData data, String help ) {

    int tok, direction;
    ObjectEntry obj;
    String classname, dirstring, passstring;
    data.value = 0;

    // create a lexer for method's use
    TokenLexer lexer = new TokenLexer( source );
    if( (tok = lexer.nexttoken()) == TokenLexer.HELP ) {
      source.addAll(help.codeUnits);
      source.deliver();
      return 0;
    }    
    // make sure there is a _slicePlayer reference
    if( _slicePlayer == null ) {
      source.webcon.writeln('ERROR: no slice player available. Must be called from player object');
      return CharBuffer.ERROR;
    }
    // first is class spec
    if( tok == TokenLexer.NAME )
      classname = lexer.name;
    else if( tok == TokenLexer.OBJECT ) {
      //ObjectEntry obj;
      if((obj = interpreter.objects.locate(lexer.name)) != null) {
        if( obj.type == ObjectEntry.TEXT || 
            ( obj.type == ObjectEntry.INTERNAL && obj.data != null && obj.data.buffer != null ))
          classname = obj.data.buffer.string;
        else {
          source.webcon.writeln('ERROR: bad object for class: "${lexer.name}"');
          return CharBuffer.ERROR;
        }
      }
    } else {
      source.webcon.writeln('ERROR: expecting class identifier, found ${lexer.lastscanchar}');
      lexer.backup();
      return CharBuffer.ERROR;      
    }   
    // then the turn direction
    tok = lexer.nexttoken();
    if( tok == TokenLexer.NAME )
      dirstring = lexer.name;
    else if( tok == TokenLexer.OBJECT ) {
      if((obj = interpreter.objects.locate(lexer.name)) != null) {
        if( obj.type == ObjectEntry.TEXT || 
            ( obj.type == ObjectEntry.INTERNAL && obj.data != null && obj.data.buffer != null ))
          dirstring = obj.data.buffer.string;
        else {
          source.webcon.writeln('ERROR: bad object for direction: "${lexer.name}"');
          return CharBuffer.ERROR;
        }
      }
    } else {
      source.webcon.writeln('ERROR: expecting direction identifier, found ${lexer.lastscanchar}');
      lexer.backup();
      return CharBuffer.ERROR;      
    }    
    // then the pass direction
    tok = lexer.nexttoken();
    if( tok == TokenLexer.NAME )
      passstring = lexer.name;
    else if( tok == TokenLexer.OBJECT ) {
      //ObjectEntry obj;
      if((obj = interpreter.objects.locate(lexer.name)) != null) {
        if( obj.type == ObjectEntry.TEXT || 
            ( obj.type == ObjectEntry.INTERNAL && obj.data != null && obj.data.buffer != null ))
          passstring = obj.data.buffer.string;
        else {
          source.webcon.writeln('ERROR: bad object for direction: "${lexer.name}"');
          return CharBuffer.ERROR;
        }
      }
    } else {
      source.webcon.writeln('ERROR: expecting direction identifier, found ${lexer.lastscanchar}');
      lexer.backup();
      return CharBuffer.ERROR;      
    }
    //
    // done gathering arguments: now get to work
    //
    BoardSquare sqr; int turn = RIGHTWARD;
    switch( dirstring ) {
      case 'leftward': turn = LEFTWARD; break;
      case 'rightward': turn = RIGHTWARD; break;
      case 'backward': turn = BACKWARD; break;
    }
    // look for direction to move
    direction = lookAround( _slicePlayer.direction, turn, classname );
    if( direction < 0 ) return 0;  // stuck
    switch( direction ) {
      case ABOVE: sqr = _slicePlayer.location.above;  break;
      case BELOW: sqr = _slicePlayer.location.below;  break;
      case LEFT:  sqr = _slicePlayer.location.left;  break;
      case RIGHT: sqr = _slicePlayer.location.right;  break;
    }
    // is it occupied? if not, move
    if( sqr.resident == null ) {
      // perform the move
      if( move( direction, false, null, _slicePlayer ) ) {
        if( direction == _slicePlayer.direction ) data.value = 1;
        else data.value = 2;
      }
      return 0;
    }
    // look for a pass
    if( passstring == 'none' ) return 0;
    if( attemptPass( direction, passstring, classname ))
      data.value = 3;
    return 0;
 }
  
  num forward_value(Map<String,ObjectEntry> dictmap, ObjectData data ) {    
    return data.value;
  }
  
  /*
   * Proximity: this object is used to sense the direction or presence of other players
   */
  static const String proximity_help = '''
<p><i>proximity</i> player_name distance_limit<br>
text_object = <i>&#36;proximity</i></p>
Proximity is used to sense the direction and presence of another player. The first
argument is the name of the player to sense for, or POV. The next argument is the distance
to limit the sense to. In this way, using distance = 1 will sense for an adjacent player. 
The results of the proximity check is found in the text output of Proximity, and will be
one of direction, left/right/up/down, or none.
''';

  int proximity_input(CharBuffer source, Map<String,ObjectEntry> dictmap, ObjectData data, String help ) {

    int         tok, direction;
    num         distance;
    String      being;
    BoardSquare bs;

    // create a lexer for method's use
    TokenLexer lexer = new TokenLexer( source );
    if( (tok = lexer.nexttoken()) == TokenLexer.HELP ) {
      source.addAll(help.codeUnits);
      source.deliver();
      return 0;
    }    
    if( tok != TokenLexer.NAME ) {
      source.webcon.writeln('ERROR: expecting player identifier, found ${lexer.lastscanchar}');
      lexer.backup();
      return CharBuffer.ERROR;      
    }    
    being = lexer.name;
    tok = lexer.nexttoken();
    if( tok == TokenLexer.NUMERIC ) 
      distance = lexer.value;
    else if( tok == TokenLexer.OBJECT ) {
      ObjectEntry obj;
      if((obj = interpreter.objects.locate(lexer.name)) != null) {
        if( obj.type == ObjectEntry.VALUE )
          distance = obj.value;
        else {
          source.webcon.writeln('ERROR: bad object for distance: "${lexer.name}"');
          return CharBuffer.ERROR;
        }
      } else {
        source.webcon.writeln('ERROR: unknown object: "${lexer.name}"');
        return CharBuffer.ERROR;
      }
    } else {
      source.webcon.writeln('ERROR: expecting distance, found ${lexer.lastscanchar}');
      lexer.backup();
      return CharBuffer.ERROR;      
    }    
    if( _slicePlayer != null ) 
      bs = _slicePlayer.location;
    else
      bs = povPlayer.location;
    
    data.buffer = new CharBuffer(null);
    data.buffer.addAll( checkproximity( being, distance, bs ).codeUnits );
    return 0;
  }
  
  int proximity_output(Map<String,ObjectEntry> dictmap, ObjectData data, CharBuffer buffer, int pos ) {
    buffer.insertAll(pos, data.buffer);
    return 0;
  }
  
  /*
   * Clone: this object is used to clone a new player from the player definitions and
   * place somewhere on the board
   */
  static const String clone_help = '''
<p><i>clone</i> player_name location_ident</p>
Clone is used to clone a new player from the player definitions and place them
somewhere on the board. The first argument is the name of the player to clone, and
the second is the location ident of the location to place the new player.
''';

  int clone_input(CharBuffer source, Map<String,ObjectEntry> dictmap, ObjectData data, String help ) {
    int         tok;
    GPlayer      player;
    BoardSquare sqr;

    // create a lexer for method's use
    TokenLexer lexer = new TokenLexer( source );
    if( (tok = lexer.nexttoken()) == TokenLexer.HELP ) {
      source.addAll(help.codeUnits);
      source.deliver();
      return 0;
    }    
    if( tok != TokenLexer.NAME ) {
      source.webcon.writeln('ERROR: expecting player identifier, found ${lexer.lastscanchar}');
      lexer.backup();
      return CharBuffer.ERROR;      
    }    
    player = board.players[lexer.name];
    if( player == null ) {
      source.webcon.writeln('ERROR: unknown player "${lexer.name}"');
      return CharBuffer.ERROR;      
    }
    tok = lexer.nexttoken();
    if( tok != TokenLexer.NAME ) {
      source.webcon.writeln('ERROR: expecting location identifier, found ${lexer.lastscanchar}');
      lexer.backup();
      return CharBuffer.ERROR;      
    }    
    sqr = locatesquare( lexer.name );
    if( sqr == null ) {
      source.webcon.writeln('ERROR: can\'t locate square with ident "${lexer.name}"');
      return CharBuffer.ERROR;      
    }
    if( sqr.resident != null ) {
      source.webcon.writeln('WARNING: square already has resident "${sqr.resident.name}": can\'t place"');
      return CharBuffer.WARNING;      
    }
    sqr.resident = player.duplicate();
    _placeboardresident(sqr);
    return 0;
  }

  /*
   * Game: this object is used control game action
   */
  static const String game_help = '''
<p><i>game</i> control_argument [ setting ]</p>
Game is used to control game action. It accepts at a minimum one control argument:
stop, pause, continue, speed, chain, return.
'stop' stops the game (once stopped, game cannot be restarted),
'pause' will pause the game and stop autonomous players from moving, 
'continue' will unpause the game, 'speed' will modify timer speed 
(it accepts one argument, the timer interval in milliseconds),
'chain' will chain load another game board and continue play on that board,
'return' will return from a chain load game to the caller board.
''';

  int game_input(CharBuffer source, Map<String,ObjectEntry> dictmap, ObjectData data, String help ) {
    int tok; num interval;
    // create a lexer for method's use
    TokenLexer lexer = new TokenLexer( source );
    if( (tok = lexer.nexttoken()) == TokenLexer.HELP ) {
      source.addAll(help.codeUnits);
      source.deliver();
      return 0;
    }    
    if( tok != TokenLexer.NAME ) {
      source.webcon.writeln(
         'ERROR: expecting stop, pause, continue or speed; chain, return or url.\nFound ${lexer.lastscanchar}');
      lexer.backup();
      return CharBuffer.ERROR;      
    }
    switch( lexer.name ) {
      case 'stop': stopRunning(); break; 
      case 'pause': paused = true; break; 
      case 'continue': paused = false; break;
      case 'speed':
        tok = lexer.nexttoken();
        if( tok == TokenLexer.NUMERIC ) 
          interval = lexer.value;
        else if( tok == TokenLexer.OBJECT ) {
          ObjectEntry obj;
          if((obj = interpreter.objects.locate(lexer.name)) != null) {
            if( obj.type == ObjectEntry.VALUE )
              interval = obj.value;
            else {
              source.webcon.writeln('ERROR: bad object for speed interval: "${lexer.name}"');
              return CharBuffer.ERROR;
            }
          } else {
            source.webcon.writeln('ERROR: unknown object: "${lexer.name}"');
            return CharBuffer.ERROR;
          }
        } else {
          source.webcon.writeln('ERROR: expecting speed interval, found ${lexer.lastscanchar}');
          lexer.backup();
          return CharBuffer.ERROR;      
        } 
        _createnewtimer( interval );
        break;
      case 'chain':
        int saveimagesize;
        tok = lexer.nexttoken();
        if( tok != TokenLexer.NAME ) { 
          source.webcon.writeln('ERROR: expecting board name, found ${lexer.lastscanchar}');
          lexer.backup();
          return CharBuffer.ERROR; 
        } 
        paused = true;            // pause the game while we load the new board
        // save the location of the povPlayer in board
        board.savePovLocation = povPlayer.location;
        // have player leave that location
        povPlayer.location.leave();
        // save the _activePlayer list length
        board.activePlayersLength = _activePlayers.length;
        board.remove();           // hide current board by removing from gameelement
        // keep the imagesize continuity
        saveimagesize = board.imageSize;
        _chainStack.add(board);   // push it on stack
        // create an new gameboard instance and load the chained board
        board = new GameBoard( this, _boardelement, _mouseover, _messages );
        board.loadEngineProps = false;    // don't load engine props on chaining
        board.loadcallback = _chainboardloaded;
        board.imageSize = saveimagesize;
        board.loadMap(lexer.name);
        break;        
      case 'return':
        if( _chainStack.length == 0 ) break;
        // return to the parent who chain to us
        paused = true;
        board.remove();   // hide current board - will be destroyed by system
        board = _chainStack.removeLast();
        // clear the _activePlayer list of any players from current board
        int n = _activePlayers.length - board.activePlayersLength;
        while( n-- > 0 ) 
          _activePlayers.removeLast();
        // return player to last location in restored board
        povPlayer.location = board.savePovLocation;
        povPlayer.location.enter(povPlayer);
        // restore the board to view
        board.restore();
        pager.updateTitle();
        paused = false;   // resume play
        break;
      case 'url':
        tok = lexer.nexttoken();
        if( tok != TokenLexer.STRING) { 
          source.webcon.writeln('ERROR: expecting "url", found ${lexer.lastscanchar}');
          lexer.backup();
          return CharBuffer.ERROR; 
        } 
        window.open(lexer.string.string,'url');
        break;
      default: 
        source.webcon.writeln(
         'Expecting stop, pause, continue or speed; chain, return or url.\nFound ${lexer.lastscanchar}');
        break;
    }
    
    return 0;
  }
  
  /*
   * Message: this object is used to update the message area with new text
   */
  static const String message_help = '''
<p><i>message</i> =/+ text_object</p>
Message is used to update the text which shows in the board's message area.
Message acts just like a text object.
''';

  int message_input(CharBuffer source, Map<String,ObjectEntry> dictmap, ObjectData data, String help ) {
    int tok, tok2;
    ObjectEntry obj, e;
    num value;
    CharBuffer buffer;
    // create a lexer for method's use
    TokenLexer lexer = new TokenLexer( source );
    if( (tok = lexer.nexttoken()) == TokenLexer.HELP ) {
      source.addAll(help.codeUnits);
      source.deliver();
      return 0;
    }    
    if( tok == TokenLexer.EQUAL || tok == TokenLexer.ADD ) {
      
      tok2 = lexer.nexttoken();
      if( tok2 == TokenLexer.STRING ) {
        // token is a quoted string
        if( lexer.quotechar == TokenLexer.doublequote )
          if( interpreter.stdobjs.expandbuffer( lexer.string, 0 ) == CharBuffer.WAIT )
            return CharBuffer.WAIT;
          buffer = lexer.string;
        
      } else if( tok2 == TokenLexer.OBJECT ) {
        if((obj = interpreter.objects.locate(lexer.name)) == null) {
          source.webcon.writeln('ERROR: can\'t locate object "${lexer.name}"');      
          return CharBuffer.ERROR;
        }
        if( obj.dict != null && lexer.scanchar == TokenLexer.period ) {
          // there's a dictionary and property/method, grab it
          lexer.nexttoken();
          tok = lexer.nexttoken();
          if( tok != TokenLexer.NAME ) {
            source.webcon.writeln('ERROR: Expecting method name, found "${lexer.lastscanchar}');
            return CharBuffer.ERROR;            
          }
          ObjectEntry e = interpreter.objects.locate_from( obj.dict, lexer.name);   
          if( e == null ) {
            source.webcon.writeln('ERROR: unrecognized method "${lexer.name}"');
            return CharBuffer.ERROR;
            }
          if( e.output != null ) {
            // use the output method.
            if( interpreter.verbosity > MandyInterpreter.VERBOSE_MED )
              source.webcon.writeln('INFO: "${obj.name}.${e.name}" recognized, calling output method');
            
            buffer = new CharBuffer( null );
            interpreter.objects.changedepth(1);
            interpreter.objects.dictmap = obj.dict;
            e.output( e.dict, e.data, buffer, 0 );
            interpreter.objects.changedepth(-1);
          } else 
            source.webcon.writeln('ERROR: no input method for "${lexer.name}"');
        }
        else if( obj.output != null ) {
          buffer = new CharBuffer( null );
          if( obj.output(obj.dict, obj.data, buffer, 0 ) == CharBuffer.WAIT )
            return CharBuffer.WAIT;
        }
        else if( e.value != null ) {
          value = e.value( e.dict, e.data );
          buffer.addAll( value.toString().codeUnits );               
        }
      } else {
        source.webcon.writeln('Expecting quoted string or object, something else');
        return CharBuffer.ERROR;
      }

      if( buffer != null )
        if( tok == TokenLexer.EQUAL )
          _messages.text = buffer.string;
        else // append for + 
          _messages.text = '${_messages.text}${buffer.string}';
    }

    else {
      source.webcon.writeln('Expecting "=" or "+" after text object, found "${lexer.lastscanchar}"');
      return CharBuffer.ERROR;
    }
    
    return 0;
  }
 
  /*
   * Narrative: this object is used to display a narrative text
   */
  static const String narrative_help = '''
<p><i>narrative</i> narative_file_name</p>
The Narrative object is used to display a game narrative on command.
Following the narrative object should be the name of the narrative file.
''';  
  
  int narrative_input(CharBuffer source, Map<String,ObjectEntry> dictmap, ObjectData data, String help ) {

    num value;
    int tok, retval = 0;
    
    // create a lexer for method's use and look for help
    TokenLexer lexer = new TokenLexer( source );

    if( (tok = lexer.nexttoken()) == TokenLexer.HELP ) {
      source.addAll(help.codeUnits);  
      source.deliver();
      return 0;
    }    
    if( tok == TokenLexer.NAME ) 
      pager.enterNarrative( lexer.name );
    else if( tok == TokenLexer.STRING ) {
      pager.enterNarrative(lexer.string.string );
    } else { 
      source.webcon.writeln('ERROR: expecting narrative filename, found "${lexer.lastscanchar}"');      
      return CharBuffer.ERROR;
    } 
    
    return 0;  
  }

  /*
   * Slice: adjust the time time slice on players
   */
  static const String slice_help = '''
<p><i>slice</i> function value</p>
The Slice object is used to control aspects of a player's time slice.
The first argument is the function: 'time' is the only one defined.
Following the function argument object should be a numeric value.
''';  
  
  int slice_input(CharBuffer source, Map<String,ObjectEntry> dictmap, ObjectData data, String help ) {

    num value;
    int tok, retval = 0;
    
    // create a lexer for method's use and look for help
    TokenLexer lexer = new TokenLexer( source );

    if( (tok = lexer.nexttoken()) == TokenLexer.HELP ) {
      source.addAll(help.codeUnits);  
      source.deliver();
      return 0;
    } 
    if( tok != TokenLexer.NAME ) {
      source.webcon.writeln('ERROR: expecting function. Found ${lexer.lastscanchar}');
      lexer.backup();
      return CharBuffer.ERROR;      
    }
    switch( lexer.name ) {
      case 'time': 
        tok = lexer.nexttoken();
        if( tok == TokenLexer.NUMERIC ) 
          _slicePlayer.sliceInit = lexer.value;
          source.webcon.writeln('slice time set to ${lexer.value.toString()}');
        break;
      default: 
        source.webcon.writeln('ERROR: expecting "time". Found ${lexer.name}');
        break;
    }
      
    return 0;  
  }

  //
  // called from main code to load gameboard objects after game has started
  //
  void load_engine_objects() {
    
    ObjectEntry player = new ObjectEntry('player', player_help, player_input, null, player_value);
    ObjectEntry square = new ObjectEntry('square', square_help, square_input, square_output, square_value);
    ObjectEntry warp = new ObjectEntry('warp', warp_help, warp_input, null, null);
    ObjectEntry move = new ObjectEntry('move', move_help, move_input, null, move_value);
    ObjectEntry forward = new ObjectEntry('forward', forward_help, forward_input, null, forward_value);
    ObjectEntry merge = new ObjectEntry('merge', merge_help, merge_input, null, merge_value);
    ObjectEntry proximity = new ObjectEntry('proximity', proximity_help, proximity_input, proximity_output, null);
    ObjectEntry clone = new ObjectEntry('clone', clone_help, clone_input, null, null);
    ObjectEntry game = new ObjectEntry('game', game_help, game_input, null, null);
    ObjectEntry message = new ObjectEntry('message', message_help, message_input, null, null);
    ObjectEntry narrative = new ObjectEntry('narrative', narrative_help, narrative_input, null, null);
    ObjectEntry slice = new ObjectEntry('slice', slice_help, slice_input, null, null);

    player.data     = new ObjectData();
    square.data     = new ObjectData();
    move.data       = new ObjectData();
    forward.data    = new ObjectData();
    merge.data      = new ObjectData();
    proximity.data  = new ObjectData();
    
    interpreter.objects.create(player);
    interpreter.objects.create(square);
    interpreter.objects.create(warp);
    interpreter.objects.create(move);
    interpreter.objects.create(forward);
    interpreter.objects.create(merge);
    interpreter.objects.create(proximity);
    interpreter.objects.create(clone);
    interpreter.objects.create(game);
    interpreter.objects.create(message);
    interpreter.objects.create(narrative);
    interpreter.objects.create(slice);
  }
  static Map helpindex = {
    'player':player_help,'square':square_help,'wart':warp_help,'move':move_help,'forward':forward_help,
    'merge':merge_help,'proximity':proximity_help,'clone':clone_help,'game':game_help,
    'message':message_help,'narrative':narrative_help,'slice':slice_help
    };

}
