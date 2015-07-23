/**************************
  *  BoardGameOne files   *
  *  (c) John Derry 2015  *
 **************************/
part of boardgameone;

// consider breaking up designtools

class HelpIndex{
  String name;
  Map<String,String> map;
  HelpIndex     next;
}

class ToolBox {
  /*
   * GameBoard Editor's Toolbox
   * Everything is pretty much lumped in here that is used for edititing. 
   * The element tags id's are established in the editor.html, otherwise it's here. 
   * From this code we also create an instances of the propery editor that we use.
   */
  static const IMAGEROWCNT = 37;    // This is wildly dependent on other things

  ButtonElement     updateProp, boardProps, dropPlayer, dropItem, copyBoard, pasteBoard,
    playerCreate, playerDelete, playerEdit, playerPlace, 
    itemCreate, itemDelete, itemEdit, itemPlace, copyPlayers, pastePlayers, copyItems, pasteItems, 
    loadImages, clearImages, clearScratch;
  TextInputElement  mapName, rowsNum, colsNum, propValue, playerName, itemName, imageRowCnt;
  CheckboxInputElement rangeCB, multiCB;
  SelectElement     propSelect, playerSelect, itemSelect, imageDirSelect, helpRoot, helpSelect;
  DivElement        playerImgList, itemImgList;

  GameEngine      engine;
  Element         _messages, _images;
  TableElement    _table;
  TableRowElement _tRow;
  List<String>    _imageList, _imageDirList;
  int             _imagerowcnt, _rowcnt;
  
  PropEditor    peditor;
  WebConsole    helpconsole;
  CharBuffer    conbuf;
  HelpIndex     helproot, helpindex;
   
  /* The toolbox has a help console at the bottom. This is the event handler
     used when some action is required
  */
  void helpconsoleevent() {
    // fetch the input and then clear it out after looking up help
    String answer;
    conbuf.fetch();
    answer = StandardObjects.helpindex[conbuf.string.trimRight()];
    if( answer == null )
      answer = GameEngine.helpindex[conbuf.string.trimRight()];  
    conbuf.webcon.clear();  // throws out last response
    conbuf.clear();         // throws out leftover input
    if( answer == null )
      conbuf.addAll('No help available<br>'.codeUnits);
    else   
      conbuf.addAll('${answer}<br>'.codeUnits);
    conbuf.deliver();
      
  }

  /* CONSTRUCTOR */ 
  ToolBox(this.engine, this._images, this._messages ) {

    peditor = new PropEditor( querySelector("#propedit"), _messages );
    helpconsole = new WebConsole(document, '.helpdiv');
    helpconsole.echo = false;
    conbuf    = new CharBuffer( helpconsole );
    helpconsole.inputeventhandler = helpconsoleevent;
    
    // associate the property editor with gameboard so that
    // square properties can be edit by the second click  
    peditor.engine = engine;
    engine.board.peditor = peditor;
    
    // get access to HTML elements defined on editor.html page
    // BUTTONS & CHECKBOXES
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
    // INPUT & SELECT
    propValue = querySelector("#propValue");
    propSelect = querySelector("#propSelect");
    playerSelect = querySelector("#playerSelect");
    playerName = querySelector("#playerName");
    itemSelect = querySelector("#itemSelect");
    itemName = querySelector("#itemName");
    imageRowCnt = querySelector("#imageRowCnt");
    loadImages = querySelector("#loadImages");
    clearImages = querySelector("#clearImages");
    imageDirSelect = querySelector("#imageDir");
    helpRoot = querySelector("#helpRoot");
    helpSelect = querySelector("#helpSelect");
    // Special Divisions
    playerImgList = querySelector("#playerlist");
    itemImgList = querySelector("#itemlist");
    
    // attach listeners
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
    loadImages.onClick.listen(buttonpress);
    clearImages.onClick.listen(buttonpress);
    helpRoot.onClick.listen(buttonpress);    
    helpSelect.onClick.listen(buttonpress);    
    //imageDirSelect.onClick.listen(buttonpress);

    /*
     * Setup the stuff that help console needs
     */
    
    helproot = helpindex = new HelpIndex();
    helpindex.name = 'script standard objects';
    helpindex.map = StandardObjects.helpindex; 
    addPDOption( helpRoot, helpindex.name );
   
    helpindex.next = new HelpIndex();
    helpindex = helpindex.next;
    helpindex.name = 'script game objects';
    helpindex.map = GameEngine.helpindex; 
    addPDOption( helpRoot, helpindex.name );

    helpindex.next = new HelpIndex();
    helpindex = helpindex.next;
    helpindex.name = 'game design help';
    helpindex.map = DesignHelp.helpindex; 
    addPDOption( helpRoot, helpindex.name );
    
    Iterator keys_iter = helproot.map.keys.iterator;
    while( keys_iter.moveNext() ) {
      addPDOption( helpSelect, keys_iter.current );
    }

    /*
     * set up and request loading the area 
     * where the images will be show for selection
     */
     
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
  // END CONSTRUCTOR
  
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
    _images.append(_table);
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
  
  void addPDOption(SelectElement select, String name) {
    OptionElement option = new OptionElement();
    option.value = option.text = name;
    select.append(option);
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
    
    else if( e.currentTarget == clearImages ) {
      // clear the image table
      _table.remove();
      _table = new TableElement();
    }
    else if( e.currentTarget == loadImages || e.currentTarget == imageDirSelect  ) {
        // load the image table with new available images
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
          addPDOption(playerSelect, playerName.value);
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
          addPDOption(itemSelect, itemName.value);
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
    else if( e.currentTarget == helpRoot ) {
      // get the right helpindex in place
      List<OptionElement> opt = helpRoot.selectedOptions;
      int indx = opt[0].index;
      helpindex = helproot;
      while( indx-- > 0 && helpindex.next != null ) 
        helpindex = helpindex.next; 
      // reload the options for display
      Node e;
      // clear old list and any help first
      while( (e = helpSelect.firstChild) != null ) e.remove();
      helpconsole.clear();
      // load new list
      Iterator keys_iter = helpindex.map.keys.iterator;
      while( keys_iter.moveNext() ) {
        addPDOption( helpSelect, keys_iter.current );
      }
    }
    else if( e.currentTarget == helpSelect ) {
      List<OptionElement> opt = helpSelect.selectedOptions;
      String answ = helpindex.map[opt[0].innerHtml]; 
      helpconsole.clear();
      helpconsole.writeln(answ);
    }
  }
  
  void reset() {
    // clear both the player and item select list
    Node child;
    while( (child = playerSelect.lastChild) != null ) 
      child.remove();
    while( (child = itemSelect.lastChild) != null ) 
      child.remove();
    if( (child = playerImgList.lastChild) != null ) 
      child.remove();
    if( (child = itemImgList.lastChild) != null ) 
      child.remove();
  }
  
  void loadPlayerOptions() {
    // load the player select list options from engine.players
    // and set up the playerList Division
    Node child;
    // clear the old list
    while( (child = playerSelect.lastChild) != null ) 
      child.remove();
    if( (child = playerImgList.lastChild) != null ) 
      child.remove();
    String nam, imagenam;
    Iterable<String> names = engine.board.players.keys;
    TableElement table = new TableElement();
    TableRowElement row = table.addRow();
    Element cell;
    playerImgList.append( table );
    for( nam in names ) {
      addPDOption( playerSelect, nam );
      imagenam = engine.board.players[nam].imagename;
      if( imagenam != null ) {
        cell = row.addCell();
        cell.append( new ImageElement(src:'http://${HOSTNAME}/images/${imagenam}.png'));
      }
    }
  }
  
  void loadItemOptions() {
  // load the item select list options from engine.items
  // and set up the itemList Division
    Node child;
    while( (child = itemSelect.lastChild) != null ) 
      child.remove();
    if( (child = itemImgList.lastChild) != null ) 
      child.remove();
    String nam, imagenam;
    Iterable<String> names = engine.board.items.keys;
    TableElement table = new TableElement();
    TableRowElement row = table.addRow();
    Element cell;
    itemImgList.append( table );
    for( nam in names ) {
      addPDOption( itemSelect, nam );   
      imagenam = engine.board.items[nam].imagename;
      if( imagenam != null ) {
        cell = row.addCell();
        cell.append( new ImageElement(src:'http://${HOSTNAME}/images/${imagenam}.png'));
      }
    }
  }

  void loadOptions() {
    loadPlayerOptions();  
    loadItemOptions();  
  }

}

class PropEditor {
  
  /*
   * Properties Editor. Generalized to edit properties of
   * gameboard, players, items
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
    
    bool nobreakyet = true;
    // set up an action textarea if necessary
    if( (obj=bsprops['action']) != null ) {
      action = new TextAreaElement();
      action.cols = 40; action.rows = 20;
      action.value = obj.data.buffer.string;
      if( nobreakyet ) { nobreakyet = false; propertyeditor.appendHtml('<br>Action'); }
      else propertyeditor.appendHtml('Action');
      propertyeditor.append(action);
    }
    if( (obj=bsprops['enteraction']) != null ) {
      enteraction = new TextAreaElement();
      enteraction.cols = 40; enteraction.rows = 20;
      enteraction.value = obj.data.buffer.string;
      if( nobreakyet ) { nobreakyet = false; propertyeditor.appendHtml('<br>EnterAction'); }
      else propertyeditor.appendHtml('EnterAction');
      propertyeditor.append(enteraction);
    }
    if( (obj=bsprops['leaveaction']) != null ) {
      leaveaction = new TextAreaElement();
      leaveaction.cols = 40; leaveaction.rows = 20;
      leaveaction.value = obj.data.buffer.string;
      if( nobreakyet ) { nobreakyet = false; propertyeditor.appendHtml('<br>LeaveAction'); }
      else propertyeditor.appendHtml('LeaveAction');
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

