// XBox controller API
Unit TERRA_XInput;
{$I terra.inc}

Interface
Uses TERRA_InputManager;

Const
  XINPUT_DLL  = 'xinput1_3.dll';

// device types
  XINPUT_DEVTYPE_GAMEPAD = $01;
  XINPUT_DEVSUBTYPE_GAMEPAD = $01;
  XINPUT_DEVSUBTYPE_WHEEL = $02;
  XINPUT_DEVSUBTYPE_ARCADE_STICK = $03;
  XINPUT_DEVSUBTYPE_FLIGHT_SICK = $04;
  XINPUT_DEVSUBTYPE_DANCE_PAD = $05;

 // Constants for gamepad buttons
  XINPUT_GAMEPAD_DPAD_UP = $0001;
  XINPUT_GAMEPAD_DPAD_DOWN = $0002;
  XINPUT_GAMEPAD_DPAD_LEFT = $0004;
  XINPUT_GAMEPAD_DPAD_RIGHT = $0008;
  XINPUT_GAMEPAD_START = $0010;
  XINPUT_GAMEPAD_BACK = $0020;
  XINPUT_GAMEPAD_LEFT_THUMB = $0040;
  XINPUT_GAMEPAD_RIGHT_THUMB = $0080;
  XINPUT_GAMEPAD_LEFT_SHOULDER = $0100;
  XINPUT_GAMEPAD_RIGHT_SHOULDER = $0200;
  XINPUT_GAMEPAD_A = $1000;
  XINPUT_GAMEPAD_B = $2000;
  XINPUT_GAMEPAD_X = $4000;
  XINPUT_GAMEPAD_Y = $8000;

  // User index definitions
  XUSER_MAX_COUNT = 4;
  XUSER_INDEX_ANY = $000000FF;

Type
  PXInputGamepad = ^TXInputGamepad;
  TXInputGamepad = Packed Record
    Buttons: Word;
    LeftTrigger: Byte;
    RightTrigger: Byte;
    ThumbLX: Smallint;
    ThumbLY: Smallint;
    ThumbRX: Smallint;
    ThumbRY: Smallint;
  End;

  PXInputState = ^TXInputState;
  TXInputState = Record
    dwPacketNumber:Cardinal;
    Gamepad: TXInputGamepad;
  End;

  PXInputVibration = ^TXInputVibration;
  TXInputVibration = Packed Record
    wLeftMotorSpeed: Word;
    wRightMotorSpeed: Word;
  End;

  PXInputCapabilities = ^TXInputCapabilities;
  TXInputCapabilities = Packed Record
    _Type:Byte;
    SubType:Byte;
    Flags:Word;
    Gamepad:TXInputGamepad;
    Vibration:TXInputVibration;
  End;

  XInputGamepad = Class(Gamepad)
    Public
      Procedure Update(Keys:InputState); Override;
  End;

Function XGetControllerState(ControllerID:Integer):TXInputGamepad;
Function XIsControllerConnected(ControllerID:Integer):Boolean;

Implementation
Uses TERRA_Log, TERRA_Application, TERRA_Engine, Windows;

Var
  XLibHandle:THandle=0;
  XInputGetState:Function(dwUserIndex:Cardinal; Var State:TXInputState):Cardinal; stdcall;
  XInputGetCapabilities:Function(dwUserIndex:Cardinal; dwFlags:Cardinal; Var Capabilities:TXInputCapabilities):Cardinal; stdcall;
  XInputEnable:Procedure (enable:Boolean); stdcall;
  HasLib:Boolean = True;

Procedure InitXInput;
Begin
  If (Not HasLib) Then
    Exit;

  XLibHandle := LoadLibrary(XINPUT_DLL);
  If XLibHandle=0 Then
  Begin
    Engine.Log.Write(logWarning, 'Input', 'Error loading XInput from '+XINPUT_DLL);
    HasLib := False;
    Exit;
  End;

  XInputGetState := GetProcAddress(XLibHandle, 'XInputGetState');
  XInputGetCapabilities := GetProcAddress(XLibHandle, 'XInputGetCapabilities');
  XInputEnable := GetProcAddress(XLibHandle, 'XInputEnable');

  //XInputEnable(True);
End;

Function XIsControllerConnected(ControllerID:Integer):Boolean;
Var
  Res:Cardinal;
  State:TXInputState;
  Caps:TXInputCapabilities;
Begin
  Result := False;

  If (XLibHandle = 0) Then
    InitXInput();

  If (XLibHandle = 0) Then
    Exit;

  FillChar(State, SizeOf(State), 0);
  Res := XInputGetState(ControllerID, State);
  If (Res <> ERROR_SUCCESS) Then
    Exit;

  Result := True;
  {Res := XInputGetCapabilities(ControllerID, XINPUT_FLAG_GAMEPAD, Caps);
  If (Res <> ERROR_SUCCESS) Then
    Exit;
   }
End;

Function XGetControllerState(ControllerID:Integer):TXInputGamepad;
Var
  Res:Cardinal;
  State:TXInputState;
Begin
  If (XLibHandle = 0) Then
    InitXInput();

  FillChar(Result, SizeOf(Result), 0);
  If (XLibHandle = 0) Then
    Exit;

  FillChar(State, SizeOf(State), 0);
  Res := XInputGetState(ControllerID, State);
  If (Res = ERROR_SUCCESS) Then
  Begin
    Result := State.Gamepad;
  End;
End;

(*
void CXBOXController::Vibrate(int leftVal, int rightVal)
    // Create a Vibraton State
    XINPUT_VIBRATION Vibration;

    // Zeroise the Vibration
    ZeroMemory(&Vibration, sizeof(XINPUT_VIBRATION));

    // Set the Vibration Values
    Vibration.wLeftMotorSpeed = leftVal;
    Vibration.wRightMotorSpeed = rightVal;

    // Vibrate the controller
    XInputSetState(_controllerNum, &Vibration);
*)

{ XInputGamepad }
Procedure XInputGamepad.Update(Keys: InputState);
Var
  XState:TXInputGamepad;
  IsConnected:Boolean;
Begin
  Self._Kind := gamepadXBox360;

  IsConnected := XIsControllerConnected(_DeviceID);

  If (Not IsConnected) Then
  Begin
    Self.Disconnnect();
    Exit;
  End Else
  Begin
    Self.Connnect();
  End;

  XState := XGetControllerState(_DeviceID);

  Keys.SetState(GetGamePadKeyValue(LocalID, keyGamePadUp_Offset), (XState.Buttons And XINPUT_GAMEPAD_DPAD_UP)<>0);
  Keys.SetState(GetGamePadKeyValue(LocalID, keyGamePadDown_Offset), (XState.Buttons And XINPUT_GAMEPAD_DPAD_DOWN)<>0);
  Keys.SetState(GetGamePadKeyValue(LocalID, keyGamePadLeft_Offset), (XState.Buttons And XINPUT_GAMEPAD_DPAD_LEFT)<>0);
  Keys.SetState(GetGamePadKeyValue(LocalID, keyGamePadRight_Offset), (XState.Buttons And XINPUT_GAMEPAD_DPAD_RIGHT)<>0);

  Keys.SetState(GetGamePadKeyValue(LocalID, keyGamePadMenu_Offset), (XState.Buttons And XINPUT_GAMEPAD_START)<>0);
  Keys.SetState(GetGamePadKeyValue(LocalID, keyGamePadZ_Offset), (XState.Buttons And XINPUT_GAMEPAD_BACK)<>0);

  Keys.SetState(GetGamePadKeyValue(LocalID, keyGamePadA_Offset), (XState.Buttons And XINPUT_GAMEPAD_A)<>0);
  Keys.SetState(GetGamePadKeyValue(LocalID, keyGamePadB_Offset), (XState.Buttons And XINPUT_GAMEPAD_B)<>0);
  Keys.SetState(GetGamePadKeyValue(LocalID, keyGamePadX_Offset), (XState.Buttons And XINPUT_GAMEPAD_X)<>0);
  Keys.SetState(GetGamePadKeyValue(LocalID, keyGamePadY_Offset), (XState.Buttons And XINPUT_GAMEPAD_Y)<>0);

  Keys.SetState(GetGamePadKeyValue(LocalID, keyGamePadL1_Offset), (XState.Buttons And XINPUT_GAMEPAD_LEFT_SHOULDER)<>0);
  Keys.SetState(GetGamePadKeyValue(LocalID, keyGamePadR1_Offset), (XState.Buttons And XINPUT_GAMEPAD_RIGHT_SHOULDER)<>0);

  Keys.SetState(GetGamePadKeyValue(LocalID, keyGamePadL2_Offset), (XState.LeftTrigger>150));
  Keys.SetState(GetGamePadKeyValue(LocalID, keyGamePadR2_Offset), (XState.RightTrigger>150));
End;

End.

