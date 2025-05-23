#Requires AutoHotkey v2.0

GetWinTransparent(_) => WinGetTransparent(_) || 255

CentreCtrl(g, ctrl, skewX := 0, skewY := 0) {
  g.GetPos(&x, &y, &w, &h), ctrl.GetPos(, , &tw, &th)
  ctrl.Move((w - tw) // 2 + x + skewX, h // 2 + y + skewY)
}

ShowGui(g, x,y,w,h) => g.Show('x' x ' y' y ' w' w ' h' h)
