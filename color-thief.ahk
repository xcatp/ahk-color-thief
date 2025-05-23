; https://github.com/xcatp
; Licensed under MIT

#Requires AutoHotkey v2.0

#SingleInstance Ignore
#NoTrayIcon

#Include _lib\GdipStarter.ahk
#Include _lib\Cursor.ahk
#Include _lib\MeowConf.ahk
#Include fullScreenGui.ahk

A_MaxHotkeysPerInterval := 200

CoordMode 'Mouse'
CoordMode 'Pixel'

Esc:: ExitApp()
OnError(ErrorHandler)

mcf := FileExist('./config.txt') ? MeowConf.Of('./config.txt') : Map()
hex := mcf.Get('hex', true)
  , drawTip := mcf.Get('tip', true)
  , drawPic := mcf.Get('pic', false)

offsetX := mcf.Get('offsetX', 12)
  , offsetY := mcf.Get('offsetY', 12)
  , WIDTH := Clamp(mcf.Get('viewW', 160), 3, 800)
  , HEIGHT := Clamp(mcf.Get('viewH', 128), 3, 800)
  , _h := Clamp(mcf.Get('zoom', 15), 5, HEIGHT)

font := mcf.Get('font', "MaytermOne")
  , fc := mcf.Get('fontColor', 'ffdbffd5')
  , fs := mcf.Get('fontSize', 's20')

pBrush := Gdip_BrushCreateSolid(StringToARGB(mcf.Get('tipBgc', 'ad282828')))
  , pPenLine := Gdip_CreatePen(StringToARGB(mcf.Get('crossLineBgc', 'c52fff00')), 1)  ; cross line
  , pPenbkBlack := Gdip_CreatePen(StringToARGB(mcf.Get('borderBgc1', 'ff000000')), 1) ; border
  , pPenbkWhite := Gdip_CreatePen(StringToARGB(mcf.Get('borderBgc2', 'ffffffff')), 1)
  , pCheckerBrush := CreateCheckerBrush(mcf.Get('tileW')
    , StringToARGB(mcf.Get('tileColor1', 'ffa2a2a2'))
    , StringToARGB(mcf.Get('tileColor2', 'ffd5d5d5')))

StringToARGB(str) => ('0x' str)


pbmp := Gdip_CreateBitmapFromFile('./rem.png')
oriW := Gdip_GetImageWIDTH(pbmp), oriH := Gdip_GetImageHEIGHT(pbmp)
; ==========

Init()

g_c := '', block := false

Hotkey('LButton Up', SaveWithPrefix, 'On')
Hotkey('Enter', SaveWithPrefix, 'On')
Hotkey('MButton', ToggleHex, 'On')
Hotkey('WheelUp', (*) => Zoom(-2), 'On')
Hotkey('WheelDown', (*) => Zoom(2), 'On')
Hotkey('RButton Up', Exit, 'On')
Hotkey('Left', (*) => MouseMove(-1, 0, 0, 'R'), 'On')
Hotkey('Right', (*) => MouseMove(1, 0, 0, 'R'), 'On')
Hotkey('Up', (*) => MouseMove(0, -1, 0, 'R'), 'On')
Hotkey('Down', (*) => MouseMove(0, 1, 0, 'R'), 'On')
Hotkey('^LButton Up', SaveNoPrefix, 'On')
Hotkey('^WheelUp', (*) => Zoom(-6), 'On')
Hotkey('^WheelDown', (*) => Zoom(6), 'On')
Hotkey('^Up', (*) => Zoom(-2), 'On')
Hotkey('^Down', (*) => Zoom(2), 'On')


; #region 静态背景
StaticBG.Show()
staticHdc := GetDC(StaticBG.insId)
; #endregion

main := Gui('-Caption +AlwaysOnTop +ToolWindow +E0x00080000')
main.Show()

getMainPos(mx, my, &x, &y) {
  x := mx + (mx + offsetX + WIDTH + 5 > A_ScreenWidth ? -WIDTH - offsetX : offsetX)
  y := my + (my + offsetY + HEIGHT + 25 > A_ScreenHeight ? -HEIGHT - 25 - offsetY : offsetY)
}

TIP_H := 24

; #region 主绘图
MouseGetPos(&n_mX, &n_mY)
Start(n_mX, n_mY)
OnMessage(0x200, OnMove)
; #endregion


Start(mouseX, mouseY) {
  Critical

  getMainPos(mouseX, mouseY, &x, &y)

  hbm := CreateDIBSection(WIDTH + oriW, HEIGHT + TIP_H + 1)
    , hdc := CreateCompatibleDC()
    , obm := SelectObject(hdc, hbm)
    , G := Gdip_GraphicsFromHDC(hdc), Gdip_SetSmoothingMode(G, 4)

  _DrawEnlargementfiFrame(G, hdc, x, y, mouseX, mouseY)
  _DrawTip(G, 0, HEIGHT)
  _DrawPic(G)
  UpdateLayeredWindow(main.Hwnd, hdc, x, y, WIDTH + oriW, HEIGHT + TIP_H + 1)

  SelectObject(hdc, obm) DeleteObject(hbm), DeleteDC(hdc), Gdip_DeleteGraphics(G)

  _DrawEnlargementfiFrame(G, hdc, x, y, mx, my) {
    global staticHdc

    _w := WIDTH * _h // HEIGHT    ; 放大区域的宽
      , sx := mx - _w // 2        ; 放大区域的左上角 x 坐标
      , sy := my - _h // 2        ; ... y 坐标
      , cx := WIDTH // 2          ; main窗口的中心坐标
      , cy := HEIGHT // 2

    ; #region cross line
    _hbm := CreateDIBSection(A_ScreenWidth, A_ScreenHeight)
      , _obm := SelectObject(_hdc := CreateCompatibleDC(), _hbm)
      , _G := Gdip_GraphicsFromHDC(_hdc)
    BitBlt(_hdc, sx, sy, sw := (_w + !(_w & 1)), _h, staticHdc, sx, sy) ; 偶数时需要加1，保持为奇数

    Gdip_DrawLine(_G, pPenLine, mx, my - 1, mx, sy) ; vertical
    Gdip_DrawLine(_G, pPenLine, mx, my + 1, mx, my + _h // 2)
    Gdip_DrawLine(_G, pPenLine, mx - 1, my, sx, my)
    Gdip_DrawLine(_G, pPenLine, mx + 1, my, mx + _w // 2, my)

    StretchBlt(hdc, 0, 0, WIDTH, HEIGHT, _hdc, sx, sy, sw, _h)

    SelectObject(_hdc, _obm), DeleteObject(_hbm), DeleteDC(_hdc), Gdip_DeleteGraphics(_G)
    ; #endregion

    _DrawOverflowZone(G, sx, sy, sw)

    ; #region border
    Gdip_DrawRectangle(G, pPenbkBlack, 0, 0, WIDTH, HEIGHT)
    Gdip_DrawRectangle(G, pPenbkWhite, 1, 1, WIDTH - 2, HEIGHT - 2)

    ; if _w < 14 {
    ;   _ph := height // _h + (_w & 1 ? 3 : 4), _halfph := _ph // 2
    ;   Gdip_DrawRectangle(G, pPenbkBlack, cx - _halfph, cy - _halfph - 1, _ph - 2, _ph)
    ;   Gdip_DrawRectangle(G, pPenbkWhite, cx - _halfph + 1, cy - _halfph, _ph - 4, _ph - 2)
    ; }
    ; #endregion
  }

  _DrawOverflowZone(G, sx, sy, sw) {
    if sx < 0
      Gdip_FillRectangle(G, pCheckerBrush, 0, 0, Ceil(WIDTH * (-sx / sw)), HEIGHT)
    if sx + sw > A_ScreenWidth {
      _ := Ceil(WIDTH * ((sx + sw - A_ScreenWidth) / sw))
      Gdip_FillRectangle(G, pCheckerBrush, WIDTH - _ - 2, 0, _, HEIGHT)
    }
    if sy < 0
      Gdip_FillRectangle(G, pCheckerBrush, 0, 0, WIDTH, Ceil(HEIGHT * (-sy / _h)))
    if sy + _h > A_ScreenHeight {
      _ := Ceil(HEIGHT * ((sy + _h - A_ScreenHeight) / _h))
      Gdip_FillRectangle(G, pCheckerBrush, 0, HEIGHT - _ - 2, WIDTH, _)
    }

  }

  _DrawTip(G, _x, _y) {
    global g_c, TIP_H
    if !drawTip
      return
    local x := _x, y := _y
    Gdip_FillRectangle(G, pBrush, x, y, WIDTH, TIP_H) ; bg

    _c := '0xff' (hexC := PixelGetColor(Cursor.x, Cursor.y, 'slow').substring(3))

    Gdip_FillRectangle(G, _b := Gdip_BrushCreateSolid(_c), x, y, TIP_H, TIP_H) ; color box
    Gdip_DrawRectangle(G, pPenbkBlack, x, y, WIDTH, TIP_H)
    Gdip_DrawRectangle(G, pPenbkWhite, x + 1, y + 1, TIP_H - 2, TIP_H - 2)

    ; text
    options := Format('x{} y{} c{} Center ' fs, x + 20, y + 2, fc)
    Gdip_TextToGraphics(G, (g_c := hex ? '#' hexC : _hexToRGB(hexC)), options, font, WIDTH - 20, 30)
    Gdip_DeleteBrush(_b)

    _hexToRGB(_c) {
      local r, g, b
      if _c.length = 3
        _c := _c[0] + _c[0] + _c[1] + _c[1] + _c[2] + _c[2]
      r := ('0x' _c.substring(1, 3)) & 0xFF
      g := ('0x' _c.substring(3, 5)) & 0xFF
      b := ('0x' _c.substring(5)) & 0xFF
      return JoinStr(',', '(' r, g, b ')')
    }
  }

  _DrawPic(G) {
    if !drawPic
      return
    local x, y
    x := WIDTH + mcf.Get('picOffsetX', 0)
    y := HEIGHT - oriH + (drawTip ? 25 : 0) + mcf.Get('picOffsetY', 0)
    Gdip_DrawImage(G, pbmp, x, y, oriW, oriH)
  }
}

Init() {
  Cursor.SetIcon(Cursor.Icon.cross)

  if !Gdip_FontFamilyCreate(font) {
    global font := mcf.Get('fontFallback', 'Microsoft JhengHei')
    Gdip_FontFamilyCreate(font)
  }
}

CreateCheckerBrush(TileWidth, FirstColor, SecondColor) {
  DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", 2 * TileWidth, "Int", 2 * TileWidth, "Int", 0, "Int", 0x26200A, "UPtr", 0, "UPtr*", &pBitmap := 0)
  DllCall("gdiplus\GdipGetImageGraphicsContext", "UPtr", pBitmap, "UPtr*", &pGraphics := 0)

  Gdip_GraphicsClear(pGraphics, FirstColor)
  b := Gdip_BrushCreateSolid(SecondColor)

  Gdip_FillRectangle(pGraphics, b, 0, 0, TileWidth, TileWidth)
  Gdip_FillRectangle(pGraphics, b, TileWidth, TileWidth, TileWidth, TileWidth)
  _pBrush := Gdip_CreateTextureBrush(pBitmap, 0, 0, 0, 2 * TileWidth, 2 * TileWidth)

  Gdip_DeleteBrush(b)
  Gdip_DisposeImage(pBitmap)
  Gdip_DeleteGraphics(pGraphics)
  return _pBrush
}


ToggleHex(*) {
  global hex := !hex
  MouseGetPos(&n_mX, &n_mY)
  Start(n_mX, n_mY)
}

Zoom(diff) {
  global _h := Clamp(_h + diff, 5, HEIGHT)
  MouseGetPos(&n_mX, &n_mY)
  Start(n_mX, n_mY)
}

SaveWithPrefix(*) => (A_Clipboard := hex ? g_c : Format('rgb{}', g_c), Exit())
SaveNoPrefix(*) => ((A_Clipboard := hex ? g_c.substring(2) : g_c), Exit())
Exit(*) => (Clean(), ExitApp())


OnMove(*) {
  static o_mX := 0, o_mY := 0
  if block
    return
  MouseGetPos(&n_mX, &n_mY)
  if n_mX = o_mX && n_mY = o_mY
    return
  Start(n_mX, n_mY)
  o_mX := n_mX, o_mY := n_mY
}

ErrorHandler(*) {
  StaticBG.Close(), HotKeysOff('LButton Up')
  return
}

Clean() {
  Critical
  global block := true
  StaticBG.Close()
  HotKeysOff('LButton Up', 'RButton Up')

  Gdip_DeletePen(pPenLine)
  Gdip_DeletePen(pPenbkBlack)
  Gdip_DeletePen(pPenbkWhite)

  Gdip_DeleteBrush(pBrush)
  Gdip_DeleteBrush(pCheckerBrush)

  DeleteDC(staticHdc)
  Gdip_DisposeImage(pbmp)
}