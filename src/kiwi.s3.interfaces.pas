unit kiwi.s3.interfaces;

interface

uses
  System.Classes,
  System.Generics.Collections,
  kiwi.s3.types;

type
  ikiwiS3 = interface;

  ikiwiS3ObjectInfo = interface
    ['{72D8B337-8BFC-4768-8979-75F954BBA989}']
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

    property name: string read getname write setname;
    property lastModifield: tdateTime read getlastModifield write setlastModifield;
    property eTag: string read geteTag write seteTag;
    property size: integer read getsize write setsize;
    property ownerID: string read getownerID write setownerID;
    property date: tdatetime read getdate write setdate;
  end;

  ikiwiS3Object = interface
    ['{BAD193E6-0832-4C67-AADB-32E2C587F210}']
    function name(pstrobjectName: string): ikiwiS3Object;
    function get(var strmFileResult: tmemoryStream): ikiwiS3;
    function post(var strmFile: tmemoryStream): ikiwiS3;
    function delete(strFile: string): boolean;
    function properties(var slresultPropertie: tstringlist): ikiwiS3;
  end;

  ikiwiS3Bucket = interface
    ['{32FD45C0-358B-4490-8AB7-BBCA0C6B6918}']
    function name(pstrBucket: string): ikiwiS3Bucket; overload;
    function find(var pListFiles : TList<ikiwiS3ObjectInfo>; pstrFilterOptions: string = ''; pstrFindFile: string = ''): ikiwiS3; overload;
    function &object(pstrFileName: string): ikiwiS3Object; overload;
  end;

  ikiwiS3 = interface
    ['{0968AEE5-DA95-4826-B663-FFC83E7E4162}']
    function bucket(pstrBucket: string): ikiwiS3Bucket; overload;
  end;


  {

    tKiwiS3
      .new(key, privatekey, region)
      .bucket('s3-xdental-dt-00948480-299348228834-')
        .find(objectList);


    tKiwiS3
      .new(key, privatekey, region)
      .bucket('s3-xdental-dt-00948480-299348228834-')
        objects()
          .get()
          .post()
          .delte()
          .property();
  }



implementation

end.
