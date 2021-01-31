unit kiwi.s3.objects;

interface

uses
  System.Classes,
  System.DateUtils,
  kiwi.s3.interfaces, System.SysUtils;

type

  tkiwiObject = class(tinterfacedobject, ikiwiS3Object)
  private
    { private declarations }
    [weak]
    fkiwiS3: ikiwiS3;
    [weak]
    fkiwiS3Bucket: ikiwiS3Bucket;

    fstrObjectName: string;
  public
    { public declarations }
    constructor create(pikiwiS3: ikiwiS3; pikiwiS3Bucket: ikiwiS3Bucket);
    destructor destroy; override;

    class function new(pikiwiS3: ikiwiS3; pikiwiS3Bucket: ikiwiS3Bucket): ikiwiS3Object;

    function name(pstrobjectName: string): ikiwiS3Object;
    function get(var pstrmFileResult: tmemoryStream): ikiwiS3;
    function post(var strmObject: tmemoryStream): ikiwiS3;
    function delete(strObjectName: string): boolean;
    function properties(var kiwiObjectInfo: ikiwiS3ObjectInfo): ikiwiS3;
  end;

implementation

{ tKiwiObjects }

uses
  kiwi.s3.client, kiwi.s3.objectinfo;

constructor tkiwiObject.create(pikiwiS3: ikiwiS3; pikiwiS3Bucket: ikiwiS3Bucket);
begin
  fkiwiS3 := pikiwiS3;
  fkiwiS3Bucket := pikiwiS3Bucket;

  fstrObjectName := '';
end;

function tkiwiObject.delete(strObjectName: string): boolean;
var
  lstrResponseInfo: string;
begin
  result := false;

  try
    result := tkiwiS3Client
                .new(fkiwiS3.accountName, fkiwiS3.accountKey, fkiwiS3.region, fkiwiS3Bucket.bucket, fkiwiS3.accelerate)
                .delete(strObjectName, lstrResponseInfo);

    if not(result)  then
      exception.create(lstrResponseInfo);
  except
    raise;
  end;
end;

destructor tkiwiObject.destroy;
begin
  fkiwiS3 := nil;
  fkiwiS3Bucket := nil;

  inherited;
end;

function tkiwiObject.name(pstrobjectName: string): ikiwiS3Object;
begin
  fstrObjectName := pstrobjectName;
  result := self;
end;

function tkiwiObject.get(var pstrmFileResult: tmemoryStream): ikiwiS3;
var
  lstrResponseInfo: string;
begin
  result := fkiwiS3;

  try
    if pstrmFileResult = nil then
      pstrmFileResult := tmemoryStream.create
    else
      pstrmFileResult.clear;

    if not( tkiwiS3Client
            .new(fkiwiS3.accountName, fkiwiS3.accountKey, fkiwiS3.region, fkiwiS3Bucket.bucket, fkiwiS3.accelerate)
            .get(fstrObjectName, pstrmFileResult, lstrResponseInfo)
          ) then
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

class function tkiwiObject.new(pikiwiS3: ikiwiS3; pikiwiS3Bucket: ikiwiS3Bucket): ikiwiS3Object;
begin
  result := self.create(pikiwiS3, pikiwiS3Bucket);
end;

function tkiwiObject.post(var strmObject: tmemoryStream): ikiwiS3;
var
  lstrResponseInfo: string;
begin
  result := fkiwiS3;

  try
    try
      if strmObject = nil then
        exit;

      strmObject.position := 0;
      if not (tkiwiS3Client
                .new(fkiwiS3.accountName, fkiwiS3.accountKey, fkiwiS3.region, fkiwiS3Bucket.bucket, fkiwiS3.accelerate)
                .upload(fstrObjectName, strmObject, lstrResponseInfo)
              ) then
      begin
        if strmObject <> nil then
          freeandnil(strmObject);

        raise Exception.Create(lstrResponseInfo)
      end;
    except
      raise;
    end;
  finally
  end;
end;

function tkiwiObject.properties(var kiwiObjectInfo: ikiwiS3ObjectInfo): ikiwiS3;

    function gmttoDateTime(const value: string): tdatetime;
    var
      lstrValue: string;
    const
      cDaysOfWeekEn: array [1 .. 7] of string = ('Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun');
      cMonthsOfYearEn: array [1 .. 12] of string = ('Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec');
    begin
      result := 0;

      if value.trim = '' then
        exit;

      lstrValue := value;
      lstrValue := stringreplace(lstrValue, ' GMT', '', [rfReplaceAll]);
      lstrValue := stringreplace(lstrValue, 'GMT', '', [rfReplaceAll]);

      for var intCount := Low(cDaysOfWeekEn) to High(cDaysOfWeekEn) do
      begin
        lstrValue := stringreplace(lstrValue, cDaysOfWeekEn[intCount] + ', ', '', [rfReplaceAll]);
        lstrValue := stringreplace(lstrValue, cDaysOfWeekEn[intCount] + ' ', '', [rfReplaceAll]);
        lstrValue := stringreplace(lstrValue, cDaysOfWeekEn[intCount], '', [rfReplaceAll]);
      end;

      for var intCount := Low(cMonthsOfYearEn) to High(cMonthsOfYearEn) do
      begin
        lstrValue := stringreplace(lstrValue, ' ' + cMonthsOfYearEn[intCount] + ' ', '/' + intCount.ToString + '/', [rfReplaceAll]);
        lstrValue := stringreplace(lstrValue, cMonthsOfYearEn[intCount], '/' + intCount.ToString + '/', [rfReplaceAll]);
      end;

      try
        result := strtodatetime(lstrValue);
      except
      end;
    end;

var
  lslproperties: tstringlist;
  lslmetaData: tstringlist;
begin
  result := fkiwiS3;
  lslproperties := nil;
  lslmetaData := nil;

  try
    try
      if  tkiwiS3Client
            .new(fkiwiS3.accountName, fkiwiS3.accountKey, fkiwiS3.region, fkiwiS3Bucket.bucket, fkiwiS3.accelerate)
             .properties(fstrObjectName, lslproperties, lslmetaData) then
      begin
        kiwiObjectInfo := tkiwiS3ObjectInfo.new(
                                         fstrObjectName,
                                         gmttoDateTime(lslproperties.values['Last-Modified']),
                                         lslproperties.values['ETag'],
                                         0,
                                         lslproperties.values['x-amz-id-2'],
                                         gmttoDateTime(lslproperties.values['Date'])
                                        );
      end;
    except
      on E: Exception do
        raise
    end;
  finally
    if lslProperties <> nil then
      freeandnil(lslProperties);

    if lslmetaData <> nil then
      freeandnil(lslmetaData);
  end;
end;

end.


