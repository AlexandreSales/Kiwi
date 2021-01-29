unit kiwi.s3.objectinfo;

interface

uses kiwi.s3.interfaces;

type

  tkiwiS3ObjectInfo = class(tinterfacedobject, ikiwiS3ObjectInfo)
  private
    { private declarations }
    fname: string;
    flastModifield: tdateTime;
    feTag: string;
    fsize: integer;
    fownerID: string;
    fdate: tdatetime;

    procedure setname(const value: string);
    procedure setlastModifield(const value: tdateTime);
    procedure seteTag(const value: string);
    procedure setsize(const value: integer);
    procedure setownerID(const value: string);
    procedure setdate(const value: tdatetime);

    function getname: string;
    function getlastModifield: tdateTime;
    function geteTag: string;
    function getsize: integer;
    function getownerID: string;
    function getdate: tdateTime;
  public
    { public declarations }
    constructor create(pname: string = ''; plastModifield: tdatetime = 0; peTag: string = ''; psize: integer = 0;
      pownerID: string = ''; pdate: tdatetime = 0);
    destructor destroy;

    class function new(pname: string = ''; plastModifield: tdatetime = 0; peTag: string = ''; psize: integer = 0;
      pownerID: string = ''; pdate: tdatetime = 0): tkiwiS3ObjectInfo;

    property name: string read getname write setname;
    property lastModifield: tdateTime read getlastModifield write setlastModifield;
    property eTag: string read geteTag write seteTag;
    property size: integer read getsize write setsize;
    property ownerID: string read getownerID write setownerID;
    property date: tdatetime read getdate write setdate;
  end;

implementation

{ tKiwiFile }

constructor tkiwiS3ObjectInfo.create(pname: string; plastModifield: tdatetime; peTag: string; psize: integer; pownerID: string;
  pdate: tdatetime);
begin
  fname := pname;
  flastModifield := plastModifield;
  feTag := peTag;
  fsize := psize;
  fownerID := pownerID;
  fdate := pdate;
end;

destructor tkiwiS3ObjectInfo.destroy;
begin
  fname := '';
  flastModifield := 0;
  feTag := '';
  fsize := 0;
  fownerID := '';
  fdate := 0;
end;

function tkiwiS3ObjectInfo.getdate: tdateTime;
begin
  result := fdate;
end;

function tkiwiS3ObjectInfo.geteTag: string;
begin
  result := feTag;
end;

function tkiwiS3ObjectInfo.getlastModifield: tdateTime;
begin
  result := flastModifield;
end;

function tkiwiS3ObjectInfo.getname: string;
begin
  result := fname;
end;

function tkiwiS3ObjectInfo.getownerID: string;
begin
  result := fownerID;
end;

function tkiwiS3ObjectInfo.getsize: integer;
begin
  result := fsize;
end;

class function tkiwiS3ObjectInfo.new(pname: string; plastModifield: tdatetime; peTag: string; psize: integer;
  pownerID: string; pdate: tdatetime): tkiwiS3ObjectInfo;
begin
  result := self.create(pname, plastModifield, peTag, psize, pownerID, pdate);
end;

procedure tkiwiS3ObjectInfo.setdate(const value: tdatetime);
begin
  fdate := value;
end;

procedure tkiwiS3ObjectInfo.seteTag(const value: string);
begin
  feTag := value;
end;

procedure tkiwiS3ObjectInfo.setlastModifield(const value: tdateTime);
begin
  flastModifield := value;
end;

procedure tkiwiS3ObjectInfo.setname(const value: string);
begin
  fname := value;
end;

procedure tkiwiS3ObjectInfo.setownerID(const value: string);
begin
  fownerID := value;
end;

procedure tkiwiS3ObjectInfo.setsize(const value: integer);
begin
  fsize := value;
end;

end.
