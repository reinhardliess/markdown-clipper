; Writes a warning message to OutputDebug for property access of a non-object value
; cf. https://www.autohotkey.com/docs/Objects.htm#Default__Warn

"".base.__Get := "".base.__Set := "".base.__Call := Func("rd_nonobj_warn")

rd_nonobj_warn(nonObj, p1="", p2="", p3="", p4="") {

  source := Exception("Warn", -2).What
  nonObj := Substr(nonObj, 1, 80)
  OutputDebug,
  ( ltrim
    Warning: A non-object value was improperly invoked in '%source%':

    Non-Object: %nonObj%
    Param1: %p1%
    Param2: %p2%
    Param3: %p3%
    Param4: %p4%
  )
  ; OutputDebug, % format("Warning: A non-object value was improperly invoked in '{6}':`n`nNon-Object: {1}`nParam1: {2}`nParam2: {3}`nParam3: {4}`nParam4: {5}`n"
  ;   , nonObj, p1, p2, p3, p4, e.What)

}
