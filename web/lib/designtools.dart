/**************************
  *  BoardGameOne files   *
  *  (c) John Derry 2015  *
 **************************/
library designtools;

import 'dart:html';
import 'dart:convert';
import 'bufferedhtmlio.dart';
import 'interpreter.dart';
import 'gameboard.dart';
import 'gameengine.dart';

class ToolBox {
  /*
   * GameBoard Editor
   * Handle all functions (except creating, loading saving boards)
   * related to midifying game board. Create instance of propery editor.
   */
  static const IMAGEROWCNT = 38;

  ButtonElement     updateProp, boardProps, dropPlayer, dropItem, copyBoard, pasteBoard,
    playerCreate, playerDelete, playerEdit, playerPlace, 
    itemCreate, itemDelete, itemEdit, itemPlace, copyPlayers, pastePlayers, copyItems, pasteItems, 
    reloadImages, clearScratch;
  TextInputElement  mapName, rowsNum, colsNum, propValue, playerName, itemName, imageRowCnt;
  CheckboxInputElement rangeCB, multiCB;
  SelectElement     propSelect, playerSelect, itemSelect, imageDirSelect;

  GameEngine      engine;
  Element         toolbox, _messages;
  TableElement    _table;
  TableRowElement _tRow;
  List<String>    _imageList, _imageDirList;
  int             _imagerowcnt, _rowcnt;
  
  PropEditor    peditor;
  
  ToolBox(this.engine, this.toolbox, this._messages ) {

    peditor = new PropEditor( querySelector("#propedit"), _messages );
    
    // associate the peditor with gameboard so that
    // square properties can be edit by the second click  
    peditor.engine = engine;
    engine.board.peditor = peditor;

    // get access to HTML elements on editor page
    multiCB = querySelector("#multi");
    rangeCB = querySelector("#range");
    updateProp = querySelector("#updateProp");
    boardProps = querySelector("#boardProps");
    dropPlayer = querySelector("#dropPlayer");
    dropItem = querySelector("#dropItem");
    copyBoard = querySelector("#copyBoard");
    pasteBoard = querySelector("#pasteBoard");
    playerEdit = querySelector("#playerEdit");
    playerCreate = querySelector("#playerCreate");
    playerDelete = querySelector("#playerDelete");
    playerPlace = querySelector("#playerPlace");
    itemEdit = querySelector("#itemEdit");
    itemCreate = querySelector("#itemCreate");
    itemDelete = querySelector("#itemDelete");
    itemPlace = querySelector("#itemPlace");
    copyPlayers = querySelector("#copyPlayers");
    pastePlayers = querySelector("#pastePlayers");
    copyItems = querySelector("#copyItems");
    pasteItems = querySelector("#pasteItems");

    propValue = querySelector("#propValue");
    propSelect = querySelector("#propSelect");
    playerSelect = querySelector("#playerSelect");
    playerName = querySelector("#playerName");
    itemSelect = querySelector("#itemSelect");
    itemName = querySelector("#itemName");
    imageRowCnt = querySelector("#imageRowCnt");
    reloadImages = querySelector("#reloadImages");
    imageDirSelect = querySelector("#imageDir");

    multiCB.onClick.listen(buttonpress);
    rangeCB.onClick.listen(buttonpress);
    updateProp.onClick.listen(buttonpress);
    boardProps.onClick.listen(buttonpress);
    dropPlayer.onClick.listen(buttonpress);
    copyBoard.onClick.listen(buttonpress);
    pasteBoard.onClick.listen(buttonpress);
    dropItem.onClick.listen(buttonpress);
    playerCreate.onClick.listen(buttonpress);
    playerDelete.onClick.listen(buttonpress);
    playerEdit.onClick.listen(buttonpress);
    playerPlace.onClick.listen(buttonpress);
    itemCreate.onClick.listen(buttonpress);
    itemDelete.onClick.listen(buttonpress);
    itemEdit.onClick.listen(buttonpress);
    itemPlace.onClick.listen(buttonpress);
    copyPlayers.onClick.listen(buttonpress);
    pastePlayers.onClick.listen(buttonpress);
    copyItems.onClick.listen(buttonpress);
    pasteItems.onClick.listen(buttonpress);
    reloadImages.onClick.listen(buttonpress);
    
    // create table to load available images
    _table = new TableElement();
    // _table.attributes['border'] = '1';
    _tRow = _table.addRow();
    
    // establish rowcnt from text area or default
    _rowcnt = int.parse( imageRowCnt.value, onError: formaterror);
	
    // request loading of JSON file 'images' from server 
    // and stuff the image directory list in imageDir select
    HttpRequest.getString('http://${HOSTNAME}/data/images.json')
      .then(_load_index).catchError(_handleError);
  }
  
  int formaterror(String s) {
    _messages.text = 'number format error in "${s}"';
    return 0;
  }

  void _load_index(String jstr) {
    if( jstr == null || (_imageDirList = JSON.decode(jstr)) == null ) {
      _messages.text = '${_messages.text}Image Index Failure: no images.json found<br>';
      return;
    }
    String name; OptionElement option;
    for( name in _imageDirList ) {
      option = new OptionElement();
      option.value = option.text = name;
      imageDirSelect.append(option);
    }
  }

  void _load_dir_index(String jstr) {
    if( jstr == null || (_imageList = JSON.decode(jstr)) == null ) {
      _messages.text = '${_messages.text}Image Directory Index Failure';
      return;
    }
    // fetch each each image referenced
    _imagerowcnt = 0;
    _imageList.forEach((image)=>_addImageCell(image));
    toolbox.append(_table);
  }

  void _addImageCell(String image) {
    // create an ImageElement for each image referenced
    // and append to a cell of the table, create onClick listener

    ImageElement imageElement = new ImageElement(src:
        'http://${HOSTNAME}/images/${image}.png' );
    if( _imagerowcnt > _rowcnt ) {
      _tRow = _table.addRow();
      _imagerowcnt = 0;
    }
    Element cell = _tRow.addCell();
    _imagerowcnt++;
    cell.id = image;
    cell.style.padding = '2px';
    cell.append(imageElement);
    cell.onClick.listen(_click);
    cell.onMouseOver.listen(_mouseover);
  }
 
  void _mouseover( Event e ) {
    if( engine.running ) return;
    Element target = e.currentTarget;
    _messages.text = 'Image: ${target.id}';  
  }
  
  void _click( Event e ) {
    // when the image in toolbox is clicked, use image's id which is the image name
    // to update the selected square in the gameboard with this image
    Element target = e.currentTarget;
    engine.board.updateSelectedImage(target.id);    
  }
  
  void _handleError(Error e) {
    // generalized error message
    _messages.text = '${_messages.text}designtools:${e.toString()}';
  }
  
  void addGPlayerOption(String name) {
    OptionElement option = new OptionElement();
    option.value = option.text = name;
    playerSelect.append(option);
  }
  
  void delGPlayerOption(String name) {
    List children = playerSelect.children;
    for( Element e in children ) {
      if( e.text == name ) {
        e.remove();
        break;
      }
    }
  }
  
  void addItemOption(String name) {
    OptionElement option = new OptionElement();
    option.value = option.text = name;
    itemSelect.append(option);
  }
  
  void delItemOption(String name) {
    List children = itemSelect.children;
    for( Element e in children ) {
      if( e.text == name ) {
        e.remove();
        break;
      }
    }
  }
  
  void buttonpress(Event e) {

    if( e.currentTarget == clearScratch ) 
      engine.board.clearScratch();
    else if( e.currentTarget == reloadImages ) {
      // create fresh table to load available images
      _table.remove();
      _table = new TableElement();
      // _table.attributes['border'] = '1';
      _tRow = _table.addRow();
      // establish rowcnt from text area or default
      _rowcnt = int.parse( imageRowCnt.value, onError: formaterror);
      // load the images again with new rowcnt
      String imagedir;
      if( imageDirSelect.selectedIndex >= 0 ) {
        imagedir = _imageDirList[imageDirSelect.selectedIndex];
	      HttpRequest.getString('http://${HOSTNAME}/data/${imagedir}.json')
          .then(_load_dir_index).catchError(_handleError);
      }
    }
    else if( e.currentTarget == boardProps ) {
      peditor.edit(engine.board.properties);
    }
    else if( e.currentTarget == multiCB ) {
      if( multiCB.checked ) engine.board.multiSelect = true;
      else                  engine.board.multiSelect = false;
    }
    else if( e.currentTarget == rangeCB ) {
      if( rangeCB.checked ) engine.board.rangeSelect = true;
      else                  engine.board.rangeSelect = false;
    }
    else if( e.currentTarget == updateProp ) 
        engine.board.updateSelectedProperty(propSelect.value, propValue.value);      
    else if( e.currentTarget == dropPlayer )
        engine.board.dropGPlayer();
    else if( e.currentTarget == dropItem )
        engine.board.dropItem();  
    else if( e.currentTarget == copyBoard )
        engine.board.copyBoard();  
    else if( e.currentTarget == pasteBoard )
        engine.board.pasteBoard();  
    else if( e.currentTarget == playerEdit ) {
      if ( playerSelect.selectedIndex >= 0 ) 
        peditor.edit( engine.board.players[playerSelect.value].properties );
    }  
    else if( e.currentTarget == playerCreate ) {
      
      if( engine.board.players != null && playerName.value.length > 0 ) 
        if( engine.board.players[playerName.value] != null) 
          _messages.text = 'GPlayer name already exists';
        else if( engine.board.items[playerName.value] != null) 
          _messages.text = 'Can\'t have a GPlayer named same as an existing Item';
        else {
          // Create a new player. Create class instance,
          // create select option, load engine.board.players with instance
          GPlayer player = new GPlayer(playerName.value);
          engine.board.players[playerName.value]= player;
          addGPlayerOption(playerName.value);
        }
    }
    else if( e.currentTarget == playerDelete ) {
      GPlayer player;
      if( engine.board.players != null &&
          (player = engine.board.players[playerSelect.value]) != null ) {
        engine.board.players.remove(playerSelect.value);        
        delGPlayerOption(playerSelect.value);
      }
    }    
    else if( e.currentTarget == playerPlace ) {
      engine.board.placeSelectedGPlayer(playerSelect.value);
    }
    else if( e.currentTarget == itemEdit ) {
      if ( itemSelect.selectedIndex >= 0 ) 
        peditor.edit( engine.board.items[itemSelect.value].properties );
    }  
    else if( e.currentTarget == itemCreate ) {
      
      if( engine.board.items != null && itemName.value.length > 0 ) 
        if( engine.board.items[itemName.value] != null) 
          _messages.text = 'Item name already exists';
        else if( engine.board.players[itemName.value] != null) 
          _messages.text = 'Can\'t have an Item named same as an existing Player';
        else {
          // Create a new item. Create class instance,
          // create select option, load engine.board.items with instance
          Item item = new Item(itemName.value);
          engine.board.items[itemName.value]= item;
          addItemOption(itemName.value);
        }
    }
    else if( e.currentTarget == itemDelete ) {
      Item item;
      if( engine.board.items != null &&
          (item = engine.board.items[itemSelect.value]) != null ) {
        engine.board.items.remove(itemSelect.value);        
        delItemOption(itemSelect.value);
      }
    }    
    else if( e.currentTarget == itemPlace ) 
      engine.board.placeSelectedItem(itemSelect.value);
    else if( e.currentTarget == copyPlayers )
      engine.board.copyPlayers();  
    else if( e.currentTarget == pastePlayers ) {
      engine.board.pastePlayers();
      loadPlayerOptions();
    }
    else if( e.currentTarget == copyItems )
      engine.board.copyItems();  
    else if( e.currentTarget == pasteItems ) {
      engine.board.pasteItems();
      loadItemOptions();
    }
  }
  
  void reset() {
    // clear both the player and item select list
    Node child;
    while( (child = playerSelect.lastChild) != null ) 
      child.remove();
    while( (child = itemSelect.lastChild) != null ) 
      child.remove();
  }
  
  void loadPlayerOptions() {
    // load the player select list options
    Node child;
    while( (child = playerSelect.lastChild) != null ) 
      child.remove();
    String nam;
    Iterable<String> names;
    names = engine.board.players.keys;
    for( nam in names )
      addGPlayerOption( nam );
  }
  
  void loadItemOptions() {
    // load the players and items select list options
    Node child;
    while( (child = itemSelect.lastChild) != null ) 
      child.remove();
    String nam;
    Iterable<String> names;
    names = engine.board.items.keys;
    for( nam in names )
      addItemOption( nam );   
  }

  void loadOptions() {
    loadPlayerOptions();  
    loadItemOptions();  
  }

}

class PropEditor {
  
  /*
   * Properties Editor. Generalized to edit properties of
   * gameboard, players, obstacles
   */
  GameEngine        engine;
  Element           propertyeditor, _messages;
  TableElement      _table;
  TextInputElement  newpropname;
  TextAreaElement   action, enteraction, leaveaction;
  ButtonElement     accept, cancel, addprop;
  
  Map<String,ObjectEntry>   bsprops;
  Map <String,InputElement> propmap;  // propertyname-to-element map we create
  
  PropEditor( this.propertyeditor, this._messages );

  void edit( Map<String,ObjectEntry> props ) {
 
    ObjectEntry obj;
    
    cleareditor();  
    bsprops = props;
    
    // Create a propertymap which will map property names to input elements
    // We load this from the suppied map which maps names to ObjectEntries.
    propmap = new Map<String,InputElement>();
    
    // create a table to display the prop-value pairs for editing
    _table = new TableElement();
    // load each property into the table and the propmap as well
    bsprops.forEach(loadprop);
    // append table to propertyeditor Node passed during instancing
    propertyeditor.append(_table);
    
    // create our editor controls
    accept = new ButtonElement();
    accept.text = 'Accept';
    accept.onClick.listen(buttonpress);
    cancel = new ButtonElement();
    cancel.text = 'Cancel';
    cancel.onClick.listen(buttonpress);
    addprop = new ButtonElement();
    addprop.text = 'AddProp';
    addprop.onClick.listen(buttonpress);
    newpropname = new TextInputElement();

    // append to properyeditor node
    propertyeditor.append(accept);
    propertyeditor.append(cancel);
    propertyeditor.append(addprop);
    propertyeditor.append(newpropname);
    
    // set up an action textarea if necessary
    if( (obj=bsprops['action']) != null ) {
      action = new TextAreaElement();
      action.cols = 40; action.rows = 20;
      action.value = obj.data.buffer.string;
      propertyeditor.appendHtml('<br>Action');
      propertyeditor.append(action);
    }
    if( (obj=bsprops['enteraction']) != null ) {
      enteraction = new TextAreaElement();
      enteraction.cols = 40; enteraction.rows = 20;
      enteraction.value = obj.data.buffer.string;
      propertyeditor.appendHtml('<br>EnterAction');
      propertyeditor.append(enteraction);
    }
    if( (obj=bsprops['leaveaction']) != null ) {
      leaveaction = new TextAreaElement();
      leaveaction.cols = 40; leaveaction.rows = 20;
      leaveaction.value = obj.data.buffer.string;
      propertyeditor.appendHtml('<br>LeaveAction');
      propertyeditor.append(leaveaction);
    }
  }

  void loadprop(String key, ObjectEntry object ) {
    
    // load the properties from the ObjectEntry map into
    // the table for editing and our local propertymapas well
    TableRowElement   tRow;
    TableCellElement  tCell; 
    TextInputElement  elem;
  
    // skip an 'action' property, that's handled by itself and
    // skip if the object exists but is not a text object
    if( key == 'action' || key == 'enteraction' || key == 'leaveaction' ||
        (object != null && object.type != ObjectEntry.TEXT) ) return;
    
    tRow = _table.addRow();
    tCell = tRow.addCell();
    tCell.appendText( key );

    elem = new TextInputElement();
    if( object != null )
      // update the input element value if object already exists,
      // else we just leave the blank one created by default
      elem.value = object.data.buffer.string;
    tCell = tRow.addCell();
    tCell.append(elem);
    // add this pair to local map
    propmap[key] = elem;

  }
  
  void cleareditor() {
    // clearing or exiting editor, remove propmap and any nodes we added
    propmap = null;
    // remove all children of the editor
    Node child;
    while( (child = propertyeditor.lastChild) != null ) {
      child.remove();
    }
  }
  
  void buttonpress(Event e) {
    CharBuffer buf;
    
	if( e.currentTarget == accept ) {
      // changes accepted, update edited property values into object map
      propmap.forEach(updatevalue);
      if( action != null )
         // if textarea was created for action, look for update required
         if( action.value.length == 0 )
           bsprops.remove('action');
         else {
           // update the action property
           buf = new CharBuffer(null);
           buf.addAll( action.value.codeUnits );
           // check if an object needs to be created first, 
           // this might be the first time action was indicated
           if( bsprops['action'] == null)
             bsprops['action'] = engine.interpreter.stdobjs.textobject(newpropname.value);
           // update object with new action value
           bsprops['action'].data.buffer = buf;
         }
      if( enteraction != null )
         // if textarea was created for enteraction, look for update required
         if( enteraction.value.length == 0 )
           bsprops.remove('enteraction');
         else {
           // update the action property
           buf = new CharBuffer(null);
           buf.addAll( enteraction.value.codeUnits );
           // check if an object needs to be created first, 
           // this might be the first time enteraction was indicated
           if( bsprops['enteraction'] == null)
             bsprops['enteraction'] = engine.interpreter.stdobjs.textobject(newpropname.value);
           // update object with new enteraction value
           bsprops['enteraction'].data.buffer = buf;
         }
      if( leaveaction != null )
         // if textarea was created for leaveaction, look for update required
         if( leaveaction.value.length == 0 )
           bsprops.remove('leaveaction');
         else {
           // update the leaveaction property
           buf = new CharBuffer(null);
           buf.addAll( leaveaction.value.codeUnits );
           // check if an object needs to be created first, 
           // this might be the first time leaveaction was indicated
           if( bsprops['leaveaction'] == null)
             bsprops['leaveaction'] = engine.interpreter.stdobjs.textobject(newpropname.value);
           // update object with new leaveaction value
           bsprops['leaveaction'].data.buffer = buf;
         }
    }
    
    else if( e.currentTarget == addprop ) {
      // create a new property to be edited
      if( newpropname.value.length == 0 ) return;
      if( newpropname.value == 'action') {
        // create and place the action textarea
        action = new TextAreaElement();
        propertyeditor.appendHtml('<br>Action');
        propertyeditor.append(action);
      } else if( newpropname.value == 'enteraction') {
        // create and place the action textarea
        enteraction = new TextAreaElement();
        propertyeditor.appendHtml('<br>EnterAction');
        propertyeditor.append(enteraction);
      } else if( newpropname.value == 'leaveaction') {
        // create and place the action textarea
        leaveaction = new TextAreaElement();
        propertyeditor.appendHtml('<br>LeaveAction');
        propertyeditor.append(leaveaction);
      } else
        // use loadprop to create the input element and load into table
        loadprop( newpropname.value, null);      
      return;
    }
    // after accept, remove editor from propertyedit node
    cleareditor();
  }

  void updatevalue( String key, InputElement elem ) {
    CharBuffer buf = new CharBuffer(null);
    buf.addAll( elem.value.codeUnits );
    // watch for element value of zero length
    if( elem.value.length == 0 ) {
      bsprops.remove(key);
      return;
    }
    // watch for the ObjectEntry object needing to be created in map
    if( bsprops[key] == null)
      bsprops[key] = engine.interpreter.stdobjs.textobject(newpropname.value);
    // update object with new property value
    bsprops[key].data.buffer = buf;
  }
}