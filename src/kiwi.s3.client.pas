unit kiwi.s3.client;

interface

uses
  System.SysUtils,
  System.DateUtils,
  System.StrUtils,
  System.Types,
  System.UITypes,
  System.Classes,
  System.NetEncoding,
  System.Net.URLClient,
  System.Hash,
  idhttp,
  Data.Cloud.CloudAPI,
  Data.Cloud.AmazonAPI,
  Xml.XMLIntf,
  Xml.XMLDoc,
  kiwi.s3.interfaces;

type

  tkiwiS3Client = class(tinterfacedobject, ikiwiS3Client)
  private
    { private declarations }

    fconnIdhttp: tidhttp;
    fstraccountName: string;
    fstraccountKey: string;
    fstrBucket: string;
    fstrRegion: string;
    fbooAccelerate: boolean;

    { functions }
      function buildHeaders(pbooAccelerate: boolean): tstringList;

    { functions componente tamazonstorageservice }
      function isoDateTimenoSeparators: string;
      function buildStringToSignHeaders(Headers: TStringList): string;
      function buildQueryParameterString(const QueryPrefix: string; QueryParameters: TStringList; DoSort: Boolean = False; ForURL: Boolean = True): string;
      function buildStringToSign(const HTTPVerb, Region: string; Headers, QueryParameters: TStringList; const QueryPrefix, URL: string): string;
      function getAuthorization(const accountName, accountKey, stringToSign, dateISO, region, serviceName, signedStrHeaders: string): string;
      function parseResponseError(pstrResponse, pstrResultString: string): string;

      procedure sortHeaders(const Headers: TStringList);
      procedure urlEncodeQueryParams(const ForURL: Boolean; var ParamName, ParamValue: string);
  public
    { public declarations }
    constructor Create(accountName, accountKey, region, bucket: string; accelerate: boolean = false);
    destructor Destroy; override;

    class function new(accountName, accountKey, region, bucket: string; accelerate: boolean = false): ikiwiS3Client;

    property AccountName: string read fstraccountName write fstraccountName;
    property AccountKey: string read fstraccountKey write fstraccountKey;
    property Bucket: string read fstrBucket write fstrBucket;
    property Region: string read fstrRegion write fstrRegion;
    property Accelerate: boolean read fbooAccelerate write fbooAccelerate;

    function get(const pstrObjectName: string; var pstrmResult: tmemorystream; var pstrError: string): boolean;
    function upload(const pstrObjectName: string; var pstrmMemoryFile: tmemorystream; var pstrError: string; pslmetaData: tstrings = nil): boolean;
    function delete(const pstrObjectName: string; var pstrError: string): boolean;

    function properties(pstrObjectName: string; var pstrsProperties, pstrsMetadata: tstringlist): boolean;
  end;

var
  kiwiS3Client: tkiwiS3Client;

implementation

function CaseSensitiveHyphenCompare(List: TStringList; Index1, Index2: Integer): Integer;
begin
  if List <> nil then
    //case sensitive stringSort is needed to sort with hyphen (-) precedence
    Result := string.Compare(List.Strings[Index1], List.Strings[Index2], [coStringSort])
  else
    Result := 0;
end;


{ TAmazonS3 }

function tkiwiS3Client.buildQueryParameterString(const QueryPrefix: string; QueryParameters: TStringList; DoSort, ForURL: Boolean): string;
var
  Count: Integer;
  I: Integer;
  lastParam, nextParam: string;
  QueryStartChar, QuerySepChar, QueryKeyValueSepChar: Char;
  CurrValue: string;
  CommaVal: string;
begin
  try
    //if there aren't any parameters, just return the prefix
    if not Assigned(QueryParameters) or (QueryParameters.Count = 0) then
      Exit(QueryPrefix);

    if ForURL then
    begin
      //If the query parameter string is beign created for a URL, then
      //we use the default characters for building the strings, as will be required in a URL
      QueryStartChar := '?';
      QuerySepChar := '&';
      QueryKeyValueSepChar := '=';
    end
    else
    begin
      //otherwise, use the charaters as they need to appear in the signed string
      QueryStartChar := '?';
      QuerySepChar := '&';
      QueryKeyValueSepChar := '=';
    end;

    {if DoSort and not QueryParameters.Sorted then
      SortQueryParameters(QueryParameters, ForURL);}

    Count := QueryParameters.Count;

    lastParam := QueryParameters.Names[0];
    CurrValue := Trim(QueryParameters.ValueFromIndex[0]);

    //URL Encode the firs set of params
    urlEncodeQueryParams(ForURL, lastParam, CurrValue);

    //there is at least one parameter, so add the query prefix, and then the first parameter
    //provided it is a valid non-empty string name
    Result := QueryPrefix;
    if CurrValue <> EmptyStr then
      Result := Result + Format('%s%s%s%s', [QueryStartChar, lastParam, QueryKeyValueSepChar, CurrValue])
    else
      Result := Result + Format('%s%s', [QueryStartChar, lastParam]);

    //in the URL, the comma character must be escaped. In the StringToSign, it shouldn't be.
    //this may need to be pulled out into a function which can be overridden by individual Cloud services.
    if ForURL then
      CommaVal := '%2c'
    else
      CommaVal := ',';

    //add the remaining query parameters, if any
    for I := 1 to Count - 1 do
    begin
      nextParam := Trim(QueryParameters.Names[I]);
      CurrValue := QueryParameters.ValueFromIndex[I];

      urlEncodeQueryParams(ForURL, nextParam, CurrValue);

      //match on key name only if the key names are not empty string.
      //if there is a key with no value, it should be formatted as in the else block
      if (lastParam <> EmptyStr) and (AnsiCompareText(lastParam, nextParam) = 0) then
        Result := Result + CommaVal + CurrValue
      else begin
        if (not ForURL) or (nextParam <> EmptyStr) then
        begin
          if CurrValue <> EmptyStr then
            Result := Result + Format('%s%s%s%s', [QuerySepChar, nextParam, QueryKeyValueSepChar, CurrValue])
          else
            Result := Result + Format('%s%s', [QuerySepChar, nextParam]);
        end;
        lastParam := nextParam;
      end;
    end;
  except
    raise;
  end;
end;

function tkiwiS3Client.buildStringToSign(const HTTPVerb, Region: string; Headers, QueryParameters: TStringList; const QueryPrefix, URL: string): string;
var
  CanRequest, Scope, LdateISO, Ldate, Lregion : string;
  URLrec : TURI;
  LParams: TStringList;
  VPParam : TNameValuePair;
begin
  //URLrec  := nil;
  LParams := nil;
  try
    try
      //Build the first part of the string to sign, including HTTPMethod
      CanRequest := HTTPVerb+ #10;

      //find and encode the requests resource
      URLrec :=  TURI.Create(URL);

      //CanonicalURI URL encoded
      CanRequest := CanRequest + TNetEncoding.URL.EncodePath(URLrec.Path,
        [Ord('"'), Ord(''''), Ord(':'), Ord(';'), Ord('<'), Ord('='), Ord('>'),
        Ord('@'), Ord('['), Ord(']'), Ord('^'), Ord('`'), Ord('{'), Ord('}'),
        Ord('|'), Ord('/'), Ord('\'), Ord('?'), Ord('#'), Ord('&'), Ord('!'),
        Ord('$'), Ord('('), Ord(')'), Ord(',')]) + #10;

      //CanonicalQueryString encoded
      if not URLrec.Query.IsEmpty then
      begin
        if Length(URLrec.Params) = 1 then
          CanRequest := CanRequest + URLrec.Query + #10
        else
        begin
          LParams := TStringList.Create;
          for VPParam in URLrec.Params do
            LParams.Append(VPParam.Name+'='+VPParam.Value);
          CanRequest := CanRequest + buildQueryParameterString('', LParams,true,false).Substring(1) + #10
        end;
      end
      else
        CanRequest := CanRequest + #10;

      //add sorted headers and header names in series for signedheader part
      CanRequest := CanRequest + buildStringToSignHeaders(Headers) + #10;

      CanRequest := CanRequest + Headers.Values['x-amz-content-sha256'];
      LdateISO :=  Headers.Values['x-amz-date'];
      Ldate :=  Leftstr(LdateISO,8);
      Lregion := Region;
      Scope :=  Ldate + '/'+Lregion+ '/s3' + '/aws4_request';

      Result := 'AWS4-HMAC-SHA256' + #10 + LdateISO + #10 + Scope + #10 + TCloudSHA256Authentication.GetHashSHA256Hex(CanRequest);
    except
      raise;
    end;
  finally
    if LParams <> nil then
      freeandnil(LParams);

    //if URLrec <> nil then
      //freeandnil(URLrec);
  end;
end;

function tkiwiS3Client.buildStringToSignHeaders(Headers: TStringList): string;
var
  RequiredHeadersInstanceOwner: Boolean;
  RequiredHeaders: TStringList;
  I, ReqCount: Integer;
  Aux: string;
  lastParam, nextParam, ConHeadPrefix: string;
begin
  RequiredHeaders := nil;

  try
    try
      //AWS always has required headers
      RequiredHeaders := TStringList.create;
      RequiredHeaders.Add('host');
      RequiredHeaders.Add('x-amz-content-sha256');
      RequiredHeaders.Add('x-amz-date');

      Assert(RequiredHeaders <> nil);
      Assert(Headers <> nil);
      //if (Headers = nil) then
       // Headers.AddStrings(RequiredHeaders);

      //AWS4 - content-type must be included in string to sign if found in headers
      if Headers.IndexOfName('content-type') > -1 then //Headers.Find('content-type',Index) then
        RequiredHeaders.Add('content-type');
      if Headers.IndexOfName('content-md5') > -1 then
        RequiredHeaders.Add('content-md5');
      RequiredHeaders.Sorted := True;
      RequiredHeaders.Duplicates := TDuplicates.dupIgnore;
      ConHeadPrefix := 'x-amz-';{AnsiLowerCase(GetCanonicalizedHeaderPrefix);}
      for I := 0 to Headers.Count - 1 do
      begin
        Aux := AnsiLowerCase(Headers.Names[I]);
        if AnsiStartsStr(ConHeadPrefix, Aux) then
          RequiredHeaders.Add(Aux);
      end;
      RequiredHeaders.Sorted := False;
      //custom sorting
      sortHeaders(RequiredHeaders);
      ReqCount := RequiredHeaders.Count;

       //AWS4 get value pairs (ordered + lowercase)
      if (Headers <> nil) then
      begin
        for I := 0 to ReqCount - 1 do
        begin
          Aux := AnsiLowerCase(RequiredHeaders[I]);
          if Headers.IndexOfName(Aux) < 0 then
            raise Exception.Create('Missing Required Header: '+RequiredHeaders[I]);
          nextParam := Aux;
          if lastParam = EmptyStr then
          begin
            lastParam := nextParam;
            Result := Result + Format('%s:%s', [nextParam, Headers.Values[lastParam]]);
          end
          else
          begin
            lastParam := nextParam;
            Result := Result + Format(#10'%s:%s', [nextParam, Headers.Values[lastParam]]);
          end;
        end;
        if lastParam <> EmptyStr then
          Result := Result + #10'';
      end;

      // string of header names
      Result := Result + #10'';
      for I := 0 to ReqCount - 1 do
      begin
        Result := Result + Format('%s;', [RequiredHeaders[I]]);
      end;

      SetLength(Result,Length(Result)-1);
    except
      raise;
    end;
  finally
    if RequiredHeaders <> nil then
      freeandnil(RequiredHeaders);
  end;
end;

function tkiwiS3Client.buildHeaders(pbooAccelerate: boolean): tstringlist;
begin
  result := TStringList.Create;
  result.CaseSensitive := false;
  result.Duplicates := TDuplicates.dupIgnore;

  if pbooAccelerate then
    result.Values['host'] :=  fstrBucket + '.s3-accelerate.amazonaws.com'
  else
    result.Values['host'] :=  fstrBucket + '.s3.amazonaws.com';

  result.Values['x-amz-content-sha256'] :=  'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'; // empty string
  result.Values['x-amz-date'] := isoDateTimenoSeparators;
  result.Values['x-amz-acl'] := 'private';
end;

constructor tkiwiS3Client.Create(accountName, accountKey, region, bucket: string; accelerate: boolean = false);
begin
  fstraccountName :=  accountName;
  fstraccountKey :=  accountKey;
  fstrBucket := bucket;
  fstrRegion := region;
  fbooAccelerate := accelerate;

  fconnIdhttp  := tidhttp.Create(nil);
  fconnIdhttp.ProtocolVersion := pv1_1;
  fconnIdhttp.Request.ContentType := 'application/octet-stream';
  fconnIdhttp.Request.BasicAuthentication := False;
end;

function tkiwiS3Client.delete(const pstrObjectName: string; var pstrError: string): boolean;
var
  l_str_meta_name     : string;
  l_str_url_file      : string;
  l_str_queryprefix   : string;
  l_str_string_sign   : string;
  l_str_authorization : string;
  l_str_signed_headers: string;

  l_int_count : integer;

  l_sl_headers      : TStringList;
  l_content_stream  : TBytesStream;
begin
  result            := false;

  l_sl_headers      := nil;
  l_content_stream  := nil;

  try
    try

      { create headers }
      l_sl_headers := buildHeaders(false);

      { authorization }
      l_str_url_file    := 'http://'+l_sl_headers.Values['host']+ '/' + pstrObjectName.trim;
      l_str_queryprefix := '/'+ fstrBucket + '/' + pstrObjectName.trim;

      l_str_string_sign := buildStringToSign('DELETE', fstrRegion, l_sl_headers, nil, l_str_queryprefix, l_str_url_file);

      for l_int_count := 0 to l_sl_headers.Count - 1 do
        if AnsiStartsText('x-amz-', l_sl_headers.names[l_int_count]) or (l_sl_headers.names[l_int_count] = 'host') then
          l_str_signed_headers  := l_str_signed_headers + l_sl_headers.names[l_int_count] + ';';

      l_str_signed_headers  := copy(l_str_signed_headers,0, length(l_str_signed_headers)-1);

      l_str_authorization := getAuthorization(fstraccountName,
                                               fstraccountKey,
                                               l_str_string_sign,
                                               formatdatetime('yyyyMMdd', TTimeZone.Local.ToUniversalTime(Now)),
                                               fstrRegion,
                                               's3',
                                               l_str_signed_headers);

      { delete }
      fconnIdhttp.Request.CustomHeaders.Clear;
      fconnIdhttp.Request.BasicAuthentication := False;
      fconnIdhttp.Request.CustomHeaders.Values['Authorization']  :=  l_str_authorization;

      for l_int_count := 0 to l_sl_headers.Count -1 do
        fconnIdhttp.Request.CustomHeaders.values[l_sl_headers.Names[l_int_count]]  := l_sl_headers.ValueFromIndex[l_int_count];

      try
        fconnIdhttp.delete(l_str_url_file, l_content_stream);
      except
      end;

      if fconnIdhttp.Response = nil then
        exit;

      if not(fconnIdhttp.Response.ResponseCode in [100, 200]) then
        pstrError := fconnIdhttp.Response.ResponseText
      else
        result  := true;

    except on
      e: exception do
      begin
        if pstrError.Trim <> ''  then
          pstrError  := pstrError + ', '+ e.message
        else
          pstrError  := e.message;
      end;
    end;
  finally
    if l_sl_headers <> nil then
      freeandnil(l_sl_headers);
  end;
end;

destructor tkiwiS3Client.Destroy;
begin
  if fconnIdhttp <> nil then
    freeandnil(fconnIdhttp);

  inherited;
end;

function tkiwiS3Client.get(const pstrObjectName: string; var pstrmResult: tmemorystream; var pstrError: string): boolean;
var
  lslHeaders: tstringList;
  lintCount: integer;
  lstrUrlFile: string;
  lstrQueryPrefix: string;
  lstrSignedHeaders: string;
  lstrAuthorization: string;
  lstrStringSign: string;
  lconnIdhttp: tidhttp;
begin
  result := false;
  lslHeaders := nil;

  try
    try
      if pstrmResult = nil then
        exit;

      { create headers }
      lslHeaders := buildHeaders(false);

      { authorization }
      lstrUrlFile    := 'http://'+lslHeaders.Values['host']+ '/' + pstrObjectName.trim;
      lstrQueryPrefix := '/'+ fstrBucket + '/' + pstrObjectName.trim;

      lstrStringSign := buildStringToSign('GET', fstrRegion, lslHeaders, nil, lstrQueryPrefix, lstrUrlFile);

      for lintCount := 0 to lslHeaders.Count - 1 do
        if AnsiStartsText('x-amz-', lslHeaders.names[lintCount]) or (lslHeaders.names[lintCount] = 'host') then
          lstrSignedHeaders  := lstrSignedHeaders + lslHeaders.names[lintCount] + ';';

      lstrSignedHeaders  := copy(lstrSignedHeaders,0, length(lstrSignedHeaders)-1);

      lstrAuthorization := getAuthorization(fstraccountName,
                                               fstraccountKey,
                                               lstrStringSign,
                                               formatdatetime('yyyyMMdd', TTimeZone.Local.ToUniversalTime(Now)),
                                               fstrRegion,
                                               's3',
                                               lstrSignedHeaders);

      { get }
      lconnIdhttp := tidhttp.Create(nil);
      lconnIdhttp.ProtocolVersion := pv1_1;
      lconnIdhttp.Request.ContentType := 'application/octet-stream';
      lconnIdhttp.Request.BasicAuthentication := False;
      lconnIdhttp.Request.CustomHeaders.Clear;
      lconnIdhttp.Request.BasicAuthentication := False;
      lconnIdhttp.Request.CustomHeaders.Values['Authorization']  :=  lstrAuthorization;

      for lintCount := 0 to lslHeaders.Count -1 do
        lconnIdhttp.Request.CustomHeaders.values[lslHeaders.Names[lintCount]]  := lslHeaders.ValueFromIndex[lintCount];

      try
        lconnIdhttp.get(lstrUrlFile, pstrmResult, [404]);
      except
      end;

      if lconnIdhttp.Response = nil then
        exit;

      if not(lconnIdhttp.Response.ResponseCode in [100, 200]) then
        pstrError := lconnIdhttp.Response.ResponseText
      else
        result := true;

    except on
      e: exception do
      begin
        if pstrError.Trim <> ''  then
          pstrError := pstrError + ', '+ e.message
        else
          pstrError := e.message;
      end;
    end;
  finally
    if lslHeaders <> nil then
      freeandnil(lslHeaders);

    if lconnIdhttp <> nil then
      freeandnil(lconnIdhttp);
  end;
end;

function tkiwiS3Client.properties(pstrObjectName: string; var pstrsProperties, pstrsMetadata: tstringlist): boolean;
var
  lstrMetaName: string;
  lstrUrlFile: string;
  lstrQueryPrefix: string;
  lstrStringSign: string;
  lstrAuthorization: string;
  lstrSignedHeaders: string;
  lstrHeaderName: string;
  lintCount: integer;
  lslHeaders: tstringList;
begin
  result := false;
  lslHeaders := nil;

  try
    try
      { create headers }
      lslHeaders := buildHeaders(false);

      { authorization }
      lstrUrlFile    := 'http://'+lslHeaders.Values['host']+ '/' + pstrObjectName.trim;
      lstrQueryPrefix := '/'+ fstrBucket + '/' + pstrObjectName.trim;

      lstrStringSign := buildStringToSign('HEAD', fstrRegion, lslHeaders, nil, lstrQueryPrefix, lstrUrlFile);

      for lintCount := 0 to lslHeaders.Count - 1 do
        if AnsiStartsText('x-amz-', lslHeaders.names[lintCount]) or (lslHeaders.names[lintCount] = 'host') then
          lstrSignedHeaders  := lstrSignedHeaders + lslHeaders.names[lintCount] + ';';

      lstrSignedHeaders  := copy(lstrSignedHeaders,0, length(lstrSignedHeaders)-1);

      lstrAuthorization := getAuthorization(fstraccountName,
                                               fstraccountKey,
                                               lstrStringSign,
                                               formatdatetime('yyyyMMdd', TTimeZone.Local.ToUniversalTime(Now)),
                                               fstrRegion,
                                               's3',
                                               lstrSignedHeaders);

      { head }
      fconnIdhttp.Request.CustomHeaders.Clear;
      fconnIdhttp.Request.BasicAuthentication := False;
      fconnIdhttp.Request.CustomHeaders.Values['Authorization']  :=  lstrAuthorization;

      for lintCount := 0 to lslHeaders.Count -1 do
        fconnIdhttp.Request.CustomHeaders.values[lslHeaders.Names[lintCount]]  := lslHeaders.ValueFromIndex[lintCount];

      try
        fconnIdhttp.head(lstrUrlFile);
      except
      end;

      if (fconnIdhttp.Response <> nil) and (fconnIdhttp.Response.ResponseCode = 200) then
      begin
        result  := true;

        if pstrsProperties = nil then
          pstrsProperties := tstringlist.create;

        pstrsProperties.CaseSensitive := false;
        pstrsProperties.Duplicates := TDuplicates.dupIgnore;

        if pstrsMetadata = nil then
          pstrsMetadata := tstringlist.create;

        pstrsMetadata.CaseSensitive := false;
        pstrsMetadata.Duplicates := TDuplicates.dupIgnore;

        for lintCount := 0 to fconnIdhttp.Response.RawHeaders.Count - 1 do
        begin
          lstrHeaderName  := fconnIdhttp.Response.RawHeaders.Names[lintCount];
          if AnsiStartsText('x-amz-meta-', lstrHeaderName ) then
          begin
            //strip the "x-amz-meta-" prefix from the name of the header,
            //to get the original metadata header name, as entered by the user.
            pstrsMetadata.Values[lstrHeaderName.Substring(11)] := fconnIdhttp.Response.RawHeaders.Values[lstrHeaderName];
          end
          else
            pstrsProperties.Values[lstrHeaderName ] := fconnIdhttp.Response.RawHeaders.Values[lstrHeaderName];
        end;
      end;

    except
    end;
  finally
    if lslHeaders <> nil then
      freeandnil(lslHeaders);
  end;
end;

function tkiwiS3Client.getAuthorization(const accountName, accountKey, stringToSign, dateISO, region, serviceName, signedStrHeaders: string): string;

  function SignString(const Signkey: TBytes; const StringToSign: string): TBytes;
  begin
    Result := THashSHA2.GetHMACAsBytes(StringToSign, Signkey);
  end;

  function GetSignatureKey(const accountkey, datestamp, region, serviceName: string): TBytes;
  begin
    Result := SignString(TEncoding.Default.GetBytes('AWS4'+AccountKey), datestamp); //'20130524'
    Result := SignString(Result, region);
    Result := SignString(Result, serviceName);
    Result := SignString(Result, 'aws4_request');
  end;

var
  l_byte_signing_key:  TBytes;
  l_str_Credentials: string;
  l_str_signedheaders: string;
  l_str_signature: string;
begin
  try
    l_byte_signing_key   := GetSignatureKey(accountKey, dateISO, region, serviceName);
    l_str_Credentials   := 'Credential='+accountName + '/'+ dateISO + '/'+region+ '/' + serviceName + '/aws4_request'+',';
    l_str_signedheaders := 'SignedHeaders='+signedStrHeaders + ',';
    l_str_signature     := 'Signature='+THash.DigestAsString(SignString(l_byte_signing_key, stringToSign));

    Result := 'AWS4-HMAC-SHA256 '+ l_str_Credentials + l_str_signedheaders + l_str_signature;
  except
    raise;
  end;
end;

function tkiwiS3Client.isoDateTimenoSeparators: string;
begin
  Result := DateToISO8601(TTimeZone.Local.ToUniversalTime(Now),True);
  Result := StringReplace(Result,'-','',[rfReplaceAll]);
  Result := StringReplace(Result,'+','',[rfReplaceAll]);
  Result := StringReplace(Result,':','',[rfReplaceAll]);
  Result := LeftStr(Result,Pos('.',Result)-1)+'Z';
end;

class function tkiwiS3Client.new(accountName, accountKey, region, bucket: string; accelerate: boolean): ikiwiS3Client;
begin
  result := self.create(accountName, accountKey, region, bucket, accelerate);
end;

function tkiwiS3Client.parseResponseError(pstrResponse, pstrResultString: string): string;
var
  xmlDoc: IXMLDocument;
  Aux, ErrorNode, MessageNode: IXMLNode;
  ErrorCode, ErrorMsg: string;
begin
  //If the ResponseInfo instance exists (to be populated) and the passed in string is Error XML, then
  //continue, otherwise exit doing nothing.
  if (pstrResultString = EmptyStr) then
    Exit;

  if (AnsiPos('<Error', pstrResultString) > 0) then
  begin
    xmlDoc := TXMLDocument.Create(nil);
    try
      xmlDoc.LoadFromXML(pstrResultString);
    except
      //Response content isn't XML
      Exit;
    end;

    //Amazon has different formats for returning errors as XML
    ErrorNode := xmlDoc.DocumentElement;

    if (ErrorNode <> nil) and (ErrorNode.HasChildNodes) then
    begin
      MessageNode := ErrorNode.ChildNodes.FindNode('Message');

      if (MessageNode <> nil) then
        ErrorMsg := MessageNode.Text;

      if ErrorMsg <> EmptyStr then
      begin
        //Populate the error code
        Aux := ErrorNode.ChildNodes.FindNode('Code');
        if (Aux <> nil) then
          ErrorCode := Aux.Text;
        result := Format('%s - %s (%s)', [pstrResponse, ErrorMsg, ErrorCode]);
      end;
    end;
  end
end;

procedure tkiwiS3Client.sortHeaders(const Headers: TStringList);
begin
 if (Headers <> nil) then
  begin
    Headers.CustomSort(CaseSensitiveHyphenCompare);
  end;
end;

function tkiwiS3Client.upload(const pstrObjectName: string; var pstrmMemoryFile: tmemorystream; var pstrError: string; pslmetaData: tstrings = nil): boolean;
var
  lstrMetaName: string;
  lstrUrlFile: string;
  lstrQueryPrefix: string;
  lstrStringSign: string;
  lstrAuthorization: string;
  lstrSignedHeaders: string;
  lstrResultMessage: string;
  lintCount: integer;
  lslHeaders: tstringList;
  lContentStream: tbytesStream;
begin
  result := false;

  lslHeaders := nil;
  lContentStream := nil;

  try
    try
      if pstrmMemoryFile = nil then
        exit;

      { load file }
      lContentStream := TBytesStream.Create;
      pstrmMemoryFile.Position := 0;
      lContentStream.LoadFromstream(pstrmMemoryFile);

      { create headers }
      lslHeaders := buildHeaders(fbooAccelerate);

      lslHeaders.Values['x-amz-content-sha256'] :=  TCloudSHA256Authentication.GetStreamToHashSHA256Hex(lContentStream);
      lslHeaders.Values['content-length'] := lContentStream.Size.tostring;

      if pSlMetaData <> nil then
        for lintCount := 0 to pSlMetaData.Count - 1 do
        begin
          lstrMetaName := pSlMetaData.Names[lintCount];
          if not AnsiStartsText('x-amz-meta-', lstrMetaName) then
            lstrMetaName := 'x-amz-meta-' + lstrMetaName;
          lslHeaders.Values[lstrMetaName] := pSlMetaData.ValueFromIndex[lintCount];
        end;

      { authorization }
      lstrUrlFile    := 'http://'+lslHeaders.Values['host']+ '/' + pstrObjectName.trim;
      lstrQueryPrefix := '/'+ fstrBucket + '/' + pstrObjectName.trim;

      lstrStringSign := buildStringToSign('PUT', fstrRegion, lslHeaders, nil, lstrQueryPrefix, lstrUrlFile);

      for lintCount := 0 to lslHeaders.Count - 1 do
        if AnsiStartsText('x-amz-', lslHeaders.names[lintCount]) or (lslHeaders.names[lintCount] = 'host') then
          lstrSignedHeaders  := lstrSignedHeaders + lslHeaders.names[lintCount] + ';';

      lstrSignedHeaders  := copy(lstrSignedHeaders,0, length(lstrSignedHeaders)-1);

      lstrAuthorization := getAuthorization(fstraccountName,
                                               fstraccountKey,
                                               lstrStringSign,
                                               formatdatetime('yyyyMMdd', TTimeZone.Local.ToUniversalTime(Now)),
                                               fstrRegion,
                                               's3',
                                               lstrSignedHeaders);

      { put }
      fconnIdhttp.Request.CustomHeaders.Clear;
      fconnIdhttp.Request.BasicAuthentication := False;
      fconnIdhttp.Request.CustomHeaders.Values['Authorization']  :=  lstrAuthorization;

      for lintCount := 0 to lslHeaders.Count -1 do
        fconnIdhttp.Request.CustomHeaders.values[lslHeaders.Names[lintCount]]  := lslHeaders.ValueFromIndex[lintCount];

      try
        lContentStream.position := 0;
        lstrResultMessage := fconnIdhttp.put(lstrUrlFile, lContentStream);
      except
      end;

      if fconnIdhttp.Response = nil then
        exit;

      if not(fconnIdhttp.Response.ResponseCode in [100, 200]) then
      begin
        pstrError := parseResponseError(fconnIdhttp.Response.ResponseText,lstrResultMessage);

        if pstrError.trim = '' then
          pstrError  := fconnIdhttp.Response.ResponseText;
      end
      else
        result  := true;
    except on
      e: exception do
      begin
        if pstrError.Trim <> ''  then
          pstrError  := pstrError + ', '+ e.message
        else
          pstrError  := e.message;

        if lstrResultMessage.Trim <> '' then
          pstrError  := pstrError + ', '+ lstrResultMessage;
      end;
    end;
  finally
    if lslHeaders <> nil then
      freeandnil(lslHeaders);

    if lContentStream <> nil then
      freeandnil(lContentStream);
  end;
end;

procedure tkiwiS3Client.urlEncodeQueryParams(const ForURL: Boolean; var ParamName, ParamValue: string);
begin
  ParamName := URLEncode(ParamName, ['=']);
  ParamValue := URLEncode(ParamValue, ['=']);
end;

end.
