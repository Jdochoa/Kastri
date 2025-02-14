unit DW.FilesSelector.iOS;

{*******************************************************}
{                                                       }
{                      Kastri                           }
{                                                       }
{         Delphi Worlds Cross-Platform Library          }
{                                                       }
{  Copyright 2020-2023 Dave Nottage under MIT license   }
{  which is located in the root folder of this library  }
{                                                       }
{*******************************************************}

{$I DW.GlobalDefines.inc}

interface

uses
  // macOS
  Macapi.ObjectiveC, 
  // iOS
  iOSapi.Foundation, iOSapi.UIKit, iOSapi.CocoaTypes, iOSapi.AVFoundation,
  // DW
  DW.iOSapi.Foundation, DW.iOSapi.UIKit, DW.iOSapi.PhotosUI, DW.FilesSelector;

type
  IItemProviderHandler = interface(IInterface)
    ['{667E818A-3BED-42E6-8A5A-EDEE4C332622}']
  end;

  TItemProviderHandlers = TArray<IItemProviderHandler>;

  TPlatformFilesSelector = class;

  // iOS 14+
  TPHPickerViewControllerDelegate = class(TOCLocal, PHPickerViewControllerDelegate)
  private
    FController: PHPickerViewController;
    FItemProviderHandlers: TItemProviderHandlers;
    FSelector: TPlatformFilesSelector;
    procedure DestroyController;
    procedure RemoveItemProviderHandler(const AHandler: IItemProviderHandler);
  protected
    procedure HandleAVAsset(const AHandler: IItemProviderHandler; const AFileName: string; const AAsset: AVAsset);
    procedure HandleUIImage(const AHandler: IItemProviderHandler; const AFileName: string; const AImage: UIImage);
  public
    { PHPickerViewControllerDelegate }
    procedure picker(picker: PHPickerViewController; didFinishPicking: NSArray); cdecl;
  public
    constructor Create(const ASelector: TPlatformFilesSelector);
    destructor Destroy; override;
    procedure ShowPicker;
  end;

  TUIImagePickerControllerDelegate = class(TOCLocal, UIImagePickerControllerDelegate)
  private
    FController: UIImagePickerController;
    FSelectedCount: Integer;
    FSelector: TPlatformFilesSelector;
    procedure DestroyController;
    // function GetImageRotation(const AImage: UIImage): Single;
  public
    { UIImagePickerControllerDelegate }
    procedure imagePickerController(picker: UIImagePickerController; didFinishPickingMediaWithInfo: NSDictionary); overload; cdecl;
    procedure imagePickerController(picker: UIImagePickerController; didFinishPickingImage: UIImage; editingInfo: NSDictionary); overload; cdecl; // API_DEPRECATED("", ios(2.0, 3.0))
    procedure imagePickerControllerDidCancel(picker: UIImagePickerController); cdecl;
  public
    constructor Create(const ASelector: TPlatformFilesSelector);
    destructor Destroy; override;
    procedure ShowPicker;
  end;

  TUIDocumentPickerDelegate = class(TOCLocal, UIDocumentPickerDelegate)
  private
    FController: UIDocumentPickerViewController;
    FSelector: TPlatformFilesSelector;
    procedure DestroyController;
  public
    { UIDocumentPickerDelegate }
    procedure documentPicker(controller: UIDocumentPickerViewController; didPickDocumentsAtURLs: NSArray); overload; cdecl;
    procedure documentPicker(controller: UIDocumentPickerViewController; didPickDocumentAtURL: NSURL); overload; cdecl;
    procedure documentPickerWasCancelled(controller: UIDocumentPickerViewController); cdecl;
  public
    constructor Create(const ASelector: TPlatformFilesSelector);
    destructor Destroy; override;
    procedure ShowPicker;
  end;

  TPlatformFilesSelector = class(TCustomPlatformFilesSelector)
  private
    FDocumentPicker: TUIDocumentPickerDelegate;
    FImagePicker: TUIImagePickerControllerDelegate;
    FPhotoPicker: TPHPickerViewControllerDelegate;
    FUTIs: TArray<string>;
    function GetUTI(const AFileKind: TFileKind): string;
    procedure HandleAVAsset(const AFileName: string; const AAsset: AVAsset);
    procedure HandleUIImage(const AFileName: string; const AImage: UIImage);
    procedure ShowDocumentPicker;
    procedure ShowImagePicker;
    procedure ShowPhotoPicker;
  protected
    procedure DoSelect(const AMode: TSelectionMode); override;
    procedure FileKindsChanged; override;
    procedure FileTypesChanged; override;
    property UTIs: TArray<string> read FUTIs;
  public
    constructor Create(const ASelector: TFilesSelector); override;
    destructor Destroy; override;
  end;

implementation

uses
  DW.OSLog,
  // RTL
  System.IOUtils, System.SysUtils, System.Classes,
  // macOS
  Macapi.Helpers,
  // iOS
  iOSapi.Helpers, iOSapi.CoreGraphics,
  // DW
  DW.Macapi.Helpers;

type
  TItemProviderHandler = class(TInterfacedObject, IItemProviderHandler)
  private
    FDelegate: TPHPickerViewControllerDelegate;
    FFileName: string;
    procedure LoadObjectUIImageCompletionHandler(AObject: Pointer; AError: NSError);
    procedure LoadObjectAVAssetCompletionHandler(AObject: Pointer; AError: NSError);
  public
    constructor Create(const ADelegate: TPHPickerViewControllerDelegate; const AItemProvider: NSItemProvider);
  end;

  TMemoryStreamHelper = class helper for TMemoryStream
  public
    procedure LoadUIImageAsJPEG(const AImage: UIImage);
  end;

function UIImagePickerControllerImageURL: UIImagePickerControllerInfoKey;
begin
  Result := CocoaNSStringConst(libUIKit, 'UIImagePickerControllerImageURL');
end;

{ TMemoryStreamHelper }

procedure TMemoryStreamHelper.LoadUIImageAsJPEG(const AImage: UIImage);
var
  LData: NSData;
begin
  LData := TNSData.Wrap(UIImageJPEGRepresentation(NSObjectToID(AImage), 1));
  Clear;
  Write(LData.bytes^, LData.length);
end;

{ TItemProviderHandler }

constructor TItemProviderHandler.Create(const ADelegate: TPHPickerViewControllerDelegate; const AItemProvider: NSItemProvider);
begin
  inherited Create;
  FDelegate := ADelegate;
  FFileName := NSStrToStr(AItemProvider.suggestedName);
  if AItemProvider.canLoadObjectOfClass(TUIImage.OCClass.&class) then
    AItemProvider.loadObjectOfClass(TUIImage.OCClass.&class, LoadObjectUIImageCompletionHandler)
  else if AItemProvider.canLoadObjectOfClass(TAVAsset.OCClass.&class) then
    AItemProvider.loadObjectOfClass(TAVAsset.OCClass.&class, LoadObjectAVAssetCompletionHandler);
end;

procedure TItemProviderHandler.LoadObjectAVAssetCompletionHandler(AObject: Pointer; AError: NSError);
begin
  if (AError = nil) or (AError.code = 0) then
    FDelegate.HandleAVAsset(Self, FFileName, TAVAsset.Wrap(AObject));
end;

procedure TItemProviderHandler.LoadObjectUIImageCompletionHandler(AObject: Pointer; AError: NSError);
begin
  if (AError = nil) or (AError.code = 0) then
    FDelegate.HandleUIImage(Self, FFileName, TUIImage.Wrap(AObject));
end;

{ TPHPickerViewControllerDelegate }

constructor TPHPickerViewControllerDelegate.Create(const ASelector: TPlatformFilesSelector);
begin
  inherited Create;
  FSelector := ASelector;
end;

destructor TPHPickerViewControllerDelegate.Destroy;
begin
  DestroyController;
  inherited;
end;

procedure TPHPickerViewControllerDelegate.DestroyController;
begin
  FController := nil;
end;

procedure TPHPickerViewControllerDelegate.HandleAVAsset(const AHandler: IItemProviderHandler; const AFileName: string; const AAsset: AVAsset);
begin
  FSelector.HandleAVAsset(AFileName, AAsset);
  RemoveItemProviderHandler(AHandler);
end;

procedure TPHPickerViewControllerDelegate.HandleUIImage(const AHandler: IItemProviderHandler; const AFileName: string; const AImage: UIImage);
begin
  FSelector.HandleUIImage(AFileName, AImage);
  RemoveItemProviderHandler(AHandler);
end;

procedure TPHPickerViewControllerDelegate.picker(picker: PHPickerViewController; didFinishPicking: NSArray);
var
  I: Integer;
  LItemProvider: NSItemProvider;
begin
  picker.dismissModalViewControllerAnimated(True);
  for I := 0 to didFinishPicking.count - 1 do
  begin
    LItemProvider := TPHPickerResult.Wrap(didFinishPicking.objectAtIndex(I)).itemProvider;
    FItemProviderHandlers := FItemProviderHandlers + [TItemProviderHandler.Create(Self, LItemProvider)];
  end;
end;

procedure TPHPickerViewControllerDelegate.RemoveItemProviderHandler(const AHandler: IItemProviderHandler);
var
  I: Integer;
begin
  for I := 0 to Length(FItemProviderHandlers) - 1 do
  begin
    if FItemProviderHandlers[I] = AHandler then
    begin
      FItemProviderHandlers[I] := nil;
      Delete(FItemProviderHandlers, I, 1);
      Break;
    end;
  end;
end;

procedure TPHPickerViewControllerDelegate.ShowPicker;
var
  LConfiguration: PHPickerConfiguration;
begin
  DestroyController;
  LConfiguration := TPHPickerConfiguration.Create;
  LConfiguration.setSelectionLimit(FSelector.SelectionLimit);
  FController := TPHPickerViewController.Alloc;
  FController := TPHPickerViewController.Wrap(FController.initWithConfiguration(LConfiguration));
  FController.setDelegate(GetObjectID);
  FController.setTitle(StrToNSStr(FSelector.Title));
  TiOSHelper.SharedApplication.keyWindow.rootViewController.presentViewController(FController, True, nil);
end;

{ TUIImagePickerControllerDelegate }

constructor TUIImagePickerControllerDelegate.Create(const ASelector: TPlatformFilesSelector);
begin
  inherited Create;
  FSelector := ASelector;
end;

destructor TUIImagePickerControllerDelegate.Destroy;
begin
  DestroyController;
  inherited;
end;

procedure TUIImagePickerControllerDelegate.DestroyController;
begin
  FController := nil;
end;

{
function TUIImagePickerControllerDelegate.GetImageRotation(const AImage: UIImage): Single;
begin
  case AImage.imageOrientation of
    UIImageOrientationDown,
    UIImageOrientationDownMirrored:
      Result := 180;
    UIImageOrientationLeft,
    UIImageOrientationLeftMirrored:
      Result := -90;
    UIImageOrientationRight,
    UIImageOrientationRightMirrored:
      Result := 90;
    UIImageOrientationUp,
    UIImageOrientationUpMirrored:
      Result := 0;
  else
    Result := 0;
  end;
end;
}

procedure TUIImagePickerControllerDelegate.imagePickerController(picker: UIImagePickerController; didFinishPickingMediaWithInfo: NSDictionary);
var
  LObject: Pointer;
  LFileName: string;
  LImage: UIImage;
begin
  LFileName := '';
  LObject := didFinishPickingMediaWithInfo.objectForKey(NSObjectToID(UIImagePickerControllerImageURL));
  if LObject <> nil then
    LFileName := NSStrToStr(TNSURL.Wrap(LObject).lastPathComponent);
  LObject := didFinishPickingMediaWithInfo.objectForKey(NSObjectToID(UIImagePickerControllerEditedImage));
  if LObject = nil then
    LObject := didFinishPickingMediaWithInfo.objectForKey(NSObjectToID(UIImagePickerControllerOriginalImage));
  if LObject <> nil then
  begin
    Inc(FSelectedCount);
    LImage := TUIImage.Wrap(LObject);
    FSelector.HandleUIImage(LFileName, LImage);
  end;
  if FSelector.IsSelectionLimit(FSelectedCount) then
    picker.dismissModalViewControllerAnimated(True);
end;

procedure TUIImagePickerControllerDelegate.imagePickerController(picker: UIImagePickerController; didFinishPickingImage: UIImage;
  editingInfo: NSDictionary);
var
  LObject: Pointer;
  LFileName: string;
begin
  picker.dismissModalViewControllerAnimated(True);
  LObject := editingInfo.objectForKey(NSObjectToID(UIImagePickerControllerImageURL));
  if LObject <> nil then
    LFileName := NSStrToStr(TNSURL.Wrap(LObject).lastPathComponent);
  FSelector.HandleUIImage(LFileName, didFinishPickingImage);
  Inc(FSelectedCount);
  if FSelector.IsSelectionLimit(FSelectedCount) then
    picker.dismissModalViewControllerAnimated(True);
end;

procedure TUIImagePickerControllerDelegate.imagePickerControllerDidCancel(picker: UIImagePickerController);
begin
  picker.dismissModalViewControllerAnimated(True);
end;

procedure TUIImagePickerControllerDelegate.ShowPicker;
begin
  FSelectedCount := 0;
  DestroyController;
  FController := TUIImagePickerController.Create;
  FController.setDelegate(GetObjectID);
  FController.setTitle(StrToNSStr(FSelector.Title));
  TiOSHelper.SharedApplication.keyWindow.rootViewController.presentViewController(FController, True, nil);
end;

// https://escapetech.eu/manuals/qdrop/uti.html
// "public.image", "public.audio", "public.movie", "public.text", "public.item", "public.content", "public.source-code"

{ TUIDocumentPickerDelegate }

constructor TUIDocumentPickerDelegate.Create(const ASelector: TPlatformFilesSelector);
begin
  inherited Create;
  FSelector := ASelector;
end;

destructor TUIDocumentPickerDelegate.Destroy;
begin
  DestroyController;
  inherited;
end;

procedure TUIDocumentPickerDelegate.DestroyController;
begin
  FController := nil;
end;

procedure TUIDocumentPickerDelegate.ShowPicker;
begin
  DestroyController;
  FController := TUIDocumentPickerViewController.Alloc;
  FController := TUIDocumentPickerViewController.Wrap(FController.initWithDocumentTypes(StringArrayToNSArray(FSelector.UTIs), UIDocumentPickerModeImport));
  FController.setAllowsMultipleSelection(True);
  FController.setDelegate(GetObjectID);
  FController.setTitle(StrToNSStr(FSelector.Title));
  TiOSHelper.SharedApplication.keyWindow.rootViewController.presentViewController(FController, True, nil);
end;

procedure TUIDocumentPickerDelegate.documentPicker(controller: UIDocumentPickerViewController; didPickDocumentAtURL: NSURL);
begin
  //
end;

procedure TUIDocumentPickerDelegate.documentPicker(controller: UIDocumentPickerViewController; didPickDocumentsAtURLs: NSArray);
var
  I: Integer;
  LEscapedFileName: NSString;
  LSelectedFile: TSelectedFile;
begin
  for I := 0 to didPickDocumentsAtURLs.count - 1 do
  begin
    LEscapedFileName := TNSURL.Wrap(didPickDocumentsAtURLs.objectAtIndex(I)).path.stringByReplacingPercentEscapesUsingEncoding(NSUTF8StringEncoding);
    LSelectedFile.DecodedPath := NSStrToStr(LEscapedFileName);
    LSelectedFile.RawPath := NSStrToStr(TNSURL.Wrap(didPickDocumentsAtURLs.objectAtIndex(I)).path);
    LSelectedFile.DisplayName := TPath.GetFileName(LSelectedFile.DecodedPath);
    FSelector.AddSelectedFile(LSelectedFile);
  end;
  FSelector.DoComplete(True);
end;

procedure TUIDocumentPickerDelegate.documentPickerWasCancelled(controller: UIDocumentPickerViewController);
begin
  FSelector.DoComplete(False);
end;

{ TPlatformFilesSelector }

constructor TPlatformFilesSelector.Create(const ASelector: TFilesSelector);
begin
  inherited;
  FileKindsChanged;
end;

destructor TPlatformFilesSelector.Destroy;
begin
  FDocumentPicker.Free;
  inherited;
end;

procedure TPlatformFilesSelector.DoSelect(const AMode: TSelectionMode);
begin
  // FPicker.ShowPicker;
  if TFileKind.Photo in FileKinds then
  begin
    if TOSVersion.Check(14) then
      ShowPhotoPicker
    else
      ShowImagePicker;
  end
  else
    ShowDocumentPicker;
end;

procedure TPlatformFilesSelector.FileKindsChanged;
var
  LFileKind: TFileKind;
begin
  FUTIs := [];
  for LFileKind := Low(TFileKind) to High(TFileKind) do
  begin
    if (LFileKind in FileKinds) or (FileKinds = []) then
      FUTIs := FUTIs + [GetUTI(LFileKind)];
  end;
end;

procedure TPlatformFilesSelector.FileTypesChanged;
begin
  FUTIs := FFileTypes.ToStringArray;
end;

function TPlatformFilesSelector.GetUTI(const AFileKind: TFileKind): string;
begin
  case AFileKind of
    TFileKind.Image:
      Result := 'public.image';
    TFileKind.Audio:
      Result := 'public.audio';
    TFileKind.Movie:
      Result := 'public.movie';
    TFileKind.Text:
      Result := 'public.text';
    TFileKind.Item, TFileKind.Key: // Apparently .item will work for .key files?
      Result := 'public.item';
    TFileKind.Content:
      Result := 'public.content';
    TFileKind.X509Certificate:
      Result := 'public.x509-certificate';
    TFileKind.SourceCode:
      Result := 'public.source-code';
    TFileKind.PDF:
      Result := 'com.adobe.pdf';
  else
    Result := 'public.item';
  end;
end;

procedure TPlatformFilesSelector.HandleAVAsset(const AFileName: string; const AAsset: AVAsset);
begin
  // Ouch - here, the AVAsset needs to be exported using AVAssetExportSession
  TOSLog.d('HandleAVAsset is yet to be implemented');
end;

procedure TPlatformFilesSelector.HandleUIImage(const AFileName: string; const AImage: UIImage);
var
  LStream: TStream;
  LData: NSData;
  LImage: UIImage;
begin
  if AImage.imageOrientation <> UIImageOrientationUp then
  begin
    UIGraphicsBeginImageContextWithOptions(AImage.size, False, AImage.scale);
    try
      AImage.drawInRect(CGRectMake(0, 0, AImage.size.width, AImage.size.height));
      LImage := TUIImage.Wrap(UIGraphicsGetImageFromCurrentImageContext);
    finally
      UIGraphicsEndImageContext;
    end;
  end
  else
    LImage := AImage;
  // Note: This operation makes the image lose its metadata - I think :-)
  LData := TNSData.Wrap(UIImageJPEGRepresentation(NSObjectToID(LImage), 1));
  LStream := TMemoryStream.Create;
  try
    LStream.Write(LData.bytes^, LData.length);
    TThread.Synchronize(nil, procedure begin DoImageStream(AFileName, LStream); end);
  finally
    LStream.Free;
  end;
end;

procedure TPlatformFilesSelector.ShowDocumentPicker;
begin
  if FDocumentPicker = nil then
    FDocumentPicker := TUIDocumentPickerDelegate.Create(Self);
  FDocumentPicker.ShowPicker;
end;

procedure TPlatformFilesSelector.ShowImagePicker;
begin
  if FImagePicker = nil then
    FImagePicker := TUIImagePickerControllerDelegate.Create(Self);
  FImagePicker.ShowPicker;
end;

procedure TPlatformFilesSelector.ShowPhotoPicker;
begin
  if FPhotoPicker = nil then
    FPhotoPicker := TPHPickerViewControllerDelegate.Create(Self);
  FPhotoPicker.ShowPicker;
end;

end.
