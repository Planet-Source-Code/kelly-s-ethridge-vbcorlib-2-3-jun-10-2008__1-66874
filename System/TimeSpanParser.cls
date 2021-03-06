VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
  Persistable = 0  'NotPersistable
  DataBindingBehavior = 0  'vbNone
  DataSourceBehavior  = 0  'vbNone
  MTSTransactionMode  = 0  'NotAnMTSObject
END
Attribute VB_Name = "TimeSpanParser"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
'    CopyRight (c) 2008 Kelly Ethridge
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
'    Module: TimeSpanParser
'

Option Explicit
Private Const MILLISECONDS_PER_SECOND       As Long = 1000
Private Const SECONDS_PER_MINUTE            As Long = 60
Private Const MINUTES_PER_HOUR              As Long = 60
Private Const HOURS_PER_DAY                 As Long = 24

Private Const MILLISECONDS_PER_MINUTE       As Long = MILLISECONDS_PER_SECOND * SECONDS_PER_MINUTE
Private Const MILLISECONDS_PER_HOUR         As Long = MILLISECONDS_PER_MINUTE * MINUTES_PER_HOUR
Private Const MILLISECONDS_PER_DAY          As Currency = MILLISECONDS_PER_HOUR * HOURS_PER_DAY

Public Enum ParseError
    None
    OverflowError
    FormatError
End Enum

Private mBuffer     As WordBuffer
Private mIndex      As Long
Private mChar       As Long
Private mError      As ParseError



'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'   Friend Methods
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Friend Property Get Error() As ParseError
    Error = mError
End Property

Friend Function TryParse(ByRef s As String, ByRef RetVal As TimeSpan) As Boolean
    Call Init(s)
    Call NextChar
    Call SkipBlanks
    
    Dim Sign As Currency
    If Char = vbMinus Then
        Sign = -1@
        Call NextChar
    Else
        Sign = 1@
    End If
    
    Dim Result As Currency
    If NextNonDigit() = vbColon Then
        If Not ParseTime(Result) Then
            Exit Function
        End If
    Else
        Dim TempInt As Long
        If Not ParseNumber(10675199, TempInt) Then
            Exit Function
        End If
        Result = Result + (TempInt * MILLISECONDS_PER_DAY)
        
        If Char = vbPeriod Then
            Call NextChar
            
            Dim TempCur As Currency
            If Not ParseTime(TempCur) Then
                Exit Function
            End If
            
            Result = Result + TempCur
        End If
    End If
    
    Call SkipBlanks
    
    If mIndex < mBuffer.SA.cElements - 1 Then
        If mError = ParseError.None Then
            mError = ParseError.FormatError
        End If
        
        Exit Function
    End If
    
    Set RetVal = TimeSpan.FromMilliseconds(Result * Sign)
    TryParse = True
End Function



'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'   Private Helpers
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Private Sub Init(ByRef s As String)
    Call InitWordBuffer(mBuffer, StrPtr(s), Len(s))
    mIndex = -1
    mError = ParseError.None
    mChar = 0
End Sub

Private Property Get Char() As Integer
    Char = mChar
End Property

Private Sub NextChar()
    mIndex = mIndex + 1
    
    If mIndex < mBuffer.SA.cElements Then
        mChar = mBuffer.Data(mIndex)
    Else
        mIndex = mIndex - 1
        mChar = 0
    End If
End Sub

Private Sub SkipBlanks()
    Do While Char = vbSpace
        Call NextChar
    Loop
End Sub

Private Function NextNonDigit() As Integer
    Dim i As Long
    For i = mIndex To mBuffer.SA.cElements - 1
        Select Case mBuffer.Data(i)
            Case vbZero To vbNine
            Case Else
                NextNonDigit = mBuffer.Data(i)
                Exit Function
        End Select
    Next i
End Function

Private Function ParseTime(ByRef RetVal As Currency) As Boolean
    Dim Result  As Currency
    Dim i       As Long
    
    If Not ParseNumber(23, i) Then
        Exit Function
    End If
    
    Result = MILLISECONDS_PER_HOUR * i
    
    ' when parsing time we require at least hours and minutes.
    If Char <> vbColon Then
        mError = ParseError.FormatError
        Exit Function
    End If
    
    Call NextChar
    
    If Not ParseNumber(59, i) Then
        Exit Function
    End If
    
    Result = Result + MILLISECONDS_PER_MINUTE * i
    
    ' check for possible seconds
    If Char = vbColon Then
        Call NextChar
        
        ' defined fraction immediately after seconds colon instead
        ' 00:00:.1234
        If Char <> vbPeriod Then
            ' fraction not defined immediately, so seconds must be.
            If Not ParseNumber(59, i) Then
                Exit Function
            End If
            
            Result = Result + MILLISECONDS_PER_SECOND * i
        End If
        
        If Char = vbPeriod Then
            Call NextChar
            
            If Not ParseNumber(10000000, i) Then
                Exit Function
            End If
            
            Do While i < 10000000
                i = i * 10
            Loop
            i = i \ 10
            
            Result = Result + (CCur(i) * 0.0001@)
        End If
    End If
    
    RetVal = Result
    ParseTime = True
End Function

Private Function ParseNumber(ByVal MaxValue As Long, ByRef RetVal As Long) As Boolean
    Dim Result  As Long
    Dim Index   As Long
    
    Index = mIndex
    Do
        Select Case Char
            Case vbZero To vbNine
                Result = Result * 10 + (Char - vbZero)
                
            Case Else
                Exit Do
                
        End Select
        
        Call NextChar
    Loop
    
    If Result <= MaxValue Then
        RetVal = Result
        ParseNumber = True
    ElseIf Index = mIndex Then
        mError = ParseError.FormatError
    Else
        mError = ParseError.OverflowError
    End If
End Function

