VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
  Persistable = 0  'NotPersistable
  DataBindingBehavior = 0  'vbNone
  DataSourceBehavior  = 0  'vbNone
  MTSTransactionMode  = 0  'NotAnMTSObject
END
Attribute VB_Name = "RSACryptoServiceProvider"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = True
'    CopyRight (c) 2006 Kelly Ethridge
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
'    Module: RSACryptoServiceProvider
'

''
' Provides RSA encryption services using the Windows Crypto API methods.
'
Option Explicit
Implements IObject
Implements AsymmetricAlgorithm
Implements RSA
Implements ICspAsymmetricAlgorithm

Private Const DEF_KEYNUMBER     As Long = AT_KEYEXCHANGE
Private Const DEF_PROVIDERTYPE  As Long = PROV_RSA_FULL

Private mProvider           As Long
Private mKey                As Long
Private mKeySize            As Long
Private mProviderName       As String
Private mProviderType       As Long
Private mKeyContainerName   As String
Private mKeyNumber          As Long
Private mPersistKeyInCsp    As Boolean
Private mFlags              As CspProviderFlags
Private mLegalKeySizes()    As KeySizes
Private mRandomlyGenerated  As Boolean
Private mPublicOnly         As Boolean
Private mIsDisposed         As Boolean




''
' Returns a CspKeyContainerInfo object containing information about this RSACryptoServiceProvider instance.
'
' @return A CspKeyContainerInfo object.
'
Public Property Get CspKeyContainerInfo() As CspKeyContainerInfo
    Call VerifyLoaded
    
    Dim Params As CspParameters
    Set Params = Cor.NewCspParameters(mProviderType, mProviderName, mKeyContainerName)
    Params.KeyNumber = mKeyNumber
    Params.Flags = mFlags
    
    Set CspKeyContainerInfo = Cor.NewCspKeyContainerInfo(Params)
    CspKeyContainerInfo.RandomlyGenerated = mRandomlyGenerated
    CspKeyContainerInfo.Accessible = True
End Property

''
' Returns the name of the key exchange algorithm this instance represents.
'
' @Return The name of the key exchange algorithm.
' @remarks When an RSACryptoServiceProvider is created as a key exchange instead
' of a signature service, this returns 'RSA-PKCS1-KeyEx', otherwise nothing is returned.
'
Public Property Get KeyExchangeAlgorithm() As String
    If mKeyNumber = AT_KEYEXCHANGE Then
        KeyExchangeAlgorithm = "RSA-PKCS1-KeyEx"
    End If
End Property

''
' Returns the RSA key size in bits.
'
' @return The key size in bits being used by this RSA instance.
' @remarks By default, the key size is 1024 for high encryption and 512 for base encryption providers.
'
Public Property Get KeySize() As Long
    KeySize = mKeySize
End Property

''
' Sets the key size.
'
' @param RHS The new key size.
' @remarks This property has no affect on the key size. To set the key size, use the
' Cor.NewRSACryptoServiceProvider constructor.
'
Public Property Let KeySize(ByVal RHS As Long)
    ' does nothing
End Property

''
' Returns an array of KeySizes objects defining the valid key sizes.
'
' @return An array of KeySizes objects.
' @remarks For high encryption systems, the legal key sizes go from 384 bits to 16384 bits
' in steps of 8 bits. For base encryption systems, the key sizes go from 384 bits to 512 bits
' in steps of 8 bits.
'
Public Property Get LegalKeySizes() As KeySizes()
    LegalKeySizes = mLegalKeySizes
End Property

''
' Returns if the current key will be stored in the current provider container.
'
' @return Returns True if the key will be stored, False otherwise.
' @remarks By default this is set to False. If a container is specified using the
' Cor.NewRSACryptoServiceProvider, then this will be set to True.<br>
' <br>A key is stored in the container to allow for each retrieval by any other
' service that knows where the key is. Only 1 key is stored in a container, therefore,
' if multiple providers share the same container, then the key may become invalid.
'
Public Property Get PersistKeyInCsp() As Boolean
    PersistKeyInCsp = mPersistKeyInCsp
End Property

''
' Sets if the current key will be stored in the current provider container.
'
' @param RHS Set to True to save the key on exit, False to have the key be deleted.
' @remarks By default this is set to False. If a container is specified using the
' Cor.NewRSACryptoServiceProvider, then this will be set to True.<br>
' <br>A key is stored in the container to allow for each retrieval by any other
' service that knows where the key is. Only 1 key is stored in a container, therefore,
' if multiple providers share the same container, then the key may become invalid.
'
Public Property Let PersistKeyInCsp(ByVal RHS As Boolean)
    mPersistKeyInCsp = RHS
End Property

''
' Returns if the key for this RSA instance is only the public half of the key pair.
'
' @return Returns True if only the public half of the key is present, False otherwise.
' @remarks RSA uses a private/public key pair to encrypt and decrypt. Only the public
' part is required to encrypt data. The private key is used to decrypt data.
'
Public Property Get PublicOnly() As Boolean
    Call VerifyLoaded
    PublicOnly = mPublicOnly
End Property

''
' Returns the signature algorithm.
'
' @return Always returns 'http://www.w3.org/2000/09/xmldsig#rsa-sha1'
'
Public Property Get SignatureAlgorithm() As String
    SignatureAlgorithm = "http://www.w3.org/2000/09/xmldsig#rsa-sha1"
End Property

''
' Releases any resources and disposes the RSA instance.
'
Public Sub Clear()
    Call CryptoAPI.DestroyKey(mKey)
    Call CryptoAPI.ReleaseContext(mProvider, Not mPersistKeyInCsp)
    
    mIsDisposed = True
End Sub

''
' Decrypts data using the private key in this RSA instance.
'
' @param Rgb The data to be decrypted.
' @param fOAEP A flag indicating if the data was padded using OAEP padding.
' @return Returns the decrypted data.
'
Public Function Decrypt(ByRef Rgb() As Byte, ByVal fOAEP As Boolean) As Byte()
    Call VerifyLoaded
    
    If cArray.IsNull(Rgb) Then _
        Throw Cor.NewArgumentNullException(Environment.GetResourceString(ArgumentNull_Array), "Rgb")
    
    Dim Flags As Long
    If fOAEP Then Flags = CRYPT_OAEP
    
    Dim size As Long
    size = cArray.GetLength(Rgb)
    
    ' We need to make a copy of the original array because we dont' want
    ' to alter its contents. Also, the copy is reversed in order to deal
    ' with .NET's Big-Endian form.
    Dim Ret() As Byte
    Ret = ReverseByteCopy(Rgb)
    
    If CryptDecrypt(mKey, 0, True, Flags, Ret(0), size) = BOOL_FALSE Then _
        Throw Cor.NewCryptographicException(GetErrorMessage(Err.LastDllError))
    
    ReDim Preserve Ret(0 To size - 1)
    Decrypt = Ret
End Function

''
' Decrypts the value.
'
' @param Rgb The value to be decrypted.
' @return The decrypted value.
' @remarks In .NET this would throw a NotSupportedException, however, it is
' supported in VBCorLib. This is equivalen to calling Decrypt(Data, False).
'
'
Public Function DecryptValue(ByRef Rgb() As Byte) As Byte()
    DecryptValue = Decrypt(Rgb, False)
End Function

''
' Encrypts data using the public key in this RSA instance.
'
' @param Rgb The data to be encrypted.
' @param fOAEP A flag indicating if OAEP padding should be used, otherwise PKCS#1 v1.5 padding is used.
'
Public Function Encrypt(ByRef Rgb() As Byte, ByVal fOAEP As Boolean) As Byte()
    Call VerifyLoaded
    
    If cArray.IsNull(Rgb) Then _
        Throw Cor.NewArgumentNullException(Environment.GetResourceString(ArgumentNull_Array), "Rgb")
    
    Dim Flags As Long
    If fOAEP Then Flags = CRYPT_OAEP
    
    Dim size As Long
    size = cArray.GetLength(Rgb)
    
    ' We copy the original array so we don't alter the
    ' original array during the encryption process.
    Dim Ret() As Byte
    ReDim Ret(0 To mKeySize \ 8 - 1)
    Call Buffer.BlockCopy(Rgb, 0, Ret, 0, size)
    
    If CryptEncrypt(mKey, 0, True, Flags, Ret(0), size, mKeySize \ 8) = BOOL_FALSE Then _
        Throw Cor.NewCryptographicException(GetErrorMessage(Err.LastDllError))
    
    ' This is to remain compatible with .NET's big-endian form.
    Encrypt = ReverseByteCopy(Ret)
End Function

''
' Encrypts a value.
'
' @param Rgb The value to be encrypted.
' @return The encrypted value.
' @remarks In .NET this would throw a NotSupportedException, however, it is
' supported in VBCorLib. This is equivalen to calling Encrypt(Data, False).
'
Public Function EncryptValue(ByRef Rgb() As Byte) As Byte()
    EncryptValue = Encrypt(Rgb, False)
End Function

''
' Exports the key information as a CryptoAPI PRIVATEKEYBLOB or PUBLICKEYBLOB structure.
'
' @param IncludePrivateParameters A flag indicating if only the public key should be exported
' or is both the public and private keys should be exported.
' @return An exported key blob structure.
'
Public Function ExportCspBlob(ByVal IncludePrivateParameters As Boolean) As Byte()
    Call VerifyLoaded
    
    Dim BlobType As Long
    BlobType = IIf(IncludePrivateParameters, PRIVATEKEYBLOB, PUBLICKEYBLOB)
    
    Dim size As Long
    If CryptExportKey(mKey, 0, BlobType, 0, ByVal 0&, size) = BOOL_FALSE Then _
        Throw Cor.NewCryptographicException(GetErrorMessage(Err.LastDllError))
    
    Dim Blob() As Byte
    ReDim Blob(0 To size - 1)
    
    If CryptExportKey(mKey, 0, BlobType, 0, Blob(0), size) = BOOL_FALSE Then _
        Throw Cor.NewCryptographicException(GetErrorMessage(Err.LastDllError))
    
    ExportCspBlob = Blob
End Function

''
' Exports the RSA algorithm parameters.
'
' @param IncludePrivateParameters A flag indicating if only the public key should be exported
' or is both the public and private keys should be exported.
' @return An RSAParameters object containing the parameters of the RSA algorithms.
'
Public Function ExportParameters(ByVal IncludePrivateParameters As Boolean) As RSAParameters
    Set ExportParameters = New RSAParameters
    Call ExportParameters.FromCspBlob(Me.ExportCspBlob(IncludePrivateParameters))
End Function

''
' Imports RSA parameters from an XML string.
'
' @param XmlString The string containing the XML formatted parameters.
'
Public Sub FromXmlString(ByVal XmlString As String)
    Dim Params As New RSAParameters
    Call Params.FromXmlString(XmlString)
    Call ImportParameters(Params)
End Sub

''
' Imports a CryptoAPI PRIVATEKEYBLOB or PUBLICKEYBLOB into the RSA provider.
'
' @param KeyBlob The blob key to be imported.
'
Public Sub ImportCspBlob(ByRef KeyBlob() As Byte)
    If cArray.IsNull(KeyBlob) Then _
        Throw Cor.NewArgumentNullException(Environment.GetResourceString(ArgumentNull_Array), "KeyBlob")
    
    Call VerifyLoaded(False)
    Call DeleteKey
    
    If CryptImportKey(mProvider, KeyBlob(LBound(KeyBlob)), cArray.GetLength(KeyBlob), 0, CRYPT_EXPORTABLE, mKey) = BOOL_FALSE Then _
        Throw Cor.NewCryptographicException(GetErrorMessage(Err.LastDllError))
    
    mPublicOnly = (KeyBlob(LBound(KeyBlob)) = PUBLICKEYBLOB)
End Sub

''
' Imports the RSA key parameters.
'
' @param Parameters The parameters to be imported as the new key.
'
Public Sub ImportParameters(ByVal Parameters As RSAParameters)
    If Parameters Is Nothing Then _
        Throw Cor.NewArgumentNullException("Parameters cannot be Nothing.", "Parameters")
    
    Call Me.ImportCspBlob(Parameters.ToCspBlob(mKeyNumber))
End Sub

''
' Signs data using the specified hash algorithm.
'
' @param InputStreamOrBuffer The data to be signed. This can be a <b>Stream</b> object or a Byte Array.
' @param hAlg The hash algorithm to use for signing. Only SHA1 and MD5 are supported.
' @param Offset The starting index of a Byte array input source. This is ignored for <b>Stream</b> input sources.
' @param Count The number of bytes of a Byte array input source to process. This is ignored for <b>Stream</b> input sources.
' @return The signature of the data.
' @remarks The hash algorithms can be specified either by the OID string, the hash name, or an actual instance of a hash
' object that implements either the <b>SHA1</b> or <b>MD5</b> interface.
' @see CryptoConfig
' @see SHA1
' @see MD5
' @see SHA1CryptoServiceProvider
' @see SHA1Manged
' @see MD5CryptoServiceProvider
'
Public Function SignData(ByRef InputStreamOrBuffer As Variant, ByVal hAlg As Variant, Optional ByRef offset As Variant, Optional ByRef Count As Variant) As Byte()
    Dim HashObj As HashAlgorithm
    Set HashObj = GetHash(hAlg)
    
    SignData = SignHash(HashObj.ComputeHash(InputStreamOrBuffer, offset, Count), GetOID(HashObj))
End Function

''
' Signs a hash using RSA AT_SIGNATURE.
'
' @param RgbHash The hash value to be signed.
' @param Str The type of hash value being signed.
' @return The signature for the hash data.
' @remarks Only SHA1 and MD5 hashes are supported.
' <p>The <i>Str</i> parameter can be "SHA", "SHA1", "MD5", or the OID.
' @see CryptoConfig
'
Public Function SignHash(ByRef RgbHash() As Byte, ByVal Str As String) As Byte()
    Dim Hash As Long
    Hash = SetHash(RgbHash, Str)

    Dim size As Long
    If CryptSignHash(Hash, AT_SIGNATURE, vbNullString, 0, ByVal 0&, size) = BOOL_FALSE Then _
        Throw Cor.NewCryptographicException(GetErrorMessage(Err.LastDllError))

    Dim Signature() As Byte
    ReDim Signature(0 To size - 1)
    
    If CryptSignHash(Hash, AT_SIGNATURE, vbNullString, 0, Signature(0), size) = BOOL_FALSE Then _
        Throw Cor.NewCryptographicException(GetErrorMessage(Err.LastDllError))
    
    Call CryptDestroyHash(Hash)
    
    SignHash = ReverseByteCopy(Signature)
    Exit Function

errTrap:
    If Hash <> vbNullPtr Then Call CryptDestroyHash(Hash)
    Call Throw
End Function

''
' Exports the RSA key to an Xml string.
'
' @param IncludePrivateParameters A flag indicating if the private portions of the key should be exported.
' @return An Xml representation of the RSA key.
'
Public Function ToXmlString(ByVal IncludePrivateParameters As Boolean) As String
    ToXmlString = Me.ExportParameters(IncludePrivateParameters).ToXmlString
End Function

''
' Verifies the data using the signature.
'
' @param Buffer The data to be verified.
' @param hAlg The hash algorithm used to verify to the data. This is the same algorithm used to sign the data. Only SHA1 and MD5 are supported.
' @param Signature The signature used to ensure the data is valid.
' @return Returns True if the data has a valid signature, False otherwise.
' @remarks The hash algorithms can be specified either by the OID string, the hash name, or an actual instance of a hash
' object that implements either the <b>SHA1</b> or <b>MD5</b> interface.
' @see CryptoConfig
' @see SHA1
' @see MD5
' @see SHA1CryptoServiceProvider
' @see SHA1Manged
' @see MD5CryptoServiceProvider
'
Public Function VerifyData(ByRef Buffer() As Byte, ByRef hAlg As Variant, ByRef Signature() As Byte) As Boolean
    If cArray.IsNull(Buffer) Then _
        Throw Cor.NewArgumentNullException(Environment.GetResourceString(ArgumentNull_Array), "Buffer")
                  
    Dim HashObj As HashAlgorithm
    Set HashObj = GetHash(hAlg)
    
    VerifyData = VerifyHash(HashObj.ComputeHash(Buffer), GetOID(HashObj), Signature)
End Function

''
' Verifies the hash using the signature.
'
' @param RgbHash The hash to be verified.
' @param Str The type of hash value being signed.
' @param Signature The signature for the hash data.
' @return Returns True if the signature is correct, False otherwise.
' @remarks Only SHA1 and MD5 hashes are supported.
' <p>The <i>Str</i> parameter can be "SHA", "SHA1", "MD5", or the OID.
' @see CryptoConfig
'
Public Function VerifyHash(ByRef RgbHash() As Byte, ByVal Str As String, ByRef Signature() As Byte) As Boolean
    If cArray.IsNull(Signature) Then _
        Throw Cor.NewArgumentNullException(Environment.GetResourceString(ArgumentNull_Array), "Signature")
    
    Dim Hash As Long
    Hash = SetHash(RgbHash, Str)

    ' We need to reverse the signature to deal with .NET's big-endian form.
    Dim RevSig() As Byte
    RevSig = ReverseByteCopy(Signature)
    
    VerifyHash = CBool(CryptVerifySignature(Hash, RevSig(0), cArray.GetLength(Signature), mKey, vbNullString, 0))
    Call CryptDestroyHash(Hash)
End Function

''
' This function determines if the value passed in is the same
' as the current object instance. Meaning, are the Value and
' this object the same object in memory.
'
' @param Value The value to test for equality.
'
Public Function Equals(ByRef Value As Variant) As Boolean
    Equals = Object.Equals(Me, Value)
End Function

''
' Returns a psuedo-unique number used to help identify this
' object in memory. The current method is to return the value
' obtained from ObjPtr. If a different method needs to be impelmented
' then change the method here in this function.
'
' An override might be necessary if the hashcode should be
' derived from a value contained within the class.
'
Public Function GetHashCode() As Long
    GetHashCode = ObjPtr(CUnk(Me))
End Function

''
' Returns a string representation of this object instance.
' The default method simply returns the application name
' and class name in which this class resides.
'
' A Person class may return the person's name instead.
'
Public Function ToString() As String
    ToString = Object.ToString(Me, App)
End Function



'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'   Friend Interface
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Friend Sub Init(ByVal KeySize As Long, ByVal Params As CspParameters)
    If KeySize > 0 Then mKeySize = KeySize
    
    If Not Params Is Nothing Then
        With Params
            mProviderName = .ProviderName
            mProviderType = .ProviderType
            mKeyContainerName = .KeyContainerName
            mKeyNumber = IIf(.KeyNumber = -1, DEF_KEYNUMBER, .KeyNumber)
            mFlags = .Flags
        End With
        
        mPersistKeyInCsp = True
    End If
End Sub


'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'   Private Helpers
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Private Sub VerifyLoaded(Optional ByVal IncludeKey As Boolean = True)
    If mIsDisposed Then _
        Throw New ObjectDisposedException
        
    Call LoadProvider
    
    If IncludeKey Then
        Call GenerateKey
    End If
End Sub

''
' This attempts to acquire a new provider and create a new key container
' within the specified provider. If the container name doesn't exist, then
' a random name will be created. If the container itself already exists,
' then the existing container will be used instead of creating a new one.
Private Sub LoadProvider()
    If mProvider <> vbNullPtr Then Exit Sub
    
    Dim dwFlags As Long
    If mFlags And CspProviderFlags.UseMachineKeyStore Then dwFlags = CRYPT_MACHINE_KEYSET
    
    mProvider = CryptoAPI.AcquireContext(mKeyContainerName, mProviderName, mProviderType, dwFlags)
End Sub

Private Sub GenerateKey()
    If mKey <> vbNullPtr Then Exit Sub
    
    If mFlags And UseExistingKey Then
        ' Try to get an existing key.
        If CryptGetUserKey(mProvider, mKeyNumber, mKey) <> BOOL_FALSE Then Exit Sub
        
        ' Something went wrong. If it's something other than
        ' not finding the key, then it's bad, so fail.
        If Err.LastDllError <> NTE_NO_KEY Then _
            Throw Cor.NewCryptographicException(GetErrorMessage(Err.LastDllError))
            
        ' We didn't find an existing key, so continue and create a new one.
    End If
    
    Dim Flags As Long
    Flags = Helper.ShiftLeft(mKeySize, 16)  ' the key size is held in the upper 16-bits.
    
    ' We must specify to make the key archivable.
    If mFlags And UseArchivableKey Then Flags = Flags Or CRYPT_ARCHIVABLE
    
    ' We must specify to NOT create an exportable key.
    If (mFlags And UseNonExportableKey) = 0 Then Flags = Flags Or CRYPT_EXPORTABLE
    
    If Not CryptoAPI.SupportsAlgorithm(mProvider, IIf(mKeyNumber = AT_KEYEXCHANGE, CALG_RSA_KEYX, CALG_RSA_SIGN)) Then _
        Throw Cor.NewCryptographicException("The Cryptography Service Provider (CSP) does not support the specified algorithm.")
    
    ' Let'er rip! This can take a bit with large key sizes.
    If CryptGenKey(mProvider, mKeyNumber, Flags, mKey) = BOOL_FALSE Then _
        Throw Cor.NewCryptographicException(GetErrorMessage(Err.LastDllError))
End Sub

Private Sub DeleteKey()
    Call CryptoAPI.DestroyKey(mKey)
    mKey = vbNullPtr
End Sub

Private Function SetHash(ByRef RgbHash() As Byte, ByVal Str As String) As Long
    Call VerifyLoaded
    
    If cArray.IsNull(RgbHash) Then _
        Throw Cor.NewArgumentNullException(Environment.GetResourceString(ArgumentNull_Array), "RgbHash")
    
    Dim HashAlg As Long
    Dim HashLen As Long
    Select Case LCase$(Str)
        Case "1.3.14.3.2.26", "sha", "sha1":    HashAlg = CALG_SHA1: HashLen = 20
        Case "1.2.840.113549.2.5", "md5":       HashAlg = CALG_MD5: HashLen = 16
        Case Else
            Throw Cor.NewArgumentException("Only SHA1 and MD5 hash algorithms are supported.", "Str")
    End Select
    
    If cArray.GetLength(RgbHash) <> HashLen Then _
        Throw Cor.NewCryptographicException("Invalid hash length.")
    
    On Error GoTo errTrap
    
    Dim Hash As Long
    If CryptCreateHash(mProvider, HashAlg, 0, 0, Hash) = BOOL_FALSE Then _
        Throw Cor.NewCryptographicException(GetErrorMessage(Err.LastDllError))

    If CryptSetHashParam(Hash, HP_HASHVAL, RgbHash(LBound(RgbHash)), 0) = 0 Then _
        Throw Cor.NewCryptographicException(GetErrorMessage(Err.LastDllError))

    SetHash = Hash
    Exit Function
    
errTrap:
    If Hash <> vbNullPtr Then Call CryptDestroyHash(Hash)
    
    Dim Ex As Exception
    If Catch(Ex) Then Throw Ex
End Function

Private Function GetOID(ByVal HashObj As HashAlgorithm) As String
    Dim OID As String
    If TypeOf HashObj Is SHA1 Then
        OID = CryptoConfig.MapNameToOID("SHA1")
    ElseIf TypeOf HashObj Is MD5 Then
        OID = CryptoConfig.MapNameToOID("MD5")
    End If
    
    GetOID = OID
End Function

Private Function GetHash(ByRef hAlg As Variant) As HashAlgorithm
    Dim HashObj As HashAlgorithm
    
    Select Case VarType(hAlg)
        Case vbString
            Select Case LCase$(hAlg)
                Case "1.3.14.3.2.26", "sha", "sha1": Set HashObj = New SHA1CryptoServiceProvider
                Case "1.2.840.113549.2.5", "md5":    Set HashObj = New MD5CryptoServiceProvider
                Case Else
                    Throw Cor.NewArgumentException("Only SHA1 and MD5 hash algorithms are supported.", "hAlg")
            End Select
            
        Case vbObject
            If hAlg Is Nothing Then _
                Throw Cor.NewArgumentNullException("Hash object cannot be Nothing.", "hAlg")
            
            If (TypeOf hAlg Is SHA1) Or (TypeOf hAlg Is MD5) Then
                Set HashObj = hAlg
            Else
                Throw Cor.NewArgumentException("Hash object must be SHA1 or MD5 compatible.", "hAlg")
            End If
            
        Case Else
            Throw Cor.NewArgumentException("Invalid hash algorithm specified.", "hAlg")
    End Select
    
    Set GetHash = HashObj
End Function


'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'   Class Events
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Private Sub Class_Initialize()
    ReDim mLegalKeySizes(0)
    If CryptoAPI.HasHighEncryption Then
        Set mLegalKeySizes(0) = Cor.NewKeySizes(384, 16384, 8)
        mKeySize = 1024
    Else
        Set mLegalKeySizes(0) = Cor.NewKeySizes(384, 512, 8)
        mKeySize = 512
    End If
    
    mProviderType = DEF_PROVIDERTYPE
    mKeyNumber = DEF_KEYNUMBER
End Sub

Private Sub Class_Terminate()
    Call CryptoAPI.DestroyKey(mKey)
    Call CryptoAPI.ReleaseContext(mProvider, Not mPersistKeyInCsp)
End Sub



'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'   AsymmetricAlgorithm Interface
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Private Sub AsymmetricAlgorithm_Clear()
    Call Clear
End Sub

Private Function AsymmetricAlgorithm_Equals(Value As Variant) As Boolean
    AsymmetricAlgorithm_Equals = Equals(Value)
End Function

Private Sub AsymmetricAlgorithm_FromXmlString(ByVal XmlString As String)
    Call FromXmlString(XmlString)
End Sub

Private Function AsymmetricAlgorithm_GetHashCode() As Long
    AsymmetricAlgorithm_GetHashCode = GetHashCode
End Function

Private Property Get AsymmetricAlgorithm_KeyExchangeAlgorithm() As String
    AsymmetricAlgorithm_KeyExchangeAlgorithm = KeyExchangeAlgorithm
End Property

Private Property Let AsymmetricAlgorithm_KeySize(ByVal RHS As Long)
    KeySize = RHS
End Property

Private Property Get AsymmetricAlgorithm_KeySize() As Long
    AsymmetricAlgorithm_KeySize = KeySize
End Property

Private Property Get AsymmetricAlgorithm_LegalKeySizes() As KeySizes()
    AsymmetricAlgorithm_LegalKeySizes = LegalKeySizes
End Property

Private Property Get AsymmetricAlgorithm_SignatureAlgorithm() As String
    AsymmetricAlgorithm_SignatureAlgorithm = SignatureAlgorithm
End Property

Private Function AsymmetricAlgorithm_ToString() As String
    AsymmetricAlgorithm_ToString = ToString
End Function

Private Function AsymmetricAlgorithm_ToXmlString(ByVal IncludePrivateParameters As Boolean) As String
    AsymmetricAlgorithm_ToXmlString = ToXmlString(IncludePrivateParameters)
End Function


'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'   ICspAsymmetricAlgorithm Interface
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Private Property Get ICspAsymmetricAlgorithm_CspKeyContainerInfo() As CspKeyContainerInfo
    Set ICspAsymmetricAlgorithm_CspKeyContainerInfo = CspKeyContainerInfo
End Property

Private Function ICspAsymmetricAlgorithm_ExportCspBlob(ByVal IncludePrivateParameters As Boolean) As Byte()
    ICspAsymmetricAlgorithm_ExportCspBlob = ExportCspBlob(IncludePrivateParameters)
End Function

Private Sub ICspAsymmetricAlgorithm_ImportCspBlob(RawData() As Byte)
    Call ImportCspBlob(RawData)
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
'   RSA Interface
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
Private Sub RSA_Clear()
    Call Clear
End Sub

Private Function RSA_DecryptValue(Rgb() As Byte) As Byte()
    RSA_DecryptValue = DecryptValue(Rgb)
End Function

Private Function RSA_EncryptValue(Rgb() As Byte) As Byte()
    RSA_EncryptValue = EncryptValue(Rgb)
End Function

Private Function RSA_Equals(Value As Variant) As Boolean
    RSA_Equals = Equals(Value)
End Function

Private Function RSA_ExportParameters(ByVal IncludePrivateParameters As Boolean) As RSAParameters
    Set RSA_ExportParameters = ExportParameters(IncludePrivateParameters)
End Function

Private Sub RSA_FromXmlString(ByVal XmlString As String)
    Call FromXmlString(XmlString)
End Sub

Private Function RSA_GetHashCode() As Long
    RSA_GetHashCode = GetHashCode
End Function

Private Sub RSA_ImportParameters(ByVal Parameters As RSAParameters)
    Call ImportParameters(Parameters)
End Sub

Private Property Get RSA_KeyExchangeAlgorithm() As String
    RSA_KeyExchangeAlgorithm = KeyExchangeAlgorithm
End Property

Private Property Let RSA_KeySize(ByVal RHS As Long)
    KeySize = RHS
End Property

Private Property Get RSA_KeySize() As Long
    RSA_KeySize = KeySize
End Property

Private Property Get RSA_LegalKeySizes() As KeySizes()
    RSA_LegalKeySizes = LegalKeySizes
End Property

Private Property Get RSA_SignatureAlgorithm() As String
    RSA_SignatureAlgorithm = SignatureAlgorithm
End Property

Private Function RSA_ToString() As String
    RSA_ToString = ToString
End Function

Private Function RSA_ToXmlString(ByVal IncludePrivateParameters As Boolean) As String
    RSA_ToXmlString = ToXmlString(IncludePrivateParameters)
End Function
