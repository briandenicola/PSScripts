' Extract MOSS 2007 Product ID
' Written by Bert Johnson (PointBridge)
' http://blogs.pointbridge.com/Blogs/johnson_bert/Pages/Post.aspx?_ID=10

Const HKEY_LOCAL_MACHINE = &H80000002
Set reg=GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\default:StdRegProv")

wscript.echo GetKey("SOFTWARE\Microsoft\Office\12.0\Registration\{90120000-110D-0000-1000-0000000FF1CE}", "DigitalProductId")

Public Function GetKey(path, key)
    Dim chars(24), prodid
    Dim productkey(14)

    reg.GetBinaryValue HKEY_LOCAL_MACHINE, path, key, prodid
    
    For ib = 52 To 66
        productkey(ib - 52) = prodid(ib)
    Next

    'Possible characters in the Product ID:
    chars(0) = Asc("B")
    chars(1) = Asc("C")
    chars(2) = Asc("D")
    chars(3) = Asc("F")
    chars(4) = Asc("G")
    chars(5) = Asc("H")
    chars(6) = Asc("J")
    chars(7) = Asc("K")
    chars(8) = Asc("M")
    chars(9) = Asc("P")
    chars(10) = Asc("Q")
    chars(11) = Asc("R")
    chars(12) = Asc("T")
    chars(13) = Asc("V")
    chars(14) = Asc("W")
    chars(15) = Asc("X")
    chars(16) = Asc("Y")
    chars(17) = Asc("2")
    chars(18) = Asc("3")
    chars(19) = Asc("4")
    chars(20) = Asc("6")
    chars(21) = Asc("7")
    chars(22) = Asc("8")
    chars(23) = Asc("9")

    For ib = 24 To 0 Step -1
        n = 0

        For ikb = 14 To 0 Step -1
            n = n * 256 Xor productkey(ikb)
            productkey(ikb) = Int(n / 24)
            n = n Mod 24
        Next

        sCDKey = Chr(chars(n)) & sCDKey
        If ib Mod 5 = 0 And ib <> 0 Then sCDKey = "-" & sCDKey
    Next

    GetKey = sCDKey
End Function

