unit kiwi.s3;


interface

uses
  System.Classes,
  System.Zip,
  System.SysUtils,
  System.Generics.Collections,
  Data.Cloud.AmazonApi,
  Data.Cloud.CloudApi,

  kiwi.s3.interfaces,
  kiwi.s3.bucket,
  kiwi.s3.client,
  kiwi.s3.types;

type

  tkiwiS3 = class(tinterfacedobject, ikiwiS3)
  private
    { private declarations }
    fstraccountName: string;
    fstraccountKey: string;
    fstrRegion: string;
    fbooAccelerate: boolean;

    fbucket: ikiwiS3Bucket;
  public
    { public delcarations }
    constructor create(pstraccountName: string = ''; pstraccountKey: string = ''; pstrRegion: string = ''; pbooAccelerate: boolean = false);
    destructor destroy; override;

    class function new(pstraccountName: string = ''; pstraccountKey: string = ''; pstrRegion: string = ''; pbooAccelerate: boolean = false): ikiwiS3;
    function bucket(pstrBucket: string): ikiwiS3Bucket;
  end;

implementation

{ tkiwi }

function tkiwiS3.bucket(pstrBucket: string): ikiwiS3Bucket;
begin
  result := fbucket.name(pstrBucket);
end;

constructor tkiwiS3.create(pstraccountName: string = ''; pstraccountKey: string = ''; pstrRegion: string = ''; pbooAccelerate: boolean = false);
begin
  fstraccountName := pstraccountName;
  fstraccountKey := pstraccountKey;
  fstrRegion := pstrRegion;
  fbucket := tkiwiS3Bucket.create(self, fstraccountName, fstraccountKey);
end;

destructor tkiwiS3.destroy;
begin
  if kiwiS3Client <> nil then
    FreeAndNil(kiwiS3Client);

  inherited;
end;

class function tkiwiS3.new(pstraccountName: string = ''; pstraccountKey: string = ''; pstrRegion: string = ''; pbooAccelerate: boolean = false): ikiwiS3;
begin
  result := self.create(pstraccountName, pstraccountKey, pstrRegion, pbooAccelerate);
end;

end.
