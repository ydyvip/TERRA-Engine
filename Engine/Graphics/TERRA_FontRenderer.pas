Unit TERRA_FontRenderer;

{$I terra.inc}

Interface
Uses TERRA_Object, TERRA_String, TERRA_Utils, TERRA_Color, TERRA_Vector2D, TERRA_Matrix3x3, TERRA_Matrix4x4,
  TERRA_Resource, TERRA_Texture, TERRA_Font, TERRA_Sprite, TERRA_ClipRect, TERRA_Image, TERRA_Viewport;

Const
  fontEffectBegin = '[';
  fontEffectEnd = ']';

  MaxStackedFontEffects = 16;

Type
  TextAlign = (
    TextAlign_Left,
    TextAlign_Right,
    TextAlign_Center,
    TextAlign_Justify
  );


  TERRAFontCharStyle = Record
    WavyText:Boolean;
    Bold:Boolean;
    Italics:Boolean;
    Underline:Boolean;
    StrikeThrough:Boolean;
    Link:TERRAString;
    Color:ColorRGBA;
    Texture:TERRATexture;
  End;

  TERRAFontCommand = Record
    Value:TERRAChar;
    X:Single;
    Y:Single;
    Width:Single;
    Height:Single;
    Glyph:FontGlyph;
    StyleID:Cardinal;
    LineID:Cardinal;
  End;

  TERRAFontRendererLine = Record
    Width:Single;
    Spaces:Integer;
  End;

  TERRAFontRenderer = Class(TERRAObject)
    Protected
      _Transform:Matrix3x3;

      _ClipRect:TERRAClipRect;

      _Align:TextAlign;

      _Font:TERRAFont;
      _FontOffset:Single;

      _ColorBase:ColorRGBA;
      _ColorLeft:ColorRGBA;
      _ColorRight:ColorRGBA;
      _ColorTop:ColorRGBA;
      _ColorBottom:ColorRGBA;

      _VerticalGradient:Boolean;
      _HorizontalGradient:Boolean;

      _Outline:ColorRGBA;
      _Glow:ColorRGBA;

      _Width:Single;
      _Height:Single;

      _MaxWidth:Single;
      _MaxHeight:Single;

      _MaxX:Single;
      _MaxY:Single;

      _NewLineOffset:Single;

      _AutoWrap:Boolean;

      _CharLimit:Integer;

      _LastAllocFrame:Cardinal;
      _Sprites:Array Of FontSprite;
      _SpriteCount:Integer;

      _Size:Single;
      _Scale:Single;

      _CharList:Array Of TERRAFontCommand;
      _CharCount:Integer;

      _LineCount:Integer;
      _Lines:Array Of TERRAFontRendererLine;

      _StylesList:Array Of TERRAFontCharStyle;
      _StyleCount:Integer;

      _Pattern:TERRATexture;

      Function AllocSprite():FontSprite;

      Function ResolveTexture(Const TextureName:TERRAString):TERRATexture; Virtual;

      Procedure QueueChar(Const Value:TERRAChar; Var X:Single; Const Y, Width, Height:Single);
      Procedure AddStyle();
      Procedure AddLine();

      Function PopColor():ColorRGBA;

      Function DrawGlyph(View:TERRAViewport; X,Y:Single; Const CommandID:Integer; Var DestSprite:FontSprite):Boolean;

    Public
      Constructor Create();
      Procedure Release; Override;

      Function Reset():TERRAFontRenderer;

      Function SetColor(Const Value:ColorRGBA):TERRAFontRenderer;
      Function SetVerticalGradient(Const Top, Bottom:ColorRGBA):TERRAFontRenderer;
      Function SetHorizontalGradient(Const Left, Right:ColorRGBA):TERRAFontRenderer;

      Function SetOutline(Const Value:ColorRGBA):TERRAFontRenderer;
      Function SetGlow(Const Value:ColorRGBA):TERRAFontRenderer;

      Function SetCharLimit(Const Limit: Integer): TERRAFontRenderer;

      Function SetAutoWrap(Const Enabled:Boolean):TERRAFontRenderer;

      Function SetFont(Const TargetFont:TERRAFont):TERRAFontRenderer;

      Function SetPattern(Pattern:TERRATexture):TERRAFontRenderer;

      Function SetAlign(Const Align:TextAlign):TERRAFontRenderer;

      Function SetSize(Const Size:Single):TERRAFontRenderer;

      Function SetAreaLimit(Const Width, Height:Single):TERRAFontRenderer;

      Function SetTransform(Const Transform:Matrix3x3):TERRAFontRenderer;
      ///Function  SetDropShadow(Const DropShadowColor:ColorRGBA):TERRAFontRenderer;

      Function GetTextAt(Const X,Y:Single; Out Text:TERRAString; Out Style:TERRAFontCharStyle):Boolean;

      Function  SetClipRect(Const Clip:TERRAClipRect):TERRAFontRenderer;

      Function Compile(Const S:TERRAString; X,Y:Single):Boolean;

      Function DrawText(View:TERRAViewport; X,Y,Layer:Single; Const Text:TERRAString):TERRAFontRenderer;
      Function DrawTextToSprite(View:TERRAViewport; X,Y,Layer:Single; Const Text:TERRAString; Var DestSprite:FontSprite):TERRAFontRenderer;
      //Function DrawTextToImage(Target:TERRAImage; X,Y:Integer; Const Text:TERRAString; ForceBlend:Boolean = True):TERRAFontRenderer;

      Function GetTextWidth(Const Text:TERRAString):Single;
      Function GetTextHeight(Const Text:TERRAString):Single;
      Function GetTextRect(Const Text:TERRAString):Vector2D;
      Function GetLength(Const Text:TERRAString):Integer;

      Property MaxX:Single Read _MaxX;
      Property MaxY:Single Read _MaxY;

      Property NewLineOffset:Single Read _NewLineOffset Write _NewLineOffset;

      Property Font:TERRAFont Read _Font;
  End;

Implementation
Uses TERRA_Log, TERRA_OS, TERRA_Engine, TERRA_GraphicsManager, TERRA_Math, TERRA_DebugDraw, TERRA_FontManager, TERRA_TextureAtlas;

{ FontRenderer }
Constructor TERRAFontRenderer.Create;
Begin
  Reset();
End;

Function TERRAFontRenderer.Reset():TERRAFontRenderer;
Begin
  SetColor(ColorWhite);

  SetAlign(TextAlign_Left);

  _VerticalGradient := False;
  _HorizontalGradient := False;

  SetTransform(Matrix3x3_Identity);
  SetSize(DefaultFontSize);

  _CharLimit := -1;

  _AutoWrap := False;

  _Pattern := Nil;

  _Glow := ColorNull;
  _Outline := ColorBlack;

  Result := Self;
End;


Function TERRAFontRenderer.PopColor: ColorRGBA;
Var
  I:Integer;
  Current:Cardinal;
Begin
  Current := Cardinal(_StylesList[Pred(_StyleCount)].Color);

  For I:=_StyleCount-2 DownTo 0 Do
  If (Cardinal(_StylesList[I].Color) <> Current) Then
  Begin
    Result := _StylesList[I].Color;
    Exit;
  End;

  Result := Self._ColorBase;
End;

Procedure TERRAFontRenderer.QueueChar(Const Value:TERRAChar; Var X:Single; Const Y, Width, Height:Single);
Var
  H:Single;
Begin
  If (Length(_CharList) <= _CharCount) Then
    SetLength(_CharList, Succ(_CharCount));

  _CharList[_CharCount].Glyph := Nil;
  _CharList[_CharCount].Value := Value;
  _CharList[_CharCount].X := X;
  _CharList[_CharCount].Y := Y;
  _CharList[_CharCount].Width := Width;
  _CharList[_CharCount].Height := Height;
  _CharList[_CharCount].LineID := Pred(_LineCount);

  X := X + Width;

  _Lines[Pred(_LineCount)].Width := X;

  If (Value = #32) Then
    Inc(_Lines[Pred(_LineCount)].Spaces);

  If (X >_MaxX) Then
    _MaxX := X;

  H := Y + Height;
  If (H > _MaxY) Then
    _MaxY := H;


  Inc(_CharCount);
End;

Procedure TERRAFontRenderer.AddStyle();
Begin
  Inc(_StyleCount);

  If (Length(_StylesList)<_StyleCount) Then
    SetLength(_StylesList, _StyleCount);

  If _StyleCount>1 Then
    _StylesList[_StyleCount-1] := _StylesList[_StyleCount-2];
End;


Procedure TERRAFontRenderer.AddLine;
Begin
  Inc(_LineCount);

  If (Length(_Lines)<_LineCount) Then
    SetLength(_Lines, _LineCount);

  _Lines[Pred(_LineCount)].Width := 0.0;
  _Lines[Pred(_LineCount)].Spaces := 0;
End;

Function TERRAFontRenderer.Compile(Const S:TERRAString; X,Y:Single):Boolean;
Var
  I, J:Integer;
  It:StringIterator;
  LastChar, NextChar, TempChar, TempNext:TERRAChar;

  WasWord, IsWord:Boolean;

  State:Integer;

  Glyph:FontGlyph;

  StartX, TargetWidth,  TargetHeight, H:Single;
  N, K:Integer;

  Tag, Arg, ImgName:TERRAString;
  ArgMode, Active, StyleChanged:Boolean;

  SkipSpaces, InsideImage:Boolean;

  Procedure ApplyLineBreak();
  Begin
    X := StartX;
    Y := Y + _NewLineOffset + (_Font.NewLineOffset + FontPadding * 2) * FontInvScale *  _Scale;

    AddLine();

    SkipSpaces := True;
  End;
Begin
  Result := False;

  If (_Font = Nil) Then
    SetFont(Engine.Fonts.DefaultFont);

  If (_Font = Nil) Or (Not _Font.IsReady()) Then
    Exit;

  _CharCount := 0;
  _LineCount := 0;
  AddLine();

  _Width := 1.0;
  _Height := 1.0;

  _MaxX := 0;
  _MaxY := 0;

  StartX := X;
  WasWord := False;
  SkipSpaces := False;

  InsideImage := False;
  ImgName := '';

  _StyleCount := 0;
  StyleChanged := False;

  Self.AddStyle();
  _StylesList[0].Italics := False;
  _StylesList[0].Underline := False;
  _StylesList[0].StrikeThrough := False;
  _StylesList[0].WavyText := False;
  _StylesList[0].Link := '';
  _StylesList[0].Color := Self._ColorBase;

  It := StringCreateIterator(S);
  NextChar := NullChar;
  While (NextChar <> NullChar) Or (_CharCount<=0) Do
  Begin
    LastChar := NextChar;

    If It.HasNext Then
      NextChar := It.GetNext()
    Else
      NextChar := NullChar;

    If (LastChar = NullChar) Then
      Continue;

    If (LastChar = fontEffectBegin) Then
    Begin
      If (Not StyleChanged) Then
      Begin
        AddStyle();
        StyleChanged := True;
      End;

      Tag := '';
      Arg := '';
      Active := True;
      ArgMode := False;
      While (True) Do
      Begin
        LastChar := NextChar;

        If It.HasNext() Then
          NextChar := It.GetNext()
        Else
          NextChar := NullChar;

        If (LastChar = fontEffectEnd) Then
          Break
        Else
        If (LastChar = '/') And (Tag ='') Then
          Active := False
        Else
        If (LastChar = '=') Then
          ArgMode := True
        Else
        If (ArgMode) Then
          StringAppendChar(Arg, LastChar)
        Else
          StringAppendChar(Tag, LastChar);
      End;

      If (Tag = 'i') Then
      Begin
        _StylesList[Pred(_StyleCount)].Italics := Active;
      End Else
      If (Tag = 'u') Then
      Begin
        _StylesList[Pred(_StyleCount)].Underline := Active;
      End Else
      If (Tag = 's') Then
      Begin
        _StylesList[Pred(_StyleCount)].StrikeThrough := Active;
      End Else
      If (Tag = 'b') Then
      Begin
        _StylesList[Pred(_StyleCount)].Bold := Active;
      End Else
      If (Tag = 'w') Then
      Begin
        _StylesList[Pred(_StyleCount)].WavyText := Active;
      End Else
      If (Tag = 'color') Then
      Begin
        If Active Then
          _StylesList[Pred(_StyleCount)].Color := ColorCreateFromString(Arg)
        Else
          _StylesList[Pred(_StyleCount)].Color := PopColor();
      End Else
      If (Tag = 'img') Then
      Begin
        InsideImage := Active;

        If Active Then
        Begin
          ImgName := '';

          N := _CharCount;

          TargetWidth := StringToInt(StringGetNextSplit(Arg, 'x'));
          TargetHeight := StringToInt(Arg);

          If TargetWidth<=0 Then
            TargetWidth := 32;

          If TargetHeight<=0 Then
            TargetHeight := TargetWidth;

          QueueChar('!', X, Y, TargetWidth, TargetHeight);
          _CharList[N].Glyph := Nil;
          _CharList[N].StyleID := Pred(_StyleCount);
        End Else
        Begin
          _StylesList[Pred(_StyleCount)].Texture := Engine.Textures.GetItem(ImgName);
          StyleChanged := False;
        End;
      End Else
      If (Tag = 'url') Then
      Begin
        _StylesList[Pred(_StyleCount)].Link := Arg;

        If Active Then
          _StylesList[Pred(_StyleCount)].Color := ColorCreate(128, 128, 255)
        Else
          _StylesList[Pred(_StyleCount)].Color := PopColor();
      End Else
        Engine.Log.Write(logWarning, 'Font', 'Unknown font effect tag: '+Tag);

      Continue;
    End;

    If (LastChar = NewLineChar) Then
    Begin
      ApplyLineBreak();
      Continue;
    End;


    If (InsideImage) Then
    Begin
      StyleChanged := True;
      StringAppendChar(ImgName, LastChar);
      Continue;
    End;

    StyleChanged := False;

    IsWord := (CharIsAlphaNumeric(LastChar));
    If (_CharCount>0) And (_AutoWrap) And (Self._MaxWidth>0) And ((Not IsWord) Or ((IsWord) And (Not WasWord))) Then
    Begin
      State := It.Position;
      TempChar := LastChar;
      TempNext := NextChar;
      TargetWidth := 0.0;
      While (It.HasNext) Do
      Begin
        Glyph := _Font.GetGlyph(LastChar);

        If Assigned(Glyph) Then
          TargetWidth := TargetWidth + Glyph.GetAdvance(NextChar) * FontInvScale * _Scale;

        LastChar := NextChar;
        NextChar := It.GetNext();

        If (Not CharIsAlphaNumeric(LastChar)) Then
          Break;
      End;

      LastChar := TempChar;
      NextChar := TempNext;
      It.Position := Succ(State);

      If  (X + TargetWidth > StartX+  Self._MaxWidth) Then
        ApplyLineBreak();
    End;

    WasWord := IsWord;

    Glyph := _Font.GetGlyph(LastChar);
    If (Glyph = Nil) Then
      Continue;

    If (SkipSpaces) Then
    Begin
      If (LastChar = #32) Then
        Continue
      Else
        SkipSpaces := False;
    End;

    TargetWidth := Glyph.GetAdvance(NextChar) * FontInvScale * _Scale;
    TargetHeight := (Glyph.Height + FontPadding) * FontInvScale * _Scale;

    N := _CharCount;
    If (_CharLimit>=0) And (N>=_CharLimit) Then
      Break;

    QueueChar(LastChar, X, Y, TargetWidth, TargetHeight);
    _CharList[N].Glyph := Glyph;
    _CharList[N].StyleID := Pred(_StyleCount);
  End;
  ReleaseObject(It);

  If Self._Align <> TextAlign_Left Then
  For I:=0 To Pred(_CharCount) Do
  Begin
    TargetWidth := _Lines[_CharList[I].LineID].Width;

    Case Self._Align Of
    TextAlign_Right:
      Begin
        _CharList[I].X := (_MaxWidth - TargetWidth) + _CharList[I].X;
      End;

    TextAlign_Center:
      Begin
        _CharList[I].X := (_MaxWidth - TargetWidth) * 0.5 + _CharList[I].X;
      End;

    TextAlign_Justify:
      If (_CharList[I].Value = #32) Then
      Begin
        TargetWidth := (_MaxWidth - TargetWidth) / _Lines[_CharList[I].LineID].Spaces;

        For J:=Succ(I) To Pred(_CharCount) Do
        If (_CharList[J].LineID = _CharList[I].LineID) Then
          _CharList[J].X := _CharList[J].X + TargetWidth;

      End;
    End;

  End;

  Result := True;
End;

Function TERRAFontRenderer.SetAlign(const Align: TextAlign): TERRAFontRenderer;
Begin
  _Align := Align;
  Result := Self;
End;

Function TERRAFontRenderer.SetCharLimit(const Limit: Integer): TERRAFontRenderer;
Begin
  _CharLimit := Limit;
  Result := Self;
End;

Function TERRAFontRenderer.SetPattern( Pattern: TERRATexture): TERRAFontRenderer;
Begin
  _Pattern := Pattern;
  Result := Self;
End;

Function TERRAFontRenderer.SetColor(Const Value:ColorRGBA):TERRAFontRenderer;
Begin
  _ColorBase := Value;
  Result := Self;
End;

Function TERRAFontRenderer.SetVerticalGradient(Const Top, Bottom:ColorRGBA):TERRAFontRenderer;
Begin
  _ColorTop := Top;
  _ColorBottom := Bottom;
  _VerticalGradient := True;
  
  Result := Self;
End;

Function TERRAFontRenderer.SetHorizontalGradient(Const Left, Right:ColorRGBA):TERRAFontRenderer;
Begin
  _ColorLeft := Left;
  _ColorRight := Right;
  _HorizontalGradient := True;

  Result := Self;
End;

Function TERRAFontRenderer.GetTextWidth(Const Text:TERRAString):Single;
Begin
  Result := GetTextRect(Text).X ;
End;

Function TERRAFontRenderer.GetTextHeight(Const Text:TERRAString):Single;
Begin
  Result := GetTextRect(Text).Y ;
End;

Function TERRAFontRenderer.GetTextRect(Const Text:TERRAString):Vector2D;
Begin
  If (_Font = Nil) Or (Not _Font.IsReady) Then
  Begin
    Result.X := 0;
    Result.Y := 0;
    Exit;
  End;

  //Log(logDebug,'AdWall', 'Starting gettextrect');
  Compile(Text, 0, 0);

  //Log(logDebug,'AdWall', 'Finished textrect');
  Result.X := Round(Self.MaxX);
  Result.Y := Round(Self.MaxY);
End;

Function TERRAFontRenderer.GetLength(Const Text:TERRAString):Integer;
Begin
  Self.Compile(Text, 0, 0);
  Result := Self._CharCount;
End;


Function TERRAFontRenderer.SetClipRect(const Clip:TERRAClipRect):TERRAFontRenderer;
Begin
  Self._ClipRect := Clip;
  Result := Self;
End;


Function TERRAFontRenderer.SetAutoWrap(Const Enabled: Boolean): TERRAFontRenderer;
Begin
  Self._AutoWrap := Enabled;
  Result := Self;
End;

Function TERRAFontRenderer.SetAreaLimit(const Width, Height: Single): TERRAFontRenderer;
Begin
  _MaxWidth := Width;
  _MaxHeight := Height;
  Result := Self;
End;

(*Function TERRAFontRenderer.SetDropShadow(Const DropShadowColor:ColorRGBA):TERRAFontRenderer;
Begin
  _DropShadow := DropShadowColor.A>0;

  If _DropShadow Then
  Begin
    _InitDropColor := DropShadowColor;
  End Else
  Begin
    _InitDropColor := ColorNull;
  End;

  {$IFDEF DISTANCEFIELDFONTS}
  Self.SetOutline(DropShadowColor);
  {$ENDIF}

  Result := Self;
End;*)

Function TERRAFontRenderer.SetSize(const Size: Single):TERRAFontRenderer;
Begin
  _Size := Size;
  _Scale := _Size / DefaultFontSize;

  Result := Self;
End;

Function TERRAFontRenderer.SetFont(const TargetFont:TERRAFont):TERRAFontRenderer;
Var
  Glyph:FontGlyph;
Begin
  Result := Self;
  _Font := TargetFont;
  If _Font = Nil Then
    Exit;

  Glyph := _Font.GetGlyph('E');
  If Assigned(Glyph) Then
    _FontOffset := Glyph.YOfs
  Else
    _FontOffset := 0;
End;

Function TERRAFontRenderer.SetGlow(Const Value:ColorRGBA):TERRAFontRenderer;
Begin
  Self._Outline := Value;
  Result := Self;
End;

Function TERRAFontRenderer.SetOutline(const Value:ColorRGBA):TERRAFontRenderer;
Begin
  Self._Outline := Value;
  Result := Self;
End;

Function TERRAFontRenderer.SetTransform(const Transform: Matrix3x3):TERRAFontRenderer;
Begin
  _Transform := Transform;
  Result := Self;
End;

Function TERRAFontRenderer.ResolveTexture(Const TextureName: TERRAString): TERRATexture;
Begin
  Result := Engine.Textures.GetItem(TextureName);
End;

Function TERRAFontRenderer.AllocSprite: FontSprite;
Begin
  _LastAllocFrame := Engine.Graphics.FrameID;

  If (Length(_Sprites)<=_SpriteCount) Then
  Begin
    If (Length(_Sprites)<=0) Then
      SetLength(_Sprites, 64)
    Else
      SetLength(_Sprites, Length(_Sprites) * 2);
  End;

  If _Sprites[_SpriteCount] = Nil Then
  Begin
    _Sprites[_SpriteCount] := FontSprite.Create();
  End;

  Result := _Sprites[_SpriteCount];
  Inc(_SpriteCount);
End;

Procedure TERRAFontRenderer.Release;
Var
  I:Integer;
Begin
  For I:=0 To Pred(Length(_Sprites)) Do
    ReleaseObject(_Sprites[I]);
End;



Function TERRAFontRenderer.GetTextAt(Const X, Y:Single; Out Text:TERRAString; out Style:TERRAFontCharStyle): Boolean;
Var
  I, J:Integer;
Begin
  Text := '';

  For I:=0 To Pred(_CharCount) Do
  If (X>=_CharList[I].X) And (Y>=_CharList[I].Y - _CharList[I].Height) And (X <= _CharList[I].X + _CharList[I].Width) And (Y<=_CharList[I].Y) Then
  Begin
    Result := True;

    Style := _StylesList[_CharList[I].StyleID];

    For J:=0 To Pred(_CharCount) Do
    If (_CharList[J].StyleID = _CharList[I].StyleID) Then
    Begin
      StringAppendChar(Text, _CharList[J].Value);
    End;
    
    Exit;
  End;

  Result := False;

  If _StyleCount<=0 Then
    Self.AddStyle();

  Style := _StylesList[0];
End;

Function TERRAFontRenderer.DrawText(View:TERRAViewport; X,Y,Layer:Single; Const Text:TERRAString):TERRAFontRenderer;
Var
  Dest:FontSprite;
Begin
  If (_LastAllocFrame <> Engine.Graphics.FrameID) Then
    _SpriteCount := 0;

  Dest := Self.AllocSprite();
  Dest.Flags := Dest.Flags Or Sprite_Font;
  Result := DrawTextToSprite(View, X,Y,Layer, Text, Dest);
  Dest.Flags := Dest.Flags Or Sprite_GUI;

  Engine.Graphics.AddRenderable(View, Dest);
End;

Function TERRAFontRenderer.DrawTextToSprite(View:TERRAViewport; X,Y,Layer:Single; Const Text:TERRAString; Var DestSprite:FontSprite):TERRAFontRenderer;
Var
  I:Integer;
  Color:ColorRGBA;
  TargetX, TargetY:Single;
  K:Integer;

  XOfs:Single;

  S:TERRASprite;
Begin
  Result := Self;

  If (DestSprite = Nil) Then
    Exit;

  If (_Font = Nil) Or (Not _Font.IsReady()) Then
    Exit;

  DestSprite.Clear();

  Y := Y - _FontOffset * FontInvScale;

  DestSprite.Flags := DestSprite.Flags Or Sprite_Font;
  DestSprite.Layer := Layer;
  DestSprite.SetTransform(_Transform);
  DestSprite.ClipRect := _ClipRect;
  DestSprite.Outline := _Outline;
  DestSprite.Glow := _Glow;
  DestSprite.SetPattern(_Pattern);
  DestSprite.Smoothing := (2.5 / _Scale)/16.0;
  //DestSprite.Smoothing := 0.9; -> adds blur

  Compile(Text, X, Y);

  If _CharCount<0 Then
    Exit;

  I := 0;
  XOfs := 0;
  While (I<_CharCount) And (_CharList[I].Glyph = Nil) Do
    Inc(I);
  XOfs := _CharList[I].Glyph.XOfs{ * _Scale}; // HACK!!!!
    
    
  For I:=0 To Pred(_CharCount) Do
  If (_CharList[I].Value <> #32) Then
  Begin
    TargetX := _CharList[I].X{ - XOfs};
    TargetY := _CharList[I].Y;

    If (_StylesList[_CharList[I].StyleID].WavyText) Then
    Begin
      K := (Application.GetTime() Div 2);
      K := K + I* 30;
      TargetY := TargetY + Sin((K Mod 360) * RAD) * 2.0 * _Scale;
    End;

    If (Assigned(_CharList[I].Glyph)) Then
    Begin
      DrawGlyph(View, TargetX, TargetY, I, DestSprite);
    End Else
    Begin
      S := Engine.FetchSprite();
      S.AddQuad(spriteAnchor_TopLeft, Vector2D_Create(TargetX, TargetY - _CharList[I].Height), 0.0, _CharList[I].Width, _CharList[I].Height);
      S.SetTexture(_StylesList[_CharList[I].StyleID].Texture);
      Engine.Graphics.AddRenderable(View, S);
    End;

  End;

  //DrawClipRect(View, _ClipRect, ColorYellow);
End;

Function TERRAFontRenderer.DrawGlyph(View:TERRAViewport; X,Y:Single; Const CommandID:Integer; Var DestSprite:FontSprite):Boolean;
Var
  Item:TextureAtlasItem;
  Target:FontSprite;
  Tex:TERRATexture;
  Skew, OfsY:Single;
  Glyph:FontGlyph;
  S:TERRASprite;

  CL, CR:ColorRGBA;
  A, B, C, D:ColorRGBA;
Begin
  Result := False;

  If (DestSprite = Nil) Then
    Exit;

  Glyph := _CharList[CommandID].Glyph;
  If Glyph = Nil Then
    Exit;

  Item := Glyph.Item;
  If Item = Nil Then
    Exit;

  Tex := Glyph.Font.Atlas.GetTexture(Item.PageID);
  If Tex = Nil Then
    Exit;

  If (_StylesList[_CharList[CommandID].StyleID].Italics) Then
    Skew := 5.0
  Else
    Skew := 0.0;

  DestSprite.Texture := Tex;

  A := _StylesList[_CharList[CommandID].StyleID].Color;
  B := _StylesList[_CharList[CommandID].StyleID].Color;
  C := _StylesList[_CharList[CommandID].StyleID].Color;
  D := _StylesList[_CharList[CommandID].StyleID].Color;

  If _HorizontalGradient Then
  Begin
    CL := ColorMix(_ColorRight, _ColorLeft, CommandID/_CharCount);
    CR := ColorMix(_ColorRight, _ColorLeft, CommandID/_CharCount);

    A := ColorMultiply(A, CL);
    B := ColorMultiply(B, CR);
    C := ColorMultiply(C, CL);
    D := ColorMultiply(D, CR);
  End;

  If _VerticalGradient Then
  Begin
    A := ColorMultiply(A, _ColorTop);
    B := ColorMultiply(B, _ColorTop);
    C := ColorMultiply(C, _ColorBottom);
    D := ColorMultiply(D, _ColorBottom);
  End;

  //_CharList[CommandID].A, _CharList[CommandID].B, _CharList[CommandID].C, _CharList[CommandID].D

  DestSprite.AddGlyph(X, Y, Glyph, A, B, C, D, Skew, _Scale, _StylesList[_CharList[CommandID].StyleID].Bold);

  Result := True;


  If (_StylesList[_CharList[CommandID].StyleID].Underline) Then
  Begin
    S := Engine.FetchSprite();
    S.SetUVs(Glyph.Item.U1, Glyph.Item.V1, Glyph.Item.U2, Glyph.Item.V2);
    S.SetColor(_StylesList[_CharList[CommandID].StyleID].Color);
    OfsY := 20 * FontInvScale *  _Scale;
    S.AddLine(Vector2D_Create(X, Y + OfsY), Vector2D_Create(X + _CharList[CommandID].Width * 2, Y + OfsY),  0.0, 3);
    Engine.Graphics.AddRenderable(View, S); {TODO FIXME}
  End;

  If (_StylesList[_CharList[CommandID].StyleID].StrikeThrough) Then
  Begin
    S := Engine.FetchSprite();
    S.SetUVs(Glyph.Item.U1, Glyph.Item.V1, Glyph.Item.U2, Glyph.Item.V2);
    S.SetColor(_StylesList[_CharList[CommandID].StyleID].Color);
    OfsY := -8 * FontInvScale *  _Scale;
    S.AddLine(Vector2D_Create(X, Y + OfsY), Vector2D_Create(X + _CharList[CommandID].Width * 2, Y + OfsY),  0.0, 3);
    Engine.Graphics.AddRenderable(View, S); {TODO FIXME}
  End;
End;

(*Function TERRAFontRenderer.DrawTextToImage(Target:TERRAImage; X, Y: Integer; const Text:TERRAString; ForceBlend:Boolean):TERRAFontRenderer;
Var
  Next:Cardinal;
  Alpha:Integer;
  DropShadowColor:ColorRGBA;
  Projection:Matrix4x4;
  A,B,C,D:ColorRGBA;
  I:Integer;
  GG:TERRAImage;
Begin
  Result := Self;

  If Target = Nil Then
    Exit;

  If (_Font = Nil) Then
    Exit;

  If (_Font.Status<>rsReady) Then
    _Font.Prefetch();

  _Font.Update();

  GetTextRect(Text); // TODO CHECK REALLY NECESSARY HERE?

  Y := Trunc(Y - _FontOffset);

  BeginRender(Text, fontmode_Offscreen, X, Y, 0);
  While (RenderNext()) Do
  Begin
    If (_CurrentGlyph = Nil) Then
      Continue;

    GG := _CurrentGlyph.GetImage();
    If (GG = Nil) Then
    Begin
    //  IntToString(2);
      Continue;
    End;

    Target.BlitWithAlpha(Trunc(Position.X + _CurrentGlyph.XOfs * FontInvScale), Trunc(Position.Y + _CurrentGlyph.YOfs * FontInvScale), 0, 0, GG.Width, GG.Height, GG, ForceBlend);
  End;
  EndRender();
End;*)


End.
