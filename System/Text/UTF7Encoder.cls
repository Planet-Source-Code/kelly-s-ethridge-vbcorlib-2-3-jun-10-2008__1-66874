VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
  Persistable = 0  'NotPersistable
  DataBindingBehavior = 0  'vbNone
  DataSourceBehavior  = 0  'vbNone
  MTSTransactionMode  = 0  'NotAnMTSObject
END
Attribute VB_Name = "UTF7Encoder"
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
'    Module: UTF7Encoder
'
Option Explicit
Implements IObject
Implements Encoder

Private mEncoding   As UTF7Encoding
Private mFlush      As Boolean

' state for GetBytes
Private mBits       As Long
Private mBitCount   As Long


Friend Sub Init(ByVal Encoding As UTF7Encoding)
    Set mEncoding = Encoding
End Sub

Friend Property Get Flush() As Boolean
    Flush = mFlush
End Property

Friend Property Get bits() As Long
    bits = mBits
End Property

Friend Property Let bits(ByVal RHS As Long)
    mBits = RHS
End Property

Friend Property Get BitCount() As Long
    BitCount = mBitCount
End Property

Friend Property Let BitCount(ByVal RHS As Long)
    mBitCount = RHS
End Property


'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'   Class Events
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Private Sub Class_Initialize()
    mBitCount = -1
End Sub


'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'   IObject Interface
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Private Function IObject_ToString() As String
    IObject_ToString = Object.ToString(Me, App)
End Function

Private Function IObject_Equals(ByRef Value As Variant) As Boolean
    IObject_Equals = Object.Equals(Me, Value)
End Function

Private Function IObject_GetHashcode() As Long
    IObject_GetHashcode = ObjPtr(CUnk(Me))
End Function


'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'   Encoder Interface
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Private Function Encoder_Equals(Value As Variant) As Boolean
    Encoder_Equals = IObject_Equals(Value)
End Function

Private Function Encoder_GetByteCount(Chars() As Integer, ByVal Index As Long, ByVal Count As Long, ByVal Flush As Boolean) As Long
    mFlush = Flush
    
    Dim result As Long
    result = VerifyArrayRange(SAPtr(Chars), Index, Count)
    If result <> NO_ERROR Then ThrowArrayRangeException result, "Chars", Index, "Index", Count, "Count"
    
    Encoder_GetByteCount = mEncoding.InternalGetByteCount(Chars, Index, Count, Me)
End Function

Private Function Encoder_GetBytes(Chars() As Integer, ByVal CharIndex As Long, ByVal CharCount As Long, Bytes() As Byte, ByVal ByteIndex As Long, ByVal Flush As Boolean) As Long
    mFlush = Flush
    
    Dim result As Long
    result = VerifyArrayRange(SAPtr(Chars), CharIndex, CharCount)
    If result <> NO_ERROR Then ThrowArrayRangeException result, "Chars", CharIndex, "CharIndex", CharCount, "CharCount"
    
    Encoder_GetBytes = mEncoding.InternalGetBytes(Chars, CharIndex, CharCount, Bytes, ByteIndex, Me)
End Function

Private Function Encoder_GetHashCode() As Long
    Encoder_GetHashCode = IObject_GetHashcode
End Function

Private Function Encoder_ToString() As String
    Encoder_ToString = IObject_ToString
End Function
