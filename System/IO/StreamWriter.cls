VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
  Persistable = 0  'NotPersistable
  DataBindingBehavior = 0  'vbNone
  DataSourceBehavior  = 0  'vbNone
  MTSTransactionMode  = 0  'NotAnMTSObject
END
Attribute VB_Name = "StreamWriter"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = True
'    CopyRight (c) 2005 Kelly Ethridge
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
'    Module: StreamWriter
'

''
' Writes characters to a byte stream using the specific encoding.
'
' @remarks The default encoding used is UTF8Encoding. If the writer is
' not appending to the stream, then an encoding preamble is written to
' the stream.
'
' @see Constructors
' @see StreamReader
' @see TextWriter
'
Option Explicit
Implements IObject
Implements TextWriter

Private Const MIN_BUFFERSIZE As Long = 128


Private mStream         As Stream
Private mAutoFlush      As Boolean
Private mEncoding       As Encoding
Private mEncoder        As Encoder
Private mNewLine        As String
Private mCharBuffer()   As Integer
Private mByteBuffer()   As Byte
Private mBufferSize     As Long
Private mPosition       As Long
Private mIsOpen         As Boolean



''
' Returns if the writer autoflushes after each write.
'
' @return Indication of autoflush.
'
Public Property Get AutoFlush() As Boolean
    AutoFlush = mAutoFlush
End Property

''
' Sets if the writer autoflushes after each write.
'
' @param RHS The new value.
'
Public Property Let AutoFlush(ByVal RHS As Boolean)
    mAutoFlush = RHS
End Property

''
' Returns the stream this writer is using.
'
' @return The stream being used by this writer.
'
Public Property Get BaseStream() As Stream
    Set BaseStream = mStream
End Property

''
' Returns the encoding being used by this writer.
'
' @return The encoding being used by this writer.
'
Public Property Get Encoding() As Encoding
    Set Encoding = mEncoding
End Property

''
' Returns the format provider being used by this writer.
'
' @return The format provider used by this writer.
'
Public Property Get FormatProvider() As IFormatProvider
    Set FormatProvider = CultureInfo.CurrentCulture
End Property

''
' Returns the new-line string used by this writer.
'
' @return The new-line string.
'
Public Property Get NewLine() As String
    NewLine = mNewLine
End Property

''
' Sets the new-line string used by this writer.
'
' @param RHS The new new-line value.
'
Public Property Let NewLine(ByVal RHS As String)
    mNewLine = RHS
End Property

''
' Closes this writer, flushing any buffers needed.
'
Public Sub CloseWriter()
    If mIsOpen Then
        Call Flush
        mIsOpen = False
        Call mStream.CloseStream
    End If
End Sub

''
' Flushes the buffers to the underlying stream.
'
Public Sub Flush()
    Call VerifyIsOpen
    Call InternalFlush(True, True)
End Sub

''
' Writes the encoded string representation of the value to the stream.
'
' @param value The value to be written to the stream.
' @param args The arguments to be used in formatting the Value.
' @remarks The <i>args</i> are used when argument indexes are supplied
' in the value to be written. Indexes are indicate by enclosing the
' specific index in curly braces {}. The indexes start at 0.
'
Public Sub WriteValue(ByRef Value As Variant, ParamArray args() As Variant)
    Dim a() As Variant
    Call Helper.Swap4(ByVal ArrPtr(a), ByVal Helper.DerefEBP(16))
    Call InternalWriteValue(Value, a)
End Sub

''
' Writes the value, then appends the new-line string.
'
' @param value The value to be written.
' @remarks The first argument in <i>value</i> is the output to the
' string. Any additional arguments are used as formatting information.
' An argument can be refered to through formatting indexes. A
' formatting index is an integer enclosed in curly braces {}. The
' indexes start at 0.
'
Public Sub WriteLine(ParamArray Value() As Variant)
    Dim a() As Variant
    Call Helper.Swap4(ByVal ArrPtr(a), ByVal Helper.DerefEBP(12))
    Call InternalWriteLine(a)
End Sub

''
' Returns a string representation of this object instance.
'
' @return String representing this instance.
Public Function ToString() As String
    ToString = Object.ToString(Me, App)
End Function

''
' Returns a boolean indicating if the value and this object
' instance are the same instance.
'
' @param value The value to compare equality to.
' @return Boolean indicating equality.
Public Function Equals(ByRef Value As Variant) As Boolean
    Equals = Object.Equals(Me, Value)
End Function

''
' Returns a pseudo-unique number identifying this instance.
'
' @return Pseudo-unique number identifying this instance.
Public Function GetHashCode() As Long
    GetHashCode = ObjPtr(CUnk(Me))
End Function


'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'   Friend Interface
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Friend Sub Init(ByVal Source As Variant, ByVal Encoding As Encoding, ByVal BufferSize As Long, ByVal Append As Boolean)
    Dim Mode As FileMode
    Dim emit As Boolean
    
    If BufferSize < 0 Then _
        Throw Cor.NewArgumentOutOfRangeException(Environment.GetResourceString(ArgumentOutOfRange_NeedNonNegNum), "BufferSize", BufferSize)
    
    Select Case VarType(Source)
        Case vbObject
            If Source Is Nothing Then _
                Throw Cor.NewArgumentNullException(Environment.GetResourceString(ArgumentNull_Stream))
            If Not TypeOf Source Is Stream Then _
                Throw Cor.NewArgumentException(Environment.GetResourceString(Argument_StreamRequired), "Source")
                
            Set mStream = Source
        
        Case vbString
            If Append Then
                Mode = FileMode.Append
            Else
                Mode = FileMode.Create
                emit = True
            End If
            Set mStream = Cor.NewFileStream(Source, Mode, FileAccess.WriteAccess, FileShare.ReadShare)
        
        Case Else
            Throw Cor.NewArgumentException("A file path or Stream object is required.", "Source")
    End Select
    
    ' Set up encoding scheme.
    If Encoding Is Nothing Then Set Encoding = Cor.NewUTF8Encoding(False, True)
    Set mEncoding = Encoding
    Set mEncoder = mEncoding.GetEncoder
    
    ' Allows any kind of characters as a newline.
    mNewLine = Environment.NewLine
    mIsOpen = True
    
    ' Set up the write buffers.
    If BufferSize < MIN_BUFFERSIZE Then BufferSize = MIN_BUFFERSIZE
    ReDim mCharBuffer(0 To BufferSize - 1)
    ReDim mByteBuffer(0 To mEncoding.GetMaxByteCount(BufferSize) - 1)
    mBufferSize = BufferSize
    
    ' Write the BOM.
    If emit Then Call WritePreamble
End Sub


'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'   Private Helpers
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Private Sub InternalWrite(ByVal Value As String, ByRef args() As Variant, ByVal NewLine As Boolean)
    Dim CharCount As Long
    Dim CharPtr As Long
    Dim CharsToCopy As Long
    
    Call VerifyIsOpen
    
    If UBound(args) >= 0 Then Value = cString.FormatArray(Value, args)
    If NewLine Then Value = Value & mNewLine
    
    CharCount = Len(Value)
    CharPtr = StrPtr(Value)
    
    Do While CharCount > 0
        ' If we will write past the end of the buffer, then
        ' empty the buffer in hopes we can fit inside it.
        If mPosition + CharCount >= mBufferSize Then Call InternalFlush(False, False)
        
        ' Determine just how many characters we can write to the buffer.
        If CharCount > mBufferSize Then
            ' Can't fit the entire thing in the buffer at once, so chop it up.
            CharsToCopy = mBufferSize
        Else
            ' It all fits now.
            CharsToCopy = CharCount
        End If
        
        ' Copy the characters to the buffer
        Call CopyMemory(mCharBuffer(mPosition), ByVal CharPtr, CharsToCopy * 2)
        
        ' Calculate the remaining characters to write.
        CharCount = CharCount - CharsToCopy
        CharPtr = CharPtr + CharsToCopy * 2
        mPosition = mPosition + CharsToCopy
    Loop
    If mAutoFlush Then Call InternalFlush(True, False)
End Sub

' WriteLine has only a ParamArray argument. This allows for nothing
' to be passed in and only write a newline to the stream.
Private Sub InternalWriteLine(ByRef args() As Variant)
    Dim ub As Long
    Dim Value As String
    
    ub = UBound(args)
    
    ' The first argument is the line to be written, so convert it to a string.
    If ub >= 0 Then Value = Convert.ToString(args(0))
    
    ' If there are additional arguments, then those arguments need
    ' to be shifted down to fill the space of the first argument, which
    ' is now a separate value.
    If ub > 0 Then
        Dim i As Long
        For i = 1 To ub
            Call Helper.MoveVariant(args(i - 1), args(i))
        Next i
        ReDim Preserve args(ub - 1)
    ElseIf ub = 0 Then
        ' The first element is now the Value and we just
        ' want an empty zero-length array now.
        args = cArray.CreateInstance(ciVariant)
    End If
    
    Call InternalWrite(Value, args, True)
End Sub

Private Sub InternalWriteValue(ByRef Value As Variant, ByRef args() As Variant)
    Call InternalWrite(Convert.ToString(Value), args, False)
End Sub

Private Sub VerifyIsOpen()
    If Not mIsOpen Then Throw Cor.NewObjectDisposedException("StreamWriter", "Cannot write to a close writer.")
End Sub

Private Sub WritePreamble()
    Dim b() As Byte
    
    If Not mStream.CanSeek Then Exit Sub
    If mStream.Length > 0 Then Exit Sub
    
    b = mEncoding.GetPreamble
    Call mStream.WriteBlock(b, 0, cArray.GetLength(b))
End Sub

Private Sub InternalFlush(ByVal FlushStream As Boolean, ByVal FlushEncoder As Boolean)
    Dim Size As Long
    
    If mPosition > 0 Then
        Size = mEncoder.GetBytes(mCharBuffer, 0, mPosition, mByteBuffer, 0, FlushEncoder)
        Call mStream.WriteBlock(mByteBuffer, 0, Size)
        mPosition = 0
    End If
    
    If FlushStream Then Call mStream.Flush
End Sub


'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'   Class Events
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Private Sub Class_Terminate()
    Call CloseWriter
End Sub


'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'   IObject Interface
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Private Function IObject_Equals(Value As Variant) As Boolean
    IObject_Equals = Equals(Value)
End Function

Private Function IObject_GetHashcode() As Long
    IObject_GetHashcode = GetHashCode
End Function

Private Function IObject_ToString() As String
    IObject_ToString = ToString
End Function


'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'   TextWriter Interface
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Private Sub TextWriter_CloseWriter()
    Call CloseWriter
End Sub

Private Property Get TextWriter_Encoding() As Encoding
    Set TextWriter_Encoding = Encoding
End Property

Private Function TextWriter_Equals(Value As Variant) As Boolean
    TextWriter_Equals = Equals(Value)
End Function

Private Sub TextWriter_Flush()
    Call Flush
End Sub

Private Property Get TextWriter_FormatProvider() As IFormatProvider
    Set TextWriter_FormatProvider = FormatProvider
End Property

Private Function TextWriter_GetHashCode() As Long
    TextWriter_GetHashCode = GetHashCode
End Function

Private Property Let TextWriter_NewLine(ByVal RHS As String)
    NewLine = RHS
End Property

Private Property Get TextWriter_NewLine() As String
    TextWriter_NewLine = NewLine
End Property

Private Function TextWriter_ToString() As String
    TextWriter_ToString = ToString
End Function

Private Sub TextWriter_WriteLine(ParamArray Value() As Variant)
    Dim a() As Variant
    Call Helper.Swap4(ByVal ArrPtr(a), ByVal Helper.DerefEBP(12))
    Call InternalWriteLine(a)
End Sub

Private Sub TextWriter_WriteValue(ByRef Value As Variant, ParamArray args() As Variant)
    Dim a() As Variant
    Call Helper.Swap4(ByVal ArrPtr(a), ByVal Helper.DerefEBP(16))
    Call InternalWriteValue(Value, a)
End Sub

