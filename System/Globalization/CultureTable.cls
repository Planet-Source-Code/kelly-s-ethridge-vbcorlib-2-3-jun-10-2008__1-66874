VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
  Persistable = 0  'NotPersistable
  DataBindingBehavior = 0  'vbNone
  DataSourceBehavior  = 0  'vbNone
  MTSTransactionMode  = 0  'NotAnMTSObject
END
Attribute VB_Name = "CultureTable"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
'    CopyRight (c) 2004 Kelly Ethridge
'
'    This file is part of VBCorLib.
'
'    VBCorLib is free software; you can redistribute it and/or modify
'    it under the terms of the GNU Library General Public License as published by
'    the Free Software Foundation; either version 2.1 of the License, or
'    (at your option) any later version.
'
'    VBCorLib is distributed in the hope that it will be useful,
'    but WITHOUT ANY WARRANTY; without even the implied warranty of
'    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
'    GNU Library General Public License for more details.
'
'    You should have received a copy of the GNU Library General Public License
'    along with Foobar; if not, write to the Free Software
'    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
'
'    Module: CultureTable
'
Option Explicit

'   vbcultures.nlp structure
'
'''' Header ''''
'   Culture Count                           :   4 bytes
'   StringPool offset from base address     :   4 bytes
'   Culture Size                            :   4 bytes
'
'''' N Cultures ''''
'   Integer array
'    13 numeric values          :   2 bytes per value
'   Long array
'    44 pointers to string pool :   4 bytes per value
'
'''' StringPool ''''
'   Unknown number of strings.
'   Any strings that are to be
'   referenced as arrays of strings
'   has a 2 byte value indicating
'   the array size preceeding the
'   array elements.

Private Const CULTURE_FILENAME          As String = "vbcultures.nlp"
Private Const CULTURE_COUNT_OFFSET      As Long = 0
Private Const STRINGPOOL_OFFSET_OFFSET  As Long = 4
Private Const INVARIANT_LCID            As Long = 127
Private Const zh_CHS_LCID               As Long = 4
Private Const zh_CHT_LCID               As Long = 31748
Private Const sr_LCID                   As Long = 31770
Private Const SIZEOF_HEADER             As Long = 12
Private Const SIZEOF_CULTURE_OFFSET     As Long = 8

' If the layout of a culture changes, then this
' structure needs to be updated to match.
Private Type CultureHeader
    Numbers(12) As Integer
    Strings(43) As Long
End Type


Private mCultureInfo()      As Byte
Private mCulturesByLCID     As Hashtable
Private mNamesToLCID        As Hashtable
Private mBaseAddress        As Long
Private mStringPoolAddress  As Long
Private mCulture()          As CultureHeader
Private mCultureSA          As SafeArray1d



'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'   Friend Interface
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Friend Property Get IsLoaded() As Boolean
    IsLoaded = (mBaseAddress <> 0)
End Property

Friend Function GetString(ByVal LCID As Integer, ByVal Index As Long) As String
    On Error GoTo errTrap
    mCultureSA.pvData = mCulturesByLCID(LCID)
    
    Dim pos As Long
    pos = mStringPoolAddress + mCulture(0).Strings(Index)
    GetString = SysAllocString(pos)
    Exit Function
    
errTrap:
    Throw Cor.NewArgumentException("Culture is not supported.", "LCID")
End Function

Friend Function GetStringArray(ByVal LCID As Integer, ByVal Index As Long) As String()
    On Error GoTo errTrap
    mCultureSA.pvData = mCulturesByLCID(LCID)   ' this will throw an error if the culture does not exist
                                                ' since it will return Empty and fail to assign.
    ' Move to the start of the array elements.
    ' The first 2-bytes represent the number of elements.
    Dim pos As Long
    pos = mStringPoolAddress + mCulture(0).Strings(Index)
    
    ' Get number of array elements
    Dim Count As Long
    Count = MemWord(pos)
    
    ' Move to next set of bytes
    pos = pos + 2
    
    Dim Ret() As String
    ReDim Ret(0 To Count - 1)
    
    ' Iterate, getting one string at a time. We assume that
    ' there are as many strings as Count says.
    Dim i As Long
    For i = 0 To Count - 1
        ' Get the string. SysAllocString goes until it find a null character.
        Ret(i) = SysAllocString(pos)
        
        ' Skip the string characters plus 2 bytes for the terminating character.
        pos = pos + LenB(Ret(i)) + 2
    Next i
    
    GetStringArray = Ret
    Exit Function
    
errTrap:
    Throw Cor.NewArgumentException("Culture is not supported.", "LCID")
End Function

Friend Function GetNumber(ByVal LCID As Integer, ByVal Index As Long) As Integer
    On Error GoTo errTrap
    mCultureSA.pvData = mCulturesByLCID(LCID)
    GetNumber = mCulture(0).Numbers(Index)
    Exit Function
    
errTrap:
    Throw Cor.NewArgumentException("Culture is not supported.", "LCID")
End Function

Friend Function GetNumberArray(ByVal LCID As Integer, ByVal Index As Long) As Long()
    On Error GoTo errTrap
    mCultureSA.pvData = mCulturesByLCID(LCID)
    
    Dim pos As Long
    pos = mStringPoolAddress + mCulture(0).Strings(Index)
    
    Dim Count As Long
    Count = MemWord(pos)
    pos = pos + 2
    
    Dim Ret() As Long
    ReDim Ret(0 To Count - 1)
    
    Dim i As Long
    For i = 0 To Count - 1
        ' The number is stored as a string, so we have
        ' to retrieve it as a string and skip the appropriate
        ' number of characters to the next number.
        Dim s As String
        s = SysAllocString(pos)
        Ret(i) = CLng(s)
        pos = pos + LenB(s) + 2
    Next i
    
    GetNumberArray = Ret
    Exit Function
    
errTrap:
    Throw Cor.NewArgumentException("Culture is not supported.", "LCID")
End Function

Friend Function GetCultureID(ByVal Name As String) As Long
    Dim ID As Variant
    
    If mNamesToLCID Is Nothing Then
        Set mNamesToLCID = New Hashtable
        For Each ID In mCulturesByLCID.Keys
            Call mNamesToLCID.Add(GetString(ID, SNAME), ID)
        Next ID
    End If
    ID = mNamesToLCID(Name)
    If Not IsEmpty(ID) Then GetCultureID = ID
End Function

Friend Function IsNeutral(ByVal LCID As Long) As Boolean
    If GetSubLangID(LCID) = 0 Or LCID = sr_LCID Then
        IsNeutral = True
    Else
        ' These neutral cultures do not contain that fact
        ' in there LCID like the other cultures, so we
        ' must check them by hand.
        Select Case LCID
            Case INVARIANT_LCID, zh_CHS_LCID, zh_CHT_LCID: IsNeutral = True
        End Select
    End If
End Function

Friend Function GetCultures(ByVal Types As CultureTypes) As CultureInfo()
    Dim getNeutral As Boolean
    getNeutral = CBool(Types And NeutralCultures)
    
    Dim getSpecific As Boolean
    getSpecific = CBool(Types And SpecificCultures)
    
    Dim getInstalled As Boolean
    getInstalled = CBool(Types And InstalledWin32Cultures)
    
    Dim List As ArrayList
    Set List = New ArrayList
    
    Dim ID As Variant
    For Each ID In mCulturesByLCID.Keys
        If IsNeutral(ID) Then
            If getNeutral Then Call List.Add(Cor.NewCultureInfo(ID))
        ElseIf IsInstalled(ID) And getInstalled Then
            Call List.Add(Cor.NewCultureInfo(ID))
        ElseIf getSpecific Then
            Call List.Add(Cor.NewCultureInfo(ID))
        End If
    Next ID
    
    Dim Ret() As CultureInfo
    ReDim Ret(0 To List.Count - 1)
    Call List.CopyTo(Ret)
    GetCultures = Ret
End Function


'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'   Private Helpers
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Private Function IsInstalled(ByVal LCID As Long) As Boolean
    IsInstalled = IsValidLocale(LCID, LCID_INSTALLED)
End Function

Private Function GetSubLangID(ByVal LCID As Long) As Long
    GetSubLangID = Helper.ShiftRight(LCID, 10) And &H3F
End Function

Private Sub Load()
    mCultureInfo = LoadResData(101, "CULTUREINFO")
    mBaseAddress = VarPtr(mCultureInfo(0))
    mStringPoolAddress = mBaseAddress + MemLong(mBaseAddress + STRINGPOOL_OFFSET_OFFSET)
    Call LoadLCIDLookup
End Sub

Private Sub LoadLCIDLookup()
    Set mCulturesByLCID = New Hashtable
    
    Dim pos As Long
    pos = mBaseAddress + SIZEOF_HEADER
    
    Dim CultureSize As Long
    CultureSize = MemLong(mBaseAddress + SIZEOF_CULTURE_OFFSET)
    mCultureSA.cbElements = CultureSize
    
    Dim NumCultures As Long
    NumCultures = MemLong(mBaseAddress + CULTURE_COUNT_OFFSET)
    
    Do While NumCultures > 0
        mCultureSA.pvData = pos
        Call mCulturesByLCID.Add(mCulture(0).Numbers(ILCID), pos)
        pos = pos + CultureSize
        NumCultures = NumCultures - 1
    Loop
End Sub


'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'   Class Events
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Private Sub Class_Initialize()
    With mCultureSA
        .cDims = 1
        .cElements = 1
    End With
    SAPtr(mCulture) = VarPtr(mCultureSA)
    Call Load
End Sub

Private Sub Class_Terminate()
    SAPtr(mCulture) = 0
End Sub
