// SPDX-License-Identifier: MIT
// signing.swift: Ed25519 signatures of a release's list of hashes (VERSION.sha256), so IntelXe Manager can tell a release
// that the project made from one that only came from the same GitHub page (CryptoKit, nothing to install).
//
//   swift release/signing.swift keygen KEYFILE           a new private key into KEYFILE (mode 600); prints the public key
//   swift release/signing.swift public KEYFILE           prints the public key of KEYFILE
//   swift release/signing.swift sign KEYFILE FILE        writes FILE.sig: the signature of FILE's bytes, base64, one line
//   swift release/signing.swift verify PUBLIC FILE SIG   exit 0 when SIG is PUBLIC's signature of FILE
//
// Keys and signatures are base64 of their raw bytes (32-byte keys, 64-byte signatures). The public key is in
// app/Sources/Signing.swift; the private key stays with the maintainer, never in this repository.
import CryptoKit
import Foundation

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

func read(_ path: String) -> Data {
    guard let data = FileManager.default.contents(atPath: path) else { fail("cannot read \(path)") }
    return data
}

func base64(_ path: String) -> Data {
    let text = String(decoding: read(path), as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    guard let data = Data(base64Encoded: text) else { fail("\(path) is not base64") }
    return data
}

func privateKey(_ path: String) -> Curve25519.Signing.PrivateKey {
    guard let key = try? Curve25519.Signing.PrivateKey(rawRepresentation: base64(path)) else { fail("\(path) is not an Ed25519 private key") }
    return key
}

let args = CommandLine.arguments
switch (args.count > 1 ? args[1] : "", args.count) {
case ("keygen", 3):
    let path = args[2]
    if FileManager.default.fileExists(atPath: path) { fail("\(path) exists: not overwritten") }
    let key = Curve25519.Signing.PrivateKey()
    guard FileManager.default.createFile(atPath: path, contents: Data((key.rawRepresentation.base64EncodedString() + "\n").utf8),
                                         attributes: [.posixPermissions: 0o600]) else { fail("cannot write \(path)") }
    print(key.publicKey.rawRepresentation.base64EncodedString())
case ("public", 3):
    print(privateKey(args[2]).publicKey.rawRepresentation.base64EncodedString())
case ("sign", 4):
    let key = privateKey(args[2])
    guard let signature = try? key.signature(for: read(args[3])) else { fail("signing failed") }
    guard key.publicKey.isValidSignature(signature, for: read(args[3])) else { fail("the new signature does not verify") }
    guard FileManager.default.createFile(atPath: args[3] + ".sig", contents: Data((signature.base64EncodedString() + "\n").utf8))
    else { fail("cannot write \(args[3]).sig") }
case ("verify", 5):
    guard let raw = Data(base64Encoded: args[2]), let key = try? Curve25519.Signing.PublicKey(rawRepresentation: raw) else { fail("not a public key: \(args[2])") }
    guard key.isValidSignature(base64(args[4]), for: read(args[3])) else { fail("BAD signature: \(args[4]) is not \(args[2])'s signature of \(args[3])") }
    print("signature OK")
default:
    fail("usage: signing.swift keygen KEYFILE | public KEYFILE | sign KEYFILE FILE | verify PUBLIC FILE SIG")
}
