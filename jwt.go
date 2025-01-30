package main

import (
	"bytes"
	"fmt"
	"log"
	"time"

	"github.com/tink-crypto/tink-go/v2/insecurecleartextkeyset"
	"github.com/tink-crypto/tink-go/v2/jwt"
	"github.com/tink-crypto/tink-go/v2/keyset"
)

func signAndVerify() {
	// A private keyset created with
	// "tinkey create-keyset --key-template=JWT_ES256 --out private_keyset.cfg".
	// Note that this keyset has the secret key information in cleartext.
	privateJSONKeyset := `{
			"primaryKeyId": 1742360595,
			"key": [
					{
							"keyData": {
									"typeUrl": "type.googleapis.com/google.crypto.tink.JwtEcdsaPrivateKey",
									"value": "GiBgVYdAPg3Fa2FVFymGDYrI1trHMzVjhVNEMpIxG7t0HRJGIiBeoDMF9LS5BDCh6YgqE3DjHwWwnEKEI3WpPf8izEx1rRogbjQTXrTcw/1HKiiZm2Hqv41w7Vd44M9koyY/+VsP+SAQAQ==",
									"keyMaterialType": "ASYMMETRIC_PRIVATE"
							},
							"status": "ENABLED",
							"keyId": 1742360595,
							"outputPrefixType": "TINK"
					}
			]
	}`

	// The corresponding public keyset created with
	// "tinkey create-public-keyset --in private_keyset.cfg"
	publicJSONKeyset := `{
			"primaryKeyId": 1742360595,
			"key": [
					{
							"keyData": {
									"typeUrl": "type.googleapis.com/google.crypto.tink.JwtEcdsaPublicKey",
									"value": "EAEaIG40E1603MP9RyoomZth6r+NcO1XeODPZKMmP/lbD/kgIiBeoDMF9LS5BDCh6YgqE3DjHwWwnEKEI3WpPf8izEx1rQ==",
									"keyMaterialType": "ASYMMETRIC_PUBLIC"
							},
							"status": "ENABLED",
							"keyId": 1742360595,
							"outputPrefixType": "TINK"
					}
			]
	}`

	// Create a keyset handle from the cleartext private keyset in the previous
	// step. The keyset handle provides abstract access to the underlying keyset to
	// limit the access of the raw key material. WARNING: In practice,
	// it is unlikely you will want to use a insecurecleartextkeyset, as it implies
	// that your key material is passed in cleartext, which is a security risk.
	// Consider encrypting it with a remote key in Cloud KMS, AWS KMS or HashiCorp Vault.
	// See https://github.com/google/tink/blob/master/docs/GOLANG-HOWTO.md#storing-and-loading-existing-keysets.
	privateKeysetHandle, err := insecurecleartextkeyset.Read(
		keyset.NewJSONReader(bytes.NewBufferString(privateJSONKeyset)))
	if err != nil {
		log.Fatal(err)
	}

	// Retrieve the JWT Signer primitive from privateKeysetHandle.
	signer, err := jwt.NewSigner(privateKeysetHandle)
	if err != nil {
		log.Fatal(err)
	}

	// Use the primitive to create and sign a token. In this case, the primary key of the
	// keyset will be used (which is also the only key in this example).
	expiresAt := time.Now().Add(time.Hour)
	audience := "example audience"
	subject := "example subject"
	rawJWT, err := jwt.NewRawJWT(&jwt.RawJWTOptions{
		Audience:  &audience,
		Subject:   &subject,
		ExpiresAt: &expiresAt,
	})
	if err != nil {
		log.Fatal(err)
	}
	token, err := signer.SignAndEncode(rawJWT)
	if err != nil {
		log.Fatal(err)
	}

	// Create a keyset handle from the keyset containing the public key. Because the
	// public keyset does not contain any secrets, we can use [keyset.ReadWithNoSecrets].
	publicKeysetHandle, err := keyset.ReadWithNoSecrets(
		keyset.NewJSONReader(bytes.NewBufferString(publicJSONKeyset)))
	if err != nil {
		log.Fatal(err)
	}

	// Retrieve the Verifier primitive from publicKeysetHandle.
	verifier, err := jwt.NewVerifier(publicKeysetHandle)
	if err != nil {
		log.Fatal(err)
	}

	// Verify the signed token.
	validator, err := jwt.NewValidator(&jwt.ValidatorOpts{ExpectedAudience: &audience})
	if err != nil {
		log.Fatal(err)
	}
	verifiedJWT, err := verifier.VerifyAndDecode(token, validator)
	if err != nil {
		log.Fatal(err)
	}

	// Extract subject claim from the token.
	if !verifiedJWT.HasSubject() {
		log.Fatal(err)
	}
	extractedSubject, err := verifiedJWT.Subject()
	if err != nil {
		log.Fatal(err)
	}
	fmt.Println(extractedSubject)
	// Output: example subject

	fmt.Println("JWT:")
	fmt.Println(token)
}
