import 'dart:html';
import 'dart:convert';

const  HOSTNAME  = 'localhost:8080';
//const  HOSTNAME  = 'domainofchildhood.com/bg1';

ButtonElement     loadMap, saveMap, list, lookup, update, clear;
TextInputElement  mapName, descName, pathName;
TextAreaElement   descTextArea;
SelectElement     descSelectList; 
Element           messages;

Map                 gamemap;
Map<String,String>  descmap, narrmap;

void main() {
  
  loadMap = querySelector("#loadMap");
  saveMap = querySelector("#saveMap");
  list = querySelector("#list");
  descSelectList = querySelector("#desclist");
  lookup = querySelector("#lookup");
  update = querySelector("#update");
  clear = querySelector("#clear");
  mapName = querySelector("#mapName");
  descName = querySelector("#descName");
  descTextArea = querySelector("#desc");
  pathName = querySelector("#path");
  messages = querySelector("#messages");
  
  loadMap.onClick.listen(buttonpress);
  saveMap.onClick.listen(buttonpress);
  list.onClick.listen(buttonpress);
  lookup.onClick.listen(buttonpress);
  update.onClick.listen(buttonpress);
  clear.onClick.listen(buttonpress);

}

void _handleError(Error e) {
  messages.text = e.toString();
}

void _load(String map) {
  
  gamemap = JSON.decode(map);
  if( (descmap = gamemap['DESCRIPTIONS']) == null )
    descmap = new Map<String,String>();
  if( (narrmap = gamemap['NARRATIVES']) == null )
    narrmap = new Map<String,String>();
  messages.text = 'Map Loaded';
}

void buttonpress(Event e) {
  HttpRequest req;
  String s;
  Iterable it;
  Element child;
  OptionElement option;

  if( e.currentTarget == loadMap ) {
    
    HttpRequest.getString('http://${HOSTNAME}/data/${mapName.value}.json')
      .then(_load).catchError(_handleError);
  }
  else if( e.currentTarget == saveMap ) {
    
    req = new HttpRequest();
    req.onReadyStateChange.listen((ProgressEvent e) {
      if (req.readyState == HttpRequest.DONE &&
          (req.status == 200 || req.status == 0))
        messages.text = 'map post success';
      else 
        messages.text = 'map post failure: ${e.toString()}';
    });
    gamemap['DESCRIPTIONS'] = descmap;
    gamemap['NARRATIVES'] = narrmap;
    req.open('POST', 'http://${HOSTNAME}/data/${mapName.value}.json', async:false);
    req.send( JSON.encode(gamemap));
    messages.text = 'Map Saved';
  }
  else if( e.currentTarget == list ) {
    it = descmap.keys;
    messages.text = it.join(', ');
    while( (child = descSelectList.lastChild) != null ) 
      child.remove();
    for( s in it ) {
      option = new OptionElement();
      option.value = option.text = s;
      descSelectList.append( option );
    }
  }
  else if( e.currentTarget == lookup ) {
    if( descSelectList.selectedIndex >= 0 )
      descName.value = descmap.keys.elementAt(descSelectList.selectedIndex);
    if( (s = descmap[descName.value]) != null )
      descTextArea.value = s;
    else
      descTextArea.value = '';
    if( (s = narrmap[descName.value]) != null )
      pathName.value = s;
    else
      pathName.value = '';
  }
  else if( e.currentTarget == update ) {
    if( descName.value.length > 0 && descTextArea.value.length > 0 ) {
      descmap[descName.value]= descTextArea.value; 
      narrmap[descName.value]= pathName.value; 
    }
  }
  else if( e.currentTarget == clear ) {
    descTextArea.value = '';
    pathName.value = '';
  }
}

