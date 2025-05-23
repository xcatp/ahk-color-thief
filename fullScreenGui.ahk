class FullScreenGui extends Gui {

  static insId := ''

  __New(opt := '') {
    super.__New('+AlwaysOnTop -Caption +ToolWindow ' opt)
  }

  static Close() {
    try WinClose('ahk_id' this.insId)
    this.insId := ''
  }
}

class StaticBG extends FullScreenGui {

  static Show(*) {
    ins := StaticBG()
    ins.Show('hide x0 y0 w' A_ScreenWidth ' h' A_ScreenHeight)
    WinSetTransparent(0, ins), Sleep(10)
    ins.Show('NA')
    hdc := DllCall('GetDC', 'ptr', ins.Hwnd), sdc := DllCall("GetDC", 'ptr', 0)

    DllCall("BitBlt"
      , "ptr", hdc, "int", 0, "int", 0, "int", A_ScreenWidth, "int", A_ScreenHeight
      , "ptr", sdc, "int", 0, "int", 0
      , "uint", 0x00CC0020)

    WinSetTransparent(255, ins)
    ReleaseDC(hdc), ReleaseDC(sdc)
    this.insId := ins.Hwnd
  }

  static Close() {
    super.Close()
  }

}
