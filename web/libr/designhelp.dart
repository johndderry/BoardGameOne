/**************************
  *  BoardGameOne files   *
  *  (c) John Derry 2015  *
 **************************/
part of boardgameone;

class DesignHelp {
  
  static const String introduction_help ='''
<H2>Introduction</H2>
<P>BoardGameOne is a browser-based game engine for creating computer
games based on a grid of equally spaced squares. Games created with
it are styled after board games of old, but with additions borrowed
from role playing games and early two dimensional computer games like
Zelda. BoardGameOne has these basic features:</P>
<UL>
  <LI><P>Game Definition Editor</P>
  <LI><P>Game Player which can be easily modified to open a specific
  game when loaded into the browser</P>
  <LI><P>Basic set of images for buildings, landscapes, home
  furnishings, bodies of water, modes of transportation, players,
  obstacles, tools. This basic set can be expanded to include your own
  images.</P>
  <LI><P>Built-in scripting language, simple and easy to learn.</P>
  <LI><P>Time-slices for movement of players and obstacles.</P>
  <LI><P>Ability to chain to new game board, an then return to the
  previous board, all during game play.</P>
</UL>
''';  
  
  static const String editor_help ='''
<H2>Game Definition Editor</H2>
<P>The Game Definition Editor path is util/editor.html. 
</P>
<P>It is used to create and edit a game definition, and can also be
used to run the game and see how it is working. Game definitions are
stored as a single JSON map, which can be saved though a web server
with Http PUT ability, or save locally with a cut-and-paste
operation.</P>
<P>Besides the complete game definition, the editor includes a
scratch area where selected portions of the game definition can
written to, and then read from, in order to reuse elements of an
already created game into a new game. 
</P>
<P>The editor also has support for troubleshooting your game
functionality, with Single-Step run mode, and direct entry of Script
instructions. 
</P>
<H3 CLASS="western">Basic Description of Editor Page Functions by
Line</H3>
<P>After opening up the Game Editor in your browser, you will see:
two lines beginning with titles in bold, two blank colored
lines(red/blue), three more lines with titles in bold, and a section
in green. Basic functions are grouped together on each line. Here is
a basic description of the functionality of each group:</P>
<UL>
  <LI><P><B>File</B><br><SPAN STYLE="font-weight: normal">loading and
  saving the game definition to the web server or local storage,
  loading or saving the scratch area to web/local storage, and
  clearing the scratch pad.</SPAN></P>
  <LI><P><B>New</B><br><SPAN STYLE="font-weight: normal">creating a
  new board, adding rows and columns to the existing board, and
  loading images made available for placement on the board.</SPAN></P>
  <LI><P STYLE="font-weight: normal">Red Line<br>description of the
  board square which the mouse is over: location, players and items
  present.</P>
  <LI><P STYLE="font-weight: normal">Blue Line<br>status messages
  which appear periodically.</P>
  <LI><P><B>Board</B><br><SPAN STYLE="font-weight: normal">various
  functions which pertain to the board and board squares which are
  selected.</SPAN></P>
  <LI><P><B>Players</B><br><SPAN STYLE="font-weight: normal">various
  functions which pertain to creating and maintaining Players.</SPAN></P>
  <LI><P><B>Items</B><br><SPAN STYLE="font-weight: normal">various
  functions which pertain to creating and maintaining Items.</SPAN></P>
  <LI><P STYLE="font-weight: normal">Green Area<br>functions related
  to both running and troubleshooting the game during run mode.</P>
</UL>
<P STYLE="font-weight: normal">As of yet, the game board hasn't
appeared on the page. It will appear directly above the red and blue
lines after loading one with the File-Load button or creating one
with the New-Create button.</P>
''';

  static const String functions_help ='''  
  <H2 CLASS="western">Basic Functions of Each Editor Line</H2>
  <P STYLE="margin-top: 0.17in; font-weight: normal; page-break-after: avoid">
  <FONT FACE="Albany, sans-serif"><FONT SIZE=4>File</FONT></FONT></P>
  <UL>
    <LI><P STYLE="font-weight: normal">Name<br>text area for the name
    of the JSON map file in which to load from, or save to, the game
    board definition. This applies to saving through the web server, but
    not when saving locally. This definition will cover the Board,
    Players, and Items definition data.</P>
    <LI><P STYLE="font-weight: normal">Load<br>button to load the named
    board definition file from the web server, or from the text box for
    local storage. When developing with Dart and using the supplied web
    server application, the location path is: BoardGame1/web/data; the
    extension is: .json. The function uses a Http GET on port 8080.
    Loading a board definition will overwrite the current game board, if
    it is present.</P>
    <LI><P STYLE="font-weight: normal">Save<br>button to save the named
    board definition file to the web server, or write in to the text box
    for local storage. The location and extension, when using Dart with
    the supplied web server application, is the same as a load. The
    function uses a Http PUT on port 8080. The board definition is a
    complete description of the current game Board, with Players and
    Items included 
    </P>
    <LI><P>UseLocal<br>button to select loading and saving to a local
    file using cut-and-paste operations, for both board definition and
    scratch area, instead of a web server. This button will open a small
    text window in which text can be displayed. For loading, this is the
    text box will have the loading text pasted into it. For saving, this
    text box will show the text which will be cut out for pasting into a
    text editor.</P>
    <LI><P>UseWeb<br>button to select loading and saving with a web
    server. This will close the text box opened with UseLocal if
    present, and restore the default operation of loading and saving to
    a web server.</P>
    <LI><P>LoadScratch<br>button to load the named file into the
    Scratch Area. Just like the Load function, but the Scratch Area is
    loaded instead of the board definition.</P>
    <LI><P>SaveScratch<br>button to save the Scratch Area into the
    named file. Just like the Save function, but the Scratch Area is the
    source instead of the board definition.</P>
    <LI><P>ClearScratch<br>clear the Scratch Area of any contents. The
    Scratch Area is where selected portions of the game board, selected
    Players and selected Items can be written to or read from. It is
    used primarily for transferring portions of a game board definition
    from an existing board to a new board, basically a cut-and-paste
    area for definition data.</P>
  </UL>
  <P STYLE="margin-top: 0.17in; page-break-after: avoid"><FONT FACE="Albany, sans-serif"><FONT SIZE=4>New</FONT></FONT></P>
  <UL>
    <LI><P>Rows<br>holds the number of rows in the new game board being
    created.</P>
    <LI><P>Cols<br>holds the number of columns in the new game board
    being created.</P>
    <LI><P>Create<br>button to create a new, empty game board of the
    specified rows and columns.</P>
    <LI><P>AddROW<br>button to add a single row into an existing game
    board.</P>
    <LI><P>AddCOL<br>button to add a single column into an existing
    game board.</P>
    <LI><P>Images<br>selector to specify the location of the directory
    which holds the images available for placing on selected game board
    squares. This will be a pull down list of possible directories which
    have been recognized when the Editor page first loaded. The images
    available are broken down into categories, with each category in a
    separate directory, to make image selection more manageable. After
    changing the directory, use the “Reload” function. 
    </P>
    <LI><P>Count<br>holds the number of images to load on a single line
    during the “Reload” function, available for changing in case the
    Editor page width is changed, etc.</P>
    <LI><P>Reload<br>button to reload the images indicated in the
    Images directory, with Count images per line, as thumbnails into the
    area directly above the Green Area and below Items.</P>
  </UL>
  <P STYLE="margin-top: 0.17in; page-break-after: avoid"><FONT FACE="Albany, sans-serif"><FONT SIZE=4>Board</FONT></FONT></P>
  <UL>
    <LI><P>Multi<br>check box to enable selecting multiple squares on
    the game board.</P>
    <LI><P>Range<br>check box to enable selecting a range of squares on
    the game board.</P>
    <LI><P>Copy<br>button to copy the selected board squares into the
    Scratch Area.</P>
    <LI><P>Paste<br>button to paste any board squares saved in the
    Scratch Area onto the game board, at the location of the first
    selected square.</P>
    <LI><P>Property Selector<br>pull down selector of common properties
    which can be applied to all selected board squares in one operation.</P>
    <LI><P>Property Text Area<br>value of the property selected by the
    selector, which will be applied to selected board squares.</P>
    <LI><P>Update<br>button to perform the application of the property
    and value (from Property above) to the selected squares.</P>
    <LI><P>BoardProperties<br>button to open an area to edit and create
    global board properties.</P>
    <LI><P>DropPlayer<br>button to remove any players from the selected
    board squares.</P>
    <LI><P>DropItem<br>button to remove any items from the selected
    board squares.</P>
  </UL>
  <P STYLE="margin-top: 0.17in; page-break-after: avoid"><FONT FACE="Albany, sans-serif"><FONT SIZE=4>Players</FONT></FONT></P>
  <UL>
    <LI><P>Copy<br>button to copy the selected Player into the Scratch
    Area.</P>
    <LI><P>Paste<br>button to append any Players saved in the Scratch
    Area onto the Player list.</P>
    <LI><P>Player Selector<br>pull down list of current Players, from
    which one can be selected.</P>
    <LI><P>Edit<br>button to open an area to edit and create properties
    of the selected Player.</P>
    <LI><P>Place<br>button to place the selected Player onto the board
    at all selected board squares.</P>
    <LI><P>Name<br>text area for name of the new Player to create.</P>
    <LI><P>Create<br>button to create a new Player of the given name.</P>
    <LI><P>Delete<br>button to delete the selected Player</P>
  </UL>
  <P STYLE="margin-top: 0.17in; page-break-after: avoid"><FONT FACE="Albany, sans-serif"><FONT SIZE=4>Items</FONT></FONT></P>
  <UL>
    <LI><P>Copy<br>button to copy the selected Item into the Scratch
    Area.</P>
    <LI><P>Paste<br>button to append any Items saved in the Scratch
    Area onto the Item list.</P>
    <LI><P>Item Selector<br>pull down list of current Items, from which
    one can be selected.</P>
    <LI><P>Edit<br>button to open an area to edit and create properties
    of the selected Item.</P>
    <LI><P>Place<br>button to place the selected Item onto the board at
    all selected board squares.</P>
    <LI><P>Name<br>text area for name of the new Item to create.</P>
    <LI><P>Create<br>button to create a new Item of the given name.</P>
    <LI><P>Delete<br>button to delete the selected Item</P>
  </UL>
  <P STYLE="margin-top: 0.17in; page-break-after: avoid"><FONT FACE="Albany, sans-serif"><FONT SIZE=4>Run
  Mode Area ( Green Area )</FONT></FONT></P>
  <UL>
    <LI><P>Swap<br>button to swap both the red and blue message areas
    for a chat area, or swapping the chat area for the red and blue
    message area.</P>
    <LI><P>Run<br>button to set the game into run mode; adjust the look
    of the game board to running and begin running the game from the
    beginning</P>
    <LI><P>SingleStep<br>button to set the game into single-step run
    mode; begin running the game from the beginning but don't start the
    time-slice timer running.</P>
    <LI><P>Step<br>button to move forward one time-slice when in
    single-step mode.</P>
    <LI><P>Stop<br>button to stop the game running; adjust the look of
    the game board to stopping and stop all game activity.</P>
    <LI><P>Source<br>text area for entering programming script to be
    interpreted immediately (after Enter key) during stop or run mode.
    Any script commands will be echoed directly below.</P>
    <LI><P>Clear<br>button to clear any script text which were echoed
    from the Source text area.</P>
    <LI><P>Console<br>text area for enter any console commands. Any
    console commands will be echoed directly below.</P>
    <LI><P>Clear<br>button to clear any console commands which were
    echoed from the Console text area.</P>
  </UL>
''';
  
  static const String properties_help ='''
<H2 CLASS="western">Common and Useful Properties of Game Elements</H2>
<P>Properties, along with the corresponding values associated with
them, are used extensively to control various aspects of the game
board and game play. These are generally referred to as
property-value pairs. All elements of BoardGameOne can have
property-value pairs attached to them. Some properties have been
predefined to be used in specific ways, that is to perform specific
functions in the game engine. Otherwise, properties can be created as
needed and accessed by the scripting language to perform other
functions which you define. 
</P>
<P>Below are the predefined properties, group by those that apply to
all elements and those that apply to a specific game element, and a
description of the function they perform in game play.</P>
<P STYLE="margin-top: 0.17in; page-break-after: avoid"><FONT FACE="Albany, sans-serif"><FONT SIZE=4>Universal
Properties</FONT></FONT></P>
<UL>
  <LI><P>desc<br>a simple description of the game element, or a label
  to a more detail description created with the DescEditor</P>
  <LI><P>imagename<br>path to the image which is to be used with this
  element</P>
</UL>
<P STYLE="margin-top: 0.17in; page-break-after: avoid"><FONT FACE="Albany, sans-serif"><FONT SIZE=4>Game
Board Properties</FONT></FONT></P>
<UL>
  <LI><P>title<br>holds the game title</P>
  <LI><P>library<br>name of a script library to load 
  </P>
</UL>
<P STYLE="margin-top: 0.17in; page-break-after: avoid"><FONT FACE="Albany, sans-serif"><FONT SIZE=4>Game
Square Properties</FONT></FONT></P>
<UL>
  <LI><P>locked<br>if set to “true”, indicates the square is
  locked and cannot be entered</P>
  <LI><P>enteraction<br>script to be executed when the square is
  entered by a player</P>
  <LI><P>leaveaction<br>script to be executed when the square is
  exited by a player</P>
</UL>
<P STYLE="margin-top: 0.17in; page-break-after: avoid"><FONT FACE="Albany, sans-serif"><FONT SIZE=4>Player
Properties</FONT></FONT></P>
<UL>
  <LI><P>POV<br>assigns this player to be the “point of view”,
  that is the player which is controlled by the actual game player</P>
  <LI><P>point<br>assign a direction to which the player will point:
  either that of right, left, up or down</P>
  <LI><P>initaction<br>script to be executed once when game begins</P>
  <LI><P>action<br>script to be executed for each time-slice the
  player is active</P>
  <LI><P>behavior<br>one of the available behavior personalities</P>
  <LI><P>knowledge<br>one of the available knowledge bases, used for chatting</P>
</UL>
<P STYLE="margin-top: 0.17in; page-break-after: avoid"><FONT FACE="Albany, sans-serif"><FONT SIZE=4>Item
Properties</FONT></FONT></P>
<P><BR><BR>
</P>
  ''';
      
  static final Map helpindex = {
'introduction':introduction_help, 'editor':editor_help, 'functions':functions_help, 'properties':properties_help };
  
}
