unit kiwi.s3.objects;

interface

uses
  System.Classes,
  kiwi.s3.interfaces, System.SysUtils;

type

  tkiwiObject = class(tinterfacedobject, ikiwiS3Object)
  private
    { private declarations }
    fstrFileName: string;
    fowner: ikiwiS3;
  public
    { public declarations }
    constructor create(powner: ikiwiS3);
    destructor destroy; override;

    class function new(powner: ikiwiS3): ikiwiS3Object;

    function name(pstrobjectName: string): ikiwiS3Object;
    function get(var pstrmFileResult: tmemoryStream): ikiwiS3;
    function post(var strmFile: tmemoryStream): ikiwiS3;
    function delete(strFile: string): boolean;
    function properties(var slresultPropertie: tstringlist): ikiwiS3;
  end;

implementation

{ tKiwiObjects }

uses
  kiwi.s3.client;

constructor tkiwiObject.create(powner: ikiwiS3);
begin
  fowner := powner;
  fstrFileName := '';
end;

function tkiwiObject.delete(strFile: string): boolean;
var
  lstrResponse: string;
begin
  result := false;

  try
    if kiwiS3Client <> nil then
    begin
      result := kiwiS3Client.Delete(strFile, lstrResponse);
      if not(result)  then
          Exception.Create(lstrResponse);
    end;
  except
    raise;
  end;
end;

destructor tkiwiObject.destroy;
begin
  fowner := nil;

  inherited;
end;

function tkiwiObject.name(pstrobjectName: string): ikiwiS3Object;
begin
  fstrFileName := pstrobjectName;
  result := self;

end;

function tkiwiObject.get(var pstrmFileResult: tmemoryStream): ikiwiS3;
var
  lstrResponseInfo: string;
begin
  result := fowner;

  try
    if pstrmFileResult = nil then
      pstrmFileResult := tmemoryStream.create
    else
      pstrmFileResult.Clear;

    if not((kiwiS3Client <> nil) and kiwiS3Client.get(fstrFileName, pstrmFileResult, lstrResponseInfo)) then
    begin
      if pstrmFileResult <> nil then
        freeandnil(pstrmFileResult);

      if not(pos('404', lstrResponseInfo) >= 0) then
        raise Exception.Create(lstrResponseInfo);
    end;
  except
    raise;
  end;
end;

class function tkiwiObject.new(powner: ikiwiS3): ikiwiS3Object;
begin
  result := self.create(powner);
end;

function tkiwiObject.post(var strmFile: tmemoryStream): ikiwiS3;
var
  lstrResponseInfo: string;
begin
  result := fowner;

  try
    try
      if strmFile = nil then
        exit;

      if not ((kiwiS3Client <> nil) and kiwiS3Client.Upload(fstrFileName, strmFile, lstrResponseInfo)) then
      begin
        if strmFile <> nil then
          freeandnil(strmFile);

        raise Exception.Create(lstrResponseInfo)
      end;
    except
      raise;
    end;
  finally
  end;
end;

function tkiwiObject.properties(var slresultPropertie: tstringlist): ikiwiS3;
var
  lslProperties: TStringlist;
begin
  result := fowner;
  lslProperties := nil;

  try
    try
      if slresultPropertie = nil then
        slresultPropertie := tstringlist.create;

      if not((kiwiS3Client <> nil) and kiwiS3Client.GetObjectProperties(fstrFileName, lslProperties, slresultPropertie)) then
      begin
        if slresultPropertie <> nil then
          FreeAndNil(slresultPropertie);
      end;
    except
      on E: Exception do
        raise
    end;
  finally
    if lslProperties <> nil then
      freeandnil(lslProperties);
  end;
end;

end.


