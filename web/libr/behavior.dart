part of boardgameone;

class VehBeh {
  GPlayer player;
  GameEngine eng;
  Map<String,ObjectEntry> properties;
  int turn;

  int passlev, lastop;
  VehBeh( this.eng, this.player, this.properties ) {
    ObjectEntry e = properties['turn'];
    turn = RIGHTWARD; 
    if( e != null ) {
      switch( e.data.buffer.string ) {
        case 'leftward': turn = LEFTWARD; break;
        case 'rightward': turn = RIGHTWARD; break;
        case 'backward': turn = BACKWARD; break;
      }
    }   
    passlev = 0;    
  }
  
  void slice() {
    bool dirchange = false;
    bool result = false;
    if( passlev == 0 && // when not passing, look for a turn
        eng.move( turn, false, 'road', player ))
       return; 
    
    // try a merge right
    if( eng.attemptPass( player.direction, 'right', 'road' ) ) return;

    // no merge, attempt to move foward
    BoardSquare sqr; int direction;
    // look for direction to move
    direction = eng.lookAround( player.direction, turn, 'road' );
    if( direction < 0 ) return;  // stuck
    switch( direction ) {
      case ABOVE: sqr = player.location.above;  break;
      case BELOW: sqr = player.location.below;  break;
      case LEFT:  sqr = player.location.left;  break;
      case RIGHT: sqr = player.location.right;  break;
    }
    // is it occupied? if not, move
    if( sqr.resident == null ) {
      // perform the move
      if( eng.move( direction, false, null, player ) ) {
        if( direction == player.direction ) dirchange = true;
        else dirchange = false;
      }
      return;
    }
    // look for a pass
    if( eng.attemptPass( direction, 'left', 'road' )) passlev++;
  }
}

class PedBeh {
  GPlayer player;
  GameEngine eng;
  Map<String,ObjectEntry> properties;
  int turn; String classname;

  int lastop;
  PedBeh( this.eng, this.player, this.properties ) {
    ObjectEntry e = properties['turn'];
    turn = RIGHTWARD; 
    if( e != null ) {
      switch( e.data.buffer.string ) {
        case 'leftward': turn = LEFTWARD; break;
        case 'rightward': turn = RIGHTWARD; break;
        case 'backward': turn = BACKWARD; break;
      }
    }   
    classname = properties['class'].data.buffer.string;
    if( classname == null ) classname = 'sidewalk';
  }
  
  void slice() {
    bool dirchange = false;
    bool result = false;
    //if( passlev == 0 && // when not passing, look for a turn
    //    eng.move( turn, false, 'road', player ))
    //   return; 
    
    // try a merge right
    //if( eng.attemptPass( player.direction, 'right', 'road' ) ) return;

    // no merge, attempt to move foward
    BoardSquare sqr; int direction = player.direction;
    // look for a quick pass
    if( eng.attemptPass( direction, 'left', classname )) return;
    else if( eng.attemptPass( direction, 'right',classname )) return;

    
    while( direction > 0 ) {
      // look for direction to move
      direction = eng.lookAround( direction, turn, classname );
      if( direction < 0 ) continue;  // stuck
      switch( direction ) {
        case ABOVE: sqr = player.location.above;  break;
        case BELOW: sqr = player.location.below;  break;
        case LEFT:  sqr = player.location.left;  break;
        case RIGHT: sqr = player.location.right;  break;
      }
      // is it occupied? if not, move
      if( sqr.resident == null ) {
        // perform the move
        if( eng.move( direction, false, null, player ) ) {
          if( direction == player.direction ) dirchange = true;
          else dirchange = false;
        }
        return;
      }
      // else don't move
      direction = -1;
    }
  }
}