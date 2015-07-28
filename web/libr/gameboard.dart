/**************************
  *  BoardGameOne files   *
  *  (c) John Derry 2015  *
 **************************/
part of boardgameone;

const   int BELOW = 1, ABOVE = 2, LEFT = 3, RIGHT = 4,
            FORWARD = 5, BACKWARD = 6, LEFTWARD = 7, RIGHTWARD = 8;
final   directionkeymap = { 40:BELOW, 38:ABOVE, 37:LEFT, 39:RIGHT };
// default game properties, in the cmap format
final Map DEFAULT_GAME_CMAP = {'title':'MyGame'};

/******************
 * class GPLAYER   *
 ******************/
class GPlayer {
  /*
   * Maintain information about players, including self.
   * GPlayers are intities which can move around, and one
   * player is labeled as our point-of-view, but this can change
   */
  
  static        int serialnum = 0;
  
  Map<String,ObjectEntry> properties;
  String        name, serialname, imagename;
  ImageElement  image;
  bool          POV;
  var           behavior;
  KnowBase      knowledge;
  BoardSquare   location;
  List<Item>    possessions;
  int           direction, sliceCount, sliceInit;
  
  GPlayer(this.name) {
    properties = new Map<String,ObjectEntry>();
    POV = false;
    sliceCount = sliceInit = 0;
  }
  
  GPlayer duplicate() {
    GPlayer p = new GPlayer( name );
    // create a serialized name as well
    p.serialname = '${name}${(++serialnum).toString()}';
    // copy over only properties to be found in definition map
    p.imagename = imagename;
    p.POV = POV;
    Iterable<String> keys = properties.keys;
    Iterable<ObjectEntry> values = properties.values;
    String k; ObjectEntry o;
    for( int i = 0; i < keys.length; i++) {
      k = keys.elementAt(i);
      o = values.elementAt(i);
      if( o.type == ObjectEntry.TEXT )
        p.properties[k] = o.duplicate();
      else
        p.properties[k] = o;
    }
    return p;
  }
}

/******************
 * class ITEM     *
 ******************/

class Item {
  /*
   * Maintain information about items, which can be obstacles or goodies.
   * Items are intities which are fixed and cannot move on their own,
   * although they can be allowed to be picked up, and then dropped.
   */
  static int serialnum = 0;
  
  Map<String,ObjectEntry> properties;
  String        name, serialname, imagename, description;

  Item(this.name) {
    properties = new Map<String,ObjectEntry>();
  }

  Item duplicate() {
    Item i = new Item( name );
    i.serialname = '${name}${(++serialnum).toString()}';
    i.imagename = imagename;
    i.description = description;
    i.properties.addAll(properties);
    return i;
  }
}

/**********************
 * class Possessions  *
 **********************/

class Possessions {
  MandyInterpreter  interpreter;
  Element           _possessions, _message;
  GPlayer           _povPlayer;
  TableElement      _table;
  TableRowElement   _row;
    
  Possessions(this._possessions);
  
  void clear() {
    // clear the board of leftover possessions stuff
    _possessions.text = '';
    _table = null;
    _row = null;
  }
  
  void show(GPlayer povPlayer) {
    Item it;
    _povPlayer = povPlayer;
    if( _row != null ) _row.remove();
    if( _table == null ) {
      _possessions.text = 'You possess:';
      _table = new TableElement();
      _possessions.append(_table);
      _message = new DivElement();
      _possessions.append(_message);
    }
    _row = _table.addRow();
    for( it in povPlayer.possessions ) {
      TableCellElement cell = _row.addCell();
      cell.style.padding = '4px';
      ImageElement elem = new ImageElement(src:'http://${HOSTNAME}/images/${it.imagename}.png');
      //elem.height = elem.width = imageSize;
      cell.append( elem );
      cell.onClick.listen(_click);
      cell.onMouseOver.listen(_mouseover);
    }
  }
  
  void _mouseover( Event e ) {
     TableCellElement target = e.currentTarget;
     Item it = _povPlayer.possessions[target.cellIndex];
     _message.text = 'Item ${it.name}';
   }
  
  void doItemAction(GPlayer player, Item item, String actionprop) {
    // handle the Item's action property if present
    // get the location from the player location property
    if( item.properties[actionprop] == null ) return;
    // fill in the resident field if present
    ObjectEntry obj;
    // first depth increase is like an object 
    interpreter.objects.changedepth(1); 
    interpreter.objects.dictmap = item.properties;
    // also create an object 'player' to access possessor player properties
    obj = interpreter.stdobjs.objectobject('player');
    obj.dict = player.properties;
    interpreter.objects.create(obj);
    // run the action in it's own level still
    interpreter.objects.changedepth(1);
    interpreter.action( item.properties[actionprop].data.buffer );
    interpreter.objects.changedepth(-2);
  }
  
   void _click( Event e ) {
     TableCellElement target = e.currentTarget;
     Item it = _povPlayer.possessions[target.cellIndex];
     doItemAction( _povPlayer, it, 'action');
   }
}  

/**********************
 * class BOARDSQUARE  *
 **********************/

class BoardSquare {
  
  //static final Map  DEFAULT_CMAP = {"imagename":"grey"};
  static final Map  DEFAULT_CMAP = {};

  Map<String,ObjectEntry> properties;

  GameBoard     board;  // reference to the board we are part of
  BoardSquare   left, right, above, below;
  Element       tabelem;
  ImageElement  image;
  GPlayer       resident;
  List<Item>    contents;
  String        description, classname;
  
  bool  selected = false;
  int   x, y;

  void _removeimage() {
    // remove the existing IMG node from square's table element
    int n = tabelem.childNodes.length;
    while( --n >= 0 ) {
      if( tabelem.childNodes[n].nodeName == 'IMG') {
        tabelem.childNodes[n].remove();
        break;
      }
    }
  }
  
  void updateImage( String img ) {
    // reload the image element of this square using the named image
    // after updating properties with the new image name
    CharBuffer buf = new CharBuffer(null);
    buf.addAll(img.codeUnits);
    if( properties['imagename'] == null )
      properties['imagename'] = board.engine.interpreter.stdobjs.textobject('imagename');
    properties['imagename'].data.buffer = buf;
    image = new ImageElement(src: 'http://${HOSTNAME}/images/${img}.png');
    image.height = image.width = board.imageSize;
    _removeimage();
    tabelem.append(image);
  }
  
  void leave() {
    // remove the resident from this square
    resident = null;
    // remove the resident image and return square internal image if available
    _removeimage();
    if( image != null ) tabelem.append(image);
    //board.messages.text = '';
  }

  void enter(GPlayer player) {
    // place the player in square as resident
    _removeimage();
    resident = player;
    if( player.image != null )  tabelem.append(player.image);
    if( contents != null )      board.engine.showcontents( this, contents );
  }

  void updateProp( String prop, String value ) {
    // update a property of this square's properties with a value
    // ignore the 'none' property and create the property ObjectEntry if necessary
    CharBuffer buf;
    if( prop != 'none' ) {
      buf = new CharBuffer(board.engine.interpreter.console);
      buf.allowinput = false;
      buf.addAll(value.codeUnits);
      // create the property on the fly if necessary
      if( properties[prop] == null )      
        properties[prop] = board.engine.interpreter.stdobjs.textobject(prop);
      properties[prop].data.buffer = buf;
    }
  }
  
  void select() {
    if( selected ) return;
    // select this square, used by the game editor
    tabelem.style.backgroundColor = 'red';
    selected = true;
  }
  
  void unselect() {
    if( !selected ) return;
    // unselect this square, used by the game editor
    tabelem.style.backgroundColor = 'grey';
    selected = false;
  }
  
  BoardSquare(this.board);
}

/********************
 * class GAMEBOARD  *
 ********************/

class GameBoard {
  bool          multiSelect, rangeSelect, loadEngineProps;
  GameEngine    engine;   // engine that we are part of  

  int           _board_rows, _board_cols, _selectRow, _selectCol, _selectRowCnt, _selectColCnt;  
  int           activePlayersLength; // length of _activePlayer list before chaining
  int           imageSize = 24;
  
  // these are division elements passed to us that we hang children HTML Elements on
  Element       _boardelement, _mouseover, _messages; 
  BoardSquare   _topleft,         // top left square of this board, start of linkage
                savePovLocation;  // povPlayer location when chaining from this board
  // _cellMap is the primary definition of gameboard, contains board size parameters,
  // board properties, and game square definitions (mixed map) - JSON compatible
  // _scratchMap is the cut and paste map
  Map                     _cellMap, _scratchMap = new Map();
         
  Map<String,BoardSquare> bsMap;   // map of BoardSquare objects to location id
  Map<String,String>      descMap, // location description map
                          narrMap; // location narrative path
  
  TableElement        _mainTable;
  List<BoardSquare>   _selected = new List<BoardSquare>();
  List<String>        _revIndex;
  
  Map<String,ObjectEntry> properties, altproperties;   // global board properties and alt
  Map<String,GPlayer>     players;      // source definition of players on this board
  Map<String,Item>        items;        // source definition of items on this board
  PropEditor              peditor;
  var                     loadcallback;
  String                  bclass = 'runboard';
  
  Element get messages { return _messages; }
  
  void set boardclass( String c ) { 
    bclass = c;
    if( _mainTable != null ) _mainTable.className = c;
  }

  BoardSquare _populate_board(bool newboard) {

    // populate the board with squares using _cellMap as source
    // and return the first boardsquare (top-left) to caller.
    // Create the table element and append to board element
    BoardSquare bs, firstbs, prevbs = null;
    
    _mainTable = new TableElement();
    // get the board size from _cellMap
    _board_rows = _cellMap['ROWS'];  
    _board_cols = _cellMap['COLS'];
    // get location descriptions
    descMap = _cellMap['DESCRIPTIONS'];
    narrMap = _cellMap['NARRATIVES'];
    
    if( _board_cols == null || _board_rows == null ) return null;
    for (var i = 0; i < _board_rows; i++) {
      // populate each board row, keep track of first boardsquare
      // and the first left square each previous row created,
      // to be sent to each row as they are created and also
      // to be plugged into next rows first square
      bs = _populate_row(i, _mainTable, prevbs, newboard);
      if (prevbs == null) firstbs = bs; else prevbs.below = bs;
      bs.above = prevbs;
      prevbs = bs;
    }

    // set the class name for board and append to board element passed to us
    _mainTable.className = bclass;
    _boardelement.append(_mainTable);
    return firstbs;
  }

  static Map<String,ObjectEntry> genproperties( GameEngine engine, Map cmap, bool filter ) {
    // generate a ObjectEntry map from a map with input elements in it
    // used by property editor and when creating initial gameboard properties
    String s;
    ObjectEntry e;
    Iterable<String> keys, values;
    Map<String,ObjectEntry> omap = new Map<String,ObjectEntry>();
    
    keys = cmap.keys;
    values = cmap.values;
    for( int n = 0; n < cmap.length; n++ ) {
      s = keys.elementAt(n);
      // skip special properties 
      if( s == 'DESCRIPTIONS' || (filter && (s == 'RESIDENTS' || s == 'CONTENTS' ))) continue;
      e = engine.interpreter.stdobjs.textobject( s );
      e.data.buffer = new CharBuffer(engine.interpreter.console);
      e.data.buffer.allowinput = false;
      e.data.buffer.addAll(values.elementAt(n).codeUnits);
      omap[s] = e; 
    }
    return omap;
  }
  
  BoardSquare _populate_row(int rownum, TableElement tab, BoardSquare rowabove, bool newboard) {
    // populate a single row of game squares for boardsquare.
    //
    TableRowElement tRow = tab.addRow();
    BoardSquare bs, firstbs, prevbs = null;
    Map cmap; String name; List<String> list;
    String desc; int indx;
    
    for (int colnum = 0; colnum < _board_cols; colnum++) {
      // create the boardsquare instance and set its row and col number,
      // enter it into bsMap which we will use later to look up clicks events
      bs = new BoardSquare(this);
      bs.x = rownum; bs.y = colnum;
       bsMap['${rownum}x${colnum}'] = bs;
      
      // look up the square in the cell map loaded from board definition
      // unless this is a new board, then don't bother but use default
      if( newboard ) 
        cmap = _cellMap['${rownum}x${colnum}'] = BoardSquare.DEFAULT_CMAP;
      else  
        cmap = _cellMap['${rownum}x${colnum}'];
      // load any resident or contents to this cell by 
      // duplicating the object from source definition maps
      // and then remove it from the cellmap so it's not a property
      if( (name = cmap['RESIDENT']) != null ) {        
        bs.resident = players[name].duplicate();
        cmap.remove('RESIDENT');
      }
      if( (list = cmap['CONTENTS']) != null ) {
        bs.contents = new List<Item>();
        for( name in list ) 
          bs.contents.add( items[name].duplicate());
        cmap.remove('CONTENTS');
      }
      // fetch the image index and convert it
      if( (indx = cmap['_II']) != null ) {
        cmap['imagename'] = _revIndex[indx];
        cmap.remove('_II');
      }
      // generate the board square properties and create table cell element
      bs.properties = genproperties( engine, cmap, true );
      bs.tabelem = tRow.addCell();
      // assign an id, this is used to look up the BoardSquare object later
      bs.tabelem.id = '${rownum}x${colnum}';
      // set the above reference to square directly above us
      bs.above = rowabove;
      if (rowabove != null) {
        // if boardsquare above exists, set it's down reference
        rowabove.below = bs;
        // move to the next square to the right
        rowabove = rowabove.right;
      }
      // check for first entry in row, if so set firstbs
      if (prevbs == null) firstbs = bs; 
      else 
        // set the square right reference, in previous square, to us
        prevbs.right = bs;
      bs.left = prevbs; // set our reference to square left
      prevbs = bs;      // update previous reference
      // using the index and image name index find the name
      // using image name in properties if available, create an image element
      if( bs.properties['imagename'] != null) {
        String imagename = bs.properties['imagename'].data.buffer.string;
        bs.image = new ImageElement(src:
            'http://${HOSTNAME}/images/${imagename}.png');
            
        // append image element to table element and set click listener
        bs.image.height = bs.image.width = imageSize;
      } else {
        bs.image = new ImageElement(src:
            'http://${HOSTNAME}/images/landscape/grey.png');
        // append image element to table element and set click listener
        bs.image.height = bs.image.width = imageSize;
      }
      bs.tabelem.append(bs.image); 
      bs.tabelem.onClick.listen(_click);
      bs.tabelem.onMouseOver.listen(_mouseover_handler);
      // make some direct properties of boardsquare
      // like description and class if available
      if( (desc = cmap['desc']) != null )
        bs.description = desc;
      if( (desc = cmap['class']) != null )
        bs.classname = desc;
    }
    return firstbs; // return the first square in this new row
  }

  void _mouseover_handler( Event e ) {
    Element target = e.currentTarget;
    // on click, look up target's id in bsMap to get boardsquare object
    BoardSquare bs = bsMap[target.id];  
    assert( bs != null );

    if( engine.running ) {
      String desc;
       // put up the description property
      if( bs.description != null ) {
        if( descMap != null && (desc = descMap[bs.description]) != null )
          _mouseover.text = desc;
        else _mouseover.text = bs.description;
        if( narrMap != null && (desc = narrMap[bs.description]) != null )
          engine.narrativeName = desc;
        else engine.narrativeName = null;
      }
      else { 
        _mouseover.text = ''; 
        engine.narrativeName = null;
      }
      return;
    }
 
    StringBuffer buf = new StringBuffer();
    buf.write('Loc:${bs.x.toString()},${bs.y.toString()}');
    if( bs.resident != null ) 
      buf.write( ' Resident: ${bs.resident.name}' );
    if( bs.contents != null ) {
      buf.write(' Contents: ');
      for( Item i in bs.contents )
        buf.write( '${i.name}, ' );
    }      
    _mouseover.text = buf.toString();  
  }
 
  static const HIGHVAL = 32000;
  void _selectbetween( BoardSquare A, BoardSquare B ) {
    // determine the range of squares to select 
    // by examining limits of squares A & B
    int lowX=HIGHVAL, lowY=HIGHVAL, hiX=0, hiY=0;
    if( A.x < lowX ) lowX = A.x;
    if( A.x > hiX  ) hiX = A.x;
    if( A.y < lowY ) lowY = A.y;
    if( A.y > hiY  ) hiY = A.y;
    if( B.x < lowX ) lowX = B.x;
    if( B.x > hiX  ) hiX = B.x;
    if( B.y < lowY ) lowY = B.y;
    if( B.y > hiY  ) hiY = B.y;
    // now select these cells between after clearing list
    _selected = new List<BoardSquare>();
    BoardSquare rowstart, bs;
    rowstart = bsMap['${lowX}x${lowY}'];
    assert( rowstart != null );
    while( rowstart != null && rowstart.x <= hiX ) {
      bs = rowstart;
      while( bs != null && bs.y <= hiY ) {
        bs.select();
        _selected.add(bs);
        bs = bs.right;
      }
      rowstart = rowstart.below;
    }
    _selectRow = lowX; _selectCol = lowY;
    _selectRowCnt = hiX - lowX + 1;
    _selectColCnt = hiY - lowY + 1;
  }
  
  void _click( Event e ) {
    int dir, dx, dy;
    Element target = e.currentTarget;
    GPlayer povp = engine.povPlayer;
    // on click, look up target's id in bsMap to get boardsquare object
    BoardSquare bs = bsMap[target.id];  
    assert( bs != null );
    
    if( engine.running ) {
      // if game running, simulate arrow keys if we clicked adjacent square
      if( povp == null )  return; 
      // determine direction quadrant
      if( bs.x < povp.location.x ) {
        dx = povp.location.x - bs.x;
        if( bs.y < povp.location.y ) {
          dy = povp.location.y - bs.y;
          if( dx < dy ) dir = LEFT;
          else dir = ABOVE;
        } else {
          dy = bs.y - povp.location.y;
           if( dx < dy ) dir = RIGHT;
           else dir = ABOVE;
        }
      } else {
        dx = bs.x - povp.location.x;
        if( bs.y < povp.location.y ) {
          dy = povp.location.y - bs.y;
          if( dx < dy ) dir = LEFT;
          else dir = BELOW;
        } else {
          dy = bs.y - povp.location.y;
           if( dx < dy ) dir = RIGHT;
           else dir = BELOW;
        }
        
      }
      engine.move( dir, false, null, povp );
      return;
    }    
    // not running, select the cell. First look for cell already selected
    if( bs.selected ) {
      // process double click by calling properties editor if available
      if( peditor != null ) peditor.edit( bs.properties );
      //bs.selected = false;
      return;
    }
    // handle range select separately
    if( rangeSelect ) {
      if( _selected.length > 1 ) {
        // unselected any selected squares
        _selected.forEach( (square) => square.unselect() );
        // clear select list
        _selected = new List<BoardSquare>();
        // then select this square only
        bs.select();
        _selected.add(bs);    
        _selectRow = bs.x;
        _selectCol = bs.y;
        _selectRowCnt = _selectColCnt = 1;
      } else if( _selected.length == 1 )
        // select all squares between selected and new one
        _selectbetween( _selected[0], bs );
      else {
        // select this square by calling square's method and add to list
        bs.select();
        _selected.add(bs);    
        _selectRow = bs.x;
        _selectCol = bs.y;
        _selectRowCnt = _selectColCnt = 1;
      }        
      return;
    }
    // handling multiselect or individual selection
    if( !multiSelect && _selected.length > 0 ) {
      // unselected any selected squares
      _selected.forEach( (square) => square.unselect() );
      // clear select list
      _selected = new List<BoardSquare>();
    }
    // select this square by calling square's method and add to list
    bs.select();
    _selected.add(bs);    
    _selectRow = bs.x;
    _selectCol = bs.y;
    _selectRowCnt = _selectColCnt = 1;
  }

  void _handleError(Error e) {
    _messages.text = 'map load failure: ${e.toString()}';
  }
  
  void clearScratch() {
    _scratchMap = new Map();
  }
  
  void copyBoard() {
    // copy the board data alone to scratch area
    _scratchMap['ROWS'] = _selectRowCnt;
    _scratchMap['COLS'] = _selectColCnt;
    int row, urow = 0;
    for( row = _selectRow; row < _selectRow + _selectRowCnt; row++ )
      _copy_row( row, _selectCol, _selectCol + _selectColCnt, urow++ );      
  }
  
  void _copy_row(int rownum, int startcol, int endcol, int urow ) {
    int ucol = 0;
    BoardSquare bs;
    Map cmap;
    for (int colnum = startcol; colnum < endcol; colnum++) {
      bs = bsMap['${rownum}x${colnum}'];
      cmap = gencmap( bs.properties );
      _scratchMap['${urow}x${ucol}'] = cmap;
      ucol++;
    }
  }
  
  void pasteBoard() {
    // replace the current board squares with squares from scratch area
    // paste the new squares using the select square as top left
    int numrows = _scratchMap['ROWS'];  
    int numcols = _scratchMap['COLS'];
    int row, urow = 0;
    for( row = _selectRow; row < _selectRow + numrows; row++ )
      _paste_row( row, _selectCol, _selectCol + numcols, urow++ );      
  }
  
  void _paste_row(int rownum, int startcol, int endcol, int urow ) {
    int ucol = 0;
    BoardSquare bs;
    Map cmap;
    for (int colnum = startcol; colnum < endcol; colnum++) {
      bs =  bsMap['${rownum}x${colnum}'];
      cmap = _scratchMap['${urow}x${ucol}'];
      ucol++;
      // update the board square properties from new map
      bs.properties = genproperties( engine, cmap, true );
      if( bs.tabelem.firstChild != null ) bs.tabelem.firstChild.remove();
      if( bs.properties['imagename'] != null) {
         String imagename = bs.properties['imagename'].data.buffer.string;
         bs.image = new ImageElement(src:
             'http://${HOSTNAME}/images/${imagename}.png');
         // append image element to table element and set click listener
         bs.image.height = bs.image.width = imageSize;
       } else {
         bs.image = new ImageElement(src:
             'http://${HOSTNAME}/images/landscape/grey.png');
         // append image element to table element and set click listener
         bs.image.height = bs.image.width = imageSize;
       }
       bs.tabelem.append(bs.image);
    }
  }
  
  void copyPlayers() {
    // copy the current player data to scratch area
    //
    // generate JSON maps for players while at the same time
    // create a list of the player names
    int n; Map m; String nam; 
    Iterable<String> names = players.keys;
    Iterable<GPlayer> pobjects = players.values;
    List<String> playerlist = new List<String>();
    //_scratchMap = new Map();
    for( n = 0; n < players.length; n++ ) {
      // gen a map from player properties and update _cellMap
      m = gencmap( pobjects.elementAt(n).properties );
      _scratchMap[(nam = names.elementAt(n))] = m;
      playerlist.add(nam);
    }        
    // update the player list in _cellMap
    List l = _scratchMap['PLAYERS'];
    if( l != null ) playerlist.addAll(l);
    _scratchMap['PLAYERS']= playerlist;
  }
  
  void pastePlayers() {
    // load the player data from scratch area
    //
    // fetch the player lists from the _cellmap
    // and create the players map
    players = new Map<String,GPlayer>();
    List<String> names = _scratchMap['PLAYERS'];
    String nam; GPlayer pobject; Item iobject; ObjectEntry e;
    if( names != null ) {
      for( nam in names ) {
        pobject = new GPlayer(nam);
        pobject.properties = genproperties( engine, _scratchMap[nam], false );
        if( (e = pobject.properties['imagename']) != null )
          pobject.imagename = e.data.buffer.string;
        players[nam] = pobject;
      }
    }
  }
  
  void copyItems() {
    // copy the Item data to scratch area
    //
    // generate JSON maps for items while at the same time
    // create a list of Item names 
    int n; Map m; String nam; 
    Iterable<String> names = items.keys;
    Iterable<Item> iobjects = items.values;
    List<String> itemlist = new List<String>();
    for( n = 0; n < items.length; n++ ) {
      // gen a map from item properties and update _cellMap
      m = gencmap( iobjects.elementAt(n).properties );
      _scratchMap[(nam = names.elementAt(n))] = m;
      itemlist.add(nam);
    }
    // update the player and item list in _cellMap
    itemlist.addAll(_scratchMap['ITEMS']);
    _scratchMap['ITEMS'] = itemlist;
  }
  
  void pasteItems() {
    // load the Item data from scratch area
    //
    // fetch the players and items lists from the _cellmap
    // and create the Items map
    items = new Map<String,Item>();
    String nam; Item iobject; ObjectEntry e;
    List<String> names = _scratchMap['ITEMS'];    
    if( names != null ) {
      for( nam in names ) {
        iobject = new Item(nam);
        iobject.properties = genproperties( engine, _scratchMap[nam], false );
        if( (e = iobject.properties['imagename']) != null )
          iobject.imagename = e.data.buffer.string;
        if( (e = iobject.properties['desc']) != null ) {
          iobject.description = e.data.buffer.string;
        } //else iobject.description = 'none';
        items[nam] = iobject;
      }
    }    
  }
  
  /*
   * constructor and associated methods
   */
  GameBoard(this.engine, this._boardelement, this._mouseover, this._messages) {
    multiSelect = rangeSelect = false;
    loadEngineProps = true;
    _board_rows = _board_cols = _selectRow = _selectCol = _selectRowCnt = _selectColCnt = 0;  
  }
  
  void adjust(int r, int c) {
    // adjust row or column of board  
    BoardSquare bs, newbs, prevbs, abovebs;
    int n, row = 0, lastcol = 0, col;
    Map cmap; TableRowElement tRow;
    if( _topleft == null ) return;
    if( c > 0 ) {
      bs = _topleft;
      // locate the last column present
      while( bs.right != null ) {
        bs = bs.right;
        lastcol++;
      }
      // work down this column, add more cells
      abovebs = null;
      while( bs != null ) {
        // for each existing row
        n = 0;
        prevbs = bs;
        tRow = bs.tabelem.parent;
        while( n < c ) {
          // add new columns
          newbs = new BoardSquare(this);
          newbs.x = row; newbs.y = col = lastcol + ++n;
          newbs.above = abovebs;
          if( abovebs != null ) abovebs.below = newbs;
          newbs.left = prevbs;
          prevbs.right = newbs;
          prevbs = newbs;
          if( abovebs != null ) abovebs = abovebs.right;
          bsMap['${row}x${col}'] = newbs;
          cmap = _cellMap['${row}x${col}'] = BoardSquare.DEFAULT_CMAP;
          // generate the board square properties and create table cell element
          newbs.properties = genproperties( engine, cmap, true );
          newbs.tabelem = tRow.addCell();
          // assign an id, this is used to look up the BoardSquare object later
          newbs.tabelem.id = '${row}x${col}';
          newbs.image = new ImageElement(src:
              'http://${HOSTNAME}/images/landscape/grey.png');
          // append image element to table element and set click listener
          newbs.image.height = bs.image.width = imageSize;
          newbs.tabelem.append(newbs.image); 
          newbs.tabelem.onClick.listen(_click);
          newbs.tabelem.onMouseOver.listen(_mouseover_handler);
        }
        row++;
        abovebs = bs.right;
        bs = bs.below;
      }
      _board_cols += c;
      _cellMap['COLS'] = _board_cols;
    }
    if( r > 0 ) {
      // add a new row of squares to board
      prevbs = _topleft;
      while( prevbs.below != null )
        prevbs = prevbs.below;
      while( r-- > 0 ) {
        bs = _populate_row(_board_rows++, _mainTable, prevbs, true);
        prevbs.below = bs;
        bs.above = prevbs;
        prevbs = bs;        
      }
      _cellMap['ROWS'] = _board_rows;
    }
  }
 
  void restore() {
    // restore existing _mainTable to boardelement after returning to this board
    if( _mainTable != null ) _boardelement.append(_mainTable);
  }
  
  void remove() {
    // remove this board's table child from boardelement 
    if( _mainTable != null ) _mainTable.remove();
  }
 
  void clearselected() {    
    // clear any selected cells left over from editing
    if( _selected.length > 0 ) 
      _selected.forEach( (square) => square.unselect() );
  }
  /*
   * methods for loading and saving game board aspects to JSON files
   */

  int formaterror(String s) {
    _messages.text = 'number format error in "${s}"';
    return 0;
  }
  
  GameBoard create(String rows, String cols) {
    // create a new, default empty gameboard
    int numrows = int.parse(rows, onError: formaterror);
    int numcols = int.parse(cols, onError: formaterror);
    if( numrows == 0 || numcols == 0 ) return this;
 
    remove();   // remove any previous table child in boardelement

    players = new Map<String,GPlayer>();
    items = new Map<String,Item>();
    _cellMap = new Map();
    _cellMap['ROWS'] = numrows;
    _cellMap['COLS'] = numcols;
    bsMap = new Map();
    _topleft = _populate_board(true);
    
    return this;
  }
  
  GameBoard loadMap(String map) {
    if( engine.uselocal )
      // use the text in maparea for source of JSON definition
      _load_board( engine.maparea.value );
    else
      // request fetching of JSON definition file from server
      // then load board from data when available
      HttpRequest.getString('http://${HOSTNAME}/data/${map}.json')
        .then(_load_board).catchError(_handleError);
    return this;
  }

  void _load_board(String jstr) {
    remove();   // remove any previous table of ours
    // decode the JSON encoded cell map for entire board
    _cellMap = JSON.decode(jstr);
    
    // fetch the players and items lists from the _cellmap
    // and create the players and items maps
    players = new Map<String,GPlayer>();
    List<String> names = _cellMap['PLAYERS'];
    String nam; GPlayer pobject; Item iobject; ObjectEntry e;
    if( names != null ) {
      for( nam in names ) {
        pobject = new GPlayer(nam);
        pobject.properties = genproperties( engine, _cellMap[nam], false );
        // create a direct property for imagename
        if( (e = pobject.properties['imagename']) != null )
          pobject.imagename = e.data.buffer.string;
        players[nam] = pobject;
      }
    }
    // now the same for items
    items = new Map<String,Item>();
    names = _cellMap['ITEMS'];    
    if( names != null ) {
      for( nam in names ) {
        iobject = new Item(nam);
        iobject.properties = genproperties( engine, _cellMap[nam], false );
        // create a direct property for imagename and desc
        if( (e = iobject.properties['imagename']) != null )
          iobject.imagename = e.data.buffer.string;
        if( (e = iobject.properties['desc']) != null ) {
          iobject.description = e.data.buffer.string;
        } //else iobject.description = 'none';
        items[nam] = iobject;
      }
    }
    // load the image index array as it is
    _revIndex = _cellMap['IMAGES'];
    // and then remove it from the _cellMap. We only need this to load the board
    _cellMap.remove('IMAGES');
    // create a blank bsMap
    bsMap = new Map();
    // populate the gameboard with squares based on _cellMap details
    _topleft = _populate_board(false);
    Map prop;
    // if present and called for, get the engine properties from the cellmap property entry
    if( (prop = _cellMap['properties']) != null ) {
      if( loadEngineProps ) properties = genproperties( engine, prop, false );
      else                  altproperties = genproperties( engine, prop, false );
    }
    // look for runlibrary specified
    ObjectEntry runlibrary;
    if( properties != null && (runlibrary = properties['library']) != null )
      HttpRequest.getString('http://${HOSTNAME}/data/libraries/${runlibrary.data.buffer.string}')
        .then(_load_library).catchError(_handleError);
    else {
      // now call the board loaded callback if present, and leave message
      if( loadcallback != null ) loadcallback();
      messages.text = 'board map load success';
    }
  }

  void _load_library(String lstr) {
    engine.runlibrary = new CharBuffer(engine.interpreter.console);
    engine.runlibrary.addAll(lstr.codeUnits);
    if( loadcallback != null ) loadcallback();
    messages.text = 'board map load success';
  }
  
  static Map gencmap( Map<String,ObjectEntry> omap ) {
    // generate a property-value map required for editing and saving 
    // from an property-ObjectEntry map which is used otherwise
    // Process Text Objects only - skip other kinds
    int n; String  s;
    Map cmap = new Map();
    ObjectEntry           obj;
    Iterable<String>      keys;
    Iterable<ObjectEntry> objects;
    keys = omap.keys;
    objects = omap.values;
    for( n = 0; n < omap.length; n++ ) {
      obj = objects.elementAt(n);
      if( obj.type != ObjectEntry.TEXT ) continue;
      s = keys.elementAt(n);
      cmap[s] = obj.data.buffer.string; 
    }
    return cmap;
  }
  
  GameBoard saveMap(String map) {
    // save the board game to the server with a Html POST request
    int n; Map m; String nam; BoardSquare bs;
    Map<String,int> imgnammap = new Map();
    int             imgnamidx = 0;
    List<String>    revIndex = new List();
    Iterable<String> names;
    HttpRequest req;
    if( !engine.uselocal ) {
      req = new HttpRequest();
      req.onReadyStateChange.listen((ProgressEvent e) {
        if (req.readyState == HttpRequest.DONE &&
            (req.status == 200 || req.status == 0))
          _messages.text = '${_messages.text} board map post success';
        else 
          _messages.text = '${_messages.text} board map post failure: ${e.toString()}';
      });
    }
    // generate the engine properties and put in _cellMap 
    _cellMap['properties'] = gencmap( properties );
    // generate JSON maps for players and items while at the same time
    // create a list of the names for each
    names = players.keys;
    Iterable<GPlayer> pobjects = players.values;
    List<String> playerlist = new List<String>();
    for( n = 0; n < players.length; n++ ) {
      // gen a map from player properties and update _cellMap
      m = gencmap( pobjects.elementAt(n).properties );
      _cellMap[(nam = names.elementAt(n))] = m;
      playerlist.add(nam);
    }        
    names = items.keys;
    Iterable<Item> iobjects = items.values;
    List<String> itemlist = new List<String>();
    for( n = 0; n < items.length; n++ ) {
      // gen a map from item properties and update _cellMap
      m = gencmap( iobjects.elementAt(n).properties );
      _cellMap[(nam = names.elementAt(n))] = m;
      itemlist.add(nam);
    }
    // update the player and item list in _cellMap
    _cellMap['PLAYERS']= playerlist;
    _cellMap['ITEMS'] = itemlist;
    // process the keys and values in bsMap in parallel
    // to update the _cellMap entry for each board square
    // with current values from the boardsquare's properties map 
    names  = bsMap.keys;
    String s; int indx;
    Iterable<BoardSquare> sqrobjects  = bsMap.values;
    for( n = 0; n < bsMap.length; n++ ) {
      // gen a map from square's properties
      m = gencmap( (bs = sqrobjects.elementAt(n)).properties );
      // convert image name to index
      if( (s = m['imagename']) != null ) {
        indx = imgnammap[s];
        if( indx == null ) {
          indx = imgnammap[s] = imgnamidx++;
          revIndex.add(s);
        }
        m['_II'] = indx; 
        m.remove('imagename');        
      }
      // add entries for any resident and contents
      if( bs.resident != null ) m['RESIDENT'] = bs.resident.name;
      if( bs.contents != null ) {
        Item i; itemlist = new List<String>();
        for( i in bs.contents ) itemlist.add( i.name );
        m['CONTENTS'] = itemlist;
      }      
      _cellMap[names.elementAt(n)] = m;
    }
    
    if( imgnammap.length > 0 ) _cellMap['IMAGES'] = revIndex;
    if( engine.uselocal )
      engine.maparea.value = JSON.encode(_cellMap);
    else {
      // open up the http channel and send an JSON encoded _cellMap using map name
      req.open('POST', 'http://${HOSTNAME}/data/${map}.json', async:false);
      String  sendstr = JSON.encode(_cellMap);
      messages.text = "sendstr length = ${sendstr.length}";
      req.send( sendstr);
    }
    return this;
  }

  void loadScratch(String map) {
    if( engine.uselocal )
      // use the text in scratch map for source of JSON definition
      _load_scratch( engine.maparea.value );
    else
      // request fetching of JSON definition file from server
      // then load board from data when available
      HttpRequest.getString('http://${HOSTNAME}/data/${map}.json')
        .then(_load_scratch).catchError(_handleError);
  }

  void _load_scratch(String jstr) {
    // decode the JSON encoded scratch map 
    _scratchMap = JSON.decode(jstr);
    messages.text = 'scratch map load success';
  }
  
  void saveScratch(String map) {
    HttpRequest req;
    if( !engine.uselocal ) {
      req = new HttpRequest();
      req.onReadyStateChange.listen((ProgressEvent e) {
        if (req.readyState == HttpRequest.DONE &&
            (req.status == 200 || req.status == 0))
          _messages.text = 'scratch map post success';
        else 
          _messages.text = 'scratch map post failure: ${e.toString()}';
      });
    }
    if( engine.uselocal )
      engine.maparea.value = JSON.encode(_scratchMap);
    else {
      // open up the http channel and send an JSON encoded _cellMap using map name
      req.open('POST', 'http://${HOSTNAME}/data/${map}.json', async:false);
      req.send( JSON.encode(_scratchMap));
    }
   
  }  
  /* 
   * methods for interacting with the board
   * the first set pertain to editing the gameboard
   */
  void updateSelectedImage( String image ) {
    // update the image for all selected squares
    if( _selected.length > 0 )
      _selected.forEach((square) => square.updateImage(image));
  }
  
  void updateSelectedProperty( String prop, String value ) {
    // change a single property for all selected squares
    if( _selected.length > 0 )
      _selected.forEach((square) => square.updateProp(prop, value));
  }
  
  void placeSelectedGPlayer(String playername) {
    // place this player on all selected squares
    BoardSquare sqr;
    GPlayer p = players[playername];
    assert( p != null );
    if( _selected.length > 0 )
      for( sqr in _selected )
        sqr.resident = p;
  }
  
  void placeSelectedItem(String itemname) {
    // place this item on all selected squares
    BoardSquare sqr;
    Item i = items[itemname];
    assert( i != null );
    if( _selected.length > 0 )
      for( sqr in _selected ) {
        if( sqr.contents == null )
          sqr.contents = new List<Item>();
        sqr.contents.add(i);
      }
    }
  
  void dropGPlayer() {
    BoardSquare sqr;
    if( _selected.length > 0 )
      for( sqr in _selected )
        sqr.resident = null;
  }
  
  void dropItem() {
    BoardSquare sqr;
    if( _selected.length > 0 )
      for( sqr in _selected )
        sqr.contents = null;    
  }
}
