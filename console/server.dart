/**************************
  *  BoardGameOne files   *
  *  (c) John Derry 2015  *
 **************************/
import 'dart:io';

/* Simple Server for game1
 * Browse to it using http://localhost:8080  
 * 
 * Provides CORS headers, so can be accessed from any other page
 */

final HOST = "10.240.96.239"; // eg: localhost 
final PORT = 80; 

void main() {
  HttpServer.bind(HOST, PORT).then((server) {
    server.listen((HttpRequest request) {
      switch (request.method) {
        case "GET": 
          handleGet(request);
          break;
        case "POST": 
          handlePost(request);
          break;
        case "OPTIONS": 
          handleOptions(request);
          break;
        default: defaultHandler(request);
      }
    }, 
    onError: printError);
    
    print("Listening for GET and POST on http://$HOST:$PORT");
  },
  onError: printError);
}

/**
 * Handle GET requests by reading the contents of data.json
 * and returning it to the client
 */
void handleGet(HttpRequest req) {
  HttpResponse resp = req.response;
  print("${req.method}: ${req.uri.path}");
  addCorsHeaders(resp);
  
  // remove the leading '/'
  String path = req.uri.path.substring(1);
  // read the contents and prepare to stream out port
  var file = new File(path);
  // determine MIME type
  String contenttype;
  if( path.contains('.html') )
    contenttype = "text/html";
  else if( path.contains('.dart') )
    contenttype = "application/javascript";
  else if( path.contains('.js') )
    contenttype = "application/javascript";
  else if( path.contains('.json') )
    contenttype = "application/json";
  else if( path.contains('.css') )
    contenttype = "text/css";
  else if( path.contains('.png') )
    contenttype = "image/png";
  else  
    contenttype = "text";
    
  if (file.existsSync()) {
    // if it exists as named use it
    resp.headers.add(HttpHeaders.CONTENT_TYPE, contenttype);
    file.readAsBytes().asStream().pipe(resp); // automatically close output stream
  }
  else if( true || path.length == 0 ) {
    file = new File("index.html");
    contenttype = "text/html";
    resp.headers.add(HttpHeaders.CONTENT_TYPE, contenttype);
    file.readAsBytes().asStream().pipe(resp); // automatically close output stream
    
  } else {
    var err = "Could not find file: ${req.uri.path}";
    resp.addError(err);
      //stderr.writeln(err);
      resp.close().catchError(printError);
  }
  
}

/**
 * Handle POST requests by overwriting the contents of data.json
 * Return the same set of data back to the client.
 */
File    file;
IOSink  ioSink; // save the data to the file

void handlePost(HttpRequest req) {
  HttpResponse res = req.response;
  print("${req.method}: ${req.uri.path}");
  
  addCorsHeaders(res);
  // remove the leading '/'
  String path = req.uri.path.substring(1);
  file = new File(path);
  ioSink = file.openWrite(); // save the data to the file
  
  req.listen((List<int> buffer) {
    ioSink.add(buffer);
    // return the same results back to the client
    res.add(buffer);
    res.close();
  },
    onDone: () { ioSink.close(); }, onError: printError);
}

/**
 * Add Cross-site headers to enable accessing this server from pages
 * not served by this server
 * 
 * See: http://www.html5rocks.com/en/tutorials/cors/ 
 * and http://enable-cors.org/server.html
 */
void addCorsHeaders(HttpResponse res) {
  res.headers.add("Access-Control-Allow-Origin", "*, ");
  res.headers.add("Access-Control-Allow-Methods", "POST, GET, OPTIONS");
  res.headers.add("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept");
}

void handleOptions(HttpRequest req) {
  HttpResponse res = req.response;
  addCorsHeaders(res);
  //print("${req.method}: ${req.uri.path}");
  res.statusCode = HttpStatus.NO_CONTENT;
  res.close();
}

void defaultHandler(HttpRequest req) {
  HttpResponse res = req.response;
  addCorsHeaders(res);
  res.statusCode = HttpStatus.NOT_FOUND;
  res.addError("Not found: ${req.method}, ${req.uri.path}");
  res.close();
}

void printError(error) => print(error);
