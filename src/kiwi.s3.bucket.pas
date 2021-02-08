unit kiwi.s3.bucket;

interface

uses
  system.classes,
  system.sysutils,
  system.generics.collections,
  data.cloud.amazonapi,
  kiwi.s3.interfaces,
  kiwi.s3.objects,
  kiwi.s3.objectinfo,
  kiwi.s3.consts;

type

  tkiwiS3Bucket = class(tinterfacedobject, ikiwiS3Bucket)
  private
    { private declarations }
    fkiwiS3: ikiwiS3;
    fstrBucket: string;
    fobject: ikiwiS3Object;

    function getbucket: string;
  public
    { public declarations }
    constructor create(pkiwiS3: ikiwiS3; pstraccountName, pstraccountKey: string);
    destructor destroy; override;

    class function new(powner: ikiwiS3; pstraccountName, pstraccountKey: string): ikiwiS3Bucket;

    property bucket: string read getbucket;

    function name(pstrBucket: string): ikiwiS3Bucket;
    function find(var pListFiles : tlist<ikiwiS3ObjectInfo>; pstrFilterOptions: string = ''; pstrFindFile: string = ''): ikiwiS3;
    function &object(pstrobjectName: string): ikiwiS3Object;
  end;

implementation

{ tkiwiS3Bucket }

constructor tkiwiS3Bucket.create(pkiwiS3: ikiwiS3; pstraccountName, pstraccountKey: string);
begin
  fkiwiS3 := pkiwiS3;
  fobject := tkiwiObject.new(pkiwiS3, self);
end;

destructor tkiwiS3Bucket.destroy;
begin

  inherited;
end;

function tkiwiS3Bucket.find(var pListFiles: tlist<ikiwiS3ObjectInfo>; pstrFilterOptions, pstrFindFile: string): ikiwiS3;
var
  lslamazonOptions: tstringList;

  lamazonConnectionInfo : tamazonConnectionInfo;
  lstorageService: tamazonStorageService;
  lamazonBucketResult: tamazonBucketResult;
begin
  result := fkiwiS3;

  lslamazonOptions := nil;

  lamazonConnectionInfo := nil;
  lstorageService       := nil;
  lamazonBucketResult   := nil;

  try
    try
      {Verifica que se passado com parametro o filtro}
      if pstrFilterOptions.trim <> '' then
      begin
        lslAmazonOptions := tstringList.create;
        lslAmazonOptions.append(pstrFilterOptions);
      end;

      { cria componente de conexao com o s3 }
        lamazonConnectionInfo := tamazonConnectionInfo.Create(nil);
        lamazonConnectionInfo.queueEndpoint := cstrKiwiS3QueueEndpoint;
        lAmazonConnectionInfo.accountName := fkiwiS3.accountName;
        lAmazonConnectionInfo.accountKey := fkiwiS3.accountKey;

        lAmazonConnectionInfo.StorageEndpoint := cstrKiwiS3Endpoint;
        lAmazonConnectionInfo.TableEndpoint := cstrKiwiS3TableEndpoint;
        lAmazonConnectionInfo.UseDefaultEndpoints := False;

        lstorageService := tamazonStorageService.create(lamazonConnectionInfo);

      { Carrega lista de arquivos e diretorios do backet com o filtro da Api}
        lamazonBucketResult := lStorageService.GetBucket(fstrBucket, lslAmazonOptions, nil);
        if lslAmazonOptions <> nil then
          freeandnil(lslAmazonOptions);

      {Procura entre os arquivos listado se existe arquivo de atualização e compara se existe atualização para realizar downloa}
        if lamazonBucketResult <> nil then
        begin
          for var ivObject in lAmazonBucketResult.objects do
            if (ivObject.Size > 0) and ((pstrFindFile.trim = '') or (pos(pstrFindFile, ivObject.name) > 0)) then
            begin
              if pListFiles = nil then
                pListFiles := tlist<ikiwiS3ObjectInfo>.create;

              pListFiles.Add(
                            tkiwiS3ObjectInfo.new(
                                                 ivObject.Name,
                                                 strToDateTime(ivObject.LastModified),
                                                 ivObject.ETag,
                                                 ivObject.Size,
                                                 ivObject.ownerid,
                                                 now()
                                                 )
                            );
            end;
        end;
    except
      on E: Exception do
        raise Exception.Create(E.Message);
    end;
  finally
    if lslAmazonOptions <> nil then
      freeandnil(lslAmazonOptions);

    if lAmazonConnectionInfo <> nil then
      freeandnil(lAmazonConnectionInfo);

    if lStorageService <> nil then
      freeandnil(lStorageService);

    if lAmazonBucketResult <> nil then
      freeandnil(lAmazonBucketResult);
  end;
end;

function tkiwiS3Bucket.getbucket: string;
begin
 result := fstrBucket;
end;

function tkiwiS3Bucket.name(pstrBucket: string): ikiwiS3Bucket;
begin
  fstrBucket := pstrBucket;
  result := self;
end;

class function tkiwiS3Bucket.new(powner: ikiwiS3; pstraccountName, pstraccountKey: string): ikiwiS3Bucket;
begin
  result := self.create(powner, pstraccountName, pstraccountKey);
end;

function tkiwiS3Bucket.&object(pstrobjectName: string): ikiwiS3Object;
begin
  result := fobject.name(pstrobjectName);
end;

end.
