component {

  cfprocessingdirective(preserveCase = true);

  function init(
    string apiKey       = "",
    string apiUrl       = "https://ipapi.co",
    numeric throttle    = 100,
    string userAgent    = "ipapi-cfml-api-client/0.7",
    numeric httpTimeOut = 3,
    boolean debug
  ) {
    arguments.debug  = (arguments.debug ?: false);
    this.apiUrl      = arguments.apiUrl;
    this.apiKey      = arguments.apiKey;
    this.userAgent   = arguments.userAgent;
    this.throttle    = arguments.throttle;
    this.httpTimeOut = arguments.httpTimeOut;
    this.debug       = arguments.debug;
    this.lastRequest = 0;
    return this;
  }

  function debugLog(required input) {
    if( this.debug ){
      var info = (isSimpleValue(arguments.input) ? arguments.input : serializeJSON(arguments.input));
      cftrace(var = "info", category = "ipapi", type = "information");
    }
    return;
  }

  string function getRemoteIp() {
    if( len(cgi.HTTP_X_REAL_IP) ){
      return cgi.HTTP_X_REAL_IP;
    }
    if( len(cgi.HTTP_X_FORWARDED_FOR) ){
      return trim(listFirst(cgi.cgi.HTTP_X_REAL_IP));
    }
    return cgi.REMOTE_ADDR;
  }

  struct function ipDetail(string ip = this.getRemoteIp()) {
    var out = this.apiRequest("GET /#arguments.ip#/json/");
    return out;
  }

  struct function quota(string ip = this.getRemoteIp()) {
    var out = this.apiRequest("GET /quota/");
    return out;
  }

  // struct function ipField( required string field, string ip= this.getRemoteIp() ) {
  // 	var out= this.apiRequest( "GET /#arguments.ip#/#arguments.field#/" );
  // 	return out;
  // }

  struct function apiRequest(required string api) {
    var http     = 0;
    var dataKeys = 0;
    var item     = "";
    var out      = {
      success   : false,
      error     : "",
      status    : "",
      json      : "",
      statusCode: 0,
      response  : "",
      verb      : listFirst(arguments.api, " "),
      requestUrl: this.apiUrl & listRest(arguments.api, " "),
    };
    if( this.debug ){
      this.debugLog(out);
    }
    if( this.throttle > 0 && this.lastRequest > 0 ){
      out.delay = this.throttle - (getTickCount() - this.lastRequest);
      if( out.delay > 0 ){
        this.debugLog("Pausing for #out.delay#/ms");
        sleep(out.delay);
      }
    }
    cftimer(type = "debug", label = "ipapi.co request") {
      cfhttp(
        result       = "http",
        method       = out.verb,
        url          = out.requestUrl,
        throwOnError = false,
        userAgent    = this.userAgent,
        timeOut      = this.httpTimeOut,
        charset      = "UTF-8"
      ) {
        if( len(this.apiKey) ){
          cfhttpparam(name = "key", type = "url", value = this.apiKey);
        }
      }
    }
    if( this.throttle > 0 ){
      this.lastRequest = getTickCount();
    }
    out.response   = toString(http.fileContent);
    // this.debugLog( out.response );
    out.statusCode = http.responseHeader.Status_Code ?: 500;
    if( left(out.statusCode, 1) == 4 || left(out.statusCode, 1) == 5 ){
      out.success = false;
      out.error   = "status code error: #out.statusCode#";
    } else if( out.response == "Connection Timeout" || out.response == "Connection Failure" ){
      out.error = out.response;
    } else if( left(out.statusCode, 1) == 2 ){
      out.success = true;
    }
    // parse response
    if( len(out.response) ){
      try {
        out.response = deserializeJSON(out.response);
        if( isStruct(out.response) && structKeyExists(out.response, "reason") ){
          out.success = false;
          out.error   = out.response.reason;
        }
      } catch( any cfcatch ){
        out.error = "JSON Error: " & (cfcatch.message ?: "No catch message") & " " & (cfcatch.detail ?: "No catch detail");
      }
    }
    if( len(out.error) ){
      out.success = false;
    }
    this.debugLog(out.statusCode & " " & out.error);
    return out;
  }

}
