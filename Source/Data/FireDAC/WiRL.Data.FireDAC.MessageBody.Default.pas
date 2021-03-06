{******************************************************************************}
{                                                                              }
{       WiRL: RESTful Library for Delphi                                       }
{                                                                              }
{       Copyright (c) 2015-2017 WiRL Team                                      }
{                                                                              }
{       https://github.com/delphi-blocks/WiRL                                  }
{                                                                              }
{******************************************************************************}
unit WiRL.Data.FireDAC.MessageBody.Default;

{$I WiRL.inc}

interface

uses
  System.Classes, System.SysUtils, System.Rtti, Data.DB,

  WiRL.Core.Attributes,
  WiRL.Core.Declarations,
  WiRL.http.Accept.MediaType,
  WiRL.Core.Request,
  WiRL.Core.Response,
  WiRL.Core.Classes,
  WiRL.Core.MessageBodyReader,
  WiRL.Core.MessageBodyWriter,
  WiRL.Core.Utils,
  WiRL.Data.Utils;

type
  [Produces(TMediaType.APPLICATION_XML), Produces(TMediaType.APPLICATION_JSON)]
  [Produces(TMediaType.APPLICATION_OCTET_STREAM)]
  TFDAdaptedDataSetWriter = class(TInterfacedObject, IMessageBodyWriter)
    procedure WriteTo(const AValue: TValue; const AAttributes: TAttributeArray;
      AMediaType: TMediaType; AResponse: TWiRLResponse);
  end;

  [Consumes(TMediaType.APPLICATION_XML), Consumes(TMediaType.APPLICATION_JSON)]
  [Consumes(TMediaType.APPLICATION_OCTET_STREAM)]
  TFDAdaptedDataSetReader = class(TInterfacedObject, IMessageBodyReader)
    function ReadFrom(AParam: TRttiParameter;
      AMediaType: TMediaType; ARequest: TWiRLRequest): TValue;
  end;

  [Produces(TMediaType.APPLICATION_JSON)]
  TArrayFDCustomQueryWriter = class(TInterfacedObject, IMessageBodyWriter)
    procedure WriteTo(const AValue: TValue; const AAttributes: TAttributeArray;
      AMediaType: TMediaType; AResponse: TWiRLResponse);
  end;


implementation

uses
  FireDAC.Comp.Client, FireDAC.Stan.Intf, FireDACJSONReflect,
  FireDAC.Stan.StorageBIN, FireDAC.Stan.StorageJSON, FireDAC.Stan.StorageXML,

  WiRL.Core.Exceptions,
  WiRL.Core.JSON,
  WiRL.Rtti.Utils;

{ TArrayFDCustomQueryWriter }

procedure TArrayFDCustomQueryWriter.WriteTo(const AValue: TValue; const
    AAttributes: TAttributeArray; AMediaType: TMediaType; AResponse:
    TWiRLResponse);
var
  LStreamWriter: TStreamWriter;
  LDatasetList: TFDJSONDataSets;
  LCurrent: TFDCustomQuery;
  LResult: TJSONObject;
  LData: TArray<TFDCustomQuery>;
begin
  LStreamWriter := TStreamWriter.Create(AResponse.ContentStream);
  try
    LResult := TJSONObject.Create;
    try
      LDatasetList := TFDJSONDataSets.Create;
      try
        LData := AValue.AsType<TArray<TFDCustomQuery>>;
        if Length(LData) > 0 then
        begin
          for LCurrent in LData do
            TFDJSONDataSetsWriter.ListAdd(LDatasetList, LCurrent.Name, LCurrent);

          if not TFDJSONInterceptor.DataSetsToJSONObject(LDataSetList, LResult) then
            raise Exception.Create('Error serializing datasets to JSON');
        end;

        LStreamWriter.Write(TJSONHelper.ToJSON(LResult));
      finally
        LDatasetList.Free;
      end;
    finally
      LResult.Free;
    end;
  finally
    LStreamWriter.Free;
  end;
end;

{ TFDAdaptedDataSetWriter }

procedure TFDAdaptedDataSetWriter.WriteTo(const AValue: TValue;
  const AAttributes: TAttributeArray; AMediaType: TMediaType; AResponse: TWiRLResponse);
var
  LDataset: TFDAdaptedDataSet;
  LStorageFormat: TFDStorageFormat;
begin
  LDataset := AValue.AsType<TFDAdaptedDataSet>;

  if AMediaType.Matches(TMediaType.APPLICATION_XML) then
    LStorageFormat := sfXML
  else if AMediaType.Matches(TMediaType.APPLICATION_JSON) then
    LStorageFormat := sfJSON
  else if AMediaType.Matches(TMediaType.APPLICATION_OCTET_STREAM) then
    LStorageFormat := sfBinary
  else
    raise EWiRLUnsupportedMediaTypeException.Create(
      Format('Unsupported media type [%s]', [AMediaType.ToString]),
      Self.ClassName, 'WriteTo'
    );

  LDataSet.SaveToStream(AResponse.ContentStream, LStorageFormat);
end;

{ TFDAdaptedDataSetReader }

function TFDAdaptedDataSetReader.ReadFrom(AParam: TRttiParameter;
  AMediaType: TMediaType; ARequest: TWiRLRequest): TValue;
var
  LDataset: TFDMemTable;
begin
  LDataSet := TFDMemTable.Create(nil);
  LDataset.LoadFromStream(ARequest.ContentStream);

  Result := TValue.From<TFDMemTable>(LDataSet);
end;

{ RegisterMessageBodyClasses }

procedure RegisterMessageBodyClasses;
begin

  // TFDAdaptedDataSetWriter
  TMessageBodyWriterRegistry.Instance.RegisterWriter<TFDAdaptedDataSet>(
    TFDAdaptedDataSetWriter, TMessageBodyWriterRegistry.AFFINITY_HIGH
  );

  // TObjectMBReader
  TMessageBodyReaderRegistry.Instance.RegisterReader<TFDAdaptedDataSet>(TFDAdaptedDataSetReader);

  // TArrayFDCustomQueryWriter
  TMessageBodyWriterRegistry.Instance.RegisterWriter(
    TArrayFDCustomQueryWriter,
    function (AType: TRttiType; const AAttributes: TAttributeArray; AMediaType: string): Boolean
    begin
      Result := Assigned(AType) and TRttiHelper.IsDynamicArrayOf<TFDCustomQuery>(AType); // and AMediaType = application/json;dialect=FireDAC
    end,
    function (AType: TRttiType; const AAttributes: TAttributeArray; AMediaType: string): Integer
    begin
      Result := TMessageBodyWriterRegistry.AFFINITY_HIGH
    end
  );

end;

initialization
  RegisterMessageBodyClasses;

end.
